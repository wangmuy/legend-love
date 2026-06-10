# tasks — extract-complete-binary

## 1. 修复 Bug（已完成）

- [x] 1.1 修复 extract_scenes.lua 出口/跳转偏移计算（tjx/tjy 循环中偏移错位）
- [x] 1.2 验证修复后 scenes.json 出口坐标正确

## 2. 补全场景字段（已完成）

- [x] 2.1 添加 exitMusic（偏移 22）、enterMusic（偏移 24）
- [x] 2.2 添加 enterCondition（偏移 28，进入条件：0=开放 1=上锁 2=需轻功>=70）
- [x] 2.3 添加 mapX2（偏移 34）、mapY2（偏移 36，第二外景入口）

## 3. 补全角色字段（已完成）

- [x] 3.1 添加 headId（偏移 2，头像代号）
- [x] 3.2 添加 hpGrowth（偏移 4，生命增长）
- [x] 3.3 添加 exp（偏移 52，当前经验）
- [x] 3.4 添加 practicePoints（偏移 64，物品修炼点数）
- [x] 3.5 添加 attackAnimFrames（偏移 70-78，出招动画帧数1-5）
- [x] 3.6 添加 attackAnimDelays（偏移 80-88，出招动画延迟1-5）
- [x] 3.7 添加 soundDelays（偏移 90-98，武功音效延迟1-5）
- [x] 3.8 添加 antiPoisonResist（偏移 118，抗毒能力）
- [x] 3.9 添加 martialKnowledge（偏移 130，武学常识）
- [x] 3.10 添加 poisonAttack（偏移 134，攻击带毒）
- [x] 3.11 添加 fame（偏移 138，声望）

## 4. 补全物品字段（已完成）

- [x] 4.1 添加 name2（偏移 42，备用名称）
- [x] 4.2 添加 learnedSkill（偏移 142，练出武功）
- [x] 4.3 添加 throwAnim（偏移 144，暗器动画编号）
- [x] 4.4 添加 user（偏移 146，使用人限制）
- [x] 4.5 添加 displayDesc（偏移 150，显示物品说明 ID）
- [x] 4.6 添加 unknown5-7（偏移 154-158）
- [x] 4.7 添加属性加成（偏移 160-204）：加生命/内力/攻击/轻功/防御/医疗/用毒/解毒/抗毒/拳掌/御剑/耍刀/特殊/暗器/武学常识/品德/攻击次数/攻击带毒
- [x] 4.8 添加修炼限制（偏移 206-238）：仅修炼人物/需内力性质/需内力/需攻击/需轻功/需用毒/需医疗/需解毒/需拳掌/需御剑/需耍刀/需特殊/需暗器/需资质/需经验/练出物品需经验/需材料
- [x] 4.9 添加合成配方（偏移 240-258）：练出物品1-5、需要物品数量1-5

## 5. 补全技能字段（已完成）

- [x] 5.1 添加 unknown1-5（偏移 22-30）
- [x] 5.2 添加 soundEffect（偏移 32，出招音效）
- [x] 5.3 添加 animEffect（偏移 36，武功动画&音效）
- [x] 5.4 添加 damageType（偏移 38，伤害类型）
- [x] 5.5 添加 poison（偏移 44，敌人中毒点数）
- [x] 5.6 添加 moveRange1-10（偏移 66-84，每级移动范围）
- [x] 5.7 添加 damageRange1-10（偏移 86-104，每级杀伤范围）
- [x] 5.8 添加 addMp1-10（偏移 106-124，每级加内力）
- [x] 5.9 添加 killMp1-10（偏移 126-144，每级杀内力）

## 6. D* 事件数据提取（已完成）

- [x] 6.1 实现 alldef.grp 读取
- [x] 6.2 写入 events.json（20000 条）
- [x] 6.3 验证通过

## 7. 基础数据提取（已完成）

- [x] 7.1 提取主角位置、队伍、物品栏等
- [x] 7.2 写入 config.json

## 8. 商店数据提取（已完成）

- [x] 8.1 读取 ranger.grp 偏移 136262，5 条 × 30 字节
- [x] 8.2 写入 shops.json（过滤空槽位 1000 标记）

## 9. 验证与测试（已完成）

- [x] 9.1 更新 verify_web_data.lua：新文件校验 + D* 事件检查 + 商店引用检查
- [x] 9.2 重新运行提取管线：`lua tools/extract_web_data.lua`
- [x] 9.3 更新 index.js 加载 events.json（JS JSON.parse 优化速度）
- [x] 9.4 更新 data_loader.lua 注册新文件，_fileCount 改为 10
- [x] 9.5 更新 data-integrity.spec.js：新增 5.11 D* 事件引用 + config/shops 测试
- [x] 9.6 Playwright 全量测试 50/50 通过
- [x] 9.7 verify_web_data.lua 全部通过