## 1. rest 命令实现
Traceability: [REQ-001]

- [x] 1.1 注册 `rest` 到 SMAP 命令表
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] SMAP help 显示 rest
    - [x] help 描述包含"休息恢复体力"

- [x] 1.2 `SmapHandlers.rest` 实现
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] house 类型场景 → 免费恢复 + 输出提示
    - [x] 客栈场景 + 有足够金钱 → 扣钱 + 恢复
    - [x] 客栈场景 + 金钱不足 → 提示
    - [x] 其他场景 → "这里不是休息的地方"

## 2. 测试

- [x] 2.1 单元测试: rest 命令注册（help 显示）
  Blast Radius: `["game/engine-web/tests/mmap-smap.spec.js"]`
  DoD:
    - [x] 程序化设置 SMAP 状态 → help → 包含 rest
