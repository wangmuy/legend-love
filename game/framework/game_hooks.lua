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
           or k == "sceneCanPass" or k == "clearBackground" then
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
end

--- 是否已注册某个 hook
function GameHooks.has(name)
    return impl[name] ~= nil
end

-- ---------------------------------------------------------------------------
-- 三个 hook（未注册时返回哨兵，不抛错）
-- ---------------------------------------------------------------------------

--- 主角当前贴图编号
-- @return number|nil 未注册时返回 nil
function GameHooks.getMyPic()
    if not impl.getMyPic then return nil end
    local ok, v = pcall(impl.getMyPic)
    if ok and type(v) == "number" then return v end
    return nil
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
