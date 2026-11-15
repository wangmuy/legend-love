-- audio_menu.lua
-- 音量的菜单构建（只产出菜单项数组，不绘制、不调引擎）
--
-- 分层层级（ADR-AS-006，3 层无中间容器）：
--
--   [第 1 层] 系统 / 设置 子菜单
--        ├ 读取进度 / 保存进度 …
--        ├ 音乐音量  ──┐   ← 本文件的 buildVolumeMenu()
--        └ 音效音量  ──┤
--                       ▼
--   [第 2 层] 值调节界面（单项菜单）   ← 本文件的 buildValueMenu()
--        ┌──────────────────┐
--        │        ▲         │
--        │   音乐音量 64/128 │
--        │        ▼         │
--        └──────────────────┘
--
-- 分层（ADR-AS-007）：
--
--   本文件          只调 Settings.get / Settings.set
--      ▼
--   Settings        纯逻辑
--      ▼ onChange
--   audio_settings  引擎接线
--
-- 因此本文件**不引用任何引擎接口** —— 这样菜单可以脱离引擎单测。
--
-- 值项描述符（ADR-AS-002）：
--   菜单项第 2 项若是 table 且 kind == "number"，menu_state_machine 会：
--     * 创建菜单时把 desc.pending 初始化为 Settings.get(desc.key)
--     * 上下键只改 pending（不写设置、不碰引擎）
--     * 确认键才 Settings.set(desc.key, pending) 并关闭菜单
--     * 取消键丢弃 pending
--
--   前提：值项所在的菜单**只有这一项**。上下键在多项菜单里必须用于导航，
--   否则语义歧义（同一个键既调值又换行）。
--
-- 显示形态（ADR-AS-002 形态 2，三行箭头布局）。为什么显示原始值而不是百分比：
--   内部 0-128 若显示成百分比，步进 1 时 22% 的按键看不到数字变化
--   （0-128 共 129 个位置，换算后只有 100 个不同的显示值）。
--   显示原始值时每按必有变化，且与 kysmod.ini 的 VOLUME 可直接对照。
--
-- 字体约束（实测 simsun.ttf 的 cmap）：
--   ▲ U+25B2 ✓   ▼ U+25BC ✓   ↑ U+2191 ✓   ↓ U+2193 ✓
--   ▶ U+25B6 ✗   ◀ U+25C0 ✗   ← 左右三角缺失，会显示成方块
--   本设计只用上下箭头，正好在字体覆盖范围内。

local AudioSettings = require("framework.audio_settings")

local AudioMenu = {}

-- 箭头字符：用实心三角（▲▼），实测 simsun.ttf 有字形
AudioMenu.ARROW_UP   = "▲"
AudioMenu.ARROW_DOWN = "▼"

--- 构造一个值调节用的三行文本
--
-- 菜单的 DrawString 是单行的，而 menu_state_machine 支持 `\n` 分隔逐行绘制
-- （见 ADR-AS-002 的「多行文本项」）。这里把箭头与值行拼成三行。
--
-- @param label string 标签，如 "音乐音量"
-- @param valueText string 值文本，如 "64/128"
-- @return string 形如 "     ▲\n音乐音量 64/128\n     ▼"
function AudioMenu.buildThreeLine(label, valueText)
    local middle = string.format("%s %s", tostring(label), tostring(valueText))
    return table.concat({
        "    " .. AudioMenu.ARROW_UP,
        middle,
        "    " .. AudioMenu.ARROW_DOWN,
    }, "\n")
end

--- 构造值项显示文本
-- @param label string
-- @param value number 0-128
-- @return string 三行文本
function AudioMenu.formatValueText(label, value)
    local max = AudioSettings.MAX
    local n = tonumber(value) or 0
    return AudioMenu.buildThreeLine(label,
        string.format("%d/%d", n, max))
end

--- 构造一个值项描述符（用于「只有一项」的菜单）
--
-- @param key string Settings 键
-- @param label string 显示用的标签
-- @return table 菜单项 {文本, 描述符, 可见性}
function AudioMenu.buildNumberItem(key, label)
    local desc = {
        kind   = "number",
        key    = key,
        step   = 1,
        min    = AudioSettings.MIN,
        max    = AudioSettings.MAX,
        label  = label,
        -- menu_state_machine 用这个函数生成显示文本；
        -- 它拿的是 pending 值，不是 Settings.get（见 ADR-AS-002）
        format = function(value)
            return AudioMenu.formatValueText(label, value)
        end,
    }
    -- 第 1 项给个占位文本：真正的显示由 desc.format(pending) 生成
    return { label, desc, 1 }
end

--- 构造「值调节界面」的菜单项（第 2 层，单项）
--
-- **每次调用返回新表**：待定值 pending 存在描述符上，复用同一个表会让
-- 上一次的 pending 残留（例如上次调到 20 但没确认，这次进来显示 20
-- 而实际仍是 64）。
--
-- 不注册 onCursorChange：音量变更只走确认键（ADR-AS-008 明确约束）。
--
-- @param key string Settings 键，如 AudioSettings.MUSIC_KEY
-- @param label string 标签
-- @return table 含 1 个值项的菜单项数组
function AudioMenu.buildValueMenu(key, label)
    return { AudioMenu.buildNumberItem(key, label) }
end

--- 构造第 1 层的「音乐音量 / 音效音量」两项
--
-- 这两项是**普通菜单项**（不是值项）：选中它们打开各自的第 2 层值调节界面。
-- 因此第 2 项的菜单里只有一项，上下键的语义无歧义。
--
-- callback 签名与 ShowMenu 一致：callback(newMenu, current)，
-- 返回 1 表示「调用方要求退出本菜单」。
--
-- @param callback function 选中某项后的处理：callback(key, label)
-- @return table 菜单项数组
function AudioMenu.buildVolumeEntries(callback)
    local function makeEntry(key, label)
        return {
            label,
            function(_, _) 
                if callback then callback(key, label) end
                return 1    -- 打开子界面后关闭本层，符合「选中即离开」的既有语义
            end,
            1,
        }
    end
    return {
        makeEntry(AudioSettings.MUSIC_KEY, "音乐音量"),
        makeEntry(AudioSettings.SFX_KEY,   "音效音量"),
    }
end

--- 第 1 层的项数
AudioMenu.ENTRY_COUNT = 2

return AudioMenu
