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

### 2. 输出目录：game/data-web/

和 `game/data/` 并列。`data/` 是原版二进制数据，`data-web/` 是提取后的 JSON。

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