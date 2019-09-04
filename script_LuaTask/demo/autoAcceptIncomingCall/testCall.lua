--- 模块功能：来电自动接听，用于天线测试.
-- @author openLuat
-- @module call.testCall
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.20

module(...,package.seeall)

ril.regUrc("RING", function()    
    ril.request("ATA")
end)
