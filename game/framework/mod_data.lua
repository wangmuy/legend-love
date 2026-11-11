-- mod_data.lua
-- MOD 数据/脚本回退加载与动态枚举（allmods-data-fallback，Contract B）
--
-- 设计要点：
--   * 纯 framework 层模块，不依赖具体引擎；文件探测通过可替换的 IO 适配器
--   * 未激活 MOD 时，Resolve/ScriptFile 返回的路径与现状**逐字节一致**（零回归）
--   * MOD 激活时：`mods/<mod>/data/<file>` 存在 → 用它；否则回退 `data/<file>`
--   * 脚本同链路：`mods/<mod>/script/<rel>` 存在 → 用它；否则回退 `script/<rel>`
--   * fight 文件集动态枚举（MOD 有则用 MOD 的，否则用原版的），编号不连续
--
-- API:
--   ModData.Active()               -> slug | nil
--   ModData.SetActive(slug)        -> nil          （测试/工具用）
--   ModData.Resolve(filename)      -> path         （相对 game/ 目录）
--   ModData.ScriptFile(relpath)    -> path
--   ModData.FightFiles()           -> { "fight000.grp", ... }
--   ModData.HasFile(path)          -> bool
--   ModData.RewriteConstants(CC, CONFIG) -> nil    （重定向 CC.* 路径常量）
--   ModData.LoadIni(opts)          -> parsed | nil （激活时解析 mods/<mod>/data/kysmod.ini）

local ModData = {}

-- ============================================================
-- 路径常量
-- ============================================================

ModData.ACTIVE_FILE = "active_mod.txt"  -- 相对 game/
ModData.DATA_DIR = "data/"
ModData.SCRIPT_DIR = "script/"
ModData.SOUND_DIR = "sound/"        -- 音效目录（REQ-SOUND-2）
ModData.MUSIC_DIR = "music/"        -- 音乐目录（REQ-MIDI-2，MOD 自带 .mid）
ModData.MODS_DIR = "mods/"
ModData.SAVE_DIR = "save/"          -- 原版（未激活 MOD）的可写存档目录

-- ============================================================
-- IO 适配（可在测试中替换）
-- ============================================================

-- 判断相对 game/ 的路径是否存在（普通文件）。默认用 io.open。
function ModData.exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

-- 判断目录是否存在（用于音效回退：mods/<slug>/sound/ 是否存在）。
function ModData.dirExists(path)
    local p = io.popen("test -d '" .. tostring(path) .. "' && echo yes 2>/dev/null")
    if not p then return false end
    local r = p:read("*l")
    p:close()
    return r == "yes"
end

-- 列出目录下匹配 pattern 的文件名（仅文件名，不含目录）。默认用 io.popen 的 ls。
function ModData.listDir(dir, pattern)
    local names = {}
    local p = io.popen("ls -1 " .. dir .. " 2>/dev/null")
    if p then
        for line in p:lines() do
            if not pattern or line:match(pattern) then
                names[#names + 1] = line
            end
        end
        p:close()
    end
    return names
end

-- 读取 active_mod.txt 内容；失败返回 nil
function ModData.readActiveFile()
    local f = io.open(ModData.ACTIVE_FILE, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

-- ============================================================
-- 激活状态
-- ============================================================

local activeSlug = nil
local activeLoaded = false

-- 归一化 slug：去空白、去 kys- 前缀（"kys-mingdong" 与 "mingdong" 等价）
-- 取首个有效行：跳过空行与 # 注释行。
-- active_mod.txt 允许保留说明文字（见 active_mod.sample.txt），只有第一个
-- 有效行生效；空文件/全注释 = 未激活（原版路径）。
-- 旧实现用 gsub("\n","") 把所有行直接拼接，导致带注释的文件被解析成
-- 一个 2000+ 字符的乱串，静默失效却不报错。
local function firstMeaningfulLine(text)
    for line in text:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            return line
        end
    end
    return nil
end

local function normalizeSlug(slug)
    if type(slug) ~= "string" then return nil end
    slug = firstMeaningfulLine(slug)
    if not slug then return nil end
    slug = slug:gsub("^kys%-", "")
    if slug == "" then return nil end
    return slug
end

-- 显式设置激活 MOD（测试/工具用）；传 nil 清除
function ModData.SetActive(slug)
    activeSlug = normalizeSlug(slug)
    activeLoaded = true
end

-- 读取激活 MOD slug；缺失/空返回 nil
function ModData.Active()
    if not activeLoaded then
        activeLoaded = true
        local raw = ModData.readActiveFile()
        activeSlug = normalizeSlug(raw)
    end
    return activeSlug
end

-- ============================================================
-- 路径回退链
-- ============================================================

-- MOD 激活时，data/ 文件优先目录：mods/<mod>/data/
local function modDataDir(slug)
    return ModData.MODS_DIR .. slug .. "/" .. ModData.DATA_DIR
end

-- MOD 激活时，script/ 文件优先目录：mods/<mod>/script/
local function modScriptDir(slug)
    return ModData.MODS_DIR .. slug .. "/" .. ModData.SCRIPT_DIR
end

-- MOD 激活时，可写存档目录：mods/<mod>/save/
local function modSaveDir(slug)
    return ModData.MODS_DIR .. slug .. "/" .. ModData.SAVE_DIR
end

-- ============================================================
-- 存档目录（MOD 间隔离）
-- ============================================================

-- 返回当前可写存档目录（相对 game/）。
--   未激活 MOD → "save/"（原版行为，零回归）
--   激活 MOD   → "mods/<slug>/save/"（各 MOD 存档互相隔离，不跨 MOD 读取）
function ModData.SaveDir()
    local slug = ModData.Active()
    if not slug then return ModData.SAVE_DIR end
    return modSaveDir(slug)
end

-- 确保存档目录存在（写文件前调用；FileUtil.open 写模式也会自动建父目录，此处为显式兜底）
function ModData.EnsureSaveDir()
    local dir = ModData.SaveDir()
    -- 去掉结尾斜杠作为目录名
    local d = dir:gsub("/$", "")
    if d == "" then return end
    os.execute("mkdir -p '" .. d .. "' 2>/dev/null")
end

-- 读取整个文件为二进制字符串；失败返回 nil
function ModData.readFileRaw(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

-- 写二进制字符串到文件（自动建父目录）；成功返回 true
function ModData.writeFileRaw(path, data)
    local dir = path:match("^(.*)/[^/]*$")
    if dir and dir ~= "" then
        os.execute("mkdir -p '" .. dir .. "' 2>/dev/null")
    end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data)
    f:close()
    return true
end

-- 首次保存存档槽 id（>0）时，若目标 idx 不存在，则从模板 idx 播种。
-- 模板优先级：
--   1) ModData.Resolve("data/ranger.idx")  —— MOD 基础数据模板，其分段偏移与
--      LoadRecord(0) 加载的 ranger.grp 严格对应（各 MOD 的 ranger.grp 大小不同）
--   2) ModData.Resolve("data/rN.idx")      —— 个别 MOD 可能自带分槽模板
-- 绝不从原版 data/rN.idx 播种（若 MOD 激活而 MOD 无 ranger.idx 才会回退到原版，
-- 此时 MOD 基础数据也用原版，仍自洽）。
-- 返回播种后目标 idx 的路径；无需播种或失败时返回 nil。
function ModData.SeedSaveSlot(id, templateName)
    if type(id) ~= "number" or id <= 0 then return nil end
    templateName = templateName or ("r" .. id .. ".idx")
    local target = ModData.SaveDir() .. "r" .. id .. ".idx"
    if ModData.exists(target) then return nil end
    -- 顺序：ranger.idx（权威基础模板）优先，其次 rN.idx
    local candidates = {
        ModData.Resolve(ModData.DATA_DIR .. "ranger.idx"),
        ModData.Resolve(ModData.DATA_DIR .. templateName),
    }
    for _, src in ipairs(candidates) do
        if ModData.exists(src) then
            local data = ModData.readFileRaw(src)
            if data and ModData.writeFileRaw(target, data) then
                return target
            end
        end
    end
    return nil
end

-- 把 "data/xxx" 形式的原版路径改写为 MOD 优先路径（若存在）
-- 仅处理以 CONFIG.DataPath / "data/" 开头的路径；其它路径原样返回。
function ModData.Resolve(filename)
    local slug = ModData.Active()
    if not slug then return filename end

    -- 归一：接受 "data/xxx"、"xxx" 两种形式
    local rel = filename
    local dataPrefix = ModData.DATA_DIR
    if rel:sub(1, #dataPrefix) == dataPrefix then
        rel = rel:sub(#dataPrefix + 1)
    end

    local modPath = modDataDir(slug) .. rel
    if ModData.exists(modPath) then
        return modPath
    end
    -- 回退原版：若原入参已带 data/ 前缀则原样返回，否则补上
    if filename:sub(1, #dataPrefix) == dataPrefix then
        return filename
    end
    return dataPrefix .. rel
end

-- 脚本回退链：mods/<mod>/script/<rel> 优先 → script/<rel>
function ModData.ScriptFile(relpath)
    local slug = ModData.Active()
    if not slug then return relpath end

    local rel = relpath
    local scriptPrefix = ModData.SCRIPT_DIR
    if rel:sub(1, #scriptPrefix) == scriptPrefix then
        rel = rel:sub(#scriptPrefix + 1)
    end

    local modPath = modScriptDir(slug) .. rel
    if ModData.exists(modPath) then
        return modPath
    end
    if relpath:sub(1, #scriptPrefix) == scriptPrefix then
        return relpath
    end
    return scriptPrefix .. rel
end

-- ============================================================
-- fight 文件动态枚举
-- ============================================================

-- 返回排序后的 fight 文件基名列表，如 { "fight000.grp", "fight002.grp", ... }
-- MOD 激活且 mods/<mod>/data/ 存在 fight*.grp → 枚举 MOD 的；否则枚举 data/ 的。
function ModData.FightFiles()
    local slug = ModData.Active()
    local dir = ModData.DATA_DIR
    if slug then
        local modDir = modDataDir(slug)
        local modFights = ModData.listDir(modDir, "^fight%d+%.grp$")
        if #modFights > 0 then
            dir = modDir
        end
    end
    local files = ModData.listDir(dir, "^fight%d+%.grp$")
    table.sort(files)
    return files
end

-- ============================================================
-- 常量重定向（CC.* 路径常量）
-- ============================================================

-- 把 jyconst.lua 中构建期拼好的绝对路径常量（形如 "data/xxx"）重写为 MOD 优先路径。
-- 未激活 MOD 时是空操作（零回归）。
function ModData.RewriteConstants(CC, CONFIG)
    if not CC then return end
    local slug = ModData.Active()
    if not slug then return end

    local dataPath = (CONFIG and CONFIG.DataPath) or ModData.DATA_DIR
    local scriptPath = (CONFIG and CONFIG.ScriptPath) or ModData.SCRIPT_DIR

    -- 将某条原版路径按回退链改写：优先 mods/<mod>/data|script/ 下的同名文件
    local function rewrite(path)
        if type(path) ~= "string" then return path end
        if path:sub(1, #dataPath) == dataPath then
            local rel = path:sub(#dataPath + 1)
            local modPath = modDataDir(slug) .. rel
            if ModData.exists(modPath) then return modPath end
            return path
        elseif path:sub(1, #scriptPath) == scriptPath then
            local rel = path:sub(#scriptPath + 1)
            local modPath = modScriptDir(slug) .. rel
            if ModData.exists(modPath) then return modPath end
            return path
        end
        return path
    end

    -- 单路径常量
    local singles = {
        "PaletteFile", "WarFile", "TalkIdxFile", "TalkGrpFile",
        "MMAPPicFile", "SMAPPicFile", "WMAPPicFile", "EffectFile",
        "HeadPicFile", "ThingPicFile", "WarMapFile", "MMapFile",
        "CloudPicFile",
    }
    for _, name in ipairs(singles) do
        local v = CC[name]
        if type(v) == "string" then
            CC[name] = rewrite(v)
        elseif type(v) == "table" then
            local out = {}
            for k, item in pairs(v) do
                out[k] = rewrite(item)
            end
            CC[name] = out
        end
    end

    -- 存档槽路径常量：索引 0 是 data/ 基础模板（走 rewrite 回退链），
    -- 索引 1..3 是可写存档槽（save/rN.*）→ 重定向到 MOD 专属存档目录，
    -- 实现「MOD 之间不共享也不读取彼此的存档」。
    local saveDir = modSaveDir(slug)
    local saveSlots = { "R_IDXFilename", "R_GRPFilename", "S_Filename", "D_Filename" }
    for _, name in ipairs(saveSlots) do
        local v = CC[name]
        if type(v) == "table" then
            local out = {}
            for k, item in pairs(v) do
                if type(k) == "number" and k > 0 and type(item) == "string"
                        and item:sub(1, #ModData.SAVE_DIR) == ModData.SAVE_DIR then
                    out[k] = saveDir .. item:sub(#ModData.SAVE_DIR + 1)
                else
                    out[k] = rewrite(item)
                end
            end
            CC[name] = out
        end
    end

    -- FightPicFile 是 printf 格式串（"data/fight%03d.idx"），只改写前缀目录
    if type(CC.FightPicFile) == "table" then
        local out = {}
        for k, item in pairs(CC.FightPicFile) do
            if type(item) == "string" and item:sub(1, #dataPath) == dataPath then
                out[k] = modDataDir(slug) .. item:sub(#dataPath + 1)
            else
                out[k] = item
            end
        end
        CC.FightPicFile = out
    end

    -- 音频常量（MIDIFile/ATKFile/EFile）也是 printf 格式串（"sound/atk%02d.wav"），
    -- 不能做字面存在性检查。仅当 MOD 确有对应的音频文件时，把前缀 sound/ 改写为
    -- mods/<slug>/sound/（REQ-SOUND-2）；否则保持原版（REQ-SOUND-3）。
    --
    -- 注意：必须逐个常量检查“是否真有匹配的文件”，不能只检查 sound/ 目录存在：
    --   20/20 MOD 的 sound/ 只有 atk*/e*/*.tit，没有 gameNN.ogg；若只查目录，
    --   MIDIFile 会被错误改写为 mods/<slug>/sound/game%02d.ogg（文件不存在）。
    local soundPrefix = (CONFIG and CONFIG.SoundPath) or ModData.SOUND_DIR
    local modSoundDir = ModData.MODS_DIR .. slug .. "/" .. ModData.SOUND_DIR
    -- 每个音频常量对应的文件名模式（文件名中无 % 字符，故用普通 %d）
    local audioConsts = {
        { "MIDIFile", "^game%d+%.ogg$" },
        { "ATKFile",  "^atk%d+%.wav$" },
        { "EFile",    "^e%d+%.wav$" },
    }
    if ModData.dirExists(modSoundDir) then
        for _, spec in ipairs(audioConsts) do
            local name, pattern = spec[1], spec[2]
            local v = CC[name]
            if type(v) == "string" and v:sub(1, #soundPrefix) == soundPrefix then
                if #ModData.listDir(modSoundDir, pattern) > 0 then
                    CC[name] = modSoundDir .. v:sub(#soundPrefix + 1)
                end
            end
        end
    end

    -- ========================================================
    -- REQ-MIDI-2: MOD 自带 MIDI 音乐直接播放（不经 OGG 转换）
    -- ========================================================
    -- 20/20 MOD 的 music/ 只有 .mid（无 .ogg），上面的 ogg 分支永不触发。
    -- 这里把 MIDIFile 重定向到 mods/<slug>/music/ 并**去掉扩展名**：
    -- CC.MIDIFile 原值 "sound/game%02d.ogg" 去掉末 4 字符（".ogg"）得到
    -- "sound/game%02d"，拼接后为 "mods/<slug>/music/game%02d"，由
    -- lib.PlayMIDI 按 .ogg -> .mid -> .mp3 顺序补全后缀。
    --
    -- 为什么把 .mid 重命名为 game<NN>.mid（而不是保留 <n>.mid）：
    --   引擎传的是 id+1（jymain.lua:2162 的 PlayMIDI(id) -> %02d, id+1），
    --   而 MOD 源文件是 music/<id>.mid（实测 <id> 命中 94.6% vs <id+1> 90.5%
    --   且多个 MOD 存在 music/0.mid，若按 id+1 会取到 -1.mid，不可能），
    --   于 是构建期把 <id>.mid 改名为 game<id+1>.mid，运行时无需额外映射。
    local modMusicDir = ModData.MODS_DIR .. slug .. "/" .. ModData.MUSIC_DIR
    if type(CC.MIDIFile) == "string"
        and CC.MIDIFile:sub(1, #soundPrefix) == soundPrefix
        and CC.MIDIFile:match("%.ogg$")
        and ModData.dirExists(modMusicDir)
        and #ModData.listDir(modMusicDir, "^game%d+%.mid$") > 0
    then
        local stem = CC.MIDIFile:sub(#soundPrefix + 1):gsub("%.ogg$", "")
        CC.MIDIFile = modMusicDir .. stem
        if ModData.Log then
            ModData.Log(string.format("[ModData] MIDIFile -> %s{ogg,mid,mp3}", CC.MIDIFile))
        end
    end
end

-- ============================================================
-- MOD 记录布局覆盖（allmods 格式）
-- ============================================================
--
-- allmods MOD 的记录大小与原版（kys-pascal）完全不同：
--   段       原版    MOD
--   Person   202  -> 182
--   Thing    260  -> 190
--   Scene     62  ->  52
--   Wugong   146  -> 136
--   Shop      30  ->  50
-- 若不覆盖，LoadRecord 会算出错误的记录数并读到错位数据。
-- 权威来源：reference/allmods/UPedit/UPedit.ini [R_Modify]

ModData.MOD_SIZES = {
    PersonSize = 182,
    ThingSize  = 190,
    SceneSize  = 52,
    WugongSize = 136,
    ShopSize   = 50,
}

-- MOD 字段偏移表
--
-- 实测验证（UPedit.ini [R_Modify] vs jyconst CC.*_S）：MOD 布局与原版
-- 结构完全相同，仅字符串字段更短，其后所有数值字段按【累计缩小量】前移：
--   Person: 姓名 20->10, 外号 20->10           => 性别起 -20
--   Thing : 名 40->20, 名2 40->20, 说明 60->30 => 练出武功起 -70
--   Scene : 名称 20->10                        => 出门音乐起 -10
--   Wugong: 名称 20->10                        => 未知起 -10
--   Shop  : 无字符串                            => 偏移不变
-- 字符串字段本身必须显式覆盖（宽度变小、偏移改变）。
ModData.MOD_STRINGS = {
    Person = { ["姓名"] = { 8, 2, 10 }, ["外号"] = { 18, 2, 10 } },
    Thing  = { ["名称"] = { 2, 2, 20 }, ["名称2"] = { 22, 2, 20 }, ["物品说明"] = { 42, 2, 30 } },
    Scene  = { ["名称"] = { 2, 2, 10 } },
    Wugong = { ["名称"] = { 2, 2, 10 } },
}

-- 各段字符串字段之后数值字段的累计缩小量（用于生成 MOD 偏移表）
ModData.MOD_SHIFT = { Person = 20, Thing = 70, Scene = 10, Wugong = 10, Shop = 0 }

-- 各段字符串字段“结束位置”（超过它的字段才需要前移）
ModData.MOD_STR_END = {
    Person = { ["姓名"] = 28, ["外号"] = 38 },   -- 原版字符串区末尾
    Thing  = { ["名称"] = 42, ["名称2"] = 82, ["物品说明"] = 142 },
    Scene  = { ["名称"] = 22 },
    Wugong = { ["名称"] = 22 },
    Shop   = {},
}

-- 根据原版 CC.<seg>_S 生成 MOD 专用的 CC.<seg>_S 表。
-- 未激活 MOD 时返回 nil。
function ModData.BuildModStruct(segName, vanillaStruct)
    local strs = ModData.MOD_STRINGS[segName]
    local shift = ModData.MOD_SHIFT[segName]
    local strEnds = ModData.MOD_STR_END[segName]
    if not shift then return nil end
    local out = {}
    -- 字符串字段：用 MOD 定义
    if strs then
        for k, v in pairs(strs) do out[k] = { v[1], v[2], v[3] } end
    end
    -- 其余字段：原版偏移 - 缩小量（仅当该字段位于字符串区之后）
    local function maxStrEnd()
        local mx = 0
        for _, e in pairs(strEnds or {}) do if e > mx then mx = e end end
        return mx
    end
    local boundary = maxStrEnd()
    for k, v in pairs(vanillaStruct or {}) do
        if not (strs and strs[k]) then
            local off = v[1]
            local newOff = off
            if off >= boundary and shift > 0 then newOff = off - shift end
            out[k] = { newOff, v[2], v[3] }
        end
    end
    return out
end

-- 覆盖引擎常量与结构表。返回 true 表示已应用。
function ModData.ApplyLayout(CC)
    if not CC then return false end
    local slug = ModData.Active()
    if not slug then return false end
    for k, v in pairs(ModData.MOD_SIZES) do
        CC[k] = v
    end
    -- 字符串结构表：重建 Person/Thing/Scene/Wugong 的 *_S
    for _, pair in ipairs({
        { "Person", "Person_S" }, { "Thing", "Thing_S" },
        { "Scene", "Scene_S" }, { "Wugong", "Wugong_S" },
    }) do
        local segName, key = pair[1], pair[2]
        local built = ModData.BuildModStruct(segName, CC[key])
        if built then CC[key] = built end
    end
    return true
end

-- ============================================================
-- 旁路字符串表（ranger.str）
-- ============================================================
--
-- MOD 原始字符串为 Big5，定长字段装不下 UTF-8（41% 超长）。构建期把字段
-- 替换为固定宽度 hint（如 "P0002"），真实 UTF-8 值写入 data/ranger.str。
-- 引擎读取时：存档覆盖（rN.ovr）→ ranger.str → 原始缓冲区（原版回退）。

ModData.SIDE_FILE = "ranger.str"
ModData.OVR_FILE  = "ranger.ovr"

-- 加载旁路表。未激活 MOD / 文件不存在时返回 nil。
-- 结果缓存在 ModData._side，可用 ModData.ClearSideCache() 清除。
function ModData.SideTable()
    if ModData._side ~= nil then return ModData._side or nil end
    local slug = ModData.Active()
    if not slug then ModData._side = false return nil end
    local path = modDataDir(slug) .. ModData.SIDE_FILE
    local data = ModData.readFileRaw(path)
    if not data then ModData._side = false return nil end
    local ok, E = pcall(require, "tools.mod_encoding")
    if not ok or not E then ModData._side = false return nil end
    ModData._side = E.ParseSideTable(data)
    return ModData._side
end

function ModData.ClearSideCache()
    ModData._side = nil
end

-- 查询旁路表：segment（"Person"/"Thing"/...）, index（数字）。
function ModData.LookupSide(segment, index)
    local side = ModData.SideTable()
    if not side then return nil end
    local t = side[segment]
    if not t then return nil end
    return t[index]
end

-- 解析 hint（如 "P0002" -> "Person", 2）。无法解析时返回 nil。
-- 前缀 -> 段名映射（与 mod_encoding.lua 的 M.LAYOUT hint 前缀一致）
ModData.HINT_PREFIX = {
    P  = { seg = "Person", field = "Name" },
    N  = { seg = "Person", field = "Nick" },
    T  = { seg = "Thing",  field = "Name" },
    T2 = { seg = "Thing",  field = "Name2" },
    TD = { seg = "Thing",  field = "Desc" },
    S  = { seg = "Scene",  field = "Name" },
    W  = { seg = "Wugong", field = "Name" },
}

function ModData.ParseHint(s)
    if type(s) ~= "string" then return nil end
    -- 前缀字母（可能带数字，如 T2）后跟 4 位数字
    local prefix, digits = s:match("^([A-Z][A-Z0-9]?)(%d%d%d%d)$")
    if not prefix then return nil end
    local info = ModData.HINT_PREFIX[prefix]
    if not info then return nil end
    return info.seg, tonumber(digits), info.field
end

-- 反向映射: (段, 字段) -> hint 前缀。用于为「未转换」的字段（构建期判定为
-- 纯 ASCII，缓冲区里存的是原文而非 hint）生成合成键，使其改写仍能进入覆盖表，
-- 而不被截断到定长字段里。
ModData.FIELD_PREFIX = {
    Person = { ["姓名"] = "P", ["外号"] = "N" },
    Thing  = { ["名称"] = "T", ["名称2"] = "T2", ["物品说明"] = "TD" },
    Scene  = { ["名称"] = "S" },
    Wugong = { ["名称"] = "W" },
}

-- 生成合成 hint：以 "!" 开头（不可能与真实 hint 冲突，因为真实 hint 首字符为 A-Z），
-- 后接 段名、字段前缀（ASCII，如 P/N/T2/TD/S/W）、记录字节偏移。
-- 例: "!Person.P.0"
-- 使用 ASCII 前缀而非中文字段名，保证覆盖表键全为 ASCII，正则解析无歧义。
function ModData.SyntheticKey(seg, field, byteOffset)
    if not seg or not field then return nil end
    local prefix
    local byField = ModData.FIELD_PREFIX[seg]
    if byField then prefix = byField[field] end
    if not prefix then return nil end
    return string.format("!%s.%s.%d", seg, prefix, byteOffset or 0)
end

-- 根据 MOD_STRINGS 的字段偏移与记录的段内偏移，找出该字段属于哪个段与字段名。
-- fieldOffset 为结构表中该字段的偏移（即 t[1]）。返回 seg, field 或 nil。
function ModData.IdentifyStringField(fieldOffset)
    if type(fieldOffset) ~= "number" then return nil end
    for seg, fields in pairs(ModData.MOD_STRINGS) do
        for field, def in pairs(fields) do
            if def[1] == fieldOffset then
                return seg, field
            end
        end
    end
    return nil
end

-- 解析一个字符串字段值：若是 hint 则查旁路表，否则原样返回。
-- 未激活 MOD / 无旁路表时原样返回（原版行为，零回归）。
function ModData.ResolveString(value)
    local side = ModData.SideTable()
    if not side then return value end
    local seg, index = ModData.ParseHint(value)
    if not seg then return value end
    local v = ModData.LookupSide(seg, index)
    if v ~= nil then return v end
    return value
end

-- 读取存档覆盖表 rN.ovr（键 "P0002" -> 值）。不存在时返回空表。
function ModData.SaveOverrides(id)
    if not id or id <= 0 then return {} end
    local slug = ModData.Active()
    if not slug then return {} end
    local path = modSaveDir(slug) .. string.format("r%d.ovr", id)
    local data = ModData.readFileRaw(path)
    if not data then return {} end
    local out = {}
    for line in data:gmatch("[^\n]+") do
        -- 真实 hint（如 "P0002"）或合成键（如 "!Person.P.0"）
        -- 键可能含中文字段名（旧格式），故用非贪婪到首个 '=' 的宽松匹配
        local k, v = line:match("^([^=]+)=(.*)$")
        if k and k ~= "" then out[k] = v end
    end
    return out
end

-- 写入存档覆盖表。ovr 为 { "P0002" = "郭靖", ... }。
function ModData.WriteSaveOverrides(id, ovr)
    if not id or id <= 0 then return false end
    local slug = ModData.Active()
    if not slug then return false end
    ModData.EnsureSaveDir()
    local keys = {}
    for k in pairs(ovr or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    local lines = {}
    for _, k in ipairs(keys) do
        lines[#lines + 1] = k .. "=" .. tostring(ovr[k])
    end
    local path = modSaveDir(slug) .. string.format("r%d.ovr", id)
    return ModData.writeFileRaw(path, table.concat(lines, "\n"))
end

-- ============================================================
-- war.sta 记录数（无索引文件，靠 warid*WarDataSize 定位）
-- ============================================================

-- 返回 CC.WarFile 中可容纳的记录数 = floor(fileSize / recordSize)。
-- 文件不存在/不可读时返回 nil。
function ModData.WarRecordCount(warFile, recordSize)
    if type(warFile) ~= "string" or type(recordSize) ~= "number" or recordSize <= 0 then
        return nil
    end
    local f = io.open(warFile, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    if not size then return nil end
    return math.floor(size / recordSize)
end

-- ============================================================
-- list/effect.bin 惰性装载（REQ-LBIN-2）
-- ============================================================

-- 读 uint16 小端数组。返回 table 或 nil。
local function readU16Array(path)
    local data = ModData.readFileRaw(path)
    if not data then return nil end
    local n = math.floor(#data / 2)
    if n == 0 then return nil end
    local out = {}
    for i = 1, n do
        local b1, b2 = data:byte((i - 1) * 2 + 1, (i - 1) * 2 + 2)
        out[i - 1] = b1 + b2 * 256   -- CC.Effect 是 0-based
    end
    return out, n
end

-- 把 mods/<mod>/data/effect.bin（构建期从 list/ 搬运）装进 CC.Effect。
-- 不修改 jyconst.lua 的字面量（禁改路径）；读不到时返回 false 并保留兜底。
-- 返回 true, count / false, reason
function ModData.LoadEffectTable(CC)
    CC = CC or _G.CC
    if type(CC) ~= "table" then return false, "no CC" end

    local slug = ModData.Active()
    if not slug then return false, "no active mod" end

    local path = modDataDir(slug) .. "effect.bin"
    if not ModData.exists(path) then return false, "missing " .. path end

    local tbl, n = readU16Array(path)
    if not tbl then return false, "empty or unreadable " .. path end

    -- 保留 [0] 的语义：effect.bin[0] 对应原版 CC.Effect[0] 的“未使用占位”。
    -- 硬编码的 CC.Effect[0] = 9 是编辑器占位值（不等于 effect.bin[0] = 10），
    -- 故这里直接用文件内容整表覆盖（包含 index 0），使数据文件成为唯一权威。
    CC.Effect = tbl
    return true, n
end

-- ============================================================
-- ini 接入
-- ============================================================

-- 激活 MOD 时解析 mods/<mod>/data/kysmod.ini 并 Apply（若 ModIni 可用）。
-- 返回 parsed 或 nil。
function ModData.LoadIni(opts)
    local slug = ModData.Active()
    if not slug then return nil end
    local iniPath = modDataDir(slug) .. "kysmod.ini"
    if not ModData.exists(iniPath) then return nil end

    local ok, ModIni = pcall(require, "framework.mod_ini")
    if not ok then return nil end

    local parsed = ModIni.Load(iniPath)
    if parsed and not (opts and opts.noApply) then
        ModIni.Apply(parsed)
    end
    return parsed
end

return ModData
