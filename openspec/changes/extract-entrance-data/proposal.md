## 为什么

Web MUD 的 `go <场景名>` 命令需要知道场景在大地图上的入口坐标。
大地图数据存储在 `mmap.grp/.idx` 二进制文件中。

## 变更内容

- 在 `tools/extract_web_data.lua` 中实现地图入口提取模块
- 扫描 mmap.grp 找到所有标记为场景入口的瓦片
- 建立 地图坐标 (mapX, mapY) → 场景 ID 的映射
- 输出 `engine-web/data-web/entrances.json`

## 能力

### 新增能力
- `extract-entrances`: 大地图场景入口坐标映射

### 修改的能力
- 无

## 影响

- 新增 `engine-web/data-web/entrances.json`（约 50-100 KB）