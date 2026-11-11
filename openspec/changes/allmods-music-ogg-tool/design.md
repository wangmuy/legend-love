---
status: abandoned
created: 2026-10-30
---
# Design: allmods-music-ogg-tool

## Context

MOD 自带音乐是 `.mid`（C 引擎时代），而 Lua 引擎的 `PlayMIDI` 只认
`sound/game<NN>.ogg`（`CC.MIDIFile`）。产物现有 **25** 个 ogg，而 mingdong 引用到
id **52**、awaken 引用到 id **81** ⇒ 这两个 MOD 的部分场景**静默无 BGM**（不崩溃）。

spike（`allmods-spike-music-refs`）已完成调研：真正受影响仅 **3/20 MOD**，
A 类需转换 **41 个 id**（去重 34），B 类 BookCalamity **20 个 id 无源可转**。

本 design 记录**实施层面**的关键决策，尤其是本轮实测踩到的 5 个坑。

---

## ADR-1：转换工具独立于 `mod_build.lua`，作为可选增强

**Context**：转换需要外部 `timidity` + `ffmpeg`。若放进主构建流程，则 CI 必须装音频工具链，
破坏项目既有的「构建期纯 Lua」约束。

**Decision**：新增独立工具 `game/tools/mid2ogg.lua`，由用户按需执行；
`mod_build.lua` **完全不感知**它的存在。

**Alternatives**：
- 放进 `mod_build.lua` 主流程 —— 否决：CI 依赖外部二进制，构建不再纯 Lua
- 预先生成 ogg 并入库、永不重转 —— 否决：MOD 源更新后无法跟随

**Consequences**：
- ✅ 构建链保持纯 Lua；无工具的机器照样能构建
- ⚠️ 新机器需手动跑一次 `mid2ogg.lua` 才有 BGM（可接受：只影响 2/20 MOD）
- ⚠️ 产物 ogg 需入库（约 36 MB）

---

## ADR-2：音色库必须用 `bank/program %font` 映射表，禁用 `soundfont` 整库写法

**Context**：这是本轮最有价值的发现。直觉写法 `soundfont "mid.sf2"` **被 timidity
静默忽略**，回退到系统 `/etc/timidity/timidity.cfg` 里的 FluidR3。

**实测证据**（4 种写法输出 md5 全同，说明全都没生效）：

| 写法 | 产物 md5 | 结论 |
|---|---|---|
| `soundfont "/path/mid.sf2"` | `3655ae82…` | ❌ 忽略 |
| `soundfont "…" order=0` | `3655ae82…` | ❌ 忽略 |
| `-x 'soundfont "…"'` | `3655ae82…` | ❌ 忽略 |
| `TIMIDITY_CFG=<cfg>` | `3655ae82…` | ❌ 忽略 |
| `bank 0` + `%font` ×128 | `b7c078ae…` | ✅ **生效** |

**Decision**：`makeTimidityCfg()` 生成 `dir` + `bank 0` + 128 行
`<prog> %font "mid.sf2" 0 <prog>`。

**Alternatives**：
- `soundfont` 整库 —— 否决：实测被忽略
- 用系统 FluidR3 —— 否决：非 MOD 原作者音色，且让 DoD 失去鉴别力

**Consequences**：
- ✅ 使用 MOD 自带音色（pascal 提供的 `mid.sf2`），最接近原意
- ⚠️ 必须做 A/B 负向对照（`mid.sf2` vs `FluidR3` md5 必须不同），否则无法证明映射表生效

---

## ADR-3：两段式转码（`timidity -Ow` → `ffmpeg`）

**Context**：`timidity -Oo`（直接出 ogg）在本机版本**未编译进来**：
实测报错 `Playmode 'o' is not compiled in.`

**Decision**：`timidity -Ow` 出 WAV → `ffmpeg -c:a libvorbis -q:a 4` 出 OGG。

**Alternatives**：
- `-Oo` 直出 —— 否决：不可用
- 只用 `ffmpeg` 读 `.mid` —— 否决：ffmpeg 无 MIDI 合成能力（无音源）

**Consequences**：
- ✅ 通用（`timidity` 提供合成、`ffmpeg` 提供编码）
- ⚠️ 需要两个外部工具；任一缺失则降级
- ⚠️ 中间 WAV 体积大（11 MB/首），必须转完即删

---

## ADR-4：只转被引用的 41 个 id，不转全部 578 个

**Context**：578 个 `.mid` 里只有 41 个被 `JY.Scene["进门音乐"]` 或 `WAR.Data["音乐"]`
实际引用（去重 34）。其余 537 个从未被这两个字段引用。

**Decision**：`M.REQUIRED_MIDS` 硬编码 41 个 id（逐 MOD），只转这些。

**Alternatives**：
- 全转 578 —— 否决：17/20 MOD 用不到，产物膨胀 ~15 倍
- 运行时按需转 —— 否决：游戏内不能调外部进程

**Consequences**：
- ✅ 产物 ~36 MB 而非 ~500 MB
- ⚠️ 若未来 MOD 版本改变引用集，需更新 `REQUIRED_MIDS`
  ⇒ 故 `mod_audit` 中剩余 537 个仍记 `PENDING`（**不是** `LEGACY`），保留未来可能性

---

## ADR-5：`.mp3` 归 LEGACY，不转换（**推翻初稿**）

**Context**：初稿计划把 `dream/24.mp3`、`pineapple/37.mp3` 也转成 ogg。
本轮实测证明**不该转**，两个独立理由：

1. **未被引用**：引用探针显示 dream max id = 22（不含 24）、pineapple max id = 24（不含 37）
2. **引擎无 MP3 音乐通道**：`PlayMPEG` 全项目仅 2 处调用，**都用于播 `start.mpg` 过场动画**；
   而 `lib_love.lua:622` 的 `PlayMPEG` 内部直接转调 `PlayMIDI`，只认 `sound/gameNN.ogg`

**Decision**：两个 `.mp3` 归 `LEGACY`（引擎零消费方），不转换。

**Alternatives**：
- 仍转换 —— 否决：产物无人消费，纯浪费 8 MB
- 新增引擎 MP3 通道 —— 否决：属四禁改（`engine-love2d/**`）

**Consequences**：
- ✅ 审计数字更诚实（`LEGACY` 而非假装 `REQUIRED_CONVERTED`）
- ⚠️ 若将来看清 `.mp3` 用途，需重新评估

---

## ADR-6：`.sf2` 归 BUILD_INPUT，不是产物

**Context**：`mid.sf2` 是转换工具的**音色输入**，不会被播放，也不进 `mods/`。

**Decision**：`classify` 归 `BUILD_INPUT`（与 `kysmod.ini` 同类）。

**Consequences**：
- ✅ 语义正确：它是「构建器消费但引擎不读」
- ⚠️ `PENDING` 减 1 的归因须写清（不是「转成了产物」）

---

## Negative Constraints（明确不做）

| # | 不做 | 理由 |
|:-:|---|---|
| 1 | 不改 `engine-love2d/**` / `engine-mud/**` | 四禁改 |
| 2 | 不改 `jyconst.lua` 的 `CC.*=` 常量 | 四禁改 |
| 3 | 不写 `reference/allmods/**` | 只读 |
| 4 | 不接入 `mod_build.lua` 主流程 | 保持纯 Lua 构建 |
| 5 | 不转 578 个全部 `.mid` | 过度 |
| 6 | 不转 `.mp3` | 未引用 + 无通道 |
| 7 | 不评判音色好坏 | 只证明映射生效 |
| 8 | 不修改历史上已归档的文档结论 | 历史不可篡改 |
| 9 | 不引入新的 Lua 依赖（纯标准库 `io.os`） | 保持零依赖 |

## Review Checklist

- [ ] `makeTimidityCfg` 输出**不含** `^soundfont`（否则静默失效）
- [ ] `game<id+1>` 用 `string.format("%02d")`，不是手写补零
- [ ] 中间 WAV 有清理，不留 11 MB 垃圾
- [ ] 外部工具缺失时退出码 **0**，不 throw
- [ ] A/B 负向对照有 md5 差异（否则映射表未生效）
- [ ] `REQUIRED_MIDS` 与 manifest Contract A 逐字一致
- [ ] 幂等（连跑两次 diff 为空）
- [ ] 产物落 `mods/<slug>/sound/`（触发 `REQ-SOUND-2` 重定向）
- [ ] 不在 `-Oo` 上浪费时间
