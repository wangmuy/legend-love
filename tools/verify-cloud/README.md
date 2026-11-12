# verify-cloud —— 主地图飘云子系统运行时取证

云子系统（`game/engine-love2d/lib_love.lua` 的 `Cloud*` / `DrawClouds`）的
单元测试只能锁住「公式与状态机」，锁不住「真实 LÖVE 下到底画没画、画在哪、
和地形一起滚没滚」。本目录是这三件事的可复现取证脚本。

> 单元测试在 `game/tests/unit/test_cloud.lua`（61 项，含
> `testCloudScrollMatchesTerrain`），跑：`cd game && lua tests/test_runner.lua cloud`。

## 一键运行

```bash
bash tools/verify-cloud/run.sh probe    # 单帧截图：云在地形/建筑之上
bash tools/verify-cloud/run.sh e2e      # 真实启动链：漂移 / MMAPAMI 门控 / 云在主角之上
bash tools/verify-cloud/run.sh scroll   # 云与地形滚动一致性（含像素分析）
bash tools/verify-cloud/run.sh all
```

依赖：LÖVE 11.x、`DISPLAY` 可用、`scroll` 的像素分析需 `python3` + `Pillow`。

`run.sh` 按 `$LOVE` → `PATH` 里的 `love`/`love2d` → 常见安装位置
（`$HOME/bin/love.AppImage`、`/usr/bin/love`、`/snap/bin/love` 等）依次探测
LÖVE 可执行文件，也可显式指定：

```bash
LOVE=/path/to/love bash tools/verify-cloud/run.sh probe
```

## 为什么不在目录里放软链

三个驱动都是「独立 LÖVE 工程」，需要把 `game/` 的 `data/ pic/ sound/ script/
framework/ engine-love2d/` 摆在项目根。历史做法是在目录里放
`data -> ../../data` 之类的相对软链，但有两个坑：

1. `tools/build-love.sh` 与 CI 都用 `7z a ./game/* -xr!.gitkeep` 打包，
   **7z 会跟随软链**。实测把带软链的 scratch 目录留在 `game/tests/` 下，
   `.love` 会从 31M 膨胀到 809M（data 39M + sound 21M + script 5.4M 被重复打
   包成 4000+ 条目）。
2. 软链路径写死为相对位置，目录一移动就断。

因此 `run.sh` 改为运行时 `mktemp -d` 建工作目录，现场软链 + 拷贝
`main.lua`/`conf.lua` 进去，跑完自动清理。仓库里只有纯文本。

## 三个驱动

### probe/ —— 云确实被画出来、且压在建筑之上

云世界 17280×8640 远大于 1024×768 视口，随机分布时屏幕内平均不到 1 朵
（实测约 0.39 朵/屏），截图大概率是空的。所以本驱动先反解 `DrawClouds` 的
坐标公式，把前 4 朵云强制摆到屏幕固定位置（150,150）/（450,320）/
（700,480）/（320,620），再截一帧。

`PROBE_MODE` 可选：`nocloud`（清空每朵云的 `img` → 只有地形建筑，做基线）、
`static`（默认，`MMAPAMI=0` 静止）、`moved`（`MMAPAMI=1` 且推进 1.5s 的
40ms tick）。固定随机种子，三次运行噪点相同，可像素级对拍。

```bash
PROBE_MODE=nocloud bash tools/verify-cloud/run.sh probe
```

产物：`~/.local/share/love/cloud_probe/cloud_probe_<mode>.png`

### e2e/ —— 真实启动链 + 漂移 + 门控 + 云在主角之上

走真实启动路径 `JYMainAdapter.init() → LoadRecord(0) → ChangeMMap →
switchState(GAME_MMAP)`，即 `GAME_MMAP.enter → Init_MMap →
CloudLoadAndInit`（真实 `cloud.idx/grp`）、`GAME_MMAP.update → lib.CloudTick`、
`GAME_MMAP.draw → lib.DrawMMap → DrawClouds`。

依次截 7 张：

| 截图 | 证明什么 |
|------|----------|
| `A_clouds1` / `B_clouds2` | 相隔若干秒，云位置不同 ⇒ 40ms 漂移在跑 |
| `C_frozen` | `CC.MMapAmi=0` 后再截，云冻结不消失 |
| `D_with_clouds` / `E_without_clouds` | 只把云 `img` 置空，差集即云层像素 |
| `F_cloud_over_player` / `G_player_no_cloud` | 把一朵云摆到主角 (507,340)-(522,379) 上方，证明云层在人物之上 |

```bash
bash tools/verify-cloud/run.sh e2e
```

产物：`~/.local/share/love/cloud_e2e/{A..G}_*.png`

### scroll/ —— 云与地形同步滚动（回归取证）

历史 bug：主角按 ← / → 走一格时地形正常沿等距轴滚动，云却朝反方向横移
（`DrawClouds` 的 x 公式把 kys 的 `+18*(Mx-My)` 玩家项照抄，而本项目的等距
投影是它的水平镜像 `-18*(mx-my)`）。修复见 commit `82d2dd2`。

驱动冻结云自身漂移（`CC.MMapAmi=0`），只改「相机滚动」这一个变量，逐方向
走一格，每个位置截「有云 / 无云」两张。

`analyze.py` 的读数方法：

* 云像素位移 = 两组 `|with - without|` 的 bbox 左上角之差；
* 地形像素位移 = 刚体平移估计，先用中心区域的行/列均值曲线做互相关求
  `(dx,dy)`（毫秒级），再用全图差集算残差复核（残差 > 12 视为估计不可信）。

判定：云位移必须与地形位移完全相等。

```bash
bash tools/verify-cloud/run.sh scroll
# 或只重跑分析（截图已存在）
python3 tools/verify-cloud/scroll/analyze.py
```

修复后的预期输出：

```
按→ 主角 X+1        地形 d=(-18,-9) 云 d=(-18,-9) 残差=0.1  OK（云与地形同步滚动）
按↓ 主角 Y+1        地形 d=(+18,-9) 云 d=(+18,-9) 残差=0.1  OK（云与地形同步滚动）
按← 主角 X-1        地形 d=(+18,+9) 云 d=(+18,+9) 残差=0.1  OK（云与地形同步滚动）
结论：云与地形滚动一致，无耦合偏移
```

把 `lib_love.lua` 的 x 公式改回 bug 版（`+mx*18 - my*18`），重跑会得到
`地形 (-18,-9) / 云 (+18,-9)` 的 `MISMATCH` —— 这就是负向对照。

产物：`~/.local/share/love/cloud_scroll/sc_<p{i}_with|p{i}_without>.png`

## evidence/ —— 静态证据

`probe_cloud_frames.png` 是 `cloud.grp` 9 帧 RLE 解码 + `mixColor/mixAlpha`
调色后的接触表；`probe_cloud_scene.png` 是按原版合成公式
`pix=(alpha*bg+(100-alpha)*pix)/100` 拼出来的场景图。两者在
`a60eccc`（云子系统移植）时随代码一起提交，用于人工核对取色正确性。

## 相关文档

- 手动测试（怎么在真机上肉眼看到云）：`TESTING.md` 的「手动验证：主地图飘云」一节
- 云子系统移植与符号修复的来龙去脉：`git log a60eccc 82d2dd2`
