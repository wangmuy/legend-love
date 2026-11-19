-- jymain_adapter.lua
-- JY_Main适配器，连接新旧架构
-- 完全事件驱动版本

local RenderFacade = require("framework.render_facade")
local JYMainAdapter = {}

-- 导入模块
local EventBridge = require("framework.event_bridge")
local GameStates = require("framework.game_states")
local MenuAsync = require("framework.menu_async")
local AsyncMessageBox = require("framework.async_message_box")
local CoroutineScheduler = require("framework.coroutine_scheduler")
local InputAsync = require("framework.input_async")
local EventExecutor = require("framework.event_executor")
local PerfLog = require("framework.perf_log")

-- 音量设置（REQ-MENU-3）
-- Settings 纯逻辑；AudioSettings 负责声明与引擎接线；AudioMenu 只产出菜单项。
local Settings = require("framework.settings")
local SettingsStore = require("framework.settings_store")
local AudioSettings = require("framework.audio_settings")
local AudioMenu = require("framework.audio_menu")
local MouseMenu = require("framework.mouse_menu")

-- 游戏初始化标志
local isInitialized = false
local initCoroutine = nil

-- 获取状态ID的辅助函数
local function getStateId(stateName)
    if stateName == "GAME_MMAP" then
        return GAME_MMAP or 2
    elseif stateName == "GAME_SMAP" then
        return GAME_SMAP or 4
    elseif stateName == "GAME_FIRSTMMAP" then
        return GAME_FIRSTMMAP or 1
    elseif stateName == "GAME_START" then
        return GAME_START or 0
    elseif stateName == "GAME_WMAP" then
        return GAME_WMAP or 5
    elseif stateName == "GAME_END" then
        return GAME_END or 7
    end
    return nil
end

-- 初始化游戏（事件驱动版本）
function JYMainAdapter.init()
    if isInitialized then
        return
    end
    
    -- 使用协程执行初始化流程
    local scheduler = CoroutineScheduler.getInstance()
    initCoroutine = scheduler:create(function()
        -- 通过 _G.JYMainAdapter 访问，这样外部覆写能生效
        -- （模块内的 local JYMainAdapter 已被闭包捕获，外部修改不影响）
        local m = rawget(_G, "JYMainAdapter") or JYMainAdapter
        m.initCoroutine()
    end, "init")
    
    scheduler:start(initCoroutine)
end

-- 初始化协程
function JYMainAdapter.initCoroutine()
    PerfLog.init()
    EngineAPI.debug.log("JYMainAdapter.initCoroutine started")
    
    -- 导入其他模块
    IncludeFile()
    EngineAPI.debug.log("IncludeFile done")
    
    SetGlobalConst()
    EngineAPI.debug.log("SetGlobalConst done")

    -- MOD ini 覆盖（REQ-DATA-4 / Contract A）：激活 MOD 时解析并 Apply kysmod.ini
    -- （分辨率、常量等）。映射表同时覆盖 CONFIG.* 与 CC.*，故无需重跑 SetGlobalConst。
    -- 未激活时为 no-op，保持默认值不变。
    do
        -- 设置系统的初始化顺序在这里很关键：
        --
        --   ① Settings.load()  读 user 层（settings.ini）
        --   ② ModData.LoadIni() 注入 mod 层（kysmod.ini 的音量）
        --   ③ AudioSettings.init() 注册引擎监听 + 推初值
        --
        -- 若 ② 在 ① 之前，mod 层会先写入、user 层再写入 —— 看起来没问题，
        -- 但 Settings.load 只是 setLayer，不改变优先级判定，
        -- 真正的风险是「先 init 后 load」：init 时的 pushAll 会把默认值
        -- 推给引擎，而 load 的变更通知会纠正它。顺序按 ①→②→③ 最直观。
        local okSet = pcall(function()
            -- REQ-MS1-4：注入平台名（必须在使用 platformDefaults 的 define 之前）。
            --
            -- 平台名只是一个字符串 —— settings.lua 不 require 引擎，
            -- 由宿主把 EngineAPI.system.getOS() 的结果传进去（ADR-MS-005）。
            -- 取不到时退化为 "unknown"，platformDefaults 不命中 → 落到 default。
            local pName = "unknown"
            local okSys = pcall(function()
                if EngineAPI and EngineAPI.system
                    and type(EngineAPI.system.getOS) == "function" then
                    pName = EngineAPI.system.getOS() or "unknown"
                end
            end)
            if okSys then
                Settings.setPlatform(pName)
                EngineAPI.debug.log("Settings.setPlatform: " .. tostring(Settings.getPlatform()))
            end

            Settings.define("audio.music", {
                default = AudioSettings.MUSIC_DEFAULT,
                type    = "int",
                min     = AudioSettings.MIN,
                max     = AudioSettings.MAX,
                label   = "音乐音量",
            })
            Settings.define("audio.sfx", {
                default = AudioSettings.SFX_DEFAULT,
                type    = "int",
                min     = AudioSettings.MIN,
                max     = AudioSettings.MAX,
                label   = "音效音量",
            })
            -- 鼠标开关（REQ-MS2-4）：平台默认桌面开、Android 关
            MouseMenu.define()

            -- 鼠标消费入口（REQ-MS2-1 / REQ-MS2-2）
            JYMainAdapter.installMouseHandling()

            Settings.setStore(SettingsStore, SettingsStore.FILENAME)
            Settings.load()
        end)
        if not okSet then
            EngineAPI.debug.log("Settings 初始化失败（不影响启动）")
        end

        local ok, ModData = pcall(require, "framework.mod_data")
        if ok and ModData and ModData.LoadIni then
            local parsed = ModData.LoadIni()
            if parsed then
                EngineAPI.debug.log("ModData.LoadIni applied: " .. tostring(ModData.Active()))
            end
        end
        -- REQ-LBIN-2：list/effect.bin → CC.Effect 惰性装载。
        -- 必须在 SetGlobalConst() 之后（CC 已建）+ SetGlobal() 之前（战鬬逻辑还没用）。
        -- 读不到文件时为 no-op，CC.Effect 保持 jyconst.lua 的 53 项兜底（REQ-LBIN-5）。
        if ok and ModData and ModData.LoadEffectTable then
            local loaded, n = ModData.LoadEffectTable(_G.CC)
            if loaded then
                EngineAPI.debug.log("ModData.LoadEffectTable: " .. tostring(n) .. " entries")
            end
        end

        -- 引擎接线（注册 onChange + 推初值）
        local okAudio = pcall(AudioSettings.init)
        if not okAudio then
            EngineAPI.debug.log("AudioSettings.init 失败（音量不可调，但不影响启动）")
        end
    end
    
    SetGlobal()
    EngineAPI.debug.log("SetGlobal done")
    
    GenTalkIdx()
    EngineAPI.debug.log("GenTalkIdx done")
    
    SetModify()
    EngineAPI.debug.log("SetModify done")
    
    -- 禁止访问全程变量
    setmetatable(_G, {
        __newindex = function(_, n)
            error("attempt read write to undeclared variable " .. n, 2)
        end,
        __index = function(_, n)
            error("attempt read read to undeclared variable " .. n, 2)
        end,
    })
    
    EngineAPI.debug.log("JY_Main start.")
    
    math.randomseed(os.time())
    
    EngineAPI.input.enableKeyRepeat(CONFIG.KeyRepeatDelay, CONFIG.KeyRepeatInterval)
    
    JY.Status = getStateId("GAME_START")
    
    EngineAPI.sprite.initSprites(CC.PaletteFile)

    -- 注册游戏逻辑钩子（port-script-decoupling）
    --
    -- framework 不硬依赖 script 层的 GetMyPic / AddMyCurrentPic /
    -- SceneCanPass / Cls 的"按状态重绘"部分。这里在启动时把 script 实现的
    -- 真实函数注入进去 —— 这是**唯一**知道 script 层存在的地方。
    --
    -- 注意：本处必须在 jymain.lua 已 require 之后执行（全局函数才存在）。
    do
        local okHooks, GameHooks = pcall(require, "framework.game_hooks")
        if okHooks and GameHooks then
            GameHooks.register({
                getMyPic        = rawget(_G, "GetMyPic"),
                addMyCurrentPic = rawget(_G, "AddMyCurrentPic"),
                sceneCanPass    = rawget(_G, "SceneCanPass"),
                -- clearBackground：复刻 script 层 Cls 的「按状态重绘」那一半
                --
                -- script 的 Cls 不只清屏：它按 JY.Status 决定重绘什么。
                -- 这段逻辑读 JY.Status（游戏状态）与 JY.Base（玩家坐标），
                -- 属于游戏逻辑，所以放这里注入而不是搬进 framework。
                clearBackground = function()
                    local EA = rawget(_G, "EngineAPI")
                    local st = rawget(_G, "JY") and rawget(_G, "JY").Status
                    local GAME_START = getStateId("GAME_START")
                    local GAME_MMAP  = getStateId("GAME_MMAP")
                    local GAME_SMAP  = getStateId("GAME_SMAP")
                    local GAME_WMAP  = getStateId("GAME_WMAP")
                    local GAME_DEAD  = rawget(_G, "GAME_DEAD") or 6

                    if st == GAME_START then
                        if EA and EA.render then
                            pcall(EA.render.fillRect, 0, 0, 0, 0, 0)
                        end
                        if EA and EA.sprite then
                            pcall(EA.sprite.drawPictureFile, CC.FirstFile, -1, -1)
                        end
                    elseif st == GAME_MMAP then
                        if EA and EA.map then
                            local gp = rawget(_G, "GameHooks")
                            local pic = gp and gp.getMyPic() or nil
                            if pic == nil then
                                local okG, g = pcall(require, "framework.game_hooks")
                                if okG and g then pic = g.getMyPic() end
                            end
                            pcall(EA.map.drawMain, JY.Base["人X"], JY.Base["人Y"], pic or 0)
                        end
                    elseif st == GAME_SMAP then
                        -- 场景地图的重绘在 script 层（DrawSMap），暂不注入，
                        -- 返回 false 让 facade 走退化路径（黑屏 + 不崩）
                        return false
                    elseif st == GAME_WMAP then
                        return false
                    elseif st == GAME_DEAD then
                        if EA and EA.render then
                            pcall(EA.render.fillRect, 0, 0, 0, 0, 0)
                        end
                        if EA and EA.sprite then
                            pcall(EA.sprite.drawPictureFile, CC.DeadFile, -1, -1)
                        end
                    end
                    return true
                end,
            })
        end
    end

    -- 注册游戏状态
    GameStates.registerAll()
    
    -- 切换到开始菜单状态
    EventBridge.getInstance():switchState(getStateId("GAME_START"))
    
    -- 显示开始菜单（使用协程版本的菜单）
    JYMainAdapter.showStartMenuCoroutine()
    
    isInitialized = true
    EngineAPI.debug.log("JYMainAdapter.initCoroutine completed")
end

--- 按菜单真实宽度求水平居中位置（REQ-MS2-13）
--
-- 为什么必须逐个菜单算：菜单宽度由最长项文本决定（isBox=0 时）。
-- 「离开游戏」是 128px，而「音乐音量」/「鼠标操作    关」是 224px ——
-- 若所有子菜单都沿用开始菜单的 menux，宽菜单会向右溢出，
-- 视觉上明显偏左（用户实测报告）。
--
-- @param items table 菜单项数组
-- @param size number 字号
-- @return number menux
function JYMainAdapter.centeredMenuX(items, size)
    local TextBoxLayout = require("framework.text_box_layout")
    local maxW = 0
    for _, it in ipairs(items or {}) do
        local text = type(it) == "table" and it[1] or it
        if type(text) == "string" then
            local w = TextBoxLayout.textWidth(text, size)
            if w > maxW then maxW = w end
        end
    end
    local menuW = maxW + 2 * CC.MenuBorderPixel
    local x = math.floor((CC.ScreenW - menuW) / 2)
    if x < 0 then x = 0 end
    return x
end

-- 显示开始菜单（协程版本）
function JYMainAdapter.showStartMenuCoroutine()
    local scheduler = CoroutineScheduler.getInstance()
    
    EngineAPI.audio.playVideo(CONFIG.DataPath .. "start.mpg", VK_ESCAPE)
    
    RenderFacade.clearScreen()
    
    PlayMIDI(16)
    EngineAPI.render.present()
    
    local menu = {
        {"重新开始", nil, 1},
        {"载入进度", nil, 1},
        {"设置",     nil, 1},
        {"离开游戏", nil, 1}
    }
    -- 水平居中：用真实宽度（见 centeredMenuX 注释）
    local menux = JYMainAdapter.centeredMenuX(menu, CC.StartMenuFontSize)
    
    -- align="center"：开始菜单的 4 项里「设置」只有 2 字，另 3 项 4 字。
    -- 框宽由最长项（4 字）决定并已水平居中，但每项文本默认**左对齐**，
    -- 于是「设置」左边贴框、右边空 64px —— 用户看到的「设置还是左对齐」。
    -- 传 center 让每项文本在框内居中（4 字项本来就正好填满，位置不变）。
    local menuReturn = MenuAsync.ShowMenuCoroutine(menu, 4, 0, menux, CC.StartMenuY, 0, 0, 0, 0, CC.StartMenuFontSize, C_STARTMENU, C_RED, "center")
    
    if menuReturn == 1 then
        JYMainAdapter.startNewGame(menux)
    elseif menuReturn == 2 then
        JYMainAdapter.loadGame()
    elseif menuReturn == 3 then
        JYMainAdapter.showSettingsCoroutine(menux)
    elseif menuReturn == 4 then
        JY.Status = getStateId("GAME_END")
        EngineAPI.app.quit()
    end
end

--------------------------------------------------------------------
-- 鼠标处理（REQ-MS2-1 ~ REQ-MS2-3）
--
-- 分工：
--   右键 → 呼出菜单（只在 MMAP/SMAP，且继承既有的输入屏蔽条件）
--   左键 → 交给 menu_state_machine 做命中测试与点击分发
--
-- 两个入口都先查 MouseMenu.isEnabled()：开关关闭时全程 no-op。
--------------------------------------------------------------------

local mouseHandlingInstalled = false

-- 上一帧的鼠标位置（供 pollHover 判断「鼠标是否真的移动过」）
local lastHoverX, lastHoverY = -1, -1

--- 对话显示中：把鼠标点击转成「推进」按键（REQ-MS2-6）
--
-- 判定条件（任一为真即认为在等玩家推进对话）：
--   ① TalkAsync.getCurrentTalk() ~= nil       打字机对话
--   ② AsyncDialog:getCurrentDialog() ~= nil   消息框/是否框/输入框
--
-- 注入 VK_SPACE（不是 VK_RETURN）：两条等待路径都接受空格；
-- 而 async_dialog 的 input 类型只认 VK_RETURN 提交、空格会进字符缓冲，
-- 所以那种情况不注入（避免把空格打进输入框）。
--
-- @return boolean 是否注入了按键
--- 注入一个「任意键」到模态 UI（左键用）
--
-- 场景名提示的语义是「按任意键关闭」，所以左键应该和键盘一样能关掉它。
-- 用 VK_SPACE：在 item/status/scene_name 这三个界面里，
-- SPACE 都不会触发破坏性操作（item 的 SPACE 是「确认选中物品」，
-- 但那条路径在左键点击时本来也不该被触发 —— 所以 item 排除）。
--
-- @return boolean 是否注入了
function JYMainAdapter.injectAnyKeyForModal()
    local okIM, InputManager = pcall(require, "framework.input_manager")
    if not okIM or not InputManager or not InputManager.enqueueKeyEvent then
        return false
    end
    local vkSpace = rawget(_G, "VK_SPACE") or 32

    -- 场景名提示：任意点击/按键都消失
    local okSN, SceneNameAsync = pcall(require, "framework.scene_name_async")
    if okSN and SceneNameAsync and SceneNameAsync.isActive then
        local okA, active = pcall(SceneNameAsync.isActive)
        if okA and active then
            InputManager.enqueueKeyEvent(vkSpace)
            -- 同时入动作队列（ADR-3：带 source，消费方可判来源）
            if InputManager.enqueueAction then
                InputManager.enqueueAction({ action = "ui.accept", source = "mouse" })
            end
            return true
        end
    end

    -- 人物状态页：左键吃掉（翻页由 injectEscapeForModal 之外的专门函数处理，
    -- 见 handleStatusClickForMouse）
    local okPS, PersonStatusAsync = pcall(require, "framework.person_status_async")
    if okPS and PersonStatusAsync and PersonStatusAsync.isActive then
        local okA, active = pcall(PersonStatusAsync.isActive)
        if okA and active then
            return true
        end
    end

    return false
end

--- 每帧轮询鼠标悬停（REQ-MS2-11）
--
-- 为什么用「每帧轮询」而不是 love.mousemoved 回调：
--   悬停效果必须与鼠标真实位置一致。回调只在移动时触发，
--   若悬停期间菜单滚动/换页，光标位置变了但鼠标没动 —— 回调不会来，
--   悬停指示就停在错误的位置。轮询天然免疫这种情况。
--
-- 成本：每帧一次 hitItem（纯算术，几十次比较）。菜单/物品格数量都在
-- 个位数到几十，可忽略。
--
-- 只在「有菜单」或「物品清单开着」时工作 —— 地图上的悬停菱形
-- 走的是 MouseHover（另一条路径，见 event_bridge 的 hoverOverlay）。
function JYMainAdapter.pollHover()
    if not MouseMenu.isEnabled() then
        return
    end

    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.input and EngineAPI.input.mousePosition) then
        return
    end
    local okPos, mx, my = pcall(EngineAPI.input.mousePosition)
    if not okPos or type(mx) ~= "number" or mx < 0 then
        return
    end

    -- **只在鼠标真的移动过时才处理悬停**（用户实测 bug）
    --
    -- 不加这个判断的后果：鼠标停在某个物品上不动，然后按方向键换一项，
    -- 下一帧 pollHover 又把选中项拉回鼠标所指的位置 —— 键盘完全失效。
    --
    -- 语义应该是：「鼠标移到这里了」才夺走焦点；鼠标没动时，
    -- 焦点归键盘。这也是绝大多数桌面 UI 的惯例。
    --
    -- 判定用整数像素比较：亚像素抖动（触摸板/高 DPI）不至于反复夺权。
    if mx == lastHoverX and my == lastHoverY then
        return
    end
    lastHoverX, lastHoverY = mx, my

    -- ① 对话框（是/否、选择框）：悬停挪选项光标
    --
    -- 必须排在物品/菜单之前：对话框是最后画、盖在最上面的，
    -- 悬停判定也该按这个层级来。
    local okAD, AsyncDialog = pcall(require, "framework.async_dialog")
    if okAD and AsyncDialog then
        local okInst, inst = pcall(AsyncDialog.getInstance)
        if okInst and inst and inst.getCurrentDialog then
            local okCur, dlg = pcall(inst.getCurrentDialog, inst)
            if okCur and dlg ~= nil then
                if inst.handleMouseHover then
                    pcall(inst.handleMouseHover, inst, mx, my)
                end
                return      -- 对话框开着时，下层 UI 不响应悬停
            end
        end
    end

    -- ② 物品清单：悬停挪选中框（与键盘方向键效果一致）
    local okItem, ItemAsync = pcall(require, "framework.item_async")
    if okItem and ItemAsync and ItemAsync.isActive and ItemAsync.handleMouseHover then
        local okA, active = pcall(ItemAsync.isActive)
        if okA and active then
            pcall(ItemAsync.handleMouseHover, mx, my)
            return
        end
    end

    -- ②-b 战斗中：悬停挪光标（REQ-MS4-1）
    local okBM, BattleMouse = pcall(require, "framework.battle_mouse")
    if okBM and BattleMouse and BattleMouse.hoverTo then
        local okB, moved = pcall(BattleMouse.hoverTo, mx, my)
        if okB and moved then
            return      -- 战斗中不再往下走（地图悬停菱形不适用）
        end
        -- 即使没移动，也不该落到地图悬停逻辑（战斗中没有地图菱形）
        local okCan = BattleMouse.canOperate and BattleMouse.canOperate()
        if okCan then return end
    end

    -- ③ 菜单：悬停挪光标（含多级菜单 —— 只有 activeMenu 会响应）
    local okMSM, MSM = pcall(require, "framework.menu_state_machine")
    if okMSM and MSM then
        local msm = MSM.getInstance()
        -- 同样跳过 EXECUTING：那种菜单屏幕上看不见逻辑上前台是回调
        if msm and msm.activeMenu
            and msm.activeMenu.state ~= "executing" and msm.hoverAt then
            pcall(msm.hoverAt, msm, mx, my)
        end
    end
end

--- 把左键点击交给人物状态页（REQ-MS2-10）
-- @param mx, my number 屏幕坐标
-- @return boolean 是否处理了
function JYMainAdapter.clickStatusForMouse(mx, my)
    local okPS, PersonStatusAsync = pcall(require, "framework.person_status_async")
    if not okPS or not PersonStatusAsync then return false end
    if not PersonStatusAsync.isActive or not PersonStatusAsync.handleMouseClick then
        return false
    end

    local okA, active = pcall(PersonStatusAsync.isActive)
    if not okA or not active then return false end

    pcall(PersonStatusAsync.handleMouseClick, mx, my)
    return true
end

--- 把左键点击交给物品清单网格（REQ-MS2-9）
--
-- 物品清单是 `while true do WaitKey() end` 的协程，无法从外部让它返回。
-- 采用「记录意图 + 注入唤醒键」的模式（与 SceneNameAsync 一致）：
--   handleMouseClick 负责命中测试并记下 pendingItemAction
--   协程在循环开头先消费 pending，再做键盘处理
--
-- @param mx, my number 屏幕坐标
-- @return boolean 是否处理了
function JYMainAdapter.clickItemForMouse(mx, my)
    local okItem, ItemAsync = pcall(require, "framework.item_async")
    if not okItem or not ItemAsync then return false end
    if not ItemAsync.isActive or not ItemAsync.handleMouseClick then return false end

    local okA, active = pcall(ItemAsync.isActive)
    if not okA or not active then return false end

    pcall(ItemAsync.handleMouseClick, mx, my)
    return true
end

--- 注入一个 ESC 等价键（关闭当前模态 UI）
--
-- 用于「右键 = ESC」的统一语义（用户需求 REQ-MS2-8）。
--
-- 这些界面都是「协程挂起等键」，注入 VK_ESCAPE 就能让它们走自己的
-- 取消分支 —— 不需要给每个模块写鼠标专用代码。
--
-- 注意顺序：**先判模态 UI，再判菜单**。
-- 因为菜单是「最后画的」，但模态 UI 可能盖在它上面。
--
-- @return boolean 是否注入了
function JYMainAdapter.injectEscapeForModal()
    local okIM, InputManager = pcall(require, "framework.input_manager")
    if not okIM or not InputManager or not InputManager.enqueueKeyEvent then
        return false
    end
    local vkEsc = rawget(_G, "VK_ESCAPE") or 27

    -- 物品选择界面
    local okItem, ItemAsync = pcall(require, "framework.item_async")
    if okItem and ItemAsync and ItemAsync.isActive then
        local okA, active = pcall(ItemAsync.isActive)
        if okA and active then
            InputManager.enqueueKeyEvent(vkEsc)
            return true
        end
    end

    -- 人物状态页
    local okPS, PersonStatusAsync = pcall(require, "framework.person_status_async")
    if okPS and PersonStatusAsync and PersonStatusAsync.isActive then
        local okA, active = pcall(PersonStatusAsync.isActive)
        if okA and active then
            InputManager.enqueueKeyEvent(vkEsc)
            return true
        end
    end

    -- 场景名提示（任意点击/按键都消失）
    local okSN, SceneNameAsync = pcall(require, "framework.scene_name_async")
    if okSN and SceneNameAsync and SceneNameAsync.isActive then
        local okA, active = pcall(SceneNameAsync.isActive)
        if okA and active then
            InputManager.enqueueKeyEvent(vkEsc)
            return true
        end
    end

    return false
end

--- 把鼠标点击交给 AsyncDialog（是/否框、选择框、消息框）
--
-- 与 injectAdvanceKeyForMouse 的分工：
--   本函数处理「有明确选项位置」的对话框（需要知道点在哪一行）
--   injectAdvanceKeyForMouse 处理「点哪都一样」的打字机对话
--
-- @param mx, my number 屏幕坐标
-- @return boolean 是否处理了
function JYMainAdapter.clickDialogForMouse(mx, my)
    local okAD, AsyncDialog = pcall(require, "framework.async_dialog")
    if not okAD or not AsyncDialog then return false end

    local okInst, inst = pcall(AsyncDialog.getInstance)
    if not okInst or not inst then return false end
    if not inst.getCurrentDialog then return false end

    local okCur, dlg = pcall(inst.getCurrentDialog, inst)
    if not okCur or dlg == nil then return false end

    if inst.handleMouseClick then
        local okClick = pcall(inst.handleMouseClick, inst, mx, my)
        if okClick then return true end
    end
    return false
end

function JYMainAdapter.injectAdvanceKeyForMouse(_, useEsc)
    -- ① 打字机对话
    local okTalk, TalkAsync = pcall(require, "framework.talk_async")
    if okTalk and TalkAsync and TalkAsync.getCurrentTalk then
        local okGet, cur = pcall(TalkAsync.getCurrentTalk)
        if okGet and cur ~= nil then
            local okIM, InputManager = pcall(require, "framework.input_manager")
            if okIM and InputManager and InputManager.enqueueKeyEvent then
                -- 左键 → SPACE（继续/翻页）；右键 → ESC（跳过/结束）
                local key
                if useEsc then
                    key = rawget(_G, "VK_ESCAPE") or 27
                else
                    key = rawget(_G, "VK_SPACE") or 32
                end
                InputManager.enqueueKeyEvent(key)
                return true
            end
        end
    end

    -- ② AsyncDialog 由 clickDialogForMouse 处理（它需要坐标），
    --    这里只管「点哪都一样」的打字机对话。
    return false
end

--- 每帧驱动虚拟手柄（input-action-layer Task 6）
--
-- 只在设置开着且引擎有触摸能力时工作。
--
-- 触摸点 → 按钮命中 → 产出**动作事件**（走 InputManager.enqueueAction）。
-- 与鼠标走同一条动作通道，所以消费方不需要区分「虚拟手柄」和「鼠标」——
-- 它们都带 source（"touch" vs "mouse"），需要区分时再判 source。
--
-- @return boolean 是否处理了触摸
function JYMainAdapter.pollVirtualPad()
    local okVP, VirtualPad = pcall(require, "framework.virtual_pad")
    if not okVP or not VirtualPad then return false end
    if not VirtualPad.isEnabled() then return false end

    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.input and EngineAPI.input.getTouches) then
        return false
    end

    local okCap, caps = pcall(EngineAPI.input.getCapabilities)
    if not okCap or not caps or not caps.touch then return false end

    local okW, sw = pcall(EngineAPI.render.getWidth)
    local okH, sh = pcall(EngineAPI.render.getHeight)
    if not okW or not okH or type(sw) ~= "number" or type(sh) ~= "number" then
        return false
    end

    local okT, touches = pcall(EngineAPI.input.getTouches)
    if not okT or type(touches) ~= "table" then return false end

    local okIM, InputManager = pcall(require, "framework.input_manager")
    if not okIM or not InputManager or not InputManager.enqueueAction then
        return false
    end

    local now = 0
    pcall(function()
        local okTime, t = pcall(EngineAPI.time.getTimeSeconds)
        if okTime and type(t) == "number" then now = t end
    end)

    local fired = VirtualPad.update(touches, sw, sh, now, function(action, touchId)
        InputManager.enqueueAction({
            action = action, source = "touch", index = touchId,
        })
    end)

    -- 绘制放在这里（与逻辑同帧，保证按钮显隐与命中区一致）
    pcall(VirtualPad.draw, sw, sh)

    return fired > 0 or #touches > 0
end

--- 消费一个鼠标事件（由 EventBridge 的 update 每帧调用，或在 update 内轮询）
-- @return boolean 是否消费了事件
function JYMainAdapter.pollMouse()
    if not MouseMenu.isEnabled() then
        return false
    end

    local InputManager = require("framework.input_manager")
    local ev = InputManager.getMouseEvent()
    if not ev then return false end

    -- 只处理「按下」，忽略 released（当前不需要）
    if ev.type ~= "pressed" then
        return true
    end

    local MenuAsync = require("framework.menu_async")

    -- ---- 右键：ESC 的等价物（REQ-MS2-8）----
    --
    -- 需求：右键「不管什么情况都等同于 ESC」——
    --   菜单打开时 → 逐层返回（先关子菜单，再关父菜单）
    --   模态 UI 显示时 → 关闭它（物品清单 / 状态页 / 场景名 / 对话框）
    --   什么都没有时 → 呼出主菜单（等价 ESC 在地图上的效果）
    --
    -- 为什么不复用左键的推进逻辑：
    --   左键在对话里是「确认/继续」（SPACE），右键是「取消/返回」（ESC）。
    --   两者在最常见场景（是/否框）里结果相反：SPACE=选是，ESC=选否。
    if ev.button == 2 then
        -- ① 有菜单 → 逐层返回（等价菜单里的 ESC）
        local MSM = require("framework.menu_state_machine")
        local msm = MSM.getInstance()
        if msm.activeMenu then
            -- **必须尊重 menu.isEsc**，与 handleInput 的 ESC 分支逐字一致：
            --     if key == VK_ESCAPE and menu.isEsc == 1 then closeMenu(0) end
            -- 若这里无条件关闭，右键就能关掉键盘 ESC 关不掉的菜单
            -- （强制选择类菜单 isEsc==0），两条输入路径行为不一致。
            if msm.activeMenu.isEsc == 1 then
                msm:closeMenu(0)
            end
            return true     -- 无论能否关闭都吃掉这次点击
        end

        -- ①-b 战斗中：右键取消当前选择（等价 ESC）
        local okBM, BattleMouse = pcall(require, "framework.battle_mouse")
        if okBM and BattleMouse and BattleMouse.cancel then
            local okB, handled = pcall(BattleMouse.cancel)
            if okB and handled then return true end
        end

        -- ② 有模态 UI（物品/状态/场景名）→ 注入 ESC 让它自己退出
        if JYMainAdapter.injectEscapeForModal() then
            return true
        end

        -- ③ 有对话框（是否框/选择框/消息框）→ ESC 语义
        local okAD, AsyncDialog = pcall(require, "framework.async_dialog")
        if okAD and AsyncDialog then
            local okInst, inst = pcall(AsyncDialog.getInstance)
            if okInst and inst and inst.getCurrentDialog then
                local okG, d = pcall(inst.getCurrentDialog, inst)
                if okG and d ~= nil then
                    -- 走 AsyncDialog 自己的取消语义（与 ESC 完全一致）
                    if inst.handleEscape then
                        inst:handleEscape()
                    else
                        inst:closeDialog(nil)
                    end
                    return true
                end
            end
        end

        -- ④ 打字机对话 → ESC 跳过/结束（talk 的等键也认 ESC）
        if JYMainAdapter.injectAdvanceKeyForMouse(nil, true) then
            return true
        end

        -- ⑤ 什么都没开 → 呼出主菜单（与键盘 ESC 在 MMAP/SMAP 上的效果一致）
        local okAM, AutoMove = pcall(require, "framework.auto_move")
        if not okAM or not AutoMove or not AutoMove.canPlayerAct() then
            return true
        end

        JYMainAdapter.requestMenu()
        return true
    end

    -- ---- 左键 ----
    if ev.button == 1 then
        -- ① 有菜单 → 菜单点击
        --
        -- **但要跳过「回调执行中」的菜单**（用户实测 bug）：
        -- 韦大宝选「地下市场」后，回调 Menu_Shop 在独立协程里跑 TalkEx，
        -- 此时 activeMenu 仍在（state=EXECUTING）。若把点击交给菜单，
        -- handleMouseClick 会直接吞掉它（EXECUTING 期间不接受点击），
        -- 于是对话无法用鼠标推进 —— 而键盘能推进（走 scheduler，不经菜单）。
        --
        -- 正确顺序：EXECUTING 的菜单只管轮询回调，点击继续往下走给对话。
        local MSM = require("framework.menu_state_machine")
        local msm = MSM.getInstance()
        if msm.activeMenu and msm.activeMenu.state ~= "executing" then
            msm:handleMouseClick(ev.x, ev.y)
            return true
        end

        -- ①-a 物品清单：点击格子 = 选中并使用该物品（REQ-MS2-9）
        --
        -- 必须排在「注入任意键」之前：物品清单里点击是「选中第 N 个」，
        -- 不是「随便按个键确认当前项」。
        if JYMainAdapter.clickItemForMouse(ev.x, ev.y) then
            return true
        end

        -- ①-b 人物状态页：点击框内 = 翻下一页（循环）
        if JYMainAdapter.clickStatusForMouse(ev.x, ev.y) then
            return true
        end

        -- ①-c 场景名等模态 UI：左键等价「任意键」
        if JYMainAdapter.injectAnyKeyForModal() then
            return true
        end

        -- ② 对话显示中
        --
        -- 分两类处理，不能一律注入 SPACE：
        --   AsyncDialog（消息框/是否框/选择框）→ 走 handleMouseClick
        --       原因：SPACE 语义是「确认当前选项」，而默认选中的是「是」。
        --       一律注入 SPACE 会导致点「否」也变成「是」（用户实测 bug）。
        --   TalkAsync（打字机对话）→ 注入 SPACE（语义就是「翻页/继续」）
        if JYMainAdapter.clickDialogForMouse(ev.x, ev.y) then
            return true
        end
        if JYMainAdapter.injectAdvanceKeyForMouse() then
            return true
        end

        -- ②-b 战斗中：驱动光标（REQ-MS4-1）
        --
        -- 战斗有自己的光标选择系统（WAR.MoveCursorX/Y + DrawMode），
        -- 与地图寻路完全是两套逻辑。canPlayerAct 会在战斗中返回 false
        -- （它要求 MMAP/SMAP），所以战斗必须单独接一条路径。
        local okBM, BattleMouse = pcall(require, "framework.battle_mouse")
        if okBM and BattleMouse and BattleMouse.clickAt then
            local okB, handled = pcall(BattleMouse.clickAt, ev.x, ev.y)
            if okB and handled then return true end
        end

        -- ③ 无菜单无对话 → 点击地图寻路（REQ-MS3-3）
        local GameStates = require("framework.game_states")
        if GameStates and GameStates._handleMapClick then
            local ok, handled = pcall(GameStates._handleMapClick, ev.x, ev.y)
            if ok and handled then return true end
        end
        return false
    end

    return true
end

--- 请求呼出主菜单（等价 ESC）
--
-- 不直接调 MMenuCoroutine，而是走与键盘 ESC 相同的入口，
-- 保证两条路径的行为完全一致（含菜单栈、disableInput 等）。
function JYMainAdapter.requestMenu()
    local GameStates = require("framework.game_states")
    if GameStates and GameStates.requestMainMenu then
        GameStates.requestMainMenu()
    end
end

--- 安装鼠标处理（幂等）
--
-- 把 pollMouse 接到 EventBridge 的 update 钩子上。
-- 之所以不用 love.mousepressed 直接处理：菜单命中需要每帧一致的
-- 输入上下文（disableInput、hasActiveMenu 等），走队列 + 每帧消费更稳。
function JYMainAdapter.installMouseHandling()
    if mouseHandlingInstalled then return true end
    local ok = pcall(function()
        local EventBridge = require("framework.event_bridge")
        EventBridge.setMousePollHook(function()
            -- 虚拟手柄先于鼠标：它在 Android 上是主输入通道
            local okPad = pcall(JYMainAdapter.pollVirtualPad)
            if not okPad then
                EngineAPI.debug.log("pollVirtualPad 抛错（不影响主循环）")
            end
            -- 先消费点击（离散事件），再更新悬停（连续状态）
            local okPoll = pcall(JYMainAdapter.pollMouse)
            if not okPoll then
                EngineAPI.debug.log("pollMouse 抛错（不影响主循环）")
            end
            local okHover = pcall(JYMainAdapter.pollHover)
            if not okHover then
                EngineAPI.debug.log("pollHover 抛错（不影响主循环）")
            end
        end)
        -- 悬停高亮（REQ-MS3-1）：位置 ①，StateMachine:draw() 之后
        EventBridge.setHoverOverlay(function()
            local okHover, MouseHover = pcall(require, "framework.mouse_hover")
            if okHover and MouseHover and MouseHover.draw then
                MouseHover.draw()
            end
        end)
    end)
    mouseHandlingInstalled = ok
    return ok
end

--- 开始菜单的「设置」子菜单（REQ-MENU-3）
--
-- 结构与大地的「系统」并列，不重复：
--   设置 → 音乐音量 → 值调节界面
--        → 音效音量 → 值调节界面
--
-- 选完音量后回到设置菜单（而非直接回开始菜单），方便连续调两项。
function JYMainAdapter.showSettingsCoroutine(menux)
    -- REQ-MS2-4：鼠标开关插在音效之后、「返回」之前
    local menu = {
        {"音乐音量", nil, 1},
        {"音效音量", nil, 1},
        MouseMenu.buildToggleItem(),
        {"返回",     nil, 1},
    }

    -- 设置菜单比开始菜单宽（「音乐音量」224px vs 「离开游戏」128px），
    -- 不能沿用 menux，否则视觉上偏左（用户实测）
    local myX = JYMainAdapter.centeredMenuX(menu, CC.StartMenuFontSize)

    local r = MenuAsync.ShowMenuCoroutine(menu, 4, 0, myX, CC.StartMenuY,
        0, 0, 0, 0, CC.StartMenuFontSize, C_STARTMENU, C_RED)

    if r == 1 then
        JYMainAdapter.showVolumeCoroutine(AudioSettings.MUSIC_KEY, "音乐音量", menux)
        -- 返回设置菜单
        JYMainAdapter.showSettingsCoroutine(menux)
    elseif r == 2 then
        JYMainAdapter.showVolumeCoroutine(AudioSettings.SFX_KEY, "音效音量", menux)
        JYMainAdapter.showSettingsCoroutine(menux)
    elseif r == 3 then
        -- 鼠标开关已在回调里切换，回到设置菜单继续操作
        JYMainAdapter.showSettingsCoroutine(menux)
    else
        -- 选「返回」或按 ESC：回到开始菜单
        JYMainAdapter.showStartMenuCoroutine()
    end
end

--- 音量值调节界面（第 3 层）
--
-- 上下键只改待定值、确认键提交，逻辑在 menu_state_machine 的值项分支里。
-- 本函数只负责构建菜单并（值真的变了时）落盘。
function JYMainAdapter.showVolumeCoroutine(key, label, menux)
    local before = Settings.get(key)
    local items = AudioMenu.buildValueMenu(key, label)

    -- 参数顺序：menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, ...
    --
    -- **isBox=1 / isEsc=1 是必须的**（用户实测：右键点不进、菜单关不掉）。
    -- 之前这里传的是 0, 0，而 pollMouse 的右键分支判的是
    --     if msm.activeMenu.isEsc == 1 then msm:closeMenu(0) end
    -- isEsc=0 → 右键被吞但菜单不动，等于「右键无响应」。
    -- 而 jymain_async.Menu_AudioVolume 的同名功能传的是 1, 1，
    -- 两条路径行为不一致。
    --
    -- isBox=1 还有一层作用：值项菜单只有一项，画个框才看得出边界。
    MenuAsync.ShowMenuCoroutine(items, 1, 0, menux, CC.StartMenuY,
        0, 0, 1, 1, CC.StartMenuFontSize, C_STARTMENU, C_RED)

    if Settings.get(key) ~= before then
        local ok, err = Settings.save()
        if not ok and EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
            EngineAPI.debug.log("showVolumeCoroutine: Settings.save 失败: " .. tostring(err))
        end
    end
end

-- 属性随机范围定义（用于判断是否为当前随机最大值）
local ATTRIBUTE_RANGES = {
    ["内力最大值"] = {min = 21, max = 40},  -- Rnd(20) + 21 (21-40)
    ["攻击力"] = {min = 21, max = 30},      -- Rnd(10) + 21 (21-30)
    ["防御力"] = {min = 21, max = 30},      -- Rnd(10) + 21 (21-30)
    ["轻功"] = {min = 21, max = 30},        -- Rnd(10) + 21 (21-30)
    ["医疗能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["用毒能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["解毒能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["拳掌功夫"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["御剑能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["耍刀技巧"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["暗器技巧"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["生命增长"] = {min = 3, max = 7},      -- Rnd(5) + 3 (3-7)
    ["生命最大值"] = {min = 38, max = 50},  -- 生命增长(3-7) * 3 + 29 = 38-50
    ["资质"] = {
        tiers = {
            {min = 30, max = 64},   -- 30-64 (20%概率: Rnd(35)+30)
            {min = 60, max = 79},   -- 60-79 (60%概率: Rnd(20)+60)
            {min = 75, max = 94}    -- 75-94 (20%概率: Rnd(20)+75)
        }
    }
}

-- 获取属性的当前随机范围最大值
local function getAttributeMaxRandomValue(attrKey, value)
    local range = ATTRIBUTE_RANGES[attrKey]
    if not range then
        return nil
    end
    
    -- 资质特殊处理，根据当前值判断属于哪个档次
    if attrKey == "资质" then
        for _, tier in ipairs(range.tiers) do
            if value >= tier.min and value <= tier.max then
                return tier.max
            end
        end
        return 94  -- 默认最大值
    end
    
    return range.max
end

-- 生成随机属性
local function generateRandomAttributes()
    JY.Person[0]["内力性质"] = Rnd(2)
    JY.Person[0]["内力最大值"] = Rnd(20) + 21
    JY.Person[0]["攻击力"] = Rnd(10) + 21
    JY.Person[0]["防御力"] = Rnd(10) + 21
    JY.Person[0]["轻功"] = Rnd(10) + 21
    JY.Person[0]["医疗能力"] = Rnd(10) + 21
    JY.Person[0]["用毒能力"] = Rnd(10) + 21
    JY.Person[0]["解毒能力"] = Rnd(10) + 21
    JY.Person[0]["抗毒能力"] = Rnd(10) + 21
    JY.Person[0]["拳掌功夫"] = Rnd(10) + 21
    JY.Person[0]["御剑能力"] = Rnd(10) + 21
    JY.Person[0]["耍刀技巧"] = Rnd(10) + 21
    JY.Person[0]["特殊兵器"] = Rnd(10) + 21
    JY.Person[0]["暗器技巧"] = Rnd(10) + 21
    JY.Person[0]["生命增长"] = Rnd(5) + 3
    JY.Person[0]["生命最大值"] = JY.Person[0]["生命增长"] * 3 + 29
    
    local rate = Rnd(10)
    if rate < 2 then
        JY.Person[0]["资质"] = Rnd(35) + 30
    elseif rate <= 7 then
        JY.Person[0]["资质"] = Rnd(20) + 60
    else
        JY.Person[0]["资质"] = Rnd(20) + 75
    end
    
    JY.Person[0]["生命"] = JY.Person[0]["生命最大值"]
    JY.Person[0]["内力"] = JY.Person[0]["内力最大值"]
end

-- 显示属性选择界面
local function showAttributeSelection()
    local fontsize = CC.NewGameFontSize
    local h = fontsize + CC.RowPixel
    local w = fontsize * 4
    local x1 = (CC.ScreenW - w * 4) / 2
    local y1 = CC.NewGameY
    
    -- 绘制属性
    -- str1: 显示名称, str2: 属性键, str3: 用于判断最大值的键, i: 列索引, y: Y坐标
    local function DrawAttrib(str1, str2, str3, i, y)
        DrawString(x1 + i * w, y, str1, C_RED, fontsize)
        
        -- 判断是否为当前随机范围的最大值，最大值用黄色显示
        local value = JY.Person[0][str2]
        local maxRandomValue = getAttributeMaxRandomValue(str3, value)
        local valueColor = C_WHITE
        
        if maxRandomValue and value >= maxRandomValue then
            valueColor = C_GOLD  -- 黄色显示当前随机范围的最大值
        end
        DrawString(x1 + i * w + fontsize * 2, y, string.format("%3d ", value), valueColor, fontsize)
    end
    
    DrawString(x1, y1, "这样的属性满意吗(Y/N)?", C_GOLD, fontsize)
    
    local i = 0
    y1 = y1 + h
    DrawAttrib("内力", "内力", "内力最大值", i, y1); i = i + 1
    DrawAttrib("攻击", "攻击力", "攻击力", i, y1); i = i + 1
    DrawAttrib("轻功", "轻功", "轻功", i, y1); i = i + 1
    DrawAttrib("防御", "防御力", "防御力", i, y1)
    
    i = 0
    y1 = y1 + h
    DrawAttrib("生命", "生命", "生命最大值", i, y1); i = i + 1
    DrawAttrib("医疗", "医疗能力", "医疗能力", i, y1); i = i + 1
    DrawAttrib("用毒", "用毒能力", "用毒能力", i, y1); i = i + 1
    DrawAttrib("解毒", "解毒能力", "解毒能力", i, y1)
    
    i = 0
    y1 = y1 + h
    DrawAttrib("拳掌", "拳掌功夫", "拳掌功夫", i, y1); i = i + 1
    DrawAttrib("御剑", "御剑能力", "御剑能力", i, y1); i = i + 1
    DrawAttrib("耍刀", "耍刀技巧", "耍刀技巧", i, y1); i = i + 1
    DrawAttrib("暗器", "暗器技巧", "暗器技巧", i, y1)
end

-- 创建属性选择绘制回调
local function createAttributeDrawCallback()
    return function()
        showAttributeSelection()
    end
end

-- 开始新游戏（异步版本）
function JYMainAdapter.startNewGame(menux)
    local tAll = PerfLog.begin("startNewGame total")
    PerfLog.mark("startNewGame begin")

    RenderFacade.clearScreen()
    DrawString(menux, CC.StartMenuY, "请稍候...", C_RED, CC.StartMenuFontSize)
    ShowScreen()
    
    -- 载入新游戏数据
    local tLoad = PerfLog.begin("startNewGame.LoadRecord(0)")
    local okLoad = LoadRecord(0)
    PerfLog.finish(tLoad, "ok=" .. tostring(okLoad))
    if not okLoad then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "新游戏基础数据缺失，无法开始", C_WHITE, CC.DefaultFont)
        EventBridge.getInstance():switchState(getStateId("GAME_START"))
        JYMainAdapter.showStartMenuCoroutine()
        return
    end
    JY.Person[0]["姓名"] = CC.NewPersonName
    
    -- 属性选择循环（异步版本）
    local satisfied = false
    while not satisfied do
        -- 生成随机属性
        generateRandomAttributes()
        
        -- 清屏并设置绘制回调
        RenderFacade.clearScreen()
        EventBridge.setGlobalDrawCallback(createAttributeDrawCallback())
        
        -- 异步菜单询问是否满意
        local menu = {
            {"是 ", nil, 1},
            {"否 ", nil, 2},
        }
        local fontsize = CC.NewGameFontSize
        local x1 = (CC.ScreenW - fontsize * 4 * 4) / 2
        local tMenu = PerfLog.begin("startNewGame.attributeMenu")
        local ok = MenuAsync.ShowMenu2Coroutine(menu, 2, 0, x1 + 11 * fontsize, CC.NewGameY - CC.MenuBorderPixel, 0, 0, 0, 1, fontsize, C_WHITE, C_RED)
        PerfLog.finish(tMenu, "choice=" .. tostring(ok))
        
        -- 清除绘制回调
        EventBridge.clearGlobalDrawCallback()
        
        if ok == 1 then
            -- 选择"是"，确认属性
            satisfied = true
        elseif ok == 0 then
            -- 按ESC键，返回到开始菜单
            EngineAPI.debug.log("startNewGame: ESC pressed, returning to start menu")
            -- 切换回开始菜单状态
            EventBridge.getInstance():switchState(getStateId("GAME_START"))
            -- 重新显示开始菜单
            JYMainAdapter.showStartMenuCoroutine()
            return
        end
        -- ok == 2 时（选择"否"），继续循环重新随机属性
    end
    
    -- 继续新游戏初始化
    JY.SubScene = CC.NewGameSceneID
    JY.Scene[JY.SubScene]["名称"] = JY.Person[0]["姓名"] .. "居"
    JY.Base["人X1"] = CC.NewGameSceneX
    JY.Base["人Y1"] = CC.NewGameSceneY
    -- 注意：不设置 JY.MyPic，让动画从第一帧开始
    -- JY.MyPic 将在动画开始时由 GAME_SMAP.update 设置
    
    EngineAPI.render.presentAndWait(50)
    
    JY.MmapMusic = -1
    
    CleanMemory()
    
    -- 设置主角初始贴图为躺着（6890/2=3445）
    -- 必须在 Init_SMap 之前设置，因为 Init_SMap 会调用 DrawSMap
    JY.MyPic = 3445  -- 躺着
    EngineAPI.debug.log("startNewGame: set initial MyPic to lying pose (3445)")
    -- 注意：不设置动画状态，让主角保持躺着姿势
    -- 动画将在事件脚本中的 instruct_27 中播放
    -- 设置 currentFrame=0 表示初始状态，GAME_SMAP.update 不会重置 JY.MyPic
    JY.AnimationState.active = false
    JY.AnimationState.currentFrame = 0
    
    -- 切换到场景状态（在事件执行前切换，确保对话期间能正确绘制场景）
    EngineAPI.debug.log("startNewGame: switching to GAME_SMAP state")
    local tSwitch = PerfLog.begin("startNewGame.switchState(GAME_SMAP)")
    EventBridge.getInstance():switchState(getStateId("GAME_SMAP"))
    PerfLog.finish(tSwitch)
    EngineAPI.debug.log("startNewGame: switched to GAME_SMAP state, JY.Status=" .. tostring(JY.Status))
    
    if CC.NewGameEvent > 0 then
        -- 关键去重：出生格 (19,20) 自带路过事件——S层3=0，且 D70[0][4]=691（即开场事件本身）。
        -- 若不抑制，主角站在出生格时 GAME_SMAP.update 的路过检查（d_pass=0 ~= OldDPass=-1）
        -- 会在下面显式 oldCallEventCoroutine(691) 之外再起一个 event_0 协程，导致开场事件
        -- 被并行执行两次（抢按键、动画/对话各播一遍），且第二个协程结束时把共享全局
        -- JY.CurrentD 复位为 -1，使 GAME_SMAP.update 的卧姿守卫失效、GetMyPic() 把卧姿
        -- 覆盖成站立（开场"前几句站着、起身动画第一帧才躺下"的根因）。
        -- 这里把 OldDPass 预设为出生格的路过值 0，复用游戏自带的路过事件去重机制
        -- （d_pass ~= OldDPass 才触发），让出生格的 691 不再二次触发——与原版单发一致。
        JY.OldDPass = 0
        EngineAPI.debug.log("startNewGame: OldDPass preset to 0 (suppress spawn-tile double-fire of NewGameEvent)")

        -- 在协程中执行新游戏事件
        -- 使用 event_executor 中的 oldCallEventCoroutine，避免 C-call boundary 问题
        local EventExecutor = require("framework.event_executor")
        local tEvent = PerfLog.begin("startNewGame.oldCallEventCoroutine")
        EventExecutor.oldCallEventCoroutine(CC.NewGameEvent)
        PerfLog.finish(tEvent, "event=" .. tostring(CC.NewGameEvent))
    end
    
    -- 事件执行完毕后，按当前方向/走路帧重算主角贴图。
    -- 原版语义：阻塞式事件结束后 MyPic 保持事件最后设置的状态（691 末尾 instruct_40(0)
    -- 已把主角转为站立方向0）。不能恢复成 CC.NewPersonPic(3445,卧姿)——那会让刚起身的
    -- 主角多显示一帧卧姿；GetMyPic() 与下一帧 GAME_SMAP.update 的计算一致，无跳变。
    JY.MyPic = GetMyPic()
    EngineAPI.debug.log("startNewGame: updated MyPic to " .. tostring(JY.MyPic) .. " after NewGameEvent")
    PerfLog.finish(tAll)
end

-- 载入游戏
function JYMainAdapter.loadGame()
    RenderFacade.clearScreen()
    local loadMenu = {
        {"进度一", nil, 1},
        {"进度二", nil, 1},
        {"进度三", nil, 1}
    }
    
    -- 同样用真实宽度居中（旧公式「假设 3 个字宽」会偏左）
    local menux2 = JYMainAdapter.centeredMenuX(loadMenu, CC.StartMenuFontSize)
    
    -- 载入进度菜单同理：档号/名字长度差异大，居中更整齐
    local r = MenuAsync.ShowMenuCoroutine(loadMenu, 3, 0, menux2, CC.StartMenuY, 0, 0, 0, 0, CC.StartMenuFontSize, C_STARTMENU, C_RED, "center")
    
    RenderFacade.clearScreen()
    DrawString(menux2, CC.StartMenuY, "请稍候...", C_RED, CC.StartMenuFontSize)
    ShowScreen()
    
    local ok = LoadRecord(r)
    
    RenderFacade.clearScreen()
    ShowScreen()
    
    if ok then
        -- 切换到首次主地图状态
        EventBridge.getInstance():switchState(getStateId("GAME_FIRSTMMAP"))
    else
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "该存档不存在或已损坏", C_WHITE, CC.DefaultFont)
        EventBridge.getInstance():switchState(getStateId("GAME_START"))
        JYMainAdapter.showStartMenuCoroutine()
    end
end

-- 更新函数（每帧调用）
function JYMainAdapter.update(dt)
    if not isInitialized then
        return
    end
    
    -- 更新节拍计数器
    JY.MyTick = JY.MyTick + 1
    JY.MyTick2 = JY.MyTick2 + 1
    
    if JY.MyTick == 20 then
        JY.MyCurrentPic = 0
        JY.MyTick = 0
    end
    
    if JY.MyTick2 == 1000 then
        JY.MyTick2 = 0
    end
    
    collectgarbage("step", 0)
end

-- 渲染函数（每帧调用）
function JYMainAdapter.draw()
    -- 渲染由状态机的draw处理
end

-- 重置适配器
function JYMainAdapter.reset()
    isInitialized = false
    initCoroutine = nil
end

return JYMainAdapter
