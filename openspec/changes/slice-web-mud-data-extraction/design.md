## 上下文

Slice 1 是整个 Web MUD 的数据基础。后续所有 slice 都依赖本 slice 产出的 JSON 数据包。

## 目标 / 非目标

**目标：**
- 只运行一次 `lua game/tools/extract_web_data.lua` 就能产出所有 JSON
- 利用现有 `lib_Byte.lua` 解析二进制（不重复造轮子）
- 产出 JSON 可以被 Lua 直接 `require`（格式兼容）
- 数据类型完整，不遗漏 Slice 2~6 所需的任何字段

**非目标：**
- 不改造 Love2D 版现有数据加载逻辑
- 不优化二进制解析性能（一次性的提取工具）
- 不包含数据校验工具（只做基本完整性检查）

## 决策

### 1. 提取工具位置：game/tools/extract_web_data.lua

不放在 openspec/ 下，而是 game/ 下。因为提取工具需要 `require "lib_Byte"` 等 game/ 中的模块，放在 game/ 中可以直接复用 Love2D 版的模块加载路径。

### 2. 输出目录：game/engine-web/data-web/

和 `game/data/` 并列。`data/` 是原版二进制数据，`game/engine-web/data-web/` 是提取后的 JSON。

### 3. JSON 格式

每条记录的 key 使用英文，value 使用原始数据的类型（number/string/boolean）：

```json
{
  "version": "1.0",
  "extracted": "2026-06-07",
  "scenes": [
    {
      "id": 70,
      "idStr": "heke_inn",
      "name": "河洛客栈",
      "exits": [
        {"dir": "南", "toSceneId": 1, "toX": 15, "toY": 19}
      ],
      "npc": [
        {"id": 137, "x": 13, "y": 8}
      ],
      "items": [
        {"id": 47, "x": 4, "y": 6, "count": 1}
      ],
      "events": [
        {"x": 13, "y": 8, "eventId": 70, "flag": 0}
      ]
    }
  ]
}
```

每种数据类型的顶层字段统一包含 `version` 和 `extracted` 元信息，便于后续数据版本校验。

### 4. idStr 生成规则

每个场景需要一个人类可读的唯一字符串标识。生成规则：

```
规则：场景名拼音首字母 + 下划线 + 编号
  河洛客栈 → heke_inn_70
  少林寺 → shaolin_12
  悦来客栈 → yuelai_inn_5

或者直接使用编号（场景名映射表在加载时由 Lua 处理）：
  用 idStr = tostring(id) 作为默认值
  后续在 scenes.json 中手工添加特殊场景的 idStr

更简单的方案:
  idStr = string.format("%s_%d", sceneName, sceneId)
  例如: "河洛客栈_70", "少林寺_12"
  这样不需要拼音映射，也不需要额外查询表
```

采用方案三：`"<场景名>_<ID>"`，最直接，无歧义。

## 输出数据定义

### dialogues.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| dialogues | array | [{id, text}] 对话条目 |
| total | number | 对话总数 |

### scenes.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| scenes | array | 场景数组 |
| scenes[].id | number | 场景编号 |
| scenes[].idStr | string | 唯一标识: `<场景名>_<ID>` |
| scenes[].name | string | 场景名称 |
| scenes[].type | string | 场景类型: inn/shop/cave/temple/outdoor/... |
| scenes[].width/height | number | 场景尺寸 |
| scenes[].exits | array | 出口列表 [{dir, toSceneId, x, y}] |
| scenes[].npc | array | NPC 坐标 [{id, x, y}] |
| scenes[].items | array | 物品坐标 [{id, x, y, count}] |
| scenes[].events | array | 事件触发点 [{x, y, eventId, flag}] |

### chars.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| chars | array | 人物数组（仅含初始状态） |

### items.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| items | array | 物品数组 |

### skills.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| skills | array | 武功数组 |

### entrances.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| entrances | array | [{mapX, mapY, sceneId}] |

### wmap.json

| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 格式版本号 |
| encounters | array | 遇敌配置 |

## 风险

| 风险 | 缓解措施 |
|------|----------|
| 某些二进制格式解析不完整 | 使用 Love2D 版已验证的 lib_Byte.lua |
| JSON 体积过大 | 控制提取范围，只提取文字版需要的字段 |
| 中文编码问题 | jyconst.lua 已是 UTF-8，保持统一 |
| oldevent 事件脚本路径依赖 | oldevent 不改动，直接复制 |

---

## 附录：二进制数据结构完整参考

> 以下内容记录了所有从原版游戏二进制文件中提取的数据结构。每个结构体的字段定义来源于 `game/script/jyconst.lua`（CC.*_S 常量表）和对应的提取脚本。

### 通用类型说明

| 类型标识 | 含义 | 大小 | Lua 读取方式 |
|---|---|---|---|
| `s16` | 有符号 16 位整数，小端序 | 2 字节 | `b1 + b2*256`，若 > 32767 则减 65536 |
| `u16` | 无符号 16 位整数，小端序 | 2 字节 | `b1 + b2*256` |
| `u32` | 无符号 32 位整数，小端序 | 4 字节 | `b1 + b2*256 + b3*65536 + b4*16777216` |
| `str` | 以 `\0` 结尾的 GBK 字符串 | 可变 | 读取 N 字节，截断到第一个 `\0` |

jyconst.lua 字段三元组定义：`{offset, type, length}`，其中 type 0 = s16, 1 = u16, 2 = str。

### 常量表

| 常量 | 值 | 描述 |
|---|---|---|
| `CC.PersonSize` | 202 | 人物记录大小（字节） |
| `CC.ThingSize` | 260 | 物品记录大小（字节） |
| `CC.SceneSize` | 62 | 场景记录大小（字节） |
| `CC.WugongSize` | 146 | 武功记录大小（字节） |
| `CC.ShopSize` | 30 | 商店记录大小（字节） |
| `CC.WarDataSize` | 186 | 战斗/遭遇记录大小（字节） |
| `CC.DNum` | 200 | 每个场景的 D* 事件数 |
| `CC.TeamNum` | 6 | 队伍最大人数 |
| `CC.MWidth` / `CC.MHeight` | 480 | 主地图宽/高（格数） |
| `CC.SWidth` / `CC.SHeight` | 64 | 场景地图宽/高（格数） |

---

### 1. ranger.idx — 全局存档偏移索引（24 字节）

ranger.idx 包含 6 个 uint32 LE 偏移量，将 ranger.grp 划分为区域。

| 索引 | 偏移 | 大小 | 类型 | 名称 | 描述 |
|---|---|---|---|---|---|
| idx[0] | — | — | — | 隐式 0 | 基础数据起始（ranger.grp 文件头） |
| idx[1] | 0 | 4 | u32 | 人物起始 | 人物数据在 ranger.grp 中的偏移 (= 836) |
| idx[2] | 4 | 4 | u32 | 物品起始 | 物品数据偏移 |
| idx[3] | 8 | 4 | u32 | 场景起始 | 场景数据偏移 |
| idx[4] | 12 | 4 | u32 | 武功起始 | 武功数据偏移 |
| idx[5] | 16 | 4 | u32 | 商店起始 | 商店数据偏移 / 文件结束 |

区域大小 = `idx[N+1] - idx[N]`，记录数 = `区域大小 / recordSize`。

---

### 2. Base_S — 基础数据（ranger.grp 头部，836 字节）

#### 2a. 玩家/船只状态（偏移 0–23）

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 乘船 | shipFlag | 0 | 2 | u16 | 0=未乘船, 非0=已乘船 |
| 无用 | unused | 2 | 2 | s16 | 填充 |
| 人X | playerX | 4 | 2 | s16 | 玩家大地图 X 坐标 |
| 人Y | playerY | 6 | 2 | s16 | 玩家大地图 Y 坐标 |
| 人X1 | playerSubX | 8 | 2 | s16 | 玩家场景内 X 坐标 |
| 人Y1 | playerSubY | 10 | 2 | s16 | 玩家场景内 Y 坐标 |
| 人方向 | playerFace | 12 | 2 | s16 | 朝向: 0=上, 1=下, 2=左, 3=右 |
| 船X | shipX | 14 | 2 | s16 | 船大地图 X |
| 船Y | shipY | 16 | 2 | s16 | 船大地图 Y |
| 船X1 | shipSubX | 18 | 2 | s16 | 船场景内 X |
| 船Y1 | shipSubY | 20 | 2 | s16 | 船场景内 Y |
| 船方向 | shipFace | 22 | 2 | s16 | 船朝向 |

#### 2b. 队伍成员（偏移 24–35，6 人 × 2 字节）

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 队伍1..6 | team[1..6] | 24..34 | 各 2 | s16 | 队员人物 ID，0=空 |

#### 2c. 背包物品（偏移 36–155，30 格 × 4 字节，每格 id + count）

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 物品N | item[N].id | 36+(N-1)×4 | 2 | s16 | 物品 ID，0=空 |
| 物品数量N | item[N].count | 36+(N-1)×4+2 | 2 | s16 | 数量 |

---

### 3. Person_S — 人物结构（202 字节/条，320 条）

> 存储于 ranger.grp，起始偏移 idx[1]，共 (idx[2]-idx[1])/202 条。

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 代号 | id | 0 | 2 | s16 | 人物 ID |
| 头像代号 | headId | 2 | 2 | s16 | 头像图片 ID |
| 生命增长 | hpGrowth | 4 | 2 | s16 | 每级生命增长 |
| 无用 | unused | 6 | 2 | s16 | 填充 |
| 姓名 | name | 8 | 20 | str | 人物名称（GBK） |
| 外号 | title | 28 | 20 | str | 称号 |
| 性别 | sex | 48 | 2 | s16 | 0=男 1=女 |
| 等级 | level | 50 | 2 | s16 | 等级 (1–30) |
| 经验 | exp | 52 | 2 | u16 | 当前经验 |
| 生命 | hp | 54 | 2 | s16 | 当前生命 |
| 生命最大值 | maxHp | 56 | 2 | s16 | 最大生命 |
| 受伤程度 | wounded | 58 | 2 | s16 | 受伤 (0–100) |
| 中毒程度 | poisoned | 60 | 2 | s16 | 中毒 (0–100) |
| 体力 | stamina | 62 | 2 | s16 | 体力 (0–100) |
| 物品修炼点数 | practicePoints | 64 | 2 | s16 | 修炼点数 |
| 武器 | weapon | 66 | 2 | s16 | 装备武器 ID |
| 防具 | armour | 68 | 2 | s16 | 装备防具 ID |
| 出招动画帧数1 | attackAnimFrames[1] | 70 | 2 | s16 | 武功1 动画帧数 |
| 出招动画帧数2 | attackAnimFrames[2] | 72 | 2 | s16 | 武功2 |
| 出招动画帧数3 | attackAnimFrames[3] | 74 | 2 | s16 | 武功3 |
| 出招动画帧数4 | attackAnimFrames[4] | 76 | 2 | s16 | 武功4 |
| 出招动画帧数5 | attackAnimFrames[5] | 78 | 2 | s16 | 武功5 |
| 出招动画延迟1 | attackAnimDelays[1] | 80 | 2 | s16 | 武功1 动画延迟 |
| 出招动画延迟2 | attackAnimDelays[2] | 82 | 2 | s16 | 武功2 |
| 出招动画延迟3 | attackAnimDelays[3] | 84 | 2 | s16 | 武功3 |
| 出招动画延迟4 | attackAnimDelays[4] | 86 | 2 | s16 | 武功4 |
| 出招动画延迟5 | attackAnimDelays[5] | 88 | 2 | s16 | 武功5 |
| 武功音效延迟1 | soundDelays[1] | 90 | 2 | s16 | 武功1 音效延迟 |
| 武功音效延迟2 | soundDelays[2] | 92 | 2 | s16 | 武功2 |
| 武功音效延迟3 | soundDelays[3] | 94 | 2 | s16 | 武功3 |
| 武功音效延迟4 | soundDelays[4] | 96 | 2 | s16 | 武功4 |
| 武功音效延迟5 | soundDelays[5] | 98 | 2 | s16 | 武功5 |
| 内力性质 | innerType | 100 | 2 | s16 | 0=无 1=阳 2=阴 3=兼 |
| 内力 | mp | 102 | 2 | s16 | 当前内力 |
| 内力最大值 | maxMp | 104 | 2 | s16 | 最大内力 |
| 攻击力 | attack | 106 | 2 | s16 | 基础攻击 |
| 轻功 | speed | 108 | 2 | s16 | 轻功/速度 |
| 防御力 | defence | 110 | 2 | s16 | 基础防御 |
| 医疗能力 | medical | 112 | 2 | s16 | 医疗技能 |
| 用毒能力 | poison | 114 | 2 | s16 | 用毒技能 |
| 解毒能力 | antiPoison | 116 | 2 | s16 | 解毒技能 |
| 抗毒能力 | antiPoisonResist | 118 | 2 | s16 | 毒抗性 |
| 拳掌功夫 | fist | 120 | 2 | s16 | 拳法 |
| 御剑能力 | sword | 122 | 2 | s16 | 剑法 |
| 耍刀技巧 | blade | 124 | 2 | s16 | 刀法 |
| 特殊兵器 | special | 126 | 2 | s16 | 特殊兵器 |
| 暗器技巧 | hidden | 128 | 2 | s16 | 暗器 |
| 武学常识 | martialKnowledge | 130 | 2 | s16 | 武学知识 |
| 品德 | morality | 132 | 2 | s16 | 品德值 |
| 攻击带毒 | poisonAttack | 134 | 2 | s16 | 攻击附加毒 |
| 左右互搏 | doubleAttack | 136 | 2 | s16 | 0=关闭 1=开启 |
| 声望 | fame | 138 | 2 | s16 | 江湖声望 |
| 资质 | aptitude | 140 | 2 | s16 | 资质 |
| 修炼物品 | trainingItem | 142 | 2 | s16 | 修炼中的物品 ID |
| 修炼点数 | trainingPoints | 144 | 2 | s16 | 修炼进度 |
| 武功1..10 | skills[1..10].id | 146..164 | 各 2 | s16 | 10 个武功槽位的技能 ID |
| 武功等级1..10 | skills[1..10].level | 166..184 | 各 2 | s16 | 对应武功等级 (0–10) |
| 携带物品1..4 | items[1..4].id | 186..192 | 各 2 | s16 | 4 个携带物品 ID |
| 携带物品数量1..4 | items[1..4].count | 194..200 | 各 2 | s16 | 对应携带数量 |

---

### 4. Thing_S — 物品结构（260 字节/条，200 条）

> 存储于 ranger.grp，起始偏移 idx[2]，共 (idx[3]-idx[2])/260 条。

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 代号 | id | 0 | 2 | s16 | 物品 ID |
| 名称 | name | 2 | 40 | str | 物品名称 |
| 名称2 | name2 | 42 | 40 | str | 备用名称 |
| 物品说明 | desc | 82 | 60 | str | 描述文本 |
| 练出武功 | learnedSkill | 142 | 2 | s16 | 修炼得到的武功 ID |
| 暗器动画编号 | throwAnim | 144 | 2 | s16 | 投掷动画编号 |
| 使用人 | user | 146 | 2 | s16 | 限定使用者 ID |
| 装备类型 | equipType | 148 | 2 | s16 | 0=不可 1=武器 2=防具 |
| 显示物品说明 | displayDesc | 150 | 2 | s16 | 显示说明标志 |
| 类型 | itemType | 152 | 2 | s16 | 物品类别 |
| 未知5 | unknown5 | 154 | 2 | s16 | 未知 |
| 未知6 | unknown6 | 156 | 2 | s16 | 未知 |
| 未知7 | unknown7 | 158 | 2 | s16 | 未知 |
| 加生命 | addHp | 160 | 2 | s16 | 使用增加生命 |
| 加生命最大值 | addMaxHp | 162 | 2 | s16 | 使用增加最大生命 |
| 加中毒解毒 | addPoison | 164 | 2 | s16 | 使用增减毒 |
| 加体力 | addStamina | 166 | 2 | s16 | 使用增加体力 |
| 改变内力性质 | changeInnerType | 168 | 2 | s16 | 改变内力性质 |
| 加内力 | addMp | 170 | 2 | s16 | 使用增加内力 |
| 加内力最大值 | addMaxMp | 172 | 2 | s16 | 使用增加最大内力 |
| 加攻击力 | addAttack | 174 | 2 | s16 | 使用增加攻击 |
| 加轻功 | addSpeed | 176 | 2 | s16 | 使用增加轻功 |
| 加防御力 | addDefence | 178 | 2 | s16 | 使用增加防御 |
| 加医疗能力 | addMedical | 180 | 2 | s16 | 使用增加医疗 |
| 加用毒能力 | addPoisonSkill | 182 | 2 | s16 | 使用增加用毒 |
| 加解毒能力 | addAntiPoison | 184 | 2 | s16 | 使用增加解毒 |
| 加抗毒能力 | addAntiPoisonResist | 186 | 2 | s16 | 使用增加毒抗 |
| 加拳掌功夫 | addFist | 188 | 2 | s16 | 使用增加拳法 |
| 加御剑能力 | addSword | 190 | 2 | s16 | 使用增加剑法 |
| 加耍刀技巧 | addBlade | 192 | 2 | s16 | 使用增加刀法 |
| 加特殊兵器 | addSpecial | 194 | 2 | s16 | 使用增加特殊 |
| 加暗器技巧 | addHidden | 196 | 2 | s16 | 使用增加暗器 |
| 加武学常识 | addMartialKnowledge | 198 | 2 | s16 | 使用增加武学常识 |
| 加品德 | addMorality | 200 | 2 | s16 | 使用改变品德 |
| 加攻击次数 | addAttackCount | 202 | 2 | s16 | 使用增加攻击次数 |
| 加攻击带毒 | addPoisonAttack | 204 | 2 | s16 | 使用增加带毒 |
| 仅修炼人物 | practiceUser | 206 | 2 | s16 | 限定修炼者 ID |
| 需内力性质 | needInnerType | 208 | 2 | s16 | 需求内力性质 |
| 需内力 | needMp | 210 | 2 | s16 | 需求最小内力 |
| 需攻击力 | needAttack | 212 | 2 | s16 | 需求最小攻击 |
| 需轻功 | needSpeed | 214 | 2 | s16 | 需求最小轻功 |
| 需用毒能力 | needPoisonSkill | 216 | 2 | s16 | 需求最小用毒 |
| 需医疗能力 | needMedical | 218 | 2 | s16 | 需求最小医疗 |
| 需解毒能力 | needAntiPoison | 220 | 2 | s16 | 需求最小解毒 |
| 需拳掌功夫 | needFist | 222 | 2 | s16 | 需求最小拳法 |
| 需御剑能力 | needSword | 224 | 2 | s16 | 需求最小剑法 |
| 需耍刀技巧 | needBlade | 226 | 2 | s16 | 需求最小刀法 |
| 需特殊兵器 | needSpecial | 228 | 2 | s16 | 需求最小特殊 |
| 需暗器技巧 | needHidden | 230 | 2 | s16 | 需求最小暗器 |
| 需资质 | needAptitude | 232 | 2 | s16 | 需求最小资质 |
| 需经验 | needExp | 234 | 2 | s16 | 需求最小经验 |
| 练出物品需经验 | craftNeedExp | 236 | 2 | s16 | 锻造需经验 |
| 需材料 | needMaterial | 238 | 2 | s16 | 需原材料 ID |
| 练出物品1..5 | craftItems[1..5] | 240..248 | 各 2 | s16 | 锻造产物 ID（5 种） |
| 需要物品数量1..5 | craftCounts[1..5] | 250..258 | 各 2 | s16 | 对应原料数量 |

---

### 5. Scene_S — 场景结构（62 字节/条，84 条）

> 存储于 ranger.grp，起始偏移 idx[3]，共 (idx[4]-idx[3])/62 条。

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 代号 | id | 0 | 2 | s16 | 场景 ID（0xFFFF=空） |
| 名称 | name | 2 | 20 | str | 场景名称 |
| 出门音乐 | exitMusic | 22 | 2 | s16 | 离开音乐 ID |
| 进门音乐 | enterMusic | 24 | 2 | s16 | 进入音乐 ID |
| 跳转场景 | exitScene | 26 | 2 | s16 | 出口跳转目标场景 ID |
| 进入条件 | enterCondition | 28 | 2 | s16 | 进入条件标志 |
| 外景入口X1 | mapX | 30 | 2 | s16 | 大地图入口 X1 |
| 外景入口Y1 | mapY | 32 | 2 | s16 | 大地图入口 Y1 |
| 外景入口X2 | mapX2 | 34 | 2 | s16 | 大地图入口 X2（备用） |
| 外景入口Y2 | mapY2 | 36 | 2 | s16 | 大地图入口 Y2 |
| 入口X | entranceX | 38 | 2 | s16 | 场景内进入点 X |
| 入口Y | entranceY | 40 | 2 | s16 | 场景内进入点 Y |
| 出口X1..X3 | exits[1..3].x | 42..46 | 各 2 | s16 | 3 个出口的目标 X |
| 出口Y1..Y3 | exits[1..3].y | 48..52 | 各 2 | s16 | 3 个出口的目标 Y |
| 跳转口X1 | exits[1].targetX | 54 | 2 | s16 | 出口1 跳转目标 X |
| 跳转口Y1 | exits[1].targetY | 56 | 2 | s16 | 出口1 跳转目标 Y |
| 跳转口X2 | exits[2].targetX | 58 | 2 | s16 | 出口2 跳转目标 X |
| 跳转口Y2 | exits[2].targetY | 60 | 2 | s16 | 出口2 跳转目标 Y |

**出口逻辑**: 若 exitScene ≠ 0 且 ≠ 0xFFFF 则有出口。3 个出口位置坐标，前 2 个有跳转目标。

---

### 6. Wugong_S — 武功结构（146 字节/条，93 条）

> 存储于 ranger.grp，起始偏移 idx[4]，共 (idx[5]-idx[4])/146 条。

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 代号 | id | 0 | 2 | s16 | 武功 ID |
| 名称 | name | 2 | 20 | str | 武功名称 |
| 未知1..5 | unknown[1..5] | 22..30 | 各 2 | s16 | 未知字段 |
| 出招音效 | soundEffect | 32 | 2 | s16 | 音效 ID |
| 武功类型 | skillType | 34 | 2 | s16 | 0=拳 1=剑 2=刀 3=特 4=内功 |
| 武功动画&音效 | animEffect | 36 | 2 | s16 | 动画效果 ID |
| 伤害类型 | damageType | 38 | 2 | s16 | 0=物理 1=内力 |
| 攻击范围 | range | 40 | 2 | s16 | 范围类型 |
| 消耗内力点数 | mpCost | 42 | 2 | s16 | 每次消耗内力 |
| 敌人中毒点数 | poison | 44 | 2 | s16 | 附加毒点数 |
| 攻击力1..10 | powers[1..10] | 46..64 | 各 2 | s16 | 10 级每级攻击力 |
| 移动范围1..10 | moveRange[1..10] | 66..84 | 各 2 | s16 | 10 级每级移动格数 |
| 杀伤范围1..10 | damageRange[1..10] | 86..104 | 各 2 | s16 | 10 级每级杀伤半径 |
| 加内力1..10 | addMp[1..10] | 106..124 | 各 2 | s16 | 10 级每级自增内力 |
| 杀内力1..10 | killMp[1..10] | 126..144 | 各 2 | s16 | 10 级每级削敌内力 |

---

### 7. Shop_S — 商店结构（30 字节/条，5 条）

> 存储于 ranger.grp，起始偏移 idx[5]，共 (idx[6]-idx[5])/30 条。

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 物品1..5 | items[1..5].id | 0..8 | 各 2 | s16 | 5 个货架物品 ID |
| 物品数量1..5 | items[1..5].count | 10..18 | 各 2 | s16 | 对应库存数量 |
| 物品价格1..5 | items[1..5].price | 20..28 | 各 2 | s16 | 对应价格 |

---

### 8. WarData_S — 战斗/遭遇结构（186 字节/条，140 条）

> 存储于 data/war.sta。

| 中文名 | 英文名 | 偏移 | 大小 | 类型 | 描述 |
|---|---|---|---|---|---|
| 代号 | id | 0 | 2 | s16 | 战斗 ID |
| 名称 | name | 2 | 10 | str | 战斗名称 |
| 地图 | mapId | 12 | 2 | s16 | 战斗地图 ID |
| 经验 | exp | 14 | 2 | s16 | 获胜经验 |
| 音乐 | music | 16 | 2 | s16 | 战斗音乐 |
| 手动选择参战人1..6 | manualChars[1..6] | 18..28 | 各 2 | s16 | 可选队员 |
| 自动选择参战人1..6 | autoChars[1..6] | 30..40 | 各 2 | s16 | 自动队员 |
| 我方X1..X6 | ourX[1..6] | 42..52 | 各 2 | s16 | 我方初始 X |
| 我方Y1..Y6 | ourY[1..6] | 54..64 | 各 2 | s16 | 我方初始 Y |
| 敌人1..20 | enemies[1..20].id | 66..104 | 各 2 | s16 | 20 个敌人 ID |
| 敌方X1..X20 | enemies[1..20].x | 106..144 | 各 2 | s16 | 对应 X 坐标 |
| 敌方Y1..Y20 | enemies[1..20].y | 146..184 | 各 2 | s16 | 对应 Y 坐标 |

---

### 9. D* 事件结构（alldef.grp）

> 每场景 200 事件，每事件 11 个 s16 字段。

| 字段索引 | 中文名 | 英文名 | 类型 | 描述 |
|---|---|---|---|---|
| 0 | 通行标志 | passable | s16 | 0=可通行，非0=不可通行 |
| 1 | 未知1 | unknown1 | s16 | 未知 |
| 2 | 空格触发事件 | eventSpace | s16 | 按空格触发的事件号 |
| 3 | 经过触发事件 | eventTouch | s16 | 走到此格触发的事件号 |
| 4 | 额外触发事件 | eventExtra | s16 | 额外事件号 |
| 5 | 起始贴图 | tileStart | s16 | 动画起始贴图编号 |
| 6 | 结束贴图 | tileEnd | s16 | 动画结束贴图编号 |
| 7 | 当前贴图 | tileCurrent | s16 | 当前活动贴图 |
| 8 | 动画延迟 | animDelay | s16 | 帧间延迟 |
| 9 | X 坐标 | x | s16 | 场景内 X |
| 10 | Y 坐标 | y | s16 | 场景内 Y |

布局：`data[ (scene*200 + tile)*11 + field ]`（0-based 索引）。

---

### 10. 对话结构（oldtalk.idx/.grp）

**idx 文件**：4 字节偏移量数组（uint32 LE）。`idx[i]` 是对话 i 在 grp 中的起始偏移。对话 i 的长度 = `idx[i+1] - idx[i]`。

**grp 文件**：原始文本数据（GBK 编码，以 `\n` 结尾）。每段对话 = `grp:sub(idx[i]+1, idx[i+1])`。

---

### 11. 文件 - 提取脚本映射

| 结构体 | 源文件 | 记录数 | 输出 JSON | 提取脚本 |
|---|---|---|---|---|
| Base_S | ranger.grp 头部 | 1 | config.json | extract_base.lua |
| Person_S | ranger.grp idx[1] | 320 | chars.json | extract_runtime.lua |
| Thing_S | ranger.grp idx[2] | 200 | items.json | extract_runtime.lua |
| Scene_S | ranger.grp idx[3] | 84 | scenes.json | extract_scenes.lua |
| Wugong_S | ranger.grp idx[4] | 93 | skills.json | extract_runtime.lua |
| Shop_S | ranger.grp idx[5] | 5 | shops.json | extract_shops.lua |
| 入口（Scene_S派生） | ranger.grp idx[3] | 95 | entrances.json | extract_entrances.lua |
| D* 事件 | alldef.grp | 20000 | events.json | extract_events.lua |
| 战斗遭遇 | war.sta | 140 | wmap.json | extract_encounters.lua |
| 对话 | oldtalk.idx/.grp | 2977 | dialogues.json | extract_dialogues.lua |