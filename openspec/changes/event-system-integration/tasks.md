## 1. 事件执行器加载
Traceability: [REQ-001]

- [ ] 1.1 在 `initWebFramework` 中加载 `event_executor`, `async_globals`, `script_loader`, `async_wrapper`
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `require("framework.event_executor")` 成功
    - [ ] `_G.EventExecutor` 全局表存在
    - [ ] `async_globals` 安装 `instruct_*` 替换函数

- [ ] 1.2 修复 `smapNpcTalk` 中 EventExecutor 调用
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] `EventExecutor.startEvent(eventId, 0, callback)` 成功执行
    - [ ] 事件回调后回到场景

## 2. instruct stubs
Traceability: [REQ-002]

- [ ] 2.1 常用 instruct 函数的 Web MUD 实现（P0）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_0()` ✅ 已有
    - [ ] `instruct_1()` ✅ 已有
    - [ ] `instruct_27()` no-op（动画不展示）
    - [ ] `instruct_40(dir)` 设置 `JY.Base["人方向"]`
    - [ ] `instruct_67(soundId)` no-op（音效不播放）
    - [ ] `instruct_3(...)` 更新场景事件数据

- [ ] 2.2 事件相关 instruct 函数（P1）
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `instruct_2(...)` 修改出入口
    - [ ] `instruct_13(...)` 菜单（MenuAsync 代理）
    - [ ] `instruct_32(...)` 给物品
    - [ ] `instruct_56(...)` 队伍管理

- [ ] 2.3 全部 67 个 instruct 的完整清单 + no-op 缺省
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] 调用未实现的 instruct → 不崩溃，输出 "[instruct_N 未实现]" 提示

## 3. D* 数据访问
Traceability: [REQ-003]

- [ ] 3.1 `GetD`/`SetD`/`GetS`/`SetS` 实现
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `GetD(sceneId, layer, x, y, field)` 从 dataCache.events 查找
    - [ ] 未找到时返回 0（非崩溃）
    - [ ] `GetS`/`SetS` 操作场景格子数据（Web MUD 中简化实现）

## 4. 测试
Traceability: [REQ-004]

- [ ] 4.1 TC-01: 软体娃娃对话
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] choose 1 → 主角的家 → look → choose 1(软体娃娃) → 对话
    - [ ] `instruct_1` 对话文本输出
    - [ ] `WaitKey` 后继续
    - [ ] 事件结束后回到场景
    - [ ] 无 gameLoop error

- [ ] 4.2 TC-02: 悦来客栈店小二
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 主角的家 → leave → MMAP → list → 选择悦来客栈
    - [ ] look → 找到店小二 → 对话 → 事件执行
    - [ ] 无 gameLoop error

- [ ] 4.3 TC-03: 南贤对话
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] MMAP → list → 南贤居 → 进入 → 找南贤 → 对话
    - [ ] 无 gameLoop error

- [ ] 4.4 TC-04: 泛化 oldevent 执行测试
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 随机选取 5 个 oldevent 脚本
    - [ ] 通过 `luaEval` 直接加载执行
    - [ ] 验证不崩溃
