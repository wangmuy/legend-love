---
status: active
created: 2026-11
parent_epic: 2026-11-mouse-input
parent_slice: mouse-slice2-mouse-menu
---
# Design: mouse-menu

> 每个关键判断记作 ADR。

## ADR-MS2-001 鼠标点击**翻译**成已有键盘语义，不另开一套选中逻辑

**Context**

菜单系统已有完整的键盘语义（`menu_state_machine.lua`）：

```
  VK_UP / VK_DOWN   →  移动 menu.current
  VK_LEFT / VK_RIGHT → 同上（横向菜单）
  VK_SPACE / VK_RETURN → selectMenuItem()
  VK_ESCAPE         → closeMenu(0)
```

朴素做法是给鼠标写一套并行的「点击 → 选中 + 执行」逻辑。问题是那会引入
**第二套语义**，两者容易走偏（比如键盘的 `selectMenuItem` 会把回调扔进协程，
鼠标版本若直接调用就会在主线程 yield）。

**Decision**

鼠标点击只做一件事：**把事件翻译成键盘等价物**。

```lua
-- 命中到第 N 行 → 等价于「光标移到第 N 行 + 按 Enter」
local function clickRow(menu, rowIndex)
    menu.current = rowIndex
    self:selectMenuItem()          -- 复用既有逻辑（含协程隔离）
end

-- 点击外部 → 等价于 ESC
local function clickOutside()
    self:closeMenu(0)              -- 复用既有逻辑（含菜单栈恢复）
end

-- 点值项箭头 → 等价于上下键
local function clickArrow(menu, desc, direction)
    desc.pending = clamp(desc.pending + direction * desc.step)
end
```

**这样保住了什么**

```
  ① 回调的协程隔离（selectMenuItem 内部 scheduler:create）自动继承
  ② 菜单栈恢复（doCloseMenu）自动继承
  ③ 值项的待定值语义（不经 Settings.set）自动继承
  ④ 键盘与鼠标的最终行为**在实现上就是同一段代码**
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 鼠标独立的选中+执行路径 | 要复制协程隔离、栈恢复、合并钳制等逻辑；两份实现必然走偏 |
| 鼠标直接把点击注入键盘事件队列 | 键码无法表达「第 N 行」（键盘只有上下，跨越 N 行要发 N 次上/下） |
| 鼠标直接调 `Settings.set` 改值项 | 绕过待定值语义，破坏「误触可撤销」的核心约束 |

**Consequences**

- `menu_state_machine.lua` 新增的只是**命中测试 + 转发**，不含业务逻辑
- 键盘路径零改动
- 鼠标的 bug 与键盘的 bug 会同时暴露（因为同一段代码），调试更简单

---

## ADR-MS2-002 命中测试用菜单的几何字段，纯函数可单测

**Context**

`createMenu` 返回的 menu 表已经有完整几何信息：

```lua
{
  x1, y1, w, h,          -- 菜单矩形
  start, num,            -- 可视范围（numShow 滚动时 start > 1）
  newNumItem,            -- 总项数
  size,                  -- 字号
  isHorizontal,          -- 横向/竖向
}
```

行高公式已存在（`menu_state_machine.lua:602`）：

```lua
local y = menu.y1 + CC.MenuBorderPixel + (i - menu.start) * (menu.size + CC.RowPixel)
```

**Decision**

命中测试写成**纯函数**，不依赖状态机实例，可完全单测：

```lua
--- 判断点是否在菜单内
-- @return boolean
local function hitMenu(menu, x, y)
    return x >= menu.x1 and x <= menu.x1 + menu.w
       and y >= menu.y1 and y <= menu.y1 + menu.h
end

--- 返回点命中的菜单项索引（1-based，对应 newMenu 的下标）
-- @return number|nil
local function hitItem(menu, x, y)
    if not hitMenu(menu, x, y) then return nil end
    local rowH = menu.size + CC.RowPixel
    for i = menu.start, menu.start + menu.num - 1 do
        if i > menu.newNumItem then break end
        local rowY = menu.y1 + CC.MenuBorderPixel + (i - menu.start) * rowH
        if y >= rowY and y < rowY + rowH then
            return i
        end
    end
    return nil    -- 在矩形内但超出项数（空白区）
end

--- 判断点命中值项的哪一行（1=▲ 2=值 3=▼）
-- @return number|nil
local function hitValueLine(menu, itemIndex, x, y)
    -- 值项是三行文本，行高同上
    ...
end
```

**关键：`numShow` 滚动偏移**

```
  错误写法： rowY = menu.y1 + pad + (i - 1) * rowH        ← 忽略 start
  正确写法： rowY = menu.y1 + pad + (i - menu.start) * rowH

  menu.start = 3、num = 5 时：
    屏幕第 1 行显示的是 newMenu[3]，不是 newMenu[1]
```

这条单独作为 spec 场景（「滚动菜单的点击命中偏移正确」）。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 用 `DrawString` 的返回值反推行位置 | `DrawString` 不返回位置信息，且依赖渲染副作用 |
| 每个菜单项自己登记点击热区 | 要在 `createMenu` 时算一遍，与 draw 的行高公式重复实现 |
| 只在非滚动菜单支持点击 | 战斗的物品/武功菜单都是滚动的，不支持等于废掉一半功能 |

**Consequences**

- 命中测试可脱离渲染与状态机单测（给定几何 → 断言命中哪一项）
- 行高公式在 draw 与 hitItem 中各出现一次 —— **风险：两处不同步**。
  缓解：抽成 `local function rowY(menu, i)` 供两处调用

---

## ADR-MS2-003 「先关子菜单再响应新项」用菜单栈深度比较

**Context**

需求明确：「出现子菜单的时候点击主菜单其他项，要保证先关闭当前子菜单，再响应其他主菜单项」。

当前菜单栈机制：

```lua
-- openMenu 时把当前菜单压栈
table.insert(self.menuStack, self.activeMenu)

-- doCloseMenu 时出栈恢复
if #self.menuStack > 0 then
    self.activeMenu = table.remove(self.menuStack)
end
```

**核心问题**：当子菜单打开时，`self.activeMenu` 是**子菜单**。
点击「主菜单的其他项」意味着：

```
  ① 主菜单的对象在哪？  → 在 self.menuStack[#self.menuStack]
  ② 点击坐标落在主菜单的几何范围里（因为子菜单通常画在主菜单右侧，
     主菜单仍然可见）
  ③ 要「先关闭子菜单」= 从栈中弹出并丢弃
  ④ 再「响应主菜单的新项」
```

**Decision**

流程设计为：

```lua
-- 鼠标点击的总入口
function MenuStateMachine:handleMouseClick(x, y)
    local menu = self.activeMenu
    if not menu then return end

    -- ① 先看点击是否落在【当前菜单】（最内层）
    local hit = hitItem(menu, x, y)
    if hit then
        self:clickRow(menu, hit)
        return
    end

    -- ② 不在最内层，看是否落在【父菜单】上（栈中任意一层）
    for depth = #self.menuStack, 1, -1 do
        local parent = self.menuStack[depth]
        local parentHit = hitItem(parent, x, y)
        if parentHit then
            -- 关闭所有比它更内层的菜单（含当前 activeMenu）
            self:popToDepth(depth)
            -- 现在 parent 成为 activeMenu，再响应点击
            self:clickRow(parent, parentHit)
            return
        end
    end

    -- ③ 都不在 → 点击外部，关闭最内层（等价 ESC）
    self:closeMenu(0)
end
```

`popToDepth(depth)` 的实现：循环 `doCloseMenu()` 直到 `#self.menuStack == depth - 1`。

**关键：不能简单「全部关闭再重新打开」**

```
  ✗ 错误做法：clear() 清空所有菜单，然后从头走一遍主菜单流程
     后果：丢失所有回调（callbackStack 被清）、
           父菜单的回调协程永远挂起（ShowMenuCoroutine 的 while 循环）

  ✓ 正确做法：逐层 doCloseMenu()，每层都触发其回调，
              保证每个 ShowMenuCoroutine 都能醒来
```

这与 `MenuStateMachine:clear()` 里已记录的教训一致（其注释写明：
「直接置 nil 会让 ShowMenuCoroutine 里的 while not menuClosed 永久挂起」）。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| `clear()` 后重新打开主菜单 | 丢失回调、父协程永久挂起（既有 bug 的复现） |
| 只支持点击最内层，点在父菜单区域算「外部点击」 | 违反需求（主菜单其他项要能响应） |
| 子菜单打开时禁用主菜单点击 | 违反需求 |

**Consequences**

- 需要新增 `popToDepth(depth)` 方法
- 栈深通常 ≤ 3，循环开销可忽略
- **风险**：`doCloseMenu` 会触发回调，回调可能又打开新菜单 —— 
  需要防重入（与既有 `menu.state == EXECUTING` 的机制一致）

---

## ADR-MS2-004 鼠标开关用普通菜单项 + 回调 `return 0`，无需新 kind

**Context**

需求要求「鼠标操作」开关项：`kind` 可能是新增值，但先验证能否复用现有机制。

**实测验证**（用真实 `menu_state_machine`，见 epic.md 约束 10）：

```lua
{ "鼠标操作    开",
  function(menu, current)
      Settings.set("input.mouse", not Settings.get("input.mouse"))
      menu[current][1] = "鼠标操作    " .. (Settings.get("input.mouse") and "开" or "关")
      return 0        -- 不关闭菜单
  end, 1 }
```

输出：

```
初始:     设置=true   文本=鼠标操作    开
Enter 后: 设置=false  文本=鼠标操作    关     菜单仍打开 ✓
再 Enter: 设置=true   文本=鼠标操作    开
按上键后: 设置=true（不变，纯导航）✓
```

四个依赖的机制全部现成：

```
  ① 回调拿到 newMenu 引用        menu_state_machine.lua:464
  ② 返回 0 → 菜单不关闭          pollCallback 只在 result == 1 时 close
  ③ draw 每帧重读 newMenu[i][1]  → 文本自动更新
  ④ 上下键在非值项上天然导航     零改动
```

**Decision**

**不新增 kind**，用普通菜单项 + 回调。

```lua
-- framework/mouse_menu.lua（新增）
function MouseMenu.buildToggleItem()
    local KEY = "input.mouse"
    local function label()
        return "鼠标操作    " .. (Settings.get(KEY) and "开" or "关")
    end
    return {
        label(),
        function(menu, current)
            Settings.set(KEY, not Settings.get(KEY))
            menu[current][1] = label()
            return 0
        end,
        1,
    }
end
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 新增 `kind = "bool"` 值项 | 要改 4 处 `kind == "number"` 判断；且值项的「待定值 + 确认」语义对开关是多余的 |
| 新增 `kind = "toggle"` | 同上，且上下键语义会与「多项菜单的导航」冲突 |
| 独立子菜单（进第三层） | 需求明确说「不做子菜单」 |
| 用 `format` 动态文本（值项机制） | 值项的 format 读 `pending`，而开关没有 pending 概念 |

**Consequences**

- `menu_state_machine.lua` **零改动**（本 ADR 贡献）
- 新增 `framework/mouse_menu.lua`（约 60 行，含两个菜单入口的构建函数）
- **副作用**：菜单项文本在回调里被改写，若菜单对象被复用（而非重建），
  下次打开会显示上一次的文本。需确认菜单每次都是 `createMenu` 新建的
  （当前所有调用点都是，安全）
