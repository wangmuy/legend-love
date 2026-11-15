-- interact.lua
-- 「交互目标」判定与接近（REQ-MS3-6）
--
-- 解决同一类问题：**不可站立但可以交互的格子**。
--
--   大地图：客栈门口那一格（建筑，不可走）→ 走过去应该进门
--   小场景：NPC / 物品所在格（D* 事件，不可走）→ 走过去应该开箱/对话
--
-- 键盘早就有这个能力（两处同构）：
--   地图：Game_MMap 先算目标格 → CanEnterScene(目标格) → 在**可走性检查之前**
--         判定，所以人从不真的站到门口格上，是「面朝门口迈一步」进的门。
--   场景：GAME_SMAP.update 里 SPACE 分支 → 取「面前一格」的 GetS(...,3)
--         → EventExecuteSync(d, 1)。同样不需要站上去。
--
-- 鼠标点击若要求「终点必须可走」（A* 的前提），就永远够不到这些格子 ——
-- 表现为「只能走到门口，进不去」。本模块把「够不到」变成「够到旁边再说」。
--
-- 设计要点（ADR-MS3-009）：
--   ① 判定与触发**复用既有函数**，不重写条件
--        MMAP → CanEnterScene
--        SMAP → GetS(...,3) + GetD(...,0)（与 SceneCanPass 一致的门槛）
--   ② 接近点用 BFS 在半径内找最近的**可走**邻格，不假设「上/下/左/右」
--      哪一个是门（门可能开在任意方向，也可能在墙角）
--   ③ 到达后「面朝目标 + 触发」，与键盘按 SPACE 完全同一条路径

local Interact = {}

-- 搜索接近点的最大半径
-- 门/NPC 一般紧贴可走区，半径 2 足够；再大容易出现「莫名其妙绕到很远」
Interact.MAX_APPROACH_RADIUS = 2

-- 4 向（与 CC.DirectX/DirectY 一致：上、右、左、下）
local DX = { 0, 1, -1, 0 }
local DY = { -1, 0, 0, 1 }

-- 方向码：0=上 1=右 2=左 3=下
local DIRECT_OF = {
    ["0,-1"] = 0,
    ["1,0"]  = 1,
    ["-1,0"] = 2,
    ["0,1"]  = 3,
}

--- 由位移求方向码
-- @param dx, dy number
-- @return number|nil
function Interact.directionOf(dx, dy)
    return DIRECT_OF[dx .. "," .. dy]
end

--- 判定某格是否是「可交互但不可站立」的目标
--
-- @param mapKind string "MMAP" | "SMAP"
-- @param x, y number 目标格（世界坐标）
-- @return string|nil kind  "scene"（可进入的场景）| "event"（场景内事件）
-- @return number|nil payload  scene → 场景 id；event → 事件 id
function Interact.probe(mapKind, x, y)
    if mapKind == "MMAP" then
        -- 逐字复用 CanEnterScene：它已处理「进入条件」的三种情况
        -- （0 可进 / 1 不可进 / 2 需轻功），自行重写必然漏条件。
        local ok, sid = pcall(function() return CanEnterScene(x, y) end)
        if ok and type(sid) == "number" and sid >= 0 then
            return "scene", sid
        end
        return nil, nil
    end

    -- SMAP：与键盘 SPACE 分支完全相同的判定
    local JY = rawget(_G, "JY")
    if not (JY and JY.SubScene) then return nil, nil end
    if JY.SubScene < 0 then return nil, nil end

    local ok, d = pcall(function() return GetS(JY.SubScene, x, y, 3) end)
    if not ok or type(d) ~= "number" or d < 0 then
        return nil, nil
    end

    -- **只判断「有没有事件」，不判断「能不能通行」**
    --
    -- 这一条我最初写错过（用户实测：箱子打不开、软体娃娃不对话）。
    -- 当时的错误逻辑是：
    --     if GetD(JY.SubScene, d, 0) ~= 0 then return nil end
    -- 认为「不可通行 = 纯障碍」。
    --
    -- 事实恰好相反：GetD(d,0) ~= 0 正是「这个事件是实体（NPC/箱子/招牌）」，
    -- 所以站不上去 —— 也正是它需要用「站旁边交互」的原因。
    -- 纯装饰性障碍才没有事件层数据。
    --
    -- 判据就是键盘 SPACE 分支的判据，一个字都不多：
    --     local d_num = GetS(JY.SubScene, targetX, targetY, 3)
    --     if d_num >= 0 then EventExecuteSync(d_num, 1) end
    -- 键盘不在 D 数据上做任何过滤，鼠标也不该做。
    return "event", d
end

--- 在目标周围找最近的、可以站立的邻格
--
-- 用 BFS 而不是「依次试 上/右/左/下」：门可能开在任意方向，
-- 固定顺序会让人绕到与点击位置相反的那一侧。
--
-- @param tx, ty number 目标格
-- @param walkable function(x,y) -> boolean
-- @param fromX, fromY number|nil 起点（用于在距离相同时选更近的接近点）
-- @return number|nil ax, ay
function Interact.findApproach(tx, ty, walkable, fromX, fromY)
    if type(walkable) ~= "function" then return nil end

    local maxR = Interact.MAX_APPROACH_RADIUS
    local best, bestScore

    for r = 1, maxR do
        -- 只扫第 r 圈（曼哈顿环）
        for ddx = -r, r do
            local rem = r - math.abs(ddx)
            local dys = { rem }
            if rem ~= 0 then dys[2] = -rem end
            for _, ddy in ipairs(dys) do
                local ax, ay = tx + ddx, ty + ddy
                if walkable(ax, ay) then
                    -- 评分：先看「离目标多远」（r 小的优先），
                    -- 再看「离起点多远」（少走路）
                    local score = r * 1000
                    if fromX and fromY then
                        score = score + math.abs(ax - fromX) + math.abs(ay - fromY)
                    end
                    if not bestScore or score < bestScore then
                        best, bestScore = { x = ax, y = ay }, score
                    end
                end
            end
        end
        -- 第 r 圈找到就停（更外圈必然更远）
        if best then return best.x, best.y end
    end

    return nil, nil
end

--- 面朝目标并触发交互（与键盘按 SPACE 同一条路径）
--
-- 调用前提：玩家已经站在目标的相邻格上。
--
-- @param mapKind string "MMAP" | "SMAP"
-- @param tx, ty number 目标格
-- @return boolean 是否触发了
function Interact.trigger(mapKind, tx, ty)
    local JY = rawget(_G, "JY")
    if not JY then return false end

    local curX, curY
    if mapKind == "MMAP" then
        curX, curY = JY.Base["人X"], JY.Base["人Y"]
    else
        curX, curY = JY.Base["人X1"], JY.Base["人Y1"]
    end

    -- 必须相邻（斜向不算）
    local dx, dy = tx - curX, ty - curY
    local direct = Interact.directionOf(dx, dy)
    if not direct then
        return false
    end

    -- 面朝目标：键盘触发事件时也用 人方向 决定「面前那一格」
    JY.Base["人方向"] = direct

    local kind, payload = Interact.probe(mapKind, tx, ty)
    if kind == "scene" then
        -- 与键盘路径一致：先重算贴图，再进场景
        local okPic, pic = pcall(GetMyPic)
        if okPic and pic then JY.MyPic = pic end
        JY.MmapMusic = -1
        JY.SubScene = payload

        -- 走共享函数：直接改 JY.Status 会跳过 GAME_SMAP.enter → Init_SMap 不执行
        --
        -- 用 pcall 包住 require：game_states 会 require 本模块，
        -- 若在它初始化过程中被反向调用，require 可能拿到不完整的表。
        local okGS, GameStates = pcall(require, "framework.game_states")
        if okGS and GameStates and GameStates._enterSubScene then
            local okEnter, err = pcall(GameStates._enterSubScene, payload)
            if okEnter then return true end
            local lib = rawget(_G, "lib")
            if lib and lib.Debug then
                lib.Debug("Interact.trigger: enterSubScene 失败 " .. tostring(err))
            end
        end
        return false
    end

    if kind == "event" then
        -- 与 GAME_SMAP.update 的 SPACE 分支逐字一致
        local okExec = pcall(function() EventExecuteSync(payload, 1) end)
        if okExec then
            -- 清掉「旧位置」缓存，强制重绘（键盘路径也这么做）
            JY.oldSMapX = -1
            JY.oldSMapY = -1
            JY.D_Valid = nil
            return true
        end
        return false
    end

    return false
end

--- 一步判定：这个格子能不能作为「走过去互动」的目标
--
-- 供 handleMapClick 使用，把「判定 + 找接近点」合起来。
--
-- @param mapKind string
-- @param gx, gy number 点击的目标格
-- @param curX, curY number 当前所在格
-- @param walkable function
-- @return table|nil { kind=, payload=, ax=, ay= }
function Interact.plan(mapKind, gx, gy, curX, curY, walkable)
    local kind, payload = Interact.probe(mapKind, gx, gy)
    if not kind then return nil end

    local ax, ay = Interact.findApproach(gx, gy, walkable, curX, curY)
    if not ax then return nil end

    return { kind = kind, payload = payload, ax = ax, ay = ay }
end

return Interact
