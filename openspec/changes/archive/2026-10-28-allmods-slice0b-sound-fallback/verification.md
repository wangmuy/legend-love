# Verification: allmods-slice0b-sound-fallback

> Contract B owner · 子 change 2/3 · 状态：**✓ PASSED**

## 1. 执行摘要

构建期复制 MOD `sound/` 到 `mods/<mod>/sound/`，并让 `CC.ATKFile`/`CC.EFile`（及对称的 `CC.MIDIFile`）按 MOD 前缀回退。

**修复前**：20/20 MOD 音效零复制；MOD 独有音效无法播放；同名音效被原版覆盖（mingdong 78 个同名中 **52 个内容不同**）。
**修复后**：20/20 MOD 音效正确加载（共 2002 个文件）。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实现 | 验证证据 | 状态 |
|-----|------|------|---------|------|
| [REQ-SOUND-1] | 构建期复制 `sound/` 到平级目录 | `collectDataFiles` 新增 `walk(modDir.."/sound","","sound")`；`Build` 新增 `outSound`；`flattenResources` 路由 | `test_mod_build.testSoundWalkInSource`/`testSoundRoutingInSource`；20/20 MOD 文件数一致 | ✓ |
| [REQ-SOUND-2] | 音频常量 MOD 前缀改写 | `ModData.RewriteConstants` 对 3 个常量做前缀改写（按文件名模式匹配） | `test_mod_data.testRewriteAudioModHit`；独立子进程实测 | ✓ |
| [REQ-SOUND-3] | 未激活/无 `sound/` 回退原版 | `ModData.dirExists(modSoundDir)` 守卫 + 每常量 `listDir` 匹配 | `test_mod_data.testRewriteAudioNoActiveIsNoop`/`testRewriteAudioNoSoundDirFallsBack` | ✓ |
| [REQ-SOUND-4] | 零回归 | 未激活时常量不变；引擎音频代码未改 | 全量测试 449/449；`git diff game/engine-love2d/` 为空 | ✓ |

### 补充：`%02d` 对 3 位编号的处理（REQ-SOUND-2 场景）

| 验证 | 结果 |
|------|------|
| `string.format("%02d", 100)` | `"100"`（Lua `%02d` 是最少 2 位，3 位原样输出） |
| `string.format(CC.EFile, 100)`（激活 mingdong） | `mods/mingdong/sound/e100.wav` ✓ |
| 实际 3 位编号来源 | BookCalamity（107 个 `e1xx`）、mingdong（76 个 `e1xx`） |

### 补充：`MIDIFile` 不误改（设计性正确）

| 验证 | 结果 |
|------|------|
| 20/20 MOD `sound/` 是否含 `game*.ogg` | 否（只有 `atk*`/`e*`/`tit`） |
| 激活 mingdong 后 `CC.MIDIFile` | `sound/game%02d.ogg`（保持原版）✓ |

## 3. 实测证据

### 3.1 产物检查（20/20 MOD）

```
总音效文件: 2002
文件数一致（MOD 产物 vs 源 MOD sound/）: 20/20
```

| MOD | 音效数 | MOD | 音效数 |
|-----|-------|-----|-------|
| BookCalamity | 234 | lyff | 78 |
| Dragon | 80 | mingdong | 201 |
| GodsDevils | 78 | pascal | 78 |
| HeavenSword | 78 | pig | 78 |
| RiverLake | 170 | pig3dos | 111 |
| SweeOan | 78 | pineapple | 109 |
| awaken | 79 | ptt | 78 |
| books | 84 | stronger | 78 |
| dream | 77 | zheng | 78 |
| lostbook | 78 | loving | 77 |

### 3.2 运行时证明（mingdong，独立子进程）

```
[PASS] ATKFile = mods/mingdong/sound/atk%02d.wav
[PASS] EFile   = mods/mingdong/sound/e%02d.wav
[PASS] MIDIFile = sound/game%02d.ogg（保持原版）
[PASS] format(EFile,100) = mods/mingdong/sound/e100.wav
```

### 3.3 未激活零回归

```
[PASS] no active: ATKFile unchanged = sound/atk%02d.wav
[PASS] no active: EFile unchanged   = sound/e%02d.wav
[PASS] no active: MIDIFile unchanged = sound/game%02d.ogg
```

### 3.4 无 `sound/` 目录回退

```
[PASS] no sound/: ATKFile falls back = sound/atk%02d.wav
[PASS] no sound/: EFile falls back   = sound/e%02d.wav
```

### 3.5 引擎音频代码未改

```
$ git status --short game/engine-love2d game/engine-mud
（无输出）
```

## 4. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/tools/mod_build.lua` | `collectDataFiles` 新增 sound walk；`Build` 新增 `outSound`；`flattenResources` 路由 + 计数 | ✓ |
| `game/framework/mod_data.lua` | `SOUND_DIR` 常量、`dirExists`、`RewriteConstants` 音频分支 | ✓ |
| `game/tests/unit/test_mod_data.lua` | 5 个新测试（noop/hit/fallback/smap 别名/dirExists） | ✓ |
| `game/tests/unit/test_mod_build.lua` | sound walk/routing 断言 | ✓ |
| `game/mods/**` | 20 MOD 新增 `sound/` | ✓ |

**未触碰**：`game/engine-love2d/**`（含 `lib_love.lua` 的 `PlayWAV`/`PlayMIDI`/`PlayMPEG`）、`game/engine-mud/**`、`game/script/jyconst.lua` 的常量定义、`reference/allmods/**`。✓

## 5. 测试结果

| 测试套件 | 结果 |
|---------|------|
| `lua tests/test_runner.lua` | **449/449 通过** |
| `lua tests/test_runner.lua mod_data` | 含 5 个新音频断言，全通过 |
| `lua tests/test_runner.lua mod_build` | 30/30 通过 |
| `lua tools/mod_build.lua --all` | 20 mods, 0 failures |
| `lua tools/mod_build.lua --verify-pascal` | PASS |

## 6. 偏差记录

| 偏差 | 说明 | 处置 |
|------|------|------|
| 初版只检查目录存在 | `dirExists(mods/<slug>/sound/)` 为真即改写全部 3 个常量，导致 `MIDIFile` 被错误改为 `mods/mingdong/sound/game%02d.ogg`（无此文件） | 改为按**文件名模式**逐常量检查（`listDir(dir, "^atk%d+%.wav$")` 非空才改写）；`MIDIFile` 因无 `game*.ogg` 正确保持原版 |
| `listDir` 空表为真 | 初版 `if ModData.listDir(...)` 恒真（空表 truthy） | 改为 `if #ModData.listDir(...) > 0` |
| Lua 模式误写 `%%d` | 初版模式串 `"^atk%%d+%.wav$"` 匹配字面 `%`，永不命中 | 改为 `"^atk%d+%.wav$"` |
| 不做 per-file 回退 | MOD 内缺失某编号时由现有 `pcall` 静默兜底，不回退原版 | ADR-003 明确设计决策；与原版「缺失即无声」一致 |

## 7. 总体判定

**✓ PASSED** — 4 个 REQ 全部满足，DoD 1~6 全部通过（含 3 位编号、MIDIFile 保持、无 sound 回退）。
