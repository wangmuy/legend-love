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

- [ ] 4.1 E2E 测试：look 显示编号列表，choose N 选择 NPC
- [ ] 4.2 E2E 测试：NPC 对话流程
- [ ] 4.3 E2E 测试：物品拾取和给予
- [ ] 4.4 E2E 测试：场景状态（NPC 离场后不可见）
- [ ] 4.5 回归测试：所有 slice3 测试通过
