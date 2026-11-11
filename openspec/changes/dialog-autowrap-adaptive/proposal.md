---
status: active
created: 2026-11-02
parent_epic: null
---
# Proposal: dialog-autowrap-adaptive

## Why

原版「韦大宝」及部分 MOD 对话文本过长时会**溢出对话框外框**。经实测定位，
这不是单点 bug，而是 **三个叠加缺陷**，且第一个是原版基因、第二个是本项目引入的回归。

### 缺陷 1：换行阈值比框内宽度大（本项目回归）

`framework/talk_async.lua` 把原版的换行字数从 `12` 改成了 `13`：

| 位置 | 代码 | 换行阈值 | 框内可用 | 结果 |
|---|---|---:|---:|---|
| 原版 `~/project/legend-mac-orig/bin/script/jymain.lua:3077` | `GenTalkString(s,12)` | 288px | 288px | ✅ 刚好 |
| 本项目 `game/framework/talk_async.lua:15` | `charsPerLine = 13` | 312px | 288px | ❌ **溢出 24px** |

`GenTalkString` 的像素估算本身是对的 —— `simsun.ttf` 实测汉字恰为 24.00px（1.0 em），
ASCII 恰为 12.00px（0.5 em），与 `charPixelWidth = CC.DefaultFont` 一致。
**坏的只是喂进去的阈值**：多 1 个字正好吃掉整行余量。

### 缺陷 2：手工 `*` 完全跳过自动换行（原版基因）

```lua
-- talk_async.lua:159
if string.find(s, "*") == nil then
    s = GenTalkString(s, talkConfig.charsPerLine)
end
```

只要作者写了 `*`，系统**一个字的换行都不做**。作者用 `*` 是想控制断行，
但某行写长了就必然溢出且系统不管。全项目 29 处 `TalkEx` 调用中 9 处含 `*`。

### 缺陷 3：框尺寸与行高写死，且行高假设与字体实测不符

| 项 | 代码值 | 实测值 | 偏差 |
|---|---|---|---|
| 框宽 | `12*CC.DefaultFont+10 = 298px` | — | 占屏 29%，长句装不下 |
| 框高 | `boxpich = 110px` | — | 固定 3 行，不随内容 |
| 行高 | `CC.DefaultFont = 24px` | `font:getHeight() = 27px` | **每行差 3px**，3 行累计 9px |

### 缺陷 4（架构）：排版算法泄露到了 framework 层

对话框当前用 **7 种图形原语**逐条下发（`DrawBox`×2、`DrawString`×1、
`lib.PicGetXY`、`lib.PicLoadCache`、`lib.GetKey`、`CC.DefaultFont`），
坐标全部由 Lua 层算好。对比同一 EngineAPI 里的 `map` 模块：

```lua
-- 已经是语义级：Lua 说"画这个场景"，引擎自己决定怎么画
function M.map.drawScene(sceneId, x, y, offX, offY, playerPic) end
```

对话框却是**原语级**。而三个引擎能力差异巨大：

| 能力 | love2d | mud | web |
|---|---|---|---|
| `DrawBox` / `DrawString` | 真画 | 空实现 + log | 空实现 |
| `CC.DefaultFont = 24` | 有效 | **无意义** | **无意义** |

`talk_async.lua` 读 `CC.DefaultFont` 算坐标，在 mud/web 上这个数字纯属浪费且不反映真实排版。

### 参考调研：KYS 引擎无可借鉴的自动换行

按要求先查了 `reference/allmods/` 的 KYS 引擎：

| 检验项 | 结果 |
|---|---|
| KYS 源码 | ❌ 只有编译后的 `kys.exe`（Free Pascal） |
| 二进制里的 `WordWrap`/`SetWordWrap` | ❌ Lazarus/LCL **控件自带**，与对话无关 |
| KYS 脚本 `talk()` 用法 | **19 处 ≥20 字全部手工写 `*`，0 处依赖自动换行** |

**但 KYS 提供了一个重要的正面证据**：20 个 MOD 分辨率各不相同
（640×440 / 640×480 / 960×660）却都能正常显示 —— 说明对话框尺寸是
**运行时按分辨率算的，不是写死像素**。这正是本变更「自适应」目标的依据。

## What Changes

| # | 改动 | 文件 | 类型 |
|:-:|---|---|---|
| 1 | 新增 `M.dialog` 语义模块（`measure` / `draw` / `clear`） | `game/engine-love2d/engine_api.lua` | 接口定义 |
| 2 | 实现 `M.dialog`（真排版 + 真绘制） | `game/engine-love2d/engine_love2d.lua` | 实现 |
| 3 | 实现 `M.dialog`（空实现 + `logCall`） | `game/engine-mud/engine_mud.lua` | 实现 |
| 4 | 实现 `M.dialog`（空实现） | `game/engine-web/engine_web.lua` | 实现 |
| 5 | `talk_async.lua` 瘦身：删除排版/坐标计算，改为调用 `EngineAPI.dialog` | `game/framework/talk_async.lua` | 重构 |
| 6 | 同步 `script/jymain.lua` 的原版 `TalkEx`（阻塞路径） | `game/script/jymain.lua` | 重构 |
| 7 | 新增单测（排版算法 / 框宽自适应 / `*` 语义 / 翻页 / 负向对照） | `game/tests/unit/test_dialog_layout.lua` | 测试 |

## 关键技术发现

### 发现 1：字体度量实测（整个方案的地基）

实测环境：LÖVE 11.5 + `game/simsun.ttf`，字号 24。

```
中                            width=24.00  per-char=8.000   ← 1.0 em
中中中中中中中中中中中中 width=288.00              ← 12 字 = 框内宽度，刚好
中中中中中中中中中中中中中 width=312.00              ← 13 字，溢出 24px
a                             width=12.00  per-char=12.000  ← 0.5 em
aa                            width=24.00
font:getHeight()=27.00                                    ← ≠ 24
```

⇒ **汉字 = 1.0 em，ASCII = 0.5 em，行高 = 27px（≠字号）**。
这三个数字是全自动换行、框宽自适应、行高修正的唯一依据。

### 发现 2：引擎不能在 `dialog.show` 内部 present 并阻塞

```lua
-- lib_love.lua:210
function ShowSurface(flag)
    -- 在 Love2D 事件驱动架构中，只有 love.draw() 应该调用 present()
    if inDrawLoop then
        love.graphics.present()
    end
end
```

`inDrawLoop` 只在 `love.draw()` 内为真。因此 API 必须拆成三段式：

```
EngineAPI.dialog.measure(spec)          → layout   纯计算，不绘制
EngineAPI.dialog.draw(spec, layout)     引擎画（在 love.draw 内）
EngineAPI.dialog.clear()
```

`measure` 是**纯函数**，这让排版算法可以留在引擎层而不破坏事件驱动架构。

### 发现 3：框高应恒等于 `boxpich`，不必随行数收缩

需求「最少 3 行高，1 行文本显示在第 1 行，其余留空」有两种实现：

| 方案 | 1 行 | 2 行 | 3 行 | 垂直锚点 |
|---|---:|---:|---:|---|
| A. 框高随内容收缩 | 37px | 64px | 91px | ❌ 6 个 flag 全要重算 |
| B. **框高恒 = 110px** | 110px | 110px | 110px | ✅ 零改动 |

选 **B**：框始终与 110px 头像框等高，视觉平齐；`talkBorder` 按 3 行固定算
（`(110-3*27)/4 = 7.25px`），不足 3 行则顶部对齐、下方留空。

### 发现 4：框宽自适应只需重算「右锚定」的 talkx

`xy[flag]` 中 flag 1/3/4 的 `talkx` 依赖 `boxtalkw`：

```
flag 0,2,5 (左锚): talkx = dx + boxpicw + 2               ← 不依赖框宽，零改动
flag 1,3,4 (右锚): talkx = ScreenW-1-dx-boxpicw-w-2       ← 必须按 w 重算
```

实测各框宽下均不越界（`MAXW = 1024-2*2-110-2 = 908px`）：

| boxtalkw | flag1 talkx | 右边界 | flag0 右边界 | 越界 |
|---:|---:|---:|---:|---|
| 298 | 611 | 909 | 412 | 无 |
| 500 | 409 | 909 | 614 | 无 |
| 700 | 209 | 909 | 814 | 无 |
| 908 | 1 | 909 | 1022 | 无 |

### 发现 5：真实数据中的「孤儿尾行」

扫描 `game/script/**/*.lua` 中长度 ≥24 的 14 条对话，**3 条有孤儿尾行**：

```
"你既然是他哥哥，那么本领是不是比他大那么一点点呢？"
  行1(12): 你既然是他哥哥，那么本领
  行2(12): 是不是比他大那么一点点呢
  行3( 1): ？                        ← 孤儿行
```

这印证了「行长度平衡」需求。实测均衡算法在框宽自适应下**不增加行数**：

| 案例 | 贪心 | 均衡 | 页数变化 |
|---|---|---|---|
| 韦大宝-1（38 字） | `[37, 1]` | `[19, 19]` | 1 → 1 ✅ |
| 韦大宝-2（53 字） | `[37, 16]` | `[27, 26]` | 1 → 1 ✅ |
| 孤儿行（25 字） | `[25]` | `[25]` | 1 → 1 ✅ |

### 发现 6：末尾空白裁剪必须区分「中间空行」与「末尾空行」

`*` 语义保持不变（= 强制断行）。多个连续 `*` 产生空行，其中：

| 位置 | 例子 | 处理 |
|---|---|---|
| 中间空行 | `"接下来换谁？**．．．．*．．．．***没有人了吗？"` | **必须保留**（作者故意的视觉间隔） |
| 末尾空行 | `"内容***"` | **必须裁掉**（否则多出空白页） |

实测裁剪效果：

```
'内容***'   裁前 ['内容','','',''] (2页) → 裁后 ['内容'] (1页)   ⚠️消除空白页
'只有一句*'  裁前 ['只有一句','']   (1页) → 裁后 ['只有一句'] (1页)
```

## 设计参数（全部由实测推导）

| 参数 | 值 | 来源 |
|---|---|---|
| 屏幕 | 1024 × 768 | `CONFIG.Width/Height` |
| 字号 | 24 | `CC.DefaultFont`（Type==1） |
| 行高 | **27** | `font:getHeight()` 实测 |
| 汉字宽 | 24.00 = 1.0 em | 实测 |
| ASCII 宽 | 12.00 = 0.5 em | 实测 |
| 框宽下限 | 298px（12 字） | 保持现状观感 |
| 框宽上限 | 908px（37 字） | `ScreenW-2*dx-boxpicw-2`，占满除头像外全部屏宽 |
| 框宽求值顺序 | **先均衡换行 → 再按实际最宽行定宽** | 若先定 908 再换行，框右会留大片空白 |
| 框高 | 恒 110px = `boxpich` | 与头像框平齐 |
| 每页行数 | 3 | 保持不变 |
| 满 3 行边距 | 7.25px | `(110-3*27)/4` |
| 内边距 | 5px | `CC.MenuBorderPixel` |

## In Scope

- EngineAPI 新增 `M.dialog` 语义模块（`measure` / `draw` / `clear`）
- 三个引擎实现（love2d 真实现，mud/web 空实现 + log）
- 按真实像素测量换行（汉字 1.0em / ASCII 0.5em / 行高 27）
- 框宽随内容自适应：先均衡换行，再 `clamp(实际最宽行+2*pad, 298, 908)`
- 框高恒 110px，不足 3 行留空
- 行长度均衡（消除孤儿尾行）
- 手工 `*` 语义不变 + 段内仍自动换行
- 末尾空白行裁剪（避免空白页）
- 行高从 24 修正为 27
- 同步 `script/jymain.lua` 的阻塞版 `TalkEx`
- 单元测试 + 负向对照

## Out of Scope

- 不改 `CC.*` 常量（`DefaultFont` / `MenuBorderPixel` 等保持原值）
- 不改 `CC.ScreenW/H` / `CONFIG.Width/Height`
- 不做竖排 / 富文本 / 字体大小运行时切换
- 不改 `*` 的语义（仍是强制断行，不是分页符）
- 不实现 mud/web 的真实对话框渲染（只需空实现，mud/web 无图形对话框需求）
- 不改 mod 脚本中的对话内容

## 风险与缓解

| 风险 | 缓解 |
|---|---|
| 框宽变大导致遮挡地图 | 框高不变、框仅在对话期间存在；上限 908px 已扣除头像区 |
| `measure` 每帧重算性能 | layout 随 `currentTalk` 缓存一次，只在进入新页时 measure |
| 均衡算法改变翻页位置 | 已实测：框宽自适应下不增加行数；且用户已确认「多一页可接受」 |
| 行高 24→27 影响其他绘制点 | 仅 `dialog` 模块使用；`CC.DefaultFont` 保留给其他 UI |
| mud/web 空实现导致行为差异 | 与现有 `map.drawScene` 等语义级调用同模式；mud/web 本就不渲染图形 |

## 父上下文

无父 epic。本变更为独立缺陷修复 + 架构改进。
