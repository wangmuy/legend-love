## 为什么

Web MUD 文字版需要在浏览器中运行游戏，而原版游戏数据为二进制格式（.grp、.idx、.bin 等），Love2D 版通过 `lib_Byte.lua` 解析这些二进制文件。Web 版没有本地文件系统，Fengari 也不能直接读取二进制文件。

解决方案：将原版二进制数据提取为 JSON 文件，Web 版通过 fetch 加载 JSON。

## 变更内容

- 在 `game/` 中创建 `tools/extract_web_data.lua` 数据提取脚本
- 脚本利用现有的 `lib_Byte.lua` 解析二进制数据
- 产出 JSON 文件到 `game/data-web/` 目录
- 每份 JSON 可直接被 Lua `require` 加载

## 能力

### 新增能力
- `extract-dialogues`: 对话文本提取（从 oldtalk.grp/.idx）
- `extract-scenes`: 场景结构提取（从 allsin、s*、d* 文件）
- `extract-chars-items-skills`: 人物/物品/武功数据导出（从 jyconst.lua + 二进制验证）
- `extract-entrances`: 大地图场景入口映射（从 mmap.grp/.idx）
- `extract-encounters`: 遇敌/战斗地图数据

### 修改的能力
- 无（纯新增工具脚本，不影响现有 Love2D 运行）

## 影响

- 新增 `game/tools/extract_web_data.lua`
- 新增 `game/data-web/` 目录，包含 5-7 个 JSON 文件
- 总量约 5-15 MB（视提取范围而定）
- 无现有代码修改，Love2D 版完全不受影响