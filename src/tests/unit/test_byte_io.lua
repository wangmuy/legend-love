-- test_byte_io.lua
-- Byte I/O 模块单元测试

local TestHelper = require("tests.test_helper")

local TestByteIO = {}

local function setup()
    TestHelper.setup()
    TestHelper.mockLove()
    TestHelper.mockGlobals()
end

local function cleanup()
    -- 清理临时文件
    os.remove("/tmp/test_save.bin")
    os.remove("/tmp/test_save_le.bin")
    os.remove("/tmp/test_save_be.bin")
end

-- 测试1: SaveFromTable16 基本功能（小端）
function TestByteIO.testSaveFromTable16LittleEndian()
    setup()
    print("\n=== Test: SaveFromTable16 Little Endian ===")
    
    local Byte = require("lib_Byte")
    
    -- 创建测试数据
    local t = {1000, 2000, 30000, 65535, 0}
    
    -- 保存
    Byte.SaveFromTable16(t, "/tmp/test_save_le.bin", 5, 1, nil, true)
    
    -- 验证文件存在
    local f = io.open("/tmp/test_save_le.bin", "rb")
    TestHelper.assertNotNil(f, "File should be created")
    if f then
        -- 读取并验证字节序（小端）
        local bytes = f:read("*a")
        f:close()
        
        -- 1000 = 0x03E8, 小端存储为 E8 03
        TestHelper.assertEquals(0xE8, bytes:byte(1), "Byte 1 should be 0xE8")
        TestHelper.assertEquals(0x03, bytes:byte(2), "Byte 2 should be 0x03")
        
        -- 验证文件大小
        TestHelper.assertEquals(10, #bytes, "File should be 10 bytes (5 elements * 2 bytes)")
    end
    
    cleanup()
end

-- 测试2: SaveFromTable16 基本功能（大端）
function TestByteIO.testSaveFromTable16BigEndian()
    setup()
    print("\n=== Test: SaveFromTable16 Big Endian ===")
    
    local Byte = require("lib_Byte")
    
    -- 创建测试数据
    local t = {1000, 2000}
    
    -- 保存
    Byte.SaveFromTable16(t, "/tmp/test_save_be.bin", 2, 1, nil, false)
    
    -- 验证文件存在
    local f = io.open("/tmp/test_save_be.bin", "rb")
    TestHelper.assertNotNil(f, "File should be created")
    if f then
        local bytes = f:read("*a")
        f:close()
        
        -- 1000 = 0x03E8, 大端存储为 03 E8
        TestHelper.assertEquals(0x03, bytes:byte(1), "Byte 1 should be 0x03")
        TestHelper.assertEquals(0xE8, bytes:byte(2), "Byte 2 should be 0xE8")
    end
    
    cleanup()
end

-- 测试3: 保存和加载数据一致性
function TestByteIO.testSaveAndLoadConsistency()
    setup()
    print("\n=== Test: Save and Load Consistency ===")
    
    local Byte = require("lib_Byte")
    
    -- 创建测试数据（使用 0-32767 范围内的正数，避免有符号转换问题）
    local original = {}
    for i = 1, 100 do
        original[i] = math.random(0, 32767)
    end
    
    -- 保存
    Byte.SaveFromTable16(original, "/tmp/test_save.bin", 100, 1, nil, true)
    
    -- 加载
    local loaded = Byte.LoadToTable16("/tmp/test_save.bin", 100, 0, true)
    
    -- 验证数据一致性
    TestHelper.assertNotNil(loaded, "Loaded data should not be nil")
    TestHelper.assertEquals(100, #loaded, "Loaded data should have 100 elements")
    
    local allMatch = true
    for i = 1, 100 do
        if original[i] ~= loaded[i] then
            print(string.format("Mismatch at index %d: expected %d, got %d", 
                i, original[i], loaded[i]))
            allMatch = false
            break
        end
    end
    TestHelper.assertEquals(true, allMatch, "All elements should match after save/load")
    
    cleanup()
end

-- 测试4: 有符号数处理（小端加载返回有符号数）
function TestByteIO.testSignedNumbers()
    setup()
    print("\n=== Test: Signed Numbers (Little Endian) ===")
    
    local Byte = require("lib_Byte")
    
    -- 创建包含大于 32767 的数值（会被解释为负数）
    local t = {65535, 65436, 32768}
    
    -- 保存
    Byte.SaveFromTable16(t, "/tmp/test_save.bin", 3, 1, nil, true)
    
    -- 加载（小端返回有符号数）
    local loaded = Byte.LoadToTable16("/tmp/test_save.bin", 3, 0, true)
    
    -- 验证（小端加载返回有符号数：65535 -> -1, 65436 -> -100, 32768 -> -32768）
    TestHelper.assertEquals(-1, loaded[1], "65535 should become -1 as signed")
    TestHelper.assertEquals(-100, loaded[2], "65436 should become -100 as signed")
    TestHelper.assertEquals(-32768, loaded[3], "32768 should become -32768 as signed")
    
    cleanup()
end

-- 测试5: 空数据处理
function TestByteIO.testEmptyData()
    setup()
    print("\n=== Test: Empty Data ===")
    
    local Byte = require("lib_Byte")
    
    -- 空表
    Byte.SaveFromTable16({}, "/tmp/test_save.bin", 0, 1, nil, true)
    
    -- nil 表
    Byte.SaveFromTable16(nil, "/tmp/test_save.bin", 0, 1, nil, true)
    
    -- 应该不会崩溃
    TestHelper.assertTrue(true, "Should handle empty/nil data without crash")
    
    cleanup()
end

-- 测试6: 大数据量性能
function TestByteIO.testLargeDataPerformance()
    setup()
    print("\n=== Test: Large Data Performance ===")
    
    local Byte = require("lib_Byte")
    
    -- 创建大数据（10万元素，使用 0-32767 范围）
    local t = {}
    for i = 1, 100000 do
        t[i] = i % 32768
    end
    
    local startTime = os.clock()
    Byte.SaveFromTable16(t, "/tmp/test_save.bin", 100000, 1, nil, true)
    local saveTime = os.clock() - startTime
    
    -- 加载
    startTime = os.clock()
    local loaded = Byte.LoadToTable16("/tmp/test_save.bin", 100000, 0, true)
    local loadTime = os.clock() - startTime
    
    print(string.format("  Save time: %.3fs", saveTime))
    print(string.format("  Load time: %.3fs", loadTime))
    
    -- 验证
    TestHelper.assertEquals(100000, #loaded, "Should load all elements")
    TestHelper.assertEquals(t[1], loaded[1], "First element should match")
    TestHelper.assertEquals(t[50000], loaded[50000], "Middle element should match")
    TestHelper.assertEquals(t[100000], loaded[100000], "Last element should match")
    
    cleanup()
end

-- 测试7: seekPos 参数
function TestByteIO.testSeekPos()
    setup()
    print("\n=== Test: Seek Position ===")
    
    local Byte = require("lib_Byte")
    
    -- 创建并保存数据
    local t1 = {100, 200}
    Byte.SaveFromTable16(t1, "/tmp/test_save.bin", 2, 1, nil, true)
    
    -- 在偏移 4 字节处追加数据
    local t2 = {300, 400}
    Byte.SaveFromTable16(t2, "/tmp/test_save.bin", 2, 1, 4, true)
    
    -- 读取验证
    local loaded = Byte.LoadToTable16("/tmp/test_save.bin", 4, 0, true)
    
    TestHelper.assertEquals(100, loaded[1], "First element should be 100")
    TestHelper.assertEquals(200, loaded[2], "Second element should be 200")
    TestHelper.assertEquals(300, loaded[3], "Third element should be 300")
    TestHelper.assertEquals(400, loaded[4], "Fourth element should be 400")
    
    cleanup()
end

-- 运行所有测试
function TestByteIO.runAll()
    print("\n========================================")
    print("Byte I/O Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    
    TestByteIO.testSaveFromTable16LittleEndian()
    TestByteIO.testSaveFromTable16BigEndian()
    TestByteIO.testSaveAndLoadConsistency()
    TestByteIO.testSignedNumbers()
    TestByteIO.testEmptyData()
    TestByteIO.testLargeDataPerformance()
    TestByteIO.testSeekPos()
    
    return TestHelper.printSummary()
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_byte_io.lua$") then
    TestByteIO.runAll()
end

return TestByteIO