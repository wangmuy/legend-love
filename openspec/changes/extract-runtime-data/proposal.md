## 为什么

Web MUD 需要人物、物品、武功的静态数据用于显示状态、管理背包、战斗计算。
这些数据在 `jyconst.lua` 中以 Lua 表的形式定义，但 Web 版需要在加载时
快速访问，JSON 格式比运行 jyconst.lua 更高效。

## 变更内容

- 在 `tools/extract_web_data.lua` 中实现运行时数据导出模块
- 加载 `script/jyconst.lua` 获取 CC.Person_S、CC.Thing_S 等数据定义
- 遍历所有人物/物品/武功编号，读取核心属性
- 输出 `engine-web/data-web/chars.json`、`items.json`、`skills.json`

## 能力

### 新增能力
- `extract-chars`: 人物静态数据导出
- `extract-items`: 物品数据导出
- `extract-skills`: 武功数据导出

### 修改的能力
- 无

## 影响

- 新增 `engine-web/data-web/chars.json`（约 200 KB）
- 新增 `engine-web/data-web/items.json`（约 100 KB）
- 新增 `engine-web/data-web/skills.json`（约 100 KB）