## 1. take 命令
Traceability: [REQ-001]

- [x] 1.1 注册 `take <物品名>` 命令到 SMAP 状态
- [x] 1.2 实现场景物品查找和拾取（mmap_smap_handlers.lua SmapHandlers.take）
- [x] 1.3 实现找不到物品时的提示

## 2. give 命令
Traceability: [REQ-002]

- [x] 2.1 注册 `give <物品名> <人名>` 命令到 SMAP 状态
- [x] 2.2 实现物品给予逻辑

## 3. look 加强
Traceability: [REQ-003]

- [ ] 3.1 实现有参 look（查看具体对象）

## 4. 测试

- [x] 4.1 E2E 测试：help 显示 take/give 命令
- [ ] 4.2 E2E 测试：take 命令拾取物品（需场景物品数据就绪）
- [ ] 4.3 E2E 测试：give 命令给予物品（需 NPC + 物品数据就绪）
