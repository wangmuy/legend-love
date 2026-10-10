-- tools/sdata_tool.lua
-- 场景 S*/D* 数据（allsin.grp / alldef.grp）通用检查工具。
--
-- 布局与 lib_love.lua 的 GetS/GetD 完全一致（常量取自 jyconst.lua）:
--   S*: 每 tile 6 层, 每场景 CC.SWidth x CC.SHeight (64x64), i16 小端
--        offset = SWidth*SHeight*(scene*6+level) + y*SWidth + x
--   D*: 每场景 CC.DNum=200 个, 每个 11 字段, i16 小端
--        offset = DNum*11*scene + did*11 + i
--
-- 用法（在仓库根目录或任意目录执行，data 目录为第一个参数）:
--   lua tools/sdata_tool.lua tile <data目录> <scene> <x> <y> [半径=2]
--                                       打印该 tile 的 6 层数据 + 邻域 level3 网格
--                                       （level3 = 路过事件 D* 编号, >=0 表示有实体）
--   lua tools/sdata_tool.lua dentity <data目录> <scene> <did> [字段i...]
--                                       打印某个 D* 的全部或指定字段
--   lua tools/sdata_tool.lua find <data目录> <scene> [level=3] [min=0]
--                                       列出该场景内 level 值 >= min 的所有 tile
--
-- 示例:
--   lua tools/sdata_tool.lua tile game/data 70 19 20
--   lua tools/sdata_tool.lua dentity game/data 70 0
--   lua tools/sdata_tool.lua find game/data 70          -- 找场景70全部路过事件 tile

local SWidth, SHeight = 64, 64   -- CC.SWidth / CC.SHeight
local DNum, DNum2 = 200, 11      -- CC.DNum / 每个 D* 的字段数

local sub = arg[1]
if not sub then
    io.write("usage: lua tools/sdata_tool.lua <tile|dentity|find> ...\n")
    os.exit(1)
end

local function readAll(p)
    local f = assert(io.open(p, "rb"), "cannot open " .. p)
    local s = f:read("a")
    f:close()
    return s
end

-- 0-based 字节偏移读 i16（小端）
local function s16(s, off0)
    local b = (s:byte(off0 + 1) or 0) + (s:byte(off0 + 2) or 0) * 256
    return b >= 32768 and b - 65536 or b
end

local function getS(sdata, scene, x, y, level)
    if scene < 0 or x < 0 or x >= SWidth or y < 0 or y >= SHeight
        or level < 0 or level >= 6 then
        return nil
    end
    return s16(sdata, SWidth * SHeight * (scene * 6 + level) + y * SWidth + x)
end

local function getD(ddata, scene, did, i)
    if scene < 0 or did < 0 or did >= DNum or i < 0 or i >= DNum2 then
        return nil
    end
    return s16(ddata, DNum * DNum2 * scene + did * DNum2 + i)
end

local function checkScene(sdata, scene)
    local maxScene = math.floor(#sdata / (SWidth * SHeight * 6 * 2))
    if scene < 0 or scene >= maxScene then
        io.write(string.format("scene %d out of range (valid: 0..%d)\n", scene, maxScene - 1))
        os.exit(1)
    end
end

if sub == "tile" then
    local data = assert(arg[2], "usage: tile <datadir> <scene> <x> <y> [radius]")
    local scene = assert(tonumber(arg[3]), "need scene id")
    local x = assert(tonumber(arg[4]), "need x")
    local y = assert(tonumber(arg[5]), "need y")
    local radius = tonumber(arg[6]) or 2
    local sdata = readAll(data .. "/allsin.grp")
    checkScene(sdata, scene)

    print(string.format("scene %d tile (%d, %d) S levels 0-5:", scene, x, y))
    for lv = 0, 5 do
        local v = getS(sdata, scene, x, y, lv)
        print(string.format("  level%d = %s", lv, v == nil and "OOB" or tostring(v)))
    end
    print(string.format("neighbors level3 (D* id, >=0 means entity), radius %d:", radius))
    for dy = -radius, radius do
        local row = {}
        for dx = -radius, radius do
            local v = getS(sdata, scene, x + dx, y + dy, 3)
            row[#row + 1] = string.format("%d,%d=%s", x + dx, y + dy, v == nil and "?" or v)
        end
        print("  " .. table.concat(row, "  "))
    end
    -- 该 tile 自身的 level3 若是有效 D* 编号, 顺带打印对应 D*
    local lv3 = getS(sdata, scene, x, y, 3)
    if lv3 ~= nil and lv3 >= 0 and lv3 < DNum then
        local ddata = readAll(data .. "/alldef.grp")
        print(string.format("D[%d][%d]:", scene, lv3))
        for i = 0, DNum2 - 1 do
            print(string.format("  [%d] = %s", i, tostring(getD(ddata, scene, lv3, i))))
        end
    end

elseif sub == "dentity" then
    local data = assert(arg[2], "usage: dentity <datadir> <scene> <did> [i...]")
    local scene = assert(tonumber(arg[3]), "need scene id")
    local did = assert(tonumber(arg[4]), "need D* id (0.." .. (DNum - 1) .. ")")
    local ddata = readAll(data .. "/alldef.grp")
    local idxs = {}
    if arg[5] then
        for i = 5, #arg do idxs[#idxs + 1] = assert(tonumber(arg[i]), "bad field: " .. arg[i]) end
    else
        for i = 0, DNum2 - 1 do idxs[#idxs + 1] = i end
    end
    print(string.format("scene %d D[%d]:", scene, did))
    for _, i in ipairs(idxs) do
        print(string.format("  [%d] = %s", i, tostring(getD(ddata, scene, did, i))))
    end

elseif sub == "find" then
    local data = assert(arg[2], "usage: find <datadir> <scene> [level=3] [min=0]")
    local scene = assert(tonumber(arg[3]), "need scene id")
    local level = tonumber(arg[4]) or 3
    local min = tonumber(arg[5]) or 0
    local sdata = readAll(data .. "/allsin.grp")
    checkScene(sdata, scene)
    local found = 0
    for y = 0, SHeight - 1 do
        local row = {}
        for x = 0, SWidth - 1 do
            local v = getS(sdata, scene, x, y, level)
            if v and v >= min then
                found = found + 1
                row[#row + 1] = string.format("%d,%d=%d", x, y, v)
            end
        end
        if #row > 0 then
            print("  " .. table.concat(row, "  "))
        end
    end
    print(string.format("scene %d level%d >= %d: %d tiles", scene, level, min, found))

else
    io.write("unknown subcommand: " .. sub .. " (expect tile|dentity|find)\n")
    os.exit(1)
end
