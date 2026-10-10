# tools/

开发辅助脚本（不属于游戏运行时，不被 game/ 代码 require）。

## 通用工具

### smap_tool.lua — grp 贴图提取与排查

解码逻辑与 `game/engine-love2d/lib_love.lua` 的 `LoadPic`/`PicLoadFile` 完全一致：
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

### trace_global.lua — 游戏内全局状态时序追踪

在 game/ 代码的写点插入一行 `TRACE.log("tag")`，按帧时序记录目标全局变量快照，
用于定位"谁在什么时候改了 X"（通用化自开场卧姿调查的 diag_mypic）。

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

## 一次性调查脚本（2026-10 开场卧姿 bug 调查产物，待清理）

`check_scene70_tile.lua`（allsin 场景 S 层数据）、`diag_smap_hdr.lua`、
`diag_smap_idx.lua`、`idx_check.lua`/`idx_check.py`（idx 映射假设验证）、
`extract_frame_v2.lua`/`extract_smap_frames.lua`（早期提取版）、
`render_frame.py`/`render_smap_frames.lua`（早期渲染版）、`scan_smap_hdr.lua`
——功能已并入 `smap_tool.lua`；`frames/`、`frames2/` 为上述脚本的输出目录。
