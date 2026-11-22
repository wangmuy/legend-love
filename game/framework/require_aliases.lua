-- require_aliases.lua
-- 裸名 require 别名的**唯一注册处**（change: engine-portability-alias）
--
-- 守的坑（实测确认）：
--   原版游戏脚本 `script/jymain.lua:15-16` 用**裸名** require 框架模块：
--
--       local FileUtil     = require "lib_file"
--       local ScriptLoader = require "script_loader"
--
--   裸名能解析，原先靠的是 **LÖVE 引擎实现文件里的一段 package.preload 注册**
--   （旧 engine_love2d.lua 头部 5 个别名的 for 循环）。这段隐式约定
--   既不在 `engine_api.lua` 里、也不在任何文档里 ——
--   于是按契约实现一个新引擎（例如 Godot）时，启动序列走到
--   `require(CONFIG.ScriptPath .. "jymain")` 就死在
--   `module 'lib_file' not found`，而契约文件对此只字未提。
--
--   修法：把这段注册**从引擎实现搬到 framework**，让所有引擎自动获得，
--   并把「需要 require 本模块」写进 engine_api.lua 的新引擎实现清单。
--
-- 为什么放在 framework/ 而不是各引擎里：
--   裸名别名是「script 层的历史写法」与「framework 模块路径」之间的桥，
--   两边都不属于具体引擎。放引擎里 → 每个引擎都要抄一遍，漏抄就崩，
--   而且崩溃点在 script 层，排查方向会先跑偏到脚本上。
--
-- 用法（任何引擎只需一次）：
--   require("framework.require_aliases")   -- 本模块被 require 时自动 install()
--
-- 幂等性约定：
--   install() 只补**缺失**的别名，**不覆盖**已存在的 package.preload 条目。
--   原因：Web 引擎从字符串装载 framework 模块（package.preload 是唯一入口），
--   它的加载器必须优先；覆盖会让 web 端的模块源被文件路径查找取代（直接失败）。

local RequireAliases = {}

-- 裸名 → framework 模块名 的别名表
--
-- **新增 framework 裸名别名请加到这里**（唯一真源）。
-- 判定标准：script/ 或旧 MOD 脚本里出现 `require "<裸名>"`，
-- 而该名字对应的是 `framework/<裸名>.lua`。
--
-- 当前 5 个来历：
--   lib_file             script/jymain.lua:15（文件操作封装）
--   script_loader        script/jymain.lua:16（脚本加载器）
--   coroutine_scheduler  旧脚本写法；现在多数调用点已写全 framework.* 前缀
--   war_async            旧脚本写法；同上
--   event_executor       旧脚本写法；同上
--
-- 后 3 个当前**没有活跃消费者**（script 层已改用全前缀），但保留：
--   MOD / 旧事件脚本可能仍在用裸名，删掉等于给它们埋一个运行期崩溃。
local ALIASES = {
    "lib_file",
    "script_loader",
    "coroutine_scheduler",
    "war_async",
    "event_executor",
}

--- 注册（幂等）全部裸名别名
--
-- 已存在的 preload 条目一律跳过：见文件头「幂等性约定」。
--
-- @return table RequireAliases 自身（便于链式调用 / 测试断言）
function RequireAliases.install()
    for _, bareName in ipairs(ALIASES) do
        if not package.preload[bareName] then
            package.preload[bareName] = function()
                return require("framework." .. bareName)
            end
        end
    end
    return RequireAliases
end

--- 取别名表副本（测试 / 文档用；调用方不得修改内部表）
-- @return table 裸名数组
function RequireAliases.list()
    local out = {}
    for i, name in ipairs(ALIASES) do out[i] = name end
    return out
end

-- **模块被 require 时自动注册**：
-- 让「任何引擎 require 一次就够」成立 —— 调用方不需要记得再调 install()。
-- 放在 return 之前，保证 require 返回时别名已就绪。
RequireAliases.install()

return RequireAliases
