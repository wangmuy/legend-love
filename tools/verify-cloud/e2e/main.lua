-- 主地图飘云「真实游戏流程」端到端验证驱动（取证脚本，run.sh e2e 运行）
--
-- 运行方式：把本文件 + conf.lua 与 game/{data,pic,sound,script,framework,
-- engine-love2d,simsun.ttf,product.env} 放进同一个 LÖVE 工程根目录。run.sh 已封装。
-- 走真实启动路径：JYMainAdapter.init() → LoadRecord(0) → ChangeMMap → switchState(GAME_MMAP)
--   * GAME_MMAP.enter → Init_MMap() → CloudLoadAndInit（真实 cloud.idx/grp）
--   * GAME_MMAP.update 每帧 → lib.CloudTick()（40ms 节流 + CC.MMapAmi 门控）
--   * GAME_MMAP.draw → lib.DrawMMap → 建筑层之后 DrawClouds
-- 截图：进入大地图后第 2 帧（A）与若干秒后（B），用帧差证明云在漂移；
--       并把 CC.MMapAmi 置 0 后再截（C），证明门控生效（C==B 的云位置）。
local EventBridge = require("framework.event_bridge")
local MenuAsync = require("framework.menu_async")
local JYMainAdapter = require("framework.jymain_adapter")

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

-- ------------------------------------------------------------------ driver
local driverStarted = false
local driverFrames = 0
local stage = 0
local stageAt = 0
local function now() return love.timer.getTime() end

local function shot(name)
    love.graphics.captureScreenshot(function(img)
        local ok, err = pcall(function()
            img:encode("png", string.format("e2e_%s.png", name))
        end)
        print(string.format("[e2e] shot %s ok=%s %s", name, tostring(ok), tostring(err or "")))
    end)
end

local function reportClouds(tag)
    print("[e2e] hasActiveMenu=" .. tostring(MenuAsync.hasActiveMenu()) .. " status=" .. tostring(JY.Status))
    local list = lib.CloudGetList()
    print(string.format("[e2e] %s clouds=%d mmapAmi=%s", tag, #list, tostring(CC.MMapAmi)))
    local mx = JY.Base["人X"]
    local my = JY.Base["人Y"]
    local centerX = math.floor(CONFIG.Width / 2)
    local centerY = math.floor(CONFIG.Height / 2)
    local onscreen = 0
    for i = 1, #list do
        local c = list[i]
        local x = c.Positionx - (mx * CONFIG.XScale - my * CONFIG.XScale + 8640 - centerX)
        local y = c.Positiony - (mx * CONFIG.YScale + my * CONFIG.YScale + CONFIG.YScale - centerY)
        if x + c.imgW > 0 and x < CONFIG.Width and y + c.imgH > 0 and y < CONFIG.Height then
            onscreen = onscreen + 1
        end
    end
    print(string.format("[e2e] player=(%d,%d) clouds on screen=%d", mx, my, onscreen))
    for i = 1, math.min(3, #list) do
        local c = list[i]
        print(string.format("  cloud%d pic=%d pos=(%d,%d) alpha=%d", i, c.Picnum, c.Positionx, c.Positiony, c.Alpha))
    end
    return onscreen
end

-- 随机分布的 60 朵云几乎不会恰好落在屏幕内，为了让截图可判定，
-- 把前 4 朵云反解坐标公式摆到屏幕固定位置（仅取证用）。
local function placeClouds()
    local list = lib.CloudGetList()
    local mx = JY.Base["人X"]
    local my = JY.Base["人Y"]
    local centerX = math.floor(CONFIG.Width / 2)
    local centerY = math.floor(CONFIG.Height / 2)
    local xterm = (mx * CONFIG.XScale - my * CONFIG.XScale + 8640 - centerX)
    local yterm = (mx * CONFIG.YScale + my * CONFIG.YScale + CONFIG.YScale - centerY)
    local targets = { {150, 150}, {470, 300}, {720, 470}, {300, 610} }
    for k, tp in ipairs(targets) do
        local c = list[k]
        if c then
            c.Positionx = tp[1] + (c.xoff or 0) + xterm
            c.Positiony = tp[2] + (c.yoff or 0) + yterm
        end
    end
end

-- 取证用：临时隐藏/恢复云贴图（全走既有字段，不新增生产 API）
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

function driver()
    driverFrames = driverFrames + 1
    if not driverStarted then
        if driverFrames < 300 then return end
        driverStarted = true
        print("[e2e] booting into GAME_MMAP")
        local okLoad = LoadRecord(0)
        print("[e2e] LoadRecord(0)=" .. tostring(okLoad))
        JY.Person[0]["姓名"] = CC.NewPersonName
        local sc = JY.Scene[CC.NewGameSceneID]
        local x = sc and sc["外景入口X1"] or 400
        local y = (sc and sc["外景入口Y1"] or 399) + 1
        ChangeMMap(x, y, 0)
        JY.MyPic = GetMyPic()
        JY.MmapMusic = -1
        EventBridge.getInstance():switchState(GAME_MMAP)
        -- 真实流程里「新游戏」会把标题菜单关掉（菜单协程返回）；
        -- 驱动器绕过菜单，这里手动清掉，否则 GAME_MMAP.update 会因
        -- hasActiveMenu() 提前 return（原版菜单是阻塞的，云此时也停）。
        MenuAsync.clear()
        stageAt = now()
        stage = 1
        return
    end

    if stage == 1 and now() - stageAt > 0.6 then
        placeClouds()
        reportClouds("placed")
        stage = 2
        stageAt = now()
    elseif stage == 2 and now() - stageAt > 0.4 then
        shot("A_clouds1")
        reportClouds("A")
        stage = 3
        stageAt = now()
    elseif stage == 3 and now() - stageAt > 1.6 then
        shot("B_clouds2")
        reportClouds("B")
        -- 冻结漂移：位置不应再变化
        CC.MMapAmi = 0
        stage = 4
        stageAt = now()
    elseif stage == 4 and now() - stageAt > 1.6 then
        shot("C_frozen")
        reportClouds("C")
        CC.MMapAmi = 1
        stage = 5
        stageAt = now()
    elseif stage == 5 and now() - stageAt > 1.0 then
        -- 冻结后：有云帧 vs 无云帧（同一场景、同一主角位置、云不动）
        -- 只把云的 img 置空，其余绘制路径完全一致 → 两帧差集 == 云层像素
        shot("D_with_clouds")
        stage = 6
        stageAt = now()
    elseif stage == 6 and now() - stageAt > 0.6 then
        hideClouds()
        print("[e2e] clouds hidden")
        shot("E_without_clouds")
        stage = 7
        stageAt = now()
    elseif stage == 7 and now() - stageAt > 0.6 then
        -- 把云的 img 恢复，并把 cloud1 精确摆到「主角所在的屏幕锚点」(屏幕中心)，
        -- 证明云画在建筑层(含主角，主角是 BuildingSort 的一员)之上。
        showClouds()
        -- 冻结漂移，保证 F/G 两帧除「云是否可见」外像素条件一致
        CC.MMapAmi = 0
        local list = lib.CloudGetList()
        local cx, cy = math.floor(CONFIG.Width / 2), math.floor(CONFIG.Height / 2)
        local mx, my = JY.Base["人X"], JY.Base["人Y"]
        local xterm = (mx * CONFIG.XScale - my * CONFIG.XScale + 8640 - cx)
        local yterm = (mx * CONFIG.YScale + my * CONFIG.YScale + CONFIG.YScale - cy)
        -- 选一朵「大云」(pic=8, 250x250) 摆到主角所在的屏幕锚点，
        -- 它的覆盖面积足以压住主角贴图 —— 用来证明云画在建筑层(含主角)之上。
        local c, pick = nil, -1
        for i = 1, #list do
            if list[i].Picnum == 8 and list[i].img ~= nil then c = list[i]; pick = i; break end
        end
        if c == nil then c = list[1]; pick = 1 end
        -- 主角贴图 15x39、xoff=5 yoff=44，画在屏幕锚点(cx,cy)=(512,384)，
        -- 即覆盖 (507,340)-(522,379)。把大云的绘制左上角放到 (500,330)，
        -- 使 250x250 的云完全压住主角贴图。
        -- 大云 pic=8 是 250x250，但不透明像素集中在上半部；实测最密实的
        -- 15x39 窗口在帧内偏移 (65,40) 处，故把帧左上角放到
        -- (507-65, 340-40) = (442,300)，让主角贴图正好落进云的不透明区。
        local drawX, drawY = 442, 300
        if c then
            c.Positionx = drawX + (c.xoff or 0) + xterm
            c.Positiony = drawY + (c.yoff or 0) + yterm
        end
        print(string.format("[e2e] cloud%d (pic=%d) drawn at (%d,%d) covering player sprite at (507,340)-(522,379)",
            pick, c and c.Picnum or -1, drawX, drawY))
        shot("F_cloud_over_player")
        stage = 8
        stageAt = now()
    elseif stage == 8 and now() - stageAt > 0.6 then
        hideClouds()
        shot("G_player_no_cloud")
        stage = 9
        stageAt = now()
    elseif stage == 9 and now() - stageAt > 0.4 then
        CC.MMapAmi = 1
        print("[e2e] done")
        love.event.quit()
    end
    if driverFrames == 4000 then
        print("[e2e] watchdog quit")
        love.event.quit()
    end
end
