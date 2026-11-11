---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice0b — MOD 兼容地基补漏（资源类型）

## Change Assignments

### Change: allmods-slice0b-smap-rename

- **Repository**: this repo
- **Scope**: infra（构建工具 + 测试）
- **Responsibility**: 构建期资源别名转换（Contract A）。`tools/mod_build.lua` 把 MOD 的 `sdx`→`smap.idx`、`smp`→`smap.grp`、`wdx`→`wmap.idx`、`wmp`→`wmap.grp`；`diff.md` 增加「改名对」小节；单元测试断言别名映射与产物名。依据 `UPedit.ini` 的 `File2/File3/SMAPIDX/SMAPGRP` 权威映射。
- **Depends On**: none
- **Status**: [x] Done

### Change: allmods-slice0b-sound-fallback

- **Repository**: this repo
- **Scope**: fullstack（构建工具 + framework + 测试）
- **Responsibility**: MOD 音频复制与回退链（Contract B）。构建期 `walk(modDir.."/sound")` → `mods/<mod>/sound/`；`ModData.RewriteConstants` 新增 `CC.MIDIFile`/`CC.ATKFile`/`CC.EFile` 三个 `%02d` 格式串常量的 MOD 前缀改写（仿现有 `FightPicFile` 分支）；单元测试断言 MOD 独有音效解析到 MOD 目录、缺失编号回退原版。
- **Depends On**: allmods-slice0b-smap-rename（共用 `mod_build.lua` 的写出循环，避免冲突）
- **Status**: [x] Done

### Change: allmods-slice0b-resource-classify

- **Repository**: this repo
- **Scope**: infra（文档 + 测试）
- **Responsibility**: 资源分类固化（Contract C）。把审计报告的判定写成可回归测试与权威文档：`thing.*` 设计性回退、`allsinbk.grp` 死参数、`name.grp` 遗留、`fightNNN..`/`fightNNN_02`/`new.idx`/`fight23.idx`/`war1.sta` 死文件、`head/`/`item/`/`eft/`/`cc/` 编辑器副产物、`music/*.mid` 待决策。更新 `resource-type-audit.md` 状态为「已分类」，并勘误 `TODO.md`。
- **Depends On**: allmods-slice0b-smap-rename, allmods-slice0b-sound-fallback（分类结论需引用两者的实现结果）
- **Status**: [x] Done

## Shared Contract Stubs

### Contract A: 构建期资源别名映射（allmods-slice0b-smap-rename 拥有）

```
-- 权威来源：reference/allmods/UPedit/UPedit.ini [File] 段
--   File2=resource\sdx,resource\smp,场景贴图   （= smap）
--   File3=resource\wdx,resource\wmp,战斗贴图   （= wmap）
--   SMAPIDX=resource\sdx   SMAPGRP=resource\smp

# 构建期文件名映射表（tools/mod_build.lua 内部常量）
ALIAS_MAP = {
  ["sdx"] = "smap.idx",
  ["smp"] = "smap.grp",
  ["wdx"] = "wmap.idx",
  ["wmp"] = "wmap.grp",
}

# 应用点：flattenResources() 计算 destRel 时
#   destRel = ALIAS_MAP[destRel] or destRel
# 约束：
#   * 仅对 resource/ 来源（kind="data"）生效；fight/、save/ 不参与别名
#   * 映射后若目标名已存在（理论上不可能，已验证 20/20 MOD 无 smap/sdx 并存），
#     报错退出（非静默覆盖）
#   * 不改写文件内容，只改文件名（内容逐字节保留）

# diff.md 新增小节（buildDiff 拥有）
## 资源别名转换
- sdx → smap.idx
- smp → smap.grp
- wdx → wmap.idx
- wmp → wmap.grp
（并对「基准独有」列表做改名对抵消：smap.idx/smap.grp/wmap.idx/wmap.grp 不再因别名而报缺失）
```

### Contract B: MOD 音频回退链（allmods-slice0b-sound-fallback 拥有）

```
# 构建期产物布局（tools/mod_build.lua 拥有）
game/mods/<mod>/
  ├─ data/            （现有）
  ├─ script/          （现有）
  ├─ sound/           （本 change 新增：源 MOD sound/ 逐字节复制，文件名小写归一）
  └─ diff.md

# 运行时路径常量（jyconst.lua 定义，ModData 改写）
CC.MIDIFile = CONFIG.SoundPath .. "game%02d.ogg"
CC.ATKFile  = CONFIG.SoundPath .. "atk%02d.wav"
CC.EFile    = CONFIG.SoundPath .. "e%02d.wav"

# ModData.RewriteConstants 新增改写（仿现有 FightPicFile 前缀改写分支）
-- 这三个是 printf 格式串（含 %02d），不能做「字面路径 exists 检查」，
-- 只能做前缀目录改写：
--   "sound/<...>"  →  "mods/<slug>/sound/<...>"   （若 mods/<slug>/sound/ 目录存在）
-- 缺失的文件由 love.audio.newSource 的 pcall 兜底（与现状一致，不新增回退逻辑）
# 硬约束：
#   * 未激活 MOD → 常量保持 "sound/..."（零回归）
#   * mods/<slug>/sound/ 不存在 → 保持 "sound/..."（回退原版）
#   * MOD 内缺失某编号 wav → love 加载失败 pcall 静默（不崩溃），
#     不额外做 per-file 回退（love.audio.newSource 只接受单路径）
```

### Contract C: 资源分类判定表（allmods-slice0b-resource-classify 拥有）

```
# 权威分类（resource-type-audit.md 的最终状态）

REQUIRED    = { smap.*, wmap.*, sound/*.wav }          -- 本 slice 移植（A/D）
DESIGNED_FALLBACK = { thing.idx, thing.grp }           -- 源 MOD 无 → 回退原版是预期（B）
DEAD_PARAM  = { allsinbk.grp }                         -- LoadSMap tmpfilename 未被引用（C）
LEGACY      = { name.idx, name.grp }                   -- C 引擎/编辑器遗留，引擎不读
DEAD_FILE   = { "fight*..grp", "fight*_02.grp",        -- 3位格式不可达
                "new.idx", "fight23.idx", "war1.sta" }
EDITOR_DUMP = { head/, item/, eft/, cc/ }              -- IGNORE_DIRS 正确忽略
PENDING     = { music/*.mid }                          -- 需 spike 决定（Out of Scope）

# 可回归断言（tests/unit/）
-- 1. 激活任一 MOD 后，CC.ThingPicFile 指向 mods/<mod>/data/thing.* 仅当该文件存在，
--    否则必须回退 data/thing.*（设计性回退，不是 bug）
-- 2. game/ 全仓 grep 无 "allsinbk" 的读取调用（除常量定义外）→ 证明死参数
-- 3. IGNORE_DIRS 覆盖 head/item/eft；构建产物不含这些目录
-- 4. 构建产物不含 fightNNN..grp / fightNNN_02.grp / new.idx / war1.sta（如源 MOD 有）
--    注：Slice 0 的"忠实拷贝"策略会复制这些死文件；本 change 决定是否过滤，
--    若过滤需同步更新 diff.md 语义（默认策略：保留拷贝但在 diff.md 标注为「死文件」）
```

## Integration Test Plan

1. **零回归**：无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿。
2. **别名转换**：`lua tools/mod_build.lua kys-mingdong` → `mods/mingdong/data/` 含 `smap.idx`(4635 项)/`smap.grp`/`wmap.idx`(3850 项)/`wmap.grp`，无 `sdx/smp/wdx/wmp`。
3. **全量别名**：`lua tools/mod_build.lua --all` → 20 MOD 全部产出 `smap.*`/`wmap.*`，0 残留。
4. **运行时证明**：激活 mingdong → `CC.SMAPPicFile[1] == "mods/mingdong/data/smap.idx"`，`ModData` 解析条目数 = 4635（非原版 4129）。
5. **音频**：激活 mingdong → `mods/mingdong/sound/` 存在；`CC.ATKFile` 改写为 `mods/mingdong/sound/atk%02d.wav`；未激活时 `== "sound/atk%02d.wav"`。
6. **分类**：`test_mod_data.lua` 含设计性回退/死参数断言，全绿。
7. **pascal 基线**：`lua tools/mod_build.lua --verify-pascal` 仍 PASS（别名不影响 pascal 的 oldevent 一致性）。

## 子 change 顺序

```
allmods-slice0b-smap-rename      ★★★ 影响最大、可立即验证
        │
        ▼
allmods-slice0b-sound-fallback   ★★  需新增回退链
        │
        ▼
allmods-slice0b-resource-classify ★  固化判定（引用前两者结果）
```

> 顺序理由：先修影响面最大且能用现有测试立即验证的（A），再修需要扩展回退链的（D），
> 最后固化文档判定（C）。A 与 D 都改 `mod_build.lua` 的写出循环，D 依赖 A 先稳定该区域。
