-- settings.lua
-- 游戏设置的统一存储与解析（引擎无关纯逻辑模块）
--
-- 为什么需要它
-- ------------
-- 在此之前，配置来源只有三处，且互不知情：
--
--   代码默认   config.lua (CONFIG.*)     开发者写，到处读
--   游戏常量   jyconst.lua (CC.*)        开发者写，到处读
--   MOD 默认   kysmod.ini                MOD 作者写，mod_ini.lua 读
--   用户偏好   ← 完全不存在，玩家改不了任何东西并保存
--
-- 于是 CONFIG.MusicVolume / CONFIG.SoundVolume 从建立至今零读取点，
-- 20 个 MOD 认真调过的音量值被写进 CONFIG.MasterVolume 后无人问津
-- （它们是「孤儿数据」而非「解析失败」—— ModIni.Apply 确实写了）。
--
-- 本模块补上第四层（user），并让四层有明确的解析优先级。
--
-- 三层优先级（高 → 低）
-- -------------------
--   user     settings.ini       玩家在菜单里改的，持久化
--     ▼ 覆盖
--   mod      kysmod.ini         MOD 作者的推荐值，只读
--     ▼ 覆盖
--   default  Settings.define    schema 里声明的出厂值
--
-- 键名用点分命名空间（audio.music），不用嵌套表：
--   audio.music 天然映射到 INI 的 [audio] music=，
--   同一个键名可以同时出现在用户文件与 MOD 文件里，两边写法一致。
--
-- 严格 _G 注意事项
-- ---------------
-- jymain_adapter.lua 给 _G 装了严格元表：读未声明全局会 **抛错** 而不是
-- 返回 nil。本模块因此：
--   * 不引用 EngineAPI / love / CC / JY（它本就不该依赖引擎）
--   * 需要探测全局时一律 rawget（见 setStore 里对 arg 的处理不需要，但
--     store 注入走参数，不碰全局）
--
-- 本模块零 IO：持久化由注入的 store 完成（见 settings_store.lua），
-- 这样它可以像 dialog_layout / text_box_layout 一样被完全单测。

local Settings = {}

----------------------------------------------------------------------
-- 内部状态
----------------------------------------------------------------------

-- 已声明的键：key -> spec（spec 是归一化后的副本，不回写调用方的表）
local specs = {}

-- 三层值：user / mod
-- default 层即 spec.default，不单独存
-- platform 层即 spec.platformDefaults[platformName]，同样不单独存
local layers = {
    user = {},
    mod  = {},
}

-- 当前平台名（由 Settings.setPlatform 注入；未注入时视为 "unknown"）
-- 只存字符串，不存引擎对象 —— 这是 settings.lua 保持零引擎依赖的关键
local platformName = "unknown"

-- 变更监听器：key -> { fn, ... }
local listeners = {}

-- 注入的持久化后端（settings_store）；nil 时 load/save 为 no-op
local store = nil

-- 调试输出（宿主可替换；默认静默）
local logger = nil

local function log(msg)
    if logger then
        local ok = pcall(logger, msg)
        if not ok then
            -- 日志失败绝不能影响设置本身
        end
    end
end

----------------------------------------------------------------------
-- 类型与范围
----------------------------------------------------------------------

-- 把任意输入按 spec.type 转成合法值；转不了返回 nil
--
-- INI 读出来全是字符串，所以 "50" 必须能变成 50；"abc" 必须变成 nil
-- （由调用方回落到下一层），而不是抛错。
local function coerce(value, spec)
    local t = spec.type

    if t == "number" or t == "int" then
        local n = value
        if type(n) ~= "number" then
            n = tonumber(value)
        end
        if n == nil then return nil end
        -- NaN / inf 都不是合法设置
        if n ~= n then return nil end
        if n == math.huge or n == -math.huge then return nil end
        if t == "int" then
            n = math.floor(n + 0.5)
        end
        return n
    elseif t == "bool" then
        -- INI 里常见 1/0、true/false、yes/no
        if type(value) == "boolean" then return value end
        local s = tostring(value):lower()
        if s == "1" or s == "true" or s == "yes" or s == "on" then return true end
        if s == "0" or s == "false" or s == "no" or s == "off" then return false end
        return nil
    else
        -- "string" 及未知类型：原样但要能转字符串
        if value == nil then return nil end
        return tostring(value)
    end
end

-- 按 spec.min / spec.max 钳制（只对数值类型有效）
local function clamp(value, spec)
    if type(value) ~= "number" then return value end
    if spec.min and value < spec.min then return spec.min end
    if spec.max and value > spec.max then return spec.max end
    return value
end

----------------------------------------------------------------------
-- 声明
----------------------------------------------------------------------

--- 声明一个设置键
--
-- 必须先声明才能 get/set：这样 min/max/type 有唯一来源，
-- 且 Settings.keys() 能枚举出来（通用设置界面依赖这个能力）。
--
-- @param key string 点分命名空间键，如 "audio.music"
-- @param spec table { default, type, min, max, label }
--   default 必填（可以是 false / 0 / ""，但不能是 nil）
--   type    默认 "number"；可选 "int" / "bool" / "string"
--   min/max 仅对数值类型有效
--   label   供通用设置界面显示
-- @return boolean ok
function Settings.define(key, spec)
    if type(key) ~= "string" or key == "" then
        log("Settings.define: 非法键名")
        return false
    end
    if type(spec) ~= "table" then
        log("Settings.define: spec 必须是 table: " .. key)
        return false
    end
    if spec.default == nil then
        log("Settings.define: 缺少 default: " .. key)
        return false
    end

    local t = spec.type or "number"
    local def = coerce(spec.default, {
        type = t, min = spec.min, max = spec.max,
    })
    if def == nil then
        log("Settings.define: default 无法转成 " .. t .. ": " .. key)
        return false
    end

    -- 平台默认值（REQ-MS1-4）：按当前注入的平台名覆盖 default。
    --
    -- 为什么用「注入平台名」而不是在这里 require EngineAPI：
    --   本模块的硬性约束是零引擎依赖
    --   （DoD: grep -E "EngineAPI|love\.|CC\.|JY\." 必须为空）。
    --   平台名只是一个字符串，由宿主（jymain_adapter）通过
    --   Settings.setPlatform 注入，测试也可注入任意值。
    local platformDefaults = nil
    if type(spec.platformDefaults) == "table" then
        platformDefaults = {}
        for pName, pValue in pairs(spec.platformDefaults) do
            local v = coerce(pValue, { type = t, min = spec.min, max = spec.max })
            if v ~= nil then
                platformDefaults[pName] = clamp(v, spec)
            end
        end
    end

    specs[key] = {
        default = clamp(def, spec),
        type    = t,
        min     = spec.min,
        max     = spec.max,
        label   = spec.label,
        platformDefaults = platformDefaults,
    }
    return true
end

--- 取某个键的 schema 副本
-- @param key string
-- @return table|nil
function Settings.spec(key)
    local s = specs[key]
    if not s then return nil end
    -- 返回副本，避免调用方改到内部状态
    local pd = nil
    if type(s.platformDefaults) == "table" then
        pd = {}
        for k, v in pairs(s.platformDefaults) do pd[k] = v end
    end
    return {
        default = s.default,
        type    = s.type,
        min     = s.min,
        max     = s.max,
        label   = s.label,
        platformDefaults = pd,
    }
end

--- 取某个键是否已声明
-- @param key string
-- @return boolean
function Settings.isDefined(key)
    return specs[key] ~= nil
end

--- 枚举全部已声明的键（按字典序，便于测试与界面稳定排序）
-- @return table 字符串数组
function Settings.keys()
    local out = {}
    for k in pairs(specs) do
        out[#out + 1] = k
    end
    table.sort(out)
    return out
end

----------------------------------------------------------------------
-- 读取
----------------------------------------------------------------------

--- 取得多层原始值（不做声明检查，供内部与测试用）
-- @param key string
-- @param layer string "user" | "mod" | "default"
-- @return any|nil
function Settings.getLayer(key, layer)
    local spec = specs[key]
    if not spec then return nil end
    if layer == "default" then
        return spec.default
    end
    if layer == "platform" then
        local pd = spec.platformDefaults
        if type(pd) ~= "table" then return nil end
        return pd[platformName or "unknown"]
    end
    local box = layers[layer]
    if not box then return nil end
    return box[key]
end

--- 取当前生效值
--
-- 三层优先级 user > mod > default。某层的值若无法按 schema 转成合法值
-- （例如 INI 里写了 "abc"），该层被跳过而不是报错 —— 设置文件的错误
-- 不应该让游戏启动不了。
--
-- @param key string
-- @return any|nil 未声明的键返回 nil
function Settings.get(key)
    local spec = specs[key]
    if not spec then return nil end

    for _, layer in ipairs({ "user", "mod" }) do
        local raw = layers[layer][key]
        if raw ~= nil then
            local v = coerce(raw, spec)
            if v ~= nil then
                return clamp(v, spec)
            end
            log("Settings.get: " .. layer .. " 层的值非法，已跳过: " ..
                key .. "=" .. tostring(raw))
        end
    end

    -- 平台层（REQ-MS1-4）：user 与 mod 都没有时才用
    --
    -- 例：鼠标操作开关在 Windows 默认 true、Android 默认 false。
    -- 平台名由宿主注入（Settings.setPlatform），未注入时视为 "unknown"
    -- → 落到 default 兜底，行为与引入该层之前一致。
    if type(spec.platformDefaults) == "table" then
        local pv = spec.platformDefaults[platformName or "unknown"]
        if pv ~= nil then
            return pv
        end
    end

    return spec.default
end

----------------------------------------------------------------------
-- 写入
----------------------------------------------------------------------

-- 通知某键的监听器。监听器之间用 pcall 隔离：
-- 一个监听器抛错不得阻止其他监听器（音量推送与调试日志并存时会遇到）。
local function notify(key, value)
    local list = listeners[key]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], value, key)
        if not ok then
            log("Settings.onChange 监听器抛错 (" .. key .. "): " .. tostring(err))
        end
    end
end

-- 写某一层，返回是否真的变化
local function setLayer(key, value, layer)
    local spec = specs[key]
    if not spec then
        log("Settings.set: 未声明的键: " .. tostring(key))
        return false
    end

    local v = coerce(value, spec)
    if v == nil then
        log("Settings.set: 值无法转成 " .. spec.type .. ": " ..
            key .. "=" .. tostring(value))
        return false
    end
    v = clamp(v, spec)

    local box = layers[layer]
    if not box then
        log("Settings.set: 未知层: " .. tostring(layer))
        return false
    end

    if box[key] == v then
        return false    -- 值未变：不写、不通知
    end
    box[key] = v
    return true
end

--- 设置用户层值（这是菜单/界面应该调用的入口）
--
-- 写 user 层并触发 onChange。值超界会被钳制，非法值被忽略。
-- 注意「值未变不触发 onChange」—— 重复 set 同一个值不会重复推送引擎。
--
-- @param key string
-- @param value any
-- @return boolean 是否发生了变化
function Settings.set(key, value)
    local changed = setLayer(key, value, "user")
    if changed then
        notify(key, Settings.get(key))
    end
    return changed
end

--- 设置 MOD 层值
--
-- 供 mod_ini 注入 MOD 作者的推荐默认值。**不是** user 层：
-- 玩家自己的选择必须能覆盖 MOD 的意图，写 user 层等于把 MOD 默认
-- 冒充成玩家的选择，玩家就改不动了。
--
-- MOD 层变化不触发 onChange：它只影响「玩家尚未选择时」的生效值，
-- 此时若已注册监听器（如引擎音量），由调用方在 Apply 之后显式推送一次。
--
-- @param key string
-- @param value any
-- @return boolean 是否发生了变化
function Settings.setMod(key, value)
    return setLayer(key, value, "mod")
end

--- 清空某一层（测试与「恢复默认」用）
-- @param layer string|nil "user" | "mod" | nil（nil = 清全部非 default 层）
function Settings.clearLayer(layer)
    local changedKeys = {}
    local function clearOne(name)
        local box = layers[name]
        if not box then return end
        for k in pairs(box) do
            changedKeys[k] = true
        end
        layers[name] = {}
    end

    if layer == nil then
        clearOne("user")
        clearOne("mod")
    else
        clearOne(layer)
    end

    for k in pairs(changedKeys) do
        if specs[k] then notify(k, Settings.get(k)) end
    end
end

----------------------------------------------------------------------
-- 变更通知
----------------------------------------------------------------------

--- 订阅某个键的变更
--
-- 回调签名 fn(newValue, key)。同一键可注册多个监听器，各自用 pcall 隔离。
-- 值未变化时不会触发。
--
-- 典型用法（引擎接线层）：
--   Settings.onChange("audio.music", function(v)
--       EngineAPI.audio.setMusicVolume(v)
--   end)
--
-- @param key string
-- @param fn function
-- @return boolean ok
function Settings.onChange(key, fn)
    if type(fn) ~= "function" then
        log("Settings.onChange: 回调必须是函数")
        return false
    end
    if not specs[key] then
        log("Settings.onChange: 未声明的键: " .. tostring(key))
        return false
    end
    listeners[key] = listeners[key] or {}
    local list = listeners[key]
    list[#list + 1] = fn
    return true
end

--- 移除监听器（不传 fn 则清空该键的全部）
-- @param key string
-- @param fn function|nil
function Settings.offChange(key, fn)
    if not listeners[key] then return end
    if fn == nil then
        listeners[key] = nil
        return
    end
    local list = listeners[key]
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
    if #list == 0 then listeners[key] = nil end
end

--- 某键当前注册了几个监听器（测试用）
-- @param key string
-- @return number
function Settings.listenerCount(key)
    return listeners[key] and #listeners[key] or 0
end

----------------------------------------------------------------------
-- 平台（第四层）
----------------------------------------------------------------------

--- 注入当前平台名
--
-- 由宿主（jymain_adapter.lua）在初始化时调用：
--     Settings.setPlatform(EngineAPI.system.getOS())
--
-- **本模块不 require 引擎** —— 平台名只是一个字符串。
-- 这是 platformDefaults 层能保持零引擎依赖的关键（ADR-MS-005）。
--
-- 传 nil 或非字符串时视为 "unknown"（会落到 default 兜底，
-- 行为与引入平台层之前一致）。
--
-- @param name string|nil "Windows"|"Linux"|"macOS"|"Android"|"iOS"|"web"|"unknown"
function Settings.setPlatform(name)
    if type(name) == "string" and name ~= "" then
        platformName = name
    else
        platformName = "unknown"
    end
end

--- 取当前注入的平台名（测试与调试用）
-- @return string
function Settings.getPlatform()
    return platformName
end

----------------------------------------------------------------------
-- 持久化（委托给注入的 store，本模块不碰 IO）
----------------------------------------------------------------------

--- 注入持久化后端
--
-- store 需实现：
--   store.read(path)      -> sections table | nil, err
--   store.write(path, t)  -> ok boolean, err
-- path 由 Settings.setStore 的第二个参数给出。
--
-- 传 nil 可以把 store 摘掉（load/save 变 no-op），测试常用。
--
-- @param impl table|nil
-- @param path string|nil
function Settings.setStore(impl, path)
    store = impl
    Settings._storePath = path
    Settings._store = impl
end

--- 只从 store 读原始 sections（供 load 复用与测试）
-- @return table|nil
function Settings._readSections()
    if not store or not Settings._storePath then return nil end
    local ok, sections = pcall(store.read, Settings._storePath)
    if not ok or type(sections) ~= "table" then return nil end
    return sections
end

--- 从持久化文件加载 user 层
--
-- 文件读不到 / 解析失败 / store 未注入时静默返回 false —— 设置文件的
-- 问题不能让游戏启动不了。
--
-- 加载后**会通知**发生变化的键：否则「先 init（注册监听器）后 load」
-- 的顺序下，引擎拿到的是默认值而不是用户文件里的值。
--
-- @return boolean 是否读到了内容
function Settings.load()
    local sections = Settings._readSections()
    if not sections then
        log("Settings.load: 无 store 或读取失败，使用默认值")
        return false
    end

    local loaded = 0
    local changed = {}
    for key in pairs(specs) do
        local section, name = key:match("^(.-)%.([^.]+)$")
        if section then
            local kv = sections[section]
            if type(kv) == "table" and kv[name] ~= nil then
                if setLayer(key, kv[name], "user") then
                    loaded = loaded + 1
                    changed[#changed + 1] = key
                end
            end
        end
    end

    -- 值已写入，逐个通知（顺序无关，但排序后日志更稳定）
    table.sort(changed)
    for _, key in ipairs(changed) do
        notify(key, Settings.get(key))
    end

    log("Settings.load: 已加载 " .. loaded .. " 项")
    return loaded > 0
end

--- 把 user 层写回持久化文件
--
-- 只写 user 层（default 与 mod 属于代码/MOD，不该写进用户文件）。
-- 写后回读校验由 store 负责（EngineAPI.file 无 rename，无法做原子写）。
--
-- @return boolean ok, string|nil err
function Settings.save()
    if not store or not Settings._storePath then
        log("Settings.save: 无 store（或只读平台），设置仅本会话有效")
        return false, "no-store"
    end

    -- 按 section 分组
    local sections = {}
    local order = {}
    for _, key in ipairs(Settings.keys()) do
        local section, name = key:match("^(.-)%.([^.]+)$")
        if section then
            local raw = layers.user[key]
            if raw ~= nil then
                if not sections[section] then
                    sections[section] = {}
                    order[#order + 1] = section
                end
                sections[section][name] = raw
            end
        end
    end

    -- [meta] version 必须存在：键改名/改语义时没有版本号就无法安全迁移。
    sections["meta"] = sections["meta"] or {}
    sections["meta"]["version"] = 1
    local hasMeta = false
    for _, s in ipairs(order) do
        if s == "meta" then hasMeta = true; break end
    end
    if not hasMeta then
        table.insert(order, 1, "meta")
    end
    sections._order = order

    -- store.write 约定返回 (ok, err)。用 pcall 隔离异常与返回值：
    -- 直接 `local ok, err = store.write(...)` 会把抛错和「返回 false」
    -- 混在一起，无法区分。
    local callOk, wroteOk, writeErr = pcall(store.write,
        Settings._storePath, sections)
    if not callOk then
        log("Settings.save: store.write 抛错: " .. tostring(wroteOk))
        return false, tostring(wroteOk)
    end
    if wroteOk ~= true then
        log("Settings.save: 写入失败: " .. tostring(writeErr))
        return false, tostring(writeErr)
    end
    return true, nil
end

----------------------------------------------------------------------
-- 调试与测试辅助
----------------------------------------------------------------------

--- 设置日志函数（传 nil 关闭）
-- @param fn function|nil
function Settings.setLogger(fn)
    logger = fn
end

--- 清空全部状态（测试用）
--
-- 这是**破坏性**的重置：schema、三层值、监听器、store 全部丢弃。
function Settings.reset()
    specs = {}
    layers = { user = {}, mod = {} }
    listeners = {}
    store = nil
    platformName = "unknown"
    Settings._store = nil
    Settings._storePath = nil
    logger = nil
end

return Settings
