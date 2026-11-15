# TODO — Future Slices & Ideas

> epic: `2026-11-mouse-input`
> 本文件跟踪**涌现的想法**，不是承诺。进入 slice 前先在这里分诊。

## 延后到鼠标 epic 之后

### 1. 触摸输入（love.touch）

当前全仓 `love.touch` 相关代码为 0。Android 上触摸屏完全不响应。
这是与鼠标**完全不同的输入通道**（多点、无 hover 状态、无右键），
需要独立 epic。

设计要点（待展开）：
- `EngineAPI.input.touchPoints()` → 多点坐标数组
- 触摸 → 按键的翻译层（虚拟摇杆/D-pad）
- 与鼠标开关的关系：两者互相独立，可同时开启

### 2. 虚拟按键 / 屏幕摇杆

Android 的主要输入方式。依赖触摸输入先完成。

### 3. 物理手柄

`conf.lua` 当前 `t.modules.joystick = false`。
LÖVE 有完整的 gamepad API（`love.gamepadpressed` / `love.joystick.setGamepadMapping`），
工作量小于虚拟按键。可作为触摸之外的独立选项。

### 4. 自绘鼠标指针图标

当前决定：**系统光标在所有模式下保留**。牺牲了视觉一致性换取零延迟与零边界问题。

如果将来要做，需要：
- `love.mouse.setVisible(false)` + 每帧 `drawTinted` 绘制指针
- 处理窗口失焦、移出窗口、Alt+Tab 等边界
- 接受一帧的输入延迟

### 5. 路径预览

需求明确说不需要。如果将来想加：
- 悬停时预计算路径（但这违反「不在 update 里寻路」）
- 或缓存上一次点击的路径用于显示

---

## 鼠标 epic 内部的后续优化

### 6. `menu_state_machine.lua` 拆分

slice 2 会往这个文件加鼠标命中测试，它会从 700+ 行继续增长。

潜在拆分：
```
  menu_state_machine.lua    状态 + 栈管理（核心）
  menu_input.lua            键盘 + 鼠标输入分发
  menu_render.lua           绘制（含值项/多行文本/宽度计算）
```

这不是 epic 内的事，但如果 slice 2 后超过 900 行，应该在下一个 change 里处理。

### 7. 鼠标事件与键盘事件的严格时序

ADR-MS-004 采用双队列，不保证跨队列的严格时序。
实际游戏中几乎不需要（不会出现「同一帧内既按键又点击」的常见场景）。

如果将来发现时序问题（比如「点击菜单项的同时按了 ESC」），
需要引入统一事件序列号。

### 8. 鼠标右键长按 / 双击

当前只处理单击。长按与双击需要计时器，收益不明确。

### 9. 战斗内鼠标操作

本 epic 明确排除。若要加：
- 战斗中点格子 = 移动/攻击目标（复用战斗已有的光标逻辑 `WAR.MoveCursorX/Y`）
- 战斗中右键 = 取消（等价于 ESC）
- 风险：战斗的坐标系统是 `War_XMax/War_YMax`，与地图不同

### 10. 鼠标显示的坐标提示

`CC.ShowXY == 1` 时会在屏幕底部显示主角坐标。
可考虑增加「鼠标所指格坐标」的显示，便于调试（生产环境应关闭）。

---

## 已否决的方向

### ✗ 用 `love.audio.setVolume` 做音量（历史记录）

见 `openspec/changes/audio-settings/design.md` ADR-AS-003。
它是全局音量，无法分离音乐/音效。

### ✗ 11 档音量百分比列表

见 `audio-settings` 的 ADR-AS-002。会让 22% 的按键看不到显示变化。

### ✗ 鼠标点击 = 直接传送

技术上最容易（不做寻路，直接改坐标），但破坏游戏体验：
玩家可以瞬移穿墙。明确否决。

### ✗ 在 update 循环里调用 A*

需求方明确要求「寻路算法肯定不能在渲染 update 中做」。
即使性能允许，也会造成每帧开销不可控。

---

## 待验证清单（进入 slice 前）

- [ ] macOS Retina 下 `love.mouse.getPosition()` 是否同样返回逻辑坐标
- [ ] Android 下 `love.mouse.getPosition()` 的行为（无鼠标时返回什么）
- [ ] 480×480 地图「点击被墙隔离区域」的 A* 最坏耗时实测
- [ ] `numShow` 滚动菜单（战斗的物品/武功菜单）的点击命中是否与
      `menu.start` 偏移一致
- [ ] `EngineAPI.sprite.drawTinted` 在 love2d 下的实际染色效果
      （`setColor` + `draw` 是否会产生预期颜色，还是需要 shader）
