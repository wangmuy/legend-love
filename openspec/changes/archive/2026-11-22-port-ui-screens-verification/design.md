# Design: port-ui-screens-verification

## ADR-PORT-025：「三个界面不可达」是**误判**，实测三个里两个可达

### Context

`engine-portability` 的收尾记录（`change-manifest` / TODO 的口径）说：

> 物品栏、人物状态、存档界面 —— 这些路径的绘制已迁移但没截图验证
> （`Menu_Thing` / `ShowPersonStatus` 在事件驱动下不可达，只有 `Cal_PicClip` 是活的）。

本轮实机验证（2026-11-21，LÖVE 11.5，`--shot=` + `--keys=` 驱动）：

| 界面 | 结论 | 证据 |
|------|------|------|
| 物品菜单 | **可达** | ESC → 物品（第 3 项）→ `item-menu.png` |
| 物品格 | **可达** | 再选「全部物品」→ `item-grid.png`（酒瓶图标 ×3 + 名称/说明/页码）|
| 人物状态 | **可达** | ESC → 状态（第 4 项）→ `person-status.png`（两列属性 + 头像）|
| 存档 | **SMAP 下不可达** | 主菜单「系统」在 `GAME_SMAP` 被置灰 |

存档不可达**不是**架构问题，是**原版行为**：

```lua
-- jymain_async.lua:47-48（与 script/jymain.lua:770-773 逐字一致）
if JY.Status == GAME_SMAP then
    menu[5][3] = 0     -- 离队
    menu[6][3] = 0     -- 系统 ← 存档入口在这里
end
```

原版就不许在子场景存档/读档（避免在小场景里存成半状态）。
所以要验证存档界面，必须**先走出屋子回主地图**。

### Decision

- 三个「已迁移但没验证」的界面里，**两个（物品、状态）本轮已捕获基线**
- 存档界面**必须**在 `GAME_MMAP` 下验证；本 change 负责补这一张
- 收尾记录里的「不可达」陈述 SHALL 更正为「两个可达、一个需在主地图」

### Consequences

**Positive**：三个界面不再是「没验证的灰区」；`docs/screenshots/README.md` 有硬判据
**Negative**：存档界面的验证路径依赖「走出屋子」这个前置，且路上可能遇敌
（缓解：用固定 `--keys` 路径 + 必要时多次跑；若仍不行，用 `LoadRecord` 直接进主地图）

## ADR-PORT-026：`ShowPersonStatus_sub` 的 27 处绘制必须搬 framework

### Context

```lua
-- framework/person_status_async.lua:217
ShowPersonStatus_sub(id, page)

-- script/jymain.lua:934
function ShowPersonStatus_sub(id,page)
    DrawBox(...)                     -- 1 处
    DrawString(...) × 26             -- 26 处
end
```

即 **framework → script → 全局绘制**，与 `port-script-decoupling` 要消除的
依赖方向完全一样。但 gate STEP F 的白名单是这 8 组：

```
DrawString|DrawBox|DrawStrBox|DrawStrBoxYesNo|DrawStrBoxWaitKey|Cls|ShowScreen|
ShowMenu|ShowMenu2|WaitKey|TalkEx|GetMyPic|AddMyCurrentPic|SceneCanPass|
PlayMIDI|PlayMPEG|FillColor|DrawRect
```

`ShowPersonStatus_sub` **不在里面** —— gate 只查「直接调 `DrawString`」的形态，
`framework/person_status_async.lua` 调的是**另一个 script 全局**，
于是「framework 零 script 全局」这条 DoD 是靠白名单漏掉才成立的。

这与 `port-map-render-native` 发现的「`drawScene` 零消费者」是同类问题：
**判据集合没盖住真实调用的那一层**。

### Decision

1. 新建 `framework/status_page.lua`：`draw(id, page, layout)`，内部**只**调 `RenderFacade`
2. `person_status_async.draw()` 改调 `StatusPage.draw`
3. `script/jymain.lua` 的 `ShowPersonStatus_sub` 保留为薄包装（调 `StatusPage.draw`），
   因为 `War_StatusMenu` 等老路径可能还调它
4. gate STEP F 扩判据：新增 `ShowPersonStatus_sub|ShowPersonStatus|SelectTeamMenu|Menu_Thing`

### 为什么几何必须逐字搬

`PersonStatusAsync.layout()` 已经硬编码了同一个公式（鼠标命中要用）：

```lua
w = 18*size + 15
h = 13*(size + CC.PersonStateRowPixel) + 10
dx = (CC.ScreenW - w)/2, dy = (CC.ScreenH - h)/2
```

若 `status_page.lua` 用不同公式，会出现「看到的框」与「点到的框」不一致。
**搬的时候必须让两处共用一个来源**（`StatusPage.layout()`，`PersonStatusAsync.layout()`
改为转调它）。

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 把 `ShowPersonStatus_sub` 整体搬到 script 的工具模块 | 它仍在 script 层，framework 照样反向依赖 |
| 只在 gate 白名单里加 `ShowPersonStatus_sub` 放行 | 把缺陷写进门禁 = 永久掩盖 |
| 删掉 `ShowPersonStatus_sub` | `War_StatusMenu`（script 侧）与旧路径还可能调它 |

## ADR-PORT-027：界面基线必须区分「有随机数」与「无随机数」

### Context

`docs/screenshots/README.md` 已记录：主地图的 md5 **不稳定**，因为
`lib.CloudCreateOnSide` 用 `math.random` 生成 60 朵云，且
`JYMainAdapter.init` 里有 `math.randomseed(os.time())`。

新捕获的三张界面：

| 图 | 有随机数？ | md5 可用作硬判据？ |
|----|-----------|------------------|
| `item-menu.png` | 否（菜单项固定） | **是** |
| `item-grid.png` | 否（但依赖存档物品：3 个醉生梦死酒） | **是**（前提：用同一新档） |
| `person-status.png` | **是**（属性是 `Rnd()` 生成的！） | **否** |

`person-status.png` 的属性值（内力 21 / 攻击 21 / 防御 25 / 轻功 21 …）
来自 `generateRandomAttributes()` 的 `Rnd()`，每次开局不同。
⇒ 状态页与主地图一样，**md5 不可当基线**，只能目视 + 断言「有框、有文字、有头像」。

### Decision

`docs/screenshots/README.md` 的基线表新增一列「稳定判据」，三类：

1. **逐字节稳定**（无随机数）：场景 / 战斗 / 物品菜单
2. **依赖存档数据**（固定新档才稳定）：物品格
3. **不稳定**（随机数）：主地图、人物状态 → 目视 + 结构断言

## Negative Constraints

- **不得**改动状态页的视觉（字体、间距、行数）
- **不得**把 `ShowPersonStatus` 的**阻塞循环**搬 framework（那是游戏流程）
- **不得**让 `PersonStatusAsync.layout()` 与 `StatusPage.layout()` 各写一份公式
- **不得**为了「让存档界面可达」而修改 `GAME_SMAP` 下的菜单置灰逻辑（那是原版行为）

## Review Checklist

- [ ] `framework/*.lua` 对 `ShowPersonStatus_sub` 的调用 = 0（gate STEP F 扩判据后）
- [ ] `status_page.lua` 的几何公式与 `PersonStatusAsync.layout()` 同源
- [ ] `status_page.lua` 零 `love.*` / 零 `require engine-*` / 零 `JY.*`（除读取传入参数）
- [ ] `person-status.png` 不被当 md5 基线（README 写清）
- [ ] 战斗内状态页同样走 `StatusPage.draw`
