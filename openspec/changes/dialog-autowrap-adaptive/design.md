---
status: active
created: 2026-11-02
---
# Design: dialog-autowrap-adaptive

## 背景

对话框文本溢出。调研确认是「换行阈值回归 + `*` 跳过换行 + 框尺寸写死 + 行高错配
+ 排版算法位置错误」五个问题的叠加。本设计记录关键决策与其被否决的替代方案。

---

## ADR-1：排版算法下沉到 EngineAPI 的 `M.dialog` 语义模块

### Context

对话框当前在 `framework/talk_async.lua` 中用 7 种图形原语逐条下发：

```
lib.Debug ×11   DrawBox ×2   DrawString ×1
lib.GetKey ×1   lib.PicGetXY ×1   lib.PicLoadCache ×1
CC.DefaultFont（直接读全局）
```

坐标全部由 Lua 层算好（`talkx+5`、`talky+5+talkBorder+i*(font+talkBorder)`）。

而同一 EngineAPI 中 `map` 模块已是语义级：

```lua
function M.map.drawScene(sceneId, x, y, offX, offY, playerPic) end
```

三个引擎的对话框相关能力差异巨大：

| 能力 | love2d | mud | web |
|---|---|---|---|
| `DrawBox` / `DrawString` | 真画 | 空实现 + log | 空实现 |
| `CC.DefaultFont` | 有效 | 无意义 | 无意义 |
| 字体对象 | 真 LÖVE Font（有 `:getWidth()`） | `{name,size}` 表 | `{name,size}` 表 |

`talk_async.lua` 读 `CC.DefaultFont` 算坐标，在 mud/web 上毫无意义。

### Decision

新增 `EngineAPI.dialog` 语义模块，三函数：

```lua
--- 排版：纯计算，不绘制、不阻塞
-- @param spec table { text, headId, flag, maxLines, ... }
-- @return table layout { width, height, lines[], headBox, textBox }
function M.dialog.measure(spec) end

--- 绘制：只能在 love.draw() 内调用
-- @param spec, layout
function M.dialog.draw(spec, layout) end

--- 清除当前对话
function M.dialog.clear() end
```

`framework/talk_async.lua` 收缩为只管：**分页节奏 + 等待按键 + `currentTalk` 状态**。

### Alternatives

| 方案 | 否决理由 |
|---|---|
| 保持原语级，但在 framework 加 `textWidth` 测量 | 测量能力仍是渲染细节，不该上浮；且 mud/web 无字体，`textWidth` 在那边只能瞎猜 |
| `EngineAPI.render.textWidth(str,size,fontname)` 单独加一个测量函数 | 方向对了一半但层级仍错：measure 应包含**换行+框尺寸+锚点**整套排版，而非只给一个宽度让 framework 自己算 |
| 单个 `showDialog(head,npc,text)` 一次调用画完并等待 | **技术上不可能**：`ShowSurface` 只在 `inDrawLoop`（即 `love.draw()` 内）为真才 present，引擎不能自己阻塞绘制 |

### Consequences

**正面**
- `framework` 层不再感知字号/行高/框尺寸，引擎各自决定显示算法
- mud/web 可以用 `logCall` 空实现，符合「mud/web 不需要对话框高度」
- 排版算法与引擎字体能力天然对齐（love2d 用真 `getWidth()`）

**负面**
- 需改 4 个引擎相关文件（第 6 次解锁 `game/engine-*/`）
- 三段式比单函数啰嗦：调用方必须「先 measure、后 draw」

---

## ADR-2：`measure` 为纯函数、三段式调用，而非 `showDialog` 一体化

### Context

需求直觉是 `showDialog(team/npc, text, headPic)` 一个调用搞定。但受 ADR-1 的
发现 2 约束：**引擎不能在内部 present 并阻塞**。

```lua
-- lib_love.lua:210
function ShowSurface(flag)
    if inDrawLoop then          -- ← 仅 love.draw() 内为真
        love.graphics.present()
    end
end
```

### Decision

三段式：

```
① EngineAPI.dialog.measure(spec)      → layout     纯函数，可随时调用
② EngineAPI.dialog.draw(spec, layout)              仅在 love.draw() 内
③ EngineAPI.dialog.clear()
```

事件驱动流程：

```
TalkExCoroutine (协程)
  ├─ layout = dialog.measure(spec)      ← 进入新页时算一次，缓存
  ├─ currentTalk = {spec, layout}       ← 供 draw 使用
  ├─ InputAsync.WaitKeyCoroutine()      ← 协程挂起
  │
love.draw() → EventBridge:draw() → TalkAsync.draw()
  └─ EngineAPI.dialog.draw(currentTalk.spec, currentTalk.layout)
```

### Alternatives

| 方案 | 否决理由 |
|---|---|
| `showDialog` 内部 measure + 标记待绘制，draw 时读标记 | 本质仍是三段式，只是把 measure 藏进 draw 内部、每帧重算（性能差且不易测） |
| 引擎内用 `love.graphics.present()` 强制刷新 | 会与 `love.draw()` 的 present 冲突 → 屏幕抖动（`lib_love.lua:211-213` 注释已明确警告） |

### Consequences

- measure 结果缓存在 `currentTalk.layout`，**每页只算一次**，每帧 draw 零计算
- measure 是纯函数 → **可单测**，无需 LÖVE 图形上下文
- 调用方必须理解「先 measure 后 draw」顺序

---

## ADR-3：框宽自适应，框高恒定 = `boxpich`

### Context

需求：① 框长随句子变；② 最少 3 行高，1 行文本显示在第 1 行、其余留空。

框宽可变后，`xy[flag]` 锚点需重算。实测各框宽下均不越界：

| boxtalkw | flag1 talkx | 右边界 | flag0 右边界 |
|---:|---:|---:|---:|
| 298 | 611 | 909 | 412 |
| 500 | 409 | 909 | 614 |
| 700 | 209 | 909 | 814 |
| 908 | 1 | 909 | 1022 |

框高若随行数变，则 6 个 flag 的**垂直**锚点全要重算（flag 1/3/5 底部对齐）。

### Decision

**求值顺序很关键**（先换行、后定框宽）：

```lua
-- ① 先按「上限内宽」做均衡换行，得到 lines
innerMax = 908 - 2*5 = 898
lines    = balancedWrap(text, innerMax)

-- ② 再按实际最宽行求框宽
maxLineW = max(textWidth(line) for line in lines)
框宽 = clamp(maxLineW + 2*pad, 298, 908)
    下限 298 = 12*CC.DefaultFont+10（保持现状观感）
    上限 908 = ScreenW - 2*dx - boxpicw - 2

-- ③ 框高恒定
框高 = boxpich = 110px  （与 110px 头像框平齐）
talkBorder = (110 - 3*27)/4 = 7.25px   （按 3 行固定算）
```

若「先定框宽 = 908、再用 898px 换行」，均衡后行宽通常远小于 908，
框右边会留大片空白：

| 案例 | 自然宽 | 先定框宽（错） | 先换行后定宽（对） | 省下空白 |
|---|---:|---:|---:|---:|
| 韦大宝-1（38 字） | 912 | 908 | **466** | 442px |
| 韦大宝-2（53 字） | 1272 | 908 | **658** | 250px |
| 超长（95 字） | 2280 | 908 | **778** | 130px |

不足 3 行时**顶部对齐**，下方留空。

### Alternatives

| 方案 | 否决理由 |
|---|---|
| 框高随行数收缩（1行37px / 2行64px / 3行91px） | 框与 110px 头像框不等高、视觉不齐；且垂直锚点全部重算，风险大 |
| 框宽固定 298，只修换行 | 用户明确要「框跟随句长」，且 37 字上限下长句仍要翻 2 页 |

### Consequences

- 垂直锚点 **零改动**（`boxpich` 不变）
- 仅 flag 1/3/4 的 `talkx` 需按新框宽重算
- 框宽上限 908px 已扣除头像区，不会遮挡头像

---

## ADR-4：行高从 24 修正为 27（实测 `getHeight()`）

### Context

实测 `simsun.ttf` 字号 24 时：

```
font:getWidth("中")   = 24.00   ← 1.0 em
font:getHeight()      = 27.00   ← ≠ 字号
```

代码用 `CC.DefaultFont = 24` 当行高 → 每行差 3px，3 行累计 9px，下行会被上行下伸部分挤压。

### Decision

`M.dialog` 内部使用实测行高：

```lua
lineHeight = font:getHeight()          -- love2d 引擎
lineHeight = size * 1.125              -- 回退估算（24*1.125 = 27）
```

**`CC.DefaultFont` 保留为 24 不变**（其他 UI 仍用它）。行高 27 只作用于 `dialog` 模块内部。

### Alternatives

| 方案 | 否决理由 |
|---|---|
| 改 `CC.DefaultFont` 为 27 | 违反「不改 `CC.*` 常量」约束，且会影响几十处其他 UI 排版 |
| 保持 24 不修 | 3 行累计 9px 偏差，文字会视觉挤压（用户已确认要修） |

### Consequences

- 3 行满页 `talkBorder` 从 9.50px 变为 7.25px
- 行高仅在 `dialog` 模块内部，零外溢风险

---

## ADR-5：行长度均衡算法（消除孤儿尾行）

### Context

需求：「段内已计算换行后，该行最后的内容要和下一行承接上，不能是短短的最后几个字单独作为一行」。

真实数据：14 条 ≥24 字对话中 **3 条有孤儿尾行**：

```
"你既然是他哥哥，那么本领是不是比他大那么一点点呢？"
  行1(12): 你既然是他哥哥，那么本领
  行2(12): 是不是比他大那么一点点呢
  行3( 1): ？                        ← 孤儿行
```

### Decision

**二分搜索最大行宽**，在「行数不变」前提下使各行等长：

```lua
function balancedWrap(text, maxW):
    n = #greedyWrap(text, maxW)
    if n <= 1: return greedyWrap(text, maxW)
    lo, hi = 1, maxW
    repeat 30 times:                      -- 二分收敛
        mid = (lo+hi)/2
        if #greedyWrap(text, mid) <= n: hi = mid
        else: lo = mid
    return greedyWrap(text, hi)
```

实测在框宽自适应下**不增加行数**：

| 案例 | 贪心 | 均衡 | 页数 |
|---|---|---|---|
| 韦大宝-1（38 字） | `[37, 1]` | `[19, 19]` | 1 → 1 |
| 韦大宝-2（53 字） | `[37, 16]` | `[27, 26]` | 1 → 1 |
| 孤儿行（25 字） | `[25]` | `[25]` | 1 → 1 |

### Alternatives

| 方案 | 否决理由 |
|---|---|
| 纯贪心（现状） | 产生孤儿尾行，正是用户要修的问题 |
| 段间接续（`*` 后内容接着上一行排） | **破坏 `*` 的断行语义**，用户明确「`*` 语义不改」 |
| 最小行数 + 均分字数（非像素） | ASCII/汉字宽度不同，按字数均分仍会视觉不齐 |

### Consequences

- 消除孤儿尾行
- 极端情况下可能多 1 页 —— 用户已确认「多一页可以接受」

---

## ADR-6：末尾空白行裁剪，但保留中间空行

### Context

多个连续 `*` 会产生空行。两种空行语义完全不同：

```
"接下来换谁？**．．．．*．．．．***没有人了吗？"
   行1 '接下来换谁？'
   行2 ''              ← 中间空行，作者故意的视觉间隔
   行3 '．．．．'
   行4 '．．．．'
   行5 ''              ← 中间空行
   行6 ''              ← 中间空行
   行7 '没有人了吗？'
```

### Decision

**只裁末尾**连续的空白行，中间一律保留：

```lua
while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
end
```

实测：

| 输入 | 裁前 | 裁后 | 页数 |
|---|---|---|---|
| `'内容***'` | `['内容','','','']` | `['内容']` | 2 → **1** ✅ |
| `'只有一句**'` | `['只有一句','','']` | `['只有一句']` | 1 → 1 |
| `'内容* * '` | `['内容',' ',' ']` | `['内容']` | 1 → 1 |
| `'接下来换谁？**...***没有人了吗？'` | 7 行含 3 空行 | **不变** | 中间空行保留 ✅ |

### Alternatives

| 方案 | 否决理由 |
|---|---|
| 裁掉所有空白行 | 破坏作者故意的视觉间隔（`**` 是刻意的空行） |
| 不裁 | `'内容***'` 会多出一整页空白 |

### Consequences

- 末尾 `***` 不再产生空白页
- 中间 `**` 语义完整保留

---

## ADR-7：`*` 语义不变，但段内仍自动换行

### Context

现状：有 `*` 就**完全跳过**自动换行。

```lua
if string.find(s, "*") == nil then
    s = GenTalkString(s, talkConfig.charsPerLine)
end
```

9 处调用用了 `*`，其中若有长行必然溢出。

### Decision

`*` = **强制断行符**（语义不变），但每段内部仍按宽度自动换行：

```lua
for seg in text:gmatch("[^*]*") do
    if seg == "" then
        lines[#lines+1] = ""           -- 空段 = 空行
    else
        appendAll(lines, balancedWrap(seg, innerW))
    end
end
```

### Alternatives

| 方案 | 否决理由 |
|---|---|
| 保持「有 `*` 就不换行」 | 长行仍溢出，用户已确认要修 |
| `*` 改为分页符 | 改变语义，破坏 9 处现有调用 |

### Consequences

- 作者写 `*` 仍能控制断行
- 万一某段写超了，自动换行兜底

---

## Negative Constraints（禁止事项）

| # | 禁止 | 原因 |
|:-:|---|---|
| 1 | 不得修改任何 `CC.*` 常量字面值 | 项目硬约束；影响几十处 UI |
| 2 | 不得修改 `CC.ScreenW/H` / `CONFIG.Width/Height` | 分辨率是外部配置 |
| 3 | 不得在 `game/engine-*/` 之外新增对 `love.*` 的直接调用 | 引擎隔离 |
| 4 | 不得让 `dialog.measure` 产生任何绘制副作用 | 必须是纯函数，否则无法单测 |
| 5 | 不得在 `EngineAPI.dialog.draw` 内调用 `present()` | 破坏 `love.draw` 单一 present 点 → 屏幕抖动 |
| 6 | 不得改变 `*` 的「强制断行」语义 | 9 处现有调用依赖 |
| 7 | 不得裁掉中间空白行 | `**` 是作者刻意的视觉间隔 |
| 8 | 不得让 `framework/` require `engine-*` 模块 | 依赖方向必须单向（engine → framework） |

## Review Checklist

- [ ] `EngineAPI.dialog.measure` 是纯函数，无绘制调用、无全局状态写入
- [ ] `EngineAPI.dialog.draw` 内无 `present()` 调用
- [ ] `framework/talk_async.lua` 中不再出现 `CC.DefaultFont` 参与布局计算
- [ ] `framework/talk_async.lua` 中不再出现 `DrawBox` / `DrawString` 直接调用
- [ ] 三个引擎的 `M.dialog` 三函数均已实现（love2d 真实现 / mud+web 空实现）
- [ ] `CC.*` 常量 diff 为空
- [ ] 汉字 1.0em / ASCII 0.5em / 行高 27 三个数字有实测依据
- [ ] 末尾空白裁剪测试含「中间空行必须保留」的反向断言
- [ ] 负向对照：撤掉均衡算法 → 孤儿尾行回归测试必须失败
- [ ] 负向对照：撤掉末尾裁剪 → 空白页测试必须失败
