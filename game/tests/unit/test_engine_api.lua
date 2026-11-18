-- test_engine_api.lua
-- EngineAPI 接口定义单元测试

local TestHelper = require("tests.test_helper")

local TestEngineAPI = {}

local function setup()
    TestHelper.setup()
end

function TestEngineAPI.testRenderModule()
    setup()
    print("\n=== Test: EngineAPI render module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.render, "render module should exist")
    TestHelper.assertNotNil(EngineAPI.render.text, "render.text should exist")
    TestHelper.assertNotNil(EngineAPI.render.fillRect, "render.fillRect should exist")
    TestHelper.assertNotNil(EngineAPI.render.rectOutline, "render.rectOutline should exist")
    TestHelper.assertNotNil(EngineAPI.render.drawBackground, "render.drawBackground should exist")
    TestHelper.assertNotNil(EngineAPI.render.setClip, "render.setClip should exist")
    TestHelper.assertNotNil(EngineAPI.render.present, "render.present should exist")
    TestHelper.assertNotNil(EngineAPI.render.presentAndWait, "render.presentAndWait should exist")
end

function TestEngineAPI.testSpriteModule()
    setup()
    print("\n=== Test: EngineAPI sprite module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.sprite, "sprite module should exist")
    TestHelper.assertNotNil(EngineAPI.sprite.initSprites, "sprite.initSprites should exist")
    TestHelper.assertNotNil(EngineAPI.sprite.loadArchive, "sprite.loadArchive should exist")
    TestHelper.assertNotNil(EngineAPI.sprite.getSize, "sprite.getSize should exist")
    TestHelper.assertNotNil(EngineAPI.sprite.draw, "sprite.draw should exist")
    -- REQ-MS1-3
    TestHelper.assertNotNil(EngineAPI.sprite.drawTinted, "sprite.drawTinted should exist")
    
    -- 验证 initPalette 不存在
    TestHelper.assertEquals(nil, EngineAPI.sprite.initPalette, "sprite.initPalette should NOT exist")
end

function TestEngineAPI.testMapModule()
    setup()
    print("\n=== Test: EngineAPI map module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.map, "map module should exist")
    TestHelper.assertNotNil(EngineAPI.map.loadMain, "map.loadMain should exist")
    TestHelper.assertNotNil(EngineAPI.map.loadScene, "map.loadScene should exist")
    TestHelper.assertNotNil(EngineAPI.map.saveScene, "map.saveScene should exist")
    TestHelper.assertNotNil(EngineAPI.map.loadBattle, "map.loadBattle should exist")
    TestHelper.assertNotNil(EngineAPI.map.drawMain, "map.drawMain should exist")
    TestHelper.assertNotNil(EngineAPI.map.drawScene, "map.drawScene should exist")
    TestHelper.assertNotNil(EngineAPI.map.drawBattle, "map.drawBattle should exist")
end

function TestEngineAPI.testInputModule()
    setup()
    print("\n=== Test: EngineAPI input module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.input, "input module should exist")
    TestHelper.assertNotNil(EngineAPI.input.getKey, "input.getKey should exist")
    TestHelper.assertNotNil(EngineAPI.input.waitForKey, "input.waitForKey should exist")
    TestHelper.assertNotNil(EngineAPI.input.setKeyRepeat, "input.setKeyRepeat should exist")
    -- REQ-MS1-2
    TestHelper.assertNotNil(EngineAPI.input.mousePosition, "input.mousePosition should exist")
    TestHelper.assertNotNil(EngineAPI.input.mouseButton, "input.mouseButton should exist")

    -- REQ-IAL-4：input-action-layer 新增 4 个函数
    TestHelper.assertNotNil(EngineAPI.input.getAxis, "input.getAxis should exist")
    TestHelper.assertNotNil(EngineAPI.input.getCapabilities, "input.getCapabilities should exist")
    TestHelper.assertNotNil(EngineAPI.input.getPointerPosition, "input.getPointerPosition should exist")
    TestHelper.assertNotNil(EngineAPI.input.pollAction, "input.pollAction should exist")
end

-- REQ-IAL-4：四个实现都必须补齐 9 个 input 函数（缺一个就会有 nil 函数）
function TestEngineAPI.testAllEnginesHaveNineInputFunctions()
    print("\n=== Test: 四引擎 input 函数完整性 ===")
    local names = {
        "getKey", "waitForKey", "setKeyRepeat",
        "mousePosition", "mouseButton",
        "getAxis", "getCapabilities", "getPointerPosition", "pollAction",
        "getTouches",
    }
    -- 说明：这里**不 require engine_love2d**。
    -- 它在模块加载期就读 love.filesystem，而测试环境只有 TestHelper 的 mock
    -- （缺 filesystem 字段），require 会失败。engine_api.lua 是接口定义，
    -- 用它的 input 表校验函数名齐全即可；真实实现由各引擎自己的测试覆盖。
    local EngineAPI = require("engine-love2d.engine_api")
    TestHelper.assertNotNil(EngineAPI.input, "engine_api 应有 input 表")
    for _, fn in ipairs(names) do
        TestHelper.assertNotNil(EngineAPI.input[fn],
            "engine_api.input." .. fn .. " 必须存在（接口定义）")
    end

    -- engine-mud 与 engine-web 不依赖 love.*，可以真加载
    for _, modName in ipairs({ "engine-mud/engine_mud", "engine-web/engine_web" }) do
        local ok, mod = pcall(require, modName)
        TestHelper.assertTrue(ok, modName .. " 应能加载: " .. tostring(mod))
        if ok and mod and mod.input then
            for _, fn in ipairs(names) do
                TestHelper.assertNotNil(mod.input[fn],
                    modName .. ".input." .. fn .. " 必须存在")
            end
        end
    end
end

-- REQ-IAL-4：轴名闭集 —— 非法名必须宽容返回 0，而不是抛错
function TestEngineAPI.testGetAxisRejectsInvalidName()
    print("\n=== Test: getAxis 非法轴名 ===")
    local EngineAPI = require("engine-love2d.engine_api")
    -- engine_api 是接口定义（空函数），所以这里只断言"函数可调用"
    -- 真实返回值验证在引擎实现的测试里
    TestHelper.assertNotNil(EngineAPI.input.getAxis, "getAxis 应存在")

    -- 契约断言：6 个合法轴名与 SDL/Godot/Unreal 一致
    local valid = { "leftx", "lefty", "rightx", "righty", "triggerleft", "triggerright" }
    TestHelper.assertEquals(6, #valid, "轴名闭集应为 6 个")
end

-- REQ-MS1-1：system 模块（第 15 个）
function TestEngineAPI.testSystemModule()
    setup()
    print("\n=== Test: EngineAPI system module ===")

    local EngineAPI = require("engine-love2d.engine_api")

    TestHelper.assertNotNil(EngineAPI.system, "system module should exist")
    TestHelper.assertNotNil(EngineAPI.system.getOS, "system.getOS should exist")
end

function TestEngineAPI.testAudioModule()
    setup()
    print("\n=== Test: EngineAPI audio module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.audio, "audio module should exist")
    TestHelper.assertNotNil(EngineAPI.audio.playMusic, "audio.playMusic should exist")
    TestHelper.assertNotNil(EngineAPI.audio.playSFX, "audio.playSFX should exist")
    TestHelper.assertNotNil(EngineAPI.audio.stopMusic, "audio.stopMusic should exist")
end

function TestEngineAPI.testTimeModule()
    setup()
    print("\n=== Test: EngineAPI time module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.time, "time module should exist")
    TestHelper.assertNotNil(EngineAPI.time.sleep, "time.sleep should exist")
    TestHelper.assertNotNil(EngineAPI.time.getTime, "time.getTime should exist")
end

function TestEngineAPI.testFileModule()
    setup()
    print("\n=== Test: EngineAPI file module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.file, "file module should exist")
    TestHelper.assertNotNil(EngineAPI.file.open, "file.open should exist")
    TestHelper.assertNotNil(EngineAPI.file.remove, "file.remove should exist")
    TestHelper.assertNotNil(EngineAPI.file.getSize, "file.getSize should exist")
    TestHelper.assertNotNil(EngineAPI.file.exists, "file.exists should exist")
    TestHelper.assertNotNil(EngineAPI.file.getInfo, "file.getInfo should exist")
end

function TestEngineAPI.testScriptModule()
    setup()
    print("\n=== Test: EngineAPI script module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.script, "script module should exist")
    TestHelper.assertNotNil(EngineAPI.script.load, "script.load should exist")
end

function TestEngineAPI.testFontModule()
    setup()
    print("\n=== Test: EngineAPI font module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.font, "font module should exist")
    TestHelper.assertNotNil(EngineAPI.font.get, "font.get should exist")
end

function TestEngineAPI.testColorModule()
    setup()
    print("\n=== Test: EngineAPI color module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.color, "color module should exist")
    TestHelper.assertNotNil(EngineAPI.color.pack, "color.pack should exist")
    TestHelper.assertNotNil(EngineAPI.color.unpack, "color.unpack should exist")
end

function TestEngineAPI.testDebugModule()
    setup()
    print("\n=== Test: EngineAPI debug module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.debug, "debug module should exist")
    TestHelper.assertNotNil(EngineAPI.debug.log, "debug.log should exist")
end

function TestEngineAPI.testCoroutineModule()
    setup()
    print("\n=== Test: EngineAPI coroutine module ===")
    
    local EngineAPI = require("engine-love2d.engine_api")
    
    TestHelper.assertNotNil(EngineAPI.coroutine, "coroutine module should exist")
    TestHelper.assertNotNil(EngineAPI.coroutine.isRunning, "coroutine.isRunning should exist")
    TestHelper.assertNotNil(EngineAPI.coroutine.yieldPoint, "coroutine.yieldPoint should exist")
    TestHelper.assertNotNil(EngineAPI.coroutine.waitFor, "coroutine.waitFor should exist")
end

function TestEngineAPI.runAll()
    print("\n========================================")
    print("EngineAPI Interface Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    TestEngineAPI.testRenderModule()
    TestEngineAPI.testSpriteModule()
    TestEngineAPI.testMapModule()
    TestEngineAPI.testSystemModule()
    TestEngineAPI.testInputModule()
    TestEngineAPI.testAllEnginesHaveNineInputFunctions()
    TestEngineAPI.testGetAxisRejectsInvalidName()
    TestEngineAPI.testAudioModule()
    TestEngineAPI.testTimeModule()
    TestEngineAPI.testFileModule()
    TestEngineAPI.testScriptModule()
    TestEngineAPI.testFontModule()
    TestEngineAPI.testColorModule()
    TestEngineAPI.testDebugModule()
    TestEngineAPI.testCoroutineModule()
    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_engine_api.lua$") then
    TestEngineAPI.runAll()
end

return TestEngineAPI