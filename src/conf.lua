require "config"

function love.conf(t)
    t.title = "金庸群侠传 lua 复刻版"
    t.author = "wangmuy@gmail.com"
    t.url = nil
    t.identity = "jy_love"
    t.version = "11.5"
    t.console = false
    t.release = false
    t.window.width = CONFIG.Width
    t.window.height = CONFIG.Height
    t.window.fullscreen = (CONFIG.FullScreen==1)
    t.window.vsync = true
    t.window.msaa = 0
    t.modules.joystick = false
    t.modules.audio = true
    t.modules.keyboard = true
    t.modules.event = true
    t.modules.image = true
    t.modules.graphics = true
    t.modules.timer = true
    t.modules.mouse = true
    t.modules.sound = true
    t.modules.physics = false
end