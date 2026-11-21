-- 金庸群侠传 Love2D 完全事件驱动架构主入口
-- 重构后的标准Love2D回调实现

-- 全局模块引用
local EventBridge = require("framework.event_bridge")
local MenuAsync = require("framework.menu_async")
local JYMainAdapter = require("framework.jymain_adapter")

-- 注册 Love2D 按键回调
function love.keypressed(key, scancode, isrepeat)
    local InputManager = require("framework.input_manager")
    InputManager.getInstance():onKeyPressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    local InputManager = require("framework.input_manager")
    InputManager.getInstance():onKeyReleased(key, scancode)
end

-- 鼠标回调（REQ-MS2-1 / REQ-MS2-2）
--
-- 只负责「入队」，不做任何业务判断：
--   * 业务条件（鼠标开关、状态、阻塞输入）在 jymain_adapter.pollMouse 里判断
--   * 直接处理会有「按下即触发、按住重复触发」的问题（鼠标按下是状态不是事件）
--
-- 开关关闭时**不入队**：省掉每帧的无用消费，也让「关闭即彻底无反应」更明确。
function love.mousepressed(x, y, button, istouch, presses)
    local ok, MouseMenu = pcall(require, "framework.mouse_menu")
    if ok and MouseMenu and not MouseMenu.isEnabled() then
        return
    end
    local InputManager = require("framework.input_manager")
    InputManager.enqueueMouseEvent({
        type = "pressed", x = x, y = y, button = button,
    })
end

function love.mousereleased(x, y, button, istouch, presses)
    local ok, MouseMenu = pcall(require, "framework.mouse_menu")
    if ok and MouseMenu and not MouseMenu.isEnabled() then
        return
    end
    local InputManager = require("framework.input_manager")
    InputManager.enqueueMouseEvent({
        type = "released", x = x, y = y, button = button,
    })
end


-- ---------------------------------------------------------------------------
-- 截图 / 错误捕获（仅调试用）
-- ---------------------------------------------------------------------------
--
-- **为什么需要这一段**：`lovec.exe` 无控制台，`print` 全丢。
-- 想验证真实游戏画面，唯一方式是 `love.graphics.captureScreenshot` 存 PNG。
--
-- **为什么用文件级 local 而不是 `_G.xxx`**：
--   `JYMainAdapter.initCoroutine` 会 `setmetatable(_G, {__newindex=error})`，
--   之后往 _G 写任何新名字都抛 "attempt read write to undeclared variable"。
--   上一轮截图钩子写了 `_G.__shotFrames` → draw 抛错 → 进错误屏 →
--   **love.draw 再没被调用过**，我据此错误地判断"draw 从未执行"。
--
-- 用法：`lovec game --shot=boot --frame=180`
--   --shot=<名字>  截图文件名（不含 .png）
--   --frame=<N>    第 N 帧截图（默认 120）
local _SHOT_MODE, _SHOT_NAME, _SHOT_FRAME = false, "shot", 120
local _shotFrameCount = 0
-- 自动进战斗（--battle=<warid>）：截图模式用来验证战斗画面。
-- 走 LoadRecord(0) + WarMainCoroutine，跳过"新游戏"的属性选择菜单
-- （那个菜单要玩家按键，无头环境过不去）。
local _AUTO_BATTLE = nil
-- 自动按键脚本（--keys=return,return,down,down,...）：截图模式推进战斗流程。
--
-- **值必须是按键名字（字符串），不是 keycode**：
--   `InputManager:onKeyPressed(key, ...)` 用 `baseKeyMap[key]` 查表，
--   而 baseKeyMap 的键是 "return" / "space" / "escape" / "up" / "down" /
--   "left" / "right" 这些**字符串**。传数字 13 会查不到 → 直接 return，
--   **事件根本不进队列**（我第一版就踩了这个，所有注入都是空操作）。
--
-- 可用的名字：return / space / escape / up / down / left / right
local _AUTO_KEYS = nil
local _autoKeyTick = 0

-- 错误捕获：把真实错误写进文件（否则只剩一个看不见的错误屏）
function love.errorhandler(msg)
    local trace = debug.traceback(tostring(msg), 2)
    pcall(function()
        love.filesystem.write("__crash.txt", trace)
    end)
    return function() end
end

function love.load()
    for _, a in ipairs(rawget(_G, "arg") or {}) do
        if type(a) == "string" then
            -- **用 %S 而不是 %w**：%w 只匹配字母数字，`--shot=c_battle`
            -- 会被截成 `c` 存成 c.png（实测踩过）。%S 匹配直到空格/参数结束。
            local shot = a:match("^%-%-shot=([^%s]+)")
            if shot then _SHOT_MODE = true; _SHOT_NAME = shot end
            local fr = a:match("^%-%-frame=(%d+)")
            if fr then _SHOT_FRAME = tonumber(fr) end
            local bat = a:match("^%-%-battle=(%d+)")
            if bat then _AUTO_BATTLE = tonumber(bat) end
            local ks = a:match("^%-%-keys=([%w_,]+)")
            if ks then
                _AUTO_KEYS = {}
                for piece in ks:gmatch("[%w_]+") do
                    _AUTO_KEYS[#_AUTO_KEYS + 1] = piece
                end
            end
        end
    end

    -- 加载配置
    require "framework.config"
    Byte = require "framework.lib_Byte"
    require "engine-love2d.lib_love"  -- 保持初始化（加载 jyconst.lua、设置 keymap 等）
    -- EngineAPI 接口。**不再覆盖全局 `lib`**：`_G.lib` 兼容层已由
    -- port-compat-layer-removal 移除，入口程序与其他调用方一律走 EngineAPI。
    local engineAPI = require "engine-love2d.engine_love2d"
    engineAPI.init()  -- Love2D 引擎初始化（图形设置、随机种子等）
    
    -- 加载事件桥接器并初始化
    EventBridge.getInstance():init()

    -- 加载游戏主逻辑
    require(CONFIG.ScriptPath .. "jymain")
    
    -- 初始化游戏（事件驱动版本）
    JYMainAdapter.init()

    -- 自动进战斗（--battle=<warid>，仅调试用）
    if _AUTO_BATTLE then
        local scheduler = require("framework.coroutine_scheduler").getInstance()
        local wa = require("framework.war_async")

        scheduler:create(function()
            -- LoadRecord(0) 是 setNewGame 用的基础存档，提供 JY.Person/CC 数据
            local okLoad = rawget(_G, "LoadRecord") and LoadRecord(0)
            if not okLoad then
                pcall(function()
                    love.filesystem.write("__battle_fail.txt", "LoadRecord(0) failed")
                end)
                return
            end
            local prog = {"LoadRecord ok"}
            pcall(function()
                love.filesystem.write("__battle_start.txt",
                    "battle=" .. tostring(_AUTO_BATTLE) .. " load=" .. tostring(okLoad))
            end)
            -- 分段推进，每步写进度（否则不知道卡在哪）
            local function step(name, fn)
                pcall(function()
                    love.filesystem.write("__battle_progress.txt", table.concat(prog, " > "))
                end)
                local ok, err = pcall(fn)
                prog[#prog + 1] = name .. (ok and " ok" or (" FAIL:" .. tostring(err)))
                return ok
            end
            step("WarLoad",    function() WarLoad(_AUTO_BATTLE) end)
            step("WarSelectTeam",  function() WarSelectTeam() end)
            step("WarSelectEnemy", function() WarSelectEnemy() end)
            pcall(function()
                love.filesystem.write("__battle_steps.txt", table.concat(prog, "\n"))
            end)
            local okB, errB = pcall(wa.WarMainCoroutine, _AUTO_BATTLE, 1)
            pcall(function()
                love.filesystem.write("__battle_end.txt",
                    "ok=" .. tostring(okB) .. " err=" .. tostring(errB))
            end)
        end, "auto_battle")
    end
end

function love.update(dt)
    -- 自动按键（--keys=...，仅调试用）：每 20 帧注入一个按键事件，
    -- 用来推进"等键"的战斗流程（否则协程一直挂在 waitKey 上）。
    if _AUTO_KEYS and #_AUTO_KEYS > 0 then
        _autoKeyTick = _autoKeyTick + 1
        if _autoKeyTick >= 20 then
            _autoKeyTick = 0
            local k = table.remove(_AUTO_KEYS, 1)
            pcall(function()
                local IM = require("framework.input_manager").getInstance()
                IM:onKeyPressed(k, nil, false)
                IM:onKeyReleased(k, nil)
            end)
        end
    end

    -- 更新游戏适配器
    JYMainAdapter.update(dt)
    
    -- 通过事件桥接器更新游戏逻辑
    EventBridge.getInstance():update(dt)
    
    -- 更新异步菜单
    MenuAsync.update(dt)
end

function love.draw()
    -- 设置标志，表示现在在 love.draw() 中（走契约，不再摸全局 lib）
    if EngineAPI and EngineAPI.render and EngineAPI.render.setDrawLoopFlag then
        EngineAPI.render.setDrawLoopFlag(true)
    end
    
    -- 通过事件桥接器渲染游戏
    EventBridge.getInstance():draw()
    
    -- 渲染异步菜单
    MenuAsync.draw()
    
    -- 清除标志
    if EngineAPI and EngineAPI.render and EngineAPI.render.setDrawLoopFlag then
        EngineAPI.render.setDrawLoopFlag(false)
    end

    -- 截图（调试用）
    if _SHOT_MODE then
        _shotFrameCount = _shotFrameCount + 1
        if _shotFrameCount == _SHOT_FRAME then
            love.graphics.captureScreenshot(function(imgdata)
                imgdata:encode("png", _SHOT_NAME .. ".png")
                pcall(function()
                    love.filesystem.write("__shot_done.txt",
                        "saved " .. _SHOT_NAME .. ".png @ frame " .. tostring(_SHOT_FRAME))
                end)
                love.event.quit()
            end)
        end
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
