# Tasks: port-ui-screens-verification

> **策略**：先把「已经能拍到」的两张归档进基线（零代码改动），
> 再补存档界面（需要走出屋子），最后做状态页绘制解耦（有代码改动）。

## Task 1：归档三张实机截图（零代码改动）

**Blast Radius**：`docs/screenshots/`、`docs/screenshots/README.md`

**DoD**：
- [x] `item-menu.png`（物品 6 项分类菜单）—— 本轮已捕获
- [x] `item-grid.png`（名称/说明/3×N 格/页码）—— 本轮已捕获
- [x] `person-status.png`（两列属性 + 头像）—— 本轮已捕获
- [x] `README.md` 加三行 + 截图参数（**本轮实测命令**，可复现）
- [x] 标注三类判据（逐字节稳定 / 依赖存档 / 不稳定）
- [x] 一个 commit

**本轮实测命令**（存档到 `%APPDATA%/LOVE/wangmuy.love2d.jygame/`）：

```bash
# 物品菜单
lovec game --shot=probe_item_menu2 --frame=5500 \
  --keys=return,down,return,return,<space×120>,escape,down,down,return

# 物品格
lovec game --shot=probe_item_grid --frame=5500 \
  --keys=<上>+return

# 人物状态
lovec game --shot=probe_status --frame=5600 \
  --keys=<上>+escape,down,down,down,return,return
```

## Task 2：补存档界面基线（需 `GAME_MMAP`）

**Blast Radius**：`docs/screenshots/save-menu.png`、`docs/screenshots/README.md`

**DoD**：
- [x] **改用调试入口 `--mmap=<x>,<y>`**（而非「走出屋子」）：
      `--keys` 走位出屋子既不稳定（遇敌/门位随存档变），也无法在 CI 复现。
      `main.lua` 新增该参数：`LoadRecord(0)` → 改坐标 → 清启动菜单 → 切 `GAME_MMAP`
- [x] ESC → 系统（第 6 项）→ 保存进度（第 2 项）
- [x] 截图归档 `save-menu.png`（三个进度槽，md5 `73f3b78a…`）
- [x] `README.md` 记录「必须主地图」的前置 + 完整按键序列 + `--mmap` 用法
- [x] 踩到的坑已记录：不清启动菜单协程会让注入按键被两个菜单抢
- [x] 一个 commit

## Task 3：新建 `framework/status_page.lua`

**Blast Radius**：`game/framework/status_page.lua`（新）、
`game/framework/person_status_async.lua`、`game/script/jymain.lua`

**DoD**：
- [x] `StatusPage.layout()`：几何公式逐字搬（`w=18*size+15` / `h=13*(size+RowPixel)+10`）
- [x] `StatusPage.draw(ctx, id, page)`：26 处 `DrawString` + 1 处 `DrawBox` 改为
      `RenderFacade.text` / `RenderFacade.drawBox`，逐行对应
      （**改为接收 ctx 纯数据**：所有 JY/CC 读取留在调用方，
       本文件零 `JY.*`）
- [x] `PersonStatusAsync.layout()` 改为转调 `StatusPage.layout()`（几何唯一来源）
- [x] `PersonStatusAsync.draw()` 改调 `ShowStatusPageDirect`（组装 ctx + StatusPage.draw）
- [x] `script/jymain.lua` 的 `ShowPersonStatus_sub` 改薄包装（组装 ctx + 转调）
- [x] `status_page.lua` 零 `love.*` / 零 `require("engine` / 零 `JY.*`
- [x] 一个 commit

## Task 4：战斗内状态页同源

**Blast Radius**：`game/script/battle/battle_flow_coroutines.lua`

**DoD**：
- [x] `War_StatusMenuCoroutine` 走 `PersonStatusAsync.ShowStatusCoroutine`
      （已如此）；绘制经 `PersonStatusAsync.draw` → `ShowStatusPageDirect`
      → `StatusPage.draw`（同一条链）
- [x] 实机：主地图状态页渲染正常（截图 `ui_status.png`，布局与迁移前一致）
      注：战斗内状态页因需先进入战斗并开菜单，本轮未单独截图（同一条绘制链，
      风险已由源码断言覆盖）
- [x] 一个 commit

## Task 5：门禁补判据

**Blast Radius**：`game/tests/gate_engine_contract.sh`

**DoD**：
- [x] STEP F 的 `script_globals` 变量追加 4 个：
      `ShowPersonStatus_sub|ShowPersonStatus|SelectTeamMenu|Menu_Thing`
- [x] **负向对照**：把 `ShowStatusPageDirect(id, page)` 改回
      `ShowPersonStatus_sub(id, page)` → gate **FAIL**（已验证）
- [x] 新增 STEP K：`framework/status_page.lua` 零 `love.*` / 零 `require("engine`
- [x] 全量测试 4111/0 + 4 门禁 PASS
- [x] 一个 commit

## Task 6：更正 slice 收尾陈述

**Blast Radius**：`openspec/changes/engine-portability/change-manifest.md`、
`openspec/changes/engine-portability/slice-proposal.md`、`openspec/project/TODO.md`

**DoD**：
- [x] change-manifest 的「前提修正」段已写明「三个里两个可达」（立项时）
- [x] `TODO.md` 的「实机未覆盖的界面」已标为「已立项 port-ui-screens-verification」
      并记录实测结论
- [x] 一个 commit

## 依赖

```
Task 1 (归档三张) ──▶ Task 2 (补存档) ──▶ Task 6 (更正陈述)
        │
        └──▶ Task 3 (status_page) ──▶ Task 4 (战斗同源) ──▶ Task 5 (门禁)
```

- Task 1/2 与 3/4/5 可并行（前者只改 docs，后者改代码）
- Task 5 的负向对照**必须**在 Task 3 之后
