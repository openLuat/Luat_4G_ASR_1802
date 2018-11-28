--- 模块功能：数据链路激活(创建、连接、状态维护)
-- @module link
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.9.20

require"net"

module(..., package.seeall)

local publish = sys.publish
local request = ril.request
local ready = false
local gprsAttached

function isReady() return ready end

-- apn，用户名，密码
local apnname, username, password
local dnsIP

function setAPN(apn, user, pwd)
    apnname, username, password = apn, user, pwd
end

function setDnsIP(ip1, ip2)
    dnsIP = "\"" .. (ip1 or "") .. "\",\"" .. (ip2 or "") .. "\""
end

function shut()
	ril.request("AT+CGACT=0,1",nil,
        function(cmd,result)
            if result then
                ready = false
                sys.publish('IP_ERROR_IND')
                request('AT+CGATT?')
            end
        end
    )	
end

function pdpCmdCnf(curCmd, result,respdata, interdata)
    log.info("link.pdpCmdCnf",curCmd, result,respdata, interdata)
    if string.find(curCmd, "CGDCONT%?") then
        if result and interdata then
            local cid,pdptyp,apn,pdpaddr1,pdpaddr2,pdpaddr3,pdpaddr4=string.match(interdata, "(%d+),(.+),(.+),[\"\'](%d+).(%d+).(%d+).(%d+)[\"\']")
            if not cid or not pdptyp or not apn or not pdpaddr1 or not pdpaddr2 or not pdpaddr3 or not pdpaddr4 then
                log.info("link.pdpCmdCnf CGDCONT is empty")
                result=false
            end
        else
            log.info("link.pdpCmdCnf CGDCONT is empty")
            result=false
        end
    end
    if result then
        if string.find(curCmd, "CGDCONT=") then
            request('AT+CGACT=1,1', nil, pdpCmdCnf)
        elseif string.find(curCmd, "CGDCONT%?") then
            sys.timerStart(pdpCmdCnf, 100, "CONNECT_DELAY",true)
        elseif string.find(curCmd, "CONNECT_DELAY") then
            log.info("publish IP_READY_IND")
            ready = true
            publish("IP_READY_IND")
        elseif string.find(curCmd, "CGACT") then
            request("AT+CGDCONT?", nil, pdpCmdCnf)
        elseif string.find(curCmd, "CGDFLT") then
            request("AT+CGDCONT?", nil, pdpCmdCnf)
        elseif string.find(curCmd,"SET_PDP_4G_WAITAPN") then
            if not apnname then
                sys.timerStart(pdpCmdCnf, 100, "SET_PDP_4G_WAITAPN",true)
            else
			    request(string.format('AT+CGDCONT=1,"IP","%s"', apnname), nil, pdpCmdCnf)
           --   request(string.format('AT*CGDFLT=0,"IP","%s"', apnname), nil, pdpCmdCnf)
            end
        end
    else
        if net.getState() ~= 'REGISTERED' then return end
        if net.getNetMode() == net.NetMode_LTE then
            request("AT+CGDCONT?", nil, pdpCmdCnf,1000)
        else
            request("AT+CGATT?", nil, nil, 1000)
        end        
    end
end

-- SIM卡 IMSI READY以后自动设置APN
sys.subscribe("IMSI_READY", function()
    if not apnname then -- 如果未设置APN设置默认APN
        local mcc, mnc = tonumber(sim.getMcc(), 16), tonumber(sim.getMnc(), 16)
        apnname, username, password = apn and apn.get_default_apn(mcc, mnc) -- 如果存在APN库自动获取运营商的APN
        if not apnname or apnname == '' or apnname=="CMNET" then -- 默认情况，如果联通卡设置为联通APN 其他都默认为CMIOT
            apnname = (mcc == 0x460 and (mnc == 0x01 or mnc == 0x06)) and 'UNINET' or 'CMIOT'
        end
    end
    username = username or ''
    password = password or ''
end)

ril.regRsp('+CGATT', function(a, b, c, intermediate)
    local attached = (intermediate == "+CGATT: 1")
    if gprsAttached ~= attached then
        gprsAttached = attached
        sys.publish("GPRS_ATTACH", attached)
    end

    if attached then
        log.info("pdp active", apnname, username, password)
        request(string.format('AT+CGDCONT=1,"IP","%s"', apnname), nil, pdpCmdCnf)
    elseif net.getState() == 'REGISTERED' then
        sys.timerStart(request, 2000, "AT+CGATT=1")
        sys.timerStart(request, 2000, "AT+CGATT?")
    end
end)

rtos.on(rtos.MSG_PDP_DEACT_IND, function()
    ready = false
    sys.publish('IP_ERROR_IND')
    request('AT+CGATT?')
end)

local function Pdp_Act()
    log.info(ready,net.getNetMode(), gprsAttached)
    if ready then 
        request("AT+CGDCONT?", nil, pdpCmdCnf)
        return 
    end
    if net.getNetMode() == net.NetMode_LTE then
        if not gprsAttached then
            gprsAttached = true
            sys.publish("GPRS_ATTACH", true)
        end
        if not apnname then
            sys.timerStart(pdpCmdCnf, 1000, "SET_PDP_4G_WAITAPN",true)
        else
            request(string.format('AT+CGDCONT=1,"IP","%s"', apnname), nil, pdpCmdCnf)
            --request(string.format('AT*CGDFLT=0,"IP","%s"', apnname), nil, pdpCmdCnf)
        end
    else
        request('AT+CGATT?')
    end
end

-- 网络注册成功 :4G,AT*CGDFLT 设置PDP Context info
--            2/3G发起GPRS附着状态查询
sys.subscribe("NET_STATE_REGISTERED", Pdp_Act)

local function cindCnf(cmd, result)
    if not result then
        request("AT+CIND=1", nil, cindCnf,1000)
    end
end

local function cgevurc(data)
    log.info("link.cgevurc",data)
    if string.match(data, "DEACT") then
        ready = false
        sys.publish('IP_ERROR_IND')
        
        if net.getState() ~= 'REGISTERED' then return end
        sys.timerStart(Pdp_Act, 2000)
    end
end

request("AT+CIND=1", nil, cindCnf)
ril.regUrc("+CGEV", cgevurc)


