--- testSocket
-- @module testSocket
-- @author AIRM2M
-- @license MIT
-- @copyright openLuat.com
-- @release 2018.10.27
require "socket"
module(..., package.seeall)

-- 此处的IP和端口请填上你自己的socket服务器和端口
local ip, port, c = "180.97.80.55", "12415"

-- tcp test
sys.taskInit(function()
    local r, s, p
    local recv_cnt, send_cnt = 0, 0
    while true do
        while not socket.isReady() do sys.wait(1000) end
        c = socket.tcp()
        while not c:connect(ip, port) do sys.wait(2000) end
        while true do
            r, s, p = c:recv(120000, "pub_msg")
            if r then
                recv_cnt = recv_cnt + #s
                log.info("这是收到的服务器下发的数据统计:", recv_cnt, "和前30个字节:", s:sub(1, 30))
            elseif s == "pub_msg" then
                send_cnt = send_cnt + #p
                log.info("这是收到别的线程发来的数据消息!", send_cnt, "和前30个字节", p:sub(1, 30))
                if not c:send(p) then break end
            elseif s == "timeout" then
                log.info("这是等待超时发送心跳包的显示!")
                if not c:send("ping") then break end
            else
                log.info("这是socket连接错误的显示!")
                break
            end
        end
        c:close()
    end
end)

-- 测试代码,用于发送消息给socket
sys.taskInit(function()
    while not socket.isReady() do sys.wait(2000) end
    sys.wait(10000)
    -- 这是演示用sys.publish()发送数据
    for i = 1, 10 do
        sys.publish("pub_msg", string.rep("0123456789", 1024))
        sys.wait(500)
    end
end)

sys.timerLoopStart(function()
    log.info("打印占用的内存:", _G.collectgarbage("count"))-- 打印占用的RAM
    log.info("打印可用的空间", rtos.get_fs_free_size())-- 打印剩余FALSH，单位Byte
end, 1000)

