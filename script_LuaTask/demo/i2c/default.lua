--- 模块功能：testLed
-- @module default
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.06.30
require "led"
require 'misc'
require "pins"
require "mqtt"
require "utils"
require "common"
require "lbsLoc"
require "mono_i2c_ssd1306"

module(..., package.seeall)

-- 本地存储文件
local demotype, demoext = "qrcode"

local function getlbs(result, lat, lng, addr)
    if result == 0 then
        msg.lat = lat
        msg.lng = lng
        msg.addr = common.ucs2beToUtf8(addr)
    end
end
sys.subscribe("IP_READY_IND", function()lbsLoc.request(getlbs, true, 30000, "0", "bs.openluat.com", "12412", true) end)
lbsLoc.request(getlbs, true)

-- disp.putqrcode(data, width, display_width, x, y) 显示二维码
-- @param data 从qrencode.encode返回的二维码数据
-- @param width 二维码数据的实际宽度
-- @param display_width 二维码实际显示宽度
-- @param x 二维码显示起始坐标x
-- @param y 二维码显示起始坐标y
--- 二维码显示函数
local function appQRCode(str)
    if str == nil or str == "" then str = 'http://www.openluat.com' end
    -- qrencode.encode(string) 创建二维码信息
    -- @param string 二维码字符串
    -- @return width 生成的二维码信息宽度
    -- @return data 生成的二维码数据
    -- @usage local width, data = qrencode.encode("http://www.openluat.com")
    local width, data = qrencode.encode(str)
    --LCD分辨率的宽度和高度(单位是像素)
    local WIDTH, HEIGHT = disp.getlcdinfo()
    local displayWidth = width * ((WIDTH > HEIGHT and HEIGHT or WIDTH) / width)
    log.info("displayWidth value is:", displayWidth)
    local x, y = (WIDTH - displayWidth) / 2, (HEIGHT - displayWidth) / 2
    disp.clear()
    -- disp.drawrect(x - 1, y - 1, x + displayWidth + 1, y + displayWidth + 1, 0xffff)
    disp.putqrcode(data, width, displayWidth, x, y)
    disp.update()
end

-- 获取字符串显示的起始X坐标
local function getxpos(width, str)
    return (width - string.len(str) * 8) / 2
end

function clockDemo(...)
    local WIDTH, HEIGHT = disp.getlcdinfo()
    disp.clear()
    local c = misc.getClock()
    local date = string.format('%04d年%02d月%02d日', c.year, c.month, c.day)
    local time = string.format('%02d:%02d:%02d 周%d', c.hour, c.min, c.sec, misc.getWeek())
    disp.puttext(common.utf8ToGb2312(date), getxpos(WIDTH, common.utf8ToGb2312(date)), 4)
    disp.puttext(common.utf8ToGb2312(time), getxpos(WIDTH, common.utf8ToGb2312(time)), 24)
    disp.puttext(common.utf8ToGb2312("LuatBoard-Air202"), getxpos(WIDTH, common.utf8ToGb2312("LuatBoard-Air202")), 44)
    --刷新LCD显示缓冲区到LCD屏幕上
    disp.update()
end

sys.taskInit(function()
    mono_i2c_ssd1306.init(0xFFFF)
    while true do
        log.info("-----二维码Demo代码正在运行-------")
        appQRCode("http://www.openluat.com")
        sys.wait(5000)
        clockDemo()
        sys.wait(1000)
    end
end)
