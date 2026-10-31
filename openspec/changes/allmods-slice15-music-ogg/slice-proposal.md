---
status: abandoned
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice15-music-ogg

> 纵向切片：把 **MOD 自带 MIDI 转成引擎能播的 OGG**，让 mingdong / awaken 两个 MOD
> 恢复缺失的 BGM，并顺带覆盖 `.mp3` 与 `.sf2` 共 581 条 `PENDING`。
>
> 这是 `allmods-spike-music-refs`（审计 spike，已 `done`）的**实施出口**。
> spike 给出的结论是「不阻塞 epic，可选增强」——本 slice 就是那个「可选增强」的正式方案。

## Why

`mod_audit --all` 现在剩下的 **581 条 `PENDING` 全是音频**（`.mid 578` + `.mp3 2` + `.sf2 1`），
而 `list/*.bin` 那批已由 `allmods-list-bin-support` 清零。**音频是整个 epic 的最后一处未支持项**。

spike 已实测清楚三件事，本 slice 直接继承、不重复调研：

1. **真正受影响只有 3/20 MOD**，其余 **17/20 零影响**（被引用 id 全落在原版 25 个 ogg 内）。
2. **A 类「源有、产物无」= 41 个 id**：mingdong 26 + awaken 15，去重后 **34**，最大 id **81**。
3. **B 类「源侧本就缺 `.mid`」= BookCalamity 20 个 id** ⇒ MOD 原始缺陷，转换流水线**无法修复**，
   只能文档记录。

本轮补充实测（spike 未覆盖的两个工程前提）：

4. **落点已就绪、零代码改动**：`game/framework/mod_data.lua:373-387` 已实现
   「MOD `sound/` 下存在 `game<NN>.ogg` 就把握放路径从 `sound/` 重定向到 `mods/<slug>/sound/`」
   （`REQ-SOUND-2`）。因 20/20 MOD 目前都没有 ogg，该分支**永不触发**。
   ⇒ 只要转换产物落进 `mods/<slug>/sound/`，**运行时自动生效，不用改引擎、不用改常量**。
5. **外部工具可用且方案可落地**：本机实测 `timidity 2.14.0` + `ffmpeg 6.1.1` 均在位；
   `10.mid`（69 秒）转换耗时 **3.5 s** + 编码 **2.7 s**。全量 34 个唯一 id 预计 **< 5 分钟**。

### 实测规模（继承 spike，本轮复核）

| 项 | 数值 | 证据 |
|----|---:|---|
| `.mid` 文件总数 | **578** | `ls reference/allmods/kys-*/music/*.mid \| wc -l` |
| `.mp3` | **2** | `kys-dream/music/24.mp3`、`kys-pineapple/music/37.mp3` |
| `.sf2` | **1** | `kys-pascal/music/mid.sf2`（唯一音色库，3.26 MB） |
| 产物现有 ogg | **25**（`game01..game25.ogg`） | `ls game/sound/game*.ogg \| wc -l` |
| 被引用 id 最大值 | **81**（awaken） | 探针 `JY.Scene["进门音乐"]` + `WAR.Data["音乐"]` |
| A 类需转换 | **41 id / 去重 34** | mingdong 26 + awaken 15，重叠 7 |
| B 类无法修复 | **20 id**（BookCalamity） | 源侧无 `.mid` 可转 |
| 零影响 MOD | **17/20** | 被引用 id 全在 25 个 ogg 内 |

## In Scope

- 新增**可选**转换工具 `game/tools/mid2ogg.lua`（纯 Lua 编排，调用外部 `timidity`+`ffmpeg`）
- 新增音色库映射生成（`mid.sf2` → timidity cfg 的 `bank/program %font` 表）
- 产物：`game/mods/{mingdong,awaken,sound 映射}/sound/game<NN>.ogg`（仅被引用的 34 个 id）
- ~~`.mp3` 2 个 → ogg~~ **修正：不转换** —— 实测均未被引用，且引擎无 MP3 音乐通道
  （`PlayMPEG` 仅用于 `start.mpg` 过场），归 `LEGACY`
- 幂等性、失败可跳过（缺外部工具时不报错、不中断构建）
- `mod_audit` 对这 34+2 个新产物的归类复核（应保持 `total` 不变，`in_product` 变化需解释）
- `openspec/changes/allmods-slice15-music-ogg/**`、`allmods-music-ogg/{proposal,tasks,...}`

## Out of Scope

- **引擎改动**：`game/engine-love2d/**`、`game/engine-mud/**`（四禁改路径）
- **`script/jyconst.lua` 常量**（`CC.MIDIFile` 等 `CC.*=` 赋值）—— 只允许函数调用
- **`reference/allmods/**`**（只读）
- **不把转换塞进 `mod_build.lua` 主流程** —— 保持「构建期纯 Lua」，改由独立工具按需执行
- **BookCalamity 的 20 个 id** —— 源侧无 `.mid`，无解，仅文档记录
- **578 个 `.mid` 全转** —— 过度：17/20 MOD 用不到，只转被引用的 34 个
- **音色艺术效果评判** —— 只断言「音色库确实按映射表加载」，不评判好听与否

## 已知坑（本轮实测发现，必须写进设计）

| # | 坑 | 实测证据 | 处置 |
|:-:|---|---|---|
| 1 | `soundfont "x.sf2"` **整库写法被 timidity 静默忽略** | 4 种音源（含错路径）输出 md5 全同 `3655ae82…` | **必须**写成 `bank 0` + 逐 program `%font` 映射表 |
| 2 | 音源加载失败**不报错、回退系统 FluidR3** | 错路径 `bad.wav` md5 == 正常 `sf2.wav` | DoD 必须**断言映射表真被读取**（strace 或 A/B md5 差异） |
| 3 | `timidity -Oo`（直接出 ogg）**未编译进来** | `Playmode 'o' is not compiled in` | 必须两段式：`-Ow` 出 WAV → `ffmpeg` 转 OGG |
| 4 | `ffmpeg` 出口是 ogg 但需指定 `libvorbis` | `-c:a libvorbis -q:a 4` → 1.08 MB | 显式指定编码器与质量 |
| 5 | **`.mp3` 是死文件**：引擎无 MP3 音乐通道 | `PlayMPEG` 两处均播 `start.mpg`；dream max id 22 / pineapple max id 24，均不引用 24/37 | 归 `LEGACY`，**不转换**（初稿「转 2 个 mp3」已推翻） |

## 子 change

| # | 子 change | 类型 | 职责 |
|---|-----------|------|------|
| 1 | `allmods-music-ogg-tool` | 工具实施 | `mid2ogg.lua` + sf2 映射生成 + 幂等/降级 |
| 2 | `allmods-music-ogg-verify` | 验证与收口 | 34+2 产物逐项验证、负向对照、文档与审计复核 |

## Definition of Done

- **功能**：mingdong 26 个 id、awaken 15 个 id 的 `game<NN>.ogg` 全部生成且能被 `love.audio` 载入
- **零代码回归**：引擎 / `jyconst` 常量 / `reference/` 改动数 = **0**；`mod_build.lua` 主流程不变
- **负向对照有鉴别力**：故意用错音色库 → 产物 md5 必须不同（证明映射表生效）
- **降级安全**：`timidity` 或 `ffmpeg` 缺失时工具**跳过并提示**，退出码 0，不破坏构建
- **幂等**：连续两次执行，产物逐字节一致
- **审计闭合**（数字已按记录条数逐类算准，`total` 恒 **11220**）：

  | 类别 | 变更前 | 变更后 | 说明 |
  |---|---:|---:|---|
  | `PENDING` | 581 | **537** | −41（被引用 `.mid`）−1（`.sf2`）−2（`.mp3`） |
  | `REQUIRED_CONVERTED` | 80 | **121** | +41 `.mid`（构建期转码后进产物） |
  | `BUILD_INPUT` | 30 | **31** | +1 `mid.sf2`（音色**输入**，非产物） |
  | `LEGACY` | 108 | **110** | +2 `.mp3`（引擎零播放路径） |
  | `total` | 11220 | **11220** | 恒等 ✅ |

  ```
  9185 + 121 + 110 + 2 + 1222 + 31 + 12 + 537 = 11220  ✅
  ```
- **必须新增审计分支**：`mod_audit.productCandidates()` 目前**没有 `music` 分支**
  （实测 `grep -c 'topdir == "music"'` = 0），转换产物**不被审计看见**，
  不补则 `PENDING` 数字不会变 —— 会变成「改了但审计说没改」的假象。
  须补 `music/<id>.mid → mods/<mod>/sound/game<NN>.ogg` 映射。
- **8 门禁全绿**，测试数不减少（当前 **1957**）

## 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 外部工具在 CI 缺失 | 转换不执行 | 工具降级跳过；DoD 允许「本地完成 + CI 跳过」 |
| 音色与原作者意图不同 | 听感差异 | 用 MOD 自带的 `mid.sf2`（pascal 提供），非系统音源 |
| 生成音频体积大 | 仓库膨胀 | 只转 34+2 个；`ogg -q:a 4` 约 1 MB/首 ⇒ 约 36 MB |
| 产物被 `mod_build --all` 覆盖 | 白转 | `mod_build` 的 `sound` walk 只搬源侧 `sound/`；MOD 源 `sound/` 无 ogg ⇒ 不冲突。DoD 需实测确认 |
