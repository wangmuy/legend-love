## mmap 数据格式

mmap.grp 存储大地图的瓦片数据。每个瓦片 2 字节（int16），
其中某些特殊值表示"场景入口"：

- 瓦片值 ≥ NNN：标记为场景入口
- 入口索引 → 通过查找表映射到场景 ID

## 输出格式

```json
{
  "version": "1.0",
  "extracted": "2026-06-07",
  "total": 200,
  "entrances": [
    { "mapX": 280, "mapY": 230, "sceneId": 70 },
    { "mapX": 140, "mapY": 110, "sceneId": 12 }
  ]
}
```

## 用途

在 Slice 3（大地图漫游）中，`go <场景名>` 命令通过 entrances.json
查找场景在大地图上的入口坐标，如果玩家在大地图上，则加载该场景。