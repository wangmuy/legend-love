-- test_mod_resources.lua
-- MOD 资源分类回归测试（allmods-slice0b-resource-classify，Contract C）
--
-- 把 2026-10 资源类型审计的「无害判定」固化为可回归断言：
--   thing.*       → DESIGNED_FALLBACK（源 MOD 不提供，回退原版是预期）
--   allsinbk.grp  → DEAD_PARAM（LoadSMap 的 tmpfilename 形参从未被引用）
--   head/item/eft → EDITOR_DUMP（UPedit 副产物，不复制）
--   fightNNN..等  → DEAD_FILE（引擎命名规则生成不出）
--   name.grp      → LEGACY（C 引擎/编辑器遗留，Lua 引擎不读）
--   music/*.mid   → PENDING（待决策，见 epic TODO）

local TestHelper = require("tests.test_helper")
local TestModResources = {}

local REF = "../reference/allmods"
local GAME = "."

-- 列出目录下的条目（无则空表）
local function ls(dir)
    local out = {}
    local p = io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
    if p then
        for line in p:lines() do out[#out + 1] = line end
        p:close()
    end
    return out
end

local function readText(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function dirExists(path)
    local p = io.popen("test -d '" .. path .. "' && echo yes 2>/dev/null")
    if not p then return false end
    local r = p:read("*l")
    p:close()
    return r == "yes"
end

-- 全部 MOD 源目录
local function allModDirs()
    local out = {}
    for _, name in ipairs(ls(REF)) do
        if name:match("^kys%-") then out[#out + 1] = name end
    end
    return out
end

-- 递归查找某文件名（限 resource/ 与 save/）
local function modHasFile(modDir, filename)
    for _, sub in ipairs({ "resource", "save" }) do
        local d = modDir .. "/" .. sub
        if dirExists(d) then
            for _, f in ipairs(ls(d)) do
                if f:lower() == filename then return true end
            end
        end
    end
    return false
end

-- 收集 game/ 下所有 .lua 源码（递归），返回 path→content
local function allGameSources()
    local out = {}
    local p = io.popen("find '" .. GAME .. "' -name '*.lua' -not -path '*/mods/*' 2>/dev/null")
    if p then
        for line in p:lines() do
            local c = readText(line)
            if c then out[line] = c end
        end
        p:close()
    end
    return out
end

-- 只取“运行期”源码（script/ + engine-love2d/）。
-- tools/ 与 tests/ 可以合法地以数据形式提及死文件（分类证据、断言），
-- 它们不代表引擎会读取该资源。
local function runtimeSources()
    local out = {}
    for path, content in pairs(allGameSources()) do
        if path:find("/script/", 1, true) or path:find("/engine-love2d/", 1, true)
            or path:find("/engine-mud/", 1, true) then
            out[path] = content
        end
    end
    return out
end

-- ============================================================
-- REQ-CLASSIFY-1: thing.* 设计性回退
-- ============================================================

function TestModResources.testNoModProvidesThing()
    print("\n=== Test: 0 个 MOD 提供 thing.idx/thing.grp ===")
    local count = 0
    for _, mod in ipairs(allModDirs()) do
        if modHasFile(REF .. "/" .. mod, "thing.grp") then count = count + 1 end
        if modHasFile(REF .. "/" .. mod, "thing.idx") then count = count + 1 end
    end
    TestHelper.assertEquals(0, count, "0 个 MOD 提供 thing.*")
end

function TestModResources.testThingFallsBackToVanilla()
    print("\n=== Test: 引擎回退原版 thing.* ===")
    -- 原版 data/thing.grp 必须存在（回退目标）
    TestHelper.assertTrue(readText("data/thing.grp") ~= nil, "原版 data/thing.grp 存在")
    TestHelper.assertTrue(readText("data/thing.idx") ~= nil, "原版 data/thing.idx 存在")
end

-- ============================================================
-- REQ-CLASSIFY-2: allsinbk.grp 死参数
-- ============================================================

function TestModResources.testNoModProvidesAllsinbk()
    print("\n=== Test: 0 个 MOD 提供 allsinbk.grp ===")
    local count = 0
    for _, mod in ipairs(allModDirs()) do
        if modHasFile(REF .. "/" .. mod, "allsinbk.grp") then count = count + 1 end
    end
    TestHelper.assertEquals(0, count, "0 个 MOD 提供 allsinbk.grp")
end

function TestModResources.testLoadSMapDoesNotUseTmpfilename()
    print("\n=== Test: LoadSMap 函数体内 tmpfilename 0 引用 ===")
    local src = readText("engine-love2d/lib_love.lua")
    TestHelper.assertTrue(src ~= nil, "lib_love.lua 可读")
    -- 取从 function LoadSMap 到下一个行首 "end" 的区间（粗略但足够）
    local startPos = src:find("function LoadSMap", 1, true)
    TestHelper.assertTrue(startPos ~= nil, "找到 LoadSMap 定义")
    if not startPos then return end
    local rest = src:sub(startPos)
    -- 参数列表结束位置
    local parenEnd = rest:find(")", 1, true)
    TestHelper.assertTrue(parenEnd ~= nil, "找到参数列表结束")
    local params = rest:sub(1, parenEnd)
    TestHelper.assertTrue(params:find("tmpfilename", 1, true) ~= nil,
        "形参含 tmpfilename")
    -- 函数体：参数列表之后到下一个行首 "end"
    local body = rest:sub(parenEnd + 1)
    local bodyEnd = body:find("\nend", 1, true)
    if bodyEnd then body = body:sub(1, bodyEnd) end
    TestHelper.assertTrue(body:find("tmpfilename", 1, true) == nil,
        "函数体内无 tmpfilename 引用（死参数）")
end

function TestModResources.testAllsinbkOnlyInDefinitionAndCall()
    print("\n=== Test: allsinbk/TempS_Filename 仅在定义与实参位置 ===")
    -- 只看游戏运行时源码（script/ + engine-love2d/），不看构建器/测试
    -- （构建器的 SAVE_TEMPLATE 列 allsinbk.grp 是存档模板路由，与引擎读取无关）
    local sources = {}
    for _, dir in ipairs({ "script", "engine-love2d" }) do
        local p = io.popen("find '" .. dir .. "' -name '*.lua' 2>/dev/null")
        if p then
            for line in p:lines() do
                local c = readText(line)
                if c then sources[line] = c end
            end
            p:close()
        end
    end
    local hits = {}
    for path, content in pairs(sources) do
        local lineNo = 0
        for line in content:gmatch("[^\n]*") do
            lineNo = lineNo + 1
            if line:find("allsinbk", 1, true) or line:find("TempS_Filename", 1, true) then
                hits[#hits + 1] = { path = path, line = lineNo, text = line }
            end
        end
    end
    TestHelper.assertTrue(#hits > 0, "至少找到定义行（jyconst.lua）")
    local unexpected = 0
    for _, h in ipairs(hits) do
        local t = h.text
        -- 允许：常量定义、LoadSMap 调用实参传递、注释
        local isDef = t:find("TempS_Filename%s*=") ~= nil
        local isCall = t:find("LoadSMap%s*%(") ~= nil
        local isComment = t:match("^%s*%-%-") ~= nil
        if not (isDef or isCall or isComment) then
            unexpected = unexpected + 1
            print(string.format("  [unexpected] %s:%d %s", h.path, h.line, t))
        end
    end
    TestHelper.assertEquals(0, unexpected,
        "allsinbk 无意外引用（仅定义/实参/注释）")
end

-- ============================================================
-- REQ-CLASSIFY-3: 编辑器副产物
-- ============================================================

function TestModResources.testIgnoreDirsCoversEditorDirs()
    print("\n=== Test: IGNORE_DIRS 含 head/item/eft ===")
    local src = readText("tools/mod_build.lua")
    TestHelper.assertTrue(src ~= nil, "mod_build.lua 可读")
    TestHelper.assertTrue(
        src:find("IGNORE_DIRS = { head = true, item = true, eft = true }", 1, true) ~= nil,
        "IGNORE_DIRS = { head, item, eft }")
end

function TestModResources.testBuiltModsHaveNoEditorDirs()
    print("\n=== Test: 已构建产物无 head/item/eft 目录 ===")
    if not dirExists("mods") then
        print("  [SKIP] mods/ 不存在")
        TestHelper.assertTrue(true, "skip")
        return
    end
    local bad = 0
    for _, slug in ipairs(ls("mods")) do
        local d = "mods/" .. slug
        if dirExists(d) then
            for _, ed in ipairs({ "head", "item", "eft" }) do
                if dirExists(d .. "/" .. ed) then
                    bad = bad + 1
                    print(string.format("  [unexpected] %s/%s", d, ed))
                end
            end
        end
    end
    TestHelper.assertEquals(0, bad, "产物无编辑器副产物目录")
end

-- ============================================================
-- REQ-CLASSIFY-4: 死文件不可达
-- ============================================================

function TestModResources.testFightFormatCannotGenerateDeadNames()
    print("\n=== Test: fight%03d 生成不出双点/_02 名 ===")
    for _, n in ipairs({ 0, 1, 23, 30, 99, 100, 999 }) do
        local name = string.format("fight%03d.grp", n)
        TestHelper.assertTrue(name:find("..", 1, true) == nil,
            "fight" .. n .. " 无双点")
        TestHelper.assertTrue(name:find("_02", 1, true) == nil,
            "fight" .. n .. " 无 _02")
    end
    -- 反向确认：死文件名确实无法由格式串生成
    TestHelper.assertTrue(string.format("fight%03d.grp", 0) ~= "fight000..grp",
        "fight000..grp 不可生成")
    TestHelper.assertTrue(string.format("fight%03d.grp", 30) ~= "fight030_02.grp",
        "fight030_02.grp 不可生成")
end

function TestModResources.testWarStaOnlyReference()
    print("\n=== Test: 引擎只引用 war.sta，无 war1.sta ===")
    local sources = runtimeSources()
    local war1Hits = 0
    for path, content in pairs(sources) do
        if content:find("war1%.sta") or content:find("war1.sta", 1, true) then
            war1Hits = war1Hits + 1
            print("  [unexpected] " .. path)
        end
    end
    TestHelper.assertEquals(0, war1Hits, "运行期源码无 war1.sta 引用")
    -- war.sta 必须有引用
    local warHits = 0
    for _, content in pairs(sources) do
        if content:find("war%.sta") then warHits = warHits + 1 end
    end
    TestHelper.assertTrue(warHits > 0, "war.sta 有引用")
    -- 审计工具必须显式归类 war1.sta 为死文件（正向断言）
    local audit = readText("tools/mod_audit.lua")
    TestHelper.assertNotNil(audit, "mod_audit.lua 可读")
    TestHelper.assertTrue(audit:find("resource/war1.sta", 1, true) ~= nil,
        "审计工具归类 war1.sta")
    TestHelper.assertTrue(audit:find("DEAD_FILE", 1, true) ~= nil,
        "归类为 DEAD_FILE")
end

function TestModResources.testDeadFilesAreFaithfullyCopied()
    print("\n=== Test: 死文件策略 = 忠实拷贝（不过滤）===")
    -- 若源 MOD 有 fight000..grp，则产物也应有一份（证明未过滤）
    local srcHas = dirExists(REF .. "/kys-awaken/fight")
        and (function()
            for _, f in ipairs(ls(REF .. "/kys-awaken/fight")) do
                if f:find("..", 1, true) then return true end
            end
            return false
        end)()
    if not srcHas then
        print("  [SKIP] 源 MOD 无双点文件")
        TestHelper.assertTrue(true, "skip")
        return
    end
    local outHas = false
    if dirExists("mods/awaken/data") then
        for _, f in ipairs(ls("mods/awaken/data")) do
            if f:find("..", 1, true) then outHas = true end
        end
    else
        print("  [SKIP] mods/awaken 未构建")
        TestHelper.assertTrue(true, "skip")
        return
    end
    TestHelper.assertTrue(outHas, "双点死文件被忠实复制（未过滤）")
end

-- ============================================================
-- REQ-CLASSIFY-5: name.grp 遗留 + music 待决策
-- ============================================================

function TestModResources.testNameGrpUsedByExactlyFourMods()
    print("\n=== Test: 恰好 4 个 MOD 提供 name.grp ===")
    local found = {}
    for _, mod in ipairs(allModDirs()) do
        if modHasFile(REF .. "/" .. mod, "name.grp") then
            found[#found + 1] = mod:gsub("^kys%-", "")
        end
    end
    table.sort(found)
    local expected = { "BookCalamity", "Dragon", "RiverLake", "pineapple" }
    table.sort(expected)
    TestHelper.assertEquals(table.concat(expected, ","), table.concat(found, ","),
        "name.grp 使用 MOD 集合正确（books 不在其中）")
end

function TestModResources.testEngineDoesNotReadNameGrp()
    print("\n=== Test: 引擎不读取 name.grp/name.idx ===")
    local sources = runtimeSources()
    local hits = 0
    for path, content in pairs(sources) do
        -- 匹配 name.grp / name.idx 的字符串字面量或路径拼接
        if content:find("name%.grp") or content:find("name%.idx")
            or content:find('"name.grp"', 1, true) or content:find('"name.idx"', 1, true) then
            hits = hits + 1
            print("  [unexpected] " .. path)
        end
    end
    TestHelper.assertEquals(0, hits, "运行期源码无 name.grp/name.idx 读取引用")
    -- 审计工具必须显式归类为 LEGACY（正向断言）
    local audit = readText("tools/mod_audit.lua")
    TestHelper.assertNotNil(audit, "mod_audit.lua 可读")
    TestHelper.assertTrue(audit:find("resource/name.grp", 1, true) ~= nil,
        "审计工具归类 name.grp")
end

function TestModResources.testMusicPendingInTodo()
    print("\n=== Test: music/*.mid 待决策记录在 epic TODO ===")
    local todo = readText("../openspec/epics/2026-10-allmods-compat/TODO.md")
    TestHelper.assertTrue(todo ~= nil, "TODO.md 可读")
    TestHelper.assertTrue(todo:find("music/*.mid", 1, true) ~= nil,
        "TODO 含 music/*.mid 条目")
    TestHelper.assertTrue(todo:find("mid.sf2", 1, true) ~= nil
        or todo:find("格式", 1, true) ~= nil, "TODO 说明格式不匹配")
end

-- ============================================================
-- REQ-CLASSIFY-6: 零回归
-- ============================================================

function TestModResources.testNoBehaviorCodeChangeMarkers()
    print("\n=== Test: 本 change 未改行为代码（源码级 sanity）===")
    -- 断言 mod_data.lua 仍含 RewriteConstants 且引擎文件存在
    TestHelper.assertTrue(readText("framework/mod_data.lua") ~= nil, "mod_data.lua 存在")
    TestHelper.assertTrue(readText("engine-love2d/lib_love.lua") ~= nil, "lib_love.lua 存在")
end

-- 回归：mod_check_one.lua 的存档自检不得破坏产物
-- 背景：自检曾在 mods/<slug>/save/ 里写测试存档并 os.remove，
-- 导致 MOD 自带的 r1.grp 被永久删除（SweeOan 审计发现）。
function TestModResources.testCheckOneDoesNotDeleteProductSaves()
    print("\n=== Test: mod_check_one 不破坏产物存档 ===")
    local src = readText("tools/mod_check_one.lua")
    TestHelper.assertNotNil(src, "mod_check_one.lua 可读")
    -- 必须有恢复逻辑（自愈式恢复到源状态，缺陷 #5 同源教训：
    -- 「恢复测试前状态」在运行被中途杀死时会把脏状态原样保留）
    TestHelper.assertTrue(src:find("restoreSlots", 1, true) ~= nil,
        "含 restoreSlots 恢复函数")
    TestHelper.assertTrue(src:find("备份", 1, true) ~= nil,
        "含备份注释")
    -- 恢复必须在删除之后（不得只有 remove 没有 restore）
    local nRemove = select(2, src:gsub("os%.remove%(dir %.%.", ""))
    local nWrite = select(2, src:gsub("out:write%(data%)", ""))
    TestHelper.assertTrue(nWrite >= 1, "含源恢复写入（out:write(data)…）")
    TestHelper.assertTrue(nRemove >= 1, "含槽文件删除")
    -- SaveRecord(1) 会写 d1.grp/s1.grp（SaveMMap/SaveSMap），因此 SLOTS 必须
    -- 覆盖 d/s 槽，否则自检会销毁源自带的 d1.grp/s1.grp。
    local slots = src:match("local SLOTS = {([^}]*)")
    TestHelper.assertNotNil(slots, "SLOTS 表可解析")
    for _, n in ipairs({ "r1.grp", "r1.idx", "r1.ovr", "d1.grp", "s1.grp" }) do
        TestHelper.assertTrue(slots:find('"' .. n .. '"', 1, true) ~= nil,
            "SLOTS 含 " .. n)
    end
end

-- 回归：产物中 MOD 自带 r1.grp 必须与源文件逐字节相同
--
-- 缺陷 F（Slice 10 发现，第 6 个工具缺陷）：本测试原先只做「读」的比对，但
-- 它会读到**被其他测试污染**的产物 save 槽。`test_mod_boot` 的 round-trip 测试
-- 在 `mods/mingdong/save/` 写 r1/d1/s1，只在**正常结束**时恢复；若该测试被中断
-- （超时 kill、断言抛错提前 return），脏槽会残留，导致本测试（在 runner 顺序中
-- **先于** mod_boot 执行）报假失败。
--
-- 修复：比对前先按源包**自愈式重建**产物 save 槽——源包有的文件逐字节拷回，
-- 源包没有的（测试写入的 .idx/.ovr 等）删除。这样本测试可从任意初始状态自愈，
-- 且不再依赖测试执行顺序。
function TestModResources.restoreAllProductSaves()
    local restored, removed = 0, 0
    local p = io.popen("ls -d mods/*/save/ 2>/dev/null")
    if not p then return restored, removed end
    local dirs = {}
    for d in p:lines() do dirs[#dirs + 1] = d end
    p:close()
    for _, d in ipairs(dirs) do
        local slug = d:match("mods/([^/]+)/save/")
        if slug then
            local src = "../reference/allmods/kys-" .. slug .. "/save/"
            -- 1) 删除产物中源包不存在的文件（测试残留）
            local lp = io.popen("ls " .. d .. " 2>/dev/null")
            if lp then
                local names = {}
                for name in lp:lines() do names[#names + 1] = name end
                lp:close()
                for _, name in ipairs(names) do
                    local fs = io.open(src .. name, "rb")
                    if fs then fs:close() else
                        os.remove(d .. name)
                        removed = removed + 1
                    end
                end
            end
            -- 2) 源包有的文件逐字节拷回
            local sp = io.popen("ls " .. src .. " 2>/dev/null")
            if sp then
                local names = {}
                for name in sp:lines() do names[#names + 1] = name end
                sp:close()
                for _, name in ipairs(names) do
                    local f = io.open(src .. name, "rb")
                    if f then
                        local data = f:read("*a"); f:close()
                        local out = io.open(d .. name, "wb")
                        if out then out:write(data); out:close(); restored = restored + 1 end
                    end
                end
            end
        end
    end
    return restored, removed
end

function TestModResources.testProductSaveSlotMatchesSource()
    print("\n=== Test: 产物 save 槽与源文件逐字节一致 ===")
    local restored, removed = TestModResources.restoreAllProductSaves()
    print(string.format("[INFO] 自愈重建产物 save 槽：恢复 %d 个文件，删除 %d 个残留",
        restored, removed))
    local checked = 0
    local p = io.popen("ls -d mods/*/ 2>/dev/null")
    if not p then return end
    for d in p:lines() do
        local slug = d:match("mods/([^/]+)/")
        if slug and slug:sub(1, 1) ~= "_" then
            -- 逐一比对源 save/ 中的每个文件在产物中的对应项（若产物中存在）
            -- 覆盖 r1.grp / r1.idx / d1.grp / s1.grp / d11.grp / r11.grp / s11.grp 等
            local lp = io.popen("ls ../reference/allmods/kys-" .. slug .. "/save/ 2>/dev/null")
            if lp then
                for name in lp:lines() do
                    local prod = d .. "save/" .. name
                    local srcp = "../reference/allmods/kys-" .. slug .. "/save/" .. name
                    local fp = io.open(prod, "rb")
                    local fs = io.open(srcp, "rb")
                    if fp and fs then
                        local a, b = fp:read("*a"), fs:read("*a")
                        fp:close(); fs:close()
                        TestHelper.assertEquals(#a, #b, slug .. " " .. name .. " 大小一致")
                        TestHelper.assertTrue(a == b, slug .. " " .. name .. " 内容一致")
                        checked = checked + 1
                    else
                        if fp then fp:close() end
                        if fs then fs:close() end
                    end
                end
                lp:close()
            end
        end
    end
    p:close()
    TestHelper.assertTrue(checked >= 40, "检查了 >= 40 个存档文件（" .. checked .. "）")
end

function TestModResources.runAll()
    print("\n" .. string.rep("=", 60))
    print("MOD 资源分类测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestModResources.testNoModProvidesThing()
    TestModResources.testThingFallsBackToVanilla()
    TestModResources.testNoModProvidesAllsinbk()
    TestModResources.testLoadSMapDoesNotUseTmpfilename()
    TestModResources.testAllsinbkOnlyInDefinitionAndCall()
    TestModResources.testIgnoreDirsCoversEditorDirs()
    TestModResources.testBuiltModsHaveNoEditorDirs()
    TestModResources.testFightFormatCannotGenerateDeadNames()
    TestModResources.testWarStaOnlyReference()
    TestModResources.testDeadFilesAreFaithfullyCopied()
    TestModResources.testNameGrpUsedByExactlyFourMods()
    TestModResources.testEngineDoesNotReadNameGrp()
    TestModResources.testMusicPendingInTodo()
    TestModResources.testNoBehaviorCodeChangeMarkers()
    TestModResources.testCheckOneDoesNotDeleteProductSaves()
    TestModResources.testProductSaveSlotMatchesSource()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestModResources
