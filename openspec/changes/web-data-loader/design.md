## 设计

### 数据加载流程

```
1. JS fetch("data-web/dialogues.json")
     → 得到 JSON 字符串
     → 传入 Lua: data_loader.load("dialogues", jsonString)

2. Lua data_loader.lua:
     local jsonData = parseJSON(jsonString)  -- 用 Lua 解析
     _G.dataCache["dialogues"] = jsonData.dialogues
     _G.dataCache["dialogues_total"] = jsonData.total

3. 重复 7 次（每个 JSON 文件一次）

4. 加载完成后:
     _G.dataCache["_loaded"] = true
     _G.dataCache["_fileCount"] = 7
     _G.dataCache["_totalSize"] = 676077
```

### JSON 解析

Fengari 没有内置 JSON 解析器。有两种选择：

**方案 A：Lua 侧实现 JSON 解析器**
- 实现一个简单的 JSON 解析器（递归下降，处理 string/number/boolean/array/object）
- 足够解析已知结构的 JSON 数据
- 不需要依赖
- 不处理所有 JSON 边缘情况（如转义序列、科学计数法）

**方案 B：JS 侧解析后传表**
- JS 用 `JSON.parse()` 解析
- 通过 Fengari 的 JS 互操作接口传入 Lua
- 更可靠，但依赖 Fengari JS 互操作

采用**方案 A**：纯 Lua 解析器，避免 JS 互操作的复杂性。

### 加载到 Lua 表的映射

```lua
-- data_loader.lua

_G.dataCache = {}

function loadFromJSON(cacheKey, jsonStr)
    local ok, data = pcall(parseJSON, jsonStr)
    if not ok then
        _G.dataCache[cacheKey] = nil
        return false, data  -- error message
    end
    _G.dataCache[cacheKey] = data
    return true
end

function getTotalSize()
    local total = 0
    for _, name in ipairs{
        "dialogues", "scenes", "chars",
        "items", "skills", "entrances", "wmap"
    } do
        local path = "data-web/" .. name .. ".json"
        -- 从 dataCache 获取，或由 JS 预先计算传入
    end
    return total
end
```

### 最小 JSON 解析器

```lua
function parseJSON(str)
    local pos = 1
    local function skipWS()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
                pos = pos + 1
            else break end
        end
    end
    local function parseValue()
        skipWS()
        local c = str:sub(pos, pos)
        if c == '"' then return parseString()
        elseif c == '{' then return parseObject()
        elseif c == '[' then return parseArray()
        elseif c == 't' or c == 'f' then return parseBoolean()
        elseif c == 'n' then pos = pos + 4; return nil
        else return parseNumber() end
    end
    -- ... 实现 parseString, parseObject, parseArray, parseBoolean, parseNumber
    local result = parseValue()
    skipWS()
    return result
end
```

## 验证

- 加载 dialogue.json → 2977 条记录正确
- 加载 chars.json → 320 个人物正确
- 跨文件引用检查（scene NPC ID → chars 表中有对应记录）