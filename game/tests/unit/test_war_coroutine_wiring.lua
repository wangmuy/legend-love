-- test_war_coroutine_wiring.lua
-- 战斗协程"名字解析"回归测试（battle-extensibility 阶段 2C 的实机 bug）
--
-- 守的坑（**实机才能发现，单测抓不到**）：
--   协程从 framework/war_async.lua 搬到 script/battle/battle_flow_coroutines.lua 后，
--   war_async 里那 20 个 `local War_XCoroutine` 前向声明变成了 **nil upvalue**，
--   而 `WarMainCoroutine` 的战斗主循环还在裸调用它们：
--
--       r = War_ManualCoroutine()      -- ← nil upvalue，运行时崩
--       War_SettlementCoroutine(n)     -- ← 同上
--
--   症状：战斗一开始就抛 "attempt to call upvalue 'War_ManualCoroutine'
--   (a nil value)"，玩家看到黑屏回主菜单。
--
-- 为什么之前的测试没抓到：
--   所有测试都**直接调用** `War_ManualCoroutine`（`package.loaded` 里的模块，
--   或 `WarAsync.War_ManualCoroutine` 转发），没有一个真的跑
--   `WarMainCoroutine` —— 那需要完整贴图档案 + 协程调度 + 按键输入。
--
-- 本测试的做法：**静态检查** war_async 的源码，确认没有裸调用协程名。
-- 这比"跑一遍战斗"便宜得多，而且能锁死这类回归。

local TestHelper = require("tests.test_helper")
local TestWarCoroutineWiring = {}

-- 20 个协程名（转发的全部条目）
local COROUTINE_NAMES = {
    "War_ManualCoroutine", "War_Manual_SubCoroutine", "War_AutoMoveCoroutine",
    "War_AutoCoroutine", "War_SettlementCoroutine", "War_GameOverCoroutine",
    "War_AttackCoroutine", "War_Fight_ExecuteCoroutine", "War_Fight_SubCoroutine",
    "War_MoveCoroutine", "War_MovePersonCoroutine", "War_ShowFightCoroutine",
    "War_PoisonCoroutine", "War_DecPoisonCoroutine", "War_DoctorCoroutine",
    "War_ExecuteMenu_SubCoroutine", "War_ExecuteMenuCoroutine",
    "War_ThingMenuCoroutine", "War_StatusMenuCoroutine", "SelectTargetCoroutine",
}

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

-- 去掉注释：避免"注释里提到 War_ManualCoroutine()"被误判为裸调用
local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- ------------------------------------------------------------ 无裸调用

function TestWarCoroutineWiring.testNoBareCoroutineCallsInWarAsync()
    print("\n=== Test: war_async 里没有裸调用协程名（必须走 WarAsync.* 转发）===")
    local src = readSource("framework/war_async.lua")
    TestHelper.assertNotNil(src, "应能读到 framework/war_async.lua")
    local code = stripComments(src)

    local bad = {}
    for _, name in ipairs(COROUTINE_NAMES) do
        -- 裸调用 = 名字后面紧跟 "("，且前面不是 "." 或 ":"（那才是转发/方法调用）
        -- Lua 模式不支持 lookbehind，用两次 find 手工排除
        local pos = 1
        while true do
            local a = code:find(name .. "(", pos, true)
            if not a then break end
            local ch = code:sub(a - 1, a - 1)
            if ch ~= "." and ch ~= ":" then
                bad[#bad + 1] = name
                break
            end
            pos = a + #name
        end
    end

    TestHelper.assertEquals(0, #bad,
        "war_async 有裸调用（应为 WarAsync.XXX）：" .. table.concat(bad, ", "))
end

function TestWarCoroutineWiring.testNoNilForwardDeclarationsRemain()
    print("\n=== Test: 旧的 local 前向声明已删除（否则会变成 nil upvalue）===")
    local src = readSource("framework/war_async.lua")
    local code = stripComments(src)

    -- 原来有 `local War_ManualCoroutine, War_AutoCoroutine, War_SettlementCoroutine`
    -- 这种"只声明不赋值"的行。搬走实现后它们永远是 nil。
    local bad = 0
    for line in code:gmatch("[^\r\n]+") do
        local t = line:gsub("^%s*", "")
        if t:match("^local%s+War_") then
            -- 允许 `local X = 值`（有赋值），只禁止纯声明
            if not t:match("^local%s+War_[%w_]+%s*=") then
                bad = bad + 1
            end
        end
    end
    TestHelper.assertEquals(0, bad,
        "还有 " .. bad .. " 行纯前向声明（搬走后它们恒为 nil）")
end

-- ------------------------------------------------------------ 转发可用

function TestWarCoroutineWiring.testAllForwardsResolve()
    print("\n=== Test: 20 个转发都能解析到真函数 ===")
    -- 先确保协程模块已加载（模拟 jymain 的加载段）
    local ok = pcall(require, "script.battle.battle_flow_coroutines")
    if not ok then
        -- 测试环境可能没有 package.path 指向 script/，用 loadfile 兜底
        local chunk = loadfile("script/battle/battle_flow_coroutines.lua")
        if chunk then pcall(chunk) end
    end

    local WA = require("framework.war_async")
    local bad = {}
    for _, name in ipairs(COROUTINE_NAMES) do
        if type(WA[name]) ~= "function" then
            bad[#bad + 1] = name
        end
    end
    TestHelper.assertEquals(0, #bad,
        "转发缺失：" .. table.concat(bad, ", "))
end

function TestWarCoroutineWiring.testForwardCallsThrough()
    print("\n=== Test: 转发真的能调到 script 实现（不是空壳）===")
    local WA = require("framework.war_async")
    local mod = package.loaded["script.battle.battle_flow_coroutines"]
    TestHelper.assertNotNil(mod, "协程模块应在 package.loaded 里")

    -- 转发应指向同一个函数对象（惰性查表，取到的是模块里的那个）
    local same = 0
    for _, name in ipairs({ "War_ManualCoroutine", "War_AutoCoroutine",
                           "War_SettlementCoroutine", "War_MoveCoroutine" }) do
        if type(mod[name]) == "function" then same = same + 1 end
    end
    TestHelper.assertEquals(4, same, "模块应导出这 4 个核心协程")
end

-- ------------------------------------------------------------ 双轨贴图

function TestWarCoroutineWiring.testWarMainLoadsBothSpriteSystems()
    print("\n=== Test: WarMainCoroutine 同时加载两套贴图系统 ===")
    -- **实机 bug**：只用 SpriteAtlas.loadArchive 时 picFileCache 是空的，
    -- 而 battle_render.lua 的 lib.PicGetXY / lib.PicLoadCache 读 picFileCache
    -- → WarShowHead 崩（PicGetXY: attempt to index a nil value）。
    local src = readSource("framework/war_async.lua")
    local code = stripComments(src)

    TestHelper.assertNotNil(code:find("SpriteAtlas.loadArchive", 1, true),
        "应有 SpriteAtlas.loadArchive（新解码链）")
    TestHelper.assertNotNil(code:find("sprite.loadArchive", 1, true),
        "应有 EngineAPI.sprite.loadArchive（写 picFileCache，供 lib.Pic* 用）")
end

function TestWarCoroutineWiring.testBattleRenderMigratedToNative()
    print("\n=== Test: battle_render 已迁到 SpriteAtlas（双轨补丁的前提消失）===")
    -- **这条断言原来方向是反的**（上一轮刻意留的"现状记录型 canary"）：
    --   原文断言「battle_render 应仍用 lib.Pic* / DrawWarMap」，注释写着：
    --   「如果哪天有人把 battle_render 迁到 SpriteAtlas，这条会失败 ——
    --    那时说明可以删掉 war_async 的双轨补丁，是个值得注意的信号」。
    --
    -- 现在它**按设计触发了**（port-sprite-native-migration Task 2 完成迁移），
    -- 所以按当初的约定反转断言方向（断言"已迁"），而不是删掉这条测试。
    -- 保留价值：若有人回退迁移（重新引入 lib.Pic*），它会 FAIL。
    local src = readSource("script/battle/battle_render.lua")
    TestHelper.assertNotNil(src, "应能读到 battle_render.lua")
    local code = stripComments(src)

    -- 旧系统调用必须清零
    local legacy = 0
    for _, n in ipairs({ "lib.PicGetXY", "lib.PicLoadCache", "lib.DrawWarMap" }) do
        if code:find(n, 1, true) then legacy = legacy + 1 end
    end
    TestHelper.assertEquals(0, legacy,
        "battle_render 不应再有 lib.Pic*/lib.DrawWarMap（实测命中 " .. legacy .. " 个）")

    -- 新系统调用必须存在
    TestHelper.assertNotNil(code:find("SpriteAtlas.getMeta", 1, true),
        "应改用 SpriteAtlas.getMeta（对应原 PicGetXY）")
    TestHelper.assertNotNil(code:find("SpriteAtlas.draw", 1, true),
        "应改用 SpriteAtlas.draw（对应原 PicLoadCache）")
    TestHelper.assertNotNil(code:find("EngineAPI.map.drawBattle", 1, true),
        "应改用 EngineAPI.map.drawBattle（对应原 lib.DrawWarMap）")
end

-- ------------------------------------------------------------ 套件入口

function TestWarCoroutineWiring.runAll()
    print("\n" .. string.rep("=", 60))
    print("战斗协程名字解析回归（阶段 2C 实机 bug）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestWarCoroutineWiring.testNoBareCoroutineCallsInWarAsync()
    TestWarCoroutineWiring.testNoNilForwardDeclarationsRemain()
    TestWarCoroutineWiring.testAllForwardsResolve()
    TestWarCoroutineWiring.testForwardCallsThrough()
    TestWarCoroutineWiring.testWarMainLoadsBothSpriteSystems()
    TestWarCoroutineWiring.testBattleRenderMigratedToNative()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_war_coroutine_wiring.lua$") then
    TestWarCoroutineWiring.runAll()
end

return TestWarCoroutineWiring
