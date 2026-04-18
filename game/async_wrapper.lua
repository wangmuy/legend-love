-- async_wrapper.lua
-- 异步函数包装器
-- 提供全局可用的异步函数，用于替换阻塞调用
-- 在事件脚本中可以直接使用这些函数

local AsyncWrapper = {}

local CoroutineScheduler = require("coroutine_scheduler")
local AsyncDialog = require("async_dialog")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local MenuAsync = require("menu_async")
local TalkAsync = require("talk_async")

-- ============================================
-- 消息框函数
-- ============================================

-- 异步显示消息框
function AsyncWrapper.ShowMessage(message, color, size)
    color = color or C_WHITE
    size = size or CC.DefaultFont
    return AsyncMessageBox.ShowMessageCoroutine(-1, -1, message, color, size)
end

-- 异步显示确认框
function AsyncWrapper.ShowYesNo(message, color, size)
    color = color or C_WHITE
    size = size or CC.DefaultFont
    return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, message, color, size)
end

-- ============================================
-- 等待按键
-- ============================================

-- 异步等待按键
function AsyncWrapper.WaitKey()
    return InputAsync.WaitKeyCoroutine()
end

-- ============================================
-- 菜单函数
-- ============================================

-- 异步显示菜单
function AsyncWrapper.ShowMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    return MenuAsync.ShowMenuCoroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
end

-- 异步显示横向菜单
function AsyncWrapper.ShowMenu2(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    return MenuAsync.ShowMenu2Coroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
end

-- ============================================
-- 对话函数
-- ============================================

-- 异步对话
function AsyncWrapper.TalkEx(s, headid, flag)
    return TalkAsync.TalkExCoroutine(s, headid, flag)
end

-- 异步简单对话
function AsyncWrapper.Talk(s, personid)
    return TalkAsync.TalkCoroutine(s, personid)
end

-- ============================================
-- 延时函数
-- ============================================

-- 异步延时
function AsyncWrapper.Delay(ms)
    local scheduler = CoroutineScheduler.getInstance()
    return scheduler:waitForTime(ms / 1000)
end

-- ============================================
-- 检查是否在协程中
-- ============================================

function AsyncWrapper.IsInCoroutine()
    local co = coroutine.running()
    return co ~= nil
end

-- ============================================
-- 兼容性包装器
-- 这些函数会自动检测是否在协程中，选择同步或异步版本
-- ============================================

-- 兼容版消息框
function AsyncWrapper.DrawStrBoxWaitKey_Compat(s, color, size)
    if AsyncWrapper.IsInCoroutine() then
        return AsyncWrapper.ShowMessage(s, color, size)
    else
        -- 不在协程中，使用原版
        return DrawStrBoxWaitKey(s, color, size)
    end
end

-- 兼容版确认框
function AsyncWrapper.DrawStrBoxYesNo_Compat(x, y, str, color, size)
    if AsyncWrapper.IsInCoroutine() then
        return AsyncWrapper.ShowYesNo(str, color, size)
    else
        return DrawStrBoxYesNo(x, y, str, color, size)
    end
end

-- 兼容版等待按键
function AsyncWrapper.WaitKey_Compat()
    if AsyncWrapper.IsInCoroutine() then
        return AsyncWrapper.WaitKey()
    else
        return WaitKey()
    end
end

return AsyncWrapper