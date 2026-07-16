## 为什么

现有 `smapNpcTalk` 从静态 NPC 数据 (`ent.npcData["事件编号"]`) 读取事件 ID，导致 `instruct_3` 修改 D* 事件表后，NPC 交互仍触发旧事件。例如霹雳堂孔八拉：首次对话 (oldevent_678) 通过 `instruct_3` 将事件修改为 686 (神杖检查)，但再次对话仍触发 678。

## 变更内容

- `game/engine-web/mmap_smap_handlers.lua` — `smapNpcTalk` 增加动态事件 ID 查找逻辑

## 能力

### 新增能力
- NPC 交互时优先从 D* 事件表 (`JY.Scene`) 查找动态事件 ID
- 若动态事件 ID 存在且有效，使用动态 ID 替代静态 NPC 数据中的 ID

### 修改的能力
- `smapNpcTalk` 的事件 ID 解析逻辑

## 影响

- 修复 `instruct_3` 修改事件后 NPC 交互仍触发旧事件的问题
- 影响所有使用 `instruct_3` 修改 NPC 事件的 oldevent 脚本（如霹雳堂孔八拉）