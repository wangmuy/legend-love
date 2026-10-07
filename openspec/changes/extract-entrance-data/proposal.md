## 为什么

Web MUD 的 `go <场景名>` 命令需要知道场景在大地图上的入口坐标。
入口坐标是 Scene_S 结构的一部分（`外景入口X1/Y1` / `外景入口X2/Y2`），存储在 `data/ranger.grp` 的场景段中，
不来自 `mmap.grp`（mmap 只存瓦片图形数据，不包含入口编码）。

## 变更内容

- 在 `tools/extract_web_data.lua` 中调用 `tools/extract_entrances.lua` 提取模块
- 从 `data/ranger.grp` 读取 Scene_S 段，提取外景入口坐标字段
- 建立 地图坐标 (mapX, mapY) → 场景 ID 的映射
- 输出 `engine-web/data-web/entrances.json`
- 建立 地图坐标 (mapX, mapY) → 场景 ID 的映射
- 输出 `engine-web/data-web/entrances.json`

## 能力

### 新增能力
- `extract-entrances`: 大地图场景入口坐标映射（84 个入口）

### 修改的能力
- 无

## 影响

- 新增 `engine-web/data-web/entrances.json`（约 50-100 KB）