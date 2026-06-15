## Context

MMAP 场景名称是中文（如"河洛客栈"），玩家需精确输入才能执行 `go`。这带来两个问题：
1. 中文名称难拼写、难记忆
2. 玩家不知道可去哪些场景，必须先 `list` 看一遍，再手动输入

Web MUD 已有 `choose N` 交互模式（`MenuAsync.closeMenu(N)`），菜单方案零额外框架修改。

## Goals / Non-Goals

**Goals:**
- `go` 无参时弹出场景菜单，玩家选 `choose N` 执行
- `list` 改为菜单模式（替代纯文字列表）
- 模式可复用，后续 heal/give/take/wugong 等命令套用
- 不改变 `go <场景名>` 精确匹配行为

**Non-Goals:**
- heal/give/take/wugong 具体实现
- 分页（场景数 < 50，不超出终端）
- 数字参数直接选择（go 5 → 第 5 处场景）
- 自动补全

## Architecture Decision Records

### ADR-001: 复用 ShowMenu（回调版）而非协程版

- **Context**: 需要显示可选列表供 choose N 选择。go/list 命令处理器是普通函数，不在协程内。
- **Decision**: 用 `MenuAsync.ShowMenu`（回调版，非阻塞）展示菜单，`choose N` 通过 `processEventQueue` 的 `MenuAsync.closeMenu(N)` 关闭。
- **Alternatives Considered**:
  - `MenuAsync.ShowMenuCoroutine`（协程版）→ 需要将命令处理器包装为协程，增加复杂度
  - 自建菜单渲染函数 → 需要额外渲染逻辑，与已有菜单风格不一致
  - 数字参数直接选择（`go 5`）→ 额外的映射和边界检查
- **Consequences**: 菜单渲染统一走 framework 已有路径，zero new rendering code。命令处理器保持普通函数，无需协程包装。

### ADR-002: "无参时弹菜单"模式放在命令处理器中

- **Context**: `go` 有参（`go 河洛客栈`）和无参（`go` → 菜单）两种行为
- **Decision**: 在 `mmap_smap_handlers.lua` 中判断参数数量，无参时调用 `CommandEngine.showMenu(items, title, callback)` 弹菜单
- **Alternatives Considered**:
  - CommandEngine 层统一处理"无参弹菜单" → 需要声明式配置，过度设计
  - 新命名 `go` 命令拆分 → 破坏接口一致性
- **Consequences**: 每个命令处理器自行决定是否弹菜单，有参/无参两套逻辑在同一函数内

## Negative Constraints

- 不修改 `game/framework/` 下的任何文件
- 不修改 `game/engine-web/index.js`
- 不引入新的第三方依赖
- 不修改已有测试文件（可新增测试）
- MenuAsync 菜单必须传 `(menu, len, ...)` 格式参数，不改变接口

## Alignment Check

无冲突。本 change 新增的命令仅注册到 GAME_MMAP / GAME_SMAP，不干扰框架的 GAME_START 流程。

## Decisions

### 菜单数据结构（回调版）

```lua
-- CommandEngine.showMenu 内部
for i, item in ipairs(items) do
    local label = string.format("%d. %s", i, item.name)
    menu[i] = {label, nil, 1}  -- {"1. 河洛客棧", nil, 允许选择}
end

MenuAsync.ShowMenu(menu, #menu, 0, 0, 0, 0, 0, 0, 1,
    CC.DefaultFont, C_RED, C_WHITE,
    function(returnValue)
        if returnValue > 0 then callback(returnValue)
        else callback(nil) end  -- ESC
    end)
```

### go 处理器逻辑

```
go(args):
  if #args > 0:
    原有逻辑：精确匹配/模糊匹配场景名
  else:
    从数据缓存中获取场景列表
    构建菜单 → CommandEngine.showMenu(items, title, callback)
    choose N → 回调获取目标 → goToScene
    ESC → 回调收到 nil，不操作
```

### list 处理器逻辑

```
list(args):
  同 go 无参分支：显示场景菜单（复用 buildSceneList + showMenu）
```

## 菜单项序号

菜单项显示格式为 `"1. 河洛客棧"`、`"2. 天寧寺"` 等，方便用户通过序号识别。序号在 `CommandEngine.showMenu` 中自动添加，无需调用方关注。

## Risks / Trade-offs

- 无。回调版 `ShowMenu` 是框架已有 API，命令处理器保持普通函数，无协程包装风险。

## Review Checklist

1. `go` 无参时弹出菜单，`choose N` 正确传送到对应场景
2. `go <场景名>` 有参时行为不变（精确匹配 + 模糊匹配）
3. `list` 改为菜单模式，`choose N` 能选择场景
4. ESC 关闭菜单回到原状态（不做任何操作）
5. 菜单命令只在 GAME_MMAP / GAME_SMAP 下可用，GAME_START 下不可见