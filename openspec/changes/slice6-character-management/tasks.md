## 1. 主选单菜单入口（`menu` 命令替代原版 ESC 键）

- [x] 1.1 实现 MMAP/SMAP 状态的 `menu` 命令，显示主选单
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: `menu` 输出"主选单：1.状态 2.物品 3.武功 4.系统(存档) 0.返回"
- [x] 1.2 实现 `RoleMenu_handleChoose(n)` 路由到子功能
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: choose 1=状态 2=背包 3=队伍 4=存档
- [x] 1.3 在 `look` 末尾追加提示"输入 menu 打开主选单"
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: SMAP `look` 末尾显示提示，MMAP 不显示（原版 MMAP 无 ESC 菜单）

## 2. 角色状态查看

- [x] 2.1 显示主角 + 队员属性（等级/HP/MP/攻击/防御/轻功/资质/武功/装备）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 显示主角完整属性，包括武功列表和装备
- [x] 2.2 查看队员（`choose N` 选人查看）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 可通过菜单选择查看各队员状态

## 3. 背包管理

- [x] 3.1 显示背包物品列表（编号 + 名称 + 数量）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 显示背包中所有非空物品
- [x] 3.2 物品使用（选择物品 → 选择目标 → 使用）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 选择物品后可使用，药品恢复HP/MP，暗器可投掷
- [x] 3.3 装备/卸下
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 武器/防具类物品可装备到角色，可选择卸下

## 4. 队伍管理

- [x] 4.1 显示当前队伍成员列表
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 列出所有队员姓名/等级/HP/MP
- [x] 4.2 医疗/解毒（选择队员 → 消耗物品 → 恢复）
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 选择队员后可使用医疗/解毒物品，HP/中毒状态恢复

## 5. 存档/读档

- [x] 5.1 存档（槽位 1-3）
  Blast Radius: `["game/engine-web/state_manager.lua", "game/engine-web/mmap_smap_handlers.lua"]`
  DoD: 选择槽位后存档成功
- [x] 5.2 读档（槽位 1-3）
  Blast Radius: `["game/engine-web/state_manager.lua"]`
  DoD: 选择槽位后读档成功，回到游戏
- [x] 5.3 自动存档（场景切换时）
  Blast Radius: `["game/engine-web/state_manager.lua", "game/engine-web/web_game_bridge.lua"]`
  DoD: 进入/离开场景时自动保存到槽位 0

## 6. 测试

- [x] 6.1 E2E 测试：主选单显示（TC-06）
- [x] 6.2 E2E 测试：状态查看（TC-06）
- [x] 6.3 E2E 测试：背包查看（TC-06b）
- [x] 6.4 E2E 测试：存档/读档（TC-06b）
