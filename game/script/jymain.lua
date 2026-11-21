
----------------------------------------------------------
-----------金庸群侠传复刻之Lua版----------------------------

--版权所无，敬请复制
--您可以随意使用代码

---本代码由游泳的鱼编写

local SpriteAtlas = require("framework.sprite_atlas")
-- 协程感知的「等一帧」（port-blocking-delay Task 2）
-- 事件协程里走 scheduler:waitForTime（非阻塞）；非协程上下文退回 lib.Delay。
local CoroutineScheduler = require("framework.coroutine_scheduler")
local RenderFacade = require("framework.render_facade")
local FileUtil = require "lib_file"
local ScriptLoader = require "script_loader"
-- 单行文本的框尺寸计算（引擎无关纯模块）。
-- DrawStrBox 需要按真实像素宽定框，手边又拿不到字体对象，统一走这里。
local TextBoxLayout = require("framework.text_box_layout")

--本模块是lua主模块，由C主程序JYLua.exe调用。C程序主要提供游戏需要的视频、音乐、键盘等API函数，供lua调用。
--游戏的所有逻辑都在lua代码中，以方便大家对代码的修改。
--为加快速度，显示主地图/场景地图/战斗地图部分用C API实现。

--导入其他模块。之所以做成函数是为了避免编译查错时编译器会寻找这些模块。
--- 等一帧（毫秒）——**协程感知的 lib.Delay 替代品**
--
-- @param ms number 毫秒
--
-- **为什么需要它**（port-blocking-delay Task 2）：
--   script 层的帧率控制模式是
--   ```
--   t1 = lib.GetTime(); 动作(); t2 = lib.GetTime()
--   lib.Delay(FRAME - (t2 - t1))
--   ```
--   而 `lib.Delay` = `love.timer.sleep` → **真阻塞主线程**（实测占 101ms）。
--
--   这些 `instruct_*` 实际上都在**事件协程里**跑
--   （`EventExecuteCoroutine` → `oldCallEventCoroutine` → `instruct_30`），
--   所以可以用 `scheduler:waitForTime` 把阻塞换成协作式等待。
--
-- **兼容非协程上下文**：`waitForTime` 在非协程里会 error，所以
--   `CoroutineScheduler.waitFrame` 先判 `isInCoroutine()`，不在协程里就
--   退回阻塞的 `EngineAPI.time.sleep`（不会崩，只是那一处仍阻塞）。
--
-- **为什么是全局函数而不是 local**：`script/battle/*.lua` 是全局函数定义
-- （不是 `return { ... }` 表），它们也要用这个 helper。全局是唯一可行方式。
-- 命名带 `WaitFrame` 前缀以免与游戏函数撞名。
function WaitFrame(ms)
    if ms == nil or ms <= 0 then return end
    -- fallback 走契约（不再摸全局 lib.Delay —— port-compat-layer-removal）
    --
    -- **fallback 必须是原始的 `time.sleep`，不能在闭包里再查 `EngineAPI.time.sleep`**：
    -- 事件脚本执行期间 `async_globals` 会临时覆盖 `EngineAPI.time.sleep`，
    -- 覆盖版内部又调 `waitFrame` → 若 fallback 再查契约就是无限递归。
    -- 这里先取出当前实现绑定进闭包（覆盖发生在进入脚本前，取到的是原本那版）。
    local sleep = EngineAPI.time.sleep
    CoroutineScheduler.getInstance():waitFrame(ms, function(m) sleep(m) end)
end

--- 加载贴图档案——**同时写两套系统**
-- @param idxFile string .idx 文件
-- @param grpFile string .grp 文件
-- @param archiveId number 档案编号
-- @param opts table|nil 传给 SpriteAtlas.loadArchive 的选项
--
-- **为什么必须双写**（这是 port-sprite-native-migration Task 4 的一个回归）：
--
--   `SpriteAtlas.loadArchive` 走新解码链（framework/sprite_decoder），
--   **不写** 引擎的 `picFileCache`。
--
--   而引擎自己的地图绘制函数（`lib.DrawSMap` / `lib.DrawMMap` / `lib.DrawWarMap`）
--   内部走 `JY_LoadPic` = `PicLoadCache` → 读 `picFileCache`。
--
--   所以只写 SpriteAtlas → 地图**全黑**（实测：开场小场景 + 主地图都是）。
--   而战斗没暴露是因为 `war_async` 里有双轨补丁兜住了。
--
--   要真正只写一套，前提是让 map 绘制契约透明化
--   （`port-map-render-native`），在那之前必须双写。
function LoadArchiveBoth(idxFile, grpFile, archiveId, opts)
    SpriteAtlas.loadArchive(idxFile, grpFile, archiveId, opts)
end

function IncludeFile()              --导入其他模块
    --dofile("config.lua");       --此文件在C函数中预先加载。这里就不加载了
    -- 通过 ScriptLoader 加载脚本（内部委托 EngineAPI.script.load 支持 .love 打包）
    -- 避免在脚本中直接依赖全局 love，具体加载细节由各引擎（engine-love2d 等）实现
    local jyconst_loader = ScriptLoader.load(CONFIG.ScriptPath .. "jyconst.lua")
    if jyconst_loader then
        jyconst_loader()
    else
        local fpath = CONFIG.ScriptPath .. "jyconst.lua"
        local ok = pcall(dofile, fpath)
        if not ok then
            pcall(dofile, "game/" .. fpath)
        end
    end
    local jymodify_loader = ScriptLoader.load(CONFIG.ScriptPath .. "jymodify.lua")
    if jymodify_loader then
        jymodify_loader()
    else
        local fpath = CONFIG.ScriptPath .. "jymodify.lua"
        local ok = pcall(dofile, fpath)
        if not ok then
            pcall(dofile, "game/" .. fpath)
        end
    end
end


function SetGlobal()   --设置游戏内部使用的全程变量
   JY={};

   JY.Status=GAME_INIT;  --游戏当前状态

   --保存R×数据
   JY.Base={};           --基本数据
   JY.PersonNum=0;      --人物个数
   JY.Person={};        --人物数据
   JY.ThingNum=0        --物品数量
   JY.Thing={};         --物品数据
   JY.SceneNum=0        --物品数量
   JY.Scene={};         --物品数据
   JY.WugongNum=0        --物品数量
   JY.Wugong={};         --物品数据
   JY.ShopNum=0        --商店数量
   JY.Shop={};         --商店数据

   JY.Data_Base=nil;     --实际保存R*数据
   JY.Data_Person=nil;
   JY.Data_Thing=nil;
   JY.Data_Scene=nil;
   JY.Data_Wugong=nil;
   JY.Data_Shop=nil;

   JY.MyCurrentPic=0;       --主角当前走路贴图在贴图文件中偏移
   JY.MyPic=0;              --主角当前贴图
   JY.MyTick=0;             --主角没有走路的持续帧数
   JY.MyTick2=0;            --显示事件动画的节拍

   JY.EnterSceneXY=nil;     --保存进入场景的坐标，有值可以进入，为nil则重新计算。

   JY.oldMMapX=-1;          --上次显示主地图的坐标。用来判断是否需要全部重绘屏幕
   JY.oldMMapY=-1;
   JY.oldMMapPic=-1;        --上次显示主地图主角贴图

   JY.SubScene=-1;          --当前子场景编号
   JY.SubSceneX=0;          --子场景显示位置偏移，场景移动指令使用
   JY.SubSceneY=0;

   JY.Darkness=0;             --=0 屏幕正常显示，=1 不显示，屏幕全黑

   JY.CurrentD=-1;          --当前调用D*的编号
   JY.OldDPass=-1;          --上次触发路过事件的D*编号, 避免多次触发
   JY.CurrentEventType=-1   --当前触发事件的方式 1 空格 2 物品 3 路过

   JY.oldSMapX=-1;          --上次显示场景地图的坐标。用来判断是否需要全部重绘屏幕
   JY.oldSMapY=-1;
   JY.oldSMapXoff=-1;       --上次场景偏移
   JY.oldSMapYoff=-1;
   JY.oldSMapPic=-1;        --上次显示场景地图主角贴图

   JY.D_Valid=nil           --记录当前场景有效的D的编号，提高速度，不用每次显示都计算了。若为nil则重新计算
   JY.D_Valid_Num=0;        --当前场景有效的D个数（原名误写为裸全局 JY_D_Valld_Num）

   JY.D_PicChange={}        --记录事件动画改变，以计算Clip
   JY.NumD_PicChange=0;     --事件动画改变的个数

   JY.CurrentThing=-1;      --当前选择物品，触发事件使用

   JY.MmapMusic=-1;         --切换大地图音乐，返回主地图时，如果设置，则播放此音乐

   JY.CurrentMIDI=-1;       --当前播放的音乐id，用来在关闭音乐时保存音乐id。
   JY.EnableMusic=1;        --是否播放音乐 1 播放，0 不播放
   JY.EnableSound=1;        --是否播放音效 1 播放，0 不播放

   JY.ThingUseFunction={};          --物品使用时调用函数，SetModify函数使用，增加新类型的物品
    JY.SceneNewEventFunction={};     --调用场景事件函数，SetModify函数使用，定义使用新场景事件触发的函数

    -- 事件驱动架构下的动画状态
    JY.AnimationState = {
        active = false,      -- 是否正在播放动画
        id = -1,             -- -1=主角, 其他=场景对象ID
        currentFrame = 0,    -- 当前帧
        startFrame = 0,      -- 起始帧
        endFrame = 0,        -- 结束帧
        startTime = 0,       -- 开始时间
        frameDuration = 150, -- 每帧持续时间(ms)
    }

    WAR={};     --战斗使用的全程变量。。这里占个位置，因为程序后面不允许定义全局变量了。具体内容在WarSetGlobal函数中
end

function JY_Main()        --主程序入口
    FileUtil.remove("debug.txt");        --清除以前的debug输出
    xpcall(JY_Main_sub,myErrFun);     --捕获调用错误
end

function myErrFun(err)      --错误处理，打印错误信息
    EngineAPI.debug.log(err);                 --输出错误信息
    EngineAPI.debug.log(debug.traceback());   --输出调用堆栈信息
end

function JY_Main_sub()        --真正的游戏主程序入口
    EngineAPI.debug.log("JY_Main_sub started")
    IncludeFile();         --导入其他模块
    EngineAPI.debug.log("IncludeFile done")
    SetGlobalConst();    --设置全程变量 CC, 程序使用的常量
    EngineAPI.debug.log("SetGlobalConst done")
    SetGlobal();         --设置全程变量 JY
    EngineAPI.debug.log("SetGlobal done")

    GenTalkIdx();        --生成对话 idx
    EngineAPI.debug.log("GenTalkIdx done")

    SetModify();         --设置对函数的修改，定义新的物品，事件等等
    EngineAPI.debug.log("SetModify done")

    --禁止访问全程变量
    setmetatable(_G,{ __newindex =function (_,n)
                       error("attempt read write to undeclared variable " .. n,2);
                       end,
                       __index =function (_,n)
                       error("attempt read read to undeclared variable " .. n,2);
                       end,
                     }  );
    EngineAPI.debug.log("JY_Main start.");

    math.randomseed(os.time());          --初始化随机数发生器

    EngineAPI.input.enableKeyRepeat(CONFIG.KeyRepeatDelay,CONFIG.KeyRepeatInterval);   --设置键盘重复率

    JY.Status=GAME_START;

    -- 调色板加载已移到 jymain_adapter.init → EngineAPI.sprite.initSprites(CC.PaletteFile)
    -- （原来这里是 lib.PicInit(CC.PaletteFile)；本行在死代码 JY_Main_sub 里，
    --   但为保持一致也删掉，避免"两处都在加载调色板"的误解）

    EngineAPI.audio.playVideo(CONFIG.DataPath .. "start.mpg",VK_ESCAPE);

    Cls();

    PlayMIDI(16);
    EngineAPI.render.present();

    local menu={  {"重新开始",nil,1},
                  {"载入进度",nil,1},
                  {"离开游戏",nil,1}  };
    local menux=(CC.ScreenW-4*CC.StartMenuFontSize-2*CC.MenuBorderPixel)/2

    local menuReturn=ShowMenu(menu,3,0,menux,CC.StartMenuY,0,0,0,0,CC.StartMenuFontSize,C_STARTMENU, C_RED)

    if menuReturn == 1 then        --重新开始游戏
        Cls();
        DrawString(menux,CC.StartMenuY,"请稍候...",C_RED,CC.StartMenuFontSize);
        ShowScreen();

        NewGame();          --设置新游戏数据

        JY.SubScene=CC.NewGameSceneID;         --新游戏直接进入场景
        JY.Scene[JY.SubScene]["名称"]=JY.Person[0]["姓名"] .. "居";
        JY.Base["人X1"]=CC.NewGameSceneX;
        JY.Base["人Y1"]=CC.NewGameSceneY;
        JY.MyPic=CC.NewPersonPic;

        EngineAPI.render.present()
        JY.Status=GAME_SMAP;
        JY.MMAPMusic=-1;

        CleanMemory();

        Init_SMap(0);

        if CC.NewGameEvent>0 then
           oldCallEvent(CC.NewGameEvent);
        end

    elseif menuReturn == 2 then         --载入旧的进度
        Cls();
        local loadMenu={ {"进度一",nil,1},
                         {"进度二",nil,1},
                         {"进度三",nil,1} };

        local menux=(CC.ScreenW-3*CC.StartMenuFontSize-2*CC.MenuBorderPixel)/2

        local r=ShowMenu(loadMenu,3,0,menux,CC.StartMenuY,0,0,0,0,CC.StartMenuFontSize,C_STARTMENU, C_RED)
        Cls();
        DrawString(menux,CC.StartMenuY,"请稍候...",C_RED,CC.StartMenuFontSize);
        ShowScreen();
        local ok = LoadRecord(r);
        Cls();
        ShowScreen();
        if ok then
            JY.Status=GAME_FIRSTMMAP;
        else
            DrawStrBoxWaitKey("该存档不存在或已损坏",C_WHITE,CC.DefaultFont,1);
        end

    elseif menuReturn == 3 then
        return ;
    end
    -- 清空整图缓存（原 `lib.LoadPicture("",0,0)` 的隐式副作用）
    EngineAPI.sprite.clearPictureCache();
    EngineAPI.input.getKey();
    Game_Cycle();
end

function CleanMemory()            --清理lua内存
    if CONFIG.CleanMemory==1 then
         collectgarbage("collect");
         --lib.Debug(string.format("Lua memory=%d",collectgarbage("count")));
    end
end

function NewGame()     --选择新游戏，设置主角初始属性
    local ok = LoadRecord(0); --  载入新游戏数据
    if not ok then
        DrawStrBoxWaitKey("新游戏基础数据缺失，无法开始",C_WHITE,CC.DefaultFont,1);
        return;
    end
    JY.Person[0]["姓名"]=CC.NewPersonName;

    while true do
        JY.Person[0]["内力性质"]=Rnd(2);
        JY.Person[0]["内力最大值"]=Rnd(20)+21;
        JY.Person[0]["攻击力"]=Rnd(10)+21;
        JY.Person[0]["防御力"]=Rnd(10)+21;
        JY.Person[0]["轻功"]=Rnd(10)+21;
        JY.Person[0]["医疗能力"]=Rnd(10)+21;
        JY.Person[0]["用毒能力"]=Rnd(10)+21;
        JY.Person[0]["解毒能力"]=Rnd(10)+21;
        JY.Person[0]["抗毒能力"]=Rnd(10)+21;
        JY.Person[0]["拳掌功夫"]=Rnd(10)+21;
        JY.Person[0]["御剑能力"]=Rnd(10)+21;
        JY.Person[0]["耍刀技巧"]=Rnd(10)+21;
        JY.Person[0]["特殊兵器"]=Rnd(10)+21;
        JY.Person[0]["暗器技巧"]=Rnd(10)+21;
        JY.Person[0]["生命增长"]=Rnd(5)+3;
        JY.Person[0]["生命最大值"]= JY.Person[0]["生命增长"]*3+29;

        local rate=Rnd(10);
        if rate<2 then
            JY.Person[0]["资质"]=Rnd(35)+30;
        elseif rate<=7 then
            JY.Person[0]["资质"]=Rnd(20)+60;
        else
            JY.Person[0]["资质"]=Rnd(20)+75;
        end

        JY.Person[0]["生命"]=JY.Person[0]["生命最大值"];
        JY.Person[0]["内力"]=JY.Person[0]["内力最大值"];

        Cls();

        local fontsize=CC.NewGameFontSize;

        local h=fontsize+CC.RowPixel;
        local w=fontsize*4;
        local x1=(CC.ScreenW-w*4)/2;
        local y1=CC.NewGameY;
        local i=0;

        local function DrawAttrib(str1,str2)    --定义内部函数
            DrawString(x1+i*w,y1,str1,C_RED,fontsize);
            DrawString(x1+i*w+fontsize*2,y1,string.format("%3d ",JY.Person[0][str2]),C_WHITE,fontsize);
            i=i+1;
        end

        DrawString(x1,y1,"这样的属性满意吗(Y/N)?",C_GOLD,fontsize);
        i=0; y1=y1+h;
        DrawAttrib("内力","内力"); DrawAttrib("攻击","攻击力"); DrawAttrib("轻功","轻功");  DrawAttrib("防御","防御力");
        i=0; y1=y1+h;
        DrawAttrib("生命","生命"); DrawAttrib("医疗","医疗能力");DrawAttrib("用毒","用毒能力"); DrawAttrib("解毒","解毒能力");
        i=0; y1=y1+h;
        DrawAttrib("拳掌","拳掌功夫"); DrawAttrib("御剑","御剑能力");  DrawAttrib("耍刀","耍刀技巧"); DrawAttrib("暗器","暗器技巧");

        ShowScreen();

        local menu={{"是 ",nil,1},
                    {"否 ",nil,2},
                   };
        local ok=ShowMenu2(menu,2,0,x1+11*fontsize,CC.NewGameY-CC.MenuBorderPixel,0,0,0,0,fontsize,C_WHITE, C_RED)
        if ok==1 then
            break;
        end
    end
end


function Game_Cycle()       --游戏主循环
    EngineAPI.debug.log("Start game cycle");

    while JY.Status ~=GAME_END do
        local tstart=EngineAPI.time.getTime();

        JY.MyTick=JY.MyTick+1;    --20个节拍无击键，则主角变为站立状态
        JY.MyTick2=JY.MyTick2+1;    --20个节拍无击键，则主角变为站立状态

        if JY.MyTick==20 then
            JY.MyCurrentPic=0;
            JY.MyTick=0;
        end

        if JY.MyTick2==1000 then
            JY.MYtick2=0;
        end

        if JY.Status==GAME_FIRSTMMAP then  --首次显示主场景，重新调用主场景贴图，渐变显示。然后转到正常显示
            CleanMemory();
            EngineAPI.render.present()
            JY.MmapMusic=16;
            JY.Status=GAME_MMAP;

            Init_MMap();

            EngineAPI.map.drawMain(JY.Base["人X"],JY.Base["人Y"],GetMyPic());
            EngineAPI.render.present();
        elseif JY.Status==GAME_MMAP then
            Game_MMap();
         elseif JY.Status==GAME_SMAP then
            Game_SMap()
        end

        collectgarbage("step",0);

        local tend=EngineAPI.time.getTime();

        if tend-tstart<CC.Frame then
            WaitFrame(CC.Frame-(tend-tstart));
        end
    end
end


function Init_MMap()   --初始化主地图数据
    EngineAPI.map.loadMain(CC.MMapFile[1],CC.MMapFile[2],CC.MMapFile[3],
            CC.MMapFile[4],CC.MMapFile[5],CC.MWidth,CC.MHeight,JY.Base["人X"],JY.Base["人Y"]);

    LoadArchiveBoth(CC.MMAPPicFile[1],CC.MMAPPicFile[2],0,{paletteFile=CC.PaletteFile});
    LoadArchiveBoth(CC.HeadPicFile[1],CC.HeadPicFile[2],1,{paletteFile=CC.PaletteFile,usage="avatar"});
    if CC.LoadThingPic==1 then
        LoadArchiveBoth(CC.ThingPicFile[1],CC.ThingPicFile[2],2,{paletteFile=CC.PaletteFile});
    end

    -- 主地图飘云（原版 kys_engine.pas:ReadTiles 加载 cloud.idx/grp，
    -- kys_main.pas 初始化 60 朵云）。文件缺失时 PicLoadFile 静默跳过，无云不报错。
    EngineAPI.map.loadClouds(CC.CloudPicFile[1],CC.CloudPicFile[2]);

    JY.EnterSceneXY=nil;         --设为空，强制重新生成场景入口数据。防止有事件更改了场景入口。
    JY.oldMMapX=-1;
    JY.oldMMapY=-1;

    PlayMIDI(JY.MmapMusic);
end


function Game_MMap()      --主地图

    local direct = -1;
    local keypress = EngineAPI.input.getKey();
    if keypress ~= -1 then
        JY.MyTick=0;
        if keypress==VK_ESCAPE then
            MMenu();
            if JY.Status==GAME_FIRSTMMAP then
                return ;
            end
            JY.oldMMapX=-1;         --强制重绘
            JY.oldMMapY=-1;
        elseif keypress==VK_UP then
            direct=0;
        elseif keypress==VK_DOWN then
            direct=3;
        elseif keypress==VK_LEFT then
            direct=2;
        elseif keypress==VK_RIGHT then
            direct=1;
        end
    end

    local x,y;              --按照方向键要到达的坐标
    if direct ~= -1 then   --按下了光标键
        AddMyCurrentPic();         --增加主角贴图编号，产生走路效果
        x=JY.Base["人X"]+CC.DirectX[direct+1];
        y=JY.Base["人Y"]+CC.DirectY[direct+1];
        JY.Base["人方向"]=direct;
    else
        x=JY.Base["人X"];
        y=JY.Base["人Y"];
    end

    JY.SubScene=CanEnterScene(x,y);   --判断是否进入子场景

    if EngineAPI.map.getTile(x,y,3)==0 and EngineAPI.map.getTile(x,y,4)==0 then     --没有建筑，可以到达
        JY.Base["人X"]=x;
        JY.Base["人Y"]=y;
    end
    JY.Base["人X"]=limitX(JY.Base["人X"],10,CC.MWidth-10);           --限制坐标不能超出范围
    JY.Base["人Y"]=limitX(JY.Base["人Y"],10,CC.MHeight-10);

    if CC.MMapBoat[EngineAPI.map.getTile(JY.Base["人X"],JY.Base["人Y"],0)]==1 then
        JY.Base["乘船"]=1;
    else
        JY.Base["乘船"]=0;
    end

    local pic=GetMyPic();

    if CONFIG.FastShowScreen==1 then  --设置快速显示，并且主角位置不变，则显示裁剪窗口
        if JY.oldMMapX==JY.Base["人X"] and JY.oldMMapY==JY.Base["人Y"] then
            if JY.oldMMapPic>=0 and JY.oldMMapPic ~= pic then        --主角贴图有变化，则刷新显示。
                local rr=ClipRect(Cal_PicClip(0,0,JY.oldMMapPic,0,0,0,pic,0));
                if rr~=nil then
                    EngineAPI.render.setClip(rr.x1,rr.y1,rr.x2,rr.y2);
                    EngineAPI.map.drawMain(JY.Base["人X"],JY.Base["人Y"],pic);             --显示主地图
                end
            end
        else
            EngineAPI.render.setClip(0,0,CC.ScreenW,CC.ScreenH);
            EngineAPI.map.drawMain(JY.Base["人X"],JY.Base["人Y"],pic);             --显示主地图
        end
    else  --全部显示
        EngineAPI.map.drawMain(JY.Base["人X"],JY.Base["人Y"],pic);             --显示主地图
    end

    if CC.ShowXY==1 then
        DrawString(10,CC.ScreenH-20,string.format("%d %d",JY.Base["人X"],JY.Base["人Y"]) ,C_GOLD,16);
    end

    ShowScreen(CONFIG.FastShowScreen);
    EngineAPI.render.setClip(0,0,0,0);

    JY.oldMMapX=JY.Base["人X"];
    JY.oldMMapY=JY.Base["人Y"];
    JY.oldMMapPic=pic;

    if JY.SubScene >= 0 then          --进入子场景
        CleanMemory();
        EngineAPI.map.unload();
            EngineAPI.render.present()

        JY.Status=GAME_SMAP;
        JY.MMAPMusic=-1;

        JY.MyPic=GetMyPic();
        JY.Base["人X1"]=JY.Scene[JY.SubScene]["入口X"]
        JY.Base["人Y1"]=JY.Scene[JY.SubScene]["入口Y"]

        Init_SMap(1);
    end

end

--showname  =1 显示场景名 0 不显示
function Init_SMap(showname)   --初始化场景数据
    LoadArchiveBoth(CC.SMAPPicFile[1],CC.SMAPPicFile[2],0,{paletteFile=CC.PaletteFile});
    LoadArchiveBoth(CC.HeadPicFile[1],CC.HeadPicFile[2],1,{paletteFile=CC.PaletteFile,usage="avatar"});
    if CC.LoadThingPic==1 then
        LoadArchiveBoth(CC.ThingPicFile[1],CC.ThingPicFile[2],2,{paletteFile=CC.PaletteFile});
    end

    PlayMIDI(JY.Scene[JY.SubScene]["进门音乐"]);

    JY.oldSMapX=-1;
    JY.oldSMapY=-1;

    JY.SubSceneX=0;
    JY.SubSceneY=0;
    JY.OldDPass=-1;

    JY.D_Valid=nil;

    DrawSMap();
    EngineAPI.render.present()
    EngineAPI.input.getKey();

    --showname=1 时提示场景名。
    --
    --原版此处是阻塞流程：
    --    DrawStrBox(-1,10,名称); ShowScreen(); WaitKey(); Cls(); ShowScreen()
    --事件驱动下不能在这里画也不能在这里等键：
    --   1. ShowScreen() 已被 async_globals 替换为空操作（draw 每帧自动 present）
    --   2. GAME_SMAP.draw 每帧无条件 DrawSMap(0) 全屏重绘，
    --      任何不在 draw 回调里画的东西都会在下一帧被覆盖
    --故改为：异步模块起一条等键协程并置 currentName，
    --绘制由 EventBridge:draw() 里的 SceneNameAsync.draw() 每帧完成。
    if showname==1 then
        ShowSceneName();
    end

end

-- 场景名提示：取当前场景名称。
--
-- jymain 这里只提供数据（GetSceneName）和绘制原语（DrawSceneName），
-- 不持有提示状态、也不等键。显示/等键由
-- framework/scene_name_async.lua 负责（对齐 person_status_async.lua 样板：
-- 协程挂起等键 + draw() 每帧渲染 + InputManager.disableInput 屏蔽行走）。
-- @return: 场景名称字符串；无名称（nil/空串/纯空白）时返回 nil
function GetSceneName()
    local scene = JY.Scene and JY.Scene[JY.SubScene];
    if scene == nil then return nil end
    local name = scene["名称"];
    -- 空串或纯空白视为无名称：否则会画出一个空框
    if name == nil or name:match("^%s*$") then return nil end
    return name;
end

-- 请求显示场景名提示。
--
-- 只转发到全局 ShowSceneNameAsyncImpl（由 framework/scene_name_async.lua 经
-- AsyncGlobals.install() 注入）。script/ 不直接依赖 framework/——
-- 严格 _G 下确实读不到 GameStates 这类模块 local。
--
-- 必须用 rawget：严格 _G 元表（jymain_adapter.lua 的 __index）对不存在的键
-- 会直接抛「attempt read read to undeclared variable」。该全局可能尚未注入
-- （例如从主地图进场景、AsyncGlobals.install() 还没跑过），此时必须能安全
-- 读到 nil 并降级为 no-op，而不是把整个 Init_SMap 炸掉。
function ShowSceneName()
    local name = GetSceneName();
    if name == nil then return end
    local impl = rawget(_G, "ShowSceneNameAsyncImpl");
    if impl == nil then return end   -- 未接入框架：静默跳过
    impl(name);
end

-- 绘制场景名提示框（由 framework/scene_name_async.lua 的 draw() 调用）。
-- 位置与原版一致：x 居中（-1），y=10，白色边框 + 白字。
-- @param name: 场景名称，省略时取当前场景
function DrawSceneName(name)
    name = name or GetSceneName();
    if name == nil then return end
    DrawStrBox(-1,10,name,C_WHITE,CC.DefaultFont);
end

--计算贴图改变形成的Clip裁剪
--(dx1,dy1) 新贴图和绘图中心点的坐标偏移。在场景中，视角不同而主角动时用到
--pic1 旧的贴图编号
--id1 贴图文件加载编号
--(dx2,dy2) 新贴图和绘图中心点的偏移
--pic2 旧的贴图编号
--id2 贴图文件加载编号
--返回，裁剪矩形 {x1,y1,x2,y2}
function Cal_PicClip(dx1,dy1,pic1,id1,dx2,dy2,pic2,id2)   --计算贴图改变形成的Clip裁剪

    -- 迁移（port-sprite-native-migration Task 5）：
    -- lib.PicGetXY 返回 4 个值 (w, h, xoff, yoff) → SpriteAtlas.getMeta 返回 table。
    --
    -- **这是最高风险的一处**：Cal_PicClip 算的是武功动画的裁剪矩形，
    -- 数值错会导致「人物缺一块」或「动画错位」，且只在实机可见。
    -- 所以 getMeta 取不到时用 0 兜底（与旧 PicGetXY 的判空返回 0,0,0,0 一致）。
    local m1 = SpriteAtlas.getMeta(id1, pic1*2);
    local w1 = m1 and m1.w or 0;
    local h1 = m1 and m1.h or 0;
    local x1_off = m1 and m1.xoff or 0;
    local y1_off = m1 and m1.yoff or 0;
    local old_r={};
    old_r.x1=CC.XScale*(dx1-dy1)+CC.ScreenW/2-x1_off;
    old_r.y1=CC.YScale*(dx1+dy1)+CC.ScreenH/2-y1_off;
    old_r.x2=old_r.x1+w1;
    old_r.y2=old_r.y1+h1;

    local m2 = SpriteAtlas.getMeta(id2, pic2*2);
    local w2 = m2 and m2.w or 0;
    local h2 = m2 and m2.h or 0;
    local x2_off = m2 and m2.xoff or 0;
    local y2_off = m2 and m2.yoff or 0;
    local new_r={};
    new_r.x1=CC.XScale*(dx2-dy2)+CC.ScreenW/2-x2_off;
    new_r.y1=CC.YScale*(dx2+dy2)+CC.ScreenH/2-y2_off;
    new_r.x2=new_r.x1+w2;
    new_r.y2=new_r.y1+h2;

    return MergeRect(old_r,new_r);
end

function MergeRect(r1,r2)     --合并矩形
    local res={};
    res.x1=math.min(r1.x1, r2.x1);
    res.y1=math.min(r1.y1, r2.y1);
    res.x2=math.max(r1.x2, r2.x2);
    res.y2=math.max(r1.y2, r2.y2);
    return res;
end

----对矩形进行屏幕剪裁
--返回剪裁后的矩形，如果超出屏幕，返回空
function ClipRect(r)    --对矩形进行屏幕剪裁
    if r.x1>=CC.ScreenW or r.x2<= 0 or r.y1>=CC.ScreenH or r.y2 <=0 then
        return nil
    else
        local res={};
        res.x1=limitX(r.x1,0,CC.ScreenW);
        res.x2=limitX(r.x2,0,CC.ScreenW);
        res.y1=limitX(r.y1,0,CC.ScreenH);
        res.y2=limitX(r.y2,0,CC.ScreenH);
        return res;
    end
end

function GetMyPic()      --计算主角当前贴图
    local n;
    if JY.Status==GAME_MMAP and JY.Base["乘船"]==1 then
        if JY.MyCurrentPic >=4 then
            JY.MyCurrentPic=0
        end
    else
        if JY.MyCurrentPic >6 then
            JY.MyCurrentPic=1
        end
    end

    if JY.Base["乘船"]==0 then
        n=CC.MyStartPic+JY.Base["人方向"]*7+JY.MyCurrentPic;
    else
        n=CC.BoatStartPic+JY.Base["人方向"]*4+JY.MyCurrentPic;
    end
    return n;
end

--增加当前主角走路动画帧, 主地图和场景地图都使用
function AddMyCurrentPic()        ---增加当前主角走路动画帧,
    JY.MyCurrentPic=JY.MyCurrentPic+1;
end

--场景是否可进
--id 场景代号
--x,y 当前主地图坐标
--返回：场景id，-1表示没有场景可进
function CanEnterScene(x,y)         --场景是否可进
    if JY.EnterSceneXY==nil then    --如果为空，则重新产生数据。
        Cal_EnterSceneXY();
    end

    local id=JY.EnterSceneXY[y*CC.MWidth+x];
    if id~=nil then
        local e=JY.Scene[id]["进入条件"];
        if e==0 then        --可进
            return id;
        elseif e==1 then    --不可进
            return -1
        elseif e==2 then    --有轻功高者进
            for i=1,CC.TeamNum do
                local pid=JY.Base["队伍" .. i];
                if pid>=0 then
                    if JY.Person[pid]["轻功"]>=70 then
                        return id;
                    end
                end
            end
        end
    end
    return -1;
end

function Cal_EnterSceneXY()   --计算哪些坐标可以进入场景
    JY.EnterSceneXY={};
    for id = 0,JY.SceneNum-1 do
        local scene=JY.Scene[id];
        if scene["外景入口X1"]>0 and scene["外景入口Y1"] then
            JY.EnterSceneXY[scene["外景入口Y1"]*CC.MWidth+scene["外景入口X1"]]=id;
        end
        if scene["外景入口X2"]>0 and scene["外景入口Y2"] then
            JY.EnterSceneXY[scene["外景入口Y2"]*CC.MWidth+scene["外景入口X2"]]=id;
        end
    end
end

--主菜单
function MMenu()      --主菜单
    local menu={      {"医疗",Menu_Doctor,1},
                      {"解毒",Menu_DecPoison,1},
                      {"物品",Menu_Thing,1},
                      {"状态",Menu_Status,1},
                      {"离队",Menu_PersonExit,1},
                      {"系统",Menu_System,1},      };
    if JY.Status==GAME_SMAP then  --子场景，后两个菜单不可见
        menu[5][3]=0;
        menu[6][3]=0;
    end

    ShowMenu(menu,6,0,CC.MainMenuX,CC.MainMenuY,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE)
end

--系统子菜单
function Menu_System()         --系统子菜单
    local menu={ {"读取进度",Menu_ReadRecord,1},
                 {"保存进度",Menu_SaveRecord,1},
                 {"离开游戏",Menu_Exit,1},   };

    local r=ShowMenu(menu,3,0,CC.MainSubMenuX,CC.MainSubMenuY,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);
    if r == 0 then
        return 0;
    elseif r<0 then   --要退出全部菜单，
        return 1;
     end
end

--离开菜单
function Menu_Exit()      --离开菜单
    Cls();
    if DrawStrBoxYesNo(-1,-1,"是否真的要离开游戏？",C_WHITE,CC.DefaultFont) == true then
        JY.Status =GAME_END;
    end
    return 1;
end

--保存进度
function Menu_SaveRecord()         --保存进度菜单
    local menu={ {"进度一",nil,1},
                 {"进度二",nil,1},
                 {"进度三",nil,1},  };
    local r=ShowMenu(menu,3,0,CC.MainSubMenuX2,CC.MainSubMenuY,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);
    if r>0 then
        DrawStrBox(CC.MainSubMenuX2,CC.MainSubMenuY,"请稍候......",C_WHITE,CC.DefaultFont);
        ShowScreen();
        SaveRecord(r);
        Cls(CC.MainSubMenuX2,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
    end
    return 0;
end

--读取进度
function Menu_ReadRecord()        --读取进度菜单
    local menu={ {"进度一",nil,1},
                 {"进度二",nil,1},
                 {"进度三",nil,1},  };
    local r=ShowMenu(menu,3,0,CC.MainSubMenuX2,CC.MainSubMenuY,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);

    if r == 0 then
        return 0;
    elseif r>0 then
        DrawStrBox(CC.MainSubMenuX2,CC.MainSubMenuY,"请稍候......",C_WHITE,CC.DefaultFont);
        ShowScreen();
        local ok = LoadRecord(r);
        if ok then
            JY.Status=GAME_FIRSTMMAP;
            return 1;
        else
            DrawStrBoxWaitKey("该存档不存在或已损坏",C_WHITE,CC.DefaultFont,1);
            return 0;
        end
    end
end

--状态子菜单
function Menu_Status()           --状态子菜单
    DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"要查阅谁的状态",C_WHITE,CC.DefaultFont);
    local nexty=CC.MainSubMenuY+CC.SingleLineHeight;

    local r=SelectTeamMenu(CC.MainSubMenuX,nexty);
    if r >0 then
        ShowPersonStatus(r)
        return 1;
    else
        Cls();
        return 0;
    end
end

--离队Exit
function Menu_PersonExit()        --离队Exit
    DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"要求谁离队",C_WHITE,CC.DefaultFont);
    local nexty=CC.MainSubMenuY+CC.SingleLineHeight;

    local r=SelectTeamMenu(CC.MainSubMenuX,nexty);
    if r==1 then
        DrawStrBoxWaitKey("抱歉！没有你游戏进行不下去",C_WHITE,CC.DefaultFont,1);
    elseif r>1 then
        local personid=JY.Base["队伍" .. r];
        for i,v in ipairs(CC.PersonExit) do         --在离队列表中调用离队函数
             if personid==v[1] then
                 oldCallEvent(v[2]);
             end
        end
    end
    Cls();
    return 0;
end

--队伍选择人物菜单
function SelectTeamMenu(x,y)          --队伍选择人物菜单
    local menu={};
    for i=1,CC.TeamNum do
        menu[i]={"",nil,0};
        local id=JY.Base["队伍" .. i]
        if id>=0 then
            if JY.Person[id]["生命"]>0 then
                menu[i][1]=JY.Person[id]["姓名"];
                menu[i][3]=1;
            end
        end
    end
    return ShowMenu(menu,CC.TeamNum,0,x,y,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);
end

function GetTeamNum()            --得到队友个数
    local r=CC.TeamNum;
    for i=1,CC.TeamNum do
        if JY.Base["队伍" .. i]<0 then
            r=i-1;
            break;
        end
    end
    return r;
end

---显示队友状态
-- 左右键翻页，上下键换队友
function ShowPersonStatus(teamid)---显示队友状态
    local page=1;
    local pagenum=2;
    local teamnum=GetTeamNum();

    while true do
        Cls();
        local id=JY.Base["队伍" .. teamid];
        ShowPersonStatus_sub(id,page);

        ShowScreen();
        local keypress=WaitKey();
        WaitFrame(100);
        if keypress==VK_ESCAPE then
            break;
        elseif keypress==VK_UP then
            teamid=teamid-1;
        elseif keypress==VK_DOWN then
            teamid=teamid+1;
        elseif keypress==VK_LEFT then
            page=page-1;
        elseif keypress==VK_RIGHT then
            page=page+1;
        end
        teamid=limitX(teamid,1,teamnum);
        page=limitX(page,1,pagenum);
    end
end

--id 人物编号
--page 显示页数，目前共两页
function ShowPersonStatus_sub(id,page)    --显示人物状态页面
    local size=CC.DefaultFont;    --字体大小
    local p=JY.Person[id];
    local width=18*size+15;             --18个汉字字符宽
    local h=size+CC.PersonStateRowPixel;
    local height=13*h+10;                --12个汉字字符高
    local dx=(CC.ScreenW-width)/2;
    local dy=(CC.ScreenH-height)/2;

    local i=1;
    local x1,y1,x2;

    DrawBox(dx,dy,dx+width,dy+height,C_WHITE);

    x1=dx+5;
    y1=dy+5;
    x2=4*size;
    -- 迁移（Task 5）：PicGetXY → getMeta（table），PicLoadCache → draw（flag 0x1）
    local headMeta = SpriteAtlas.getMeta(1, p["头像代号"]*2);
    local headw = headMeta and headMeta.w or 0;
    local headh = headMeta and headMeta.h or 0;
    local headx=(width/2-headw)/2;
    local heady=(h*6-headh)/2;


    SpriteAtlas.draw(1, p["头像代号"]*2, x1+headx, y1+heady, 0x1);
    i=6;
    DrawString(x1,y1+h*i,p["姓名"],C_WHITE,size);
    DrawString(x1+10*size/2,y1+h*i,string.format("%3d",p["等级"]),C_GOLD,size);
    DrawString(x1+13*size/2,y1+h*i,"级",C_ORANGE,size);

    local function DrawAttrib(str,color1,color2,v)    --定义内部函数
        v=v or 0;
        DrawString(x1,y1+h*i,str,color1,size);
        DrawString(x1+x2,y1+h*i,string.format("%5d",p[str]+v),color2,size);
        i=i+1;
    end

if page==1 then
    local color;              --显示生命和最大值，根据受伤和中毒显示不同颜色
    if p["受伤程度"]<33 then
        color =RGB(236,200,40);
    elseif p["受伤程度"]<66 then
        color=RGB(244,128,32);
    else
        color=RGB(232,32,44);
    end
    i=i+1;
    DrawString(x1,y1+h*i,"生命",C_ORANGE,size);
    DrawString(x1+2*size,y1+h*i,string.format("%5d",p["生命"]),color,size);
    DrawString(x1+9*size/2,y1+h*i,"/",C_GOLD,size);

    if p["中毒程度"]==0 then
        color =RGB(252,148,16);
    elseif p["中毒程度"]<50 then
        color=RGB(120,208,88);
    else
        color=RGB(56,136,36);
    end
    DrawString(x1+5*size,y1+h*i,string.format("%5s",p["生命最大值"]),color,size);

    i=i+1;              --显示内力和最大值，根据内力性质显示不同颜色
    if p["内力性质"]==0 then
        color=RGB(208,152,208);
    elseif p["内力性质"]==1 then
        color=RGB(236,200,40);
    else
        color=RGB(236,236,236);
    end
    DrawString(x1,y1+h*i,"内力",C_ORANGE,size);
    DrawString(x1+2*size,y1+h*i,string.format("%5d/%5d",p["内力"],p["内力最大值"]),color,size);

    i=i+1;
    DrawAttrib("体力",C_ORANGE,C_GOLD)
    DrawAttrib("经验",C_ORANGE,C_GOLD)
    local tmp;
    if p["等级"] >=CC.Level then
        tmp="=";
    else
        tmp=string.format("%5d",CC.Exp[p["等级"]]);
    end

    DrawString(x1,y1+h*i,"升级",C_ORANGE,size);
    DrawString(x1+x2,y1+h*i,tmp,C_GOLD,size);

    local tmp1,tmp2,tmp3=0,0,0;
    if p["武器"]>-1 then
        tmp1=tmp1+JY.Thing[p["武器"]]["加攻击力"];
        tmp2=tmp2+JY.Thing[p["武器"]]["加防御力"];
        tmp3=tmp3+JY.Thing[p["武器"]]["加轻功"];
    end
    if p["防具"]>-1 then
        tmp1=tmp1+JY.Thing[p["防具"]]["加攻击力"];
        tmp2=tmp2+JY.Thing[p["防具"]]["加防御力"];
        tmp3=tmp3+JY.Thing[p["防具"]]["加轻功"];
    end

    i=i+1;
    DrawString(x1,y1+h*i,"左右键翻页，上下键查看其它队友",C_RED,size);


    i=0;
    x1=dx+width/2;
    DrawAttrib("攻击力",C_WHITE,C_GOLD,tmp1);
    DrawAttrib("防御力",C_WHITE,C_GOLD,tmp2);
    DrawAttrib("轻功",C_WHITE,C_GOLD,tmp3);

    DrawAttrib("医疗能力",C_WHITE,C_GOLD);
    DrawAttrib("用毒能力",C_WHITE,C_GOLD);
    DrawAttrib("解毒能力",C_WHITE,C_GOLD);


    DrawAttrib("拳掌功夫",C_WHITE,C_GOLD);
    DrawAttrib("御剑能力",C_WHITE,C_GOLD);
    DrawAttrib("耍刀技巧",C_WHITE,C_GOLD);
    DrawAttrib("特殊兵器",C_WHITE,C_GOLD);
    DrawAttrib("暗器技巧",C_WHITE,C_GOLD);
    DrawAttrib("资质",C_WHITE,C_GOLD);

elseif page==2 then
    i=i+1;
    DrawString(x1,y1+h*i,"武器:",C_ORANGE,size);
    if p["武器"]>-1 then
        DrawString(x1+size*3,y1+h*i,JY.Thing[p["武器"]]["名称"],C_GOLD,size);
    end
    i=i+1;
    DrawString(x1,y1+h*i,"防具:",C_ORANGE,size);
    if p["防具"]>-1 then
        DrawString(x1+size*3,y1+h*i,JY.Thing[p["防具"]]["名称"],C_GOLD,size);
    end
    i=i+1;
    DrawString(x1,y1+h*i,"修炼物品",C_ORANGE,size);
    local thingid=p["修炼物品"];
    if thingid>0 then
        i=i+1;
        DrawString(x1+size,y1+h*i,JY.Thing[thingid]["名称"],C_GOLD,size);
        i=i+1;
        local n=TrainNeedExp(id);
        if n <math.huge then
            DrawString(x1+size,y1+h*i,string.format("%5d/%5d",p["修炼点数"],n),C_GOLD,size);
        else
            DrawString(x1+size,y1+h*i,string.format("%5d/===",p["修炼点数"]),C_GOLD,size);
        end
    else
        i=i+2;
    end

    i=i+1;
    DrawString(x1,y1+h*i,"左右键翻页，上下键查看其它队友",C_RED,size);

    i=0;
    x1=dx+width/2;
    DrawString(x1,y1+h*i,"所会功夫",C_ORANGE,size);
    for j=1,10 do
        i=i+1
        local wugong=p["武功" .. j];
        if wugong > 0 then
            local level=math.modf(p["武功等级" .. j] / 100)+1;
            DrawString(x1+size,y1+h*i,string.format("%s",JY.Wugong[wugong]["名称"]),C_GOLD,size);
            DrawString(x1+size*7,y1+h*i,string.format("%2d",level),C_WHITE,size);
        end
    end

end

end


--计算人物修炼成功需要的点数
--id 人物id
function TrainNeedExp(id)         --计算人物修炼物品成功需要的点数
    local thingid=JY.Person[id]["修炼物品"];
    local r =0;
    if thingid >= 0 then
        if JY.Thing[thingid]["练出武功"] >=0 then
            local level=0;          --此处的level是实际level-1。这样没有武功時和炼成一级是一样的。
            for i =1,10 do               -- 查找当前已经炼成武功等级
                if JY.Person[id]["武功" .. i]==JY.Thing[thingid]["练出武功"] then
                    level=math.modf(JY.Person[id]["武功等级" .. i] /100);
                    break;
                end
            end
            if level <9 then
                r=(7-math.modf(JY.Person[id]["资质"]/15))*JY.Thing[thingid]["需经验"]*(level+1);
            else
                r=math.huge;
            end
        else
            r=(7-math.modf(JY.Person[id]["资质"]/15))*JY.Thing[thingid]["需经验"]*2;
        end
    end
    return r;
end

--医疗菜单
-- 注意：本函数（以及 Menu_DecPoison、MMenu、Game_MMap/Game_SMap）只在
-- 原版阻塞式 JY_Main 循环里可达；Love2D 版走 JYMainAdapter + MMenuCoroutine，
-- 这些函数是死代码，保留作为原版行为的参考。
-- 里面的 string.format("%-10s%4d", ...) 同样有「%-10s 按字节补齐」的缺陷
-- （汉字 3 字节，补到 10 字节 ≈ 3.33 个汉字，3/4 字姓名各占一档，
--   实测姓名列抖动 12px）。活路径 framework/jymain_async.lua 已改用
-- TextBoxLayout.formatColumns 按显示宽度对齐，此处不再改，
-- 以免在死代码上引入无法用实机验证的改动。
function Menu_Doctor()       --医疗菜单
    DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"谁要使用医术",C_WHITE,CC.DefaultFont);
    local nexty=CC.MainSubMenuY+CC.SingleLineHeight;
    DrawStrBox(CC.MainSubMenuX,nexty,"医疗能力",C_ORANGE,CC.DefaultFont);

    local menu1={};
    for i=1,CC.TeamNum do
        menu1[i]={"",nil,0};
        local id=JY.Base["队伍" .. i]
        if id >=0 then
            if JY.Person[id]["医疗能力"]>=20 then
                 menu1[i][1]=string.format("%-10s%4d",JY.Person[id]["姓名"],JY.Person[id]["医疗能力"]);
                 menu1[i][3]=1;
            end
        end
    end

    local id1,id2;
    nexty=nexty+CC.SingleLineHeight;
    local r=ShowMenu(menu1,CC.TeamNum,0,CC.MainSubMenuX,nexty,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);

    if r >0 then
        id1=JY.Base["队伍" .. r];
        Cls(CC.MainSubMenuX,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
        DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"要医治谁",C_WHITE,CC.DefaultFont);
        nexty=CC.MainSubMenuY+CC.SingleLineHeight;

        local menu2={};
        for i=1,CC.TeamNum do
            menu2[i]={"",nil,0};
            local id=JY.Base["队伍" .. i]
            if id>=0 then
                 menu2[i][1]=string.format("%-10s%4d/%4d",JY.Person[id]["姓名"],JY.Person[id]["生命"],JY.Person[id]["生命最大值"]);
                 menu2[i][3]=1;
            end
        end

        local r2=ShowMenu(menu2,CC.TeamNum,0,CC.MainSubMenuX,nexty,0,0,1,1,CC.DefaultFont,C_ORANGE,C_WHITE);

        if r2 >0 then
            id2=JY.Base["队伍" .. r2];
            local num=ExecDoctor(id1,id2);
            if num>0 then
                AddPersonAttrib(id1,"体力",-2);
            end
            DrawStrBoxWaitKey(string.format("%s 生命增加 %d",JY.Person[id2]["姓名"],num),C_ORANGE,CC.DefaultFont);
        end
    end

    Cls();

    return 0;
end

--执行医疗
--id1 医疗id2, 返回id2生命增加点数
function ExecDoctor(id1,id2)      --执行医疗
    if JY.Person[id1]["体力"]<50 then
        return 0;
    end

    local add=JY.Person[id1]["医疗能力"];
    local value=JY.Person[id2]["受伤程度"];
    if value > add+20 then
        return 0;
    end

    if value <25 then    --根据受伤程度计算实际医疗能力
        add=add*4/5;
    elseif value <50 then
        add=add*3/4;
    elseif value <75 then
        add=add*2/3;
    else
        add=add/2;
    end
     add=math.modf(add)+Rnd(5);

    AddPersonAttrib(id2,"受伤程度",-add);
    return AddPersonAttrib(id2,"生命",add)
end

--解毒
function Menu_DecPoison()         --解毒
    DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"谁要帮人解毒",C_WHITE,CC.DefaultFont);
    local nexty=CC.MainSubMenuY+CC.SingleLineHeight;
    DrawStrBox(CC.MainSubMenuX,nexty,"解毒能力",C_ORANGE,CC.DefaultFont);

    local menu1={};
    for i=1,CC.TeamNum do
        menu1[i]={"",nil,0};
        local id=JY.Base["队伍" .. i]
        if id>=0 then
            if JY.Person[id]["解毒能力"]>=20 then
                 menu1[i][1]=string.format("%-10s%4d",JY.Person[id]["姓名"],JY.Person[id]["解毒能力"]);
                 menu1[i][3]=1;
            end
        end
    end

    local id1,id2;
     nexty=nexty+CC.SingleLineHeight;
    local r=ShowMenu(menu1,CC.TeamNum,0,CC.MainSubMenuX,nexty,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);

    if r >0 then
        id1=JY.Base["队伍" .. r];
         Cls(CC.MainSubMenuX,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
        DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"替谁解毒",C_WHITE,CC.DefaultFont);
        nexty=CC.MainSubMenuY+CC.SingleLineHeight;

        DrawStrBox(CC.MainSubMenuX,nexty,"中毒程度",C_WHITE,CC.DefaultFont);
        nexty=nexty+CC.SingleLineHeight;

        local menu2={};
        for i=1,CC.TeamNum do
            menu2[i]={"",nil,0};
            local id=JY.Base["队伍" .. i]
            if id>=0 then
                 menu2[i][1]=string.format("%-10s%5d",JY.Person[id]["姓名"],JY.Person[id]["中毒程度"]);
                 menu2[i][3]=1;
            end
        end

        local r2=ShowMenu(menu2,CC.TeamNum,0,CC.MainSubMenuX,nexty,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);
        if r2 >0 then
            id2=JY.Base["队伍" .. r2];
            local num=ExecDecPoison(id1,id2);
            DrawStrBoxWaitKey(string.format("%s 中毒程度减少 %d",JY.Person[id2]["姓名"],num),C_ORANGE,CC.DefaultFont);
        end
    end
    Cls();
    return 0;
end

--解毒
--id1 解毒id2, 返回id2中毒减少点数
function ExecDecPoison(id1,id2)     --执行解毒
    local add=JY.Person[id1]["解毒能力"];
    local value=JY.Person[id2]["中毒程度"];

    if value > add+20 then
        return 0;
    end

     add=limitX(math.modf(add/3)+Rnd(10)-Rnd(10),0,value);
    return -AddPersonAttrib(id2,"中毒程度",-add);
end

--物品菜单
function Menu_Thing()       --物品菜单

    local menu={ {"全部物品",nil,1},
                 {"剧情物品",nil,1},
                 {"神兵宝甲",nil,1},
                 {"武功秘笈",nil,1},
                 {"灵丹妙药",nil,1},
                 {"伤人暗器",nil,1}, };

    local r=ShowMenu(menu,CC.TeamNum,0,CC.MainSubMenuX,CC.MainSubMenuY,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);

    if r>0 then
        local thing={};
        local thingnum={};

        for i = 0,CC.MyThingNum-1 do
            thing[i]=-1;
            thingnum[i]=0;
        end

        local num=0
        for i = 0,CC.MyThingNum-1 do
            local id=JY.Base["物品" .. i+1];
            if id>=0 then
                if r==1 then
                    thing[i]=id
                    thingnum[i]=JY.Base["物品数量" ..i+1];
                else
                    if JY.Thing[id]["类型"]==r-2 then             --对应于类型0-4
                         thing[num]=id;
                        thingnum[num]=JY.Base["物品数量" ..i+1];
                        num=num+1;
                    end
                end
            end
        end

        local r=SelectThing(thing,thingnum);
        if r>=0 then
            UseThing(r);           --使用物品
            return 1;             --退出主菜单
        end
    end
    return 0;
end

--新的显示物品菜单，模仿原游戏
--显示物品菜单
--返回选择的物品编号, -1表示没有选择
function SelectThing(thing,thingnum)    --显示物品菜单

    local xnum=CC.MenuThingXnum;
    local ynum=CC.MenuThingYnum;

    local w=CC.ThingPicWidth*xnum+(xnum-1)*CC.ThingGapIn+2*CC.ThingGapOut;  --总体宽度
    local h=CC.ThingPicHeight*ynum+(ynum-1)*CC.ThingGapIn+2*CC.ThingGapOut; --物品栏高度

    local dx=(CC.ScreenW-w)/2;
    local dy=(CC.ScreenH-h-2*(CC.ThingFontSize+2*CC.MenuBorderPixel+5))/2;


    local y1_1,y1_2,y2_1,y2_2,y3_1,y3_2;                  --名称，说明和图片的Y坐标

    local cur_line=0;
    local cur_x=0;
    local cur_y=0;
    local cur_thing=-1;

    while true do
        Cls();
        y1_1=dy;
        y1_2=y1_1+CC.ThingFontSize+2*CC.MenuBorderPixel;
        DrawBox(dx,y1_1,dx+w,y1_2,C_WHITE);
        y2_1=y1_2+5
        y2_2=y2_1+CC.ThingFontSize+2*CC.MenuBorderPixel
        DrawBox(dx,y2_1,dx+w,y2_2,C_WHITE);
        y3_1=y2_2+5;
        y3_2=y3_1+h;
        DrawBox(dx,y3_1,dx+w,y3_2,C_WHITE);

        for y=0,ynum-1 do
            for x=0,xnum-1 do
                local id=y*xnum+x+xnum*cur_line         --当前待选择物品
                local boxcolor;
                if x==cur_x and y==cur_y then
                    boxcolor=C_WHITE;
                    if thing[id]>=0 then
                        cur_thing=thing[id];
                        local str=JY.Thing[thing[id]]["名称"];
                        if JY.Thing[thing[id]]["类型"]==1 or JY.Thing[thing[id]]["类型"]==2 then
                            if JY.Thing[thing[id]]["使用人"] >=0 then
                                str=str .. "(" .. JY.Person[JY.Thing[thing[id]]["使用人"]]["姓名"] .. ")";
                            end
                        end
                        str=string.format("%s X %d",str,thingnum[id]);
                        local str2=JY.Thing[thing[id]]["物品说明"];

                         DrawString(dx+CC.ThingGapOut,y1_1+CC.MenuBorderPixel,str,C_GOLD,CC.ThingFontSize);
                         DrawString(dx+CC.ThingGapOut,y2_1+CC.MenuBorderPixel,str2,C_ORANGE,CC.ThingFontSize);

                    else
                        cur_thing=-1;
                    end
                else
                     boxcolor=C_BLACK;
                end
                local boxx=dx+CC.ThingGapOut+x*(CC.ThingPicWidth+CC.ThingGapIn);
                local boxy=y3_1+CC.ThingGapOut+y*(CC.ThingPicHeight+CC.ThingGapIn);
                EngineAPI.render.rectOutline(boxx,boxy,boxx+CC.ThingPicWidth+1,boxy+CC.ThingPicHeight+1,boxcolor);
                if thing[id]>=0 then
                    if CC.LoadThingPic==1 then
                        SpriteAtlas.draw(2, thing[id]*2, boxx+1, boxy+1, 0x1);
                    else
                        SpriteAtlas.draw(0, (thing[id]+CC.StartThingPic)*2, boxx+1, boxy+1, 0x1);
                    end
                end
            end
        end

        ShowScreen();
        local keypress=WaitKey();
        WaitFrame(100);
        if keypress==VK_ESCAPE then
            cur_thing=-1;
            break;
        elseif keypress==VK_RETURN or keypress==VK_SPACE then
            break;
        elseif keypress==VK_UP then
            if  cur_y == 0 then
                if  cur_line > 0 then
                    cur_line = cur_line - 1;
                end
            else
                cur_y = cur_y - 1;
            end
        elseif keypress==VK_DOWN then
            if  cur_y ==ynum-1 then
                -- **xnum 需判零**：`CC.MenuThingXnum` 是「一行显示几个物品」，
                -- 由 jyconst 装配（正常 5 或 10），但 MOD 可改成 0。
                -- `200/0` 在 Lua 里得 inf（不报错），于是
                -- `cur_line < inf - ynum` 恒真 → cur_line 每按一次下键就 +1
                -- → 物品索引 `y*xnum + x + xnum*cur_line` 无限增长 → 越界读到 nil。
                -- 钳到 >= 1 后，除零场景退化为"不会继续翻页"，行为安全。
                local xnumSafe = (xnum and xnum > 0) and xnum or 1
                if  cur_line < (math.modf(200/xnumSafe)-ynum) then
                    cur_line = cur_line + 1;
                end
            else
                cur_y = cur_y + 1;
            end
        elseif keypress==VK_LEFT then
            if  cur_x > 0 then
                cur_x=cur_x-1;
            else
                cur_x=xnum-1;
            end
        elseif keypress==VK_RIGHT then
            if  cur_x ==xnum-1 then
                cur_x=0;
            else
                cur_x=cur_x+1;
            end
        end

    end

    Cls();
    return cur_thing;
end


--场景处理主函数
function Game_SMap()         --场景处理主函数

    DrawSMap(CONFIG.FastShowScreen);
    if CC.ShowXY==1 then
        DrawString(10,CC.ScreenH-20,string.format("%s %d %d",JY.Scene[JY.SubScene]["名称"],JY.Base["人X1"],JY.Base["人Y1"]) ,C_GOLD,16);
    end

    ShowScreen(CONFIG.FastShowScreen);

    EngineAPI.render.setClip(0,0,0,0);

    local d_pass=GetS(JY.SubScene,JY.Base["人X1"],JY.Base["人Y1"],3);   --当前路过事件
    if d_pass>=0 then
        if d_pass ~=JY.OldDPass then     --避免重复触发
            EventExecute(d_pass,3);       --路过触发事件
            JY.OldDPass=d_pass;
            JY.oldSMapX=-1;
            JY.oldSMapY=-1;
            JY.D_Valid=nil;
        end
    else
        JY.OldDPass=-1;
    end

    local isout=0;                --是否碰到出口
    if (JY.Scene[JY.SubScene]["出口X1"] ==JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y1"] ==JY.Base["人Y1"]) or
       (JY.Scene[JY.SubScene]["出口X2"] ==JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y2"] ==JY.Base["人Y1"]) or
       (JY.Scene[JY.SubScene]["出口X3"] ==JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y3"] ==JY.Base["人Y1"]) then
       isout=1;
    end

    if isout==1 then    --出去，返回主地图
        JY.Status=GAME_MMAP;

            CleanMemory();
        EngineAPI.render.present()

        if JY.MMAPMusic<0 then
            JY.MMAPMusic=JY.Scene[JY.SubScene]["出门音乐"];
        end

        Init_MMap();



        JY.SubScene=-1;
        JY.oldSMapX=-1;
        JY.oldSMapY=-1;

        EngineAPI.map.drawMain(JY.Base["人X"],JY.Base["人Y"],GetMyPic());
        EngineAPI.render.present()
        EngineAPI.input.getKey();
        return;
    end

    --是否跳转到其他场景
    if JY.Scene[JY.SubScene]["跳转场景"] >=0 then
        if JY.Base["人X1"]==JY.Scene[JY.SubScene]["跳转口X1"] and JY.Base["人Y1"]==JY.Scene[JY.SubScene]["跳转口Y1"] then
            JY.SubScene=JY.Scene[JY.SubScene]["跳转场景"];
            EngineAPI.render.present();

            if JY.Scene[JY.SubScene]["外景入口X1"]==0 and JY.Scene[JY.SubScene]["外景入口Y1"]==0 then
                JY.Base["人X1"]=JY.Scene[JY.SubScene]["入口X"];            --新场景的外景入口为0，表示这是一个内部场景
                JY.Base["人Y1"]=JY.Scene[JY.SubScene]["入口Y"];
            else
                JY.Base["人X1"]=JY.Scene[JY.SubScene]["跳转口X2"];         --外部场景，即从其他内部场景跳回。
                JY.Base["人Y1"]=JY.Scene[JY.SubScene]["跳转口Y2"];
            end

            Init_SMap(1);

            return;
        end
    end

    local x,y;
    local keypress = EngineAPI.input.getKey();
    local direct=-1;
    if keypress ~= -1 then
        JY.MyTick=0;
        if keypress==VK_ESCAPE then
            MMenu();
            JY.oldSMapX=-1;
            JY.oldSMapY=-1;
        elseif keypress==VK_UP then
            direct=0;
        elseif keypress==VK_DOWN then
            direct=3;
        elseif keypress==VK_LEFT then
            direct=2;
        elseif keypress==VK_RIGHT then
            direct=1;
        elseif keypress==VK_SPACE or keypress==VK_RETURN  then
            if JY.Base["人方向"]>=0 then        --当前方向下一个位置
                local d_num=GetS(JY.SubScene,JY.Base["人X1"]+CC.DirectX[JY.Base["人方向"]+1],JY.Base["人Y1"]+CC.DirectY[JY.Base["人方向"]+1],3);
                if d_num>=0 then
                    EventExecute(d_num,1);       --空格触发事件
                    JY.oldSMapX=-1;
                    JY.oldSMapY=-1;
                    JY.D_Valid=nil;
                end
            end
        end
    end

    if JY.Status~=GAME_SMAP then
        return ;
    end

    if direct ~= -1 then
        AddMyCurrentPic();
        x=JY.Base["人X1"]+CC.DirectX[direct+1];
        y=JY.Base["人Y1"]+CC.DirectY[direct+1];
        JY.Base["人方向"]=direct;
    else
        x=JY.Base["人X1"];
        y=JY.Base["人Y1"];
    end

    JY.MyPic=GetMyPic();

    DtoSMap();

    if SceneCanPass(x,y)==true then          --新的坐标可以走过去
        JY.Base["人X1"]=x;
        JY.Base["人Y1"]=y;
    end

    JY.Base["人X1"]=limitX(JY.Base["人X1"],1,CC.SWidth-2);
    JY.Base["人Y1"]=limitX(JY.Base["人Y1"],1,CC.SHeight-2);

end

--场景坐标(x,y)是否可以通过
--返回true,可以，false不能
function SceneCanPass(x,y)  --场景坐标(x,y)是否可以通过
    local ispass=true;        --是否可以通过

    if GetS(JY.SubScene,x,y,1)>0 then     --场景层1有物品，不可通过
        ispass=false;
    end

    local d_data=GetS(JY.SubScene,x,y,3);     --事件层4
    if d_data>=0 then
        if GetD(JY.SubScene,d_data,0)~=0 then  --d*数据为不能通过
            ispass=false;
        end
    end

    if CC.SceneWater[GetS(JY.SubScene,x,y,0)] ~= nil then   --水面，不可进入
        ispass=false;
    end
    return ispass;
end


function Cal_D_Valid()     --计算200个D中有效的D
    if JY.D_Valid~=nil then
        return ;
    end

    local sceneid=JY.SubScene;
    JY.D_Valid={};
    JY.D_Valid_Num=0;
    for i=0,CC.DNum-1 do
        local x=GetD(sceneid,i,9);
        local y=GetD(sceneid,i,10);
        local v=GetS(sceneid,x,y,3);
        if v>=0 then
            JY.D_Valid[JY.D_Valid_Num]=i;
            JY.D_Valid_Num=JY.D_Valid_Num+1;
        end
    end
end

function DtoSMap()          ---D*中的事件处理动画效果。
    local sceneid=JY.SubScene;
    JY.NumD_PicChange=0;
    JY.D_PicChange={};

    if JY.D_Valid==nil then
        Cal_D_Valid();
    end

    for k=0,JY.D_Valid_Num-1 do
        local i=JY.D_Valid[k];

        local p1=GetD(sceneid,i,5);
        if p1>0 then
            local p2=GetD(sceneid,i,6);
            local p3=GetD(sceneid,i,7);
            if p1 ~= p2 then
                local old_p3=p3;
                local delay=GetD(sceneid,i,8);
                if not (p3>=CC.SceneFlagPic[1]*2 and p3<=CC.SceneFlagPic[2]*2 and CC.ShowFlag==0) then --是否显示旗帜
                    if p3<=p1 then     --动画已停止
                        if JY.MyTick2 %100 > delay then
                            p3=p3+2;
                        end
                    else
                        if JY.MyTick2 % 4 ==0 then      --4个节拍动画增加一次
                            p3=p3+2;
                        end
                    end
                    if p3>p2 then
                         p3=p1;
                    end
                end
                if old_p3 ~=p3 then    --动画改变了，增加一个
                    local x=GetD(sceneid,i,9);
                    local y=GetD(sceneid,i,10);
                    local dy=GetS(sceneid,x,y,4);       --海拔
                    JY.D_PicChange[JY.NumD_PicChange]={x=x, y=y, dy=dy, p1=old_p3/2, p2=p3/2}
                    JY.NumD_PicChange=JY.NumD_PicChange+1;
                    SetD(sceneid,i,7,p3);
                end
            end
        end
    end
end

--fastdraw = 0 or nil 全部重绘。用于事件中
--           1 考虑脏矩形 用于显示场景循环
function DrawSMap(fastdraw)         --绘场景地图
    if fastdraw==nil then
        fastdraw=0;
    end
    local x0=JY.SubSceneX+JY.Base["人X1"]-1;    --绘图中心点
    local y0=JY.SubSceneY+JY.Base["人Y1"]-1;

    local x=limitX(x0,CC.SceneXMin,CC.SceneXMax)-JY.Base["人X1"];
    local y=limitX(y0,CC.SceneYMin,CC.SceneYMax)-JY.Base["人Y1"];

    if fastdraw==0 then
        EngineAPI.map.drawScene(JY.SubScene,JY.Base["人X1"],JY.Base["人Y1"],x,y,JY.MyPic);
    else
        if JY.oldSMapX>=0 and JY.oldSMapY>=0 and
           JY.oldSMapX+JY.oldSMapXoff==JY.Base["人X1"]+x and         --绘图中心点不变，人走路也可以用裁剪方式绘图
           JY.oldSMapY+JY.oldSMapYoff==JY.Base["人Y1"]+y then

            local num_clip=0;
            local clip={};

            for i=0,JY.NumD_PicChange-1 do   --计算D*中贴图改变的矩形
                local dx=JY.D_PicChange[i].x-JY.Base["人X1"]-x;
                local dy=JY.D_PicChange[i].y-JY.Base["人Y1"]-y;
                clip[num_clip]=Cal_PicClip(dx,dy,JY.D_PicChange[i].p1,0,
                                           dx,dy,JY.D_PicChange[i].p2,0 );
                clip[num_clip].y1=clip[num_clip].y1-JY.D_PicChange[i].dy
                clip[num_clip].y2=clip[num_clip].y2-JY.D_PicChange[i].dy
                num_clip=num_clip+1;
            end

            if JY.oldSMapPic>=0 then  --计算主角矩形
                if not ( JY.oldSMapX==JY.Base["人X1"] and    --主角有变化
                         JY.oldSMapY==JY.Base["人Y1"] and
                         JY.oldSMapPic==JY.MyPic ) then
                    local dy1=GetS(JY.SubScene,JY.Base["人X1"],JY.Base["人Y1"],4);   --海拔
                    local dy2=GetS(JY.SubScene,JY.oldSMapX,JY.oldSMapY,4);
                    local dy=math.max(dy1,dy2);
                    clip[num_clip]=Cal_PicClip(-JY.oldSMapXoff,-JY.oldSMapYoff,JY.oldSMapPic,0,
                                                -x,-y,JY.MyPic,0)
                    clip[num_clip].y1=clip[num_clip].y1- dy;
                    clip[num_clip].y2=clip[num_clip].y2- dy;
                    num_clip=num_clip+1;
                end
            end

            local area=0;          --计算所有脏矩形面积
            for i=0,num_clip-1 do
                clip[i]=ClipRect(clip[i]);    --矩形屏幕剪裁
                if clip[i]~=nil then
                    area=area+(clip[i].x2-clip[i].x1)*(clip[i].y2-clip[i].y1)
                end
            end

            if area <CC.ScreenW*CC.ScreenH/2 and num_clip<15 then        --面积足够小，矩形数目少，则更新脏矩形。
                for i=0,num_clip-1 do
                    if clip[i]~=nil then
                        EngineAPI.render.setClip(clip[i].x1,clip[i].y1,clip[i].x2,clip[i].y2);
                        EngineAPI.map.drawScene(JY.SubScene,JY.Base["人X1"],JY.Base["人Y1"],x,y,JY.MyPic);
                    end
                end
            else    --面积太大，直接重绘
                EngineAPI.render.setClip(0,0,CC.ScreenW,CC.ScreenH);   --由于redraw=0，必须给出裁剪矩形以后才能ShowSurface
                EngineAPI.map.drawScene(JY.SubScene,JY.Base["人X1"],JY.Base["人Y1"],x,y,JY.MyPic);
            end
        else
            EngineAPI.render.setClip(0,0,CC.ScreenW,CC.ScreenH);
            EngineAPI.map.drawScene(JY.SubScene,JY.Base["人X1"],JY.Base["人Y1"],x,y,JY.MyPic);
        end
    end

    JY.oldSMapX=JY.Base["人X1"];
    JY.oldSMapY=JY.Base["人Y1"];
    JY.oldSMapPic=JY.MyPic;
    JY.oldSMapXoff=x;
    JY.oldSMapYoff=y;
end


-- 读取游戏进度
-- id=0 新进度，=1/2/3 进度
--
-- MOD 旁路字符串表接入（allmods 编码转换）
-- MOD 的字符串字段在 ranger.grp 中被替换为固定宽度 hint（如 "P0002"），
-- 真实 UTF-8 值在 data/ranger.str。未激活 MOD 时 ModData 为空操作，
-- 行为与原版逐字节一致（零回归）。
-- 注意：这三个 helper 必须在 LoadRecord/SaveRecord 之前定义（局部函数
-- 需先声明后使用），故放在文件此处。
local _modDataHooked = false
local _modDataCache = nil
local function modDataForStrings()
    if _modDataHooked then return _modDataCache end
    _modDataHooked = true
    local ok, m = pcall(require, "framework.mod_data")
    _modDataCache = (ok and m) or false
    return _modDataCache
end

-- 解析从缓冲区读到的字符串：若是 hint 且能查到旁路表，返回真实值。
-- 当前存档覆盖表（若有）优先。
-- 对「未转换」字段（缓冲区里是纯 ASCII 原文），则用合成键查覆盖表。
local function resolveModString(v, t, offset)
    local m = modDataForStrings()
    if not m or not m.Active() then return v end
    local ovr = m._currentOverrides
    -- 1) 真实 hint 键
    if ovr and ovr[v] ~= nil then return ovr[v] end
    -- 2) 合成键（未转换字段的改写）
    if ovr and t and m.IdentifyStringField and m.SyntheticKey then
        local seg, field = m.IdentifyStringField(t[1])
        if seg then
            local k = m.SyntheticKey(seg, field, offset)
            if k and ovr[k] ~= nil then return ovr[k] end
        end
    end
    return m.ResolveString(v)
end

-- 写入字符串字段：MOD 激活时记录到存档覆盖表（而非写缓冲区），
-- 以便存档回写时能保留玩家修改的字符串（UTF-8 放不回定长字段）。
-- 键的选择：
--   * 缓冲区是真实 hint（构建期已转换）→ 用 hint 作键
--   * 缓冲区是纯 ASCII 原文（构建期未转换）→ 用合成键（段+字段+记录偏移）
local function writeModString(data, t, offset, v)
    local m = modDataForStrings()
    if m and m.Active() and m._currentOverrides then
        local hint = Byte.getstr(data, t[1]+offset, t[3])
        if hint and hint ~= "" and m.ParseHint and m.ParseHint(hint) then
            m._currentOverrides[hint] = v
            return true
        end
        -- 无 hint：用合成键，避免 UTF-8 被截断进定长字段
        if m.IdentifyStringField and m.SyntheticKey then
            local seg, field = m.IdentifyStringField(t[1])
            if seg then
                local k = m.SyntheticKey(seg, field, offset)
                if k then
                    m._currentOverrides[k] = v
                    return true
                end
            end
        end
    end
    return false
end

--这里是先把数据读入Byte数组中。然后定义访问相应表的方法，在访问表时直接从数组访问。
--与以前的实现相比，从文件中读取和保存到文件的时间显著加快。而且内存占用少了
function LoadRecord(id)       -- 读取游戏进度
    local t1=EngineAPI.time.getTime();

    local idxFile = CC.R_IDXFilename[id]
    local grpFile = CC.R_GRPFilename[id]
    local sFile = CC.S_Filename[id]
    local dFile = CC.D_Filename[id]

    EngineAPI.debug.log(string.format("LoadRecord: id=%d", id));
    EngineAPI.debug.log(string.format("LoadRecord: idx=%s grp=%s s=%s d=%s", tostring(idxFile), tostring(grpFile), tostring(sFile), tostring(dFile)));

    -- 存档文件不存在时，不做任何读取，避免崩溃
    if id > 0 then
        if not FileUtil.exists(idxFile) or not FileUtil.exists(grpFile) or not FileUtil.exists(sFile) or not FileUtil.exists(dFile) then
            EngineAPI.debug.log(string.format("LoadRecord: save slot %d missing files, skip load", id));
            return false;
        end
    else
        -- 新游戏基础数据必须存在
        if not FileUtil.exists(idxFile) or not FileUtil.exists(grpFile) then
            EngineAPI.debug.log("LoadRecord: base new game files missing, skip load");
            return false;
        end
    end

    --读取R*.idx文件
    local data=Byte.create(6*4);
    Byte.loadfile(data,idxFile,0,6*4);

    -- MOD 存档覆盖表：读档时先加载 rN.ovr（未激活 MOD / 无文件时为空表）
    do
        local m = modDataForStrings()
        if m and m.Active() and m.SaveOverrides then
            m._currentOverrides = m.SaveOverrides(id)
        else
            if m then m._currentOverrides = nil end
        end
    end

    local idx={};
    idx[0]=0;
    for i =1,6 do
        idx[i]=Byte.get32(data,4*(i-1));
    end

    --读取R*.grp文件
    JY.Data_Base=Byte.create(idx[1]-idx[0]);              --基本数据
    Byte.loadfile(JY.Data_Base,grpFile,idx[0],idx[1]-idx[0]);

    --设置访问基本数据的方法，这样就可以用访问表的方式访问了。而不用把二进制数据转化为表。节约加载时间和空间
    local meta_t={
        __index=function(t,k)
            return GetDataFromStruct(JY.Data_Base,0,CC.Base_S,k);
        end,

        __newindex=function(t,k,v)
            SetDataFromStruct(JY.Data_Base,0,CC.Base_S,k,v);
         end
    }
    setmetatable(JY.Base,meta_t);


    JY.PersonNum=math.floor((idx[2]-idx[1])/CC.PersonSize);   --人物

    JY.Data_Person=Byte.create(CC.PersonSize*JY.PersonNum);
    Byte.loadfile(JY.Data_Person,grpFile,idx[1],CC.PersonSize*JY.PersonNum);

    for i=0,JY.PersonNum-1 do
        JY.Person[i]={};
        local meta_t={
            __index=function(t,k)
                return GetDataFromStruct(JY.Data_Person,i*CC.PersonSize,CC.Person_S,k);
            end,

            __newindex=function(t,k,v)
                SetDataFromStruct(JY.Data_Person,i*CC.PersonSize,CC.Person_S,k,v);
            end
        }
        setmetatable(JY.Person[i],meta_t);
    end

    JY.ThingNum=math.floor((idx[3]-idx[2])/CC.ThingSize);     --物品
    JY.Data_Thing=Byte.create(CC.ThingSize*JY.ThingNum);
    Byte.loadfile(JY.Data_Thing,grpFile,idx[2],CC.ThingSize*JY.ThingNum);
    for i=0,JY.ThingNum-1 do
        JY.Thing[i]={};
        local meta_t={
            __index=function(t,k)
                return GetDataFromStruct(JY.Data_Thing,i*CC.ThingSize,CC.Thing_S,k);
            end,

            __newindex=function(t,k,v)
                SetDataFromStruct(JY.Data_Thing,i*CC.ThingSize,CC.Thing_S,k,v);
            end
        }
        setmetatable(JY.Thing[i],meta_t);
    end

    JY.SceneNum=math.floor((idx[4]-idx[3])/CC.SceneSize);     --场景
    JY.Data_Scene=Byte.create(CC.SceneSize*JY.SceneNum);
    Byte.loadfile(JY.Data_Scene,grpFile,idx[3],CC.SceneSize*JY.SceneNum);
    for i=0,JY.SceneNum-1 do
        JY.Scene[i]={};
        local meta_t={
            __index=function(t,k)
                return GetDataFromStruct(JY.Data_Scene,i*CC.SceneSize,CC.Scene_S,k);
            end,

            __newindex=function(t,k,v)
                SetDataFromStruct(JY.Data_Scene,i*CC.SceneSize,CC.Scene_S,k,v);
            end
        }
        setmetatable(JY.Scene[i],meta_t);
    end

    JY.WugongNum=math.floor((idx[5]-idx[4])/CC.WugongSize);     --武功
    JY.Data_Wugong=Byte.create(CC.WugongSize*JY.WugongNum);
    Byte.loadfile(JY.Data_Wugong,grpFile,idx[4],CC.WugongSize*JY.WugongNum);
    for i=0,JY.WugongNum-1 do
        JY.Wugong[i]={};
        local meta_t={
            __index=function(t,k)
                return GetDataFromStruct(JY.Data_Wugong,i*CC.WugongSize,CC.Wugong_S,k);
            end,

            __newindex=function(t,k,v)
                SetDataFromStruct(JY.Data_Wugong,i*CC.WugongSize,CC.Wugong_S,k,v);
            end
        }
        setmetatable(JY.Wugong[i],meta_t);
    end

    JY.ShopNum=math.floor((idx[6]-idx[5])/CC.ShopSize);     --小宝商店
    JY.Data_Shop=Byte.create(CC.ShopSize*JY.ShopNum);
    Byte.loadfile(JY.Data_Shop,grpFile,idx[5],CC.ShopSize*JY.ShopNum);
    for i=0,JY.ShopNum-1 do
        JY.Shop[i]={};
        local meta_t={
            __index=function(t,k)
                return GetDataFromStruct(JY.Data_Shop,i*CC.ShopSize,CC.Shop_S,k);
            end,

            __newindex=function(t,k,v)
                SetDataFromStruct(JY.Data_Shop,i*CC.ShopSize,CC.Shop_S,k,v);
            end
        }
        setmetatable(JY.Shop[i],meta_t);

    end

    EngineAPI.map.loadScene(sFile,CC.TempS_Filename,JY.SceneNum,CC.SWidth,CC.SHeight,dFile,CC.DNum,11);
    collectgarbage();

    EngineAPI.debug.log(string.format("Loadrecord time=%d",EngineAPI.time.getTime()-t1));
    return true;
end

-- 写游戏进度
-- id=0 新进度，=1/2/3 进度
function SaveRecord(id)         -- 写游戏进度
    EngineAPI.debug.log("SaveRecord: start id=" .. tostring(id))
    --读取R*.idx文件
    local t1=EngineAPI.time.getTime();

    -- 首次保存该槽时，存档目录里还没有 rN.idx（分段偏移表），
    -- 先从 MOD/原版的基础数据模板（ranger.idx）播种一份，否则会读到全 0 idx，
    -- 导致写出的存档各段长度为 0（损坏）。
    if id > 0 then
        local ok, ModData = pcall(require, "framework.mod_data")
        if ok and ModData and ModData.SeedSaveSlot then
            ModData.EnsureSaveDir()
            local seeded = ModData.SeedSaveSlot(id)
            if seeded then
                EngineAPI.debug.log(string.format("SaveRecord: seeded idx from template -> %s", seeded))
            end
        end
    end

    EngineAPI.debug.log("SaveRecord: reading idx file")
    local data=Byte.create(6*4);
    Byte.loadfile(data,CC.R_IDXFilename[id],0,6*4);

    local idx={};
    idx[0]=0;
    for i =1,6 do
        idx[i]=Byte.get32(data,4*(i-1));
    end

    EngineAPI.debug.log("SaveRecord: writing grp files")
    --写R*.grp文件
    Byte.savefile(JY.Data_Base,CC.R_GRPFilename[id],idx[0],idx[1]-idx[0]);

    Byte.savefile(JY.Data_Person,CC.R_GRPFilename[id],idx[1],CC.PersonSize*JY.PersonNum);

    Byte.savefile(JY.Data_Thing,CC.R_GRPFilename[id],idx[2],CC.ThingSize*JY.ThingNum);

    Byte.savefile(JY.Data_Scene,CC.R_GRPFilename[id],idx[3],CC.SceneSize*JY.SceneNum);

    Byte.savefile(JY.Data_Wugong,CC.R_GRPFilename[id],idx[4],CC.WugongSize*JY.WugongNum);

    Byte.savefile(JY.Data_Shop,CC.R_GRPFilename[id],idx[5],CC.ShopSize*JY.ShopNum);

    EngineAPI.debug.log("SaveRecord: calling SaveSMap")
    EngineAPI.map.saveScene(CC.S_Filename[id],CC.D_Filename[id]);

    -- MOD 存档覆盖表：把本次会话中修改过的字符串写入 rN.ovr
    do
        local m = modDataForStrings()
        if m and m.Active() and m._currentOverrides and m.WriteSaveOverrides then
            m.WriteSaveOverrides(id, m._currentOverrides)
        end
    end

    EngineAPI.debug.log(string.format("SaveRecord time=%d",EngineAPI.time.getTime()-t1));
    EngineAPI.debug.log("SaveRecord: done")

end
-------------------------------------------------------------------------------------
-----------------------------------通用函数-------------------------------------------

function filelength(filename)         --得到文件长度
    local inp=FileUtil.open(filename,"rb");
    if inp == nil then
        return 0;
    end
    local l= inp:seek("end");
    inp:close();
    return l;
end

--读S×数据, (x,y) 坐标，level 层 0-5
function GetS(id,x,y,level)       --读S×数据
    return EngineAPI.map.getSceneTile(id,x,y,level);
end

--写S×
function SetS(id,x,y,level,v)       --写S×
    EngineAPI.map.setSceneTile(id,x,y,level,v);
end

--读D*
--sceneid 场景编号，
--id D*编号
--要读第几个数据, 0-10
function GetD(Sceneid,id,i)          --读D*
    return EngineAPI.map.getSceneEventData(Sceneid,id,i);
end

--写D×
function SetD(Sceneid,id,i,v)         --写D×
    EngineAPI.map.setSceneEventData(Sceneid,id,i,v);
end

--从数据的结构中翻译数据
--data 二进制数组
--offset data中的偏移
--t_struct 数据的结构，在jyconst中有很多定义
--key  访问的key
function GetDataFromStruct(data,offset,t_struct,key)  --从数据的结构中翻译数据，用来取数据
    local t=t_struct[key];
    if t == nil then
        JY_Error(string.format("GetDataFromStruct: key '%s' not found in struct, available keys: %s", 
            tostring(key), table.concat(getTableKeys(t_struct), ", ")))
        return nil
    end
    local r;
    if t[2]==0 then
        r=Byte.get16(data,t[1]+offset);
    elseif t[2]==1 then
        r=Byte.getu16(data,t[1]+offset);
    elseif t[2]==2 then
        r=Byte.getstr(data,t[1]+offset,t[3]);
        r=resolveModString(r, t, offset);
    end
    return r;
end

-- 辅助函数：获取表的所有键
function getTableKeys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, tostring(k))
    end
    return keys
end

-- 写入字符串字段：MOD 激活时记录到存档覆盖表（而非写缓冲区 hint），
-- 以便存档回写时能保留玩家修改的字符串。
function SetDataFromStruct(data,offset,t_struct,key,v)  --从数据的结构中翻译数据，保存数据
    local t=t_struct[key];
    if t[2]==0 then
        Byte.set16(data,t[1]+offset,v);
    elseif t[2]==1 then
        Byte.setu16(data,t[1]+offset,v);
    elseif t[2]==2 then
        if not writeModString(data, t, offset, v) then
            local s;
            s=v;
            Byte.setstr(data,t[1]+offset,t[3],s);
        end
    end
end

--按照t_struct 定义的结构把数据从data二进制串中读到表t中
function LoadData(t,t_struct,data)        --data二进制串中读到表t中
    for k,v in pairs(t_struct) do
        if v[2]==0 then
            t[k]=Byte.get16(data,v[1]);
        elseif v[2]==1 then
            t[k]=Byte.getu16(data,v[1]);
        elseif v[2]==2 then
            t[k]=Byte.getstr(data,v[1],v[3]);
        end
    end
end

--按照t_struct 定义的结构把数据写入data Byte数组中。
function SaveData(t,t_struct,data)      --数据写入data Byte数组中。
    for k,v in pairs(t_struct) do
        if v[2]==0 then
            Byte.set16(data,v[1],t[k]);
        elseif v[2]==1 then
            Byte.setu16(data,v[1],t[k]);
        elseif v[2]==2 then
            local s;
            s=t[k];
            Byte.setstr(data,v[1],v[3],s);
        end
    end
end

--等待键盘输入
function WaitKey()       --等待键盘输入
    local keyPress=-1;
    while true do
        keyPress=EngineAPI.input.getKey();
        if keyPress ~=-1 then
             break;
        end
        WaitFrame(20);
    end
    return keyPress;
end

--绘制一个带背景的白色方框，四角凹进
function DrawBox(x1,y1,x2,y2,color)         --绘制一个带背景的白色方框
    -- 薄包装：阴影 + 双层边框的完整实现搬到 framework/render_facade.drawBox
    -- （注意：不能只调 drawBackground —— 那会丢掉白边框，实测踩过）
    RenderFacade.drawBox(x1,y1,x2,y2,color);
end

--绘制四角凹进的方框
function DrawBox_1(x1,y1,x2,y2,color)       --绘制四角凹进的方框
    -- 薄包装：12 段折线搬到 framework/render_facade._drawBox1
    RenderFacade._drawBox1(x1,y1,x2,y2,color);
end

--显示阴影字符串
function DrawString(x,y,str,color,size)         --显示阴影字符串
    -- 薄包装：实现搬到 framework/render_facade（port-script-decoupling Task 5）
    -- 保留这个全局是因为 script 层有 100+ 处调用点，签名必须不变。
    -- facade 内部会自动补 CC.FontName（否则中文变方块）。
    RenderFacade.text(x,y,str,color,size);
end

--显示带框的字符串
--(x,y) 坐标，如果都为-1,则在屏幕中间显示
--
-- 框宽按文本的**真实像素宽**算，不再用 `size*#str/2`。
--
-- 原版 C 层 JY_DrawStr 用 TTF_SizeUTF8 量真实宽（charset.c:150），
-- 上式在原版是准的。但 Lua 的 #str 是 **UTF-8 字节数**：一个汉字 3 字节，
-- 于是中文字符串的框宽被算成约 4.5 倍字号，比实际宽一大截；
-- 而 ASCII 恰好只占 1 字节，算出来是对的。这就是「中文提示框右边空一大块、
-- 英文框却正常」的原因。
--
-- 实测（simsun@24）：
--   梅庄               真实 48px   旧公式  82px   多 29px
--   牛家村             真实 72px   旧公式 118px   多 41px
--   得到物品:倚天剑 1  真实 204px  旧公式 298px   多 89px
--
-- 框高仍用字号（size + 2*pad）：单行文本要的是光学居中，
-- 而 getHeight（27）比字形墨迹高（23）大 4px，多出的空间是给下伸部
-- 预留的，中文单行用不上，反而让文字偏上（实测 上7/下10）。
--
-- 注意：ShowMenu 的自动定宽（jymain.lua:2333）里还有同一处 `string.len`
-- 字节数公式，影响全游戏所有菜单框宽，改动面远大于本函数，暂未动。
function DrawStrBox(x,y,str,color,size)         --显示带框的字符串
    -- 薄包装：排版 + 画框 + 画字搬到 framework/render_facade.drawStrBox
    RenderFacade.drawStrBox(x,y,str,color,size);
end

--显示并询问Y/N，如果点击Y，则返回true, N则返回false
--(x,y) 坐标，如果都为-1,则在屏幕中间显示
--改为用菜单询问是否
function DrawStrBoxYesNo(x,y,str,color,size)        --显示字符串并询问Y/N
    EngineAPI.input.getKey();
    size = size or CC.DefaultFont;
    -- 与 DrawStrBox 同源：框宽必须按真实像素宽算，
    -- 否则下面 ShowMenu 的 x 定位（依赖 w）也会偏。
    local box = TextBoxLayout.measure(str, {size=size});
    local w = box.width;
    local h = box.height;
    if x==-1 then
        x=(CC.ScreenW-w)/2;
    end
    if y==-1 then
        y=(CC.ScreenH-h)/2;
    end

    DrawStrBox(x,y,str,color,size);
    local menu={{"确定/是",nil,1},
                {"取消/否",nil,2}};

    local r=ShowMenu(menu,2,0,x+w-4*size-2*CC.MenuBorderPixel,y+h+CC.MenuBorderPixel,0,0,1,0,CC.DefaultFont,C_ORANGE, C_WHITE)

    if r==1 then
        return true;
    else
        return false;
    end

end


--显示字符串并等待击键，字符串带框，显示在屏幕中间
function DrawStrBoxWaitKey(s,color,size)          --显示字符串并等待击键
    EngineAPI.input.getKey();
    Cls();
    DrawStrBox(-1,-1,s,color,size);
    ShowScreen();
    WaitKey();
end

--返回 [0 , i-1] 的整形随机数
function Rnd(i)           --随机数
    -- **参数钳制到 >= 1**（根因修复，不是补丁）
    --
    -- `math.random(0)` 的跨版本行为不一致（实测）：
    --   Lua 5.1 / 5.3 → 抛 "bad argument #1 to 'random' (interval is empty)"
    --   Lua 5.4 / 5.5 → **返回一个巨大整数**（实测 8426388018768443949）
    -- 后者不会报错，于是 `Rnd(0)+1` = 8e18 会被静默写进人物属性，
    -- 造成"属性值爆炸"且极难定位。前者则直接让战斗/升级流程崩掉。
    --
    -- 语义上 `Rnd(n)` 的原意是「取 [0, n-1] 的随机整数」，n<=0 时区间为空，
    -- 唯一合理的退化是「恒返回 0」（不对应任何随机选择，等价于"没得选"）。
    -- 所以钳到 1 再减 1，正好返回 0 —— 与调用方 `Rnd(x)+1` 的用法一致。
    --
    -- 单点修复：`Rnd` 是全仓唯一随机入口（105 处调用），改这里覆盖全部。
    i = tonumber(i) or 1
    if i < 1 then i = 1 end
    local r=math.random(math.floor(i));
    return r-1;
end

--增加人物属性，如果有最大值限制，则应用最大值限制。最小值则限制为0
--id 人物id
--str属性字符串
--value 要增加的值，负数表示减少
--返回1,实际增加的值
--返回2，字符串：xxx 增加/减少 xxxx，用于显示药品效果
function AddPersonAttrib(id,str,value)            --增加人物属性
    local oldvalue=JY.Person[id][str];
    local attribmax=math.huge;
    if str=="生命" then
        attribmax=JY.Person[id]["生命最大值"] ;
    elseif str=="内力" then
        attribmax=JY.Person[id]["内力最大值"] ;
    else
        if CC.PersonAttribMax[str] ~= nil then
            attribmax=CC.PersonAttribMax[str];
        end
    end
    local newvalue=limitX(oldvalue+value,0,attribmax);
    JY.Person[id][str]=newvalue;
    local add=newvalue-oldvalue;

    local showstr="";
    if add>0 then
        showstr=string.format("%s 增加 %d",str,add);
    elseif add<0 then
        showstr=string.format("%s 减少 %d",str,-add);
    end
    return add,showstr;
end

--播放midi
function PlayMIDI(id)             --播放midi
    JY.CurrentMIDI=id;
    if JY.EnableMusic==0 then
        return ;
    end
    if id>=0 then
        EngineAPI.audio.playMusic(string.format(CC.MIDIFile,id+1));
    end
end

--播放音效atk***
function PlayWavAtk(id)             --播放音效atk***
    if JY.EnableSound==0 then
        return ;
    end
    if id>=0 then
        EngineAPI.audio.playSFX(string.format(CC.ATKFile,id));
    end
end

--播放音效e**
function PlayWavE(id)              --播放音效e**
    if JY.EnableSound==0 then
        return ;
    end
    if id>=0 then
        EngineAPI.audio.playSFX(string.format(CC.EFile,id));
    end
end

--flag =0 or nil 全部刷新屏幕
--      1 考虑脏矩形的快速刷新
function ShowScreen(flag)              --刷新屏幕显示
    EngineAPI.debug.log(string.format("ShowScreen called: flag=%s, Darkness=%d", tostring(flag), JY.Darkness));
    if JY.Darkness==0 then
        if flag==nil then
            flag=0;
          end
        EngineAPI.render.present();
    end
end

--通用菜单函数
-- menuItem 表，每项保存一个子表，内容为一个菜单项的定义
--          菜单项定义为  {   ItemName,     菜单项名称字符串
--                          ItemFunction, 菜单调用函数，如果没有则为nil
--                          Visible       是否可见  0 不可见 1 可见, 2 可见，作为当前选择项。只能有一个为2，
--                                        多了则只取第一个为2的，没有则第一个菜单项为当前选择项。
--                                        在只显示部分菜单的情况下此值无效。
--                                        此值目前只用于是否菜单缺省显示否的情况
--                       }
--          菜单调用函数说明：         itemfunction(newmenu,id)
--
--       返回值
--              0 正常返回，继续菜单循环 1 调用函数要求退出菜单，不进行菜单循环
--
-- numItem      总菜单项个数
-- numShow      显示菜单项目，如果总菜单项很多，一屏显示不下，则可以定义此值
--                =0表示显示全部菜单项

-- (x1,y1),(x2,y2)  菜单区域的左上角和右下角坐标，如果x2,y2=0,则根据字符串长度和显示菜单项自动计算x2,y2
-- isBox        是否绘制边框，0 不绘制，1 绘制。若绘制，则按照(x1,y1,x2,y2)的矩形绘制白色方框，并使方框内背景变暗
-- isEsc        Esc键是否起作用 0 不起作用，1起作用
-- Size         菜单项字体大小
-- color        正常菜单项颜色，均为RGB
-- selectColor  选中菜单项颜色,
--;
-- 返回值  0 Esc返回
--         >0 选中的菜单项(1表示第一项)
--         <0 选中的菜单项，调用函数要求退出父菜单，这个用于退出多层菜单

function ShowMenu(menuItem,numItem,numShow,x1,y1,x2,y2,isBox,isEsc,size,color,selectColor)     --通用菜单函数
    EngineAPI.debug.log(string.format("ShowMenu called: numItem=%d, numShow=%d", numItem, numShow));
    
    local w=0;
    local h=0;   --边框的宽高
    local i=0;
    local num=0;     --实际的显示菜单项
    local newNumItem=0;  --能够显示的总菜单项数

    EngineAPI.input.getKey();

    local newMenu={};   -- 定义新的数组，以保存所有能显示的菜单项

    --计算能够显示的总菜单项数
    for i=1,numItem do
        if menuItem[i][3]>0 then
            newNumItem=newNumItem+1;
            newMenu[newNumItem]={menuItem[i][1],menuItem[i][2],menuItem[i][3],i};   --新数组多了[4],保存和原数组的对应
        end
    end

    --计算实际显示的菜单项数
    if numShow==0 or numShow > newNumItem then
        num=newNumItem;
    else
        num=numShow;
    end

    --计算边框实际宽高
    local maxlength=0;
    if x2==0 and y2==0 then
        for i=1,newNumItem do
            if string.len(newMenu[i][1])>maxlength then
                maxlength=string.len(newMenu[i][1]);
            end
        end
        w=size*maxlength/2+2*CC.MenuBorderPixel;        --按照半个汉字计算宽度，一边留4个象素
        h=(size+CC.RowPixel)*num+CC.MenuBorderPixel;            --字之间留4个象素，上面再留4个象素
    else
        w=x2-x1;
        h=y2-y1;
    end

    local start=1;             --显示的第一项

    local current =1;          --当前选择项
    for i=1,newNumItem do
        if newMenu[i][3]==2 then
            current=i;
            break;
        end
    end
    if numShow~=0 then
        current=1;
    end

    local keyPress =-1;
    local returnValue =0;
    if isBox==1 then
        DrawBox(x1,y1,x1+w,y1+h,C_WHITE);
    end

    while true do
        if numShow ~=0 then
            Cls(x1,y1,x1+w,y1+h);
            if isBox==1 then
                DrawBox(x1,y1,x1+w,y1+h,C_WHITE);
            end
        end

        for i=start,start+num-1 do
              local drawColor=color;           --设置不同的绘制颜色
            if i==current then
                drawColor=selectColor;
            end
            DrawString(x1+CC.MenuBorderPixel,y1+CC.MenuBorderPixel+(i-start)*(size+CC.RowPixel),
                       newMenu[i][1],drawColor,size);

        end
        ShowScreen();
        keyPress=WaitKey();
        WaitFrame(100);
        if keyPress==VK_ESCAPE then                  --Esc 退出
            if isEsc==1 then
                break;
            end
        elseif keyPress==VK_DOWN then                --Down
            current = current +1;
            if current > (start + num-1) then
                start=start+1;
            end
            if current > newNumItem then
                start=1;
                current =1;
            end
        elseif keyPress==VK_UP then                  --Up
            current = current -1;
            if current < start then
                start=start-1;
            end
            if current < 1 then
                current = newNumItem;
                start =current-num+1;
            end
        elseif   (keyPress==VK_SPACE) or (keyPress==VK_RETURN)  then
            if newMenu[current][2]==nil then
                returnValue=newMenu[current][4];
                break;
            else
                local r=newMenu[current][2](newMenu,current);               --调用菜单函数
                if r==1 then
                    returnValue= -newMenu[current][4];
                    break;
                else
                    Cls(x1,y1,x1+w,y1+h);
                    if isBox==1 then
                        DrawBox(x1,y1,x1+w,y1+h,C_WHITE);
                    end
                end
            end
        end
    end

    Cls(x1,y1,x1+w+1,y1+h+1,0,1);

    EngineAPI.debug.log(string.format("ShowMenu returned: returnValue=%d", returnValue));
    return returnValue;
end

--横向显示菜单，参数和ShowMenu一样
function ShowMenu2(menuItem,numItem,numShow,x1,y1,x2,y2,isBox,isEsc,size,color,selectColor)     --通用菜单函数
    local w=0;
    local h=0;   --边框的宽高
    local i=0;
    local num=0;     --实际的显示菜单项
    local newNumItem=0;  --能够显示的总菜单项数

    EngineAPI.input.getKey();

    local newMenu={};   -- 定义新的数组，以保存所有能显示的菜单项

    --计算能够显示的总菜单项数
    for i=1,numItem do
        if menuItem[i][3]>0 then
            newNumItem=newNumItem+1;
            newMenu[newNumItem]={menuItem[i][1],menuItem[i][2],menuItem[i][3],i};   --新数组多了[4],保存和原数组的对应
        end
    end

    --计算实际显示的菜单项数
    if numShow==0 or numShow > newNumItem then
        num=newNumItem;
    else
        num=numShow;
    end

    --计算边框实际宽高
    local maxlength=0;
    if x2==0 and y2==0 then
        for i=1,newNumItem do
            if string.len(newMenu[i][1])>maxlength then
                maxlength=string.len(newMenu[i][1]);
            end
        end
        w=(size*maxlength/2+CC.RowPixel)*num+CC.MenuBorderPixel;
        h=size+2*CC.MenuBorderPixel;
    else
        w=x2-x1;
        h=y2-y1;
    end

    local start=1;             --显示的第一项

    local current =1;          --当前选择项
    for i=1,newNumItem do
        if newMenu[i][3]==2 then
            current=i;
            break;
        end
    end
    if numShow~=0 then
        current=1;
    end

    local keyPress =-1;
    local returnValue =0;
    if isBox==1 then
        DrawBox(x1,y1,x1+w,y1+h,C_WHITE);
    end
    while true do
        if numShow ~=0 then
            Cls(x1,y1,x1+w,y1+h);
            if isBox==1 then
                DrawBox(x1,y1,x1+w,y1+h,C_WHITE);
            end
        end

        for i=start,start+num-1 do
            local drawColor=color;           --设置不同的绘制颜色
            if i==current then
                drawColor=selectColor;
            end
            DrawString(x1+CC.MenuBorderPixel+(i-start)*(size*maxlength/2+CC.RowPixel),
                       y1+CC.MenuBorderPixel,newMenu[i][1],drawColor,size);
        end
        ShowScreen();
        keyPress=WaitKey();
        WaitFrame(100);

        if keyPress==VK_ESCAPE then                  --Esc 退出
            if isEsc==1 then
                break;
            end
        elseif keyPress==VK_RIGHT then                --Down
            current = current +1;
            if current > (start + num-1) then
                start=start+1;
            end
            if current > newNumItem then
                start=1;
                current =1;
            end
        elseif keyPress==VK_LEFT then                  --Up
            current = current -1;
            if current < start then
                start=start-1;
            end
            if current < 1 then
                current = newNumItem;
                start =current-num+1;
            end
        elseif   (keyPress==VK_SPACE) or (keyPress==VK_RETURN)  then
            if newMenu[current][2]==nil then
                returnValue=newMenu[current][4];
                break;
            else
                local r=newMenu[current][2](newMenu,current);               --调用菜单函数
                if r==1 then
                    returnValue= -newMenu[current][4];
                    break;
                else
                    Cls(x1,y1,x1+w,y1+h);
                    if isBox==1 then
                        DrawBox(x1,y1,x1+w,y1+h,C_WHITE);
                    end
                end
            end
        end
    end

    Cls(x1,y1,x1+w+1,y1+h+1,0,1);
    return returnValue;
end

------------------------------------------------------------------------------------
--------------------------------------物品使用---------------------------------------
--物品使用模块
--当前物品id
--返回1 使用了物品， 0 没有使用物品。可能是某些原因不能使用
function UseThing(id)             --物品使用
    --调用函数
    if JY.ThingUseFunction[id]==nil then
        return DefaultUseThing(id);
    else
        return JY.ThingUseFunction[id](id);
    end
end

--缺省物品使用函数，实现原始游戏效果
--id 物品id
function DefaultUseThing(id)                --缺省物品使用函数
    if JY.Thing[id]["类型"]==0 then
        return UseThing_Type0(id);
    elseif JY.Thing[id]["类型"]==1 then
        return UseThing_Type1(id);
    elseif JY.Thing[id]["类型"]==2 then
        return UseThing_Type2(id);
    elseif JY.Thing[id]["类型"]==3 then
        return UseThing_Type3(id);
    elseif JY.Thing[id]["类型"]==4 then
        return UseThing_Type4(id);
    end
end

--剧情物品，触发事件
function UseThing_Type0(id)              --剧情物品使用
    if JY.SubScene>=0 then
        local x=JY.Base["人X1"]+CC.DirectX[JY.Base["人方向"]+1];
        local y=JY.Base["人Y1"]+CC.DirectY[JY.Base["人方向"]+1];
        local d_num=GetS(JY.SubScene,x,y,3)
        if d_num>=0 then
            JY.CurrentThing=id;
            EventExecute(d_num,2);       --物品触发事件
            JY.CurrentThing=-1;
            return 1;
        else
            return 0;
        end
    end
end

--装备物品
function UseThing_Type1(id)            --装备物品使用
    DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,string.format("谁要配备%s?",JY.Thing[id]["名称"]),C_WHITE,CC.DefaultFont);
    local nexty=CC.MainSubMenuY+CC.SingleLineHeight;
    local r=SelectTeamMenu(CC.MainSubMenuX,nexty);

    if r>0 then
        local personid=JY.Base["队伍" ..r]
        if CanUseThing(id,personid) then
            if JY.Thing[id]["装备类型"]==0 then
                if JY.Thing[id]["使用人"]>=0 then
                    JY.Person[JY.Thing[id]["使用人"]]["武器"]=-1;
                end
                if JY.Person[personid]["武器"]>=0 then
                    JY.Thing[JY.Person[personid]["武器"]]["使用人"]=-1
                end
                JY.Person[personid]["武器"]=id;
            elseif JY.Thing[id]["装备类型"]==1 then
                if JY.Thing[id]["使用人"]>=0 then
                    JY.Person[JY.Thing[id]["使用人"]]["防具"]=-1;
                end
                if JY.Person[personid]["防具"]>=0 then
                    JY.Thing[JY.Person[personid]["防具"]]["使用人"]=-1
                end
                JY.Person[personid]["防具"]=id;
            end
            JY.Thing[id]["使用人"]=personid
        else
            DrawStrBoxWaitKey("此人不适合配备此物品",C_WHITE,CC.DefaultFont);
            return 0;
        end
    end
--    Cls();
--    ShowScreen();
    return 1;
end

--判断一个人是否可以装备或修炼一个物品
--返回 true可以修炼，false不可
function CanUseThing(id,personid)           --判断一个人是否可以装备或修炼一个物品
    local str="";
    if JY.Thing[id]["仅修炼人物"] >=0 then
        if JY.Thing[id]["仅修炼人物"] ~= personid then
            return false;
        end
    end

    if JY.Thing[id]["需内力性质"] ~=2 and JY.Person[personid]["内力性质"] ~=2 then
        if JY.Thing[id]["需内力性质"] ~= JY.Person[personid]["内力性质"] then
            return false;
        end
    end

    if JY.Thing[id]["需内力"] > JY.Person[personid]["内力最大值"] then
        return false;
    end
    if JY.Thing[id]["需攻击力"] > JY.Person[personid]["攻击力"] then
        return false;
    end
    if JY.Thing[id]["需轻功"] > JY.Person[personid]["轻功"] then
        return false;
    end
    if JY.Thing[id]["需用毒能力"] > JY.Person[personid]["用毒能力"] then
        return false;
    end
    if JY.Thing[id]["需医疗能力"] > JY.Person[personid]["医疗能力"] then
        return false;
    end
    if JY.Thing[id]["需解毒能力"] > JY.Person[personid]["解毒能力"] then
        return false;
    end
    if JY.Thing[id]["需拳掌功夫"] > JY.Person[personid]["拳掌功夫"] then
        return false;
    end
    if JY.Thing[id]["需御剑能力"] > JY.Person[personid]["御剑能力"] then
        return false;
    end
    if JY.Thing[id]["需耍刀技巧"] > JY.Person[personid]["耍刀技巧"] then
        return false;
    end
    if JY.Thing[id]["需特殊兵器"] > JY.Person[personid]["特殊兵器"] then
        return false;
    end
    if JY.Thing[id]["需暗器技巧"] > JY.Person[personid]["暗器技巧"] then
        return false;
    end
    if JY.Thing[id]["需资质"] >= 0 then
        if JY.Thing[id]["需资质"] > JY.Person[personid]["资质"] then
            return false;
        end
    else
        if -JY.Thing[id]["需资质"] < JY.Person[personid]["资质"] then
            return false;
        end
    end

    return true
end


--秘籍物品
function UseThing_Type2(id)               --秘籍物品使用
    if JY.Thing[id]["使用人"]>=0 then
        if DrawStrBoxYesNo(-1,-1,"此物品已经有人修炼，是否换人修炼?",C_WHITE,CC.DefaultFont)==false then
            Cls(CC.MainSubMenuX,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
            ShowScreen();
            return 0;
        end
    end

    Cls();
    DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,string.format("谁要修炼%s?",JY.Thing[id]["名称"]),C_WHITE,CC.DefaultFont);
    local nexty=CC.MainSubMenuY+CC.SingleLineHeight;
    local r=SelectTeamMenu(CC.MainSubMenuX,nexty);

    if r>0 then
        local personid=JY.Base["队伍" ..r]

        if JY.Thing[id]["练出武功"]>=0 then
            local yes=0;
            for i = 1,10 do
                if JY.Person[personid]["武功"..i]==JY.Thing[id]["练出武功"] then
                    yes=1;             --武功已经有了
                    break;
                end
            end
            if yes==0 and JY.Person[personid]["武功10"]>0 then
                DrawStrBoxWaitKey("一个人只能修炼10种武功",C_WHITE,CC.DefaultFont);
                return 0;
            end
        end

       if CC.Shemale[id]==1 then                --辟邪和葵花
            if JY.Person[personid]["性别"]==0 then
                Cls(CC.MainSubMenuX,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
                if DrawStrBoxYesNo(-1,-1,"修炼此书必须先挥刀自宫，是否仍要修炼?",C_WHITE,CC.DefaultFont)==false then
                    return 0;
                else
                    JY.Person[personid]["性别"]=2;
                end
            elseif JY.Person[personid]["性别"]==1 then
                DrawStrBoxWaitKey("此人不适合修炼此物品",C_WHITE,CC.DefaultFont);
                return 0;
            end
        end


        if CanUseThing(id,personid) then
            if JY.Thing[id]["使用人"]==personid then
                return 0;
            end

            if JY.Person[personid]["修炼物品"]>=0 then
                JY.Thing[JY.Person[personid]["修炼物品"]]["使用人"]=-1;
            end

            if JY.Thing[id]["使用人"]>=0 then
                JY.Person[JY.Thing[id]["使用人"]]["修炼物品"]=-1;
                JY.Person[JY.Thing[id]["使用人"]]["修炼点数"]=0;
                JY.Person[JY.Thing[id]["使用人"]]["物品修炼点数"]=0;
            end

            JY.Thing[id]["使用人"]=personid
            JY.Person[personid]["修炼物品"]=id;
            JY.Person[personid]["修炼点数"]=0;
            JY.Person[personid]["物品修炼点数"]=0;
        else
            DrawStrBoxWaitKey("此人不适合修炼此物品",C_WHITE,CC.DefaultFont);
            return 0;
        end
    end

    return 1;
end

--药品物品
function UseThing_Type3(id)        --药品物品使用
    local usepersonid=-1;
    if JY.Status==GAME_MMAP or JY.Status==GAME_SMAP then
        Cls(CC.MainSubMenuX,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
        DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,string.format("谁要使用%s?",JY.Thing[id]["名称"]),C_WHITE,CC.DefaultFont);
        local nexty=CC.MainSubMenuY+CC.SingleLineHeight;
        local r=SelectTeamMenu(CC.MainSubMenuX,nexty);
        if r>0 then
            usepersonid=JY.Base["队伍" ..r]
        end
    elseif JY.Status==GAME_WMAP then           ---战斗场景使用药品
        usepersonid=WAR.Person[WAR.CurID]["人物编号"];
    end

    if usepersonid>=0 then
        if UseThingEffect(id,usepersonid)==1 then       --使用有效果
            instruct_32(id,-1);            --物品数量减少
            WaitKey();
        else
            return 0;
        end
    end

 --   Cls();
 --   ShowScreen();
    return 1;
end

--药品使用实际效果
--id 物品id，
--personid 使用人id
--返回值：0 使用没有效果，物品数量应该不变。1 使用有效果，则使用后物品数量应该-1
function UseThingEffect(id,personid)          --药品使用实际效果
    local str={};
    str[0]=string.format("使用 %s",JY.Thing[id]["名称"]);
    local strnum=1;
    local addvalue;

    if JY.Thing[id]["加生命"] >0 then
        local add=JY.Thing[id]["加生命"]-math.modf(JY.Person[personid]["受伤程度"]/2)+Rnd(10);
        if add <=0 then
            add=5+Rnd(5);
        end
        AddPersonAttrib(personid,"受伤程度",-JY.Thing[id]["加生命"]/4);
        addvalue,str[strnum]=AddPersonAttrib(personid,"生命",add);
        if addvalue ~=0 then
            strnum=strnum+1
        end
    end

    local function ThingAddAttrib(s)     ---定义局部函数，处理吃药后增加属性
        if JY.Thing[id]["加" .. s] ~=0 then
            addvalue,str[strnum]=AddPersonAttrib(personid,s,JY.Thing[id]["加" .. s]);
            if addvalue ~=0 then
                strnum=strnum+1
            end
        end
    end

    ThingAddAttrib("生命最大值");

    if JY.Thing[id]["加中毒解毒"] <0 then
        addvalue,str[strnum]=AddPersonAttrib(personid,"中毒程度",math.modf(JY.Thing[id]["加中毒解毒"]/2));
        if addvalue ~=0 then
            strnum=strnum+1
        end
    end

    ThingAddAttrib("体力");

    if JY.Thing[id]["改变内力性质"] ==2 then
        str[strnum]="内力门路改为阴阳合一"
        strnum=strnum+1
    end

    ThingAddAttrib("内力");
    ThingAddAttrib("内力最大值");
    ThingAddAttrib("攻击力");
    ThingAddAttrib("防御力");
    ThingAddAttrib("轻功");
    ThingAddAttrib("医疗能力");
    ThingAddAttrib("用毒能力");
    ThingAddAttrib("解毒能力");
    ThingAddAttrib("抗毒能力");
    ThingAddAttrib("拳掌功夫");
    ThingAddAttrib("御剑能力");
    ThingAddAttrib("耍刀技巧");
    ThingAddAttrib("特殊兵器");
    ThingAddAttrib("暗器技巧");
    ThingAddAttrib("武学常识");
    ThingAddAttrib("攻击带毒");

    if strnum>1 then
        local maxlength=0      --计算字符串最大长度
        for i = 0,strnum-1 do
            if #str[i] > maxlength then
                maxlength=#str[i];
            end
        end
        Cls();

        local ww=maxlength*CC.DefaultFont/2+CC.MenuBorderPixel*2;
        local hh=strnum*CC.DefaultFont+(strnum-1)*CC.RowPixel+2*CC.MenuBorderPixel;
        local x=(CC.ScreenW-ww)/2;
        local y=(CC.ScreenH-hh)/2;
        DrawBox(x,y,x+ww,y+hh,C_WHITE);
        DrawString(x+CC.MenuBorderPixel,y+CC.MenuBorderPixel,str[0],C_WHITE,CC.DefaultFont);
        for i =1,strnum-1 do
            DrawString(x+CC.MenuBorderPixel,y+CC.MenuBorderPixel+(CC.DefaultFont+CC.RowPixel)*i,str[i],C_ORANGE,CC.DefaultFont);
        end
        ShowScreen();
        return 1;
    else
        return 0;
    end

end


--暗器物品
function UseThing_Type4(id)             --暗器物品使用
    if JY.Status==GAME_WMAP then
         return War_UseAnqi(id);
    end
    return 0;
end



--------------------------------------------------------------------------------
--------------------------------------事件调用-----------------------------------

--事件调用主入口
--id，d*中的编号
--flag 1 空格触发，2，物品触发，3，路过触发
function EventExecute(id,flag)               --事件调用主入口
    JY.CurrentD=id;
    EngineAPI.debug.log(string.format("EventExecute: id=%d, flag=%d, SubScene=%d", id, flag, JY.SubScene));
    if JY.SceneNewEventFunction[JY.SubScene]==nil then         --没有定义新的事件处理函数，调用旧的
        EngineAPI.debug.log("EventExecute: calling oldEventExecute");
        oldEventExecute(flag)
    else
        EngineAPI.debug.log("EventExecute: calling SceneNewEventFunction");
        JY.SceneNewEventFunction[JY.SubScene](flag)         --调用新的事件处理函数
    end
    JY.CurrentD=-1;
    JY.Darkness=0;
end

--调用原有的指定位置的函数
--旧的函数名字格式为  oldevent_xxx();  xxx为事件编号
function oldEventExecute(flag)            --调用原有的指定位置的函数

    local eventnum;
    if flag==1 then
        eventnum=GetD(JY.SubScene,JY.CurrentD,2);
    elseif flag==2 then
        eventnum=GetD(JY.SubScene,JY.CurrentD,3);
    elseif flag==3 then
        eventnum=GetD(JY.SubScene,JY.CurrentD,4);
    end

    EngineAPI.debug.log(string.format("oldEventExecute: flag=%d, CurrentD=%d, eventnum=%d", flag, JY.CurrentD, eventnum or -1));

    if eventnum>0 then
        oldCallEvent(eventnum);
    end

end

function oldCallEvent(eventnum)     --执行旧的事件函数
    local eventfilename=string.format("oldevent_%d.lua",eventnum);
    EngineAPI.debug.log(string.format("oldCallEvent: eventnum=%d, filename=%s", eventnum, eventfilename));
    local chunk, err = ScriptLoader.load(CONFIG.OldEventPath .. eventfilename)
    if chunk then
        chunk()
    else
        JY_Error("oldCallEvent load failed: %s (%s)", tostring(eventfilename), tostring(err))
    end
    EngineAPI.debug.log(string.format("oldCallEvent: eventnum=%d finished", eventnum));
end


--改变大地图坐标，从场景出去后移动到相应坐标
function ChangeMMap(x,y,direct)          --改变大地图坐标
    JY.Base["人X"]=x;
    JY.Base["人Y"]=y;
    JY.Base["人方向"]=direct;
end

--改变当前场景
function ChangeSMap(sceneid,x,y,direct)       --改变当前场景
    JY.SubScene=sceneid;
    JY.Base["人X1"]=x;
    JY.Base["人Y1"]=y;
    JY.Base["人方向"]=direct;
end


--清除(x1,y1)-(x2,y2)矩形内的文字等。
--如果没有参数，则清除整个屏幕表面
--注意该函数并不直接刷新显示屏幕
function Cls(x1,y1,x2,y2)                    --清除屏幕
    if x1==nil then        --第一个参数为nil,表示没有参数，用缺省
        x1=0;
        y1=0;
        x2=0;
        y2=0;
    end

    EngineAPI.debug.log(string.format("Cls called: x1=%s, y1=%s, x2=%s, y2=%s, Status=%d", tostring(x1), tostring(y1), tostring(x2), tostring(y2), JY.Status));
    EngineAPI.render.setClip(x1,y1,x2,y2);

    if JY.Status==GAME_START then
        EngineAPI.render.fillRect(0,0,0,0,0);
        EngineAPI.sprite.drawPictureFile(CC.FirstFile,-1,-1);
    elseif JY.Status==GAME_MMAP then
        EngineAPI.map.drawMain(JY.Base["人X"],JY.Base["人Y"],GetMyPic());             --显示主地图
    elseif JY.Status==GAME_SMAP then
        DrawSMap();
    elseif JY.Status==GAME_WMAP then
        WarDrawMap(0);
    elseif JY.Status==GAME_DEAD then
        EngineAPI.render.fillRect(0,0,0,0,0);
        EngineAPI.sprite.drawPictureFile(CC.DeadFile,-1,-1);
    end
    EngineAPI.render.setClip(0,0,0,0);
end


--产生对话显示需要的字符串，即每隔n个中文字符加一个星号
function GenTalkString(str,n)              --产生对话显示需要的字符串
    local tmpstr="";
    for s in string.gmatch(str .. "*","(.-)%*") do           --去掉对话中的所有*. 字符串尾部加一个星号，避免无法匹配
        tmpstr=tmpstr .. s;
    end

    local newstr="";
    while #tmpstr>0 do
        local w=0;
        while w<#tmpstr do
            local v=string.byte(tmpstr,w+1);          --当前字符的值
            if v>=128 then
                w=w+2;
            else
                w=w+1;
            end
            if w >= 2*n-1 then     --为了避免跨段中文字符
                break;
            end
        end

        if w<#tmpstr then
            if w==2*n-1 and string.byte(tmpstr,w+1)<128 then
                newstr=newstr .. string.sub(tmpstr,1,w+1) .. "*";
                tmpstr=string.sub(tmpstr,w+2,-1);
            else
                newstr=newstr .. string.sub(tmpstr,1,w)  .. "*";
                tmpstr=string.sub(tmpstr,w+1,-1);
            end
        else
            newstr=newstr .. tmpstr;
            break;
        end
    end
    return newstr;
end

--最简单版本对话
function Talk(s,personid)            --最简单版本对话
    local flag;
    if personid==0 then
        flag=1;
    else
        flag=0;
    end
    TalkEx(s,JY.Person[personid]["头像代号"],flag);
end


--复杂版本对话
--s 字符串，必须加上*作为分行，如果里面没有*,则会自动加上
function TalkEx(s,headid,flag)          --复杂版本对话
    EngineAPI.debug.log(string.format("TalkEx called: headid=%d, flag=%d, s=%s", headid, flag, string.sub(s, 1, 30)));

    if flag<0 or flag>5 then
        flag=0;
    end

    -- 排版交由引擎：对话框属于渲染介质相关决策。
    -- EngineAPI.dialog.measure 是纯函数（Love2D 用真实 font:getWidth/getHeight，
    -- 汉字 1.0em、ASCII 0.5em、行高 27px），因此本函数不再自算坐标。
    local spec = { text = s, headId = headid, flag = flag };
    local layout = EngineAPI.dialog.measure(spec);
    local dialog = EngineAPI.dialog;

    if CONFIG.KeyRepeat==0 then
         EngineAPI.input.enableKeyRepeat(0,CONFIG.KeyRepeatInterval);
    end
    EngineAPI.input.getKey();

    if not layout or not layout.lines or #layout.lines == 0 then
        -- 引擎未实现排版（非图形引擎）：直接结束
        if CONFIG.KeyRepeat==0 then
             EngineAPI.input.enableKeyRepeat(CONFIG.KeyRepeatDelay,CONFIG.KeyRepeatInterval);
        end
        Cls();
        return;
    end

    -- 按每页行数分页
    local perPage = layout.linesPerPage or 3;
    local total = #layout.lines;
    local pageStart = 1;

    while pageStart <= total do
        -- 取当前页的行
        local pageLines = {};
        for i = pageStart, math.min(pageStart + perPage - 1, total) do
            pageLines[#pageLines + 1] = layout.lines[i];
        end

        Cls();

        -- 构造单页视图（框宽/锚点/行高沿用整段排版，只有 lines 换成本页）
        local pageLayout = {
            width = layout.width,
            height = layout.height,
            lineHeight = layout.lineHeight,
            lines = pageLines,
            pages = layout.pages,
            linesPerPage = perPage,
            headId = layout.headId,
            flag = layout.flag,
            headBox = layout.headBox,
            textBox = layout.textBox,
            border = layout.border,
            lineY = layout.lineY,
            fontSize = layout.fontSize,
            showHead = layout.showHead,
        };

        dialog.draw(spec, pageLayout);
        ShowScreen();
        WaitKey();

        pageStart = pageStart + perPage;
    end

    if CONFIG.KeyRepeat==0 then
         EngineAPI.input.enableKeyRepeat(CONFIG.KeyRepeatDelay,CONFIG.KeyRepeatInterval);
    end

    Cls();
end


--测试指令，占位置用
function instruct_test(s)
    DrawStrBoxWaitKey(s,C_ORANGE,24);
end

--清屏
function instruct_0()         --清屏
    EngineAPI.debug.log("instruct_0: START");
    Cls();
    EngineAPI.debug.log("instruct_0: FINISHED");
end

--对话
--talkid: 为数字，则为对话编号；为字符串，则为对话本身。
--headid: 头像id
--flag :对话框位置：0 屏幕上方显示, 左边头像，右边对话
--            1 屏幕下方显示, 左边对话，右边头像
--            2 屏幕上方显示, 左边空，右边对话
--            3 屏幕下方显示, 左边对话，右边空
--            4 屏幕上方显示, 左边对话，右边头像
--            5 屏幕下方显示, 左边头像，右边对话

function instruct_1(talkid,headid,flag)        --对话
    EngineAPI.debug.log(string.format("instruct_1: START talkid=%d, headid=%d, flag=%d", talkid, headid, flag));
    local s=ReadTalk(talkid);
    if s==nil then        --对话id不存在
        EngineAPI.debug.log(string.format("instruct_1: talkid=%d not found", talkid));
        return ;
    end
    EngineAPI.debug.log(string.format("instruct_1: calling TalkEx with talkid=%d", talkid));
    TalkEx(s,headid,flag);
    EngineAPI.debug.log(string.format("instruct_1: FINISHED talkid=%d", talkid));
end

--根据oldtalk.grp文件来idx索引文件。供后面读对话使用
function GenTalkIdx()         --生成对话索引文件
    local band = bit32 and bit32.band
    local rshift = bit32 and bit32.rshift

    -- 索引已存在且格式合法时直接复用，避免每次启动全量重建
    -- 通过 FileUtil.getInfo 获取文件信息（内部委托 EngineAPI.file.getInfo），不直接依赖 love
    local idxInfo = FileUtil.getInfo(CC.TalkIdxFile)
    local grpInfo = FileUtil.getInfo(CC.TalkGrpFile)
    local idxSize = FileUtil.getsize(CC.TalkIdxFile)
    if idxSize and idxSize > 0 and idxSize % 4 == 0 and idxInfo and grpInfo and idxInfo.modtime and grpInfo.modtime and idxInfo.modtime >= grpInfo.modtime then
        return
    end

    p=FileUtil.open(CC.TalkGrpFile,"r");
    if p == nil then
        return;
    end
    local num=0
    for line in p:lines() do
        num=num+1;
    end
    p:seek("set",0);
    local out=FileUtil.open(CC.TalkIdxFile,"wb");
    if out == nil then
        p:close();
        return;
    end

    for i=0,num-1 do
        local talk=p:read("*line");
        local offset=p:seek();
        local b1, b2, b3, b4
        if band and rshift then
            b1 = band(offset, 0xFF)
            b2 = band(rshift(offset, 8), 0xFF)
            b3 = band(rshift(offset, 16), 0xFF)
            b4 = band(rshift(offset, 24), 0xFF)
        else
            local n = offset
            b1 = n % 256
            n = math.floor(n / 256)
            b2 = n % 256
            n = math.floor(n / 256)
            b3 = n % 256
            n = math.floor(n / 256)
            b4 = n % 256
        end
        out:write(string.char(b1, b2, b3, b4))
    end
    p:close();
    out:close();
end

--从old_talk.lua中读取编号为talkid的字符串。
--需要的时候读取，可以节约内存占用，不用再把整个文件读入内存数据了。
function ReadTalk(talkid)            --从文件读取一条对话
    local idxfile=CC.TalkIdxFile
    local grpfile=CC.TalkGrpFile

    local length=filelength(idxfile);

    if talkid<0 or talkid>=length/4 then
        EngineAPI.debug.log(string.format("ReadTalk: talkid=%d out of range", talkid));
        return
    end

    local data=Byte.create(2*4);
    local id1,id2;
    if talkid==0 then
        Byte.loadfile(data,idxfile,0,4);
        id1=0;
        id2=Byte.get32(data,0);
    else
        Byte.loadfile(data,idxfile,(talkid-1)*4,4*2);
        id1=Byte.get32(data,0);
        id2=Byte.get32(data,4);
    end

    local p=FileUtil.open(grpfile,"r");
    if p == nil then
        return nil;
    end
    p:seek("set",id1);
    local talk=p:read("*line");
    p:close();

    EngineAPI.debug.log(string.format("ReadTalk: talkid=%d, talk=%s", talkid, string.sub(talk or "nil", 1, 30)));

    return talk;

end


--得到物品
function instruct_2(thingid,num)            --得到物品
    if JY.Thing[thingid]==nil then   --无此物品id
        return ;
    end

    instruct_32(thingid,num);    --增加物品
    DrawStrBoxWaitKey(string.format("得到物品:%s %d",JY.Thing[thingid]["名称"],num),C_ORANGE,CC.DefaultFont);
    instruct_2_sub();         --是否可得武林帖
end

--声望>200以及14天书后得到武林帖
function instruct_2_sub()               --声望>200以及14天书后得到武林帖

    if JY.Person[0]["声望"] < 200 then
        return ;
    end

    if instruct_18(189) ==true then            --有武林帖， 189 武林帖id
        return;
    end

    local booknum=0;
    for i=1,CC.BookNum do
        if instruct_18(CC.BookStart+i-1)==true then
            booknum=booknum+1;
        end
    end

    if booknum==CC.BookNum then        --设置主角居桌子上的武林帖事件
        instruct_3(70,11,-1,1,932,-1,-1,7968,7968,7968,-2,-2,-2);
    end
end

--修改D*
-- sceneid 场景id, -2表示当前场景
-- id  D*的id， -2表示当前id
-- v0 - v10 D*参数， -2表示此参数不变
function instruct_3(sceneid,id,v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10)     --修改D*
    if sceneid==-2 then
        sceneid=JY.SubScene;
    end
    if id==-2 then
        id=JY.CurrentD;
    end

    if v0~=-2 then
        SetD(sceneid,id,0,v0)
    end
    if v1~=-2 then
        SetD(sceneid,id,1,v1)
    end
    if v2~=-2 then
        SetD(sceneid,id,2,v2)
    end
    if v3~=-2 then
        SetD(sceneid,id,3,v3)
    end
    if v4~=-2 then
        SetD(sceneid,id,4,v4)
    end
    if v5~=-2 then
        SetD(sceneid,id,5,v5)
    end
    if v6~=-2 then
        SetD(sceneid,id,6,v6)
    end
    if v7~=-2 then
        SetD(sceneid,id,7,v7)
    end
    if v8~=-2 then
        SetD(sceneid,id,8,v8)
    end

    if v9~=-2 and v10 ~=-2 then
        if v9>0 and v10 >0 then   --为了和苍龙兼容，修改的坐标不能为0
            SetS(sceneid,GetD(sceneid,id,9),GetD(sceneid,id,10),3,-1);   --如果xy坐标移动了，那么S中相应数据要修改。
            SetD(sceneid,id,9,v9)
            SetD(sceneid,id,10,v10)
            SetS(sceneid,GetD(sceneid,id,9),GetD(sceneid,id,10),3,id);
        end
    end
end

--是否使用物品触发
function instruct_4(thingid)         --是否使用物品触发
    if JY.CurrentThing==thingid then
        return true;
    else
        return false;
    end
end


function instruct_5()         --选择战斗
    return DrawStrBoxYesNo(-1,-1,"是否与之过招(Y/N)?",C_ORANGE,CC.DefaultFont);
end


function instruct_6(warid,tmp,tmp2,flag)      --战斗
    local co = coroutine.running()
    local isexp = (flag == 0) and 0 or (flag or 1)
    if co then
        EngineAPI.debug.log("instruct_6: running in coroutine, warid=" .. warid .. ", flag=" .. tostring(flag) .. ", isexp=" .. tostring(isexp))
        -- 注意：必须写全 framework.* 前缀。裸名 "coroutine_scheduler"/"war_async"
        -- 在 package.path 下找不到（实测 require 直接失败），会让 instruct_6
        -- 在协程分支抛错、整场战斗无法开始。
        local scheduler = require("framework.coroutine_scheduler").getInstance()
        local WarAsync = require("framework.war_async")
        
        EngineAPI.debug.log("instruct_6: creating battle sub-coroutine")
        local warCo = scheduler:create(function()
            return WarAsync.WarMainCoroutine(warid, isexp)
        end, "battle_sub")
        
        EngineAPI.debug.log("instruct_6: created sub-coroutine id=" .. tostring(warCo))
        
        scheduler:start(warCo)
        EngineAPI.debug.log("instruct_6: started sub-coroutine, now waiting")
        
        -- 等待战斗协程结束
        local waitCount = 0
        while scheduler:isActive(warCo) do
            waitCount = waitCount + 1
            if waitCount % 100 == 0 then
                EngineAPI.debug.log("instruct_6: waiting for battle, count=" .. waitCount .. ", isActive=" .. tostring(scheduler:isActive(warCo)))
            end
            scheduler:yield("battle_person_done")
        end
        
        local result = scheduler:getResult(warCo)
        EngineAPI.debug.log("instruct_6: battle ended, result=" .. tostring(result))
        return result
    else
        EngineAPI.debug.log("instruct_6: NOT in coroutine, warid=" .. warid .. ", using blocking WarMain")
        return WarMain(warid, isexp)
    end
end


function instruct_7()                 --已经翻译为return了
    instruct_test("指令7测试")
end


function instruct_8(musicid)            --改变主地图音乐
    JY.MmapMusic=musicid;
end


function instruct_9()                --是否要求加入队伍
    Cls();
    return DrawStrBoxYesNo(-1,-1,"是否要求加入(Y/N)?",C_ORANGE,CC.DefaultFont);
end


function instruct_10(personid)            --加入队员
    if JY.Person[personid]==nil then
        EngineAPI.debug.log("instruct_10 error: person id not exist");
        return ;
    end
    -- 防重复入队：若该角色已在队伍中（不区分其当前所在地），直接返回，避免因
    -- 重复触发加入剧情（如重复对话、事件在同 tile 多实体上重复分发）而产生两份相同队员。
    for i =1, CC.TeamNum do
        if JY.Base and JY.Base["队伍"..i]==personid then
            EngineAPI.debug.log("instruct_10 info: person "..tostring(personid).." already in team, skip duplicate join");
            return ;
        end
    end
    local add=0;
    for i =2, CC.TeamNum do             --第一个位置是主角，从第二个开始
        if JY.Base["队伍"..i]<0 then
            JY.Base["队伍"..i]=personid;
            add=1;
            break;
        end
    end
    if add==0 then
        EngineAPI.debug.log("instruct_10 error: 加入队伍已满");
        return ;
    end

    for i =1,4 do                --个人物品归公
        local id =JY.Person[personid]["携带物品" .. i];
        local n=JY.Person[personid]["携带物品数量" .. i];
        if id>=0 and n>0 then
            instruct_2(id,n);
            JY.Person[personid]["携带物品" .. i]=-1;
            JY.Person[personid]["携带物品数量" .. i]=0;
        end
    end
end


function instruct_11()              --是否住宿
    Cls();
    return DrawStrBoxYesNo(-1,-1,"是否住宿(Y/N)?",C_ORANGE,CC.DefaultFont);
end


function instruct_12()             --住宿，回复体力
    for i=1,CC.TeamNum do
        local id=JY.Base["队伍" .. i];
        if id>=0 then
            if JY.Person[id]["受伤程度"]<33 and JY.Person[id]["中毒程度"]<=0 then
                JY.Person[id]["受伤程度"]=0;
                AddPersonAttrib(id,"体力",math.huge);     --给一个很大的值，自动限制为最大值
                AddPersonAttrib(id,"生命",math.huge);
                AddPersonAttrib(id,"内力",math.huge);
            end
        end
    end
end


function instruct_13()            --场景变亮
    Cls();
    JY.Darkness=0;
    EngineAPI.render.present()
    EngineAPI.input.getKey();
end


function instruct_14()             --场景变黑
    EngineAPI.render.present();
    JY.Darkness=1;
end

function instruct_15()          --game over
    JY.Status=GAME_DEAD;
    Cls();
    DrawString(CC.GameOverX,CC.GameOverY,JY.Person[0]["姓名"],RGB(0,0,0),CC.DefaultFont);

    local x=CC.ScreenW-9*CC.DefaultFont;
    DrawString(x,10,os.date("%Y-%m-%d %H:%M"),RGB(216, 20, 24) ,CC.DefaultFont);
    DrawString(x,10+CC.DefaultFont+CC.RowPixel,"在地球的某处",RGB(216, 20, 24) ,CC.DefaultFont);
    DrawString(x,10+(CC.DefaultFont+CC.RowPixel)*2,"当地人口的失踪数",RGB(216, 20, 24) ,CC.DefaultFont);
    DrawString(x,10+(CC.DefaultFont+CC.RowPixel)*3,"又多了一笔。。。",RGB(216, 20, 24) ,CC.DefaultFont);

    local loadMenu={ {"载入进度一",nil,1},
                     {"载入进度二",nil,1},
                     {"载入进度三",nil,1},
                     {"回家睡觉去",nil,1} };
    local y=CC.ScreenH-4*(CC.DefaultFont+CC.RowPixel)-10;
    local r=ShowMenu(loadMenu,4,0,x,y,0,0,0,0,CC.DefaultFont,C_ORANGE, C_WHITE)

    if r<4 then
        LoadRecord(r);
        JY.Status=GAME_FIRSTMMAP;
    else
        JY.Status=GAME_END;
    end

end


function instruct_16(personid)      --队伍中是否有某人
    local r=false;
    for i = 1, CC.TeamNum do
        if personid==JY.Base["队伍" .. i] then
            r=true;
            break;
        end
    end;
    return r;
end


function instruct_17(sceneid,level,x,y,v)     --修改场景图形
    if sceneid==-2 then
        sceneid=JY.SubScene;
    end
    SetS(sceneid,x,y,level,v);
end


function instruct_18(thingid)           --是否有某种物品
    for i = 1,CC.MyThingNum do
        if JY.Base["物品" .. i]==thingid then
            return true;
        end
    end
    return false;
end


function instruct_19(x,y)             --改变主角位置
    JY.Base["人X1"]=x;
    JY.Base["人Y1"]=y;
    JY.SubSceneX=0;
    JY.SubSceneY=0;
end


function instruct_20()                 --判断队伍是否满
    if JY.Base["队伍" .. CC.TeamNum ] >=0 then
        return true;
    end
    return false;
end


function instruct_21(personid)               --离队
    if JY.Person[personid]==nil then
        EngineAPI.debug.log("instruct_21 error: personid not exist");
        return ;
    end
    local j=0;
    for i = 1, CC.TeamNum do
        if personid==JY.Base["队伍" .. i] then
            j=i;
            break;
        end
    end;
    if j==0 then
       return;
    end

    for  i=j+1,CC.TeamNum do
        JY.Base["队伍" .. i-1]=JY.Base["队伍" .. i];
    end
    JY.Base["队伍" .. CC.TeamNum]=-1;

    if JY.Person[personid]["武器"]>=0 then
        JY.Thing[JY.Person[personid]["武器"]]["使用人"]=-1;
        JY.Person[personid]["武器"]=-1
    end
    if JY.Person[personid]["防具"]>=0 then
        JY.Thing[JY.Person[personid]["防具"]]["使用人"]=-1;
        JY.Person[personid]["防具"]=-1;
    end

    if JY.Person[personid]["修炼物品"]>=0 then
        JY.Thing[JY.Person[personid]["修炼物品"]]["使用人"]=-1;
        JY.Person[personid]["修炼物品"]=-1;
    end

    JY.Person[personid]["修炼点数"]=0;
    JY.Person[personid]["物品修炼点数"]=0;
end


function instruct_22()            --内力降为0
    for i = 1, CC.TeamNum do
        if JY.Base["队伍" .. i] >=0 then
            JY.Person[JY.Base["队伍" .. i]]["内力"]=0;
        end
    end
end


function instruct_23(personid,value)           --设置用毒
    JY.Person[personid]["用毒能力"]=value;
    AddPersonAttrib(personid,"用毒能力",0)
end

--空指令
function instruct_24()
    instruct_test("指令24测试")
end

--场景移动
--为简化，实际上是场景移动(x2-x1)，(y2-y1)。先y后x。因此，x1,y1可设为0
function instruct_25(x1,y1,x2,y2)             --场景移动
    local sign;
    if y1 ~= y2 then
        if y2<y1 then
            sign=-1;
        else
            sign=1;
        end
        for i=y1+sign,y2,sign do
            local t1=EngineAPI.time.getTime();
            JY.SubSceneY=JY.SubSceneY+sign;
            --JY.oldSMapX=-1;
            --JY.oldSMapY=-1;
            DrawSMap();
            ShowScreen();
            local t2=EngineAPI.time.getTime();
            if (t2-t1)<CC.SceneMoveFrame then
                WaitFrame(CC.SceneMoveFrame-(t2-t1));
            end
        end
    end

    if x1 ~= x2 then
        if x2<x1 then
            sign=-1;
        else
            sign=1;
        end
        for i=x1+sign,x2,sign do
            local t1=EngineAPI.time.getTime();
            JY.SubSceneX=JY.SubSceneX+sign;
            --JY.oldSMapX=-1;
            --JY.oldSMapY=-1;

            DrawSMap();
            ShowScreen();
            local t2=EngineAPI.time.getTime();
            if (t2-t1)<CC.SceneMoveFrame then
                WaitFrame(CC.SceneMoveFrame-(t2-t1));
            end
        end
    end
end


function instruct_26(sceneid,id,v1,v2,v3)           --增加D*编号
    if sceneid==-2 then
        sceneid=JY.SubScene;
    end

    local v=GetD(sceneid,id,2);
    SetD(sceneid,id,2,v+v1);
    v=GetD(sceneid,id,3);
    SetD(sceneid,id,3,v+v2);
    v=GetD(sceneid,id,4);
    SetD(sceneid,id,4,v+v3);
end

--显示动画 id=-1 主角位置动画
-- 事件驱动架构版本：设置动画状态，由 GAME_SMAP.update 驱动
function instruct_27(id,startpic,endpic)           --显示动画
    local startTime = EngineAPI.time.getTime()
    EngineAPI.debug.log(string.format("instruct_27: START id=%d, startpic=%d, endpic=%d, time=%d", id, startpic, endpic, startTime));
    local old1,old2,old3;
    if id ~=-1 then
        old1=GetD(JY.SubScene,id,5);
        old2=GetD(JY.SubScene,id,6);
        old3=GetD(JY.SubScene,id,7);
    end

    -- 获取协程调度器
    local scheduler = nil
    if coroutine.running() then
        scheduler = require("framework.coroutine_scheduler").getInstance()
    end
    
    if scheduler then
        -- 事件驱动架构：设置动画状态，由 GAME_SMAP.update 驱动
        JY.AnimationState = {
            active = true,
            id = id,
            startFrame = startpic,
            endFrame = endpic,
            currentFrame = startpic,
            startTime = EngineAPI.time.getTime(),
            frameDuration = CC.AnimationFrame,
        }
        EngineAPI.debug.log(string.format("instruct_27: set AnimationState id=%d, startFrame=%d, endFrame=%d", id, startpic, endpic))
        -- 等待动画完成
        -- 使用 yield 让出协程，让 GAME_SMAP.update 播放动画
        while JY.AnimationState.active do
            scheduler:yield("animation")
        end
        
        -- 动画结束后重置 currentFrame
        JY.AnimationState.currentFrame = 0
        EngineAPI.debug.log("instruct_27: animation finished, currentFrame reset to 0")
    else
        -- 不在协程中，使用原版同步方式
        for i = startpic, endpic, 2 do
            local t1 = EngineAPI.time.getTime();
            
            -- 设置当前帧
            if id == -1 then
                JY.MyPic = i / 2;
                EngineAPI.debug.log(string.format("instruct_27: frame id=-1, i=%d, MyPic=%d", i, JY.MyPic));
            else
                SetD(JY.SubScene, id, 5, i);
                SetD(JY.SubScene, id, 6, i);
                SetD(JY.SubScene, id, 7, i);
                EngineAPI.debug.log(string.format("instruct_27: frame id=%d, i=%d", id, i));
            end
            
            -- 更新场景数据
            DtoSMap();
            
            -- 原版方式：直接绘制和显示
            DrawSMap();
            ShowScreen();
            local t2 = EngineAPI.time.getTime();
            if t2 - t1 < CC.AnimationFrame then
                WaitFrame(CC.AnimationFrame - (t2 - t1));
            end
        end
    end
    
    -- 注意：不恢复原始MyPic，让动画贴图保持到事件结束
    -- 事件执行完毕后，由调用方恢复
    -- JY.MyPic = originalMyPic
    
    if id ~=-1 then
        SetD(JY.SubScene,id,5,old1);
        SetD(JY.SubScene,id,6,old2);
        SetD(JY.SubScene,id,7,old3);
    end
    local endTime = EngineAPI.time.getTime()
    EngineAPI.debug.log(string.format("instruct_27: END id=%d, final MyPic=%d, duration=%dms", id, JY.MyPic, endTime - startTime));
end

--判断品德
function instruct_28(personid,vmin,vmax)          --判断品德
    local v=JY.Person[personid]["品德"];
    if v >=vmin and v<=vmax then
        return true;
    else
        return false;
    end
end

--判断攻击力
function instruct_29(personid,vmin,vmax)           --判断攻击力
    local v=JY.Person[personid]["攻击力"];
    if v >=vmin and v<=vmax then
        return true;
    else
        return false
    end
end

--主角走动
--为简化，走动使用相对值(x2-x1)(y2-y1),因此x1,y1可以为0，不必一定要为当前坐标。
function instruct_30(x1,y1,x2,y2)                --主角走动
    --Cls();
    --ShowScreen();

    if x1<x2 then
        for i=x1+1,x2 do
            local t1=EngineAPI.time.getTime();
            instruct_30_sub(1);
            local t2=EngineAPI.time.getTime();
            if (t2-t1)<CC.PersonMoveFrame then
                WaitFrame(CC.PersonMoveFrame-(t2-t1));
            end
        end
    elseif x1>x2 then
        for i=x2+1,x1 do
            local t1=EngineAPI.time.getTime();
            instruct_30_sub(2);
            local t2=EngineAPI.time.getTime();
            if (t2-t1)<CC.PersonMoveFrame then
                WaitFrame(CC.PersonMoveFrame-(t2-t1));
            end
        end
    end

    if y1<y2 then
        for i=y1+1,y2 do
            local t1=EngineAPI.time.getTime();
            instruct_30_sub(3);
            local t2=EngineAPI.time.getTime();
            if (t2-t1)<CC.PersonMoveFrame then
                WaitFrame(CC.PersonMoveFrame-(t2-t1));
            end
        end
    elseif y1>y2 then
        for i=y2+1,y1 do
            local t1=EngineAPI.time.getTime();
            instruct_30_sub(0);
            local t2=EngineAPI.time.getTime();
            if (t2-t1)<CC.PersonMoveFrame then
                WaitFrame(CC.PersonMoveFrame-(t2-t1));
            end
        end
    end
end

--主角走动sub
function instruct_30_sub(direct)            --主角走动sub
    local x,y;
    AddMyCurrentPic();
    x=JY.Base["人X1"]+CC.DirectX[direct+1];
    y=JY.Base["人Y1"]+CC.DirectY[direct+1];
    JY.Base["人方向"]=direct;
    JY.MyPic=GetMyPic();
    DtoSMap();

    if  SceneCanPass(x,y)==true then
        JY.Base["人X1"]=x;
        JY.Base["人Y1"]=y;
    end
    JY.Base["人X1"]=limitX(JY.Base["人X1"],1,CC.SWidth-2);
    JY.Base["人Y1"]=limitX(JY.Base["人Y1"],1,CC.SHeight-2);

    DrawSMap();
--    Cls();
    ShowScreen();
end

--判断是否够钱
function instruct_31(num)             --判断是否够钱
    local r=false;
    for i =1,CC.MyThingNum do
        if JY.Base["物品" .. i]==CC.MoneyID then
            if JY.Base["物品数量" .. i]>=num then
                r=true;
            end
            break;
        end
    end
    return r;
end

--增加物品
--num 物品数量，负数则为减少物品
function instruct_32(thingid,num)           --增加物品
    local p=1;
    for i=1,CC.MyThingNum do
        if JY.Base["物品" .. i]==thingid then
            JY.Base["物品数量" .. i]=JY.Base["物品数量" .. i]+num
            p=i;
            break;
        elseif JY.Base["物品" .. i]==-1 then
            JY.Base["物品" .. i]=thingid;
            JY.Base["物品数量" .. i]=num;
            p=1;
            break;
        end
    end

    if JY.Base["物品数量" .. p] <=0 then
        for i=p+1,CC.MyThingNum do
            JY.Base["物品" .. i-1]=JY.Base["物品" .. i];
            JY.Base["物品数量" .. i-1]=JY.Base["物品数量" .. i];
        end
        JY.Base["物品" .. CC.MyThingNum]=-1;
        JY.Base["物品数量" .. CC.MyThingNum]=0;
    end
end

--学会武功
function instruct_33(personid,wugongid,flag)           --学会武功
    local add=0;
    for i=1,10 do
        if JY.Person[personid]["武功" .. i]==0 then
            JY.Person[personid]["武功" .. i]=wugongid;
            JY.Person[personid]["武功等级" .. i]=0;
            add=1
            break;
        end
    end

    if add==0 then      --，武功已满，覆盖最后一个武功
        JY.Person[personid]["武功10" ]=wugongid;
        JY.Person[personid]["武功等级10"]=0;
    end

    if flag==0 then
        DrawStrBoxWaitKey(string.format("%s 学会武功 %s",JY.Person[personid]["姓名"],JY.Wugong[wugongid]["名称"]),C_ORANGE,CC.DefaultFont);
    end
end

--资质增加
function instruct_34(id,value)              --资质增加
    local add,str=AddPersonAttrib(id,"资质",value);
    DrawStrBoxWaitKey(JY.Person[id]["姓名"] .. str,C_ORANGE,CC.DefaultFont);
end

--设置武功
function instruct_35(personid,id,wugongid,wugonglevel)         --设置武功
    if id>=0 then
        JY.Person[personid]["武功" .. id+1]=wugongid;
        JY.Person[personid]["武功等级" .. id+1]=wugonglevel;
    else
        local flag=0;
        for i =1,10 do
            if JY.Person[personid]["武功" .. i]==0 then
                flag=1;
                JY.Person[personid]["武功" .. i]=wugongid;
                JY.Person[personid]["武功等级" .. i]=wugonglevel;
                return;
            end
        end
        if flag==0 then
            JY.Person[personid]["武功" .. 1]=wugongid;
            JY.Person[personid]["武功等级" .. 1]=wugonglevel;
        end
    end
end

--判断主角性别
function instruct_36(sex)               --判断主角性别
    if JY.Person[0]["性别"]==sex then
        return true;
    else
        return false;
    end
end


function instruct_37(v)              --增加品德
    AddPersonAttrib(0,"品德",v);
end

--修改场景某层贴图
function instruct_38(sceneid,level,oldpic,newpic)         --修改场景某层贴图
    if sceneid==-2 then
        sceneid=JY.SubScene;
    end

    for i=0,CC.SWidth-1 do
        for j=1, CC.SHeight-1 do
            if GetS(sceneid,i,j,level)==oldpic then
                SetS(sceneid,i,j,level,newpic)
            end
        end
    end
end


function instruct_39(sceneid)             --打开场景
    JY.Scene[sceneid]["进入条件"]=0;
end


function instruct_40(v)                --改变主角方向
    JY.Base["人方向"]=v;
    JY.MyPic=GetMyPic();
end


function instruct_41(personid,thingid,num)        --其他人员增加物品
    local k=0;
    for i =1, 4 do        --已有物品
        if JY.Person[personid]["携带物品" .. i]==thingid then
            JY.Person[personid]["携带物品数量" .. i]=JY.Person[personid]["携带物品数量" .. i]+num;
            k=i;
            break
        end
    end

    --物品减少到0，则后面物品往前移动
    if k>0 and JY.Person[personid]["携带物品数量" .. k] <=0 then
        for i=k+1,4 do
            JY.Person[personid]["携带物品" .. i-1]=JY.Person[personid]["携带物品" .. i];
            JY.Person[personid]["携带物品数量" .. i-1]=JY.Person[personid]["携带物品数量" .. i];
        end
        JY.Person[personid]["携带物品" .. 4]=-1;
        JY.Person[personid]["携带物品数量" .. 4]=0;
    end


    if k==0 then    --没有物品，注意此处不考虑超过4个物品的情况，如果超过，则无法加入。
        for i =1, 4 do        --已有物品
            if JY.Person[personid]["携带物品" .. i]==-1 then
                JY.Person[personid]["携带物品" .. i]=thingid;
                JY.Person[personid]["携带物品数量" .. i]=num;
                break
            end
        end
    end
end


function instruct_42()          --队伍中是否有女性
    local r=false;
    for i =1,CC.TeamNum do
        if JY.Base["队伍" .. i] >=0 then
            if JY.Person[JY.Base["队伍" .. i]]["性别"]==1 then
                r=true;
            end
        end
    end
    return r;
end


function instruct_43(thingid)        --是否有某种物品
    return instruct_18(thingid);
end


function instruct_44(id1,startpic1,endpic1,id2,startpic2,endpic2)     --同时显示两个动画
    local old1=GetD(JY.SubScene,id1,5);
    local old2=GetD(JY.SubScene,id1,6);
    local old3=GetD(JY.SubScene,id1,7);
    local old4=GetD(JY.SubScene,id2,5);
    local old5=GetD(JY.SubScene,id2,6);
    local old6=GetD(JY.SubScene,id2,7);

    --Cls();
    --ShowScreen();
    for i =startpic1,endpic1,2 do
        local t1=EngineAPI.time.getTime();
        if id1==-1 then
            JY.MyPic=i/2;
        else
            SetD(JY.SubScene,id1,5,i);
            SetD(JY.SubScene,id1,6,i);
            SetD(JY.SubScene,id1,7,i);
        end
        if id2==-1 then
            JY.MyPic=i/2;
        else
            SetD(JY.SubScene,id2,5,i-startpic1+startpic2);
            SetD(JY.SubScene,id2,6,i-startpic1+startpic2);
            SetD(JY.SubScene,id2,7,i-startpic1+startpic2);
        end
        DtoSMap();
        DrawSMap();
        ShowScreen();
        local t2=EngineAPI.time.getTime();
        if t2-t1<CC.AnimationFrame then
            WaitFrame(CC.AnimationFrame-(t2-t1));
        end
    end
    SetD(JY.SubScene,id1,5,old1);
    SetD(JY.SubScene,id1,6,old2);
    SetD(JY.SubScene,id1,7,old3);
    SetD(JY.SubScene,id2,5,old4);
    SetD(JY.SubScene,id2,6,old5);
    SetD(JY.SubScene,id2,7,old6);

end


function instruct_45(id,value)        --增加轻功
    local add,str=AddPersonAttrib(id,"轻功",value);
    DrawStrBoxWaitKey(JY.Person[id]["姓名"] .. str,C_ORANGE,CC.DefaultFont);
end


function instruct_46(id,value)            --增加内力
    local add,str=AddPersonAttrib(id,"内力最大值",value);
    AddPersonAttrib(id,"内力",0);
    DrawStrBoxWaitKey(JY.Person[id]["姓名"] .. str,C_ORANGE,CC.DefaultFont);
end


function instruct_47(id,value)
    local add,str=AddPersonAttrib(id,"攻击力",value);           --增加攻击力
    DrawStrBoxWaitKey(JY.Person[id]["姓名"] .. str,C_ORANGE,CC.DefaultFont);
end


function instruct_48(id,value)         --增加生命
    local add,str=AddPersonAttrib(id,"生命最大值",value);
    AddPersonAttrib(id,"生命",0);
    if instruct_16(id)==true then             --我方队员，显示增加
        DrawStrBoxWaitKey(JY.Person[id]["姓名"] .. str,C_ORANGE,CC.DefaultFont);
    end
end


function instruct_49(personid,value)       --设置内力属性
    JY.Person[personid]["内力性质"]=value;
end

--判断是否有5种物品
function instruct_50(id1,id2,id3,id4,id5)       --判断是否有5种物品
    local num=0;
    if instruct_18(id1)==true then
        num=num+1;
    end
    if instruct_18(id2)==true then
        num=num+1;
    end
    if instruct_18(id3)==true then
        num=num+1;
    end
    if instruct_18(id4)==true then
        num=num+1;
    end
    if instruct_18(id5)==true then
        num=num+1;
    end
    if num==5 then
        return true;
    else
        return false;
    end
end


function instruct_51()     --问软体娃娃
    instruct_1(2547+Rnd(18),114,0);
end


function instruct_52()       --看品德
    DrawStrBoxWaitKey(string.format("你现在的品德指数为: %d",JY.Person[0]["品德"]),C_ORANGE,CC.DefaultFont);
end


function instruct_53()        --看声望
    DrawStrBoxWaitKey(string.format("你现在的声望指数为: %d",JY.Person[0]["声望"]),C_ORANGE,CC.DefaultFont);
end


function instruct_54()        --开放其他场景
    for i = 0, JY.SceneNum-1 do
        JY.Scene[i]["进入条件"]=0;
    end
    JY.Scene[2]["进入条件"]=2;    --云鹤崖
    JY.Scene[38]["进入条件"]=2;   --摩天崖
    JY.Scene[75]["进入条件"]=1;   --桃花岛
    JY.Scene[80]["进入条件"]=1;   --绝情谷底
end


function instruct_55(id,num)      --判断D*编号的触发事件
    if GetD(JY.SubScene,id,2)==num then
        return true;
    else
        return false;
    end
end


function instruct_56(v)             --增加声望
    JY.Person[0]["声望"]=JY.Person[0]["声望"]+v;
    instruct_2_sub();     --是否可以增加武林帖
end

--高昌迷宫劈门
function instruct_57()       --高昌迷宫劈门
    instruct_27(-1,7664,7674);
    --Cls();
    --ShowScreen();
    for i=0,56,2 do
        local t1=EngineAPI.time.getTime();
        if JY.MyPic< 7688/2 then
            JY.MyPic=(7676+i)/2;
        end
        SetD(JY.SubScene,2,5,i+7690);
        SetD(JY.SubScene,2,6,i+7690);
        SetD(JY.SubScene,2,7,i+7690);
        SetD(JY.SubScene,3,5,i+7748);
        SetD(JY.SubScene,3,6,i+7748);
        SetD(JY.SubScene,3,7,i+7748);
        SetD(JY.SubScene,4,5,i+7806);
        SetD(JY.SubScene,4,6,i+7806);
        SetD(JY.SubScene,4,7,i+7806);

        DtoSMap();
        DrawSMap();
        ShowScreen();
        local t2=EngineAPI.time.getTime();
        if t2-t1<CC.AnimationFrame then
            WaitFrame(CC.AnimationFrame-(t2-t1));
        end
    end
end

--武道大会比武
function instruct_58()           --武道大会比武
    local group=5           --比武的组数
    local num1 = 6          --每组有几个战斗
    local num2 = 3          --选择的战斗数
    local startwar=102      --起始战斗编号
    local flag={};

    for i = 0,group-1 do
        for j=0,num1-1 do
            flag[j]=0;
        end

        for j = 1,num2 do
            local r;
            while true do          --选择一场战斗
                r=Rnd(num1);
                if flag[r]==0 then
                    flag[r]=1;
                    break;
                end
            end
            local warnum =r+i*num1;      --武道大会战斗编号
            -- **检查返回值**：越界时 WarLoad 只 JY_Error + return false，
            -- 继续用 WAR.Data 会读到上一场的数据（甚至越界索引 JY.Person）。
            if not WarLoad(warnum + startwar) then
                JY_Error("instruct_58: WarLoad failed for warid=%d, aborting tournament",
                         warnum + startwar);
                return;
            end
            instruct_1(2854+warnum, JY.Person[WAR.Data["敌人1"]]["头像代号"], 0);
            instruct_0();
            if WarMain(warnum + startwar, 0) ==true  then     --赢
                instruct_0();
                instruct_13();
                TalkEx("还有那位前辈肯赐教？", 0, 1)
                instruct_0();
            else
                instruct_15();
                return;
            end
        end

        if i < group - 1 then
            TalkEx("少侠已连战三场，*可先休息再战．", 70, 0);
            instruct_0();
            instruct_14();
            WaitFrame(300);
            if JY.Person[0]["受伤程度"] < 50 and JY.Person[0]["中毒程度"] <= 0 then
               JY.Person[0]["受伤程度"] = 0
               AddPersonAttrib(0,"体力",math.huge);
               AddPersonAttrib(0,"内力",math.huge);
               AddPersonAttrib(0,"生命",math.huge);
            end
            instruct_13();
            TalkEx("我已经休息够了，*有谁要再上？",0,1);
            instruct_0();
        end
    end

    TalkEx("接下来换谁？**．．．．*．．．．***没有人了吗？",0,1);
    instruct_0();
    TalkEx("如果还没有人要出来向这位*少侠挑战，那麽这武功天下*第一之名，武林盟主之位，*就由这位少侠夺得．***．．．．．．*．．．．．．*．．．．．．*好，恭喜少侠，这武林盟主*之位就由少侠获得，而这把*”武林神杖”也由你保管．",70,0);
    instruct_0();
    TalkEx("恭喜少侠！",12,0);
    instruct_0();
    TalkEx("小兄弟，恭喜你！",64,4);
    instruct_0();
    TalkEx("好，今年的武林大会到此已*圆满结束，希望明年各位武*林同道能再到我华山一游．",19,0);
    instruct_0();
    instruct_14();
    for i = 24,72 do
        instruct_3(-2, i, 0, 0, -1, -1, -1, -1, -1, -1, -2, -2, -2)
    end
    instruct_0();
    instruct_13();
    TalkEx("历经千辛万苦，我终於打败*群雄，得到这武林盟主之位*及神杖．*但是”圣堂”在那呢？*为什麽没人告诉我，难道大*家都不知道．*这会儿又有的找了．", 0, 1)
    instruct_0();
    instruct_2(143, 1)           --得到神杖

end

--全体队员离队
function instruct_59()           --全体队员离队
    for i=CC.TeamNum,2,-1 do
        if JY.Base["队伍" .. i]>=0 then
            instruct_21(JY.Base["队伍" .. i]);
        end
    end

    for i,v in ipairs(CC.AllPersonExit) do
        instruct_3(v[1],v[2],0,0,-1,-1,-1,-1,-1,-1,0,-2,-2);
    end
end

--判断D*图片
function instruct_60(sceneid,id,num)          --判断D*图片
    if sceneid==-2 then
         sceneid=JY.SubScene;
    end

    if id==-2 then
         id=JY.CurrentD;
    end

    if GetD(sceneid,id,5)==num then
        return true;
    else
        return false;
    end
end

--判断是否放完14天书
function instruct_61()               --判断是否放完14天书
    for i=11,24 do
        if GetD(JY.SubScene,i,5) ~= 4664 then
            return false;
        end
    end
    return true;
end

--播放时空机动画，结束
function instruct_62(id1,startnum1,endnum1,id2,startnum2,endnum2)      --播放时空机动画，结束
      JY.MyPic=-1;
      instruct_44(id1,startnum1,endnum1,id2,startnum2,endnum2);

      --此处应该插入正规的片尾动画。这里暂时用图片代替

      EngineAPI.sprite.drawPictureFile(CONFIG.PicturePath .."end.png",-1,-1);
      ShowScreen();
      PlayMIDI(24);
      WaitFrame(5000);
      EngineAPI.input.getKey();
      WaitKey();
      JY.Status=GAME_END;
end

--设置性别
function instruct_63(personid,sex)          --设置性别
    JY.Person[personid]["性别"]=sex
end

--小宝卖东西
function instruct_64()                 --小宝卖东西
    local headid=111;           --小宝头像

    EngineAPI.debug.log(string.format("instruct_64: JY.SubScene=%d, JY.ShopNum=%d", JY.SubScene, JY.ShopNum));
    EngineAPI.debug.log(string.format("instruct_64: CurrentD=%d, CurrentEventType=%d", JY.CurrentD, JY.CurrentEventType));

    local id=-1;
    for i=0,JY.ShopNum-1 do                --找到当前商店id
        EngineAPI.debug.log(string.format("  ShopScene[%d].sceneid=%d", i, CC.ShopScene[i].sceneid));
        if CC.ShopScene[i].sceneid==JY.SubScene then
            id=i;
            break;
        end
    end
    if id<0 then
        EngineAPI.debug.log("instruct_64: Shop scene not found, using default shop 0");
        id=0;  -- 默认使用第一个商店
    end

    EngineAPI.debug.log("instruct_64: About to call TalkEx");
    TalkEx("这位小哥，看看有什麽需要*的，小宝我卖的东西价钱绝*对公道．",headid,0);
    EngineAPI.debug.log("instruct_64: TalkEx returned");

    local menu={};
    -- 名称与价格必须按**显示宽度**对齐，不能按字节数。
    -- 旧写法 string.format("%-12s %5d", name, price) 里的 12 是字节数，
    -- 汉字 UTF-8 占 3 字节，于是「补到 12 字节」= 补到 4 个汉字：
    -- 3/4/5 字的名字各占一档，价格列呈三级台阶。
    -- 实测真实存档 5 家商店 × 5 项，价格列起点在 108/120/132 间跳动，
    -- 抖动 24px = 恰好 1 个汉字宽。
    -- 改为先收集各列原文，再用 formatColumns 按列内最大显示宽度补齐。
    local rows={};
    for i=1,5 do
        local thingid=JY.Shop[id]["物品" ..i];
        rows[i]={JY.Thing[thingid]["名称"], tostring(JY.Shop[id]["物品价格" ..i])};
    end
    local lines=TextBoxLayout.formatColumns(rows, CC.DefaultFont);
    for i=1,5 do
        menu[i]={};
        menu[i][1]=lines[i];
        menu[i][2]=nil;
        if JY.Shop[id]["物品数量" ..i] >0 then
            menu[i][3]=1;
        else
            menu[i][3]=0;
        end
    end

    local x1=(CC.ScreenW-9*CC.DefaultFont-2*CC.MenuBorderPixel)/2;
    local y1=(CC.ScreenH-5*CC.DefaultFont-4*CC.RowPixel-2*CC.MenuBorderPixel)/2;



    local r=ShowMenu(menu,5,0,x1,y1,0,0,1,1,CC.DefaultFont,C_ORANGE, C_WHITE);

    if r>0 then
        if instruct_31(JY.Shop[id]["物品价格" ..r])==false then
            TalkEx("非常抱歉，*你身上的钱似乎不够．",headid,0);
        else
            JY.Shop[id]["物品数量" ..r]=JY.Shop[id]["物品数量" ..r]-1;
            instruct_32(CC.MoneyID,-JY.Shop[id]["物品价格" ..r]);
            instruct_32(JY.Shop[id]["物品" ..r],1);
            TalkEx("大爷买了我小宝的东西，*保证绝不後悔．",headid,0);
        end
    end

    for i,v in ipairs(CC.ShopScene[id].d_leave) do
        instruct_3(-2,v,0,-2,-1,-1,939,-1,-1,-1,-2,-2,-2);      --设置离开场景时触发小宝离开事件，
    end
end

--小宝去其他客栈
function instruct_65()           --小宝去其他客栈
    local id=-1;
    for i=0,JY.ShopNum-1 do                --找到当前商店id
        if CC.ShopScene[i].sceneid==JY.SubScene then
            id=i;
            break;
        end
    end
    if id<0 then
        return ;
    end

    ---清除当前商店所有小宝D×
    instruct_3(-2,CC.ShopScene[id].d_shop,0,-2,-1,-1,-1,-1,-1,-1,-2,-2,-2);
    for i,v in ipairs(CC.ShopScene[id].d_leave) do
        instruct_3(-2,v,0,-2,-1,-1,-1,-1,-1,-1,-2,-2,-2);
    end

    local newid=id+1;              --暂时用顺序取代随机，
    if newid>=5 then
        newid=0;
    end

    --设置新的小宝商店位置
    instruct_3(CC.ShopScene[newid].sceneid,CC.ShopScene[newid].d_shop,1,-2,938,-1,-1,8256,8256,8256,-2,-2,-2);
end

--播放音乐
function instruct_66(id)       --播放音乐
    PlayMIDI(id);
end

--播放音效
function instruct_67(id)      --播放音效
     PlayWavAtk(id);
end





---------------------------------------------------------------------------
---------------------------------战斗-----------------------------------
--入口函数为WarMain，由战斗指令调用

--设置战斗全程变量
-- 战斗人物槽位容量（port-battle-robustness Task 3）
--
-- 原版是硬编码 26（`for i=0,26-1`），刚好等于：
--   我方最多 6（CC.TeamNum）+ 敌方最多 20（WarSelectEnemy 的 for i=1,20）
-- ⇒ **零余量**。MOD 把 CC.TeamNum 改成 >6、或敌方 >20 就会越界写
-- WAR.Person[26]（nil）→ 下一行索引崩。
--
-- 40 = 6 + 20 + 14 余量，够 MOD 把队伍提到 10、敌方提到 25 这类合理改动。
WAR_PERSON_CAPACITY = 40;

function WarSetGlobal()            --设置战斗全程变量
    WAR={};

    WAR.Data={};              --战斗信息，war.sta文件

    WAR.SelectPerson={}            --设置选择参战人  0 未选，1 选，不可取消，2 选，可取消。选择参展人菜单调用使用

    WAR.Person={};                 --战斗人物信息
    for i=0,(WAR_PERSON_CAPACITY or 26)-1 do
        WAR.Person[i]={};
        WAR.Person[i]["人物编号"]=-1;
        WAR.Person[i]["我方"]=true;            --true 我方，false敌人
        WAR.Person[i]["坐标X"]=-1;
        WAR.Person[i]["坐标Y"]=-1;
        WAR.Person[i]["死亡"]=true;
        WAR.Person[i]["人方向"]=-1;
        WAR.Person[i]["贴图"]=-1;
        WAR.Person[i]["贴图类型"]=0;        --0 wmap中贴图，1 fight***中贴图
        WAR.Person[i]["轻功"]=0;
        WAR.Person[i]["移动步数"]=0;
        WAR.Person[i]["点数"]=0;
        WAR.Person[i]["经验"]=0;
        WAR.Person[i]["自动选择对手"]=-1;     --自动战斗中每个人选择的战斗对手
   end

    WAR.PersonNum=0;               --战斗人物个数

    WAR.AutoFight=0;               --我方自动战斗参数 0 手动，1 自动。

    WAR.CurID=-1;                  --当前操作战斗人id

    WAR.ShowHead=0;                --是否显示头像

    WAR.Effect=0;              --效果，用来确认人物头上数字的颜色
                               --2 杀生命 , 3 杀内力, 4 医疗 ， 5 用毒 ， 6 解毒

    WAR.EffectColor={};      ---定义人物头上数字的颜色
    WAR.EffectColor[2]=RGB(236, 200, 40);
    WAR.EffectColor[3]=RGB(112, 12, 112);
    WAR.EffectColor[4]=RGB(236, 200, 40);
    WAR.EffectColor[5]=RGB(96, 176, 64)
    WAR.EffectColor[6]=RGB(104, 192, 232);

    WAR.EffectXY=nil            --保存武功效果产生的坐标
    WAR.EffectXYNum=0;          --坐标个数

end

--加载战斗数据
function WarLoad(warid)              --加载战斗数据
    WarSetGlobal();         --初始化战斗变量

    -- 边界校验（MOD 的 war.sta 大小不同）：warid 越界时报错并**返回 false**
    --
    -- 为什么必须返回布尔（而不是裸 `return`）：
    --   `JY_Error` 实测只是 `Log()`（framework/lib_log.lua:54），**不抛错、不终止**。
    --   而调用方 `WarMainCoroutine` 原先不检查返回值 → 越界时会用
    --   **上一场战斗的 WAR.Data** 继续跑（地图/敌人/音乐全是错的），
    --   且 `warState.result` 保持上个值 → 调用方读到**错误的胜负**。
    do
        local ok, ModData = pcall(require, "framework.mod_data")
        if ok and ModData and ModData.WarRecordCount then
            local n = ModData.WarRecordCount(CC.WarFile, CC.WarDataSize)
            if n and (warid < 0 or warid >= n) then
                JY_Error("WarLoad: warid=%d out of range (war.sta has %d records)", warid, n)
                return false
            end
        end
    end
    local data=Byte.create(CC.WarDataSize);      --读取战斗数据
    local okRead, errRead = pcall(Byte.loadfile, data, CC.WarFile,
                                  warid*CC.WarDataSize, CC.WarDataSize);
    if not okRead then
        JY_Error("WarLoad: Byte.loadfile failed for warid=%d: %s", warid, tostring(errRead))
        return false
    end
    LoadData(WAR.Data,CC.WarData_S,data);
    return true
end

--战斗主函数
--warid  战斗编号
--isexp  输后是否有经验 0 没经验，1 有经验
--返回  true 战斗胜利，false 失败
function WarMain(warid,isexp)           --战斗主函数
    EngineAPI.debug.log(string.format("war start. warid=%d",warid));
    -- 检查返回值（与 WarMainCoroutine 一致；这是阻塞版，仅在非协程上下文兜底用）
    if not WarLoad(warid) then
        EngineAPI.debug.log("WarMain: WarLoad failed, aborting");
        return false;
    end
    WarSelectTeam();          --选择我方
    WarSelectEnemy();         --选择敌人

    CleanMemory()
     EngineAPI.render.present() ;      --场景变暗

    WarLoadMap(WAR.Data["地图"]);       --加载战斗地图

    JY.Status=GAME_WMAP;

    --加载贴图文件
    LoadArchiveBoth(CC.WMAPPicFile[1],CC.WMAPPicFile[2],0,{paletteFile=CC.PaletteFile});
    LoadArchiveBoth(CC.HeadPicFile[1],CC.HeadPicFile[2],1,{paletteFile=CC.PaletteFile,usage="avatar"});
    if CC.LoadThingPic==1 then
        LoadArchiveBoth(CC.ThingPicFile[1],CC.ThingPicFile[2],2,{paletteFile=CC.PaletteFile});
    end
    LoadArchiveBoth(CC.EffectFile[1],CC.EffectFile[2],3,{paletteFile=CC.PaletteFile});

    PlayMIDI(WAR.Data["音乐"]);

    local first=0;            --第一次显示战斗标记
    local warStatus;          --战斗状态

    WarPersonSort();    --战斗人按轻功排序

    for i=0,WAR.PersonNum-1 do
        local pid=WAR.Person[i]["人物编号"];
        LoadArchiveBoth(string.format(CC.FightPicFile[1],JY.Person[pid]["头像代号"]),
                        string.format(CC.FightPicFile[2],JY.Person[pid]["头像代号"]),
                        4+i,{paletteFile=CC.PaletteFile});
    end

    while true do             --战斗主循环

        for i=0,WAR.PersonNum-1 do
            WAR.Person[i]["贴图"]=WarCalPersonPic(i);
        end
        for i=0,WAR.PersonNum-1 do                ---计算各人的轻功，包括装备加成
            local id=WAR.Person[i]["人物编号"];
            local move=math.modf(WAR.Person[i]["轻功"]/15)-math.modf(JY.Person[id]["受伤程度"]/40);
            if move<0 then
                move=0;
            end
            WAR.Person[i]["移动步数"]=move;
        end

        WarSetPerson();     --设置战斗人物位置

        local p=0;
        while p<WAR.PersonNum do       --每回合战斗循环，每个人轮流战斗
            collectgarbage("step",0);
            WAR.Effect=0;
            if WAR.AutoFight==1 then                 --我方自动战斗时读取键盘，看是否取消
                local keypress=EngineAPI.input.getKey();
                if keypress==VK_SPACE or keypress==VK_RETURN then
                    WAR.AutoFight=0;
                end
            end


            if WAR.Person[p]["死亡"]==false then

                WAR.CurID=p;

                if first==0 then              --第一次渐亮显示
                    WarDrawMap(0);
                    EngineAPI.render.present()
                    first=1;
                else
--                    WarDrawMap(0);
                    --WarShowHead();
--                    ShowScreen();
                end

                local r;
                if WAR.Person[p]["我方"]==true then
                    if WAR.AutoFight==0 then
                        r=War_Manual();                  --手动战斗
                    else
                        r=War_Auto();                  --自动战斗
                    end
                else
                    r=War_Auto();                  --自动战斗
                end

                warStatus=War_isEnd();        --战斗是否结束？   0继续，1赢，2输

                if math.abs(r)==7 then         --等待
                    p=p-1;
                end

                if warStatus>0 then
                    break;
                end

            end
            p=p+1;
        end

        if warStatus>0 then
            break;
        end

        War_PersonLostLife();

    end

    local r;

    WAR.ShowHead=0;

    if warStatus==1 then
        DrawStrBoxWaitKey("战斗胜利",C_WHITE,CC.DefaultFont);
        r=true;
    elseif warStatus==2 then
        DrawStrBoxWaitKey("战斗失败",C_WHITE,CC.DefaultFont);
        r=false;
    end

    War_EndPersonData(isexp,warStatus);    --战斗后设置人物参数

    --本场战斗经验清零，避免下场所持 WAR.Person["经验"] 残留（原版 WAR 数据每场重建，
    --事件驱动架构下 WAR 表跨场复用，不清零会叠加）
    for i=0,WAR.PersonNum-1 do
        WAR.Person[i]["经验"]=0;
    end

    EngineAPI.render.present();

    if JY.Scene[JY.SubScene]["进门音乐"]>=0 then
        PlayMIDI(JY.Scene[JY.SubScene]["进门音乐"]);
    else
        PlayMIDI(0);
    end

    CleanMemory();
    LoadArchiveBoth(CC.SMAPPicFile[1],CC.SMAPPicFile[2],0,{paletteFile=CC.PaletteFile});
    LoadArchiveBoth(CC.HeadPicFile[1],CC.HeadPicFile[2],1,{paletteFile=CC.PaletteFile,usage="avatar"});
    if CC.LoadThingPic==1 then
        LoadArchiveBoth(CC.ThingPicFile[1],CC.ThingPicFile[2],2,{paletteFile=CC.PaletteFile});
    end

    JY.Status=GAME_SMAP;

    return r;
end


-- 战斗模块（battle-extensibility 阶段 1：从本文件搬出的 66 个函数）
--
-- **必须在本文件之后、任何战斗调用之前加载**：
--   main.lua 先 require 本文件（jymain.lua），再由 JYMainAdapter.init()
--   触发 EventBridge → game_states → war_async。
--
-- 为什么用 dofile 而不是 require：
--   这些文件里是**全局函数定义**（`function War_X()`），不是模块返回值。
--   dofile 在当前环境执行 chunk，`function X()` 直接写 _G。
--   用 require 的话返回值是 nil，但全局函数照样会定义 —— 两者等价，
--   但 dofile 语义更清楚（"执行这个脚本"），且不会被 package.loaded 缓存
--   导致重复加载时跳过。
--
-- 顺序：data/render/action/ai/flow 的依赖是单向的
--   （flow 调 action/ai/render，action 调 data/render）
-- 所以按 data → render → action → ai → flow 加载最稳。
do
    local BattleLoader = require("framework.script_loader")
    for _, name in ipairs({ "battle_data", "battle_render", "battle_action", "battle_ai", "battle_flow" }) do
        local path = CONFIG.ScriptPath .. "battle/" .. name .. ".lua"
        local chunk, err = BattleLoader.load(path)
        if chunk then
            local ok, e = pcall(chunk)
            if ok then
                -- 成功也记一条：这样 LÖVE 冒烟日志能证明"battle 模块真的加载了"，
                -- 而不是只在失败时才留痕（失败留痕会让"没输出"两种含义混淆）。
                if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
                    EngineAPI.debug.log("battle module loaded: " .. name)
                end
            end
            if not ok then
                if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
                    EngineAPI.debug.log("battle module load failed: " .. name .. " : " .. tostring(e))
                end
            end
        else
            if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
                EngineAPI.debug.log("battle module not found: " .. tostring(path) .. " : " .. tostring(err))
            end
        end
    end

    -- 战斗规则策略：这是**模块**（返回 table），不是全局函数集
    --
    -- MOD 可以覆盖 mods/<mod>/script/battle/battle_rules.lua 实现新玩法。
    -- 阶段 1 只读 kind（= "turnbased"），不改变任何行为。
    local rulesPath = CONFIG.ScriptPath .. "battle/battle_rules.lua"
    local rulesChunk = BattleLoader.load(rulesPath)
    if rulesChunk then
        local okR, rules = pcall(rulesChunk)
        if okR and type(rules) == "table" then
            BattleRules = rules
        end
    end
end
