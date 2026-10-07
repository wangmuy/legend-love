## 上下文

对话数据是 Web MUD 的核心叙事内容。对话从 `script/oldtalk.grp/.idx` 提取（对话不存储在 ranger.grp 中）。

## oldtalk 二进制格式

```
oldtalk.idx:
   每条记录 4 字节 (int32 little-endian)
   记录数 = 文件大小 / 4
   每条记录 = 该对话在 oldtalk.grp 中的起始偏移量

oldtalk.grp:
   连续存储的对话文本
   每条对话以 '\n' 结尾
   编码: GBK（原版）→ 提取时转为 UTF-8
```

## 提取逻辑

```lua
local function extractDialogues()
    local idxData = readFile("script/oldtalk.idx")
    -- idx 文件中每条记录是 4 字节偏移量
    local grpData = readFile("script/oldtalk.grp")
    -- 按偏移量切分对话
    for i = 1, #offsets do
        local startOffset = offsets[i]
        local endOffset = offsets[i+1] or #grpData
        local text = grpData:sub(startOffset+1, endOffset)
        dialogues[i] = { 说话人 = "", 内容 = cleanText(text) }
    end
end
```

## 输出格式

```json
{
  "version": "1.0",
  "extracted": "2026-06-07",
  "total": 2977,
  "dialogues": [
    { "说话人": "胡斐", "内容": "你来了..." },
    { "说话人": "", "内容": "对话内容第二行" }
  ]
}
```

## 风险

| 风险 | 缓解 |
|------|------|
| GBK 编码未转 UTF-8 | 确认 data/ 中的文件是否已转码 |
| 对话分隔符不确定 | 先提取前 10 条人工验证 |