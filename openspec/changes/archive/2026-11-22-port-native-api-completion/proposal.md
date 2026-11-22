# Change Proposal: port-native-api-completion — 消除 script 层的 `lib.*` 兼容层

> 父 slice: `engine-portability`
> 前置: `port-map-render-native` ✓（map 绘制契约已透明化）

## Why

`script/` 层仍直接调用 `lib.*`（LÖVE 侧那套原始实现），共
**196 处 / 29 个函数**（本轮实测，比早期估的 258 处少 —— 那含了 oldevent 脚本的重复统计）。

这带来三个问题：

1. **`lib.*` 只在 LÖVE 存在**。MUD/Web/测试桩只实现 `EngineAPI`，
   实测 **MUD 缺 30/35 个常用 `lib.*` 函数** → 「换引擎只需写 `engine-xxx`」
   这个 slice DoD **在这种情况下不成立**。
2. **等价物其实早就有**：196 处里 **165 处**（84%）已经有 EngineAPI 契约，
   只是 script 层没改用它。
3. **`lib_love.lua` 的 119 行 `LoadPic` RLE 解码删不掉**，因为
   `PicLoadFile` 还被 `lib.*` 调用方依赖（在 map 透明化前）。

### 本轮实测分布

| 函数 | 处数 | 目标契约 |
|------|------|---------|
| `lib.Debug` | 68 | `debug.log` |
| `lib.GetTime` | 33 | `time.getTime` |
| `lib.SetClip` | 20 | `render.setClip` |
| `lib.GetKey` | 19 | `input.getKey` |
| `lib.ShowSlow` | 16 | `render.present` |
| `lib.EnableKeyRepeat` | 4 | `input.enableKeyRepeat` |
| `lib.FillColor` | 2 | `render.fillRect` |
| `lib.DrawRect` | 1 | `render.rectOutline` |
| `lib.Delay` | 1 | **保留**（`WaitFrame` 的 fallback） |

**小计 165 处 / 8 个函数 —— 零新契约。**

### 剩下的 31 处（需逐个查语义等价）

| 函数 | 处数 | 目标契约 | 风险 |
|------|------|---------|------|
| `lib.DrawMMap` | 6 | `map.drawMain` | 低（已透明化） |
| `lib.LoadPicture` | 4 | `sprite.drawPictureFile` | 中（**语义要查**：前者是「加载图片」，后者是「画图片」） |
| `lib.GetMMap` | 3 | `map.getTile` | 低 |
| `lib.PlayWAV` | 2 | `audio.playSFX` | 中（参数是「文件名」还是「索引」？） |
| `lib.ShowSurface` | 2 | `render.present` | 低 |
| `lib.PlayMPEG` | 1 | `audio.playVideo` | 低 |
| `lib.LoadMMap` / `UnloadMMap` | 各 1 | `map.loadMain` / `map.unload` | 中（**loadMain 的参数顺序与 Custom 版不同**） |
| `lib.LoadSMap` / `SaveSMap` | 各 1 | `map.loadScene` / `map.saveScene` | 中 |
| `lib.GetS` / `SetS` / `GetD` / `SetD` | 各 1 | `map.getSceneTile` / ... | 低（已实测签名） |
| `lib.LoadWarMap` / `GetWarMap` / `SetWarMap` / `CleanWarMap` | 各 1 | `map.loadBattle` / ... | 低 |
| `lib.PlayMIDI` | 1 | `audio.playMusic` | **高**（TODO.md 已记「audio 概念重设计」） |
| `lib.CloudLoadAndInit` | 1 | **无契约** | 需新增 `map.loadClouds` |

---

## In Scope

### 1. 批量替换 165 处（Task 1-2）

按函数分组，一批一个 commit。每批都跑全量测试 + 实机截图。

### 2. 逐个核实 17 个函数的语义等价（Task 3）

**不能机械替换** —— 名字像不等于语义像。已知的坑：

- `lib.LoadPicture(filename, x, y)` vs `sprite.drawPictureFile(filename, x, y, opts)`：
  前者**加载并画**，后者只画（依赖 opts.cache）。语义可能等价，但要实测。
- `lib.PlayWAV(...)` vs `audio.playSFX(...)`：参数形态可能不同。
- `lib.LoadMMap(...)` vs `map.loadMain(...)`：**参数顺序可能不同**
  （`jymain.lua:1980` 传 9 个参数，而 `map.loadMain` 契约也是 9 个 —— 要逐位核对）。

### 3. 新增 1 个契约 `map.loadClouds(idxFile, grpFile)`

云的加载/烘焙属 sprite 子系统（逐像素调色板），引擎侧做。
但契约要有 —— 否则 script 层不能消除 `lib.CloudLoadAndInit`。

### 4. 删除 `lib.*` 兼容层（Task 5，可选）

`engine_love2d.lua:985` 的 `_G.lib = setmetatable(EngineAPI, { __index = lib })`。
如果 script 层零 `lib.*`，这一层可以删 —— 但 **`lib_love.lua` 本身不能删**
（`EngineAPI` 的实现还转发它，且 map 绘制的旧路径仍在其中）。

---

## Out of Scope

```
✗ 删 lib_love.lua 的 LoadPic 119 行 RLE 解码
  → 它仍被 PicLoadFile 调用，而 PicLoadFile 被 sprite.loadArchive 消费
  → 要删得先让 sprite 系统完全走 SpriteDecoder（当前已走，但 loadArchive
    仍调 PicLoadFile 写 picFileCache 供旧路径用）
  → 属独立 change

✗ audio 概念重设计（playMusic 收 filename vs PlayMIDI 收索引）
  → TODO.md 已记，独立评估

✗ oldevent/ 脚本里的 lib.*（约 2000 个脚本文件）
  → 那些是**数据**不是代码，随 MOD 一起分发；改它们要求 MOD 作者同步更新
  → 本 change 只改 script/ 的 6 个代码文件
```

## 关键度量

| 指标 | 基线（实测） | 目标 |
|------|-------------|------|
| `script/` 代码文件的 `lib.*` | **196 处 / 29 函数** | 1 处（`lib.Delay` 的 WaitFrame fallback） |
| MUD 缺失的 `lib.*` | 30/35 | **不适用**（script 不再用 `lib.*`） |
| 新契约 | — | +1（`map.loadClouds`） |
| `lib_love.lua` 行数 | 1700 | 不变（Out of Scope） |

## 风险

| 风险 | 缓解 |
|------|------|
| 165 处机械替换引入笔误 | 按函数分批 + 每批实机截图 |
| 语义不等价（`LoadPicture` / `PlayWAV` / `LoadMMap`） | Task 3 逐个实测，不机械替换 |
| `lib.Debug` 的 68 处替换改变日志行为 | `debug.log` 内部就是 `lib.Debug`，等价；但 `CONFIG.Debug` 门控要一致 |
| oldevent 脚本仍需 `lib.*` | `_G.lib` 兼容层**保留**（Task 5 是可选，且默认不做） |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-NAC-1 | 165 处有契约的 `lib.*` 全部替换 | specs/native-api/spec.md |
| REQ-NAC-2 | 17 个函数逐个验证语义等价 | 同上 |
| REQ-NAC-3 | 新增 `map.loadClouds` 契约 | 同上 |
| REQ-NAC-4 | 三界面像素逐字节相同 | 同上 |
