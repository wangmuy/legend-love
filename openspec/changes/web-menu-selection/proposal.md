## Why

`go 河洛客栈` 需要精确输入场景名称，中文名称难拼写、难记忆。玩家需要一种不依赖精确拼写的方式选择场景和其他命令目标。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 3 (大地图漫游): `openspec/changes/slice-web-mud-mmap-gameplay/change-manifest.md`

## What Changes

为 `go`、`list` 等选择型命令增加菜单模式——无参调用时弹出可选项列表，玩家用 `choose N` 选择。不改变已有 `go <名称>` 精确匹配行为。

## Scope Boundaries

### In Scope

- go 无参时弹出场景菜单（从 entrances.json 生成）
- list 改为展示场景菜单（替代纯文字列表）
- 菜单出 ESC 返回前一个状态
- 统一菜单辅助模式，供后续 heal/give/take/wugong 等命令复用
- 从 GAME_START 过渡到游戏开始后，注册已有 `go` 菜单命令到 MMAP 和 SMAP 的 `go` 冲突保留：go 也保持参数模式不冲突

### Out of Scope

- heal/give/take/wugong 等命令的菜单——只做框架模式，不做具体实现
- 菜单分页（场景数量有限，不分页）
- 数字参数直接选择（go 5 → 第 5 个场景）——不实现，纯 choose N 够用
- 场景名称自动补全

## Capabilities

### New Capabilities
- `go-menu`: go 无参时弹出场景选择菜单，玩家 choose N 选择后执行
- `list-menu`: list 改为菜单列表（替代不可选的纯文字输出）
- `menu-helper`: 通用的"无参→弹出菜单"辅助模式，被 `go` 和后续命令复用

### Modified Capabilities
- `go`: 原有的 `go <场景名>` 不变，新增无参分支

## Contract Adherence

本 change 遵循 slice3 change-manifest 的全部共有契约：
- processEventQueue 中 choose N → MenuAsync.closeMenu(N)
- CommandEngine.dispatchCommand 根据 JY.Status 路由
- 仅注册到 GAME_MMAP / GAME_SMAP 状态（不注册到 GAME_START）

## Impact

- `game/engine-web/web_command_engine.lua`：新增菜单辅助函数
- `game/engine-web/mmap_smap_handlers.lua`：修改 go/list 处理器
- `game/engine-web/web_game_bridge.lua`：注册新命令
- 无 framework/ 或 script/ 修改
