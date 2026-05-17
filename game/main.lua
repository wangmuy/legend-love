-- 金庸群侠传 Love2D 完全事件驱动架构主入口
-- 重构后的标准Love2D回调实现

-- 全局模块引用
local EventBridge = require("framework.event_bridge")
local MenuAsync = require("framework.menu_async")
local JYMainAdapter = require("framework.jymain_adapter")

-- 注册 Love2D 按键回调（全局函数形式，Love2D 要求回调在顶层定义）
local onKeyPressed, onKeyReleased = EventBridge.getKeyHandlers()

function love.keypressed(key, scancode, isrepeat)
    onKeyPressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    onKeyReleased(key, scancode)
end

function love.load()
    -- 加载配置
    require "framework.config"
    Byte = require "framework.lib_Byte"
    require "engine-love2d.lib_love"  -- 保持初始化（加载 jyconst.lua、设置 keymap 等）
    lib = require "engine-love2d.engine_love2d"  -- EngineAPI 接口，覆盖 lib 全局变量
    lib.init()  -- Love2D 引擎初始化（图形设置、随机种子等）
    
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
