-- battle_render.lua
-- 战斗绘制（从 script/jymain.lua 搬入，**逻辑未改**）
--
-- battle-extensibility 阶段 1：纯搬移。

-- port-sprite-native-migration：头像贴图改走 SpriteAtlas（不再用 lib.Pic*）
local SpriteAtlas = require("framework.sprite_atlas")

function WarDrawMap(flag,v1,v2,v3)
    local x=WAR.Person[WAR.CurID]["坐标X"];
    local y=WAR.Person[WAR.CurID]["坐标Y"];

    lib.Debug(string.format("WarDrawMap: flag=%d, maptype=%s", flag, tostring(WAR.Data and WAR.Data["地图"])))

    if flag==0 then
        EngineAPI.map.drawBattle(0,x,y,0,0,-1);
    elseif flag==1 then
        if WAR.Data["地图"]==0 then     --雪地地图用黑色菱形
            EngineAPI.map.drawBattle(1,x,y,v1,v2,-1);
        else
            EngineAPI.map.drawBattle(2,x,y,v1,v2,-1);
        end
    elseif flag==2 then
        EngineAPI.map.drawBattle(3,x,y,0,0,-1);
    elseif flag==4 then
        EngineAPI.map.drawBattle(4,x,y,v1,v2,v3);
    end
    if WAR.ShowHead==1 then
        WarShowHead();
    end
end

function WarCalPersonPic(id)       --计算战斗人物贴图
    local n=5106;            --战斗人物贴图起始位置
    n=n+JY.Person[WAR.Person[id]["人物编号"]]["头像代号"]*8+WAR.Person[id]["人方向"]*2;
    return n;
end

-------------------------------------------------------------------------------------------
---------------------------------以下为手动战斗函数-------------------------------------------
-------------------------------------------------------------------------------------------

--手动战斗
--id 战斗人物编号
--返回，选中菜单编号，选中"等待"时有效，

function WarShowHead()               --显示战斗人头像
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local p=JY.Person[pid];

    local fontsize = CC.DefaultFont
    local h=fontsize+2;
    local width=fontsize*7+2*CC.MenuBorderPixel;  -- 足够显示 "生命 9999/9999"
    local height=100+2*CC.MenuBorderPixel+4*h;
    local x1,y1;
    local i=1;
    if WAR.Person[WAR.CurID]["我方"]==true then
        x1=CC.ScreenW-width-10;
        y1=CC.ScreenH-height-10;
    else
        x1=10;
        y1=10;
    end

    DrawBox(x1,y1,x1+width,y1+height,C_WHITE);

    -- 头像贴图（迁移：lib.PicGetXY/PicLoadCache → SpriteAtlas.getMeta/draw）
    --
    -- 档案编号 1 = 头像档案（CC.HeadPicFile），frameId = 头像代号*2
    -- （该资产约定：显示用 picid 是偶数，内部 slot = picid/2，见 sprite_atlas）。
    --
    -- `getMeta` 返回 table（不是多返回值）；PNG 帧（hdgrp 的 slot 59/111）
    -- 现在也能拿到真实尺寸（见 port-sprite-native-migration Task 1）。
    --
    -- `draw` 的 flag=0x1 语义与旧 `PicLoadCache(..., 1)` 完全相同：
    -- 「忽略锚点偏移」，因为这里的居中由调用方自己算。
    local headMeta = SpriteAtlas.getMeta(1, p["头像代号"]*2)
    local headw = headMeta and headMeta.w or 0
    local headh = headMeta and headMeta.h or 0
    local headx=(100-headw)/2;
    local heady=(100-headh)/2;

    SpriteAtlas.draw(1, p["头像代号"]*2, x1+5+headx, y1+5+heady, 0x1);
    x1=x1+5
    y1=y1+5+100;

    DrawString(x1,y1,p["姓名"],C_WHITE,fontsize);

    local color;              --显示生命和最大值，根据受伤和中毒显示不同颜色
    if p["受伤程度"]<33 then
        color =RGB(236,200,40);
    elseif p["受伤程度"]<66 then
        color=RGB(244,128,32);
    else
        color=RGB(232,32,44);
    end
    DrawString(x1,y1+h,"生命",C_ORANGE,fontsize);
    DrawString(x1+fontsize*2.5,y1+h,string.format("%4d",p["生命"]),color,fontsize);
    DrawString(x1+fontsize*4.5,y1+h,"/",C_GOLD,fontsize);
    if p["中毒程度"]==0 then
        color =RGB(252,148,16);
    elseif p["中毒程度"]<50 then
        color=RGB(120,208,88);
    else
        color=RGB(56,136,36);
    end
    DrawString(x1+fontsize*5,y1+h,string.format("%4d",p["生命最大值"]),color,fontsize);

                  --显示内力和最大值，根据内力性质显示不同颜色
    if p["内力性质"]==0 then
        color=RGB(208,152,208);
    elseif p["内力性质"]==1 then
        color=RGB(236,200,40);
    else
        color=RGB(236,236,236);
    end
    DrawString(x1,y1+h*2,"内力",C_ORANGE,fontsize);
    DrawString(x1+fontsize*2.5,y1+h*2,string.format("%4d/%4d",p["内力"],p["内力最大值"]),color,fontsize);

    DrawString(x1,y1+h*3,"体力",C_ORANGE,fontsize);
    DrawString(x1+fontsize*2.5,y1+h*3,string.format("%4d",p["体力"]),C_GOLD,fontsize);
end


--返回1：已经移动    0 没有移动
