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
    TestEngineAPI.testInputModule()
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