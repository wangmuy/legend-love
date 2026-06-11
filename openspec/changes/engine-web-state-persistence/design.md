# 设计 — engine-web-state-persistence

## 数据流

提取管线输出中文键 JSON（匹配 CC.*_S 定义）→ dataCache → JY.*（直接赋值，无 mapping）。

```
提取管线 (extract_*.lua)
    │  输出 {"代号":0, "姓名":"令狐冲", "攻击力":120, ...}
    ▼
dataCache.chars[i]（中文键）
    │  initGameState() 直接赋值
    ▼
JY.Person[id]（中文键）
    │  游戏脚本直接读写：JY.Person[0]["攻击力"] = 100
    ▼
saveGameState() → encodeSimpleJSON → JSBridge.save() → IndexedDB
```

## 场景数据展平

dataCache 中的场景数据使用嵌套结构（`入口`/`出口`），但 JY.* 使用 CC.Scene_S 的平铺字段。`initGameState()` 负责展平：

| JSON 路径 | JY.* 键 |
|-----------|---------|
| `scene["入口"]["地图X"]` | `scene["外景入口X1"]` |
| `scene["入口"]["地图Y"]` | `scene["外景入口Y1"]` |
| `scene["入口"]["地图X2"]` | `scene["外景入口X2"]` |
| `scene["出口"][j]["X"]` | `scene["出口X"..j]` |
| `scene["出口"][j]["目标X"]` | `scene["跳转口X"..j]` |

## 存档格式

使用中文键名存储，与游戏脚本的字段名一致，无需二次映射。

```json
{
  "version": "1",
  "timestamp": 1234567890,
  "base": { "人X": 357, "人Y": 235, "队伍1": 0, ... },
  "persons": { "0": { "代号": 0, "姓名": "徐小俠", ... }, ... },
  "things": { "0": { "代号": 0, "名称": "药材", ... }, ... },
  "scenes": { "0": { "代号": 0, "名称": "胡斐居", ... }, ... },
  "wugongs": { "0": { "代号": 0, "名称": "野球拳", ... }, ... },
  "shops": { "0": { "物品1": 7, ... }, ... }
}
```

0-based 数值键在 JSON 中保存为字符串 key（`"0"`）。`restoreNumericKeys()` 在 load 时恢复为数值 key。

## 存档槽规划

| 槽位 | key | 用途 |
|------|-----|------|
| 0 | `save_0` | 自动存档 |
| 1 | `save_1` | 手动存档 1 |
| 2 | `save_2` | 手动存档 2 |
| 3 | `save_3` | 手动存档 3 |

## JSBridge 存储接口

使用 `fengari.to_jsstring(lua_tolstring())` 正确转换 Lua 字符串，避免 WASM 指针问题。

```javascript
// 初始化
const saveCache = {};
const DB_NAME = 'jyLegendWebMud';
const STORE_NAME = 'saves';

function dbSave(key, value) {
    saveCache[key] = value;                  // 同步内存缓存
    if (!dbInstance) return;
    const tx = dbInstance.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    store.put({ key, value });               // 异步 IndexedDB 写
}

function dbLoad(key) {
    return saveCache[key] || null;
}
```

页面加载时从 IndexedDB 预加载所有存档到 `saveCache`（`loadAllSavesToCache()`），后续所有读写操作通过同步的 `saveCache` 完成。

## 关键技术决策

1. **没有 mapping 层** — 提取管线直接输出中文 key，dataCache 和 JY.* 使用相同的键名
2. **内存缓存 + IndexedDB 双写** — saveCache 提供同步读取，IndexedDB 提供跨页面持久化
3. **`lua_tolstring` + `to_jsstring`** — 修复 Fengari WASM 的指针问题，避免 JS object key 变成 Uint8Array