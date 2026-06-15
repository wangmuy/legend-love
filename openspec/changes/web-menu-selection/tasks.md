## 1. 菜单辅助函数
Traceability: [REQ-003]

- [x] 1.1 在 CommandEngine 中新增 `showMenu(items, title, callback)` 函数，使用 `MenuAsync.ShowMenu`（回调版，非阻塞）
  Blast Radius: `["game/engine-web/web_command_engine.lua"]`
  DoD:
    - [x] `showMenu` 构建菜单项，通过回调返回选中索引

- [x] 1.2 使用回调版 `MenuAsync.ShowMenu` 避免协程依赖（无需 coroutine 包装）
  Blast Radius: `["game/engine-web/web_command_engine.lua", "game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `go` 无参时菜单正常弹出，choose N 通过回调处理

## 2. go/list 命令菜单模式
Traceability: [REQ-001, REQ-002, REQ-004]

- [x] 2.1 提取 `goToScene` 和 `buildSceneList` 辅助函数
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `go <场景名>` 有参时行为不变

- [x] 2.2 `go` 无参时弹出场景菜单，选中后调用 `goToScene`；ESC 不操作
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `go` 弹出场景菜单，choose 1 传送到对应场景
    - [x] ESC（choose 0）菜单关闭，无副作用

- [x] 2.3 `list` 改为菜单模式（复用 `buildSceneList` + `showMenu`）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `list` 弹出场景菜单，choose N 传送到对应场景

- [x] 2.4 菜单命令仅在 GAME_MMAP / GAME_SMAP 下注册，GAME_START 不受影响
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 开始菜单输入 go → "未知命令"

- [x] 2.5 菜单项显示序号（"1. 名称" 格式）
  Blast Radius: `["game/engine-web/web_command_engine.lua"]`
  DoD:
    - [x] list 菜单项显示为 "1. 河洛客棧"、 "2. 天寧寺" 等

## 4. 验证
Traceability: [REQ-001, REQ-002, REQ-003, REQ-004]

- [x] 4.1 更新已有测试适配菜单行为（list 不再显示"共 N 个场景"）
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] `npx playwright test tests/mmap-smap.spec.js --workers=1` passes (6/6)

- [x] 4.2 `go` 有参行为不变
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [x] 已有 go 精确匹配/模糊匹配测试通过

- [x] 4.3 完整流程测试：start → choose 1 → choose 1 → go（菜单）→ choose N → 进入场景
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [x] `npx playwright test tests/s3-menu-test.spec.js --workers=1` passes

## 5. 集成测试

- [x] 5.1 新增 s3-integration.spec.js：完整流程集成测试（开始→属性→list→choose→SMAP→leave）
- [x] 5.2 新增测试：未知命令不报错、choose 0 关闭菜单、多次循环不累积错误
