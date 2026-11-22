-- status_page.lua
-- 人物状态页的**纯绘制**（零引擎依赖、零游戏状态读取）
--
-- 分层（change: port-ui-screens-verification Task 3）：
--
--   framework/person_status_async.lua   ← 读 JY.* 组装 ctx（数据来源）
--          │  ctx（纯数据）
--          ▼
--   framework/status_page.lua           ← 本文件：只算布局 + 调 RenderFacade
--          │
--          ▼
--   framework/render_facade.lua         ← 只转发 EngineAPI.render
--
-- **为什么要拆出来**：
--   迁移前 `person_status_async.draw()` 直接调 script 全局
--   `ShowPersonStatus_sub(id, page)`，而那个函数内部有 **26 处 DrawString
--   + 1 处 DrawBox** —— framework → script → 全局绘制，与
--   `port-script-decoupling` 要消除的依赖方向完全一样。
--   但 gate STEP F 的白名单只查 8 组绘制函数，没盖住这条，于是
--   「framework 零 script 全局」这条 DoD 是靠漏判成立的。
--
-- **本文件不得**：
--   调 love.*
--   require engine-*
--   读写 JY / WAR / CC（**所有**游戏数据经 ctx 传入）
--
-- 几何公式与 `script/jymain.lua:ShowPersonStatus_sub` **逐字一致**
-- （鼠标命中判定要用同一个公式，否则「看到的框」和「点到的框」会不一致）。

local RenderFacade = require("framework.render_facade")

local StatusPage = {}

-- 页数（与 `ShowPersonStatus` 的 pagenum 一致）
StatusPage.PAGE_NUM = 2

--- 状态框几何（唯一来源）
--
-- 原公式（jymain.lua:ShowPersonStatus_sub）：
--     width  = 18*size + 15
--     h      = size + CC.PersonStateRowPixel
--     height = 13*h + 10
--     dx = (ScreenW-width)/2, dy = (ScreenH-height)/2
--
-- @param size number 字体大小
-- @param rowPixel number 行间距附加像素（CC.PersonStateRowPixel）
-- @param screenW, screenH number 屏幕尺寸
-- @return table { dx=, dy=, w=, h=, rowH= }
function StatusPage.layout(size, rowPixel, screenW, screenH)
    size = tonumber(size) or 24
    rowPixel = tonumber(rowPixel) or 1
    screenW = tonumber(screenW) or 1024
    screenH = tonumber(screenH) or 768

    local w = 18 * size + 15
    local rowH = size + rowPixel
    local h = 13 * rowH + 10
    return {
        dx = (screenW - w) / 2,
        dy = (screenH - h) / 2,
        w = w,
        h = h,
        rowH = rowH,
    }
end

--- 绘制状态页
--
-- @param ctx table 由调用方组装的**纯数据**上下文：
--   {
--     person      = table,       -- JY.Person[id]
--     thingName   = function(id),-- id → 物品名（nil 安全）
--     wugongName  = function(id),-- id → 武功名（nil 安全）
--     trainNeedExp= function(id),-- 修炼所需点数（math.huge 表示已满级）
--     levelCap    = number,      -- CC.Level
--     expTable    = table,       -- CC.Exp
--     size        = number,      -- CC.DefaultFont
--     rowPixel    = number,      -- CC.PersonStateRowPixel
--     screenW     = number,
--     screenH     = number,
--     colors      = { white=, gold=, orange=, red= },
--     rgb         = function(r,g,b) --> number,
--     headMeta    = table|nil,   -- { w=, h= } 头像尺寸（由调用方查好）
--     drawHead    = function(x, y),  -- 画头像（由调用方封装 SpriteAtlas.draw）
--   }
-- @param id number 人物编号（仅用于 ctx.trainNeedExp）
-- @param page number 1|2
function StatusPage.draw(ctx, id, page)
    if type(ctx) ~= "table" or type(ctx.person) ~= "table" then return end
    local p = ctx.person
    local C = ctx.colors or {}
    local size = ctx.size or 24
    local rgb = ctx.rgb or function(r, g, b) return (r * 65536) + (g * 256) + b end

    local L = StatusPage.layout(size, ctx.rowPixel, ctx.screenW, ctx.screenH)
    local dx, dy, width, h = L.dx, L.dy, L.w, L.rowH

    local i = 1
    local x1, y1, x2

    RenderFacade.drawBox(dx, dy, dx + width, dy + h * 13 + 10, C.white)

    x1 = dx + 5
    y1 = dy + 5
    x2 = 4 * size

    -- 头像：尺寸与绘制都由调用方提供（framework 不碰 SpriteAtlas 的游戏语义）
    local headMeta = ctx.headMeta
    if ctx.drawHead and type(headMeta) == "table" then
        local headw = headMeta.w or 0
        local headh = headMeta.h or 0
        local headx = (width / 2 - headw) / 2
        local heady = (h * 6 - headh) / 2
        ctx.drawHead(x1 + headx, y1 + heady)
    end

    i = 6
    RenderFacade.text(x1, y1 + h * i, tostring(p["姓名"] or ""), C.white, size)
    RenderFacade.text(x1 + 10 * size / 2, y1 + h * i, string.format("%3d", p["等级"] or 0), C.gold, size)
    RenderFacade.text(x1 + 13 * size / 2, y1 + h * i, "级", C.orange, size)

    local function DrawAttrib(str, color1, color2, v)
        v = v or 0
        RenderFacade.text(x1, y1 + h * i, str, color1, size)
        RenderFacade.text(x1 + x2, y1 + h * i,
            string.format("%5d", (p[str] or 0) + v), color2, size)
        i = i + 1
    end

    if page == 1 then
        local color
        -- 生命：按受伤程度着色
        if (p["受伤程度"] or 0) < 33 then
            color = rgb(236, 200, 40)
        elseif (p["受伤程度"] or 0) < 66 then
            color = rgb(244, 128, 32)
        else
            color = rgb(232, 32, 44)
        end
        i = i + 1
        RenderFacade.text(x1, y1 + h * i, "生命", C.orange, size)
        RenderFacade.text(x1 + 2 * size, y1 + h * i, string.format("%5d", p["生命"] or 0), color, size)
        RenderFacade.text(x1 + 9 * size / 2, y1 + h * i, "/", C.gold, size)

        -- 生命最大值：按中毒程度着色
        if (p["中毒程度"] or 0) == 0 then
            color = rgb(252, 148, 16)
        elseif (p["中毒程度"] or 0) < 50 then
            color = rgb(120, 208, 88)
        else
            color = rgb(56, 136, 36)
        end
        RenderFacade.text(x1 + 5 * size, y1 + h * i,
            string.format("%5s", tostring(p["生命最大值"] or 0)), color, size)

        -- 内力：按内力性质着色
        i = i + 1
        if (p["内力性质"] or 0) == 0 then
            color = rgb(208, 152, 208)
        elseif (p["内力性质"] or 0) == 1 then
            color = rgb(236, 200, 40)
        else
            color = rgb(236, 236, 236)
        end
        RenderFacade.text(x1, y1 + h * i, "内力", C.orange, size)
        RenderFacade.text(x1 + 2 * size, y1 + h * i,
            string.format("%5d/%5d", p["内力"] or 0, p["内力最大值"] or 0), color, size)

        i = i + 1
        DrawAttrib("体力", C.orange, C.gold)
        DrawAttrib("经验", C.orange, C.gold)

        -- 升级所需经验
        local tmp
        if (p["等级"] or 0) >= (ctx.levelCap or 30) then
            tmp = "="
        else
            local expTable = ctx.expTable or {}
            tmp = string.format("%5d", expTable[p["等级"] or 0] or 0)
        end
        RenderFacade.text(x1, y1 + h * i, "升级", C.orange, size)
        RenderFacade.text(x1 + x2, y1 + h * i, tmp, C.gold, size)

        -- 装备加成
        local tmp1, tmp2, tmp3 = 0, 0, 0
        local function addThing(thingId)
            if type(thingId) ~= "number" or thingId <= -1 then return end
            local bonus = ctx.thingBonus and ctx.thingBonus(thingId)
            if type(bonus) ~= "table" then return end
            tmp1 = tmp1 + (bonus.attack or 0)
            tmp2 = tmp2 + (bonus.defense or 0)
            tmp3 = tmp3 + (bonus.qinggong or 0)
        end
        addThing(p["武器"])
        addThing(p["防具"])

        i = i + 1
        RenderFacade.text(x1, y1 + h * i, "左右键翻页，上下键查看其它队友", C.red, size)

        i = 0
        x1 = dx + width / 2
        DrawAttrib("攻击力", C.white, C.gold, tmp1)
        DrawAttrib("防御力", C.white, C.gold, tmp2)
        DrawAttrib("轻功", C.white, C.gold, tmp3)

        DrawAttrib("医疗能力", C.white, C.gold)
        DrawAttrib("用毒能力", C.white, C.gold)
        DrawAttrib("解毒能力", C.white, C.gold)

        DrawAttrib("拳掌功夫", C.white, C.gold)
        DrawAttrib("御剑能力", C.white, C.gold)
        DrawAttrib("耍刀技巧", C.white, C.gold)
        DrawAttrib("特殊兵器", C.white, C.gold)
        DrawAttrib("暗器技巧", C.white, C.gold)
        DrawAttrib("资质", C.white, C.gold)

    elseif page == 2 then
        local thingName = ctx.thingName or function() return "" end
        i = i + 1
        RenderFacade.text(x1, y1 + h * i, "武器:", C.orange, size)
        if (p["武器"] or -1) > -1 then
            RenderFacade.text(x1 + size * 3, y1 + h * i, thingName(p["武器"]), C.gold, size)
        end
        i = i + 1
        RenderFacade.text(x1, y1 + h * i, "防具:", C.orange, size)
        if (p["防具"] or -1) > -1 then
            RenderFacade.text(x1 + size * 3, y1 + h * i, thingName(p["防具"]), C.gold, size)
        end

        i = i + 1
        RenderFacade.text(x1, y1 + h * i, "修炼物品", C.orange, size)
        local thingid = p["修炼物品"] or -1
        if thingid > 0 then
            i = i + 1
            RenderFacade.text(x1 + size, y1 + h * i, thingName(thingid), C.gold, size)
            i = i + 1
            local n = ctx.trainNeedExp and ctx.trainNeedExp(id) or math.huge
            if n < math.huge then
                RenderFacade.text(x1 + size, y1 + h * i,
                    string.format("%5d/%5d", p["修炼点数"] or 0, n), C.gold, size)
            else
                RenderFacade.text(x1 + size, y1 + h * i,
                    string.format("%5d/===", p["修炼点数"] or 0), C.gold, size)
            end
        else
            i = i + 2
        end

        i = i + 1
        RenderFacade.text(x1, y1 + h * i, "左右键翻页，上下键查看其它队友", C.red, size)

        i = 0
        x1 = dx + width / 2
        RenderFacade.text(x1, y1 + h * i, "所会功夫", C.orange, size)
        local wugongName = ctx.wugongName or function() return "" end
        for j = 1, 10 do
            i = i + 1
            local wugong = p["武功" .. j] or 0
            if wugong > 0 then
                local level = math.modf((p["武功等级" .. j] or 0) / 100) + 1
                RenderFacade.text(x1 + size, y1 + h * i,
                    string.format("%s", wugongName(wugong)), C.gold, size)
                RenderFacade.text(x1 + size * 7, y1 + h * i,
                    string.format("%2d", level), C.white, size)
            end
        end
    end
end

return StatusPage
