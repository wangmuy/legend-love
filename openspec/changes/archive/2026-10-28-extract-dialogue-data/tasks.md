## 1. 对话提取

- [x] 1.1 从 ranger.grp 偏移量信息读取对话数据（所有对话存储在游戏主数据文件中）
- [x] 1.2 提取 2977 条对话，包含 speaker、text 字段
- [x] 1.3 写入 `engine-web/data-web/dialogues.json`

## 2. 验证

- [x] 2.1 确认对话总数 2977（与 CC 常量一致）
- [x] 2.2 抽样检查前 10 条和后 10 条对话的完整性
- [x] 2.3 verify_web_data.lua 校验通过
- [x] 2.4 E2E data-integrity.spec.js 检查 dataCache.dialogues 非空
