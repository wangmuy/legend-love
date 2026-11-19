-- scene_name_async.lua
-- 异步场景名提示（对应原版 Init_SMap(1) 的阻塞流程）
--
-- 原版行为（~/project/legend-mac-orig/bin/script/jymain.lua:436 起）：
--     if showname==1 then
--         DrawStrBox(-1,10,JY.Scene[JY.SubScene]["名称"],C_WHITE,CC.DefaultFont);
--         ShowScreen();
--         WaitKey();
--         Cls();
--         ShowScreen();
--     end
-- 即「画一次框 → 等键 → 清屏」，全程阻塞主循环。
--
-- 本项目的事件驱动改法遵循 person_status_async.lua 的既有样板：
--   * 绘制：由 draw() 每帧执行，挂在 EventBridge:draw() 之后
--     （GAME_SMAP.draw 每帧全屏 DrawSMap，画在这里才不会被覆盖）
--   * 等键：协程里 InputAsync.WaitKeyCoroutine() 挂起，
--     由 CoroutineScheduler:update 在按键事件到来时唤醒（非轮询）
--   * 屏蔽行走：InputManager.disableInput = true，
--     GAME_SMAP.update 的 lib.GetKey() 返回 -1，移动逻辑自然停摆
--   * 状态：模块级 currentName，退出时置 nil

local SceneNameAsync = {}

local CoroutineScheduler = require("framework.coroutine_scheduler")

-- 当前要显示的场景名；nil 表示不显示
local currentName = nil

-- 显示场景名并等待任意键
-- @param name: 场景名称；nil/空串时不显示、立即返回
function SceneNameAsync.ShowCoroutine(name)
    if name == nil or name:match("^%s*$") then
        return
    end

    EngineAPI.debug.log("SceneNameAsync.ShowCoroutine: " .. tostring(name))

    -- 阻止游戏主循环处理按键（GAME_SMAP.update 的行走逻辑）
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = true

    currentName = name

    -- 挂起当前协程，等按键事件唤醒
    local InputAsync = require("framework.input_async")
    local keypress = InputAsync.WaitKeyCoroutine()

    EngineAPI.debug.log("SceneNameAsync.ShowCoroutine: key=" .. tostring(keypress) .. " -> dismiss")

    currentName = nil
    InputManager.disableInput = false
end

-- 非协程版本：直接启动一个协程执行
-- 用于 GAME_SMAP.update 这类非协程调用点
-- @return: 是否启动成功
function SceneNameAsync.Show(name)
    if name == nil or name:match("^%s*$") then
        return false
    end

    -- 已有提示在显示：只更新名称，不重复起协程
    if currentName ~= nil then
        currentName = name
        return true
    end

    local scheduler = CoroutineScheduler.getInstance()
    local co = scheduler:create(function()
        SceneNameAsync.ShowCoroutine(name)
    end, "scene_name")
    local ok, err = scheduler:start(co)
    if not ok then
        EngineAPI.debug.log("SceneNameAsync.Show: start failed: " .. tostring(err))
        return false
    end
    return true
end

-- 绘制场景名（在 draw 中调用）
function SceneNameAsync.draw()
    if currentName == nil then
        return
    end
    DrawSceneName(currentName)
end

-- 是否有提示正在显示
function SceneNameAsync.isActive()
    return currentName ~= nil
end

-- 清空（供测试、异常恢复、**状态切换**使用）
--
-- 必须由状态切换调用（GAME_SMAP.exit）：场景名提示靠一个「挂起等键」的
-- 协程维持，切走状态时那个协程不会被唤醒也不会被取消。
-- 不清空的后果（用户实测）：
--   ① currentName 残留 → EventBridge:draw() 每帧照画 → 名字留在屏幕上
--   ② disableInput 残留为 true → 之后所有点击都被 canPlayerAct 挡掉
--      → 表现为「小场景内点什么都没反应」
--
-- 顺带收敛 InputManager.disableInput：它是个「多人共用」的布尔量，
-- 提示结束后必须恢复成 false，否则别的模块会一直以为在被阻塞。
function SceneNameAsync.clear()
    currentName = nil
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = false
end

-- 场景切换时的清理钩子（幂等）
--
-- 与 clear() 的区别：这个函数在「没有提示显示」时完全不动 disableInput，
-- 避免误清掉别的模块（动画、菜单）设置的阻塞标志。
function SceneNameAsync.dismissOnStateChange()
    local had = (currentName ~= nil)
    currentName = nil
    if had then
        local InputManager = require("framework.input_manager")
        InputManager.disableInput = false
        EngineAPI.debug.log("SceneNameAsync: dismissed on state change")
    end
end

return SceneNameAsync
