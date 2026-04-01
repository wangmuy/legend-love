-- async_message_box.lua
-- 异步消息框模块
-- 提供协程版本的消息框和确认框函数
-- 用于替换阻塞的 DrawStrBoxWaitKey 和 DrawStrBoxYesNo

local AsyncMessageBox = {}

local AsyncDialog = require("async_dialog")
local CoroutineScheduler = require("coroutine_scheduler")

-- 显示消息框并等待按键（协程版本）
-- 替代 DrawStrBoxWaitKey
-- @param x: x坐标，-1 表示居中
-- @param y: y坐标，-1 表示居中
-- @param message: 显示的消息
-- @param color: 消息颜色
-- @param size: 字体大小
-- @return: 无返回值
function AsyncMessageBox.ShowMessageCoroutine(x, y, message, color, size)
    local options = {
        x = x,
        y = y,
        color = color,
        size = size,
    }
    return AsyncDialog.getInstance():showMessageCoroutine(message, options)
end

-- 显示确认框并等待选择（协程版本）
-- 替代 DrawStrBoxYesNo
-- @param x: x坐标，-1 表示居中
-- @param y: y坐标，-1 表示居中
-- @param message: 显示的消息
-- @param color: 消息颜色
-- @param size: 字体大小
-- @return: boolean (true=是，false=否)
function AsyncMessageBox.ShowYesNoCoroutine(x, y, message, color, size)
    local options = {
        x = x,
        y = y,
        color = color,
        size = size,
    }
    return AsyncDialog.getInstance():showYesNoCoroutine(message, options)
end

-- 别名，保持与原函数命名相似
AsyncMessageBox.DrawStrBoxWaitKeyCoroutine = AsyncMessageBox.ShowMessageCoroutine
AsyncMessageBox.DrawStrBoxYesNoCoroutine = AsyncMessageBox.ShowYesNoCoroutine

return AsyncMessageBox