require "config"

function love.conf(t)
    t.title = "金庸群侠传lua复刻版"
    t.author = "wangmuy@gmail.com"
    t.url = nil
    --t.identity = nil            -- The name of the save directory (string)
    t.version = "0.8.0"         -- The LÖVE version this game was made for (string)
    --t.console = false           -- Attach a console (boolean, Windows only)
    --t.release = false           -- Enable release mode (boolean)
    t.screen.width = CONFIG.Width        -- The window width (number)
    t.screen.height = CONFIG.Height       -- The window height (number)
    t.screen.fullscreen = (CONFIG.FullScreen==1) -- Enable fullscreen (boolean)
    t.screen.vsync = true       -- Enable vertical sync (boolean)
    t.screen.fsaa = 0           -- The number of FSAA-buffers (number)
    t.modules.joystick = false   -- Enable the joystick module (boolean)
    t.modules.audio = true      -- Enable the audio module (boolean)
    t.modules.keyboard = true   -- Enable the keyboard module (boolean)
    t.modules.event = true      -- Enable the event module (boolean)
    t.modules.image = true      -- Enable the image module (boolean)
    t.modules.graphics = true   -- Enable the graphics module (boolean)
    t.modules.timer = true      -- Enable the timer module (boolean)
    t.modules.mouse = false      -- Enable the mouse module (boolean)
    t.modules.sound = true      -- Enable the sound module (boolean)
    t.modules.physics = false    -- Enable the physics module (boolean)
end