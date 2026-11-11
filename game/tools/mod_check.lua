-- tools/mod_check.lua — 全 MOD 适配自检（headless，无需 love 图形界面）
--
-- 用途：
--   回答「各个 MOD 是否都适配了」。对每个已构建的 MOD 逐一在 headless 引擎上
--   走完整启动链路，检查：记录数、字符串解码（UTF-8/无 hint 泄漏）、
--   资源回退链、事件脚本加载、对话读取、存档隔离。
--
-- 用法：
--   cd game && lua tools/mod_check.lua            # 检查 mods/ 下全部 MOD
--   cd game && lua tools/mod_check.lua mingdong   # 只检查指定 MOD
--   cd game && lua tools/mod_check.lua --json     # 机器可读输出
--
-- 退出码：0 = 全部通过；1 = 有失败项。
--
-- 说明：本脚本为每个 MOD 派生一个独立子进程（状态隔离），因此较慢（每个约 1-2 秒）。
--       单 MOD 详细检查逻辑在 tools/mod_check_one.lua。

local function sh(cmd)
    local p = io.popen(cmd .. " 2>&1")
    if not p then return nil end
    local out = p:read("*a")
    p:close()
    return out
end

local JSON = false
local only = nil
for _, a in ipairs(arg or {}) do
    if a == "--json" then JSON = true
    elseif not a:match("^%-") then only = a end
end

-- 收集已构建的 MOD（跳过审计输出目录 _audit）
local mods = {}
for m in io.popen("ls mods 2>/dev/null"):lines() do
    if m:sub(1, 1) ~= "_" then
        if not only or m == only then mods[#mods + 1] = m end
    end
end
table.sort(mods)

if #mods == 0 then
    print("mods/ 下没有已构建的 MOD。请先运行: lua tools/mod_build.lua --all")
    os.exit(1)
end

local results = {}
local nPass, nFail = 0, 0

if not JSON then
    print(string.format("%-14s %-7s %-6s %-6s %-6s %-6s %-9s %-9s %-8s",
        "MOD", "布局", "Person", "Thing", "Scene", "Wugong", "字符串", "事件", "存档"))
    print(string.rep("-", 92))
end

for _, slug in ipairs(mods) do
    local out = sh(string.format("MOD_SLUG=%s lua tools/mod_check_one.lua", slug))
    -- 解析 `KEY=value` 行
    local kv = {}
    for line in (out or ""):gmatch("[^\n]+") do
        local k, v = line:match("^([A-Z_]+)=(.*)$")
        if k then kv[k] = v end
    end

    local layout = (kv.PERSON and kv.THING and kv.SCENE and kv.WUGONG) and "OK" or "FAIL"
    local strings = kv.STRINGS or "?"
    local events = kv.EVENTS or "?"
    local save = kv.SAVE or "?"
    local ok = (layout == "OK") and (strings == "OK") and (events == "OK") and (save == "OK")
    if ok then nPass = nPass + 1 else nFail = nFail + 1 end

    results[#results + 1] = {
        slug = slug, ok = ok, layout = layout,
        person = kv.PERSON or "-", thing = kv.THING or "-",
        scene = kv.SCENE or "-", wugong = kv.WUGONG or "-",
        strings = strings, events = events, save = save,
        hero = kv.HERO or "-", note = kv.NOTE or "",
    }

    if not JSON then
        print(string.format("%-14s %-7s %-6s %-6s %-6s %-6s %-9s %-9s %-8s",
            slug, layout, kv.PERSON or "-", kv.THING or "-",
            kv.SCENE or "-", kv.WUGONG or "-", strings, events, save))
    end
end

if JSON then
    print("{")
    print('  "summary": { "total": ' .. #mods .. ', "pass": ' .. nPass .. ', "fail": ' .. nFail .. ' },')
    print('  "mods": [')
    for i, r in ipairs(results) do
        print(string.format(
            '    { "slug": "%s", "ok": %s, "person": %s, "thing": %s, "scene": %s, "wugong": %s, "hero": "%s" }%s',
            r.slug, tostring(r.ok), r.person, r.thing, r.scene, r.wugong, r.hero,
            i < #results and "," or ""))
    end
    print("  ]")
    print("}")
else
    print(string.rep("-", 92))
    print(string.format("总计: %d MOD, 通过 %d, 失败 %d", #mods, nPass, nFail))
    if nFail > 0 then
        print("\n失败明细:")
        for _, r in ipairs(results) do
            if not r.ok then
                print(string.format("  %s: 布局=%s 字符串=%s 事件=%s 存档=%s %s",
                    r.slug, r.layout, r.strings, r.events, r.save, r.note))
            end
        end
    end
end

os.exit(nFail == 0 and 0 or 1)
