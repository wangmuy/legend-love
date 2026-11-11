-- tests/unit/boot_one_mod.lua
-- 单 MOD 全启动链路验证（在独立进程中运行，保证全局状态干净）。
-- 用法: lua tests/unit/boot_one_mod.lua <slug> <Person> <Thing> <Scene> <Wugong> <heroIndex>
--
-- 由 test_mod_boot.lua 通过 shell 为 5 个「有问题」MOD 各调一次。
-- 独立进程是关键：真实启动是"一次进程一个 MOD"，同进程内多次重载
-- jymain/lib 会留下 JY 全局残留，反而不能证明真实启动路径。
--
-- 注意：主角姓名**不通过命令行传递**。Windows 上子进程参数要经过
-- cmd.exe 的代码页转换（GBK ↔ UTF-8），中文会变成 "小蝦�?2" 这类乱码，
-- 导致断言凭空失败。改为传一个序号，在本文件内查表。
package.path = "./?.lua;" .. package.path

-- 期望数据表：与 test_mod_boot.lua 的 PROBLEMATIC_MODS 一一对应（按 slug 查）
local EXPECT = {
    BookCalamity = { person = 800, thing = 550, scene = 139, wugong = 398, hero = "主角" },
    zheng        = { person = 320, thing = 200, scene =  84, wugong =  93, hero = "小蝦米" },
    loving       = { person = 320, thing = 200, scene =  84, wugong =  93, hero = "莫言" },
    awaken       = { person = 720, thing = 237, scene = 153, wugong = 163, hero = "北辰月" },
    pig3dos      = { person = 607, thing = 242, scene = 133, wugong = 202, hero = "主角" },
}

local slug      = arg[1]
local expPerson = tonumber(arg[2])
local expThing  = tonumber(arg[3])
local expScene  = tonumber(arg[4])
local expWugong = tonumber(arg[5])
-- arg[6] 保留兼容（旧调用方会传 hero），但不再使用命令行里的中文
local expHero   = (EXPECT[slug] and EXPECT[slug].hero) or arg[6]

local fails = {}
local function check(cond, msg)
    if cond then
        print("[PASS] " .. msg)
    else
        print("[FAIL] " .. msg)
        fails[#fails + 1] = msg
    end
end
local function eq(a, b, msg)
    check(a == b, string.format("%s (期望 %s, 实际 %s)", msg, tostring(b), tostring(a)))
end

-- ============ 无头 harness（bit32 + love stub + format 容错）============
require("tests.mod_boot_harness").setup()

-- ============ 启动 ============
package.loaded["framework.mod_data"] = nil
local ModData = require("framework.mod_data")
ModData.SetActive(slug)

_G.EngineAPI = require("tests.engine_test")
local EventBridge = require("framework.event_bridge")
require("framework.config")
_G.Byte = require("framework.lib_Byte")
require("engine-love2d.lib_love")
_G.lib = require("engine-love2d.engine_love2d")

local ok, err = pcall(function() lib.init() end)
check(ok, "lib.init 无报错: " .. tostring(err))

EventBridge.getInstance():init()
require(CONFIG.ScriptPath .. "jymain")
local JYMainAdapter = require("framework.jymain_adapter")
ok, err = pcall(function() JYMainAdapter.init() end)
check(ok, "JYMainAdapter.init 无报错: " .. tostring(err))

-- MOD 布局常量必须生效
eq(CC.PersonSize, 182, "CC.PersonSize=182（MOD 布局）")
eq(CC.ThingSize,  190, "CC.ThingSize=190（MOD 布局）")
eq(CC.SceneSize,  52,  "CC.SceneSize=52（MOD 布局）")
eq(CC.WugongSize, 136, "CC.WugongSize=136（MOD 布局）")

-- 读档
local okLoad, resLoad = pcall(function() return LoadRecord(0) end)
check(okLoad, "LoadRecord(0) 无报错: " .. tostring(resLoad))

eq(JY.PersonNum, expPerson, "PersonNum")
eq(JY.ThingNum,  expThing,  "ThingNum")
eq(JY.SceneNum,  expScene,  "SceneNum")
eq(JY.WugongNum, expWugong, "WugongNum")
eq(JY.Person[0]["姓名"], expHero, "主角姓名")

-- 全量字符串扫描
local fffd, ctrl, checked = 0, 0, 0
local function scan(tbl, num, fields)
    for i = 0, num - 1 do
        local rec = tbl[i]
        if rec then
            for _, fld in ipairs(fields) do
                local v = rec[fld]
                if type(v) == "string" then
                    checked = checked + 1
                    if v:find("\239\191\189", 1, true) then fffd = fffd + 1 end
                    if v:find("[\1-\31\127]") then ctrl = ctrl + 1 end
                end
            end
        end
    end
end
scan(JY.Person, JY.PersonNum, { "姓名", "外号" })
scan(JY.Thing,  JY.ThingNum,  { "名称", "名称2", "物品说明" })
scan(JY.Scene,  JY.SceneNum,  { "名称" })
scan(JY.Wugong, JY.WugongNum, { "名称" })

check(checked > 100, "扫描字段数 > 100（实际 " .. checked .. "）")
eq(fffd, 0, "全量字符串无 U+FFFD")
eq(ctrl, 0, "全量字符串无控制符")

-- 运行时帧
local okFrames, errFrames = pcall(function()
    for _ = 1, 10 do
        JYMainAdapter.update(0.016)
        EventBridge.getInstance():update(0.016)
    end
end)
check(okFrames, "运行时 10 帧无报错: " .. tostring(errFrames))

print(string.rep("-", 50))
if #fails == 0 then
    print("RESULT " .. slug .. ": OK")
    os.exit(0)
else
    print("RESULT " .. slug .. ": FAIL (" .. #fails .. ")")
    os.exit(1)
end
