## 为什么

Web MUD 文字版需要对话文本。原版对话存储在二进制文件 `oldtalk.grp/.idx` 中，
Web 版（Fengari）无法直接读取二进制文件，需要提取为 JSON。

## 变更内容

- 在 `tools/extract_web_data.lua` 中实现对话数据提取模块
- 读取 `game/data/oldtalk.idx`（4 字节偏移量数组）
- 按偏移量从 `game/data/oldtalk.grp` 读取每条对话文本
- 输出 `game/data-web/dialogues.json`

## 能力

### 新增能力
- `extract-dialogues`: 从 oldtalk 二进制文件提取 5000+ 条对话为 JSON

### 修改的能力
- 无

## 影响

- 新增 `game/data-web/dialogues.json`（约 1-2 MB）
- 无现有代码修改