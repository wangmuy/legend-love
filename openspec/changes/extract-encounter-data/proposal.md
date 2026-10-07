## 为什么

Web MUD 需要知道在哪里会遇到哪些敌人。战斗地图和遇敌配置
存储在 `data/war.sta`、`data/fight*.grp`、`data/warfld.*` 等二进制文件中，
文字版需要用这些数据触发战斗。

## 变更内容

- 在 `tools/extract_web_data.lua` 中调用 `tools/extract_encounters.lua` 提取模块
- 读取 `data/war.sta` 获取遇敌配置（146 条固定格式）
- 读取 `data/fight*.grp` 和 `data/warfld.*` 获取战斗地图列表
- 输出 `engine-web/data-web/wmap.json`（中文键名）

## 能力

### 新增能力
- `extract-encounters`: 遇敌配置 + 战斗地图数据（11 地图 + 146 遇敌）

### 修改的能力
- 无

## 影响

- 新增 `engine-web/data-web/wmap.json`（约 500 KB）