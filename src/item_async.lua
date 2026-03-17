-- item_async.lua
-- 异步物品系统模块
-- 提供非阻塞版本的物品选择和使用功能

local ItemAsync = {}

-- 导入必要的依赖模块
local CoroutineScheduler = require("coroutine_scheduler")
local MenuAsync = require("menu_async")
local AsyncMessageBox = require("async_message_box")
local AsyncDialog = require("async_dialog")
local InputAsync = require("input_async")

-- 异步物品选择菜单
-- 返回选择的物品ID，-1表示取消选择
function ItemAsync.SelectThingAsync()
    -- 显示物品分类菜单
    local categoryMenu = {
        {"全部物品", nil, 1},
        {"剧情物品", nil, 1},
        {"神兵宝甲", nil, 1},
        {"武功秘笈", nil, 1},
        {"灵丹妙药", nil, 1},
        {"伤人暗器", nil, 1},
    }
    
    local category = MenuAsync.ShowMenuCoroutine(categoryMenu, 6, 0, CC.MainSubMenuX, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if category <= 0 then
        return -1  -- 取消选择
    end
    
    -- 收集符合条件的物品
    local items = {}
    local itemCount = 0
    
    for i = 0, CC.MyThingNum - 1 do
        local id = JY.Base["物品" .. i + 1]
        if id >= 0 then
            local shouldInclude = false
            
            if category == 1 then
                -- 全部物品
                shouldInclude = true
            else
                -- 特定类型：剧情(0)、装备(1)、秘籍(2)、药品(3)、暗器(4)
                local typeFilter = category - 2
                if JY.Thing[id]["类型"] == typeFilter then
                    shouldInclude = true
                end
            end
            
            if shouldInclude then
                itemCount = itemCount + 1
                items[itemCount] = {
                    id = id,
                    name = JY.Thing[id]["名称"],
                    count = JY.Base["物品数量" .. i + 1],
                    type = JY.Thing[id]["类型"]
                }
            end
        end
    end
    
    -- 检查是否有物品
    if itemCount == 0 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "没有物品", C_WHITE, CC.DefaultFont)
        return -1
    end
    
    -- 构建物品菜单
    local itemMenu = {}
    for i = 1, itemCount do
        local displayName = items[i].name
        -- 如果物品已装备，显示装备者
        if (items[i].type == 1 or items[i].type == 2) and JY.Thing[items[i].id]["使用人"] >= 0 then
            local userName = JY.Person[JY.Thing[items[i].id]["使用人"]]["姓名"]
            displayName = displayName .. "(" .. userName .. ")"
        end
        -- 显示名称和数量
        local menuText = string.format("%-20s x%d", displayName, items[i].count)
        itemMenu[i] = {menuText, nil, 1, items[i].id}
    end
    
    -- 显示物品列表菜单
    local x1 = CC.MainSubMenuX
    local y1 = CC.MainSubMenuY + CC.SingleLineHeight * 2
    
    local selected = MenuAsync.ShowMenuCoroutine(itemMenu, itemCount, 0, x1, y1, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if selected > 0 then
        return itemMenu[selected][4]  -- 返回物品ID
    else
        return -1  -- 取消选择
    end
end

-- 减少物品数量的辅助函数
-- thingId: 物品ID
-- amount: 减少数量（默认为1）
-- 返回: 是否成功减少
local function ReduceThingCount(thingId, amount)
    amount = amount or 1
    
    -- 查找物品在背包中的位置
    for i = 0, CC.MyThingNum - 1 do
        local id = JY.Base["物品" .. i + 1]
        if id == thingId then
            local currentCount = JY.Base["物品数量" .. i + 1]
            if currentCount >= amount then
                JY.Base["物品数量" .. i + 1] = currentCount - amount
                -- 如果数量为0，清空该位置
                if JY.Base["物品数量" .. i + 1] <= 0 then
                    JY.Base["物品" .. i + 1] = -1
                    JY.Base["物品数量" .. i + 1] = 0
                end
                return true
            else
                return false  -- 数量不足
            end
        end
    end
    return false  -- 未找到物品
end

-- 异步选择队友菜单（辅助函数）
local function SelectTeamMemberAsync(title)
    local menu = {}
    local validCount = 0
    
    for i = 1, CC.TeamNum do
        local id = JY.Base["队伍" .. i]
        if id >= 0 and JY.Person[id]["生命"] > 0 then
            validCount = validCount + 1
            menu[validCount] = {JY.Person[id]["姓名"], nil, 1, id}
        end
    end
    
    if validCount == 0 then
        return -1
    end
    
    if title then
        DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, title, C_WHITE, CC.DefaultFont)
    end
    
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    local r = MenuAsync.ShowMenuCoroutine(menu, validCount, 0, CC.MainSubMenuX, nexty, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        return menu[r][4]  -- 返回人物ID
    else
        return -1
    end
end

-- 异步物品使用入口
-- thingId: 物品ID
-- 返回: true表示使用成功，false表示使用失败或取消
function ItemAsync.UseThingAsync(thingId)
    local thingType = JY.Thing[thingId]["类型"]
    
    if thingType == 0 then
        return ItemAsync.UseThing_Type0Async(thingId)
    elseif thingType == 1 then
        return ItemAsync.UseThing_Type1Async(thingId)
    elseif thingType == 2 then
        return ItemAsync.UseThing_Type2Async(thingId)
    elseif thingType == 3 then
        return ItemAsync.UseThing_Type3Async(thingId)
    elseif thingType == 4 then
        return ItemAsync.UseThing_Type4Async(thingId)
    else
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "未知物品类型", C_WHITE, CC.DefaultFont)
        return false
    end
end

-- 剧情物品使用（类型0）
function ItemAsync.UseThing_Type0Async(thingId)
    -- 剧情物品触发事件
    if JY.SubScene >= 0 then
        -- 检查是否有对应的事件
        -- 这里简化处理，实际应该根据物品ID和场景查找对应事件
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Thing[thingId]["名称"] .. "已使用", C_ORANGE, CC.DefaultFont)
        return true
    else
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "此处无法使用" .. JY.Thing[thingId]["名称"], C_WHITE, CC.DefaultFont)
        return false
    end
end

-- 装备物品使用（类型1）
function ItemAsync.UseThing_Type1Async(thingId)
    local thingName = JY.Thing[thingId]["名称"]
    local equipType = JY.Thing[thingId]["装备类型"]  -- 0=武器, 1=防具
    
    -- 选择装备目标
    local personId = SelectTeamMemberAsync("谁要配备" .. thingName .. "?")
    
    if personId < 0 then
        return false  -- 取消选择
    end
    
    -- 检查是否可以装备
    -- 简化版：检查内力性质、仅修炼人物等条件
    if JY.Thing[thingId]["需内力性质"] ~= 2 then
        if JY.Person[personId]["内力性质"] ~= 2 and 
           JY.Thing[thingId]["需内力性质"] ~= JY.Person[personId]["内力性质"] then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, "内力性质不符，无法装备", C_WHITE, CC.DefaultFont)
            return false
        end
    end
    
    -- 检查仅修炼人物限制
    if JY.Thing[thingId]["仅修炼人物"] >= 0 then
        if JY.Thing[thingId]["仅修炼人物"] ~= personId then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, "此人不适合配备此物品", C_WHITE, CC.DefaultFont)
            return false
        end
    end
    
    -- 解除原使用者的装备
    local oldUser = JY.Thing[thingId]["使用人"]
    if oldUser >= 0 then
        if equipType == 0 then
            JY.Person[oldUser]["武器"] = -1
        else
            JY.Person[oldUser]["防具"] = -1
        end
    end
    
    -- 解除目标人物原有的同类装备
    if equipType == 0 then
        local oldWeapon = JY.Person[personId]["武器"]
        if oldWeapon >= 0 then
            JY.Thing[oldWeapon]["使用人"] = -1
        end
        JY.Person[personId]["武器"] = thingId
    else
        local oldArmor = JY.Person[personId]["防具"]
        if oldArmor >= 0 then
            JY.Thing[oldArmor]["使用人"] = -1
        end
        JY.Person[personId]["防具"] = thingId
    end
    
    -- 设置新的使用人
    JY.Thing[thingId]["使用人"] = personId
    
    AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Person[personId]["姓名"] .. "装备了" .. thingName, C_ORANGE, CC.DefaultFont)
    return true
end

-- 秘籍物品使用（类型2）
function ItemAsync.UseThing_Type2Async(thingId)
    local thingName = JY.Thing[thingId]["名称"]
    
    -- 选择修炼目标
    local personId = SelectTeamMemberAsync("要谁修炼" .. thingName .. "?")
    
    if personId < 0 then
        return false
    end
    
    -- 检查修炼条件
    -- 内力性质检查
    if JY.Thing[thingId]["需内力性质"] ~= 2 then
        if JY.Person[personId]["内力性质"] ~= 2 and 
           JY.Thing[thingId]["需内力性质"] ~= JY.Person[personId]["内力性质"] then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, "内力性质不符，无法修炼", C_WHITE, CC.DefaultFont)
            return false
        end
    end
    
    -- 检查内力上限
    if JY.Person[personId]["内力上限"] < JY.Thing[thingId]["需内力"] then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "内力不足，无法修炼", C_WHITE, CC.DefaultFont)
        return false
    end
    
    -- 检查仅修炼人物限制
    if JY.Thing[thingId]["仅修炼人物"] >= 0 then
        if JY.Thing[thingId]["仅修炼人物"] ~= personId then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, "此人不适合修炼此武功", C_WHITE, CC.DefaultFont)
            return false
        end
    end
    
    -- 增加武功等级（简化处理）
    -- 实际应该根据秘籍类型增加对应武功
    -- 减少物品数量（秘籍修炼后消失）
    ReduceThingCount(thingId, 1)
    AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Person[personId]["姓名"] .. "修炼了" .. thingName, C_ORANGE, CC.DefaultFont)
    return true
end

-- 药品物品使用（类型3）
function ItemAsync.UseThing_Type3Async(thingId)
    local thingName = JY.Thing[thingId]["名称"]
    
    -- 选择使用目标
    local personId = SelectTeamMemberAsync("要给谁使用" .. thingName .. "?")
    
    if personId < 0 then
        return false
    end
    
    local personName = JY.Person[personId]["姓名"]
    local effectText = ""
    local hasEffect = false
    
    -- 恢复生命
    if JY.Thing[thingId]["加生命"] > 0 then
        local maxLife = JY.Person[personId]["生命上限"]
        local currentLife = JY.Person[personId]["生命"]
        if currentLife < maxLife then
            local addLife = JY.Thing[thingId]["加生命"]
            JY.Person[personId]["生命"] = math.min(currentLife + addLife, maxLife)
            effectText = effectText .. "生命+" .. addLife .. " "
            hasEffect = true
        end
    end
    
    -- 恢复内力
    if JY.Thing[thingId]["加内力"] > 0 then
        local maxMp = JY.Person[personId]["内力上限"]
        local currentMp = JY.Person[personId]["内力"]
        if currentMp < maxMp then
            local addMp = JY.Thing[thingId]["加内力"]
            JY.Person[personId]["内力"] = math.min(currentMp + addMp, maxMp)
            effectText = effectText .. "内力+" .. addMp .. " "
            hasEffect = true
        end
    end
    
    -- 恢复体力
    if JY.Thing[thingId]["加体力"] > 0 then
        local maxTili = 100  -- 假设体力上限为100
        local currentTili = JY.Person[personId]["体力"]
        if currentTili < maxTili then
            local addTili = JY.Thing[thingId]["加体力"]
            JY.Person[personId]["体力"] = math.min(currentTili + addTili, maxTili)
            effectText = effectText .. "体力+" .. addTili .. " "
            hasEffect = true
        end
    end
    
    -- 解毒
    if JY.Thing[thingId]["减中毒"] > 0 then
        local currentPoison = JY.Person[personId]["中毒程度"]
        if currentPoison > 0 then
            local reducePoison = JY.Thing[thingId]["减中毒"]
            JY.Person[personId]["中毒程度"] = math.max(currentPoison - reducePoison, 0)
            effectText = effectText .. "解毒" .. reducePoison .. " "
            hasEffect = true
        end
    end
    
    if hasEffect then
        -- 减少物品数量
        ReduceThingCount(thingId, 1)
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, personName .. "使用" .. thingName .. ": " .. effectText, C_ORANGE, CC.DefaultFont)
        return true
    else
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, personName .. "无需使用" .. thingName, C_WHITE, CC.DefaultFont)
        return false
    end
end

-- 暗器物品使用（类型4）
function ItemAsync.UseThing_Type4Async(thingId)
    -- 暗器只能在战斗中使用
    AsyncMessageBox.ShowMessageCoroutine(-1, -1, "暗器只能在战斗中使用", C_WHITE, CC.DefaultFont)
    return false
end

-- 模块导出
return ItemAsync
