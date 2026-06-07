## 1. 格式研究

- [ ] 1.1 研究 mmap.grp/.idx 的地图数据格式
- [ ] 1.2 确认场景入口在地图中的标记方式

## 2. 提取实现

- [ ] 2.1 实现 `scanMapEntrances()` — 扫描大地图所有瓦片
- [ ] 2.2 实现 `extractEntranceJson()` — 汇总入口映射
- [ ] 2.3 写入 `engine-web/data-web/entrances.json`

## 3. 验证

- [ ] 3.1 确认入口数量合理（100-500 之间）
- [ ] 3.2 抽样 5 个入口：确认坐标与场景 ID 的对应关系正确