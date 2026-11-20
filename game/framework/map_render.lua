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
    -- **开头就清零**：原实现靠 `DrawMMap` 里的 `buildNumber=0` 兜住早退路径，
    -- 但那样「谁调 buildingSort 谁负责清零」是隐式约定。放这里更稳 ——
    -- 任何早退（EngineAPI 缺失 / 地图未加载）都留下 0 而不是上一次的旧值。
    buildNumber = 0

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

-- ---------------------------------------------------------------------------
-- 贴图绘制
-- ---------------------------------------------------------------------------

--- 绘制一格地图贴图（含锚点偏移）
--
-- @param picnum number 容器帧编号（既有代码里的 picid）
-- @param x, y number 屏幕坐标
--
-- **为什么用 `SpriteAtlas.draw` 而不是 `EngineAPI.sprite.draw`**：
--
--   `EngineAPI.sprite.draw` 的实现是 `lib.PicLoadCache` —— **读 picFileCache**，
--   换引擎时仍要重写那套 RLE 解码（这是 C 要消除的东西）。
--
--   `SpriteAtlas.draw` 走 `EngineAPI.sprite.drawHandle(handle, ...)` ——
--   贴图已由 framework 解好并缓存在 handle 里，引擎只负责把 handle 画出来。
--
-- **编号约定实测一致**：
--   `PicLoadCache(fileid, picid)` → 档案 `picFileCache[fileid+1]`，帧 `floor(picid/2)+1`
--   `SpriteAtlas(atlasId, frameId)` → 档案 `atlases[atlasId]`，帧 `floor(frameId/2)+1`
--   所以 `JY_LoadPic(0, picnum, ...)` 等价于 `SpriteAtlas.draw(0, picnum, ...)`
--
-- **flags 语义差异**（唯一风险点，实测已核对）：
--   `PicLoadCache`：black(0x4) / white(0x8) / alpha(0x2) **三者独立**
--   `drawHandle`  ：black/white/alpha **互斥**（0x4 优先，此时 alpha 被忽略）
--   地图绘制只用到 flag=0 和一处 `4+2`（见 drawBattle）：
--   后者黑化且 alpha=255 → 旧 a=255/255=1，新 alpha 忽略（默认 1）→ **像素相同**
function drawTile(picnum, x, y, flags, alpha)
    local EngineAPI = api()
    if not EngineAPI or not EngineAPI.sprite then return false end
    local SA = require("framework.sprite_atlas")
    return SA.draw(0, picnum, x, y, flags or 0, alpha)
end

-- ---------------------------------------------------------------------------
-- 主地图绘制（原 lib.DrawMMap，79 行）
-- ---------------------------------------------------------------------------

--- 绘制主地图（**逐字搬移** `lib.DrawMMap`）
--
-- @param x, y number 主角地图坐标
-- @param mypic number 主角贴图编号
--
-- **工程要点**（都是从原实现注释里保留下来的，改动会引入真实回归）：
--
--  ① 建筑层：单次按 `buildingSort` 的顺序绘制。主角/船由 buildingSort
--     临时写进建筑层，和其它建筑一起参与同一份排序，所以绘制次序 = 深度次序
--     （对应原版 mainmap.c:JY_DrawMMap 唯一的一层循环）。
--
--     **禁止**把主角拆出来「最后单独绘制」：那样任何建筑都遮不住主角，
--     走到大山背后会整块露出来（commit 2c8a644 引入过的回归）。
--
--     **禁止**给主角加额外 y 偏移：屏幕位置完全由贴图头的 xoff/yoff 决定，
--     贴图头里已带正确的 yoff（主角帧 15x39，xoff=5 yoff=44），再叠加就错位。
--
--  ② 云层在建筑层之后、解除裁剪之前绘制（天空层，永远在地面/建筑之上）。
function MapRender.drawMain(x, y, mypic)
    local EngineAPI = api()
    if not EngineAPI or not EngineAPI.map or not EngineAPI.render then return end

    local CONFIG = rawget(_G, "CONFIG") or {}
    local CC = rawget(_G, "CC") or {}

    -- 原实现用 love.graphics.getScissor() 取两次（一次存快照、一次算循环范围）。
    -- framework 只需一次 —— 契约返回的就是当前 clip。
    local oldClip = EngineAPI.render.getClip()

    local rect = oldClip or { x = 0, y = 0, w = CONFIG.Width, h = CONFIG.Height }
    if rect.w == nil then rect.w = CONFIG.Width end
    if rect.h == nil then rect.h = CONFIG.Height end

    -- 根据 clip 确定循环参数。提高绘制速度
    local istart = math.floor((rect.x - math.floor(CONFIG.Width / 2)) / (2 * CONFIG.XScale)) - 1 - CONFIG.MMapAddX
    local iend = math.floor((rect.x + rect.w - math.floor(CONFIG.Width / 2)) / (2 * CONFIG.XScale)) + 1 + CONFIG.MMapAddX

    local jstart = math.floor((rect.y - math.floor(CONFIG.Height / 2)) / (2 * CONFIG.YScale)) - 1
    local jend = math.floor((rect.y + rect.h - math.floor(CONFIG.Height / 2)) / (2 * CONFIG.YScale)) + 1

    -- 建筑排序
    MapRender.buildingSort(x, y, mypic)
    EngineAPI.render.fillRect(0, 0, 0, 0, 0)

    for j = 0, 2 * jend - 2 * jstart + CONFIG.MMapAddY do
        for i = istart, iend do
            local i1 = i + math.floor(j / 2) + jstart
            local j1 = -i + math.floor(j / 2) + j % 2 + jstart

            local x1 = CONFIG.XScale * (i1 - j1) + math.floor(CONFIG.Width / 2)
            local y1 = CONFIG.YScale * (i1 + j1) + math.floor(CONFIG.Height / 2)
            if (x + i1) >= 0 and (x + i1) < CC.MWidth and (y + j1) >= 0 and (y + j1) < CC.MHeight then
                local picnum = EngineAPI.map.getTile(x + i1, y + j1, 0)
                if picnum > 0 then
                    drawTile(picnum, x1, y1)
                end
                picnum = EngineAPI.map.getTile(x + i1, y + j1, 1)
                if picnum > 0 then
                    drawTile(picnum, x1, y1)
                end
            end
        end
    end

    -- 建筑层（见上方 ① 的说明）
    for i = 0, buildNumber - 1 do
        local idxi = i + 1
        local i1 = buildList[idxi].x - x
        local j1 = buildList[idxi].y - y
        local x1 = CONFIG.XScale * (i1 - j1) + math.floor(CONFIG.Width / 2)
        local y1 = CONFIG.YScale * (i1 + j1) + math.floor(CONFIG.Height / 2)
        local picnum = buildList[idxi].num
        if picnum > 0 then
            drawTile(picnum, x1, y1)
        end
    end

    -- 云层（见上方 ② 的说明）
    if EngineAPI.map.drawClouds then
        EngineAPI.map.drawClouds(x, y)
    end

    -- 恢复裁剪（原实现就是恢复快照；setClip(0,0,0,0) 表示"清除裁剪"）
    if oldClip then
        EngineAPI.render.setClip(oldClip.x, oldClip.y,
                                 oldClip.x + oldClip.w, oldClip.y + oldClip.h)
    else
        EngineAPI.render.setClip(0, 0, 0, 0)
    end
end

-- ---------------------------------------------------------------------------
-- 场景地图绘制（原 lib.DrawSMap，79 行）
-- ---------------------------------------------------------------------------

--- 绘制场景地图（**逐字搬移** `lib.DrawSMap`）
--
-- @param sceneid number 场景编号
-- @param x, y number 场景坐标
-- @param xoff, yoff number 视口偏移
-- @param mypic number 主角贴图编号
--
-- 原实现是**两趟循环**（对应原版 kys_draw.pas 的两层）：
--   ① 只画地面层（GetS level 0）
--   ② 画建筑 / 空中 / 事件贴图 / 主角（level 1..5）
--
-- 分两趟的原因：地面必须先全部铺完，否则相邻格子的建筑会被后画的地面盖住。
-- **不要合并成一趟**（顺序是视觉正确性的一部分）。
function MapRender.drawScene(sceneid, x, y, xoff, yoff, mypic)
    local EngineAPI = api()
    if not EngineAPI or not EngineAPI.map or not EngineAPI.render then return end

    local CONFIG = rawget(_G, "CONFIG") or {}
    local CC = rawget(_G, "CC") or {}

    local sceneSize = EngineAPI.map.getSceneSize and EngineAPI.map.getSceneSize()
                      or { w = CC.SWidth or 64, h = CC.SHeight or 64 }
    local SXMax, SYMax = sceneSize.w or 64, sceneSize.h or 64

    local oldClip = EngineAPI.render.getClip()
    local rect = oldClip or { x = 0, y = 0, w = CONFIG.Width, h = CONFIG.Height }
    if rect.w == nil then rect.w = CONFIG.Width end
    if rect.h == nil then rect.h = CONFIG.Height end

    -- 根据 clip 确定循环参数。提高绘制速度
    local istart = math.floor((rect.x - math.floor(CONFIG.Width / 2)) / (2 * CONFIG.XScale)) - 1 - CONFIG.SMapAddX
    local iend = math.floor((rect.x + rect.w - math.floor(CONFIG.Width / 2)) / (2 * CONFIG.XScale)) + 1 + CONFIG.SMapAddX

    local jstart = math.floor((rect.y - math.floor(CONFIG.Height / 2)) / (2 * CONFIG.YScale)) - 1
    local jend = math.floor((rect.y + rect.h - math.floor(CONFIG.Height / 2)) / (2 * CONFIG.YScale)) + 1

    EngineAPI.render.fillRect(0, 0, 0, 0, 0)

    -- ① 地面层
    for j = 0, 2 * jend - 2 * jstart + CONFIG.SMapAddY do
        for i = istart, iend do
            local i1 = i + math.floor(j / 2) + jstart
            local j1 = -i + math.floor(j / 2) + j % 2 + jstart

            local x1 = CONFIG.XScale * (i1 - j1) + math.floor(CONFIG.Width / 2)
            local y1 = CONFIG.YScale * (i1 + j1) + math.floor(CONFIG.Height / 2)

            local xx = x + i1 + xoff
            local yy = y + j1 + yoff

            if (xx >= 0) and (xx < SXMax) and (yy >= 0) and (yy < SYMax) then
                local d0 = EngineAPI.map.getSceneTile(sceneid, xx, yy, 0)
                if d0 > 0 then
                    drawTile(d0, x1, y1)
                end
            end
        end
    end

    -- ② 建筑 / 空中 / 事件 / 主角
    for j = 0, 2 * jend - 2 * jstart + CONFIG.SMapAddY do
        for i = istart, iend do
            local i1 = i + math.floor(j / 2) + jstart
            local j1 = -i + math.floor(j / 2) + j % 2 + jstart

            local x1 = CONFIG.XScale * (i1 - j1) + math.floor(CONFIG.Width / 2)
            local y1 = CONFIG.YScale * (i1 + j1) + math.floor(CONFIG.Height / 2)

            local xx = x + i1 + xoff
            local yy = y + j1 + yoff

            if (xx >= 0) and (xx < SXMax) and (yy >= 0) and (yy < SYMax) then
                local d1 = EngineAPI.map.getSceneTile(sceneid, xx, yy, 1)
                local d2 = EngineAPI.map.getSceneTile(sceneid, xx, yy, 2)
                local d3 = EngineAPI.map.getSceneTile(sceneid, xx, yy, 3)
                local d4 = EngineAPI.map.getSceneTile(sceneid, xx, yy, 4)
                local d5 = EngineAPI.map.getSceneTile(sceneid, xx, yy, 5)

                if d1 > 0 then
                    drawTile(d1, x1, y1 - d4)          -- 建筑
                end
                if d2 > 0 then
                    drawTile(d2, x1, y1 - d5)          -- 空中
                end
                if d3 >= 0 then                        -- 事件
                    local picnum = EngineAPI.map.getSceneEventData(sceneid, d3, 7)
                    if picnum > 0 then
                        drawTile(picnum, x1, y1 - d4)
                    end
                end

                if (i1 == -xoff) and (j1 == -yoff) then     -- 主角
                    drawTile(mypic * 2, x1, y1 - d4)
                end
            end
        end
    end

    if oldClip then
        EngineAPI.render.setClip(oldClip.x, oldClip.y,
                                 oldClip.x + oldClip.w, oldClip.y + oldClip.h)
    else
        EngineAPI.render.setClip(0, 0, 0, 0)
    end
end

--- 重置排序状态（测试用）
function MapRender.reset()
    buildNumber = 0
end

return MapRender
