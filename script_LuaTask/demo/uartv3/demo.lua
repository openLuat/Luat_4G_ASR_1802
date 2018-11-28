--- 模块功能：串口功能测试(TASK版)
-- @author openLuat
-- @module uart.testUartTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.10.20
require "utils"
require "pm"
require "pins"
module(..., package.seeall)


-------------------------------------------- 配置串口 --------------------------------------------
-- 串口ID,串口读缓冲区
local UART_ID, sendQueue, writeBuff, writeBusy = 1, {}, {{}, {}}, false
-- 串口超时，串口准备好后发布的消息
local uartimeout, recvReady = 25, "UART_RECV_ID"
--保持系统处于唤醒状态，不会休眠
pm.wake("mcuart")
uart.setup(UART_ID, 115200, 8, uart.PAR_NONE, uart.STOP_1, nil, 1)
uart.on(UART_ID, "receive", function(uid)
    table.insert(sendQueue, uart.read(uid, 8192))
    sys.timerStart(sys.publish, uartimeout, recvReady)
end)
uart.on(UART_ID, "sent", function()
    if #writeBuff[1] == 0 then
        writeBusy = false
        sys.publish("done")
        log.info("uart 1 send done")
    else
        writeBusy = true
        uart.write(UART_ID, table.remove(writeBuff[1], 1))
        log.info("uart 1 send ing...")
    end
end)
function write(uid, str)
    for i = 1, #str, 8192 do
        table.insert(writeBuff[1], str:sub(i, i + 8192 - 1))
    end
    log.info("串口缓冲队列的长度:", writeBusy, #table.concat(writeBuff[1]))
    if not writeBusy then
        writeBusy = true
        uart.write(uid, table.remove(writeBuff[1], 1))
    end
end

-- 向串口发送收到的字符串
sys.subscribe(recvReady, function()
    local str = table.concat(sendQueue)
    -- 串口的数据读完后清空缓冲区
    sendQueue = {}
    log.info("uart read length:", #str)
    write(UART_ID, str)
end)
