## Context

WLove2D 版中住宿通过 `instruct_11()` 询问 → `instruct_12()` 恢复。Web MUD 需要 `rest` 命令覆盖这组交互。

## Decisions

### rest 命令逻辑

```
rest:
  场景类型 == "house" (主角的家) →
    instruct_12() → 满血满魔
    WebUI.write("你休息了一晚，体力完全恢复了。")
    
  场景有 NPC 事件指向 oldevent_235 (客栈住宿) →
    检查 JY.Base["金钱"] >= 100
    够 → instruct_32(174, -100) 扣钱
        instruct_12() 恢复
        不够 → "住一晚要100两，你钱不够。"
    
  其他场景 →
    "这里不是休息的地方。"
```

### 与 NPC 对话的关系

客栈住宿通过 NPC 对话触发（店小二 → 对话 → 客栈菜单 → "住宿"）。`rest` 命令是快捷方式，直接执行住宿逻辑。

## Review Checklist

1. `rest` 在 `house` 类型场景免费恢复
2. `rest` 在客栈场景检查金钱
3. 无 gameLoop error
