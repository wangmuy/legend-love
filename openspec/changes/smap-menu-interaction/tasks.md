## 1. look 编号列表输出
Traceability: [REQ-001]

- [x] 1.1 `SmapHandlers.look` 输出 NPC/物品/出口编号列表
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] 格式 "N. <NPC名>" / "N. <物品名>" / "N. → <出口名>"
    - [x] 末尾提示 "输入 choose <编号> 选择交互对象"
    - [x] 无对象时输出 "这里什么都没有。"

- [x] 1.2 `smapEntityList` 重建
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] 每次 `look` 时清除并重建列表

## 2. choose 路由
Traceability: [REQ-001]

- [x] 2.1 `SmapHandlers.chooseInteraction(idx)` 路由到子处理器
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] NPC → CE.showMenu({对话, 查看, 给予物品})
    - [x] 物品 → CE.showMenu({拾取, 查看})
    - [x] 出口 → SmapHandlers.go()

- [x] 2.2 `processEventQueue` 中 SMAP choose 拦截
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `choose N` 无菜单时 → SMAP State 4 → chooseInteraction

## 3. 测试
Traceability: [REQ-001]

- [x] 3.1 单元测试：look 显示编号列表（程序化 SMAP 状态）
- [x] 3.2 单元测试：choose N 不报错
