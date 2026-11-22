-- boot.lua
-- 运行时装配（**新引擎唯一需要知道的启动入口**）
--
-- 背景（change: engine-portability / 第三批）：
--
--   在 `Boot` 存在之前，「引擎实现好契约之后怎么把游戏跑起来」这段知识
--   只存在于 `game/main.lua` 的 `love.load()` 里（147 行）。新引擎作者
--   （Godot / Unreal / 其它）必须逐行读那个文件、抄出 6 个必需步骤，
--   还要自己发现 5 个裸名 require 别名和 3 个初始化全局。
--
--   本模块把那段序列搬进 framework，于是任何引擎的入口都只需要：
--
--   ```lua
--   local Boot = require("framework.boot")
--   Boot.install({ quit = function() ... end })   -- 启动一次
--   function _process(dt) Boot.update(dt) end      -- 每帧
--   function _draw()      Boot.draw()   end        -- 每帧（绘制回调内）
--   function _exit()      Boot.quit()   end        -- 退出
--   ```
--
--   这就是 `EngineAPI.app.install(runtime)` 契约的实现（引擎侧转发到这里）。
--
-- **本文件是 framework 的「最后一层」**：它允许调 script 全局
-- （`JYMainAdapter` / `EventBridge` / `MenuAsync` 等），因为它本来就是
-- 「把 framework 与 script 缝起来」的那一层。其余 framework 模块仍然
-- 必须零 script 全局依赖（gate STEP F 管这个）。

local Boot = {}

-- 宿主能力（由 install 传入，都是可选的）
local runtime = nil
-- 是否已安装（幂等：重复 install 只更新 runtime，不重复装配）
local installed = false

local function log(msg)
    local EA = rawget(_G, "EngineAPI")
    if EA and EA.debug and EA.debug.log then
        pcall(EA.debug.log, msg)
    end
end

--- 默认 runtime（所有钩子都可缺省）
local function normalizeRuntime(rt)
    rt = rt or {}
    return {
        -- 退出整个应用（未提供时降级为「什么也不做 + 返回 false」）
        quit = type(rt.quit) == "function" and rt.quit or function() return false end,
        -- 致命错误上报（未提供时只记日志）
        onError = type(rt.onError) == "function" and rt.onError or nil,
        -- 全屏切换（未提供时走 EngineAPI.app.toggleFullscreen）
        requestFullscreen = type(rt.requestFullscreen) == "function"
            and rt.requestFullscreen or nil,
        -- 资源根目录（默认 "game/"，与 EngineAPI.file.* 的相对路径基准一致）
        assetDir = type(rt.assetDir) == "string" and rt.assetDir or nil,
        -- 额外启动步骤（宿主想在 jymain 之前插自己的东西时用）
        beforeScript = type(rt.beforeScript) == "function" and rt.beforeScript or nil,
        -- 额外启动步骤（jymain + JYMainAdapter.init 之后）
        afterInit = type(rt.afterInit) == "function" and rt.afterInit or nil,
    }
end

--- 安装运行时（**幂等**）
--
-- 顺序不能变（每一步都依赖前一步的产物）：
--
--   ① `framework.config`      → 提供 CONFIG（Width/Height/ScriptPath/...）
--   ② `framework.lib_Byte`    → 提供全局 Byte（script 层到处在用）
--   ③ `framework.require_aliases` → 裸名 require（`require "lib_file"` 等）
--   ④ `EngineAPI.init()`      → 引擎自己的初始化（图形设置、随机种子）
--   ⑤ `EventBridge:init()`    → 状态机 / 输入 / 调度器 / 对话框
--   ⑥ `require jymain`        → 加载游戏逻辑（内部 require jyconst 得到 CC）
--   ⑦ `JYMainAdapter.init()`  → 起启动菜单协程
--
-- **为什么 ③ 是独立模块而不是写在这里**：web 引擎用自己的别名注册表
-- （`web_game_bridge.lua`），两边必须共用同一份清单，否则又是「两处维护」。
--
-- @param rt table|nil 宿主能力表（见文件头）
-- @return boolean 是否成功
function Boot.install(rt)
    runtime = normalizeRuntime(rt)

    -- 幂等：重复调用只更新 runtime（允许宿主换 quit 钩子而不重跑装配）
    if installed then
        log("Boot.install: already installed, runtime updated")
        return true
    end

    -- ① 配置
    local okCfg, errCfg = pcall(require, "framework.config")
    if not okCfg then
        log("Boot.install: framework.config FAILED: " .. tostring(errCfg))
        return false
    end
    local CONFIG = rawget(_G, "CONFIG") or {}

    -- ② Byte 全局（script 层 `Byte.LoadToTable16` 等直接用它）
    local okByte, ByteMod = pcall(require, "framework.lib_Byte")
    if okByte and ByteMod then
        rawset(_G, "Byte", ByteMod)
    else
        log("Boot.install: framework.lib_Byte FAILED: " .. tostring(ByteMod))
    end

    -- ③ 裸名 require 别名（`require "lib_file"` / `require "script_loader"`）
    --
    -- 这段以前写在 `engine-love2d/engine_love2d.lua` 头部 —— 意味着
    -- 换引擎就必须重新发现它（实测：模拟 Godot 宿主时第一次就死在
    -- `module 'lib_file' not found`）。
    local okAlias, errAlias = pcall(require, "framework.require_aliases")
    if not okAlias then
        log("Boot.install: framework.require_aliases FAILED: " .. tostring(errAlias))
    end

    -- ④ 引擎自身初始化（历史隐式契约，见 engine_api.lua 的 app.install 注释）
    local EngineAPI = rawget(_G, "EngineAPI")
    if EngineAPI and type(EngineAPI.init) == "function" then
        local okInit, errInit = pcall(EngineAPI.init)
        if not okInit then
            log("Boot.install: EngineAPI.init() FAILED: " .. tostring(errInit))
        end
    else
        log("Boot.install: EngineAPI.init missing (optional for non-graphical engines)")
    end

    -- ⑤ 事件桥接器（状态机 / 输入 / 协程调度 / 对话框）
    local okEB, EventBridge = pcall(require, "framework.event_bridge")
    if not okEB or not EventBridge then
        log("Boot.install: framework.event_bridge FAILED: " .. tostring(EventBridge))
        return false
    end
    pcall(function() EventBridge.getInstance():init() end)

    -- 宿主自定义：脚本加载前
    if runtime.beforeScript then
        pcall(runtime.beforeScript)
    end

    -- ⑥ 游戏逻辑（内部 require "script.jyconst" 之后就绪 CC）
    local scriptPath = (CONFIG and CONFIG.ScriptPath) or "script/"
    local okJY, errJY = pcall(require, scriptPath .. "jymain")
    if not okJY then
        log("Boot.install: require " .. scriptPath .. "jymain FAILED: " .. tostring(errJY))
        return false
    end

    -- ⑦ 游戏适配器（起启动菜单协程）
    local okJA, JYMainAdapter = pcall(require, "framework.jymain_adapter")
    if okJA and JYMainAdapter then
        pcall(JYMainAdapter.init)
    else
        log("Boot.install: framework.jymain_adapter FAILED: " .. tostring(JYMainAdapter))
    end

    -- 宿主自定义：初始化完成后
    if runtime.afterInit then
        pcall(runtime.afterInit)
    end

    installed = true
    log("Boot.install: done")
    return true
end

--- 每帧更新（**顺序不能变**，见 `AGENTS.md` 的「每帧流程」）
--
--  1. JYMainAdapter.update  —— 游戏适配器（鼠标轮询、输入状态）
--  2. EventBridge:update    —— 事件桥接（输入消费、协程调度、状态机）
--  3. MenuAsync.update      —— 菜单（必须最后，它读的是本帧输入结果）
--
-- @param dt number 帧间隔（**秒**；LÖVE / Godot / Unreal 都是秒）
function Boot.update(dt)
    if not installed then return end
    dt = tonumber(dt) or 0

    local ok1, JYMainAdapter = pcall(require, "framework.jymain_adapter")
    if ok1 and JYMainAdapter then pcall(JYMainAdapter.update, dt) end

    local ok2, EventBridge = pcall(require, "framework.event_bridge")
    if ok2 and EventBridge then
        pcall(function() EventBridge.getInstance():update(dt) end)
    end

    local ok3, MenuAsync = pcall(require, "framework.menu_async")
    if ok3 and MenuAsync then pcall(MenuAsync.update, dt) end
end

--- 每帧绘制（**必须在宿主的帧绘制回调内调用**）
--
-- 用 `beginFrame()` / `endFrame()` 夹住，而不是直接调 `setDrawLoopFlag`
-- （后者是「传 false 就把绘制状态留在错的一边」的写法）。
--
-- **为什么用 pcall**：绘制中途出错时，`endFrame()` 仍然必须被调用，
-- 否则引擎的绘制批次/渲染目标会跨帧泄漏（LÖVE 会一直往同一个
-- Canvas 上画，Godot 会留下未关闭的 `draw_*` 状态）。
-- 错误本身不吞：记日志后**重新抛出**，让宿主/引擎的错误屏能看到。
function Boot.draw()
    if not installed then return end

    local EngineAPI = rawget(_G, "EngineAPI")
    local R = EngineAPI and EngineAPI.render

    local began = false
    if R and type(R.beginFrame) == "function" then
        began = pcall(R.beginFrame) or false
    end

    local ok, err = pcall(function()
        local okEB, EventBridge = pcall(require, "framework.event_bridge")
        if okEB and EventBridge then
            EventBridge.getInstance():draw()
        end
        local okMA, MenuAsync = pcall(require, "framework.menu_async")
        if okMA and MenuAsync then
            MenuAsync.draw()
        end
    end)

    if began and type(R.endFrame) == "function" then
        pcall(R.endFrame)
    end

    if not ok then
        log("Boot.draw: FAILED: " .. tostring(err))
        if runtime and runtime.onError then
            pcall(runtime.onError, err)
        else
            error(err, 0)
        end
    end
end

--- 退出（释放资源）
--
-- 调用方应在宿主退出前调一次。返回 true 表示可以退出。
function Boot.quit()
    local okEB, EventBridge = pcall(require, "framework.event_bridge")
    if okEB and EventBridge then
        pcall(function() EventBridge.getInstance():reset() end)
    end
    local okJA, JYMainAdapter = pcall(require, "framework.jymain_adapter")
    if okJA and JYMainAdapter then
        pcall(JYMainAdapter.reset)
    end
    installed = false
    return true
end

--- 请求退出应用（走宿主提供的钩子；无钩子时降级）
--
-- `EngineAPI.app.requestQuit` 的实现就是转调这里。
--
-- @return boolean 是否真的触发了
function Boot.requestQuit()
    if runtime and runtime.quit then
        local ok, r = pcall(runtime.quit)
        return ok and r ~= false
    end
    -- 没有宿主钩子：尝试引擎自己的退出契约（LÖVE 的 app.quit）
    local EngineAPI = rawget(_G, "EngineAPI")
    if EngineAPI and EngineAPI.app and type(EngineAPI.app.quit) == "function" then
        local ok = pcall(EngineAPI.app.quit)
        if ok then return true end
    end
    return false
end

--- 当前是否已安装（测试用）
function Boot.isInstalled()
    return installed
end

--- 读取/替换 runtime（测试用）
-- 传 nil 只读；传表则替换并返回旧表。
function Boot._runtime(newRuntime)
    local old = runtime
    if newRuntime ~= nil then
        runtime = normalizeRuntime(newRuntime)
    end
    return old
end

--- 重置（**仅测试用**）：让 install 可以重跑
function Boot._reset()
    installed = false
    runtime = nil
end

return Boot
