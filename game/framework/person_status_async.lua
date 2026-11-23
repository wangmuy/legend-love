-- person_status_async.lua
-- 异步人物状态显示模块
-- 提供非阻塞版本的人物状态显示功能

local PersonStatusAsync = {}

-- 导入必要的模块
local CoroutineScheduler = require("framework.coroutine_scheduler")

-- 当前显示的状态数据
local currentStatus = nil

-- 鼠标点击产生的待处理动作（REQ-MS2-10）
--
-- 与 ItemAsync 同一模式：状态页是 `while true do WaitKey() end` 的协程，
-- 外部无法让它直接返回，只能 ① 记录意图 ② 注入唤醒键 ③ 循环开头消费意图。
local pendingStatusAction = nil

-- 状态页总数（与 ShowPersonStatus 的 pagenum 一致）
local PAGE_NUM = 2

-- 前向声明：`draw()` 在定义之后才用到它（Lua 的 local 必须先声明）
local ShowStatusPageDirect

-- 每页对应的「热区」——目前整块状态框都算下一页热区
PersonStatusAsync.PAGE_NUM = PAGE_NUM

-- 异步显示人物状态
-- teamid: 队伍位置（1-6）
-- 返回: 无（直接显示，ESC退出）
function PersonStatusAsync.ShowStatusCoroutine(teamid)
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: started with teamid=" .. tostring(teamid))
    end
    
    -- 设置标志，阻止游戏主循环处理按键
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = true
    
    local page = 1
    local pagenum = 2
    local teamnum = GetTeamNum()
    local scheduler = CoroutineScheduler.getInstance()
    local InputAsync = require("framework.input_async")
-- 语义动作（input-action-layer Task 5 批 5）
local InputActions = require("framework.input_actions")
    
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: modules loaded")
    end
    
    -- 设置当前显示的状态数据（只在开始时设置一次）
    local id = JY.Base["队伍" .. teamid]
    if id >= 0 then
        currentStatus = {
            personId = id,
            page = page,
            teamid = teamid
        }
        if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
            EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: set currentStatus, personId=" .. tostring(id))
        end
    end
    
    while true do
        -- 更新当前显示的状态数据（如果人物或页面变化）
        local newId = JY.Base["队伍" .. teamid]
        if newId >= 0 and (not currentStatus or currentStatus.personId ~= newId or currentStatus.page ~= page) then
            currentStatus = {
                personId = newId,
                page = page,
                teamid = teamid
            }
            if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
                EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: updated currentStatus, personId=" .. tostring(newId) .. ", page=" .. tostring(page))
            end
        end
        
        -- 异步等待按键
        if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
            EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: waiting for key")
        end
        -- 周期性等待（同 item_async）：悬停需要「不按键也能醒一次」
        --
        -- 若用纯 WaitKey + 注入键唤醒，会和物品清单一样出现键积压，
        -- 表现为「悬停一会儿自己翻页」。
        -- 语义动作（input-action-layer Task 5 批 5）
        local action = InputAsync.WaitActionTimeoutBypass(0.05)
        if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
            EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: action=" .. tostring(action))
        end

        -- **先消费鼠标意图**（REQ-MS2-10）
        local mouseAction = pendingStatusAction
        pendingStatusAction = nil
        if mouseAction then
            if mouseAction.kind == "nextPage" then
                -- 翻到下一页；到最后一页就回到第 1 页（循环）
                page = page + 1
                if page > PAGE_NUM then page = 1 end
            elseif mouseAction.kind == "prevPage" then
                page = page - 1
                if page < 1 then page = PAGE_NUM end
            elseif mouseAction.kind == "close" then
                currentStatus = nil
                local IM = require("framework.input_manager")
                IM.disableInput = false
                break
            end
            -- 消费完继续（不把唤醒键当键盘输入）
            action = nil
        end
        
        if action == InputActions.CANCEL then
            if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
                EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: ESC pressed, exiting")
            end
            -- 清除状态显示
            currentStatus = nil
            -- 清除标志，恢复游戏主循环按键处理
            local InputManager = require("framework.input_manager")
            InputManager.disableInput = false
            break
        elseif action == InputActions.UP then
            teamid = teamid - 1
        elseif action == InputActions.DOWN then
            teamid = teamid + 1
        elseif action == InputActions.LEFT then
            page = page - 1
        elseif action == InputActions.RIGHT then
            page = page + 1
        end
        
        teamid = limitX(teamid, 1, teamnum)
        page = limitX(page, 1, pagenum)
        
        -- 小延迟防止按键过快
        scheduler:waitForTime(0.1)
    end
    
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("PersonStatusAsync.ShowStatusCoroutine: ended")
    end
end

-- 绘制人物状态（在draw函数中调用）
--- 人物状态页是否正在显示
--
-- 与 ItemAsync.isActive 同理：不能依赖 disableInput（它每帧被覆盖）。
--
-- @return boolean
function PersonStatusAsync.isActive()
    return currentStatus ~= nil
end

--- 状态框的几何（与 ShowPersonStatus_sub 逐字一致）
--
-- jymain.lua:ShowPersonStatus_sub 里：
--     width  = 18*size + 15
--     h      = size + CC.PersonStateRowPixel
--     height = 13*h + 10
--     dx = (ScreenW-width)/2, dy = (ScreenH-height)/2
--
-- 鼠标命中必须用同一个公式，否则「看到的框」和「点到的框」会不一致。
--
-- @return table { dx=, dy=, w=, h= }
function PersonStatusAsync.layout()
    -- 几何公式**唯一来源**是 `StatusPage.layout`（同一份代码同时用于绘制
    -- 与鼠标命中 —— 各写一份必然漂移，这正是本条注释存在的原因）
    local StatusPage = require("framework.status_page")
    local L = StatusPage.layout(CC.DefaultFont, CC.PersonStateRowPixel,
                                CC.ScreenW, CC.ScreenH)
    return { dx = L.dx, dy = L.dy, w = L.w, h = L.h }
end

--- 点击状态框 → 翻下一页（循环）
--
-- 设计取舍（用户问：边缘按钮 vs 点击循环）：
--   选「点击循环」，理由：
--     ① 状态页只有 2 页，画两个箭头按钮反而增加视觉噪音
--     ② 手柄/键盘是「左右键翻页」，鼠标点击最自然的类比是「点一下翻一页」
--     ③ 需求里玩家最常做的是「看下一页」，不是「精确跳页」
--   到最后一页再点 → 回到第 1 页，形成循环，永远不会「点不动」。
--
-- @param mx, my number 屏幕坐标
-- @return boolean 是否处理了
function PersonStatusAsync.handleMouseClick(mx, my)
    if not currentStatus then return false end

    local L = PersonStatusAsync.layout()

    -- 点在框外：吃掉但不动作（关闭是右键/ESC 的职责）
    if mx < L.dx or mx > L.dx + L.w or my < L.dy or my > L.dy + L.h then
        return true
    end

    -- 只记录意图，不注入键（协程用 WaitKeyTimeoutBypass 周期性醒来消费）
    --
    -- 注入键会积压：pollHover/pollMouse 的调用频率可能高于协程消费频率，
    -- 残留的键会被当成玩家按键（物品清单那边实测到「悬停一会儿自动卖出」）。
    pendingStatusAction = { kind = "nextPage" }
    return true
end

function PersonStatusAsync.draw()
    if not currentStatus then
        return
    end

    local id = currentStatus.personId
    local page = currentStatus.page

    if id >= 0 then
        -- **不再调 script 全局 `ShowPersonStatus_sub`**（port-ui-screens-verification
        -- Task 3）：那是 framework → script → 全局绘制的反向依赖，且 gate
        -- STEP F 的白名单没盖住它，等于 DoD 靠漏判成立。
        -- 现在直接调 `framework/status_page.lua`（只经 RenderFacade）。
        ShowStatusPageDirect(id, page)
    end
end

--- 组装 ctx 并调 `StatusPage.draw`（**框架内唯一的绘制入口**）
--
-- JY/CC 的读取留在这里（本模块本来就管状态数据），
-- `status_page.lua` 只负责怎么画。
ShowStatusPageDirect = function(id, page)
    local StatusPage = require("framework.status_page")
    local p = JY.Person[id]
    local CC = rawget(_G, "CC") or {}
    local Thing, Wugong = JY.Thing, JY.Wugong

    local headMeta = nil
    local drawHead = nil
    do
        local okSA, SA = pcall(require, "framework.sprite_atlas")
        if okSA and SA and SA.getMeta then
            local m = SA.getMeta(1, p["头像代号"] * 2)
            if m then headMeta = { w = m.w, h = m.h } end
            drawHead = function(x, y) SA.draw(1, p["头像代号"] * 2, x, y, 0x1) end
        end
    end

    StatusPage.draw({
        person     = p,
        size       = CC.DefaultFont,
        rowPixel   = CC.PersonStateRowPixel,
        screenW    = CC.ScreenW,
        screenH    = CC.ScreenH,
        levelCap   = CC.Level,
        expTable   = CC.Exp,
        colors     = { white = rawget(_G, "C_WHITE"), gold = rawget(_G, "C_GOLD"),
                       orange = rawget(_G, "C_ORANGE"), red = rawget(_G, "C_RED") },
        rgb        = rawget(_G, "RGB"),
        headMeta   = headMeta,
        drawHead   = drawHead,
        thingName  = function(tid) return Thing[tid] and Thing[tid]["名称"] end,
        thingBonus = function(tid)
            local t = Thing[tid]
            if not t then return nil end
            return { attack = t["加攻击力"], defense = t["加防御力"],
                     qinggong = t["加轻功"] }
        end,
        wugongName = function(wid) return Wugong[wid] and Wugong[wid]["名称"] end,
        trainNeedExp = rawget(_G, "TrainNeedExp"),
    }, id, page)
end

PersonStatusAsync.ShowStatusPageDirect = ShowStatusPageDirect

-- 模块导出
return PersonStatusAsync
