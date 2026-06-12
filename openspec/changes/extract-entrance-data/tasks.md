## 1. 格式研究

- [x] 1.1 确认 ranger.grp 中大地图入口数据格式（100 × 100 瓦片地图）
- [x] 1.2 确认场景入口编码方式（入口瓦片编码对应场景 ID）

## 2. 提取实现

- [x] 2.1 实现 `extractEntrances()` — 扫描大地图所有瓦片，提取入口坐标→场景 ID 映射
- [x] 2.2 写入 `engine-web/data-web/entrances.json`

## 3. 验证

- [x] 3.1 确认入口数量 84 个（每个场景一个入口）
- [x] 3.2 verify_web_data.lua 校验通过：entrances 中 sceneId 在 scenes 中都存在
