# 设计 — engine-web-state-persistence

## 字段名映射

在 Lua 中生成映射表，覆盖所有需要存档的数据结构。映射表为双向：

```lua
_G.fieldMap = {
    base = {
        ["乘船"] = "shipFlag",  ["人X"] = "playerX",  ["人Y"] = "playerY",
        -- ... 所有 Base_S 字段
    },
    person = {
        ["代号"] = "id",  ["姓名"] = "name",  ["攻击力"] = "attack",
        -- ... 所有 Person_S 字段
    },
    thing = {
        ["代号"] = "id",  ["名称"] = "name",  ["加攻击力"] = "addAttack",
        -- ... 所有 Thing_S 字段
    },
    scene = {
        ["代号"] = "id",  ["名称"] = "name",  ["进入条件"] = "enterCondition",
        -- ... 所有 Scene_S 字段
    },
    wugong = {
        ["代号"] = "id",  ["名称"] = "name",  ["武功类型"] = "skillType",
        -- ... 所有 Wugong_S 字段
    },
    shop = {
        ["物品1"] = "item1", -- ...
    },
}
```

映射表从 jyconst.lua 中的 CC.*_S 定义自动推导：`{key = {offset, type, length}}` → 键名即中文名。

## 状态加载/保存流程

```
loadGameState(slotId)                 saveGameState(slotId)
─────────────────────                 ─────────────────────
dataCache（英文键）                    JY.* 表（中文键）
    │                                      │
    │  fieldMap.person                    │  fieldMap.person（反向）
    ▼                                      ▼
JY.Person[i][字段表]                   JSON 字符串
（中文键 Lua 表）                          │
    │                                      │  JSBridge.save()
    │  (后续由游戏脚本直接修改)              ▼
    ▼                                   IndexedDB
JY.Person[0]["攻击力"] = 100
```

## JSBridge 存储接口

```javascript
// index.js 新增
lua.lua_pushstring(L, 'save');
lua.lua_pushcfunction(L, function(state) {
    const key = lua.lua_tostring(state, -2);    // key
    const val = lua.lua_tostring(state, -1);    // JSON string
    // 存到 IndexedDB
    return 0;
});
lua.lua_settable(L, -3);

lua.lua_pushstring(L, 'load');
lua.lua_pushcfunction(L, function(state) {
    const key = lua.lua_tostring(state, -1);    // key
    // 从 IndexedDB 读取（同步返回值）
    // 用 coroutine.yield/resume 异步等待
    return 1;
});
lua.lua_settable(L, -3);
```

## 存档槽规划

| 槽位 | key | 用途 |
|------|-----|------|
| 0 | `save_0` | 自动存档 |
| 1 | `save_1` | 手动存档 1 |
| 2 | `save_2` | 手动存档 2 |
| 3 | `save_3` | 手动存档 3 |

## 序列化格式

```json
{
  "version": "1",
  "timestamp": 1234567890,
  "base": { "玩家": 0, "队伍": [0,...], ... },
  "persons": [ { "代号": 0, "姓名": "...", ... }, ... ],
  "things": [ { "代号": 0, "名称": "...", ... }, ... ],
  "scenes": [ { "代号": 0, "名称": "...", ... }, ... ],
  "wugongs": [ { "代号": 0, "名称": "...", ... }, ... ],
  "shops": [ { "物品1": 10, ... }, ... ],
}
```

使用中文键名存储，确保与游戏脚本的字段名一致，无需二次映射。