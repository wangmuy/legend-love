# 游戏修改指南

本文档记录在项目中进行各类修改时，需要修改哪些文件。

## 概述

游戏代码分为三大目录：
- `game/script/` - 游戏脚本（事件、数据、逻辑配置）
- `game/framework/` - 引擎无关框架代码（事件驱动架构、异步系统）
- `game/engine-love2d/` - Love2D 引擎实现（可整体替换）

> **原则**：优先在 `script/` 目录进行修改，只有框架级别的新功能才需要修改 `framework/` 或 `engine-love2d/` 目录。

---

## 一、只需要修改 script/ 目录的场景

### 1.1 新增 instruct 指令

**文件**：`script/jymain.lua`

```lua
-- 添加新的 instruct 函数
function instruct_N(param1, param2, ...)
    -- 实现逻辑
end
```

事件脚本中的调用方式：
```lua
instruct_N(1, 2, 3)  -- 直接调用
```

> **注意**：如需支持协程异步，还需修改 `framework/async_globals.lua` 添加全局替换。

### 1.2 新增对话

**方式一**：直接编辑对话文件
- 修改 `script/oldtalk.grp`（追加新对话）
- 重建索引：`script/oldtalk.idx`

**方式二**：运行时动态加载（高级）
- 在事件脚本中使用特定逻辑

### 1.3 新增事件脚本

**旧事件**（传统方式）：
```
script/oldevent/oldevent_XXX.lua
```
- 文件名格式：`oldevent_<事件编号>.lua`
- 事件编号从场景数据 `GetD(scene, id, 2/3/4)` 读取

**新事件**（增强方式）：
```
script/newevent/scene_<场景ID>_event_<事件ID>.lua
```
- 需要在 `script/jymodify.lua` 中注册：
```lua
JY.SceneNewEventFunction[场景ID] = 函数名
```

### 1.4 新增武功

**文件**：`script/jyconst.lua`

修改武功数据常量 `JY.Wugong` 的定义（从二进制数据加载）。

### 1.5 修改数值平衡

**文件**：`script/jyconst.lua`

常见配置：
```lua
CC.PersonAttribMax = {}    -- 人物属性最大值
CC.WugongBase = {}         -- 武功基础伤害
CC.ExpNeeded = {}          -- 升级经验需求
```

### 1.6 新增物品使用逻辑

**文件**：`script/jymodify.lua`

```lua
JY.ThingUseFunction[物品ID] = function(...)
    -- 物品使用逻辑
end
```

---

## 二、需要同时修改 framework/ 目录的场景

### 2.1 新增人物头像贴图

| 修改位置 | 说明 |
|----------|------|
| `data/fightXXX.idx` + `data/fightXXX.grp` | 新增战斗动作贴图文件 |
| `script/jyconst.lua` | 可能需要调整人物数量常量 |

### 2.2 新增战斗动画贴图

| 修改位置 | 说明 |
|----------|------|
| `data/eft.idx` + `data/eft.grp` | 新增武功效果贴图 |
| `script/jyconst.lua` | 修改 `CC.Effect` 映射表（第439行左右） |

### 2.3 新增地图贴图

| 修改位置 | 说明 |
|----------|------|
| `data/xxx.idx` + `data/xxx.grp` | 新增贴图文件 |
| `script/jyconst.lua` | 添加 `CC.*PicFile` 配置 |

### 2.4 新增音效/音乐

| 修改位置 | 说明 |
|----------|------|
| `sound/` 目录 | 添加音频文件 |
| `script/jyconst.lua` | 修改 `CC.MIDIFile`、`CC.ATKFile` 等路径常量 |

### 2.5 新增战斗系统逻辑

| 修改位置 | 说明 |
|----------|------|
| `framework/war_async.lua` | 战斗流程协程 |
| `framework/game_states.lua` | 战斗状态处理器 |
| `script/jyconst.lua` | 战斗相关配置 |

### 2.6 新增菜单系统

| 修改位置 | 说明 |
|----------|------|
| `framework/menu_async.lua` | 异步菜单逻辑 |
| `framework/menu_state_machine.lua` | 菜单状态机 |
| `script/jymodify.lua` | 注册新菜单函数 |

### 2.7 修改事件指令为异步

如果需要将某个 instruct 改为非阻塞（协程）版本：

| 修改位置 | 说明 |
|----------|------|
| `script/jymain.lua` | 保留原函数 |
| `framework/async_globals.lua` | 添加全局替换逻辑 |
| `framework/event_executor.lua` | 确保协程调度正确 |

---

## 三、文件修改速查表

| 修改内容 | 主要修改文件 | 辅助修改文件 |
|----------|-------------|-------------|
| 新 instruct 指令 | script/jymain.lua | framework/async_globals.lua（可选） |
| 新对话 | script/oldtalk.grp | script/oldtalk.idx |
| 新事件脚本 | script/oldevent/*.lua | - |
| 新场景事件 | script/newevent/*.lua | script/jymodify.lua |
| 新武功 | script/jyconst.lua | - |
| 修改数值平衡 | script/jyconst.lua | - |
| 物品使用逻辑 | script/jymodify.lua | - |
| 人物头像贴图 | data/fight*.idx/grp | - |
| 战斗动画贴图 | data/eft.idx/grp | script/jyconst.lua |
| 地图贴图 | data/*.idx/grp | script/jyconst.lua |
| 音效/音乐 | sound/* | script/jyconst.lua |
| 战斗逻辑 | framework/war_async.lua | script/jyconst.lua |
| 菜单系统 | framework/menu_async.lua | script/jymodify.lua |
| 核心框架 | framework/*.lua | - |
| 换引擎 | engine-love2d/*.lua | - |

---

## 四、修改优先级

1. **优先修改 `script/` 目录** - 大部分游戏内容调整都在这里
2. **只在需要新框架功能时修改 `framework/`** - 如新的交互模式、异步流程
3. **换引擎时只修改 `engine-love2d/`** - 实现新的 EngineAPI 即可
4. **资源文件（图片/音乐）添加到对应目录** - 然后在 `jyconst.lua` 引用

---

## 五、注意事项

1. **事件脚本独立于框架**：oldevent 脚本通过 `ScriptLoader.load()` 动态加载，框架不直接引用
2. **数值配置集中在 jyconst.lua**：避免散落在多处
3. **资源文件命名规范**：遵循现有命名模式（如 `fight%03d.idx`）
4. **测试**：修改后运行 `cd game && lua tests/test_runner.lua` 验证