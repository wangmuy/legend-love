## 数据来源

运行时数据主要来自 `game/script/jyconst.lua`，其中定义了：

- `CC.Person_S`：人物数据结构定义（各字段偏移量）
- `CC.Thing_S`：物品数据结构定义
- 游戏初始化时通过二进制数据填充的具体数值

## 提取方法

1. `dofile` / `require` 加载 `jyconst.lua`
2. 读取 `JY.Person` 表（在游戏初始化后填充）
3. 读取 `JY.Thing` 表
4. 读取武功相关数据表

## 输出格式

### chars.json

```json
{
  "version": "1.0",
  "total": 999,
  "chars": [
    {
      "id": 0,
      "name": "主角",
      "level": 1,
      "hp": 50,
      "mp": 30,
      "attack": 30,
      "defence": 30,
      "speed": 30,
      "qinggong": 30,
      "skill1": 0, "skill1Lv": 0,
      "skill2": 0, "skill2Lv": 0,
      "skill3": 0, "skill3Lv": 0,
      "skill4": 0, "skill4Lv": 0,
      "wugong1": 1, "wugong1Lv": 1,
      "wugong2": 0, "wugong2Lv": 0,
      "wugong3": 0, "wugong3Lv": 0,
      "wugong4": 0, "wugong4Lv": 0
    }
  ]
}
```

### items.json

```json
{
  "version": "1.0",
  "total": 200,
  "items": [
    {
      "id": 0,
      "name": "基本物品",
      "type": 0,
      "effect": 0,
      "price": 0
    }
  ]
}
```

字段说明（物品 type）：
- 0=剧情 1=武器 2=防具 3=药品 4=暗器 5=秘籍 6=装备材料

### skills.json

```json
{
  "version": "1.0",
  "total": 100,
  "skills": [
    {
      "id": 1,
      "name": "野球拳",
      "type": 0,
      "power": 100,
      "mpCost": 0,
      "range": 1,
      "rangeType": 0
    }
  ]
}
```

字段说明（武功 type）：
- 0=拳掌 1=剑法 2=刀法 3=特殊 4=暗器 5=医疗 6=用毒 7=解毒

（range/rangeType 留作战斗系统 1D 距离换算的原始数据）