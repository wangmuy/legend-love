-- sprite_anim.lua
-- 精灵动画播放器（**纯逻辑，零引擎依赖**）
--
-- 分层（change: port-sprite-animation，design.md ADR-PORT-013..018）：
--
--   framework/sprite_anim.lua        ← 本文件：帧序列 + 时间推进 + 状态机
--          │  只调这一个既有契约
--          ▼
--   EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)
--
-- **为什么动画播放器必须住 framework，不能借引擎的**（实测依据）：
--   LÖVE   love.graphics.draw(quad)              无资产格式
--   Godot  AnimatedSprite2D + SpriteFrames        绑死 .tres 资产
--   Unreal PaperFlipbookComponent                绑死 .uasset 资产
--   SDL2   SDL_RenderCopy(srcRect)               无动画概念
--
--   Godot 与 Unreal 的动画播放器**都绑死各自资产管线**。
--   唯一公共子集是「给定 archiveId + 不透明整数帧号，画在 (x,y)」。
--   所以播放器必须由 framework 自己驱动时间，引擎只认帧号。
--
-- **frameId 是不透明整数**（ADR-PORT-015）：
--   本文件**不得**对 frameId 做算术（+ - * %）。序列里存的就是最终帧号，
--   由 `animation_defs.lua`（游戏层数据）算好。这是换引擎时不裂的关键 ——
--   不同引擎的 frameId 语义不同（LÖVE=绝对索引 / Godot=hframes 组合），
--   只有「原样透传」才能都支持。
--
-- **update(dt) 是唯一时间源**（ADR-PORT-017）：
--   不得存在"走一格加一帧"的旁路。dt 来自 EventBridge:update(dt)。

local SpriteAnim = {}

-- ---------------------------------------------------------------------------
-- 序列定义
-- ---------------------------------------------------------------------------

-- id -> { frames = {frameId...}, fps = number, mode = "loop"|"once"|"pingpong" }
local sequences = {}

SpriteAnim.MODE_LOOP     = "loop"
SpriteAnim.MODE_ONCE     = "once"
SpriteAnim.MODE_PINGPONG = "pingpong"

--- 定义一个帧序列
--
-- @param id string 序列 id（如 "person.walk.down"）
-- @param spec table {
--     frames = {frameId...},            必需，最终帧号（不透明整数）
--     fps    = number,                  可选，默认 12
--     mode   = "loop"|"once"|"pingpong" 可选，默认 "loop"
--   }
-- @return boolean
function SpriteAnim.defineSequence(id, spec)
    if type(id) ~= "string" or id == "" then return false end
    if type(spec) ~= "table" then return false end
    if type(spec.frames) ~= "table" or #spec.frames == 0 then return false end

    local fps = tonumber(spec.fps) or 12
    if fps <= 0 then fps = 12 end

    local mode = spec.mode or SpriteAnim.MODE_LOOP
    if mode ~= SpriteAnim.MODE_LOOP
       and mode ~= SpriteAnim.MODE_ONCE
       and mode ~= SpriteAnim.MODE_PINGPONG then
        mode = SpriteAnim.MODE_LOOP
    end

    sequences[id] = {
        id = id,
        frames = spec.frames,
        fps = fps,
        mode = mode,
        -- 每帧持续时间（秒）
        frameTime = 1 / fps,
    }
    return true
end

--- 取序列定义（只读）
function SpriteAnim.getSequence(id)
    return sequences[id]
end

--- 列出已定义的序列 id
function SpriteAnim.listSequences()
    local out = {}
    for id in pairs(sequences) do out[#out + 1] = id end
    table.sort(out)
    return out
end

--- 清空全部序列（测试 / 场景重置）
function SpriteAnim.clearSequences()
    sequences = {}
end

-- ---------------------------------------------------------------------------
-- 播放句柄
-- ---------------------------------------------------------------------------

-- handleId -> 播放状态
local handles = {}
local nextHandle = 1

-- 单帧内的播放状态
--
-- 字段说明：
--   seqId      当前序列 id
--   index      当前帧在 frames 数组里的下标（1-based）
--   dir        播放方向（1 = 前进，-1 = 后退，pingpong 用）
--   elapsed    在当前帧已累计的时间（秒）
--   playing    是否在播
--   onComplete 完成回调（once/pingpong 用，只触发一次）
--   completeFired 是否已触发过回调

--- 创建一个播放句柄（不自动播放）
-- @return number|nil handleId
function SpriteAnim.createHandle()
    local id = nextHandle
    nextHandle = nextHandle + 1
    handles[id] = {
        seqId = nil,
        index = 1,
        dir = 1,
        elapsed = 0,
        playing = false,
        onComplete = nil,
        completeFired = false,
    }
    return id
end

--- 销毁句柄
function SpriteAnim.destroyHandle(handleId)
    handles[handleId] = nil
end

--- 清空全部句柄（测试用）
function SpriteAnim.clearHandles()
    handles = {}
    nextHandle = 1
end

--- 开始播放
--
-- @param handleId number
-- @param seqId string 序列 id
-- @param opts table|nil { onComplete = function() end, restart = true }
-- @return boolean
function SpriteAnim.play(handleId, seqId, opts)
    local h = handles[handleId]
    if not h then return false end
    local seq = sequences[seqId]
    if not seq then return false end

    opts = opts or {}
    -- restart 默认 true：play 总是从头开始（重复调 play 同一序列也是重播）
    h.seqId = seqId
    h.index = 1
    h.dir = 1
    h.elapsed = 0
    h.playing = true
    h.onComplete = opts.onComplete
    h.completeFired = false
    return true
end

--- 停止播放（保留当前帧）
function SpriteAnim.stop(handleId)
    local h = handles[handleId]
    if not h then return false end
    h.playing = false
    return true
end

--- 是否正在播放
function SpriteAnim.isPlaying(handleId)
    local h = handles[handleId]
    if not h then return false end
    return h.playing == true
end

--- 取当前帧号（**原样返回序列里的值，不做任何算术**）
-- @return number|nil
function SpriteAnim.getFrameId(handleId)
    local h = handles[handleId]
    if not h or not h.seqId then return nil end
    local seq = sequences[h.seqId]
    if not seq then return nil end
    return seq.frames[h.index]
end

--- 取当前帧下标（1-based，调试/测试用）
function SpriteAnim.getFrameIndex(handleId)
    local h = handles[handleId]
    if not h then return nil end
    return h.index
end

--- 手动设置帧下标（调试 / "回到站立帧" 用）
--
-- @param handleId number
-- @param index number 1-based
function SpriteAnim.setFrameIndex(handleId, index)
    local h = handles[handleId]
    if not h then return false end
    local seq = sequences[h.seqId]
    if not seq then return false end
    if index < 1 then index = 1 end
    if index > #seq.frames then index = #seq.frames end
    h.index = index
    h.elapsed = 0
    return true
end

-- ---------------------------------------------------------------------------
-- 时间推进（唯一时间源）
-- ---------------------------------------------------------------------------

--- 推进所有活跃动画
--
-- @param dt number 帧间隔（秒）
-- @return number 本次推进中触发的 onComplete 次数
function SpriteAnim.update(dt)
    if type(dt) ~= "number" or dt <= 0 then return 0 end

    local completed = 0

    for _, h in pairs(handles) do
        if h.playing and h.seqId then
            local seq = sequences[h.seqId]
            if seq then
                h.elapsed = h.elapsed + dt

                -- 用 while 而不是 if：dt 可能大于一帧时长（低帧率时跳帧）
                --
                -- **必须带浮点容差**：0.3 - 0.1 - 0.1 在 IEEE754 下是
                -- 0.09999999999999998，不足一帧时长 → 少推进一帧。
                -- 实测：fps=10 时 update(0.3) 只推进 2 帧而不是 3 帧。
                -- 容差取 1e-9（相对 frameTime 足够小，不会误触发）。
                local EPS = 1e-9
                local guard = 0
                while h.elapsed >= seq.frameTime - EPS and guard < 1000 do
                    h.elapsed = h.elapsed - seq.frameTime
                    guard = guard + 1
                    local done = SpriteAnim._advance(h, seq)
                    if done then
                        completed = completed + 1
                        break   -- once 播完就停，不再推进
                    end
                end
            end
        end
    end

    return completed
end

--- 前进一帧（内部）
--
-- @return boolean 是否播完（once / pingpong 到头）
function SpriteAnim._advance(h, seq)
    local n = #seq.frames

    if seq.mode == SpriteAnim.MODE_LOOP then
        h.index = h.index + 1
        if h.index > n then h.index = 1 end
        return false

    elseif seq.mode == SpriteAnim.MODE_ONCE then
        h.index = h.index + 1
        if h.index >= n then
            h.index = n
            h.playing = false
            if not h.completeFired then
                h.completeFired = true
                if type(h.onComplete) == "function" then
                    pcall(h.onComplete)
                end
            end
            return true
        end
        return false

    else -- pingpong
        if n == 1 then
            h.index = 1
            h.playing = false
            if not h.completeFired then
                h.completeFired = true
                if type(h.onComplete) == "function" then
                    pcall(h.onComplete)
                end
            end
            return true
        end

        h.index = h.index + h.dir
        if h.index > n then
            h.index = n - 1
            h.dir = -1
        elseif h.index < 1 then
            -- 一次完整的往返结束
            h.index = 1
            h.dir = 1
            h.playing = false
            if not h.completeFired then
                h.completeFired = true
                if type(h.onComplete) == "function" then
                    pcall(h.onComplete)
                end
            end
            return true
        end
        return false
    end
end

--- 统计（调试 / 测试用）
function SpriteAnim.stats()
    local playing, total = 0, 0
    for _, h in pairs(handles) do
        total = total + 1
        if h.playing then playing = playing + 1 end
    end
    return { handles = total, playing = playing, sequences = (#SpriteAnim.listSequences()) }
end

return SpriteAnim
