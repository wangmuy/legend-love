require "config"

-- Read product configuration from product.env
-- Shared between the game and CI
local product_config = {}
for line in love.filesystem.lines("product.env") do
    -- Skip comment lines and blank lines
    if not (line:match("^%s*#") or line:match("^%s*$")) then
        local key, value = line:match("([^=]+)=(.*)")
        if key then
            product_config[key] = value:match('^"?(.-)-"?$')
        end
    end
end

-- Check if running in debug mode via VSCode debugger
local IS_DEBUG = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" and arg[2] == "debug"
if IS_DEBUG then
    require("lldebugger").start()

    function love.errorhandler(msg)
        error(msg, 2)
    end
end

function love.conf(t)
    -- Use product ID from product.env if available, otherwise fallback
    t.identity = product_config["PRODUCT_ID"] or "wangmuy.love2d.jygame"
    t.appendidentity = false
    t.version = product_config["LOVE_VERSION"] or "11.5"

    -- Keep existing console setting (false for debugger compatibility)
    t.console = false
    t.accelerometerjoystick = false
    t.externalstorage = false
    t.gammacorrect = false

    -- Audio settings from product.env
    t.audio.mic = product_config["AUDIO_MIC"] or "false"
    t.audio.mixwithsystem = false

    -- Window settings - keep existing Chinese title and dimensions
    t.window.title = "金庸群侠传 lua 复刻版"
    t.window.icon = nil
    t.window.width = CONFIG.Width
    t.window.height = CONFIG.Height
    t.window.borderless = false
    t.window.resizable = false
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = (CONFIG.FullScreen == 1)
    t.window.fullscreentype = "desktop"
    t.window.vsync = true
    t.window.msaa = 0
    t.window.depth = nil
    t.window.stencil = nil
    t.window.display = 1
    t.window.highdpi = true
    t.window.usedpiscale = true
    t.window.x = nil
    t.window.y = nil

    -- Enable all standard modules
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = true
    t.modules.video = true
    t.modules.window = true
end
