--- 模块功能：SSD 1306驱动芯片 I2C屏幕显示测试
-- @author openLuat
-- @module ui.mono_i2c_ssd1306
-- @license MIT
-- @copyright openLuat
-- @release 2018.07.03

module(..., package.seeall)

local i2cid = 0

local i2cslaveaddr = 0x3c
--注意：此处的i2cslaveaddr是7bit地址
--如果i2c外设手册中给的是8bit地址，需要把8bit地址右移1位，赋值给i2cslaveaddr变量
--如果i2c外设手册中给的是7bit地址，直接把7bit地址赋值给i2cslaveaddr变量即可
--发起一次读写操作时，启动信号后的第一个字节是命令字节
--命令字节的bit0表示读写位，0表示写，1表示读
--命令字节的bit7-bit1,7个bit表示外设地址
--i2c底层驱动在读操作时，用 (i2cslaveaddr << 1) | 0x01 生成命令字节
--i2c底层驱动在写操作时，用 (i2cslaveaddr << 1) | 0x00 生成命令字节

--向屏幕发送命令字
local function lcd_write_cmd(val)
    --向从设备的寄存器地址0x00中写1字节的数据val
    i2c.write(i2cid,0x00,val)

    --该代码与下面的代码等价
    --向从设备i2cslaveaddr发送寄存器地址0x00与数据val
    --i2c.send(i2cid,i2cslaveaddr,{0x00,val})
end

--向屏幕发送数据
local function lcd_write_data(val)
    --向从设备的寄存器地址0x40中写1字节的数据val
    i2c.write(i2cid,0x40,val)

    --该代码与下面的代码等价
    --向从设备i2cslaveaddr发送寄存器地址0x40与数据val
    --i2c.send(i2cid,i2cslaveaddr,{0x40,val})
end


--[[
函数名：i2cShow
功能  ：打开i2c，并设置屏幕显示内容
参数  ：无
返回值：无
说明  : 此函数演示setup、send和recv接口的使用方式
]]
local function i2cShow()

    if i2c.setup(i2cid,i2c.SLOW,i2cslaveaddr) ~= i2c.SLOW then
        print("testI2c.init fail")
        return
    end

    local cmd = {0xAE, 0X00, 0x10, 0x40, 0x81, 0x7f, 0xA1, 0XA6, 0XA8, 63, 0XC8, 0XD3, 0X00, 0XD5, 0X80, 0XDA, 0X12, 0X8D, 0X14, 0X20, 0X01, 0XAF}
    local i

    lcd_write_cmd(0xAF)
    lcd_write_cmd(0xAF)
    lcd_write_cmd(0xAF)
    lcd_write_cmd(0xAF)
    log.info("zwb_Lua lcd_write_cmd cmd ", 0xAF)
    for i=1,#cmd do
        log.info("zwb_Lua lcd_write_cmd cmd1 ", lcd_write_cmd(cmd[i]))
    end

    local cmd2 =  {0X21, 0X00, 0X7F}

    for i=1,3 do
        log.info("zwb_Lua lcd_write_cmd cmd2 ", lcd_write_cmd(cmd2[i]))
    end

    for i=1,128*4 do
        lcd_write_data(0)
        lcd_write_data(0)
    end

    lcd_write_cmd(0x22)
    lcd_write_cmd(2)
    lcd_write_cmd(3)

    lcd_write_cmd(0x21)
    lcd_write_cmd(43)
    lcd_write_cmd(63)

    local cmd_G = {0x0, 0x0,0xf0, 0x7,0xf8, 0xf,0x8, 0x8,0x98, 0xf,0x90, 0x7,0x0, 0x0}
    local cmd_O = {0x0, 0x0,0xf0, 0x7,0xf8, 0xf,0x8, 0x8,0xf8, 0xf,0xf0, 0x7,0x0, 0x0}
    local cmd_  = {0x0, 0x0,0x0, 0x0,0xf8, 0xd,0xf8, 0xd,0x0, 0x0,0x0, 0x0,0x0, 0x0}

    for i=1,#cmd_G do
        lcd_write_data(cmd_G[i])
    end
    for i=1,#cmd_O do
        lcd_write_data(cmd_O[i])
    end
    for i=1,#cmd_ do
        lcd_write_data(cmd_[i])
    end

    --从从设备的寄存器地址0x20中读1字节的数据，并且打印出来
    log.info("zwb_Lua 0x20 read",string.toHex(i2c.read(i2cid,0x20,1)))

    --该代码与下面的代码等价
    --向从设备i2cslaveaddr发送寄存器地址0x20
    i2c.send(i2cid,i2cslaveaddr,0x20)
    --读取从设备i2cslaveaddr寄存器内的1个字节的数据，并且打印出来
    log.info("zwb_Lua 0x20 recv",string.toHex(i2c.recv(i2cid,i2cslaveaddr,1)))
end

--显示内容
i2cShow()
