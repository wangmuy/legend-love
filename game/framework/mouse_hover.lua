-- mouse_hover.lua
-- 鼠标悬停高亮 + 坐标反解 + 寻路失败红闪（REQ-MS3-1 / REQ-MS3-2）
--
-- 分层：
--   本文件    坐标反解（纯算术）+ 高亮绘制（经 EngineAPI）
--      ▼
--   EngineAPI.sprite.drawTinted    染色绘制（slice 1）
--   Settings.get("input.mouse")    开关
--
-- 菱形资源：三张地图文件（mmap/smap/wmap）的 picid 0 都是 36x18 的菱形遮罩，
-- 与瓦片尺寸（2*XScale × 2*YScale）完全吻合，所以不需要新资源、不需要多边形。

local MouseHover = {}

-- 红闪参数（REQ-MS3-3）
MouseHover.FLASH_THROTTLE_MS = 200   -- 两次红闪之间的最小间隔
MouseHover.FLASH_DURATION_MS = 150   -- 单次红闪持续时长

-- 悬停/红闪用的精灵与颜色
MouseHover.HOVER_SPRITE_ID = 0        -- 三张地图文件的 picid 0 都是菱形
-- 菱形来自哪张地图的档案：MMAP=0 / SMAP=1（战斗地图也用 0）
-- 当前 hover 只在 MMAP/SMAP 生效，camera() 会返回地图类型
MouseHover.HOVER_ATLAS_ID = 0
MouseHover.HOVER_COLOR = { r = 0, g = 0, b = 0 }
MouseHover.HOVER_ALPHA = 64
MouseHover.DENIED_COLOR = { r = 1, g = 0, b = 0 }
MouseHover.DENIED_ALPHA = 180
-- 可交互目标（门 / NPC / 物品）：青色提示，与普通黑色的可走格区分。
-- 目的：让玩家看出「这一格点下去会发生事」，而不是看到菱形却点了红闪。
MouseHover.INTERACT_COLOR = { r = 0, g = 1, b = 1 }
MouseHover.INTERACT_ALPHA = 90

-- 内部状态
-- 注意：不缓存 EngineAPI 引用（严格 _G + 表可被替换，见 test_engine_system 的教训）
local flash = {
    tileX = nil, tileY = nil,
    startMs = 0,
    lastTriggerMs = -100000,   -- 允许第一次立即触发
}

----------------------------------------------------------------------
-- 坐标反解（REQ-MS3-2 / ADR-MS3-001）
----------------------------------------------------------------------

--- 取绘图用的一半瓦片宽高（贴图尺寸的一半）
local function scales()
    local CONFIG = rawget(_G, "CONFIG")
    local xs = (CONFIG and CONFIG.XScale) or 18
    local ys = (CONFIG and CONFIG.YScale) or 9
    return xs, ys
end

local function screenCenter()
    local CONFIG = rawget(_G, "CONFIG")
    local w = (CONFIG and CONFIG.Width) or 1024
    local h = (CONFIG and CONFIG.Height) or 768
    return math.floor(w / 2), math.floor(h / 2)
end

--- 屏幕坐标 → 格坐标
--
-- **坐标系有两层，必须分清（这是本模块最容易错的地方）：**
--
--   ① 格点层 i1/j1 —— 屏幕上的菱形网格坐标
--        screenX = XScale * (i1 - j1) + W/2
--        screenY = YScale * (i1 + j1) + H/2
--
--   ② 世界层 —— 地图数据里的格坐标（GetMMap / GetS 用）
--
-- 两者**不等**，差一个相机偏移：
--   DrawMMap：world = 人X   + i1               （xoff 不存在）
--   DrawSMap：world = 人X1  + i1 + xoff
--                  = 人X1  + i1 + (相机 - 人X1)
--                  = 相机  + i1
--
-- 把 ① 反解出来的 i1 直接当世界坐标用，会整体偏移「相机位置」那么多格。
-- 实测（新游戏起点 人X1=19, 人Y1=20, 相机一旦 clamp 到 18,19）：
--   点主角脚下 → 反解成 (1,1)，偏差 (-18,-19)
-- 表现为：点近处红闪不动，点别处跑很远甚至走出地图 —— 这就是当初的 bug。
--
-- 另外 **必须 +0.5 再 floor**：
-- 整数格 (gi, gj) 绘制时中心在屏幕 (gi, gj)，而浮点空间里一个单位格是
-- [gi,gi+1]×[gj,gj+1]，几何中心在 (gi+0.5, gj+0.5)。直接 floor 有半格错位。
-- 实测：13858 个菱形内部采样点，floor 错 75.6%，round 错 0%。
--
-- @param sx, sy number 屏幕逻辑坐标
-- @param camX, camY number|nil 相机世界坐标（nil 视为 0,0，便于纯算术测试）
-- @return number gridX, gridY 世界格坐标
function MouseHover.screenToTile(sx, sy, camX, camY)
    local xs, ys = scales()
    local cx, cy = screenCenter()
    local u = (sx - cx) / xs
    local v = (sy - cy) / ys
    -- 先得到格点层 i1/j1
    local i1 = math.floor((u + v) / 2 + 0.5)
    local j1 = math.floor((v - u) / 2 + 0.5)
    -- 再转世界层
    return i1 + (camX or 0), j1 + (camY or 0)
end

--- 格坐标 → 屏幕坐标（绘制高亮用）
--
-- 必须与 screenToTile 用同一个相机，否则「看到的菱形」和「点到的格」不一致 ——
-- 那比不显示还糟。
--
-- @param gx, gy number 世界格坐标
-- @param camX, camY number|nil 相机世界坐标
-- @return number screenX, screenY
function MouseHover.tileToScreen(gx, gy, camX, camY)
    local xs, ys = scales()
    local cx, cy = screenCenter()
    local i1 = gx - (camX or 0)
    local j1 = gy - (camY or 0)
    return xs * (i1 - j1) + cx, ys * (i1 + j1) + cy
end

--- 取当前地图的相机世界坐标
--
-- 逐字对照两处绘制调用（不可自行推导，必须与绘制端一致）：
--
--   MMAP：lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
--         → 相机 = 主角坐标
--
--   SMAP：local x0 = JY.SubSceneX + JY.Base["人X1"] - 1
--         local x  = limitX(x0, CC.SceneXMin, CC.SceneXMax) - JY.Base["人X1"]
--         lib.DrawSMap(JY.SubScene, JY.Base["人X1"], JY.Base["人Y1"], x, y, pic)
--         → 相机 = limitX(JY.SubSceneX + 人X1 - 1, SceneXMin, SceneXMax)
--                  （SceneXMin/Max 是「场景视角范围」，超出则只移动主角）
--
-- @param mapKind string|nil "MMAP" | "SMAP"（nil 时按 JY.Status 判断）
-- @return number camX, camY
function MouseHover.camera(mapKind)
    local JY = rawget(_G, "JY")
    local CC = rawget(_G, "CC")
    local GAME_MMAP = rawget(_G, "GAME_MMAP")
    local GAME_SMAP = rawget(_G, "GAME_SMAP")

    if not JY then return 0, 0 end

    local GAME_WMAP = rawget(_G, "GAME_WMAP")

    local isMMAP, isWMAP
    if mapKind == "MMAP" then
        isMMAP, isWMAP = true, false
    elseif mapKind == "SMAP" then
        isMMAP, isWMAP = false, false
    elseif mapKind == "WMAP" then
        isMMAP, isWMAP = false, true
    else
        isMMAP = (JY.Status == GAME_MMAP)
        isWMAP = (JY.Status == GAME_WMAP)
    end

    -- 战斗中：相机是当前行动者的坐标
    --
    -- DrawWarMap 的坐标链（与地图同一套 i1/j1，但相机来源不同）：
    --     x1 = XScale*(i1-j1) + W/2
    --     y1 = YScale*(i1+j1) + H/2
    --     xx = WAR.Person[WAR.CurID].坐标X + i1
    --     yy = WAR.Person[WAR.CurID].坐标Y + j1
    -- 所以反解公式完全一致，只有相机要换成战斗单位坐标。
    if isWMAP then
        local WAR = rawget(_G, "WAR")
        if not (WAR and WAR.Person and WAR.CurID) then return 0, 0 end
        local p = WAR.Person[WAR.CurID]
        if not p then return 0, 0 end
        return p["坐标X"] or 0, p["坐标Y"] or 0
    end

    -- 地图状态才需要 JY.Base（战斗状态没有它）
    local Base = JY.Base
    if not Base then return 0, 0 end

    if isMMAP then
        return Base["人X"] or 0, Base["人Y"] or 0
    end

    -- SMAP：与 DrawSMap 的调用端逐字一致
    local px = Base["人X1"] or 0
    local py = Base["人Y1"] or 0
    local subX = JY.SubSceneX or 0
    local subY = JY.SubSceneY or 0
    local mnX = (CC and CC.SceneXMin) or 0
    local mxX = (CC and CC.SceneXMax) or 65535
    local mnY = (CC and CC.SceneYMin) or 0
    local mxY = (CC and CC.SceneYMax) or 65535

    local function clamp(v, mn, mx)
        if v < mn then return mn end
        if v > mx then return mx end
        return v
    end

    return clamp(subX + px - 1, mnX, mxX), clamp(subY + py - 1, mnY, mxY)
end

----------------------------------------------------------------------
-- 红闪
----------------------------------------------------------------------

local function nowMs()
    local EngineAPI = rawget(_G, "EngineAPI")
    if EngineAPI and EngineAPI.time and EngineAPI.time.getTime then
        local ok, t = pcall(EngineAPI.time.getTime)
        if ok and type(t) == "number" then return t end
    end
    return os.clock() * 1000
end

--- 触发一次寻路失败红闪（200ms 节流）
-- @param gx, gy number 格坐标
-- @return boolean 是否真的触发了（节流期内返回 false）
function MouseHover.flashDenied(gx, gy)
    local t = nowMs()
    if t - flash.lastTriggerMs < MouseHover.FLASH_THROTTLE_MS then
        return false
    end
    flash.tileX = gx
    flash.tileY = gy
    flash.startMs = t
    flash.lastTriggerMs = t
    return true
end

--- 红闪是否正在显示
-- @return boolean
function MouseHover.isFlashing()
    if not flash.tileX then return false end
    return (nowMs() - flash.startMs) < MouseHover.FLASH_DURATION_MS
end

--- 清空红闪状态（场景切换等）
function MouseHover.clearFlash()
    flash.tileX = nil
    flash.tileY = nil
end

----------------------------------------------------------------------
-- 绘制
----------------------------------------------------------------------

local function settingsEnabled()
    local ok, Settings = pcall(require, "framework.settings")
    if not ok or not Settings then return false end
    return Settings.get("input.mouse") == true
end

local function mouseInWindow()
    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.input and EngineAPI.input.mousePosition) then
        return false
    end
    local ok, mx, my = pcall(EngineAPI.input.mousePosition)
    if not ok or type(mx) ~= "number" then return false end
    local CONFIG = rawget(_G, "CONFIG")
    local w = (CONFIG and CONFIG.Width) or 1024
    local h = (CONFIG and CONFIG.Height) or 768
    -- 无鼠标的引擎返回 -1,-1 → 天然落在范围外
    return mx >= 0 and mx < w and my >= 0 and my < h
end

--- 取当前悬停格的「交互提示类型」
-- @return string|nil "scene" | "event" | nil
function MouseHover.hoverKind()
    local JY = rawget(_G, "JY")
    if not (JY and JY.Status) then return nil end
    local GAME_MMAP = rawget(_G, "GAME_MMAP")
    local GAME_SMAP = rawget(_G, "GAME_SMAP")
    local mapKind
    if JY.Status == GAME_MMAP then mapKind = "MMAP"
    elseif JY.Status == GAME_SMAP then mapKind = "SMAP"
    else return nil end

    local gx, gy = MouseHover.currentTile(mapKind)
    if not gx then return nil end

    local okI, Interact = pcall(require, "framework.interact")
    if not okI or not Interact then return nil end
    return Interact.probe(mapKind, gx, gy)
end

--- 判断当前是否应该绘制悬停高亮
--
-- 复用 AutoMove.canPlayerAct()：悬停高亮是「可以点击走过去」的视觉提示，
-- 玩家不能行动时（对话/动画/事件/菜单）显示它会造成误导 ——
-- 更糟的是它会被画在对话框上面（位置 ① 在 TalkAsync 之前）。
--
-- @return boolean
function MouseHover.shouldDraw()
    if not settingsEnabled() then return false end           -- ① 开关开

    local okAM, AutoMove = pcall(require, "framework.auto_move")
    if not okAM or not AutoMove or not AutoMove.canPlayerAct then
        return false
    end
    if not AutoMove.canPlayerAct() then
        -- 菜单 / 阻塞输入 / 事件执行中 / 对话中 / 动画中 / 非地图状态
        return false
    end

    return mouseInWindow()                                    -- 鼠标在窗内
end

--- 取当前鼠标所指的格（供点击处理复用）
-- @return number|nil gridX, gridY  世界格坐标
function MouseHover.currentTile(mapKind)
    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.input and EngineAPI.input.mousePosition) then
        return nil
    end
    local ok, mx, my = pcall(EngineAPI.input.mousePosition)
    if not ok or type(mx) ~= "number" or mx < 0 then return nil end

    local camX, camY = MouseHover.camera(mapKind)
    return MouseHover.screenToTile(mx, my, camX, camY)
end

local function drawTint(gx, gy, color, alpha)
    -- 不再检查 EngineAPI.sprite.drawTinted —— 已改走 SpriteAtlas.drawTinted，
    -- 引擎侧只需要 drawHandleTinted（SpriteAtlas 内部检查）。
    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.sprite and EngineAPI.sprite.drawHandleTinted) then
        return
    end
    -- 必须用与 screenToTile 相同的相机，否则菱形画在别处
    local camX, camY = MouseHover.camera()
    local sx, sy = MouseHover.tileToScreen(gx, gy, camX, camY)
    -- 改走 SpriteAtlas.drawTinted：容器解析与锚点全在 framework，
    -- 引擎只认 handle（ADR-PORT-013 的接线层）
    local okSA, SpriteAtlas = pcall(require, "framework.sprite_atlas")
    if not okSA or not SpriteAtlas then return end

    -- 菱形来自**当前显示的那张地图**的档案（MMAP=0 / SMAP=0 各自加载，
    -- 战斗地图也用 0）。war_async 加载时都用 atlasId=0，所以统一取 0。
    pcall(SpriteAtlas.drawTinted,
        MouseHover.HOVER_ATLAS_ID, MouseHover.HOVER_SPRITE_ID,
        sx, sy, color, alpha)
end

--- 绘制悬停高亮（由 EventBridge 的 hoverOverlay 钩子调用，位置 ①）
function MouseHover.draw()
    -- 红闪优先（即使 shouldDraw 因某个条件为假，红闪仍然显示 ——
    -- 它是玩家点击后的即时反馈，不该被"鼠标出屏"之类的情况吞掉）
    if MouseHover.isFlashing() then
        drawTint(flash.tileX, flash.tileY,
            MouseHover.DENIED_COLOR, MouseHover.DENIED_ALPHA)
        return
    end

    if not MouseHover.shouldDraw() then
        return
    end

    local gx, gy = MouseHover.currentTile()
    if not gx then return end

    -- 可交互目标用青色，普通可走格用黑色
    if MouseHover.hoverKind() then
        drawTint(gx, gy, MouseHover.INTERACT_COLOR, MouseHover.INTERACT_ALPHA)
    else
        drawTint(gx, gy, MouseHover.HOVER_COLOR, MouseHover.HOVER_ALPHA)
    end
end

return MouseHover
