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

-- 模块导出
return ItemAsync
