--- 模块功能：GPS功能测试(本demo是以Air720通过uart1外接Air530为例配置，注意：Air530供电要求3.3V，Air720的IO是1.8V，硬件上注意做电平转换).
-- @author openLuat
-- @module gps.testGps
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.23

module(...,package.seeall)

require"gps"
--agps功能模块只能配合Air800或者Air530使用；如果不是这两款模块，不要打开agps功能
require"agps"

local function printGps()
    if gps.isOpen() then
        local tLocation = gps.getLocation()
        local speed = gps.getSpeed()
        log.info("testGps.printGps",
            gps.isOpen(),gps.isFix(),
            tLocation.lngType,tLocation.lng,tLocation.latType,tLocation.lat,
            gps.getAltitude(),
            speed,
            gps.getCourse(),
            gps.getViewedSateCnt(),
            gps.getUsedSateCnt())
    end
end

local function test1Cb(tag)
    log.info("testGps.test1Cb",tag)
    printGps()
end

local function test2Cb(tag)
    log.info("testGps.test2Cb",tag)
    printGps()
end

local function test3Cb(tag)
    log.info("testGps.test3Cb",tag)
    printGps()
end

--测试代码开关，取值1,2
local testIdx = 1
local function test(idx)
    --第1种测试代码
    if idx==1 then
        --执行完下面三行代码后，GPS就会一直开启，永远不会关闭
        --因为gps.open(gps.DEFAULT,{tag="TEST1",cb=test1Cb})，这个开启，没有调用gps.close关闭
        gps.open(gps.DEFAULT,{tag="TEST1",cb=test1Cb})

        --10秒内，如果gps定位成功，会立即调用test2Cb，然后自动关闭这个“GPS应用”
        --10秒时间到，没有定位成功，会立即调用test2Cb，然后自动关闭这个“GPS应用”
        gps.open(gps.TIMERORSUC,{tag="TEST2",val=10,cb=test2Cb})

        --300秒时间到，会立即调用test3Cb，然后自动关闭这个“GPS应用”
        gps.open(gps.TIMER,{tag="TEST3",val=300,cb=test3Cb})
    --第2种测试代码
    elseif idx==2 then
        --执行完下面三行代码打开GPS后，5分钟之后GPS会关闭
        gps.open(gps.DEFAULT,{tag="TEST1",cb=test1Cb})
        sys.timerStart(gps.close,300000,gps.DEFAULT,{tag="TEST1"})
        gps.open(gps.TIMERORSUC,{tag="TEST2",val=10,cb=test2Cb})
        gps.open(gps.TIMER,{tag="TEST3",val=60,cb=test3Cb}) 
    end
end

--[[
函数名：nemacb
功能  ：NEMA数据的处理回调函数
参数  ：
		data：一条NEMA数据
返回值：无
]]
local function nmeaCb(nmeaItem)
    log.info("testGps.nmeaCb",nmeaItem)
end

--如果是外部控制对GPS模块的供电，调用下面的接口，根据实际情况控制GPS模块的供电开关，配置uart通信参数
--如下两部分是以Air720通过uart1外接Air530为例的配置代码
--gps.setPowerCbFnc，设置供电开关回调，实际测试时，使用的是直流电源直接给Air530供电，所有回调中没有实现任何有效代码
gps.setPowerCbFnc(
    function(staus)
        if status then
            --打开供电
        else
            --关闭供电
        end
    end
)
--gps.setPowerCbFnc，设置串口通信参数，Air530的波特率为9600
gps.setUart(1,9600,8,uart.PAR_NONE,uart.STOP_1)


--设置GPS+BD定位(此接口目前仅针对Air530或者Air800有效)
--如果不调用此接口，默认也为GPS+BD定位
--gps.setAerialMode(1,1,0,0)

--设置仅gps.lua内部处理NEMA数据
--如果不调用此接口，默认也为仅gps.lua内部处理NEMA数据
--如果gps.lua内部不处理，把NMEA数据通过回调函数cb提供给外部程序处理，参数设置为1,nmeaCb
--如果gps.lua和外部程序都处理，参数设置为2,nmeaCb
gps.setNmeaMode(2,nmeaCb)

test(testIdx)
sys.timerLoopStart(printGps,2000)
