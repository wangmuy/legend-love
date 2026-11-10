-- 云滚动耦合端到端验证驱动（取证脚本，用 tools/verify-cloud/run.sh scroll 运行）
--
-- 运行方式：把本文件 + conf.lua 与 game/{data,pic,sound,script,framework,
-- engine-love2d,simsun.ttf,product.env} 放进同一个 LÖVE 工程根目录。run.sh 已封装。
--
-- 目标：以真实游戏流程（JYMainAdapter.init → LoadRecord(0) → GAME_MMAP →
-- GAME_MMAP.update 消费真实按键队列 → DrawMMap）驱动主角按方向键走一格，
-- 用「有云帧 / 无云帧」像素差反解云在屏幕上的真实像素包围盒，量化
--   * 主角移动 1 格时，云在屏幕上移动了多少；
--   * 同一时刻地形在屏幕上移动了多少（用同一帧的地形像素差测量）。
-- 历史 bug：云随主角左右偏移（云与地形反向滑动）。修复后云必须与地形
-- 完全同步滚动（同一位移量），且云自身不额外横移。
--
-- 取证方式：截图落盘（~/.local/share/love/cloud_scroll/）+ 屏幕坐标日志，
-- 像素分析由 tools/verify-cloud/scroll/analyze.py 完成。
local EventBridge = require("framework.event_bridge")
local MenuAsync = require("framework.menu_async")
local JYMainAdapter = require("framework.jymain_adapter")

local stage = 0
local stageAt = 0
local frames = 0
local driverStarted = false

local function now() return love.timer.getTime() end

local function shot(name)
    love.graphics.captureScreenshot(function(img)
        local ok, err = pcall(function()
            img:encode("png", string.format("sc_%s.png", name))
        end)
        print(string.format("[sc] shot %s ok=%s %s", name, tostring(ok), tostring(err or "")))
    end)
end

-- 取证用：临时隐藏/恢复云贴图（只动既有字段，不新增生产 API）
local savedImgs = {}
local function hideClouds()
    local list = lib.CloudGetList()
    for i = 1, #list do
        savedImgs[i] = list[i].img
        list[i].img = nil
    end
end
local function showClouds()
    local list = lib.CloudGetList()
    for i = 1, #list do
        if savedImgs[i] ~= nil then list[i].img = savedImgs[i] end
    end
end

-- 云的实际屏幕位置：直接调用生产代码 DrawClouds 并捕获它的绘制坐标，
-- 这样取证脚本与生产公式解耦（修复前后都能把云摆到同一目标屏幕位置）。
local function cloudScreenPos()
    local c = lib.CloudGetList()[1]
    if not c then return nil end
    local cap
    local orig = love.graphics.draw
    love.graphics.draw = function(img, x, y)
        if img == c.img and not cap then cap = { x = x, y = y } end
    end
    lib.DrawClouds(JY.Base["人X"], JY.Base["人Y"])
    love.graphics.draw = orig
    if not cap then return nil end
    return cap.x, cap.y
end

local function placeCloudAtScreen(sx, sy)
    local c = lib.CloudGetList()[1]
    if not c then return end
    c.Positionx, c.Positiony = 0, 0
    local x0, y0 = cloudScreenPos()
    if x0 == nil then return end
    c.Positionx = c.Positionx + (sx - x0)
    c.Positiony = c.Positiony + (sy - y0)
end

local function report(tag)
    local c = lib.CloudGetList()[1]
    local x, y = cloudScreenPos()
    print(string.format("[sc] %s player=(%d,%d) cloud1 pos=(%s,%s) screen=(%s,%s) pic=%s",
        tag, JY.Base["人X"], JY.Base["人Y"],
        tostring(c and c.Positionx), tostring(c and c.Positiony),
        tostring(x), tostring(y), tostring(c and c.Picnum)))
end

-- 真实按键：走 InputManager 队列 → GAME_MMAP.update → 移动主角
local function press(key)
    local InputManager = require("framework.input_manager")
    InputManager.getInstance():onKeyPressed(key, key, false)
    InputManager.getInstance():onKeyReleased(key, key)
end

function love.keypressed(key, scancode, isrepeat)
    local InputManager = require("framework.input_manager")
    InputManager.getInstance():onKeyPressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    local InputManager = require("framework.input_manager")
    InputManager.getInstance():onKeyReleased(key, scancode)
end

function love.load()
    require "framework.config"
    Byte = require "framework.lib_Byte"
    require "engine-love2d.lib_love"
    lib = require "engine-love2d.engine_love2d"
    lib.init()

    EventBridge.getInstance():init()
    require(CONFIG.ScriptPath .. "jymain")
    JYMainAdapter.init()
end

function love.update(dt)
    JYMainAdapter.update(dt)
    EventBridge.getInstance():update(dt)
    MenuAsync.update(dt)
    driver()
end

function love.draw()
    if lib and lib.SetDrawLoopFlag then lib.SetDrawLoopFlag(true) end
    EventBridge.getInstance():draw()
    MenuAsync.draw()
    if lib and lib.SetDrawLoopFlag then lib.SetDrawLoopFlag(false) end
end

function love.quit()
    if EventBridge then EventBridge.getInstance():reset() end
    if JYMainAdapter then JYMainAdapter.reset() end
    return false
end

local baseX, baseY

function driver()
    frames = frames + 1
    if not driverStarted then
        if frames < 300 then return end
        driverStarted = true
        print("[sc] booting into GAME_MMAP")
        local okLoad = LoadRecord(0)
        print("[sc] LoadRecord(0)=" .. tostring(okLoad))
        JY.Person[0]["姓名"] = CC.NewPersonName
        local sc = JY.Scene[CC.NewGameSceneID]
        local x = sc and sc["外景入口X1"] or 400
        local y = (sc and sc["外景入口Y1"] or 399) + 1
        ChangeMMap(x, y, 0)
        JY.MyPic = GetMyPic()
        JY.MmapMusic = -1
        EventBridge.getInstance():switchState(GAME_MMAP)
        MenuAsync.clear()
        -- 冻结云自身漂移，隔离「相机滚动」这一个变量
        CC.MMapAmi = 0
        stage, stageAt = 1, now()
        return
    end

    local wait = now() - stageAt
    if stage == 1 then
        if wait > 0.5 then
            placeCloudAtScreen(420, 260)
            baseX, baseY = JY.Base["人X"], JY.Base["人Y"]
            print(string.format("[sc] base player=(%d,%d)", baseX, baseY))
            report("placed")
            stage, stageAt = 2, now()
        end
    elseif stage == 2 then
        if wait > 0.35 then
            -- 位置 0：起始位置
            showClouds(); shot("p0_with")
            stage, stageAt = 3, now()
        end
    elseif stage == 3 then
        if wait > 0.25 then
            hideClouds(); shot("p0_without")
            stage, stageAt = 4, now()
        end
    elseif stage == 4 then
        if wait > 0.25 then
            showClouds()
            press("right")   -- 人X+1
            stage, stageAt = 5, now()
        end
    elseif stage == 5 then
        if wait > 0.35 then
            report("after_right")
            shot("p1_with")
            stage, stageAt = 6, now()
        end
    elseif stage == 6 then
        if wait > 0.25 then
            hideClouds(); shot("p1_without")
            stage, stageAt = 7, now()
        end
    elseif stage == 7 then
        if wait > 0.25 then
            showClouds()
            press("down")    -- 人Y+1（回到 X+1, Y+1）
            stage, stageAt = 8, now()
        end
    elseif stage == 8 then
        if wait > 0.35 then
            report("after_down")
            shot("p2_with")
            stage, stageAt = 9, now()
        end
    elseif stage == 9 then
        if wait > 0.25 then
            hideClouds(); shot("p2_without")
            stage, stageAt = 10, now()
        end
    elseif stage == 10 then
        if wait > 0.25 then
            showClouds()
            press("left")
            stage, stageAt = 11, now()
        end
    elseif stage == 11 then
        if wait > 0.35 then
            report("after_left")
            stage, stageAt = 12, now()
        end
    elseif stage == 12 then
        if wait > 0.25 then
            press("left")
            stage, stageAt = 13, now()
        end
    elseif stage == 13 then
        if wait > 0.35 then
            report("after_left2")
            shot("p3_with")
            stage, stageAt = 14, now()
        end
    elseif stage == 14 then
        if wait > 0.25 then
            hideClouds(); shot("p3_without")
            stage, stageAt = 15, now()
        end
    elseif stage == 15 then
        if wait > 0.25 then
            showClouds()
            press("up")
            stage, stageAt = 16, now()
        end
    elseif stage == 16 then
        if wait > 0.35 then
            report("after_up")
            print("[sc] done")
            love.event.quit()
        end
    end
    if frames == 5000 then
        print("[sc] watchdog quit")
        love.event.quit()
    end
end
