---
status: done
created: 2026-10-26
---

# Tasks: allmods-pineapple-verify

> 规范：[`specs/allmods-pineapple-verification/spec.md`](specs/allmods-pineapple-verification/spec.md)
> 设计：[`design.md`](design.md)
> 工作目录 `game/`；每次 mod 相关操作前 `rm -f active_mod.txt`。

---

## 1 双向 set-equal（REQ-PINV-1）

**Blast Radius**：无写入（只读）

- [x] 1.1 解析 `diff.md` 并双向比较
  ```bash
  cd game && python3 - <<'PY'
  import os, glob
  lines=open("mods/pineapple/diff.md",encoding="utf-8").read().splitlines()
  add=set(l.split("  - + ",1)[1].strip() for l in lines if l.startswith("  - + "))
  rem=set(l.split("  - - ",1)[1].strip() for l in lines if l.startswith("  - - "))
  md=set(os.path.basename(p) for p in glob.glob("mods/pineapple/data/*"))
  gd=set(os.listdir("data"))
  print("diff.md added:",len(add)," removed:",len(rem))
  print("实测 MOD 独有:",len(md-gd)," 实测 基线独有:",len(gd-md))
  print("add == 实测MOD独有 ?", add == (md-gd))
  print("rem == 实测基线独有 ?", rem == (gd-md))
  PY
  ```
  **DoD**：两个 `==` 均为 `True`
  **实测**：
  ```
  diff.md added: 140  removed: 21
  实测 MOD 独有: 140  实测 基线独有: 21
  add == 实测MOD独有 ? True
  rem == 实测基线独有 ? True
  ```
  ✅

---

## 2 140 条 MOD 独有分类（REQ-PINV-2）

- [x] 2.1 fight / 非 fight 拆分
  **DoD**：`124` fight + `16` 非 fight = `140`
  **实测**：
  ```
  added 分类: {'fight': 124, 'non-fight': 16}
  ```
  ✅

- [x] 2.2 fight 再拆 grp/idx
  **DoD**：`62 .grp + 62 .idx = 124`
  **实测**：`added fight .grp: 62  .idx: 62  合计: 124` ✅

- [x] 2.3 16 条非 fight 逐条列出
  **实测**：
  ```
  cloud.grp cloud.idx end.png icon.png kdef.grp kdef.idx kysmod.ini
  name.grp name.idx open.png ranger.str talk.grp talk.idx talkutf8.txt
  title.grp title.idx
  ```
  ✅ 共 16 条

---

## 3 21 条基线独有三分类（REQ-PINV-3）

- [x] 3.1 按 `isSaveSlotFile` 分流
  ```bash
  cd game && python3 - <<'PY'
  import os,re
  rem=[l.split("  - - ",1)[1].strip() for l in open("mods/pineapple/diff.md",encoding="utf-8") if l.startswith("  - - ")]
  def isSlot(n):
      m=re.match(r'^([rds]\d+)\.([a-z]+)$', n.lower())
      return bool(m) and m.group(2) in ("grp","idx")
  slot=[n for n in rem if isSlot(n)]; non=[n for n in rem if not isSlot(n)]
  print("总数:",len(rem)," 槽类:",len(slot)," 非槽:",len(non))
  print("非槽明细:",sorted(non))
  PY
  ```
  **DoD**：`21 = 18 槽 + 3 非槽`
  **实测**：
  ```
  总数: 21  槽类: 18  非槽: 3
  非槽明细: ['allsinbk.grp', 'thing.grp', 'thing.idx']
  ```
  ✅

- [x] 3.2 18 个槽文件长度一致
  **DoD**：`size(mods/pineapple/save/n) == size(源 save/n)` 全部成立
  **实测**：
  ```
  d1/d2/d3.grp = 519200 ; .idx = 476
  r1/r2/r3.grp = 228210 ; .idx = 24
  s1/s2/s3.grp = 5799936 ; .idx = 476
  长度不一致: []
  ```
  ✅

- [x] 3.3 3 个非槽文件实测 `ModData.Resolve` 回退
  ```bash
  cd game && rm -f active_mod.txt && lua /tmp/fb.lua
  ```
  **DoD**：三者均指向基线 `data/` 且 `EXISTS`
  **实测**：
  ```
  thing.grp      -> data/thing.grp          EXISTS (345600 B)
  thing.idx      -> data/thing.idx          EXISTS (800 B)
  allsinbk.grp   -> data/allsinbk.grp       EXISTS (4128768 B)
  ```
  ✅ 属设计内回退，非构建遗漏

- [x] 3.4 真删除数为 0
  **实测**：三处（`save/`、`data/`、源）皆无 ⇒ 真删除 **0** ✅

---

## 4 16 条非 fight 内容溯源（REQ-PINV-4）

- [x] 4.1 md5 与源逐一比对
  **DoD**：`15` 条 IDENTICAL + `1` 条 NO-SRC（`ranger.str`）
  **实测**：
  ```
  字节完全一致: 15  不同: 0
  ranger.str   21987  NO-SRC
  ```
  ✅

- [x] 4.2 15 条 IDENTICAL 明细
  | 文件 | 大小 | 源位置 |
  |------|-----:|--------|
  | `cloud.grp` | 38120 | `resource/` |
  | `cloud.idx` | 36 | `resource/` |
  | `end.png` | 490590 | `resource/` |
  | `icon.png` | 9383 | `resource/` |
  | `kdef.grp` | 608388 | `resource/` |
  | `kdef.idx` | 4272 | `resource/` |
  | `kysmod.ini` | 1666 | 根目录 |
  | `name.grp` | 152082 | `resource/` |
  | `name.idx` | 14384 | `resource/` |
  | `open.png` | 152850 | `resource/` |
  | `talk.grp` | 152098 | `resource/` |
  | `talk.idx` | 14384 | `resource/` |
  | `talkutf8.txt` | 223454 | `resource/` |
  | `title.grp` | 8179 | `resource/` |
  | `title.idx` | 36 | `resource/` |
  ✅ 15 条

---

## 5 fight 四象限（REQ-PINV-5）

- [x] 5.1 四象限分解 + 自洽校验
  ```bash
  cd game && python3 - <<'PY'
  import os,glob,hashlib
  def md5(p): return hashlib.md5(open(p,'rb').read()).hexdigest()
  mg={os.path.basename(p):p for p in glob.glob("mods/pineapple/data/fight*.grp")}
  bg={os.path.basename(p):p for p in glob.glob("data/fight*.grp")}
  both=set(mg)&set(bg)
  A=set(n for n in both if md5(mg[n])==md5(bg[n]))
  B=set(n for n in both if md5(mg[n])!=md5(bg[n]))
  C=set(mg)-set(bg)
  D=set(n for n in mg if os.path.getsize(mg[n])==0)
  print("A 同名同容:",len(A),sorted(A))
  print("B 同名异容:",len(B))
  print("C MOD独有 :",len(C))
  print("D 零字节  :",len(D))
  print("A+B == 基线fight数:", len(A)+len(B), "==", len(bg))
  print("A+B+C == MOD fight 数:", len(A)+len(B)+len(C), "==", len(mg))
  print("D∩A:",len(D&A)," D∩B:",len(D&B)," D∩C:",len(D&C))
  PY
  ```
  **DoD**：`A=2 / B=90 / C=62 / D=115`；`A+B=92`；`A+B+C=154`；`D∩B + D∩C = 115`
  **实测**：
  ```
  A 同名同容: 2 ['fight000.grp', 'fight015.grp']
  B 同名异容: 90
  C MOD独有 : 62
  D 零字节  : 115
  A+B == 基线fight数: 92 == 92
  A+B+C == MOD fight 数: 154 == 154
  D∩A: 0  D∩B: 76  D∩C: 39
  ```
  ✅ 全部自洽

---

## 6 零字节源侧溯源（REQ-PINV-6）★ 决定性

- [x] 6.1 115 个零字节的源文件也是 0B
  ```bash
  cd game && python3 - <<'PY'
  import os,glob
  src='../reference/allmods/kys-pineapple/'
  md=[p for p in glob.glob("mods/pineapple/data/fight*.grp") if os.path.getsize(p)==0]
  miss=zero=nz=0
  for p in md:
      n=os.path.basename(p)
      sp=src+"fight/"+n
      if not os.path.exists(sp):
          sp=src+"resource/"+n
      if not os.path.exists(sp): miss+=1
      elif os.path.getsize(sp)==0: zero+=1
      else: nz+=1
  print("产物零字节:",len(md)," 源中找不到:",miss," 源也0B:",zero," 源非0B:",nz)
  PY
  ```
  **DoD**：`源中找不到 = 0` 且 `源非0B = 0`（即 115/115 源文件也是 0B）
  **实测**：
  ```
  产物零字节 grp: 115
  源中找不到: 0
  源也 0B: 115
  源非 0B: 0
  ```
  ✅ **零字节来自 MOD 作者，构建工具无缺陷**

- [x] 6.2 76 / 39 拆分
  **DoD**：`D∩B = 76`（基线有非零贴图、MOD 清零）、`D∩C = 39`（MOD 新增空占位）
  **实测**：`D∩B: 76  D∩C: 39` ✅ 与 §5.1 同源输出

---

## 7 `ranger.str` 构建生成（REQ-PINV-7）

- [x] 7.1 源中不存在
  ```bash
  cd game && find ../reference/allmods/kys-pineapple -name 'ranger.str' | wc -l
  ```
  **DoD**：`0`
  **实测**：`0` ✅

- [x] 7.2 产物存在且格式正确
  **实测**：`21987B`、`648 行`、首行 `# ranger.str - MOD side string table (UTF-8)` ✅

---

## 8 两套口径分离（REQ-PINV-8）

- [x] 8.1 口径①与口径②数字关系
  **DoD**：`124 = 62 × 2`（文件数 vs 组数），且 B 类 90 个**不在** `diff.md` 中
  **实测**：
  ```
  diff.md added fight: 124
    addfight == C ? False（差异仅在 .idx：addfight 含 grp+idx，C 仅 grp）
    addfight - C: ['fight030.idx', ...]   ← 62 个 .idx
    C - addfight: []
  A 在 diff 中? []      ← fight000/fight015 完全无差异
  B 在 diff 中? 0       ← 90 个同名异容不在 diff
  ```
  ✅ 口径分离明确

---

## 9 报告产出（REQ-PINV-9）

- [x] 9.1 写 `reports/pineapple-verify.md`
  **DoD**：含 161 条差异分解 + 四象限 `2/90/62/115` + 三分类 `18/3/0` +
  `15 IDENTICAL + 1 GENERATED`，每条附实测命令
  ✅

---

## 10 8 道门禁复跑（REQ-PINV-10）

| # | 命令 | 实测 | 判定 |
|---|------|------|:----:|
| 1 | `lua tests/test_runner.lua` | `总测试数: 1842 / 通过: 1842 / 失败: 0` | ✅ |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `PASS`，`mismatches=0` | ✅ |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures`（退出码 1 属设计） | ✅ |
| 4 | `lua tools/mod_check.lua` | `通过 20, 失败 0` | ✅ |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`；`failed=0` | ✅ |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` | ✅ |
| 7 | 门禁 7 脚本 | `槽=341 模板=110 合计=451`，真实问题 0 | ✅ |
| 8 | 三禁改路径 + `jyconst.lua` | 全空；无 `CC.*=` 增删 | ✅ |

---

## 11 文档同步

- [x] 11.1 `verification.md` 记录实测
- [x] 11.2 `reports/pineapple-verify.md` 人读报告
- [x] 11.3 `allmods-slice12/change-manifest.md` 勾选
- [x] 11.4 `epic.md` Slice 12 段落
- [x] 11.5 `TODO.md` pineapple `[x]`

---

## Blast Radius

| 路径 | 允许 | 实际 |
|------|:----:|------|
| `openspec/changes/allmods-pineapple-verify/**` | ✅ 写 | 全部 |
| `openspec/changes/allmods-slice12/**` | ✅ 写 | manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic.md / TODO.md |
| `game/mods/pineapple/**` | ⚠ 只读 | 未改 |
| `game/tools/**` | ❌ | 未改 |
| `game/engine-love2d/**`、`game/engine-mud/**` | ❌ | `git status` 空 |
| `game/script/jyconst.lua` 常量 | ❌ | 无 `CC.*=` 增删 |
| `reference/allmods/**` | ❌ 只读 | `git status` 空 |
