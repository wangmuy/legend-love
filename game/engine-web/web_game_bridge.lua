-- web_game_bridge.lua
-- Web MUD 游戏框架集成层
-- processEventQueue + 兼容函数 + 模块加载

-- WebUI 输出辅助
_G.WebUI = {}

-- 预注册运行时需要的全局变量（必须在 setmetatable(_G) 之前，否则 _G.xxx 触发 __index=error）
rawset(_G, "eventConsumed", {})

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
                if w then
                    -- 查找说话人名称
                    local speakerName = "???"
                    -- 常见头像 ID → 名称映射（头像 ID ≠ 人物代号）
                    local HEAD_NAME_MAP = {
                        [0] = "主角",
                        [73] = "南贤",
                        [74] = "北丑",
                        [105] = "掌柜",
                        [106] = "店小二",
                        [111] = "韦小宝",
                        [114] = "软体娃娃",
                    }
                    speakerName = HEAD_NAME_MAP[headId]
                    if not speakerName then
                        if headId == 0 then
                            local JY = rawget(_G, "JY")
                            speakerName = JY and JY.Person and JY.Person[0] and JY.Person[0]["姓名"] or "主角"
                        else
                            -- 尝试按头像代号查找
                            local chars = dc["chars"]
                            if not chars then
                                local ds = rawget(_G, "initDataSource")
                                chars = ds and ds["chars"]
                            end
                            if chars then
                                local clist = chars["chars"] or chars
                                if type(clist) == "table" then
                                    for _, c in ipairs(clist) do
                                        if c["头像代号"] == headId or c["代号"] == headId then
                                            speakerName = c["姓名"] or "???"
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    w.write("【" .. speakerName .. "】" .. tostring(text))
                end
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
rawset(_G, "instruct_3", function(sceneid, id, v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10)
    -- 修改D*（原版 jymain.lua:3133 实现）
    -- sceneid: 场景id, -2=当前场景
    -- id: D*编号, -2=当前事件编号(JY.CurrentD)
    -- v0-v10: D*参数, -2=不变
    local JY = rawget(_G, "JY")
    if not JY then return end
    if sceneid == -2 then sceneid = JY.SubScene end
    if id == -2 then id = JY.CurrentD end
    local SetD = rawget(_G, "SetD")
    if not SetD then return end
    for field = 0, 10 do
        local v = select(field + 1, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10)
        if v ~= -2 then
            SetD(sceneid, id, field, v)
        end
    end
end)

rawset(_G, "instruct_2", function(itemId, count)
    -- instruct_2(itemId, count): 得到物品（原版注释: 2(2):得到物品）
    -- 给玩家背包添加物品/金钱
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.Base = JY.Base or {}
    count = count or 1
    itemId = tonumber(itemId) or 0
    -- 银两（物品代号174）：加到 JY.Base["金钱"]
    if itemId == 174 then
        JY.Base["金钱"] = (JY.Base["金钱"] or 0) + count
        local WebUI = rawget(_G, "WebUI")
        if WebUI then WebUI.write(string.format("获得 %d 两银子。", count)) end
        return
    end
    -- 普通物品：找到空槽位放入
    for i = 1, 30 do
        if not JY.Base["物品" .. i] or JY.Base["物品" .. i] == 0 then
            JY.Base["物品" .. i] = itemId
            JY.Base["物品数量" .. i] = (JY.Base["物品数量" .. i] or 0) + count
            -- 从 initDataSource.items 查找物品名称（JY.Thing 未被 initGameState 填充）
            local name = ("物品" .. itemId)
            local ds = rawget(_G, "initDataSource")
            if ds and ds.items then
                local list = ds.items["items"] or ds.items
                if type(list) == "table" then
                    for _, it in ipairs(list) do
                        if type(it) == "table" and tonumber(it["代号"]) == itemId then
                            name = it["名称"] or name
                            break
                        end
                    end
                end
            end
            local WebUI = rawget(_G, "WebUI")
            if WebUI then WebUI.write(string.format("获得 %s x%d。", name, count)) end
            return
        end
    end
    -- 背包已满
    local WebUI = rawget(_G, "WebUI")
    if WebUI then WebUI.write("背包已满！") end
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

rawset(_G, "instruct_32", function(giveFlag, thingId, num, ...)
    -- 给/取物品: 操作 JY.Base["物品N"]
    -- oldevent 调用方式: instruct_32(174, -20) 扣除银两
    -- 或: instruct_32(0, personid, thingId, num) 给某人物品
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.Base = JY.Base or {}
    local id = tonumber(thingId) or 0
    local count = tonumber(num) or 0
    -- 银两（物品174）
    if id == 174 then
        JY.Base["金钱"] = (JY.Base["金钱"] or 0) + count
        return
    end
    -- 普通物品
    if count > 0 then
        -- 添加物品到空槽
        for i = 1, 30 do
            if not JY.Base["物品" .. i] or JY.Base["物品" .. i] == 0 then
                JY.Base["物品" .. i] = id
                JY.Base["物品数量" .. i] = (JY.Base["物品数量" .. i] or 0) + count
                return
            end
        end
    else
        -- 扣除物品（负数量）
        local remain = -count
        for i = 1, 30 do
            if remain <= 0 then break end
            if JY.Base["物品" .. i] == id then
                local qty = JY.Base["物品数量" .. i] or 1
                local take = math.min(qty, remain)
                JY.Base["物品数量" .. i] = qty - take
                remain = remain - take
                if JY.Base["物品数量" .. i] <= 0 then
                    JY.Base["物品" .. i] = 0
                end
            end
        end
    end
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
    -- 住宿询问（原版返回 true=住宿, false=不住）
    local w = rawget(_G, "WebUI")
    if w then w.write("是否住宿？") end
    local MenuAsync = rawget(_G, "MenuAsync")
    if MenuAsync then
        local ok, result = pcall(MenuAsync.ShowMenu2Coroutine, {{"是", nil, 1}, {"否", nil, 2}}, 2, 0, 0, 0, 0, 0, 0, 1)
        if ok then
            return result == 1
        end
    end
    return false
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
    if flag == 0 then return (total >= (count or 1)) end
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

-- instruct_51: 问软体娃娃 — 随机显示 18 条游戏提示之一
rawset(_G, "instruct_51", function()
    local Rnd = rawget(_G, "Rnd") or function(i) return math.random(i) - 1 end
    local talkId = 2547 + Rnd(18)
    local instruct_1 = rawget(_G, "instruct_1")
    if instruct_1 then
        instruct_1(talkId, 114, 0)
    end
end)

-- === 以下 instruct_* 由 jymain.lua 定义但被 Web MUD 空桩覆盖 ===
-- 由于 catch-all 循环会保存空桩并在 jymain.lua 加载后恢复，
-- 此处提前实现真实逻辑，确保被 _our_instruct 保存。

-- instruct_9: 是否要求加入队伍（安全版本，非协程上下文返回 false）
rawset(_G, "instruct_9", function()
    local co = coroutine.running()
    if not co then return false end
    local ok, result = pcall(function()
        local AsyncMessageBox = require("framework.async_message_box")
        return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否要求加入？", C_ORANGE, CC.DefaultFont)
    end)
    if ok then return result == 1 end
    return false
end)

-- instruct_10: 加入队员
rawset(_G, "instruct_10", function(personid)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[personid] then return end
    for i = 2, CC.TeamNum do
        if JY.Base["队伍" .. i] == nil or JY.Base["队伍" .. i] < 0 then
            JY.Base["队伍" .. i] = personid
            for j = 1, 4 do
                local id = JY.Person[personid]["携带物品" .. j]
                local num = JY.Person[personid]["携带物品数量" .. j]
                if id and id > 0 then
                    local instruct_32 = rawget(_G, "instruct_32")
                    if instruct_32 then instruct_32(0, personid, id, 0) end
                    instruct_31(id, num, 2)
                end
            end
            return
        end
    end
end)

-- instruct_16: 队伍中是否有某人
rawset(_G, "instruct_16", function(personid)
    local JY = rawget(_G, "JY")
    if not JY then return false end
    for i = 1, CC.TeamNum do
        if JY.Base["队伍" .. i] == personid then return true end
    end
    return false
end)

-- instruct_18: 是否有某种物品
rawset(_G, "instruct_18", function(thingid)
    local JY = rawget(_G, "JY")
    if not JY then return false end
    for i = 1, CC.MyThingNum or 30 do
        if JY.Base["物品" .. i] == thingid then return true end
    end
    return false
end)

-- instruct_20: 判断队伍是否满
rawset(_G, "instruct_20", function()
    local JY = rawget(_G, "JY")
    if not JY then return false end
    return (JY.Base["队伍" .. CC.TeamNum] or 0) >= 0
end)

-- instruct_21: 离队
rawset(_G, "instruct_21", function(personid)
    local JY = rawget(_G, "JY")
    if not JY then return end
    local j = 0
    for i = 1, CC.TeamNum do
        if JY.Base["队伍" .. i] == personid then j = i; break end
    end
    if j == 0 then return end
    for i = j + 1, CC.TeamNum do
        JY.Base["队伍" .. i - 1] = JY.Base["队伍" .. i]
    end
    JY.Base["队伍" .. CC.TeamNum] = -1
end)

-- instruct_22: 内力降为0
rawset(_G, "instruct_22", function()
    local JY = rawget(_G, "JY")
    if not JY then return end
    for i = 1, CC.TeamNum do
        local pid = JY.Base["队伍" .. i]
        if pid and pid >= 0 and JY.Person[pid] then
            JY.Person[pid]["内力"] = 0
        end
    end
end)

-- instruct_23: 设置用毒
rawset(_G, "instruct_23", function(personid, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[personid] then
        JY.Person[personid]["用毒能力"] = value
    end
end)

-- instruct_28: 判断品德
rawset(_G, "instruct_28", function(personid, vmin, vmax)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[personid] then return false end
    local v = JY.Person[personid]["品德"] or 0
    return v >= vmin and v <= vmax
end)

-- instruct_29: 判断攻击力
rawset(_G, "instruct_29", function(personid, vmin, vmax)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[personid] then return false end
    local v = JY.Person[personid]["攻击力"] or 0
    return v >= vmin and v <= vmax
end)

-- instruct_33: 学会武功
rawset(_G, "instruct_33", function(personid, wugongid, flag)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[personid] then return end
    local added = false
    for i = 1, 10 do
        if JY.Person[personid]["武功" .. i] == 0 or not JY.Person[personid]["武功" .. i] then
            JY.Person[personid]["武功" .. i] = wugongid
            JY.Person[personid]["武功等级" .. i] = 0
            added = true
            break
        end
    end
    if not added then
        JY.Person[personid]["武功10"] = wugongid
        JY.Person[personid]["武功等级10"] = 0
    end
end)

-- instruct_34: 资质增加
rawset(_G, "instruct_34", function(id, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[id] then
        JY.Person[id]["资质"] = (JY.Person[id]["资质"] or 0) + value
    end
end)

-- instruct_35: 设置武功
rawset(_G, "instruct_35", function(personid, idx, wugongid, wugonglevel)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[personid] then return end
    if idx and idx >= 0 then
        JY.Person[personid]["武功" .. (idx + 1)] = wugongid
        JY.Person[personid]["武功等级" .. (idx + 1)] = wugonglevel
    else
        for i = 1, 10 do
            if not JY.Person[personid]["武功" .. i] or JY.Person[personid]["武功" .. i] == 0 then
                JY.Person[personid]["武功" .. i] = wugongid
                JY.Person[personid]["武功等级" .. i] = wugonglevel
                return
            end
        end
        JY.Person[personid]["武功1"] = wugongid
        JY.Person[personid]["武功等级1"] = wugonglevel
    end
end)

-- instruct_36: 判断主角性别
rawset(_G, "instruct_36", function(sex)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[0] then return false end
    return JY.Person[0]["性别"] == sex
end)

-- instruct_39: 打开场景
rawset(_G, "instruct_39", function(sceneid)
    local JY = rawget(_G, "JY")
    if JY and JY.Scene and JY.Scene[sceneid] then
        JY.Scene[sceneid]["进入条件"] = 0
    end
end)

-- instruct_41: 其他人员增加物品
rawset(_G, "instruct_41", function(personid, thingid, num)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person or not JY.Person[personid] then return end
    local k = 0
    for i = 1, 4 do
        if JY.Person[personid]["携带物品" .. i] == thingid then
            JY.Person[personid]["携带物品数量" .. i] = (JY.Person[personid]["携带物品数量" .. i] or 1) + num
            k = i
            break
        end
    end
    if k == 0 then
        for i = 1, 4 do
            if not JY.Person[personid]["携带物品" .. i] or JY.Person[personid]["携带物品" .. i] <= 0 then
                JY.Person[personid]["携带物品" .. i] = thingid
                JY.Person[personid]["携带物品数量" .. i] = num
                break
            end
        end
    end
end)

-- instruct_42: 队伍中是否有女性
rawset(_G, "instruct_42", function()
    local JY = rawget(_G, "JY")
    if not JY then return false end
    for i = 1, CC.TeamNum do
        local pid = JY.Base["队伍" .. i]
        if pid and pid >= 0 and JY.Person and JY.Person[pid] and JY.Person[pid]["性别"] == 1 then
            return true
        end
    end
    return false
end)

-- instruct_43: 是否有某种物品（委托给 instruct_18）
rawset(_G, "instruct_43", function(thingid)
    local instruct_18 = rawget(_G, "instruct_18")
    if instruct_18 then return instruct_18(thingid) end
    return false
end)

-- instruct_45: 增加轻功
rawset(_G, "instruct_45", function(id, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[id] then
        JY.Person[id]["轻功"] = (JY.Person[id]["轻功"] or 0) + value
    end
end)

-- instruct_46: 增加内力
rawset(_G, "instruct_46", function(id, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[id] then
        JY.Person[id]["内力最大值"] = (JY.Person[id]["内力最大值"] or 0) + value
    end
end)

-- instruct_47: 增加攻击力
rawset(_G, "instruct_47", function(id, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[id] then
        JY.Person[id]["攻击力"] = (JY.Person[id]["攻击力"] or 0) + value
    end
end)

-- instruct_48: 增加生命
rawset(_G, "instruct_48", function(id, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[id] then
        JY.Person[id]["生命最大值"] = (JY.Person[id]["生命最大值"] or 0) + value
    end
end)

-- instruct_49: 设置内力属性
rawset(_G, "instruct_49", function(personid, value)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[personid] then
        JY.Person[personid]["内力性质"] = value
    end
end)

-- instruct_50: 判断是否有5种物品
rawset(_G, "instruct_50", function(id1, id2, id3, id4, id5)
    local instruct_18 = rawget(_G, "instruct_18")
    if not instruct_18 then return false end
    local num = 0
    for _, id in ipairs({id1, id2, id3, id4, id5}) do
        if instruct_18(id) then num = num + 1 end
    end
    return num == 5
end)

-- instruct_52: 看品德
rawset(_G, "instruct_52", function()
    local JY = rawget(_G, "JY")
    local morale = JY and JY.Person and JY.Person[0] and JY.Person[0]["品德"] or 0
    local WebUI = rawget(_G, "WebUI")
    if WebUI then WebUI.write(string.format("品德指数: %d", morale)) end
end)

-- instruct_53: 看声望
rawset(_G, "instruct_53", function()
    local JY = rawget(_G, "JY")
    local rep = JY and JY.Person and JY.Person[0] and JY.Person[0]["声望"] or 0
    local WebUI = rawget(_G, "WebUI")
    if WebUI then WebUI.write(string.format("声望指数: %d", rep)) end
end)

-- instruct_54: 开放其他场景
rawset(_G, "instruct_54", function()
    local JY = rawget(_G, "JY")
    if not JY then return end
    local CC = rawget(_G, "CC")
    local sceneNum = (CC and CC.SceneNum) or 100
    for i = 0, sceneNum - 1 do
        if JY.Scene[i] then JY.Scene[i]["进入条件"] = 0 end
    end
    if JY.Scene[2] then JY.Scene[2]["进入条件"] = 2 end   --云鹤崖
    if JY.Scene[38] then JY.Scene[38]["进入条件"] = 2 end  --摩天崖
    if JY.Scene[75] then JY.Scene[75]["进入条件"] = 1 end  --桃花岛
    if JY.Scene[80] then JY.Scene[80]["进入条件"] = 1 end  --绝情谷底
end)

-- instruct_55: 判断D*编号的触发事件
rawset(_G, "instruct_55", function(id, num)
    local GetD = rawget(_G, "GetD")
    if not GetD then return false end
    local JY = rawget(_G, "JY")
    local sceneId = JY and JY.SubScene or 0
    return GetD(sceneId, id, 2) == num
end)

-- instruct_59: 全体队员离队
rawset(_G, "instruct_59", function()
    local JY = rawget(_G, "JY")
    if not JY then return end
    local instruct_21 = rawget(_G, "instruct_21")
    for i = CC.TeamNum, 2, -1 do
        local pid = JY.Base["队伍" .. i]
        if pid and pid >= 0 and instruct_21 then
            instruct_21(pid)
        end
    end
end)

-- instruct_61: 判断是否放完14天书
rawset(_G, "instruct_61", function()
    local GetD = rawget(_G, "GetD")
    if not GetD then return false end
    local JY = rawget(_G, "JY")
    local sceneId = JY and JY.SubScene or 0
    for i = 11, 24 do
        if GetD(sceneId, i, 5) ~= 4664 then return false end
    end
    return true
end)

-- instruct_63: 设置性别
rawset(_G, "instruct_63", function(personid, sex)
    local JY = rawget(_G, "JY")
    if JY and JY.Person and JY.Person[personid] then
        JY.Person[personid]["性别"] = sex
    end
end)

-- 兜底: 所有未显式实现的 instruct_* 输出 debug 日志
for i = 0, 67 do
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
    if not JY then
        EngineAPI.debug.log("ensureSceneDEvents: JY is nil")
        return
    end
    JY.D = JY.D or {}
    EngineAPI.debug.log("ensureSceneDEvents: JY.D=" .. tostring(JY.D) .. ", JY.D[" .. tostring(sceneId) .. "]=" .. tostring(JY.D[sceneId]))
    if JY.D[sceneId] then return end  -- 已加载
    
    local ds = rawget(_G, "initDataSource")
    local events = ds and ds["events"]
    if not events then
        JY.D[sceneId] = {}
        EngineAPI.debug.log("ensureSceneDEvents: no events data, created empty JY.D[" .. tostring(sceneId) .. "]")
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
    EngineAPI.debug.log("ensureSceneDEvents: loaded " .. tostring(#sceneEvents) .. " events for scene " .. tostring(sceneId))
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
    for i = 0, 67 do
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
    for i = 0, 67 do
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

    -- 覆写 startNewGame：Web MUD 使用纯文字菜单（CommandEngine + choose N）
    -- 原始 startNewGame 假设有图形菜单和二进制存档，Web MUD 用文字交互代替
    startNewGameAdapter.startNewGame = function(menux)
        local JY = rawget(_G, "JY")
        if not JY then JY = {}; rawset(_G, "JY", JY) end

        -- 调用 initGameState 初始化人物、物品、场景等数据
        local initGameState = rawget(_G, "initGameState")
        if initGameState then initGameState() end

        local P0 = JY.Person[0]
        local CC = rawget(_G, "CC")

        -- 设置主角初始属性
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

        -- 属性随机生成与确认循环（Web MUD 文字版）
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

        -- 设置初始队伍（initGameState 从 config 加载，格式为 队伍=[0,-1,...] 数组）
        local cfg = rawget(_G, "initDataSource") and rawget(_G, "initDataSource").config
        if cfg and cfg["队伍"] then
            for i = 1, 6 do
                JY.Base["队伍" .. i] = cfg["队伍"][i] or -1
            end
        else
            JY.Base["队伍1"] = 0
            for i = 2, (CC and CC.TeamNum or 6) do
                JY.Base["队伍" .. i] = -1
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
        -- 执行新游戏开场事件（主角独白对话）
        local EventExecutor = rawget(_G, "EventExecutor")
        if EventExecutor and EventExecutor.oldCallEventCoroutine then
            EventExecutor.oldCallEventCoroutine(CC.NewGameEvent)
        end
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

    -- 初始化 JY.Thing（物品数据）/ JY.Wugong（武功数据），原版 initGameState 运行时未调用
    -- jymain.lua 的 SetGlobal 会设置 JY.Base/JY.Person 但不填充 JY.Thing/JY.Wugong
    local ds = rawget(_G, "initDataSource")
    if ds then
        if ds.items then
            local itemList = ds.items["items"] or ds.items
            if type(itemList) == "table" then
                JY.Thing = JY.Thing or {}
                for _, rec in ipairs(itemList) do
                    if type(rec) == "table" and rec["代号"] ~= nil then
                        JY.Thing[rec["代号"]] = rec
                    end
                end
            end
        end
        if ds.skills then
            local skillList = ds.skills["skills"] or ds.skills
            if type(skillList) == "table" then
                JY.Wugong = JY.Wugong or {}
                for _, rec in ipairs(skillList) do
                    if type(rec) == "table" and rec["代号"] ~= nil then
                        JY.Wugong[rec["代号"]] = rec
                    end
                end
            end
        end
    end

    -- 覆写 LoadRecord：Web MUD 改用 save/load 系统，不从二进制文件读取
    rawset(_G, "LoadRecord", function(id)
        id = tonumber(id) or 0
        -- id=0 是"新游戏"（加载初始数据），不走存档；id=1~3 是读档
        if id == 0 then
            -- 新游戏：从 config 数据初始化（initGameState 负责格式转换）
            local initGameState = rawget(_G, "initGameState")
            if initGameState then
                initGameState()
                return true
            end
            return false
        end
        -- 读档 1~3：从 IndexedDB 加载
        local loadGameState = rawget(_G, "loadGameState")
        if loadGameState then
            return loadGameState(id)
        end
        return false
    end)

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
            menu  = { handler = _G.MmapHandlers.menu,  description = "打开主选单（状态/物品/存挡）" },
            quit  = { handler = _G.MmapHandlers.quit,  description = "退出当前游戏，返回开始菜单" },
            help  = { handler = CE.showHelp,           description = "显示帮助信息" },
            choose= { handler = CE.handleChoose,        description = "choose <编号> 选择菜单项" },
        }
        local smapCmds = {
            look  = { handler = _G.SmapHandlers.look,  description = "查看场景并选择交互对象" },
            menu  = { handler = _G.SmapHandlers.menu,  description = "打开主选单（状态/物品/存挡）" },
            rest  = { handler = _G.SmapHandlers.rest,  description = "休息恢复体力" },
            exits = { handler = _G.SmapHandlers.exits, description = "列出出口" },
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
                    -- 检查角色管理菜单（Slice 6）
                    if JY and (JY.Status == 2 or JY.Status == 4) and n ~= nil then
                        local handled = RoleMenu_handleChoose(n)
                        if handled then
                            -- 角色管理已处理
                        elseif JY.Status == 4 then
                            local sh = rawget(_G, "SmapHandlers")
                            if sh and sh.chooseInteraction then
                                sh.chooseInteraction(n)
                            end
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
