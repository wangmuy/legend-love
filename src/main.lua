-- 金庸群侠传 Love2D 完全事件驱动架构主入口
-- 重构后的标准Love2D回调实现

-- 全局模块引用
local EventBridge = require("event_bridge")
local MenuAsync = require("menu_async")
local JYMainAdapter = require("jymain_adapter")

function love.load()
    -- 使用 regular alpha 模式（非预乘）
    if love.graphics then
        love.graphics.setBlendMode("alpha")
        love.graphics.setDefaultFilter("nearest", "nearest")
        love.graphics.setBackgroundColor(0, 0, 0, 1)
    end
    
    math.randomseed(os.time())
    math.random()
    
    -- 加载配置
    require "config"
    Byte = require "lib_Byte"
    lib = require "lib_love"
    
    -- 加载事件桥接器并初始化
    EventBridge.getInstance():init()
    
    -- 加载游戏主逻辑
    require(CONFIG.ScriptPath .. "jymain")
    
    -- 初始化游戏（事件驱动版本）
    JYMainAdapter.init()
end

function love.update(dt)
    -- 更新游戏适配器
    JYMainAdapter.update(dt)
    
    -- 通过事件桥接器更新游戏逻辑
    EventBridge.getInstance():update(dt)
    
    -- 更新异步菜单
    MenuAsync.update(dt)
end

function love.draw()
    -- 调试：记录draw被调用
    if lib and lib.Debug then
        lib.Debug("love.draw called")
    end
    
    -- 设置标志，表示现在在 love.draw() 中
    if lib and lib.SetDrawLoopFlag then
        lib.SetDrawLoopFlag(true)
    end
    
    -- 通过事件桥接器渲染游戏
    EventBridge.getInstance():draw()
    
    -- 渲染异步菜单
    MenuAsync.draw()
    
    -- 清除标志
    if lib and lib.SetDrawLoopFlag then
        lib.SetDrawLoopFlag(false)
    end
end

-- 按键事件由event_bridge在init()中注册
-- 这里不需要定义love.keypressed/love.keyreleased

-- 测试：直接定义love.keypressed来调试按键问题
function love.keypressed(key, scancode, isrepeat)
    if lib and lib.Debug then
        lib.Debug(string.format("love.keypressed: key=%s, scancode=%s", tostring(key), tostring(scancode)))
    end
end

function love.quit()
    -- 清理资源
    if EventBridge then
        EventBridge.getInstance():reset()
    end
    if JYMainAdapter then
        JYMainAdapter.reset()
    end
    return false
end
