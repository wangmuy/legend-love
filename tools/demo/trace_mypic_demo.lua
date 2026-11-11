-- tools/demo/trace_mypic_demo.lua
-- trace_global 可运行 demo：「谁在什么时候改了 JY.MyPic」追踪
-- （通用化自开场卧姿 bug 调查中的 game/framework/diag_mypic.lua，后者已删除）
--
-- 直接运行（任意目录，无需 Love2D / 游戏数据）:
--   lua tools/demo/trace_mypic_demo.lua
-- 输出: tools/trace_out.txt
--
-- 实际用法（在 game/ 代码写点插桩，详见 tools/trace_global.lua 头部注释）:
--   local TRACE = require "tools.trace_global"
--   TRACE.fields = {
--       MyPic = function() return JY.MyPic end,
--       dir   = function() return JY.Base and JY.Base["人方向"] end,
--   }
--   TRACE.log("startNewGame:348")  -- 每个写点插一行

-- 让 require 能找到仓库根下的 tools.trace_global（无论从哪里运行）
local src = debug.getinfo(1, "S").source
if src:sub(1, 1) == "@" then src = src:sub(2) end
local root = src:match("^(.*)/tools/demo/")
if root == "" then root = nil end
if root then
    package.path = root .. "/?.lua;" .. package.path
end
local TRACE = require "tools.trace_global"

-- 模拟游戏全局（真实运行时由 game/script/jymain.lua 提供）
JY = {
    MyPic = 3445,                   -- 开场卧姿
    Base = { ["人方向"] = 1 },
    CurrentD = 691,                 -- 开场事件执行中
}

-- 配置追踪字段（惰性求值，log 时才调用）
TRACE.fields = {
    MyPic = function() return JY.MyPic end,
    dir   = function() return JY.Base["人方向"] end,
    curD  = function() return JY.CurrentD end,
}

-- 模拟开场时序：各写点逐一插桩
TRACE.log("startNewGame:348 设卧姿")
JY.MyPic = 2508                     -- GetMyPic() 覆盖为站立（人方向=1）
TRACE.log("GAME_SMAP.update GetMyPic")
JY.CurrentD = -1                    -- 嵌套事件协程结束把共享全局复位
TRACE.log("event_0:42 复位")

-- 展示输出文件内容
local candidates = { "tools/trace_out.txt" }
if root then candidates[#candidates + 1] = root .. "/tools/trace_out.txt" end
local f, p
for _, c in ipairs(candidates) do
    f = io.open(c, "r")
    if f then p = c break end
end
if f then
    print("=== " .. p .. " ===")
    print(f:read("a"))
    f:close()
else
    print("未找到 tools/trace_out.txt")
end
