---
status: active
created: 2026-06
---

# Epic: Web MUD 文字版 — 金庸群侠传

## 愿景

使用 Fengari 在静态网页上运行金庸群侠传的 Lua 游戏逻辑，xterm.js 作为终端界面，实现纯文字 MUD 风格的单机游戏体验。所有游戏脚本（framework + 1018 个 oldevent）不经修改直接运行，数据从原版二进制提取为 JSON 精简包。产出可直接部署为静态页面的完整版本，也为未来对接网络 MUD 服务器打下基础。

## 架构概述

```
game/
├── framework/*.lua
├── script/*.lua
└── engine-web/
    ├── index.html + xterm.js
    ├── engine_web.lua
    ├── data_loader.lua
    ├── data-web/*.json
    └── ...
```

## 交互设计

- **纯命令输入**：所有输入为 `命令 参数...`，无斜杠前缀
- **菜单选择**：`choose N` 选择显示的菜单项
- **上下文解析**：可用命令集合取决于当前 `JY.Status`（GAME_MMAP / GAME_SMAP / GAME_WMAP）
- **sleep**：在文字版中等价于 `yield + return`，让出控制权给其他协程

## Vertical Slices

### Slice 1: 数据提取管线

将原版二进制数据提取为 Web 版需要的 JSON 精简包。

**业务价值**：消除对原版 .grp/.idx 二进制数据的依赖，为所有后续 slice 提供数据基础。

**命令（本 slice 不涉及游戏交互，无命令）**

| 产出文件 | 内容 | 原始来源 |
|----------|------|----------|
| `game/engine-web/data-web/dialogues.json` | 对话文本（2977 条） | `oldtalk.grp/.idx` |
| `game/engine-web/data-web/scenes.json` | 场景元数据（名称、出口、入口坐标、进入条件） | `ranger.grp`（Scene_S 段） |
| `game/engine-web/data-web/chars.json` | 人物数据（187 人，67 字段） | `ranger.grp`（Person_S 段） |
| `game/engine-web/data-web/items.json` | 物品数据（199 物，54 字段） | `ranger.grp`（Thing_S 段） |
| `game/engine-web/data-web/skills.json` | 武功数据（100 武功，38 字段） | `ranger.grp`（Wugong_S 段） |
| `game/engine-web/data-web/entrances.json` | 大地图场景入口坐标 → 场景 ID 映射 | `ranger.grp`（Scene_S 段，外景入口字段） |
| `game/engine-web/data-web/wmap.json` | 遇敌信息（11 战斗地图 + 146 遇敌配置） | `war.sta` + `fight*.grp` + `warfld.*` |
| `game/engine-web/data-web/events.json` | D* 事件定义（16800 条，每场景 200 地砖） | `alldef.grp` |
| `game/engine-web/data-web/config.json` | 基础游戏配置（主角位置、队伍、物品栏） | `ranger.grp` 头部 |
| `game/engine-web/data-web/shops.json` | 商店商品列表（5 个商店，每店 5 个货架） | `ranger.grp`（Shop_S 段） |

> 数据源说明：场景元数据（Scene_S 结构体，62 字节/场景）只存储在 ranger.grp 中。`allsin.grp` 是场景贴图数据（64×64×6 层 int16），`mmap.grp` 是瓦片图形数据（RLE/PNG），均不包含结构化元数据。chars/items/skills 数据在 DOS 原版中嵌于可执行文件，Love2D 项目将其提取到 ranger.grp，没有其他独立源文件。参见 Slice 1 design.md 第 4 节"数据源架构辨析"。

**DoD**：在 Love2D 环境中运行提取脚本 `tools/extract_web_data.lua`，产出所有 JSON 文件。每份 JSON 可以被 Lua 直接 `require` 加载。JSON 总大小 ≤ 15MB。

**影响领域**：binary-data, devops
**依赖**：无

---

### Slice 2: 前端骨架 + EngineAPI Web 实现

搭建静态网页壳子，实现 `engine_web.lua` 的 45 个 EngineAPI 函数（13 个模块），加载精简数据包。

**业务价值**：建立完整的运行环境——浏览器里能跑 Lua 游戏脚本了。

**命令**：无（本 slice 只搭建引擎，不进入游戏逻辑）

**核心组件**：

| 组件 | 说明 |
|------|------|
| `index.html` | 页面骨架：输出区 (#output, xterm.js) + 输入区 (#input, `<input>`) |
| `index.js` | Fengari bootstrap、JS ↔ Lua 桥接（使用 fengari.load()，lauxlib 在 0.1.4 不可用）、事件队列、xterm.js 配置（含 FitAddon） |
| `engine_web.lua` | EngineAPI 45 个函数的 Web 实现 |

**engine_web.lua 关键映射**：

| EngineAPI 模块 | Web 实现 |
|---------------|----------|
| `render.text(x, y, str, color)` | 转换为 ANSI 转义码追加到缓冲区 |
| `render.fillRect` / `rectOutline` | ANSI 背景色模拟矩形，或忽略 |
| `render.drawBackground` | 清屏 + ANSI 背景色 |
| `render.present` | 缓冲区内容 → `JS: terminal.write(ansiString)` |
| `render.presentAndWait` | `present()` + yield（无等待） |
| `sprite.*` | 全部 no-op |
| `map.*` | 全部 no-op（文字版不需要贴图渲染） |
| `input.getKey` | 返回事件队列中的下一个按键 |
| `input.waitForKey` | yield，等待用户输入事件入队 |
| `audio.*` | 全部 no-op |
| `time.sleep` | yield + return（无真实时间等待） |
| `time.getTime` | `os.clock()` |
| `file.*` | 从预加载的 JSON 数据表中读取，无磁盘 I/O |
| `script.load` | 从预加载的 script 表加载，或 fetch |
| `font.*` | 返回存根（字体由 xterm.js 处理） |
| `color.*` | 正常实现（用于 ANSI 色彩转换） |
| `debug.log` | 通过 JSBridge.write 输出到 xterm 终端 |
| `coroutine.*` | 正常实现（Fengari 原生支持协程） |
| `app.quit` | 无操作（浏览器不能自己退出） |

**事件队列模型**：

```
requestAnimationFrame 循环:
  │
  ▼
processEventQueue():
  ├─ 输入事件 → 恢复等待输入的协程
  ├─ 定时事件 → CoroutineScheduler:update()
  │              └─ sleep 的 yield → 立即恢复
  └─ 渲染事件 → ANSI 缓冲区 → xterm.js
```

**DoD**：`love.game()` 等价操作在 Web 版变为：打开 `index.html` → xterm.js 显示引擎初始化完成 → 加载 JSON 数据成功 → Lua VM 就绪。

**影响领域**：engine, event-bridge, render, input
**依赖**：Slice 1

---

### Slice 3: 大地图漫游

加载 framework + script 进入游戏，实现大地图 [GAME_MMAP] 的文字版交互。

**业务价值**：用户在浏览器里能玩到第一个完整的游戏环节——从开始菜单到大地图。

**本 slice 覆盖的游戏状态**：`GAME_START` → `GAME_MMAP`

**交互流程**：
```
打开页面
  ↓
显示欢迎画面
  ↓
文字版开始菜单: 1.新游戏  2.读档  3.退出
  > choose 1
  ↓
属性选择: 生命/攻击/防御/轻功/资质 ...
   确认（choose 1）或重掷（choose 2）
  ↓
进入大地图 [GAME_MMAP]
  > look          ← 查看当前位置、坐标、方位、附近场景
  > list          ← 选择场景前往
  > quit          ← 退出游戏返回开始菜单
  > help          ← 显示当前状态可用命令
  ↓
进入场景 [GAME_SMAP]（场景在本 slice 只做基础入口）
  > look
   显示场景模板描述
  > exits
   显示出口编号列表
  > go <编号>
   通过出口编号离开场景（或回到大地图）
  > leave
   离开场景回到大地图
```

**命令列表（MMAP 状态）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `list` | 无 | 列出可去的场景列表并选择前往（从 `entrances.json` 生成） |
| `look` | 无 | 查看当前位置、坐标、方位、相对中心位置和附近场景 |
| `quit` | 无 | 退出当前游戏，返回开始菜单（二次确认） |
| `help` | `[命令名]` | 无参=列出所有可用命令，有参=查看命令用法 |
| `choose` | `<编号>` | 选择菜单项 |

> **注**：`go <场景名>` 已从 MMAP 移除（与 `list` 功能重叠），`where` 已合并到 `look`。

**命令列表（SMAP 状态 — 本 slice 最小实现）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `look` | 无 | 场景模板描述（场景名 + 描述 + NPC + 出口） |
| `exits` | 无 | 显示出口编号列表 + 目标场景名 |
| `go` | `<编号>` | 按出口编号离开场景（`go 1` = 第一个出口） |
| `leave` | 无 | 离开场景回到大地图 |
| `choose` | `<编号>` | 选择菜单项 |

**DoD**：用户完成"打开页面 → 新游戏 → 属性分配 → 大地图 → list 查看场景 → choose 进入 → 进入场景 → look → exits → go/leave → 回到大地图"的完整流程。

**影响领域**：game-states, async-main, jymain-adapter
**依赖**：Slice 2

---

### 架构重构: Web Worker 引擎隔离

将 Fengari Lua VM 从浏览器主线程移入 Web Worker，使 Lua 执行不阻塞 UI。

**业务价值**：加载和运行 Lua 时界面不卡顿；架构更接近 Love2D 的渲染/逻辑分离，也更容易映射到真正 MUD server。

| 字段 | 值 |
|------|-----|
| Change | `openspec/changes/web-worker-engine/` |
| 内容 | `worker.js`, 简化 `index.js`, 调整 `index.html` |
| 类型 | 架构重构 |
| 依赖 | Slice 3（搬运已有代码，不依赖新功能） |
| 阻塞 | Slice 4（后续 slice 受益于不卡的 UI） |

**影响领域**：all（跨切面）

---

### 横向: 事件系统集成

将事件执行器（EventExecutor）和全部 67 个 `instruct_*` 函数集成到 Web MUD，使 1018 个 oldevent 脚本不经修改即可运行。

**业务价值**：NPC 对话不再是"系统不可用"——玩家可以与软体娃娃对话、触发剧情事件，驱动游戏流程。

| 字段 | 值 |
|------|-----|
| Change | `openspec/changes/slice-event-system-integration/` |
| 子 change | event-executor-loader, instruct-stubs, event-data-access, event-flow-tests |
| 类型 | 横向 slice（跨架构层） |
| 依赖 | Slice 4（场景交互菜单已就绪） |
| 不阻塞 | Slice 5（战斗系统可以并行开发） |

**影响领域**：framework, event-executor, async-globals, script-loader

---

### Slice 4: 场景交互

完善场景 [GAME_SMAP] 内的交互——NPC 对话、事件触发、物品操作。

**业务价值**：场景不再是静态文本，玩家可以与 NPC 和物品互动，驱动游戏剧情。

**命令列表（SMAP 状态）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `look` | 无 | 显示场景描述 + NPC/物品/出口编号列表 |
| `choose` | `<编号>` | 选择交互对象（NPC→对话/查看/给予，物品→拾取/查看，出口→传送） |
| `exits` | 无 | 出口列表 |
| `leave` | 无 | 离开场景回到大地图 |
| `rest` | 无 | 休息恢复体力（house=免费，inn=付费） |
| `help` | `[命令名]` | 显示帮助 |

> 注：SMAP 已统一为菜单驱动交互（`look` → `choose N` → 子菜单 → `choose N`）。`talk`/`take`/`give`/`go` 直接命令已移除，全部通过菜单流触发。

**技术实现**：

```
talk 胡斐
  │
  ├─ 找到场景中胡斐对应的事件 ID
  ├─ 执行 EventExecutor.startEvent(eventId, flag)
  │    ├─ async_globals 安装替换
  │    ├─ 加载 oldevent_N.lua
  │    ├─ 在协程中执行事件脚本
  │    │    ├─ instruct_1(talkId, headId) → 输出对话文本
  │    │    ├─ instruct_0() → 清屏
  │    │    └─ 如果有菜单 → 显示选项 → choose N
  │    └─ 事件结束
  └─ 回到场景
```

**事件脚本执行时的输入处理**：
- 对话中的 `WaitKey` → 等待用户输入任意文字 + 回车
- 对话中的 `ShowMenu` → 显示选项 → `choose N` 选择
- 事件中的 `instruct_32`（给物品）→ 直接输出"获得 xx"

**场景状态管理**：
```lua
-- 场景动态状态
_G.sceneState = {
    ["heke_inn"] = {
        npc = { [70] = { present = false } },  -- 胡斐离队后不在客栈了
        items = { [47] = { count = 0 } },      -- 白酒被拿走了
    }
}
```

**DoD**：在场景中与 NPC 对话，触发事件脚本，获得物品，事件改变场景状态后再次 `look` 能看到变化。

**影响领域**：event-executor, async-dialog, legacy-events
**依赖**：Slice 3

---

### Slice 5: 战斗系统

实现文字版 1D 线性距离战斗。

**业务价值**：游戏的核心战斗可以玩了，遇敌不再是死路。

**交互流程**：
```
遇敌 / 触发战斗
  ↓
进入 [GAME_WMAP]
  > look
  战场态势（我方回合）:
    我方: 胡斐 HP 150/150 位置 0 ✓     ← ✓ = 可行动
          田伯光 HP 120/120 位置 1 ✓
    敌方: 阎基 HP 80/80   位置 5
    距离: 5步

  --- 第 1 步：选队友 ---
  > choose 1
  选择行动队友:
    1. 胡斐 (HP:150, 位置 0) ★主动出击  ← ★=行动高优先
    2. 田伯光 (HP:120, 位置 1) ★
  （单人战斗自动跳过此步）

  --- 第 2 步：选行动 ---
  > choose 1 (胡斐)
  胡斐 行动:
    1. 攻击              ← 选目标 → 执行
    2. 武功              ← 选武功 → 选目标 → 执行
    3. 物品              ← 选物品 → 选目标 → 执行
    4. 防御              ← 直接执行（本回合待机）
    5. 移动              ← 走近/远离 → 执行
    6. 查看状态           ← 选角色查看

  > choose 2
  武功:
    1. 苗家剑法 (Lv5) 威力:450 范围:0-2步  ❌ 距离不足
    2. 胡家刀法 (Lv3) 威力:280 范围:0-2步  ❌ 距离不足
    3. 暗器 (Lv1)    威力:80  范围:1-4步  ✅
  > choose 3

  --- 第 3 步：选目标 ---
  选择目标:
    1. 阎基 (HP:80, 距离5步) ✅
  > choose 1
  胡斐使出暗器！伤害 15！
  阎基 HP 80 → 65
  （胡斐行动结束，进入田伯光回合或敌回合）

  > 
  阎基的回合:
  阎基走近胡斐，距离 5 → 3
  阎基攻击胡斐！伤害 12！
  胡斐 HP 150 → 138
  （阎基行动结束，进入我方回合）

  > look
  我方回合:
    胡斐 HP138/150 ✓     ← 胡斐可行动
    田伯光 HP120/120 ✓   ← 田伯菲可行动
  > choose 1 (田伯光)
  田伯光 行动:
    1. 攻击
    2. 武功
    ...
  战斗流程: 选队友 → 选行动 → 选目标 → 执行 → 下个队友/敌回合
```

**命令列表（WMAP 状态）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `look` | 无 | 战场态势 + 行动菜单 |
| `choose` | `<编号>` | 选择行动（攻击/武功/物品/防御/移动/查看） |

> 注：WMAP 采用菜单驱动交互，与 SMAP 一致。所有战斗操作通过 `look` → `choose N` → 子菜单完成，无需记忆复杂命令。`move`/`attack`/`wugong`/`defend`/`item`/`status` 作为快捷命令保留，但不做主要交互路径。|

**1D 线性距离系统**：

```
战场距离模型:

  位置 0       位置 5         位置 10
    │           │               │
    ├─ 我方 ────┼──── 敌方 ────┤
    │  胡斐     │   阎基         │
    │  田伯光   │   苗人凤       │
    └──────────┴──────────────┘
          距离 5步

移动步数 = floor(轻功 / 30) + 1 (2~6步)
移动消耗一回合行动，移动后可攻击

武器攻击范围 (1D):
  拳掌: 0-1步    剑法: 0-2步
  刀法: 0-2步    特殊: 0-3步
  暗器: 1-4步    医疗: 0-1步

敌我距离逻辑:
  move 阎基 3  → 胡斐向阎基走近 3 步，距离减 3
  move 阎基 -2 → 胡斐远离阎基 2 步，距离加 2
```

**DoD**：在大地图触发战斗，完成移动 → 攻击/武功 → 使用物品 → 胜利的完整战斗流程。战斗失败返回大地图。

**影响领域**：async-battle, war-async
**依赖**：Slice 4

---

### Slice 6: 角色管理与完整体验

实现角色管理系统和所有跨状态通用命令，全部采用菜单驱动交互。

**业务价值**：玩家可以管理队伍、装备、存档，游戏体验完整。

**交互流程**（菜单驱动）：
```
MMAP/SMAP 状态:
  > look
  当前位置: ...
  附近场景: ...
  > choose 1 (或对应编号)
    1. 查看状态      ← 角色状态/背包/装备
    2. 队伍管理      ← 查看队员/调整
    3. 存档/读档     ← 保存/读取进度
    4. 系统设置      ← 帮助/关于
```

**命令列表（跨状态通用）**：

| 命令 | 可用状态 | 说明 |
|------|---------|------|
| `look` | MMAP, SMAP | 查看当前状态 + 交互选项（含状态/背包/存档入口） |
| `choose` | MMAP, SMAP | 选择菜单项：角色状态/背包/队伍/存档 |
| `help` | 全部 | 显示当前状态可用命令 |

> 注：所有角色管理功能通过菜单驱动，无需记忆复杂命令。`look` 显示主菜单，`choose N` 进入子菜单（状态/背包/队伍/存档）。

**存档系统**：使用 IndexedDB（浏览器持久化 + 同步 saveCache 内存缓存），不涉及服务器。

**场景描述增强**：
- 逐步将 Slice 4 的自动模板替换为人工编写的场景描述
- 场景类型专用模板（客栈、山洞、商店、民居、门派、迷宫...）

**DoD**：用户能通过菜单完成查看状态、管理背包、存档读档。游戏基本流程可完整进行。

**影响领域**：async-item, async-person, jymain-async, save-load
**依赖**：Slice 4, Slice 5

---

## Slice 依赖图

```
S1 (数据提取)
  │
  ▼
S2 (前端骨架 + engine_web)
  │
  ▼
S3 (大地图漫游: list/go/look/where)
  │
  ▼
WR (Web Worker 引擎隔离)    ← 架构重构
  │
  ▼
EV (事件系统集成)            ← 横向: oldevent + instruct_*
  │
  ├──────────────┐
  ▼              ▼
S4 (场景交互:     S5 (战斗系统:
    look/choose/      look/choose/
    rest/leave)     攻击/武功/物品)
  │              │
  └──────┬───────┘
         ▼
   S6 (角色管理 + 完整体验:
       status/bag/heal/detox/
       leave/save/load)
```

## 全局验收标准

- [ ] 所有 1018 个 oldevent 脚本不经修改在 Web MUD 中运行
- [ ] 所有 framework 模块不经修改在 Web MUD 中运行（通过 EngineAPI 适配）
- [ ] JSON 数据包总大小 ≤ 15MB
- [ ] 单页应用，无需服务器，静态部署可用
- [ ] ANSI 彩色输出（xterm.js 渲染）
- [ ] 存档使用浏览器 IndexedDB 持久化（4 槽位：槽 0 自动 + 槽 1~3 手动）
- [ ] 命令上下文感知——错误状态下的命令给出明确的拒绝提示
- [ ] `sleep` 在文字版中为 yield-only，不消耗真实时间