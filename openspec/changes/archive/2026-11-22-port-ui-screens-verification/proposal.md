# Change Proposal: port-ui-screens-verification — 三个"活但没验证"界面的实机基线

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）
> 前置: 无（可独立开工）；但 `port-compat-layer-removal` / `port-legacy-picture-removal`
> 完成后需回归本 change 的基线

## Why

`engine-portability` 的收尾记录里写：

> 实机未覆盖的界面：物品栏、人物状态、存档界面 —— 这些路径的绘制已迁移
> 但没截图验证（`Menu_Thing` / `ShowPersonStatus` 在事件驱动下不可达，
> 只有 `Cal_PicClip` 是活的）。

**本轮实测推翻了「不可达」这一半**（2026-11-21）：

| 界面 | 实际能否到达 | 本轮证据 |
|------|-------------|---------|
| 物品菜单（6 个分类） | **可达** | `item-menu.png`（实机截图） |
| 物品格 + 名称/说明框 + 页码 | **可达** | `item-grid.png`（实机截图） |
| 人物状态页（2 页、上下换人） | **可达** | `person-status.png`（实机截图） |
| 存档界面 | **在 SMAP 下不可达** | 主菜单的「系统」项在 `GAME_SMAP` 被置灰（`jymain_async.lua:47-48`），存档入口藏在「系统」里 |

到这三个界面的路径（都是**事件驱动**，非原版阻塞式）：

```
ESC → startMenuCoroutine → JyMainAsync.MMenuCoroutine
                                    ├─ Menu_Thing  → ItemAsync.SelectThingAsync（协程）
                                    │                    └─ ItemAsync.draw（每帧由 EventBridge 调）
                                    └─ Menu_Status → SelectTeamMenuAsync → PersonStatusAsync.ShowStatusCoroutine
                                                          └─ PersonStatusAsync.draw → ShowPersonStatus_sub
```

### 但截图暴露了 3 个**真问题**

**① 人物状态页的绘制**仍是 script 全局（`ShowPersonStatus_sub`）

```
game/framework/person_status_async.lua:217:  ShowPersonStatus_sub(id, page)
game/script/jymain.lua:934:                  function ShowPersonStatus_sub(id,page)
```

该函数内部有 **26 处 `DrawString` + 1 处 `DrawBox`**（仍走 script 全局），
而 `port-script-decoupling` 的 gate STEP F 白名单**只覆盖 8 组绘制函数**，
`ShowPersonStatus_sub` 不在这 8 组里 —— 于是「framework 零 script 全局」这条
DoD 是靠白名单**漏掉**才成立的。这与 `port-map-render-native` 记录的
「`drawScene` 零消费者」属同类：门禁判据没盖住。

**② 状态页在战斗里也走同一条路径**

`script/battle/battle_flow_coroutines.lua:1398` 的 `War_StatusMenuCoroutine`
也调 `PersonStatusAsync.ShowStatusCoroutine` → 同样落到 `ShowPersonStatus_sub`。

**③ 存档界面必须在主地图（`GAME_MMAP`）才能验证**

`GAME_SMAP` 下「系统」被置灰（与 script 版 `jymain.lua:770-773` 一致，是原版行为）。
所以本轮在开场小场景里怎么按键都到不了存档界面 —— 需要**先走出屋子**回主地图。

## In Scope

1. **补 3 个界面的实机基线**（含截图参数、md5 记录）：
   - 物品菜单 / 物品格 / 人物状态 —— 本轮已捕获，归档为基线
   - 存档界面 —— **必须在主地图**，本轮未捕获，需补
2. **把 `ShowPersonStatus_sub` 的绘制搬进 framework**：
   - 新建 `framework/status_page.lua`（纯绘制，只调 `RenderFacade`）
   - `person_status_async.lua` 改调它；`script/jymain.lua` 的原函数保留为薄包装
     （`ShowPersonStatus` 的阻塞循环仍在 script，但绘制部分搬走）
3. **gate STEP F 补 4 个判据**：
   - `ShowPersonStatus_sub` / `ShowPersonStatus` / `SelectTeamMenu` / `Menu_Thing`
     加入白名单**目标集**（当前它们能通过 gate 是因为根本不检查）
4. **存档界面的文案与几何与旧版逐字对齐**（只在主地图可达，需在 `GAME_MMAP` 下验证）
5. **`docs/screenshots/README.md` 增加 4 行基线表**（含「必须主地图」的标注）

## Out of Scope

```
✗ 重做这三个界面的视觉设计
✗ 触摸/手柄在三个界面上的可用性（归 input-action-layer / 鼠标 slice）
✗ `EnableMusic` / 音频（归 port-audio-semantics）
✗ 存档格式与 SaveRecord/LoadRecord 的数据逻辑（只验证绘制与可达性）
✗ 主角状态页的「页数 2」是否该增加（原版就是 2 页）
```

## Acceptance Criteria

### Scenario: 三个界面有实机基线

- **GIVEN** `docs/screenshots/` 与 README 里的参数
- **WHEN** 按参数重新截图
- **THEN** 物品菜单 / 物品格 / 人物状态三张图与基线一致（逐字节）
      （注：三者都无云层、无随机数 → md5 稳定，可当硬判据）

### Scenario: 存档界面可验证

- **GIVEN** 处于 `GAME_MMAP`
- **WHEN** ESC → 系统 → 保存进度
- **THEN** 出现「进度一/二/三」菜单（截图归档）

### Scenario: framework 不再直接画状态页

- **WHEN** 执行 gate STEP F（补白名单后）
- **THEN** `framework/*.lua` 对 `ShowPersonStatus_sub` 的调用为 0，
      改由 `framework/status_page.lua` 内部只调 `RenderFacade`

### Scenario: 战斗内状态页零回归

- **GIVEN** 进入战斗
- **WHEN** 战斗菜单选「状态」
- **THEN** 状态页画出（与 `person-status.png` 同源数据，md5 可比）

## 风险

| 风险 | 缓解 |
|------|------|
| 状态页绘制搬家后字体/间距漂移 | `status_page.lua` 的几何公式逐字搬（`18*size+15` / `13*h+10`）；截图 md5 比对 |
| 存档界面仍到不了（走出屋子有随机遇敌） | 用 `--keys` 固定路径，多试几次；实在不行用 `--battle` 之外的调试入口（记 TODO） |
| 物品截图依赖存档数据（`R0` 存档含 3 个醉生梦死酒） | 基线图与存档绑定；README 写明「用新档开局」 |
