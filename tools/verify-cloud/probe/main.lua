-- 主地图飘云运行时验证探针（真实数据 + 真实渲染路径 + 单次截图）
-- 运行方式：bash tools/verify-cloud/run.sh probe
-- 云世界 17280x8640 远大于 1024x768 屏幕，随机分布时屏幕内平均不到 1 朵云，
-- 故先把前 4 朵云「反解坐标公式」强制摆到屏幕固定位置，再按模式截图：
--   PROBE_MODE=nocloud  清空每朵云的 img（DrawClouds 直接跳过）→ 只有地形/建筑
--   PROBE_MODE=static   正常云，MMAPAMI=0（静止）
--   PROBE_MODE=moved    正常云，MMAPAMI=1 且推进 1.5s 的 40ms tick（已右移）
-- 每次运行只截一张图（cloud_probe_<mode>.png），避免多次截图回调时序互相干扰。
-- 三次运行的噪点相同（固定随机种子），故可像素级对比。
local lib
local frames = 0
local shotDone = false
local PX, PY = 240, 224
local MODE = os.getenv("PROBE_MODE") or "static"
local TARGETS = { { 150, 150 }, { 450, 320 }, { 700, 480 }, { 320, 620 } }

local function placeClouds()
    local centerX = math.floor(CONFIG.Width / 2)
    local centerY = math.floor(CONFIG.Height / 2)
    local list = lib.CloudGetList()
    local xterm = (PX * CONFIG.XScale - PY * CONFIG.XScale + 8640 - centerX)
    local yterm = (PX * CONFIG.YScale + PY * CONFIG.YScale + CONFIG.YScale - centerY)
    for k, tp in ipairs(TARGETS) do
        local c = list[k]
        if c then
            c.Positionx = tp[1] + (c.xoff or 0) + xterm
            c.Positiony = tp[2] + (c.yoff or 0) + yterm
        end
    end
end

local function shot(name)
    love.graphics.captureScreenshot(function(img)
        local ok, err = pcall(function()
            img:encode("png", string.format("cloud_probe_%s.png", name))
        end)
        print(string.format("[probe] shot %s ok=%s %s", name, tostring(ok), tostring(err or "")))
    end)
end

function love.load()
    require "framework.config"
    Byte = require "framework.lib_Byte"
    require "engine-love2d.lib_love"
    lib = require "engine-love2d.engine_love2d"
    lib.init()

    math.randomseed(20261110)
    lib.PicInit(CC.PaletteFile)
    lib.LoadMMap(CC.MMapFile[1], CC.MMapFile[2], CC.MMapFile[3],
                 CC.MMapFile[4], CC.MMapFile[5], CC.MWidth, CC.MHeight, PX, PY)
    lib.PicLoadFile(CC.MMAPPicFile[1], CC.MMAPPicFile[2], 0)
    lib.PicLoadFile(CC.HeadPicFile[1], CC.HeadPicFile[2], 1)
    CC.MMapAmi = (MODE == "moved") and 1 or 0
    lib.CloudLoadAndInit(CC.CloudPicFile[1], CC.CloudPicFile[2])
    placeClouds()

    local list = lib.CloudGetList()
    if MODE == "nocloud" then
        for i = 1, #list do list[i].img = nil end
    end
    print(string.format("[probe] mode=%s clouds=%d", MODE, #list))
    for i = 1, 4 do
        local c = list[i]
        if c then
            print(string.format("  cloud%d pic=%d target=(%d,%d) pos=(%d,%d) img=%s %dx%d alpha=%d mixAlpha=%d",
                i, c.Picnum, TARGETS[i][1], TARGETS[i][2], c.Positionx, c.Positiony,
                tostring(c.img ~= nil), c.imgW or -1, c.imgH or -1, c.Alpha, c.mixAlpha))
        end
    end
end

function love.update(dt)
    frames = frames + 1
    -- 与 framework/game_states.lua GAME_MMAP.update 一致：每帧调用，内部 40ms 节流
    lib.CloudTick()

    if not shotDone and frames == 130 then
        shotDone = true
        shot(MODE)
        local list = lib.CloudGetList()
        for i = 1, 4 do
            local c = list[i]
            print(string.format("  [captured] cloud%d pos=(%d,%d)", i, c.Positionx, c.Positiony))
        end
    elseif shotDone and frames == 140 then
        love.event.quit()
    end
end

function love.draw()
    if lib.SetDrawLoopFlag then lib.SetDrawLoopFlag(true) end
    lib.SetClip(0, 0, CC.ScreenW, CC.ScreenH)
    lib.DrawMMap(PX, PY, 2501)
    lib.SetClip(0, 0, 0, 0)
    if lib.SetDrawLoopFlag then lib.SetDrawLoopFlag(false) end
end
