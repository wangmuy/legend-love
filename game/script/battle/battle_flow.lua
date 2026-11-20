-- battle_flow.lua
-- 战斗流程（手动/自动战斗编排、结算、菜单）
-- 从 script/jymain.lua 搬入，**逻辑未改**
--
-- battle-extensibility 阶段 1：纯搬移。

function War_EndPersonData(isexp,warStatus)            --战斗以后设置人物参数
--敌方人员参数恢复
    for i=0,WAR.PersonNum-1 do
        local pid=WAR.Person[i]["人物编号"]
        if WAR.Person[i]["我方"]==false then
            JY.Person[pid]["生命"]=JY.Person[pid]["生命最大值"];
            JY.Person[pid]["内力"]=JY.Person[pid]["内力最大值"];
            JY.Person[pid]["体力"]=CC.PersonAttribMax["体力"];
            JY.Person[pid]["受伤程度"]=0;
            JY.Person[pid]["中毒程度"]=0;
        end
    end

    --我方人员参数恢复，输赢都有
    for i=0,WAR.PersonNum-1 do
        local pid=WAR.Person[i]["人物编号"]
        if WAR.Person[i]["我方"]==true then
            if JY.Person[pid]["生命"]<JY.Person[pid]["生命最大值"]/5 then
                JY.Person[pid]["生命"]=math.modf(JY.Person[pid]["生命最大值"]/5);
            end
            if JY.Person[pid]["体力"]<10 then
                JY.Person[pid]["体力"]=10 ;
            end
        end
    end

    if warStatus==2 and isexp==0 then  --输，没有经验，退出
        return ;
    end

    local liveNum=0;          --计算我方活着的人数
    for i=0,WAR.PersonNum-1 do
        if WAR.Person[i]["我方"]==true and JY.Person[WAR.Person[i]["人物编号"]]["生命"]>0  then
            liveNum=liveNum+1;
        end
    end

    --分配战斗经验---基本经验，战斗数据中的
    if warStatus==1 then     --赢了才有
        -- **liveNum 为 0 时不能除**（根因：原实现信任 warStatus 外部参数）
        --
        -- `liveNum` = 我方存活人数。warStatus==1 表示胜利，正常流程下
        -- War_isEnd 已保证「敌方全灭 + 我方至少一人活着」，所以 liveNum >= 1。
        -- 但 warStatus 是**外部传入**的参数（War_EndPersonData(isexp, warStatus)
        -- 被 war_async 直接调用，不经过 War_isEnd），MOD 或异常流程可传 (1, 1)
        -- 而此刻我方恰好全灭 → liveNum == 0。
        --
        -- Lua 的 `n/0` 不抛错，而是得 **inf**（实测 5.1: 1.#INF）。
        -- inf 经 `math.modf` 仍是 inf，再经 AddPersonAttrib 的 limitX 钳到
        -- 属性最大值（60000）—— 于是「全灭却白拿 60000 经验」，
        -- 且完全静默（不报错、不日志），是典型的难查数据污染。
        --
        -- 修法：liveNum <= 0 时视为「无人可分」，跳过分配（经验归零）。
        local liveNumForExp = (liveNum > 0) and liveNum or 1
        for i=0,WAR.PersonNum-1 do
            local pid=WAR.Person[i]["人物编号"]
            if WAR.Person[i]["我方"]==true then
                if liveNum > 0 and JY.Person[pid]["生命"]>0 then
                    WAR.Person[i]["经验"]=WAR.Person[i]["经验"] + math.modf(WAR.Data["经验"]/liveNumForExp);
                end
            end
        end
    end


    --每个人经验增加，以及升级
    for i=0,WAR.PersonNum-1 do
        local pid=WAR.Person[i]["人物编号"];
        AddPersonAttrib(pid,"物品修炼点数",math.modf(WAR.Person[i]["经验"]*8/10));
        AddPersonAttrib(pid,"修炼点数",math.modf(WAR.Person[i]["经验"]*8/10));
        AddPersonAttrib(pid,"经验",WAR.Person[i]["经验"]);

        if WAR.Person[i]["我方"]==true then

            DrawStrBoxWaitKey( string.format("%s 获得经验点数 %d",JY.Person[pid]["姓名"],WAR.Person[i]["经验"]),C_WHITE,CC.DefaultFont);

            local r=War_AddPersonLevel(pid);     --人物升级

            if r==true then
                DrawStrBoxWaitKey( string.format("%s 升级了",JY.Person[pid]["姓名"]),C_WHITE,CC.DefaultFont);
            end
        end

        War_PersonTrainBook(pid);            --修炼秘籍
        War_PersonTrainDrug(pid);            --修炼药品
    end
end

--人物是否升级
--pid 人id
--返回 true 升级，false不升级

function War_AddPersonLevel(pid)      --人物是否升级

    local tmplevel=JY.Person[pid]["等级"];
    if tmplevel>=CC.Level then     --级别到顶
        return false;
    end

    if JY.Person[pid]["经验"]<CC.Exp[tmplevel] then     --经验不够升级
        return false
    end

    while true do          --判断可以升几级
        if tmplevel >= CC.Level then
            break;
        end
        if JY.Person[pid]["经验"]>=CC.Exp[tmplevel] then
            tmplevel=tmplevel+1;
        else
            break;
        end
    end
    local leveladd=tmplevel-JY.Person[pid]["等级"];   --升级次数
    JY.Person[pid]["等级"]=JY.Person[pid]["等级"]+leveladd;
    AddPersonAttrib(pid,"生命最大值", (JY.Person[pid]["生命增长"]+Rnd(3))*leveladd*3);
    JY.Person[pid]["生命"]=JY.Person[pid]["生命最大值"];
    JY.Person[pid]["体力"]=CC.PersonAttribMax["体力"];
    JY.Person[pid]["受伤程度"]=0;
    JY.Person[pid]["中毒程度"]=0;

    local cleveradd;
    if JY.Person[pid]["资质"]<30 then
        cleveradd=2;
    elseif JY.Person[pid]["资质"]<50 then
        cleveradd=3;
    elseif JY.Person[pid]["资质"]<70 then
        cleveradd=4;
    elseif JY.Person[pid]["资质"]<90 then
        cleveradd=5;
    else
        cleveradd=6;
    end
    cleveradd=Rnd(cleveradd)+1;        --按照资质计算的增长点，越高则技能增加越多，而内力增加越少。
    AddPersonAttrib(pid,"内力最大值",  (9-cleveradd)*leveladd*4);   --聪明人不练内力
    JY.Person[pid]["内力"]=JY.Person[pid]["内力最大值"];

    AddPersonAttrib(pid,"攻击力",  cleveradd*leveladd);
    AddPersonAttrib(pid,"防御力",  cleveradd*leveladd);
    AddPersonAttrib(pid,"轻功",  cleveradd*leveladd);

    if JY.Person[pid]["医疗能力"]>=20 then
        AddPersonAttrib(pid,"医疗能力",  Rnd(3));
    end
    if JY.Person[pid]["用毒能力"]>=20 then
        AddPersonAttrib(pid,"用毒能力",  Rnd(3));
    end
    if JY.Person[pid]["解毒能力"]>=20 then
        AddPersonAttrib(pid,"解毒能力",  Rnd(3));
    end
    if JY.Person[pid]["拳掌功夫"]>=20 then
        AddPersonAttrib(pid,"拳掌功夫",  Rnd(3));
    end
    if JY.Person[pid]["御剑能力"]>=20 then
        AddPersonAttrib(pid,"御剑能力",  Rnd(3));
    end
    if JY.Person[pid]["耍刀技巧"]>=20 then
        AddPersonAttrib(pid,"耍刀技巧",  Rnd(3));
    end
    if JY.Person[pid]["暗器技巧"]>=20 then
        AddPersonAttrib(pid,"暗器技巧",  Rnd(3));
    end

    return true;

end

--修炼秘籍

function War_PersonTrainBook(pid)           --战斗后修炼秘籍是否成功
    local p=JY.Person[pid];

    local thingid=p["修炼物品"];
    if thingid<0 then
        return ;
    end

    local wugongid=JY.Thing[thingid]["练出武功"];

    local needpoint=TrainNeedExp(pid);      --计算修炼成功需要点数

    if p["修炼点数"]>=needpoint then   --修炼成功

        DrawStrBoxWaitKey( string.format("%s 修炼 %s 成功",p["姓名"],JY.Thing[thingid]["名称"]),C_WHITE,CC.DefaultFont);

        AddPersonAttrib(pid,"生命最大值",JY.Thing[thingid]["加生命最大值"]);
        if JY.Thing[thingid]["改变内力性质"]==2 then
            p["内力性质"]=2;
        end
        AddPersonAttrib(pid,"内力最大值",JY.Thing[thingid]["加内力最大值"]);
        AddPersonAttrib(pid,"攻击力",JY.Thing[thingid]["加攻击力"]);
        AddPersonAttrib(pid,"轻功",JY.Thing[thingid]["加轻功"]);
        AddPersonAttrib(pid,"防御力",JY.Thing[thingid]["加防御力"]);
        AddPersonAttrib(pid,"医疗能力",JY.Thing[thingid]["加医疗能力"]);
        AddPersonAttrib(pid,"用毒能力",JY.Thing[thingid]["加用毒能力"]);
        AddPersonAttrib(pid,"解毒能力",JY.Thing[thingid]["加解毒能力"]);
        AddPersonAttrib(pid,"抗毒能力",JY.Thing[thingid]["加抗毒能力"]);
        AddPersonAttrib(pid,"拳掌功夫",JY.Thing[thingid]["加拳掌功夫"]);
        AddPersonAttrib(pid,"御剑能力",JY.Thing[thingid]["加御剑能力"]);
        AddPersonAttrib(pid,"耍刀技巧",JY.Thing[thingid]["加耍刀技巧"]);
        AddPersonAttrib(pid,"特殊兵器",JY.Thing[thingid]["加特殊兵器"]);
        AddPersonAttrib(pid,"暗器技巧",JY.Thing[thingid]["加暗器技巧"]);
        AddPersonAttrib(pid,"武学常识",JY.Thing[thingid]["加武学常识"]);
        AddPersonAttrib(pid,"品德",JY.Thing[thingid]["加品德"]);
        AddPersonAttrib(pid,"攻击带毒",JY.Thing[thingid]["加攻击带毒"]);
        if JY.Thing[thingid]["加攻击次数"]==1 then
            p["左右互搏"]=1;
        end

        p["修炼点数"]=0;

        if wugongid>=0 then
            local oldwugong=0;
            for i =1,10 do
                if p["武功" .. i]==wugongid then
                    oldwugong=1;
                    p["武功等级" .. i]=p["武功等级" .. i]+100;

                    DrawStrBoxWaitKey(string.format("%s 升为第%s级",JY.Wugong[wugongid]["名称"],math.modf(p["武功等级" ..i]/100)+1),C_WHITE,CC.DefaultFont);

                    break;
                end
            end
            if oldwugong==0 then  --新的武功
                for i=1,10 do
                    if p["武功" .. i]==0 then
                        p["武功" .. i]=wugongid;
                        break;
                    end
                end
                ---这里不考虑10个武功已满的时候如何增加新的武功
            end
        end
    end
end

--练出药品

function War_PersonTrainDrug(pid)         --战斗后是否修炼出物品
    local p=JY.Person[pid];

    local thingid=p["修炼物品"];
    if thingid<0 then
        return ;
    end

    if JY.Thing[thingid]["练出物品需经验"] <=0 then          --不可以修炼出物品
        return ;
    end

    local needpoint=(7-math.modf(p["资质"]/15))*JY.Thing[thingid]["练出物品需经验"];
    if p["物品修炼点数"]< needpoint then
        return ;
    end

    local haveMaterial=0;       --是否有需要的材料
    local MaterialNum=-1;
    for i=1,CC.MyThingNum do
        if JY.Base["物品" .. i]==JY.Thing[thingid]["需材料"] then
            haveMaterial=1;
            MaterialNum=JY.Base["物品数量" .. i]
            break;
        end
    end

    if haveMaterial==1 then   --有材料
        local enough={};
        local canMake=0;
        for i=1,5 do       --根据需要材料的数量，标记可以练出哪些物品
            if JY.Thing[thingid]["练出物品" .. i] >=0 and MaterialNum >= JY.Thing[thingid]["需要物品数量" .. i] then
                canMake=1;
                enough[i]=1;
            else
                enough[i]=0;
            end
        end

        if canMake ==1 then    --可练出物品
            local makeID;
            while true do      --随机选择练出的物品，必须是前面enough数组中标记可以练出的
                makeID=Rnd(5)+1;
                if enough[makeID]==1 then
                    break;
                end
            end
            local newThingID=JY.Thing[thingid]["练出物品" .. makeID];

            DrawStrBoxWaitKey(string.format("%s 制造出 %s",p["姓名"],JY.Thing[newThingID]["名称"]),C_WHITE,CC.DefaultFont);

            if instruct_18(newThingID)==true then       --已经有物品
                instruct_32(newThingID,1);
            else
                instruct_32(newThingID,1+Rnd(3));
            end

            instruct_32(JY.Thing[thingid]["需材料"],-JY.Thing[thingid]["需要物品数量" .. makeID]);
            p["物品修炼点数"]=0;
        end
    end
end

--战斗是否结束
--返回：0 继续   1 赢    2 输

function WarSelectTeam()            --选择我方参战人
    WAR.PersonNum=0;

    for i=1,6 do
        local id=WAR.Data["自动选择参战人" .. i];
        if id>=0 then
            -- **容量守卫**（port-battle-robustness Task 4）：
            -- WAR.Person 的槽数是 WAR_PERSON_CAPACITY（40）。原版 26 时
            -- 我方 6 + 敌方 20 = 刚好 26（零余量）→ MOD 改 CC.TeamNum 或
            -- 敌方数量 > 20 就会写到 WAR.Person[26] = nil → 下一行崩。
            if WAR.PersonNum >= (WAR_PERSON_CAPACITY or 26) then
                JY_Error("WarSelectTeam: person 槽位已满（上限 %d），忽略剩余参战人",
                         WAR_PERSON_CAPACITY or 26)
                break
            end
            WAR.Person[WAR.PersonNum]["人物编号"]=id;
            WAR.Person[WAR.PersonNum]["我方"]=true;
            WAR.Person[WAR.PersonNum]["坐标X"]=WAR.Data["我方X"  .. i];
            WAR.Person[WAR.PersonNum]["坐标Y"]=WAR.Data["我方Y"  .. i];
            WAR.Person[WAR.PersonNum]["死亡"]=false;
            WAR.Person[WAR.PersonNum]["人方向"]=2;
            WAR.PersonNum=WAR.PersonNum+1;
        end
    end
    if WAR.PersonNum>0 then
        return ;
    end

    for i=1,CC.TeamNum do                 --设置事先确定的参战人
        WAR.SelectPerson[i]=0;
        local id=JY.Base["队伍" .. i];
        if id>=0 then
            for j=1,6 do
                if WAR.Data["手动选择参战人" .. j]==id then
                    WAR.SelectPerson[i]=1;
                end
            end
        end
    end

    local menu={};
    for i=1, CC.TeamNum do
        menu[i]={"",WarSelectMenu,0};
        local id=JY.Base["队伍" .. i];
        if id>=0 then
            menu[i][3]=1;
            local s=JY.Person[id]["姓名"];
            if WAR.SelectPerson[i]==1 then
                menu[i][1]="*" .. s;
            else
                menu[i][1]=" " .. s;
            end
        end
    end

    menu[CC.TeamNum+1]={" 结束",nil,1}

    while true do
        Cls();
        local x=(CC.ScreenW-7*CC.DefaultFont-2*CC.MenuBorderPixel)/2;
        DrawStrBox(x,10,"请选择参战人物",C_WHITE,CC.DefaultFont);
        local r=ShowMenu(menu,CC.TeamNum+1,0,x,10+CC.SingleLineHeight,0,0,1,0,CC.DefaultFont,C_ORANGE,C_WHITE);
        Cls();

        for i=1,6 do
            if WAR.SelectPerson[i]>0 then
                -- **容量守卫**（port-battle-robustness Task 4）：
                -- WAR.Person 的槽数是 WAR_PERSON_CAPACITY（40）。原版 26 时
                -- 我方 6 + 敌方 20 = 刚好 26（零余量）→ MOD 改 CC.TeamNum 或
                -- 敌方数量 > 20 就会写到 WAR.Person[26] = nil → 下一行崩。
                if WAR.PersonNum >= (WAR_PERSON_CAPACITY or 26) then
                    JY_Error("WarSelectTeam: person 槽位已满（上限 %d），忽略剩余参战人",
                             WAR_PERSON_CAPACITY or 26)
                    break
                end
                WAR.Person[WAR.PersonNum]["人物编号"]=JY.Base["队伍" ..i];
                WAR.Person[WAR.PersonNum]["我方"]=true;
                WAR.Person[WAR.PersonNum]["坐标X"]=WAR.Data["我方X"  .. i];
                WAR.Person[WAR.PersonNum]["坐标Y"]=WAR.Data["我方Y"  .. i];
                WAR.Person[WAR.PersonNum]["死亡"]=false;
                WAR.Person[WAR.PersonNum]["人方向"]=2;
                WAR.PersonNum=WAR.PersonNum+1;
            end
        end
        if WAR.PersonNum>0 then   --选择了我方参战人
           break;
        end
    end
end


--选中战斗人菜单调用函数

function WarSelectMenu(newmenu,newid)            --选择战斗人菜单调用函数
    local id=newmenu[newid][4];

    if WAR.SelectPerson[id]==0 then
        WAR.SelectPerson[id]=2;
    elseif WAR.SelectPerson[id]==2 then
        WAR.SelectPerson[id]=0;
    end

    if WAR.SelectPerson[id]>0 then
        newmenu[newid][1]="*" .. string.sub(newmenu[newid][1],2);
    else
        newmenu[newid][1]=" " .. string.sub(newmenu[newid][1],2);
    end
    return 0;
end

--选择敌方参战人

function WarSelectEnemy()            --选择敌方参战人
    for i=1,20 do
        if WAR.Data["敌人"  .. i]>0 then
            -- **容量守卫**（port-battle-robustness Task 4）：
            -- WAR.Person 的槽数是 WAR_PERSON_CAPACITY（40）。原版 26 时
            -- 我方 6 + 敌方 20 = 刚好 26（零余量）→ MOD 改 CC.TeamNum 或
            -- 敌方数量 > 20 就会写到 WAR.Person[26] = nil → 下一行崩。
            if WAR.PersonNum >= (WAR_PERSON_CAPACITY or 26) then
                JY_Error("WarSelectEnemy: person 槽位已满（上限 %d），忽略剩余参战人",
                         WAR_PERSON_CAPACITY or 26)
                break
            end
            WAR.Person[WAR.PersonNum]["人物编号"]=WAR.Data["敌人"  .. i];
            WAR.Person[WAR.PersonNum]["我方"]=false;
            WAR.Person[WAR.PersonNum]["坐标X"]=WAR.Data["敌方X"  .. i];
            WAR.Person[WAR.PersonNum]["坐标Y"]=WAR.Data["敌方Y"  .. i];
            WAR.Person[WAR.PersonNum]["死亡"]=false;
            WAR.Person[WAR.PersonNum]["人方向"]=1;
            WAR.PersonNum=WAR.PersonNum+1;
        end
    end
end

--加载战斗地图
--共6层，包括了工作用地图
--        0层 地面数据
--        1层 建筑
--以上为战斗地图数据，从战斗文件中载入。下面为工作用的地图结构
--        2层 战斗人战斗编号，即WAR.Person的编号
--        3层 移动时显示可移动的位置
--        4层 命中效果
--        5层 战斗人对应的贴图

function WarPersonSort()               --战斗人物按轻功排序
    for i=0,WAR.PersonNum-1 do                ---计算各人的轻功，包括装备加成
        local id=WAR.Person[i]["人物编号"];
        local add=0;
        if JY.Person[id]["武器"]>-1 then
            add=add+JY.Thing[JY.Person[id]["武器"]]["加轻功"];
        end
        if JY.Person[id]["防具"]>-1 then
            add=add+JY.Thing[JY.Person[id]["防具"]]["加轻功"];
        end
        WAR.Person[i]["轻功"]=JY.Person[id]["轻功"]+add;
        local move=math.modf(WAR.Person[i]["轻功"]/15)-math.modf(JY.Person[id]["受伤程度"]/40);
        if move<0 then
            move=0;
        end
        WAR.Person[i]["移动步数"]=move;
    end

    --按轻功排序，用比较笨的方法
    for i=0,WAR.PersonNum-2 do
        local maxid=i;
        for j=i,WAR.PersonNum-1 do
            if WAR.Person[j]["轻功"]>WAR.Person[maxid]["轻功"] then
                maxid=j;
            end
        end
        WAR.Person[maxid],WAR.Person[i]=WAR.Person[i],WAR.Person[maxid];
    end
end

--设置战斗人物位置和贴图

function WarSetPerson()            --设置战斗人物位置
     CleanWarMap(2,-1);
     CleanWarMap(5,-1);

    for i=0,WAR.PersonNum-1 do
        if WAR.Person[i]["死亡"]==false then
            SetWarMap(WAR.Person[i]["坐标X"],WAR.Person[i]["坐标Y"],2,i);
            SetWarMap(WAR.Person[i]["坐标X"],WAR.Person[i]["坐标Y"],5,WAR.Person[i]["贴图"]);
        end
    end
end

function War_Manual()        --手动战斗
    local r;
    while true do
        WAR.ShowHead=1;          --显示头像
        r=War_Manual_Sub();  --手动战斗菜单
        if math.abs(r)~=1 then        --移动完毕后，重新生成菜单
            break;
        end
    end
    WAR.ShowHead=0;
    return r;
end

function War_Manual_Sub()                --手动战斗菜单
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local menu={ {"移动",War_MoveMenu,1},
                 {"攻击",War_FightMenu,1},
                 {"用毒",War_PoisonMenu,1},
                 {"解毒",War_DecPoisonMenu,1},
                 {"医疗",War_DoctorMenu,1},
                 {"物品",War_ThingMenu,1},
                 {"等待",War_WaitMenu,1},
                 {"状态",War_StatusMenu,1},
                 {"休息",War_RestMenu,1},
                 {"自动",War_AutoMenu,1},   };

    if JY.Person[pid]["体力"]<=5 or WAR.Person[WAR.CurID]["移动步数"]<=0 then  --不能移动
        menu[1][3]=0;
    end

    local minv=War_GetMinNeiLi(pid);

    if JY.Person[pid]["内力"] < minv or JY.Person[pid]["体力"] <10 then  --不能战斗
        menu[2][3]=0;
    end

    if JY.Person[pid]["体力"]<10 or JY.Person[pid]["用毒能力"]<20 then  --不能用毒
        menu[3][3]=0;
    end

    if JY.Person[pid]["体力"]<10 or JY.Person[pid]["解毒能力"]<20 then  --不能解毒
        menu[4][3]=0;
    end

    if JY.Person[pid]["体力"]<50 or JY.Person[pid]["医疗能力"]<20 then  --不能医疗
        menu[5][3]=0;
    end

    lib.GetKey();
    Cls();
    return ShowMenu(menu,10,0,CC.MainMenuX,CC.MainMenuY,0,0,1,0,CC.DefaultFont,C_ORANGE,C_WHITE);

end

function War_MoveMenu()           --执行移动菜单
    WAR.ShowHead=0;   --不显示头像
    if WAR.Person[WAR.CurID]["移动步数"]<=0 then
        return 0;
    end

    War_CalMoveStep(WAR.CurID,WAR.Person[WAR.CurID]["移动步数"],0);   --计算移动步数

    local r;
    local x,y=War_SelectMove()             --选择移动位置
    if x ~=nil then            --空值表示没有选择，esc返回了，非空则表示选择了位置
        War_MovePerson(x,y);    --移动到相应的位置
        r=1;
    else
        r=0
        WAR.ShowHead=1;
        Cls();
    end
    lib.GetKey();
    return r;
end

--计算可移动步数
--id 战斗人id，
--stepmax 最大步数，
--flag=0  移动，物品不能绕过，1 武功，用毒医疗等，不考虑挡路。

function War_SelectMove()              ---选择移动位置
    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];
    local x=x0;
    local y=y0;

    while true do
        local x2=x;
        local y2=y;

        WarDrawMap(1,x,y);

        ShowScreen();
        local key=WaitKey();
        if key==VK_UP then
            y2=y-1;
        elseif key==VK_DOWN then
            y2=y+1;
        elseif key==VK_LEFT then
            x2=x-1;
        elseif key==VK_RIGHT then
            x2=x+1;
        elseif key==VK_SPACE or key==VK_RETURN then
            return x,y;
        elseif key==VK_ESCAPE then
            return nil;
        end

        if GetWarMap(x2,y2,3)<128 then
            x=x2;
            y=y2;
        end
    end

end

function War_ShowFight(pid,wugong,wugongtype,level,x,y,eft)              --显示战斗动画

    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];

    local fightdelay,fightframe,sounddelay;
    if wugongtype>=0 then
        fightdelay=JY.Person[pid]["出招动画延迟" .. wugongtype+1];
        fightframe=JY.Person[pid]["出招动画帧数" .. wugongtype+1];
        sounddelay=JY.Person[pid]["武功音效延迟" .. wugongtype+1];
    else            ---暗器，这些数据什么意思？？
        fightdelay=0;
        fightframe=-1;
        sounddelay=-1;
    end

    local framenum=fightdelay+CC.Effect[eft];            --总帧数

    local startframe=0;               --计算fignt***中当前出招起始帧
    if wugongtype>=0 then
        for i=0,wugongtype-1 do
            startframe=startframe+4*JY.Person[pid]["出招动画帧数" .. i+1];
        end
    end

    local starteft=0;          --计算起始武功效果帧
    for i=0,eft-1 do
        starteft=starteft+CC.Effect[i];
    end

    WAR.Person[WAR.CurID]["贴图类型"]=0;
    WAR.Person[WAR.CurID]["贴图"]=WarCalPersonPic(WAR.CurID);

    WarSetPerson();

    WarDrawMap(0);
    ShowScreen();

    local fastdraw;
    if CONFIG.FastShowScreen==0 or CC.AutoWarShowHead==1 then    --显示头像则全部重绘
        fastdraw=0;
    else
        fastdraw=1;
    end

    --在显示动画前先加载贴图
    local oldpic=WAR.Person[WAR.CurID]["贴图"]/2;
    local oldpic_type=0;

    local oldeft=-1;

    for i=0,framenum-1 do
        local tstart=lib.GetTime();
        local mytype;
        if fightframe>0 then
            WAR.Person[WAR.CurID]["贴图类型"]=1;
            mytype=4+WAR.CurID;
            if i<fightframe then
                WAR.Person[WAR.CurID]["贴图"]=(startframe+WAR.Person[WAR.CurID]["人方向"]*fightframe+i)*2;
            end
        else       --暗器，不使用fight中图像
            WAR.Person[WAR.CurID]["贴图类型"]=0;
            WAR.Person[WAR.CurID]["贴图"]=WarCalPersonPic(WAR.CurID);
            mytype=0;
        end

        if i==sounddelay then
            PlayWavAtk(JY.Wugong[wugong]["出招音效"]);
        end
        if i==fightdelay then
            PlayWavE(eft);
        end
        local pic=WAR.Person[WAR.CurID]["贴图"]/2;
        if fastdraw==1 then
            local rr=ClipRect(Cal_PicClip(0,0,oldpic,oldpic_type,0,0,pic,mytype));
            if rr ~=nil then
                lib.SetClip(rr.x1,rr.y1,rr.x2,rr.y2);
            end
        else
            lib.SetClip(0,0,0,0);
        end
        oldpic=pic;
        oldpic_type=mytype;

        if i<fightdelay then   --只显示出招
            WarDrawMap(4,pic*2,mytype,-1);
        else        --同时显示武功效果
            starteft=starteft+1;            --此处似乎是eft第一个数据有问题，应该是10，现为9，因此加1

            if fastdraw==1 then
                local clip1={};
                clip1=Cal_PicClip(WAR.EffectXY[1][1]-x0,WAR.EffectXY[1][2]-y0,oldeft,3,
                                        WAR.EffectXY[1][1]-x0,WAR.EffectXY[1][2]-y0,starteft,3);
                local clip2={};
                clip2=Cal_PicClip(WAR.EffectXY[2][1]-x0,WAR.EffectXY[2][2]-y0,oldeft,3,
                                        WAR.EffectXY[2][1]-x0,WAR.EffectXY[2][2]-y0,starteft,3);
                local clip=ClipRect(MergeRect(clip1,clip2));

                if clip ~=nil then
                    local area=(clip.x2-clip.x1)*(clip.y2-clip.y1);          --计算脏矩形面积
                    if area <CC.ScreenW*CC.ScreenH/2 then        --面积足够小，则更新脏矩形。
                        WarDrawMap(4,pic*2,mytype,starteft*2);
                        lib.SetClip(clip.x1,clip.y1,clip.x2,clip.y2);
                        WarDrawMap(4,pic*2,mytype,starteft*2);
                    else    --面积太大，直接重绘
                        lib.SetClip(0,0,CC.ScreenW,CC.ScreenH);
                        WarDrawMap(4,pic*2,mytype,starteft*2);
                    end
                else
                    WarDrawMap(4,pic*2,mytype,starteft*2);
                end
            else
                lib.SetClip(0,0,0,0);
                WarDrawMap(4,pic*2,mytype,starteft*2);
            end
            oldeft=starteft;
        end

        ShowScreen(fastdraw);
        lib.SetClip(0,0,0,0);

        local tend=lib.GetTime();
        if tend-tstart<1*CC.Frame then
            WaitFrame(1*CC.Frame-(tend-tstart));
        end

    end

    lib.SetClip(0,0,0,0);
    WAR.Person[WAR.CurID]["贴图类型"]=0;
    WAR.Person[WAR.CurID]["贴图"]=WarCalPersonPic(WAR.CurID);
    WarSetPerson();
    WarDrawMap(0);

    ShowScreen();
    WaitFrame(200);

    WarDrawMap(2);          --全黑显示命中人物
    ShowScreen();
    WaitFrame(200);

    WarDrawMap(0);
    ShowScreen();

    local HitXY={};               --记录命中点数的坐标
    local HitXYNum=0;
    for i = 0, WAR.PersonNum-1 do
        local x1=WAR.Person[i]["坐标X"];
        local y1=WAR.Person[i]["坐标Y"];
        if WAR.Person[i]["死亡"]==false then
             if GetWarMap(x1,y1,4)>1 then
                local n=WAR.Person[i]["点数"]
                HitXY[HitXYNum]={x1,y1,string.format("%+d",n)};
                HitXYNum=HitXYNum+1;
             end
        end
    end

if HitXYNum>0 then
    local clips={};                --计算命中点数clip
    for i=0,HitXYNum-1 do
        local dx=HitXY[i][1]-x0;
        local dy=HitXY[i][2]-y0;
        local ll=string.len(HitXY[i][3]);
        local w=ll*CC.DefaultFont/2+1;
        clips[i]={x1=CC.XScale*(dx-dy)+CC.ScreenW/2,
                 y1=CC.YScale*(dx+dy)+CC.ScreenH/2,
                 x2=CC.XScale*(dx-dy)+CC.ScreenW/2+w,
                 y2=CC.YScale*(dx+dy)+CC.ScreenH/2+CC.DefaultFont+1 };
    end

    local clip=clips[0];

    for i=1,HitXYNum-1 do
        clip=MergeRect(clip,clips[i]);
    end

    local area=(clip.x2-clip.x1)*(clip.y2-clip.y1)

    for i=1,15 do           --显示命中的点数
        local tstart=lib.GetTime();
        local y_off=i*2+65;
        if fastdraw==1 and area <CC.ScreenW*CC.ScreenH/2 then
            local tmpclip={x1=clip.x1, y1=clip.y1-y_off, x2=clip.x2, y2=clip.y2-y_off};
            tmpclip=ClipRect(tmpclip);
            if tmpclip~=nil then
                lib.SetClip(tmpclip.x1,tmpclip.y1,tmpclip.x2,tmpclip.y2);
                WarDrawMap(0)
                for j=0,HitXYNum-1 do
                    DrawString(clips[j].x1, clips[j].y1-y_off, HitXY[j][3],
                               WAR.EffectColor[WAR.Effect],CC.DefaultFont)
                end
            end
        else    --面积太大，直接重绘
            lib.SetClip(0,0,CC.ScreenW,CC.ScreenH);
            WarDrawMap(0)
            for j=0,HitXYNum-1 do
                    DrawString(clips[j].x1, clips[j].y1-y_off, HitXY[j][3],
                                WAR.EffectColor[WAR.Effect],CC.DefaultFont)
            end
        end

        ShowScreen(1);
        lib.SetClip(0,0,0,0);

        local tend=lib.GetTime();
        if (tend-tstart)<CC.Frame then
            WaitFrame(CC.Frame-(tend-tstart));
        end
    end
end

    lib.SetClip(0,0,0,0);
    WarDrawMap(0);
    ShowScreen();
end

--武功伤害生命
--enemyid 敌人战斗id，
--wugong  我方使用武功
--返回：伤害点数

function War_PoisonMenu()              ---用毒菜单
    WAR.ShowHead=0;
    local r=War_ExecuteMenu(1);
    WAR.ShowHead=1;
    Cls();
    return r;
end

--计算敌人中毒点数
--pid 使毒人，
--emenyid  中毒人

function War_PoisonHurt(pid,emenyid)     --计算敌人中毒点数
    local v=math.modf((JY.Person[pid]["用毒能力"]-JY.Person[emenyid]["抗毒能力"])/4);
    if v<0 then
        v=0;
    end
    return AddPersonAttrib(emenyid,"中毒程度",v);
end

---解毒菜单

function War_DecPoisonMenu()          ---解毒菜单
    WAR.ShowHead=0;
    local r=War_ExecuteMenu(2);
    WAR.ShowHead=1;
    Cls();
    return r;
end

---医疗菜单

function War_DoctorMenu()            ---医疗菜单
    WAR.ShowHead=0;
    local r=War_ExecuteMenu(3);
    WAR.ShowHead=1;
    Cls();
    return r;
end

---执行医疗，解毒用毒
---flag=1 用毒， 2 解毒，3 医疗 4 暗器
---thingid 暗器物品id

function War_ExecuteMenu(flag,thingid)            ---执行医疗，解毒用毒暗器
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local step;

    if flag==1 then
        step=math.modf(JY.Person[pid]["用毒能力"]/15)+1;         --用毒步数
    elseif flag==2 then
        step=math.modf(JY.Person[pid]["解毒能力"]/15)+1;         --解毒步数
    elseif flag==3 then
        step=math.modf(JY.Person[pid]["医疗能力"]/15)+1;         --医疗步数
    elseif flag==4 then
        step=math.modf(JY.Person[pid]["暗器技巧"]/15)+1;         --暗器步数
    end

    War_CalMoveStep(WAR.CurID,step,1);

    local x1,y1=War_SelectMove();              --选择攻击对象

    if x1 ==nil then
        lib.GetKey();
        Cls();
        return 0;
    else
        return War_ExecuteMenu_Sub(x1,y1,flag,thingid);
    end
end

function War_ExecuteMenu_Sub(x1,y1,flag,thingid)     ---执行医疗，解毒用毒暗器的子函数，自动医疗也可调用
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];

    CleanWarMap(4,0);

    WAR.Person[WAR.CurID]["人方向"]=War_Direct(x0,y0,x1,y1);

    SetWarMap(x1,y1,4,1);

    local emeny=GetWarMap(x1,y1,2);
    if emeny>=0 then          --有人
         if flag==1 then
             if WAR.Person[WAR.CurID]["我方"] ~= WAR.Person[emeny]["我方"] then       --是敌人
                 WAR.Person[emeny]["点数"]=War_PoisonHurt(pid,WAR.Person[emeny]["人物编号"])
                 SetWarMap(x1,y1,4,5);
                   WAR.Effect=5;
             end
         elseif flag==2 then
             if WAR.Person[WAR.CurID]["我方"] == WAR.Person[emeny]["我方"] then       --不是敌人
                 WAR.Person[emeny]["点数"]=ExecDecPoison(pid,WAR.Person[emeny]["人物编号"])
                 SetWarMap(x1,y1,4,6);
                   WAR.Effect=6;
             end
         elseif flag==3 then
             if WAR.Person[WAR.CurID]["我方"] == WAR.Person[emeny]["我方"] then       --不是敌人
                 WAR.Person[emeny]["点数"]=ExecDoctor(pid,WAR.Person[emeny]["人物编号"])
                 SetWarMap(x1,y1,4,4);
                   WAR.Effect=4;
             end
         elseif flag==4 then
             if WAR.Person[WAR.CurID]["我方"] ~= WAR.Person[emeny]["我方"] then       --是敌人
                 WAR.Person[emeny]["点数"]=War_AnqiHurt(pid,WAR.Person[emeny]["人物编号"],thingid)
                 SetWarMap(x1,y1,4,2);
                   WAR.Effect=2;
             end
         end

    end

    WAR.EffectXY={};
    WAR.EffectXY[1]={x1,y1};
    WAR.EffectXY[2]={x1,y1};

    if flag==1 then
        War_ShowFight(pid,0,0,0,x1,y1,30);
    elseif flag==2 then
        War_ShowFight(pid,0,0,0,x1,y1,36);
    elseif flag==3 then
        War_ShowFight(pid,0,0,0,x1,y1,0);
    elseif flag==4 then
        if emeny>=0 then
            War_ShowFight(pid,0,-1,0,x1,y1,JY.Thing[thingid]["暗器动画编号"]);
        end
    end

    for i=0,WAR.PersonNum-1 do
        WAR.Person[i]["点数"]=0;
    end
    if flag==4 then
        if emeny>=0 then
            instruct_32(thingid,-1);            --物品数量减少
            return 1;
        else
            return 0;                   --暗器打空，则等于没有打
        end
    else
        WAR.Person[WAR.CurID]["经验"]=WAR.Person[WAR.CurID]["经验"]+1;
        AddPersonAttrib(pid,"体力",-2);
    end

    return 1;

end


--物品菜单

function War_ThingMenu()            --战斗物品菜单
    WAR.ShowHead=0;
    local thing={};
    local thingnum={};

    for i = 0,CC.MyThingNum-1 do
        thing[i]=-1;
        thingnum[i]=0;
    end

    local num=0;
    for i = 0,CC.MyThingNum-1 do
        local id = JY.Base["物品" .. i+1];
        if id>=0 then
            if JY.Thing[id]["类型"]==3 or JY.Thing[id]["类型"]==4 then
                thing[num]=id;
                thingnum[num]=JY.Base["物品数量" ..i+1];
                num=num+1;
            end
        end
    end

    local r=SelectThing(thing,thingnum);
    Cls();
    local rr=0;
    if r>=0 then
        if UseThing(r)==1 then
            rr=1;
        end
    end
    WAR.ShowHead=1;
    Cls();
    return rr;
end


---使用暗器

function War_RestMenu()           --休息
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local v=3+Rnd(3);
    AddPersonAttrib(pid,"体力",v);
    if JY.Person[pid]["体力"]>30 then
        v=3+Rnd(math.modf(JY.Person[pid]["体力"]/10)-2);
        AddPersonAttrib(pid,"生命",v);
        v=3+Rnd(math.modf(JY.Person[pid]["体力"]/10)-2);
        AddPersonAttrib(pid,"内力",v);
    end
    return 1;
end


--等待，把当前战斗人调到队尾

function War_WaitMenu()            --等待，把当前战斗人调到队尾

    for i =WAR.CurID, WAR.PersonNum-2 do
        local tmp=WAR.Person[i+1];
        WAR.Person[i+1]=WAR.Person[i];
        WAR.Person[i]=tmp;
        --调换人物
    end

    WarSetPerson();     --设置战斗人物位置

    for i=0,WAR.PersonNum-1 do
        WAR.Person[i]["贴图"]=WarCalPersonPic(i);
    end

    return 1;

end

function War_StatusMenu()          --战斗中显示状态
    WAR.ShowHead=0;
    Menu_Status();
    WAR.ShowHead=1;
    Cls();
end
