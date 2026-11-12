-- test_mmap_depth.lua
-- 锁定「主地图 2.5D 遮挡关系」这一移植缺陷的修复。
--
-- 原版 legend-mac-orig/src/mainmap.c：
--   * BuildingSort() 把主角/船作为普通建筑条目插入 Build[]（区间右旋一位，
--     绝不增长数组），排序键就是 (x,y)；
--   * JY_DrawMMap() 只有 *一趟* 循环，按 Build[0..BuildNumber-1] 顺序绘制。
--   于是「主角走到大山背后」时，山在排序里排在主角之后 → 山脉遮挡主角。
--
-- 本项目曾出现两处移植偏差，二者都会破坏遮挡：
--   缺陷 A（commit 2c8a644「修复主地图主角显示问题」）：
--       DrawMMap 把主角/船从第一趟里排除，最后单独再画一趟，还加了 y_adjust=-10。
--       → 主角永远压在所有建筑之上，山/房屋永远遮不住人。
--   缺陷 B（commit 16cf358「图像显示基本OK」）：
--       BuildingSort 用 table.insert(buildList, idxk+1, tmp) 代替
--       memmove(&Build[k+1],&Build[k],...) + Build[k]=tmp，
--       → 插入点后移一位（深度顺序与原版不一致，遮挡错位），
--         且 buildList 每帧越长（长跑内存只增不减）。
--
-- 本套件用「排序签名」+「绘制次序」两条独立判据锁定修复：
--   判据 1：BuildingSort 在 8 个坐标上的 (x,y,num) 序列签名，
--           与 mainmap.c 逐字移植得到的期望值完全一致；
--   判据 2：#buildList 多帧重复排序后保持不变（不再无限增长）；
--   判据 3：DrawMMap 实际发出的绘制序列里，主角出现在 build 层的
--           排序位置（而不是最后一位），且该位置之后仍有建筑被绘制。
--
-- 负向对照（已人工验证，见提交信息）：把任一缺陷改回去，判据 1/2/3 必失败。

local TestHelper = require("tests.test_helper")
local TestMmapDepth = {}

-- 每行：x, y, buildNumber, 排序签名, 主角排序序号,
--       主角之后仍被绘制的、与主角矩形相交的条目数
-- 期望值全部由 mainmap.c 逐字移植 + 真实帧头几何算出（见 openspec 记录）。
-- 最后一个字段是「遮挡证据」：>0 表示确实有山/房屋在主角之后绘制并压到主角身上。
local EXPECTED = {
    { 20, 19, 364, 894492441,  62, 0 }, -- 空地上，周围没有可遮挡的建筑
    { 39, 33, 475, 462916664, 177, 1 }, -- 大山背后
    { 12, 10, 287, 103988566,  20, 2 }, -- 大山背后
    { 10,  8, 276, 286728652,  20, 1 }, -- 大山背后
    { 39, 30, 438, 772636259, 165, 3 }, -- 大山背后
    { 14, 10, 294, 883141402,  30, 1 }, -- 大山背后
    { 12, 12, 309, 424577670,  24, 2 }, -- 房屋背后
    { 45, 38, 535, 222910756, 210, 2 }, -- 大山背后
}

local SIG_MOD = 1000000007
local PLAYER_PIC = 2501
local PLAYER_SPRITE = 2501 * 2 -- BuildingSort 存的是 Mypic*2

-- ---------------------------------------------------------------- 环境搭建

local harnessReady = false
local draws = {}

-- 用 mmap.idx/grp 的真实帧头（w,h,xoff,yoff）构造 getPic 桩，
-- 这样屏幕坐标是真实坐标，但不需要解码 RLE（数百张图会太慢）。
local function readFrameTable()
    local idxData = io.open("data/mmap.idx", "rb"):read("*a")
    local grpData = io.open("data/mmap.grp", "rb"):read("*a")
    local offs = {}
    -- 用 math.floor 而不是 // （整除运算符是 Lua 5.3+ 语法，5.1/LuaJIT 报错）
    for i = 1, math.floor(#idxData / 4) do
        local b1, b2, b3, b4 = idxData:byte((i - 1) * 4 + 1, (i - 1) * 4 + 4)
        offs[i] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
    return offs, grpData
end

local function buildStubPicFile()
    local offs, grpData = readFrameTable()
    local idxTbl = { 0 }
    for i = 1, #offs do idxTbl[i + 1] = offs[i] end

    local frames = {}
    local function frameOf(picnum)
        if frames[picnum] ~= nil then return frames[picnum] or nil end
        local slot = math.floor(picnum / 2)
        local a = 0
        if slot >= 1 then a = offs[slot] end
        local b = offs[slot + 1] or #grpData
        local buf = grpData:sub(a + 1, b)
        local r = false
        if #buf >= 8 then
            local w = buf:byte(1) + buf:byte(2) * 256
            local h = buf:byte(3) + buf:byte(4) * 256
            local xo = buf:byte(5) + buf:byte(6) * 256
            local yo = buf:byte(7) + buf:byte(8) * 256
            if xo > 32767 then xo = xo - 65536 end
            if yo > 32767 then yo = yo - 65536 end
            r = { w = w, h = h, xoff = xo, yoff = yo }
        end
        frames[picnum] = r
        return r or nil
    end

    return {
        idx = idxTbl,
        getPic = function(self, picid)
            local picnum = (picid - 1) * 2
            local f = frameOf(picnum)
            if not f then return nil end
            return {
                w = f.w, h = f.h, xoff = f.xoff, yoff = f.yoff,
                img = { pic = picnum, mmapFrame = true },
            }
        end,
    }, frameOf
end

local Lib      -- lib_love 模块
local frameOf  -- picnum -> {w,h,xoff,yoff}

local function bootEngine()
    if not harnessReady then
        require("tests.mod_boot_harness").setup()
        harnessReady = true
    end

    love.graphics.draw = function(img, x, y)
        if img and img.pic then draws[#draws + 1] = { pic = img.pic, x = x, y = y } end
    end
    love.graphics.setColor = function() end
    love.graphics.clear = function() end
    love.graphics.getScissor = function() return nil end
    love.graphics.setScissor = function() end
    love.graphics.rectangle = function() end
    _G.Debug = function() end

    -- 重新加载 lib_love，避免与其他套件共享 buildList / mmap 状态。
    package.loaded["engine-love2d.lib_love"] = nil
    local ok, mod = pcall(require, "engine-love2d.lib_love")
    if not ok then
        TestHelper.assertTrue(false, "加载 lib_love 失败: " .. tostring(mod))
        return nil
    end
    Lib = mod
    if not CC.MWidth then CC.MWidth, CC.MHeight = 480, 480 end
    Lib.LoadMMap(CC.MMapFile[1], CC.MMapFile[2], CC.MMapFile[3],
                 CC.MMapFile[4], CC.MMapFile[5],
                 CC.MWidth, CC.MHeight, 20, 19)
    local stub, fo = buildStubPicFile()
    frameOf = fo
    Lib.picFileCache[1] = stub
    return Lib
end

-- ---------------------------------------------------------------- 判据实现

local function buildSortSignature(x, y)
    Lib.BuildingSort(x, y, PLAYER_PIC)
    local h = 0
    for i = 1, Lib.buildNumber do
        local e = Lib.buildList[i]
        h = (h + (e.x * 7 + e.y * 131 + e.num * 65599) * i) % SIG_MOD
    end
    return Lib.buildNumber, h
end

-- 主角在 build 层里的序号（1 基）
local function playerBuildIndex()
    for i = 1, Lib.buildNumber do
        local e = Lib.buildList[i]
        if e.num == PLAYER_SPRITE then return i end
    end
    return nil
end

-- DrawMMap 发出的绘制序列里，主角是第几个「建筑层」绘制、其后还有多少条目
local function playerDrawPosition(x, y)
    draws = {}
    Lib.DrawMMap(x, y, PLAYER_PIC)
    local total = #draws
    local buildStart = total - Lib.buildNumber + 1
    local at
    for i = buildStart, total do
        if draws[i].pic == PLAYER_SPRITE then at = i end
    end
    if not at then return nil, total, buildStart end
    return at - buildStart + 1, total, buildStart
end

-- 主角矩形与「在它之后绘制」的条目矩形是否相交（屏幕坐标）
local function overlappingDrawnAfter(x, y, drawIdx, total, buildStart)
    if not drawIdx then return 0 end
    local pf = frameOf(PLAYER_SPRITE)
    local pi = buildStart + drawIdx - 1
    local startX = draws[pi].x
    local startY = draws[pi].y
    local n = 0
    for i = pi + 1, total do
        local g = frameOf(draws[i].pic)
        if g then
            local ox, oy = draws[i].x, draws[i].y
            if ox < startX + pf.w and ox + g.w > startX
                and oy < startY + pf.h and oy + g.h > startY then
                n = n + 1
            end
        end
    end
    return n
end

-- ---------------------------------------------------------------- 测试用例

-- 判据 1：BuildingSort 的排序结果必须与 mainmap.c 逐字移植完全一致。
-- 缺陷 B（table.insert 后移一位）会让这些签名全部对不上。
function TestMmapDepth.testBuildingSortMatchesOriginalOrder()
    print("\n=== Test: BuildingSort 顺序与原版 mainmap.c 一致 ===")
    if not bootEngine() then return end

    for _, exp in ipairs(EXPECTED) do
        local x, y, wantN, wantSig = exp[1], exp[2], exp[3], exp[4]
        local n, sig = buildSortSignature(x, y)
        TestHelper.assertEquals(wantN, n,
            string.format("(%d,%d) buildNumber 应与原版一致", x, y))
        TestHelper.assertEquals(wantSig, sig,
            string.format("(%d,%d) 排序序列签名应与原版一致", x, y))
    end
end

-- 判据 2：反复排序不得让 buildList 变长（原版是原地右旋）。
function TestMmapDepth.testBuildListDoesNotGrow()
    print("\n=== Test: 反复 BuildingSort 不增长 buildList ===")
    if not bootEngine() then return end
    local initial = #Lib.buildList
    for round = 1, 40 do
        local e = EXPECTED[(round - 1) % #EXPECTED + 1]
        Lib.BuildingSort(e[1], e[2], PLAYER_PIC)
    end
    TestHelper.assertEquals(initial, #Lib.buildList,
        "40 次 BuildingSort 之后 buildList 长度不应变化（原版 memmove 是原地右旋）")
end

-- 判据 3：主角必须按排序位置参与那一趟绘制，不能最后单独补画。
-- 缺陷 A（两趟绘制 + 排除主角）会让 drawIdx == buildNumber 且 overlappingAfter == 0。
function TestMmapDepth.testPlayerDrawnAtSortedDepth()
    print("\n=== Test: 主角按排序深度绘制（不是最后补画）===")
    if not bootEngine() then return end

    local occluded = 0
    for _, exp in ipairs(EXPECTED) do
        local x, y, wantIdx, wantOverlap = exp[1], exp[2], exp[5], exp[6]
        local drawIdx, total, buildStart = playerDrawPosition(x, y)
        TestHelper.assertNotNil(drawIdx,
            string.format("(%d,%d) 主角应出现在建筑层绘制序列中", x, y))
        if drawIdx then
            TestHelper.assertEquals(playerBuildIndex(), drawIdx,
                string.format("(%d,%d) 主角绘制位置应等于其排序序号", x, y))
            TestHelper.assertEquals(wantIdx, drawIdx,
                string.format("(%d,%d) 主角排序序号应与原版一致", x, y))
            local after = overlappingDrawnAfter(x, y, drawIdx, total, buildStart)
            TestHelper.assertEquals(wantOverlap, after,
                string.format("(%d,%d) 主角之后与其相交的绘制条目数应与原版一致", x, y))
            if after > 0 then occluded = occluded + 1 end
        end
    end
    -- 若主角被抬到最上层，上式全部会变成 0；这一条专门兜住这种退化。
    TestHelper.assertEquals(7, occluded,
        "8 个采样点中应有 7 个存在「主角之后绘制且压到主角」的条目")
end

-- 判据 3 补充：大范围内每个位置都必须「有东西画在主角之后」，
-- 否则说明主角被系统性抬到最上层。
function TestMmapDepth.testNoPositionDrawsPlayerLast()
    print("\n=== Test: 扫描 20 个位置，主角从不被放到最上层 ===")
    if not bootEngine() then return end

    local checked, bad = 0, {}
    for gy = 8, 44, 9 do
        for gx = 10, 46, 9 do
            local drawIdx = playerDrawPosition(gx, gy)
            if drawIdx then
                checked = checked + 1
                if drawIdx == Lib.buildNumber then
                    bad[#bad + 1] = string.format("(%d,%d)", gx, gy)
                end
            end
        end
    end
    TestHelper.assertTrue(checked >= 10,
        "扫描应覆盖至少 10 个有主角条目的位置（实际 " .. checked .. "）")
    TestHelper.assertEquals(0, #bad,
        "不应有位置把主角画在建筑层最后：" .. table.concat(bad, " "))
end

function TestMmapDepth.runAll()
    print("\n" .. string.rep("=", 60))
    print("主地图 2.5D 遮挡关系测试")
    print(string.rep("=", 60))

    local savedMt = getmetatable(_G)
    setmetatable(_G, nil)

    TestMmapDepth.testBuildingSortMatchesOriginalOrder()
    TestMmapDepth.testBuildListDoesNotGrow()
    TestMmapDepth.testPlayerDrawnAtSortedDepth()
    TestMmapDepth.testNoPositionDrawsPlayerLast()

    setmetatable(_G, savedMt)

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestMmapDepth
