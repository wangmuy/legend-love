## 为什么

原版游戏按 ESC 打开主选单（系统/物品/武功/状态/存挡/读挡）。Web MUD 需要文字替代方案。

## What Changes

MMAP/SMAP 状态下添加 `menu` 命令，显示主选单。`look` 末尾提示 "输入 menu 打开主选单"。

## Scope Boundaries

### In Scope
- `menu` 命令在 MMAP/SMAP 注册
- 主选单：1.状态 2.物品 3.武功 4.系统(存档) 0.返回
- `look` 末尾提示入口

### Out of Scope
- 主选单的子功能（由子 change s6-role-status/s6-bag/s6-saveload 实现）
