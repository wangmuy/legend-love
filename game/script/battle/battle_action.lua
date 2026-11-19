-- battle_action.lua
-- 战斗动作执行（移动/攻击/武功/道具/伤害计算）
-- 从 script/jymain.lua 搬入，**逻辑未改**
--
-- battle-extensibility 阶段 1：纯搬移。

function War_PersonLostLife()             --计算战斗后每回合由于中毒或受伤而掉血
    for i=0,WAR.PersonNum-1 do
        local pid=WAR.Person[i]["人物编号"]
        if WAR.Person[i]["死亡"]==false then
            if JY.Person[pid]["受伤程度"]>0 then
                local dec=math.modf(JY.Person[pid]["受伤程度"]/20);
                AddPersonAttrib(pid,"生命",-dec);
            end
            if JY.Person[pid]["中毒程度"]>0 then
                local dec=math.modf(JY.Person[pid]["中毒程度"]/10);
                AddPersonAttrib(pid,"生命",-dec);
            end
            if JY.Person[pid]["生命"]<=0 then
                JY.Person[pid]["生命"]=1;
            end
        end
    end
end

function War_isEnd()           --战斗是否结束

    for i=0,WAR.PersonNum-1 do
        if JY.Person[WAR.Person[i]["人物编号"]]["生命"]<=0 then
            WAR.Person[i]["死亡"]=true;
        end
    end
    WarSetPerson();     --设置战斗人物位置

    Cls();
    ShowScreen();

    local myNum=0;
    local EmenyNum=0;
    for i=0,WAR.PersonNum-1 do
        if WAR.Person[i]["死亡"]==false then
            if WAR.Person[i]["我方"]==true then
                myNum=1;
            else
                EmenyNum=1;
            end
        end
    end

    if EmenyNum==0 then
        return 1;
    end
    if myNum==0 then
        return 2;
    end
    return 0;
end

--选择我方参战人

function War_CalMoveStep(id,stepmax,flag)                   --计算可移动步数

      CleanWarMap(3,255);           --第三层坐标用来设置移动，先都设为255，

    local x=WAR.Person[id]["坐标X"];
    local y=WAR.Person[id]["坐标Y"];

    local steparray={};     --用数组保存第n步的坐标。
    for i=0,stepmax do
        steparray[i]={};
        steparray[i].x={};
        steparray[i].y={};
    end

    SetWarMap(x,y,3,0);
    steparray[0].num=1;
    steparray[0].x[1]=x;
    steparray[0].y[1]=y;
    for i=0,stepmax-1 do       --根据第0步的坐标找出第1步，然后继续找
        War_FindNextStep(steparray,i,flag);
        if steparray[i+1].num==0 then
            break;
        end
    end

    return steparray;

end

function War_FindNextStep(steparray,step,flag)      --设置下一步可移动的坐标
    local num=0;
    local step1=step+1;
    for i=1,steparray[step].num do
        local x=steparray[step].x[i];
        local y=steparray[step].y[i];
        if x+1<CC.WarWidth-1 then                        --当前步数的相邻格
            local v=GetWarMap(x+1,y,3);
            if v ==255 and War_CanMoveXY(x+1,y,flag)==true then
                num= num+1;
                steparray[step1].x[num]=x+1;
                steparray[step1].y[num]=y;
                SetWarMap(x+1,y,3,step1);
            end
        end

        if x-1>0 then                        --当前步数的相邻格
            local v=GetWarMap(x-1,y,3);
            if v ==255 and War_CanMoveXY(x-1,y,flag)==true then
                 num=num+1;
                steparray[step1].x[num]=x-1;
                steparray[step1].y[num]=y;
                SetWarMap(x-1,y,3,step1);
            end
        end

        if y+1<CC.WarHeight-1 then                        --当前步数的相邻格
            local v=GetWarMap(x,y+1,3);
            if v ==255 and War_CanMoveXY(x,y+1,flag)==true then
                 num= num+1;
                steparray[step1].x[num]=x;
                steparray[step1].y[num]=y+1;
                SetWarMap(x,y+1,3,step1);
            end
        end

        if y-1>0 then                        --当前步数的相邻格
            local v=GetWarMap(x ,y-1,3);
            if v ==255 and War_CanMoveXY(x,y-1,flag)==true then
                num= num+1;
                steparray[step1].x[num]=x ;
                steparray[step1].y[num]=y-1;
                SetWarMap(x ,y-1,3,step1);
            end
        end
    end
    steparray[step1].num=num;

end

function War_CanMoveXY(x,y,flag)  --坐标是否可以通过，判断移动时使用
    if GetWarMap(x,y,1)>0 then    --第1层有物体
        return false
    end
    if flag==0 then
        if CC.WarWater[GetWarMap(x,y,0)]~=nil then          --水面，不可走
            return false
        end
        if GetWarMap(x,y,2)>=0 then    --有人
            return false
        end
    end
    return true;
end

function War_MovePerson(x,y)            --移动人物到位置x,y

    local movenum=GetWarMap(x,y,3);
    WAR.Person[WAR.CurID]["移动步数"]=WAR.Person[WAR.CurID]["移动步数"]-movenum;    --可移动步数减小

    local movetable={};  --   记录每步移动
    for i=movenum,1,-1 do    --从目的位置反着找到初始位置，作为移动的次序
        movetable[i]={};
        movetable[i].x=x;
        movetable[i].y=y;
        if GetWarMap(x-1,y,3)==i-1 then
            x=x-1;
            movetable[i].direct=1;
        elseif GetWarMap(x+1,y,3)==i-1 then
            x=x+1;
            movetable[i].direct=2;
        elseif GetWarMap(x,y-1,3)==i-1 then
            y=y-1;
            movetable[i].direct=3;
        elseif GetWarMap(x,y+1,3)==i-1 then
            y=y+1;
            movetable[i].direct=0;
        end
    end

    for i=1,movenum do
        local t1=lib.GetTime();

        SetWarMap(WAR.Person[WAR.CurID]["坐标X"],WAR.Person[WAR.CurID]["坐标Y"],2,-1);
        SetWarMap(WAR.Person[WAR.CurID]["坐标X"],WAR.Person[WAR.CurID]["坐标Y"],5,-1);

        WAR.Person[WAR.CurID]["坐标X"]=movetable[i].x;
        WAR.Person[WAR.CurID]["坐标Y"]=movetable[i].y;
        WAR.Person[WAR.CurID]["人方向"]=movetable[i].direct;
        WAR.Person[WAR.CurID]["贴图"]=WarCalPersonPic(WAR.CurID);

        SetWarMap(WAR.Person[WAR.CurID]["坐标X"],WAR.Person[WAR.CurID]["坐标Y"],2,WAR.CurID);
        SetWarMap(WAR.Person[WAR.CurID]["坐标X"],WAR.Person[WAR.CurID]["坐标Y"],5,WAR.Person[WAR.CurID]["贴图"]);

        WarDrawMap(0);
        ShowScreen();
        local t2=lib.GetTime();
        if i<movenum then
            if (t2-t1)< 2*CC.Frame then
                lib.Delay(2*CC.Frame-(t2-t1));
            end
        end
    end

end

function War_FightMenu()              --执行攻击菜单
    local pid=WAR.Person[WAR.CurID]["人物编号"];

    local numwugong=0;
    local menu={};
    for i=1,10 do
        local tmp=JY.Person[pid]["武功" .. i];
        if tmp>0 then
            menu[i]={JY.Wugong[tmp]["名称"],nil,1};
            if JY.Wugong[tmp]["消耗内力点数"] > JY.Person[pid]["内力"] then
                menu[i][3]=0;
            end
            numwugong=numwugong+1;
        end
    end

    if numwugong==0 then
        return 0;
    end
    local r;
    if numwugong==1 then
        r=1;
    else
        r=ShowMenu(menu,numwugong,0,CC.MainSubMenuX,CC.MainSubMenuY,0,0,1,1,CC.DefaultFont,C_ORANGE,C_WHITE);
    end
    if r==0 then
        return 0;
    end

    WAR.ShowHead=0;
    local r2=War_Fight_Sub(WAR.CurID,r);
    WAR.ShowHead=1;
    Cls();
    return r2;
end

--执行战斗，自动和手动战斗都调用

function War_Fight_Sub(id,wugongnum,x,y)          --执行战斗
    local pid=WAR.Person[id]["人物编号"];
    local wugong=JY.Person[pid]["武功" .. wugongnum];
    local level=math.modf(JY.Person[pid]["武功等级" .. wugongnum]/100)+1;

       CleanWarMap(4,0);

    local fightscope=JY.Wugong[wugong]["攻击范围"];
    --在map4标注武功攻击效果
    if fightscope==0 then
        if War_FightSelectType0(wugong,level,x,y)==false then
            return 0;
        end
    elseif fightscope==1 then
        War_FightSelectType1(wugong,level,x,y)

    elseif fightscope==2 then
        War_FightSelectType2(wugong,level,x,y)

    elseif fightscope==3 then
        if War_FightSelectType3(wugong,level,x,y)==false then
            return 0;
        end
    end

    local fightnum=1;
    if JY.Person[pid]["左右互搏"]==1 then
        fightnum=2;
    end

for k=1,fightnum  do         --如果左右互搏，则攻击两次
    for i=0,CC.WarWidth-1 do
        for j=0,CC.WarHeight-1 do
            local effect=GetWarMap(i,j,4);
            if effect>0 then              --攻击效果地方
                  local emeny=GetWarMap(i,j,2);
                 if emeny>=0 then          --有人
                     if WAR.Person[WAR.CurID]["我方"] ~= WAR.Person[emeny]["我方"] then       --是敌人
                         --只有点和面攻击可以杀内力。此时伤害类型有效
                         if JY.Wugong[wugong]["伤害类型"]==1 and (fightscope==0 or fightscope==3) then
                             WAR.Person[emeny]["点数"]=-War_WugongHurtNeili(emeny,wugong,level)
                             SetWarMap(i,j,4,3);
                             WAR.Effect=3;
                         else
                             WAR.Person[emeny]["点数"]=-War_WugongHurtLife(emeny,wugong,level)
                             WAR.Effect=2;
                             SetWarMap(i,j,4,2);
                         end
                     end
                 end
             end
         end
    end

    War_ShowFight(pid,wugong,JY.Wugong[wugong]["武功类型"],level,x,y,JY.Wugong[wugong]["武功动画&音效"]);

    for i=0,WAR.PersonNum-1 do
        WAR.Person[i]["点数"]=0;
    end

    WAR.Person[WAR.CurID]["经验"]=WAR.Person[WAR.CurID]["经验"]+2;

    if JY.Person[pid]["武功等级" .. wugongnum]<900 then
        JY.Person[pid]["武功等级" .. wugongnum]=JY.Person[pid]["武功等级" .. wugongnum]+Rnd(2)+1;
    end

    if math.modf(JY.Person[pid]["武功等级" .. wugongnum]/100)+1 ~= level then    --武功升级了
        level=math.modf(JY.Person[pid]["武功等级" .. wugongnum]/100)+1;
        DrawStrBox(-1,-1,string.format("%s 升为 %d 级",JY.Wugong[wugong]["名称"],level),C_ORANGE,CC.DefaultFont)
        ShowScreen();
        lib.Delay(500);
        Cls();
        ShowScreen();
    end

    AddPersonAttrib(pid,"内力",-math.modf((level+1)/2)*JY.Wugong[wugong]["消耗内力点数"])

end

    AddPersonAttrib(pid,"体力",-3);

    return 1;
end

--选择点攻击
--x1,y1 攻击点，如果为空则手工选择

function War_FightSelectType0(wugong,level,x1,y1)          --选择点攻击
    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];
    War_CalMoveStep(WAR.CurID,JY.Wugong[wugong]["移动范围" .. level],1);

    if x1==nil and y1==nil then
        x1,y1=War_SelectMove();              --选择攻击对象
    end
    if x1 ==nil then
        lib.GetKey();
        Cls();
        return false;
    end

    WAR.Person[WAR.CurID]["人方向"]=War_Direct(x0,y0,x1,y1);

    SetWarMap(x1,y1,4,1);

    WAR.EffectXY={};
    WAR.EffectXY[1]={x1,y1};
    WAR.EffectXY[2]={x1,y1};

end

--选择线攻击
--direct 攻击方向，为空则手工设置

function War_FightSelectType1(wugong,level,x,y)            --选择线攻击
    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];
    local direct;

    if x==nil and y==nil  then
        direct =-1;
        DrawStrBox(CC.MainSubMenuX,CC.MainSubMenuY,"请选择攻击方向",C_ORANGE,CC.DefaultFont)
        ShowScreen();

        while true do           --选择方向
            local key=WaitKey();
            if key==VK_UP then
                direct=0;
            elseif key==VK_DOWN then
                direct=3;
            elseif key==VK_LEFT then
                direct=2;
            elseif key==VK_RIGHT then
                direct=1;
            end
            if direct>=0 then
                break;
            end
        end

        Cls(CC.MainSubMenuX,CC.MainSubMenuY,CC.ScreenW,CC.ScreenH);
        ShowScreen();
    else
        direct=War_Direct(x0,y0,x,y);
    end

    WAR.Person[WAR.CurID]["人方向"]=direct;
    local move=JY.Wugong[wugong]["移动范围" .. level]

    WAR.EffectXY={};

    for i=1,move do
        if direct==0 then
            SetWarMap(x0,y0-i,4,1);
        elseif direct==3 then
            SetWarMap(x0,y0+i,4,1);
        elseif direct==2 then
            SetWarMap(x0-i,y0,4,1);
        elseif direct==1 then
            SetWarMap(x0+i,y0,4,1);
        end
    end

    if direct==0 then
        WAR.EffectXY[1]={x0,y0-1};
        WAR.EffectXY[2]={x0,y0-move};
    elseif direct==3 then
        WAR.EffectXY[1]={x0,y0+1};
        WAR.EffectXY[2]={x0,y0+move};
    elseif direct==2 then
        WAR.EffectXY[1]={x0-1,y0};
        WAR.EffectXY[2]={x0-move,y0};
    elseif direct==1 then
        WAR.EffectXY[1]={x0+1,y0};
        WAR.EffectXY[2]={x0+move,y0};
    end

end

--选择十字攻击

function War_FightSelectType2(wugong,level)                 --选择十字攻击
    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];

    local move=JY.Wugong[wugong]["移动范围" .. level]

    WAR.EffectXY={};

    for i=1,move do
        SetWarMap(x0,y0-i,4,1);
        SetWarMap(x0,y0+i,4,1);
        SetWarMap(x0-i,y0,4,1);
        SetWarMap(x0+i,y0,4,1);
    end

    WAR.EffectXY[1]={x0-move,y0};
    WAR.EffectXY[2]={x0+move,y0};

end

--选择面攻击
--x1,y1 攻击点，如果为空则手工选择

function War_FightSelectType3(wugong,level,x1,y1)            --选择面攻击
    local x0=WAR.Person[WAR.CurID]["坐标X"];
    local y0=WAR.Person[WAR.CurID]["坐标Y"];
    War_CalMoveStep(WAR.CurID,JY.Wugong[wugong]["移动范围" .. level],1);

    if x1==nil and y1==nil then
        x1,y1=War_SelectMove();              --选择攻击对象
    end

    if x1 ==nil then
        lib.GetKey();
        Cls();
        return false;
    end

    WAR.Person[WAR.CurID]["人方向"]=War_Direct(x0,y0,x1,y1);

    local move=JY.Wugong[wugong]["杀伤范围" .. level]

    WAR.EffectXY={};

    for i=-move,move do
        for j=-move,move do
            SetWarMap(x1+i,y1+j,4,1);
         end
    end

    WAR.EffectXY[1]={x1-2*move,y1};
    WAR.EffectXY[2]={x1+2*move,y1};
end

--计算人方向
--(x1,y1) 人位置     -(x2,y2) 目标位置
--返回： 方向

function War_Direct(x1,y1,x2,y2)             --计算人方向
    local x=x2-x1;
    local y=y2-y1;

    if math.abs(y)>math.abs(x) then
        if y>0 then
            return 3;
        else
            return 0
        end
    else
        if x>0 then
            return 1;
        else
            return 2;
        end
    end
end


--显示战斗动画
--pid 人id
--wugong  武功编号， 0 表示用毒解毒等，使用普通攻击效果
--wogongtype =0 医疗用毒解毒，1,2,3,4 武功类型  -1 暗器
--level 武功等级
--x,y 攻击坐标
--eft  武功动画效果id  eft.idx/grp中的效果

function War_WugongHurtLife(emenyid,wugong,level)             --计算武功伤害生命
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local eid=WAR.Person[emenyid]["人物编号"];

    --计算武学常识
    local mywuxue=0;
    local emenywuxue=0;
    for i=0,WAR.PersonNum-1 do
        local id =WAR.Person[i]["人物编号"]
        if WAR.Person[i]["死亡"]==false and JY.Person[id]["武学常识"]>80 then
            if WAR.Person[WAR.CurID]["我方"]==WAR.Person[i]["我方"] then
                mywuxue=mywuxue+JY.Person[id]["武学常识"];
            else
                emenywuxue=emenywuxue+JY.Person[id]["武学常识"];
            end
        end
    end

    --计算实际使用武功等级
    while true do
        if math.modf((level+1)/2)*JY.Wugong[wugong]["消耗内力点数"] > JY.Person[pid]["内力"] then
            level=level-1;
        else
            break;
        end
    end

    if level<=0 then     --防止出现左右互博时第一次攻击完毕，第二次攻击没有内力的情况。
        level=1;
    end

    --武功武器配合增加攻击力
    local fightnum=0;
    for i,v in ipairs(CC.ExtraOffense) do
        if v[1]==JY.Person[pid]["武器"] and v[2]==wugong then
            fightnum=v[3];
            break;
        end
    end

    --计算攻击力
    fightnum=fightnum+(JY.Person[pid]["攻击力"]*3+JY.Wugong[wugong]["攻击力" .. level ])/2;

    if JY.Person[pid]["武器"]>=0 then
        fightnum=fightnum+JY.Thing[JY.Person[pid]["武器"]]["加攻击力"];
    end
    if JY.Person[pid]["防具"]>=0 then
        fightnum=fightnum+JY.Thing[JY.Person[pid]["防具"]]["加攻击力"];
    end
    fightnum=fightnum+mywuxue;

    --计算防御力
    local defencenum=JY.Person[eid]["防御力"];
    if JY.Person[eid]["武器"]>=0 then
        defencenum=defencenum+JY.Thing[JY.Person[eid]["武器"]]["加防御力"];
    end
    if JY.Person[eid]["防具"]>=0 then
        defencenum=defencenum+JY.Thing[JY.Person[eid]["防具"]]["加防御力"];
    end
    defencenum= defencenum+ emenywuxue;

    --计算实际伤害
    local hurt=(fightnum-3*defencenum)*2/3+Rnd(20)-Rnd(20);
    if hurt <0 then
        hurt=Rnd(10)+1;
    end
    hurt=hurt+JY.Person[pid]["体力"]/15+JY.Person[eid]["受伤程度"]/20;

    --考虑距离因素
    local offset=math.abs(WAR.Person[WAR.CurID]["坐标X"]-WAR.Person[emenyid]["坐标X"])+
                 math.abs(WAR.Person[WAR.CurID]["坐标Y"]-WAR.Person[emenyid]["坐标Y"]);

    if offset <10 then
        hurt=hurt*(100-(offset-1)*3)/100;
    else
        hurt=hurt*2/3;
    end

    hurt=math.modf(hurt);
    if hurt<=0 then
        hurt=Rnd(8)+1;
    end

    JY.Person[eid]["生命"]=JY.Person[eid]["生命"]-hurt;
    WAR.Person[WAR.CurID]["经验"]=WAR.Person[WAR.CurID]["经验"]+math.modf(hurt/5);

    if JY.Person[eid]["生命"]<0 then                 --打死敌人获得额外经验
        JY.Person[eid]["生命"]=0;
        WAR.Person[WAR.CurID]["经验"]=WAR.Person[WAR.CurID]["经验"]+JY.Person[eid]["等级"]*10;
    end

    AddPersonAttrib(eid,"受伤程度",math.modf(hurt/10));

    --敌人中毒点数
    local poisonnum=level*JY.Wugong[wugong]["敌人中毒点数"]+JY.Person[pid]["攻击带毒"];

    if JY.Person[eid]["抗毒能力"]< poisonnum and JY.Person[eid]["抗毒能力"]<90 then
         AddPersonAttrib(eid,"中毒程度",math.modf(poisonnum/15));
    end

    return hurt;
end

--武功伤害内力
--enemyid 敌人战斗id，
--wugong  我方使用武功
--返回：伤害点数

function War_WugongHurtNeili(enemyid,wugong,level)           --计算武功伤害内力
    local pid=WAR.Person[WAR.CurID]["人物编号"];
    local eid=WAR.Person[enemyid]["人物编号"];

    local addvalue=JY.Wugong[wugong]["加内力" .. level];
    local decvalue=JY.Wugong[wugong]["杀内力" .. level];

    if addvalue>0 then
        if math.modf(addvalue/2)>0 then
            AddPersonAttrib(pid,"内力最大值",Rnd(math.modf(addvalue/2)));
        end
        AddPersonAttrib(pid,"内力",math.abs(addvalue+Rnd(3)-Rnd(3)));
    end
    return -AddPersonAttrib(eid,"内力",-math.abs(decvalue+Rnd(3)-Rnd(3)));
end

---用毒菜单

function War_UseAnqi(id)          ---战斗使用暗器
    return War_ExecuteMenu(4,id);
end

function War_AnqiHurt(pid,emenyid,thingid)         --计算暗器伤害
    local num;
    if JY.Person[emenyid]["受伤程度"]==0 then
        num=JY.Thing[thingid]["加生命"]/4-Rnd(5);
    elseif JY.Person[emenyid]["受伤程度"]<=33 then
        num=JY.Thing[thingid]["加生命"]/3-Rnd(5);
    elseif JY.Person[emenyid]["受伤程度"]<=66 then
        num=JY.Thing[thingid]["加生命"]/2-Rnd(5);
    else
        num=JY.Thing[thingid]["加生命"]/2-Rnd(5);
    end

    num=math.modf((num-JY.Person[pid]["暗器技巧"]*2)/3);
    AddPersonAttrib(emenyid,"受伤程度",math.modf(-num/4));      --此处的num为负值

    local r=AddPersonAttrib(emenyid,"生命",math.modf(num));

    if JY.Thing[thingid]["加中毒解毒"]>0 then
        num=math.modf((JY.Thing[thingid]["加中毒解毒"]+JY.Person[pid]["暗器技巧"])/2);
        num=num-JY.Person[emenyid]["抗毒能力"];
        num=limitX(num,0,CC.PersonAttribMax["用毒能力"]);
        AddPersonAttrib(emenyid,"中毒程度",num);
    end
    return r;
end

--休息
