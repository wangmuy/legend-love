---
status: abandoned
created: 2026-10-30
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice15-music-ogg
---
# Proposal: allmods-music-ogg-tool

## Why

`mod_audit --all` 剩下的 **581 条 `PENDING` 全是音频**（`.mid 578` + `.mp3 2` + `.sf2 1`），
是整个 allmods epic 的最后一处未支持项。其中真正影响游戏体验的是
**mingdong（26 个 id）与 awaken（15 个 id）的 BGM 缺失**——这两个 MOD 的场景音乐
指向 `game26..game82`，而产物只有 `game01..game25`，运行时会静默无 BGM。

`allmods-spike-music-refs`（spike，已 `done`）已完成调研与决策，但**零实施**。
本 change 是它的实施单元之一：**造出转换工具并真正产出 ogg**。

## What Changes

新增 `game/tools/mid2ogg.lua`（**可选**构建增强工具，不入 `mod_build.lua` 主流程）：

1. 硬编码唯一真相源 `M.REQUIRED_MIDS`（mingdong 26 / awaken 15）
2. `checkDeps()` —— 检测 `timidity` / `ffmpeg`，缺失则降级
3. `makeTimidityCfg()` —— 生成 **`bank/program %font` 映射表**（不是 `soundfont` 整库写法，
   实测后者被 timidity 静默忽略）
4. `convertOne()` —— 两段式 `timidity -Ow → ffmpeg -c:a libvorbis`
5. `convertAll()` / `main()` —— `--all` / `--mod <slug>` / `--dry-run`

## In Scope

- `game/tools/mid2ogg.lua`（新文件，唯一代码产出）
- `game/mods/{mingdong,awaken}/sound/game<NN>.ogg`（产物，41 个文件）
- `openspec/changes/allmods-music-ogg-tool/**`
- 可选的 `game/tests/unit/test_mid2ogg.lua`（纯逻辑单测，不依赖外部工具）

## Out of Scope

- **`game/tools/mod_build.lua` 主流程** —— 明确不接入，保持「构建期纯 Lua」
- **引擎改动**：`engine-love2d/**`、`engine-mud/**`（四禁改）
- **`script/jyconst.lua` 常量**（`CC.MIDIFile` 不改）
- **`reference/allmods/**`**（只读，绝不写入源树）
- **`.mp3` / `.sf2` 转换** —— mp3 未被引用且引擎无 MP3 通道（LEGACY）；sf2 是音色输入
- **578 个 `.mid` 全转** —— 只转被引用的 41 个
- **`mod_audit` 的 `music` 分支** —— 属 `allmods-music-ogg-verify` 的职责

## 关键约束（实测得出，非推测）

| # | 约束 | 实测证据 |
|:-:|---|---|
| 1 | 必须用 `bank/program %font` 映射表 | `soundfont "x.sf2"` 四种写法（含错路径）输出 md5 全同 `3655ae82…` |
| 2 | 映射表生效可用 md5 区分 | `mid.sf2` → `b7c078ae…`，`FluidR3` → `379f412e…` |
| 3 | 必须两段式（`-Oo` 不可用） | `Playmode 'o' is not compiled in` |
| 4 | 输出名 = `game<id+1>` 补零两位 | `CC.MIDIFile="sound/game%02d.ogg"`，`jymain.lua:2162` 传 `id+1` |
| 5 | 输出目录 = `mods/<slug>/sound/` | `mod_data.lua:375`；该目录有 ogg 即触发 `REQ-SOUND-2` 重定向 |

## Definition of Done

- `lua game/tools/mid2ogg.lua --dry-run` 列出 **41** 个待转 `.mid`，零写入
- `lua game/tools/mid2ogg.lua --all` 产出 **41** 个 `game<NN>.ogg`（除零失败）
- 文件大小合理（每首个 ~0.2–1.5 MB），`ffprobe` 可识别为 vorbis
- **负向对照**：`--sf2 mid.sf2` 与 `--sf2 FluidR3_GM.sf2` 产物 md5 **必须不同**
- **降级**：`PATH` 中无 `timidity` 时 → 打印提示、退出码 **0**、零产物
- **幂等**：连跑两次，`diff -rq` 产物为空
- 四禁改路径改动数 = **0**

## Impact

| 区域 | 影响 |
|---|---|
| `game/tools/` | +1 新文件（不影响既有工具） |
| `game/mods/mingdong/sound/` | +26 个 ogg（约 28 MB） |
| `game/mods/awaken/sound/` | +15 个 ogg（约 16 MB） |
| 运行时 | 这两个 MOD 的 BGM 从「静默无音乐」变为「正常播放」 |
| 引擎 / 常量 / 源树 | **零改动** |
