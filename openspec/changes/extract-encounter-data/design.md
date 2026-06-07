## 战斗地图数据

战斗地图数据存储了所有战斗场景的瓦片布局。
文字版不需要瓦片数据，但需要战斗地图的编号和名称索引。

## 遇敌配置

遇敌配置定义了：
- 大地图哪些区域会遇到哪些敌人
- 场景内哪些位置会遇到敌人
- 遇敌概率

## 输出格式

```json
{
  "version": "1.0",
  "extracted": "2026-06-07",
  "maps": [
    { "id": 1, "name": "悦来客栈外", "width": 25, "height": 25 }
  ],
  "encounters": [
    {
      "type": "scene_enter",
      "sceneId": 1,
      "enemies": [{"id": 50, "count": 2}],
      "probability": 30
    },
    {
      "type": "map_region",
      "mapX1": 100, "mapY1": 100,
      "mapX2": 200, "mapY2": 200,
      "enemies": [{"id": 30, "count": 1}],
      "probability": 20
    }
  ]
}
```

## 用途

在 Slice 5（战斗系统）中，玩家进入场景或在大地图移动时，
根据 encouters 配置决定是否遇敌和遇到什么敌人。