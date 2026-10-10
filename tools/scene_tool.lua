-- tools/scene_tool.lua
-- 子场景 S*/D* 数据通用排查工具（allsin.grp / alldef.grp，base 模板数据）。
--
-- 与 lib_love.lua LoadSMap/GetS/GetD 完全一致:
--   S: 每格 i16 有符号; 索引 = SWidth*SHeight*(scene*6+level) + y*SWidth + x
--      level 0 地面贴图 / 1 物品 / 2 ? / 3 事件(D*编号, >=0 表示该格挂着实体) / 4 海拔 / 5 ?
--   D: 每实体 11 个 i16 字段; 索引 = DNum*11*scene + id*11 + field (DNum=200)
--      field 0: 不可通过标记(0=可通过)
--      field 1: 保留
--      field 2: 空格触发事件号 (oldEventExecute flag=1)
--      field 3: 物品触发事件号 (flag=2)
--      field 4: 路过触发事件号 (flag=3)
--      field 5/6/7: 动画起始/结束/当前帧 pic*2; field 8: 动画延迟
--      field 9/10: 实体坐标 x/y
--
-- 用法:
--   lua tools/scene_tool.lua tile <data目录> <场景> <x> <y>   单格: S 层0-5 + 挂接实体全部字段
--   lua tools/scene_tool.lua dump <data目录> <场景> <层> [x1 y1 x2 y2]
--                                                   打印场景(或区域)某层 S 数据网格
--   lua tools/scene_tool.lua ents <data目录> <场景>   列出场景全部有效 D* 实体
--   lua tools/scene_tool.lua base <data目录>          打印 ranger.grp 新游戏 base 段基础字段
--
-- 示例:
--   lua tools/scene_tool.lua tile game/data 70 19 20
--   lua tools/scene_tool.lua dump game/data 70 3
--   lua tools/scene_tool.lua dump game/data 70 3 17 18 23 22
--   lua tools/scene_tool.lua ents game/data 70
--   lua tools/scene_tool.lua base game/data

local SWidth, SHeight, SNum, DNum = 64, 64, 100, 200
local LEVEL_NAMES = { "地面", "物品", "S2", "事件", "海拔", "S5" }

local sub = arg[1]
if not sub then
    io.write("usage: lua tools/scene_tool.lua <tile|dump|ents|base> ...\n")
    os.exit(1)
end

local function readAll(p)
    local f = assert(io.open(p, "rb"), "cannot open " .. p)
    local s = f:read("a")
    f:close()
    return s
end

local function sshortl(s, o)
    local v = (s:byte(o) or 0) + (s:byte(o + 1) or 0) * 256
    if v >= 32768 then v = v - 65536 end
    return v
end

local function getSceneFiles(data)
    for _, name in ipairs({ "allsin.grp", "alldef.grp" }) do
        local f = io.open(data .. "/" .. name, "rb")
        if f then f:close() end
        assert(f, "no " .. data .. "/" .. name)
    end
    return data .. "/allsin.grp", data .. "/alldef.grp"
end

local sgrp, dgrp

local function loadSceneData(data)
    local sp, dp = getSceneFiles(data)
    sgrp, dgrp = readAll(sp), readAll(dp)
end

local function getS(scene, x, y, level)
    if scene < 0 or scene >= SNum or x < 0 or x >= SWidth or y < 0 or y >= SHeight
        or level < 0 or level >= 6 then
        return "OOB"
    end
    local i = SWidth * SHeight * (scene * 6 + level) + y * SWidth + x + 1
    local b1, b2 = sgrp:byte(i), sgrp:byte(i + 1)
    if not b1 then return "OOB" end
    local n = b1 + b2 * 256
    return n > 32767 and n - 65536 or n
end

local function getD(scene, id, field)
    if scene < 0 or scene >= SNum or id < 0 or id >= DNum or field < 0 or field >= 11 then
        return "OOB"
    end
    local i = DNum * 11 * scene + id * 11 + field + 1
    local b1, b2 = dgrp:byte(i), dgrp:byte(i + 1)
    if not b1 then return "OOB" end
    local n = b1 + b2 * 256
    return n > 32767 and n - 65536 or n
end

local function checkScene(scene)
    scene = tonumber(scene)
    assert(scene and scene >= 0 and scene < SNum, "scene out of range (0.." .. (SNum - 1) .. "): " .. tostring(scene))
    return scene
end

if sub == "tile" then
    local data = assert(arg[2], "usage: tile <datadir> <scene> <x> <y>")
    local scene = checkScene(arg[3])
    local x, y = tonumber(arg[4]), tonumber(arg[5])
    assert(x and y, "usage: tile <datadir> <scene> <x> <y>")
    loadSceneData(data)

    print(string.format("scene %d tile (%d,%d) S levels:", scene, x, y))
    for lv = 0, 5 do
        print(string.format("  level%d (%s) = %s", lv, LEVEL_NAMES[lv + 1], tostring(getS(scene, x, y, lv))))
    end
    local d_id = getS(scene, x, y, 3)
    if type(d_id) == "number" and d_id >= 0 and d_id < DNum then
        local names = { "不可通过", "保留", "事件(空格)", "事件(物品)", "事件(路过)",
            "动画起", "动画止", "动画当前", "动画延迟", "x", "y" }
        print(string.format("  实体 D[%d]:", d_id))
        for f = 0, 10 do
            print(string.format("    field%2d (%s) = %s", f, names[f + 1], tostring(getD(scene, d_id, f))))
        end
    elseif type(d_id) == "number" then
        print(string.format("  实体 D[%s]: 超出 DNum=%d 范围", tostring(d_id), DNum))
    end

elseif sub == "dump" then
    local data = assert(arg[2], "usage: dump <datadir> <scene> <level> [x1 y1 x2 y2]")
    local scene = checkScene(arg[3])
    local level = tonumber(arg[4])
    assert(level and level >= 0 and level < 6, "level out of range (0-5): " .. tostring(level))
    loadSceneData(data)

    local x1, y1, x2, y2 = 0, 0, SWidth - 1, SHeight - 1
    if arg[5] then
        x1, y1, x2, y2 = tonumber(arg[5]), tonumber(arg[6]), tonumber(arg[7]), tonumber(arg[8])
        assert(x1 and y1 and x2 and y2, "usage: dump <datadir> <scene> <level> <x1> <y1> <x2> <y2>")
        if x1 > x2 then x1, x2 = x2, x1 end
        if y1 > y2 then y1, y2 = y2, y1 end
    end
    print(string.format("scene %d level%d (%s) [%d,%d]-[%d,%d]:", scene, level, LEVEL_NAMES[level + 1], x1, y1, x2, y2))
    for y = y1, y2 do
        local row = { string.format("%3d ", y) }
        for x = x1, x2 do
            local v = getS(scene, x, y, level)
            if v == 0 then
                row[#row + 1] = "   ."
            elseif type(v) == "number" then
                row[#row + 1] = ("%4d"):format(v)
            else
                row[#row + 1] = "  ??"
            end
        end
        print(table.concat(row, " "))
    end

elseif sub == "ents" then
    local data = assert(arg[2], "usage: ents <datadir> <scene>")
    local scene = checkScene(arg[3])
    loadSceneData(data)

    local count = 0
    for id = 0, DNum - 1 do
        local x, y = getD(scene, id, 9), getD(scene, id, 10)
        local s3 = getS(scene, x, y, 3)
        if x >= 0 and x < SWidth and y >= 0 and y < SHeight and s3 == id then
            count = count + 1
            print(string.format("D[%3d] (%2d,%2d) 不可通过=%s 空格=%s 物品=%s 路过=%s 动画=%s..%s",
                id, x, y,
                tostring(getD(scene, id, 0)), tostring(getD(scene, id, 2)),
                tostring(getD(scene, id, 3)), tostring(getD(scene, id, 4)),
                tostring(getD(scene, id, 5)), tostring(getD(scene, id, 6))))
        end
    end
    print(string.format("scene %d: %d 个有效实体 (S层3 挂接)", scene, count))

elseif sub == "base" then
    local data = assert(arg[2], "usage: base <datadir>")
    local idx = io.open(data .. "/ranger.idx", "rb")
    assert(idx, "no " .. data .. "/ranger.idx")
    idx:close()
    local idxb = readAll(data .. "/ranger.idx")
    local grpb = readAll(data .. "/ranger.grp")
    local baseEnd = (idxb:byte(1) or 0) + (idxb:byte(2) or 0) * 256
        + (idxb:byte(3) or 0) * 65536 + (idxb:byte(4) or 0) * 16777216
    print(string.format("ranger.grp: base 段 = [0..%d] (idx[0]=%d)", baseEnd - 1, baseEnd))

    -- 与 jyconst.lua CC.Base_S 一致的 base 段字段（物品之前）
    local fields = {
        { "乘船", 0 }, { "无用", 2 }, { "人X", 4 }, { "人Y", 6 }, { "人X1", 8 },
        { "人Y1", 10 }, { "人方向", 12 }, { "船X", 14 }, { "船Y", 16 }, { "船X1", 18 },
        { "船Y1", 20 }, { "船方向", 22 },
    }
    for i = 1, 6 do fields[#fields + 1] = { "队伍" .. i, 24 + 2 * (i - 1) } end
    for _, f in ipairs(fields) do
        print(string.format("  %-6s @%-2d = %d", f[1], f[2], sshortl(grpb, f[2] + 1)))
    end

else
    io.write("unknown subcommand: " .. sub .. " (expect tile|dump|ents|base)\n")
    os.exit(1)
end
