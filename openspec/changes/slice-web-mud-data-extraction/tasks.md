## 1. 对话数据提取

- [x] 1.1 研究 oldtalk.grp/.idx 的二进制格式
- [x] 1.2 实现 oldtalk.idx 读取：每条 4 字节偏移量
- [x] 1.3 按偏移量读取每条对话文本，输出 2977 条对话
- [x] 1.4 写入 `engine-web/data-web/dialogues.json`

## 2. 场景数据提取

- [x] 2.1 研究 ranger.grp 中 Scene_S 结构格式（62 字节/场景）
- [x] 2.2 读取 Scene_S 获取场景基础信息（名称、坐标、出口、跳转）
- [x] 2.3 写入 `engine-web/data-web/scenes.json`
- [x] 2.4 验证：84 个场景，出口目标场景 ID 存在性检查通过

## 3. 人物/物品/武功数据导出

- [x] 3.1 从 ranger.grp 二进制读取人物段（187 人 × 140 字节，67 字段）
- [x] 3.2 从 ranger.grp 读取物品段（199 物 × 260 字节，54 字段）
- [x] 3.3 从 ranger.grp 读取武功段（100 武功 × 150 字节，38 字段）
- [x] 3.4 分别写入 `chars.json`、`items.json`、`skills.json`

## 4. 地图入口数据提取

- [x] 4.1 确认入口坐标来自 Scene_S 字段（外景入口X1/Y1/X2/Y2），非 mmap.grp
- [x] 4.2 从 ranger.grp Scene_S 段提取入口坐标
- [x] 4.3 写入 `engine-web/data-web/entrances.json`

## 5. 遇敌/战斗数据提取

- [x] 5.1 研究 war.sta + fight*.grp + warfld.* 的二进制格式
- [x] 5.2 提取战斗地图列表（11 张）
- [x] 5.3 提取遇敌配置（146 条）
- [x] 5.4 写入 `engine-web/data-web/wmap.json`

## 6. 数据完整性审计与补充提取

- [x] 6.1 审计二进制结构体，补全遗漏字段（场景4 + 角色11 + 物品49 + 技能33 = 97 字段）
- [x] 6.2 修复 extract_scenes.lua 出口/跳转偏移计算 Bug
- [x] 6.3 提取 D* 事件数据（alldef.grp → events.json, 16800 条）
- [x] 6.4 提取基础数据（ranger.grp 头部 → config.json）
- [x] 6.5 提取商店数据（ranger.grp 商店段 → shops.json）
- [x] 6.6 更新 verify_web_data.lua：校验所有 10 个文件
- [x] 6.7 更新 data-integrity 测试：跨文件引用验证
- [x] 6.8 重新运行提取管线 + 验证 + 测试，全部通过
- [x] 6.9 数据源调研确认：ranger.grp 是随游戏发布的源文件（非用户存档），Scene_S 是场景元数据唯一源

### 6.10 从 thing.grp + allsin.grp 提取场景 NPC/物品放置数据

调研发现：NPC 和物品在场景中的位置数据不在 ranger.grp 中，也不在 s1/s2/s3.grp 的 tile 数据中（tile 值仅为1-15的地形/墙体索引）。
数据在 `thing.grp`（200 场景 × 1728 字节/场景）和 `allsin.grp`（100场景 × 49152字节/场景×6层）中。
需要在 extract_scenes.lua 中新增解析器来提取这些数据。

- [ ] 6.10.1 逆向 thing.grp 的每场景 1728 字节格式
  Blast Radius: `["game/tools/extract_scenes.lua"]`
  DoD:
    - [ ] 确认每场景的 thing 记录数量（1728 字节 / 记录大小）
    - [ ] 确认记录是否包含 {itemId, count, x, y} 或 NPC 引用
    - [ ] 编写测试脚验证已知场景的数据正确性

- [ ] 6.10.2 实现 NPC/物品提取并输出到 scenes.json
  Blast Radius: `["game/tools/extract_scenes.lua"]`
  DoD:
    - [ ] scenes.json 中 NPC 数组不再为空（有数据的场景不复为空）
    - [ ] scenes.json 中物品数组不再为空
    - [ ] 重新运行 `lua tools/extract_web_data.lua` 成功

- [ ] 6.10.3 验证与回归
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] data-integrity 测试全部通过
    - [ ] 主角的家场景 NPC 包含软体娃娃