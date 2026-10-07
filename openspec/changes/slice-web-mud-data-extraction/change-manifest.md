# Change Manifest — 数据提取管线

## 依赖顺序

```
extract-dialogue-data  ──┐
extract-scene-data     ──┤
extract-runtime-data   ──┤  (无依赖，可并行)
extract-entrance-data  ──┤
extract-encounter-data ──┘
          │
extract-complete-binary ── (依赖前 5 个完成，做全字段审计与补充)
```

前 5 个 change 无前置依赖，可并行开发。第 6 个 change 依赖前 5 个的基础结构。

## Change Assignments

### 1. extract-dialogue-data

| 字段 | 值 |
|------|-----|
| Scope | 从 oldtalk.grp/.idx 提取对话文本 |
| Responsibility | 读取 idx 偏移量 → 按偏移截取 grp 文本 → 提取 speaker/text → 写入 JSON |
| Depends on | 无 |
| Status | [x] Created |

### 2. extract-scene-data

| 字段 | 值 |
|------|-----|
| Scope | 从 ranger.grp 提取场景结构 |
| Responsibility | 读取场景基础信息、出口坐标、跳转目标 |
| Depends on | 无 |
| Status | [x] Created |

### 3. extract-runtime-data

| 字段 | 值 |
|------|-----|
| Scope | 从 ranger.grp 导出人物/物品/武功数据 |
| Responsibility | 解析二进制结构 → 提取核心属性 → 写入 JSON |
| Depends on | 无 |
| Status | [x] Created |

### 4. extract-entrance-data

| 字段 | 值 |
|------|-----|
| Scope | 从 ranger.grp 提取场景在大地图的入口坐标 |
| Responsibility | 读取场景入口坐标 → 建立坐标→场景 ID 映射 |
| Depends on | 无 |
| Status | [x] Created |

### 5. extract-encounter-data

| 字段 | 值 |
|------|-----|
| Scope | 提取战斗地图和遇敌配置 |
| Responsibility | 读取战斗地图索引和遇敌配置 → 写入 JSON |
| Depends on | 无 |
| Status | [x] Created |

### 6. extract-complete-binary

| 字段 | 值 |
|------|-----|
| Scope | 全字段审计 + D* 事件 + 基础/商店数据 + 补充提取 |
| Responsibility | 补全所有二进制字段、修复 Bug、提取 D*/基础/商店数据、更新验证脚本和测试 |
| Depends on | 1-5 |
| Status | [x] Created |

## Shared Contracts

所有 6 个 change 的产出都是 JSON 文件，约定：

| 约定 | 规则 |
|------|------|
| 文件位置 | `game/engine-web/data-web/` |
| 顶层字段 | 必须包含 `version`、`extracted`、`total` |
| 文件名 | 固定：dialogues.json, scenes.json, chars.json, items.json, skills.json, entrances.json, wmap.json, events.json, shops.json, config.json |
| 编码 | UTF-8，无 BOM |
| 加载方式 | data_loader.lua 的 `loadJSONChunk()` 注入到 `_G.dataCache[key]`，JS 侧 fetch 后逐个注入 |

## Integration Test Plan

验证脚本 `tools/verify_web_data.lua` 会：
1. 加载所有 JSON 文件
2. 检查每个文件的格式完整性（version、total 字段）
3. 检查跨文件引用（entrances 场景 ID → scenes、shops 物品 ID → items、D* 事件场景 ID → scenes）
4. 输出统计报告（场景数、对话数、物品数等）
5. 确认总大小 ≤ 15MB

Playwright E2E 测试（`game/engine-web/tests/data-integrity.spec.js`）会：
1. 验证 Lua VM 中 dataCache 加载完整
2. 验证所有 10 个 JSON 文件在浏览器中可用
3. 验证跨数据引用完整性（entrances→scenes、D* 事件→scenes、shops 物品→items）