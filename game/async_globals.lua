-- async_globals.lua
-- 全局函数替换模块
-- 基于 EngineAPI yieldable 函数的事件驱动适配层
-- 在事件脚本执行前安装，将阻塞函数替换为异步版本

local AsyncGlobals = {}

local AsyncMessageBox = require("async_message_box")
local MenuAsync = require("menu_async")
local TalkAsync = require("talk_async")

-- 保存原始函数
local _DrawStrBoxWaitKey
local _DrawStrBoxYesNo
local _WaitKey
local _ShowMenu
local _ShowMenu2
local _TalkEx
local _ShowScreen
local _libDelay

-- 替换的 DrawStrBoxWaitKey
function AsyncGlobals.DrawStrBoxWaitKey_Async(s, color, size)
    if EngineAPI.coroutine.isRunning() then
        return AsyncMessageBox.ShowMessageCoroutine(-1, -1, s, color or C_WHITE, size or CC.DefaultFont)
    else
        return _DrawStrBoxWaitKey(s, color, size)
    end
end

-- 替换的 DrawStrBoxYesNo
function AsyncGlobals.DrawStrBoxYesNo_Async(x, y, str, color, size)
    if EngineAPI.coroutine.isRunning() then
        return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, str, color or C_WHITE, size or CC.DefaultFont)
    else
        return _DrawStrBoxYesNo(x, y, str, color, size)
    end
end

-- 替换的 WaitKey
function AsyncGlobals.WaitKey_Async()
    if EngineAPI.coroutine.isRunning() then
        return EngineAPI.input.waitForKey()
    else
        return _WaitKey()
    end
end

-- 替换的 ShowMenu
function AsyncGlobals.ShowMenu_Async(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    if EngineAPI.coroutine.isRunning() then
        return MenuAsync.ShowMenuCoroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    else
        return _ShowMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    end
end

-- 替换的 ShowMenu2
function AsyncGlobals.ShowMenu2_Async(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    if EngineAPI.coroutine.isRunning() then
        return MenuAsync.ShowMenu2Coroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    else
        return _ShowMenu2(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    end
end

-- 替换的 TalkEx
function AsyncGlobals.TalkEx_Async(s, headid, flag)
    if EngineAPI.coroutine.isRunning() then
        return TalkAsync.TalkExCoroutine(s, headid, flag)
    else
        return _TalkEx(s, headid, flag)
    end
end

-- 替换的 lib.Delay
function AsyncGlobals.lib_Delay_Async(millis)
    if EngineAPI.coroutine.isRunning() then
        return EngineAPI.time.sleep(millis)
    else
        return _libDelay(millis)
    end
end

-- 替换的 ShowScreen
function AsyncGlobals.ShowScreen_Async(flag)
    -- 在事件驱动架构中，love.draw 每帧自动调用
end

-- 安装替换
function AsyncGlobals.install()
    _DrawStrBoxWaitKey = _G.DrawStrBoxWaitKey
    _DrawStrBoxYesNo = _G.DrawStrBoxYesNo
    _WaitKey = _G.WaitKey
    _ShowMenu = _G.ShowMenu
    _ShowMenu2 = _G.ShowMenu2
    _TalkEx = _G.TalkEx
    _ShowScreen = _G.ShowScreen
    _libDelay = lib and lib.Delay

    _G.DrawStrBoxWaitKey = AsyncGlobals.DrawStrBoxWaitKey_Async
    _G.DrawStrBoxYesNo = AsyncGlobals.DrawStrBoxYesNo_Async
    _G.WaitKey = AsyncGlobals.WaitKey_Async
    _G.ShowMenu = AsyncGlobals.ShowMenu_Async
    _G.ShowMenu2 = AsyncGlobals.ShowMenu2_Async
    _G.TalkEx = AsyncGlobals.TalkEx_Async
    _G.ShowScreen = AsyncGlobals.ShowScreen_Async

    if lib then
        lib.Delay = AsyncGlobals.lib_Delay_Async
    end

    local ItemAsync = require("item_async")
    if _G.SelectThing then
        _G.SelectThing = function() return ItemAsync.SelectThingAsync() end
    end
    if _G.UseThing then
        _G.UseThing = function(thingId)
            local success = ItemAsync.UseThingAsync(thingId)
            return success and 1 or 0
        end
    end
end

-- 卸载替换
function AsyncGlobals.uninstall()
    _G.DrawStrBoxWaitKey = _DrawStrBoxWaitKey
    _G.DrawStrBoxYesNo = _DrawStrBoxYesNo
    _G.WaitKey = _WaitKey
    _G.ShowMenu = _ShowMenu
    _G.ShowMenu2 = _ShowMenu2
    _G.TalkEx = _TalkEx
    _G.ShowScreen = _ShowScreen

    if lib and _libDelay then
        lib.Delay = _libDelay
    end
end

return AsyncGlobals