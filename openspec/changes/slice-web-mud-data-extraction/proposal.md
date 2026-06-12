## 为什么

Web MUD 文字版需要在浏览器中运行游戏，而原版游戏数据为二进制格式（.grp、.idx、.bin 等），Love2D 版通过 `lib_Byte.lua` 解析这些二进制文件。Web 版没有本地文件系统，Fengari 也不能直接读取二进制文件。

解决方案：将原版二进制数据提取为 JSON 文件，Web 版通过 fetch 加载 JSON。

## 变更内容

- 在 `game/tools/` 中创建提取管线，包含多个提取脚本
- 脚本在 Love2D 环境（纯 Lua）中运行，读取 data/ 和 script/ 下的二进制文件
- 产出 10 个 JSON 文件到 `game/engine-web/data-web/` 目录
- JSON 使用中文键名（匹配 CC.*_S 定义），无需字段名映射

## 能力

### 新增能力
- `extract-dialogues`: 对话文本提取（从 oldtalk.grp/.idx）
- `extract-scenes`: 场景结构提取（从 ranger.grp 的 Scene_S 段——场景元数据唯一源）
- `extract-chars-items-skills`: 人物/物品/武功数据导出（从 ranger.grp 的运行时数据段——无独立源文件，数据原嵌于 DOS 可执行文件）
- `extract-entrances`: 大地图场景入口映射（从 ranger.grp 的 Scene_S 段——入口坐标字段 `外景入口X1/Y1` / `外景入口X2/Y2`）
- `extract-encounters`: 遇敌/战斗地图数据（从 war.sta、fight*.grp、warfld.*）
- `extract-events`: D* 事件数据（从 alldef.grp）
- `extract-base-config`: 游戏基础配置（从 ranger.grp 头部——初始存档模板，唯一源）
- `extract-shops`: 商店数据（从 ranger.grp 商店段——无独立源文件）

### 修改的能力
- 无（纯新增工具脚本，不影响现有 Love2D 运行）

## 影响

- 新增 `game/tools/extract_web_data.lua` 统一运行器 + 8 个子提取脚本
- 新增 `game/tools/filter_web_data.py` 过滤不需要的图形/音效字段
- 新增 `game/tools/verify_web_data.lua` 完整性验证器
- 新增 `game/engine-web/data-web/` 目录，包含 10 个 JSON 文件（中文键名）
- 总量约 5-15 MB（视提取范围而定）
- 无现有代码修改，Love2D 版完全不受影响
- data-web/*.json 文件虽在 .gitignore 中，但通过 git add -f 追踪