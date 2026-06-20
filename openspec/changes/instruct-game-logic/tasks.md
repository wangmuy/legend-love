## 1. 功能性 instruct 实现
Traceability: [REQ-001]

- [x] 1.1 `instruct_11` 住宿询问
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 显示"是否住宿？"菜单（是/否）
    - [x] 选择"是"→ 调用 instruct_12
    - [x] 选择"否"→ 不操作

- [x] 1.2 `instruct_12` 恢复体力
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 生命恢复至生命最大值
    - [x] 体力恢复至 100
    - [x] 内力恢复至内力最大值
    - [x] 输出"体力完全恢复了。"

- [x] 1.3 `instruct_14` 重绘场景
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 调用 SmapHandlers.look({}) 刷新场景描述

- [x] 1.4 `instruct_19` 移动主角
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 设置 JY.Base["人X1"] = x
    - [x] 设置 JY.Base["人Y1"] = y

- [x] 1.5 `instruct_31` 物品/金钱检查
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] itemId=0 时操作金钱
    - [x] flag=0: 检查是否有足够数量，返回 1/0
    - [x] flag=1: 扣除数量
    - [x] flag=2: 增加数量

## 2. 测试

- [x] 2.1 instruct_12 函数存在
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] type(instruct_12) == 'function'

- [x] 2.2 instruct_14 不抛异常
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] instruct_14() → 不崩溃

- [x] 2.3 instruct_19 移动主角
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] instruct_19(33,44) → JY.Base["人X1"] = 33

- [x] 2.4 instruct_31 金钱检查/扣除
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] 金钱 200 → flag=0 count=100 → 返回 1
    - [x] 金钱 200 → flag=1 count=100 → 金钱变 100
    - [x] 金钱 50 → flag=0 count=100 → 返回 0
