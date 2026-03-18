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

-- 当前显示的物品选择状态（用于draw函数）
local currentItemSelect = nil

-- 是否正在显示物品选择（用于阻止游戏主循环处理按键）
-- 注意：现在使用 InputManager.disableInput 替代

-- 异步物品选择菜单（Grid形式，带缩略图和描述）
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
                    type = JY.Thing[id]["类型"],
                    desc = JY.Thing[id]["物品说明"],
                    user = JY.Thing[id]["使用人"]
                }
            end
        end
    end
    
    -- 检查是否有物品
    if itemCount == 0 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "没有物品", C_WHITE, CC.DefaultFont)
        return -1
    end
    
    -- 使用Grid形式选择物品
    return ItemAsync.SelectThingGridAsync(items, itemCount)
end

-- Grid形式物品选择（带缩略图和描述）
-- items: 物品列表，每个元素包含 id, name, count, type, desc, user
-- itemCount: 物品数量
-- 返回选择的物品ID，-1表示取消
function ItemAsync.SelectThingGridAsync(items, itemCount)
    -- Grid配置
    local xnum = CC.MenuThingXnum or 5  -- 每行物品数
    local ynum = CC.MenuThingYnum or 3  -- 每列物品数
    local itemsPerPage = xnum * ynum
    
    -- 计算总页数
    local totalPages = math.ceil(itemCount / itemsPerPage)
    local currentPage = 1
    local selectedIndex = 1  -- 当前选中的物品索引（1-based）
    local scheduler = CoroutineScheduler.getInstance()
    local InputAsync = require("input_async")
    
    -- 设置标志，阻止游戏主循环处理按键
    local InputManager = require("input_manager")
    InputManager.getInstance().disableInput = true
    
    while true do
        -- 计算当前页显示的物品
        local pageStart = (currentPage - 1) * itemsPerPage + 1
        local pageEnd = math.min(pageStart + itemsPerPage - 1, itemCount)
        local pageItemCount = pageEnd - pageStart + 1
        
        -- 确保选中索引在当前页范围内
        if selectedIndex < pageStart then
            selectedIndex = pageStart
        elseif selectedIndex > pageEnd then
            selectedIndex = pageEnd
        end
        
        -- 获取当前选中的物品
        local selectedItem = items[selectedIndex]
        
        -- 设置当前显示状态（供draw函数使用）
        currentItemSelect = {
            items = items,
            itemCount = itemCount,
            currentPage = currentPage,
            totalPages = totalPages,
            selectedIndex = selectedIndex,
            pageStart = pageStart,
            pageEnd = pageEnd,
            xnum = xnum,
            ynum = ynum,
            selectedItem = selectedItem
        }
        
        -- 异步等待按键
        local keypress = InputAsync.WaitKeyCoroutine()
        
        -- 清除显示状态
        currentItemSelect = nil
        
        -- 处理按键
        if keypress == VK_ESCAPE then
            -- ESC取消选择
            local InputManager = require("input_manager")
            InputManager.getInstance().disableInput = false
            return -1
        elseif keypress == VK_RETURN or keypress == VK_SPACE then
            -- 确认选择
            if selectedItem then
                local InputManager = require("input_manager")
                InputManager.getInstance().disableInput = false
                return selectedItem.id
            end
        elseif keypress == VK_UP then
            -- 向上移动
            local currentPos = selectedIndex - pageStart + 1
            local currentRow = math.ceil(currentPos / xnum)
            local currentCol = (currentPos - 1) % xnum + 1
            
            if currentRow > 1 then
                -- 在同一页向上移动
                selectedIndex = selectedIndex - xnum
            elseif currentPage > 1 then
                -- 翻到上一页，选中最后一行同列
                currentPage = currentPage - 1
                local newPageStart = (currentPage - 1) * itemsPerPage + 1
                local newPageEnd = math.min(newPageStart + itemsPerPage - 1, itemCount)
                local newPageCount = newPageEnd - newPageStart + 1
                local lastRowStart = newPageStart + (math.ceil(newPageCount / xnum) - 1) * xnum
                selectedIndex = math.min(lastRowStart + currentCol - 1, newPageEnd)
            end
        elseif keypress == VK_DOWN then
            -- 向下移动
            local currentPos = selectedIndex - pageStart + 1
            local currentRow = math.ceil(currentPos / xnum)
            local currentCol = (currentPos - 1) % xnum + 1
            local maxRow = math.ceil(pageItemCount / xnum)
            
            if currentRow < maxRow then
                -- 在同一页向下移动
                selectedIndex = math.min(selectedIndex + xnum, pageEnd)
            elseif currentPage < totalPages then
                -- 翻到下一页，选中第一行同列
                currentPage = currentPage + 1
                local newPageStart = (currentPage - 1) * itemsPerPage + 1
                selectedIndex = math.min(newPageStart + currentCol - 1, itemCount)
            end
        elseif keypress == VK_LEFT then
            -- 向左移动
            if selectedIndex > pageStart then
                selectedIndex = selectedIndex - 1
            elseif currentPage > 1 then
                -- 翻到上一页最后一项
                currentPage = currentPage - 1
                local newPageEnd = math.min(currentPage * itemsPerPage, itemCount)
                selectedIndex = newPageEnd
            end
        elseif keypress == VK_RIGHT then
            -- 向右移动
            if selectedIndex < pageEnd then
                selectedIndex = selectedIndex + 1
            elseif currentPage < totalPages then
                -- 翻到下一页第一项
                currentPage = currentPage + 1
                selectedIndex = (currentPage - 1) * itemsPerPage + 1
            end
        end
        
        -- 小延迟防止按键过快
        scheduler:waitForTime(0.05)
    end
end

-- 绘制物品选择界面（在draw函数中调用）
function ItemAsync.draw()
    if not currentItemSelect then
        return
    end
    
    local select = currentItemSelect
    local items = select.items
    local xnum = select.xnum
    local ynum = select.ynum
    local pageStart = select.pageStart
    local pageEnd = select.pageEnd
    local selectedIndex = select.selectedIndex
    local selectedItem = select.selectedItem
    
    -- 计算布局
    local w = CC.ThingPicWidth * xnum + (xnum - 1) * CC.ThingGapIn + 2 * CC.ThingGapOut
    local h = CC.ThingPicHeight * ynum + (ynum - 1) * CC.ThingGapIn + 2 * CC.ThingGapOut
    local dx = (CC.ScreenW - w) / 2
    local dy = (CC.ScreenH - h - 2 * (CC.ThingFontSize + 2 * CC.MenuBorderPixel + 5)) / 2
    
    local y1_1 = dy
    local y1_2 = y1_1 + CC.ThingFontSize + 2 * CC.MenuBorderPixel
    local y2_1 = y1_2 + 5
    local y2_2 = y2_1 + CC.ThingFontSize + 2 * CC.MenuBorderPixel
    local y3_1 = y2_2 + 5
    local y3_2 = y3_1 + h
    
    -- 绘制信息框（名称和说明）
    DrawBox(dx, y1_1, dx + w, y1_2, C_WHITE)
    DrawBox(dx, y2_1, dx + w, y2_2, C_WHITE)
    DrawBox(dx, y3_1, dx + w, y3_2, C_WHITE)
    
    -- 显示选中物品的信息
    if selectedItem then
        local displayName = selectedItem.name
        if (selectedItem.type == 1 or selectedItem.type == 2) and selectedItem.user >= 0 then
            displayName = displayName .. "(" .. JY.Person[selectedItem.user]["姓名"] .. ")"
        end
        displayName = string.format("%s X %d", displayName, selectedItem.count)
        DrawString(dx + CC.ThingGapOut, y1_1 + CC.MenuBorderPixel, displayName, C_GOLD, CC.ThingFontSize)
        DrawString(dx + CC.ThingGapOut, y2_1 + CC.MenuBorderPixel, selectedItem.desc, C_ORANGE, CC.ThingFontSize)
    end
    
    -- 绘制物品Grid
    for i = pageStart, pageEnd do
        local localIndex = i - pageStart
        local x = localIndex % xnum
        local y = math.floor(localIndex / xnum)
        
        local boxx = dx + CC.ThingGapOut + x * (CC.ThingPicWidth + CC.ThingGapIn)
        local boxy = y3_1 + CC.ThingGapOut + y * (CC.ThingPicHeight + CC.ThingGapIn)
        
        -- 判断是否选中
        local isSelected = (i == selectedIndex)
        local boxcolor = isSelected and C_WHITE or C_BLACK
        
        -- 绘制物品框
        lib.DrawRect(boxx, boxy, boxx + CC.ThingPicWidth + 1, boxy + CC.ThingPicHeight + 1, boxcolor)
        
        -- 绘制物品图片
        local item = items[i]
        if item then
            if CC.LoadThingPic == 1 then
                lib.PicLoadCache(2, item.id * 2, boxx + 1, boxy + 1, 1)
            else
                lib.PicLoadCache(0, (item.id + CC.StartThingPic) * 2, boxx + 1, boxy + 1, 1)
            end
        end
    end
    
    -- 显示页码
    local pageStr = string.format("%d/%d", select.currentPage, select.totalPages)
    DrawString(dx + w - 50, y3_2 + 5, pageStr, C_WHITE, CC.DefaultFont)
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
