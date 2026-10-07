## 为什么

oldevent 脚本通过 67 个 `instruct_*` 函数与游戏引擎交互。Web MUD 中目前只有 `instruct_0`（分隔线）和 `instruct_1`（对话文本）已实现。其他 65 个函数缺失导致 oldevent 脚本执行到第一个未实现函数时就崩溃。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/event-system-integration/change-manifest.md`
- 依赖: event-executor-loader

## What Changes

在 `web_game_bridge.lua` 中为全部 67 个 `instruct_*` 函数提供 Web MUD 版实现：

| 分类 | 策略 | 函数 |
|------|------|------|
| 显示 | ✅ 已有 | 0, 1 |
| 动画/音效 | no-op | 27, 67, 37(场景音乐) |
| 状态修改 | 更新 JY 数据 | 3(事件), 2(出入口), 40(方向), 17 |
| 菜单 | MenuAsync 代理 | 13, 14(战斗) |
| 物品/金钱 | 背包操作 | 32, 5, 33 |
| 队友 | 队伍管理 | 56, 34, 44 |
| 其他 | `debug.log` 提示 | 4, 6-12, 15-26, 28-31, 35-36, 38-39, 41-43, 45-55, 57-66 |
| 未实现 | 输出 "[instruct_N 未实现]" | 兜底 handler |

## Impact

| 文件 | 改动 |
|------|------|
| `web_game_bridge.lua` | 注册 67 个 instruct 函数 |
