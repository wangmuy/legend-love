---
status: active
created: 2026-06
---

# Epic: Web MUD 文字版 — 金庸群侠传

## 愿景

使用 Fengari 在静态网页上运行金庸群侠传的 Lua 游戏逻辑，xterm.js 作为终端界面，实现纯文字 MUD 风格的单机游戏体验。所有游戏脚本（framework + 1018 个 oldevent）不经修改直接运行，数据从原版二进制提取为 JSON 精简包。产出可直接部署为静态页面的完整版本，也为未来对接网络 MUD 服务器打下基础。

## 架构概述

```
浏览器 (static web)
  ┌───────────────────────────────────┐
  │  index.html + xterm.js            │
  │  ┌─────────────────────────────┐  │
  │  │  Fengari (Lua 5.3 VM)       │  │
  │  │                             │  │
  │  │  engine_web.lua             │  │
  │  │   ─ render.* → ANSI 流      │  │
  │  │   ─ input.* → xterm 输入    │  │
  │  │   ─ file.* → fetch JSON     │  │
  │  │   ─ sprite/map/audio → noop │  │
  │  │                             │  │
  │  │  framework/*.lua (不改)      │  │
  │  │  script/*.lua (不改)         │  │
  │  │  data-web/*.json (精简数据)  │  │
  │  └─────────────────────────────┘  │
  │                                    │
  │  JS Bridge:                        │
  │   ─ requestAnimationFrame 驱动     │
  │   ─ 事件队列调度协程               │
  │   ─ Lua → ANSI → xterm.js         │
  └───────────────────────────────────┘
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
| `data-web/dialogues.json` | 对话文本（原版 5000+ 条） | `oldtalk.grp/.idx` |
| `data-web/scenes.json` | 场景结构 + NPC/物品坐标 + 出口 | `allsin.grp/.idx`、`s*.grp/.idx`、`d*.grp/.idx` |
| `data-web/chars.json` | 人物数据（初始状态、属性） | `jyconst.lua` + 二进制验证 |
| `data-web/items.json` | 物品数据 | `jyconst.lua` + 二进制验证 |
| `data-web/skills.json` | 武功数据 | `jyconst.lua` + 二进制验证 |
| `data-web/entrances.json` | 大地图场景入口坐标 → 场景 ID 映射 | `mmap.grp/.idx` |
| `data-web/wmap.json` | 遇敌信息（地图 → 敌人列表） | 原版遇敌配置 |

**DoD**：在 Love2D 环境中运行提取脚本 `tools/extract_web_data.lua`，产出所有 JSON 文件。每份 JSON 可以被 Lua 直接 `require` 加载。JSON 总大小 ≤ 15MB。

**影响领域**：binary-data, devops
**依赖**：无

---

### Slice 2: 前端骨架 + EngineAPI Web 实现

搭建静态网页壳子，实现 `engine_web.lua` 的 37 个 EngineAPI 函数，加载精简数据包。

**业务价值**：建立完整的运行环境——浏览器里能跑 Lua 游戏脚本了。

**命令**：无（本 slice 只搭建引擎，不进入游戏逻辑）

**核心组件**：

| 组件 | 说明 |
|------|------|
| `index.html` | 页面骨架：输出区 (#output, xterm.js) + 输入区 (#input, `<input>`) |
| `index.js` | Fengari bootstrap、JS ↔ Lua 桥接、事件队列、xterm.js 配置 |
| `engine/engine_web.lua` | EngineAPI 37 个函数的 Web 实现 |
| `engine/web_bridge.lua` | ANSI 输出桥接、输入路由、事件队列 |

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
| `debug.log` | 输出到浏览器 console |
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
属性选择: 1.力道(30) 2.悟性(30) ...
  按 MUD 方式分配属性，确认
  ↓
进入大地图 [GAME_MMAP]
  > list          ← 列出可去场景
  > look          ← 查看当前位置描述
  > where         ← 查看当前坐标和方位
  > go 河洛客栈    ← 直接传送
  > help          ← 显示当前状态可用命令
  ↓
进入场景 [GAME_SMAP]（场景在本 slice 只做基础入口）
  > look
  显示场景模板描述
  > exits
  显示出口
  > go 南
  离开场景回到大地图
```

**命令列表（MMAP 状态）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `list` | 无 | 列出可去的场景列表（从 `entrances.json` 生成） |
| `go` | `<场景名>` | 传送到指定场景，进入后自动触发 `look` |
| `look` | 无 | 查看当前位置描述 |
| `where` | 无 | 显示当前坐标、方位 |
| `help` | `[命令名]` | 无参=列出所有可用命令，有参=查看命令用法 |
| `choose` | `<编号>` | 选择菜单项 |

**命令列表（SMAP 状态 — 本 slice 最小实现）**：

| 命令 | 说明 |
|------|------|
| `look` | 场景模板描述（NPC、物品、出口） |
| `exits` | 出口列表 |
| `go` | `<方向>` 离开场景 |
| `choose` | `<编号>` 选择菜单项 |

**DoD**：用户完成"打开页面 → 新游戏 → 属性分配 → 大地图 → list 查看场景 → go 传送 → 进入场景 → exits → go 离开 → 回到大地图"的完整流程。

**影响领域**：game-states, async-main, jymain-adapter
**依赖**：Slice 2

---

### Slice 4: 场景交互

完善场景 [GAME_SMAP] 内的交互——NPC 对话、事件触发、物品操作。

**业务价值**：场景不再是静态文本，玩家可以与 NPC 和物品互动，驱动游戏剧情。

**命令列表（SMAP 状态）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `look` | 无 / `<目标>` | 无参=场景描述，有参=查看具体对象 |
| `talk` | `<人名>` | 与 NPC 对话，触发 oldevent 事件 |
| `exits` | 无 | 出口列表 |
| `go` | `<方向>` | 离开场景 |
| `take` | `<物品名>` | 拾取物品 |
| `give` | `<物品名> <人名>` | 将物品交给 NPC |
| `choose` | `<编号>` | 选择菜单项 |

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
进入 [GAME_WMAP]，显示战场信息
  > look
  胡斐 HP 150/150  阎基 HP 80/80
  距离: 6 步
  >
  > move 阎基 3     ← 走近阎基 3 步
  胡斐走向阎基，距离 6 → 3 步
  >
  > wugong          ← 列出可用武功及距离
  1. 苗家剑法 (Lv5)  威力 450  范围 0-2步  ❌ 距离不足
  2. 胡家刀法 (Lv3)  威力 280  范围 0-2步  ❌ 距离不足
  3. 暗器           威力 80   范围 1-4步  ✅
  >
  > move 阎基 1     ← 再走近 1 步
  距离 3 → 2 步
  >
  > wugong
  苗家剑法  ✅ 范围 0-2步  可行
  >
  > wugong 苗家剑法 阎基
  胡斐使出苗家剑法！伤害 45！
  阎基 HP 80 → 35
  >
  阎基的回合:
  阎基走进胡斐，距离 2 → 1
  阎基攻击！伤害 12！
  胡斐 HP 150 → 138
  >
  > attack 阎基     ← 普通攻击
  胡斐攻击！伤害 25！
  阎基 HP 35 → 10
  >
  阎基的回合:
  阎基攻击！伤害 15！
  胡斐 HP 138 → 123
  >
  > item 小还丹 自己
  胡斐使用小还丹！HP +80
  胡斐 HP 123 → 150
  >
  > attack 阎基
  胡斐攻击！伤害 30！
  阎基 HP 10 → 0
  阎基被击败！
  战斗胜利！
  获得经验 200，银两 50
  ↓
返回大地图/场景
```

**命令列表（WMAP 状态）**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `look` | 无 | 战场态势：敌我位置、HP/MP、距离 |
| `move` | `<目标> <步数>` | 走近或远离目标（负数=远离） |
| `attack` | `<目标>` | 普通攻击（自动检查距离范围） |
| `wugong` | `[武功名] [目标]` | 无参=列出可用武功及范围，全参=直接使用 |
| `defend` | 无 | 防御，本回合不行动 |
| `item` | `<物品名> [目标]` | 战斗中使用物品（药品/暗器） |
| `status` | `[人名]` | 战斗中查看状态 |
| `choose` | `<编号>` | 选择菜单项 |

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

实现角色管理系统和所有跨状态通用命令。

**业务价值**：玩家可以管理队伍、装备、存档，游戏体验完整。

**命令列表（跨状态通用）**：

| 命令 | 可用状态 | 参数 | 说明 |
|------|---------|------|------|
| `status` | MMAP, SMAP | `[人名]` 或 `全体` | 查看状态，无参=当前选中 |
| `bag` | MMAP, SMAP | 无 | 查看背包物品列表 |
| `bag look` | MMAP, SMAP | `<物品名>` | 查看物品详细描述 |
| `bag use` | MMAP, SMAP | `<物品名> [目标]` | 使用物品 |
| `equip` | MMAP, SMAP | `<物品名> [人]` | 装备物品 |
| `unequip` | MMAP, SMAP | `<装备名> [人]` | 卸下装备 |
| `heal` | MMAP, SMAP | `<人名>` | 医疗队友 |
| `detox` | MMAP, SMAP | `<人名>` | 为队友解毒 |
| `learn` | MMAP, SMAP | `<武功名> [人]` | 修炼武功 |
| `leave` | MMAP, SMAP | `<人名>` | 让队友离队 |
| `save` | MMAP, SMAP | `<槽位名>` | 存档 |
| `load` | MMAP, SMAP | `<槽位名>` | 读档 |
| `saves` | MMAP, SMAP | 无 | 列出所有存档 |
| `help` | 全部 | `[命令名]` | 帮助信息 |

**存档系统**：使用 `localStorage`（浏览器持久化），不涉及服务器。

**场景描述增强**：
- 逐步将 Slice 4 的自动模板替换为人工编写的场景描述
- 场景类型专用模板（客栈、山洞、商店、民居、门派、迷宫...）
- `/look <目标>` 支持查看具体 NPC 或物品的描述

**DoD**：用户能完成查看状态、管理背包、存档读档、使用所有通用命令。游戏基本流程可完整进行。

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
  ├──────────────┐
  ▼              ▼
S4 (场景交互:     S5 (战斗系统:
    talk/take/      move/attack/
    give/exits)     wugong/defend)
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
- [ ] 存档使用浏览器 localStorage 持久化
- [ ] 命令上下文感知——错误状态下的命令给出明确的拒绝提示
- [ ] `sleep` 在文字版中为 yield-only，不消耗真实时间