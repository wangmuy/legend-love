# Change Manifest — 数据提取管线

## 依赖顺序

```
extract-dialogue-data  ──┐
extract-scene-data     ──┤
extract-runtime-data   ──┤  (无依赖，可并行)
extract-entrance-data  ──┤
extract-encounter-data ──┘
```

所有 5 个 change 无前置依赖，可并行开发。

## Change Assignments

### 1. extract-dialogue-data

| 字段 | 值 |
|------|-----|
| Scope | 从 oldtalk.grp/.idx 提取对话文本 |
| Responsibility | 读取 idx 偏移量 → 按偏移截取 grp 文本 → 写入 JSON |
| Depends on | 无 |
| Status | [x] Created |

### 2. extract-scene-data

| 字段 | 值 |
|------|-----|
| Scope | 从 allsin、s*、d* 文件提取场景结构 |
| Responsibility | 读取场景基础信息、出口、NPC/物品坐标、事件触发点 |
| Depends on | 无 |
| Status | [x] Created |

### 3. extract-runtime-data

| 字段 | 值 |
|------|-----|
| Scope | 从 jyconst.lua 导出人物/物品/武功数据 |
| Responsibility | 加载 jyconst.lua → 遍历数据表 → 写入 JSON |
| Depends on | 无 |
| Status | [x] Created |

### 4. extract-entrance-data

| 字段 | 值 |
|------|-----|
| Scope | 从 mmap.grp/.idx 提取大地图场景入口 |
| Responsibility | 扫描 mmap 瓦片 → 识别入口标记 → 建立坐标→场景 ID 映射 |
| Depends on | 无 |
| Status | [x] Created |

### 5. extract-encounter-data

| 字段 | 值 |
|------|-----|
| Scope | 提取战斗地图和遇敌配置 |
| Responsibility | 读取战斗地图索引和遇敌配置 → 写入 JSON |
| Depends on | 无 |
| Status | [x] Created |

## Shared Contracts

所有 5 个 change 的产出都是 JSON 文件，约定：

| 约定 | 规则 |
|------|------|
| 文件位置 | `game/engine-web/data-web/` |
| 顶层字段 | 必须包含 `version`、`extracted`、`total` |
| 文件名 | 固定：dialogues.json, scenes.json, chars.json, items.json, skills.json, entrances.json, wmap.json |
| 编码 | UTF-8，无 BOM |
| 加载方式 | Lua 中 `local data = require("data-web.<name>")` |

## Integration Test Plan

验证脚本 `tools/verify_web_data.lua` 会：
1. 加载所有 7 个 JSON 文件
2. 检查每个文件的格式完整性（version、total 字段）
3. 检查跨文件引用（场景中的 NPC ID 在 chars.json 中存在）
4. 输出统计报告（场景数、对话数、物品数等）
5. 确认总大小 ≤ 15MB