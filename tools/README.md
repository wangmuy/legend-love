# tools/

开发辅助脚本（不属于游戏运行时，不被 game/ 代码 require）。
解码逻辑均与 `game/engine-love2d/lib_love.lua` 的对应实现保持一致，调查期一次性脚本已清理。

## 通用工具

### smap_tool.lua — grp 贴图提取与排查（纯 Lua）

idx 条目为图结束偏移（小端 u32），显示 picid → 图序号 `slot = floor(picid/2)`，
帧头 `w,h(u16) xoff,yoff(i16)`，RLE 逐行（trans/solid/调色板索引），
调色板 `mmap.col`（256×3 字节，0..63 → ×4）。

```bash
# 提取帧为 P6 PPM（真实调色板 RGB；--gray 输出调色板索引灰度，便于 diff）
lua tools/smap_tool.lua extract game/data <outdir> 6890 6932 4988 [--gray]

# 在 grp 偏移附近寻找有效帧头（排查 idx 映射时）
lua tools/smap_tool.lua scan game/data 1228382 [半径=400]

# 按偏移十六进制 dump
lua tools/smap_tool.lua hexdump game/data 1 3009849 [--len 32]

# 打印 idx 条目与帧头（slot 为 0-based 图序号 = 显示 picid/2）
lua tools/smap_tool.lua entries game/data 3445 3466
```

### sdata_tool.lua — 子场景 S*/D* 数据排查（纯 Lua）

直接读 base 模板数据 `allsin.grp`/`alldef.grp`，与 `LoadSMap/GetS/GetD` 索引公式一致：
S 每格 i16（level 3 = 事件层，≥0 表示该格挂着 D* 实体）；D 每实体 11 个 i16 字段。

```bash
# 单格: 6 层数据 + 邻域 level3 网格（半径可调）
lua tools/sdata_tool.lua tile game/data 70 19 20 [半径=2]

# 打印某个 D* 的全部或指定字段
lua tools/sdata_tool.lua dentity game/data 70 0 [字段i...]

# 列出场景内 level 值 >= min 的所有 tile
lua tools/sdata_tool.lua find game/data 70 [level=3] [min=0]
```

### scene_tool.lua — 子场景 S*/D* 数据排查（纯 Lua）

直接读 base 模板数据 `allsin.grp`/`alldef.grp`，与 `LoadSMap/GetS/GetD` 索引公式一致：
S 每格 i16（level 3 = 事件层，≥0 表示该格挂着 D* 实体）；D 每实体 11 个 i16 字段
（2/3/4 = 空格/物品/路过触发事件号，9/10 = 实体坐标）。

```bash
# 单格: S 层 0-5 值 + 挂接实体的全部 D 字段
lua tools/scene_tool.lua tile game/data 70 19 20

# 打印场景(或区域)某层 S 数据网格
lua tools/scene_tool.lua dump game/data 70 3
lua tools/scene_tool.lua dump game/data 70 3 17 18 23 22

# 列出场景全部有效 D* 实体（坐标/不可通过/三类触发事件号/动画帧范围）
lua tools/scene_tool.lua ents game/data 70

# 打印 ranger.grp 新游戏 base 段基础字段（乘船/人X/人方向/队伍...）
lua tools/scene_tool.lua base game/data
```

### render_frames.py — grp 帧渲染为 PNG（Python + Pillow）

任意前缀的 grp/idx 都能渲染（smap/mmap/fightNNN/wmap/thing...），
输出透明 PNG + 白底 `_white.png`，并打印不透明像素 bbox。

```bash
python3 tools/render_frames.py game/data <outdir> 6890 6932 4988          # smap 贴图
python3 tools/render_frames.py game/data <outdir> 1000 --prefix mmap      # 主地图贴图
python3 tools/render_frames.py game/data <outdir> 6890 --scale 4          # 放大 4 倍
```

> 无 Pillow 时可用 `smap_tool.lua extract` 出 PPM 再自行转 PNG。

### trace_global.lua — 游戏内全局状态时序追踪

在 game/ 代码的写点插入一行 `TRACE.log("tag")`，按帧时序记录目标全局变量快照，
用于定位"谁在什么时候改了 X"。启用配方见 `examples/trace_mypic_demo.lua`
（以追踪 JY.MyPic 的开场卧姿调查为例，3 步照抄即可用）。
`demo/trace_mypic_demo.lua` 是独立可运行示例（模拟开场时序，无需 Love2D/游戏数据）：

```bash
lua tools/demo/trace_mypic_demo.lua   # 输出并打印 tools/trace_out.txt
```

```lua
-- 需在 package.path 含仓库根目录: package.path = ... ";/path/to/legend-love/?.lua"
local TRACE = require "tools.trace_global"
TRACE.fields = {  -- 惰性求值，log 时调用
    MyPic = function() return JY.MyPic end,
    dir   = function() return JY.Base["人方向"] end,
}
TRACE.log("startNewGame:348")  -- 调用点
```

输出 `tools/trace_out.txt`（每次加载清空重记）；不受 CONFIG.Debug 控制，
调查完成后请移除调用点。

#### demo/trace_mypic_demo.lua — 可运行 demo

`lua tools/demo/trace_mypic_demo.lua`（任意目录，无需 Love2D / 游戏数据），
模拟开场卧姿调查的写点时序并打印 `tools/trace_out.txt` 输出，
用于快速验证 trace_global 工作方式；真实用法仍见上方启用配方。

## 输出物

- `tools/trace_out.txt`（trace_global）— 已 gitignore
- 提取/渲染输出目录建议放仓库外（如 `/tmp/frames`）；历史调查输出
  `tools/frames/`、`tools/frames2/` 已 gitignore
