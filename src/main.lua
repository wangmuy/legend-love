function love.load()
    require "config"
    Byte = require "lib_Byte"
    lib = require "lib_love"
    require(CONFIG.ScriptPath .. "jymain")
end

function love.run()
    math.randomseed(os.time())
    math.random()

    if love.load then love.load(arg) end
    JY_Main()
--[[
    IncludeFile();
    SetGlobalConst();
    SetGlobal();
    JY.Status=GAME_START;
    Cls()
    lib.ShowSlow(50,0);
    Cls()
    Cls()
    love.graphics.present()
    while(lib.GetKey()) do  end
]]
    --lib.PicInit("data/Mmap.col")
    --lib.PicLoadFile("data/Mmap.idx", "data/Mmap.grp", 0)
    --print("fileid=1,picid=1:", lib.PicGetXY(1, 1))
    --print("CC.MWidth:", CC.MWidth)
    --lib.LoadMMap_Sub(CONFIG.DataPath .. "Earth.002")

    --[[os.remove("debug.txt")
    for i=180,200 do lib.picFileCache[1]:getPic(i) end
    local hdsize = #(lib.picFileCache[1].pcache)
    local offset = 180
    for i=180,200 do
        love.graphics.draw(lib.picFileCache[1].pcache[i].img, ((i-1-offset)%10)*60, math.floor((i-1-offset)/10)*60)
    end
    love.graphics.present()
    lib.GetKey()--]]
--[[
    local dt = 0

    while true do
        if love.timer then
            love.timer.step()
            dt = love.timer.getDelta()
        end

        if love.update then love.update(dt) end
        if love.graphics then
            love.graphics.clear()
            if love.draw then love.draw() end
            local pic = love.graphics.newImage("pic/title.png")
            if pic ~= nil then
                love.graphics.draw(pic, 0, 0)
            end
        end

        --if love.timer then love.timer.sleep(0.001) end
        if love.graphics then love.graphics.present() end
        lib.GetKey()
    end
--]]
end
