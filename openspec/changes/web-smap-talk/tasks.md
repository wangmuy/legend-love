## 1. talk 命令实现
Traceability: [REQ-001]

- [ ] 1.1 注册 `talk <人名>` 命令到 SMAP 状态
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] SMAP 命令表中包含 `talk` 条目
    - [ ] help 在 SMAP 状态显示 talk

- [ ] 1.2 实现 NPC 查找和事件 ID 获取
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 根据 `JY.SubScene` 获取当前场景数据
    - [ ] 在场景 NPC 列表中按名称匹配
    - [ ] 获取 NPC 的 `事件编号` 字段

- [ ] 1.3 调用 EventExecutor 执行 oldevent
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua", "game/framework/event_executor.lua"]`
  DoD:
    - [ ] `EventExecutor.startEvent(eventId, flag, callback)` 被调用
    - [ ] 事件完成后调用回到场景的命令

- [ ] 1.4 实现 instruct_1（对话文本输出）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取文本
    - [ ] 对话文本通过 WebUI.write 输出
    - [ ] 与场景描述之间有分隔线

- [ ] 1.5 实现 instruct_0（清屏）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_0()` 输出分隔线（不清除终端，只输出视觉分隔）

- [ ] 1.6 实现 WaitKey（等待用户输入）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `WaitKey()` 显示 "按回车继续..."
    - [ ] 等待用户输入任意文字 + 回车后继续

- [ ] 1.7 实现 ShowMenu 的事件菜单版本
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] 事件中的 ShowMenu 调用显示选项列表
    - [ ] choose N 选择后事件脚本继续

## 2. 测试
Traceability: [REQ-001]

- [ ] 2.1 E2E 测试：talk 命令匹配场景 NPC
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 在场景中输入 talk <NPC名> 能定位到 NPC
    - [ ] 找不到 NPC 时给出提示

- [ ] 2.2 E2E 测试：instruct_1 对话文本输出
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 对话文本显示在终端
