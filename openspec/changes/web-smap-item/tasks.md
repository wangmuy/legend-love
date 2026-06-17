## 1. take 命令实现
Traceability: [REQ-002]

- [ ] 1.1 注册 `take <物品名>` 命令到 SMAP 状态
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] SMAP 命令表中包含 `take` 条目

- [ ] 1.2 实现场景物品查找和拾取
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 根据当前场景查找物品列表
    - [ ] 按名称匹配物品
    - [ ] 检查 sceneState 中物品是否可用
    - [ ] 物品加入背包（JY.Base["物品N"]）
    - [ ] sceneState 标记为已拾取
    - [ ] 输出 "你获得了 xxx"

- [ ] 1.3 实现找不到物品时的提示
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 物品不存在时输出 "这里没有 xxx"

## 2. give 命令实现
Traceability: [REQ-003]

- [ ] 2.1 注册 `give <物品名> <人名>` 命令到 SMAP 状态
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] SMAP 命令表中包含 `give` 条目

- [ ] 2.2 实现物品给予逻辑
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 检查背包中是否有该物品
    - [ ] 检查 NPC 是否在场景中
    - [ ] 从背包移除物品
    - [ ] 输出 "你将 xxx 交给了 yyy"

## 3. look <目标> 实现
Traceability: [REQ-004]

- [ ] 3.1 实现有参 look（查看具体对象）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] `look xxx` 在场景 NPC 中查找匹配
    - [ ] `look xxx` 在场景物品中查找匹配
    - [ ] 输出对象描述

## 4. 测试
Traceability: [REQ-002, REQ-003, REQ-004]

- [ ] 4.1 E2E 测试：take 命令拾取物品
- [ ] 4.2 E2E 测试：give 命令给予物品
- [ ] 4.3 E2E 测试：look 查看具体对象
