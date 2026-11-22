-- 金庸群侠传 Love2D 入口
--
-- **本文件现在只做三件事**（change: port-engine-boot）：
--   ① 把 LÖVE 的回调**翻译**成 framework/boot.lua 的 4 个入口
--      （install / update / draw / quit）
--   ② 处理截图与自动按键这两个**调试设施**（不属于生产启动路径）
--   ③ 把 LÖVE 独有的宿主能力（`love.event.quit` / 截屏）作为 runtime 传进去
--
-- 以前这里写着 147 行「装配游戏」的步骤（require config → 设 Byte →
-- require jymain → JYMainAdapter.init → ...）。那段知识已经搬进
-- `framework/boot.lua`，于是**任何**引擎的入口都只剩下面这 4 个转发。
-- 这是本文件存在的意义：证明「换引擎只需写 engine-xxx + 一个薄入口」。

local Boot = require("framework.boot")

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
-- 直接进主地图（--mmap=<x>,<y>）：截图模式用来验证**只在 GAME_MMAP 可达**的界面。
--
-- 为什么需要它（port-ui-screens-verification Task 2）：
--   存档/读档入口在主菜单的「系统」里，而「系统」在 GAME_SMAP 下被置灰
--   （**原版行为**，jymain_async.lua:47-48）。开场出生点在小场景里，
--   用 `--keys` 走位出屋子既不稳定（遇敌/门位随存档变），也无法在
--   CI 里复现。所以给一个调试入口：LoadRecord(0) → 直接把坐标改成主地图
--   坐标 → 切到 GAME_MMAP。生产路径不受影响（只有带这个参数才走）。
local _AUTO_MMAP = nil
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
            local mm = a:match("^%-%-mmap=(%d+),(%d+)")
            if mm then _AUTO_MMAP = { tonumber(a:match("=(%d+),")), tonumber(a:match(",(%d+)$")) } end
            local ks = a:match("^%-%-keys=([%w_,]+)")
            if ks then
                _AUTO_KEYS = {}
                for piece in ks:gmatch("[%w_]+") do
                    _AUTO_KEYS[#_AUTO_KEYS + 1] = piece
                end
            end
        end
    end

    -- 引擎实现（必须在这之前 require，因为它会算好 EngineAPI 的 94 个函数）
    require "engine-love2d.lib_love"   -- 保持初始化（加载 jyconst.lua、设置 keymap 等）
    require "engine-love2d.engine_love2d"

    -- **启动装配交给 framework**（change: port-engine-boot）
    --
    -- Boot.install 里做的事（顺序固定，见 framework/boot.lua 头注释）：
    --   framework.config → Byte → require_aliases → EngineAPI.init
    --   → EventBridge:init → require jymain → JYMainAdapter.init
    --
    -- runtime 里传的是**只有 LÖVE 宿主知道**的能力：
    --   quit  → love.event.quit()（Godot 是 get_tree().quit()）
    --   onError → 写进 __crash.txt（各引擎的错误上报机制都不同）
    local okBoot = Boot.install({
        quit = function()
            love.event.quit()
            return true
        end,
        onError = function(err)
            pcall(function()
                love.filesystem.write("__crash.txt",
                    debug.traceback(tostring(err), 2))
            end)
        end,
    })
    if not okBoot then
        pcall(function()
            love.filesystem.write("__boot_fail.txt", "Boot.install returned false")
        end)
    end

    -- 直接进主地图（--mmap=x,y，仅调试用）—— 必须先于 --battle 判断
    if _AUTO_MMAP then
        local scheduler = require("framework.coroutine_scheduler").getInstance()
        local EventBridge = require("framework.event_bridge")
        local GameStates = require("framework.game_states")
        scheduler:create(function()
            if rawget(_G, "LoadRecord") then LoadRecord(0) end
            -- **必须先关掉启动菜单协程**：JYMainAdapter.init 会起
            -- showStartMenuCoroutine，它的 ShowMenuCoroutine 一直挂在
            -- waitKey 上。若不清理，之后注入的 ESC/方向键会被**两个**菜单
            -- 同时消费 —— 实测表现为「按 6 次 down + return 却落在读取进度」。
            pcall(function()
                local MenuAsync = require("framework.menu_async")
                MenuAsync.clear()
                local IM = require("framework.input_manager")
                if IM then IM.disableInput = false end
            end)
            local JY = rawget(_G, "JY")
            if JY then
                JY.Base["人X"] = _AUTO_MMAP[1]
                JY.Base["人Y"] = _AUTO_MMAP[2]
                JY.Base["人X1"] = _AUTO_MMAP[1]
                JY.Base["人Y1"] = _AUTO_MMAP[2]
                JY.Base["人方向"] = 0
                JY.MyPic = 2501
                JY.oldMMapX = -1
                JY.oldMMapY = -1
            end
            -- 走与 GAME_SMAP → GAME_MMAP 完全相同的入口（getStateId + switchState），
            -- 这样 enter 回调（Init_MMap）会正常执行。
            local id = (GameStates and GameStates.getStateId
                        and GameStates.getStateId("GAME_MMAP")) or 2
            EventBridge.getInstance():switchState(id)
            pcall(function()
                love.filesystem.write("__mmap_ok.txt",
                    "mmap=" .. tostring(_AUTO_MMAP[1]) .. "," .. tostring(_AUTO_MMAP[2]))
            end)
        end, "auto_mmap")
    end

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

    -- 游戏逻辑推进（顺序写死在 framework/boot.lua 里，见其注释）
    Boot.update(dt)
end

function love.draw()
    -- 绘制边界 + 两条渲染链都在 Boot.draw 里（它内部用 beginFrame/endFrame
    -- 夹住，且保证出错时 endFrame 一定被调用）
    Boot.draw()

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
    Boot.quit()
    return false
end
