## 1. NPC 对话实现（SmapHandlers.talk 内部调用，非直接命令）

- [x] 1.1 实现 NPC 查找和事件 ID 获取
- [x] 1.2 调用 EventExecutor 执行 oldevent
- [x] 1.3 实现 instruct_1（对话文本输出 + 说话人名称）
- [x] 1.4 实现 instruct_0（分隔线输出）
- [x] 1.5 实现 WaitKey（等待用户输入）
- [x] 1.6 实现 ShowMenu 的事件菜单版本

注意：`talk` 已从 SMAP 命令表移除，NPC 对话通过 look → choose N → 对话 菜单流触发。`SmapHandlers.talk` 保留作为内部函数供菜单流调用。

## 2. 对话说话人名称

- [x] 2.1 instruct_1 输出【说话人】对话文本
- [x] 2.2 使用 HEAD_NAME_MAP 映射常见头像 ID→名称
- [x] 2.3 头像代号字段保留在 chars.json 中（不再过滤）
