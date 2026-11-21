# 战斗实机截图

由 `main.lua` 的调试参数自动生成（battle-extensibility 验收）：

```bash
# 战斗开始画面
lovec game --shot=battle --frame=250 --battle=4

# 完整战斗（失败结算）
lovec game --shot=s3 --frame=1400 --battle=4 \
      --keys=return,return,down,down,down,down,down,down,return
```

截图落在 LÖVE 的 save 目录：
`%APPDATA%/LOVE/wangmuy.love2d.jygame/`

## 文件

| 文件 | 内容 | 证明了什么 |
|------|------|-----------|
| `battle-start.png` | 战斗地图 + 9 项战斗菜单 + 双方人物 + 头像血条 | 战斗初始化 + 绘制链全部正确 |
| `battle-settlement-failure.png` | 「战斗失败」提示框 + 回主地图 | 战斗能跑到结束判定 + 结算 + 失败语义 |

**为什么这两张重要**：这两张是唯一"自动化替代不了"的验证，
它们暴露了 5 个只在实机可见的回归（见 commit `ebf81ac` / `508da14`）：

1. 协程搬到 `script/battle/` 后成了 nil upvalue（战斗一开就崩）
2. `lib_love.lua` 的 `PicLoadCache` 少写 `local`（历史遗留）
3. `SpriteAtlas` 与 `lib.PicFileCache` 两套贴图系统不互通
4. `--keys` 传数字是空操作（我的调试工具坏了）
5. `PicGetXY` 只判一层空（历史遗留）

## map-render-native 迁移的三张基线图（port-map-render-native Task 7）

这三张图是**契约透明化**的验收基准。C 完成后的判定方式：
用同样的参数重新截图，**md5 必须完全相同**。

| 文件 | 界面 | 截图参数 | md5 |
|------|------|---------|-----|
| `battle-start.png` | 战斗（胡斐 vs 敌人） | `--shot=… --frame=250 --battle=4` | `6c8eb32217839a7c6c30eed8ed9c6be5` |
| `scene-intro-house.png` | 开场对话（主角家） | `--shot=… --frame=1400 --keys=return,down,return,return,space,space,space,space,space` | `1efd2af3a9ecfce48b89ef14b9a14338` |
| `main-map-after-walk.png` | 对话推进后（**有云层**） | `--shot=… --frame=2000 --keys=…（见上）+space×8` | ⚠️ **不稳定**，当前存档为 `a83715fe…`（见下） |

### ⚠️ 主地图的 md5 **不稳定**：云层是随机的

`lib.CloudCreateOnSide` 用 `math.random` 生成 60 朵云的
`Picnum` / `Positionx` / `Positiony` / `Alpha` / `mixR/G/B`（`lib_love.lua:1265-1287`）：

```lua
c.Picnum   = math.random(0, cloudPicAmount - 1)
c.Alpha    = 10 + math.random(0, 49)
c.Positionx = math.random(0, CLOUD_WORLD_X - 1)
```

而且 `JYMainAdapter.init` 里有 `math.randomseed(os.time())` —— **每次启动不同**。

⇒ **主地图不能用 md5 当基线**。它的正确验证方式是：

1. **目视**：地图/建筑/主角全部正常渲染（截图作为记录，不是基线）
2. **场景与战斗的 md5**：这两个界面无云层，md5 稳定，是硬判据

（我一度把某次随机的主地图 md5 写成基线，改 `CloudLoadAndInit` 时
md5 变了就误以为有回归 —— 实际只是云的随机位置不同。）

### 为什么这三张

`lib.DrawMMap` / `DrawSMap` / `DrawWarMap` 是三个独立的绘制函数，
各有各的投影参数（`MMapAddX/Y`、`SMapAddX/Y`、`WMapAddX/Y`）。
三个界面各覆盖一个，缺一张就有一个函数没被实机验证。

### 为什么必须是 md5 而不是"看起来对"

等距投影的坐标是整数运算，**错一位整张图就偏**。肉眼看"好像差不多"，
md5 能精确抓到 1 像素的偏移。

⚠️ **不要用 `--shot` 之外的自动化方式来"验证"这三张图**：
`test_map_render.lua` 的单测覆盖的是**调用语义**（画了哪些 frameId / flags），
不是**像素结果**。地图全黑时那 81 条断言**照样全绿**（实测踩过）。
