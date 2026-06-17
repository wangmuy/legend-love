## 1. 集成 — 在 SMAP 命令注册表中添加 talk/take/give/look
Traceability: [REQ-001, REQ-002, REQ-004]

- [ ] 1.1 更新 SMAP 命令表注册
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] SMAP 命令包含 talk/take/give/look(增强)/exits/go/leave/help/choose
    - [ ] help 在 SMAP 状态显示所有命令

- [ ] 1.2 运行所有 slice3 测试确认无回归
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] `npx playwright test` 全部通过

## 2. 验证 — 完整流程测试
Traceability: [REQ-001, REQ-002, REQ-003, REQ-004, REQ-005]

- [ ] 2.1 E2E 测试：场景全流程
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 进入场景 → talk → 对话 → WaitKey → 继续 → 回到场景

- [ ] 2.2 E2E 测试：场景状态持久化
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] NPC 离场后重新 look 不再显示
    - [ ] 物品拾取后重新 look 不再显示
