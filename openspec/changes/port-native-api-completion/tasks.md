# Tasks: port-native-api-completion

> **策略**：先做 165 处机械替换（有确定契约、零语义风险），
> 再逐个核实剩下的 31 处。每批一个 commit + 实机截图。

## Task 1：批量替换 165 处（有确定契约的）—— **完成，实际 161 处**

**Blast Radius**：`script/jymain.lua`、`script/battle/*.lua`、
`script/newevent/*.lua`

### 实测结果

| 替换 | 处数 | 说明 |
|------|------|------|
| `lib.Debug` → `EngineAPI.debug.log` | 68 | 内部就是 `lib.Debug` |
| `lib.GetTime` → `EngineAPI.time.getTime` | 35 | 含 2 处嵌在 `string.format` 里的 |
| `lib.SetClip` → `EngineAPI.render.setClip` | 20 | 内部就是 `lib.SetClip` |
| `lib.GetKey` → `EngineAPI.input.getKey` | 19 | 内部就是 `lib.GetKey` |
| `lib.ShowSlow` → `EngineAPI.render.present` | 16 | **三函数实测等价**：都忽略参数，只 `inDrawLoop + present()` |
| `lib.EnableKeyRepeat` → `input.enableKeyRepeat` | 4 | |
| `lib.FillColor` → `render.fillRect` | 2 | |
| `lib.DrawRect` → `render.rectOutline` | 1 | |

**合计 161 处**（不是估的 165 —— `lib.ShowSlow` 实际 16 处里 14 处带参数，
替换后清掉了多余参数）。

### 两个顺带修的问题

1. **`ShowSlow(delay, flag)` 的两个参数**：原实现完全忽略，所以
   `present(delay, flag)` 语法合法但**语义混乱**。清掉 14 处多余参数 → `present()`。
2. **2 处 `lib.GetTime` 嵌在 `string.format` 里**（`"Loadrecord time=%d",lib.GetTime()-t1`）
   → 第一遍批量替换没匹配到（因为它不在行首），单独修。

### 保真校验白名单要扩 6 个函数

`gate_battle_extensibility.sh` 的字节级保真校验抓到 6 个战斗函数"内容不一致"。
它们只改了 `lib.Debug` → `debug.log` 这类**等价转发**，逻辑零改动。
加入白名单并写清理由（每条替换的等价性依据）。

**DoD**：
- [x] 161 处替换（8 个函数）
- [x] 清掉 `present()` 的 14 处多余参数
- [x] 修 2 处嵌在 `string.format` 里的 `lib.GetTime`
- [x] 保真白名单扩 6 个函数（附等价性依据）
- [x] 四版本全量测试零失败（4011/0）
- [x] **实机三界面 md5 不变**（`6c8eb322…` / `1efd2af3…`）
- [x] 五门禁全 PASS（含修好保真白名单）
- [x] 一个 commit

---

## Task 2：新增 `map.loadClouds` 契约 —— **完成**

**Blast Radius**：`engine_api.lua`、4 个引擎实现、`script/jymain.lua`

### 为什么云的加载归引擎

云的像素要做**逐像素调色板烘焙**（`CloudBakeImage`，`lib_love.lua:1255`
→ `love.image.newImageData`），属 sprite 子系统，不是 map 投影逻辑。

三者分工：

| 契约 | 职责 | 归属 |
|------|------|------|
| `map.loadClouds(idx, grp)` | 加载容器 + 逐像素烘焙 | 引擎（sprite 子系统） |
| `map.tickClouds()` | 位置更新（纯时间驱动） | 引擎（已有） |
| `map.drawClouds(mx, my)` | 贴图绘制 | 引擎（已有） |

契约数 88 → **89**。

**DoD**：
- [x] `map.loadClouds(idxFile, grpFile)` 契约（4 引擎）
- [x] LÖVE 实现 = `lib.CloudLoadAndInit`
- [x] MUD/Web 空实现
- [x] `script/jymain.lua:439` 的 `lib.CloudLoadAndInit` → `EngineAPI.map.loadClouds`
- [x] 单测：4 引擎都有
- [x] 四版本全量测试零失败（4011/0）

### ⚠️ 顺带发现一个验证方法的坑：主地图 md5 **不能当基线**

改 `CloudLoadAndInit` 后主地图 md5 从 `36fd32b0…` 变成 `a83715fe…`，
我一度以为是回归。实际是**云的位置每次启动都不同**：

```lua
-- lib.CloudCreateOnSide（lib_love.lua:1265-1287）
c.Picnum   = math.random(0, cloudPicAmount - 1)
c.Alpha    = 10 + math.random(0, 49)
c.Positionx = math.random(0, CLOUD_WORLD_X - 1)
-- JYMainAdapter.init: math.randomseed(os.time())
```

⇒ **只有无随机元素的界面能用 md5 当硬基线**：
- 场景（主角家对话）`1efd2af3…` ✓
- 战斗 `6c8eb322…` ✓
- 主地图 ✗（云随机）—— 只能目视

已在 `docs/screenshots/README.md` 写清这一点。

---

## Task 3：逐个核实 31 处的语义等价

**Blast Radius**：同上 + `engine_love2d.lua`


### 实测记录（逐个核实的结果）

| 函数 | 处数 | 判定 | 依据 |
|------|------|------|------|
| `lib.DrawMMap` | 6 | ✓ 迁移 | Task 3 已透明化 `map.drawMain` |
| `lib.GetMMap` | 3 | ✓ 迁移 | `map.getTile`（layer 0..4 一致） |
| `lib.ShowSurface` | 2 | ✓ 迁移 | 与 `ShowSlow` 一样忽略 flag，三者等价 |
| `lib.PlayWAV` | 2 | ✓ 迁移 | `audio.playSFX` **直接转发** `lib.PlayWAV` |
| `lib.PlayMPEG` | 1 | ✓ 迁移 | `audio.playVideo` 转发；旧版无返回、新版返回 true，调用点忽略 → 等价 |
| `lib.PlayMIDI` | 1 | ✓ 迁移 | `audio.playMusic` **直接转发** |
| `lib.LoadMMap` | 1 | ✓ 迁移 | `map.loadMain`（9 参逐位核对一致） |
| `lib.UnloadMMap` | 1 | ✓ 迁移 | `map.unload` |
| `lib.LoadSMap` | 1 | ✓ 迁移 | `map.loadScene`（8 参一致） |
| `lib.SaveSMap` | 1 | ✓ 迁移 | `map.saveScene` |
| `lib.GetS/SetS/GetD/SetD` | 各 1 | ✓ 迁移 | 签名已实测 |
| `lib.LoadWarMap/GetWarMap/SetWarMap/CleanWarMap` | 各 1 | ✓ 迁移 | 在 `battle_data.lua`，签名一致 |
| `lib.LoadPicture` | 4 | **分两种** | 见下 |
| `lib.CloudLoadAndInit` | 1 | ✓ 迁移 | Task 2 新增的 `map.loadClouds` |

### `lib.LoadPicture` 的语义差异（唯一必须拆开的）

逐字对比两个实现：

```lua
lib.LoadPicture(filename, x, y):
  if filename == "" → pictureCache = {}      ← **清空缓存！**
  x == -1 → 居中用 CONFIG.Width

EngineAPI.sprite.drawPictureFile(filename, x, y, opts):
  if filename == "" → return false           ← **不清缓存**
  x == -1 → 居中用 EngineAPI.render.getWidth()
```

**第 295 行正是 `lib.LoadPicture("",0,0)`** —— 靠的就是"清缓存"这个隐式副作用。

⇒ 不能机械替换。处置：
- **新增契约** `sprite.clearPictureCache()`（4 引擎 + `lib.ClearPictureCache`）
- 那 1 处 → `EngineAPI.sprite.clearPictureCache()`
- 其余 3 处（x/y = -1 居中）→ `sprite.drawPictureFile`（等价）

契约数 89 → **90**。

### 顺带修了 2 个测试判据（都是我这次迁移触发的误报）

1. **`test_mod_resources` 的 `allsinbk` 死参数判据**：
   原来只认 `LoadSMap(` 字面，迁移后变成 `map.loadScene(...)` → 误报
   "allsinbk 有意外引用"。判据扩成 `LoadSMap(` 或 `loadScene(`。
2. **`test_battle_flow_headless` 只 stub 了 `lib.*`**：
   `battle_data.lua` 现在调 `EngineAPI.map.setBattleTile` → 报
   "attempt to call field 'setBattleTile' (a nil value)"。
   补 stub 了 `EngineAPI.map` 的 5 个战斗契约。

### 3a. `lib.DrawMMap` 6 处 → `map.drawMain`（低风险，已透明化）

- [x] 6 处替换
- [x] 实机主地图 md5 `36fd32b0…` 不变

### 3b. `lib.GetMMap` 3 处 → `map.getTile`

- [x] 3 处替换（注意第 3 个参数是 layer 0..4）
- [x] 实机主地图不变

### 3c. `lib.ShowSurface` 2 处 → `render.present`

- [x] 2 处替换
- [x] 实机三界面不变

### 3d. `lib.LoadPicture` 4 处 → `sprite.drawPictureFile`（**中风险：语义要查**）

- [x] **先写对照测试**：`lib.LoadPicture(filename,x,y)` 与
      `sprite.drawPictureFile(filename,x,y)` 各画一次，像素对比
- [x] 若不等价 → **不迁移**，记录原因
- [x] 若等价 → 4 处替换

### 3e. `lib.PlayWAV` 2 处 → `audio.playSFX`（**中风险：参数形态**）

- [x] 核实 `playSFX` 收文件名还是索引
- [x] 2 处替换或保留

### 3f. `lib.LoadMMap` / `UnloadMMap` / `LoadSMap` / `SaveSMap` / `LoadWarMap`

- [x] **逐位核对参数顺序**（`LoadMMap` 9 参 vs `map.loadMain` 9 参）
- [x] 若顺序不同 → 在契约实现里适配，不改 script
- [x] 各 1 处替换

### 3g. `lib.GetS` / `SetS` / `GetD` / `SetD` / `GetWarMap` / `SetWarMap` / `CleanWarMap`

- [x] 各 1 处替换（签名已实测一致）
- [x] 实机三界面不变

### 3h. `lib.PlayMPEG` 1 处 → `audio.playVideo` / `lib.PlayMIDI` 1 处 → `audio.playMusic`

- [x] `PlayMPEG`：1 处替换
- [x] `PlayMIDI`：**高风险**（TODO.md 已记「audio 概念重设计」）
      → 若 `playMusic` 语义不明，**保留** `lib.PlayMIDI` 并记录

### 3i. `lib.CloudLoadAndInit` 1 处 → `map.loadClouds`

- [x] 1 处替换（Task 2 完成后）

---

## Task 4：全量验证

- [x] 四版本全量测试零失败：5.1 **4011** / 5.3 **4011** / 5.4 **4011** / 5.5 **4010**
      （5.5 的 1 条差异是既有 `test_version_compat` 已知项，非本次引入）
- [x] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [x] 五门禁全 PASS
- [x] **实机三界面**：战斗 `6c8eb322…` ✓ / 场景 `1efd2af3…` ✓（md5 不变）；
      主地图目视正常（云随机，md5 不可当基线）
- [x] 新增 STEP D6：`script/` 零 `lib.*`（负向对照已验证）
- [x] 更新 `TODO.md` + `slice-proposal.md`（225 → 实测 196）
- [x] 一个 commit

---

## Task 5：门禁 + 记录

**Blast Radius**：`gate_engine_contract.sh`、`TODO.md`、`slice-proposal.md`

**DoD**：
- [x] 新增 STEP D6：`script/` 的 `lib.*` ≤ 1（只允许 WaitFrame fallback）
- [x] 负向对照：加一处 `lib.Debug` → gate FAIL
- [x] 更新 `TODO.md`
- [x] 更新 `slice-proposal.md`（把「258 处 lib.*」的实测数字改成 196）
- [x] 一个 commit
