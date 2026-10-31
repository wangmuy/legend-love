---
status: abandoned
created: 2026-10-30
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice15-music-ogg

> 本 slice 是 `allmods-spike-music-refs`（审计 spike，`done`）的**实施出口**。
> spike 只做了「调研 + 决策建议」，**没有任何代码与产物**；本 slice 才真正把
> MOD 自带 MIDI 变成引擎能播的 OGG。
>
> **关键优势**：落点已就绪 —— `game/framework/mod_data.lua:373-387` 已实现
> 「MOD `sound/` 下存在 `game<NN>.ogg` 就把播放路径重定向到 `mods/<slug>/sound/`」
> （`REQ-SOUND-2`）。因 20/20 MOD 目前都没有 ogg，该分支永不触发。
> ⇒ 产物一旦落进 `mods/<slug>/sound/`，**运行时自动生效，零引擎改动、零常量改动**。

## 实测基线（变更前）

```
mod_audit --all --evidence:
total=11220 in_product=9285 not_in_product=1935 unclassified=0 bad_evidence=0
  REQUIRED 9185 / REQUIRED_CONVERTED 80 / LEGACY 108 / DEAD_FILE 2
  EDITOR_DUMP 1222 / BUILD_INPUT 30 / PLATFORM_ARTIFACT 12 / PENDING 581
  PENDING 构成: .mid 578 + .mp3 2 + .sf2 1   ← 全部是音频，.bin 残留 0
format_spec --all: formats=14 checked=6838 gaps=0
tests: 1957 / 0 failed
产物现有 ogg: 25 个（game/sound/game01..game25.ogg）
```

## 子 change 列表

| # | 子 change | 依赖 | 职责 | 状态 |
|---|-----------|------|------|------|
| 1 | `allmods-music-ogg-tool` | `allmods-spike-music-refs`（spike 已 done） | `mid2ogg.lua` + sf2 映射生成 + 幂等/降级 | `[x]` Created |
| 2 | `allmods-music-ogg-verify` | 子 change #1 | 产物逐项验证 + 负向对照 + 审计分支 + 文档收口 | `[x]` Created |

## 执行顺序

```
allmods-music-ogg-tool  →  allmods-music-ogg-verify
   (造工具+跑转换)            (逐项验证+审计归口+文档)
```

两者**不可并行**：verify 的所有断言都依赖 tool 的实际产物。

---

## Contract A — 转换清单（tool → verify）

tool 必须**只**转换被运行时引用的 id，清单如下（**逐 MOD 计，不去重**）：

| MOD | 被引用 id 数 | 需转换 id（源有 `.mid`、产物无 `.ogg`） |
|-----|---:|---|
| `mingdong` | 43 | **26**：`26,27,28,29,30,31,32,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52` |
| `awaken` | 31 | **15**：`26,27,31,32,40,44,45,55,57,58,70,71,72,77,81` |
| `dream` | 14（max id 22） | **0** —— 不引用 24，`24.mp3` 无消费方 |
| `pineapple` | 15（max id 24） | **0** —— 不引用 37，`37.mp3` 无消费方 |
| 其余 14 MOD | ≤23 | **0**（被引用 id 全在现有 25 个 ogg 内） |

> **修正（本轮实测推翻初稿）**：初稿计划「`.mp3` 2 个也转成 ogg」。实测证明**不该转**：
> 1. **引用探针**：dream 引用 id `{1,2,4,8,9,10,11,12,13,15,16,17,20,22}`（max 22，不含 24）；
>    pineapple 引用 `{1,3,4,8,9,12,13,15,17,18,19,20,21,23,24}`（max 24，不含 37）⇒ **两个 mp3 都没被引用**。
> 2. **引擎零播放路径**：`PlayMPEG` 全项目仅 `jymain.lua:171` / `jymain_adapter.lua:137` 两处，
>    **都用于播 `start.mpg` 过场动画**，与音乐无关；`lib_love.lua:622` 的 `PlayMPEG` 内部
>    直接转调 `PlayMIDI`（只认 `sound/gameNN.ogg`）⇒ **引擎没有 MP3 音乐通道**，转了也无从触发。
> 3. 故 `*.mp3` 归 **`LEGACY`**（引擎零消费方），**不转换**。

**消费方**：verify 逐文件核对「34 个唯一 id + 2 个 mp3」是否全部产出。

> **推测需实测确认**：`dream/24.mp3` 与 `pineapple/37.mp3` 是否真被 `JY.Scene["进门音乐"]`
> 或 `WAR.Data["音乐"]` 引用，spike 未实测。verify 必须先跑一次引用探针；
> **未被引用则跳过转换**（`Out of Scope` 已声明只转被引用的）。

## Contract A2 — 产物落点与命名

| 项 | 规则 | 依据 |
|---|---|---|
| 输出目录 | `game/mods/<slug>/sound/` | `mod_data.lua:375` `MODS_DIR..slug.."/"..SOUND_DIR` |
| 输出文件名 | `game<NN>.ogg`，`NN` = `id + 1` **补零两位** | `CC.MIDIFile = "sound/game%02d.ogg"`；`jymain.lua:2162` 传 `id+1` |
| 举例 | id `26` → `game27.ogg` / id `81` → `game82.ogg` | `string.format("%sgame%02d.ogg", dir, id+1)` |
| 重定向触发条件 | `mods/<slug>/sound/` 下存在**至少 1 个** `^game%d+%.ogg$` | `mod_data.lua:381-385` |

> **⚠ 命名陷阱**：`%02d` 是**最小宽度 2**，id 81 → `game82`（3 字符），不是 `game082`。
> verify 必须用 `string.format("game%02d.ogg", id+1)` 生成期望名，不能手写。

## Contract B — 音色库加载（**本 slice 最大的坑**）

**已实测证明的错误做法**（4 种写法输出 md5 全同 `3655ae82…`，说明全部回退系统 FluidR3）：

| 写法 | 结果 |
|---|---|
| `soundfont "/path/mid.sf2"` | ❌ 被静默忽略 |
| `soundfont "/path/mid.sf2" order=0` | ❌ 忽略 |
| `-x 'soundfont "…"'` | ❌ 忽略 |
| `TIMIDITY_CFG=<含 soundfont 的 cfg>` | ❌ 忽略 |

**唯一生效写法**（实测 md5 不同 `b7c078ae…` vs `379f412e…`，证明有鉴别力）：

```
dir /path/to/music
bank 0
0 %font "mid.sf2" 0 0
1 %font "mid.sf2" 0 1
...
127 %font "mid.sf2" 0 127
```

⇒ **Contract B 要求**：`mid2ogg.lua` 必须生成上述 `bank/program %font` 映射表，
**不得**使用 `soundfont` 整库写法。

**verify 的负向对照（必须做）**：

| 对照 | 期望 |
|---|---|
| 用 `mid.sf2` 映射表转换 `10.mid` | md5 = `b7c078ae…`（或记录值） |
| 用系统 `FluidR3_GM.sf2` 映射表转同一文件 | md5 **不同** |
| 若两者 md5 相同 | ⇒ 映射表未生效，**验证失败** |

## Contract C — 两段式转码

`timidity -Oo`（直接出 ogg）**未编译进来**（实测 `Playmode 'o' is not compiled in`），
必须两段式：

```
1) timidity -c <映射表.cfg> -Ow -o /tmp/xx.wav <id>.mid
2) ffmpeg -y -i /tmp/xx.wav -c:a libvorbis -q:a 4 <out>.ogg
```

实测耗时：`10.mid`（69 秒）→ timidity **3.5 s** + ffmpeg **2.7 s**；产物 **1.08 MB**。
34 个唯一 id 预计 **< 5 分钟**。

**降级要求**：`timidity` 或 `ffmpeg` 任一不存在 ⇒ 打印提示 + **退出码 0** + 不产出文件，
**不得**中断或报错（保持「不阻塞构建」）。

## Contract D — 审计归口

`mod_audit.productCandidates()` 目前**没有 `music` 分支**（实测）：

```bash
$ grep -c 'topdir == "music"' game/tools/mod_audit.lua
0
```

⇒ 转换产物**不被审计看见**。必须新增：

```lua
elseif topdir == "music" then
    -- 只有被引用的 <id>.mid 被转成 sound/game<id+1>.ogg
    local m = filename:match("^(%d+)%.mid$")
    if m then
        cands[#cands+1] = M.MODS_OUT.."/"..mod.."/sound/"..string.format("game%02d.ogg", tonumber(m)+1)
    end
    -- .mp3（LEGACY）/ .sf2（BUILD_INPUT）无可执行产物候选 ⇒ 不追加
end
```

**预期分类变化**（逐记录条数，`total` 恒 11220）：

| 类别 | 前 | 后 | 变化 |
|---|---:|---:|---|
| `PENDING` | 581 | **537** | −41（被引用 `.mid`）−1（`.sf2`）−2（`.mp3`） |
| `REQUIRED_CONVERTED` | 80 | **121** | +41（`.mid` 构建期转码） |
| `BUILD_INPUT` | 30 | **31** | +1（`mid.sf2` 音色**输入**，非产物） |
| `LEGACY` | 108 | **110** | +2（`.mp3`：引擎零播放路径） |
| `total` | 11220 | **11220** | 恒等 |

```
9185 + 121 + 110 + 2 + 1222 + 31 + 12 + 537 = 11220  ✅
```

> **注意**：`music/*.mid` 的 578 − 41 = 537 个**未被引用**的 id 应保持 `PENDING`
> 还是转 `LEGACY`，须在实施时明确（建议保持 `PENDING` 并在报告说明，
> 因它们仍可被未来 MOD 版本引用，不是「永不需要」）。

## Contract E — 零回归

| 断言 | 命令 | 期望 |
|---|---|---|
| 引擎未改 | `git status --porcelain \| grep -cE 'engine-love2d/\|engine-mud/'` | `0` |
| 常量未改 | `git diff game/script/jyconst.lua \| grep -cE '^\+.*CC\.[A-Za-z]+ *='` | `0` |
| 源树未改 | `git status --porcelain \| grep -c 'reference/allmods/'` | `0` |
| 主流程未改 | `git diff --stat game/tools/mod_build.lua` | 无音视频相关新增 |
| 测试数 | `lua tests/test_runner.lua` | **≥ 1957**，0 失败 |
| 幂等 | 连跑两次 `mid2ogg.lua`，`diff -rq` 产物 | 空 |

---

## 契约冻结：`mid2ogg.lua` 对外接口（供 verify 编写断言）

```lua
-- game/tools/mid2ogg.lua
M = {}
M.REQUIRED_MIDS = {           -- 唯一真相源，verify 直接读它
  mingdong = {26,27,28,29,30,31,32,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52},
  awaken   = {26,27,31,32,40,44,45,55,57,58,70,71,72,77,81},
}
-- .mp3 不转换（实测未被引用 + 引擎无 MP3 通道），故无 REQUIRED_MP3S 表

function M.checkDeps()          -- → ok:boolean, missing:string[]
function M.makeTimidityCfg(sf2Path, outPath)  -- 生成 bank/program %font 映射表
function M.convertOne(midPath, outOggPath)    -- → ok:boolean, err
function M.convertAll(opts)     -- → report:table {converted, skipped, failed}
function M.main(args)           -- --all | --mod <slug> | --dry-run
```

**verify 可依赖的稳定点**：`REQUIRED_MIDS` 表、`game<id+1>` 命名、退出码 0 降级语义。

## 集成测试计划

| # | 场景 | 判定 |
|:-:|---|---|
| 1 | `mid2ogg.lua --dry-run` | 列出 41 个 `.mid` + 2 `.mp3`，不写文件 |
| 2 | `mid2ogg.lua --mod mingdong` | 产出 **26** 个 `game*.ogg` 于 `mods/mingdong/sound/` |
| 3 | `mid2ogg.lua --mod awaken` | 产出 **15** 个，最大 `game82.ogg` |
| 3b | `mid2ogg.lua --mod dream` / `--mod pineapple` | **0 产物**（mp3 未引用，不转） |
| 4 | 缺 `timidity`（`PATH=/usr/bin:/bin` 且改名） | 打印提示 + 退出 0 + 零产物 |
| 5 | 连跑两次 `--mod mingdong` | 第二轮 `diff -rq` 为空 |
| 6 | 音色库负向对照 | `mid.sf2` 与 `FluidR3` 产物 md5 不同 |
| 7 | 真实启动 mingdong | `boot_one_mod.lua mingdong 632 367 139 220 小蝦米` → `RESULT: OK`，无 `PlayMIDI error` |
| 8 | `mod_audit --all` | `PENDING=537`、`REQUIRED_CONVERTED=123`、`total=11220` |

## 状态汇总

| 项 | 值 |
|---|---|
| 子 change 数 | 2 |
| 已完成 | 0 |
| 需转换音频 | **41 `.mid`**（去重 34）；`.mp3` **0**（未引用+无通道） |
| 预计产物体积 | ≈ 36 MB（34 唯一 × ~1.08 MB） |
| 不转换项 | 2 `.mp3` → `LEGACY`；1 `.sf2` → `BUILD_INPUT` |
| 无法修复项 | BookCalamity 20 个 id（源侧无 `.mid`） |
| 外部依赖 | `timidity ≥2.14` + `ffmpeg`（缺失则降级跳过） |
