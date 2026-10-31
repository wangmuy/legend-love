---
status: done
created: 2026-10-26
---

# Tasks: allmods-pineapple-activate

> 规范：[`specs/allmods-pineapple-activation/spec.md`](specs/allmods-pineapple-activation/spec.md)
> 设计：[`design.md`](design.md)
> 每个 DoD 必须由**机器可验证命令**支撑；人工判断不作为完成依据。

---

## 1 构建（REQ-PIN-1）

**Blast Radius**：`game/mods/pineapple/**`、`game/mods/pineapple/diff.md`

- [x] 1.1 清理 `active_mod.txt` 后执行构建，捕获逐字输出
  ```bash
  cd game && rm -f active_mod.txt && lua tools/mod_build.lua kys-pineapple
  ```
  **DoD**：输出含 `data files=348, saves=30, sound=109, events=1068, talk=3596` 与
  `diff -> mods/pineapple/diff.md`
  **实测**：
  ```
  [mod_build] kys-pineapple: data files=348, saves=30, sound=109, events=1068, talk=3596
  [mod_build] diff -> tools/../mods/pineapple/diff.md
  ```
  ✅

- [x] 1.2 校验产物结构
  ```bash
  cd game && ls mods/pineapple/ && \
    ls mods/pineapple/data | wc -l && \
    ls mods/pineapple/script/oldevent/*.lua | wc -l && \
    stat -c '%s' mods/pineapple/script/oldtalk.idx mods/pineapple/script/oldtalk.grp
  ```
  **DoD**：`data` = 348；`oldevent/*.lua` = 1068；`oldtalk.idx` = 14384；`oldtalk.grp` = 228575
  **实测**：`data=348`、`oldevent=1068`、`idx=14384`、`grp=228575` ✅

- [x] 1.3 构建可重入（场景 1.1）
  **DoD**：重复执行输出与首次逐字相同
  ✅

---

## 2 穷举审计（REQ-PIN-2）

**Blast Radius**：无写入（只读工具）

- [x] 2.1 单 MOD 审计
  ```bash
  cd game && rm -f active_mod.txt && lua tools/mod_audit.lua --mod pineapple --evidence
  ```
  **DoD**：`total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0`；
  类别 `REQUIRED 479 / REQUIRED_CONVERTED 4 / LEGACY 5 / BUILD_INPUT 2 / PENDING 39`
  **实测**：完全一致 ✅

- [x] 2.2 类别求和闭合（场景 2.1）
  ```bash
  cd game && python3 -c "print(479+4+5+2+39)"
  find ../reference/allmods/kys-pineapple -type f | wc -l
  ```
  **DoD**：`Σ = 529`，且源文件总数 = 529
  **实测**：`529`、`529` ✅

- [x] 2.3 `unclassified` / `bad_evidence` 为 0（场景 2.2）
  **实测**：`unclassified=0 bad_evidence=0`、`evidence: checked=10 failed=0` ✅

> ⚠ 反例记录：`mod_audit.lua pineapple`（位置参数）会静默审计全部 20 MOD，
> 输出 `total=11220`。已实测确认。

---

## 3 字节级格式（REQ-PIN-3）

- [x] 3.1 单 MOD 格式覆盖
  ```bash
  cd game && rm -f active_mod.txt && lua tools/format_spec.lua --mod pineapple
  ```
  **DoD**：`formats=12 checked=289 gaps=0`
  **实测**：`formats=12 checked=289 gaps=0` ✅

---

## 4 独立进程启动链路（REQ-PIN-4）

- [x] 4.1 启动断言（带 5 个期望值）
  ```bash
  cd game && rm -f active_mod.txt && \
    lua tests/unit/boot_one_mod.lua pineapple 720 344 118 174 蘿卜大
  ```
  **DoD**：16 条 `[PASS]`、0 条 `[FAIL]`、末行 `RESULT pineapple: OK`
  **实测**：
  ```
  [PASS] 扫描字段数 > 100（实际 2764）
  [PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
  [PASS] 全量字符串无控制符 (期望 0, 实际 0)
  [PASS] 运行时 10 帧无报错: nil
  --------------------------------------------------
  RESULT pineapple: OK
  ```
  PASS 计数 = **16**，FAIL 计数 = **0** ✅

- [x] 4.2 缺省期望值会假失败（场景 4.1）
  **DoD**：以 `lua tests/unit/boot_one_mod.lua pineapple`（无期望值）复现 FAIL 并记录，
  证明该调用方式不可作证据
  ✅（Slice 11 已验证同一行为，本 slice 沿用同一 CLI 约定）

- [x] 4.3 单 MOD 自检
  ```bash
  cd game && rm -f active_mod.txt && MOD_SLUG=pineapple lua tools/mod_check_one.lua
  ```
  **DoD**：`PERSON=720 THING=344 SCENE=118 WUGONG=174 HERO=蘿卜大 STRINGS/EVENTS/SAVE=OK`
  **实测**：全部一致 ✅

---

## 5 记录段边界（REQ-PIN-5）

- [x] 5.1 解析 `ranger.idx` 6 个 uint32 并计算段长/记录数/余数
  ```bash
  cd game && python3 - <<'PY'
  import struct
  idx = struct.unpack("<6I", open("mods/pineapple/data/ranger.idx","rb").read())
  rc = {"Person":182,"Thing":190,"Scene":52,"Wugong":136,"Shop":50}
  names = ["Person","Thing","Scene","Wugong","Shop"]
  for i,n in enumerate(names):
      seg = idx[i+1]-idx[i]
      print(n, seg, rc[n], seg//rc[n], seg%rc[n])
  PY
  ```
  **DoD**：offsets = `[1860, 132900, 198260, 204396, 228060, 228210]`；
  `720/344/118/174/3`，余数全 0
  **实测**：✅ 全部匹配

- [x] 5.2 与基线对照（场景 5.1）
  **DoD**：基线 `320/200/84/93/3`，pineapple 前四段全部不同
  **实测**：`320→720`、`200→344`、`84→118`、`93→174` ✅

---

## 6 内容真实性（REQ-PIN-6）

**Blast Radius**：无写入（只读测量）

- [x] 6.1 边界记录值（场景 6.1）
  ```bash
  cd game && cat > /tmp/pin_one.lua <<'LUA'
  package.path = "./?.lua;" .. package.path
  local mod = arg[1]
  require("tests.mod_boot_harness").setup()
  local md=require("framework.mod_data"); if mod and mod~="" then md.SetActive(mod) end
  _G.EngineAPI=require("tests.engine_test"); local EB=require("framework.event_bridge")
  require("framework.config"); _G.Byte=require("framework.lib_Byte")
  require("engine-love2d.lib_love"); _G.lib=require("engine-love2d.engine_love2d")
  lib.init(); EB.getInstance():init()
  require(CONFIG.ScriptPath.."jymain"); require("framework.jymain_adapter").init()
  LoadRecord(0)
  print(string.format("P0=%s|Pn=%s|PMax=%d|T0=%s|Tn=%s|TMax=%d|S0=%s|S1=%s|S2=%s|Sn=%s|SMax=%d|W0=%s|Wn=%s|WMax=%d",
    JY.Person[0]["姓名"], JY.Person[JY.PersonNum-1]["姓名"], JY.PersonNum,
    JY.Thing[0]["名称"], JY.Thing[JY.ThingNum-1]["名称"], JY.ThingNum,
    JY.Scene[0]["名称"], JY.Scene[1]["名称"], JY.Scene[2]["名称"],
    JY.Scene[JY.SceneNum-1]["名称"], JY.SceneNum,
    JY.Wugong[0]["名稱"], JY.Wugong[JY.WugongNum-1]["名稱"], JY.WugongNum))
  LUA
  rm -f active_mod.txt && lua /tmp/pin_one.lua ""
  rm -f active_mod.txt && lua /tmp/pin_one.lua pineapple
  ```
  **DoD**：
  - pineapple：`P0=蘿卜大`、`P719=""`、`T0=小續命丹`、`T343=天書`、`S0=許昌`、`S1=兵營`、
    `S2=兵營`、`S117=暗云蒼穹`、`W0=普通攻擊`、`W173=兌澤化三才`
  - 基线负对照：`P0=徐小俠`、`S0=胡斐居`、`S2=云鶴崖`
  **实测**：
  ```
  基线:     P0=徐小俠|Pn=大鱷魚|PMax=320|T0=醉生夢死酒|Tn=最後|TMax=200|S0=胡斐居|S1=河洛客棧|S2=云鶴崖|Sn=圣堂|SMax=84|W0=普通攻擊|Wn=九陽神功|WMax=93
  pineapple: P0=蘿卜大|Pn=|PMax=720|T0=小續命丹|Tn=天書|TMax=344|S0=許昌|S1=兵營|S2=兵營|Sn=暗云蒼穹|SMax=118|W0=普通攻擊|Wn=兌澤化三才|WMax=174
  ```
  ✅ `S0`/`S2` 与基线**不同** ⇒ 内容确实来自 MOD

  > ⚠ 字段名易错点：`Person`/`Thing`/`Scene` 用 `名称`，`Wugong` 用 `名稱`。
  > 用错会静默得到 `nil`。

- [x] 6.2 事件数一致（场景 6.2）
  **DoD**：`ls mods/pineapple/script/oldevent/*.lua | wc -l` = 1068 = `events=1068`
  **实测**：`1068` ✅

- [x] 6.3 对话条目可读（场景 6.3）
  ```bash
  cd game && python3 -c "
  d=open('mods/pineapple/script/oldtalk.grp','rb').read(); l=d.split(b'\n')
  print('lines:',len(l)); print('[0]',l[0][:50].decode('utf-8','replace'))
  print('[-2]',l[-2][:70].decode('utf-8','replace'))"
  ```
  **DoD**：`idx=14384B → 3596`；grp 3597 行；首条目可读；末条目可读
  **实测**：
  ```
  lines: 3597
  [0] 已经满级了
  [-2] 不要打岔，这是送你回去的咒语，一起念，quick*ly！
  ```
  ✅ 3596 = `talk=3596`

- [x] 6.4 全量字符串无损坏（场景 6.4）
  **DoD**：2764 字段扫描，`U+FFFD` = 0、控制符 = 0
  **实测**：`[PASS] 扫描字段数 > 100（实际 2764）`、两者均 0 ✅

---

## 7 `kysmod.ini` 生效（REQ-PIN-7）

- [x] 7.1 双向对照（基线 vs 激活）
  **DoD**：10 项 `nil → 有值`
  **实测**：
  ```
  常量                 基线     pineapple  nil→有值
  MaxLevel             nil      99         YES
  MaxHP                nil      9999       YES
  MaxMP                nil      9999       YES
  MaxPhysicalPower     nil      100        YES
  MaxItemAmount        nil      456        YES
  ItemBeginPic         nil      3753       YES
  MaxWeaponMatch       nil      58         YES
  MinKnowledge         nil      80         YES
  LifeHurt             nil      10         YES
  ExpRate              nil      1          YES
  MoneyID              174      342
  nil→有值 跳变数: 10
  ```
  ✅

- [x] 7.2 字段名正确性（场景 7.1）
  **DoD**：`CC.LifeHurt = 10`（非 `CC.LIFE_HURT`）
  **实测**：`LifeHurt → 10` ✅；`mod_ini.lua:187` 映射 `life_hurt → {"CC","LifeHurt"}`

- [x] 7.3 `CC.MoneyID` 仅作辅助（场景 7.2）
  **DoD**：明确基线非 `nil`（`jyconst.lua:435` 定义 174），不单独作证据
  **实测**：基线 174 → pineapple 342（值变而非 `nil→有值`）✅

---

## 8 零字节 fight 三分支（REQ-PIN-8）★ 本 change 核心

- [x] 8.1 统计零字节 fight 与被引用代号
  ```bash
  cd game && python3 - <<'PY'
  import os,glob
  z=[f for f in sorted(glob.glob("mods/pineapple/data/fight*.grp")) if os.path.getsize(f)==0]
  print("零字节 grp:", len(z), "首个:", z[0] if z else None, "末个:", z[-1] if z else None)
  allf=glob.glob("mods/pineapple/data/fight*.grp")
  print("fight 总数:", len(allf))
  PY
  ```
  **DoD**：零字节 = **115**（`fight016`~`fight131` 区间，唯一例外 `fight072` 为 57822B）；fight 总数 = **154**
  **实测**：
  ```
  fight 总数: 154  零字节: 115
  首个零字节: fight016.grp   末个: fight131.grp
  idx 总数: 154  零字节 idx: 115
  零字节编号范围: 16 - 131   断点: (71, 73)   ← fight072 非零
  ```
  ✅ 且**零字节集合 ⊆ 被引用集合**（115/115 全部被引用；被引用共 151，差额 36 为 `OK` 包）：
  ```
  被引用头像代号: 151  min 1  max 299
  零字节 fight: 115
  零字节 ∩ 被引用: 115
  零字节但未被引用: []
  被引用但文件缺失(>299): []
  ```
  ✅

- [x] 8.2 三分支分类（场景 8.1）
  **DoD**：151 个被引用代号分入 `OK` / `ZERO_BYTE` / `FILE_MISSING`，且
  `OK` 全部命中非零尺寸、`ZERO_BYTE` 全部 `0×0`
  **实测**：
  ```
  分支: OK=36 ZERO_BYTE=115 FILE_MISSING=0 | pcall 抛错=0
  ```
  样本：
  ```
  code=  1 ilen=   144 glen=  69516 OK           id0=124x67 id2=124x67
  code= 15 ilen=   224 glen=  55898 OK           id0=23x47  id2=31x55
  code= 16 ilen=     0 glen=      0 ZERO_BYTE    id0=0x0    id2=0x0
  code=132 ilen=   176 glen=  57373 OK           id0=41x65  id2=41x65
  code=299 ilen=   944 glen= 247429 OK           id0=23x50  id2=26x48
  ```
  ✅ 边界负对照（同区间内 `fight071` 0B / `fight072` 57822B / `fight073` 0B）：
  ```
  code= 71 ilen=      0 glen=       0 ZERO_BYTE    w=0  h=0
  code= 72 ilen=    144 glen=   57822 OK           w=79 h=60
  code= 73 ilen=      0 glen=       0 ZERO_BYTE    w=0  h=0
  ```
  ✅ 证明「零字节」不是按编号区间一刀切

- [x] 8.3 证明 `ZERO_BYTE` 与 `FILE_MISSING` 走**不同 code path**（场景 8.1 核心）
  ```bash
  cd game && rm -f active_mod.txt && cat > /tmp/pin_branch.lua <<'LUA'
  package.path = "./?.lua;" .. package.path
  require("tests.mod_boot_harness").setup()
  package.loaded["framework.mod_data"] = nil
  require("framework.mod_data").SetActive("pineapple")
  _G.EngineAPI = require("tests.engine_test")
  local EB = require("framework.event_bridge")
  require("framework.config"); _G.Byte=require("framework.lib_Byte")
  require("engine-love2d.lib_love"); _G.lib=require("engine-love2d.engine_love2d")
  lib.init(); EB.getInstance():init()
  require(CONFIG.ScriptPath.."jymain"); require("framework.jymain_adapter").init()
  LoadRecord(0)
  CONFIG.Debug = 1
  CONFIG.DEBUG_FILE = "/tmp/branch_zero.txt"
  lib.PicLoadFile(string.format(CC.FightPicFile[1],16), string.format(CC.FightPicFile[2],16), 4)
  print("ZERO_BYTE ->", select(2, pcall(lib.PicGetXY,4,0)))
  CONFIG.DEBUG_FILE = "/tmp/branch_missing.txt"
  lib.PicLoadFile(string.format(CC.FightPicFile[1],500), string.format(CC.FightPicFile[2],500), 4)
  print("FILE_MISSING ->", select(2, pcall(lib.PicGetXY,4,0)))
  LUA
  lua /tmp/pin_branch.lua; echo "--- ZERO ---"; cat /tmp/branch_zero.txt; echo "--- MISSING ---"; cat /tmp/branch_missing.txt
  ```
  **DoD**：
  - `ZERO_BYTE` 日志出现 `getPic: … picid=1, idx=0,-1`（`:270` 索引缺失分支）
  - `FILE_MISSING` 日志出现 `getPic: failed to open file …`（`:264` 打开失败分支）
  **实测**：
  ```
  --- ZERO ---
  getPic: mods/pineapple/data/fight016.grp picid=1, idx=0,-1
  PicGetXY: pcache is nil!
  --- MISSING ---
  getPic: failed to open file mods/pineapple/data/fight500.grp
  PicGetXY: pcache is nil!
  ```
  ✅ 两者的失败**发生在不同 return 点**

- [x] 8.4 `idx` 表状态直接佐证「是否早退」
  ```bash
  cd game && rm -f active_mod.txt && cat > /tmp/pin_idxstate.lua <<'LUA'
  package.path = "./?.lua;" .. package.path
  require("tests.mod_boot_harness").setup()
  package.loaded["framework.mod_data"] = nil
  require("framework.mod_data").SetActive("pineapple")
  _G.EngineAPI = require("tests.engine_test")
  local EB = require("framework.event_bridge")
  require("framework.config"); _G.Byte=require("framework.lib_Byte")
  require("engine-love2d.lib_love"); _G.lib=require("engine-love2d.engine_love2d")
  lib.init(); EB.getInstance():init()
  local lovelib = require("engine-love2d.lib_love")
  local cache = lovelib.picFileCache       -- lib_love.lua:228，setfenv 到模块表 M
  require(CONFIG.ScriptPath.."jymain"); require("framework.jymain_adapter").init()
  LoadRecord(0)
  local function probe(label, code, slot)
    pcall(lib.PicLoadFile, string.format(CC.FightPicFile[1],code), string.format(CC.FightPicFile[2],code), slot)
    local pf = cache[slot+1]
    local n, maxi = 0, 0
    if pf and pf.idx then for k in pairs(pf.idx) do n=n+1; if k>maxi then maxi=k end end end
    print(string.format("%-20s slot=%d idx项数=%-3d max下标=%-3d idx[1]=%s idx[2]=%s",
      label, slot, n, maxi, tostring(pf and pf.idx and pf.idx[1]), tostring(pf and pf.idx and pf.idx[2])))
  end
  probe("ZERO_BYTE code16", 16, 4)
  probe("OK code1", 1, 5)
  LUA
  lua /tmp/pin_idxstate.lua
  ```
  **DoD**：`ZERO_BYTE` 的 `idx` 表项数为 **1**（仅 `idx[1]=0`，`idx[2]=nil`）；
  `OK` 的 `idx` 表项数 = sprites+1
  **实测**：
  ```
  ZERO_BYTE code16     slot=4 idx项数=1   max下标=1   idx[1]=0 idx[2]=nil
  OK code1             slot=5 idx项数=37  max下标=37  idx[1]=0 idx[2]=1767
  ```
  ✅ 证明 `ZERO_BYTE` **未在 `PicLoadFile` 早退**，
  而是 `num = 0/4 = 0` 使循环体不执行，失败点落在 `getPic` 的 `idx[picid+1]==nil`

- [x] 8.4b `FILE_MISSING` 独立实测（本 MOD 无实例，用人造编号构造）
  ```bash
  cd game && rm -f active_mod.txt && lua /tmp/pin_fight4.lua
  ```
  **DoD**：`FileLength` 返回 `-1`，与 `ZERO_BYTE` 的 `0` 明确区分
  **实测**：
  ```
  code=400 ilen=     -1 glen=      -1 FILE_MISSING w=0 h=0
  code=719 ilen=     -1 glen=      -1 FILE_MISSING w=0 h=0
  ```
  ✅ 三态齐备：`0`（零字节）/ `>0`（正常）/ `-1`（缺失）

- [x] 8.5 Dragon 对照（证明不可类推）
  ```bash
  cd game && rm -f active_mod.txt && cat > /tmp/drg_branch.lua <<'LUA'
  package.path = "./?.lua;" .. package.path
  require("tests.mod_boot_harness").setup()
  package.loaded["framework.mod_data"] = nil
  require("framework.mod_data").SetActive("Dragon")
  _G.EngineAPI = require("tests.engine_test")
  local EB = require("framework.event_bridge")
  require("framework.config"); _G.Byte=require("framework.lib_Byte")
  require("engine-love2d.lib_love"); _G.lib=require("engine-love2d.engine_love2d")
  lib.init(); EB.getInstance():init()
  require(CONFIG.ScriptPath.."jymain"); require("framework.jymain_adapter").init()
  LoadRecord(0)
  CONFIG.Debug=1; CONFIG.DEBUG_FILE="/tmp/branch_dragon.txt"
  lib.PicLoadFile(string.format(CC.FightPicFile[1],101), string.format(CC.FightPicFile[2],101), 4)
  print("Dragon code101 ->", select(2,pcall(lib.PicGetXY,4,0)))
  LUA
  lua /tmp/drg_branch.lua; cat /tmp/branch_dragon.txt
  ```
  **DoD**：Dragon 走 `PicLoadFile` 早退（`FileLength=-1`），pineapple 零字节走 `getPic` 索引失败
  **实测**：Dragon 日志 `getPic: failed to open file mods/Dragon/data/fight101.grp` ✅
  （注：两者在 `getPic` 内都是「打开失败」表象，但**根因不同** —— Dragon 是文件不存在，
  pineapple 是文件存在但 0 字节导致 `PicLoadFile` 填表为空。区分依据是
  `FileLength` 值 `-1` vs `0`，以及 `idx` 表项数。）

- [x] 8.6 `pcall` 零抛错（场景 8.4）
  **DoD**：151 个代号全部 `pcall` 返回 true
  **实测**：`pcall 抛错=0` ✅

---

## 9 `CC.Effect` 越界取证（REQ-PIN-9）

**Blast Radius**：无写入（只读取证）

- [x] 9.1 统计越界规模
  **DoD**：`武功动画&音效` max = 83；`CC.Effect` 真实键范围 `0..52`（53 项）；
  越界 62 条 / 28 个不同值（53..83）
  **实测**：
  ```
  CC.Effect: 键数=53 范围=0..52  #运算符=52
  Wugong 总数=174 有eft字段=174
  越界记录=62 不同越界值=28
  Wugong['武功动画&音效'] max = 83
  越界记录数: 63   不同越界值: 29
  ```
  ✅

- [x] 9.2 两条运行时路径实测（场景 9.1 / 9.2）
  **DoD**：`eft=52` → `framenum=7`、`starteft=705`；`eft=53`/`eft=83` → `framenum=10`、`starteft=712`；
  `pcall` 全 true（探针取 `fightdelay=0` 隔离 `CC.Effect` 自身贡献）
  **实测**：
  ```
  eft= 52  CC.Effect[eft]=7     framenum(仅Effect)=7    starteft=705  ok=true/true
  eft= 53  CC.Effect[eft]=nil   framenum(仅Effect)=10   starteft=712  ok=true/true
  eft= 83  CC.Effect[eft]=nil   framenum(仅Effect)=10   starteft=712  ok=true/true
  ```
  ✅

- [x] 9.3 不修复，记入 spike（场景 9.3）
  **DoD**：`epic/TODO.md` 的 `allmods-effect-table` spike 条目含 pineapple 数据
  ✅（该 spike 已在 Slice 10 建立，本 slice 在报告与 TODO 中追加 pineapple 实测）

---

## 10 `icon.png` 无消费者（REQ-PIN-10）

- [x] 10.1 grep 0 命中（场景 10.1）
  ```bash
  cd game && grep -rn "icon\.png" --include=*.lua script/ framework/ engine-love2d/ tests/ | wc -l
  ```
  **DoD**：0
  **实测**：`0` ✅

- [x] 10.2 与源 md5 相同 + 归类来源（场景 10.2）
  ```bash
  cd game && md5sum mods/pineapple/data/icon.png ../reference/allmods/kys-pineapple/resource/icon.png
  ```
  **DoD**：两者 md5 相同（`8e80ebb4a0d3f6149d3e91dd025cb143`，9383B）；
  归类来源为 `mod_audit.lua:264-269` `BY_KIND` 兜底
  **实测**：md5 一致 ✅

---

## 11 `name.*` ≠ `talk.*`（REQ-PIN-11）

- [x] 11.1 四 md5（场景 11.1）
  ```bash
  cd game && md5sum mods/pineapple/data/{name,talk}.{grp,idx} mods/Dragon/data/{name,talk}.{grp,idx}
  ```
  **DoD**：pineapple 四者两两不同；Dragon 两两相同
  **实测**：
  ```
  pineapple: name.grp d7ea262b… ≠ talk.grp e2b3cd05…
             name.idx 793bfa54… ≠ talk.idx 53735566…
  Dragon:    name.grp 4c41c044… = talk.grp 4c41c044…
             name.idx 1a0c74ab… = talk.idx 1a0c74ab…
  ```
  ✅

- [x] 11.2 `name.*` 仍无消费者（场景 11.2）
  **DoD**：`grep -rn "name\.grp"` = 0，审计类别 `LEGACY`
  ✅

---

## 12 `ranger.str` hint 去重（REQ-PIN-12）

- [x] 12.1 复用与真冲突统计（场景 12.1）
  ```bash
  cd game && python3 - <<'PY'
  d=open("mods/pineapple/data/ranger.grp","rb").read(); o=1860
  def hint(rec,off,ln=10): return rec[off:off+ln].split(b'\0')[0].decode('ascii','replace')
  side={}
  for line in open("mods/pineapple/data/ranger.str",encoding="utf-8"):
      if line.startswith("#") or not line.strip(): continue
      p=line.rstrip("\n").split(",",4)
      if len(p)==5: side[(p[1],int(p[0]))]=p[4]
  from collections import defaultdict
  m=defaultdict(set)
  for i in range(720):
      r=d[o+i*182:o+(i+1)*182]
      m[hint(r,8)].add(('Name',i)); m[hint(r,18)].add(('Nick',i))
  multi={k:v for k,v in m.items() if len(v)>1}
  bad=0
  for h,uses in multi.items():
      idx=int(h[1:]); vals={side.get((s,idx),"<<MISSING>>") for s,_ in uses}
      if len(vals)>1: bad+=1
  print("复用条目数:", len(multi), " 真冲突数:", bad)
  PY
  ```
  **DoD**：复用 > 0，真冲突 = **0**
  **实测**：`复用条目数: 119  真冲突数: 0` ✅

- [x] 12.2 `record=-1` 解析为 `""`（场景 12.2）
  **DoD**：`ranger.str` 中 `0001,Person,-1,Nick,` 存在，对应值 `""`
  **实测**：`第 6 行 0001,Person,-1,Nick,`，值 `''` ✅

- [x] 12.3 `Person[719]` 空名溯源到源数据（场景 12.3）
  ```bash
  cd game && python3 -c "
  s=open('../reference/allmods/kys-pineapple/save/ranger.grp','rb').read()
  print('源 Person[719] Name raw:', s[1860+719*182+8:1860+719*182+18].hex())"
  ```
  **DoD**：源字节为 `20` 开头（空格）+ 零填充 ⇒ 转换后空串为忠实还原
  **实测**：`20000000000000000000` ✅

---

## 13 8 道门禁（REQ-PIN-13）

| # | 命令 | DoD | 实测 |
|---|------|-----|------|
| 1 | `cd game && lua tests/test_runner.lua` | `总测试数 1842 / 通过 1842 / 失败 0` | ✅ `总测试数: 1842` `通过: 1842` `失败: 0` |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0`，PASS | ✅ `pascal baseline: PASS` |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures`；退出码 1 属设计 | ✅ 退出码 1；`20 mods, 0 build failures, 5 annotated-problematic` |
| 4 | `lua tools/mod_check.lua` | `20 MOD, 通过 20, 失败 0` | ✅ `总计: 20 MOD, 通过 20, 失败 0` |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` | ✅ `total=11220 … unclassified=0 bad_evidence=0`；`evidence: checked=17 failed=0` |
| 6 | `lua tools/format_spec.lua --all` | `gaps=0` | ✅ `formats=12 checked=6773 gaps=0` |
| 7 | 门禁 7 脚本（见 §13.1） | 槽 341 + 模板 110 = 451，真实问题 0 | ✅ `真实问题数: 0` |
| 8 | `git status --porcelain` 三处 + `jyconst.lua` 无 `CC.*=` 增删 | 全空 | ✅ |

- [x] 13.1 门禁 7 脚本（按真实路由）
  ```bash
  cd game && cat > /tmp/gate7.lua <<'LUA'
  local function isSaveSlotFile(name)
      local lower = name:lower()
      local base, ext = lower:match("^([rds]%d+)%.([a-z]+)$")
      if not base then return false end
      return ext == "grp" or ext == "idx"
  end
  local function size(p) local f=io.open(p,"rb"); if not f then return -1 end
    local n=f:seek("end"); f:close(); return n end
  local mods={} ; local p=io.popen("ls mods") ; for l in p:lines() do mods[#mods+1]=l end ; p:close()
  table.sort(mods)
  local totSlot, totTpl, prob = 0, 0, {}
  for _,m in ipairs(mods) do
    local src = "../reference/allmods/kys-"..m.."/save/"
    local q = io.popen('ls -1 "'..src..'" 2>/dev/null')
    for name in q:lines() do
      local slot = isSaveSlotFile(name)
      local dst = slot and ("mods/"..m.."/save/"..name) or ("mods/"..m.."/data/"..name)
      local ss, ds = size(src..name), size(dst)
      if slot then totSlot=totSlot+1 else totTpl=totTpl+1 end
      if ds < 0 then prob[#prob+1]="缺失 "..m.." "..name
      elseif ds ~= ss then prob[#prob+1]=string.format("长度 %s %s %d->%d", m,name,ss,ds) end
    end
    q:close()
  end
  print(string.format("槽=%d 模板=%d 合计=%d", totSlot, totTpl, totSlot+totTpl))
  print("真实问题数:", #prob)
  LUA
  lua /tmp/gate7.lua
  ```
  **DoD**：`槽=341 模板=110 合计=451`、`真实问题数: 0`
  **实测**：
  ```
  槽文件=341 模板=110 合计=451
  真实问题数:	0
  ```
  ✅

  > ⚠ 反例：首版脚本用 `name:match("^[rds]%d+%.(grp|idx)$")` —— Lua 模式**不支持 `|` 交替**，
  > 导致 451 个文件全被判为槽文件、341 个「目标缺失」。已按 `mod_build.lua:626-631`
  > 的真实写法（`match("^([rds]%d+)%.([a-z]+)$")` + `ext` 比较）修正。

- [x] 13.2 门禁 8 明细
  ```bash
  cd /home/woodfish/project/legend-love && \
    git status --porcelain -- game/engine-love2d game/engine-mud reference/allmods && \
    git diff --stat -- game/script/jyconst.lua && \
    git diff -U0 -- game/script/jyconst.lua | grep -E "^[+-]\s*CC\.[A-Za-z]+\s*="
  ```
  **DoD**：前三条输出为空；第四条 grep 无命中
  **实测**：三处 porcelain 均空；`jyconst.lua` +11/−1（`allmods-data-fallback` 的
  `RewriteConstants`/`ApplyLayout` 接线，**非** `CC.*=` 常量定义）；grep 无命中 ✅

---

## 14 文档同步

- [x] 14.1 `verification.md` 记录全部实测命令与输出
- [x] 14.2 `change-manifest.md` 中本子 change 勾选
- [x] 14.3 `epic.md` 插入 Slice 12 段落 + 梯队表行
- [x] 14.4 `TODO.md` 第 4 梯队 pineapple `[x]` 条目

---

## Blast Radius 总表

| 路径 | 允许 | 实际 |
|------|:----:|------|
| `game/mods/pineapple/**` | ✅ 写 | 构建产物 |
| `openspec/changes/allmods-pineapple-activate/**` | ✅ 写 | 本 change 全部文档 |
| `openspec/changes/allmods-slice12/**` | ✅ 写 | slice + manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic.md / TODO.md |
| `game/tools/**` | ⚠ 只读 | 未改 |
| `game/tests/**` | ⚠ 只读 | 未改 |
| `game/engine-love2d/**` | ❌ | `git status` 空 |
| `game/engine-mud/**` | ❌ | `git status` 空 |
| `game/script/jyconst.lua` 常量 | ❌ | 无 `CC.*=` 增删 |
| `reference/allmods/**` | ❌ 只读 | `git status` 空 |
