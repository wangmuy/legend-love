# 三个界面的实机基线与状态页绘制解耦

## ADDED Requirements

### Requirement: REQ-UIV-1 三个界面 SHALL 有实机基线

`docs/screenshots/` SHALL 收录物品菜单、物品格、人物状态三张图，
并在 `README.md` 记录截图参数。

依据（实测 2026-11-21）：三者**都可达**（与 slice 收尾记录的「不可达」相反）。

#### Scenario: 物品菜单可达

- **GIVEN** 处于 `GAME_SMAP`（开场小场景）
- **WHEN** ESC → 主菜单第 3 项「物品」
- **THEN** 出现 6 项分类菜单（全部物品/剧情物品/神兵宝甲/武功秘笈/灵丹妙药/伤人暗器）

#### Scenario: 物品格可达

- **GIVEN** 物品菜单
- **WHEN** 选「全部物品」
- **THEN** 出现名称框 + 说明框 + 3×N 物品格 + 页码（如「1/1」）

#### Scenario: 人物状态可达

- **GIVEN** 主菜单
- **WHEN** 选「状态」→ 选队伍成员
- **THEN** 出现两列属性 + 头像 + 底部提示「左右键翻页，上下键查看其它队友」

### Requirement: REQ-UIV-2 存档界面 SHALL 在 `GAME_MMAP` 下验证

存档入口在「系统」子菜单，而「系统」在 `GAME_SMAP` 下被置灰（原版行为，
`jymain_async.lua:47-48` 与 `script/jymain.lua:770-773` 一致）。
因此存档界面的实机基线 SHALL 在主地图（`GAME_MMAP`）下捕获。

#### Scenario: 子场景不可达（原版行为，不得改）

- **GIVEN** `JY.Status == GAME_SMAP`
- **WHEN** ESC 打开主菜单
- **THEN** 「离队」「系统」两项置灰（`menu[5][3]=0` / `menu[6][3]=0`，逐字保留）

#### Scenario: 主地图可达

- **GIVEN** `JY.Status == GAME_MMAP`
- **WHEN** ESC → 系统 → 保存进度
- **THEN** 出现「进度一/进度二/进度三」菜单（截图归档）

### Requirement: REQ-UIV-3 `ShowPersonStatus_sub` 的绘制 SHALL 搬入 framework

新建 `framework/status_page.lua`，`draw(id, page)` 内部**只**调 `RenderFacade`。
`framework/person_status_async.lua` SHALL NOT 直接调 script 全局
`ShowPersonStatus_sub`。

依据：`script/jymain.lua:934` 的 `ShowPersonStatus_sub` 内有 26 处 `DrawString`
+ 1 处 `DrawBox`，而 framework 调它 = 与 `port-script-decoupling` 要消除的
依赖方向相同。gate STEP F 的白名单没覆盖它，所以 DoD 是靠漏判成立的。

#### Scenario: framework 零 script 全局（补判据后）

- **WHEN** 运行 gate STEP F（白名单新增 `ShowPersonStatus_sub|ShowPersonStatus|SelectTeamMenu|Menu_Thing`）
- **THEN** `game/framework/*.lua` 对这四个的调用 = 0

#### Scenario: 几何公式同源

- **WHEN** 对比 `StatusPage.layout()` 与 `PersonStatusAsync.layout()`
- **THEN** 后者转调前者（不是各写一份）

#### Scenario: 状态页零引擎细节

- **WHEN** 执行 `grep -nE 'love\.|require\("engine' game/framework/status_page.lua`
- **THEN** 命中数 = 0

### Requirement: REQ-UIV-4 界面基线 SHALL 标注「判据类型」

`docs/screenshots/README.md` 的基线表 SHALL 有三类标注：

| 类型 | 含义 | 图 |
|------|------|----|
| 逐字节稳定 | 无随机数、无存档依赖 → md5 可当硬判据 | 战斗、场景、物品菜单 |
| 依赖存档 | 需用同一新档才稳定 | 物品格 |
| 不稳定 | 有随机数 → 只能目视 + 结构断言 | 主地图、人物状态 |

#### Scenario: 状态页不被当 md5 基线

- **WHEN** 读 README
- **THEN** `person-status.png` 明确标注「属性由 `Rnd()` 生成，md5 不稳定」

## Out of Scope

- 三个界面的视觉重设计
- 触摸/手柄在这三个界面的可用性
- 存档数据格式
