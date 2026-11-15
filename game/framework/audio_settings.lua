-- audio_settings.lua
-- 音量设置的定义与引擎接线
--
-- 分层位置（ADR-AS-007）：
--
--   audio_menu.lua   只调 Settings.get / Settings.set
--         ▼
--   Settings         纯逻辑，无引擎依赖
--         ▼ onChange 通知
--   audio_settings   本文件：把设置变化接到引擎
--         ▼
--   EngineAPI.audio  引擎实现（per-source 应用）
--
-- 菜单完全不知道音量最终怎么作用到音频上；换引擎只改本文件。
--
-- 量程 0-128（与原版 SDL_mixer / kysmod.ini 同一把尺子）。
-- 增益由引擎侧按**线性** value/128 映射，见 lib_love.lua 的注释。

local Settings = require("framework.settings")

local AudioSettings = {}

-- 键名常量：避免多处手写字符串导致拼错
AudioSettings.MUSIC_KEY = "audio.music"
AudioSettings.SFX_KEY   = "audio.sfx"

-- 量程与原版一致
AudioSettings.MIN = 0
AudioSettings.MAX = 128

-- 默认值：64 = 50%，90 = 70%
-- 收益参考：config.lua 里从未生效的旧值 16 / 32 分别是 12.5% / 25%，
-- 明显偏轻；这里取更中庸的默认，玩家可自行调整。
AudioSettings.MUSIC_DEFAULT = 64
AudioSettings.SFX_DEFAULT   = 90

-- 幂等标记：重复 init 不得重复注册监听器（否则一次 set 会推多次给引擎）
local initialized = false

--- 声明音量设置键
--
-- 只做 define，不注册监听器 —— 声明与接线分开，便于测试单独验证。
-- 重复调用是安全的（Settings.define 覆盖同名 spec）。
-- @return boolean ok
function AudioSettings.define()
    local okMusic = Settings.define(AudioSettings.MUSIC_KEY, {
        default = AudioSettings.MUSIC_DEFAULT,
        type    = "int",
        min     = AudioSettings.MIN,
        max     = AudioSettings.MAX,
        label   = "音乐音量",
    })
    local okSFX = Settings.define(AudioSettings.SFX_KEY, {
        default = AudioSettings.SFX_DEFAULT,
        type    = "int",
        min     = AudioSettings.MIN,
        max     = AudioSettings.MAX,
        label   = "音效音量",
    })
    return okMusic and okSFX
end

-- 取引擎的 audio 模块（严格 _G 下未声明全局会抛错，必须 rawget）
local function engineAudio()
    local api = rawget(_G, "EngineAPI")
    if type(api) == "table" and type(api.audio) == "table" then
        return api.audio
    end
    return nil
end

-- 把当前值推一次到引擎（注册监听器之前已有的值不会被 onChange 覆盖）
local function pushAll()
    local audio = engineAudio()
    if not audio then return end
    if type(audio.setMusicVolume) == "function" then
        pcall(audio.setMusicVolume, Settings.get(AudioSettings.MUSIC_KEY))
    end
    if type(audio.setSFXVolume) == "function" then
        pcall(audio.setSFXVolume, Settings.get(AudioSettings.SFX_KEY))
    end
end

--- 初始化：声明 + 接线 + 推初值
--
-- 幂等：重复调用不会重复注册监听器。
-- Settings.load() 必须在调用本函数之前完成（否则推给引擎的是旧值）；
-- 但即使顺序错了，下一次 onChange 也会纠正。
--
-- @return boolean ok
function AudioSettings.init()
    if initialized then
        -- 已初始化：仍重推一次当前值（调用方可能在 init 后改了设置）
        pushAll()
        return true
    end

    if not AudioSettings.define() then
        return false
    end

    local audio = engineAudio()
    if audio then
        if type(audio.setMusicVolume) == "function" then
            Settings.onChange(AudioSettings.MUSIC_KEY, function(value)
                local a = engineAudio()
                if a and type(a.setMusicVolume) == "function" then
                    pcall(a.setMusicVolume, value)
                end
            end)
        end
        if type(audio.setSFXVolume) == "function" then
            Settings.onChange(AudioSettings.SFX_KEY, function(value)
                local a = engineAudio()
                if a and type(a.setSFXVolume) == "function" then
                    pcall(a.setSFXVolume, value)
                end
            end)
        end
    end

    -- 推初值：注册监听器之前已存在的 user/mod 值不会触发 onChange
    pushAll()

    initialized = true
    return true
end

--- 测试用：重置幂等标记（不清 Settings 本身）
function AudioSettings.resetInit()
    initialized = false
end

--- 取当前音乐音量（0-128）
-- @return number
function AudioSettings.getMusic()
    return Settings.get(AudioSettings.MUSIC_KEY)
end

--- 取当前音效音量（0-128）
-- @return number
function AudioSettings.getSFX()
    return Settings.get(AudioSettings.SFX_KEY)
end

--- 设置音乐音量
-- @param value number 0-128
-- @return boolean 是否变化
function AudioSettings.setMusic(value)
    return Settings.set(AudioSettings.MUSIC_KEY, value)
end

--- 设置音效音量
-- @param value number 0-128
-- @return boolean 是否变化
function AudioSettings.setSFX(value)
    return Settings.set(AudioSettings.SFX_KEY, value)
end

return AudioSettings
