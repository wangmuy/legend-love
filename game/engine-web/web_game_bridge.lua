-- web_game_bridge.lua
-- Web MUD 游戏框架集成层
-- processEventQueue + 兼容函数 + 模块加载

-- WebUI 输出辅助
_G.WebUI = {}

function _G.WebUI.write(text)
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write(tostring(text) .. "\n")
    end
end

function _G.WebUI.writeLine(text)
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write(tostring(text))
    end
end

function _G.WebUI.separator()
    _G.JSBridge.write(string.rep("─", 40) .. "\n")
end

function _G.WebUI.title(text)
    _G.JSBridge.write("\n" .. tostring(text) .. "\n")
    _G.JSBridge.write(string.rep("═", #tostring(text)) .. "\n")
end

-- io 桩函数（浏览器环境无文件系统）
_G.io = {
    open = function() return nil end,
    lines = function() return function() return nil end end,
    input = function() end,
    output = function() end,
    tmpfile = function() return nil end,
    type = function() return nil end,
    write = function() end,
    read = function() return nil end,
}

-- 兼容函数映射
_G.Cls = function()
    EngineAPI.render.drawBackground({0, 0, 0})
end

_G.ShowScreen = function()
    EngineAPI.render.present()
end

_G.DrawString = function(x, y, str, color, size)
    EngineAPI.render.text(x, y, str, color, size)
end

_G.DrawBox = function(x1, y1, x2, y2, color)
    EngineAPI.render.text(x1, y1, string.rep("─", 20), color)
end

_G.DrawMMap = function()
end

_G.DrawSMap = function()
end

_G.DrawHead = function(x, y, headId) end
_G.DrawHeadPic = function(x, y, headId) end
_G.PlayMIDI = function() end

-- 框架模块源存储
_G.FrameworkSources = _G.FrameworkSources or {}

function _G.registerFrameworkModule(name, source)
    _G.FrameworkSources[name] = source
    package.preload[name] = function()
        local fn, err = load(source, "@" .. name)
        if not fn then
            EngineAPI.debug.log("加载模块失败 " .. name .. ": " .. tostring(err))
            return {}
        end
        local ok, result = pcall(fn)
        if not ok then
            EngineAPI.debug.log("执行模块失败 " .. name .. ": " .. tostring(err))
            return {}
        end
        return result
    end
end

-- Slice 4: Web MUD 版 instruct 函数（供 oldevent 脚本使用）
rawset(_G, "instruct_0", function()
    local w = rawget(_G, "WebUI")
    if w then w.separator() end
end)

rawset(_G, "instruct_1", function(talkId, headId)
    local dc = rawget(_G, "initDataSource")
    if not dc then return end
    local raw = dc["dialogues"]
    if not raw then return end
    -- dialogues 可能是 {dialogues=[...]} 或直接是列表
    local dlg = raw["dialogues"] or raw
    if type(dlg) ~= "table" then return end
    for _, entry in ipairs(dlg) do
        if entry.id == tonumber(talkId) then
            local text = entry.text
            if type(text) == "table" then
                text = text[tostring(headId or 1)]
            end
            if text then
                local w = rawget(_G, "WebUI")
                if w then w.write(tostring(text)) end
            else
                local w = rawget(_G, "WebUI")
                if w then w.write("[对话文本为空, talkId=" .. tostring(talkId) .. "]") end
            end
            return
        end
    end
    local w = rawget(_G, "WebUI")
    if w then w.write("[未找到对话, talkId=" .. tostring(talkId) .. "]") end
end)

-- WaitKey — 供 oldevent 脚本使用，等待用户输入后继续
rawset(_G, "WaitKey", function()
    local w = rawget(_G, "WebUI")
    if w then w.write("按回车继续...") end
    local CoroutineScheduler = rawget(_G, "CoroutineScheduler")
    if CoroutineScheduler then
        local cs = CoroutineScheduler.getInstance()
        if cs and cs.waitForKey then
            cs:waitForKey()
        end
    end
end)

-- P0 instruct 函数 — 影响游戏流程的
rawset(_G, "instruct_3", function(...)
    -- 修改场景事件: oldevent 脚本执行时修改事件表
    -- no-op: Web MUD 中运行时事件无需持久化
end)

rawset(_G, "instruct_2", function(...)
    -- 修改场景出入口: no-op
end)

rawset(_G, "instruct_40", function(dir)
    local JY = rawget(_G, "JY")
    if JY then JY.Base["人方向"] = dir end
end)

rawset(_G, "instruct_27", function() end)  -- 动画, no-op
rawset(_G, "instruct_67", function() end)  -- 音效, no-op

rawset(_G, "instruct_13", function(...)
    -- 菜单选择: 交给 MenuAsync 处理
end)

rawset(_G, "instruct_32", function(...)
    -- 给/取物品: 操作 JY.Base["物品N"]
end)

rawset(_G, "instruct_37", function() end)  -- 场景音乐, no-op

rawset(_G, "instruct_56", function(...)
    -- 队伍: no-op
end)

rawset(_G, "instruct_26", function(...)
    -- 修改角色属性: no-op
end)

-- 功能性 instruct（instruct-game-logic）

rawset(_G, "instruct_11", function()
    -- 住宿询问
    local w = rawget(_G, "WebUI")
    if w then w.write("是否住宿？") end
    local MenuAsync = rawget(_G, "MenuAsync")
    if MenuAsync then
        local ok = MenuAsync.ShowMenu2Coroutine({{"是", nil, 1}, {"否", nil, 2}}, 2, 0, 0, 0, 0, 0, 0, 1)
        if ok and ok == 1 then
            rawget(_G, "instruct_12")()
        end
    end
end)

rawset(_G, "instruct_12", function()
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[0] then
        local p0 = JY.Person[0]
        p0["生命"] = p0["生命最大值"]
        p0["体力"] = 100
        p0["内力"] = p0["内力最大值"]
    end
    local w = rawget(_G, "WebUI")
    if w then w.write("体力完全恢复了。") end
end)

rawset(_G, "instruct_14", function()
    local sh = rawget(_G, "SmapHandlers")
    if sh and sh.look then sh.look({}) end
end)

rawset(_G, "instruct_19", function(x, y)
    local JY = rawget(_G, "JY")
    if JY then
        JY.Base["人X1"] = x
        JY.Base["人Y1"] = y
    end
end)

rawset(_G, "instruct_31", function(itemId, count, flag)
    local JY = rawget(_G, "JY")
    if not JY then return -1 end
    JY.Base = JY.Base or {}
    if itemId == 0 then
        local money = JY.Base["金钱"] or 0
        if flag == 0 then return (money >= (count or 0)) and 1 or 0 end
        if flag == 1 then JY.Base["金钱"] = math.max(0, money - (count or 0)); return 1 end
        if flag == 2 then JY.Base["金钱"] = (money or 0) + (count or 0); return 1 end
        return -1
    end
    -- 物品检查（非金钱）: 遍历背包
    local total = 0
    for i = 1, 30 do
        if JY.Base["物品" .. i] == itemId then
            total = total + (JY.Base["物品数量" .. i] or 1)
        end
    end
    if flag == 0 then return (total >= (count or 1)) and 1 or 0 end
    if flag == 1 then
        local remain = count or 1
        for i = 1, 30 do
            if remain <= 0 then break end
            if JY.Base["物品" .. i] == itemId then
                local qty = JY.Base["物品数量" .. i] or 1
                local take = math.min(qty, remain)
                JY.Base["物品数量" .. i] = qty - take
                remain = remain - take
                if JY.Base["物品数量" .. i] <= 0 then
                    JY.Base["物品" .. i] = 0
                end
            end
        end
        return (remain <= 0) and 1 or 0
    end
    return -1
end)

-- 兜底: 所有未显式实现的 instruct_* 输出 debug 日志
for i = 0, 66 do
    if not rawget(_G, "instruct_" .. i) then
        rawset(_G, "instruct_" .. i, function(...)
            EngineAPI.debug.log("instruct_" .. i .. " 未实现(no-op)")
        end)
    end
end

-- 调试函数（在 setmetatable(_G) 之前定义，之后可调用）

-- D* 事件数据访问（event-data-access）
-- 原版 GetD/SetD 操作 JY.D{sceneId} Lua 运行时表
-- 首次访问某场景时，从 initDataSource.events 拷贝到 JY.D{sceneId}

local function ensureSceneDEvents(sceneId)
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.D = JY.D or {}
    if JY.D[sceneId] then return end  -- 已加载
    
    local ds = rawget(_G, "initDataSource")
    local events = ds and ds["events"]
    if not events then
        JY.D[sceneId] = {}
        return
    end
    
    -- 从 initDataSource.events 拷贝该场景的所有事件
    local sceneEvents = {}
    -- events 是 [sceneId, layer, x, y, eventType, ...] 的数组
    for _, evt in ipairs(events) do
        if evt[1] == sceneId then
            table.insert(sceneEvents, evt)
        end
    end
    JY.D[sceneId] = sceneEvents
end

rawset(_G, "GetD", function(sceneId, eventId, field)
    sceneId = tonumber(sceneId) or sceneId
    eventId = tonumber(eventId) or 0
    field = tonumber(field) or 0
    
    ensureSceneDEvents(sceneId)
    local JY = rawget(_G, "JY")
    local sceneD = JY and JY.D and JY.D[sceneId]
    if not sceneD then return 0 end
    
    local evt = sceneD[eventId]
    if not evt then return 0 end
    
    local val = evt[field]
    return val or 0
end)

rawset(_G, "SetD", function(sceneId, eventId, field, value)
    sceneId = tonumber(sceneId) or sceneId
    eventId = tonumber(eventId) or 0
    field = tonumber(field) or 0
    
    ensureSceneDEvents(sceneId)
    local JY = rawget(_G, "JY")
    local sceneD = JY and JY.D and JY.D[sceneId]
    if not sceneD then return end
    
    if not sceneD[eventId] then
        sceneD[eventId] = {}
    end
    sceneD[eventId][field] = value
end)

rawset(_G, "GetS", function(id, x, y, level)
    return 0  -- 场景格子数据在 MUD 中简化
end)

rawset(_G, "SetS", function(id, x, y, level, value)
    -- no-op，MUD 中不需要
end)
function _G.__debug_coro_state()
    local cs = package.loaded["framework.coroutine_scheduler"]
    if not cs then return {} end
    local s = cs.getInstance()
    local all = s:getAllCoroutines()
    local r = {}
    for _, id in ipairs(all) do
        local info = s:getInfo(id)
        r[#r+1] = {id=id, status=info.status, waitingFor=info.waitingFor}
    end
    return r
end

-- 绘制状态跟踪（必须在前，returnToStartMenu 需要访问）
local lastDrawState = nil

-- 初始化框架
function _G.initWebFramework()
    -- 0. 先加载 config 确保 CONFIG 全局变量存在
    require("framework.config")
    
    -- 初始化 __quiet 标志（必须在 setmetatable(_G) 之前存在）
    _G.__quiet = false

    -- 1. 加载脚本模块
    -- 先保存我们的 instruct 函数，脚本加载会覆盖它们
    local _our_instruct = {}
    for i = 0, 66 do
        local fn = rawget(_G, "instruct_" .. i)
        if fn then _our_instruct[i] = fn end
    end
    local scriptList = {
        "script/jymain.lua",
        "script/jyconst.lua",
        "script/jymodify.lua",
    }
    for _, path in ipairs(scriptList) do
        local source = _G.FrameworkSources[path]
        if source then
            local fn, err = load(source, "@" .. path)
            if fn then
                local ok, result = pcall(fn)
                if ok then
                    EngineAPI.debug.log("  " .. path .. ": OK")
                else
                    EngineAPI.debug.log("  " .. path .. ": FAILED " .. tostring(result))
                end
            else
                EngineAPI.debug.log("  " .. path .. ": 编译失败 " .. tostring(err))
            end
        else
            EngineAPI.debug.log("  " .. path .. ": 未找到")
        end
    end

    -- 脚本加载后会覆盖 DrawSMap/DrawMMap（jymain.lua 定义了自己的版本），
    -- 重新安装 Web MUD 空桩版本
    _G.DrawMMap = function() end
    _G.DrawSMap = function() end
    -- script 加载后 jymain.lua 覆盖了 instruct 函数，恢复 Web MUD 版本
    for i = 0, 66 do
        if _our_instruct[i] then
            _G["instruct_" .. i] = _our_instruct[i]
        end
    end

    -- 2. 初始化游戏适配器
    require("framework.lib_log")
    _G.EventBridge = require("framework.event_bridge")
    _G.StateMachine = require("framework.state_machine")
    _G.MenuAsync = require("framework.menu_async")
    _G.CoroutineScheduler = require("framework.coroutine_scheduler")
    _G.AsyncDialog = require("framework.async_dialog")
    -- 事件系统集成
    require("framework.async_globals")
    require("framework.script_loader")
    require("framework.async_wrapper")
    _G.EventExecutor = require("framework.event_executor")
    -- CommandEngine already loaded as global via loadLuaModule in index.js
    if not _G.CommandEngine then
        _G.CommandEngine = require("web_command_engine")
    end
    -- 注册内置命令（对所有状态生效）
    local CE = _G.CommandEngine
    local builtInCmds = {
        help = { handler = function(args) CE.showHelp(args) end, description = "显示帮助信息" },
        choose = { handler = function(args) CE.handleChoose(args) end, description = "选择菜单项: choose <编号>" },
    }
    for _, stateId in ipairs({0, 1, 2, 3, 4}) do
        CE.registerCommands(stateId, builtInCmds)
    end

    -- 在 init() 之前覆写 JYMainAdapter 的方法
    -- 注意：init() 内部会调用 showStartMenuCoroutine，所以必须在之前覆写
    -- init() 会设置 setmetatable(_G, {__index=error, __newindex=error})，
    -- 因此覆写函数体内必须使用 rawget/rawset 访问 _G
    local JYMainAdapter = require("framework.jymain_adapter")
    -- 确保 initCoroutine 中的 JYMainAdapter 引用也看到覆写
    -- 直接从 package.loaded 获取并写入
    local target = package.loaded["framework.jymain_adapter"]
    if not target then target = JYMainAdapter end
    local startNewGameAdapter = target  -- 模块表引用

    -- 保存原始函数引用，覆写后替换
    -- 用 rawset 直接写入 _G，因为 initCoroutine 中 JYMainAdapter 是全局引用
    rawset(_G, "JYMainAdapter", target)

    -- 覆写 loadGame：Web MUD 无二进制存档文件
    startNewGameAdapter.loadGame = function()
        local WebUI = rawget(_G, "WebUI")
        if WebUI then WebUI.write("没有存档，输入 choose 1 返回菜单重新开始游戏\n") end
    end

    -- 覆写 startNewGame：Web MUD 无法读取 R*.idx/grp 文件，直接创建默认数据
    startNewGameAdapter.startNewGame = function(menux)
        local JY = rawget(_G, "JY")
        if not JY then JY = {}; rawset(_G, "JY", JY) end
        JY.Base = JY.Base or {}
        JY.Person = JY.Person or {}
        JY.Person[0] = JY.Person[0] or {}

        local P0 = JY.Person[0]
        local CC = rawget(_G, "CC")
        P0["姓名"] = CC and CC.NewPersonName or "小虾米"
        P0["头像"] = 1
        P0["体力最大值"] = 100
        P0["体力"] = 100
        P0["经验"] = 0
        P0["等级"] = 1
        P0["声望"] = 0
        P0["品德"] = 50
        P0["第一项武功"] = 0
        P0["武功数量"] = 0
        P0["人X"] = 364
        P0["人Y"] = 284
        P0["人朝向"] = 0

        local function generateWebAttrs()
            local P0 = JY.Person[0]
            P0["内力性质"] = math.random(0, 2)
            P0["内力最大值"] = math.random(20) + 21
            P0["攻击力"] = math.random(10) + 21
            P0["防御力"] = math.random(10) + 21
            P0["轻功"] = math.random(10) + 21
            P0["医疗能力"] = math.random(10) + 21
            P0["用毒能力"] = math.random(10) + 21
            P0["解毒能力"] = math.random(10) + 21
            P0["抗毒能力"] = math.random(10) + 21
            P0["拳掌"] = math.random(10) + 21
            P0["御剑"] = math.random(10) + 21
            P0["耍刀"] = math.random(10) + 21
            P0["特殊武功"] = math.random(10) + 21
            P0["暗器"] = math.random(10) + 21
            P0["生命增长"] = math.random(5) + 3
            P0["生命最大值"] = P0["生命增长"] * 3 + 29
            local rate = math.random(0, 9)
            if rate < 2 then
                P0["资质"] = math.random(35) + 30
            elseif rate <= 7 then
                P0["资质"] = math.random(20) + 60
            else
                P0["资质"] = math.random(20) + 75
            end
            P0["生命"] = P0["生命最大值"]
            P0["内力"] = P0["内力最大值"]
        end

        local satisfied = false
        while not satisfied do
            generateWebAttrs()

            local WebUI = rawget(_G, "WebUI")
            WebUI.write(string.format("生命:%d/%d  内力:%d/%d  体力:%d/%d",
                P0["生命"], P0["生命最大值"],
                P0["内力"], P0["内力最大值"],
                P0["体力"], P0["体力最大值"]))
            WebUI.write(string.format("攻击:%d  防御:%d  轻功:%d  资质:%d",
                P0["攻击力"], P0["防御力"], P0["轻功"], P0["资质"]))
            WebUI.write(string.format("拳掌:%d  御剑:%d  耍刀:%d  特殊:%d  暗器:%d",
                P0["拳掌"], P0["御剑"], P0["耍刀"], P0["特殊武功"], P0["暗器"]))
            WebUI.write(string.format("医疗:%d  用毒:%d  解毒:%d  抗毒:%d",
                P0["医疗能力"], P0["用毒能力"], P0["解毒能力"], P0["抗毒能力"]))
            WebUI.write(string.format("内力性质:%s  生命增长:%d",
                P0["内力性质"] == 0 and "无" or P0["内力性质"] == 1 and "阳性" or "阴性",
                P0["生命增长"]))

            WebUI.write("输入 choose 1 (是) 或 choose 2 (否)，choose 0 返回开始菜单，输入 help 查看命令")
            local menu = {
                {"是 ", nil, 1},
                {"否 ", nil, 2},
            }
            local MenuAsync = rawget(_G, "MenuAsync")
            local ok = MenuAsync.ShowMenu2Coroutine(menu, 2, 0,
                0, 0, 0, 0, 0, 1, CC.DefaultFont, rawget(_G, "C_RED"), rawget(_G, "C_WHITE"))

            if ok == 1 then
                satisfied = true
            elseif ok == 0 then
                local JSBridge = rawget(_G, "JSBridge")
                if JSBridge then JSBridge.write("返回开始菜单\n") end
                local CE = rawget(_G, "CommandEngine")
                CE.registerCommands(0, {
                    help = { handler = function(args) CE.showHelp(args) end, description = "显示帮助信息" },
                    choose = { handler = function(args) CE.handleChoose(args) end, description = "选择菜单项: choose <编号>" },
                })
                local EventBridge = rawget(_G, "EventBridge")
                EventBridge.getInstance():switchState(0)
                return
            end
        end

        JY.Base["人X1"] = 364
        JY.Base["人Y1"] = 284
        JY.Base["人X"] = 364
        JY.Base["人Y"] = 284
        JY.Base["人方向"] = 0
        JY.Base["场景X"] = 0
        JY.Base["场景Y"] = 0
        JY.Base["场景宽度"] = 64
        JY.Base["场景高度"] = 64

        JY.Scene = JY.Scene or {}
        JY.Scene[0] = JY.Scene[0] or {["名称"] = "小虾米居", ["进入条件"] = 0}
        JY.SubScene = 70  -- 主角的家（原版 CC.NewGameSceneID）
        JY.EnterSceneXY = JY.EnterSceneXY or {}
        -- 新游戏从主角的家场景开始，非大地图
        JY.Base["人X1"] = 19
        JY.Base["人Y1"] = 20
        JY.Status = 4  -- GAME_SMAP
        JY.MmapMusic = -1

        -- 修正主角的家场景类型（提取中类型为"inn"，应为"house"）
        local dc = rawget(_G, "initDataSource")
        local sceneTables = dc and dc["scenes"]
        if sceneTables then
            local sceneList = sceneTables["scenes"] or sceneTables
            if type(sceneList) == "table" then
                for _, s in ipairs(sceneList) do
                    if type(s) == "table" and s["代号"] == 70 then
                        s["类型"] = "house"
                        break
                    end
                end
            end
        end

        local WebUI = rawget(_G, "WebUI")
        WebUI.write("新游戏开始！你来到了金庸群侠传的世界。")
        WebUI.write("输入 help 查看可用命令，choose 查看交互对象")
        local SmapHandlers = rawget(_G, "SmapHandlers")
        if SmapHandlers then SmapHandlers.look({}) end
    end

    -- 覆写 showStartMenuCoroutine：loop 模式，每次循环都输出菜单文本和提示
    startNewGameAdapter.showStartMenuCoroutine = function()
        while true do
            local JY = rawget(_G, "JY")
            if JY and JY.Status ~= 0 then  -- GAME_START == 0
                break
            end
            local MenuAsync = rawget(_G, "MenuAsync")
            local CC = rawget(_G, "CC")
            if not MenuAsync or not CC then
                break
            end
            -- Web MUD: 每次循环输出输入提示（菜单项由主线程 ready 事件输出）
            local WebUI = rawget(_G, "WebUI")
            if WebUI then
                WebUI.write("输入 choose 1 开始新游戏，choose 2 载入进度，choose 3 离开")
            end
            local menu = {
                {"重新开始", nil, 1},
                {"载入进度", nil, 1},
                {"离开游戏", nil, 1},
            }
            local menuReturn = MenuAsync.ShowMenuCoroutine(menu, 3, 0, 0, 0, 0, 0, 0, 1, CC.DefaultFont, rawget(_G, "C_RED"), rawget(_G, "C_WHITE"))
            if menuReturn == 1 then
                startNewGameAdapter.startNewGame(0)
            elseif menuReturn == 2 then
                startNewGameAdapter.loadGame()
            elseif menuReturn == 3 then
                -- Web MUD: choose 3 = no-op，显示提示后继续显示开始菜单
                local WebUI = rawget(_G, "WebUI")
                if WebUI then
                    WebUI.write("游戏已退出。输入 choose 1 重新开始，choose 2 载入进度")
                end
            end
        end
    end

    local ok, err = pcall(function()
        -- 设置 _G.JYMainAdapter 指向模块表，init 协程通过它访问可看到覆写
        rawset(_G, "JYMainAdapter", JYMainAdapter)
        JYMainAdapter.init()
    end)
    if not ok then
        EngineAPI.debug.log("JYMainAdapter.init 失败: " .. tostring(err))
    end

    -- 覆写 Init_MMap/Init_SMap：Web MUD 无需加载贴图文件
    rawset(_G, "Init_MMap", function()
        JY.EnterSceneXY = nil
        JY.oldMMapX = -1
        JY.oldMMapY = -1
    end)
    rawset(_G, "Init_SMap", function(showname)
        JY.oldSMapX = -1
        JY.oldSMapY = -1
        JY.SubSceneX = 0
        JY.SubSceneY = 0
        JY.OldDPass = -1
        JY.D_Valid = nil
    end)
    rawset(_G, "CleanMemory", function() end)
    -- 覆写 MMAP/SMAP 状态处理器：Web MUD 通过命令处理，无需 game_states 渲染/更新
    local eb = _G.EventBridge and _G.EventBridge.getInstance()
    if eb then
        local noop = { enter = function() end, exit = function() end, update = function() end, draw = function() end }
        eb:registerState(GAME_MMAP, noop)
        eb:registerState(GAME_SMAP, noop)
        eb:registerState(GAME_FIRSTMMAP, noop)
    end

    -- 注册 MMAP/SMAP 命令（仅在对应状态下可用）
    if _G.MmapHandlers and _G.SmapHandlers then
        local mmapCmds = {
            list  = { handler = _G.MmapHandlers.list,  description = "列出可去场景并选择前往" },
            look  = { handler = _G.MmapHandlers.look,  description = "查看当前位置、坐标和附近场景" },
            walk  = { handler = _G.MmapHandlers.walk,  description = "行走: walk <方向> (n/s/e/w)" },
            quit  = { handler = _G.MmapHandlers.quit,  description = "退出当前游戏，返回开始菜单" },
            help  = { handler = CE.showHelp,           description = "显示帮助信息" },
            choose= { handler = CE.handleChoose,        description = "choose <编号> 选择菜单项" },
        }
        local smapCmds = {
            look  = { handler = _G.SmapHandlers.look,  description = "查看场景并选择交互对象" },
            rest  = { handler = _G.SmapHandlers.rest,  description = "休息恢复体力" },
            exits = { handler = _G.SmapHandlers.exits, description = "列出出口" },
            go    = { handler = _G.SmapHandlers.go,    description = "go <编号> 前往出口" },
            leave = { handler = _G.SmapHandlers.leave, description = "离开场景回到大地图" },
            help  = { handler = CE.showHelp,           description = "显示帮助信息" },
            choose= { handler = CE.handleChoose,        description = "choose <编号> 选择交互对象" },
        }
        CE.registerCommands(GAME_MMAP, mmapCmds)
        CE.registerCommands(GAME_SMAP, smapCmds)
        -- Slice 5: WMAP 战斗命令
        if _G.WmapHandlers then
            local wmapCmds = {
                look  = { handler = _G.WmapHandlers.look,  description = "查看战场态势" },
                choose= { handler = CE.handleChoose,        description = "choose <编号> 选择行动" },
            }
            CE.registerCommands(GAME_WMAP, wmapCmds)
        end
    end

    -- 全局函数：从游戏中返回开始菜单（由 MmapHandlers.quit 调用）
    rawset(_G, "returnToStartMenu", function()
        -- 重置游戏状态
        local JY = rawget(_G, "JY")
        if JY then
            JY.Base = {}
            JY.Person = {}
            JY.Scene = {}
            JY.Status = 0  -- GAME_START
        end

        -- 注册开始菜单命令
        local CE = rawget(_G, "CommandEngine")
        if CE then
            CE.registerCommands(0, {
                help = { handler = function(args) CE.showHelp(args) end, description = "显示帮助信息" },
                choose = { handler = function(args) CE.handleChoose(args) end, description = "选择菜单项: choose <编号>" },
            })
        end

        -- 清除活动菜单
        local MenuAsync = rawget(_G, "MenuAsync")
        if MenuAsync and MenuAsync.clear then MenuAsync.clear() end

        -- 显示返回消息
        local WebUI = rawget(_G, "WebUI")
        if WebUI then WebUI.write("已返回开始菜单。") end

        -- 强制重绘
        lastDrawState = nil

        -- 启动新的开始菜单协程
        local CoroutineScheduler = rawget(_G, "CoroutineScheduler")
        if CoroutineScheduler then
            local scheduler = CoroutineScheduler.getInstance()
            if scheduler then
                local JYMainAdapter = require("framework.jymain_adapter")
                scheduler:create(JYMainAdapter.showStartMenuCoroutine, "start-menu")
            end
        end
    end)

    -- 初始状态：保持游戏原有流程（开始菜单），玩家用 choose 1 开始新游戏
    _G.__quiet = true
end

local function determineDrawState()
    local AsyncDialog = _G.AsyncDialog or (package.loaded["framework.async_dialog"])
    if AsyncDialog and AsyncDialog.getInstance():hasDialog() then
        return "dialog"
    end
    local MenuAsync = _G.MenuAsync or (package.loaded["framework.menu_async"])
    if MenuAsync and MenuAsync.hasActiveMenu and MenuAsync.hasActiveMenu() then
        return "menu"
    end
    return "idle"
end

-- processEventQueue
function processEventQueue(timestamp)
    local AsyncDialog = _G.AsyncDialog or (package.loaded["framework.async_dialog"])
    local hasDialog = AsyncDialog and AsyncDialog.getInstance():hasDialog()
    local MenuAsync = _G.MenuAsync or (package.loaded["framework.menu_async"])
    local hasMenu = MenuAsync and MenuAsync.hasActiveMenu and MenuAsync.hasActiveMenu()

    -- 1. 处理输入事件（仅当无对话框时消费事件；对话框自己通过 lib.GetKey 消费）
    if not hasDialog and _G.JSBridge and _G.JSBridge.getEventCount and _G.JSBridge.getEventCount() > 0 then
        local evt = _G.JSBridge.getEvent()
        if evt and type(evt) == "table" and evt.type == "input" then
            local text = evt.data
            if text and text ~= "" then
                local cmd, arg = text:match("^(%S+)%s*(.-)$")
                cmd = cmd and cmd:lower() or ""

                if cmd == "choose" and hasMenu then
                    local n = tonumber(arg)
                    if n then
                        MenuAsync.closeMenu(n)
                        -- 菜单关闭后，协程可能立即重新创建菜单（如 showStartMenuCoroutine 循环）。
                        -- 强制重绘，确保新菜单的文本能输出到终端。
                        lastDrawState = nil
                    end
                elseif cmd == "choose" and not hasMenu then
                    -- SMAP/WMAP 状态无菜单时：choose N 选择交互对象
                    local JY = rawget(_G, "JY")
                    local n = tonumber(arg)
                    if JY and JY.Status == 4 and n and n > 0 then  -- GAME_SMAP
                        local sh = rawget(_G, "SmapHandlers")
                        if sh and sh.chooseInteraction then
                            sh.chooseInteraction(n)
                        end
                    elseif JY and JY.Status == 5 and n then  -- GAME_WMAP
                        local wh = rawget(_G, "WmapHandlers")
                        if wh and wh.chooseInteraction then
                            wh.chooseInteraction(n)
                        end
                    else
                        -- 非 SMAP/WMAP 状态：走 CommandEngine dispatch
                        local parsed = rawget(_G, "CommandEngine").parseCommand(text)
                        if parsed then
                            local handled = rawget(_G, "CommandEngine").dispatchCommand(parsed.cmd, parsed.args)
                            if not handled then
                                WebUI.write("未知命令: " .. cmd)
                                WebUI.write("当前可用命令: choose N (选择菜单项)")
                            end
                        end
                    end
                elseif rawget(_G, "CommandEngine") and rawget(_G, "CommandEngine").parseCommand then
                    local parsed = rawget(_G, "CommandEngine").parseCommand(text)
                    if parsed then
                        local handled = rawget(_G, "CommandEngine").dispatchCommand(parsed.cmd, parsed.args)
                        if not handled then
                            WebUI.write("未知命令: " .. cmd)
                            WebUI.write("当前可用命令: choose N (选择菜单项)")
                        end
                    end
                else
                    WebUI.write("未知命令: " .. cmd)
                    WebUI.write("当前可用命令: choose N (选择菜单项)")
                end
            end
        end
    end

    -- 2. 驱动协程调度器
    if CoroutineScheduler then
        local scheduler = CoroutineScheduler.getInstance()
        if scheduler and scheduler.update then
            scheduler:update(0)
        end
    end

    -- 3. 更新状态机
    if StateMachine then
        local sm = StateMachine.getInstance()
        if sm and sm.update then
            sm:update(0)
        end
    end

    -- 4. 更新对话框（内部调用 lib.GetKey 读取事件）
    if AsyncDialog then
        AsyncDialog.getInstance():update(0)
    end

    -- 5. 更新菜单（不绘制，仅处理逻辑）
    if MenuAsync then
        MenuAsync:update(0)
    end

    -- 6. 检测状态变化，决定是否需要重绘
    local currentState = determineDrawState()
    if currentState ~= lastDrawState then
        lastDrawState = currentState
        EngineAPI.render.drawBackground(0, 0, 0, 0, 0)
        if currentState == "dialog" then
            AsyncDialog.getInstance():draw()
        end
        if currentState == "menu" then
            MenuAsync:draw()
        end
        if StateMachine then
            local sm = StateMachine.getInstance()
            if sm and sm.draw then
                sm:draw()
            end
        end
        EngineAPI.render.present()
        
        -- 对话框状态下提示用户操作
        if currentState == "dialog" then
            WebUI.write("输入 choose 1 确认，choose 2 取消")
        end
    end
end
