# 设计 — extract-complete-binary

## D* 事件数据（alldef.grp）

alldef.grp 存储每个场景 200 个地砖事件，每个事件 11 个 int16 字段（22 字节）。

```
场景数: 84
每个场景事件数: 200
每个事件大小: 22 字节 (11 × int16)
总大小: 84 × 200 × 22 = 369,600 字节
```

**事件字段**:
| 索引 | 用途 | 提取名 |
|------|------|--------|
| 0 | 通行标志 (0=可通行) | passable |
| 1 | 未知 | unknown1 |
| 2 | 空格触发事件 ID | eventSpace |
| 3 | 触碰触发事件 ID | eventTouch |
| 4 | 额外触发事件 ID | eventExtra |
| 5 | 起始贴图编号 | tileStart |
| 6 | 结束贴图编号 | tileEnd |
| 7 | 当前贴图编号 | tileCurrent |
| 8 | 动画延迟 | animDelay |
| 9 | X 坐标（场景内） | x |
| 10 | Y 坐标（场景内） | y |

**events.json 结构**:
```json
{
  "version": 1,
  "extracted": "2026-06-10",
  "total": 16800,
  "events": [
    {
      "sceneId": 0,
      "tileIndex": 0,
      "passable": true,
      "eventSpace": -1,
      "eventTouch": -1,
      "eventExtra": -1,
      "tileStart": 0,
      "tileEnd": 0,
      "tileCurrent": 0,
      "animDelay": 0,
      "x": 0,
      "y": 0
    }
  ]
}
```

## 基础数据（ranger.grp 0-836 字节）

CC.Base_S 结构。提取主角当前场景/位置、队伍、物品栏等游戏状态基础数据。

**config.json 结构**:
```json
{
  "version": 1,
  "extracted": "2026-06-10",
  "my": { "id": 0, "sceneId": 70, "x": 0, "y": 0, "face": 2 },
  "team": [0, -1, -1, -1, -1, -1],
  "items": [],
  "ship": false
}
```

## 出口 Bug 修复

原代码（extract_scenes.lua，第 139-144 行）：
```lua
for j = 0, 2 do
    local ex = offset + 42 + j * 2
    local ey = offset + 48 + j * 2
    local tjx = offset + 54 + j * 2  -- Bug: j=1 时读取 56(Y1)，j=2 时读取 58(X2)
    local tjy = offset + 56 + j * 2  -- Bug: j=1 时读取 58(X2)，j=2 时读取 60(Y2)
    ...
end
```

修正：
```lua
for j = 0, 2 do
    local ex = offset + 42 + j * 2
    local ey = offset + 48 + j * 2
    if j < 2 then  -- 只有 2 个跳转目标
        local tjx = offset + 54 + j * 2
        local tjy = offset + 56 + j * 2
    end
    ...
end
```

## 数据流变更

```
extract_web_data.lua:
  ├── extract_dialogues()   → dialogues.json
  ├── extract_scenes()      → scenes.json      (字段补全 + Bug 修复)
  ├── extract_runtime()     → chars.json        (字段补全)
  │                        → items.json         (字段补全)
  │                        → skills.json        (字段补全)
  ├── extract_entrances()   → entrances.json
  ├── extract_encounters()  → wmap.json
  ├── extract_events()      → events.json       (新增)
  ├── extract_base()        → config.json       (新增)
  └── extract_shops()       → shops.json        (新增)
```

data_loader.lua:
- 新增 `events.json` → `dataCache["events"]`
- 新增 `config.json` → `dataCache["config"]`
- 新增 `shops.json` → `dataCache["shops"]`
- dataCachePaths 更新 + _fileCount 更新为 10

data-integrity.spec.js:
- 新增 3 个文件测试 (events/config/shops)
- 新增 5.11 D* 事件引用的物品 ID 在 items 中存在