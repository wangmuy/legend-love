## 为什么

Web MUD 需要知道每个场景里有什么——NPC 在哪个坐标、有哪些出口、哪里触发事件。
这些信息存储在 `allsin.grp/.idx`、`s*.grp/.idx`、`d*.grp/.idx` 等二进制文件中，
Web 版无法直接读取。

## 变更内容

- 在 `tools/extract_web_data.lua` 中实现场景数据提取模块
- 从 allsin 文件读取场景基础信息（名称、尺寸）
- 从 s* 文件读取场景出口、NPC 坐标、物品坐标
- 从 d* 文件读取事件触发点
- 输出 `game/data-web/scenes.json`

## 能力

### 新增能力
- `extract-scenes`: 提取所有场景的结构数据（70+ 个场景）

### 修改的能力
- 无

## 影响

- 新增 `game/data-web/scenes.json`（约 2-3 MB）