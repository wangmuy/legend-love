## 为什么

Web MUD 需要知道每个场景里有什么——NPC 在哪个坐标、有哪些出口。场景数据存储在 `data/ranger.grp` 的场景段中（由游戏从 allsin.grp/s*.grp 初始化后写入存档），Web 版无法直接读取二进制。

## 变更内容

- 在 `tools/extract_web_data.lua` 中调用 `tools/extract_scenes.lua` 提取模块
- 从 `data/ranger.grp` 读取场景 Scene_S 段（场景元数据唯一源：名称、出口、入口坐标、进入条件等）
- 提取场景基础信息、出口坐标、NPC/物品坐标
- 输出 `game/engine-web/data-web/scenes.json`（中文键名）

## 能力

### 新增能力
- `extract-scenes`: 提取所有场景的结构数据（84 个场景，30+ 个字段）

### 修改的能力
- 无

## 影响

- 新增 `game/engine-web/data-web/scenes.json`（约 2-3 MB）