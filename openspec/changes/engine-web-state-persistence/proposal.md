## 为什么

游戏脚本（jymain.lua 等）使用中文键名操作 JY.* 表（如 `JY.Person[0]["攻击力"]=100`）。提取管线现在直接输出中文键名的 JSON（匹配 CC.*_S 定义），因此 dataCache 和 JY.* 之间无需翻译层。

但 Web MUD 需要在浏览器中持久化游戏状态（存档/读档），Lua 侧没有文件系统能力，需要通过 JSBridge 访问浏览器的 IndexedDB 存储引擎。

## 变更内容

1. **initGameState()** — 将 dataCache（中文键 JSON）拷贝到 JY.* 表，处理场景数据展平（嵌套 `入口`/`出口` → 平铺字段）
2. **saveGameState()** — 序列化 JY.* 表（中文键）为 JSON，通过 JSBridge 存入 IndexedDB
3. **loadGameState()** — 从 IndexedDB 读取 JSON，恢复 JY.* 表
4. **JSBridge 存储接口** — `JSBridge.save(key, jsonStr)` / `JSBridge.load(key)` / `JSBridge.delete(key)` / `JSBridge.listSaves()`
5. **提取管线** — 所有提取脚本输出中文键 JSON，无 mapping 层

## 能力

### 新增能力
- `initGameState()` → 从 dataCache 初始化 JY.* 表
- `saveGameState(slotId)` → 序列化 JY.* 表到 IndexedDB
- `loadGameState(slotId)` → 从 IndexedDB 恢复 JY.* 表
- `JSBridge.save(key, json)` / `JSBridge.load(key)` / `JSBridge.delete(key)` / `JSBridge.listSaves()` → IndexedDB 存储
- `restoreNumericKeys()` → JSON 反序列化时恢复 0-based 数值键
- `encodeSimpleJSON()` → 轻量 JSON 编码器（无外部依赖）
- 4 个存档槽（槽 0 自动存档 + 槽 1~3 手动存档）

### 修改的能力
- index.js：新增 JSBridge.save/load/delete/listSaves 的 IndexedDB 实现
- 提取脚本（extract_*.lua）：所有字段名改为中文

## 影响

- engine-web/index.js — 新增 IndexedDB 存储逻辑
- engine-web/state_manager.lua — 新增状态管理器
- engine-web/tests/ — 新增状态持久化测试（9 个）
- game/tools/extract_runtime.lua — 字段名中文化
- game/tools/extract_scenes.lua — 字段名中文化
- game/tools/extract_base.lua — 字段名中文化
- game/tools/extract_shops.lua — 字段名中文化
- game/tools/filter_web_data.py/.lua — 过滤字段名中文化