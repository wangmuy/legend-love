-- game_hooks.lua
-- 游戏逻辑注入点：framework 不硬依赖 game/script 的具体实现
--
-- 分层（change: port-script-decoupling）：
--
--   framework/game_states.lua 等
--        │  调 GameHooks.getMyPic() / addMyCurrentPic() / sceneCanPass(x,y)
--        ▼
--   framework/game_hooks.lua    ← 注入点（本文件）
--        │  启动时由 jymain_adapter 注册
--        ▼
--   game/script/jymain.lua 的真实实现
--
-- **为什么用注入而不是直接 require**：
--   GetMyPic / AddMyCurrentPic / SceneCanPass 是**纯游戏逻辑**
--   （主角贴图编号计算、走路动画帧推进、场景可通行判定）。
--   它们不属于引擎、也不属于 framework —— 属于游戏。
--   framework 硬依赖它们 = 层次倒置（framework 反过来依赖 script）。
--
--   注入式的好处：framework 可以在**没有游戏脚本**的环境里单独测试
--   （这正是 framework 要能复用到仙剑/白金英雄坛说的前提）。
--
-- **未注册时的行为**：返回 nil / 哨兵值，**不抛错**。
--   调用方必须能容忍这种状态（单元测试环境就是这样）。

local GameHooks = {}

-- 注册的实现（默认全 nil）
local impl = {
    getMyPic        = nil,
    addMyCurrentPic = nil,
    sceneCanPass    = nil,
    -- 背景重绘（替代 script 层 Cls 的"按状态重绘"那一半）
    --
    -- script 的 Cls 不只是清屏：它按 JY.Status 决定重绘主地图/场景/战斗/开场图。
    -- 这是**游戏逻辑**（读 JY.Status），所以走注入。
    clearBackground = nil,
    -- 播放音乐（替代 script 层 PlayMIDI）
    --
    -- script 的 PlayMIDI(id) 不只是播：它写 JY.CurrentMIDI、判 JY.EnableMusic、
    -- 再用 CC.MIDIFile 模板拼文件名。这些是游戏逻辑，走注入。
    playMIDI = nil,
    -- 动画推进（替代 AddMyCurrentPic 的"走一格加一帧"语义）
    --
    -- port-sprite-animation：动画改由 framework/sprite_anim 时间驱动。
    -- 但 "什么时候算在行走" 是游戏逻辑（读 JY.Base/按键），所以走注入。
    advanceWalkAnim = nil,
    -- 停止走路动画（回到站立帧）
    --
    -- 原版语义：MyTick 累加到 20（≈333ms 无输入）时把 MyCurrentPic 复位成站立帧。
    -- 改造后由这个 hook 让 sprite_anim 切到 stand 序列。
    stopWalkAnim = nil,
    -- 优先帧号（port-sprite-animation Task 4）
    --
    -- GetMyPic 的 script 实现仍保留（零回归兜底），但 framework 可以优先问
    -- sprite_anim 要帧号。返回 nil 表示"用 script 的实现"。
    preferredFrameId = nil,
}

--- 注册一组实现
--
-- 用法（jymain_adapter.init 里）：
--   GameHooks.register({
--       getMyPic        = GetMyPic,
--       addMyCurrentPic = AddMyCurrentPic,
--       sceneCanPass    = SceneCanPass,
--   })
--
-- @param spec table 函数表；只注册提供的键，未提供的保持原值
function GameHooks.register(spec)
    if type(spec) ~= "table" then return false end
    for k, v in pairs(spec) do
        if impl[k] ~= nil or k == "getMyPic" or k == "addMyCurrentPic"
           or k == "sceneCanPass" or k == "clearBackground"
           or k == "playMIDI" or k == "advanceWalkAnim"
           or k == "stopWalkAnim" or k == "preferredFrameId" then
            if type(v) == "function" then
                impl[k] = v
            elseif v == nil then
                impl[k] = nil
            end
        end
    end
    return true
end

--- 清空注册（测试用）
function GameHooks.clear()
    impl.getMyPic = nil
    impl.addMyCurrentPic = nil
    impl.sceneCanPass = nil
    impl.clearBackground = nil
    impl.playMIDI = nil
    impl.advanceWalkAnim = nil
    impl.stopWalkAnim = nil
    impl.preferredFrameId = nil
end

--- 是否已注册某个 hook
function GameHooks.has(name)
    return impl[name] ~= nil
end

-- ---------------------------------------------------------------------------
-- 三个 hook（未注册时返回哨兵，不抛错）
-- ---------------------------------------------------------------------------

--- 主角当前贴图编号
--
-- **优先走 sprite_anim（时间驱动），拿不到时退回 script 的 GetMyPic。**
-- 这个顺序保证零回归：sprite_anim 未激活（handle 尚未创建）时，
-- 行为与改造前完全一致。
--
-- @return number|nil 未注册时返回 nil
function GameHooks.getMyPic()
    -- ① 优先：sprite_anim 的当前帧（port-sprite-animation Task 4）
    if impl.preferredFrameId then
        local ok1, v1 = pcall(impl.preferredFrameId)
        if ok1 and type(v1) == "number" then return v1 end
    end
    -- ② 兜底：script 的 GetMyPic（legacy 公式，零回归）
    if not impl.getMyPic then return nil end
    local ok, v = pcall(impl.getMyPic)
    if ok and type(v) == "number" then return v end
    return nil
end

--- 取主角贴图编号，**未注册时返回 fallback**（赋值场景必须用它）
--
-- 为什么需要这个包装（而不是调用方写 `if v then ... end`）：
--
--   `getMyPic()` 返回 nil 是**合法的**——它表示"没有注入实现"（见上方
--   「未注册时的行为」）。但把它直接赋给 `JY.MyPic` 会让后续所有算术崩：
--
--   ```lua
--   JY.MyPic = GameHooks.getMyPic()          -- nil
--   EngineAPI.map.drawMain(x, y, JY.MyPic)   -- buildingSort: mypic * 2 → 崩
--   ```
--
--   实测踩过（`test_auto_move.lua` 单模块运行时）：
--     `attempt to compare number with nil`，而全量跑时不暴露
--     —— 因为 `mod_boot` 先跑、注册了 hook。这类"只在特定执行顺序下崩"
--     的缺陷最难查，所以统一收敛到一个函数。
--
-- @param fallback number|nil 未注册时用这个（通常是 `JY.MyPic` 的当前值，
--        或 `CC.MyStartPic`）
-- @return number|nil fallback 本身也可能是 nil（仍由调用方决定怎么处理）
function GameHooks.getMyPicOr(fallback)
    local v = GameHooks.getMyPic()
    if type(v) == "number" then return v end
    return fallback
end

--- 推进主角走路动画帧
-- @return boolean 是否真的执行了
function GameHooks.addMyCurrentPic()
    if not impl.addMyCurrentPic then return false end
    local ok = pcall(impl.addMyCurrentPic)
    return ok
end

--- 重绘当前状态的背景（未注册时退化为"填充黑屏"）
-- @return boolean 是否走了注入实现
function GameHooks.clearBackground()
    if not impl.clearBackground then return false end
    local ok = pcall(impl.clearBackground)
    return ok
end

--- 播放音乐
-- @param id number 曲目编号（负数 = 停）
-- @return boolean 是否走了注入实现
function GameHooks.playMIDI(id)
    if not impl.playMIDI then return false end
    local ok = pcall(impl.playMIDI, id)
    return ok
end

--- 推进走路动画
-- @return boolean 是否走了注入实现
function GameHooks.advanceWalkAnim()
    if not impl.advanceWalkAnim then return false end
    local ok = pcall(impl.advanceWalkAnim)
    return ok
end

--- 停止走路动画（回到站立帧）
-- @return boolean 是否走了注入实现
function GameHooks.stopWalkAnim()
    if not impl.stopWalkAnim then return false end
    local ok = pcall(impl.stopWalkAnim)
    return ok
end

--- 优先帧号（sprite_anim 路径）
-- @return number|nil nil = 用 script 的 GetMyPic
function GameHooks.preferredFrameId()
    if not impl.preferredFrameId then return nil end
    local ok, v = pcall(impl.preferredFrameId)
    if ok and type(v) == "number" then return v end
    return nil
end

--- 场景某格是否可通行
--
-- @param x, y number 场景坐标
-- @return boolean|nil 未注册时返回 nil（调用方需按"不可通行"处理）
function GameHooks.sceneCanPass(x, y)
    if not impl.sceneCanPass then return nil end
    local ok, v = pcall(impl.sceneCanPass, x, y)
    if ok then return v == true end
    return nil
end

return GameHooks
