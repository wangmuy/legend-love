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

## 界面基线第二批（port-ui-screens-verification，2026-11-21 实机捕获）

`engine-portability` 收尾时记「物品栏 / 人物状态 / 存档界面在事件驱动下不可达」。
**实测：三个里两个可达，一个需在主地图。** 下面三张是能直接复现的基线。

### 复现步骤（本轮实测命令）

```bash
# 共同前缀：开始菜单 → 新游戏 → 属性确认 → 推进开场对话
PREFIX="return,down,return,return,$(for i in $(seq 1 120); do printf 'space,'; done)"

# ① 物品菜单（6 项分类）
lovec game --shot=item-menu --frame=5500 --keys=${PREFIX%,},escape,down,down,return

# ② 物品格（名称/说明/3×N 格/页码）—— 上一步仲裁「全部物品」再按一次 return
lovec game --shot=item-grid --frame=5500 --keys=${PREFIX%,},escape,down,down,return,return

# ③ 人物状态（两列属性 + 头像）
lovec game --shot=person-status --frame=5600       --keys=${PREFIX%,},escape,down,down,down,return,return
```

截图落在 `%APPDATA%/LOVE/wangmuy.love2d.jygame/`。

| 文件 | 界面 | 判据类型 | md5（参考值，仅记录） |
|------|------|---------|---------------------|
| `item-menu.png` | 物品 6 项分类菜单 | **逐字节稳定**（无随机数） | `24635ea94a486c75ee73213e82ee3616` |
| `item-grid.png` | 物品格 + 名称/说明 + 页码 | **依赖存档**（物品来自新档：醉生梦死酒 ×3） | `07d2ff05ac7621d0edaaebf3330626d9` |
| `person-status.png` | 人物状态两列属性 + 头像 | ⚠️ **不稳定**（属性由 `Rnd()` 生成） | `820b2708237bbb0180228f68b1795514` |

### 判据分类（第三列的含义）

| 类型 | 含义 | 可用的验证方式 |
|------|------|---------------|
| 逐字节稳定 | 无随机数、无存档依赖 | **md5 必须相同**（硬判据） |
| 依赖存档 | 内容来自固定新档 | md5 相同（前提：同一新档、同一路径） |
| 不稳定 | 有随机数（云、属性、掉落） | **只能目视 + 结构断言**，md5 仅作记录 |

`person-status.png` 的属性值（内力/攻击/轻功/防御…）来自
`generateRandomAttributes()` 的 `Rnd()`，每次开局不同 →
**不能当 md5 基线**，只能断言「有框、有两列、有头像、有底部提示」。
（与主地图同一类问题，见上面「主地图的 md5 不稳定」小节。）

### 存档界面：必须在主地图（已捕获）

主菜单的「系统」项在 `GAME_SMAP` 下被置灰（**原版行为**，
`framework/jymain_async.lua:47-48` 与 `script/jymain.lua:770-773` 逐字一致）：

```lua
if JY.Status == GAME_SMAP then
    menu[5][3] = 0     -- 离队
    menu[6][3] = 0     -- 系统 ← 存档入口在这里
end
```

⇒ 在开场小场景里怎么按键都到不了存档界面。要验证必须先**回主地图**。

**加了调试入口 `--mmap=<x>,<y>`**（`main.lua`，仅调试用）：走
`LoadRecord(0)` → 改主角坐标 → 切 `GAME_MMAP`，并先清掉启动菜单协程
（否则 `showStartMenuCoroutine` 的菜单会和后续注入按键「抢」同一个按键，
实测表现为「按 6 次 down + return 却落在读取进度」）。

| 文件 | 界面 | 判据类型 | 复现命令 |
|------|------|---------|---------|
| `save-menu.png` | 主地图上的「保存进度」三槽菜单 | ⚠️ **不稳定**（背景是主地图，含随机云） | `lovec game --shot=save-menu --frame=1200 --mmap=150,150 --keys=escape,down,down,down,down,down,return,down,return` |

**⚠️ 判据更正（2026-11-22 实测）**：最初把这张图标成「逐字节稳定」是**错的**。
保存菜单画在主地图之上，而主地图每帧**随机生成云**：

```lua
-- game/framework/cloud_layer.lua:245-247
c.Picnum = (picAmount > 0) and math.random(0, picAmount - 1) or 0
c.Alpha  = 10 + math.random(0, 49)
c.mixR   = math.random(0, 255)
```

连拍两次实测 md5 不同（`af65113e…` / `3ccdacef…`）。
**只能目视 + 结构断言**（三个「进度一/二/三」槽 + 高亮框 + 位置正确），
md5 仅作记录。这与「主地图 md5 不稳定」是同一个根因。

> 顺带还有一个**与引擎无关但会影响判据**的因素：`--mmap` 的坐标决定了
> 背景是山还是海（不同坐标画出的地形完全不同）。所以即使关掉云，
> 「md5 相同」的前提也只能是**同一坐标 + 同一按键序列**。
