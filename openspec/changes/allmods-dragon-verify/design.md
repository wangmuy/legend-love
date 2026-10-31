# Design: allmods-dragon-verify

## Negative Constraints

- **不得**以「记录数正确」代替「内容正确」——必须给出边界值/文本/事件等直接证据。
- **不得**把 `not_in_product` 解读为「物理上不在产物里」（本 MOD 已证伪 4 例）。
- **不得**把 `name.grp`/`name.idx` 判为「构建冗余缺陷」（构建对 `resource/` 一律展平复制，
  这是既有契约，非缺陷）。
- **不得**把 `war1.sta` 的「`DEAD_FILE`」与「`diff.md` MOD 独有」判为矛盾。
- **不得**在本 change 修复 `not_in_product` 语义（改工具契约 = 独立 change）。
- **不得**改引擎、`jyconst.lua` 常量定义、`reference/allmods/**`。

---

## ADR-001：`diff.md` 逐项相等（非仅计数相等）

### Context

activate 的 REQ-DRG-9 只对 fight 做了 set 相等校验。verify 要把**全部 254 项**
纳入 set 相等校验，并覆盖非 fight 16 项。

### Decision

用**双向 set 相等**判据，而非计数相等：

```
MOD 独有 set(diff.md)  ==  set(实测 product files) - set(实测 baseline files)
MOD 独有 set(diff.md)  ==  set(实测 source files)
```

### Alternatives

- **仅比计数**：254 == 254 可能掩盖「两项错位但总数相同」。**否决**。
- **仅比 fight**：activate 已做，对非 fight 16 项无覆盖。**否决**。

### Consequences

- ✅ 254 项全部逐项可比；实测 set 相等。
- ⚠ 非 fight 16 项中有 2 项（`ranger.str`、`name.*` 的产物副本）在
  `diff.md` 与审计中的**归类不同**，须显式对齐（见 ADR-004）。

---

## ADR-002：MOD 独有 254 = 238 fight + 16 非 fight 的结构分解

### Context

```
MOD 独有: 254
  fight#.grp  119
  fight#.idx  119
  cloud.grp    1    cloud.idx   1
  end.png      1    kdef.grp    1    kdef.idx    1
  kysmod.ini   1    name.grp    1    name.idx    1
  open.png     1    ranger.str  1    talk.grp    1
  talk.idx     1    talkutf8.txt 1   title.grp   1
  title.idx    1    war1.sta    1
```

16 项非 fight 必须逐项给用途。

### Decision

按「产物位置 + 引擎用途」二分：

| 项 | 源大小 | 产物大小 | 字节一致 | 引擎消费者（实测） | 审计类别 |
|----|-------:|--------:|:--------:|--------------------|----------|
| `cloud.grp` | 38120 | 38120 | ✅ | **无 `CC.*` 常量**；`grep -rn cloud script/ framework/ engine-love2d/` → **0 命中** | REQUIRED（`BY_KIND` 兜底） |
| `cloud.idx` | 36 | 36 | ✅ | 同上 | REQUIRED（`BY_KIND` 兜底） |
| `title.grp` | 10050 | 10050 | ✅ | **无 `CC.*` 常量**；`title.grp`/`title.idx` grep → **0 命中** | REQUIRED（`BY_KIND` 兜底） |
| `title.idx` | 36 | 36 | ✅ | 同上 | REQUIRED（`BY_KIND` 兜底） |
| `open.png` | 188358 | 188358 | ✅ | **0 命中**（引擎无 `open.png` 引用） | REQUIRED（`BY_KIND` 兜底） |
| `end.png` | 490590 | 490590 | ✅ | `jymain.lua:4273` `lib.LoadPicture(CONFIG.PicturePath .."end.png")` → 读 **`pic/end.png`**（**基线**，非 `data/end.png`） | REQUIRED（`BY_KIND` 兜底） |
| `kdef.grp` | 190110 | 190110 | ✅ | **运行时不读**；仅**构建期** `mod_build.lua:893` `readIndexedEntries("resource/kdef.grp")` 提取事件 → `script/oldevent/` | REQUIRED |
| `kdef.idx` | 4348 | 4348 | ✅ | 同上（构建期） | REQUIRED |
| `talk.grp` | 211697 | 211697 | ✅ | **运行时不读**；仅**构建期** `mod_build.lua:916` 提取 → `script/oldtalk.{grp,idx}`（`CC.TalkGrpFile = script/oldtalk.grp`） | REQUIRED |
| `talk.idx` | 16080 | 16080 | ✅ | 同上（构建期） | REQUIRED |
| `talkutf8.txt` | 311989 | 311989 | ✅ | 构建输入（覆盖编码探测） | BUILD_INPUT |
| `kysmod.ini` | 1729 | 1729 | ✅ | `framework/mod_ini.lua` 解析为 `CC.*`/`CONFIG.*` 覆盖（**实测生效**，见 ADR-003） | BUILD_INPUT |
| `ranger.str` | **不存在** | 35898 | — | `framework/mod_data.lua:517` `ModData.SideValue` 查旁路表（UTF-8 真值） | 构建**生成**（`mod_build.lua:1174`） |
| `name.grp` | 211697 | 211697 | ✅ | **0 引用**（`EV_LEGACY_NAME`：「引擎从不读取 name.grp」） | LEGACY |
| `name.idx` | 16080 | 16080 | ✅ | **0 引用** | LEGACY |
| `war1.sta` | 66030 | 66030 | ✅ | **0 引用**（`CC.WarFile` 只指 `war.sta`） | **DEAD_FILE** |

Σ = 16 ✅

### Consequences

- ✅ 15/16 字节逐字节一致（`ranger.str` 源不存在，是构建生成）。
- ✅ 1 项（`ranger.str`）是**构建生成**（`mod_build.lua:1174`）。
- ⚠ **4 项（`cloud.*`/`title.*`/`open.png`/`end.png`，共 6 文件）在 Lua 引擎中
  无运行时消费者**，仅靠 `BY_KIND`（`resource|.grp`/`.idx`/`.png` → `REQUIRED`）兜底归类。
  `end.png` 有一个引用但是**基线路径** `pic/end.png`，不指向 `data/end.png`。
  这解释了「为什么产物里有但没人读」—— 见 ADR-004b。
- ⚠ 2 项（`name.*`）是「引擎 0 引用但被复制」—— 见 ADR-004。
- ⚠ 1 项（`war1.sta`）是「源里有、产物有、引擎不读」—— 见 ADR-005。

---

## ADR-003：MOD 内容真实性 —— 四类直接证据

### Context

记录数正确（589/237/106/114）只是**结构**证据。前 10 个 slice 的教训：
结构对了内容也可能没加载。必须有**内容级**证据。

### Decision

四类直接证据：

| # | 类型 | 证据 |
|---|------|------|
| 1 | **Record 边界值** | 8 个边界记录（首/末 × 4 段）全部可读非空，且与基线不同 |
| 2 | **`kdef` 事件** | 产物 `script/oldevent/` = **1087** 个 `.lua`（= 构建报告 `events=1087`） |
| 3 | **`talk` 文本** | 产物 `oldtalk.idx` = **4020** 条目（= 构建报告 `talk=4020`），首尾可读 |
| 4 | **`kysmod.ini` 常量覆盖** | ≥10 个 `CC.*` 常量取到 MOD 值 |

实测：

| # | 结果 |
|---|------|
| 1 | `Person[0]=資`/`Person[588]=李卡多`；`Thing[0]=小還丹`/`Thing[236]=真武劍`；`Scene[0]=胡斐居`/`Scene[105]=西部農村`；`Wugong[0]=普通攻擊`/`Wugong[113]=閃電貂` |
| 2 | `ls mods/Dragon/script/oldevent \| wc -l` → **1087** |
| 3 | `oldtalk.idx` → **4020** 条目；`lines: 4021`；`[1] = 小兄弟，到此寒天雪地，不知有何指教？`；`[4018] = 国家兴亡，匹夫有责！兄弟，我也来帮你吧。` |
| 4 | `MAX_LEVEL=60`、`MAX_HP=999`、`MAX_MP=9999`、`MAX_PHYSICAL_POWER=100`、`MAX_ITEM_AMOUNT=200`、`ITEM_BEGIN_PIC=4131`、`MONEY_ID=174`、`MAX_WEAPON_MATCH=7`、`MIN_KNOWLEDGE=80`、`LIFE_HURT=10`、`EXP_RATE=1` |

### 关键的「反向对照」：ini 覆盖确实改变行为

无 MOD 基线：`MaxLevel=nil MaxHP=nil MaxMP=nil MaxItemAmount=nil MaxPhysicalPower=nil LIFE_HURT=nil MIN_KNOWLEDGE=nil`
（这些 `CC.*` **基线根本不存在**，只在 `mod_ini.lua` 的映射表里定义）。

激活 Dragon 后：全部取到 `kysmod.ini` 的值。

⇒ 这是**强证据**：这些常量不是「默认值恰好相同」，而是**确实由 MOD 的 ini 注入**。
若 ini 未被解析，它们会是 `nil`（导致下游 `nil` 比较错误）。

### Consequences

- ✅ 4 类证据全部直接、可复核，不依赖「记录数」推断。
- ✅ 反向对照（基线 nil vs 激活后有值）比正向断言更强。

---

## ADR-004：`not_in_product` 语义不精确（范围外发现）

### Context

`mod_audit.lua` 的输出里 `not_in_product=256`。初版文档容易读成
「256 个文件不在产物里」。实测不成立：

```
not_in_product 中：物理存在于产物=4  物理缺失=252
  present: resource/name.grp        [LEGACY]
  present: resource/name.idx        [LEGACY]
  present: resource/talkutf8.txt    [BUILD_INPUT]
  present: resource/war1.sta        [DEAD_FILE]
```

根因（`tools/mod_audit.lua:453-462`）：

```lua
function M.checkInProduct(rec)
    local rule = M.classify(rec)
    if rule.in_product == false then return false end         -- ← 关卡 1
    if rule.in_product ~= true and not M.IN_PRODUCT_BY_CATEGORY[rule.category] then
        return false                                          -- ← 关卡 2（类别决定）
    end
    for _, p in ipairs(M.productCandidates(...)) do ... end    -- ← 关卡 3（物理检查）
end
```

`IN_PRODUCT_BY_CATEGORY` 中 `LEGACY=false` / `DEAD_FILE=false` / `BUILD_INPUT=false`，
所以这三个类别的文件**无论产物是否存在**都返回 `in_product=false`。

### Decision

**判为工具的语义不精确（命名问题，非逻辑缺陷）**，本 change **不修复**，只记录并给出正确解读：

| 字段 | 正确解读 |
|------|----------|
| `in_product=true` | 「必需类 且 物理在产物里」 |
| `in_product=false` | 「**不需要**（按类别）**或** 物理缺失」 —— 两者并集 |

即 `not_in_product` 实际含义是 **「非必需产物成员」**，不是「产物中不存在」。

**建议改名**（未来独立 change）：`in_product` → `needed_in_product`，
或新增 `physically_present` 字段。

### Alternatives

- **本 change 修复**：会改 `mod_audit` 契约与既有 12 个 slice 的文档口径，
  且需同步 `test_mod_audit.lua` 断言。超 Blast Radius。**否决**。
- **静默忽略**：后续 slice 会继续误读。**否决**。

### Consequences

- ✅ 本 MOD 的 4 例已显式列出，`verification.md` 与 `reports/dragon-verify.md` 均标注。
- ⚠ 这是**第 7 个工具问题**，但性质是「命名/语义」而非「逻辑错误」，
  故不计数为「缺陷 G」，而记为「精度发现」。
- 📌 已入 epic `TODO.md` 作为待决策项。

---

## ADR-004b：`cloud.*` / `title.*` / `open.png` / `end.png` —— 引擎无运行时消费者（范围外发现）

### Context

这 4 类共 6 个文件（`cloud.{grp,idx}`、`title.{grp,idx}`、`open.png`、`end.png`）
在全部 20 个 MOD 中提供（`title`/`open`/`cloud` 20/20，`end.png` 16/20），
审计归类为 `REQUIRED`/`in_product=true`。但实测：

```
$ grep -rn "cloud" --include=*.lua script/ framework/ engine-love2d/
（0 命中）

$ grep -rn "title\.grp\|title\.idx" --include=*.lua script/ framework/ engine-love2d/
（0 命中）

$ grep -rn "open\.png" --include=*.lua script/ framework/ engine-love2d/
（0 命中）

$ grep -rn "end\.png" --include=*.lua script/ framework/ engine-love2d/
script/jymain.lua:4273:  lib.LoadPicture(CONFIG.PicturePath .."end.png",-1,-1);
```

而 `CONFIG.PicturePath = "pic/"`，产物 `end.png` 在 `data/`，其 md5（`b538413b…`）
与基线 `pic/end.png`（`ea0d6132…`）**不同** ⇒ 运行时读的是**基线**那张，不是 MOD 那张。

`CC.*` 常量里也**没有** `CloudPicFile` / `TitlePicFile` / `OpenFile` / `EndFile`
（实测全部 `nil`）。

### Decision

判为 **「C 引擎资源，Lua 引擎未接入」**，`REQUIRED` 归类由 `BY_KIND` 兜底
（`mod_audit.lua:264-269`：`resource|.grp` / `resource|.idx` / `resource|.png` → `REQUIRED`），
**不是**按「Lua 引擎实际读取」判定的。

与 `name.*`（`LEGACY`，有 `EXACT` 规则显式降级）的区别：
`cloud`/`title`/`open`/`end` **没有** `EXACT` 规则，落到了 `BY_KIND` 的宽泛兜底，
因此被标为 `REQUIRED` 但实际无运行时消费者。

### Alternatives

- **在本 change 把它们改判 `LEGACY`**：会改动审计类别统计、影响其余 19 个 MOD 的
  `REQUIRED` 计数（各 −6），并需同步 `test_mod_audit.lua` 与 12 个既有 slice 的口径。
  属**独立 change**。**否决**。
- **判为构建缺陷**：构建契约是「`resource/` 一律展平复制」，复制无错。**否决**。

### Consequences

- ✅ 本 change 只记录，不改判定；`verification.md` §7 与报告 §3.2 显式标注。
- ⚠ 这是**精度发现**（与 ADR-004 同性质）：`REQUIRED` 在本项目里实际含义是
  「C 引擎资源 + Lua 引擎已知必需」的并集，而非「Lua 引擎运行时读取」。
- 📌 已入 epic `TODO.md` 待决策（与 `not_in_product` 语义问题合并为一条）。
- ✅ 不影响本 slice 结论：这 6 个文件的字节一致性、来源正确性均已验证；
  只是「需要性」判定偏保守（保守 = 多带文件，无害）。

---

## ADR-005：`name.*` 与 `talk.*` 内容完全相同 —— 历史兼容副本

### Context

```
4c41c044413860015bd626d480e36951  resource/name.grp
4c41c044413860015bd626d480e36951  resource/talk.grp
1a0c74ab1dd84e8714a5b4fd1ed22488  resource/name.idx
1a0c74ab1dd84e8714a5b4fd1ed22488  resource/talk.idx
```

`name.grp`/`name.idx` 被构建复制到 `mods/Dragon/data/`（211697B / 16080B），
但审计归类为 `LEGACY`（`needed=false`），证据串：「引擎从不读取 name.grp；
人名来自 ranger.grp 的 `JY.Person[i][姓名]`」（`mod_audit.lua:102`）。

### Decision

判为 **MOD 作者的历史遗留副本**（`name.*` 是 C 引擎早期的人名表，
Lua 引擎统一从 `ranger.grp` 取），**不是构建缺陷**。

三条理由：

1. **构建契约是「`resource/` 一律展平复制」**（`mod_build.lua:7` 注释
   「`data/` = resource/fight/save flattened (lowercased), + kysmod.ini」）
   —— 不做白名单过滤是既有设计，不是这个 MOD 触发的。
2. **引擎确实零引用**：`CC.*` 中无 `NameFile`；`grep -rn "talk.grp\|NameFile"` 只命中
   `CC.TalkGrpFile = script/oldtalk.grp`（构建期产物，非 `data/talk.grp`）。
3. **同名同内容的 `talk.*` 确实被构建期使用**（提取 `oldtalk.grp`/`oldtalk.idx`），
   所以复制 `talk.*` 是必要的；`name.*` 只是粘在同一个 `resource/` 目录里被顺带复制。

⇒ 「**物理存在但逻辑不需要**」—— 与 ADR-004 的 `not_in_product` 语义问题直接相关。

### Consequences

- ✅ 保留 `data/name.*`（删除会破坏「产物 = 源 + 转换」的可追溯性，且 15KB~211KB 成本可忽略）。
- ✅ 不判为缺陷（4/20 MOD 有该文件：BookCalamity / Dragon / RiverLake / pineapple）。
- ⚠ 这解释了为什么 `not_in_product=256` 里有 2 项其实物理存在。

---

## ADR-006：`war1.sta` 两处判定不矛盾

### Context

同一文件出现两个看似矛盾的判定：

| 来源 | 判定 |
|------|------|
| `mod_audit` | `DEAD_FILE`, `needed=false` |
| `diff.md` | MOD 独有 16 项之一（源里有、产物也有） |

### Decision

**两处不矛盾** —— 它们回答的是不同问题：

| 判定 | 回答的问题 |
|------|-----------|
| `DEAD_FILE` | 「**引擎需要读它吗？**」 → 不需要（零引用） |
| `diff.md` MOD 独有 | 「**这个文件在 MOD 源里、基线里没有？**」 → 是的（相对基线是新增） |

判据矩阵：

| 维度 | 值 |
|------|-----|
| 源存在 | ✅ 66030B，`66030 ÷ 186 = 355` 记录 |
| 产物存在 | ✅ 66030B，逐字节一致 |
| 基线存在 | ❌ |
| 引擎常量引用 | ❌ `CC.WarFile` 只指 `war.sta` |
| 代码引用 | ❌ `grep -rn "war1" script/ framework/ engine-love2d/` → 0 命中 |
| 审计标注 | `mod_audit.lua:189` `category="DEAD_FILE", needed=false` |

⇒ 「新增但不用」= 两个判定都正确。

### 与 RiverLake `allsinbk.grp` 的对比（必须区分）

| 维度 | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|------|--------------------------|-------------------|
| 属于 `diff.md` MOD 独有？ | ❌（是「基准独有」D 类） | ✅（MOD 独有） |
| 常量 | ✅ `CC.TempS_Filename` | ❌ 无 |
| 传参 | ✅ 传入 `LoadSMap` | ❌ 从不传 |
| 引擎侧 | 形参 `tmpfilename` 零引用 | 完全无代码路径 |
| 归类来源 | 运行时取证 | 审计规则 |

**核心差异**：`allsinbk.grp` 是「**基线有、MOD 没有 ⇒ 回退基线**，但基线的这份从不被读」；
`war1.sta` 是「**MOD 新生成了这份，但引擎从不读它**」。
前者是「回退到的文件是死的」，后者是「新增的文件是死的」。

### Consequences

- ✅ 保留 `war1.sta`（照源复制）。
- ⚠ 报告必须并列展示两处判定，避免读者误判为工具自相矛盾。
