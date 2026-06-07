## 1. 对话数据提取

- [ ] 1.1 研究 oldtalk.grp/.idx 的二进制格式（参考 lib_Byte.lua 中的 `LoadToTable16` 等函数）
- [ ] 1.2 实现 oldtalk.idx 读取：每条 4 字节偏移量，计算总条目数
- [ ] 1.3 实现 oldtalk.grp 读取：按偏移量读取每条对话文本（GBK→UTF-8 转换）
- [ ] 1.4 将对话数据写入 `engine-web/data-web/dialogues.json`
- [ ] 1.5 验证：对话总数 > 5000，抽样检查文本完整性

## 2. 场景数据提取

- [ ] 2.1 研究 allsin.grp/.idx 的二进制格式
- [ ] 2.2 读取 allsin 获取场景基础信息（名称、尺寸）
- [ ] 2.3 读取 s* 文件获取场景出口数据
- [ ] 2.4 读取场景数据获取 NPC 坐标和物品坐标
- [ ] 2.5 读取 d* 文件获取事件触发点
- [ ] 2.6 根据场景名称推断场景类型（客栈/山洞/商店/...）
- [ ] 2.7 生成 idStr：`<场景名>_<ID>` 格式
- [ ] 2.8 将场景数据写入 `engine-web/data-web/scenes.json`
- [ ] 2.9 验证：场景数量与原版一致，出口/NPC/物品坐标随机抽样验证

## 3. 人物/物品/武功数据导出

- [ ] 3.1 读取 jyconst.lua 中的人物数据结构定义
- [ ] 3.2 遍历所有人物编号，提取核心属性（id、name、level、hp、mp、attack、defence、speed、skills）
- [ ] 3.3 遍历所有物品编号，提取核心属性（id、name、type、effect、price）
- [ ] 3.4 遍历所有武功编号，提取核心属性（id、name、type、power、mpCost、range）
- [ ] 3.5 分别写入 `engine-web/data-web/chars.json`、`items.json`、`skills.json`
- [ ] 3.6 验证：数据数量正确，关键数据抽样检查

## 4. 地图入口数据提取

- [ ] 4.1 研究 mmap.grp/.idx 的二进制格式
- [ ] 4.2 读取大地图数据，扫描场景入口坐标
- [ ] 4.3 建立 mapX/mapY → sceneId 的映射
- [ ] 4.4 写入 `engine-web/data-web/entrances.json`
- [ ] 4.5 验证：入口数量合理，随机抽取几个入口在原版游戏中验证

## 5. 遇敌/战斗数据提取

- [ ] 5.1 研究战斗地图索引和遇敌配置的存储格式
- [ ] 5.2 提取战斗地图列表
- [ ] 5.3 提取遇敌配置（场景/区域 → 敌人列表 + 概率）
- [ ] 5.4 写入 `engine-web/data-web/wmap.json`
- [ ] 5.5 验证：战斗地图数量正确

## 6. 整合验证

- [ ] 6.1 编写一个验证脚本 `tools/verify_web_data.lua`：
  - 加载所有 JSON
  - 检查 JSON 格式完整性（version、total 字段存在）
  - 检查数据间引用关系（如 scenes 中引用的 NPC ID 在 chars.json 中存在）
  - 报告统计信息（场景数、对话数、物品数等）
- [ ] 6.2 运行验证脚本，确保所有检查通过
- [ ] 6.3 确认所有 JSON 总大小 ≤ 15MB

## 7. 清理和文档

- [ ] 7.1 添加 `engine-web/data-web/` 到 `.gitignore`（JSON 是构建产物，每次提取覆盖）
- [ ] 7.2 在 `tools/extract_web_data.lua` 头部添加使用说明注释
- [ ] 7.3 在 epic 的 TODO.md 中更新 Slice 1 进度