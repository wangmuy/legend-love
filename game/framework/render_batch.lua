-- render_batch.lua
-- 绘制批处理（引擎无关的「问引擎要不要攒一批」薄层）
--
-- **为什么要有这一层**（change: port-render-batching）：
--
--   主地图一帧 `drawMain` 实测发出 **约 2900 次 `EngineAPI.sprite.drawHandle`**
--   （2896 / 复测 2926，随裁剪区浮动；480×480 等距地图，视野内每格 2 层 + 建筑层）。
--   三个目标引擎的代价差别巨大：
--
--     LÖVE (OpenGL)  同纹理连续 draw 有隐式批处理 → 实测流畅
--     Godot 4        每帧重建约 2900 个绘制命令 → 可行
--     Unreal (HUD)   `DrawTile` 每次是独立 draw call → 很可能掉帧
--
--   所以需要一条「把这堆画法一次性告诉引擎」的通路。但这条通路**不是正确性
--   前提** —— 引擎没有批处理能力时，调用方必须能照旧逐次 draw。
--
-- **为什么探测/缓存放 framework 而不是各调用方**：
--
--   调用方（`map_render` / 将来的 `text_*`）不该关心「引擎支不支持」的探测
--   逻辑。否则每个调用方都要写一份「先问一次、记住结论、不支持就走老路」，
--   而且每份都要处理「引擎表被替换（测试 mock / 热切换）后缓存失效」。
--   这一层的存在就是为了把这些琐碎收成一份。
--
-- **负约束**（与 framework 其它模块一致，gate_engine_contract.sh 会查）：
--   ✗ 不 require("engine-*")  —— framework 只经 EngineAPI
--   ✗ 不调 love.*             —— 否则等于换个地方写引擎代码
--   ✗ 不读 JY.* / CONFIG.*    —— 本模块只做转发与缓存，无游戏语义
--
-- **语义与契约的关系**（详见 `engine-love2d/engine_api.lua` 的 beginBatch 注释）：
--   - `EngineAPI.render.beginBatch(kind)` 返回 false = 引擎不支持/不优化
--   - 批次内 `drawHandle` 的语义不变（引擎可以攒、也可以立即画，调用方无感知）
--   - 嵌套：本层也**拒绝嵌套**（内层 wrap 退化为直接执行，外层批次保持有效），
--     与契约「beginBatch 在批次内返回 false」保持一致的观感。
--
-- **为什么不在这里实现真正的批处理**：
--   真正的批处理能力属于引擎（LÖVE 要 SpriteBatch + atlas 生命周期，
--   Unreal 要一次 HUD 批次提交）。framework 层只能「请求」，不能替引擎攒顶点
--   —— 那会把引擎的纹理格式/顶点格式搬进 framework，正好是要消除的东西。

local RenderBatch = {}

-- ---------------------------------------------------------------------------
-- 内部状态
-- ---------------------------------------------------------------------------

-- 引擎是否支持批处理：nil = 尚未探测，true/false = 探测结论（缓存）
local cachedSupported = nil

-- 本层当前是否**已经**开启了批次（用于拒绝嵌套 + 保证 endBatch 只配对一次）
local active = false

--- 取引擎 API（每次动态查，避免测试替换 _G.EngineAPI 后拿到旧引用）
local function api()
    return rawget(_G, "EngineAPI")
end

--- 引擎是否具备批处理契约（只查函数存在，不代表支持）
local function hasContract(EngineAPI)
    return EngineAPI ~= nil
        and type(EngineAPI.render) == "table"
        and type(EngineAPI.render.beginBatch) == "function"
        and type(EngineAPI.render.endBatch) == "function"
end

-- ---------------------------------------------------------------------------
-- 探测
-- ---------------------------------------------------------------------------

--- 引擎是否支持批处理（**首次探测后缓存**）
--
-- 探测方式：发起一个**空批次**（beginBatch + endBatch，中间不画任何东西）。
-- 为什么可以这么探：
--   - 契约要求 `beginBatch` 必须返回 boolean，「是否真的进入批处理」是它唯一
--     的输出 —— 不调它就无法知道结论（LÖVE 也实现了这两个函数，但返回 false）。
--   - 空批次按契约是**完全无害**的（不改变画面、不改变绘制状态），
--     所以探测可以发生在任何时刻，包括帧绘制回调之外。
--   - 失败（抛错/返回非 true）一律当作「不支持」：批处理是纯优化，
--     探测失败绝不能让调用方崩。
--
-- **注意**：`begin()` 也会顺手把探测结论写进缓存（第一次真实 begin 就是探测），
-- 所以生产路径上通常**不需要**先调 `isSupported()` —— 它是给「想在开批次之前
-- 就决定走哪条代码路径」的调用方用的（例如决定要不要预先排序/合并顶点）。
--
-- 缓存失效时机：
--   - 引擎表被替换（测试 mock / 热切换）→ 调 `RenderBatch.reset()`
--   - 测试里改实现（如 `_batchSupported` 开关）→ 调 `RenderBatch.reset()`
--
-- @return boolean
function RenderBatch.isSupported()
    if cachedSupported ~= nil then return cachedSupported end

    local EngineAPI = api()
    if not hasContract(EngineAPI) then
        -- 缺契约（老引擎 / 测试桩没补）→ 明确不支持，调用方走逐次绘制
        cachedSupported = false
        return false
    end

    local ok, entered = pcall(EngineAPI.render.beginBatch, "probe")
    if ok and entered == true then
        -- 配对关掉探测批次；失败也不能影响结论（画面上是空的，没什么可提交）
        pcall(EngineAPI.render.endBatch)
        cachedSupported = true
    else
        cachedSupported = false
    end
    return cachedSupported
end

--- 开始一个绘制批次
--
-- **第一次调用兼任探测**：不先发一个空批次，而是直接把真实批次发下去 ——
-- 支持批处理的引擎因此每帧只有 begin/end 各一次，不多付探测开销。
--
-- @param kind string|nil "tile" | "text" | "shape"（透传给引擎，便于选策略）
-- @return boolean 是否**真的**进入了批处理
--         false 的三种来源（调用方只需知道「别指望批次」）：
--           ① 引擎不支持（结论已缓存 → 之后**一次都不再调**引擎的 beginBatch）
--           ② 已在本层的批次内（禁止嵌套 → 内层退化为直接执行）
--           ③ 引擎这次拒绝（例如它自己的批次正在占用）
--
-- ① 的「只打扰一次」是刻意的：`drawMain` 每帧都会调它，若每帧都去问一个
-- 明确不支持的引擎，约 2900 次绘制之外还要多付几千次无意义的契约调用。
function RenderBatch.begin(kind)
    -- ② 禁止嵌套：外层批次保持有效，内层什么都不做（返回 false）
    if active then return false end

    -- ① 已知不支持：连 beginBatch 都不再调（避免每帧约 2900 次之外的额外调用）
    if cachedSupported == false then return false end

    local EngineAPI = api()
    if not hasContract(EngineAPI) then
        cachedSupported = false
        return false
    end

    -- **首次真实 begin 同时充当探测**：省掉一次「空批次探测」，
    -- 让支持批处理的引擎每帧只有 begin/end 各一次，不多付探测开销。
    local ok, entered = pcall(EngineAPI.render.beginBatch, kind)
    if not ok then
        -- 引擎实现抛错也不能让渲染链断：视为不支持，逐次画
        cachedSupported = false
        return false
    end

    entered = (entered == true)
    cachedSupported = entered
    active = entered
    return entered
end

--- 结束当前批次（引擎在此一次性提交）
--
-- **无害空操作**语义（契约要求）：没开过批次 / 没进批次 / 已经关过 → 直接返回，
-- 不抛错。这样调用方用 `pcall` 保证成对调用时不必记住「上次 begin 成没成功」。
--
-- 为什么必须保证被调用（即使 fn 抛错）：批次状态属于引擎，跨帧泄漏的话
-- 下一帧的绘制会落进上一帧的批次里 —— 表现是「画面错位/闪烁但不报错」，
-- 比崩溃难查得多。`wrap` 里用 pcall + 无条件 finish 保证这一点。
function RenderBatch.finish()
    if not active then return end
    active = false
    local EngineAPI = api()
    if hasContract(EngineAPI) then
        -- 引擎的 endBatch 自己也可能抛错（如 GPU 提交失败）。
        -- **不再 pcall 吞掉**：提交失败就是真的画错了，应该让调用方看到。
        EngineAPI.render.endBatch()
    end
end

--- 便利函数：begin → pcall(fn) → finish（**finish 一定执行**）
--
-- @param kind string|nil 批次类型提示
-- @param fn function 批次内要执行的绘制
-- @return boolean|number|nil 进入了批次时返回 fn 的返回值；引擎不支持时也返回
--         fn 的返回值（降级路径语义完全一致）
--
-- **错误处理**：fn 抛错时先 finish（防止批次状态跨帧泄漏），再把错误**原样
-- 重抛**。这里故意不吞错 —— 与 `render.endFrame` 的注释同一个理由：
-- 「吞掉绘制异常会让黑屏但无报错更难查」。
--
-- **嵌套**：内层 wrap 时 begin 返回 false → 直接执行 fn（不进批次）。
-- 外层批次保持有效，可见结果不变。
function RenderBatch.wrap(kind, fn)
    if type(fn) ~= "function" then
        -- 参数错是编程错误，但绘制路径上抛错会毁掉整帧。
        -- 与「批处理是纯优化」一致：不执行、不抛错，返回 nil。
        return nil
    end

    if not RenderBatch.begin(kind) then
        -- 降级：引擎不支持/已嵌套 → 与改造前完全一样地逐次调用
        return fn()
    end

    local ok, result = pcall(fn)
    RenderBatch.finish()          -- **无条件**：throw 也要关批次
    if not ok then
        error(result, 0)          -- 原样重抛（0 = 不加本层的位置信息）
    end
    return result
end

--- 清空探测缓存与批次状态
--
-- 什么时候需要：
--   ① 测试里切换引擎能力（桩的 `_batchSupported` 开关）
--   ② 运行时替换了 `_G.EngineAPI`（测试 mock / 引擎热切换）
--   ③ 引擎报告的「不支持」是**暂时**的（如外部队列占满），想重新探测
--
-- 生产路径不需要主动调（启动后引擎能力不变）。
function RenderBatch.reset()
    cachedSupported = nil
    active = false
end

--- 当前是否处在（本层开启的）批次内（测试/诊断用）
-- @return boolean
function RenderBatch.isActive()
    return active
end

return RenderBatch
