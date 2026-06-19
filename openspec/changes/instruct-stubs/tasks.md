## 1. P0 常用 instruct 实现
Traceability: [REQ-002]

- [x] 1.1 P0 函数（oldevent_691 使用）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `instruct_27()` no-op 不崩溃
    - [x] `instruct_40(dir)` 设置 JY.Base["人方向"]
    - [x] `instruct_67()` no-op 不崩溃
    - [x] `instruct_3(...)` no-op 不崩溃

## 2. P1-P2 覆盖

- [x] 2.1 P1 函数
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `instruct_2(...)` no-op 不崩溃
    - [x] `instruct_13(...)` no-op 不崩溃
    - [x] `instruct_32(...)` no-op 不崩溃
    - [x] `instruct_56(...)` no-op 不崩溃

- [x] 2.2 全部 67 个函数的兜底 handler
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 循环注册未定义函数，输出 debug.log
    - [x] 调用未实现 instruct → 不崩溃
