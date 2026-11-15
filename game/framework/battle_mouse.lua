-- battle_mouse.lua
-- 战斗中的鼠标支持（REQ-MS4-1）
--
-- 战斗有自己的「光标选择」系统（WAR.MoveCursorX/Y + DrawMode），
-- 和地图寻路（AutoMove/Pathfind）完全是两回事：
--
--   地图：点击 → A* 找路 → 逐步移动主角
--   战斗：方向键 → 移动光标 → 空格确认 → 角色移动一格/施展武功选目标
--
-- 所以战斗中鼠标必须**驱动光标**，不能复用地图点击逻辑。
--
-- 坐标反解与地图共用同一套等轴公式（DrawWarMap 的 i1/j1 与 DrawSMap 一致），
-- 只有相机不同：战斗的相机 = WAR.Person[WAR.CurID].坐标X/Y。

local BattleMouse = {}

----------------------------------------------------------------------
-- 可移动范围判定
----------------------------------------------------------------------

--- 该格是否在「当前行动者的可移动范围」内
--
-- War_CalMoveStep 会把可达格写进 GetWarMap 的第 3 层：
--     255          → 不可达
--     0..stepmax   → 第几步可到
-- 所以判据是「不等于 255」。
--
-- @param x, y number 战斗地图坐标
-- @return boolean
function BattleMouse.isMovable(x, y)
    local ok, v = pcall(function() return GetWarMap(x, y, 3) end)
    if not ok or type(v) ~= "number" then return false end
    return v ~= 255
end

--- 该格是否有敌人（用于选目标）
-- @param x, y number
-- @return boolean
function BattleMouse.isEnemyAt(x, y)
    local WAR = rawget(_G, "WAR")
    if not (WAR and WAR.Person) then return false end

    for i = 0, (WAR.PersonNum or 0) - 1 do
        local p = WAR.Person[i]
        if p and p["坐标X"] == x and p["坐标Y"] == y then
            return p["我方"] ~= true
        end
    end
    return false
end

----------------------------------------------------------------------
-- 状态判定
----------------------------------------------------------------------

--- 战斗界面是否正在进行光标选择
-- @return boolean, string|nil  mode
function BattleMouse.activeMode()
    local WAR = rawget(_G, "WAR")
    if not WAR then return false, nil end
    if WAR.DrawMode == nil then return false, nil end
    if WAR.MoveCursorX == nil or WAR.MoveCursorY == nil then return false, nil end
    return true, WAR.DrawMode
end

--- 战斗是否允许鼠标操作
--
-- 与 canPlayerAct 的区别：后者要求 Status 是 MMAP/SMAP（地图状态），
-- 战斗必须单独判断 —— 战斗本身就该能操作，只是操作对象是「光标」。
--
-- @return boolean
function BattleMouse.canOperate()
    local JY = rawget(_G, "JY")
    local GAME_WMAP = rawget(_G, "GAME_WMAP")
    if not (JY and JY.Status == GAME_WMAP) then return false end

    local ok, mode = BattleMouse.activeMode()
    return ok, mode
end

----------------------------------------------------------------------
-- 鼠标 → 光标
----------------------------------------------------------------------

--- 把屏幕坐标转成战斗地图格坐标
-- @param mx, my number
-- @return number|nil gx, gy
function BattleMouse.screenToBattleTile(mx, my)
    local okH, MouseHover = pcall(require, "framework.mouse_hover")
    if not okH or not MouseHover then return nil end

    local camX, camY = MouseHover.camera("WMAP")
    return MouseHover.screenToTile(mx, my, camX, camY)
end

--- 鼠标移动：把光标挪到所指的格（仅当该格合法）
--
-- @param mx, my number
-- @return boolean 是否移动了光标
function BattleMouse.hoverTo(mx, my)
    local ok, mode = BattleMouse.canOperate()
    if not ok then return false end

    local WAR = rawget(_G, "WAR")
    local gx, gy = BattleMouse.screenToBattleTile(mx, my)
    if not gx then return false end

    -- 边界
    local CC = rawget(_G, "CC")
    local w = (CC and CC.WarWidth) or 64
    local h = (CC and CC.WarHeight) or 64
    if gx < 0 or gy < 0 or gx >= w or gy >= h then return false end

    if gx == WAR.MoveCursorX and gy == WAR.MoveCursorY then
        return false    -- 已在该格
    end

    -- DrawMode 1 = 选移动位置：只能在可移动范围内挪
    -- DrawMode 3 = 选攻击目标：可以指到任意格（含敌人）
    if mode == 1 then
        if not BattleMouse.isMovable(gx, gy) then
            return false
        end
    end

    WAR.MoveCursorX = gx
    WAR.MoveCursorY = gy
    return true
end

--- 鼠标点击：把光标挪过去并确认
--
-- 实现方式：挪光标 + 注入一个 VK_SPACE。
--
-- **与物品清单不同，这里注入键是安全的**：
--   War_MoveCoroutine 用的是纯 WaitKeyCoroutine（没有 waitForTime 循环），
--   注入一个键就会被消费一次，不会积压。
--
-- @param mx, my number
-- @return boolean 是否处理了
function BattleMouse.clickAt(mx, my)
    local ok, mode = BattleMouse.canOperate()
    if not ok then return false end

    local WAR = rawget(_G, "WAR")
    local gx, gy = BattleMouse.screenToBattleTile(mx, my)
    if not gx then return false end

    local CC = rawget(_G, "CC")
    local w = (CC and CC.WarWidth) or 64
    local h = (CC and CC.WarHeight) or 64
    if gx < 0 or gy < 0 or gx >= w or gy >= h then
        return true     -- 点在界外：吃掉但不动作
    end

    -- DrawMode 1（选移动位置）：只有可移动格能确认
    if mode == 1 then
        if not BattleMouse.isMovable(gx, gy) then
            return true     -- 不可达：吃掉但不动作（等价键盘「走不过去」）
        end
    end

    -- 挪光标
    WAR.MoveCursorX = gx
    WAR.MoveCursorY = gy

    -- 注入确认键（协程在 WaitKeyCoroutine 上等，消费一次即返回）
    local okIM, InputManager = pcall(require, "framework.input_manager")
    if okIM and InputManager and InputManager.enqueueKeyEvent then
        InputManager.enqueueKeyEvent(rawget(_G, "VK_SPACE") or 32)
    end
    return true
end

--- 鼠标右键：取消（等价 ESC）
-- @return boolean
function BattleMouse.cancel()
    local ok = BattleMouse.canOperate()
    if not ok then return false end

    local okIM, InputManager = pcall(require, "framework.input_manager")
    if okIM and InputManager and InputManager.enqueueKeyEvent then
        InputManager.enqueueKeyEvent(rawget(_G, "VK_ESCAPE") or 27)
    end
    return true
end

return BattleMouse
