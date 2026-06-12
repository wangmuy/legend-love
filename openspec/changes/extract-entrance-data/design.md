## 入口数据来源

大地图入口坐标来自 `data/ranger.grp` 中 Scene_S 结构体的 `外景入口X1/Y1`（偏移 30-32）和 `外景入口X2/Y2`（偏移 34-36）字段。

入口不来自 `mmap.grp`——mmap.grp 及其 idx 是瓦片图形数据文件（RLE/PNG 编码），不包含入口编码信息。大地图网格数据存储在 `earth.002`/`surface.002`/`building.002` 等文件中，且这些只是纯地形/建筑物网格值（每个格子的贴图编号），不编码入口映射。

游戏运行时通过 `Cal_EnterSceneXY()` 函数从 `JY.Scene[id]["外景入口X1/Y1"]` 构建入口查找表。

## 提取逻辑

```
读取 ranger.grp 的 Scene_S 段（62 字节/条 × 84 条）：
  对每个场景 i:
    读取 外景入口X1 (偏移 30), 外景入口Y1 (偏移 32)
    若 > 0 → 记录 {sceneId, name, mapX, mapY}
    读取 外景入口X2 (偏移 34), 外景入口Y2 (偏移 36)
    若 > 0 且与 X1/Y1 不同 → 记录 {sceneId, name, mapX, mapY}
## 输出格式

```json
{
  "version": "1.0",
  "extracted": "2026-06-07",
  "total": 84,
  "entrances": [
    { "sceneId": 70, "mapX": 357, "mapY": 235, "name": "河洛客栈" }
  ]
}
```

## 用途

在 Slice 3（大地图漫游）中，`go <场景名>` 命令通过 entrances.json
查找场景在大地图上的入口坐标，实现场景间传送。