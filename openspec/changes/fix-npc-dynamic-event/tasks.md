## 1. SetD/GetD 实现
Traceability: [REQ-002]

- [x] 1.1 实现 `SetD(sceneid, id, field, value)` 存储 D* 事件数据到 `JY.Scene`
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `JY.Scene[sceneid][id][field] = value`

- [x] 1.2 实现 `GetD(sceneid, id, field)` 从 `JY.Scene` 读取 D* 事件数据
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 返回 `JY.Scene[sceneid][id][field]` 或 0

## 2. smapNpcTalk 动态事件 ID 查找
Traceability: [REQ-002]

- [x] 2.1 在 `smapNpcTalk` 中，先尝试从 `GetD(sceneId, dIdx, 0)` 获取动态事件 ID
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] 使用 `ent.npcIndex` 作为 dIdx
    - [x] 设置 `JY.CurrentD = dIdx` 确保 `instruct_3` 可正确修改 D* 表
    - [x] 若 `GetD` 返回有效 ID (>0)，使用动态 ID

- [ ] 2.2 修复 `instruct_3` 修改字段 4/5 后动态事件 ID 读取
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua", "game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `SetD`/`GetD` 实现，使用 `JY.D` 存储
    - [x] `smapNpcTalk` 字段5优先（神杖检查686）
    - [ ] 霹雳堂孔八拉二次对话触发神杖检查(686)：`GetD` 返回字段5=686
    - [ ] 已知问题：`lib.SetD` 写入 `JY.D` 后，`lib.GetD` 未返回写入值（可能 `JY.D` 未持久化或 `ensureSceneDEvents` 覆盖数据）

## 3. 验证
Traceability: [REQ-WT-001]

- [x] 3.1 回归测试 P1-P10 全部通过
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] `npx playwright test tests/walkthrough-p1.spec.js` 通过
    - [x] P2-P10 全部通过