## Context

SMAP 场景中的交互对象（NPC/物品/出口）需要通过统一菜单展示。`look` 输出编号列表，`choose N` 做二级选择。

## Decisions

### `SmapHandlers.look` 输出格式
```
1. <NPC名>
2. <物品名>
3. → <出口场景名>
...
输入 choose <编号> 选择交互对象
```

### `SmapHandlers.chooseInteraction(idx)`
- idx 从 `smapEntityList` 查找实体
- NPC → `CE.showMenu({对话, 查看, 给予物品})`
- 物品 → `CE.showMenu({拾取, 查看})`
- 出口 → `SmapHandlers.go({tostring(idx)})`

### `smapEntityList`
`mmap_smap_handlers.lua` 中的 local 表，`look` 时重建。

### 数据流
```
look → 从 scenes 数据读取 NPC/物品/出口 → 填充 smapEntityList → 输出编号
choose N → smapEntityList[N] → type=npc → showMenu → smapNpcTalk
                              → type=item → showMenu → smapTakeItem
                              → type=exit → SmapHandlers.go()
```

## Tests

- `look` 显示编号列表（程序化 SMAP 状态）
- `chooseInteraction` NPC/物品/出口路由
- choose N → 出口 → 无 gameLoop error

## Review Checklist

1. 所有单元测试通过
2. 无 gameLoop error
3. look 输出格式正确
4. choose N 不报错
