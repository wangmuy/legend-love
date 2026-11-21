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

## Task 2：新增 `map.loadClouds` 契约

**Blast Radius**：`engine_api.lua`、4 个引擎实现

**DoD**：
- [ ] `map.loadClouds(idxFile, grpFile)` 契约（4 引擎）
- [ ] LÖVE 实现 = `lib.CloudLoadAndInit`（它内部逐像素烘焙，属 sprite 子系统）
- [ ] MUD/Web 空实现
- [ ] 契约数 88 → **89**
- [ ] 单测：4 引擎都有
- [ ] 一个 commit

---

## Task 3：逐个核实 31 处的语义等价

**Blast Radius**：同上 + `engine_love2d.lua`

### 3a. `lib.DrawMMap` 6 处 → `map.drawMain`（低风险，已透明化）

- [ ] 6 处替换
- [ ] 实机主地图 md5 `36fd32b0…` 不变

### 3b. `lib.GetMMap` 3 处 → `map.getTile`

- [ ] 3 处替换（注意第 3 个参数是 layer 0..4）
- [ ] 实机主地图不变

### 3c. `lib.ShowSurface` 2 处 → `render.present`

- [ ] 2 处替换
- [ ] 实机三界面不变

### 3d. `lib.LoadPicture` 4 处 → `sprite.drawPictureFile`（**中风险：语义要查**）

- [ ] **先写对照测试**：`lib.LoadPicture(filename,x,y)` 与
      `sprite.drawPictureFile(filename,x,y)` 各画一次，像素对比
- [ ] 若不等价 → **不迁移**，记录原因
- [ ] 若等价 → 4 处替换

### 3e. `lib.PlayWAV` 2 处 → `audio.playSFX`（**中风险：参数形态**）

- [ ] 核实 `playSFX` 收文件名还是索引
- [ ] 2 处替换或保留

### 3f. `lib.LoadMMap` / `UnloadMMap` / `LoadSMap` / `SaveSMap` / `LoadWarMap`

- [ ] **逐位核对参数顺序**（`LoadMMap` 9 参 vs `map.loadMain` 9 参）
- [ ] 若顺序不同 → 在契约实现里适配，不改 script
- [ ] 各 1 处替换

### 3g. `lib.GetS` / `SetS` / `GetD` / `SetD` / `GetWarMap` / `SetWarMap` / `CleanWarMap`

- [ ] 各 1 处替换（签名已实测一致）
- [ ] 实机三界面不变

### 3h. `lib.PlayMPEG` 1 处 → `audio.playVideo` / `lib.PlayMIDI` 1 处 → `audio.playMusic`

- [ ] `PlayMPEG`：1 处替换
- [ ] `PlayMIDI`：**高风险**（TODO.md 已记「audio 概念重设计」）
      → 若 `playMusic` 语义不明，**保留** `lib.PlayMIDI` 并记录

### 3i. `lib.CloudLoadAndInit` 1 处 → `map.loadClouds`

- [ ] 1 处替换（Task 2 完成后）

---

## Task 4：全量验证

- [ ] 四版本全量测试零失败（记录断言数）
- [ ] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [ ] 五门禁全 PASS
- [ ] **实机三界面 md5 全部不变**
- [ ] 一个 commit

---

## Task 5：门禁 + 记录

**Blast Radius**：`gate_engine_contract.sh`、`TODO.md`、`slice-proposal.md`

**DoD**：
- [ ] 新增 STEP D6：`script/` 的 `lib.*` ≤ 1（只允许 WaitFrame fallback）
- [ ] 负向对照：加一处 `lib.Debug` → gate FAIL
- [ ] 更新 `TODO.md`
- [ ] 更新 `slice-proposal.md`（把「258 处 lib.*」的实测数字改成 196）
- [ ] 一个 commit
