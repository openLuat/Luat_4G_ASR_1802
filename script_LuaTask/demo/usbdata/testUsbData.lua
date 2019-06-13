--- 模块功能：USB AT 口收发数据功能测试
-- @author openLuat
-- @module update.testUpdate1
-- @license MIT
-- @copyright openLuat
-- @release 2019.05.9

module(...,package.seeall)

--[[
函数名：usbreader
功能  ：向USB AT 口发送数据
参数  ：无
返回值：无
]]
local function usbwrite(s)
    log.info("usb send",s)
    uart.write(uart.USB, s) 
end

--[[
函数名：usbreader
功能  ：从USB AT 口接收数据
参数  ：无
返回值：无
]]
local function usbreader()
    local s
    
    --循环读取收到的数据
    while true do
        --每次读取一行
        s = uart.read(uart.USB, "*l", 0)
        if string.len(s) ~= 0 then
                log.info("usb rcv",s);
                usbwrite(s)                
        else
            break
        end
    end
end

uart.setup(uart.USB, 0, 0, uart.PAR_NONE, uart.STOP_1)

uart.on(uart.USB, "receive", usbreader)

sys.timerLoopStart(log.info,5000,"testUpdate.version",rtos.get_version(),_G.VERSION)
