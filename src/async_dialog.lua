-- async_dialog.lua
-- 异步对话框管理器
-- 支持非阻塞的对话框显示和交互

local AsyncDialog = {}
AsyncDialog.__index = AsyncDialog

-- 对话框堆栈
local dialogStack = {}
local currentDialog = nil

-- 动画配置
local animationConfig = {
    enabled = true,
    openDuration = 0.15,   -- 打开动画持续时间
    closeDuration = 0.1,   -- 关闭动画持续时间
    fadeInOpacity = true,  -- 启用淡入效果
    scaleAnimation = true, -- 启用缩放动画
}

-- 单例实例
local instance = nil

-- 获取单例
function AsyncDialog.getInstance()
    if not instance then
        instance = setmetatable({}, AsyncDialog)
    end
    return instance
end

-- 初始化对话框管理器
function AsyncDialog:init()
    dialogStack = {}
    currentDialog = nil
end

-- 显示确认对话框（是/否）
-- @param message: 显示的消息
-- @param callback: 回调函数，参数为boolean（true=是，false=否）
-- @param options: 可选配置（x, y, width, height, color, size等）
function AsyncDialog:showYesNo(message, callback, options)
    options = options or {}
    
    -- 计算默认尺寸
    local size = options.size or CC.DefaultFont
    local ll = #message
    local width = size * ll / 2 + 2 * CC.MenuBorderPixel
    local height = size + 2 * CC.MenuBorderPixel
    
    -- 计算默认位置（居中）
    local x = options.x
    local y = options.y
    if x == -1 or x == nil then
        x = (CC.ScreenW - size / 2 * ll - 2 * CC.MenuBorderPixel) / 2
    end
    if y == -1 or y == nil then
        y = (CC.ScreenH - size - 2 * CC.MenuBorderPixel) / 2
    end
    
    -- 创建对话框数据
    local dialog = {
        type = "yesno",
        message = message,
        callback = callback,
        x = x,
        y = y,
        width = width,
        height = height,
        color = options.color or C_WHITE,
        size = size,
        result = nil,
        state = "opening",
        animationTime = 0,
        selected = 1,  -- 1=是，2=否
    }
    
    self:pushDialog(dialog)
end

-- 显示输入对话框
-- @param prompt: 提示文本
-- @param callback: 回调函数，参数为string（输入内容）或nil（取消）
-- @param options: 可选配置
function AsyncDialog:showInput(prompt, callback, options)
    options = options or {}
    
    local dialog = {
        type = "input",
        prompt = prompt,
        callback = callback,
        x = options.x or -1,
        y = options.y or -1,
        width = options.width or 400,
        height = options.height or 150,
        maxLength = options.maxLength or 20,
        input = "",
        result = nil,
        state = "opening",
        animationTime = 0,
    }
    
    self:pushDialog(dialog)
end

-- 显示选择对话框
-- @param title: 标题
-- @param items: 选项列表 {text, value}
-- @param callback: 回调函数，参数为选中项的value或nil（取消）
-- @param options: 可选配置
function AsyncDialog:showSelect(title, items, callback, options)
    options = options or {}
    
    local dialog = {
        type = "select",
        title = title,
        items = items,
        callback = callback,
        x = options.x or -1,
        y = options.y or -1,
        width = options.width or 300,
        height = options.height or (#items * 30 + 60),
        selected = 1,
        scroll = 0,
        result = nil,
        state = "opening",
        animationTime = 0,
    }
    
    self:pushDialog(dialog)
end

-- 推入对话框堆栈
function AsyncDialog:pushDialog(dialog)
    -- 暂停当前对话框
    if currentDialog then
        currentDialog.paused = true
    end
    
    -- 推入新对话框
    table.insert(dialogStack, dialog)
    currentDialog = dialog
    
    -- 播放打开动画
    if animationConfig.enabled then
        dialog.state = "opening"
        dialog.animationTime = 0
    else
        dialog.state = "open"
    end
end

-- 关闭当前对话框
-- @param result: 返回结果
function AsyncDialog:closeDialog(result)
    if not currentDialog then
        return
    end
    
    currentDialog.result = result
    
    -- 播放关闭动画
    if animationConfig.enabled then
        currentDialog.state = "closing"
        currentDialog.animationTime = 0
    else
        self:doCloseDialog()
    end
end

-- 执行关闭
function AsyncDialog:doCloseDialog()
    if not currentDialog then
        return
    end
    
    -- 调用回调
    if currentDialog.callback then
        currentDialog.callback(currentDialog.result)
    end
    
    -- 移除当前对话框
    table.remove(dialogStack)
    
    -- 恢复上一个对话框
    currentDialog = dialogStack[#dialogStack]
    if currentDialog then
        currentDialog.paused = false
    end
end

-- 更新对话框
-- @param dt: delta time
function AsyncDialog:update(dt)
    if not currentDialog or currentDialog.paused then
        return
    end
    
    -- 处理动画
    if currentDialog.state == "opening" then
        currentDialog.animationTime = currentDialog.animationTime + dt
        if currentDialog.animationTime >= animationConfig.duration then
            currentDialog.state = "open"
            currentDialog.animationTime = animationConfig.duration
        end
    elseif currentDialog.state == "closing" then
        currentDialog.animationTime = currentDialog.animationTime + dt
        if currentDialog.animationTime >= animationConfig.duration then
            self:doCloseDialog()
            return
        end
    end
    
    -- 处理输入
    self:handleInput()
end

-- 处理输入
function AsyncDialog:handleInput()
    if not currentDialog or currentDialog.state ~= "open" then
        return
    end
    
    local key = lib.GetKey()
    if key == -1 then
        return
    end
    
    if currentDialog.type == "yesno" then
        if key == VK_ESCAPE then
            self:closeDialog(false)
        elseif key == VK_RETURN or key == VK_SPACE then
            self:closeDialog(currentDialog.selected == 1)
        elseif key == VK_LEFT or key == VK_RIGHT then
            currentDialog.selected = currentDialog.selected == 1 and 2 or 1
        end
    elseif currentDialog.type == "input" then
        if key == VK_ESCAPE then
            self:closeDialog(nil)
        elseif key == VK_RETURN then
            self:closeDialog(currentDialog.input)
        elseif key == VK_BACKSPACE then
            if #currentDialog.input > 0 then
                currentDialog.input = string.sub(currentDialog.input, 1, -2)
            end
        elseif key >= 32 and key <= 126 then
            if #currentDialog.input < currentDialog.maxLength then
                currentDialog.input = currentDialog.input .. string.char(key)
            end
        end
    elseif currentDialog.type == "select" then
        if key == VK_ESCAPE then
            self:closeDialog(nil)
        elseif key == VK_RETURN then
            local item = currentDialog.items[currentDialog.selected]
            if item then
                self:closeDialog(item.value)
            end
        elseif key == VK_UP then
            currentDialog.selected = currentDialog.selected - 1
            if currentDialog.selected < 1 then
                currentDialog.selected = #currentDialog.items
            end
        elseif key == VK_DOWN then
            currentDialog.selected = currentDialog.selected + 1
            if currentDialog.selected > #currentDialog.items then
                currentDialog.selected = 1
            end
        end
    end
end

-- 渲染对话框
function AsyncDialog:draw()
    if not currentDialog then
        return
    end
    
    -- 计算动画进度
    local progress = 1
    if currentDialog.state == "opening" then
        progress = currentDialog.animationTime / animationConfig.duration
    elseif currentDialog.state == "closing" then
        progress = 1 - (currentDialog.animationTime / animationConfig.duration)
    end
    
    -- 计算位置和大小
    local x, y, w, h
    if currentDialog.x == -1 then
        x = (CC.ScreenW - currentDialog.width) / 2
    else
        x = currentDialog.x
    end
    if currentDialog.y == -1 then
        y = (CC.ScreenH - currentDialog.height) / 2
    else
        y = currentDialog.y
    end
    w = currentDialog.width * progress
    h = currentDialog.height * progress
    x = x + (currentDialog.width - w) / 2
    y = y + (currentDialog.height - h) / 2
    
    -- 绘制对话框背景
    DrawBox(x, y, x + w, y + h, C_WHITE)
    
    -- 绘制内容
    if currentDialog.type == "yesno" then
        self:drawYesNo(currentDialog, x, y, w, h)
    elseif currentDialog.type == "input" then
        self:drawInput(currentDialog, x, y, w, h)
    elseif currentDialog.type == "select" then
        self:drawSelect(currentDialog, x, y, w, h)
    end
end

-- 绘制确认对话框
function AsyncDialog:drawYesNo(dialog, x, y, w, h)
    -- 绘制消息
    DrawString(x + 10, y + 10, dialog.message, C_WHITE, CC.DefaultFont)
    
    -- 绘制选项
    local yesColor = dialog.selected == 1 and C_RED or C_WHITE
    local noColor = dialog.selected == 2 and C_RED or C_WHITE
    DrawString(x + w/4, y + h - 30, "是", yesColor, CC.DefaultFont)
    DrawString(x + w*3/4, y + h - 30, "否", noColor, CC.DefaultFont)
end

-- 绘制输入对话框
function AsyncDialog:drawInput(dialog, x, y, w, h)
    -- 绘制提示
    DrawString(x + 10, y + 10, dialog.prompt, C_WHITE, CC.DefaultFont)
    
    -- 绘制输入框
    DrawBox(x + 10, y + 40, x + w - 10, y + 70, C_WHITE)
    DrawString(x + 15, y + 45, dialog.input, C_WHITE, CC.DefaultFont)
    
    -- 绘制光标
    local cursorX = x + 15 + #dialog.input * CC.DefaultFont / 2
    DrawString(cursorX, y + 45, "_", C_WHITE, CC.DefaultFont)
end

-- 绘制选择对话框
function AsyncDialog:drawSelect(dialog, x, y, w, h)
    -- 绘制标题
    DrawString(x + 10, y + 10, dialog.title, C_WHITE, CC.DefaultFont)
    
    -- 绘制选项
    local startY = y + 40
    for i, item in ipairs(dialog.items) do
        local color = (i == dialog.selected) and C_RED or C_WHITE
        DrawString(x + 20, startY + (i-1) * 30, item.text, color, CC.DefaultFont)
    end
end

-- 检查是否有对话框显示
function AsyncDialog:hasDialog()
    return #dialogStack > 0
end

-- 获取当前对话框
function AsyncDialog:getCurrentDialog()
    return currentDialog
end

-- 清空所有对话框
function AsyncDialog:clear()
    dialogStack = {}
    currentDialog = nil
end

-- 设置动画配置
function AsyncDialog:setAnimationConfig(config)
    animationConfig.enabled = config.enabled ~= false
    animationConfig.duration = config.duration or 0.2
end

-- 重置对话框管理器
function AsyncDialog:reset()
    self:clear()
    instance = nil
end

return AsyncDialog
