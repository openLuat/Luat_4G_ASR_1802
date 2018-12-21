--- 模块功能：ADC功能测试.
-- ADC测量精度(10bit，电压测量范围为0到1.85V，分辨率为1850/1024=1.8MV，测量精度误差为20MV)
-- 每隔1s读取一次ADC值
-- @author openLuat
-- @module adc.testAdc
-- @license MIT
-- @copyright openLuat
-- @release 2018.12.19

module(...,package.seeall)

--- ADC读取测试
-- @return 无
-- @usage read()
local function read()
    --ADC1接口用来读取电压
    local ADC_ID = 1
    -- 读取adc
    -- adcval为number类型，表示adc的原始值，无效值为0xFFFF
    -- voltval为number类型，表示转换后的电压值，单位为毫伏，无效值为0xFFFF；adc.read接口返回的voltval放大了3倍，所以需要除以3还原成原始电压

    -- adc1读取量程为0-1400mV

    local adcval,voltval = adc.read(ADC_ID)
    log.info("testAdc1.read",adcval,(voltval-(voltval%3))/3,voltval)
end

--- ADC读取测试
-- @return 无
-- @usage read()
local function read0()
    --ADC0接口用来读取电压
    local ADC_ID = 0
    -- 读取adc
    -- adcval为number类型，表示adc的原始值，无效值为0xFFFF
    -- voltval为number类型，表示转换后的电压值，单位为毫伏，无效值为0xFFFF；adc.read接口返回的voltval放大了3倍，所以需要除以3还原成原始电压

    -- adc0的值经过了电阻分压，输入模块的端口为BAT_ADC_IN，如下图：
    --
    -- BAT_ADC_IN ----R1(100K)------+------------------ADC0
    --                              |
    --                              |
    --                           R2(47K)
    --                              |
    --                              |
    --                             GND
    --
    -- 依据公式：Vadc0 = Vbat x R2/(R1+R2)
    -- Vbat = Vadc0/(R2/(R1+R2)) = Vadc0*(R1+R2)/R2 ≈ Vadc0 * 3127 / 1000

    local adcval,voltval = adc.read(ADC_ID)
    log.info("testAdc0.read",adcval,(voltval-(voltval%3))/3,voltval)
    -- 输出计算得出的原始电压值
    log.info("testAdc0.Vbat",voltval/3 * 3127 / 1000)
end

-- 开启对应的adc通道
adc.open(0)
adc.open(1)

-- 定时每秒读取adc值
sys.timerLoopStart(read,1000)
sys.timerLoopStart(read0,1000)
