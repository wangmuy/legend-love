## 1. P0 常用 instruct 实现
Traceability: [REQ-002]

- [ ] 1.1 P0 函数（oldevent_691 使用）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_27()` no-op 不崩溃
    - [ ] `instruct_40(dir)` 设置 JY.Base["人方向"]
    - [ ] `instruct_67()` no-op 不崩溃
    - [ ] `instruct_3(...)` 更新场景事件数据不崩溃

## 2. P1-P2 覆盖

- [ ] 2.1 P1 函数
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_2(...)` no-op 不崩溃
    - [ ] `instruct_13(...)` 菜单（MenuAsync 代理）
    - [ ] `instruct_32(...)` 给物品（背包操作）
    - [ ] `instruct_56(...)` 队伍

- [ ] 2.2 全部 67 个函数的兜底 handler
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] 循环注册未定义函数，输出 debug.log
    - [ ] 调用未实现 instruct → 不崩溃

## 3. 测试

- [ ] 3.1 instruct 函数存在性测试
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] `rawget(_G,"instruct_27")` 为 function
    - [ ] `rawget(_G,"instruct_40")` 为 function
    - [ ] `rawget(_G,"instruct_67")` 为 function
