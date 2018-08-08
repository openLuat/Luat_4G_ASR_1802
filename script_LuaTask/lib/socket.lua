--- 模块功能：数据链路激活、SOCKET管理(创建、连接、数据收发、状态维护)
-- @module socket
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.9.25
require"link"
require"utils"
module(..., package.seeall)

local valid = { "0", "1", "2", "3", "4", "5", "6", "7" }
local sockets = {}
-- 单次发送数据最大值
local SENDSIZE = 1460
-- 缓冲区最大下标
local INDEX_MAX = 49

--- SOCKET 是否有可用
-- @return 可用true,不可用false
socket.isReady = link.isReady

local function isSocketActive()
    for _, c in pairs(sockets) do
        if c.connected then
            return true
        end
    end
end

local function socketStatusNtfy()
    sys.publish("SOCKET_ACTIVE",isSocketActive())
end

local function errorInd(error)
    for _, c in pairs(sockets) do -- IP状态出错时，通知所有已连接的socket
        --if c.connected then
            if error == 'CLOSED' then c.connected = false socketStatusNtfy() end
            c.error = error
            if c.co and coroutine.status(c.co)=="suspended" then coroutine.resume(c.co, false) end
        --end
    end
end

sys.subscribe("IP_ERROR_IND", function() errorInd('IP_ERROR_IND') end)
sys.subscribe('IP_SHUT_IND', function() errorInd('CLOSED') end)

-- 创建socket函数
local mt = { __index = {} }
local function socket(protocol, cert)
    local ssl = protocol:match("SSL")
    local id = table.remove(ssl and validSsl or valid)
    if not id then
        log.warn("socket.socket: too many sockets")
        return nil
    end
    
    local co = coroutine.running()
    if not co then
        log.warn("socket.socket: socket must be called in coroutine")
        return nil
    end
    -- 实例的属性参数表
    local o = {
        id = id,
        protocol = protocol,
        ssl = ssl,
        cert = cert,
        co = co,
        input = {},
        wait = "",
        core_id = nil,
    }

    sockets[id] = o

    return setmetatable(o, mt)
end

--- 创建基于TCP的socket对象
-- @bool[opt=nil] ssl，是否为ssl连接，true表示是，其余表示否
-- @table[opt=nil] cert，ssl连接需要的证书配置，只有ssl参数为true时，才参数才有意义，cert格式如下：
-- {
--     caCert = "ca.crt", --CA证书文件(Base64编码 X.509格式)，如果存在此参数，则表示客户端会对服务器的证书进行校验；不存在则不校验
--     clientCert = "client.crt", --客户端证书文件(Base64编码 X.509格式)，服务器对客户端的证书进行校验时会用到此参数
--     clientKey = "client.key", --客户端私钥文件(Base64编码 X.509格式)
--     clientPassword = "123456", --客户端证书文件密码[可选]
-- }
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage 
-- c = socket.tcp()
-- c = socket.tcp(true)
-- c = socket.tcp(true, {caCert="ca.crt"})
-- c = socket.tcp(true, {caCert="ca.crt", clientCert="client.crt", clientKey="client.key"})
-- c = socket.tcp(true, {caCert="ca.crt", clientCert="client.crt", clientKey="client.key", clientPassword="123456"})
function tcp(ssl,cert)
    return socket("TCP"..(ssl==true and "SSL" or ""), (ssl==true) and cert or nil)
end

--- 创建基于UDP的socket对象
-- @return client，创建成功返回socket客户端对象；创建失败返回nil
-- @usage c = socket.udp()
function udp()
    return socket("UDP")
end

--- 连接服务器
-- @string address 服务器地址，支持ip和域名
-- @param port string或者number类型，服务器端口
-- @return bool result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect();
function mt.__index:connect(address, port)
    assert(self.co == coroutine.running(), "socket:connect: coroutine mismatch")

    if not link.isReady() then
        log.info("socket.connect: ip not ready")
        return false
    end

    log.info("socket.connect", self.protocol, address, port, self.cert)
    local core_id
    if self.protocol == 'TCP' then        
        core_id = socketcore.sock_conn(0, address, port)
    elseif self.protocol == 'TCPSSL' then
        local cert = {hostName=address}
        if self.cert then
            if self.cert.caCert then
                if self.cert.caCert:sub(1,1)~="/" then self.cert.caCert="/lua/"..self.cert.caCert end
                cert.caCert = io.readFile(self.cert.caCert)
            end
            if self.cert.clientCert then
                if self.cert.clientCert:sub(1,1)~="/" then self.cert.clientCert="/lua/"..self.cert.clientCert end
                cert.clientCert = io.readFile(self.cert.clientCert)
            end
            if self.cert.clientKey then
                if self.cert.clientKey:sub(1,1)~="/" then self.cert.clientKey="/lua/"..self.cert.clientKey end
                cert.clientKey = io.readFile(self.cert.clientKey)
            end
        end
        core_id = socketcore.sock_conn(2, address, port, cert)
    else 
        core_id = socketcore.sock_conn(1, address, port)
    end
    if not core_id then
        log.info("socket:connect: core sock conn error")
        return false
    end
    log.info("socket:connect", core_id, self.protocol, address, port)
    self.core_id = core_id
    self.wait = "SOCKET_CONNECT"
    if coroutine.yield() == false then return false end
    log.info("socket:connect: connect ok")
    self.connected = true
    socketStatusNtfy()
    return true
end
--- 发送数据
-- @string data 数据
-- @return result true - 成功，false - 失败
-- @usage  c = socket.tcp(); c:connect(); c:send("12345678");
function mt.__index:send(data)
    assert(self.co == coroutine.running(), "socket:send: coroutine mismatch")
    if self.error then
        log.warn('socket.client:send', 'error', self.error)
        return false
    end
    if self.id==nil then
        log.warn('socket.client:send', 'closed')
        return false
    end
    
    for i = 1, string.len(data), SENDSIZE do
        -- 按最大MTU单元对data分包
        local stepData = string.sub(data, i, i + SENDSIZE - 1)
        --发送AT命令执行数据发送
        log.info("socket.send", "total "..stepData:len().." bytes", "first 300 bytes", stepData:sub(1,300))
        socketcore.sock_send(self.core_id, stepData)
        self.wait = "SOCKET_SEND"
        if not coroutine.yield() then return false end
    end
    return true
end
--- 接收数据
-- @number[opt=0] timeout 可选参数，接收超时时间
-- @return result true - 成功，false - 失败
-- @return data 如果成功的话，返回接收到的数据，超时时返回错误为"timeout"
-- @usage  c = socket.tcp(); c:connect(); result, data = c:recv()
function mt.__index:recv(timeout)
    assert(self.co == coroutine.running(), "socket:recv: coroutine mismatch")
    if self.error then
        log.warn('socket.client:recv', 'error', self.error)
        return false
    end

    if #self.input == 0 then
        self.wait = "+RECEIVE"
        if timeout and timeout~=0 then
            local r, s = sys.wait(timeout)
            if r == nil then
                return false, "timeout"
            else
                return r, s
            end
        else
            return coroutine.yield()
        end
    end

    if self.protocol == "UDP" then
        return true, table.remove(self.input)
    else
        local s = table.concat(self.input)
        self.input = {}
        return true, s
    end
end

--- 销毁一个socket
-- @return nil
-- @usage  c = socket.tcp(); c:connect(); c:send("123"); c:close()
function mt.__index:close()
    assert(self.co == coroutine.running(), "socket:close: coroutine mismatch")
    if self.connected then
        log.info("socket:sock_close", self.core_id)
        self.connected = false
        socketcore.sock_close(self.core_id)
        self.wait = "SOCKET_CLOSE"
        coroutine.yield()
        socketStatusNtfy()
    end
    if self.id~=nil then
        table.insert(valid, 1, self.id)
        sockets[self.id] = nil
        self.id = nil
    end
end

local function find_socket(core_id)
    for _, client in pairs(sockets) do
        if client.core_id == core_id then
            return client
        end
    end
end

local function on_response(msg)
    local item = find_socket(msg.socket_index)
    if not item then
        log.warn('response on nil socket', msg.socket_index, msg.id)
        return
    end

    local t = {
        [rtos.MSG_SOCK_CLOSE_CNF] = 'SOCKET_CLOSE',
        [rtos.MSG_SOCK_SEND_CNF] = 'SOCKET_SEND',
        [rtos.MSG_SOCK_CONN_CNF] = 'SOCKET_CONNECT',
    }
    log.info("socket:on_response:", msg.socket_index, t[msg.id], msg.result)
    if item.wait ~= t[msg.id] then
        log.warn('response on invalid wait', item.id, item.wait, t[msg.id], msg.socket_index)
        return
    end

    coroutine.resume(item.co, msg.result == 0)
end

rtos.on(rtos.MSG_SOCK_CLOSE_CNF, on_response)
rtos.on(rtos.MSG_SOCK_CONN_CNF, on_response)
rtos.on(rtos.MSG_SOCK_SEND_CNF, on_response)
rtos.on(rtos.MSG_SOCK_CLOSE_IND, function(msg)
    local item = find_socket(msg.socket_index)
    if not item then
        log.warn('close ind on nil socket', msg.socket_index, msg.id)
        return
    end
    item.connected = false
    item.error = 'CLOSED'
    socketStatusNtfy()
    coroutine.resume(item.co, false)
end)
rtos.on(rtos.MSG_SOCK_RECV_IND, function(msg)
    local item = find_socket(msg.socket_index)
    if not item then
        log.warn('close ind on nil socket', msg.socket_index, msg.id)
        return
    end

    local s = socketcore.sock_recv(msg.socket_index, msg.recv_len)
    
    --[[if s and s:len()>0 then
        log.info("socket recv","total "..s:len().." bytes","first 300 bytes",s:sub(1,300))
    end]]

    if item.wait == "+RECEIVE" then
        coroutine.resume(item.co, true, s)
    else -- 数据进缓冲区，缓冲区溢出采用覆盖模式
        if #item.input > INDEX_MAX then log.error("socket recv","out of stack") sockets[id].input = {} end
        table.insert(item.input, s)
    end
end)

function printStatus()
    log.info('socket.printStatus', 'valid id', table.concat(valid))

    for _, client in pairs(sockets) do
        for k, v in pairs(client) do
            log.info('socket.printStatus', 'client', client.id, k, v)
        end
    end
end
