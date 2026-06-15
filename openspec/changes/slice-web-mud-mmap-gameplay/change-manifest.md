# Change Manifest — 大地图漫游

## 依赖顺序

```
web-game-bridge  (框架集成，无依赖，需最先完成)
        │
        ├── web-command-engine  (命令解析引擎，依赖 web-game-bridge)
        │
        ├── web-mmap-smap  (大地图和场景交互，依赖 web-game-bridge + web-command-engine)
        │
        └── web-menu-selection  (菜单辅助选择模式，依赖 web-command-engine + web-mmap-smap)
```

## Change Assignments

### 1. web-game-bridge

| 字段 | 值 |
|------|-----|
| Scope | 游戏框架在 Web 环境的集成 |
| Responsibility | processEventQueue 驱动协程调度器、choose N → MenuAsync.closeMenu(N)、framework/*.lua 加载、脚本模块加载、JYMainAdapter.init() 运行、开始菜单+属性选择文字版、排版修复（convertEol、WebUI 输出路径统一、idle 状态不清屏） |
| Depends on | Slice 2 (engine-web-core, web-data-loader, web-frontend-shell) |
| Status | [x] Complete |

### 2. web-command-engine

| 字段 | 值 |
|------|-----|
| Scope | 文本命令解析和分发引擎 |
| Responsibility | parseCommand、命令注册表、dispatchCommand、help 命令、choose N 命令、未知命令提示 |
| Depends on | web-game-bridge |
| Status | [x] Complete |

### 3. web-mmap-smap

| 字段 | 值 |
|------|-----|
| Scope | 大地图和场景的文字交互 |
| Responsibility | MMAP 命令（list/go/look/where）、SMAP 命令（look/exits/go）、场景描述模板 |
| Depends on | web-game-bridge, web-command-engine |
| Status | [x] Complete |

### 4. web-menu-selection

| 字段 | 值 |
|------|-----|
| Scope | go/list 等命令无参时弹出菜单辅助选择 |
| Responsibility | 菜单辅助函数、go/list 菜单模式、协程包装支持 |
| Depends on | web-command-engine, web-mmap-smap |
| Status | [x] Complete |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| `processEventQueue` | 每帧拉取 JSBridge 事件：`choose N` → `MenuAsync.closeMenu(N)`，其他命令 → `CommandEngine.dispatchCommand` |
| `_G.CommandEngine` | 命令解析引擎全局表 |
| `CommandEngine.parseCommand(text)` | 解析文本为 `{cmd, args}` |
| `CommandEngine.dispatchCommand(cmd, args)` | 根据 JY.Status 查找并执行命令处理器 |
| `CommandEngine.registerCommands(stateId, commands)` | 为指定状态注册命令列表 |
| `CommandEngine.getHelpText()` | 返回当前状态的帮助文本 |
| `_G.WebUI` | Web 文字 UI 渲染函数 |
| `WebUI.displayScene(sceneData)` | 渲染场景描述到终端 |
| `WebUI.displayMmap(location)` | 渲染大地图信息到终端 |
| `WebUI.displayMenu(items, title)` | 渲染菜单选项到终端 |
| `CommandEngine.showMenuAndWait(items)` | 弹出菜单并等待 choose N 选择，返回选中索引（0 = ESC） |

## Integration Test Plan

1. 打开 `game/engine-web/index.html`
2. 系统就绪后输入 `choose 1` → 开始新游戏
3. 显示属性 → `choose 1` 确认 → 进入大地图
4. 输入 `list` → 显示场景列表
5. 输入 `go 河洛客栈` → 进入场景
6. 输入 `look` → 场景描述
7. 输入 `exits` → 出口列表
8. 输入 `go 南` → 返回大地图
9. 输入 `help` → 显示可用命令
10. 输入 `xyz` → "未知命令" 提示

### 自动化测试

1. Playwright 打开 Chromium → 页面加载完全
2. 通过 `page.evaluate` 调用 Lua 函数验证命令解析
3. E2E 场景覆盖完整 MMAP → SMAP 流程
