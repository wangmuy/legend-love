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

    lib.Debug("SceneNameAsync.ShowCoroutine: " .. tostring(name))

    -- 阻止游戏主循环处理按键（GAME_SMAP.update 的行走逻辑）
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = true

    currentName = name

    -- 挂起当前协程，等按键事件唤醒
    local InputAsync = require("framework.input_async")
    local keypress = InputAsync.WaitKeyCoroutine()

    lib.Debug("SceneNameAsync.ShowCoroutine: key=" .. tostring(keypress) .. " -> dismiss")

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
        lib.Debug("SceneNameAsync.Show: start failed: " .. tostring(err))
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

-- 清空（供测试与异常恢复使用）
function SceneNameAsync.clear()
    currentName = nil
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = false
end

return SceneNameAsync
