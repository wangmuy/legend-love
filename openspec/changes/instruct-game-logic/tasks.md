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

- [x] 1.3 `instruct_14` 重绘场景
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 调用 SmapHandlers.look({})

- [x] 1.4 `instruct_19` 移动主角
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 设置 JY.Base["人X1"] / ["人Y1"]

- [x] 1.5 `instruct_31` 物品/金钱检查
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] flag=0: 检查 / flag=1: 扣除 / flag=2: 增加

## 2. 测试

- [x] 2.1 instruct_12 函数存在
- [x] 2.2 instruct_14 不抛异常
- [x] 2.3 instruct_19 移动主角
- [x] 2.4 instruct_31 金钱检查/扣除
- [x] 2.5 剩余 instruct 存在性（26/37/56）
- [x] 2.6 instruct_11 函数存在
