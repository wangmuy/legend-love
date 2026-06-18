## 1. TC-01: 软体娃娃对话
Traceability: [REQ-004]

- [ ] 1.1 对话流程测试
  Blast Radius: `["game/engine-web/tests/event-flow.spec.js"]`
  DoD:
    - [ ] choose 1 → choose 1 → 进入主角的家
    - [ ] look → 显示 "1. 软体娃娃"
    - [ ] choose 1 → 软体娃娃 → 对话 → `instruct_1` 输出文本
    - [ ] `WaitKey` 后继续
    - [ ] 事件结束后回到场景
    - [ ] 无 gameLoop error

## 2. TC-02: 悦来客栈

- [ ] 2.1 店小二对话
  Blast Radius: `["game/engine-web/tests/event-flow.spec.js"]`
  DoD:
    - [ ] 离开主角的家 → MMAP
    - [ ] list → 悦来客栈 → 进入
    - [ ] look → 找到店小二 → 对话
    - [ ] 无 gameLoop error

## 3. TC-03: 南贤

- [ ] 3.1 南贤对话
  Blast Radius: `["game/engine-web/tests/event-flow.spec.js"]`
  DoD:
    - [ ] MMAP → list → 南贤居 → 进入
    - [ ] 南贤 → 对话
    - [ ] 无 gameLoop error

## 4. TC-04: 泛化 oldevent 测试

- [ ] 4.1 随机 oldevent 执行
  Blast Radius: `["game/engine-web/tests/event-flow.spec.js"]`
  DoD:
    - [ ] 5 个随机 oldevent 脚本直接加载执行
    - [ ] 不崩溃
