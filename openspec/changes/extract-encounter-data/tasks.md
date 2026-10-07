## 1. 格式研究

- [x] 1.1 确认 ranger.grp 中战斗地图索引格式（偏移 146000）
- [x] 1.2 确认遇敌配置结构（146 条 × 17 字节）

## 2. 提取实现

- [x] 2.1 实现 `extractWarMaps()` — 读取战斗地图列表（count/walkable 等字段）
- [x] 2.2 实现 `extractEncounters()` — 读取 146 条遇敌配置（prob、levels、enemies 等）
- [x] 2.3 写入 `engine-web/data-web/wmap.json`（含 warMaps 和 encounters 两个子表）

## 3. 验证

- [x] 3.1 确认战斗地图 11 张
- [x] 3.2 确认遇敌配置 146 条
- [x] 3.3 verify_web_data.lua 校验通过
