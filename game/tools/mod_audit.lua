-- mod_audit.lua -- MOD 资源覆盖穷举审计（文件级）
--
-- 目的：把"每个源文件都被检查到并归类"从人工承诺变成机器保证。
--
-- 核心设计（见 allmods-slice0c-file-inventory/design.md）：
--   * 遍历 reference/allmods/kys-*/ 的**全部**文件（不用白名单目录）
--   * 每个文件恰好归入一个类别；**未归类 = 失败**（不存在 OTHER 兜底）
--   * needed=false 的记录必须有结构化证据
--   * in_product=true 的记录必须能在 game/mods/<mod>/ 找到
--
-- 用法：
--   cd game && lua tools/mod_audit.lua --all
--   cd game && lua tools/mod_audit.lua --mod mingdong
--   cd game && lua tools/mod_audit.lua --json   # 只输出统计

local M = {}

-- 跨平台文件系统原语（Windows 上 io.popen 走 cmd.exe，POSIX 命令不可用）
local Fs = require("framework.fs_compat")

M.REPO_ROOT = ".."                      -- 相对 game/
M.MODS_SRC  = M.REPO_ROOT .. "/reference/allmods"
M.MODS_OUT  = "mods"                    -- 构建产物根
M.AUDIT_DIR = M.MODS_OUT .. "/_audit"

-- ============================================================
-- 类别枚举（REQ-INV-3）：恰好 10 项，无 OTHER/UNKNOWN/MISC 兜底
-- ============================================================
M.CATEGORY = {
    "REQUIRED",           -- 引擎必需，已进产物（原名）
    "REQUIRED_CONVERTED", -- 引擎必需，构建期转换后进产物（改名/转码/重排）
    "DESIGNED_FALLBACK",  -- 引擎可选，源不提供是预期
    "DEAD_PARAM",         -- 引擎形参从未引用
    "LEGACY",             -- C 引擎/编辑器遗留，Lua 引擎不读
    "DEAD_FILE",          -- 引擎命名规则无法生成
    "EDITOR_DUMP",        -- 编辑器导出副产物
    "BUILD_INPUT",        -- 构建器消费但引擎不读（如 kysmod.ini）
    "PLATFORM_ARTIFACT",  -- 平台运行时（dll/exe/bat/zip）
    "PENDING",            -- 待决策（需 spike）
}

local CATEGORY_SET = {}
for _, c in ipairs(M.CATEGORY) do CATEGORY_SET[c] = true end

-- 证据种类（见 unneeded-evidence/design.md ADR-002）
M.EVIDENCE_KINDS = {
    "code", "strings", "offset_table", "format", "external", "manual",
}

-- 类别 -> 是否进产物（用于一致性校验）
M.IN_PRODUCT_BY_CATEGORY = {
    REQUIRED           = true,
    REQUIRED_CONVERTED = true,
    DESIGNED_FALLBACK  = false,
    DEAD_PARAM         = false,
    LEGACY             = false,
    DEAD_FILE          = false,
    EDITOR_DUMP        = false,
    -- BUILD_INPUT 是混合类：多数不产物（如 cc/ 词典），
    -- 但 kysmod.ini 会被复制到 data/。由 per-rule in_product 覆盖，
    -- 未显式声明时默认 false。
    BUILD_INPUT        = false,
    PLATFORM_ARTIFACT  = false,
    PENDING            = false,
}

-- ============================================================
-- 证据构造器（供 unneeded-evidence 复用/扩展）
-- ============================================================
local function ev(kind, ref, cmd, expect, text)
    -- 证据命令统一在 game/ 目录下执行（见 design.md ADR-002）。
    -- ref 用仓库相对路径（可读），cmd 用 game/ 相对路径（可执行）。
    return { kind = kind, ref = ref, cmd = cmd, expect = expect, text = text }
end

-- 把仓库相对路径（game/xxx）转为 game/ 内可执行的相对路径
local function gameRel(p)
    if not p then return p end
    return (p:gsub("^game/", ""))
end
M.gameRel = gameRel

local EV_IGNORE_DIRS = ev("code",
    "game/tools/mod_build.lua:IGNORE_DIRS",
    "grep -n IGNORE_DIRS tools/mod_build.lua",
    "head",
    "构建器显式忽略 head/item/eft 目录，不复制到产物")

local EV_UPEDIT_DUMP = ev("code",
    "game/tools/mod_build.lua:IGNORE_DIRS",
    "grep -n IGNORE_DIRS tools/mod_build.lua",
    "head",
    "UPedit 编辑器导出的 PNG 转储，引擎读 hdgrp.grp/thing.grp")

local EV_MUSIC_PENDING = ev("external",
    "reference/allmods/kys-pascal/music",
    "head -c 4 $(ls ../reference/allmods/kys-pascal/music/*.mid | head -1)",
    "MThd",
    "MIDI 魔数 MThd != 引擎期望 OggS/RIFF；且 MOD 66 首 vs 引擎 25 槽位不匹配，需 spike 决策")

local EV_LEGACY_NAME = ev("code",
    "game/script/jymain.lua:LoadRecord",
    "grep -c 'name\\.grp' script/jymain.lua engine-love2d/lib_love.lua",
    "0",
    "引擎从不读取 name.grp；人名来自 ranger.grp 的 JY.Person[i][姓名]")

local EV_DEAD_PARAM = ev("code",
    "game/engine-love2d/lib_love.lua:LoadSMap",
    "grep -n 'function LoadSMap' engine-love2d/lib_love.lua",
    "tmpfilename",
    "allsinbk.grp 作为 tmpfilename 形参传入，函数体内 0 引用")

local EV_THING_FALLBACK = ev("code",
    "game/script/jyconst.lua:CC.ThingPicFile",
    "grep -n 'ThingPicFile' script/jyconst.lua",
    "thing",
    "引擎读 data/thing.* 并回退原版；源 MOD 0/20 提供")

local EV_DEAD_FIGHT = ev("format",
    "game/tools/mod_build.lua:FightPicFile",
    "lua -e 'print(string.format(\"fight%03d.grp\",30))'",
    "fight030.grp",
    "%03d 生成不出 fight030_02.grp / fight000..grp；该名永不可达")

local EV_DEAD_NEWIDX = ev("format",
    "reference/allmods/kys-dream/resource/new.idx",
    "lua -e 'print(string.format(\"new%03d.idx\",1))'",
    "new001.idx",
    "引擎无 new.idx 引用；且不存在 new.grp 配对")

local EV_DEAD_WAR1 = ev("code",
    "game/script/jyconst.lua:CC.WarFile",
    "grep -n 'CC.WarFile' script/jyconst.lua",
    "war.sta",
    "引擎只读 war.sta，war1.sta 不可达")

local EV_PLATFORM = ev("external",
    nil,
    "head -c 2 ../reference/allmods/kys-pascal/kys.exe",
    "MZ",
    "Windows PE 可执行/动态库，属 C 引擎运行时，Lua 引擎不使用")

local EV_BUILD_INPUT = ev("code",
    "game/tools/mod_build.lua",
    "grep -n 'kysmod' tools/mod_build.lua",
    "kysmod",
    "kysmod.ini 由构建器复制到 data/（mod_build.lua:879-882）；" ..
    "引擎不读，仅构建期由 mod_ini.lua 解析为 CONFIG/CC 覆盖")

local EV_EDITOR_DRAFT = ev("manual",
    "reference/allmods/kys-awaken/111.txt",
    "ls ../reference/allmods/kys-awaken/111.txt",
    "111.txt",
    "MOD 作者草稿（txt/xlsx），与引擎无关")

local EV_CC_DICT = ev("manual", nil,
    "ls ../reference/allmods/kys-pascal/cc/",
    "STCharacters",
    "OpenCC 简繁词典，属 MOD 启动器配置，非引擎资源")

local EV_LIST_TXT = ev("manual", nil,
    "ls ../reference/allmods/kys-pascal/list/",
    "end.txt",
    "剧情文本（通关/开场），C 引擎直接读取的文本，Lua 引擎未接入")

-- ============================================================
-- list/ 下 4 个 .bin（REQ-LBIN-4）
--
-- 分类依据：
--   effect.bin → war_async.lua:1110/1121 消费 CC.Effect（现由 ModData.LoadEffectTable
--                 从 data/effect.bin 装载）。源数据 sum(effect.bin) == eft.idx 段数
--                 在 14/20 MOD 精确成立 ⇒ 确有引擎语义。
--   match.bin  → 武器/武功/攻击力三元组，对应硬编码的 CC.ExtraOffense。
--   leave.bin  → 可离队人物 id 表；引擎零引用（grep 实测 0 命中），也无硬编码替代。
--   levelup.bin→ 升级经验阀值；引擎零引用，也无硬编码替代。
-- ============================================================
local EV_LIST_EFFECT = ev("code",
    "game/framework/war_async.lua:1110",
    "grep -n 'CC.Effect' framework/war_async.lua",
    "CC.Effect",
    "war_async.lua:1110 framenum 与 :1121-1123 starteft 累加读 CC.Effect；" ..
    "该表由 ModData.LoadEffectTable 从 data/effect.bin 装载（mod_build 白名单搬运）")

local EV_LIST_MATCH = ev("code",
    "game/script/jyconst.lua:453",
    "grep -n 'CC.ExtraOffense' script/jyconst.lua framework/*.lua",
    "ExtraOffense",
    "match.bin 的 (武器id, 武功id, 攻击加成) 三元组即 CC.ExtraOffense 的硬编码内容；" ..
    "构建期搬运到 data/match.bin 作为数据侧权威副本")

local EV_LIST_LEAVE = ev("code",
    "game/framework/war_async.lua",
    "grep -rn 'leave\\.bin\\|leave' script/ framework/ engine-love2d/ | grep -c 'leave\\.bin'",
    "0",
    "引擎零引用 leave.bin（全仓 grep 0 命中）；也没有对应的硬编码替代表 ⇒ C 引擎遗留")

local EV_LIST_LEVELUP = ev("code",
    "game/framework/war_async.lua",
    "grep -rn 'levelup\\.bin\\|levelup' script/ framework/ engine-love2d/ | grep -c 'levelup\\.bin'",
    "0",
    "引擎零引用 levelup.bin（全仓 grep 0 命中）；升级阀值走 JY.Person 经验字段 ⇒ C 引擎遗留")

-- 作者手工备份（Windows 资源管理器「复制」命名）：BookCalamity / Dragon 各一个。
-- 实测：42 字节、md5 e4d31678...，与 Dragon 版 match.bin 完全相同，也与 pascal
-- 的 96 字节 match.bin 不同 ⇒ 是「原始 42 字节模板」的备份，不是引擎输入。
local EV_LIST_MATCH_COPY = ev("external",
    "reference/allmods/kys-BookCalamity/list/match - 复制.bin",
    "md5sum ../reference/allmods/kys-Dragon/list/match.bin '../reference/allmods/kys-BookCalamity/list/match - 复制.bin'",
    "e4d31678461ecf7310ef7ff9cdcaa6fa",
    "作者手工备份文件（Windows「复制」命名）：与 Dragon 的 match.bin 字节相同，" ..
    "是未修改的 42 字节原始模板；引擎不读该文件名（match.bin 才是输入）")

-- ============================================================
-- 精确文件名判据（优先于 BY_KIND）
-- key = "<topdir>/<filename>"（topdir 为 "resource" 等，根级文件用 ""）
-- ============================================================
local EXACT = {
    ["resource/sdx"] = { category="REQUIRED_CONVERTED", needed=true,
        content_type="smap_index", alias_to="smap.idx",
        evidence={ ev("code", "game/tools/mod_build.lua:ALIAS_MAP",
            "grep -n 'sdx' tools/mod_build.lua", "smap.idx",
            "UPedit.ini File2 声明 sdx=场景贴图索引；构建期改名为 smap.idx") } },
    ["resource/smp"] = { category="REQUIRED_CONVERTED", needed=true,
        content_type="smap_payload", alias_to="smap.grp",
        evidence={ ev("code", "game/tools/mod_build.lua:ALIAS_MAP",
            "grep -n 'smp' tools/mod_build.lua", "smap.grp",
            "UPedit.ini File2 声明 smp=场景贴图数据；构建期改名为 smap.grp") } },
    ["resource/wdx"] = { category="REQUIRED_CONVERTED", needed=true,
        content_type="wmap_index", alias_to="wmap.idx",
        evidence={ ev("code", "game/tools/mod_build.lua:ALIAS_MAP",
            "grep -n 'wdx' tools/mod_build.lua", "wmap.idx",
            "UPedit.ini File3 声明 wdx=战斗贴图索引；构建期改名为 wmap.idx") } },
    ["resource/wmp"] = { category="REQUIRED_CONVERTED", needed=true,
        content_type="wmap_payload", alias_to="wmap.grp",
        evidence={ ev("code", "game/tools/mod_build.lua:ALIAS_MAP",
            "grep -n 'wmp' tools/mod_build.lua", "wmap.grp",
            "UPedit.ini File3 声明 wmp=战斗贴图数据；构建期改名为 wmap.grp") } },
    -- 死文件
    ["resource/war1.sta"] = { category="DEAD_FILE", needed=false,
        content_type="war_table_unreachable", evidence={ EV_DEAD_WAR1 } },
    ["resource/new.idx"] = { category="DEAD_FILE", needed=false,
        content_type="orphan_index", evidence={ EV_DEAD_NEWIDX } },
    ["resource/fight23.idx"] = { category="DEAD_FILE", needed=false,
        content_type="nonstandard_index", evidence={ EV_DEAD_FIGHT } },
    -- C 引擎运行时（少数 MOD 放在 resource/）
    ["resource/kys.exe"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="pe_executable", evidence={ EV_PLATFORM } },
    -- 遗留资源
    ["resource/name.idx"] = { category="LEGACY", needed=false,
        content_type="legacy_name_index", evidence={ EV_LEGACY_NAME } },
    ["resource/name.grp"] = { category="LEGACY", needed=false,
        content_type="legacy_name_payload", evidence={ EV_LEGACY_NAME } },
    -- list/ 下 4 个 .bin（REQ-LBIN-4）：不能按 (topdir, ext) 一刀切，
    -- 因为 effect/match 有引擎消费方、leave/levelup 没有 ⇒ 必须逐文件分类。
    ["list/effect.bin"] = { category="REQUIRED", needed=true, in_product=true,
        content_type="effect_frame_table", evidence={ EV_LIST_EFFECT } },
    ["list/match.bin"] = { category="REQUIRED", needed=true, in_product=true,
        content_type="extra_offense_table", evidence={ EV_LIST_MATCH } },
    ["list/leave.bin"] = { category="LEGACY", needed=false,
        content_type="leavable_person_ids", evidence={ EV_LIST_LEAVE } },
    ["list/levelup.bin"] = { category="LEGACY", needed=false,
        content_type="levelup_exp_thresholds", evidence={ EV_LIST_LEVELUP } },
    ["list/match - 复制.bin"] = { category="EDITOR_DUMP", needed=false,
        content_type="author_backup", evidence={ EV_LIST_MATCH_COPY } },
    -- 作者草稿
    ["111.txt"]  = { category="EDITOR_DUMP", needed=false,
        content_type="author_draft", evidence={ EV_EDITOR_DRAFT } },
    ["111.xlsx"] = { category="EDITOR_DUMP", needed=false,
        content_type="author_draft", evidence={ EV_EDITOR_DRAFT } },
    -- 平台运行时
    ["SDL3.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["SDL3_mixer.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["SDL3_ttf.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["simplecc.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["mpg123.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["libfluidsynth-3.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["lua52.dll"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="shared_library", evidence={ EV_PLATFORM } },
    ["kys.exe"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="pe_executable", evidence={ EV_PLATFORM } },
    -- 构建输入
    -- kysmod.ini：构建器复制到 data/（mod_build.lua:879-882），引擎不读
    ["kysmod.ini"] = { category="BUILD_INPUT", needed=false, in_product=true,
        content_type="ini_config", evidence={ EV_BUILD_INPUT } },
    -- 构建输入：作者的手改脚本，构建器不使用（事件从 kdef.grp 提取）
    ["script/1.lua"] = { category="LEGACY", needed=false,
        content_type="author_script",
        evidence={ ev("code", "game/tools/mod_build.lua:collectDataFiles",
            "grep -n 'walk(modDir' tools/mod_build.lua", "resource",
            "构建器只遍历 resource/fight/save/sound；script/ 事件由 kdef.grp 提取生成") } },
    -- 构建输入：UTF-8 对话文本（C 引擎/工具产物，引擎读 talk.grp）
    ["resource/talkutf8.txt"] = { category="BUILD_INPUT", needed=false,
        content_type="text_asset",
        evidence={ ev("code", "game/script/jymain.lua:ReadTalk",
            "grep -n 'TalkGrpFile' script/jyconst.lua", "oldtalk.grp",
            "引擎读 script/oldtalk.grp；talkutf8.txt 是作者导出的中间文本") } },
    ["resource/修改档说明.txt"] = { category="LEGACY", needed=false,
        content_type="readme_text",
        evidence={ ev("manual",
            "reference/allmods/kys-SweeOan/resource/修改档说明.txt",
            "ls ../reference/allmods/kys-SweeOan/resource/*.txt",
            "修改档说明",
            "作者说明文档，与引擎无关") } },
    ["resource/consoleimz.exe"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="pe_executable", evidence={ EV_PLATFORM } },
    ["resource/for_fight.bat"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="batch_script", evidence={ EV_PLATFORM } },
    ["resource/转换.bat"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="batch_script", evidence={ EV_PLATFORM } },
    -- 用户存档副本（非槽位命名）
    ["save/save.zip"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="archive", evidence={ EV_PLATFORM } },
}

-- ============================================================
-- (topdir, ext) 判据表（EXACT 未命中时使用）
-- ============================================================
local BY_KIND = {
    -- resource/ 二进制资源（引擎必需，原名进产物）
    ["resource|.idx"] = { category="REQUIRED", needed=true,  content_type="resource_index" },
    ["resource|.grp"] = { category="REQUIRED", needed=true,  content_type="resource_payload" },
    ["resource|.002"] = { category="REQUIRED", needed=true,  content_type="smap_grid" },
    ["resource|.col"] = { category="REQUIRED", needed=true,  content_type="palette" },
    ["resource|.sta"] = { category="REQUIRED", needed=true,  content_type="war_table" },
    ["resource|.png"] = { category="REQUIRED", needed=true,  content_type="png_image" },
    ["resource|.ttf"] = { category="REQUIRED", needed=true,  content_type="font" },
    ["resource|.bat"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="batch_script", evidence={ EV_PLATFORM } },
    ["resource|.exe"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="pe_executable", evidence={ EV_PLATFORM } },
    ["resource|.txt"] = { category="BUILD_INPUT", needed=false,
        content_type="text_asset", evidence={ EV_CC_DICT } },

    -- fight/ 战斗贴图
    ["fight|.idx"] = { category="REQUIRED", needed=true, content_type="fight_sprite_index" },
    ["fight|.grp"] = { category="REQUIRED", needed=true, content_type="fight_sprite_rle" },

    -- sound/ 音效
    ["sound|.wav"] = { category="REQUIRED", needed=true, content_type="wav_pcm" },

    -- save/ 存档模板与数据
    ["save|.idx"] = { category="REQUIRED", needed=true, content_type="save_index" },
    ["save|.grp"] = { category="REQUIRED", needed=true, content_type="save_payload" },
    ["save|.zip"] = { category="PLATFORM_ARTIFACT", needed=false,
        content_type="archive", evidence={ EV_PLATFORM } },

    -- script/ 事件脚本
    ["script|.lua"] = { category="REQUIRED", needed=true, content_type="event_script" },

    -- list/ C 引擎文本列表（.bin 走 EXACT，见上）
    ["list|.txt"] = { category="LEGACY", needed=false,
        content_type="story_text", evidence={ EV_LIST_TXT } },

    -- head/ item/ eft/ 编辑器导出
    ["head|.png"] = { category="EDITOR_DUMP", needed=false,
        content_type="png_image", evidence={ EV_UPEDIT_DUMP } },
    ["item|.png"] = { category="EDITOR_DUMP", needed=false,
        content_type="png_image", evidence={ EV_UPEDIT_DUMP } },
    ["eft|.png"] = { category="EDITOR_DUMP", needed=false,
        content_type="png_image", evidence={ EV_UPEDIT_DUMP } },
    ["eft|.idx"] = { category="EDITOR_DUMP", needed=false,
        content_type="editor_index", evidence={ EV_UPEDIT_DUMP } },

    -- cc/ OpenCC 词典
    ["cc|.txt"] = { category="BUILD_INPUT", needed=false,
        content_type="openc_cc_dict", evidence={ EV_CC_DICT } },

    -- music/ 待决策
    ["music|.mid"] = { category="PENDING", needed=nil,
        content_type="midi", evidence={ EV_MUSIC_PENDING } },
    ["music|.mp3"] = { category="PENDING", needed=nil,
        content_type="mp3", evidence={ EV_MUSIC_PENDING } },
    ["music|.sf2"] = { category="PENDING", needed=nil,
        content_type="soundfont", evidence={ EV_MUSIC_PENDING } },
}

-- 目录级：DESIGNED_FALLBACK / DEAD_PARAM（源 MOD 不提供的资源）
-- 这些不产生记录（源中无文件），但作为"参考"导出，供 unneeded-evidence 引用。
M.ABSENT_EXPECTED = {
    { path="resource/thing.idx", category="DESIGNED_FALLBACK", needed=true,
      note="引擎读 data/thing.* 并回退原版；源 MOD 0/20 提供", evidence={ EV_THING_FALLBACK } },
    { path="resource/thing.grp", category="DESIGNED_FALLBACK", needed=true,
      note="同上", evidence={ EV_THING_FALLBACK } },
    { path="resource/allsinbk.grp", category="DEAD_PARAM", needed=false,
      note="LoadSMap 形参 tmpfilename 从未被引用；源 MOD 0/20 提供", evidence={ EV_DEAD_PARAM } },
}

-- ============================================================
-- 遍历
-- ============================================================
local function splitPath(rel)
    -- 返回 topdir, filename
    -- 根级文件 topdir = ""
    local d = rel:match("^(.*)/[^/]+$")
    local f = rel:match("([^/]+)$")
    return d or "", f
end

function M.walkMods(modFilter)
    local out = {}
    local mods = {}
    -- 枚举 reference/allmods/kys-* 目录（跨平台，不依赖 find/ls）
    for _, name in ipairs(Fs.listDirectory(M.MODS_SRC)) do
        if name:match("^kys%-.+") and Fs.directoryExists(M.MODS_SRC .. "/" .. name) then
            local slug = name:gsub("^kys%-", "")
            if not modFilter or slug == modFilter then
                mods[#mods + 1] = { slug = slug, dir = M.MODS_SRC .. "/" .. name }
            end
        end
    end
    table.sort(mods, function(a, b) return a.slug < b.slug end)

    for _, m in ipairs(mods) do
        -- 递归列举该 MOD 的全部文件（相对路径已排序，保证输出稳定）
        for _, rel in ipairs(Fs.walkFiles(m.dir)) do
            local full = m.dir .. "/" .. rel
            local size = 0
            local fh = io.open(full, "rb")
            if fh then size = fh:seek("end") or 0; fh:close() end
            out[#out + 1] = { mod = m.slug, path = rel, size = size, src = full }
        end
    end
    return out
end

-- ============================================================
-- 归类（REQ-INV-2：未命中返回 nil，不兜底）
-- ============================================================
function M.classify(rec)
    local topdir, filename = splitPath(rec.path)
    local ext = filename:match("(%.[^%.]*)$") or ""
    -- 根级文件：EXACT key 用纯文件名
    local exactKey = (topdir == "") and filename or (topdir .. "/" .. filename)
    if EXACT[exactKey] then
        return EXACT[exactKey]
    end
    local kindKey = topdir .. "|" .. ext
    if BY_KIND[kindKey] then
        return BY_KIND[kindKey]
    end
    return nil
end

-- ============================================================
-- in_product 判定（含别名转换，REQ-INV-5）
-- ============================================================
local function fileExists(p)
    -- 走 fs_compat：MOD 源里有中文文件名（如 "ranger - 副本.idx"），
    -- Windows 上 io.open 打不开这类 UTF-8 路径。
    return Fs.fileExists(p)
end

-- save/ 下的模板（ranger.*/alldef.*/allsin.*/allsinbk.*）→ data/；
-- 用户存档（rN/dN/sN.grp|idx）→ save/（见 mod_build.lua:SAVE_TEMPLATE/isSaveSlotFile）。
local SAVE_TEMPLATE_NAMES = {
    ["ranger.idx"] = true, ["ranger.grp"] = true,
    ["alldef.grp"] = true, ["alldef.idx"] = true,
    ["allsin.grp"] = true, ["allsin.idx"] = true,
    ["allsinbk.grp"] = true,
}

local function isSaveSlot(name)
    local lower = name:lower()
    local base, ext = lower:match("^([rds]%d+)%.([a-z]+)$")
    if not base then return false end
    return ext == "grp" or ext == "idx"
end

-- 源相对路径 -> 产物可能路径列表（含别名目标）
function M.productCandidates(mod, path, rule)
    local topdir, filename = splitPath(path)
    local cands = {}
    if topdir == "resource" then
        local target = rule and rule.alias_to
        if target then
            cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. target
        else
            cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename
        end
    elseif topdir == "fight" then
        cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename
    elseif topdir == "save" then
        -- 模板 → data/；用户存档 → save/
        if SAVE_TEMPLATE_NAMES[filename:lower()] or not isSaveSlot(filename) then
            cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename
        else
            cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/save/" .. filename
        end
    elseif topdir == "sound" then
        cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/sound/" .. filename
    elseif topdir == "script" then
        cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/script/" .. filename
    elseif topdir == "list" then
        -- REQ-LBIN-1：只有白名单里的 effect.bin / match.bin 被拍平到 data/
        cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename
    elseif topdir == "" then
        -- 根目录文件：kysmod.ini 被复制到 data/
        cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename
    end
    return cands
end

function M.checkInProduct(rec)
    local rule = M.classify(rec)
    if not rule then return false end
    -- per-rule 覆盖优先（BUILD_INPUT 混合类需要）
    if rule.in_product == false then return false end
    if rule.in_product ~= true and not M.IN_PRODUCT_BY_CATEGORY[rule.category] then
        return false
    end
    for _, p in ipairs(M.productCandidates(rec.mod, rec.path, rule)) do
        if fileExists(p) then return true end
    end
    return false
end

-- ============================================================
-- 主审计（REQ-INV-1）
-- ============================================================
function M.auditAll(modFilter)
    local files = M.walkMods(modFilter)
    local records, unclassified = {}, {}
    local seenUnclassified = {}

    for _, f in ipairs(files) do
        local rule = M.classify(f)
        if not rule then
            local topdir, filename = splitPath(f.path)
            local ext = filename:match("(%.[^%.]*)$") or ""
            local key = topdir .. "|" .. ext
            if not seenUnclassified[key] then
                seenUnclassified[key] = true
                unclassified[#unclassified + 1] = { topdir = topdir, ext = ext, example = f.path }
            end
        else
            local topdir, filename = splitPath(f.path)
            local ext = filename:match("(%.[^%.]*)$") or ""
            records[#records + 1] = {
                mod = f.mod, path = f.path, size = f.size,
                topdir = topdir, ext = ext,
                needed = rule.needed,
                category = rule.category,
                content_type = rule.content_type,
                alias_to = rule.alias_to,
                in_product = M.checkInProduct(f),
                evidence = rule.evidence or {},
            }
        end
    end
    return records, unclassified, #files
end

-- ============================================================
-- 统计
-- ============================================================
function M.summarize(records)
    local byCat, byContent, inProduct = {}, {}, 0
    for _, r in ipairs(records) do
        byCat[r.category] = (byCat[r.category] or 0) + 1
        byContent[r.content_type] = (byContent[r.content_type] or 0) + 1
        if r.in_product then inProduct = inProduct + 1 end
    end
    return { total = #records, by_category = byCat,
             by_content_type = byContent, in_product = inProduct,
             not_in_product = #records - inProduct }
end

-- ============================================================
-- 最小 JSON writer（无外部依赖）
-- ============================================================
local function jsonEscape(s)
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
         :gsub('\r', '\\r'):gsub('\t', '\\t')
    return s
end

local function jsonVal(v, indent)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then return tostring(v) end
    if t == "string" then return '"' .. jsonEscape(v) .. '"' end
    if t == "table" then
        if #v > 0 then
            local parts = {}
            for _, x in ipairs(v) do parts[#parts + 1] = jsonVal(x, indent) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = k end
            table.sort(keys)
            local parts = {}
            for _, k in ipairs(keys) do
                parts[#parts + 1] = '"' .. jsonEscape(tostring(k)) .. '":' .. jsonVal(v[k], indent)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

M.jsonVal = jsonVal

-- ============================================================
-- Markdown 报告（REQ-INV-6）
-- ============================================================
function M.renderMarkdown(records, sum)
    local L = {}
    L[#L + 1] = "# MOD 资源穷举审计报告"
    L[#L + 1] = ""
    L[#L + 1] = "> 本文件由 `game/tools/mod_audit.lua` 生成，请勿手改。"
    L[#L + 1] = ""
    L[#L + 1] = string.format("源文件总数：**%d**　进产物：**%d**　未进产物：**%d**",
        sum.total, sum.in_product, sum.not_in_product)
    L[#L + 1] = ""
    L[#L + 1] = "## 汇总"
    L[#L + 1] = ""
    L[#L + 1] = "| 类别 | 文件数 | 占比 | 是否进产物 |"
    L[#L + 1] = "|------|-------:|-----:|-----------|"
    for _, cat in ipairs(M.CATEGORY) do
        local n = sum.by_category[cat] or 0
        local pct = sum.total > 0 and (n * 100 / sum.total) or 0
        local ip = M.IN_PRODUCT_BY_CATEGORY[cat]
        local ipStr = (ip == true) and "是" or ((ip == false) and "否" or "待定")
        L[#L + 1] = string.format("| `%s` | %d | %.1f%% | %s |", cat, n, pct, ipStr)
    end
    L[#L + 1] = ""

    for _, cat in ipairs(M.CATEGORY) do
        local group = {}
        for _, r in ipairs(records) do
            if r.category == cat then group[#group + 1] = r end
        end
        if #group > 0 then
            L[#L + 1] = string.format("## `%s`（%d 个）", cat, #group)
            L[#L + 1] = ""
            L[#L + 1] = "| 文件（示例） | MOD 数 | 进产物 | 证据 |"
            L[#L + 1] = "|------|-------:|-------|------|"
            -- 按 (topdir, ext) 聚合
            local agg, order = {}, {}
            for _, r in ipairs(group) do
                local key = r.topdir .. "/" .. (r.ext == "" and "(无扩展名)" or r.ext)
                if not agg[key] then agg[key] = { n = 0, mods = {}, ip = r.in_product, ev = r.evidence }
                    order[#order + 1] = key end
                agg[key].n = agg[key].n + 1
                agg[key].mods[r.mod] = true
            end
            table.sort(order)
            for _, key in ipairs(order) do
                local a = agg[key]
                local nm = 0; for _ in pairs(a.mods) do nm = nm + 1 end
                local evStr = "-"
                if a.ev and a.ev[1] then
                    evStr = string.format("`%s`: %s", a.ev[1].kind, a.ev[1].text or a.ev[1].ref or "")
                end
                L[#L + 1] = string.format("| `%s` | %d | %s | %s |", key, nm,
                    a.ip and "是" or "否", evStr)
            end
            L[#L + 1] = ""
        end
    end
    return table.concat(L, "\n") .. "\n"
end

-- ============================================================
-- 证据质量检查（REQ-EVID-3，供 unneeded-evidence 复用）
-- ============================================================
function M.checkEvidenceQuality(e)
    if type(e) ~= "table" then return false, "not a table" end
    local kinds = {}
    for _, k in ipairs(M.EVIDENCE_KINDS) do kinds[k] = true end
    if not kinds[e.kind] then return false, "bad kind: " .. tostring(e.kind) end
    if e.kind == "code" and not e.cmd then return false, "code evidence needs cmd" end
    if e.kind == "manual" and not e.cmd then return false, "manual evidence needs cmd" end
    if e.text and #e.text < 10 then return false, "text too short" end
    if not e.text and not e.ref and not e.cmd then return false, "no text/ref/cmd" end
    return true
end

-- ============================================================
-- 证据执行（REQ-EVID-2）：跑 cmd，断言输出含 expect
--
-- 证据里的 cmd 刻意保留 POSIX 形式（grep/head/ls/md5sum），因为它们是写进
-- 审计文档给人复现的。执行层负责跨平台：
--   * POSIX  → /bin/sh
--   * Windows→ 找一个 bash（msys2 / Git for Windows / WSL）来跑同一条命令
-- 找不到 bash 时返回「环境不支持」，调用方应跳过而不是判失败。
-- ============================================================
function M.runEvidence(e, timeoutSec)
    if type(e) ~= "table" or not e.cmd then
        return false, "no cmd"
    end
    local ok, quality = M.checkEvidenceQuality(e)
    if not ok then return false, "bad evidence: " .. tostring(quality) end

    -- `lua -e ...` 在 Windows 上通常不在 PATH 里，替换成当前解释器
    local cmd = e.cmd
    local interp = Fs.luaInterpreter()
    if interp then
        cmd = cmd:gsub("%f[%w]lua%s+%-e", Fs.isWindows
            and (Fs.quoteWin(interp) .. " -e")
            or (Fs.quotePosix(interp) .. " -e"))
    end

    local ran, out, reason = Fs.runShell(cmd, { timeout = timeoutSec or 20 })
    if not ran then
        return false, "shell-unavailable: " .. tostring(reason)
    end

    if e.expect and #e.expect > 0 then
        if not out:find(e.expect, 1, true) then
            return false, string.format("output missing %q\n---\n%s", e.expect, out)
        end
    end
    return true, out
end

-- 全部证据可执行性检查（REQ-EVID-2）
-- 返回 checked, failed, details
function M.verifyAllEvidence(records, opts)
    opts = opts or {}
    local checked, failed = 0, 0
    local details = {}
    local seen = {}
    for _, r in ipairs(records) do
        for _, e in ipairs(r.evidence) do
            -- 相同 cmd 只跑一次
            local key = tostring(e.cmd)
            if not seen[key] then
                seen[key] = true
                if e.cmd and not opts.skip_run then
                    checked = checked + 1
                    local ok, out = M.runEvidence(e, opts.timeout)
                    if not ok then
                        failed = failed + 1
                        details[#details + 1] = { cmd = e.cmd, err = out, ref = e.ref }
                    end
                end
            end
        end
    end
    return checked, failed, details
end

-- ============================================================
-- 权威文档 MOD_RESOURCE_AUDIT.md（REQ-EVID-4）
-- 每行含 <!-- rec:<mod>:<path> --> 锚点，便于机器比对
-- ============================================================
function M.renderResourceAudit(records, sum, unclassified)
    local L = {}
    local function w(s) L[#L + 1] = s or "" end

    w("# MOD 资源审计（穷举）")
    w("")
    w("> **自动生成**：本文件由 `game/tools/mod_audit.lua` 生成，请勿手改。")
    w("> 重新生成：`cd game && lua tools/mod_audit.lua --all`")
    w("")
    w("本文件是「每个源文件都被检查到并归类」的权威清单。")
    w("与 `DATA_FILES.md` §8 的关系：§8 是按格式族的**摘要**，本文件是**逐文件穷举**。")
    w("")
    w("## 汇总")
    w("")
    w(string.format("源文件总数：**%d**", sum.total))
    w("")
    w("| 类别 | 文件数 | 进产物 | 含义 |")
    w("|------|-------:|-------|------|")
    local MEAN = {
        REQUIRED           = "引擎必需，原名进产物",
        REQUIRED_CONVERTED = "引擎必需，构建期转换后进产物",
        DESIGNED_FALLBACK  = "引擎可选，源不提供是预期（回退原版）",
        DEAD_PARAM         = "引擎形参从未引用",
        LEGACY             = "C 引擎/编辑器遗留，Lua 引擎不读",
        DEAD_FILE          = "引擎命名规则无法生成",
        EDITOR_DUMP        = "编辑器导出副产物",
        BUILD_INPUT        = "构建器消费但引擎不读",
        PLATFORM_ARTIFACT  = "平台运行时（dll/exe/bat/zip）",
        PENDING            = "待决策（需 spike）",
    }
    for _, cat in ipairs(M.CATEGORY) do
        local n = sum.by_category[cat] or 0
        if n > 0 then
            w(string.format("| `%s` | %d | %s | %s |", cat, n,
                M.IN_PRODUCT_BY_CATEGORY[cat] and "是" or "否",
                MEAN[cat] or ""))
        end
    end
    w("")
    w(string.format("进产物：**%d**　未进产物：**%d**",
        sum.in_product, sum.not_in_product))
    w("")

    -- 未归类的（应为 0）
    w("## 未归类（应为 0）")
    w("")
    if #unclassified == 0 then
        w("无。所有 `(topdir, ext)` 组合均有判据。")
    else
        for _, u in ipairs(unclassified) do
            w(string.format("- `%s|%s`（例：`%s`）",
                u.topdir == "" and "(root)" or u.topdir,
                u.ext == "" and "(无扩展名)" or u.ext, u.example))
        end
    end
    w("")

    -- 逐类别逐文件
    for _, cat in ipairs(M.CATEGORY) do
        local group = {}
        for _, r in ipairs(records) do
            if r.category == cat then group[#group + 1] = r end
        end
        if #group > 0 then
            w(string.format("## `%s`（%d 个）", cat, #group))
            w("")
            w("| 文件 | 内容类型 | 进产物 | 证据 |")
            w("|------|---------|-------|------|")
            table.sort(group, function(a, b)
                if a.mod ~= b.mod then return a.mod < b.mod end
                return a.path < b.path
            end)
            for _, r in ipairs(group) do
                local evs = {}
                for _, e in ipairs(r.evidence) do
                    evs[#evs + 1] = string.format("`%s`:%s", e.kind,
                        e.text and e.text:gsub("|", "\\|") or (e.ref or ""))
                end
                local evStr = #evs > 0 and table.concat(evs, "<br>") or "-"
                w(string.format(
                    "| `%s/%s` <!-- rec:%s:%s --> | `%s` | %s | %s |",
                    r.mod, r.path, r.mod, r.path,
                    r.content_type or "?",
                    r.in_product and "是" or "否",
                    evStr))
            end
            w("")
        end
    end

    -- 如何复现
    w("## 如何复现")
    w("")
    w("```bash")
    w("cd game")
    w("lua tools/mod_audit.lua --all          # 重新生成 audit.json / audit.md")
    w("lua tools/mod_audit.lua --evidence     # 执行全部证据并校验")
    w("lua tests/test_runner.lua mod_audit    # 穷举归类测试")
    w("lua tools/format_spec.lua --all        # 字节级覆盖（字段级）")
    w("```")
    w("")
    w("`game/mods/_audit/audit.json` 是机器可读版本（含每条记录的完整字段）。")
    w("")
    return table.concat(L, "\n") .. "\n"
end

-- ============================================================
-- CLI
-- ============================================================
local function writeFile(path, content)
    Fs.makeDirectory(path:match("^(.*)[/\\][^/\\]+$") or ".")
    local f = assert(io.open(path, "wb"))
    f:write(content)
    f:close()
end

local function main(args)
    local modFilter = nil
    local doEvidence = false
    for i, a in ipairs(args) do
        if a == "--mod" then modFilter = args[i + 1]
        elseif a == "--evidence" then doEvidence = true end
    end

    local records, unclassified, total = M.auditAll(modFilter)

    if #unclassified > 0 then
        io.stderr:write("未归类文件组合（REQ-INV-2 失败）：\n")
        for _, u in ipairs(unclassified) do
            io.stderr:write(string.format("  topdir=%s ext=%s 例=%s\n",
                u.topdir, u.ext == "" and "(无)" or u.ext, u.example))
        end
        os.exit(1)
    end

    local sum = M.summarize(records)

    -- 完整性自检
    if sum.total ~= total then
        io.stderr:write(string.format("记录数 %d != 遍历总数 %d\n", sum.total, total))
        os.exit(1)
    end

    -- 证据质量自检
    local badEv = 0
    for _, r in ipairs(records) do
        if r.needed == false then
            if #r.evidence == 0 then badEv = badEv + 1 end
            for _, e in ipairs(r.evidence) do
                local ok = M.checkEvidenceQuality(e)
                if not ok then badEv = badEv + 1 end
            end
        end
    end

    Fs.makeDirectory(M.AUDIT_DIR)
    local jsonPayload = jsonVal({
        total = sum.total,
        in_product = sum.in_product,
        not_in_product = sum.not_in_product,
        by_category = sum.by_category,
        records = records,
    }, 0)
    if modFilter then
        -- 单 MOD 审计（缺陷 #5 修复）：只写每 MOD 文件，绝不触碰全局权威报告。
        -- 此前 --mod <slug> 也会覆盖 audit.json / audit.md / MOD_RESOURCE_AUDIT.md，
        -- 用单 MOD 内容（如 total=425）污染全量报告（total=11220），
        -- 导致全量审计断言（锚点数/total/REQUIRED/PENDING）整组失败。
        writeFile(string.format("%s/%s.json", M.AUDIT_DIR, modFilter), jsonPayload)
        writeFile(string.format("%s/%s.md", M.AUDIT_DIR, modFilter),
            M.renderMarkdown(records, sum))
    else
        writeFile(M.AUDIT_DIR .. "/audit.json", jsonPayload)
        writeFile(M.AUDIT_DIR .. "/audit.md", M.renderMarkdown(records, sum))
        writeFile(M.REPO_ROOT .. "/MOD_RESOURCE_AUDIT.md",
            M.renderResourceAudit(records, sum, unclassified))
    end

    print(string.format("total=%d in_product=%d not_in_product=%d unclassified=%d bad_evidence=%d",
        sum.total, sum.in_product, sum.not_in_product, #unclassified, badEv))
    for _, cat in ipairs(M.CATEGORY) do
        local n = sum.by_category[cat] or 0
        if n > 0 then print(string.format("  %-20s %d", cat, n)) end
    end

    if badEv > 0 then os.exit(1) end

    if doEvidence then
        local checked, failed, details = M.verifyAllEvidence(records)
        print(string.format("evidence: checked=%d failed=%d", checked, failed))
        for _, d in ipairs(details) do
            print(string.format("  [FAIL] %s\n         %s", d.cmd, d.err))
        end
        if failed > 0 then os.exit(1) end
    end

    os.exit(0)
end

if ... == nil or arg == nil or (arg and arg[0] and arg[0]:match("mod_audit")) then
    -- 作为脚本运行
    if arg then main(arg) end
end

return M
