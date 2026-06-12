## 1. 数据研究

- [x] 1.1 确认 CC.Char_S（偏移结构）、CC.Thing_S（偏移结构）、CC.Skill_S（偏移结构）
- [x] 1.2 确认 ranger.grp 中人物/物品/武功的数据存储偏移

## 2. 提取实现

- [x] 2.1 读取 ranger.grp 人物数据段（187 人 × 140 字节，共 67 个字段含中文键名）
- [x] 2.2 读取 ranger.grp 物品数据段（199 物 × 260 字节，共 54 个字段含中文键名）
- [x] 2.3 读取 ranger.grp 武功数据段（100 武功 × 150 字节，共 38 个字段含中文键名）
- [x] 2.4 分别写入 `engine-web/data-web/chars.json`、`items.json`、`skills.json`

## 3. 验证

- [x] 3.1 确认人物 187 条
- [x] 3.2 确认物品 199 条
- [x] 3.3 确认武功 100 条
- [x] 3.4 verify_web_data.lua 跨文件引用校验通过（场景中 NPC ID 在 chars 中存在）
