--- 模块功能：串口功能测试(TASK版)
-- @author openLuat
-- @module uart.testUartTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.10.20
require "utils"
require "pm"
module(..., package.seeall)


-------------------------------------------- 配置串口 --------------------------------------------
-- 串口ID,串口读缓冲区
local UART_ID, sendQueue = 1, {}
-- 串口超时，串口准备好后发布的消息
local uartimeout, recvReady = 25, "UART_RECV_ID"
--保持系统处于唤醒状态，不会休眠
pm.wake("mcuart")
uart.setup(UART_ID, 115200, 8, uart.PAR_NONE, uart.STOP_1, nil, 1)
uart.on(1, "receive", function(uid)
    table.insert(sendQueue, uart.read(uid, 1460))
    sys.timerStart(sys.publish, uartimeout, recvReady)
end)
local count = 0
uart.on(1, "sent", function()
    sys.publish("done")
    count = count + 1
    log.info("send done", count)
end)
-- 向串口发送收到的字符串
sys.subscribe(recvReady, function()
    local str = table.concat(sendQueue)
    log.info("uart read length:", #str, str)
    -- 串口写缓冲区最大1460
    for i = 1, #str, 1460 do
        uart.write(UART_ID, str:sub(i, i + 1460 - 1))
    end
    -- 串口的数据读完后清空缓冲区
    sendQueue = {}
end)

sys.taskInit(function()
    local str = string.rep("s", 120000)
    while true do
        for i = 1, #str, 1000 do
            uart.write(UART_ID, str:sub(i, i + 1000 - 1))
            log.info("test 100K uart data", #str:sub(i, i + 1000 - 1))
            sys.waitUntil("done")
        end
        sys.wait(10000)
    end
end)

-- for i = 0, 120000, 1000 do
--     uart.write(uartID, spiFlash.read_m(i, 1000))
-- end

sys.timerLoopStart(log.info, 1000, "测试打印的数据方法：", "test")
