-- mouse_menu.lua
-- 鼠标相关的菜单项与开关（REQ-MS2-4）
--
-- 分层（与 audio_menu 一致）：
--   本文件          只调 Settings.get / Settings.set
--      ▼
--   Settings        纯逻辑
--      ▼ onChange
--   （无引擎接线：鼠标开关的生效方式是在消费点判断，
--     不像音量需要推给引擎）
--
-- 为什么「鼠标操作」不需要新增 menu kind（ADR-MS2-004）：
--   用普通菜单项 + 回调即可，依赖四个现成机制：
--     ① 回调拿到 newMenu 引用（menu_state_machine 的 scheduler:create）
--     ② 回调返回 0 → 菜单不关闭（pollCallback 只在 result == 1 时 close）
--     ③ draw 每帧重读 newMenu[i][1] → 文本自动更新
--     ④ 上下键在非值项上天然是导航（零改动）
--   实测已验证（见 epic.md 约束 10）。

local Settings = require("framework.settings")

local MouseMenu = {}

MouseMenu.KEY = "input.mouse"

-- 平台默认值（REQ-MS2-4）：桌面开、Android 关
-- Android 可以接 USB/蓝牙鼠标，但其主要输入方式是后续要加的虚拟按键。
MouseMenu.PLATFORM_DEFAULTS = {
    Windows = true,
    Linux   = true,
    macOS   = true,
    Android = false,
    iOS     = false,
    -- "web" 与 "unknown" 不在表里 → 落到 default(false)
}

MouseMenu.DEFAULT = false

--- 声明设置键（幂等）
-- @return boolean ok
function MouseMenu.define()
    -- 先声明虚拟手柄的键（它和鼠标操作同属「输入方式」设置，一起声明便于
    -- 设置文件一次成型）。放在这里而不是各处散落，避免漏声明。
    pcall(function()
        local VP = require("framework.virtual_pad")
        if VP and VP.SETTINGS_KEY and Settings then
            Settings.define(VP.SETTINGS_KEY, {
                default = false,
                type    = "bool",
                label   = "虚拟手柄",
                platformDefaults = VP.PLATFORM_DEFAULTS,
            })
        end
    end)

    return Settings.define(MouseMenu.KEY, {
        default = MouseMenu.DEFAULT,
        type    = "bool",
        label   = "鼠标操作",
        platformDefaults = MouseMenu.PLATFORM_DEFAULTS,
    })
end

--- 当前是否启用鼠标
-- @return boolean
function MouseMenu.isEnabled()
    return Settings.get(MouseMenu.KEY) == true
end

--- 取开关项的显示文本
-- @return string
function MouseMenu.label()
    return "鼠标操作    " .. (MouseMenu.isEnabled() and "开" or "关")
end

--- 构造「鼠标操作」菜单项
--
-- 普通菜单项（第 2 项是回调函数），不是值项：
--   * 上下键 → 纯导航（不切换）
--   * Enter / 空格 → 切换
--   * 切换后菜单不关闭（return 0），文本实时变化
--
-- **每次调用返回新表**：菜单项文本在回调里被改写，
-- 若复用同一张表，下次打开会显示上一次的文本。
--
-- @return table 菜单项 {文本, 回调, 可见性}
function MouseMenu.buildToggleItem()
    return {
        MouseMenu.label(),
        function(menu, current)
            Settings.set(MouseMenu.KEY, not MouseMenu.isEnabled())
            -- 就地改写本行文本 → draw 下一帧自动显示新值
            if menu and menu[current] then
                menu[current][1] = MouseMenu.label()
            end
            return 0    -- 0 = 不关闭菜单，可连续切换
        end,
        1,
    }
end

--- 把「鼠标操作」插到菜单项数组的指定位置之后
--
-- @param items table 原菜单项数组
-- @param afterIndex number 插在第几项之后（1-based；0 表示插到最前）
-- @return table 新数组
function MouseMenu.insertInto(items, afterIndex)
    local out = {}
    for i = 1, #items do
        out[#out + 1] = items[i]
        if i == afterIndex then
            out[#out + 1] = MouseMenu.buildToggleItem()
        end
    end
    if afterIndex <= 0 then
        table.insert(out, 1, MouseMenu.buildToggleItem())
    end
    return out
end

return MouseMenu
