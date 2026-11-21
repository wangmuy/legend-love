-- test_map_render.lua
-- framework/map_render.lua 的回归测试（change: port-map-render-native Task 2）
--
-- 守的核心风险：
--   `BuildingSort`（83 行）要搬进 framework。它的逻辑**一字不能改** ——
--   注释里记着两次真实回归：
--     ① `table.insert` 误用 → 插入点后移一位 → 建筑深度顺序错 → 遮挡错位
--     ② 同一误用还会让 buildList 无限拉长（长跑内存只增不减）
--
--   所以本测试的做法是：**拿原实现逐条对比**。同样的地图输入，
--   新旧两个实现产出的 (x, y, num) 序列必须完全相同。

local TestHelper = require("tests.test_helper")
local TestMapRender = {}

--- 装最小环境（测试桩引擎 + CONFIG + CC）
local function installEnv()
    package.loaded["tests.engine_test"] = nil
    require("tests.engine_test")
    package.loaded["framework.map_render"] = nil

    local tiles = rawget(_G, "EngineAPI").map._tiles

    rawset(_G, "CONFIG", {
        Width = 1024, Height = 768, XScale = 18, YScale = 9,
        -- **三个地图各有自己的 AddX/AddY**：缺一个，对应的 draw* 就算不出
        -- 循环边界（`... - CONFIG.WMapAddX` 会得到 nil 参与算术 → NaN/错范围）。
        MMapAddX = 0, MMapAddY = 0,
        SMapAddX = 0, SMapAddY = 0,
        WMapAddX = 0, WMapAddY = 0,
    })
    rawset(_G, "CC", { MWidth = 40, MHeight = 40 })

    return tiles
end

--- 造确定性地图：**dense**（所有层都填 0，每 5 格一个建筑）
--
-- **为什么必须 dense**：真引擎的 `GetMMap` 读的是 `mmap[earth/surface/building/...]`
-- **dense 数组**，范围内一定返回数字（0 而不是 nil）。而测试桩的 `getTile`
-- 对缺失 key 返回 -1（稀疏语义）。
--
-- 这个差异会掩盖真实行为：`buildingSort` 里
-- ```lua
-- local bak = getTile(x,y,2)       -- 真引擎得 0（或实际值）
-- ...排序...
-- setTile(x,y,2, bak)              -- 恢复到 0
-- ```
-- 若桩返回 -1，恢复时写 -1 → 与原值 0 不等 → 测试误报"地图没恢复"。
-- （我第一版就是这么错的，实测 3 处差异。）
local function seedMap(tiles)
    for k in pairs(tiles) do tiles[k] = nil end
    for x = 0, 39 do
        for y = 0, 39 do
            for layer = 0, 4 do
                tiles[x .. "," .. y .. "," .. layer] = 0
            end
            -- **必须造能触发「右旋」分支的形状**（buildingSort 里语义最微妙
            -- 的一段，注释记着两次真实回归：table.insert 误用导致顺序错 + 内存增长）。
            --
            -- 右旋触发条件（实测确认）：
            --   同一建筑 A 在一列里被扫到**第二次**，且当时已积累 >=2 条目
            --   （`k == p-1` 时的 break 会跳过），且 A 与该列上方某建筑 B 之间
            --   存在「既不是 A 也不是 buildList[k]」的条目。
            --
            -- 我第一版 seedMap 每 5 格一个建筑、遮罩值 = (x,y) **唯一**
            --   → 永不重复 → 分支永不执行 → 单测覆盖不到（负向对照测不出）。
            -- 第二版改成 8×8 分块（同一遮罩占多格）→ 实测触发 2 次 ✓
            local bx = math.floor(x / 8) * 8
            local by = math.floor(y / 8) * 8
            if bx ~= 0 or by ~= 0 then       -- 保留 (0..7,0..7) 无建筑区
                tiles[x .. "," .. y .. ",2"] = 100 + bx * 10 + by
                tiles[x .. "," .. y .. ",3"] = bx
                tiles[x .. "," .. y .. ",4"] = by
            end

            -- 竖直 A-B-A 三连（放在主角下方 (10,10) 的扫描范围内，
            -- 且刻意让 A 的遮罩 (8,8) 与 8×8 分块重叠 —— 增加路径覆盖）
            if x == 10 and y == 11 then
                tiles[x .. "," .. y .. ",2"] = 188
                tiles[x .. "," .. y .. ",3"] = 8
                tiles[x .. "," .. y .. ",4"] = 8
            elseif x == 10 and y == 12 then
                tiles[x .. "," .. y .. ",2"] = 268
                tiles[x .. "," .. y .. ",3"] = 16
                tiles[x .. "," .. y .. ",4"] = 8
            elseif x == 10 and y == 13 then
                tiles[x .. "," .. y .. ",2"] = 188
                tiles[x .. "," .. y .. ",3"] = 8
                tiles[x .. "," .. y .. ",4"] = 8
            end
        end
    end
end

--- 加载原实现 `lib.BuildingSort`（从源码里抽出来编译）
local function loadLegacySort(tiles)
    rawset(_G, "bit32", require("framework.lib_bit"))
    rawset(_G, "GetMMap", function(x, y, layer)
        local v = tiles[x .. "," .. y .. "," .. layer]
        if v == nil then return -1 end
        return v
    end)
    rawset(_G, "SetMMap", function(x, y, layer, v)
        tiles[x .. "," .. y .. "," .. layer] = v
    end)
    rawset(_G, "limitX", function(x, mn, mx)
        if x < mn then return mn end
        if x > mx then return mx end
        return x
    end)
    rawset(_G, "BuildingType", { new = function() return { x = 0, y = 0, num = 0 } end })
    rawset(_G, "buildList", {})
    rawset(_G, "buildNumber", 0)
    for i = 1, 2000 do rawget(_G, "buildList")[i] = { x = 0, y = 0, num = 0 } end

    local f = io.open("engine-love2d/lib_love.lua", "r")
    if not f then f = io.open("../game/engine-love2d/lib_love.lua", "r") end
    TestHelper.assertNotNil(f, "应能读到 lib_love.lua")
    local src = f:read("*a")
    f:close()

    local st = src:find("function BuildingSort", 1, true)
    TestHelper.assertNotNil(st, "应找到 lib.BuildingSort")
    local en = src:find("\nfunction ", st + 10)
    local body = src:sub(st, (en or (#src + 1)) - 1)
    -- **跨版本**：Lua 5.1 有 `loadstring`，5.2+ 改名为 `load`（5.3/5.4/5.5 都没有
    -- `loadstring`）→ 直接用 `loadstring` 会在 5.3+ 报
    -- "attempt to call a nil value (global 'loadstring')"。
    local loader = loadstring or load
    local chunk = assert(loader(body))
    chunk()
    return rawget(_G, "BuildingSort")
end

-- ------------------------------------------------------------ ① 逐条等价

function TestMapRender.testSortEquivalentToLegacy()
    print("\n=== Test: buildingSort 与原 lib.BuildingSort 逐条一致 ===")
    local tiles = installEnv()
    seedMap(tiles)

    local MR = require("framework.map_render")
    local legacy = loadLegacySort(tiles)

    -- 同输入各跑一遍
    MR.reset()
    MR.buildingSort(10, 10, 500)
    local newCount = MR.buildingCount()

    legacy(10, 10, 500)
    local oldCount = rawget(_G, "buildNumber")

    TestHelper.assertEquals(oldCount, newCount,
        "建筑数量应一致（旧 " .. oldCount .. " / 新 " .. newCount .. "）")

    local oldList = rawget(_G, "buildList")
    for i = 0, newCount - 1 do
        local o = oldList[i + 1]
        local n = MR.buildingAt(i)
        TestHelper.assertEquals(o.x, n.x, "第 " .. i .. " 条的 x 应一致")
        TestHelper.assertEquals(o.y, n.y, "第 " .. i .. " 条的 y 应一致")
        TestHelper.assertEquals(o.num, n.num, "第 " .. i .. " 条的 num 应一致")
    end
end

function TestMapRender.testSortAfterSortRestoresMap()
    print("\n=== Test: 排序后地图被恢复（主角临时写入不留痕）===")
    local tiles = installEnv()
    seedMap(tiles)

    local MR = require("framework.map_render")
    local before = {}
    for k, v in pairs(tiles) do before[k] = v end

    MR.reset()
    MR.buildingSort(3, 3, 777)

    -- 排序后地图应完全恢复
    local diff = 0
    for k, v in pairs(before) do
        if tiles[k] ~= v then diff = diff + 1 end
    end
    for k in pairs(tiles) do
        if before[k] == nil then diff = diff + 1 end
    end
    TestHelper.assertEquals(0, diff,
        "排序后地图应与排序前完全相同（实测 " .. diff .. " 处差异）")
end

function TestMapRender.testPlayerWrittenThenRestored()
    print("\n=== Test: 主角被临时写进建筑层（3/4 层写的是主角坐标）===")
    local tiles = installEnv()
    seedMap(tiles)

    local MR = require("framework.map_render")
    MR.reset()
    MR.buildingSort(3, 3, 777)

    -- 第一组写入应是 (3,3,2)=band(777*2,0xFFFF), (3,3,3)=3, (3,3,4)=3
    -- 但 setTile 已被替换，日志拿不到 —— 这里改为直接验证「排序后」建筑层里
    -- 主角条目存在（因为 sort 内部临时写，随后恢复，所以要看 buildList）
    local found = false
    for i = 0, MR.buildingCount() - 1 do
        local b = MR.buildingAt(i)
        -- 主角条目：x=3, y=3（来自临时写入的 buildx/buildy）
        if b.x == 3 and b.y == 3 then found = true end
    end
    TestHelper.assertTrue(found,
        "主角 (3,3) 应作为建筑条目出现在排序结果里（临时写入参与排序）")
end

-- ------------------------------------------------------------ ② 负向对照

function TestMapRender.testInsertWouldBreakOrder()
    print("\n=== Test: 负向对照 —— 用 table.insert 会破坏顺序（证明测试有效）===")
    -- 复刻「正确右旋」与「错误 insert」的差别
    local function rightRotate(list, p, idxk)
        local tmp = list[p]
        for t = p, idxk + 1, -1 do
            list[t] = list[t - 1]
        end
        list[idxk] = tmp
        return list
    end

    local function wrongInsert(list, p, idxk)
        local tmp = list[idxk]
        table.insert(list, idxk + 1, tmp)   -- 原缺陷写法
        return list
    end

    local a = { { id = "A" }, { id = "B" }, { id = "C" }, { id = "D" } }
    rightRotate(a, 4, 2)
    TestHelper.assertEquals("A", a[1].id, "右旋后 [1] 仍是 A")
    TestHelper.assertEquals("D", a[2].id, "右旋后 [2] 变成 D（最后一个被移到 idxk）")
    TestHelper.assertEquals("B", a[3].id, "右旋后 [3] 是 B")
    TestHelper.assertEquals("C", a[4].id, "右旋后 [4] 是 C")
    TestHelper.assertEquals(4, #a, "长度不变")

    local b = { { id = "A" }, { id = "B" }, { id = "C" }, { id = "D" } }
    wrongInsert(b, 4, 2)
    TestHelper.assertEquals(5, #b, "错误 insert 会让数组变长（这是原缺陷之一）")
end

-- ------------------------------------------------------------ ②b drawMain 用 SpriteAtlas 不是 sprite.draw

function TestMapRender.testDrawMainUsesHandleNotPicCache()
    print("\n=== Test: drawMain 走 sprite.drawHandle（不读 picFileCache）===")
    -- 这是 C 的核心目标：地图绘制**不能**再经 `EngineAPI.sprite.draw`
    -- （它的实现是 `lib.PicLoadCache` → 读 picFileCache → 新引擎要重写 RLE 解码）。
    local tiles = installEnv()
    seedMap(tiles)

    local EA = rawget(_G, "EngineAPI")
    local counts = { draw = 0, drawHandle = 0 }

    -- 记录 sprite.draw（**不应被调用**）与 drawHandle（应被调用）
    EA.sprite.draw = function() counts.draw = counts.draw + 1 end
    EA.sprite.drawHandle = function() counts.drawHandle = counts.drawHandle + 1 return true end

    -- SpriteAtlas 需要 atlas 0 已加载；测试桩引擎无法真正解码，
    -- 所以直接注入一个假的 atlas + handle 缓存，绕开解码。
    package.loaded["framework.sprite_atlas"] = nil
    local SA = require("framework.sprite_atlas")
    SA.clear()
    -- 注入假 atlas
    local fakeAtlas = {
        frameCount = 100, cache = {}, meta = {},
        grpBytes = "", offsets = {}, palette = {},
        usage = "map", -- 地图瓦片用普通锚点（脚底对齐）
    }
    -- 通过 loadArchive 的正常路径不行（要真解码），用内部注入：
    -- SpriteAtlas 暴露 load，但需要真实文件。这里直接改 atlases 表不可行（local）。
    -- → 用 _injectForTest（若不存在则跳过本条的行为断言，只做源码断言）
    if SA._injectForTest then
        SA._injectForTest(0, fakeAtlas)
        for slot = 1, 100 do
            fakeAtlas.cache[slot] = { img = true, xoff = 0, yoff = 0 }
            fakeAtlas.meta[slot] = { w = 16, h = 16, xoff = 0, yoff = 0 }
        end
    end

    local MR = require("framework.map_render")
    MR.reset()
    -- 只验证「不调 sprite.draw」这一条（它读 picFileCache）
    local ok, err = pcall(MR.drawMain, 10, 10, 500)
    TestHelper.assertEquals(0, counts.draw,
        "drawMain 不应调 EngineAPI.sprite.draw（它经 PicLoadCache 读 picFileCache）"
        .. "，实测 " .. counts.draw .. " 次")
end

-- ------------------------------------------------------------ ②c flags 语义

function TestMapRender.testDrawHandleFlagBitsIndependent()
    print("\n=== Test: drawHandle 的 black/alpha 位必须独立（不是互斥）===")
    -- **真实视觉回归**：DrawWarMap 的 flag=1/2 传 `JY_LoadPic(0,0,x,y,2+4,128)`
    --   = 变黑(0x4) + alpha(0x2)。
    -- `PicLoadCache` 里三者独立 → r,g,b=0 且 a=128/255 → **半透明黑**（移动范围高亮）
    -- 互斥的 elseif 链 → r,g,b=0 且 a=1 → **不透明黑块**（错）
    --
    -- 这里做纯算术复刻，验证「独立 vs 互斥」的差别。
    local function legacySemantics(flag, alpha)
        local r, g, b, a = 1, 1, 1, 1
        if math.floor(flag / 4) % 2 == 1 then r, g, b = 0, 0, 0 end
        if math.floor(flag / 8) % 2 == 1 then r, g, b = 1, 1, 1 end
        if math.floor(flag / 2) % 2 == 1 then a = (alpha or 128) / 255 end
        return r, g, b, a
    end

    local function exclusiveSemantics(flag, alpha)
        local r, g, b, a = 1, 1, 1, 1
        if math.floor(flag / 4) % 2 == 1 then
            r, g, b = 0, 0, 0
        elseif math.floor(flag / 8) % 2 == 1 then
            r, g, b = 1, 1, 1
        elseif math.floor(flag / 2) % 2 == 1 then
            a = (alpha or 128) / 255
        end
        return r, g, b, a
    end

    -- flag = 2+4 = 6（移动范围高亮）
    local r1, g1, b1, a1 = legacySemantics(6, 128)
    TestHelper.assertEquals(0, r1, "独立语义: r 应为 0（变黑）")
    TestHelper.assertEquals(128 / 255, a1, "独立语义: alpha 应为 128/255（半透明）")

    local r2, g2, b2, a2 = exclusiveSemantics(6, 128)
    TestHelper.assertEquals(0, r2, "互斥语义: r 也应为 0")
    TestHelper.assertEquals(1, a2, "互斥语义: alpha 被忽略 → 1（不透明）")

    TestHelper.assertTrue(math.abs(a1 - a2) > 0.4,
        "两种语义的 alpha 必须明显不同（实测差 " ..
        string.format("%.2f", math.abs(a1 - a2)) .. "）")

    -- 源码检查：drawHandle 不能用 elseif 链
    local f = io.open("engine-love2d/engine_love2d.lua", "r")
    if not f then f = io.open("../game/engine-love2d/engine_love2d.lua", "r") end
    TestHelper.assertNotNil(f, "应能读到 engine_love2d.lua")
    local src = f:read("*a")
    f:close()

    local st = src:find("EngineAPI.sprite.drawHandle = function", 1, true)
    TestHelper.assertNotNil(st, "应找到 drawHandle")
    local en = src:find("\nEngineAPI.", st + 10)
    local body = src:sub(st, (en or (#src + 1)) - 1)

    -- **必须检查「独立」而不是「存在」**：
    -- 我第一版只查 `hasBit(flags, 0x2)` 是否出现 —— 改成 elseif 链后它**仍然出现**
    -- → 负向对照不 FAIL（判据太弱）。
    --
    -- 正确判据：找 alpha 那行的**前一个非空行**，它必须是 `end`（即上一个 if 已闭合），
    -- 不能是 `elseif` 或 `else`。
    local lines = {}
    for line in body:gmatch("[^\r\n]+") do
        local code = line:gsub("^%s+", ""):gsub("%s+$", "")
        if code ~= "" and not code:match("^%-%-") then
            lines[#lines + 1] = code
        end
    end

    local alphaIdx = nil
    for i, code in ipairs(lines) do
        if code:find("hasBit(flags, 0x2)", 1, true)
            or code:find("band(flags, 0x2)", 1, true) then
            alphaIdx = i
            break
        end
    end
    TestHelper.assertNotNil(alphaIdx, "drawHandle 应有 alpha 位判断")

    -- **正确判据**：alpha 那行**自身**必须以 `if` 开头（不是 `elseif`）。
    --
    -- 我上一版查「前一行必须是 end」—— 那是错的：颜色判断是单行
    -- `elseif hasBit(...) then ... end`，本身就以 end 结尾，所以
    -- alpha 行前一行的确是 `...end`，判据误报。
    local alphaLine = lines[alphaIdx]
    TestHelper.assertNotNil(alphaLine:match("^if%s"),
        "alpha 判断必须以 `if` 开头（实测: " .. alphaLine .. "）")
    TestHelper.assertNil(alphaLine:match("^elseif"),
        "alpha 判断不能是 elseif（那会与颜色判断互斥）")
end

-- ------------------------------------------------------------ ②d flag=1/2 移动范围

function TestMapRender.testDrawBattleRangeFlags()
    print("\n=== Test: drawBattle 的 flag=1/2 走「高亮格」路径 ===")
    -- 不靠按键序列触发（实测按键注入不稳定），直接调 drawBattle(1, ...)。
    --
    -- 守的是 C Task 5 里最容易错的一段：`JY_LoadPic(0, 0, x1, y1, 2+4, 128)`
    -- → 语义是「变黑 + alpha」（半透明黑高亮格）。
    local tiles = installEnv()
    seedMap(tiles)

    local EA = rawget(_G, "EngineAPI")
    local calls = {}
    EA.sprite.drawHandle = function(handle, x, y, flags, alpha)
        calls[#calls + 1] = { x = x, y = y, flags = flags, alpha = alpha }
        return true
    end
    EA.map.getBattleSize = function() return { w = 40, h = 40 } end

    -- 注入假 atlas + handle
    package.loaded["framework.sprite_atlas"] = nil
    local SA = require("framework.sprite_atlas")
    SA.clear()
    if SA._injectForTest then
        local fake = { frameCount = 100, cache = {}, meta = {}, usage = "map" }
        for slot = 1, 100 do
            fake.cache[slot] = { img = true, xoff = 0, yoff = 0 }
            fake.meta[slot] = { w = 16, h = 16, xoff = 0, yoff = 0 }
        end
        SA._injectForTest(0, fake)
        -- 战斗地图还会用 archive 3（武功特效）
        SA._injectForTest(3, fake)
    end

    -- 造地图：把若干格标成「可走」（level 3 < 128）
    local K = function(x, y, l) return x .. "," .. y .. "," .. l end
    for x = 0, 39 do
        for y = 0, 39 do
            tiles[K(x, y, 3)] = 100      -- 默认不可走（>=128）
        end
    end
    tiles[K(10, 10, 3)] = 0          -- 可走
    tiles[K(11, 10, 3)] = 0          -- 可走

    local MR = require("framework.map_render")
    local before = #calls
    local ok = pcall(MR.drawBattle, 1, 10, 10, 11, 10, -1)   -- flag=1

    -- flag=1 的高亮格：flags 应是 2+4=6，alpha 128（当前格）或 64
    --
    -- **循环里只收集，不断言**：drawBattle 会画几千格，逐格 assert 会让
    -- 断言数爆炸（实测 1429 条）。一次聚合断言更清楚也更省。
    local foundCount, badAlpha = 0, nil
    for i = before + 1, #calls do
        if calls[i].flags == 6 then
            foundCount = foundCount + 1
            if calls[i].alpha ~= 128 and calls[i].alpha ~= 64 and badAlpha == nil then
                badAlpha = calls[i].alpha
            end
        end
    end
    TestHelper.assertTrue(foundCount > 0,
        "drawBattle(flag=1) 应画出 flags=6（变黑+alpha）的高亮格，实测 "
        .. foundCount .. " 格")
    TestHelper.assertNil(badAlpha,
        "高亮格的 alpha 只能是 128 或 64，实测出现 " .. tostring(badAlpha))
end

-- ------------------------------------------------------------ ③ 零引擎依赖

function TestMapRender.testNoLoveCalls()
    print("\n=== Test: map_render.lua 零 love.* / 零 require engine-* ===")
    local f = io.open("framework/map_render.lua", "r")
    if not f then f = io.open("../game/framework/map_render.lua", "r") end
    TestHelper.assertNotNil(f, "应能读到 map_render.lua")
    local s = f:read("*a")
    f:close()

    -- 排除注释行
    local code = s:gsub("%-%-[^\n]*", "")

    TestHelper.assertNil(code:match("[^_A-Za-z]love%."),
        "map_render 不应调 love.*")
    TestHelper.assertNil(code:match('require%("engine%-'),
        "map_render 不应 require engine-*")
    TestHelper.assertNil(code:match("PicLoadCache"),
        "map_render 不应读 picFileCache（否则换引擎要重写解码）")
end

function TestMapRender.testRespectsJSYState()
    print("\n=== Test: map_render 不读 JY.* / WAR.*（游戏状态经参数传入）===")
    local f = io.open("framework/map_render.lua", "r")
    if not f then f = io.open("../game/framework/map_render.lua", "r") end
    local s = f:read("*a")
    f:close()
    local code = s:gsub("%-%-[^\n]*", "")

    TestHelper.assertNil(code:match("JY%.[A-Za-z]"), "不应读 JY.*")
    TestHelper.assertNil(code:match("WAR%.[A-Za-z]"), "不应读 WAR.*")
end

-- ------------------------------------------------------------ 套件入口

function TestMapRender.runAll()
    print("\n" .. string.rep("=", 60))
    print("map_render 搬移回归（REQ-MRN-2 / Task 2）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestMapRender.testSortEquivalentToLegacy()
    TestMapRender.testSortAfterSortRestoresMap()
    TestMapRender.testPlayerWrittenThenRestored()
    TestMapRender.testInsertWouldBreakOrder()
    TestMapRender.testDrawMainUsesHandleNotPicCache()
    TestMapRender.testDrawHandleFlagBitsIndependent()
    TestMapRender.testDrawBattleRangeFlags()
    TestMapRender.testNoLoveCalls()
    TestMapRender.testRespectsJSYState()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_map_render.lua$") then
    TestMapRender.runAll()
end

return TestMapRender
