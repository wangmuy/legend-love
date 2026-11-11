---
status: active
created: 2026-11-02
---
# Spec: dialog-autowrap-adaptive

对话框自动换行 + 框尺寸自适应。所有数值均来自实测（LÖVE 11.5 + `game/simsun.ttf` 字号 24）。

**实测基准**：
```
字体宽度  汉字 = 24.00px (1.0 em)    ASCII = 12.00px (0.5 em)
字体行高  font:getHeight() = 27px    (≠ 字号 24)
屏幕      1024 x 768
框宽范围  [298, 908]px               (12 ~ 37 汉字/行)
框高      恒 110px = boxpich
每页行数  3
```

---

## REQ-DLG-1：新增 `EngineAPI.dialog` 语义模块

**Motivation**：对话框排版算法当前泄露在 `framework/talk_async.lua`，
用 7 种图形原语（`DrawBox`×2 / `DrawString`×1 / `lib.PicGetXY` / `lib.PicLoadCache` /
`lib.GetKey` / `CC.DefaultFont`）逐条下发，坐标全在 Lua 层算好。而同一 EngineAPI 的
`map` 模块已是语义级（`M.map.drawScene(sceneId,x,y,offX,offY,playerPic)`）。
mud/web 引擎没有 `CC.DefaultFont` 的有效语义，Lua 层算出的坐标在那边毫无意义。

### Scenario 1.1：模块存在且三函数齐全

- **Given** 三个引擎实现文件
- **When** 检查 `EngineAPI.dialog`
- **Then** 存在 `measure` / `draw` / `clear` 三个函数

验证命令：
```bash
grep -c "M.dialog.measure\|M.dialog.draw\|M.dialog.clear" game/engine-love2d/engine_api.lua
# 期望 3
grep -c "EngineAPI.dialog.measure\|EngineAPI.dialog.draw\|EngineAPI.dialog.clear" \
  game/engine-love2d/engine_love2d.lua game/engine-mud/engine_mud.lua game/engine-web/engine_web.lua
# 期望 每个文件 3
```

### Scenario 1.2：mud 引擎为空实现 + logCall

- **Given** `game/engine-mud/engine_mud.lua`
- **When** 调用 `EngineAPI.dialog.measure(spec)`
- **Then** 输出 `logCall("dialog.measure", ...)` 且返回 nil（mud 无图形对话框）

验证命令：
```bash
grep -A4 "EngineAPI.dialog.measure" game/engine-mud/engine_mud.lua | grep -c logCall
# 期望 1
```

### Scenario 1.3：web 引擎为空实现

- **Given** `game/engine-web/engine_web.lua`
- **When** 检查 `EngineAPI.dialog.measure`
- **Then** 函数体为空（`function ... end` 单行）

验证命令：
```bash
grep -c "^function EngineAPI.dialog.measure(spec) end" game/engine-web/engine_web.lua
# 期望 1
```

### Scenario 1.4：framework 不再直接调用绘制原语

- **Given** `game/framework/talk_async.lua` 改动后
- **When** 统计 `DrawBox` / `DrawString` / `CC.DefaultFont` 出现次数
- **Then** 三者均为 0（布局与绘制全部下沉到 `EngineAPI.dialog`）

验证命令：
```bash
grep -c "DrawBox\|DrawString" game/framework/talk_async.lua     # 期望 0
grep -c "CC.DefaultFont" game/framework/talk_async.lua          # 期望 0
```

---

## REQ-DLG-2：按真实像素测量自动换行

**Motivation**：现状 `charsPerLine = 13` 但框内仅容 12 字，每满行溢出 24px
（正好 1 个汉字）。`GenTalkString` 的 em 估算本身正确，坏的是阈值。

### Scenario 2.1：换行阈值以框内宽度为唯一真源

- **Given** 框内可用宽 `innerW`
- **When** 对文本流式贪心换行
- **Then** 每行像素宽 ≤ `innerW`，无一行溢出

验证命令（纯函数单测）：
```
for each line in layout.lines:
    assert textWidth(line) <= innerW
```

### Scenario 2.2：汉字与 ASCII 宽度区分

- **Given** 文本含中文与 ASCII 混排
- **When** 计算换行
- **Then** 汉字按 24px（1.0 em）、ASCII 按 12px（0.5 em）累加

实测依据：
```
中              width=24.00
a               width=12.00
a中             width=36.00   (= 12 + 24)
```

验证命令：
```bash
cd /tmp/fontmeasure && love . && cat ~/.local/share/love/fontmeasure/measure.txt
```

### Scenario 2.3：12 字恰好填满，13 字必定换行

- **Given** 框内 288px
- **When** 排版 12 个汉字 / 13 个汉字
- **Then** 12 字 1 行不换行；13 字换行为 2 行

- **Given** `text = "中"×12`, `innerW = 288`
- **When** `layout(text)`
- **Then** `#lines == 1`

- **Given** `text = "中"×13`, `innerW = 288`
- **When** `layout(text)`
- **Then** `#lines == 2`

---

## REQ-DLG-3：框宽随内容自适应

**Motivation**：框宽写死 `12*CC.DefaultFont+10 = 298px`（占屏 29%），长句装不下。

### Scenario 3.1：短句用下限宽度

- **Given** 文本 `"好"`（自然宽 24px）
- **When** `measure(spec)`
- **Then** `layout.width == 298`（下限，不缩到 34px）

实测：
```
【短句】1字 自然宽=24px → 框宽=298px
```

### Scenario 3.2：中等长度按内容宽度

- **Given** 文本 `"欢迎光临佣兵行会，您可以选择任务"`（16 字，自然宽 384px）
- **When** `measure(spec)`
- **Then** `layout.width == 394`（384 + 2×5 内边距），1 行

实测：
```
【中等】16字 自然宽=384px → 框宽=394px 框内=384px，1行
```

### Scenario 3.3：超长文本先换行、后按实际行宽定框

- **Given** 文本自然宽 > 898px
- **When** `measure(spec)`
- **Then** 先按 `innerMax=898` 均衡换行，再令
  `layout.width = clamp(max(textWidth(line))+2*5, 298, 908)`

**求值顺序必须有判别力**：若先定框宽 = 908 再换行，框右会留大片空白。

实测对照：

| 案例 | 自然宽 | 先定框宽（错） | 先换行后定宽（对） | 省下空白 |
|---|---:|---:|---:|---:|
| 韦大宝-1（38 字） | 912 | 908 | **466** | 442px |
| 韦大宝-2（53 字） | 1272 | 908 | **658** | 250px |
| 超长（95 字） | 2280 | 908 | **778** | 130px |

负向断言的写法：断言 `layout.width == 466`（对 38 字案例），
而不是断言「≤ 908」——后者在错误实现下也会通过。

### Scenario 3.4：右锚定 flag 的 talkx 按新框宽重算且不越界

- **Given** flag ∈ {1,3,4}（右锚定）
- **When** `boxtalkw` 变化
- **Then** `talkx = ScreenW-1-dx-boxpicw-boxtalkw-2`，且 `0 ≤ talkx` 且 `talkx+boxtalkw ≤ ScreenW`

实测各框宽下均不越界：

| boxtalkw | flag1 talkx | 右边界 | flag0 右边界 |
|---:|---:|---:|---:|
| 298 | 611 | 909 | 412 |
| 500 | 409 | 909 | 614 |
| 700 | 209 | 909 | 814 |
| 908 | 1 | 909 | 1022 |

---

## REQ-DLG-4：框高恒定 110px，最少 3 行，不足留空

**Motivation**：需求「为跟头像平齐，最少 3 行高，文本只有 1 行就显示在第一行，其他留空」。

### Scenario 4.1：任意行数框高均为 110px

- **Given** 文本为 1 行 / 2 行 / 3 行
- **When** `measure(spec)`
- **Then** `layout.height == 110` 恒成立（= `boxpich`，与头像框等高）

### Scenario 4.2：1 行文本顶部对齐，下方留空

- **Given** 1 行文本
- **When** 计算首行 y 坐标
- **Then** `lineY[1] == textBox.y + 5 + talkBorder`
  且 `talkBorder = (110-3*27)/4 = 7.25`（按 3 行固定算，不按 1 行放大）

验证：
```
talkBorder = 7.25 (恒定)
lineY[1] = talky + 5 + 7.25
lineY[2] = lineY[1] + 27     ← 空行位置（不绘制）
lineY[3] = lineY[2] + 27     ← 空行位置（不绘制）
```

### Scenario 4.3：垂直锚点零改动

- **Given** `boxpich` 不变（110px）
- **When** 对比改动前后 flag 1/3/5 的 `talky`
- **Then** 完全一致（`talky = ScreenH-dy-boxpich` 或 `dy`）

---

## REQ-DLG-5：行高修正为 27px

**Motivation**：实测 `font:getHeight() = 27`，代码用 `CC.DefaultFont = 24` 当行高，
每行差 3px，3 行累计 9px，下行被上行下伸部分挤压。

### Scenario 5.1：行高取实测值

- **Given** 字号 24 的 `simsun.ttf`
- **When** `measure(spec)`
- **Then** `layout.lineHeight == 27`（非 24）

验证依据：
```
font:getHeight()=27.00
```

### Scenario 5.2：`CC.DefaultFont` 常量不变

- **Given** 改动前后
- **When** `git diff game/script/jyconst.lua`
- **Then** diff 为空（`CC.DefaultFont` 仍为 24）

验证命令：
```bash
cd /home/woodfish/project/legend-love && git diff --stat game/script/jyconst.lua
# 期望 无输出
```

### Scenario 5.3：行高仅作用于 dialog 模块内部

- **Given** 其他 UI 仍用 `CC.DefaultFont = 24` 排版
- **When** 检查 `layout.lineHeight` 的消费方
- **Then** 仅 `EngineAPI.dialog` 内部使用，无外溢

---

## REQ-DLG-6：行长度均衡，消除孤儿尾行

**Motivation**：真实数据 14 条 ≥24 字对话中 3 条有孤儿尾行（末行仅 1–3 字）。

### Scenario 6.1：孤儿尾行被均衡掉

- **Given** 文本 `"你既然是他哥哥，那么本领是不是比他大那么一点点呢？"`
- **When** 贪心换行（旧）/ 均衡换行（新）
- **Then** 旧结果末行 1 字；新结果各行长度差 ≤ 最大单字宽

实测对照：

| 案例 | 贪心 | 均衡 |
|---|---|---|
| 韦大宝-1（38 字） | `[37, 1]` | `[19, 19]` |
| 韦大宝-2（53 字） | `[37, 16]` | `[27, 26]` |
| 孤儿行（25 字） | `[25]` | `[25]` |

### Scenario 6.2：均衡不改变行数

- **Given** 贪心换行得到 n 行
- **When** 均衡换行
- **Then** 行数仍为 n（均衡只调整断点，不新增行）

验证：
```
二分搜索 upper bound = maxW, 收敛条件 #greedyWrap(mid) <= n
```

### Scenario 6.3：单行文本不受影响

- **Given** 文本自然宽 ≤ 框内宽
- **When** 均衡换行
- **Then** 1 行原样返回，不做任何调整

---

## REQ-DLG-7：`*` 语义不变（强制断行），段内仍自动换行

**Motivation**：现状「有 `*` 就完全跳过自动换行」，长行必然溢出。9 处调用用 `*`。

### Scenario 7.1：`*` 处强制断行

- **Given** `text = "少侠已连战三场，*可先休息再战．"`，框内宽容纳 12 字
- **When** `measure(spec)`
- **Then** 第 1 行以 `"少侠已连战三场，"` 开头（`*` 位置强制断开）

### Scenario 7.2：段内超长仍自动换行

- **Given** `text = "<20 字>*<3 字>"`，框内宽容纳 12 字
- **When** `measure(spec)`
- **Then** 第 1 段换行为 2 行（12 + 8），再接第 2 段

### Scenario 7.3：连续 `*` 产生空行且保留

- **Given** `text = "接下来换谁？**．．．．*．．．．***没有人了吗？"`
- **When** `measure(spec)`
- **Then** 产生 7 行，其中第 2、5、6 行为空行（保留）

实测：
```
行1 '接下来换谁？'
行2 ''          ← 保留
行3 '．．．．'
行4 '．．．．'
行5 ''          ← 保留
行6 ''          ← 保留
行7 '没有人了吗？'
```

---

## REQ-DLG-8：末尾空白行裁剪，避免空白页

**Motivation**：多个连续 `*` 在末尾会产生空白行，进而多出一整页空白。

### Scenario 8.1：末尾 `***` 不再产生空白页

- **Given** `text = "内容***"`
- **When** `measure(spec)` 后分页
- **Then** 1 页（裁前 2 页）

实测：
```
'内容***'   裁前 ['内容','','',''] (2页) → 裁后 ['内容'] (1页)
```

### Scenario 8.2：中间空行必须保留

- **Given** `text = "接下来换谁？**．．．．*．．．．***没有人了吗？"`
- **When** 末尾裁剪
- **Then** 中间 3 个空行全部保留，仅末尾无空行

这是**反向断言**：若实现错误地裁掉所有空行，本场景必须失败。

### Scenario 8.3：纯空白行（含空格）也算空行

- **Given** `text = "内容* * "`
- **When** 末尾裁剪
- **Then** `["内容"]`（`" "` 也被裁掉，判据是 `^%s*$`）

实测：
```
'内容* * '  裁前 ['内容',' ',' '] (1页) → 裁后 ['内容'] (1页)
```

### Scenario 8.4：无空白时不做任何改动

- **Given** `text = "内容"`
- **When** 末尾裁剪
- **Then** `["内容"]` 不变

---

## REQ-DLG-9：`measure` 是纯函数

**Motivation**：三段式设计中 `measure` 必须可单测，不能依赖 LÖVE 图形上下文或产生绘制副作用。

### Scenario 9.1：无绘制调用

- **Given** `EngineAPI.dialog.measure` 实现
- **When** 静态检查函数体
- **Then** 不含 `present` / `DrawBox` / `DrawString` / `love.graphics.print`

### Scenario 9.2：不写全局状态

- **Given** `EngineAPI.dialog.measure` 调用前后
- **When** 对比 `currentTalk` 等全局状态
- **Then** 无变化（纯计算）

### Scenario 9.3：可重复调用结果一致

- **Given** 同一 `spec`
- **When** 连续调用 `measure` 两次
- **Then** 两次结果 `lines` 内容深度相等

---

## REQ-DLG-10：不改动任何 `CC.*` 常量

**Motivation**：项目硬约束 —— `game/script/jyconst.lua` 的常量字面值禁改。

### Scenario 10.1：jyconst.lua diff 为空

- **Given** 改动完成
- **When** `git diff game/script/jyconst.lua`
- **Then** 无输出

验证命令：
```bash
cd /home/woodfish/project/legend-love && git diff --stat game/script/jyconst.lua
# 期望 无输出
```

### Scenario 10.2：关键常量值不变

- **Given** 运行态
- **When** 读取常量
- **Then** `CC.DefaultFont == 24`、`CC.MenuBorderPixel == 5`、
  `CC.ScreenW == 1024`、`CC.ScreenH == 768`

验证命令：
```bash
cd game && lua -e 'require("framework.config"); require("engine-love2d.lib_love")
print(CC.DefaultFont, CC.MenuBorderPixel, CC.ScreenW, CC.ScreenH)'
# 期望 24  5  1024  768
```

---

## REQ-DLG-11：负向对照（判别力验证）

**Motivation**：断言必须有判别力。撤掉修复后对应测试必须失败。

### Scenario 11.1：撤掉均衡算法 → 孤儿尾行测试失败

- **Given** 将 `balancedWrap` 替换为纯 `greedyWrap`
- **When** 运行 `test_dialog_layout`
- **Then** 至少 1 个断言失败（孤儿尾行回归）

### Scenario 11.2：撤掉末尾裁剪 → 空白页测试失败

- **Given** 注释掉末尾裁剪循环
- **When** 运行 `test_dialog_layout`
- **Then** `"内容***"` 的分页断言失败（应为 1 页，实为 2 页）

### Scenario 11.3：撤掉框宽自适应 → 框宽测试失败

- **Given** 框宽硬编码返回 298
- **When** 运行 `test_dialog_layout`
- **Then** 「中等长度按内容宽度」断言失败（应 394，实 298）

### Scenario 11.4：把行高改回 24 → 行高测试失败

- **Given** `layout.lineHeight = 24`
- **When** 运行 `test_dialog_layout`
- **Then** `lineHeight == 27` 断言失败
