# game/script 目录文件说明

本文档记录 `game/script` 目录下各脚本文件的用途和结构。

## 目录结构

```
game/script/
├── jymain.lua          # 主游戏逻辑
├── jyconst.lua         # 常量和配置定义
├── jymodify.lua        # 游戏修改和扩展
├── convertkdef2.lua    # KDEF/TALK 转换工具
├── oldevent_320.lua    # 修复的事件文件（需覆盖到 oldevent/ 目录）
├── oldevent_458.lua    # 修复的事件文件（需覆盖到 oldevent/ 目录）
├── oldevent_655.lua    # 修复的事件文件（需覆盖到 oldevent/ 目录）
├── oldevent_676.lua    # 修复的事件文件（需覆盖到 oldevent/ 目录）
├── oldevent/           # 原版事件脚本目录 (1018个文件)
│   ├── oldevent_0.lua
│   ├── oldevent_1.lua
│   └── ... (事件编号 0-1017)
└── newevent/           # 新增事件脚本目录
    └── scene_1_event_19.lua
```

> **注意**：`old_talk.lua` 和 `oldtalk.idx/grp` 已不再使用，对话直接从二进制文件读取。

---

## 一、核心脚本文件

### 1. jymain.lua - 主游戏逻辑

**用途**：游戏核心逻辑实现，由 `main.lua` 加载。

**主要功能**：
- `IncludeFile()` - 加载其他模块
- `SetGlobal()` - 初始化全局变量
- `LoadRecord(id)` / `SaveRecord(id)` - 存档读写
- 场景管理：`Game_MMap()`, `Game_SMap()`, `Game_WMap()`
- 菜单系统：`ShowMenu()`, 各类菜单函数
- 战斗系统：`WarMain()`, `WarSetGlobal()`
- 指令系统：`instruct_0()` ~ `instruct_50()` 等事件指令
- 事件执行：`oldEventExecute()`, `oldCallEvent()`

**代码引用**：
```lua
-- main.lua:29
require(CONFIG.ScriptPath .. "jymain")

-- jymain.lua:18-33
function IncludeFile()
    local jyconst_loader = love.filesystem.load(CONFIG.ScriptPath .. "jyconst.lua")
    if jyconst_loader then
        jyconst_loader()
    else
        dofile(CONFIG.ScriptPath .. "jyconst.lua")
    end
    -- 同理加载 jymodify.lua
end
```

---

### 2. jyconst.lua - 常量定义

**用途**：定义游戏常量和数据结构。

**主要内容**：
- 键盘映射：`VK_*`, `SDLK_*`
- 屏幕常量：`GAME_*` 状态码
- 文件路径：`CC.*_Filename` 数据文件定义
- 颜色定义：`RGB()`, `GetRGB()` 函数
- 数据结构：`CC.Base_S`, `CC.Person_S`, `CC.Thing_S` 等

**代码引用**：
```lua
-- lib_love.lua:16
dofile(CONFIG.ScriptPath .. "jyconst.lua")
```

---

### 3. jymodify.lua - 游戏修改扩展

**用途**：存放对游戏的修改和扩展，避免直接修改 jymain.lua。

**主要功能**：
- `SetModify()` - 在游戏启动时调用，修改原有数据和函数
- 重载原有函数：如 `Menu_System_new()` 替代 `Menu_System()`
- 新增物品使用函数：`JY.ThingUseFunction[id]`
- 新增场景事件：`JY.SceneNewEventFunction[id]`

**示例**：
```lua
function SetModify()
    Menu_System_old = Menu_System
    Menu_System = Menu_System_new
    
    JY.ThingUseFunction[182] = Show_Position  -- 罗盘
    JY.SceneNewEventFunction[1] = newSceneEvent_1
end
```

---

## 二、对话系统文件

> **状态**：对话系统使用二进制格式，`old_talk.lua` 已不再使用。

### 1. oldtalk.idx / oldtalk.grp - 对话文件（二进制格式）

**用途**：二进制格式的对话存储。

**格式**：
- `oldtalk.idx`：每条 4 字节偏移量
- `oldtalk.grp`：文本内容，每行一条对话

**代码引用**：
```lua
-- jyconst.lua:133-134
CC.TalkIdxFile = CONFIG.ScriptPath .. "oldtalk.idx"
CC.TalkGrpFile = CONFIG.ScriptPath .. "oldtalk.grp"

-- jymain.lua:3057
function ReadTalk(talkid)
    -- 从 oldtalk.idx/grp 读取对话
end
```

**不再使用**：`old_talk.lua`（Lua 表格式）已废弃，对话通过 `ReadTalk()` 函数从二进制文件读取。

---

## 三、事件脚本文件

### 1. oldevent/ 目录 - 原版事件

**用途**：存储从原版 KDEF 文件转换的事件脚本。

**文件数量**：1018 个文件（事件编号 0-1017）

**命名规则**：`oldevent_<事件编号>.lua`

**文件格式**：
```lua
--function oldevent_1()
    instruct_1(0,1,0);   -- 1(1):[胡斐]说: 小兄弟...
    instruct_0();        -- 0(0):空语句(清屏)
    instruct_1(1,0,1);   -- 1(1):[WWW]说: 请问...
    -- ...
--end
```

**加载方式**：事件脚本独立于游戏框架，框架不直接 require 它们，而是在运行时根据场景数据动态加载。

```lua
-- jymain.lua:2763
function oldCallEvent(eventnum)
    local eventfilename = string.format("oldevent_%d.lua", eventnum)
    local chunk, err = ScriptLoader.load(CONFIG.OldEventPath .. eventfilename)
    if chunk then
        chunk()
    else
        JY_Error("oldCallEvent load failed: %s (%s)", tostring(eventfilename), tostring(err))
    end
end
```

**事件调用链路**：
```
场景数据 GetD(scene, id, 2/3/4)
        ↓
EventExecute(id, flag)  -- jymain.lua:2728
        ↓
oldEventExecute(flag)   -- jymain.lua:2744 → 从 GetD 读取事件编号
        ↓
oldCallEvent(eventnum)  -- 动态加载 oldevent_{id}.lua
```

**框架引用**：main.lua 只加载核心脚本 (`jymain`, `jyconst`, `jymodify`)，不引用任何 oldevent 文件。

**注意事项**：
- 文件开头函数定义被注释掉（`--function oldevent_xxx()`）
- 使用全局 `instruct_*` 函数执行指令
- 部分事件有 bug，需要用根目录的修复文件覆盖

---

### 2. 根目录的 oldevent_*.lua 文件

| 文件 | 说明 |
|------|------|
| `oldevent_320.lua` | 东方不败剧情修复 |
| `oldevent_458.lua` | 事件修复 |
| `oldevent_655.lua` | 事件修复 |
| `oldevent_676.lua` | 事件修复 |

**用途**：原版转换脚本有 bug，这些是修正后的版本，需手动覆盖到 `oldevent/` 目录对应文件。

---

### 3. newevent/ 目录 - 新增事件

**用途**：存放用户自定义的新事件，支持更复杂的逻辑。

**文件数量**：1 个示例文件

**命名规则**：`scene_<场景ID>_event_<事件ID>.lua`

**示例文件**：`scene_1_event_19.lua`
- 场景 1（河洛客栈）事件 19
- 实现了典当、商店、任务、传送等功能

**使用方式**：
```lua
-- jymodify.lua:33
JY.SceneNewEventFunction[1] = newSceneEvent_1

-- jymodify.lua:296
function newSceneEvent_1(flag)
    local eventfilename = string.format(
        CONFIG.NewEventPath .. "scene_%d_event_%d.lua",
        JY.SubScene, JY.CurrentD
    );
    dofile(eventfilename);
end
```

**调用链路**：
```
EventExecute(id, flag)
    ↓
JY.SceneNewEventFunction[scene_id](flag)  -- 如果已注册
    ↓
dofile "newevent/scene_X_event_Y.lua"
```

---

## 四、转换工具文件

### 1. convertkdef2.lua

**用途**：将原版 kdef 和 talk 文件转换为 Lua 脚本。

**输入文件**：
- `talk.txt` - 对话文本（从 fishedit 导出）
- `kdefout.txt` - 事件定义（从 fishedit 导出）

**输出文件**：
- `oldtalk.grp` - 对话文件
- `oldevent/oldevent_*.lua` - 事件脚本

---

### 2. ConvertKdef&talk.txt

**用途**：转换流程说明文档。

**转换步骤**：
1. 使用 fishedit 0.72 导出 kdef 和 talk 为文本文件
2. 确保存在 `oldevent/` 目录
3. 运行 `convertkdef2.bat`
4. 用根目录的修复文件覆盖有问题的文件

---

## 五、事件指令系统

事件脚本使用 `instruct_*` 系列函数：

| 指令 | 说明 |
|------|------|
| `instruct_0()` | 空语句/清屏 |
| `instruct_1(talkid, headid, flag)` | 显示对话 |
| `instruct_3(...)` | 修改事件定义 |
| `instruct_14()` | 场景变黑 |
| `instruct_32(thingid, num)` | 物品增减 |
| `instruct_31(money)` | 判断金钱是否足够 |
| `instruct_13()` | 战后处理 |
| ... | 共约 50 个指令 |

**完整指令定义**：见 `jymain.lua` 第 2800-3100 行。

---

## 六、代码加载流程

```
main.lua
  ├─ require "config"
  ├─ require "lib_Byte"
  ├─ require "lib_love"
  │    └─ love.filesystem.load/dofile "jyconst.lua"
  ├─ require "jymain"
  │    ├─ love.filesystem.load/dofile "jyconst.lua"
  │    └─ love.filesystem.load/dofile "jymodify.lua"
  │         └─ SetModify() 执行修改
  ├─ EventBridge:init()
  └─ JYMainAdapter.init()

运行时:
  ├─ oldCallEvent(eventnum)
  │    └─ ScriptLoader.load "oldevent/oldevent_xxx.lua"
  └─ JY.SceneNewEventFunction[id](flag)
       └─ dofile "newevent/scene_x_event_y.lua"
```

---

## 七、文件状态总结

| 类别 | 文件 | 使用状态 |
|------|------|----------|
| 核心逻辑 | jymain.lua | ✅ main.lua 加载 |
| 常量定义 | jyconst.lua | ✅ 被多次加载 |
| 修改扩展 | jymodify.lua | ✅ jymain.lua 加载 |
| 对话文本 | old_talk.lua | ❌ 已废弃 |
| 对话二进制 | oldtalk.idx/grp | ✅ ReadTalk() 使用 |
| 转换工具 | convertkdef2.* | ⚠️ 开发工具，不参与运行 |
| 事件脚本 | oldevent/*.lua | ✅ 运行时动态加载 |
| 修复文件 | oldevent_*.lua | ⚠️ 需覆盖到 oldevent/ |
| 新事件 | newevent/*.lua | ✅ 通过 SceneNewEventFunction 使用 |

> **注**：根目录的 4 个修复文件 (`oldevent_320.lua`, `oldevent_458.lua`, `oldevent_655.lua`, `oldevent_676.lua`) 需要覆盖到 `oldevent/` 目录对应文件。

---

## 八、开发建议

1. **修改游戏**：优先在 `jymodify.lua` 中进行，避免修改 `jymain.lua`

2. **添加对话**：直接修改 `oldtalk.grp` 并通过 `GenTalkIdx()` 重新生成索引

3. **添加事件**：
   - 简单事件：创建 `oldevent/oldevent_xxx.lua`
   - 复杂事件：创建 `newevent/scene_x_event_y.lua` 并在 `jymodify.lua` 注册 `JY.SceneNewEventFunction[scene_id]`

4. **修复 bug**：参考根目录的 `oldevent_*.lua` 修复文件，手动覆盖到 `oldevent/` 目录
