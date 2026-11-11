## 1. TC-01: 软体娃娃对话

- [x] 1.1 对话流程测试
  DoD:
    - [x] choose 1 → choose 1 → 进入主角的家
    - [x] look → 显示 "1. 软体娃娃"
    - [x] talk 软体娃娃 → 对话启动
    - [x] 事件结束后回到场景
    - [x] 无 gameLoop error

## 2. TC-02: 悦来客栈

- [x] 2.1 店小二对话
  DoD:
    - [x] 离开主角的家 → MMAP
    - [x] list → 悦来客栈 → 进入
    - [x] talk oldevent_235 → 对话
    - [x] 无 gameLoop error

## 3. TC-03: 南贤

- [x] 3.1 南贤对话
  DoD:
    - [x] MMAP → list → 南贤居 → 进入
    - [x] talk 南贤 → 对话
    - [x] 无 gameLoop error

## 4. TC-04: 泛化 oldevent 测试

- [x] 4.1 随机 oldevent 执行
  DoD:
    - [x] 5 个随机 oldevent 脚本直接加载执行
    - [x] 不崩溃
