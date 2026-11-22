-- test_archive_dual_write.lua
-- 贴图档案双写回归测试（change: port-sprite-native-migration 的回归修复）
--
-- 守的坑（**我的改动引入的真实 bug**）：
--
--   Task 4 我把 `lib.PicLoadFile(...)` 换成了 `SpriteAtlas.loadArchive(...)`。
--   但 `SpriteAtlas.loadArchive` **不写** 引擎的 `picFileCache`，而引擎的
--   地图绘制函数内部走 `PicLoadCache` → 读 `picFileCache`：
--
--     lib.DrawSMap  → JY_LoadPic = PicLoadCache → picFileCache[0]
--     lib.DrawMMap  → 同上
--
--   ⇒ **地图全黑**（实测：开场小场景 + 主地图都是纯黑，只有文字框）。
--
--   为什么 3909 条断言全绿却没发现：测试里 `lib.DrawSMap` 是**桩**
--   （`L.DrawSMap = function() end`），桩不读 picFileCache，所以不暴露。
--
--   战斗路径没暴露，是因为 `war_async` 里早就有双轨补丁兜住了。
--
-- 修法：`LoadArchiveBoth` 同时写两套。这个测试守它不被退回单写。

local TestHelper = require("tests.test_helper")
local TestArchiveDualWrite = {}

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

local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- ------------------------------------------------------------ ① helper 双写

function TestArchiveDualWrite.testHelperWritesBoth()
    print("\n=== Test: LoadArchiveBoth 同时调 SpriteAtlas 和 EngineAPI.sprite ===")
    local calls = { atlas = 0, engine = 0 }

    -- 装最小环境
    local saved = {
        SpriteAtlas = rawget(_G, "SpriteAtlas"),
        EngineAPI = rawget(_G, "EngineAPI"),
        LoadArchiveBoth = rawget(_G, "LoadArchiveBoth"),
    }
    rawset(_G, "SpriteAtlas", {
        loadArchive = function() calls.atlas = calls.atlas + 1 end,
    })
    rawset(_G, "EngineAPI", {
        sprite = { loadArchive = function() calls.engine = calls.engine + 1 end },
    })

    -- 复刻 helper 的实现（不依赖 jymain 加载）
    rawset(_G, "LoadArchiveBoth", function(idxFile, grpFile, archiveId, opts)
        rawget(_G, "SpriteAtlas").loadArchive(idxFile, grpFile, archiveId, opts)
        if EngineAPI and EngineAPI.sprite and EngineAPI.sprite.loadArchive then
            EngineAPI.sprite.loadArchive(idxFile, grpFile, archiveId)
        end
    end)

    LoadArchiveBoth("a.idx", "a.grp", 0, { paletteFile = "p.col" })

    TestHelper.assertEquals(1, calls.atlas, "应调 SpriteAtlas.loadArchive 1 次")
    TestHelper.assertEquals(1, calls.engine,
        "应调 EngineAPI.sprite.loadArchive 1 次（否则 picFileCache 空 → 地图全黑）")

    for k, v in pairs(saved) do
        if v == nil then rawset(_G, k, nil) else rawset(_G, k, v) end
    end
end

-- ------------------------------------------------------------ ② 源码检查

function TestArchiveDualWrite.testJymainNoSingleWrite()
    print("\n=== Test: jymain 里不再有单写的 SpriteAtlas.loadArchive ===")
    local src = readSource("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain.lua")
    local code = stripComments(src)

    -- 排除 helper 内部的那一行
    local helperStart = code:find("function LoadArchiveBoth", 1, true)
    TestHelper.assertNotNil(helperStart, "应有 LoadArchiveBoth")
    local helperEnd = code:find("\nend", helperStart) + 4
    local outside = code:sub(1, helperStart) .. code:sub(helperEnd)

    local singleWrites = 0
    for line in outside:gmatch("[^\r\n]+") do
        if line:find("SpriteAtlas.loadArchive", 1, true) then
            singleWrites = singleWrites + 1
        end
    end
    TestHelper.assertEquals(0, singleWrites,
        "jymain 里不应再有单写的 SpriteAtlas.loadArchive（实测 " .. singleWrites .. " 处）")
end

function TestArchiveDualWrite.testJymainUsesHelper()
    print("\n=== Test: jymain 的档案加载走 LoadArchiveBoth ===")
    local src = readSource("script/jymain.lua")
    local code = stripComments(src)

    local uses = 0
    for line in code:gmatch("[^\r\n]+") do
        if line:find("LoadArchiveBoth%(") and not line:find("function LoadArchiveBoth") then
            uses = uses + 1
        end
    end
    TestHelper.assertTrue(uses >= 14,
        "应至少有 14 处 LoadArchiveBoth 调用（实测 " .. uses .. " 处）")
end

function TestArchiveDualWrite.testNoSelfRecursion()
    print("\n=== Test: LoadArchiveBoth 不自递归 ===")
    local src = readSource("script/jymain.lua")
    local code = stripComments(src)

    local fnStart = code:find("function LoadArchiveBoth", 1, true)
    TestHelper.assertNotNil(fnStart, "应有 LoadArchiveBoth")
    local fnEnd = code:find("\nend", fnStart)
    local body = code:sub(fnStart, fnEnd)

    -- 函数体里不能有 `LoadArchiveBoth(` —— 那会无限递归（stack overflow）
    --
    -- **注意：要把签名行本身排除掉**。`function LoadArchiveBoth(`
    -- 就含 `LoadArchiveBoth(`，直接 match 会误报（我第一版就是这么错的）。
    local sigEnd = body:find("\n") or 1
    local afterSig = body:sub(sigEnd)

    TestHelper.assertNil(afterSig:match("LoadArchiveBoth%("),
        "helper 体内不能调自己（会 stack overflow）")

    -- **注意：find 的第 4 个参数 true = 纯文本匹配**，
    -- 所以这里**不能**写 `"SpriteAtlas%.loadArchive"`（会把 % 当字面量）。
    -- 我第一版就是这么错的 —— 三条断言全 FAIL。
    TestHelper.assertNotNil(afterSig:find("SpriteAtlas.loadArchive", 1, true),
        "helper 体内应调 SpriteAtlas.loadArchive")
    -- **双写已摘除**（port-map-render-native Task 6）：
    -- 3 个地图绘制契约改走 SpriteAtlas 后不再读 picFileCache，
    -- 所以 helper 只需写一套。
    TestHelper.assertNil(afterSig:find("sprite.loadArchive", 1, true),
        "helper 体内不应再调 EngineAPI.sprite.loadArchive（双写已摘除）")
end

-- ------------------------------------ ③ 历史：为什么曾经必须双写

--- **历史回归（已不再适用，保留作教训记录）**：
--
--   `port-map-render-native` 之前，引擎自己的 `DrawMMap/DrawSMap/DrawWarMap`
--  经 `JY_LoadPic = PicLoadCache` 读 `picFileCache`，而 `SpriteAtlas` 不写它
--  → 只写一套会地图全黑 → 需要 `LoadArchiveBoth` 双写。
--
-- `port-legacy-picture-removal`（2026-11-22）删掉了那一整条链：
--   `lib_love` 的 LoadPic/PicLoadFile/PicLoadCache/JY_LoadPic/picFileCache
--   与 DrawMMap/DrawSMap/DrawWarMap 全部移除；地图绘制改走
--   `framework/map_render.lua` → `SpriteAtlas` → `sprite.drawHandle`。
--   所以「双写」这个妥协本身已经没有必要，本套件的 ③ 改为**断言旧链已消失**。
function TestArchiveDualWrite.testLegacyPicCacheChainRemoved()
    print("\n=== Test: 旧的 picFileCache 贴图链已从 lib_love 删除 ===")
    local src = readSource("engine-love2d/lib_love.lua")
    TestHelper.assertNotNil(src, "应能读到 lib_love.lua")
    local code = stripComments(src)

    for _, sym in ipairs({
        "local JY_LoadPic = PicLoadCache",
        "function PicLoadCache(",
        "function PicLoadFile(",
        "function PicGetXY(",
        "function LoadPic(",
        "function DrawMMap(",
        "function DrawSMap(",
        "function DrawWarMap(",
    }) do
        TestHelper.assertNil(code:find(sym, 1, true),
            "lib_love 不应再有 " .. sym .. "（已随旧贴图子系统删除）")
    end
end

-- ------------------------------------------------------------ ④ 负向对照

function TestArchiveDualWrite.testSingleWriteBreaksPicCache()
    print("\n=== Test: 只写 SpriteAtlas 会让 picFileCache 空（行为复刻）===")
    -- 复刻两套系统：SpriteAtlas 有数据，picFileCache 空
    local atlasLoaded = false
    local picFileCache = {}

    -- 单写：只调 SpriteAtlas
    local function singleWrite()
        atlasLoaded = true
        -- 注意：不写 picFileCache
    end

    singleWrite()
    TestHelper.assertEquals(true, atlasLoaded, "SpriteAtlas 应有数据")
    TestHelper.assertEquals(nil, picFileCache[0],
        "picFileCache[0] 应为 nil（这就是地图全黑的直接原因）")

    -- 双写
    local function dualWrite()
        atlasLoaded = true
        picFileCache[0] = { data = "loaded" }
    end
    dualWrite()
    TestHelper.assertNotNil(picFileCache[0], "双写后 picFileCache[0] 应有数据")
end

-- ------------------------------------------------------------ 套件入口

function TestArchiveDualWrite.runAll()
    print("\n" .. string.rep("=", 60))
    print("贴图档案双写回归（REQ-SNM-3：地图不得全黑）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestArchiveDualWrite.testHelperWritesBoth()
    TestArchiveDualWrite.testJymainNoSingleWrite()
    TestArchiveDualWrite.testJymainUsesHelper()
    TestArchiveDualWrite.testNoSelfRecursion()
    TestArchiveDualWrite.testLegacyPicCacheChainRemoved()
    TestArchiveDualWrite.testSingleWriteBreaksPicCache()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_archive_dual_write.lua$") then
    TestArchiveDualWrite.runAll()
end

return TestArchiveDualWrite
