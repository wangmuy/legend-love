function love.conf(t)
    t.identity = "cloud_probe"
    t.appendidentity = false
    t.version = "11.5"
    t.window.title = "cloud probe"
    t.window.width = 1024
    t.window.height = 768
    t.window.vsync = false
    t.modules.audio = false
    t.modules.joystick = false
    t.modules.physics = false
end
