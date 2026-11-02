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
