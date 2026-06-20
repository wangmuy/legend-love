## 1. talk 命令实现
Traceability: [REQ-001]

- [x] 1.1 注册 `talk <人名>` 命令到 SMAP 状态（web_game_bridge.lua）
- [x] 1.2 实现 NPC 查找和事件 ID 获取（mmap_smap_handlers.lua SmapHandlers.talk）
- [x] 1.3 调用 EventExecutor 执行 oldevent
- [x] 1.4 实现 instruct_1（对话文本输出）
- [x] 1.5 实现 instruct_0（分隔线输出）
- [x] 1.6 实现 WaitKey（等待用户输入）
- [x] 1.7 实现 ShowMenu 的事件菜单版本

## 2. 测试

- [x] 2.1 E2E 测试：help 显示 talk 命令
- [x] 2.2 E2E 测试：talk NPC 返回提示（当前无场景 NPC 数据时输出"此场景没有可以对话的 NPC"）
- [ ] 2.3 E2E 测试：NPC 数据完备后的完整对话流程（需 thing.grp 逆向完成）
