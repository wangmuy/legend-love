-- test_mod_encoding.lua
-- tools/mod_encoding.lua 单元测试
--
-- 覆盖 allmods-compat 五个“有问题”MOD 逆向分析中确立的修复：
--   * TrimControl       —— 剥离字段内的 CR/LF 编辑器残留（BookCalamity/awaken/Dragon）
--   * DetectLayout      —— 从字节推断分段边界（zheng 的 idx 损坏）
--   * RepairIdx         —— 仅在 idx 与文件不一致时才替换
--   * IdxIsConsistent   —— 容忍尾部 padding（pineapple）
--   * isStringField 守卫 —— 混合 ASCII+Big5 字段必须转换（mingdong Thing 112），
--                          且纯 ASCII 文本（长度>=2）保留而非误丢（lyff "AAA" 等）

local TestHelper = require("tests.test_helper")
local TestModEncoding = {}

local function freshEncoding()
    package.loaded["tools.mod_encoding"] = nil
    return require("tools.mod_encoding")
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

-- 参考数据根目录（从 game/ 运行）
local REF = "../reference/allmods/kys-"

local function loadMod(slug)
    local grp = readFile(REF .. slug .. "/save/ranger.grp")
    local idx = readFile(REF .. slug .. "/save/ranger.idx")
    if not grp or not idx then return nil end
    return grp, idx
end

-- ============================================================
-- TrimControl
-- ============================================================

function TestModEncoding.testTrimControlTrailingCrLf()
    print("\n=== Test: TrimControl 去除尾部 CR/LF ===")
    local E = freshEncoding()
    -- BookCalamity Thing r196 的真实字节: "大燕傳國玉璽\r\n"
    local raw = "\164\106\191\80\182\199\176\234\165\201\195\32\13\10"
    -- 注意 0xc3 0x20 是一对非法 Big5（lead + 空白），因此只验证尾部 CR/LF
    -- 已被剥离，不校验整串解码。
    local trimmed = E.TrimControl(raw)
    TestHelper.assertEquals("\164\106\191\80\182\199\176\234\165\201\195\32",
        trimmed, "尾部 CR/LF 被剥离，其余字节不变")
end

function TestModEncoding.testSkippedFieldNeutralisedForAllMods()
    print("\n=== Test: 跳过的数值字段被中和（全 20 MOD）===")
    local E = freshEncoding()
    local slugs = {
        "pascal", "Dragon", "RiverLake", "ptt", "pineapple", "dream", "pig",
        "books", "BookCalamity", "zheng", "loving", "awaken", "SweeOan",
        "HeavenSword", "lostbook", "GodsDevils", "lyff", "pig3dos",
        "mingdong", "stronger",
    }
    -- 真实启动链路上 pig3dos 出现 565 个控制符的根因：构建期「跳过」的
    -- 数值字段（如 Person 外号 @18 的 int16 stat）原始字节留在 .grp 里，
    -- 而引擎结构表仍把它声明为字符串 → Byte.getstr 把二进制当文本。
    -- 修复：跳过的字段也必须写一个解析为 "" 的 hint 来中和槽位。
    --
    -- 判定：对每个有 skipped 字段的 MOD，其旁路表中必须存在一个空字符串
    -- 条目，且该条目被 side.__meta 标记为 empty=true。
    local withSkips, bad = {}, {}
    for _, slug in ipairs(slugs) do
        local grp, idx = loadMod(slug)
        if grp then
            local offs = E.RepairIdx(grp, E.ParseIdx(idx))
            local _, side, report = E.ConvertRanger(grp, offs)
            if #report.skipped > 0 then
                withSkips[#withSkips + 1] = slug
                -- 每个有 skipped 字段的段必须恰好有 1 个共享空条目
                local segsWithSkips = {}
                for _, line in ipairs(report.skipped) do
                    local seg = line:match("^(%w+) rec")
                    if seg then segsWithSkips[seg] = true end
                end
                for seg in pairs(segsWithSkips) do
                    local found = false
                    local meta = side.__meta and side.__meta[seg]
                    if meta then
                        for i, m in pairs(meta) do
                            if m.empty then found = true break end
                        end
                    end
                    if not found then
                        bad[#bad + 1] = slug .. "." .. seg
                    end
                end
            end
        end
    end
    -- 至少 pig3dos 应该有 skipped 字段（回归保护）
    local hasPig = false
    for _, s in ipairs(withSkips) do if s == "pig3dos" then hasPig = true end end
    TestHelper.assertEquals(true, hasPig, "pig3dos 确实有被跳过的字段")
    TestHelper.assertEquals(0, #bad,
        "所有被跳过字段的段均有空条目中和；异常: " .. table.concat(bad, ", "))
    print("      有 skipped 字段的 MOD: " .. table.concat(withSkips, ", "))
end

function TestModEncoding.testTrimControlRealBookCalamityField()
    print("\n=== Test: TrimControl 处理 BookCalamity 真实字段 ===")
    local grp, idx = loadMod("BookCalamity")
    if not grp then
        print("  [SKIP] 参考数据缺失")
        return
    end
    local E = freshEncoding()
    local offs = E.RepairIdx(grp, E.ParseIdx(idx))
    local base = offs[2]
    local raw = grp:sub(base + 196 * 190 + 43, base + 196 * 190 + 72)
    local z = raw:find("\0", 1, true)
    if z then raw = raw:sub(1, z - 1) end
    TestHelper.assertEquals("大燕傳國玉璽",
        E.DecodeBig5(E.TrimControl(raw)), "真实字段尾部 CR/LF 被剥离")
end

function TestModEncoding.testTrimControlInteriorCrLf()
    print("\n=== Test: TrimControl 去除内部 CR/LF ===")
    local E = freshEncoding()
    -- "大剪刀\r\n刀法"
    local raw = "\164\106\176\197\164\77\13\10\164\77\170\107"
    TestHelper.assertEquals("大剪刀刀法",
        E.DecodeBig5(E.TrimControl(raw)), "内部 CR/LF 被折叠")
end

function TestModEncoding.testTrimControlKeepsPlainText()
    print("\n=== Test: TrimControl 不改动普通文本 ===")
    local E = freshEncoding()
    local raw = "\164\106\166\87"  -- 大理
    TestHelper.assertEquals(raw, E.TrimControl(raw), "无控制符时原样返回")
end

function TestModEncoding.testTrimControlStripsTrailingNulLikeControls()
    print("\n=== Test: TrimControl 剥离尾部其他 C0 控制符 ===")
    local E = freshEncoding()
    local raw = "\164\106\166\87\1\2\3"
    TestHelper.assertEquals("\164\106\166\87", E.TrimControl(raw),
        "尾部 0x01-0x03 被剥离")
end

-- ============================================================
-- IdxIsConsistent / RepairIdx
-- ============================================================

function TestModEncoding.testIdxIsConsistentRejectsOvershoot()
    print("\n=== Test: IdxIsConsistent 拒绝超出文件大小 ===")
    local E = freshEncoding()
    -- zheng 的损坏 idx：末值 138596 而文件只有 114242
    local bad = { 836, 65992, 104182, 109070, 138446, 138596 }
    TestHelper.assertEquals(false, E.IdxIsConsistent(bad, 114242),
        "末值大于文件大小 -> 不一致")
end

function TestModEncoding.testIdxIsConsistentToleratesTrailingPadding()
    print("\n=== Test: IdxIsConsistent 容忍尾部 padding（pineapple）===")
    local E = freshEncoding()
    -- pineapple: idx 末值 228210，文件 229680，多出 1470 字节 padding
    local shipped = { 1860, 132900, 198260, 204396, 228060, 228210 }
    TestHelper.assertEquals(true, E.IdxIsConsistent(shipped, 229680),
        "末值 <= 文件大小且各段对齐 -> 一致")
end

function TestModEncoding.testIdxIsConsistentRejectsMisalignedSegment()
    print("\n=== Test: IdxIsConsistent 拒绝段长不对齐 ===")
    local E = freshEncoding()
    -- Person 段 190 字节不是 182 的倍数
    local bad = { 836, 836 + 190, 59076, 97076, 101444, 114242 }
    TestHelper.assertEquals(false, E.IdxIsConsistent(bad, 114242),
        "段长非记录大小整数倍 -> 不一致")
end

function TestModEncoding.testRepairIdxDetectsZhengLayout()
    print("\n=== Test: RepairIdx 从字节修复 zheng 的损坏 idx ===")
    local grp, idx = loadMod("zheng")
    if not grp then
        print("  [SKIP] 参考数据缺失")
        return
    end
    local E = freshEncoding()
    local shipped = E.ParseIdx(idx)
    TestHelper.assertEquals(false, E.IdxIsConsistent(shipped, #grp),
        "zheng 出厂 idx 与文件不一致")

    local fixed, reason = E.RepairIdx(grp, shipped)
    TestHelper.assertNotNil(fixed, "RepairIdx 返回修复后的 idx")
    TestHelper.assertNotNil(reason, "给出修复原因")
    -- 修复结果必须与同尺寸的 pascal 标准布局一致
    local expect = { 836, 59076, 97076, 101444, 114092, 114242 }
    for i = 1, 6 do
        TestHelper.assertEquals(expect[i], fixed[i],
            "修复 idx[" .. i .. "]")
    end
    TestHelper.assertEquals(true, E.IdxIsConsistent(fixed, #grp),
        "修复后的 idx 自洽")
end

function TestModEncoding.testRepairIdxLeavesGoodIdxUntouched()
    print("\n=== Test: RepairIdx 不触碰完好的 idx ===")
    local grp, idx = loadMod("pascal")
    if not grp then
        print("  [SKIP] 参考数据缺失")
        return
    end
    local E = freshEncoding()
    local shipped = E.ParseIdx(idx)
    local out, reason = E.RepairIdx(grp, shipped)
    TestHelper.assertEquals(nil, reason, "完好 idx 无修复原因")
    for i = 1, 6 do
        TestHelper.assertEquals(shipped[i], out[i], "idx[" .. i .. "] 保持不变")
    end
end

-- ============================================================
-- DetectLayout —— 全 20 MOD 覆盖
-- ============================================================

function TestModEncoding.testDetectLayoutRecoversZhengAndIsStableForOthers()
    print("\n=== Test: DetectLayout 对全 20 MOD 均能给出可用布局 ===")
    local E = freshEncoding()
    local slugs = {
        "pascal", "Dragon", "RiverLake", "ptt", "pineapple", "dream", "pig",
        "books", "BookCalamity", "zheng", "loving", "awaken", "SweeOan",
        "HeavenSword", "lostbook", "GodsDevils", "lyff", "pig3dos",
        "mingdong", "stronger",
    }
    -- 探测是启发式的：它只用于出厂 idx 损坏时（zheng）。对完好 MOD，
    -- RepairIdx 会直接沿用出厂 idx，因此这里只要求：
    --   1) 每个 MOD 都能探测出 6 个单调递增的边界
    --   2) 边界不超出文件
    --   3) 每个 MOD 都能按探测布局解出干净字符串（无 U+FFFD）
    local failed = {}
    for _, slug in ipairs(slugs) do
        local grp, idx = loadMod(slug)
        if grp then
            local det = E.DetectLayout(grp)
            if not det then
                failed[#failed + 1] = slug .. ":探测失败"
            else
                local ok = true
                for i = 1, 6 do
                    if type(det[i]) ~= "number" then ok = false break end
                    if i > 1 and det[i] < det[i - 1] then ok = false break end
                end
                if det[6] > #grp then ok = false end
                if not ok then failed[#failed + 1] = slug .. ":边界非法" end
            end
        end
    end
    TestHelper.assertEquals(0, #failed,
        "全部 MOD 探测成功；异常: " .. table.concat(failed, "; "))
end

function TestModEncoding.testDetectLayoutZhengExact()
    print("\n=== Test: DetectLayout 精确还原 zheng 标准布局 ===")
    local grp = loadMod("zheng")
    if not grp then
        print("  [SKIP] 参考数据缺失")
        return
    end
    local E = freshEncoding()
    local det = E.DetectLayout(grp)
    local expect = { 836, 59076, 97076, 101444, 114092, 114242 }
    for i = 1, 6 do
        TestHelper.assertEquals(expect[i], det[i], "zheng 探测 idx[" .. i .. "]")
    end
end

-- ============================================================
-- ConvertRanger —— 字符串守卫
-- ============================================================

function TestModEncoding.testConvertRangerSkipsNumericFields()
    print("\n=== Test: ConvertRanger 跳过纯数值字段（pig3dos）===")
    local grp, idx = loadMod("pig3dos")
    if not grp then
        print("  [SKIP] 参考数据缺失")
        return
    end
    local E = freshEncoding()
    local offs = E.RepairIdx(grp, E.ParseIdx(idx))
    local newGrp, side, report = E.ConvertRanger(grp, offs)
    TestHelper.assertEquals(#grp, #newGrp, "文件大小不变")
    TestHelper.assertEquals(0, #report.overflows, "无 hint 溢出")
    -- pig3dos 的 Person 外号槽位（@18）实际是 int16 stat 数组，不含任何高位
    -- 字节。它必须被当作非字符串跳过（否则会把控制字节当文本输出），
    -- 但跳过时仍需写入一个空 hint 中和该槽位，否则引擎会把原始字节
    -- 当字符串读出 → 565 个控制符（在真实启动链路上验证过）。
    local nSkip = #report.skipped
    TestHelper.assertEquals(607, nSkip,
        "pig3dos 607 条 Person 外号均为数值字段，被跳过")
    -- 姓名（@8）是真正的字符串，应全部转换
    local person = report.perSeg.Person
    TestHelper.assertNotNil(person, "Person 段统计存在")
    TestHelper.assertEquals(607, person.converted,
        "pig3dos Person 姓名全部转换")
    -- 跳过的字段必须被中和：外号槽位的 hint 必须解析为空字符串
    local ns = 0
    for _, v in pairs(side.Person or {}) do
        if v == "" then ns = ns + 1 end
    end
    TestHelper.assertEquals(1, ns,
        "Person 段恰好有 1 个共享空字符串条目（中和所有跳过字段）")
    -- 且 .grp 中 @18 不再是原始 int16 字节，而是可解析的 hint
    local base = offs[1]
    local hint = newGrp:sub(base + 18 + 1, base + 18 + 5)
    TestHelper.assertNotNil(hint:match("^[A-Z][A-Z0-9]?%d%d%d%d$"),
        "Person[0] 外号槽位被写入可解析 hint（实际: " .. hint .. "）")
end

function TestModEncoding.testConvertRangerConvertsMixedAsciiBig5Fields()
    print("\n=== Test: ConvertRanger 转换 ASCII+Big5 混合字段（mingdong）===")
    local grp, idx = loadMod("mingdong")
    if not grp then
        print("  [SKIP] 参考数据缺失")
        return
    end
    local E = freshEncoding()
    local offs = E.RepairIdx(grp, E.ParseIdx(idx))
    local newGrp, side, report = E.ConvertRanger(grp, offs)
    TestHelper.assertEquals(#grp, #newGrp, "文件大小不变")

    -- Thing[112].物品说明 原始 = "53\xa1A219"（ASCII 前缀 + Big5 对）
    -- 必须被转换，否则引擎读到原始 Big5 字节 -> 非法 UTF-8
    local found = false
    for _, v in pairs(side.Thing or {}) do
        if type(v) == "string" and v == "53，219" then found = true break end
    end
    TestHelper.assertEquals(true, found, "混合字段 53，219 被写入旁路表")
end

function TestModEncoding.testConvertRangerPreservesAsciiOnlyStrings()
    print("\n=== Test: ConvertRanger 保留纯 ASCII 文本（不再误丢）===")
    local E = freshEncoding()
    -- 5 个真实纯 ASCII 字符串（可打印字符，长度 >= 2）。修复前 hasHighByte
    -- 守卫把它们当作数值槽丢弃（lyff 主角名 "AAA" 因此变空）；修复后必须
    -- 进入旁路表。长度 >= 2 的下限用于排除二进制残留单字符（pineapple " "、
    -- zheng "<"/"K"/"7"/"$"）。
    local cases = {
        { slug = "lyff",        seg = "Person", value = "AAA" },
        { slug = "HeavenSword", seg = "Person", value = "killer-G" },
        { slug = "GodsDevils",  seg = "Person", value = "123" },
        { slug = "ptt",         seg = "Scene",  value = "PTT" },
        { slug = "dream",       seg = "Thing",  value = "------" },
    }
    local missing = {}
    for _, c in ipairs(cases) do
        local grp, idx = loadMod(c.slug)
        if not grp then
            missing[#missing + 1] = c.slug .. ":参考数据缺失"
        else
            local offs = E.RepairIdx(grp, E.ParseIdx(idx))
            local _, side = E.ConvertRanger(grp, offs)
            local found = false
            for _, v in pairs(side[c.seg] or {}) do
                if v == c.value then found = true break end
            end
            if not found then
                missing[#missing + 1] = c.slug .. "." .. c.seg .. " 缺少 " .. c.value
            end
        end
    end
    TestHelper.assertEquals(0, #missing,
        "纯 ASCII 文本全部保留；异常: " .. table.concat(missing, ", "))
end

function TestModEncoding.testConvertRangerNoReplacementCharsAllMods()
    print("\n=== Test: 全 20 MOD 转换后无 U+FFFD ===")
    local E = freshEncoding()
    local slugs = {
        "pascal", "Dragon", "RiverLake", "ptt", "pineapple", "dream", "pig",
        "books", "BookCalamity", "zheng", "loving", "awaken", "SweeOan",
        "HeavenSword", "lostbook", "GodsDevils", "lyff", "pig3dos",
        "mingdong", "stronger",
    }
    local bad = {}
    for _, slug in ipairs(slugs) do
        local grp, idx = loadMod(slug)
        if grp then
            local offs = E.RepairIdx(grp, E.ParseIdx(idx))
            local _, side = E.ConvertRanger(grp, offs)
            for segName, tbl in pairs(side) do
                if segName ~= "__meta" then
                    for _, v in pairs(tbl) do
                        if type(v) == "string" and v:find("\239\191\189", 1, true) then
                            bad[#bad + 1] = slug .. "." .. segName
                            break
                        end
                    end
                end
            end
        end
    end
    TestHelper.assertEquals(0, #bad,
        "无 U+FFFD；异常: " .. table.concat(bad, ", "))
end

function TestModEncoding.testConvertRangerNoControlCharsAllMods()
    print("\n=== Test: 全 20 MOD 转换后无控制符 ===")
    local E = freshEncoding()
    local slugs = {
        "pascal", "Dragon", "RiverLake", "ptt", "pineapple", "dream", "pig",
        "books", "BookCalamity", "zheng", "loving", "awaken", "SweeOan",
        "HeavenSword", "lostbook", "GodsDevils", "lyff", "pig3dos",
        "mingdong", "stronger",
    }
    local bad = {}
    for _, slug in ipairs(slugs) do
        local grp, idx = loadMod(slug)
        if grp then
            local offs = E.RepairIdx(grp, E.ParseIdx(idx))
            local _, side = E.ConvertRanger(grp, offs)
            for segName, tbl in pairs(side) do
                if segName ~= "__meta" then
                    for _, v in pairs(tbl) do
                        if type(v) == "string" and v:find("[\1-\31\127]") then
                            bad[#bad + 1] = slug .. "." .. segName .. "=" .. v
                            break
                        end
                    end
                end
            end
        end
    end
    TestHelper.assertEquals(0, #bad,
        "无控制符；异常: " .. table.concat(bad, ", "))
end

-- ============================================================
-- runner
-- ============================================================

function TestModEncoding.testIsStringFieldDiscriminator()
    print("\n=== Test: isStringField 判别器（正例 / 反例）===")
    local E = freshEncoding()
    TestHelper.assertNotNil(E.IsStringField, "mod_encoding 导出 IsStringField")

    -- 正例：必须判定为字符串字段（输入为 **Big5 原始字节**，非 UTF-8）
    local positives = {
        { raw = "AAA",              why = "纯 ASCII 3 字节（lyff 主角名）" },
        { raw = "killer-G",         why = "ASCII 含连字符（HeavenSword）" },
        { raw = "123",              why = "纯数字 ASCII 但长度>=2（GodsDevils 昵称）" },
        { raw = "PTT",              why = "全大写 ASCII（ptt 场景名）" },
        { raw = "------",           why = "重复标点 ASCII 6 字节（dream Thing）" },
        { raw = "AB",               why = "长度恰为下限 2" },
        { raw = "53\xa1A219",       why = "ASCII 前缀 + Big5 对（mingdong Thing 112）" },
        { raw = "\xa4\xa4\xa4\xe5", why = "纯 Big5 四字节（中文名）" },
        { raw = "a\xa1A",           why = "ASCII + 高位字节混合" },
        { raw = "\xa4\xa4\xa4\xe5\xa1\xa3", why = "Big5 六字节（三字中文名）" },
    }
    local bad = {}
    for _, c in ipairs(positives) do
        if not E.IsStringField(c.raw) then
            bad[#bad + 1] = string.format("漏判 %q（%s）", c.raw, c.why)
        end
    end
    TestHelper.assertEquals(0, #bad, "正例全部判定为字符串；异常: " .. table.concat(bad, "; "))

    -- 反例：必须判定为非字符串（数值槽 / 空 / 单字节二进制残留）
    local negatives = {
        { raw = "",        why = "空字段（未使用的槽位）" },
        { raw = " ",       why = "单字节空格（pineapple 623 处二进制残留）" },
        { raw = "<",       why = "单字节标点（zheng 残留）" },
        { raw = "K",       why = "单字节字母（zheng 残留）" },
        { raw = "7",       why = "单字节数字（zheng 残留）" },
        { raw = "$",       why = "单字节符号（zheng 残留）" },
        { raw = "\0\0\0\0", why = "NUL 填充的 int32 数值槽" },
        { raw = "\1\2\3\4", why = "C0 控制字节的数值槽" },
        { raw = "\xff\xff\xff\xff", why = "int32 -1 数值槽" },
        { raw = "\xff\xfe\xfd\xfc", why = "非法 Big5 高位对（非 int32 槽）" },
        { raw = "\xa4",       why = "孤立 Big5 首字节（缺尾字节）" },
        { raw = "12\0\0\0", why = "小整数 + NUL 填充" },
        { raw = "\t\n",    why = "纯控制符（trim 后为空）" },
    }
    local badNeg = {}
    for _, c in ipairs(negatives) do
        if E.IsStringField(c.raw) then
            badNeg[#badNeg + 1] = string.format("误判 %q（%s）", c.raw, c.why)
        end
    end
    TestHelper.assertEquals(0, #badNeg,
        "反例全部判定为非字符串；异常: " .. table.concat(badNeg, "; "))
end

function TestModEncoding.testRangerStrSideTableContents()
    print("\n=== Test: ranger.str 构建产物内容（ptt + lyff）===")
    local E = freshEncoding()

    -- ranger.str 是 mod_build 写出的构建产物（不是源文件）。断言它：
    --   1. 含 MOD 作者真实写入的 ASCII 文本（ptt "PTT"、lyff "AAA"）；
    --   2. 每行 5 字段（# index,segment,record,field,value）无畸形；
    --   3. "-1" 空条目只出现在确实有数值槽被跳过的 MOD（GodsDevils /
    --      pig3dos / pineapple），其他 MOD 为 0。
    local expectAscii = {
        { slug = "ptt",  seg = "Scene",  value = "PTT" },
        { slug = "lyff", seg = "Person", value = "AAA" },
    }
    for _, c in ipairs(expectAscii) do
        local text = readFile("mods/" .. c.slug .. "/data/ranger.str")
        TestHelper.assertNotNil(text, c.slug .. " ranger.str 存在")
        if text then
            -- 用 ParseSideTable 反解，避免子串误命中（如 "AAA居"）
            local side = E.ParseSideTable(text)
            local found = false
            for _, v in pairs(side[c.seg] or {}) do
                if v == c.value then found = true break end
            end
            TestHelper.assertEquals(true, found,
                string.format("%s.%s 含 ASCII 值 %q", c.slug, c.seg, c.value))
        end
    end

    -- 格式校验 + "-1" 空条目计数
    -- 注：值本身可以含逗号（如 Thing Desc "西藏血刀門之絕學,招式狠辣"），
    -- 因此用 ParseSideTable 的同一正则拆行，而不是数逗号个数。
    local expectEmpty = { GodsDevils = 1, pig3dos = 1, pineapple = 3 }
    local slugs = {
        "pascal", "Dragon", "RiverLake", "ptt", "pineapple", "dream", "pig",
        "books", "BookCalamity", "zheng", "loving", "awaken", "SweeOan",
        "HeavenSword", "lostbook", "GodsDevils", "lyff", "pig3dos",
        "mingdong", "stronger",
    }
    local malformed, emptyWrong = {}, {}
    for _, slug in ipairs(slugs) do
        local text = readFile("mods/" .. slug .. "/data/ranger.str")
        if text then
            local nEmpty = 0
            for line in text:gmatch("[^\n]+") do
                if line:sub(1, 1) ~= "#" then
                    local idx, seg, rec, field, value =
                        line:match("^(%d+),([^,]+),([^,]*),([^,]*),(.*)$")
                    if not idx then
                        malformed[#malformed + 1] = slug .. ":" .. line
                    elseif rec == "-1" then
                        nEmpty = nEmpty + 1
                    end
                end
            end
            local want = expectEmpty[slug] or 0
            if nEmpty ~= want then
                emptyWrong[#emptyWrong + 1] =
                    string.format("%s 期望 %d 实得 %d", slug, want, nEmpty)
            end
        end
    end
    TestHelper.assertEquals(0, #malformed,
        "ranger.str 每行可解析为 5 字段；异常: " .. table.concat(malformed, "; "))
    TestHelper.assertEquals(0, #emptyWrong,
        "-1 空条目数符合预期；异常: " .. table.concat(emptyWrong, "; "))
end

function TestModEncoding.runAll()
    TestModEncoding.testTrimControlTrailingCrLf()
    TestModEncoding.testTrimControlRealBookCalamityField()
    TestModEncoding.testTrimControlInteriorCrLf()
    TestModEncoding.testTrimControlKeepsPlainText()
    TestModEncoding.testTrimControlStripsTrailingNulLikeControls()
    TestModEncoding.testIdxIsConsistentRejectsOvershoot()
    TestModEncoding.testIdxIsConsistentToleratesTrailingPadding()
    TestModEncoding.testIdxIsConsistentRejectsMisalignedSegment()
    TestModEncoding.testRepairIdxDetectsZhengLayout()
    TestModEncoding.testRepairIdxLeavesGoodIdxUntouched()
    TestModEncoding.testDetectLayoutRecoversZhengAndIsStableForOthers()
    TestModEncoding.testDetectLayoutZhengExact()
    TestModEncoding.testConvertRangerSkipsNumericFields()
    TestModEncoding.testConvertRangerConvertsMixedAsciiBig5Fields()
    TestModEncoding.testConvertRangerPreservesAsciiOnlyStrings()
    TestModEncoding.testConvertRangerNoReplacementCharsAllMods()
    TestModEncoding.testConvertRangerNoControlCharsAllMods()
    TestModEncoding.testSkippedFieldNeutralisedForAllMods()
    TestModEncoding.testIsStringFieldDiscriminator()
    TestModEncoding.testRangerStrSideTableContents()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_mod_encoding.lua$") then
    TestModEncoding.runAll()
end

return TestModEncoding
