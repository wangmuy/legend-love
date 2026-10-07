## 1. 场景状态
Traceability: [REQ-001]

- [x] 1.1 创建 `sceneState` 表 + 辅助函数（mmap_smap_handlers.lua）
- [x] 1.2 在 `look` 输出中集成状态过滤
- [x] 1.3 暴露状态更新接口供 talk/take 调用

## 2. 测试
Traceability: [REQ-002]

- [x] 2.1 E2E 测试：NPC 离场后 look 不可见
- [x] 2.2 E2E 测试：物品拾取后 look 不可见
