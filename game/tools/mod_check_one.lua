-- tools/mod_check_one.lua — 单 MOD 适配自检（由 tools/mod_check.lua 派生调用）
--
-- 读取环境变量 MOD_SLUG，在 headless 引擎上走完整启动链路，输出 KEY=value 结果行。
-- 不在进程内循环多个 MOD，以保证状态隔离（每个 MOD 一个全新 Lua VM）。
--
-- 输出键：
--   PERSON/THING/SCENE/WUGONG  各段记录数
--   HERO                       主角姓名（验证旁路表解码）
--   STRINGS                    OK/FAIL  字符串解码（UTF-8 合法 + 无 hint 泄漏）
--   EVENTS                     OK/FAIL  起始事件脚本加载并执行
--   SAVE                       OK/FAIL  存档隔离（写/读 MOD save/ 目录）
--   NOTE                       附加说明（异常但可容忍）

package.path = "./?.lua;./?/init.lua;" .. package.path

local slug = os.getenv("MOD_SLUG")
if not slug or slug == "" then
    print("ERROR=MOD_SLUG not set")
    os.exit(1)
end

-- ---- 复用 test_mod_boot 的 love/bit32 stub（已验证可用）----
local function installStubs()
    local f = io.open("tests/unit/test_mod_boot.lua", "rb")
    if not f then return false end
    local src = f:read("*a"); f:close()
    local chunk = src
        :gsub("local function ensureBit32", "_G.ensureBit32 = function")
        :gsub("local function installLoveStub", "_G.installLoveStub = function")
        :gsub("local function installFormatTolerance", "_G.installFormatTolerance = function")
    local ok, fn = pcall(load, chunk, "bootmod")
    if not ok or not fn then return false end
    pcall(fn)
    if _G.ensureBit32 then pcall(_G.ensureBit32) end
    if _G.installLoveStub then pcall(_G.installLoveStub) end
    if _G.installFormatTolerance then pcall(_G.installFormatTolerance) end
    return true
end
if not installStubs() then
    print("ERROR=stub install failed")
    os.exit(1)
end

-- ---- 启动链路 ----
local okBoot, bootErr = pcall(function()
    local ModData = require("framework.mod_data")
    ModData.SetActive(slug)
    ModData.ClearSideCache()

    _G.EngineAPI = require("tests.engine_test")
    require("framework.config")
    _G.Byte = require("framework.lib_Byte")
    require("engine-love2d.lib_love")
    _G.lib = require("engine-love2d.engine_love2d")
    lib.init()
    require("framework.event_bridge").getInstance():init()
    require("script.jyconst")
    require("script.jymain")
    require("framework.jymain_adapter").init()
end)
if not okBoot then
    print("ERROR=" .. tostring(bootErr):gsub("\n", " "))
    os.exit(1)
end

local okLoad, loadErr = pcall(LoadRecord, 0)
if not okLoad then
    print("ERROR=" .. tostring(loadErr):gsub("\n", " "))
    os.exit(1)
end

print("PERSON=" .. tostring(JY.PersonNum))
print("THING="  .. tostring(JY.ThingNum))
print("SCENE="  .. tostring(JY.SceneNum))
print("WUGONG=" .. tostring(JY.WugongNum))

local hero = (JY.Person[0] and JY.Person[0]["姓名"]) or "?"
print("HERO=" .. hero)

-- ---- 字符串解码检查 ----
-- 1) 合法 UTF-8  2) 无 hint 泄漏
local function isUtf8(s)
    if type(s) ~= "string" then return true end
    local i, n = 1, #s
    while i <= n do
        local c = s:byte(i)
        local len
        if c < 0x80 then len = 1
        elseif c >= 0xC2 and c <= 0xDF then len = 2
        elseif c >= 0xE0 and c <= 0xEF then len = 3
        elseif c >= 0xF0 and c <= 0xF4 then len = 4
        else return false end
        if i + len - 1 > n then return false end
        for k = 1, len - 1 do
            local cc = s:byte(i + k)
            if not cc or cc < 0x80 or cc > 0xBF then return false end
        end
        i = i + len
    end
    return true
end
local function isHint(s)
    return type(s) == "string" and (s:match("^[PNTSW]%d%d%d%d$") or s:match("^T[2D]%d%d%d%d$")) ~= nil
end

local badUtf8, leaked = 0, 0
local function scan(tbl, n, field)
    for i = 0, math.min(n - 1, 400) do
        local v = tbl[i] and tbl[i][field]
        if isHint(v) then leaked = leaked + 1 end
        if type(v) == "string" and #v > 0 and not isUtf8(v) then badUtf8 = badUtf8 + 1 end
    end
end
scan(JY.Person, JY.PersonNum, "姓名")
scan(JY.Person, JY.PersonNum, "外号")
scan(JY.Thing,  JY.ThingNum,  "名称")
scan(JY.Thing,  JY.ThingNum,  "物品说明")
scan(JY.Scene,  JY.SceneNum,  "名称")
scan(JY.Wugong, JY.WugongNum, "名称")

local stringsOK = (badUtf8 == 0 and leaked == 0)
print("STRINGS=" .. (stringsOK and "OK" or "FAIL"))
if not stringsOK then
    print(string.format("NOTE=badUtf8=%d hintLeak=%d", badUtf8, leaked))
end

-- ---- 事件脚本检查 ----
local evOK = false
local evNote = ""
local okEv = pcall(function()
    local ModData = require("framework.mod_data")
    local evid = CC.BeginEvent
    if evid == nil then evid = 691 end
    -- 引擎常量名可能是 CC.NewGameEventID 等，做兜底
    if CC.NewGameEventID then evid = CC.NewGameEventID end

    local rel = CONFIG.OldEventPath .. "oldevent_" .. evid .. ".lua"
    local resolved = ModData.ScriptFile and ModData.ScriptFile(rel) or rel
    local EventExecutor = require("framework.event_executor")
    local EventBridge = require("framework.event_bridge")
    local done = false
    EventExecutor.startEvent(evid, 0, function() done = true end)
    for _ = 1, 150 do
        EventBridge.getInstance():update(0.016)
        if done then break end
    end
    evOK = true
    evNote = resolved:match("^mods/") and "mod-event" or "vanilla-event"
end)
print("EVENTS=" .. (evOK and "OK" or "FAIL"))
if not evOK then
    print("NOTE=" .. tostring(evNote ~= "" and evNote or "event exec failed"))
end

-- ---- 存档隔离检查 ----
-- 注意：本自检**不得**在产物目录 mods/<slug>/save/ 里写入/删除测试存档，
-- 否则会破坏 MOD 自带的 r1.grp（构建产物）。改为：
--   1) 先备份产物目录中可能存在的 r1.*
--   2) 跑自检
--   3) 恢复备份（字节级）
local saveOK = false
local okSave = pcall(function()
    local ModData = require("framework.mod_data")
    local dir = ModData.SaveDir()
    -- 必须指向 mods/<slug>/save/
    if dir ~= ("mods/" .. slug .. "/save/") then
        error("SaveDir 不是 MOD 目录: " .. tostring(dir))
    end

    -- 槽文件保护（MOD 包可能自带 r1.grp / d1.grp / s1.grp）。
    -- 注意：SaveRecord(1) 除写 r1.* 外，还会写存档槽 1 的地图/场景数据
    -- （d1.grp / s1.grp，由 SaveMMap/SaveSMap 触发），因此这些槽都必须
    -- 在自检后恢复，否则会销毁源自带的 d1.grp/s1.grp（缺陷 #1/#4 同源）。
    --
    -- 恢复策略 = 自愈式恢复到**源状态**（缺陷 #5 同源教训）：
    -- 「恢复测试前状态」在运行被中途杀死时会把脏状态原样保留
    -- （备份的就是脏状态），污染之后每一次自检。改为：
    -- 源包 save/ 中有的槽文件逐字节拷回，没有的删除。幂等、可自愈。
    local SLOTS = { "r1.grp", "r1.idx", "r1.ovr", "d1.grp", "d1.idx", "s1.grp", "s1.idx" }
    local srcDir = "../reference/allmods/kys-" .. slug .. "/save/"
    -- 自检前自愈：产物 save/ 与源 save/ 逐字节对齐（与 TestHelper.healModSave
    -- 同一实现）——上次自检若被中途杀死留下引擎存档状态，会污染本次及之后
    -- 的每次自检。
    local okTH, TH = pcall(require, "tests.test_helper")
    if okTH and TH.healModSave then pcall(TH.healModSave, slug) end
    local function restoreSlots()
        for _, n in ipairs(SLOTS) do
            os.remove(dir .. n)
            local f = io.open(srcDir .. n, "rb")
            if f then
                local data = f:read("*a"); f:close()
                -- 原子写：先写临时文件再 rename，中途被杀不会留下截断文件
                local tmp = dir .. n .. ".restore"
                local out = io.open(tmp, "wb")
                if out then
                    out:write(data); out:close()
                    os.rename(tmp, dir .. n)
                end
            end
        end
    end

    local ok, err = pcall(function()
        -- 清理旧槽
        for _, n in ipairs(SLOTS) do os.remove(dir .. n) end
        JY.Person[0]["姓名"] = "自检改名"
        SaveRecord(1)
        local after = io.open(dir .. "r1.grp", "rb") ~= nil
        local ovr = io.open(dir .. "r1.ovr", "rb")
        local ovrOK = false
        if ovr then
            local c = ovr:read("*a"); ovr:close()
            -- 两种键都可能：真实 hint（P0000，构建期已转换）或合成键（!Person.P.0，
            -- 构建期判定为纯 ASCII 未转换）。只要键值对应即可。
            ovrOK = c:find("P0000=自检改名", 1, true) ~= nil
                 or c:find("!Person.P.0=自检改名", 1, true) ~= nil
        end
        -- 回读：覆盖表生效
        local readback = false
        if after and ovrOK then
            LoadRecord(1)
            readback = JY.Person[0] and JY.Person[0]["姓名"] == "自检改名"
        end
        saveOK = after and ovrOK and readback
    end)
    if not ok then saveOK = false end

    -- 恢复到源状态（无论自检成功与否）
    restoreSlots()
    LoadRecord(0)
end)
print("SAVE=" .. (saveOK and "OK" or "FAIL"))
