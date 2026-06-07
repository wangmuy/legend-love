## 为什么

Web MUD 需要知道在哪里会遇到哪些敌人。战斗地图和遇敌配置
存储在二进制文件中，文字版需要用这些数据触发战斗。

## 变更内容

- 在 `tools/extract_web_data.lua` 中实现遇敌数据提取模块
- 读取战斗地图索引文件获取战斗地图列表
- 读取遇敌配置数据（地图区域/场景 → 敌人列表 + 概率）
- 输出 `engine-web/data-web/wmap.json`

## 能力

### 新增能力
- `extract-encounters`: 遇敌配置和战斗地图数据

### 修改的能力
- 无

## 影响

- 新增 `engine-web/data-web/wmap.json`（约 500 KB）