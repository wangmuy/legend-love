## 1. look 增强为菜单模式
Traceability: [REQ-001]

- [x] 1.1 `SmapHandlers.look` 输出编号列表
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] NPC 列表显示为 "N. <NPC名>"
    - [x] 物品列表显示为 "N. <物品名>"
    - [x] 出口列表显示为 "N. → <目标场景名>"
    - [x] 底部提示 "输入 choose <编号> 选择交互对象"
    - [x] 过滤已离场 NPC 和已拾取物品

- [x] 1.2 `choose N` 在 SMAP 的级联菜单
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua", "game/engine-web/web_command_engine.lua"]`
  DoD:
    - [x] 选择 NPC → 弹出子菜单（1.对话 2.查看）
    - [x] 选择物品 → 弹出子菜单（1.拾取 2.查看）
    - [x] 选择出口 → 直接传送（同 go <编号>）
    - [x] 子菜单中 ESC(choose 0) 回到场景总览

## 2. NPC 对话
Traceability: [REQ-002]

- [x] 2.1 子菜单"对话"执行 oldevent
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua", "game/framework/event_executor.lua"]`
  DoD:
    - [x] 调用 `EventExecutor.startEvent(eventId, 0, callback)`
    - [x] 事件结束后回到场景总览

- [x] 2.2 对话文本输出
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取文本
    - [x] `instruct_0()` 输出分隔线

- [x] 2.3 WaitKey/ShowMenu 适配
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `WaitKey()` 显示 "按回车继续..." → 等待输入
    - [x] 事件中 `ShowMenu` 通过 MenuAsync 显示

## 3. 场景状态管理
Traceability: [REQ-003]

- [x] 3.1 `_G.sceneState` 惰性初始化 + 全套 API
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `setNpcPresent` / `isNpcPresent`
    - [x] `setItemCount` / `getItemCount` / `itemAvailable`
    - [x] `look` 和 `choose` 列表过滤不可见对象

## 4. 测试
Traceability: [REQ-001, REQ-002, REQ-003]

### 4.1 菜单交互单元测试

- [x] 4.1.1 `SmapHandlers.look` 输出编号列表（程序化 SMAP 状态）
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] 有出口的场景：输出 `"N. → 出口名"` + `"输入 choose <编号> 选择交互对象"`
    - [x] 无 NPC/物品/出口的场景：输出 `"这里什么都没有。"`

- [x] 4.1.2 `SmapHandlers.chooseInteraction` 路由到正确子处理器
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] choose N → NPC → 子菜单（对话/查看/给予物品）
    - [x] choose N → 物品 → 子菜单（拾取/查看）
    - [x] choose N → 出口 → 直接传送（同 `go <编号>`）

### 4.2 NPC 对话单元测试

- [x] 4.2.1 对话通过 EventExecutor 执行 oldevent
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] NPC 有事件编号 → `EventExecutor.startEvent` 被调用
    - [x] NPC 无事件编号 → 显示"似乎不想说话"

- [x] 4.2.2 instruct_1 对话文本输出
  Blast Radius: `["game/engine-web/tests/*.spec.js"]`
  DoD:
    - [x] `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取并输出

- [x] 4.2.3 instruct_0 输出分隔线
  Blast Radius: `["game/engine-web/tests/*.spec.js"]`
  DoD:
    - [x] `instruct_0()` 调用 `WebUI.separator()`

### 4.3 物品交互单元测试

- [x] 4.3.1 `smapTakeItem` 拾取物品
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] 物品可用 → 加入背包 `JY.Base["物品N"]` → sceneState 标记已拾取 → 显示"你获得了"
    - [x] 物品已被拾取 → 显示"已经被拿走了"

- [x] 4.3.2 `smapGiveToNpc` 给予物品
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] 背包有物品 → 显示物品菜单 → 选择后从背包移除
    - [x] 背包无物品 → 显示"身上没有可以给予的物品"

### 4.4 场景状态单元测试

- [x] 4.4.1 `sceneState` API
  Blast Radius: `["game/engine-web/tests/*.spec.js"]`
  DoD:
    - [x] `setNpcPresent` / `isNpcPresent` — 设置后 `isNpcPresent` 返回正确值
    - [x] `setItemCount` / `getItemCount` / `itemAvailable` — 设置后状态正确
    - [x] 未设置时默认可用（`isNpcPresent` 返回 true）

- [x] 4.4.2 状态过滤在 `look` 中生效
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] NPC 离场后 `look` 不再显示该 NPC
    - [x] 物品拾取后 `look` 不再显示该物品

### 4.5 Slice 4 完整流程集成测试

- [x] 4.5.1 创建 `tests/s4-integration.spec.js`：场景交互完整流程
  Blast Radius: `["game/engine-web/tests/s4-integration.spec.js"]`
  DoD:
    - [x] 进入场景 → look 显示编号列表
    - [x] choose N → exit → leave 回到大地图
    - [x] 无 gameLoop error 贯穿全流程

- [x] 4.5.2 Web MUD 兼容性：SMAP 所有命令 help 显示
  Blast Radius: `["game/engine-web/tests/s4-integration.spec.js"]`
  DoD:
    - [x] SMAP help 显示 look/exits/go/leave/choose

### 4.6 回归测试

- [x] 4.6 所有 slice3 测试通过
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [x] `npx playwright test` 全部通过
