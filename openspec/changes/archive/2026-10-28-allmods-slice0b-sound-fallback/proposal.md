---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

MOD 源数据含 `sound/` 目录（音效），但 `tools/mod_build.lua` 的 `collectDataFiles()` 只 walk `resource/`、`fight/`、`save/`，**音频零复制**；同时 `ModData.rewrite()` 只重写 `data/` 与 `script/` 前缀，**`sound/` 无 MOD 回退链**。后果：

- MOD 独有音效无法播放（mingdong 123 个独有文件）。
- 同名音效被原版覆盖（mingdong 78 个同名文件中 **52 个内容不同**，MOD 定制音效丢失）。
- 20/20 MOD 全部受影响。

**权威依据**：源 MOD `sound/` 的文件命名与引擎常量完全吻合——
`CC.ATKFile = sound/atk%02d.wav`、`CC.EFile = sound/e%02d.wav`（编号全为 2~3 位，`%02d` 可正确格式化）。
pascal 的 78 个同名文件与 `game/sound/` **逐字节相同**（证明命名约定一致，是同一体系的复制）。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0b/slice-proposal.md`（Contract B 的拥有方）
- 依赖: `allmods-slice0b-smap-rename`（共用 `mod_build.lua` 写出循环）；Slice 0 的 `allmods-data-fallback`（提供 `ModData.RewriteConstants` 的 `FightPicFile` 前缀改写范式，本 change 仿照它）

## What Changes

1. **`game/tools/mod_build.lua`**：
   - `collectDataFiles()` 新增 `walk(modDir .. "/sound", "", "sound")`
   - `flattenResources()` 处理 `kind=="sound"`：写入 `mods/<mod>/sound/`（小写归一，不拍平到 `data/`）
   - 新增 `outSound` 输出目录
2. **`game/framework/mod_data.lua`**：
   - `RewriteConstants` 新增对 `CC.MIDIFile`、`CC.ATKFile`、`CC.EFile` 三个 `%02d` 格式串常量的前缀改写（仿现有 `FightPicFile` 分支）：`sound/...` → `mods/<slug>/sound/...`（仅当 `mods/<slug>/sound/` 目录存在）
3. **单元测试**：断言 `sound/` 复制、`CC.ATKFile`/`CC.EFile` 改写、未激活时零回归。

## Scope Boundaries

### In Scope

- `sound/` 目录的构建期复制（含 `tit.wav` 等非编号文件，忠实复制）
- `CC.MIDIFile`/`CC.ATKFile`/`CC.EFile` 的 MOD 前缀回退
- 单元测试

### Out of Scope

- **`music/*.mid` 转换** — 格式不兼容（`.mid` vs 引擎 `game%02d.ogg`），需外部音源工具，且 MOD 66 首 vs 引擎 25 槽；需先做「MOD 音乐引用分析」spike（见 epic TODO）
- **per-file 回退** — `love.audio.newSource` 只接受单路径；MOD 内缺失某编号 wav 时由现有 `pcall` 静默兜底（不新增逐文件回退逻辑）
- 音量/3D 音效等 `[music]` 段 ini 参数（已由 Slice 0 的 ini 解析器处理）
- 引擎音频解码器改动

## Capabilities

### New Capabilities

- `allmods-sound-fallback`: MOD 音效复制与回退链（[REQ-SOUND-1]~[REQ-SOUND-4]）

## Contract Adherence

完全遵守 `change-manifest.md` 的 **Contract B**：

- 构建期产物 `mods/<mod>/sound/`（与 `data/`、`script/` 平级）。
- 运行时仅改 `CC.*` 常量的前缀，不改 `lib_love.lua` 的音频加载逻辑。
- 未激活 MOD → 常量保持 `sound/...`（零回归）；`mods/<slug>/sound/` 不存在 → 保持 `sound/...`。
- 不做 per-file 回退。

无偏离。

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-SOUND-1] | 构建期复制源 MOD `sound/` → `mods/<mod>/sound/`（小写归一，逐字节保留） |
| [REQ-SOUND-2] | `CC.MIDIFile`/`CC.ATKFile`/`CC.EFile` 前缀改写为 MOD 路径（当 MOD `sound/` 存在） |
| [REQ-SOUND-3] | 未激活 MOD 或 MOD 无 `sound/` → 常量保持原版路径（回退原版） |
| [REQ-SOUND-4] | 未激活 MOD 零回归：`tests/test_runner.lua` 全绿 |

## DoD

1. `lua tools/mod_build.lua kys-mingdong` → `game/mods/mingdong/sound/` 含 201 个文件（与原 MOD `sound/` 文件名集合一致，小写）。
2. 激活 mingdong 并加载 `CC` → `CC.ATKFile == "mods/mingdong/sound/atk%02d.wav"`、`CC.EFile == "mods/mingdong/sound/e%02d.wav"`、`CC.MIDIFile == "sound/game%02d.ogg"`（音乐未处理，保持原版）。
3. 未激活 MOD → `CC.ATKFile == "sound/atk%02d.wav"`（零回归）。
4. 激活一个**无** `sound/` 目录的 MOD（构造测试用例）→ 常量保持原版路径。
5. 无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿。
6. `lua tools/mod_build.lua --verify-pascal` 仍 PASS。

## Impact

- **代码**：`game/tools/mod_build.lua`（`collectDataFiles`/`flattenResources`/`Build`）、`game/framework/mod_data.lua`（`RewriteConstants`）
- **测试**：`game/tests/unit/test_mod_build.lua`、`game/tests/unit/test_mod_data.lua`
- **产物**：全部 20 个 `game/mods/<mod>/sound/` 新增（约 100~200 文件/MOD）
- **依赖**：无新增
- **风险**：低。`%02d` 已验证可正确格式化 2~3 位编号；pascal 同名文件逐字节相同证明命名一致。产物体积增加（每 MOD 约 3~10MB 音频）。
