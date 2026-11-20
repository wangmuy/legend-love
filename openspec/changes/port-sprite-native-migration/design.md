# Design: port-sprite-native-migration

> 父 slice: `engine-portability`

## Context

`framework/` 已完全走 `SpriteAtlas`（引擎只见 handle）。`script/` 仍有 27 处
`lib.Pic*` 走旧系统（读引擎的 `picFileCache`）。两套系统不互通，导致：

1. `war_async` 必须同时加载两套（`ebf81af` 的临时补丁）
2. 新引擎必须再造一份 `lib_love.lua`（否则 script 层跑不起来）
3. gate STEP D 的 `engine-love2d` 豁免永远摘不掉
4. `lib_love.LoadPic`（119 行解码）删不掉

---

## ADR-SNM-001：先修 SpriteAtlas 的 PNG 路径，再迁移

### Context

实测发现迁移的两个前置阻塞：

```
hdgrp.grp 的 PNG 帧:  slot 59 / 111        （parseIdx 扫描）
r1.grp 里人物 59 的头像代号 = 59
  → picid = 59*2 = 118 → slot = 118/2 = 59  ← 命中 PNG
```

而 `SpriteAtlas` 对 PNG 帧的处理有两处缺陷：

| 位置 | 缺陷 | 后果 |
|------|------|------|
| `getMeta:238-241` | PNG 帧直接 `return nil` | 头像尺寸拿到 nil |
| `getHandle:220-224` | `atlas.meta[slot]` 存 `d.w or 0`，而 PNG 的 `d.w` 是 nil | 存 0×0 |

### Decision

**两处都修，且必须先修再迁**：

1. `getHandle` 的 PNG 分支：handle 创建后从 `EngineAPI.sprite.getMeta(handle)`
   回读真实 `w/h`，写进 `atlas.meta[slot]`
2. `getMeta` 的 PNG 分支：兜底调 `getHandle`（它内部会缓存 meta），再取缓存

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| A. 迁移时对 PNG 帧特殊处理（跳过尺寸） | 治标：`WarShowHead` 的居中计算必需 w/h |
| B. 让 framework 自己解 PNG（加 zlib） | framework 应零引擎依赖；且 LÖVE 的 PNG 解码已可用 |
| C. 只在 `getMeta` 兜底，不改 `getHandle` | `getHandle` 存的 0×0 会污染缓存，之后所有读 meta 都错 |
| **D. 两处都修（采纳）** | 一处负责"取到真值"，一处负责"存对值" |

**为什么 `getMeta` 的"不解码纹理"语义要让步**：
原注释说「PNG 必须引擎解码才知道尺寸」——这是对的，但**正确性优先于
这个性能优化**。而且真实数据里 PNG 帧只有 2 个（115 个 slot 中），
兜底解码的代价可忽略。

### Consequences

- `getMeta` 对 PNG 帧不再是"纯元数据查询"，会触发一次 handle 创建 + 缓存
- 对不解码 PNG 的引擎（MUD/Web 返回 `{w=0,h=0}`），兜底后返回 `w=0`
  → **必须容忍**，不能当错误（否则 MUD/Web 的测试全崩）

---

## ADR-SNM-002：`PicInit` 全部删除（不是迁移）

### Context

7 处 `lib.PicInit` 里：
- **6 处无参**：`function PicInit(PalletteFilename) if PalletteFilename == nil then return end` → **no-op**
- 1 处带参（`jymain.lua:173`）：在死代码 `JY_Main_sub` 里，且
  `jymain_adapter.init` 已调 `EngineAPI.sprite.initSprites(CC.PaletteFile)`

### Decision

7 处**全部删除**，不迁移到任何新 API。

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| 迁移到 `EngineAPI.sprite.initSprites` | 6 处无参调用变成"传 nil 的 initSprites"= 还是 no-op，只是换了个没人用的函数名 |
| 保留 1 处带参的 | 它在死代码里，且已被 `jymain_adapter.init` 覆盖 |

### Consequences

`script/` 少 7 处调用；调色板加载的唯一入口变成 `jymain_adapter.init`
→ `EngineAPI.sprite.initSprites(CC.PaletteFile)`。**这是单点，更清晰。**

---

## ADR-SNM-003：`PicLoadFile` → `SpriteAtlas.loadArchive`（含调色板）

### Context

`lib.PicLoadFile(idxFile, grpFile, archiveId)` 有两个职责：
1. 把档案注册进引擎的 `picFileCache`（旧系统）
2. 加载全局调色板（隐含在 `PicInit` 之后的首次加载里）

`SpriteAtlas.loadArchive(idxFile, grpFile, archiveId, opts)` 的行为：
- 读 `.idx` + `.grp` 的**字节**（`EngineAPI.file.read`）
- 用 `opts.paletteFile` 读调色板
- **不写 `picFileCache`**（这是 ADR-PORT-013 的设计）

### Decision

14 处 `lib.PicLoadFile` → `SpriteAtlas.loadArchive(a, b, id, {paletteFile = CC.PaletteFile, usage = ...})`。

`usage = "avatar"` 只给头像档案（`CC.HeadPicFile` → archive 1），
因为它决定锚点策略（头像用中心，其它用脚底）。

### Consequences

- `script/` 少 14 处 `lib.*`
- `picFileCache` 不再被写 → `lib.PicGetXY/PicLoadCache` 若还有调用会拿不到数据
  → **所以必须同时迁那 6 处**（ADR-SNM-004）
- `EngineAPI.sprite.loadArchive` 契约仍有消费者（`SpriteAtlas` 不调它，
  但 `lib.PicLoadFile` 的兼容路径还在）→ **暂不删契约**

---

## ADR-SNM-004：`PicGetXY`/`PicLoadCache` → `getMeta`/`draw`（解构变更）

### Context

```lua
local headw, headh = lib.PicGetXY(1, p["头像代号"]*2)          -- 返回 2 个值
local w1,h1,x1_off,y1_off = lib.PicGetXY(id1, pic1*2)         -- 返回 4 个值
lib.PicLoadCache(1, p["头像代号"]*2, x1+headx, y1+heady, 1)    -- 5 个参数
```

新 API：
```lua
local meta = SpriteAtlas.getMeta(atlasId, frameId)   -- 返回 table
-- meta.w / meta.h / meta.xoff / meta.yoff
SpriteAtlas.draw(atlasId, frameId, x, y, flags, alpha)
```

### Decision

调用点逐个改**解构方式**（`getMeta` 返回 table，不是多返回值）。
`flags` 语义完全一致（0x1 忽略锚点 / 0x2 alpha / 0x4 黑 / 0x8 白），无需转换。

### Consequences

- 6 处调用点的代码形态变了（不是机械替换）
- `Cal_PicClip` 用 `PicGetXY` 拿 4 个值算裁剪矩形 → 要改成读 `meta.w/h/xoff/yoff`
- **风险点**：`Cal_PicClip` 是 `battle_flow` 的动画裁剪计算，改错会导致
  武功动画错位 → 需要实机截图验证

---

## Negative Constraints

```
✗ 不得在迁移中改变 flags 的位域语义
✗ 不得为了省事把 getMeta 改成返回多值（会与既有 table 语义冲突）
✗ 不得删除 EngineAPI.sprite.loadArchive 契约（它仍有消费者）
✗ 不得在 getMeta 的 PNG 兜底里把 w=0 当错误（MUD/Web 就是 0）
✗ 不得只迁移活代码、留下死代码路径（gate 豁免会摘不掉）
✗ 不得跳过实物验证（Cal_PicClip 的裁剪计算改错很难察觉）
```

## Review Checklist

```
[ ] SpriteAtlas 的 PNG 路径修好（getMeta 返回真实尺寸，getHandle 存真实尺寸）
[ ] hdgrp slot 59（PNG 帧）的 getMeta 返回 w>0
[ ] script/ 的 lib.Pic* = 0（grep 实证）
[ ] 7 处 PicInit 全部删除
[ ] war_async 的双轨补丁移除（只剩 SpriteAtlas）
[ ] gate STEP D 无 engine-love2d 豁免
[ ] 四版本 Lua 全量测试零失败
[ ] 实机截图：战斗头像 / 物品图标 / 武功动画裁剪 全部正常
[ ] 人物 59 的头像专项验证（这是 PNG 帧的命中案例）
```
