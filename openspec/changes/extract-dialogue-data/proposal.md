## 为什么

Web MUD 文字版需要对话文本。原版对话存储在二进制文件 `script/oldtalk.grp/.idx` 中，
Web 版（Fengari）无法直接读取二进制文件，需要提取为 JSON。

## 变更内容

- 在 `tools/extract_web_data.lua` 中调用 `tools/extract_dialogues.lua` 提取模块
- 读取 `game/script/oldtalk.idx`（4 字节偏移量数组）
- 按偏移量从 `game/script/oldtalk.grp` 读取每条对话文本
- 输出 `game/engine-web/data-web/dialogues.json`，中文键名（`{说话人, 内容}`）

## 能力

### 新增能力
- `extract-dialogues`: 从 oldtalk 二进制文件提取 2977 条对话为 JSON

### 修改的能力
- 无

## 影响

- 新增 `game/engine-web/data-web/dialogues.json`（约 1-2 MB）
- 无现有代码修改