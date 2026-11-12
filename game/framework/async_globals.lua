-- async_globals.lua
-- 全局函数替换模块
-- 基于 EngineAPI yieldable 函数的事件驱动适配层
-- 在事件脚本执行前安装，将阻塞函数替换为异步版本

local AsyncGlobals = {}

local AsyncMessageBox = require("framework.async_message_box")
local MenuAsync = require("framework.menu_async")
local TalkAsync = require("framework.talk_async")

-- 保存原始函数
local _DrawStrBoxWaitKey
local _DrawStrBoxYesNo
local _WaitKey
local _ShowMenu
local _ShowMenu2
local _TalkEx
local _ShowScreen
local _libDelay
local _WarMain

-- 替换的 DrawStrBoxWaitKey
function AsyncGlobals.DrawStrBoxWaitKey_Async(s, color, size)
    if EngineAPI.coroutine.isRunning() then
        return AsyncMessageBox.ShowMessageCoroutine(-1, -1, s, color or C_WHITE, size or CC.DefaultFont)
    else
        return _DrawStrBoxWaitKey(s, color, size)
    end
end

-- 替换的 DrawStrBoxYesNo
function AsyncGlobals.DrawStrBoxYesNo_Async(x, y, str, color, size)
    if EngineAPI.coroutine.isRunning() then
        return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, str, color or C_WHITE, size or CC.DefaultFont)
    else
        return _DrawStrBoxYesNo(x, y, str, color, size)
    end
end

-- 替换的 WaitKey
function AsyncGlobals.WaitKey_Async()
    if EngineAPI.coroutine.isRunning() then
        return EngineAPI.input.waitForKey()
    else
        return _WaitKey()
    end
end

-- 替换的 ShowMenu
function AsyncGlobals.ShowMenu_Async(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    if EngineAPI.coroutine.isRunning() then
        return MenuAsync.ShowMenuCoroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    else
        return _ShowMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    end
end

-- 替换的 ShowMenu2
function AsyncGlobals.ShowMenu2_Async(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    if EngineAPI.coroutine.isRunning() then
        return MenuAsync.ShowMenu2Coroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    else
        return _ShowMenu2(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    end
end

-- 替换的 TalkEx
function AsyncGlobals.TalkEx_Async(s, headid, flag)
    if EngineAPI.coroutine.isRunning() then
        return TalkAsync.TalkExCoroutine(s, headid, flag)
    else
        return _TalkEx(s, headid, flag)
    end
end

-- 替换的 lib.Delay
function AsyncGlobals.lib_Delay_Async(millis)
    if EngineAPI.coroutine.isRunning() then
        return EngineAPI.time.sleep(millis)
    else
        return _libDelay(millis)
    end
end

-- 替换的 ShowScreen
function AsyncGlobals.ShowScreen_Async(flag)
    -- 在事件驱动架构中，love.draw 每帧自动调用
end

-- 安装替换
--
-- 必须是**可重入**的：事件脚本里嵌套触发另一个事件时，内层 EventExecutor
-- 会再次 install()。若每次都无条件保存/覆盖「原始函数」，内层保存到的是
-- 外层装好的异步版本，uninstall 时就把异步版当成原版永久留下；
-- 更糟的是 WarMain 包装器闭包引用同一个 _WarMain upvalue，二次安装会变成
-- 自我递归。因此用深度计数：只在最外层真正替换与还原。
local _installDepth = 0

function AsyncGlobals.install()
    _installDepth = _installDepth + 1
    if _installDepth > 1 then
        -- 已安装（嵌套调用）：什么都不做，等最外层 uninstall 统一还原
        return
    end

    _DrawStrBoxWaitKey = _G.DrawStrBoxWaitKey
    _DrawStrBoxYesNo = _G.DrawStrBoxYesNo
    _WaitKey = _G.WaitKey
    _ShowMenu = _G.ShowMenu
    _ShowMenu2 = _G.ShowMenu2
    _TalkEx = _G.TalkEx
    _ShowScreen = _G.ShowScreen
    _libDelay = lib and lib.Delay
    _WarMain = _G.WarMain

    _G.DrawStrBoxWaitKey = AsyncGlobals.DrawStrBoxWaitKey_Async
    _G.DrawStrBoxYesNo = AsyncGlobals.DrawStrBoxYesNo_Async
    _G.WaitKey = AsyncGlobals.WaitKey_Async
    _G.ShowMenu = AsyncGlobals.ShowMenu_Async
    _G.ShowMenu2 = AsyncGlobals.ShowMenu2_Async
    _G.TalkEx = AsyncGlobals.TalkEx_Async
    _G.ShowScreen = AsyncGlobals.ShowScreen_Async

    if lib then
        lib.Delay = AsyncGlobals.lib_Delay_Async
    end

    -- 场景名提示：把 SceneNameAsync.Show 注入为全局实现。
    --
    -- 必须用 rawset！严格 _G 元表（jymain_adapter.lua 安装的 __newindex）
    -- 只放行「已存在键」的赋值；ShowSceneNameAsyncImpl 是本文件新引入的
    -- 全新全局，裸赋值 `_G.X = ...` 会抛
    --   attempt read write to undeclared variable ShowSceneNameAsyncImpl
    -- 而这一行位于 install() 中段——一旦抛错，上面已换好的
    -- WaitKey/ShowMenu/TalkEx 停留在「已替换」状态、后面的 uninstall()
    -- 永不执行，开场事件直接卡死（表现为画面完全静止）。
    local SceneNameAsync = require("framework.scene_name_async")
    rawset(_G, "ShowSceneNameAsyncImpl", SceneNameAsync.Show)

    -- 战斗入口 WarMain 的异步替换。
    --
    -- 韦大宝（script/newevent/scene_1_event_19.lua）的「佣兵行会」直接调用
    -- WarMain(warid,1)，而 jymain.lua 里的 WarMain 是纯阻塞实现
    -- （内部就是 `while true do ... end` 战斗主循环 + 阻塞版 GetKey），
    -- 在主线程调用会把 love.update 彻底锁死。
    --
    -- 注意：WarMain 是全仓库唯一没有异步替代的原版阻塞入口，且唯一调用者
    -- 就是 newevent 韦大宝脚本（oldevent 走 instruct_6，后者早已有协程分支）。
    -- 因此这里按 instruct_6 的既有做法接管：开战斗子协程 → 等在协程里跑完 →
    -- 返回 warState.result（true=胜）。调用方仍可写 `if WarMain(id,1)==true`。
    rawset(_G, "WarMain", function(warid, isexp)
        if not EngineAPI.coroutine.isRunning() then
            -- 非协程上下文：保持原版行为（主线程阻塞），避免语义突变
            return _WarMain(warid, isexp)
        end
        local CoroutineScheduler = require("framework.coroutine_scheduler")
        local WarAsync = require("framework.war_async")
        local scheduler = CoroutineScheduler.getInstance()

        local warCo = scheduler:create(function()
            return WarAsync.WarMainCoroutine(warid, isexp)
        end, "war_main_sub")
        scheduler:start(warCo)

        -- 与 instruct_6 相同：每帧把控制权交回调度器，直到战斗协程结束
        while scheduler:isActive(warCo) do
            scheduler:yield("war_main_wait")
        end

        -- 兜底：战斗协程可能因未捕获错误而 dead，此时 WarMainCoroutine 的
        -- 收尾段（恢复 JY.Status、重载 SMAP 贴图与音乐、写 warState.result）
        -- 一行都没执行。协程错误只会被调度器静默记录到 error.txt，调用方
        -- 拿不到任何信号，玩家就永久卡在战斗画面、回不到原场景。
        --
        -- 这里只做最小的状态修复：把 JY.Status 从 GAME_WMAP 拉回 SMAP，
        -- 让状态机下一帧切回场景，避免死锁。正常结束时 WarMainCoroutine
        -- 已把 Status 设成 prevState，本分支不会触发。
        local info = nil
        if type(scheduler.getInfo) == "function" then
            info = scheduler:getInfo(warCo)
        end
        if info and info.status == "error" then
            lib.Debug("WarMain: battle coroutine died with error, recovering state")
            if JY and (JY.Status == nil or JY.Status == GAME_WMAP) then
                JY.Status = GAME_SMAP
            end
        end

        return scheduler:getResult(warCo)
    end)

    local ItemAsync = require("framework.item_async")
    if _G.SelectThing then
        -- 必须转发入参！原版签名是 SelectThing(thing, thingnum)，
        -- 调用方会传入自己的物品数组（韦大宝典当就是先快照背包再传进来）。
        -- 之前写死成无参 SelectThingAsync()，会忽略调用方的数组、改读全局背包，
        -- 典当列表因此与玩家实际背包不符。
        _G.SelectThing = function(thing, thingnum)
            if thing then
                return ItemAsync.SelectThingByArrayAsync(thing, thingnum, CC.MyThingNum)
            end
            return ItemAsync.SelectThingAsync()
        end
    end
    if _G.UseThing then
        _G.UseThing = function(thingId)
            local success = ItemAsync.UseThingAsync(thingId)
            return success and 1 or 0
        end
    end
end

-- 卸载替换（与 install 配对，深度计数归零时才真正还原）
function AsyncGlobals.uninstall()
    if _installDepth > 0 then
        _installDepth = _installDepth - 1
    end
    if _installDepth > 0 then
        -- 还有外层事件在执行：保持替换状态
        return
    end

    _G.DrawStrBoxWaitKey = _DrawStrBoxWaitKey
    _G.DrawStrBoxYesNo = _DrawStrBoxYesNo
    _G.WaitKey = _WaitKey
    _G.ShowMenu = _ShowMenu
    _G.ShowMenu2 = _ShowMenu2
    _G.TalkEx = _TalkEx
    _G.ShowScreen = _ShowScreen
    -- 必须无条件还原（含 nil 的情形）：若进入 install() 时 WarMain 尚未定义
    -- （jymain 还没加载），旧写法 `if _WarMain then` 会把异步包装器永久留在
    -- 全局上，后续 install() 保存到的「原版」就是上一个包装器，层层自包裹。
    rawset(_G, "WarMain", _WarMain)

    if lib and _libDelay then
        lib.Delay = _libDelay
    end
end

--- 当前安装深度（调试/测试用）。
-- @return number
function AsyncGlobals.installDepth()
    return _installDepth
end

--- 强制复位（仅测试用：某个用例中途抛错后留下的残留状态）。
function AsyncGlobals.resetInstallState()
    _installDepth = 0
end

return AsyncGlobals