# src/data 目录文件说明

本文档记录 `src/data` 目录下各数据文件的用途和格式。

## 文件类型总览

| 扩展名 | 数量 | 用途 |
|--------|------|------|
| `.idx` | 111  | 索引文件，存储图片偏移量 |
| `.grp` | 112  | 图片组文件，存储实际图片数据 |
| `.002` | 5    | 主地图数据文件 |
| `.sta` | 1    | 战斗配置数据 |
| `.col` | 1    | 调色板文件 |

---

## 一、图片文件 (.idx/.grp)

### 格式说明

**索引文件 (.idx)**
- 存储 4 字节小端无符号整数
- 每个整数表示对应图片在 .grp 文件中的起始偏移量
- 图片 `i` 的数据范围为 `[idx[i], idx[i+1])`

**图片组文件 (.grp)**
- 包含多个图片，支持两种格式：
  1. **RLE 压缩格式**：前 8 字节为 `width(2) + height(2) + xoff(2) + yoff(2)`，随后是逐行的 RLE 编码数据
  2. **PNG 格式**：直接嵌入 PNG 文件数据

**RLE 格式详解** (每行)：
```
[count:1字节]  -- 本行数据字节数
  [trans_size:1字节][solid_num:1字节][palette_index:1字节]*solid_num ... 循环
```

### 文件列表

| 文件对 | 用途 | 代码引用 |
|--------|------|----------|
| `mmap.idx` + `mmap.grp` | 主地图贴图 | `CC.MMAPPicFile` |
| `smap.idx` + `smap.grp` | 场景地图贴图 | `CC.SMAPPicFile` |
| `wmap.idx` + `wmap.grp` | 战斗地图贴图 | `CC.WMAPPicFile` |
| `eft.idx` + `eft.grp` | 武功效果贴图 | `CC.EffectFile` |
| `hdgrp.idx` + `hdgrp.grp` | 人物头像贴图 | `CC.HeadPicFile` |
| `thing.idx` + `thing.grp` | 物品贴图 | `CC.ThingPicFile` |
| `warfld.idx` + `warfld.grp` | 战斗场景贴图 | `CC.WarMapFile` |

### R 存档文件

| 文件对 | 用途 | 代码引用 |
|--------|------|----------|
| `ranger.idx` + `ranger.grp` | 新游戏初始数据 | `CC.R_IDXFilename[0]`, `CC.R_GRPFilename[0]` |
| `r1.idx` + `r1.grp` | 存档 1 | `CC.R_IDXFilename[1]` |
| `r2.idx` + `r2.grp` | 存档 2 | `CC.R_IDXFilename[2]` |
| `r3.idx` + `r3.grp` | 存档 3 | `CC.R_IDXFilename[3]` |

**R 文件结构** (grp 内部)：
```
[基本数据段]     -- 角色位置、队伍、物品等
[人物数据段]     -- 所有人物属性
[物品数据段]     -- 所有物品定义
[场景数据段]     -- 所有场景信息
[武功数据段]     -- 所有武功定义
[商店数据段]     -- 所有商店配置
```

idx 文件存储各段的起始偏移量（6 个 4 字节整数）。

### S 场景文件

| 文件 | 用途 | 代码引用 |
|------|------|----------|
| `allsin.grp` | 所有场景数据合并 | `CC.S_Filename[0]` |
| `s1.grp` | 场景数据分卷 1 | `CC.S_Filename[1]` |
| `s2.grp` | 场景数据分卷 2 | `CC.S_Filename[2]` |
| `s3.grp` | 场景数据分卷 3 | `CC.S_Filename[3]` |
| `allsinbk.grp` | 场景数据备份 | `CC.TempS_Filename` |

> 注：`allsin.idx`、`s1.idx`、`s2.idx`、`s3.idx` 存在于目录中，但代码未引用，可能是转换工具遗留或备用。

### D 防御数据文件

| 文件 | 用途 | 代码引用 |
|------|------|----------|
| `alldef.grp` | 所有场景防御数据 | `CC.D_Filename[0]` |
| `d1.grp` | 防御数据分卷 1 | `CC.D_Filename[1]` |
| `d2.grp` | 防御数据分卷 2 | `CC.D_Filename[2]` |
| `d3.grp` | 防御数据分卷 3 | `CC.D_Filename[3]` |

> 注：`alldef.idx`、`d1.idx`、`d2.idx`、`d3.idx` 存在于目录中，但代码未引用，可能是转换工具遗留或备用。

> 注：`alldef.idx`、`d1.idx`、`d2.idx`、`d3.idx` 存在于目录中，但代码未引用，可能是转换工具遗留或备用。

### 战斗人物贴图 (fight000 - fight109)

**共 92 对文件**，按人物头像代号编号。

| 文件模式 | 用途 | 代码引用 |
|----------|------|----------|
| `fight%03d.idx` + `fight%03d.grp` | 各人物战斗动作贴图 | `CC.FightPicFile` |

部分编号文件不存在（如 fight030, fight039-042 等），对应游戏中不存在的人物。

---

## 二、主地图数据文件 (.002)

### 文件列表

| 文件 | 大小 | 用途 | 代码引用 |
|------|------|------|----------|
| `earth.002` | 450KB | 地面层 | `CC.MMapFile[1]` |
| `surface.002` | 450KB | 地表层 | `CC.MMapFile[2]` |
| `building.002` | 450KB | 建筑层 | `CC.MMapFile[3]` |
| `buildx.002` | 450KB | 建筑 X 坐标辅助 | `CC.MMapFile[4]` |
| `buildy.002` | 450KB | 建筑 Y 坐标辅助 | `CC.MMapFile[5]` |

### 格式说明

- 主地图尺寸：480 x 480（由 `CC.MWidth` 和 `CC.MHeight` 定义）
- 每个坐标点存储贴图编号
- 文件大小一致，每个坐标 2 字节

**层叠关系**：earth(地面) → surface(地表) → building(建筑)

---

## 三、战斗配置文件 (.sta)

### 文件信息

| 文件 | 大小 | 用途 | 代码引用 |
|------|------|------|----------|
| `war.sta` | 26KB | 所有战斗配置数据 | `CC.WarFile` |

### 格式说明

每条战斗记录 186 字节（`CC.WarDataSize`），结构如下：

| 字段 | 偏移 | 类型 | 说明 |
|------|------|------|------|
| 代号 | 0 | int16 | 战斗 ID |
| 名称 | 2 | string[10] | 战斗名称 |
| 地图 | 12 | int16 | 战斗地图 ID |
| 经验 | 14 | int16 | 胜利经验值 |
| 音乐 | 16 | int16 | 背景音乐 |
| 手动选择参战人 1-6 | 18-28 | int16[6] | 手动战斗可选人物 |
| 自动选择参战人 1-6 | 30-40 | int16[6] | 自动战斗可选人物 |
| 我方X 1-6 | 42-52 | int16[6] | 我方起始 X 坐标 |
| 我方Y 1-6 | 54-64 | int16[6] | 我方起始 Y 坐标 |
| 敌人 1-20 | 66-104 | int16[20] | 敌人人物 ID |
| 敌方X 1-20 | 106-144 | int16[20] | 敌方 X 坐标 |
| 敌方Y 1-20 | 146-184 | int16[20] | 敌方 Y 坐标 |

---

## 四、调色板文件 (.col)

### 文件信息

| 文件 | 大小 | 用途 | 代码引用 |
|------|------|------|----------|
| `mmap.col` | 768 字节 | 主地图调色板 | `CC.PaletteFile` |

### 格式说明

- 256 色调色板
- 每色 3 字节（RGB）
- 用于 RLE 格式图片的颜色索引

---

## 五、代码中的加载函数

### 图片加载

```lua
-- 加载图片文件对
lib.PicLoadFile(idxfilename, grpfilename, fileid)

-- 获取图片
lib.PicGetXY(fileid, picid)     -- 获取尺寸
lib.PicLoadCache(fileid, picid, x, y, flag, value)  -- 显示图片
```

### 地图加载

```lua
-- 主地图
lib.LoadMMap(CC.MMapFile[1], CC.MMapFile[2], CC.MMapFile[3],
             CC.MMapFile[4], CC.MMapFile[5], CC.MWidth, CC.MHeight,
             JY.Base["人X"], JY.Base["人Y"])

-- 战斗地图
lib.LoadWarMap(CC.WarMapFile[1], CC.WarMapFile[2], mapid, 6,
               CC.WarWidth, CC.WarHeight)

-- 场景地图
lib.LoadSMap(CC.S_Filename[id], CC.TempS_Filename, JY.SceneNum,
             CC.SWidth, CC.SHeight, CC.D_Filename[id], CC.DNum, 11)
```

### 存档加载

```lua
LoadRecord(id)  -- id: 0=新游戏, 1/2/3=存档
SaveRecord(id)
```

---

## 六、数据结构定义位置

所有数据结构定义在 `src/script/jyconst.lua`：

| 常量名 | 说明 |
|--------|------|
| `CC.Base_S` | 基本数据结构（位置、队伍、物品） |
| `CC.Person_S` | 人物数据结构 |
| `CC.Thing_S` | 物品数据结构 |
| `CC.Scene_S` | 场景数据结构 |
| `CC.Wugong_S` | 武功数据结构 |
| `CC.WarData_S` | 战斗配置数据结构 |

---

## 七、文件使用状态

### 已使用文件

| 类别 | 文件 |
|------|------|
| 地图贴图 | mmap, smap, wmap, thing, warfld |
| 特效贴图 | eft |
| 人物贴图 | hdgrp, fight000-109 |
| 存档数据 | ranger, r1, r2, r3 |
| 场景数据 | allsin, s1, s2, s3, allsinbk |
| 防御数据 | alldef, d1, d2, d3 |
| 地图数据 | earth, surface, building, buildx, buildy (002) |
| 配置数据 | war.sta, mmap.col |

### 缺失的 fight 文件

部分编号的 fight 文件不存在（对应不存在的人物），这是正常现象：
- fight030, fight039-042, fight052, fight066, fight072-075, fight089, fight103-108

实际存在的 fight 文件编号：000-029, 031-038, 043-051, 053-065, 067-071, 076-088, 090-102, 109（共 92 对）

实际存在的 fight 文件编号：000-029, 031-038, 043-051, 053-065, 067-071, 076-088, 090-102, 109（共 92 对）

---

## 八、相关源码文件

| 文件 | 说明 |
|------|------|
| `src/script/jyconst.lua` | 数据文件名和结构定义 |
| `src/script/jymain.lua` | 加载/保存函数实现 |
| `src/lib_love.lua` | 图片加载和 RLE 解码 |
| `src/lib_Byte.lua` | 二进制数据读写工具 |
