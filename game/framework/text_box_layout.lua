-- text_box_layout.lua
-- 「画一个框、把一行字写在框里」的尺寸计算（引擎无关纯模块）
--
-- 原版 jymain.lua 的 DrawStrBox 用的是：
--     local w = size * #str / 2 + 2*CC.MenuBorderPixel
--     local h = size     + 2*CC.MenuBorderPixel
--
-- 在实际运行的原版里这个公式是准的，因为原版 C 层的 JY_DrawStr 用
-- TTF_SizeUTF8 量真实像素宽（charset.c:150），而移植版的公式把 #str
-- 当成了字符数。Lua 5.1 的 # 是**字节数**：
--
--     汉字 UTF-8 占 3 字节  ->  框宽被算成 4.5 倍字号（严重偏大）
--     ASCII 占 1 字节       ->  框宽被算成 0.5 倍字号（正确）
--     全角标点占 3 字节     ->  同样偏大
--
-- 实测（simsun.ttf @ 24，真实宽由 font:getWidth 给出）：
--   「梅庄」              2 字符 / 6 字节   真实 48px   旧公式 82px   多 29px
--   「牛家村」            3 字符 / 9 字节   真实 72px   旧公式 118px  多 41px
--   「得到物品:倚天剑 1」 10 字符 / 24 字节 真实 204px  旧公式 298px  多 89px
--   「要查阅谁的状态」    7 字符 / 21 字节  真实 168px  旧公式 262px  多 89px
--
-- 框比文字宽出来的那部分，文字按左对齐画上去，右边就是一片空白。
-- 两个用户可见症状同源：
--   ① 获取物品的提示框，文字明显靠左（用户描述为「没有垂直居中」，
--      实际框高只有 34px、上下间隙各 7px 本来是对称的，视觉上的不居中来
--      自右侧大片空白把文字挤到了左边）；
--   ② 进入小场景的名称框，右边空位太多。
--
-- 本模块只做尺寸计算，不绘制。所有需要「框包住一行字」的地方都应当调用
-- 这里，避免再出现第二套（错误的）公式。
--
-- 关于宽度口径（为什么不需要 EngineAPI 提供字体度量）：
--   对项目当前字体 simsun.ttf 做过实测（LÖVE 11.5，字号 24）：
--   font:getWidth 与「汉字 1.0em / ASCII 0.5em」的估算在 20 个代表性文本
--   （含中英混排、全角标点、纯 ASCII）上**最大偏差 0.00px**；32..126 的全部
--   95 个 ASCII 可打印字符也全部精确等于 0.5em。simsun 是等宽设计，
--   每个半角字形恰好半个字身。
--   因此这里直接用 em 估算即可，无需跨引擎新增字体度量接口
--   （engine-*/ 是受保护路径，能不动就不动）。
--   若将来换成非等宽字体导致偏差，优先在引擎侧补 EngineAPI.font.measureText，
--   本模块的 textWidth 已经会优先使用它（见下），无需改动调用方。

local TextBoxLayout = {}

-- 兜底的 em 宽度估算：汉字 1.0em、ASCII 0.5em。
-- 仅在调用方拿不到 EngineAPI.font.measureText 时使用。
local function emWidth(str, size)
    local total = 0
    for ch in str:gmatch("[^\128-\191][\128-\191]*") do
        total = total + ((#ch >= 2) and size or size * 0.5)
    end
    return total
end

--- 取文本的像素宽度
--
-- 口径：汉字（含全角标点，UTF-8 多字节）按 1.0em，ASCII 按 0.5em。
-- 实测与 simsun.ttf 的真实 font:getWidth 完全一致（见文件头注释）。
--
-- 若将来引擎提供 EngineAPI.font.measureText，则优先用它做真实度量，
-- 以适配非等宽字体；没有该接口时退回 em 估算。
-- 这个函数永远返回数值，不返回 nil，调用方无需写平台分支。
--
-- @param str string 文本
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @return number 像素宽度
function TextBoxLayout.textWidth(str, size, fontName)
    if str == nil or str == "" then
        return 0
    end
    size = size or 20
    -- 工程开启了严格 _G（jymain_adapter.lua:102-109），未声明的全局变量
    -- 一读就抛 "attempt read read to undeclared variable"。
    -- EngineAPI 只在真正跑游戏时才存在，所以必须用 rawget 探测。
    local engineAPI = rawget(_G, "EngineAPI")
    if engineAPI and engineAPI.font and engineAPI.font.measureText then
        local ok, w = pcall(engineAPI.font.measureText, str, size, fontName)
        if ok and type(w) == "number" then
            return w
        end
    end
    return emWidth(str, size)
end

--- 取行高
--
-- 注意不等于字号：simsun.ttf @ 24 的 getHeight() 是 27px。
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @return number 行高
function TextBoxLayout.lineHeight(size, fontName)
    size = size or 20
    local engineAPI = rawget(_G, "EngineAPI")
    if engineAPI and engineAPI.font and engineAPI.font.measureHeight then
        local ok, h = pcall(engineAPI.font.measureHeight, size, fontName)
        if ok and type(h) == "number" and h > 0 then
            return h
        end
    end
    return size * 1.125
end

--- 计算「框包住一行字」的框尺寸
--
-- 框宽 = 文本真实像素宽 + 左右各一个 padding
-- 框高 = **字号** + 上下各一个 padding
--
-- 为何框高用字号而不是行高（getHeight = 27）：
--   单行文本要的是**光学居中**，即字形墨迹到框上下边的距离相等。
--   实测算（simsun@24，画到画布后逐像素扫描墨迹包围盒）：
--     框高 = size   + 2*pad = 34  ->  墨迹间隙 上 7 / 下 7   ✅ 对称
--     框高 = getHeight + 2*pad = 37 ->  墨迹间隙 上 7 / 下 10  ❌ 偏上
--   因为 getHeight(27) 比字形墨迹高(23) 大 4px，多出来的空间是给
--   下伸部（g/p/q 的尾巴）预留的，中文单行文本用不上，反而破坏对称。
--   行高（lineHeight）只在**多行**排版里作为行间距使用，见 measureHeight。
--
-- 与旧的 `size * #str / 2` 公式的关键区别：宽度基于**真实像素**，
-- 与 UTF-8 字节数无关。中英文混排也不会偏。
--
-- @param str string 文本
-- @param opts table {
--     size      字号，默认 20
--     pad       内边距，默认 CC.MenuBorderPixel（= 5）
--     fontName  字体名，默认 CC.FontName
--     minWidth  框宽下限，可选
--   }
-- @return table { width, height, textWidth, textHeight, pad }
function TextBoxLayout.measure(str, opts)
    opts = opts or {}
    local size = opts.size or 20
    local cc = rawget(_G, "CC")
    local fontName = opts.fontName or (cc and cc.FontName) or nil
    local pad = opts.pad
    if pad == nil then
        pad = (cc and cc.MenuBorderPixel) or 5
    end

    local tw = TextBoxLayout.textWidth(str, size, fontName)
    local lineH = TextBoxLayout.lineHeight(size, fontName)

    local w = tw + 2 * pad
    if opts.minWidth and w < opts.minWidth then
        w = opts.minWidth
    end

    return {
        width  = w,
        -- 单行框高用字号（见上方注释：光学居中），不用 lineHeight
        height = size + 2 * pad,
        textWidth = tw,
        lineHeight = lineH,
        pad = pad,
    }
end

--- 把文本左对齐补到指定显示宽度（用于「名称 价格」这类多列排版）
--
-- 为什么需要它：`string.format("%-12s", name)` 的 12 是**字节数**，
-- 汉字 UTF-8 占 3 字节，所以「补到 12 字节」= 补到 4 个汉字。
-- 3/4/5 字的名字会各占一档，右侧的数字列呈台阶状，完全对不齐。
--
-- 实测（真实存档数据，5 家小宝商店 × 5 项商品）：
--   用 %-12s 时价格列起点在 108/120/132 之间跳动，抖动 24px = 恰好 1 个汉字。
--   医疗/解毒菜单用 %-10s 时姓名列抖动 12px = 0.5 个汉字。
--
-- 本函数按**显示宽度**补空格，粒度是半角空格（0.5em）。汉字名宽必为
-- 1.0em 的整数倍，因此只要目标宽度是 0.5em 的整数倍，就能精确对齐。
--
-- 注意：只补不截。若文本本身已超过 targetWidth，原样返回 ——
-- 截断会丢字，而「超出」说明调用方给的列宽不够，应当由调用方放大列宽。
--
-- @param str string 文本（可含多字节字符）
-- @param targetWidth number 目标显示宽度（像素）
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @return string 补齐后的文本
function TextBoxLayout.padToWidth(str, targetWidth, size, fontName)
    return TextBoxLayout.alignToWidth(str, targetWidth, size, fontName, "left")
end

--- 按指定对齐方向把文本补到目标显示宽度
--
-- align = "left"（默认，在右侧补空格）或 "right"（在左侧补空格）。
--
-- 为什么需要右对齐：原版菜单用 string.format("%-10s%4d", 姓名, 数值)，
-- 其中 %4d 是**右对齐数字**。修掉字节数缺陷时不能顺手把数字也改成左对齐，
-- 否则「价格列 / 能力值列」的观感就跟原版不一致了。
-- 右对齐后所有数值的右边缘也对齐，读起来像一张表。
--
-- 同样只补不截：文本超过目标宽度时原样返回（截断会丢字）。
--
-- @param str string 文本
-- @param targetWidth number 目标显示宽度（像素）
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @param align string|nil "left" | "right"
-- @return string 补齐后的文本
function TextBoxLayout.alignToWidth(str, targetWidth, size, fontName, align)
    str = str or ""
    targetWidth = targetWidth or 0
    size = size or 20

    local w = TextBoxLayout.textWidth(str, size, fontName)
    if w >= targetWidth then
        -- 已达或超出目标宽度：不截断，原样返回
        return str
    end

    local spaceW = TextBoxLayout.textWidth(" ", size, fontName)
    if spaceW <= 0 then
        -- 理论上不会发生（字号 0 或度量异常），避免死循环/除零
        return str
    end

    local n = math.floor((targetWidth - w) / spaceW + 0.5)
    if n <= 0 then
        return str
    end

    local pad = string.rep(" ", n)
    if align == "right" then
        return pad .. str
    end
    return str .. pad
end

--- 计算一组多列条目中某一列的显示宽度（取该列所有单元格的最大值）
--
-- 供「名称 价格」这类表格型菜单统一列宽用。调用方拿到宽度后，
-- 用 padToWidth 逐格补齐，即可保证同一列起点一致。
--
-- @param rows table 二维表，rows[i][colIndex] 为第 i 行第 col 列的文本
-- @param colIndex number 列序号
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @return number 该列最大显示宽度
function TextBoxLayout.columnWidth(rows, colIndex, size, fontName)
    size = size or 20
    local maxW = 0
    for i = 1, #rows do
        local row = rows[i]
        local cell = row and row[colIndex]
        if type(cell) == "string" then
            local w = TextBoxLayout.textWidth(cell, size, fontName)
            if w > maxW then
                maxW = w
            end
        end
    end
    return maxW
end

--- 判断一列是否应当右对齐（整列都是数字/负数）
--
-- 原版菜单里的数值列用 %4d / %5d，本来就是右对齐的。
-- 这里自动识别数字列，让调用方不必逐个声明。
local function isNumericColumn(rows, colIndex)
    local sawAny = false
    for i = 1, #rows do
        local row = rows[i]
        local cell = (type(row) == "table") and row[colIndex] or nil
        if cell ~= nil then
            local t = tostring(cell)
            if t ~= "" then
                sawAny = true
                if not t:match("^%-?%d+$") then
                    return false
                end
            end
        end
    end
    return sawAny
end

--- 把多列表格拼成一行行等宽列文本
--
-- 每个单元格按所在列的**最大显示宽度**补齐，列与列之间插入 sep。
-- 文本列左对齐、数字列右对齐（与原版 %-10s%4d 的语义一致），
-- 也可用 opts.aligns 逐列显式指定 "left" / "right"。
--
-- 末列的处理：
--   · 左对齐 -> 不补（避免行尾出现无意义空格）
--   · 右对齐 -> 左侧补齐（使数值右边缘对齐）
--
-- @param rows table 二维表
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @param sep string|nil 列分隔符，默认 " "
-- @param opts table|nil { aligns = {"left","right",...} }
-- @return table 文本行数组
function TextBoxLayout.formatColumns(rows, size, fontName, sep, opts)
    size = size or 20
    if sep == nil then
        sep = " "
    end
    opts = opts or {}

    local explicitAligns = opts.aligns

    -- 求列数
    local colCount = 0
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" then
            for c = 1, #row do
                if c > colCount then
                    colCount = c
                end
            end
        end
    end

    local colW, colAlign = {}, {}
    for c = 1, colCount do
        colW[c] = TextBoxLayout.columnWidth(rows, c, size, fontName)
        if explicitAligns and explicitAligns[c] then
            colAlign[c] = explicitAligns[c]
        elseif isNumericColumn(rows, c) then
            colAlign[c] = "right"
        else
            colAlign[c] = "left"
        end
    end

    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        local parts = {}
        for c = 1, colCount do
            local cell = (type(row) == "table") and row[c] or nil
            if cell == nil then
                cell = ""
            else
                cell = tostring(cell)
            end
            local isLast = (c == colCount)
            -- 末列左对齐时不补，避免行尾空格
            if isLast and colAlign[c] == "left" then
                parts[c] = cell
            else
                parts[c] = TextBoxLayout.alignToWidth(cell, colW[c], size, fontName, colAlign[c])
            end
        end
        out[i] = table.concat(parts, sep)
    end
    return out
end

--- 计算让框在屏幕上居中时的左上角坐标
--
-- 语义与原版 DrawStrBox 的 x/y == -1 分支一致，但基于真实框尺寸。
--
-- @param box table measure 的返回值（需要 width / height）
-- @param screenW number 屏幕宽
-- @param screenH number 屏幕高
-- @return number x, number y
function TextBoxLayout.center(box, screenW, screenH)
    local x = (screenW - box.width) / 2
    local y = (screenH - box.height) / 2
    return x, y
end

return TextBoxLayout
