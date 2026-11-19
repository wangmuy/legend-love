-- settings_store.lua
-- 设置的 INI 持久化（只做 IO，不做业务逻辑）
--
-- 与 framework/settings.lua 的分工：
--   settings.lua      schema / 三层优先级 / 变更通知   ← 零 IO
--   settings_store.lua 读文件 / 写文件 / 回读校验        ← 只有 IO
--
-- 为什么必须回读校验
-- -----------------
-- EngineAPI.file 提供 read / write / exists / getSize / remove /
-- createDirectory / directoryExists / listDirectory，但**没有 rename**。
-- LÖVE 的 love.filesystem 同样没有 rename 原语。
-- 因此「写 .tmp → rename 覆盖」这一标准原子写模式不可用。
--
-- 于是采用 ModData.writeFileRaw 已经验证过的形态：
-- 写入后把内容回读一遍，逐字节比对，一致才算成功。
-- 某些实现（测试桩、只读挂载）会返回 true 却什么也没写 —— 只看返回值不可靠。
--
-- 为什么用 INI 而不是 JSON / 二进制
-- --------------------------------
--   * 仓库已有 INI 解析语义（framework/mod_ini.lua），口径可复用
--   * 人可读、可手工编辑、支持注释
--   * 与 kysmod.ini 同一格式，用户设置与 MOD 默认可以直接对照
--
-- 跨平台
-- ------
-- 只走 EngineAPI.file.*，不直接 io.open：
--   * 桌面 / Android → love.filesystem（Android 上只有可写目录能落盘）
--   * 测试 / tools   → test_helper 的桩
--   * Web           → engine_web 的 file.write 是空实现，写入失败后
--                     settings.lua 会降级为「仅本会话有效」，不崩

local Store = {}

-- 取 EngineAPI（严格 _G 下未声明全局会抛错，必须 rawget）
local function engineFile()
    local api = rawget(_G, "EngineAPI")
    if type(api) == "table" and type(api.file) == "table" then
        return api.file
    end
    return nil
end

local function debugLog(msg)
    local lib = rawget(_G, "lib")
    if type(EngineAPI) == "table" and EngineAPI.debug
       and type(EngineAPI.debug.log) == "function" then
        pcall(EngineAPI.debug.log, msg)
    end
end

----------------------------------------------------------------------
-- 解析
----------------------------------------------------------------------

--- 解析 INI 文本
--
-- 口径与 mod_ini.lua 一致（大小写不敏感、; / # 注释、行尾注释、BOM、CRLF），
-- 但**不**做键名映射 —— 设置的 section/key 就是字面量。
--
-- 返回 { sections = {sec = {key = value}}, order = {...} }
-- value 一律是**字符串**；类型转换由 settings.lua 的 schema 负责。
--
-- @param text string|nil
-- @return table { sections = table, order = table }
function Store.parse(text)
    local result = { sections = {}, order = {} }
    if type(text) ~= "string" then return result end

    -- 去掉 UTF-8 BOM
    text = text:gsub("^\239\187\191", "")

    local sections, order = result.sections, result.order
    local cur = nil

    for rawline in text:gmatch("[^\r\n]*") do
        local line = rawline:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= ";" and line:sub(1, 1) ~= "#" then
            local sec = line:match("^%[(.-)%]")
            if sec then
                cur = sec:gsub("^%s+", ""):gsub("%s+$", ""):lower()
                if not sections[cur] then
                    sections[cur] = {}
                    order[#order + 1] = cur
                end
            else
                local k, v = line:match("^([%w_%.%-]+)%s*=%s*(.-)%s*$")
                if k and cur then
                    -- 行尾注释：; 之后的内容丢弃
                    v = v:gsub("%s*;.*$", "")
                    sections[cur][k:lower()] = v
                end
            end
        end
    end

    -- 把顺序也挂到 sections 上，使「parse → serialize」幂等：
    -- 否则 serialize 会退回按键名排序，往返后字节序可能改变。
    sections._order = order

    return result
end

----------------------------------------------------------------------
-- 序列化
----------------------------------------------------------------------

--- 把 sections 序列化为 INI 文本
--
-- 顺序优先用 sections._order（settings.save 会填），否则按键名排序，
-- 保证同样的内容总是产生同样的字节（便于回读校验与 diff）。
--
-- @param sections table { sec = {key = value}, _order = {...} }
-- @return string
function Store.serialize(sections)
    local order = sections._order
    if type(order) ~= "table" or #order == 0 then
        order = {}
        for sec in pairs(sections) do
            if sec ~= "_order" then order[#order + 1] = sec end
        end
        table.sort(order)
    end

    local out = {}
    out[#out + 1] = "; 金庸群侠传 Love2D 复刻版 — 用户设置"
    out[#out + 1] = "; 自动生成，可手工编辑。删除本文件即恢复默认值。"
    out[#out + 1] = ""

    local seen = {}
    for _, sec in ipairs(order) do
        local kv = sections[sec]
        if type(kv) == "table" and not seen[sec] then
            seen[sec] = true
            out[#out + 1] = "[" .. sec .. "]"
            local keys = {}
            for k in pairs(kv) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = kv[k]
                if type(v) == "boolean" then
                    v = v and "1" or "0"
                end
                out[#out + 1] = tostring(k) .. "=" .. tostring(v)
            end
            out[#out + 1] = ""
        end
    end

    return table.concat(out, "\n")
end

----------------------------------------------------------------------
-- 读写
----------------------------------------------------------------------

--- 读取设置文件
--
-- 文件不存在 / 读失败 / 内容为空都返回 nil（调用方回落到默认值，
-- 不得让设置文件的问题阻塞启动）。
--
-- @param path string
-- @return table|nil sections, string|nil err
function Store.read(path)
    if type(path) ~= "string" or path == "" then
        return nil, "bad-path"
    end
    local f = engineFile()
    if not f or type(f.read) ~= "function" then
        return nil, "no-engine-file-api"
    end

    local ok, text = pcall(f.read, path)
    if not ok then
        return nil, "read-failed: " .. tostring(text)
    end
    if type(text) ~= "string" or text == "" then
        return nil, "empty-or-missing"
    end

    return Store.parse(text).sections, nil
end

--- 写入设置文件（带回读校验）
--
-- @param path string
-- @param sections table
-- @return boolean ok, string|nil err
function Store.write(path, sections)
    if type(path) ~= "string" or path == "" then
        return false, "bad-path"
    end
    if type(sections) ~= "table" then
        return false, "bad-sections"
    end

    local f = engineFile()
    if not f or type(f.write) ~= "function" then
        return false, "no-engine-file-api"
    end

    local text = Store.serialize(sections)

    local ok, wrote = pcall(f.write, path, text, "wb")
    if not ok then
        return false, "write-failed: " .. tostring(wrote)
    end
    if wrote ~= true then
        -- Web 引擎的 file.write 是空函数（返回 nil）—— 由 settings.lua
        -- 降级为「仅本会话有效」，这里如实报告失败原因。
        return false, "write-rejected"
    end

    -- 回读校验：某些实现返回 true 却没真写
    if type(f.read) ~= "function" then
        return true, nil      -- 无法校验时信任写入结果
    end
    local okR, back = pcall(f.read, path)
    if not okR then
        return false, "verify-read-failed: " .. tostring(back)
    end
    if back ~= text then
        debugLog("[settings_store] 回读校验失败，内容不一致: " .. tostring(path))
        return false, "verify-mismatch"
    end

    return true, nil
end

--- 默认设置文件名
-- @return string
Store.FILENAME = "settings.ini"

return Store
