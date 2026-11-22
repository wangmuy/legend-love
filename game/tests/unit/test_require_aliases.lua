-- test_require_aliases.lua
-- 裸名 require 别名注册的回归测试（change: engine-portability-alias）
--
-- 守的坑（实测确认）：
--   ① 别名注册原来只写在 LÖVE 引擎实现里，契约与文档都没提 → 照契约
--      新写一个引擎（模拟「Godot 宿主」）时，启动就死在
--      `module 'lib_file' not found`，而报错点在 script 层。
--      现在唯一来源是 framework/require_aliases.lua，**require 即自动 install**。
--   ② 幂等：重复 install 不得报错，也不得覆盖已有的 package.preload
--      （Web 引擎从字符串装载模块，覆盖它等于让 web 端模块源失效）。
--   ③ 负向对照：某别名被清掉后，再 install() 必须**恢复**它 ——
--      否则「模块已加载过」会让后续引擎悄悄失去别名。

local TestHelper = require("tests.test_helper")
local TestRequireAliases = {}

-- 契约里承诺的 5 个别名（与 framework/require_aliases.lua 的 ALIASES 一致）
local EXPECTED = {
    "lib_file",
    "script_loader",
    "coroutine_scheduler",
    "war_async",
    "event_executor",
}

--- 备份别名当前状态，便于每步之后恢复（测试之间不互相污染）
local function snapshot()
    local saved = {}
    for _, name in ipairs(EXPECTED) do
        saved[name] = package.preload[name]
    end
    return saved
end

local function restore(saved)
    for _, name in ipairs(EXPECTED) do
        package.preload[name] = saved[name]
    end
end

-- ------------------------------------------------------------ ① 5 个别名可解析

function TestRequireAliases.testInstallProvidesAllAliases()
    print("\n=== Test: require 别名模块后 5 个别名都能 require ===")
    local saved = snapshot()

    -- 模拟「新引擎第一次启动」：先把别名全部清掉
    for _, name in ipairs(EXPECTED) do
        package.preload[name] = nil
    end

    -- 只 require 一次（模块被 require 时自动 install）
    package.loaded["framework.require_aliases"] = nil
    local RA = require("framework.require_aliases")
    TestHelper.assertNotNil(RA, "应能加载 framework.require_aliases")
    TestHelper.assertNotNil(RA.install, "应导出 install()")

    for _, name in ipairs(EXPECTED) do
        TestHelper.assertNotNil(package.preload[name],
            "别名 " .. name .. " 应已注册到 package.preload")

        -- 真的能 require 出来（preload 存在但 loader 报错也是失败）
        local ok, mod = pcall(require, name)
        TestHelper.assertTrue(ok, "require(\"" .. name .. "\") 应成功：" .. tostring(mod))
        TestHelper.assertNotNil(mod, "require(\"" .. name .. "\") 应返回模块表")
    end

    restore(saved)
end

-- ------------------------------------------------------------ ② 幂等 + 不覆盖

function TestRequireAliases.testInstallIsIdempotent()
    print("\n=== Test: install 幂等（重复调用不报错、不覆盖已有条目）===")
    local saved = snapshot()
    local RA = require("framework.require_aliases")

    RA.install()
    local first = {}
    for _, name in ipairs(EXPECTED) do first[name] = package.preload[name] end

    -- 重复 install：不得报错
    local ok, err = pcall(RA.install)
    TestHelper.assertTrue(ok, "第二次 install 不应报错：" .. tostring(err))

    -- 且不得替换已有的 loader（函数同一性）
    for _, name in ipairs(EXPECTED) do
        TestHelper.assertEquals(first[name], package.preload[name],
            "重复 install 不得覆盖 " .. name .. " 的 loader")
    end

    -- **负向对照的核心**：外部（如 Web 引擎）注册的 loader 必须保留
    local WebOwnedLoader = function() return { from = "web" } end
    package.preload["lib_file"] = WebOwnedLoader
    RA.install()
    TestHelper.assertEquals(WebOwnedLoader, package.preload["lib_file"],
        "install 不得覆盖其它引擎自己注册的裸名 loader（web 从字符串装载，必须优先）")

    restore(saved)
end

-- ------------------------------------------------------------ ③ 负向对照：恢复

function TestRequireAliases.testInstallRestoresClearedAlias()
    print("\n=== Test: 负向对照 —— 清掉别名后再 install 必须恢复 ===")
    local saved = snapshot()
    local RA = require("framework.require_aliases")

    -- 先确保都装上，再清掉一个（模拟「某个引擎/测试动过 package.preload」）
    RA.install()
    local victim = "script_loader"
    package.preload[victim] = nil
    TestHelper.assertNil(package.preload[victim], "前置条件：别名已被清掉")

    RA.install()

    TestHelper.assertNotNil(package.preload[victim],
        "install() 必须把被清掉的 " .. victim .. " 补回来")

    -- 补回来的 loader 要真的能用
    local ok, mod = pcall(require, victim)
    TestHelper.assertTrue(ok, "恢复后的 " .. victim .. " 应能 require：" .. tostring(mod))
    TestHelper.assertNotNil(mod, "恢复后的 " .. victim .. " 应返回模块表")

    restore(saved)
end

-- ------------------------------------------------------------ ④ 唯一来源

function TestRequireAliases.testAliasTableIsListed()
    print("\n=== Test: 别名表可枚举（唯一真源，5 项）===")
    local RA = require("framework.require_aliases")
    local list = RA.list()

    TestHelper.assertNotNil(list, "应导出 list()")
    TestHelper.assertEquals(#EXPECTED, #list,
        "别名数量应为 " .. #EXPECTED .. "，实测 " .. #list)

    for i, name in ipairs(EXPECTED) do
        TestHelper.assertEquals(name, list[i],
            "第 " .. i .. " 个别名应为 " .. name .. "，实测 " .. tostring(list[i]))
    end
end

-- ------------------------------------------------------------ ⑤ 引擎不再各抄一份

function TestRequireAliases.testEnginesDelegateToModule()
    print("\n=== Test: 四个引擎都走同一个注册处（不再各抄一份）===")
    local function readSource(rel)
        for _, p in ipairs({ rel, "../game/" .. rel }) do
            local f = io.open(p, "r")
            if f then local s = f:read("*a"); f:close(); return s end
        end
        return nil
    end

    local engines = {
        "engine-love2d/engine_love2d.lua",
        "engine-mud/engine_mud.lua",
        "engine-web/web_game_bridge.lua",
        "tests/engine_test.lua",
    }
    for _, rel in ipairs(engines) do
        local src = readSource(rel)
        TestHelper.assertNotNil(src, "应能读到 " .. rel)
        TestHelper.assertNotNil(src:find('require("framework.require_aliases")', 1, true),
            rel .. " 应 require framework.require_aliases（别名的唯一来源）")
    end

    -- LÖVE 引擎不得再保留自己那份 for 循环注册
    local loveSrc = readSource("engine-love2d/engine_love2d.lua")
    TestHelper.assertNil(loveSrc:find("frameworkAliases", 1, true),
        "engine_love2d.lua 不应再有 frameworkAliases 局部表（已搬到 framework）")

    -- web 的 registerFrameworkModule 不得再顺手注册裸名
    --
    -- 判据用**纯文本查找**（plain=true）：原实现的关键语句是
    -- `if moduleName and not package.preload[moduleName] then`。
    -- 不要用 Lua 模式匹配写 `name:match("^framework%.")` —— `(` `)` 在
    -- Lua 模式里是魔法字符（捕获），那种判据永远命中不了（本测试第一版踩过）。
    local webSrc = readSource("engine-web/web_game_bridge.lua")
    TestHelper.assertNil(webSrc:find("package.preload[moduleName]", 1, true),
        "web_game_bridge.lua 不应再按 framework.* 前缀注册裸名（统一到 require_aliases）")
end

function TestRequireAliases.runAll()
    print("\n" .. string.rep("=", 60))
    print("裸名 require 别名（engine-portability-alias）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestRequireAliases.testInstallProvidesAllAliases()
    TestRequireAliases.testInstallIsIdempotent()
    TestRequireAliases.testInstallRestoresClearedAlias()
    TestRequireAliases.testAliasTableIsListed()
    TestRequireAliases.testEnginesDelegateToModule()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_require_aliases.lua$") then
    TestRequireAliases.runAll()
end

return TestRequireAliases
