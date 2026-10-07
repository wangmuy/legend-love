## Context

5 个功能性 instruct 函数在 jymain.lua 中有定义，但 Web MUD 的 save/restore 机制未保存它们（因为我们的桩函数从未注册过这些编号），导致 oldevent 脚本调用时报错。

## Decisions

### instruct_11 — 住宿询问

```lua
rawset(_G, "instruct_11", function()
    local w = rawget(_G, "WebUI")
    if w then w.write("是否住宿？") end
    local MenuAsync = rawget(_G, "MenuAsync")
    if MenuAsync then
        local ok = MenuAsync.ShowMenu2Coroutine({{"是", nil, 1}, {"否", nil, 2}}, 2, 0, 0, 0, 0, 0, 0, 1)
        if ok == 1 then
            instruct_12()
        end
    end
end)
```

### instruct_12 — 恢复体力

```lua
rawset(_G, "instruct_12", function()
    local p0 = rawget(_G, "JY").Person[0]
    p0["生命"] = p0["生命最大值"]
    p0["体力"] = 100
    p0["内力"] = p0["内力最大值"]
    local w = rawget(_G, "WebUI")
    if w then w.write("体力完全恢复了。") end
end)
```

### instruct_14 — 重绘场景

```lua
rawset(_G, "instruct_14", function()
    local sh = rawget(_G, "SmapHandlers")
    if sh and sh.look then sh.look({}) end
end)
```

### instruct_19 — 移动主角

```lua
rawset(_G, "instruct_19", function(x, y)
    local JY = rawget(_G, "JY")
    if JY then
        JY.Base["人X1"] = x
        JY.Base["人Y1"] = y
    end
end)
```

### instruct_31 — 物品/金钱检查

flag 0=检查是否有, 1=扣除, 2=获取。itemId=0 表示金钱。

```lua
rawset(_G, "instruct_31", function(itemId, count, flag)
    local JY = rawget(_G, "JY")
    if not JY then return -1 end
    JY.Base = JY.Base or {}
    if itemId == 0 then
        local money = JY.Base["金钱"] or 0
        if flag <= 0 then return (money >= count) and 1 or 0 end
        if flag == 1 then JY.Base["金钱"] = math.max(0, money - count); return 1 end
        JY.Base["金钱"] = (money or 0) + count; return 1
    end
    ...
end)
```

## Review Checklist

1. `instruct_11()` 显示"是否住宿？"菜单，选择"是"后调用 instruct_12
2. `instruct_12()` 恢复主角 HP/MP/体力到最大值
3. `instruct_14()` 调用 SmapHandlers.look 重绘场景
4. `instruct_19(10,20)` 设置 JY.Base["人X1"]=10, ["人Y1"]=20
5. `instruct_31(0,100,0)` 金钱 >= 100 返回 1
