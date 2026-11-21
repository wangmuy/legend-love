-- battle_data.lua
-- 战斗地图数据读写（从 script/jymain.lua 搬入，**逻辑未改**）
--
-- battle-extensibility 阶段 1：纯搬移。
-- 所有函数仍是全局函数（`function Xxx()` 形式），调用方零改动。

function WarLoadMap(mapid)      --加载战斗地图
   EngineAPI.debug.log(string.format("load war map %d",mapid));
   lib.LoadWarMap(CC.WarMapFile[1],CC.WarMapFile[2],mapid,6,CC.WarWidth,CC.WarHeight);
end

function GetWarMap(x,y,level)   --取战斗地图数据
     return lib.GetWarMap(x,y,level);
end

function SetWarMap(x,y,level,v)  --存战斗地图数据
     lib.SetWarMap(x,y,level,v);
end

--设置某层为给定值

function CleanWarMap(level,v)
    lib.CleanWarMap(level,v);
end


--绘战斗地图
--flag==0 基本
--      1 显示移动路径 (v1,v2) 当前移动位置
--      2 命中人物（武功，医疗等）另一个颜色显示
--      4 战斗动画, v1 战斗人物pic, v2战斗人物贴图类型(0 使用战斗场景贴图，4，fight***贴图编号 v3 武功效果贴图 -1没有效果
