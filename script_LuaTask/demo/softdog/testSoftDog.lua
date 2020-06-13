--- 模块功能：软狗功能测试
-- @author openLuat
-- @module testSoftDog
-- @license MIT
-- @copyright openLuat
-- @release 2019.11.26

module(...,package.seeall)

--[[
函数名：eatSoftDog
功能  ：喂狗
参数  ：无
返回值：无
]]
function eatSoftDog()
    print("eatSoftDog test")
    rtos.eatSoftDog()
end

--[[
函数名：closeSoftDog
功能  ：关闭软狗
参数  ：无
返回值：无
]]
function closeSoftDog()
    print("closeSoftDog test")
    sys.timerStop(eatSoftDog)
    rtos.closeSoftDog()
end

--打开并设置软狗超时时间单位MS,超过设置时间没去喂狗，重启模块
rtos.openSoftDog(60*1000)

--定时喂狗
sys.timerLoopStart(eatSoftDog,50*1000)

--关闭软狗
sys.timerStart(closeSoftDog,180*1000)

--打印版本号
sys.timerLoopStart(log.info,2000,rtos.get_version(),_G.VERSION)
