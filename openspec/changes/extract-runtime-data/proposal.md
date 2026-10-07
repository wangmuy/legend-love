## 为什么

Web MUD 需要人物、物品、武功的静态数据用于显示状态、管理背包、战斗计算。
这些数据在 `data/ranger.grp` 中以游戏存档格式存储（由 Love2D 版从原始二进制初始化后写入），
Web 版需要在加载时快速访问，JSON 格式比读二进制更高效。

## 变更内容

- 在 `tools/extract_web_data.lua` 中调用 `tools/extract_runtime.lua` 提取模块
- 读取 `data/ranger.idx` 获取各数据段偏移
- 从 `data/ranger.grp` 直接读取人物/物品/武功的二进制数据
- 按 CC.Char_S/Thing_S/Skill_S 结构解析所有字段（中文键名）
- 输出 `engine-web/data-web/chars.json`、`items.json`、`skills.json`

## 能力

### 新增能力
- `extract-chars`: 人物运行时数据导出（187 人，50+ 字段）
- `extract-items`: 物品数据导出（199 物，42+ 字段）
- `extract-skills`: 武功数据导出（100 武功，22+ 字段）

### 修改的能力
- 无

## 影响

- 新增 `engine-web/data-web/chars.json`（约 200 KB）
- 新增 `engine-web/data-web/items.json`（约 100 KB）
- 新增 `engine-web/data-web/skills.json`（约 100 KB）