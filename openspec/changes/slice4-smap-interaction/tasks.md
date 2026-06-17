## 1. look 增强为菜单模式
Traceability: [REQ-001]

- [ ] 1.1 `SmapHandlers.look` 输出编号列表
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] NPC 列表显示为 "N. <NPC名>"
    - [ ] 物品列表显示为 "N. <物品名>"
    - [ ] 出口列表显示为 "N. <目标场景名>"
    - [ ] 底部提示 "输入 choose N 选择交互对象"
    - [ ] 过滤已离场 NPC 和已拾取物品

- [ ] 1.2 `choose N` 在 SMAP 的级联菜单
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua", "game/engine-web/web_command_engine.lua"]`
  DoD:
    - [ ] 选择 NPC → 弹出子菜单（1.对话 2.查看 3.给予物品）
    - [ ] 选择物品 → 弹出子菜单（1.拾取 2.查看）
    - [ ] 选择出口 → 直接传送（同 go <编号>）
    - [ ] 子菜单中 ESC(choose 0) 回到场景总览
    - [ ] 给予物品时列出背包物品供选择

## 2. NPC 对话
Traceability: [REQ-002]

- [ ] 2.1 子菜单"对话"执行 oldevent
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua", "game/framework/event_executor.lua"]`
  DoD:
    - [ ] 调用 `EventExecutor.startEvent(eventId, 0, callback)`
    - [ ] 事件结束后回到场景总览

- [ ] 2.2 对话文本输出
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取文本
    - [ ] `instruct_0()` 输出分隔线

- [ ] 2.3 WaitKey/ShowMenu 适配
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `WaitKey()` 显示 "按回车继续..." → 等待输入
    - [ ] 事件中 `ShowMenu` 通过 MenuAsync 显示

## 3. 场景状态管理
Traceability: [REQ-003]

- [ ] 3.1 `_G.sceneState` 惰性初始化 + 全套 API
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] `setNpcPresent` / `isNpcPresent`
    - [ ] `setItemCount` / `getItemCount` / `itemAvailable`
    - [ ] `look` 和 `choose` 列表过滤不可见对象

## 4. 测试
Traceability: [REQ-001, REQ-002, REQ-003]

### 4.1 菜单交互单元测试

- [ ] 4.1.1 `SmapHandlers.look` 输出编号列表（程序化 SMAP 状态）
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [ ] 有出口的场景：输出 `"N. → 出口名"` + `"输入 choose <编号> 选择交互对象"`
    - [ ] 无 NPC/物品/出口的场景：输出 `"这里什么都没有。"`

- [ ] 4.1.2 `SmapHandlers.chooseInteraction` 路由到正确子处理器
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [ ] choose N → NPC → 子菜单（对话/查看/给予物品）
    - [ ] choose N → 物品 → 子菜单（拾取/查看）
    - [ ] choose N → 出口 → 直接传送（同 `go <编号>`）

### 4.2 NPC 对话单元测试

- [ ] 4.2.1 对话通过 EventExecutor 执行 oldevent
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [ ] NPC 有事件编号 → `EventExecutor.startEvent` 被调用
    - [ ] NPC 无事件编号 → 显示"似乎不想说话"

- [ ] 4.2.2 instruct_1 对话文本输出
  Blast Radius: `["game/engine-web/tests/*.spec.js"]`
  DoD:
    - [ ] `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取并输出

- [ ] 4.2.3 instruct_0 输出分隔线
  Blast Radius: `["game/engine-web/tests/*.spec.js"]`
  DoD:
    - [ ] `instruct_0()` 调用 `WebUI.separator()`

### 4.3 物品交互单元测试

- [ ] 4.3.1 `smapTakeItem` 拾取物品
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [ ] 物品可用 → 加入背包 `JY.Base["物品N"]` → sceneState 标记已拾取 → 显示"你获得了"
    - [ ] 物品已被拾取 → 显示"已经被拿走了"

- [ ] 4.3.2 `smapGiveToNpc` 给予物品
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [ ] 背包有物品 → 显示物品菜单 → 选择后从背包移除
    - [ ] 背包无物品 → 显示"身上没有可以给予的物品"

### 4.4 场景状态单元测试

- [ ] 4.4.1 `sceneState` API
  Blast Radius: `["game/engine-web/tests/*.spec.js"]`
  DoD:
    - [ ] `setNpcPresent` / `isNpcPresent` — 设置后 `isNpcPresent` 返回正确值
    - [ ] `setItemCount` / `getItemCount` / `itemAvailable` — 设置后状态正确
    - [ ] 未设置时默认可用（`isNpcPresent` 返回 true）

- [ ] 4.4.2 状态过滤在 `look` 中生效
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [ ] NPC 离场后 `look` 不再显示该 NPC
    - [ ] 物品拾取后 `look` 不再显示该物品

### 4.5 Slice 4 完整流程集成测试

- [x] 4.5.1 创建 `tests/s4-integration.spec.js`：场景交互完整流程
  Blast Radius: `["game/engine-web/tests/s4-integration.spec.js"]`
  DoD:
    - [ ] 进入场景 → look 显示编号列表（NPC/物品/出口）
    - [ ] choose N → NPC 子菜单（对话/查看）
    - [ ] choose N → 物品 → 拾取 → 背包验证
    - [ ] 拾取后 look 不再显示该物品
    - [ ] choose N → 出口 → 传送/leave 回到大地图
    - [ ] 无 gameLoop error 贯穿全流程

- [ ] 4.5.2 Web MUD 兼容性：SMAP 所有命令 help 显示
  Blast Radius: `["game/engine-web/tests/s4-integration.spec.js"]`
  DoD:
    - [ ] SMAP help 显示 look/exits/go/leave/choose

### 4.6 回归测试

- [ ] 4.5 所有 slice3 测试通过
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] `npx playwright test` 88 tests passing
