-- test_map_render_missing.lua
-- 锁定「map 绘制契约在 framework 模块缺失时**显式失败**」
-- （change: port-legacy-picture-removal Task 5 / REQ-LPR-4）
--
-- 守的坑：
--   原来 `EngineAPI.map.drawMain/drawScene/drawBattle` 在 `framework.map_render`
--   加载失败时会回退到引擎内部的旧实现（`lib.DrawMMap/DrawSMap/DrawWarMap`）。
--   但旧实现的 `PicLoadCache` flag 位语义与新 `drawHandle` **不同**
--   （`port-map-render-native` 为此专门修过 drawHandle 的互斥判断），
--   静默回退会产生「有点不对但不崩」的画面 —— 比崩溃更难定位。
--
--   这个 fallback 掩盖的真问题是「`.love` 打包漏了 map_render.lua」，
--   应该立刻报错。

local TestHelper = require("tests.test_helper")
local TestMapRenderMissing = {}

--- 读源码（测试在 game/ 下跑，按两种相对路径找）
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
    src = src:gsub("%-%-%[%[.-%]%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

function TestMapRenderMissing.testNoLegacyMapDrawFallback()
    print("\n=== Test: 三个 map 绘制契约不再回退 lib.DrawMMap/DrawSMap/DrawWarMap ===")
    local src = readSource("engine-love2d/engine_love2d.lua")
    TestHelper.assertNotNil(src, "应能读到 engine_love2d.lua")
    local code = stripComments(src)

    for _, name in ipairs({ "DrawMMap", "DrawSMap", "DrawWarMap" }) do
        TestHelper.assertNil(code:find("lib%." .. name, 1),
            "不得再调 lib." .. name .. "（逃生舱已改显式失败）")
    end
end

function TestMapRenderMissing.testMissingModuleRaises()
    print("\n=== Test: map_render 缺失时契约抛错（不是静默回退）===")
    local src = readSource("engine-love2d/engine_love2d.lua")
    TestHelper.assertNotNil(src, "应能读到 engine_love2d.lua")

    TestHelper.assertNotNil(src:find('error(msg, 2)', 1, true),
        "mapRender() 应以 error 结束（显式失败）")
    TestHelper.assertNotNil(src:find("framework.map_render missing", 1, true),
        "错误信息应说明是 map_render 缺失（打包 bug）")

    -- 三个契约都必须经过 mapRender()
    local code = stripComments(src)
    for _, fn in ipairs({ "drawMain", "drawScene", "drawBattle" }) do
        local bodyStart = code:find("EngineAPI.map." .. fn .. " = function", 1, true)
        TestHelper.assertNotNil(bodyStart, "应有 EngineAPI.map." .. fn)
        local bodyEnd = code:find("\nend", bodyStart)
        local body = code:sub(bodyStart, bodyEnd)
        TestHelper.assertNotNil(body:find("mapRender()", 1, true),
            fn .. " 必须先取 mapRender()（缺失即抛错）")
    end
end

function TestMapRenderMissing.runAll()
    print("\n" .. string.rep("=", 60))
    print("map 绘制契约的显式失败（REQ-LPR-4）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestMapRenderMissing.testNoLegacyMapDrawFallback()
    TestMapRenderMissing.testMissingModuleRaises()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_map_render_missing.lua$") then
    TestMapRenderMissing.runAll()
end

return TestMapRenderMissing
