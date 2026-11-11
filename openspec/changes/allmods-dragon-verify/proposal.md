---
status: done
created: 2026-10-25
---

# Proposal: allmods-dragon-verify

> 父上下文：epic [`2026-10-allmods-compat`](../../epics/2026-10-allmods-compat/epic.md)，
> slice [`allmods-slice11`](../allmods-slice11/slice-proposal.md)，
> 姊妹 change [`allmods-dragon-activate`](../allmods-dragon-activate/proposal.md)。
>
> 本 change 对 Dragon 做**独立复核**：逐条审计 `diff.md`、证明 MOD 内容确实加载、
> 定性 25 项「基准独有」、量化范围外发现、复跑全部门禁。

## 1. 为什么需要独立的 verify change

activate 已证明「构建成功 + 启动成功 + 数据段正确」。但前 10 个 slice 的教训是：
**「记录数对」不等于「内容对」**。verify 的职责是把「MOD 数据真的进了运行时」
从**间接推断**变成**直接证据**，并对 `diff.md` 每一行负责。

Dragon 的额外必要性：

1. **254 项 MOD 独有**中 238 项是 fight（119 对 `.grp`/`.idx`），16 项非 fight ——
   需确认非 fight 16 项各自真的被引擎使用，而非「构建产生了但没人读」。
2. **`name.grp`/`name.idx` 被构建复制进 `data/`**（211697B / 16080B，与 `talk.grp`
   **md5 完全相同**），但审计归类为 `LEGACY`（引擎 0 引用）—— 必须解释「物理存在但逻辑不需要」。
3. **25 项「基准独有」首次出现第 5 类（E 类：数据引用但资源缺失）**。
4. **`war1.sta` 是本 epic 首个由审计规则标注的 `DEAD_FILE`**。
5. **`not_in_product` 语义首次被证伪**：4 项被标 `not_in_product` 的文件**物理存在于产物**
   （`name.grp`/`name.idx`/`talkutf8.txt`/`war1.sta`）—— 这是工具的**语义不精确**，
   必须记录并给出正确解读，否则后续 slice 会误判。

## 2. In Scope

- `diff.md` 逐项审计：254 项 MOD 独有 / 25 项基准独有，逐项给结论。
- MOD 内容真实性证明：Record 边界值、`kdef` 事件、`talk` 文本、`kysmod.ini` 常量覆盖。
- 25 项「基准独有」五分法（A/B/C/D/**E**）定性。
- 范围外发现：`not_in_product` 语义不精确、`name.*` 重复文件、`war1.sta` 双类别。
- 全量门禁复跑。
- `reports/dragon-verify.md` 六章节报告。
- 零回归。

## 3. Out of Scope

- Slice 12-13（pineapple / books）。
- 修复 `not_in_product` 语义（会改审计工具契约，属独立 change）。
- `music/*.mid` / `list/*.bin` 全局遗留 spike。
- 引擎改动。

## 4. 需求

### REQ-DRGV-1 `diff.md` 双向 set 相等 + 254 项逐项审计
254 = **238 fight**（119 `.grp` + 119 `.idx`）+ **16 非 fight**。
`diff.md` 的「MOD 独有 / 基准独有」列表必须与实测差集**双向 set 相等**
（非仅计数相等）；非 fight 16 项须逐项给出字节一致性与引擎消费者。

### REQ-DRGV-2 25 项「基准独有」五分法
A 9 / B 9 / C 2 / D 1 / **E 4** = 25。每类须有可执行判据；
B 类须证明播种源是 MOD 的 `ranger.idx`（非基线）；E 类须证明数据引用与资源缺失并存。

### REQ-DRGV-3 MOD 内容真实性（不只计数）
四类直接证据：Record 边界值（8 个）、`kdef` 事件 1087 个且结构合法、
`talk` 4020 条且首尾可读、`kysmod.ini` 常量覆盖生效（**10 项**基线为 `nil` 的常量跳变）。
另须做 **Scene 内容负对照**（记录数同为 106 但内容不同）。

### REQ-DRGV-4 `not_in_product` 语义修正（范围外发现）
`not_in_product` 是**类别决定**（`IN_PRODUCT_BY_CATEGORY`）而非物理存在性。
必须列出本 MOD 的 4 项「被标 not_in_product 但物理存在」并给出正确解读。

### REQ-DRGV-5 `name.*` 重复文件定性
`resource/name.grp`/`name.idx` 与 `resource/talk.grp`/`talk.idx` **md5 完全相同**；
`name.*` 归 `LEGACY`（引擎 0 引用）但被构建复制到 `data/`。须给出证据与结论。

### REQ-DRGV-6 `war1.sta` 双类别一致性
`war1.sta` 同时是「审计 `DEAD_FILE`」与「`diff.md` MOD 独有 16 项之一」。
须证明两处判定**不矛盾**，并说明它与 RiverLake `allsinbk.grp` 的本质区别
（「新增的死文件」vs「回退到的死文件」）。

### REQ-DRGV-7 `fight101`/`fight102` 缺失的优雅降级（**须带正对照**）
MOD 删除这两个战斗贴图但 `Person` 仍引用头像代号 101/102。
须实测三级降级路径，且必须用存在的 `fight103` 作正对照，
否则无法区分「降级生效」与「测量方法本身失效」。

### REQ-DRGV-8 `cloud/title/open/end` 归类保守（范围外发现）
这 6 个文件被标 `REQUIRED` 但 Lua 引擎**无运行时消费者**；
须证明归类来自 `BY_KIND` 兜底，并量化影响（20/20 覆盖）。

### REQ-DRGV-9 `hdgrp` 267 条目索引驱动
`hdgrp.idx` 1068B ÷ 4 = 267（基线 115），须证明由索引驱动、无固定计数常量。

### REQ-DRGV-10 全量门禁复跑（含门禁 7 口径修正）
8 道门禁全部实跑。门禁 7（20 MOD `save/` vs 源）须区分
**逐字节一致**与**设计内转换**（`ranger.grp`×20 Big5→UTF-8+hint、`ranger.idx`×1 重建），
不得笼统宣称「451 文件不一致 = 0」。

### REQ-DRGV-11 报告
`reports/dragon-verify.md` 六章节齐备，且每条数字可复跑；
`verification.md` 逐 REQ 记录实测结果与**对 activate 初稿的偏差修正**。

## 5. Blast Radius

| 路径 | 允许 |
|------|:----:|
| `openspec/changes/allmods-dragon-verify/**` | ✅ 写 |
| `openspec/changes/allmods-slice11/**`、`openspec/epics/**` | ✅ 写 |
| `game/mods/Dragon/**` | ✅ 写（实验后须恢复） |
| `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量定义、`reference/allmods/**` | ❌ 禁 |
