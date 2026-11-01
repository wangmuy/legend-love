-- dialog_layout.lua
-- 对话框排版算法（引擎无关，纯函数，无副作用）
--
-- 本模块只做「文本 → 行数组 + 框宽」的计算，不涉及任何绘制，
-- 也不 require 任何 engine-* 模块（依赖方向：engine → framework）。
--
-- 字体度量的分工：
--   * 默认用 em 估算（汉字 1.0 em / ASCII 0.5 em），与 lib_love 的
--     simsun.ttf@24 实测完全一致（汉字 24.00px、ASCII 12.00px）；
--   * 引擎可传入 widthFn（如 Love2D 的 font:getWidth）做真实测量，
--     从而自适应未来换字体 / 换字号 / 换分辨率。
--
-- 排版规则：
--   1. `*` = 强制断行（语义与原版 TalkEx 一致，保持不变）；
--   2. 每个段内部仍按像素宽度自动换行（原版缺失，长句会溢出）；
--   3. 段内换行采用「均衡」策略，消除孤儿尾行（末行只剩 1-3 字）；
--   4. 只裁掉末尾的空白行，中间空行是作者故意的视觉间隔，必须保留。

local DialogLayout = {}

--------------------------------------------------------------------
-- 内部工具：UTF-8 字符遍历
--------------------------------------------------------------------

--- 遍历 UTF-8 字符串的每个字符
-- @param s string
-- @return function 迭代器，每次返回一个字符
local function utf8Iter(s)
    local i = 1
    local n = #s
    return function()
        if i > n then
            return nil
        end
        local b = s:byte(i)
        local len = 1
        if b >= 0xF0 then
            len = 4
        elseif b >= 0xE0 then
            len = 3
        elseif b >= 0xC0 then
            len = 2
        end
        if i + len - 1 > n then
            len = 1
        end
        local ch = s:sub(i, i + len - 1)
        i = i + len
        return ch
    end
end

--------------------------------------------------------------------
-- 字体度量
--------------------------------------------------------------------

--- 单字符宽度（em 估算）
--
-- 判据与原版 GenTalkString 一致：首字节 >= 128 视为全角汉字（1.0 em），
-- 其余视为半角 ASCII（0.5 em）。实测 simsun.ttf@24：
--   汉字 24.00px = 1.0 em，ASCII 12.00px = 0.5 em
--
-- @param ch string 单个 UTF-8 字符
-- @param size number 字号（像素）
-- @return number 宽度（像素）
function DialogLayout.charWidth(ch, size)
    if #ch >= 2 then
        return size
    end
    return size * 0.5
end

--- 字符串宽度（em 估算）
-- @param s string
-- @param size number 字号
-- @return number 像素宽度
function DialogLayout.textWidth(s, size)
    local w = 0
    for ch in utf8Iter(s) do
        w = w + DialogLayout.charWidth(ch, size)
    end
    return w
end

--- 构造默认的 em 估算宽度函数
-- @param size number 字号
-- @return function (string) -> number
function DialogLayout.emWidthFn(size)
    return function(s)
        return DialogLayout.textWidth(s, size)
    end
end

--------------------------------------------------------------------
-- 换行
--------------------------------------------------------------------

--- 贪心换行：每行尽量塞满
--
-- 判断方式是「把下一个字符拼上去后是否超宽」，因此 widthFn 可以是
-- em 估算，也可以是引擎的真实像素测量函数。
--
-- @param text string 单段文本（不含 *）
-- @param maxW number 行内可用宽（像素）
-- @param widthFn function (string) -> number
-- @return table 行数组，至少一行
function DialogLayout.greedyWrap(text, maxW, widthFn)
    local lines = {}
    local cur = ""
    for ch in utf8Iter(text) do
        if cur ~= "" and widthFn(cur .. ch) > maxW then
            lines[#lines + 1] = cur
            cur = ch
        else
            cur = cur .. ch
        end
    end
    if cur ~= "" then
        lines[#lines + 1] = cur
    end
    if #lines == 0 then
        lines[1] = ""
    end
    return lines
end

--- 均衡换行：行数不变的前提下，使各行长度尽量均匀
--
-- 做法：先用贪心得到行数 n，然后二分搜索「仍能得到 n 行的最窄宽度」，
-- 再按该宽度重排。这样末行不会只剩几个字（孤儿尾行）。
--
-- 已实测：框宽自适应时均衡不增加行数。
--   "你既然是他哥哥，那么本领是不是比他大那么一点点呢？"
--     贪心 [12,12,1]  →  均衡 [9,9,7]
--
-- @param text string 单段文本（不含 *）
-- @param maxW number 行内可用宽
-- @param widthFn function (string) -> number
-- @return table 行数组
function DialogLayout.balancedWrap(text, maxW, widthFn)
    local lines = DialogLayout.greedyWrap(text, maxW, widthFn)
    local n = #lines
    if n <= 1 then
        return lines
    end

    -- 二分：找出「仍能排成 n 行」的最小宽度
    local lo, hi = 1.0, maxW
    for _ = 1, 30 do
        local mid = (lo + hi) / 2
        if #DialogLayout.greedyWrap(text, mid, widthFn) <= n then
            hi = mid
        else
            lo = mid
        end
    end
    return DialogLayout.greedyWrap(text, hi, widthFn)
end

--------------------------------------------------------------------
-- * 切段
--------------------------------------------------------------------

--- 按 * 切段（* 是强制断行符）
--
-- 空段会保留，用于表示作者故意的空行：
--   "a*b"   -> {"a", "b"}
--   "a**b"  -> {"a", "", "b"}
--   "a***"  -> {"a", "", "", ""}
--   ""      -> {""}
--
-- @param text string
-- @return table 段数组
function DialogLayout.splitByStar(text)
    local segs = {}
    local start = 1
    while true do
        local p = text:find("*", start, true)
        if not p then
            segs[#segs + 1] = text:sub(start)
            break
        end
        segs[#segs + 1] = text:sub(start, p - 1)
        start = p + 1
    end
    return segs
end

--------------------------------------------------------------------
-- 空白处理
--------------------------------------------------------------------

--- 裁掉末尾的空白行（只裁末尾，中间空行保留）
--
-- 为什么只裁末尾：多个连续 * 会生成空行，位置不同语义不同。
--   "接下来换谁？**．．．．*．．．．***没有人了吗？"
--     行2/5/6 是作者嵌入的视觉间隔 → 必须保留
--   "内容***"
--     末尾 3 个空行 → 会产生一整页空白 → 必须裁掉
--
-- @param lines table 行数组
-- @return table 新行数组（不修改入参）
function DialogLayout.trimTrailingBlank(lines)
    local out = {}
    for i = 1, #lines do
        out[i] = lines[i]
    end
    while #out > 0 and out[#out]:match("^%s*$") do
        table.remove(out)
    end
    return out
end

--------------------------------------------------------------------
-- 顶层排版
--------------------------------------------------------------------

--- 文本排版：切段 → 段内均衡换行 → 裁末尾空白 → 算框宽 → 分页
--
-- 框宽求值顺序很关键：**先换行、后定框宽**。
-- 若先假定框宽 = maxWidth 再换行，均衡后每行往往远窄于 maxWidth，
-- 框右边会留大片空白（实测 38 字案例会白 442px）。
--
-- @param text string 原始对话文本（可含 *）
-- @param opts table|nil 选项
--   size        number 字号，默认 24
--   pad         number 内边距，默认 5
--   minWidth    number 框宽下限，默认 298
--   maxWidth    number 框宽上限，默认 908
--   linesPerPage number 每页行数，默认 3
--   widthFn     function|nil 真实测量函数，nil 则用 em 估算
-- @return table { lines, width, pages, lineCount }
function DialogLayout.layoutText(text, opts)
    opts = opts or {}
    local size = opts.size or 24
    local pad = opts.pad or 5
    local minWidth = opts.minWidth or 298
    local maxWidth = opts.maxWidth or 908
    local linesPerPage = opts.linesPerPage or 3

    local widthFn = opts.widthFn or DialogLayout.emWidthFn(size)
    local innerMax = maxWidth - 2 * pad

    -- ① 切段 + 段内均衡换行
    local lines = {}
    for _, seg in ipairs(DialogLayout.splitByStar(text)) do
        if seg == "" then
            lines[#lines + 1] = ""
        else
            for _, l in ipairs(DialogLayout.balancedWrap(seg, innerMax, widthFn)) do
                lines[#lines + 1] = l
            end
        end
    end

    -- ② 只裁末尾空白行
    lines = DialogLayout.trimTrailingBlank(lines)
    if #lines == 0 then
        lines[1] = ""
    end

    -- ③ 按实际最宽行求框宽（而不是直接顶到上限）
    local maxLineW = 0
    for _, l in ipairs(lines) do
        local w = widthFn(l)
        if w > maxLineW then
            maxLineW = w
        end
    end
    local width = math.floor(maxLineW + 2 * pad + 0.5)
    if width < minWidth then
        width = minWidth
    end
    if width > maxWidth then
        width = maxWidth
    end

    -- ④ 分页
    local pages = math.ceil(#lines / linesPerPage)
    if pages < 1 then
        pages = 1
    end

    return {
        lines = lines,
        width = width,
        pages = pages,
        lineCount = #lines,
        linesPerPage = linesPerPage,
    }
end

--- 按每页行数切页
-- @param lines table 行数组
-- @param perPage number 每页行数
-- @return table 页数组，每个元素是行数组
function DialogLayout.paginate(lines, perPage)
    perPage = perPage or 3
    local pages = {}
    local i = 1
    while i <= #lines do
        local page = {}
        for k = 0, perPage - 1 do
            if lines[i + k] == nil then
                break
            end
            page[k + 1] = lines[i + k]
        end
        pages[#pages + 1] = page
        i = i + perPage
    end
    if #pages == 0 then
        pages[1] = { "" }
    end
    return pages
end

return DialogLayout
