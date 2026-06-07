## 上下文

对话数据是 Web MUD 的核心叙事内容。Slice 2（engine_web）需要加载 dialogues.json 来支持 `talk` 命令。

## oldtalk 二进制格式

```
oldtalk.idx:
  每条记录 4 字节 (int32 little-endian)
  记录数 = 文件大小 / 4
  每条记录 = 该对话在 oldtalk.grp 中的起始偏移量

oldtalk.grp:
  连续存储的对话文本
  每条对话以 '\n' 或 '\0' 结尾（需要确认）
  编码: GBK（原版）或 UTF-8（本项目已转码）
```

## 提取逻辑

```lua
local function extractDialogues()
    -- 读取 idx 文件，获取每条对话的偏移量列表
    local idxData = LoadToTable16("data/oldtalk.idx")
    -- idx 文件中每条记录是 4 字节偏移量
    
    -- 读取 grp 文件
    local grpData = LoadFile("data/oldtalk.grp")
    
    -- 按偏移量切分对话
    for i = 1, #offsets do
        local startOffset = offsets[i]
        local endOffset = offsets[i+1] or #grpData
        local text = grpData:sub(startOffset+1, endOffset)
        -- 去除末尾分隔符，处理编码
        dialogues[i] = { id = i - 1, text = cleanText(text) }
    end
end
```

## 输出格式

```json
{
  "version": "1.0",
  "extracted": "2026-06-07",
  "total": 5120,
  "dialogues": [
    { "id": 0, "text": "对话内容第一行\n对话内容第二行" },
    { "id": 1, "text": "..." }
  ]
}
```

## 风险

| 风险 | 缓解 |
|------|------|
| GBK 编码未转 UTF-8 | 确认 data/ 中的文件是否已转码 |
| 对话分隔符不确定 | 先提取前 10 条人工验证 |