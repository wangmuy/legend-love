-- async_globals.lua
-- 全局函数替换模块
-- 替换全局的阻塞函数，在协程中自动使用异步版本
-- 在事件脚本执行前加载此模块

local AsyncGlobals = {}

local CoroutineScheduler = require("coroutine_scheduler")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local MenuAsync = require("menu_async")
local TalkAsync = require("talk_async")

-- 保存原始函数
local _DrawStrBoxWaitKey = DrawStrBoxWaitKey
local _DrawStrBoxYesNo = DrawStrBoxYesNo
local _WaitKey = WaitKey
local _ShowMenu = ShowMenu
local _ShowMenu2 = ShowMenu2
local _TalkEx = TalkEx

-- 检查是否在协程中
local function isInCoroutine()
    local co = coroutine.running()
    return co ~= nil
end

-- 替换的 DrawStrBoxWaitKey
function AsyncGlobals.DrawStrBoxWaitKey_Async(s, color, size)
    if isInCoroutine() then
        return AsyncMessageBox.ShowMessageCoroutine(-1, -1, s, color or C_WHITE, size or CC.DefaultFont)
    else
        return _DrawStrBoxWaitKey(s, color, size)
    end
end

-- 替换的 DrawStrBoxYesNo
function AsyncGlobals.DrawStrBoxYesNo_Async(x, y, str, color, size)
    if isInCoroutine() then
        return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, str, color or C_WHITE, size or CC.DefaultFont)
    else
        return _DrawStrBoxYesNo(x, y, str, color, size)
    end
end

-- 替换的 WaitKey
function AsyncGlobals.WaitKey_Async()
    if isInCoroutine() then
        return InputAsync.WaitKeyCoroutine()
    else
        return _WaitKey()
    end
end

-- 替换的 ShowMenu
function AsyncGlobals.ShowMenu_Async(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    if isInCoroutine() then
        return MenuAsync.ShowMenuCoroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    else
        return _ShowMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    end
end

-- 替换的 ShowMenu2
function AsyncGlobals.ShowMenu2_Async(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    if isInCoroutine() then
        return MenuAsync.ShowMenu2Coroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    else
        return _ShowMenu2(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    end
end

-- 替换的 TalkEx
function AsyncGlobals.TalkEx_Async(s, headid, flag)
    if isInCoroutine() then
        return TalkAsync.TalkExCoroutine(s, headid, flag)
    else
        return _TalkEx(s, headid, flag)
    end
end

-- 安装替换
function AsyncGlobals.install()
    -- 替换全局函数
    _G.DrawStrBoxWaitKey = AsyncGlobals.DrawStrBoxWaitKey_Async
    _G.DrawStrBoxYesNo = AsyncGlobals.DrawStrBoxYesNo_Async
    _G.WaitKey = AsyncGlobals.WaitKey_Async
    _G.ShowMenu = AsyncGlobals.ShowMenu_Async
    _G.ShowMenu2 = AsyncGlobals.ShowMenu2_Async
    _G.TalkEx = AsyncGlobals.TalkEx_Async
end

-- 卸载替换
function AsyncGlobals.uninstall()
    _G.DrawStrBoxWaitKey = _DrawStrBoxWaitKey
    _G.DrawStrBoxYesNo = _DrawStrBoxYesNo
    _G.WaitKey = _WaitKey
    _G.ShowMenu = _ShowMenu
    _G.ShowMenu2 = _ShowMenu2
    _G.TalkEx = _TalkEx
end

return AsyncGlobals