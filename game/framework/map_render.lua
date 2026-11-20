-- map_render.lua
-- 等距地图投影 + 瓦片绘制（引擎无关）
--
-- **为什么有这个模块**（port-map-render-native）：
--
-- 原版的地图绘制住在引擎里（`lib_love.lua` 的 `DrawMMap`/`DrawSMap`/`DrawWarMap`），
-- 但它们的 **90% 是纯投影数学**（等距坐标变换 + 可见瓦片循环），
-- 只有 10% 真的碰引擎（贴图上传 / 裁剪 / 清屏）。
--
--   DrawMMap:   79 行，8 行碰引擎
--   DrawSMap:   79 行，8 行碰引擎
--   DrawWarMap: 122 行，12 行碰引擎
--   BuildingSort: 83 行，**0 行**碰引擎
--
-- 引擎不该持有这些 —— 换引擎时不该重写等距投影。
--
-- **状态归属**：`buildList` / `buildNumber`（建筑深度排序结果）
-- 是本模块的**模块内状态**，不是引擎的。原版放在 `lib_love.lua` 全局里，
-- 那是历史遗留（渲染状态和引擎实现写在同一个文件）。
--
-- **负约束**：
--   ✗ 不 require("engine-*")   —— framework 只经 EngineAPI
--   ✗ 不调 love.*              —— 否则等于换了个地方写引擎代码
--   ✗ 不读 JY.* / WAR.*        —— 游戏状态经参数传入
--
-- 但 `CC.*`（地图尺寸）和 `CONFIG.*`（投影常量）**必须读**：
-- 它们是**数据格式的一部分**（`.grp` 里就是按 CC.MWidth/MHeight 排布的），
-- framework 其他模块也这么做（`game_states.lua` 有 31 处 `CC.`）。
-- 抽成契约反而要每个引擎自己定义映射，是多引擎分歧的源头。

local Bit = require("framework.lib_bit")

local MapRender = {}

-- ---------------------------------------------------------------------------
-- 依赖
-- ---------------------------------------------------------------------------

--- 取引擎 API（每次动态查，避免测试 stub 后拿到旧引用）
local function api()
    return rawget(_G, "EngineAPI")
end

--- 限制 x 的范围（与 `script/jyconst.lua:limitX` 逐字一致）
-- 复制而非引用：framework 不能调 script 全局（gate STEP F 的硬约束）。
local function limitX(x, minv, maxv)
    if x < minv then return minv end
    if x > maxv then return maxv end
    return x
end

--- 与 `lib_love.lua` 的 `BuildingType` 逐字一致
local function newBuilding()
    return { x = 0, y = 0, num = 0 }
end

-- ---------------------------------------------------------------------------
-- 建筑深度排序（原 lib.BuildingSort，83 行，零引擎调用）
-- ---------------------------------------------------------------------------

-- 排序结果：附近建筑 + 深度顺序。**逐条对应**原版 `buildList`。
-- 容量 2000 与原版一致（`lib_love.lua` 初始化了 2000 个）。
local MAX_BUILDINGS = 2000
local buildList = {}
local buildNumber = 0
for i = 1, MAX_BUILDINGS do
    buildList[i] = newBuilding()
end

--- 建筑深度排序（**逐字搬移** `lib.BuildingSort`）
--
-- 做什么：扫描主角周围的地图，把建筑按深度顺序排进 `buildList`。
-- 主角和船会被**临时写进建筑层**参与同一份排序（这是原版行为，
-- 拆出来单独绘制会导致「走到大山背后整块露出来」，见 `2c8a644` 的回归）。
--
-- @param x, y number 主角地图坐标
-- @param mypic number 主角贴图编号
function MapRender.buildingSort(x, y, mypic)
    local EngineAPI = api()
    if not EngineAPI or not EngineAPI.map then return end

    local CONFIG = rawget(_G, "CONFIG") or {}
    local CC = rawget(_G, "CC") or {}
    local rangex=math.floor(math.floor(CONFIG.Width/(2*CONFIG.XScale))/2)+1+CONFIG.MMapAddX
    local rangey=math.floor(math.floor(CONFIG.Height/(2*CONFIG.YScale))/2)+1

    local range=rangex+rangey+CONFIG.MMapAddY

    local bak=EngineAPI.map.getTile(x,y,2)
    local bakx=EngineAPI.map.getTile(x,y,3)
    local baky=EngineAPI.map.getTile(x,y,4)

    local xmin=limitX(x-range,1,CC.MWidth-1)
    local xmax=limitX(x+range,1,CC.MWidth-1)
    local ymin=limitX(y-range,1,CC.MHeight-1)
    local ymax=limitX(y+range,1,CC.MHeight-1)

    local tmpBuild=nil

    EngineAPI.map.setTile(x,y,2, Bit.band(mypic * 2, 0xFFFF))
    EngineAPI.map.setTile(x,y,3,x)
    EngineAPI.map.setTile(x,y,4,y)

    local p = 0
    local seenbefore = false
    for i=xmin,xmax do
        local dy = ymin
        for j=ymin,ymax do
            local ij3 = EngineAPI.map.getTile(i,j,3)
            local ij4 = EngineAPI.map.getTile(i,j,4)
            if ij3~=0 and ij4~=0 then
                seenbefore = false
                for k=0,p-1 do
                    local idxk = k+1 -- lua starts with 1
                    --Debug("BuildingSort: i=%d, j=%d, k=%d", i,j,k)
                    if buildList[idxk].x == ij3 and buildList[idxk].y == ij4 then
                        seenbefore = true
                        if k==p-1 then break end

                        for m=j-1,dy,-1 do
                            local im3=EngineAPI.map.getTile(i,m,3)
                            local im4=EngineAPI.map.getTile(i,m,4)
                            if im3~=0 and im4~=0 then
                                if im3~=ij3 or im4~=ij4 then
                                    if im3~=buildList[idxk].x or im4~=buildList[idxk].y then
                                        -- 与原版 mainmap.c:BuildingSort 逐字一致：
                                        --     tmpBuild = Build[p-1];
                                        --     memmove(&Build[k+1], &Build[k], (p-k-1)*sizeof(BuildingType));
                                        --     Build[k] = tmpBuild;
                                        -- 即把 buildList[idxk..p] 这一段整体右旋一位，数组长度不变。
                                        -- 早期移植误写成 table.insert(buildList, idxk+1, tmp)，造成
                                        --   ① 插入点后移一位 → 建筑深度顺序与原版不一致（遮挡错位）
                                        --   ② buildList 被无限拉长（每次排序增长，长跑内存只增不减）
                                        tmpBuild = buildList[p] -- C: Build[p-1]，最后一个有效元素
                                        for t=p, idxk+1, -1 do
                                            buildList[t] = buildList[t-1]
                                        end
                                        buildList[idxk] = tmpBuild
                                    end
                                end
                            end
                        end
                        dy=j+1
                        break
                    end
                end
                if not seenbefore then
                    local idxp = p+1
                    buildList[idxp] = newBuilding()
                    buildList[idxp].x =ij3
                    buildList[idxp].y =ij4
                    buildList[idxp].num =EngineAPI.map.getTile(buildList[idxp].x,buildList[idxp].y,2)
                    p=p+1
                end
            end
        end
    end

    buildNumber=p
    --Debug("BuildingSort: x=%d,y=%d, buildNumber=%d", x, y, buildNumber)

    EngineAPI.map.setTile(x,y,2,bak)
    EngineAPI.map.setTile(x,y,3,bakx)
    EngineAPI.map.setTile(x,y,4,baky)  
end

--- 当前排序出的建筑数量（供 drawMain 遍历）
function MapRender.buildingCount()
    return buildNumber
end

--- 第 i 个建筑条目（1-based）
-- @return table|nil { x=, y=, num= }
function MapRender.buildingAt(i)
    local idx = i + 1
    if idx < 1 or idx > buildNumber then return nil end
    return buildList[idx]
end

--- 重置排序状态（测试用）
function MapRender.reset()
    buildNumber = 0
end

return MapRender
