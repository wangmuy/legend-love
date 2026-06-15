## 设计目标

将 Love2D 框架（framework/*.lua）在 Web 环境中运行起来，用文本命令替代键盘扫描，实现大地图漫游的核心交互。

## 核心架构变化

### Love2D 事件流 vs Web MUD 事件流

```
Love2D:
  love.update(dt)
    → EventBridge.getInstance():update(dt)
        → InputManager.update(dt)       ← 扫描键盘状态
        → CoroutineScheduler:update(dt)  ← 恢复等待协程
        → StateMachine:update(dt)        ← 更新游戏状态
        → MenuAsync.update(dt)

Web MUD:
  requestAnimationFrame → gameLoop(timestamp)
    → processEventQueue(timestamp)
        → 拉取 JSBridge 事件: choose N → MenuAsync.closeMenu(N)
        │                   其他命令 → CommandEngine.dispatchCommand
        → CoroutineScheduler:update(dt)  ← 恢复等待协程
        → StateMachine:update(dt)        ← 更新游戏状态
    → requestAnimationFrame(gameLoop)
```

### 输入适配方案

Web MUD 输入全是文本命令，没有按键。处理分两种情况：

**1. 菜单选择（choose N）**：直接关闭当前菜单，不走按键流程。

```
用户输入 "choose 1"
  → MenuAsync.hasActiveMenu() == true?
  → 是 → MenuAsync.closeMenu(1)
          → MenuStateMachine:doCloseMenu()
            → callback(1)
              → ShowMenuCoroutine 返回 1
              → 框架正常执行（完全无感）
```

`MenuAsync.closeMenu(N)` 是 framework 已有的公共 API（`menu_async.lua:102`），不修改任何框架代码。子菜单也自然工作——每次 `ShowMenuCoroutine` 注册自己的回调，`closeMenu` 关闭的是当前活动菜单。

**2. 游戏命令（list/go/look 等）**：通过 CommandEngine 按 JY.Status 分发，完全不经过 WaitKey。

### processEventQueue 实现

```lua
-- 在 web_game_bridge.lua 中实现
function processEventQueue(timestamp)
    local scheduler = CoroutineScheduler.getInstance()
    local sm = StateMachine.getInstance()
    
    -- 1. 从 JSBridge 拉取输入事件
    local evt = _G.JSBridge and _G.JSBridge.getEvent()
    if evt and evt.type == "input" then
        local parsed = CommandEngine.parseCommand(evt.data)
        if parsed then
            if parsed.cmd == "choose" and MenuAsync.hasActiveMenu() then
                -- 菜单选择：直接关闭菜单
                local n = tonumber(parsed.args[1])
                if n then MenuAsync.closeMenu(n) end
            else
                -- 游戏命令：通过 CommandEngine 分发
                CommandEngine.dispatchCommand(parsed.cmd, parsed.args)
            end
        end
    end
    
    -- 2. 驱动协程调度器（恢复挂起的协程）
    scheduler:update(dt or 0)
    
    -- 3. 更新状态机
    local sm = StateMachine.getInstance()
    sm:update(dt or 0)
end
```

## 模块分解

### 1. web-game-bridge — 游戏框架集成

将 framework 下的核心模块加载到 Fengari 运行环境。

```
加载路径: require("framework.xxx") 
         → 从 dataCache 查找对应的 Lua 源码
         → fengari.load() 编译执行
         → 注册模块到 package.preload
```

核心模块清单（按加载顺序）：
1. `framework.coroutine_scheduler` — 协程调度器
2. `framework.state_machine` — 状态机
3. `framework.game_states` — 游戏状态处理器（MMAP/SMAP 等）
4. `framework.event_bridge` — 事件桥接器
5. `framework.input_manager` — 输入管理器（Web 版中菜单由 choose N → closeMenu 处理，不走 InputManager）
6. `framework.menu_async` — 异步菜单
7. `framework.jymain_adapter` — 游戏主适配器
8. `framework.perf_log` — 性能日志
9. `framework.lib_file` — 文件操作
10. `framework.lib_Byte`, `framework.luabit` — 二进制/位操作

游戏脚本模块：
1. `script/jymain.lua` — 主游戏逻辑（IncludeFile, SetGlobalConst, SetGlobal 等）
2. `script/jyconst.lua` — 常量定义
3. `script/jymodify.lua` — 游戏修改

### 2. web-command-engine — 命令解析引擎

```
用户输入 "go 河洛客栈"
  │
  ├─ 解析: { cmd="go", args={"河洛客栈"} }
  │
  ├─ 上下文检查: JY.Status == GAME_MMAP → go 在 MMAP 可用
  │
  ├─ 执行命令处理器: MmapHandlers.go("河洛客栈")
  │    ├─ entrances.json 查找 "河洛客栈" → sceneId
  │    ├─ scenes.json 获取场景数据
  │    ├─ JY.Base["人X1"] / JY.Base["人Y1"] 更新
  │    ├─ JY.Status = GAME_SMAP
  │    └─ 输出场景描述
  │
  └─ 等待下一个命令
```

命令注册表结构：
```lua
local commandRegistry = {
    [GAME_MMAP] = {
        list = { handler = MmapHandlers.list, description = "列出可去场景" },
        go = { handler = MmapHandlers.go, description = "传送到场景: go <场景名>" },
        look = { handler = MmapHandlers.look, description = "查看当前位置" },
        where = { handler = MmapHandlers.where, description = "查看坐标方位" },
        help = { handler = CommonHandlers.help, description = "显示帮助" },
        choose = { handler = CommonHandlers.choose, description = "选择: choose <编号>" },
    },
    [GAME_SMAP] = {
        look = { handler = SmapHandlers.look, description = "查看场景" },
        exits = { handler = SmapHandlers.exits, description = "列出出口" },
        go = { handler = SmapHandlers.go, description = "离开场景: go <编号>" },
        leave = { handler = SmapHandlers.leave, description = "离开场景回到大地图" },
        help = { handler = CommonHandlers.help, description = "显示帮助" },
        choose = { handler = CommonHandlers.choose, description = "选择: choose <编号>" },
    },
}
```

### 3. web-mmap-smap — 大地图和场景文字交互

MMAP 文字渲染（替换原来基于贴图的 DrawMMap）：

```
当前位置: 河洛客栈外
坐标: (364, 284)  场景数: 189
────────────────────────────────
可以使用以下命令：
  list    — 列出所有可去场景
  go      — go <场景名> 传送到场景
  look    — 查看当前位置描述
  where   — 查看坐标方位
  help    — 显示帮助
```

SMAP 文字渲染（替换 DrawSMap）：

```
河洛客棧
════════
这是一间客栈，店小二正在忙碌地招呼客人。柜台后面摆满了酒坛。
────────────────────────────────────────
NPC: 掌柜, 胡斐, 田伯光
出口: 河洛客栈外, 客房, 二楼
输入 exits 查看出口详情，leave 回到大地图
```

## 数据流

```
用户输入 → keydown → eventQueue.push({type="input", data="go 河洛客栈"})
                                                      │
requestAnimationFrame → gameLoop                       │
  → lua_getglobal("processEventQueue")                 │
  → processEventQueue(timestamp)                       │
      └─ JSBridge.getEvent() ←─────────────────────────┘
          → {type="input", data="go 河洛客栈"}
          → parseCommand → {cmd="go", args={"河洛客栈"}}
          │
          ├─ choose N + 有活动菜单?
          │   → MenuAsync.closeMenu(N)
          │   → 框架菜单协程恢复（无需 key injection）
          │
          └─ 其他命令?
              → CommandEngine.dispatch("go", {"河洛客栈"})
                  → 按 JY.Status 查命令表 → MmapHandlers.go()
                  → 更新 JY 数据，切换状态
                  → 输出场景描述
      
      ├─ CoroutineScheduler:update(dt)
      │   └─ 恢复挂起的协程
      │
      └─ StateMachine:update(dt)
          └─ 同步 JY.Status → 状态机切换
```

## 测试策略

### 单元测试 (via luaEval)
- 命令解析器：`parseCommand("go 河洛客栈")` → `{cmd="go", args={"河洛客栈"}}`
- 命令注册表：各状态的命令列表正确
- MMAP handlers：`MmapHandlers.list()` 输出场景列表
- SMAP handlers：`SmapHandlers.exits()` 输出出口列表

### E2E 测试 (Playwright)
- 输入 `choose 1` 开始新游戏
- 属性选择后输入 `choose 1` 确认
- 进入 MMAP 后输入 `list` 显示场景列表
- 输入 `go 河洛客栈` 进入场景
- 输入 `exits` 显示出口编号列表
- 输入 `go 1` 按编号离开场景返回大地图

## 依赖关系

```
Slice 2 (前端骨架 + engine_web)
  │
  └── web-game-bridge (框架集成)
         │
         ├── web-command-engine (命令引擎)
         │      │
         │      └── web-mmap-smap (地图/场景交互)
         │
         └── (无其他依赖)
```
