-- animation_defs.lua
-- 本游戏的帧序列定义（**游戏层数据，纯数据无逻辑**）
--
-- 分层（change: port-sprite-animation，ADR-PORT-016）：
--
--   framework/sprite_anim.lua        ← 播放器（不含任何具体帧号）
--   framework/animation_defs.lua     ← 本文件：把 CC 常量翻译成帧号数组
--
-- **为什么帧号定义要单独一个文件、而不是写死在 sprite_anim 里**：
--   帧号编码是本游戏的约定（`CC.MyStartPic + 方向*7 + 帧号`），
--   换游戏（仙剑 / 白金英雄坛说）时这套编码完全不同。
--   放在独立文件里，游戏层可整体替换，播放器保持通用。
--
-- **为什么不在模块加载期读 CC**：
--   CC 由 script/jyconst.lua 在运行时装配，本文件可能在 CC 之前被 require。
--   所以在模块顶层**不读任何全局**，只提供 defineAll(opts) 由调用方在
--   CC 就绪后调用。
--
-- **帧号是原样透传的绝对索引**（ADR-PORT-015）：
--   这里算出来的每个数就是 `EngineAPI.sprite.draw` 要收的 frameId。
--   播放器不解释、不换算、不做算术。

local SpriteAnim = require("framework.sprite_anim")

local AnimationDefs = {}

-- 方向编号 → 方向键名（仅用于生成序列 id）
-- 原版 JY.Base["人方向"] 取值 0..3
AnimationDefs.DIRECTIONS = {
    [0] = "down",
    [1] = "up",
    [2] = "left",
    [3] = "right",
}

-- 主角行走帧数（原版 GetMyPic 的硬编码：`MyCurrentPic > 6` 时复位为 1）
AnimationDefs.WALK_FRAMES = 6

-- 乘船帧数（原版：`MyCurrentPic >= 4` 时复位为 0，所以是 0..3 共 4 帧）
AnimationDefs.BOAT_FRAMES = 4

-- 站立帧在本组中的偏移（0 = 站立，1..6 = 行走）
AnimationDefs.STAND_OFFSET = 0

--- 计算某一方向的行走帧号数组
--
-- 与 script/GetMyPic 的公式**完全一致**：
--   n = CC.MyStartPic + 方向*7 + MyCurrentPic
-- 行走帧取 MyCurrentPic = 1..6（0 是站立帧）
--
-- @param startPic number CC.MyStartPic
-- @param dir number 方向 0..3
-- @return table {frameId...}
function AnimationDefs.walkFrames(startPic, dir)
    local base = startPic + dir * 7
    local out = {}
    for i = 1, AnimationDefs.WALK_FRAMES do
        out[i] = base + i      -- 原样透传：这就是最终 frameId
    end
    return out
end

--- 计算某一方向的乘船帧号数组
--
-- 与 script/GetMyPic 的乘船分支一致：
--   n = CC.BoatStartPic + 方向*4 + MyCurrentPic
-- 乘船帧取 MyCurrentPic = 0..3
--
-- @param boatStartPic number CC.BoatStartPic
-- @param dir number 方向 0..3
-- @return table {frameId...}
function AnimationDefs.boatFrames(boatStartPic, dir)
    local base = boatStartPic + dir * 4
    local out = {}
    for i = 0, AnimationDefs.BOAT_FRAMES - 1 do
        out[i + 1] = base + i
    end
    return out
end

--- 计算某一方向的站立帧号
-- @param startPic number CC.MyStartPic
-- @param dir number 方向 0..3
-- @return number frameId
function AnimationDefs.standFrame(startPic, dir)
    return startPic + dir * 7 + AnimationDefs.STAND_OFFSET
end

--- 定义全部序列（由 jymain_adapter 在 CC 就绪后调用）
--
-- @param opts table {
--     myStartPic   = number,  必需（CC.MyStartPic）
--     boatStartPic = number,  必需（CC.BoatStartPic）
--     walkFps      = number,  可选，默认 15
--     boatFps      = number,  可选，默认 8
--   }
-- @return number 定义的序列数量
function AnimationDefs.defineAll(opts)
    if type(opts) ~= "table" then return 0 end
    local startPic = tonumber(opts.myStartPic)
    local boatStart = tonumber(opts.boatStartPic)
    if not startPic or not boatStart then return 0 end

    local walkFps = tonumber(opts.walkFps) or 15
    local boatFps = tonumber(opts.boatFps) or 8

    local n = 0

    for dir = 0, 3 do
        local name = AnimationDefs.DIRECTIONS[dir]

        -- 行走
        local walkId = "person.walk." .. name
        SpriteAnim.defineSequence(walkId, {
            frames = AnimationDefs.walkFrames(startPic, dir),
            fps = walkFps,
            mode = SpriteAnim.MODE_LOOP,
        })
        n = n + 1

        -- 站立（单帧序列，loop 无副作用）
        local standId = "person.stand." .. name
        SpriteAnim.defineSequence(standId, {
            frames = { AnimationDefs.standFrame(startPic, dir) },
            fps = walkFps,
            mode = SpriteAnim.MODE_LOOP,
        })
        n = n + 1

        -- 乘船
        local boatId = "person.boat." .. name
        SpriteAnim.defineSequence(boatId, {
            frames = AnimationDefs.boatFrames(boatStart, dir),
            fps = boatFps,
            mode = SpriteAnim.MODE_LOOP,
        })
        n = n + 1
    end

    return n
end

--- 按 (方向, 是否乘船, 是否行走) 给出序列 id
--
-- 这个函数是 GetMyPic 改造后的「序列选择」唯一入口。
--
-- @param dir number 方向 0..3
-- @param onBoat boolean 是否乘船
-- @param walking boolean 是否在行走
-- @return string|nil 序列 id
function AnimationDefs.sequenceId(dir, onBoat, walking)
    local name = AnimationDefs.DIRECTIONS[dir]
    if not name then return nil end
    if onBoat then
        return walking and ("person.boat." .. name) or ("person.boat." .. name)
    end
    return walking and ("person.walk." .. name) or ("person.stand." .. name)
end

return AnimationDefs
