## Context

原版 ESC 主菜单在 Web MUD 中由 `menu` 命令替代。

## Decisions

### `menu` 命令
- MMAP/SMAP 状态均可使用
- 设置 `roleMenuPhase = "main"`，后续 `choose N` 由 `RoleMenu_handleChoose` 路由

### 与原版差异
- 原版 ESC 返回游戏环境；`menu` 为命令输入后显示菜单
- 原版 5 选项（系统/物品/武功/状态/存挡）；Web 版合并系统+存档，保留 4 选项
  
## Review Checklist

1. `menu` 在 MMAP 可用
2. `menu` 在 SMAP 可用
3. `look` 末尾显示提示
