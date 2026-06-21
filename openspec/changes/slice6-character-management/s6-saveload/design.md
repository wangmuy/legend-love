## Context

原版存档使用 .grp 文件。Web MUD 使用 IndexedDB + `state_manager.lua`。

## Decisions

### 存档流程
1. 调用 `saveGameState(slot)` 序列化 JY 全局状态
2. `state_manager.lua` 将状态写入 IndexedDB

### 读档流程
1. 调用 `loadGameState(slot)` 从 IndexedDB 读取
2. 恢复 JY 全局状态
3. 自动显示当前状态（MMAP/SMAP）

### 自动存档
- 场景切换时（`go`/`leave` 命令）自动保存到槽位 0
- 不打断用户操作流程
