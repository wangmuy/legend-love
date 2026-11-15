-- pathfind.lua
-- A* 寻路（纯算法，零引擎依赖）
--
-- 为什么不放进 update 循环（REQ-MS3-4）：
--   正常可达路径（可见范围 ~2400 格）通常 < 5ms，但「点击被墙完全隔离
--   的区域」时 A* 要搜完整个连通区才能确认不可达 —— 可能是几万节点，
--   几十毫秒。所以只在**点击瞬间**跑一次，update 里只做 O(1) 的队列消费。
--
-- 为什么用曼哈顿启发式（ADR-MS3-002）：
--   移动是 4 向（CC.DirectX/DirectY 只有上下左右），每步代价 1，
--   曼哈顿距离是 consistent 的 admissible heuristic，
--   因此 A* 最优且无需「重新打开已关闭节点」的复杂逻辑。
--   **若未来改成 8 向移动或带地形代价，必须重新验证这一条。**
--
-- 为什么设 maxNodes（ADR-MS3-003）：
--   阻断搜索可能遍历整个连通区。默认 5000 是正常路径（~42 步）的 10 倍余量，
--   超过说明目标极可能在另一个连通区 → 判定不可达对玩家友好。

local Pathfind = {}

Pathfind.DEFAULT_MAX_NODES = 5000

-- 4 向邻居（与 CC.DirectX/DirectY 一致的顺序：上、右、左、下）
local DX = { 0, 1, -1, 0 }
local DY = { -1, 0, 0, 1 }

----------------------------------------------------------------------
-- 二叉最小堆（按 f 值）
----------------------------------------------------------------------

local Heap = {}
Heap.__index = Heap

local function heapNew()
    return setmetatable({ n = 0 }, Heap)
end

local function heapPush(h, node)
    h.n = h.n + 1
    local i = h.n
    h[i] = node
    while i > 1 do
        local parent = math.floor(i / 2)
        if h[parent].f <= h[i].f then break end
        h[parent], h[i] = h[i], h[parent]
        i = parent
    end
end

local function heapPop(h)
    if h.n == 0 then return nil end
    local top = h[1]
    h[1] = h[h.n]
    h[h.n] = nil
    h.n = h.n - 1
    local i = 1
    while true do
        local l, r = i * 2, i * 2 + 1
        local smallest = i
        if l <= h.n and h[l].f < h[smallest].f then smallest = l end
        if r <= h.n and h[r].f < h[smallest].f then smallest = r end
        if smallest == i then break end
        h[smallest], h[i] = h[i], h[smallest]
        i = smallest
    end
    return top
end

----------------------------------------------------------------------
-- 坐标打包（避免用字符串做 key，字符串拼接在热点路径上很慢）
----------------------------------------------------------------------

-- 地图坐标范围远小于 4096，用 x * 8192 + y 做 key
-- 负坐标也支持：range 保证在 -4096..4095 内时唯一
local PACK_OFFSET = 4096
local PACK_STRIDE = 8192

local function pack(x, y)
    return (x + PACK_OFFSET) * PACK_STRIDE + (y + PACK_OFFSET)
end

local function unpackX(key)
    return math.floor(key / PACK_STRIDE) - PACK_OFFSET
end

local function unpackY(key)
    return key % PACK_STRIDE - PACK_OFFSET
end

Pathfind._pack = pack
Pathfind._unpackX = unpackX
Pathfind._unpackY = unpackY

----------------------------------------------------------------------
-- 主入口
----------------------------------------------------------------------

--- 求最短路径
--
-- @param sx, sy number 起点格坐标
-- @param gx, gy number 终点格坐标
-- @param isWalkable function(x, y) -> boolean 可走性判定
-- @param opts table|nil { maxNodes = number }
-- @return table|nil path  路径点数组（含起点与终点），每项 { x =, y = }
-- @return string|nil err  失败原因：
--   "goal-unwalkable"    终点本身不可站立
--   "no-path"            真的不连通
--   "exceeded-max-nodes" 搜索超过上限（视为不可达）
--   "bad-args"           起点/终点为 nil
function Pathfind.find(sx, sy, gx, gy, isWalkable, opts)
    if type(sx) ~= "number" or type(sy) ~= "number"
        or type(gx) ~= "number" or type(gy) ~= "number" then
        return nil, "bad-args"
    end
    if type(isWalkable) ~= "function" then
        return nil, "bad-args"
    end

    opts = opts or {}
    local maxNodes = opts.maxNodes or Pathfind.DEFAULT_MAX_NODES

    -- 目标本身不可站立：直接失败（避免把站不住的格子当终点）
    if not isWalkable(gx, gy) then
        return nil, "goal-unwalkable"
    end

    -- 起点 == 终点：返回仅含起点的路径（不是空表）
    if sx == gx and sy == gy then
        return { { x = sx, y = sy } }, nil
    end

    -- 起点不可站立时仍然允许搜（玩家可能站在"不合法"的位置，比如被事件推到墙上），
    -- 但不做特殊处理 —— 邻居判定会自然限制。

    local open = heapNew()
    local gScore = {}     -- key -> 已走代价
    local cameFrom = {}   -- key -> 父节点 key
    local closed = {}     -- key -> true
    local startKey = pack(sx, sy)
    local goalKey = pack(gx, gy)

    gScore[startKey] = 0
    heapPush(open, {
        x = sx, y = sy, key = startKey,
        g = 0,
        f = math.abs(sx - gx) + math.abs(sy - gy),   -- 曼哈顿
    })

    local expanded = 0

    while open.n > 0 do
        local cur = heapPop(open)
        if not closed[cur.key] then
            closed[cur.key] = true
            expanded = expanded + 1

            if expanded > maxNodes then
                return nil, "exceeded-max-nodes"
            end

            if cur.key == goalKey then
                -- 回溯路径
                local path = {}
                local k = goalKey
                while k do
                    table.insert(path, 1, { x = unpackX(k), y = unpackY(k) })
                    k = cameFrom[k]
                end
                return path, nil
            end

            local cg = gScore[cur.key] or 0
            for d = 1, 4 do
                local nx = cur.x + DX[d]
                local ny = cur.y + DY[d]
                local nk = pack(nx, ny)
                if not closed[nk] and isWalkable(nx, ny) then
                    local tentative = cg + 1
                    local best = gScore[nk]
                    if best == nil or tentative < best then
                        gScore[nk] = tentative
                        cameFrom[nk] = cur.key
                        heapPush(open, {
                            x = nx, y = ny, key = nk,
                            g = tentative,
                            f = tentative + math.abs(nx - gx) + math.abs(ny - gy),
                        })
                    end
                end
            end
        end
    end

    return nil, "no-path"
end

return Pathfind
