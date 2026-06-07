## 1. 格式研究

- [ ] 1.1 读取 oldtalk.idx 头 20 字节，验证 4 字节 little-endian 偏移量格式
- [ ] 1.2 读取 oldtalk.grp 头几条对话，确认文本编码和分隔符
- [ ] 1.3 记录格式结论到 design.md

## 2. 提取实现

- [ ] 2.1 在 `tools/extract_web_data.lua` 中实现 `readIdxOffsets()` 函数
- [ ] 2.2 实现 `readGrpTexts(grpData, offsets)` 函数
- [ ] 2.3 实现 `writeDialoguesJson(dialogues)` 函数
- [ ] 2.4 主流程集成：读取 → 提取 → 写入 JSON

## 3. 验证

- [ ] 3.1 确认对话总数 > 5000
- [ ] 3.2 抽样检查前 10 条和后 10 条对话的完整性
- [ ] 3.3 确认 JSON 格式可通过 Lua require 加载