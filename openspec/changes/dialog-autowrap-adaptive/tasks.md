---
status: active
created: 2026-11-02
---
# Tasks: dialog-autowrap-adaptive

## 前置说明

**`game/engine-*/` 第 6 次解锁**（前 5 次：4× `isRunning` `80b0152` + 1× 字号 `262130f`）。
仅限本变更的 `M.dialog` 模块，不改动任何既有函数。

**禁止路径**（本次全部不触碰）：
- `game/script/jyconst.lua` 的 `CC.*` 常量字面值
- `reference/allmods/**`

---

## 组 1：EngineAPI 接口定义

Blast Radius: `["game/engine-love2d/engine_api.lua"]`

- [x] 1.1 新增 `M.dialog = {}` 模块段（放在 `M.font` 之后，`M.color` 之前）
  DoD:
    - [x] `grep -c "^M.dialog = {}" game/engine-love2d/engine_api.lua` == 1
    - [x] 文件仍 `luac -p` 通过

- [x] 1.2 定义 `M.dialog.measure(spec)`
  DoD:
    - [x] 签名注释说明 `spec` 字段：`text` / `headId` / `flag` / `maxLines`
    - [x] 返回注释说明 `layout` 字段：`width` / `height` / `lineHeight` / `lines` / `headBox` / `textBox`
    - [x] `grep -c "function M.dialog.measure" ` == 1

- [x] 1.3 定义 `M.dialog.draw(spec, layout)`
  DoD:
    - [x] 注释显式标注 `只能在 love.draw() 内调用`
    - [x] `grep -c "function M.dialog.draw"` == 1

- [x] 1.4 定义 `M.dialog.clear()`
  DoD:
    - [x] `grep -c "function M.dialog.clear"` == 1

- [x] 1.5 接口文件自检
  DoD:
    - [x] `lua -e 'local M=dofile("game/engine-love2d/engine_api.lua"); assert(M.dialog and M.dialog.measure and M.dialog.draw and M.dialog.clear)'` 通过

---

## 组 2：排版算法（纯函数，可单测）

Blast Radius: `["game/framework/dialog_layout.lua"]`

> 说明：排版算法放在 `framework/`（引擎无关纯函数），由引擎实现调用。
> 这样 love2d/mud/web 可共用同一套换行逻辑，仅 `measure` 内的字体度量各自提供。
> `framework/` 不 require `engine-*`，符合依赖方向约束。

- [x] 2.1 `charWidth(ch, size)` — 汉字 1.0em / ASCII 0.5em
  DoD:
    - [x] `charWidth("中",24)` == 24
    - [x] `charWidth("a",24)` == 12
    - [x] `charWidth("a",24)+charWidth("中",24)` == 36（与实测 `a中=36.00` 一致）
    - [x] UTF-8 多字节字符正确识别（`#ch == 3` 视为汉字宽）

- [x] 2.2 `textWidth(s, size)` — 累加字符宽
  DoD:
    - [x] `textWidth("中"×12, 24)` == 288
    - [x] `textWidth("中"×13, 24)` == 312
    - [x] `textWidth("", 24)` == 0

- [x] 2.3 `greedyWrap(text, maxW, size)` — 贪心换行
  DoD:
    - [x] 每行 `textWidth(line) <= maxW`
    - [x] 不丢失字符：`table.concat(lines)` == 原文
    - [x] `textWidth("中"×12)==288` 时 12 字 → 1 行；13 字 → 2 行

- [x] 2.4 `balancedWrap(text, maxW, size)` — 二分均衡
  DoD:
    - [x] 行数与 `greedyWrap` 相同
    - [x] 不丢失字符：`table.concat(lines)` == 原文
    - [x] 单行输入原样返回
    - [x] `"你既然是他哥哥，那么本领是不是比他大那么一点点呢？"` 在 `maxW=288` 下
          末行长度 ≥ 4（消除孤儿行；旧贪心末行 1 字）

- [x] 2.5 `splitByStar(text)` — `*` 切段，空段转空行
  DoD:
    - [x] `"a*b"` → `{"a","b"}`
    - [x] `"a**b"` → `{"a","","b"}`
    - [x] `"a***"` → `{"a","","",""}`
    - [x] `""` → `{""}`

- [x] 2.6 `trimTrailingBlank(lines)` — 只裁末尾空白
  DoD:
    - [x] `{"内容","","",""}` → `{"内容"}`
    - [x] `{"内容"," "," "}` → `{"内容"}`（`^%s*$` 判据）
    - [x] `{"a","","b"}` → **不变**（中间空行保留）
    - [x] `{"内容"}` → 不变

- [x] 2.7 `layoutText(text, opts)` — 顶层排版（切段 → 段内换行 → 裁末尾 → 分页）
  DoD:
    - [x] `"少侠已连战三场，*可先休息再战．"` 第 1 行以 `"少侠已连战三场，"` 开头
    - [x] `"内容***"` 分页数 == 1
    - [x] `"接下来换谁？**．．．．*．．．．***没有人了吗？"` 含 3 个空行
    - [x] 每页行数 ≤ 3

---

## 组 3：love2d 引擎实现

Blast Radius: `["game/engine-love2d/engine_love2d.lua"]`

- [x] 3.1 `EngineAPI.dialog.measure(spec)` — 真实现
  DoD:
    - [x] 通过 `lib_love` 的 `getFont` 取真实字体对象
    - [x] `lineHeight` 优先用 `font:getHeight()`（实测 27）
    - [x] 框宽求值顺序：**先均衡换行 → 再按实际最宽行** `clamp(maxLineW+2*5, 298, 908)`
    - [x] 韦大宝 38 字案例框宽为 466（不是 908 —— 后者说明顺序错了）
    - [x] 框高恒 110（= `pich+10`）
    - [x] 6 个 flag 的 `textBox` / `headBox` 坐标齐全；flag 1/3/4 的 `talkx` 按实际框宽重算
    - [x] 无任何绘制调用（`grep` 函数体内无 `present` / `DrawBox` / `DrawString` / `love.graphics.print`）

- [x] 3.2 `EngineAPI.dialog.draw(spec, layout)` — 真实现
  DoD:
    - [x] 绘制头像框 + 头像（`headId >= 0` 时）
    - [x] 绘制对话框（`DrawBox`）
    - [x] 逐行绘制文字，行距用 `layout.lineHeight`（27）
    - [x] 函数体内无 `present()` 调用
    - [x] 不足 3 行时顶部对齐（`lineY[i] = textBox.y+5+border+(i-1)*lineHeight`）

- [x] 3.3 `EngineAPI.dialog.clear()`
  DoD:
    - [x] 清空引擎侧对话状态（若有）
    - [x] 幂等（连续调用两次不报错）

- [x] 3.4 引擎文件自检
  DoD:
    - [x] `luac -p game/engine-love2d/engine_love2d.lua` 通过
    - [x] 既有 53 个函数一个不少：`grep -c "^EngineAPI\." ` 计数 ≥ 53+3

---

## 组 4：mud / web 引擎空实现

Blast Radius: `["game/engine-mud/engine_mud.lua", "game/engine-web/engine_web.lua"]`

- [x] 4.1 mud：三函数空实现 + `logCall`
  DoD:
    - [x] `EngineAPI.dialog.measure` 含 `logCall("dialog.measure", ...)`，返回 nil
    - [x] `EngineAPI.dialog.draw` 含 `logCall("dialog.draw", ...)`
    - [x] `EngineAPI.dialog.clear` 含 `logCall("dialog.clear")`
    - [x] `luac -p` 通过
    - [x] 既有 49 个函数一个不少

- [x] 4.2 web：三函数空实现
  DoD:
    - [x] 三个 `function EngineAPI.dialog.X(...) end` 单行空实现
    - [x] `luac -p` 通过
    - [x] 既有 73 个函数一个不少

---

## 组 5：`talk_async.lua` 瘦身

Blast Radius: `["game/framework/talk_async.lua"]`

- [x] 5.1 删除 `talkConfig` 中的排版参数
  DoD:
    - [x] 移除 `charsPerLine`（阈值改由引擎 measure 决定）
    - [x] 移除 `talkxnum` / `picw` / `pich`（坐标计算下沉）
    - [x] 保留 `talkynum = 3`（分页节奏仍在 framework）

- [x] 5.2 删除 `getTalkPosition(flag)` 整个函数
  DoD:
    - [x] `grep -c "getTalkPosition" game/framework/talk_async.lua` == 0

- [x] 5.3 `TalkExCoroutine` 改为「measure 一次 → 缓存 → 分页等键」
  DoD:
    - [x] 进入新页时调 `EngineAPI.dialog.measure(spec)`，结果存入 `currentTalk.layout`
    - [x] 删除 `GenTalkString` 调用：`grep -c "GenTalkString" talk_async.lua` == 0
    - [x] 删除 `talkBorder` 计算：`grep -c "talkBorder" talk_async.lua` == 0
    - [x] 保留 `InputAsync.WaitKeyCoroutine()` 与 `clearCurrentKey()` 逻辑
    - [x] 保留 `TalkAsync.clear()` 与 `draw()` 的 `GAME_WMAP`/`GAME_DEAD`/`GAME_START` 守卫（`7f462a2` 的修复不得回退）

- [x] 5.4 `TalkAsync.draw()` 改为单次 `EngineAPI.dialog.draw`
  DoD:
    - [x] `grep -c "DrawBox\|DrawString" game/framework/talk_async.lua` == 0
    - [x] `grep -c "CC.DefaultFont" game/framework/talk_async.lua` == 0
    - [x] `lib.PicGetXY` / `lib.PicLoadCache` 调用从本文件消失（下沉到引擎）
    - [x] 战斗状态守卫仍在

- [x] 5.5 自检
  DoD:
    - [x] `luac -p game/framework/talk_async.lua` 通过
    - [x] `grep -c "require(\"engine-" game/framework/talk_async.lua` == 0（依赖方向）

---

## 组 6：`jymain.lua` 阻塞版 `TalkEx` 同步

Blast Radius: `["game/script/jymain.lua"]`

- [x] 6.1 `TalkEx` 改为复用 `EngineAPI.dialog` 排版
  DoD:
    - [x] 删除本地 `boxtalkw` / `boxtalkh` / `talkBorder` 计算
    - [x] 删除 `xy` 表（6 个 flag 坐标）
    - [x] 改为 `measure` + 逐页 `draw` + `WaitKey`
    - [x] `grep -c "GenTalkString(s,12)" game/script/jymain.lua` == 0

- [x] 6.2 `GenTalkString` 保留但不再被 `TalkEx` 调用
  DoD:
    - [x] 函数定义仍在（其他调用方可能引用）
    - [x] `grep -c "GenTalkString" game/script/jymain.lua` 仅剩定义处 1 次

- [x] 6.3 自检
  DoD:
    - [x] `luac -p game/script/jymain.lua` 通过
    - [x] `git diff --stat game/script/jyconst.lua` 无输出（`CC.*` 未动）

---

## 组 7：单元测试

Blast Radius: `["game/tests/unit/test_dialog_layout.lua", "game/tests/test_runner.lua"]`

- [x] 7.1 新建 `test_dialog_layout.lua`，覆盖组 2 全部纯函数
  DoD:
    - [x] `charWidth` / `textWidth` / `greedyWrap` / `balancedWrap`
    - [x] `splitByStar` / `trimTrailingBlank` / `layoutText`
    - [x] 至少 30 个断言

- [x] 7.2 框宽自适应测试（REQ-DLG-3）
  DoD:
    - [x] 短句 `"好"` → 298
    - [x] 中等 16 字 → 394
    - [x] 韦大宝 38 字 → **466**（先换行后定宽的判别点；若得 908 说明顺序错）
    - [x] 韦大宝 53 字 → 658
    - [x] 任何情况下 ≤ 908
    - [x] flag 1/3/4 在 298/500/700/908 四种框宽下均不越界

- [x] 7.3 `*` 语义测试（REQ-DLG-7）+ 末尾裁剪（REQ-DLG-8）
  DoD:
    - [x] `"内容***"` → 1 页
    - [x] `"接下来换谁？**...***没有人了吗？"` → 3 个中间空行保留（**反向断言**）
    - [x] `"内容* * "` → `{"内容"}`

- [x] 7.4 行高测试（REQ-DLG-5）
  DoD:
    - [x] `layout.lineHeight == 27`
    - [x] `talkBorder == 7.25`

- [x] 7.5 注册到 `test_runner.lua`
  DoD:
    - [x] `require("tests.unit.test_dialog_layout")` 已加入
    - [x] `lua tests/test_runner.lua dialog_layout` 可单独运行且全通过

- [x] 7.6 全量回归
  DoD:
    - [x] `lua tests/test_runner.lua` 总数 ≥ 2188 + 新增数，0 failed
    - [x] 输出含 `✓ 所有测试通过!`
    - [x] `test_new_event` 仍 73/73/0

---

## 组 8：负向对照（判别力验证）

Blast Radius: `["game/tests/unit/test_dialog_layout.lua"]`（临时改动，验证后还原）

- [x] 8.1 撤掉均衡算法 → 孤儿尾行测试必须失败
  DoD:
    - [x] 临时把 `balancedWrap` 改为直接 `return greedyWrap(...)`
    - [x] 运行测试，出现 `[FAIL]` 且失败项含「孤儿尾行」
    - [x] 还原后 `[FAIL]` 消失

- [x] 8.2 撤掉末尾裁剪 → 空白页测试必须失败
  DoD:
    - [x] 临时注释 `trimTrailingBlank` 调用
    - [x] `"内容***"` 分页断言失败（期望 1 页，实得 2 页）
    - [x] 还原后通过

- [x] 8.3 框宽硬编码 → 框宽测试必须失败
  DoD:
    - [x] 临时 `layout.width = 298` 恒定
    - [x] 「中等 16 字 → 394」断言失败
    - [x] 还原后通过

- [x] 8.4 行高改回 24 → 行高测试必须失败
  DoD:
    - [x] 临时 `lineHeight = 24`
    - [x] `lineHeight == 27` 断言失败
    - [x] 还原后通过

- [x] 8.5 记录负向对照结果
  DoD:
    - [x] 4 组负向对照的实际 `[FAIL]` 输出粘入提交信息
    - [x] 每组注明「撤掉什么 / 哪条断言失败 / 还原后通过」

---

## 组 9：实机验证

Blast Radius: `[]`（只读验证）

- [x] 9.1 韦大宝长对话
  DoD:
    - [x] `./tools/run-mod.sh --vanilla`
    - [x] 河洛客栈 → 韦大宝 → 空格触发对话
    - [x] 「咦？你刚才还在外面…移行幻影之术？」完整显示不溢出
    - [x] 「那当然，他的那些货色…要不要试试看？」（53 字）完整显示不溢出
    - [x] 框宽随句子变化，框高与头像框平齐

- [x] 9.2 短句框宽
  DoD:
    - [x] 「祝你好运！」等短句框宽为下限 298px，不缩成窄条

- [x] 9.3 含 `*` 的对话
  DoD:
    - [x] 「少侠已连战三场，*可先休息再战．」在 `*` 处断行
    - [x] 「接下来换谁？**．．．．*．．．．***没有人了吗？」空行保留，末尾无空白页

- [x] 9.4 回归：既有修复不回退
  DoD:
    - [x] 场景名提示正常（`ed0ead4`）
    - [x] 传送/取消对话后键盘正常（`627a60c`）
    - [x] 佣兵行会战斗失败能回场景（`7f462a2`）
    - [x] 战斗画面无选项单残留（`5b87b00`）

- [x] 9.5 日志检查
  DoD:
    - [x] 开启 `CONFIG.Debug=1` 后 `debug.txt` 无 `attempt to` 错误
    - [x] `error.txt` 为空

---

## 组 10：文档同步

Blast Radius: `["AGENTS.md", "ENGINE_API_DESIGN.md", "ARCHITECTURE.md"]`

- [x] 10.1 `ENGINE_API_DESIGN.md` 增加 `M.dialog` 模块说明
  DoD:
    - [x] 记录 measure/draw/clear 三函数签名
    - [x] 记录「三段式」原因（`ShowSurface` 仅 `inDrawLoop` 内 present）
    - [x] 更新函数总数（46 → 49）

- [x] 10.2 `AGENTS.md` 记录 EngineAPI 模块表新增 `dialog`
  DoD:
    - [x] 模块列表含 `dialog`
    - [x] 注明 mud/web 为空实现

- [x] 10.3 提交信息
  DoD:
    - [x] 含「撤掉修复 vs 修复后」实测对照表
    - [x] 含 4 组负向对照结果
    - [x] 含字体度量实测数据（1.0em / 0.5em / 27px）
