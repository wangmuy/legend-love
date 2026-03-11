function love.load()
    -- 使用 regular alpha 模式（非预乘）
    if love.graphics then
        love.graphics.setBlendMode("alpha")
        love.graphics.setDefaultFilter("nearest", "nearest")
        love.graphics.setBackgroundColor(0, 0, 0, 1)
    end
    
    math.randomseed(os.time())
    math.random()
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
end
