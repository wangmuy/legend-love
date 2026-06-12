## 设计

### 数据加载流程

```
1. JS fetch("data-web/dialogues.json")
     → 得到 JSON 字符串
     → events.json (3.5MB): 使用 JS JSON.parse 后注入 Lua (injectParsedJson)
     → 其他文件: 传入 Lua data_loader.loadJSONChunk(key, jsonString)

2. Lua data_loader.lua:
     local ok, data = pcall(parseJSON, jsonString)  -- 用 Lua 递归下降解析
     _G.dataCache[key] = data                       -- 直接存储整个解析结果

3. 对 events.json:
     JS 侧 JSON.parse → 遍历事件数组 → 逐个注入 Lua dataCache

4. 重复 10 次（每个 JSON 文件一次）

5. 加载完成后（finalizeDataLoad）:
     _G.dataCache["_loaded"] = true
     _G.dataCache["_fileCount"] = 10
     _G.dataCache["_totalSize"] = totalBytes
```

### JSON 解析

Fengari 没有内置 JSON 解析器。采用方案 A（纯 Lua 解析器）+ 方案 B 混合：

- **3.5MB events.json**：使用 JS `JSON.parse()` 加速（`injectParsedJson()`），避免 Lua 解析器成为瓶颈
- **其余文件**（< 1MB）：使用纯 Lua 递归下降解析器 `parseJSON()`

### 加载到 Lua 表的映射

```lua
-- data_loader.lua

_G.dataCache = {}

function loadJSONChunk(cacheKey, jsonStr)
    local ok, data = pcall(parseJSON, jsonStr)
    if not ok then
        _G.dataCache[cacheKey] = nil
        return false, data  -- error message
    end
    _G.dataCache[cacheKey] = data
    return true
end

function injectParsedJson(cacheKey, data)
    _G.dataCache[cacheKey] = data
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

- 加载 dialogues.json → 2977 条记录正确
- 加载 chars.json → 187 个人物正确
- 跨文件引用检查（scene NPC ID → chars 表中有对应记录）
- events.json 通过 JS JSON.parse 加载后 dataCache["events"] 可访问
- 10 个文件全部加载后 dataCache._loaded == true