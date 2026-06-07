## 1. 格式研究

- [ ] 1.1 研究 allsin.grp/.idx 的记录格式
- [ ] 1.2 研究 s* 文件的场景数据结构
- [ ] 1.3 研究 d* 文件的事件触发数据格式
- [ ] 1.4 记录格式结论到 design.md

## 2. 提取实现

- [ ] 2.1 实现 `extractSceneList()` — 读取 allsin 获取场景基础信息
- [ ] 2.2 实现 `extractSceneExits()` — 读取 s* 文件解析出口
- [ ] 2.3 实现 `extractSceneNPCItems()` — 读取场景数据解析 NPC/物品坐标
- [ ] 2.4 实现 `extractSceneEvents()` — 读取 d* 文件解析事件触发点
- [ ] 2.5 实现场景类型推断逻辑
- [ ] 2.6 写入 `data-web/scenes.json`

## 3. 验证

- [ ] 3.1 确认场景数量与原版一致（约 70+ 个）
- [ ] 3.2 抽样 5 个场景：验证出口、NPC、物品坐标正确
- [ ] 3.3 确认所有场景都有 idStr 和 type 字段