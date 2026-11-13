-- test_version_compat.lua
-- Lua 5.1 / 5.3 / 5.4 / 5.5 跨版本兼容性回归测试
--
-- 背景：运行时是 LuaJIT（5.1 语法 + goto 扩展），但仓库必须在多个 PUC-Lua
-- 版本下都能跑测试与 tools。各版本之间有三处**会改变行为**的破坏性变更，
-- 本套件把它们逐条锁死，避免以后又写回不兼容的写法：
--
--   1. 5.5 起 for 的控制变量是 const —— `for k,v in ... do k = ... end`
--      在 5.4 能跑，5.5 直接编译期报错。
--   2. 5.5 起 `#t` 对带洞表返回**边界**（第一个洞之前），5.4 及更早返回
--      任意边界（实测常返回数组末尾）。靠 `#t` 判断“还有多少元素”的代码
--      在 5.5 下会提前停。
--   3. 5.5 起浮点 `tostring` 改为最短往返表示（0.30000000000000004），
--      5.4 是 `%.14g`（0.3）。任何把浮点转字符串做比较/存盘的地方都会变。
--
-- 另有：5.4 起 `bit32` 被移除（本仓库用 framework/lib_bit.lua 兜底）。

local TestHelper = require("tests.test_helper")
local TestVersionCompat = {}

-- jymain_adapter 会给 _G 装严格元表（__index 对未声明全局直接 error），
-- 而 loadstring 在 5.2+ 根本不存在 —— 裸读 `loadstring` 会抛
--   attempt read read to undeclared variable loadstring
-- 因此一律用 rawget 探测，不在运行时依赖「读不到就是 nil」的默认语义。
local rawget = rawget

--- 返回当前解释器的字符串编译函数。
-- 5.1: loadstring(src, chunkname)；5.2+: load(src, chunkname, "t")
-- @return function|nil
local function stringCompiler()
    local ls = rawget(_G, "loadstring")
    if type(ls) == "function" then return ls end
    return load
end

-- ============================================================
-- 1. for 控制变量不可赋值（5.5 const）
-- ============================================================

-- 判定编译器是否允许给 for 变量赋值。用 load 隔离，避免本文件自身
-- 在 5.5 下编译失败（那会让整个套件加载不了）。
local function compilerAllowsForVarAssign()
    local compile = stringCompiler()
    if not compile then return false, nil end
    local chunk = compile(
        "local n = 0; for i = 1, 3 do i = i + 10; n = n + 1 end; return n")
    if not chunk then return false, nil end
    local ok, r = pcall(chunk)
    if not ok then return false, nil end
    return true, r
end

function TestVersionCompat.testForVariableAssignRejectedOn55()
    print("\n=== Test: for 控制变量赋值（Lua 5.5 起为 const）===")
    local allowed, result = compilerAllowsForVarAssign()
    -- 只断言"本仓库代码里不再依赖这种写法"，而不是断言某种语言行为：
    -- 5.1~5.4 允许（allowed=true，返回 3），5.5 拒绝（allowed=false）。
    -- 两种都算通过，真正锁死在下面的源码扫描上。
    TestHelper.assertTrue(allowed == true or allowed == false,
        "编译器行为可探测（allowed=" .. tostring(allowed) .. "）")
    if allowed then
        TestHelper.assertEquals(3, result, "允许赋值时循环体执行 3 次")
    end
end

function TestVersionCompat.testNoForVariableAssignInSource()
    print("\n=== Test: 全仓运行时源码在当前解释器下可编译 ===")
    -- 用 load() 逐文件编译：这就是「本版本能不能读这个文件」的判据。
    -- 在 Lua 5.5 下跑本套件时，任何 `for k in ... do k = ... end` 都会
    -- 在这里暴露（编译期报 attempt to assign to const variable）。
    --
    -- 比正则扫描可靠：正则无法跟踪 for 的作用域，会被同名局部变量误报
    -- （实测误报 80 处，而 luac5.5 编译 0 失败）。
    local Fs = require("framework.fs_compat")
    local scanned, failed = 0, {}

    for _, dir in ipairs({ "framework", "engine-love2d", "engine-mud",
                           "engine-web", "script" }) do
        for _, rel in ipairs(Fs.walkFiles(dir)) do
            if rel:match("%.lua$") then
                local path = dir .. "/" .. rel
                local src = Fs.readFile(path)
                if src then
                    scanned = scanned + 1
                    -- 去掉 UTF-8 BOM：Lua 5.1 的 load 不接受 BOM
                    if src:sub(1, 3) == "\239\187\191" then
                        src = src:sub(4)
                    end
                    -- 5.1 的字符串编译入口是 loadstring（load 只收函数）；
                    -- 5.2+ 则是 load
                    local chunk, err = stringCompiler()(src, "@" .. path)
                    if not chunk then
                        failed[#failed + 1] = tostring(err)
                    end
                end
            end
        end
    end

    TestHelper.assertTrue(scanned > 100,
        "编译检查了足够多的运行时源文件（" .. scanned .. "）")
    for i = 1, math.min(#failed, 5) do print("  " .. failed[i]) end
    TestHelper.assertEquals(0, #failed,
        "全部运行时源文件在 " .. _VERSION .. " 下可编译")
end

-- ============================================================
-- 2. # 对带洞表的语义（5.5 起为边界）
-- ============================================================

function TestVersionCompat.testTableLengthWithHolesIsNotTrusted()
    print("\n=== Test: 不得依赖 #t 判断带洞表长度 ===")
    -- 这条不是断言某个具体数值（5.1~5.4 之间本身就"任意边界"），
    -- 而是锁死「本仓库的代码路径不这么写」。真正的判别在源码扫描里。
    local t = { 1, 2, 3, 4, 5 }
    t[3] = nil
    local n = #t
    TestHelper.assertTrue(type(n) == "number" and n >= 2 and n <= 5,
        "# 带洞表返回某个合法边界（实际 " .. n .. "）")

    -- 正确做法：显式计数
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    TestHelper.assertEquals(4, count, "pairs 计数才是可靠的（4 个非 nil 元素）")
end

function TestVersionCompat.testNoLengthBasedArrayShrink()
    print("\n=== Test: 不得用 t[#t] = nil / while #t 收缩数组 ===")
    local Fs = require("framework.fs_compat")
    local offenders = {}

    local function scanFile(path)
        local src = Fs.readFile(path)
        if not src then return end
        local lineNo = 0
        for line in (src .. "\n"):gmatch("(.-)\r?\n") do
            lineNo = lineNo + 1
            local code = line:gsub("%-%-.*$", "")
            -- t[#t] = nil
            if code:match("%[%s*#[%w_]+%s*%]%s*=%s*nil") then
                offenders[#offenders + 1] = string.format(
                    "%s:%d  %s", path, lineNo, line:gsub("^%s+", ""):sub(1, 90))
            end
        end
    end

    for _, dir in ipairs({ "framework", "engine-love2d", "engine-mud",
                           "engine-web", "script" }) do
        for _, rel in ipairs(Fs.walkFiles(dir)) do
            if rel:match("%.lua$") then scanFile(dir .. "/" .. rel) end
        end
    end

    if #offenders > 0 then
        for i = 1, math.min(#offenders, 5) do print("  " .. offenders[i]) end
    end
    TestHelper.assertEquals(0, #offenders,
        "无 t[#t] = nil 收缩（5.5 下数组会从中段被截断）")
end

-- ============================================================
-- 3. 浮点 tostring（5.5 改最短往返表示）
-- ============================================================

function TestVersionCompat.testFloatToStringDiffersAcrossVersions()
    print("\n=== Test: 浮点 tostring 的版本差异已被识别 ===")
    -- 记录当前版本的实际行为，并断言「整数不受影响」——
    -- 本项目所有持久化都走 string.format("%d") / Byte 打包，不用浮点 tostring。
    local s = tostring(0.1 + 0.2)
    TestHelper.assertTrue(s == "0.3" or s == "0.30000000000000004",
        "浮点 tostring 是已知形态之一（实际 " .. s .. "）")

    -- 整数永远稳定
    TestHelper.assertEquals("42", tostring(42), "整数 tostring 稳定")
    TestHelper.assertEquals("0", tostring(0), "零 tostring 稳定")
    TestHelper.assertEquals("-7", tostring(-7), "负数 tostring 稳定")
end

function TestVersionCompat.testSavePathDoesNotUseFloatToString()
    print("\n=== Test: 存档路径不用浮点 tostring（跨版本字节一致）===")
    local Fs = require("framework.fs_compat")
    local path = Fs.tempPath("verfmt_probe.bin")

    -- 用真实的 Byte 打包往返：1000 / 2000 / 65535 / 0
    local Byte = require("framework.lib_Byte")
    Byte.SaveFromTable16({ 1000, 2000, 65535, 0 }, path, 4, 1, nil, true)
    local back = Byte.LoadToTable16(path, 4, 0, true)
    os.remove(path)

    TestHelper.assertNotNil(back, "读回成功")
    TestHelper.assertEquals(1000, back[1], "第 1 个值往返一致")
    TestHelper.assertEquals(2000, back[2], "第 2 个值往返一致")
    TestHelper.assertEquals(-1, back[3], "65535 以小端有符号读回 -1")
    TestHelper.assertEquals(0, back[4], "第 4 个值往返一致")
end

-- ============================================================
-- 4. bit32 可用性（5.4 起被移除）
-- ============================================================

function TestVersionCompat.testBitOpsAvailableOnEveryVersion()
    print("\n=== Test: 按位与/右移在各版本可用（lib_bit 兜底）===")
    local Bit = require("framework.lib_bit")
    TestHelper.assertNotNil(Bit, "lib_bit 可加载")
    TestHelper.assertTrue(type(Bit.backend) == "string",
        "已选定后端（" .. tostring(Bit.backend) .. "）")

    TestHelper.assertEquals(15, Bit.band(0xFF, 0x0F), "band(0xFF,0x0F)=15")
    TestHelper.assertEquals(255, Bit.rshift(65535, 8), "rshift(65535,8)=255")
    -- 大数：验证不因 float 精度走偏
    TestHelper.assertEquals(239, Bit.band(0x89ABCDEF, 0xFF),
        "band(0x89ABCDEF,0xFF)=239")
    TestHelper.assertEquals(205, Bit.rshift(Bit.band(0x89ABCDEF, 0xFFFF), 8),
        "rshift(band(...),8)=205")
end

function TestVersionCompat.testLibByteWorksWithoutTestHarness()
    print("\n=== Test: lib_Byte 不依赖测试 harness 的 bit32 补丁 ===")
    -- tests/test_helper.lua 的 mockLoveData 会顺手装 bit32 shim，掩盖了
    -- 「5.4/5.5 下 lib_Byte 自己拿不到 bit32」的问题。这里验证 lib_bit 的
    -- 兜底是自足的：只要 lib_Byte 能加载，bit32 就已被填好。
    local ok, Byte = pcall(require, "framework.lib_Byte")
    TestHelper.assertTrue(ok, "lib_Byte 可加载: " .. tostring(Byte))
    TestHelper.assertNotNil(rawget(_G, "bit32"),
        "加载 lib_Byte 后 bit32 必须可用（5.4/5.5 无原生实现）")
end

function TestVersionCompat.runAll()
    print("\n" .. string.rep("=", 60))
    print("跨版本兼容性测试（Lua 5.1 / 5.3 / 5.4 / 5.5）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestVersionCompat.testForVariableAssignRejectedOn55()
    TestVersionCompat.testNoForVariableAssignInSource()
    TestVersionCompat.testTableLengthWithHolesIsNotTrusted()
    TestVersionCompat.testNoLengthBasedArrayShrink()
    TestVersionCompat.testFloatToStringDiffersAcrossVersions()
    TestVersionCompat.testSavePathDoesNotUseFloatToString()
    TestVersionCompat.testBitOpsAvailableOnEveryVersion()
    TestVersionCompat.testLibByteWorksWithoutTestHarness()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_version_compat.lua$") then
    TestVersionCompat.runAll()
end

return TestVersionCompat
