# Change Manifest — 角色管理与完整体验 (Slice 6)

## 依赖顺序

```
slice6-character-management (角色管理)
  │
  ├── s6-role-menu       (角色管理菜单入口)
  ├── s6-role-status     (角色状态查看)
  ├── s6-bag             (背包管理)
  ├── s6-team            (队伍管理)
  └── s6-saveload        (存档/读档)
```

## 设计决策

- 全部采用菜单驱动交互，与 Slice 4/5 一致
- 不引入新的直接命令
- `look` 输出扩展附加菜单
- 存档使用 IndexedDB，兼容现有 state_manager.lua
- 背包/队伍/存档均为 `look` 后的子菜单
