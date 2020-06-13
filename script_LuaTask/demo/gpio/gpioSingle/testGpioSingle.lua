--- 模块功能：GPIO功能测试.
-- @author openLuat
-- @module gpio.testGpioSingle
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"pins"

local level = 0
--GPIO79配置为输出，默认输出低电平，可通过setGpio79Fnc(0或者1)设置输出电平
local setGpio79Fnc = pins.setup(pio.P2_15,0)
sys.timerLoopStart(function()
    level = level==0 and 1 or 0
    setGpio79Fnc(level)
    log.info("testGpioSingle.setGpio79Fnc",level)
end,1000)

--GPIO53配置为输入，可通过getGpio53Fnc()获取输入电平
local getGpio53Fnc = pins.setup(pio.P1_21)
sys.timerLoopStart(function()
    log.info("testGpioSingle.getGpio53Fnc",getGpio53Fnc())
end,1000)
--pio.pin.setpull(pio.PULLUP,pio.P1_21)  --配置为上拉
--pio.pin.setpull(pio.PULLDOWN,pio.P1_21)  --配置为下拉
--pio.pin.setpull(pio.NOPULL,pio.P1_21)  --不配置上下拉



function gpio54IntFnc(msg)
    log.info("testGpioSingle.gpio54IntFnc",msg,getGpio54Fnc())
    --上升沿中断
    if msg==cpu.INT_GPIO_POSEDGE then
    --下降沿中断
    else
    end
end

--GPIO54配置为中断，可通过getGpio54Fnc()获取输入电平，产生中断时，自动执行gpio54IntFnc函数
getGpio54Fnc = pins.setup(pio.P1_22,gpio54IntFnc)

--[[
pmd.ldoset(x,pmd.VLDO6)
x=0时：关闭LDO
x=1时：LDO输出1.8V
x=2时：LDO输出1.9V
x=3时：LDO输出2.5V
x=4时：LDO输出2.8V
x=5时：LDO输出2.9V
x=6时：LDO输出3.1V
x=7时：LDO输出3.3V
x=8时：LDO输出1.7V
]]

