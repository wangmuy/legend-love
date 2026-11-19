-- item_async.lua
-- 异步物品系统模块
-- 提供非阻塞版本的物品选择和使用功能

local RenderFacade = require("framework.render_facade")
local SpriteAtlas = require("framework.sprite_atlas")
local ItemAsync = {}

-- 导入必要的依赖模块
local CoroutineScheduler = require("framework.coroutine_scheduler")
local MenuAsync = require("framework.menu_async")
local AsyncMessageBox = require("framework.async_message_box")
local AsyncDialog = require("framework.async_dialog")
local InputAsync = require("framework.input_async")

-- 当前显示的物品选择状态（用于draw函数）
local currentItemSelect = nil

-- 鼠标点击产生的待处理动作（REQ-MS2-9）
--
-- 为什么用「队列 + 唤醒键」而不是直接返回：
--   物品选择是一个 `while true do WaitKey() ... end` 的协程，
--   WaitKey 会在「键队列为空」时挂起。鼠标点击无法从外部让它返回，
--   只能 ① 记录意图 ② 注入一个键把它唤醒 ③ 循环开头先消费意图。
--
-- 这个模式与 SceneNameAsync / PersonStatusAsync 的注入方案一致，
-- 好处是**协程代码改动最小**，且键盘路径完全不受影响。
local pendingItemAction = nil

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

function ItemAsync.SelectThingByArrayAsync(thing, thingnum, itemCount)
    local items = {}
    local count = itemCount or 0
    
    for i = 0, count - 1 do
        if thing[i] and thing[i] >= 0 then
            items[i + 1] = {
                id = thing[i],
                name = JY.Thing[thing[i]]["名称"],
                count = thingnum[i] or 0,
                type = JY.Thing[thing[i]]["类型"],
                desc = JY.Thing[thing[i]]["物品说明"],
                user = JY.Thing[thing[i]]["使用人"]
            }
        end
    end
    
    if count == 0 then
        return -1
    end
    
    return ItemAsync.SelectThingGridAsync(items, count)
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
    local InputAsync = require("framework.input_async")
    
    -- 设置标志，阻止游戏主循环处理按键
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = true
    if CONFIG and CONFIG.Debug == 1 then
        Debug("ItemAsync.SelectThingGridAsync: disableInput set to true")
    end
    
    while true do
        -- **循环最顶部先消费鼠标意图**（REQ-MS2-9）
        --
        -- 必须放在「重建 currentItemSelect」之前：
        -- 若放在它之后，悬停改了 selectedIndex 还要等下一轮才反映到
        -- currentItemSelect（供 draw 读），实测延迟约 120ms，
        -- 表现为「鼠标划过物品，选中框慢半拍才跟过来」。
        --
        -- 也不能靠注入键唤醒（会积压成「悬停一会儿自动卖出」，见
        -- handleMouseHover 的注释）。
        local mouseAction = pendingItemAction
        pendingItemAction = nil

        if mouseAction then
            if mouseAction.kind == "hover" then
                -- 只挪选中框 + 刷新信息栏（不确认、不退出）
                selectedIndex = mouseAction.index
            elseif mouseAction.kind == "select" then
                -- 挪到点击的格子并直接确认（等价「选中 + 按空格」）
                selectedIndex = mouseAction.index
                local clicked = items[selectedIndex]
                if clicked then
                    currentItemSelect = nil
                    local IM = require("framework.input_manager")
                    IM.disableInput = false
                    return clicked.id
                end
            elseif mouseAction.kind == "cancel" then
                currentItemSelect = nil
                local IM = require("framework.input_manager")
                IM.disableInput = false
                return -1
            end
        end

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
        -- 只在第一次或页面/选中变化时更新，避免不必要的重绘
        if not currentItemSelect or 
           currentItemSelect.currentPage ~= currentPage or 
           currentItemSelect.selectedIndex ~= selectedIndex then
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
        end
        
        -- 周期性等待按键（不是纯 WaitKey）
        --
        -- 换成 WaitKeyTimeout 的原因：悬停需要「不按键也能让协程醒一次」。
        -- 用 50ms 超时轮询：既能让悬停及时生效，又完全不碰键队列。
        local keypress = InputAsync.WaitKeyTimeoutBypass(0.05)

        -- 处理按键
        if keypress == VK_ESCAPE then
            -- ESC取消选择
            currentItemSelect = nil  -- 清除显示状态
            local InputManager = require("framework.input_manager")
            InputManager.disableInput = false
            if CONFIG and CONFIG.Debug == 1 then
                Debug("ItemAsync.SelectThingGridAsync: ESC pressed, disableInput set to false")
            end
            return -1
        elseif keypress == VK_RETURN or keypress == VK_SPACE then
            -- 确认选择
            if selectedItem then
                currentItemSelect = nil  -- 清除显示状态
                local InputManager = require("framework.input_manager")
                InputManager.disableInput = false
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

--- 物品选择界面是否正在显示
--
-- 供 canPlayerAct 判断「玩家此刻能不能行动」。
--
-- **不能只看 InputManager.disableInput**：GAME_SMAP.update 每帧会把它
-- 重算成「动画是否在播」（`if AnimationState.active then true else false`），
-- 于是这里设的 true 下一帧就被覆盖成 false。
-- 实测症状：显示物品清单时，鼠标点击又落到了地图寻路上。
--
-- @return boolean
function ItemAsync.isActive()
    return currentItemSelect ~= nil
end

--- 消费一条鼠标意图（协程循环内部调用）
--
-- 抽成纯函数的目的：
--   ① 顺序要求（必须在 WaitKey 之后、所有判断之前）可以被单测锁死
--   ② 延迟问题（必须在循环**顶部**之外）也可以被单测覆盖
--
-- @param action table pendingItemAction
-- @param ctx table { selectedIndex=, items=, xnum=, itemsPerPage= }
-- @return table { selectedIndex=, finished=, value= }
function ItemAsync.applyMouseAction(action, ctx)
    if not action then return nil end

    if action.kind == "hover" then
        return { selectedIndex = action.index }
    end
    if action.kind == "select" then
        local clicked = ctx.items and ctx.items[action.index]
        return {
            selectedIndex = action.index,
            finished = true,
            value = clicked and clicked.id or -1,
        }
    end
    if action.kind == "cancel" then
        return { finished = true, value = -1 }
    end
    return nil
end

--- 当前选中项的索引（调试/测试用）
--
-- 只读访问器：currentItemSelect 是模块局部变量，外部无法观察。
-- 悬停/键盘的优先级测试需要读它，调试时也用得上。
--
-- @return number|nil
function ItemAsync.selectedIndex()
    return currentItemSelect and currentItemSelect.selectedIndex or nil
end

--- 计算物品网格的布局（供 draw 与鼠标命中**共用**）
--
-- 与 draw 里的布局计算逐字一致。两处若各写一份，
-- 迟早会漂移成「看到的格子」和「点到的格子」不一致。
--
-- @param select table currentItemSelect
-- @return table { dx=, dy=, w=, h=, y3_1=, xnum=, ynum=, cellW=, cellH=, gapIn=, gapOut= }
function ItemAsync.layout(select)
    if not select then return nil end
    local xnum = select.xnum
    local ynum = select.ynum

    local w = CC.ThingPicWidth * xnum + (xnum - 1) * CC.ThingGapIn + 2 * CC.ThingGapOut
    local h = CC.ThingPicHeight * ynum + (ynum - 1) * CC.ThingGapIn + 2 * CC.ThingGapOut
    local dx = (CC.ScreenW - w) / 2
    local dy = (CC.ScreenH - h - 2 * (CC.ThingFontSize + 2 * CC.MenuBorderPixel + 5)) / 2

    local y1_1 = dy
    local y1_2 = y1_1 + CC.ThingFontSize + 2 * CC.MenuBorderPixel
    local y2_1 = y1_2 + 5
    local y2_2 = y2_1 + CC.ThingFontSize + 2 * CC.MenuBorderPixel
    local y3_1 = y2_2 + 5

    return {
        dx = dx, dy = dy, w = w, h = h,
        y3_1 = y3_1,
        xnum = xnum, ynum = ynum,
        cellW = CC.ThingPicWidth, cellH = CC.ThingPicHeight,
        gapIn = CC.ThingGapIn, gapOut = CC.ThingGapOut,
    }
end

--- 点 (mx,my) 落在第几个物品上（纯函数，可独立测试）
--
-- 抽出来的理由：命中循环的行列公式（尤其换行用的 floor）是很容易写错的
-- 地方，写在 handleMouseClick 内部就只能在真机上手点验证。
-- 抽成纯函数后可以直接对坐标做断言。
--
-- @param select table currentItemSelect
-- @param mx, my number
-- @return number|nil 物品的全局索引（可直接用作 selectedIndex）
function ItemAsync.indexAt(select, mx, my)
    if not select then return nil end
    local L = ItemAsync.layout(select)
    if not L then return nil end

    local pageCount = select.pageEnd - select.pageStart + 1
    for localIndex = 0, pageCount - 1 do
        -- 换行用 floor：第 0..xnum-1 个是第 1 行，第 xnum.. 是第 2 行。
        -- 用 ceil 会让第 0 个算出 row=0、第 1 个算出 row=1（错位一格）。
        local col = localIndex % L.xnum
        local row = math.floor(localIndex / L.xnum)

        local x1 = L.dx + L.gapOut + col * (L.cellW + L.gapIn)
        local y1 = L.y3_1 + L.gapOut + row * (L.cellH + L.gapIn)
        local x2, y2 = x1 + L.cellW, y1 + L.cellH

        if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
            return select.pageStart + localIndex
        end
    end
    return nil
end

--- 悬停在物品网格某一格 → 移动选中框（REQ-MS2-11）
--
-- 与键盘方向键的效果完全相同：选中框移到该格，
-- 上方信息栏随之显示该物品的名称/说明/数量。
--
-- @param mx, my number 屏幕坐标
-- @return boolean 是否需要重绘
function ItemAsync.handleMouseHover(mx, my)
    local select = currentItemSelect
    if not select then return false end

    local index = ItemAsync.indexAt(select, mx, my)
    if not index or index == select.selectedIndex then
        return false    -- 空白区或已选中：不重绘
    end

    -- **悬停不注入键**（用户实测 bug：悬停一会儿会自动卖掉物品）
    --
    -- 为什么：物品格协程挂在 WaitKeyCoroutine 上，只在「键事件到来」时迭代。
    -- 若悬停靠注入键唤醒，而注入频率高于消费频率（协程有 waitForTime 帧
    -- 不消费键），键就会在队列里积压。等鼠标停在「已选中」的格子上
    -- （此时不再产生 pending），下一个残留键被消费 → keypress=VK_SPACE、
    -- pending=nil → 走确认分支 → **自动卖出**。
    -- 实测复现：12 帧内队列从 -1 变成常驻 32。
    --
    -- 改为：只记录意图，由协程的 WaitKeyTimeout 周期性醒来消费。
    pendingItemAction = { kind = "hover", index = index }
    return true
end

--- 点击物品网格里的某一格 → 记录意图并唤醒协程（REQ-MS2-9）
--
-- @param mx, my number 屏幕坐标
-- @return boolean 是否处理了
function ItemAsync.handleMouseClick(mx, my)
    local select = currentItemSelect
    if not select then return false end

    local index = ItemAsync.indexAt(select, mx, my)
    if index then
        -- 只记录意图，**不注入键**
        --
        -- 注入键会被协程的「等待按键」分支先消费掉：
        --   WaitKeyTimeoutBypass 返回 32 → 走 VK_SPACE 分支
        --   → return selectedItem.id（旧值，还没读到 pending）
        --   → 永远轮不到循环顶部去消费 pending。
        --
        -- 现在协程用 50ms 超时轮询，pending 最迟 50ms 后被消费，
        -- 用户感知不到延迟，而且完全不碰键队列。
        pendingItemAction = { kind = "select", index = index }
    end
    -- 点在信息框 / 空白处：吃掉点击但不动作（避免误选）
    return true
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
    
    -- 布局（与 ItemAsync.handleMouseClick 共用同一份计算，避免漂移）
    local L = ItemAsync.layout(select)
    local w, h, dx, dy = L.w, L.h, L.dx, L.dy
    local y3_1 = L.y3_1
    local y1_1 = dy
    local y1_2 = y1_1 + CC.ThingFontSize + 2 * CC.MenuBorderPixel
    local y2_1 = y1_2 + 5
    local y2_2 = y2_1 + CC.ThingFontSize + 2 * CC.MenuBorderPixel
    local y3_2 = y3_1 + h
    
    -- 绘制信息框（名称和说明）
    RenderFacade.drawBackground(dx, y1_1, dx + w, y1_2, C_WHITE)
    RenderFacade.drawBackground(dx, y2_1, dx + w, y2_2, C_WHITE)
    RenderFacade.drawBackground(dx, y3_1, dx + w, y3_2, C_WHITE)
    
    -- 显示选中物品的信息
    if selectedItem then
        local displayName = selectedItem.name
        if (selectedItem.type == 1 or selectedItem.type == 2) and selectedItem.user >= 0 then
            displayName = displayName .. "(" .. JY.Person[selectedItem.user]["姓名"] .. ")"
        end
        displayName = string.format("%s X %d", displayName, selectedItem.count)
        RenderFacade.text(dx + CC.ThingGapOut, y1_1 + CC.MenuBorderPixel, displayName, C_GOLD, CC.ThingFontSize)
        RenderFacade.text(dx + CC.ThingGapOut, y2_1 + CC.MenuBorderPixel, selectedItem.desc, C_ORANGE, CC.ThingFontSize)
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
        EngineAPI.render.rectOutline(boxx, boxy, boxx + CC.ThingPicWidth + 1, boxy + CC.ThingPicHeight + 1, boxcolor)
        
        -- 绘制物品图片
        local item = items[i]
        if item then
            if CC.LoadThingPic == 1 then
                SpriteAtlas.draw(2, item.id * 2, boxx + 1, boxy + 1, 1)
            else
                SpriteAtlas.draw(0, (item.id + CC.StartThingPic) * 2, boxx + 1, boxy + 1, 1)
            end
        end
    end
    
    -- 显示页码
    local pageStr = string.format("%d/%d", select.currentPage, select.totalPages)
    RenderFacade.text(dx + w - 50, y3_2 + 5, pageStr, C_WHITE, CC.DefaultFont)
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
        RenderFacade.drawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, title, C_WHITE, CC.DefaultFont)
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
    -- 对齐原版 UseThing：先查自定义物品函数（JY.ThingUseFunction，
    -- SetModify 中注册，如罗盘 Show_Position）。命中则调用（需在协程中安装
    -- AsyncGlobals，见下方）；不命中才按 type 分发缺省处理。
    local useFn = JY.ThingUseFunction and JY.ThingUseFunction[thingId]
    if useFn ~= nil then
        -- 自定义物品函数（罗盘/醉生梦死酒/还魂液）内部使用原版阻塞式 UI
        --（DrawStrBoxWaitKey/DrawStrBoxYesNo/ShowMenu/WaitKey 等）。在事件驱动协程
        -- 中直接调用会卡死：原版 WaitKey 是 while 轮询 lib.GetKey + lib.Delay，而
        -- 事件驱动版 lib.GetKey 依赖 love.keypressed 填队列、lib.Delay 用
        -- love.timer.sleep 阻塞主循环 → 键盘事件进不来 → 永久死循环（罗盘卡死根因）。
        -- 安装 AsyncGlobals 把这些全局替换为协程版（可 yield 等键），调用后卸载，
        -- 与 event_executor / Menu_PersonExit 调用原版阻塞函数的既有模式一致。
        local AsyncGlobals = require("framework.async_globals")
        AsyncGlobals.install()
        local ok, result = pcall(useFn, thingId)
        AsyncGlobals.uninstall()
        if not ok then
            EngineAPI.debug.log("ItemAsync.UseThingAsync: custom thing function error: " .. tostring(result))
            return false
        end
        return result == 1
    end

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
-- 对齐原版 UseThing_Type0：主角面朝格的 D*>=0 时，设置 JY.CurrentThing 并
-- 触发物品事件（flag=2，事件脚本内 instruct_4 据此判断触发物品）。
function ItemAsync.UseThing_Type0Async(thingId)
    -- 剧情物品触发事件
    if JY.SubScene >= 0 then
        local x = JY.Base["人X1"] + CC.DirectX[JY.Base["人方向"] + 1]
        local y = JY.Base["人Y1"] + CC.DirectY[JY.Base["人方向"] + 1]
        local d_num = GetS(JY.SubScene, x, y, 3)
        if d_num >= 0 then
            JY.CurrentThing = thingId
            EventExecuteSync(d_num, 2)
            -- 原版在 EventExecute 返回后复位；事件驱动版事件在协程中异步执行
            -- （含跨帧对话），故延迟 2 帧复位：事件协程首帧内已读取 JY.CurrentThing
            --（instruct_4），之后复位避免污染下一次触发
            scheduler:create(function()
                scheduler:yield("time")
                scheduler:yield("time")
                JY.CurrentThing = -1
            end, "current_thing_reset")
            return true
        end
        return false
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
    local personId
    
    -- 战斗场景：直接使用当前战斗人物
    if JY.Status == GAME_WMAP then
        personId = WAR.Person[WAR.CurID]["人物编号"]
    else
        -- 非战斗场景：选择使用目标
        personId = SelectTeamMemberAsync("要给谁使用" .. thingName .. "?")
        if personId < 0 then
            return false
        end
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
