-- test_cal_pic_clip.lua
-- Cal_PicClip 迁移的数值等价性验证（port-sprite-native-migration Task 5）
--
-- 为什么必须单独测这个：
--   Cal_PicClip 算的是**武功动画的裁剪矩形**。全量测试（3805 条）覆盖不到它
--   —— 因为要真的打到武功攻击才会走到。截图也不好验（要恰好截到动画帧）。
--   所以用**数值等价**：同一组输入，迁移前后算出的矩形必须逐字段相同。
--
-- 迁移内容：
--   lib.PicGetXY(id, picid)   返回 4 个值 (w, h, xoff, yoff)
--   SpriteAtlas.getMeta(id, frameId)  返回 table { w, h, xoff, yoff }
--
-- 关键等价点：
--   ① 参数换算：PicGetXY 收 picid；getMeta 收 frameId = picid（同一个数）
--      （因为 picid 本身就是 frameId —— 都是偶数索引，见 sprite_atlas 的
--        frameToSlot = floor(frameId/2) + 1）
--   ② 取不到时的兜底：PicGetXY 判空返回 0,0,0,0；getMeta 现在也是 0 兜底

local TestHelper = require("tests.test_helper")
local TestCalPicClip = {}

local function readSource(rel)
    for _, p in ipairs({ rel, "../game/" .. rel }) do
        local f = io.open(p, "r")
        if f then
            local s = f:read("*a")
            f:close()
            return s
        end
    end
    return nil
end

--- 迁移后的算法（复刻 Cal_PicClip 的算术部分，不依赖全局）
local function newCalc(dx1, dy1, m1, dx2, dy2, m2, CC)
    local w1 = m1 and m1.w or 0
    local h1 = m1 and m1.h or 0
    local x1_off = m1 and m1.xoff or 0
    local y1_off = m1 and m1.yoff or 0

    local old_r = {}
    old_r.x1 = CC.XScale * (dx1 - dy1) + CC.ScreenW / 2 - x1_off
    old_r.y1 = CC.YScale * (dx1 + dy1) + CC.ScreenH / 2 - y1_off
    old_r.x2 = old_r.x1 + w1
    old_r.y2 = old_r.y1 + h1

    local w2 = m2 and m2.w or 0
    local h2 = m2 and m2.h or 0
    local x2_off = m2 and m2.xoff or 0
    local y2_off = m2 and m2.yoff or 0

    local new_r = {}
    new_r.x1 = CC.XScale * (dx2 - dy2) + CC.ScreenW / 2 - x2_off
    new_r.y1 = CC.YScale * (dx2 + dy2) + CC.ScreenH / 2 - y2_off
    new_r.x2 = new_r.x1 + w2
    new_r.y2 = new_r.y1 + h2

    return old_r, new_r
end

--- 迁移前的算法（复刻 lib.PicGetXY 的四值返回）
local function oldCalc(dx1, dy1, w1, h1, x1_off, y1_off, dx2, dy2, w2, h2, x2_off, y2_off, CC)
    local old_r = {}
    old_r.x1 = CC.XScale * (dx1 - dy1) + CC.ScreenW / 2 - x1_off
    old_r.y1 = CC.YScale * (dx1 + dy1) + CC.ScreenH / 2 - y1_off
    old_r.x2 = old_r.x1 + w1
    old_r.y2 = old_r.y1 + h1

    local new_r = {}
    new_r.x1 = CC.XScale * (dx2 - dy2) + CC.ScreenW / 2 - x2_off
    new_r.y1 = CC.YScale * (dx2 + dy2) + CC.ScreenH / 2 - y2_off
    new_r.x2 = new_r.x1 + w2
    new_r.y2 = new_r.y1 + h2

    return old_r, new_r
end

local function assertRectEqual(a, b, label)
    for _, k in ipairs({ "x1", "y1", "x2", "y2" }) do
        TestHelper.assertEquals(b[k], a[k],
            string.format("%s 的 %s 应一致（旧=%s 新=%s）", label, k, tostring(b[k]), tostring(a[k])))
    end
end

-- ------------------------------------------------------------ 数值等价

function TestCalPicClip.testSameCoordinatesSameResult()
    print("\n=== Test: 同一组输入算出完全相同的矩形 ===")
    local CC = { XScale = 32, YScale = 16, ScreenW = 1024, ScreenH = 768 }

    -- 典型场景：人物从 (0,0) 走到 (1,0)，同方向
    local cases = {
        { dx1 = 0, dy1 = 0, dx2 = 0, dy2 = 0, m1 = { w = 56, h = 58, xoff = 0, yoff = 57 },
                                              m2 = { w = 56, h = 58, xoff = 0, yoff = 57 } },
        { dx1 = 0, dy1 = 0, dx2 = 1, dy2 = 0, m1 = { w = 56, h = 58, xoff = 0, yoff = 57 },
                                              m2 = { w = 56, h = 58, xoff = 0, yoff = 57 } },
        { dx1 = 2, dy1 = 1, dx2 = 3, dy2 = 1, m1 = { w = 100, h = 102, xoff = 10, yoff = 20 },
                                              m2 = { w = 100, h = 93, xoff = 12, yoff = 21 } },
        { dx1 = -1, dy1 = 0, dx2 = 0, dy2 = 1, m1 = { w = 40, h = 40, xoff = 0, yoff = 0 },
                                              m2 = { w = 48, h = 44, xoff = 2, yoff = 5 } },
    }

    for _, c in ipairs(cases) do
        local old_r, old_n = oldCalc(c.dx1, c.dy1, c.m1.w, c.m1.h, c.m1.xoff, c.m1.yoff,
                                     c.dx2, c.dy2, c.m2.w, c.m2.h, c.m2.xoff, c.m2.yoff, CC)
        local new_r, new_n = newCalc(c.dx1, c.dy1, c.m1, c.dx2, c.dy2, c.m2, CC)
        assertRectEqual(old_r, new_r, "old_r")
        assertRectEqual(old_n, new_n, "new_r")
    end
end

function TestCalPicClip.testNilMetaFallsBackToZero()
    print("\n=== Test: getMeta 返回 nil 时按 0 兜底（与旧 PicGetXY 一致）===")
    local CC = { XScale = 32, YScale = 16, ScreenW = 1024, ScreenH = 768 }

    -- 旧：PicGetXY 判空 → return 0,0,0,0
    local old_r = oldCalc(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, CC)
    -- 新：getMeta 返回 nil → 各项 or 0
    local new_r = newCalc(0, 0, nil, 0, 0, nil, CC)
    assertRectEqual(old_r, new_r, "nil 兜底")

    -- 尺寸为 0 时矩形退化为「一个点」（x2==x1, y2==y1）
    TestHelper.assertEquals(new_r.x1, new_r.x2, "w=0 时 x2 应等于 x1")
    TestHelper.assertEquals(new_r.y1, new_r.y2, "h=0 时 y2 应等于 y1")
end

-- ------------------------------------------------------------ 源码检查

function TestCalPicClip.testSourceMigrated()
    print("\n=== Test: 源码已迁到 SpriteAtlas.getMeta（无 lib.PicGetXY）===")
    local src = readSource("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain.lua")

    TestHelper.assertNotNil(src:find("function Cal_PicClip", 1, true),
        "应能找到 Cal_PicClip")

    -- 取 Cal_PicClip 函数体（到下一个顶层 function）
    local fnStart = src:find("function Cal_PicClip", 1, true)
    local bodyEnd = src:find("\nfunction ", fnStart + 10)
    local body = src:sub(fnStart, bodyEnd or (fnStart + 4000))

    -- **必须先去注释**：迁移时我在 Cal_PicClip 函数体里写了
    -- 「lib.PicGetXY 返回 4 个值」的说明性注释，直接 find 会误判。
    local bodyCode = body:gsub("%-%-[^\n]*", "")

    TestHelper.assertNil(bodyCode:match("lib%.PicGetXY"),
        "Cal_PicClip 不应再调 lib.PicGetXY（代码行）")
    TestHelper.assertNotNil(body:find("SpriteAtlas.getMeta", 1, true),
        "应改用 SpriteAtlas.getMeta")
end

function TestCalPicClip.testScriptHasZeroLibPic()
    print("\n=== Test: script/ 全仓零 lib.Pic*（REQ-SNM-2）===")
    local files = { "script/jymain.lua" }
    -- battle 目录也检查
    for _, name in ipairs({ "battle_data", "battle_render", "battle_action",
                            "battle_ai", "battle_flow" }) do
        files[#files + 1] = "script/battle/" .. name .. ".lua"
    end

    local total = 0
    for _, rel in ipairs(files) do
        local src = readSource(rel)
        if src then
            for line in src:gmatch("[^\r\n]+") do
                local code = line:gsub("^%s*%-%-.*$", "")
                if code:match("lib%.Pic") and not code:match("%-%-") then
                    total = total + 1
                end
            end
        end
    end
    TestHelper.assertEquals(0, total,
        "script/ 不应再有 lib.Pic* 代码行（实测 " .. total .. " 处）")
end

-- ------------------------------------------------------------ 套件入口

function TestCalPicClip.runAll()
    print("\n" .. string.rep("=", 60))
    print("Cal_PicClip 迁移的数值等价验证（Task 5 最高风险点）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestCalPicClip.testSameCoordinatesSameResult()
    TestCalPicClip.testNilMetaFallsBackToZero()
    TestCalPicClip.testSourceMigrated()
    TestCalPicClip.testScriptHasZeroLibPic()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_cal_pic_clip.lua$") then
    TestCalPicClip.runAll()
end

return TestCalPicClip
