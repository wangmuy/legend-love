---
status: done
created: 2026-10-17
---

# allmods-encoding-convert — MOD 数据 Big5 → UTF-8 转换 + 记录布局适配

## 父上下文

- Epic: [2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md)
- Slice: [allmods-slice1](../allmods-slice1/slice-proposal.md)（本 change 补齐 slice1 遗留的编码/布局硬阻塞）
- 前置: [allmods-build-pipeline](../allmods-build-pipeline/proposal.md)、[allmods-data-fallback](../allmods-data-fallback/proposal.md)

## 背景

allmods 系列 MOD（`kys-*`）与原版（`kys-pascal`）有 **两个独立的硬阻塞**：

1. **记录布局不同**：MOD 的 `ranger.grp` 记录大小与原版不同（Person 202→182、
   Thing 260→190、Scene 62→52、Wugong 146→136、Shop 30→50）。
   用原版 `CC.*Size` 读取会算出错误记录数并读到错位数据
   （mingdong 实测 PersonNum 569 vs 真实 632，姓名乱码）。
2. **字符串编码不同**：MOD 字符串为 **Big5**，引擎依赖 LÖVE 默认 **UTF-8** 渲染。
   定长字段装不下 UTF-8 形式——实测 20 个 MOD 共 34174 个字段，
   **13335 个（41%）UTF-8 超长**，原地转换必然截断。

### 为什么不能简单截断

用户要求 **保留原 MOD 的简繁体（不做繁→简）且不得有内容截断或遗漏**。
`雪山飛狐`（12 字节 UTF-8）放不进 10 字节字段——截断会丢失数据。

## In Scope

1. **构建期 Big5 → UTF-8 转换（方案 D：旁路字符串表）**
   - `ranger.grp` 字符串区替换为固定宽度 **hint**（`P0002`、`TD0007` …），数值区一字不改；
   - 文件大小保持不变（零偏移风险）；
   - 真实 UTF-8 值写入旁路表 `data/ranger.str`（按段分组、去重、保留繁体）；
   - 每 MOD 产出 `encoding-report.md`（转换数 / 去重数 / 截断数 / 溢出数）。
2. **记录布局适配**：MOD 激活时覆盖 `CC.PersonSize`/`ThingSize`/`SceneSize`/`WugongSize`/`ShopSize`
   与 `CC.Person_S`/`Thing_S`/`Scene_S`/`Wugong_S` 字段偏移表。
3. **运行时读取链**：`GetDataFromStruct` 字符串分支 = `rN.ovr` → `ranger.str` → 原始缓冲区（原版回退）。
4. **运行时写入链**：`SetDataFromStruct` 字符串分支写入存档覆盖表 `rN.ovr`（不写回 hint 占位）。
5. **零回归**：未激活 MOD 时所有新路径为空操作，原版行为逐字节一致。

## Out of Scope

- 繁 → 简转换（用户明确不做；保留 MOD 原有简繁体）。
- 变长记录（`ranger.idx` 的 6×uint32 格式无法描述变长记录，故不改记录布局）。
- 非 `ranger.grp` 的 Big5 数据（`fight/*.grp`、`resource/war.sta` 等）——
  经扫描确认为无字符串或与显示无关，留待后续 change。
- 修改 MOD 源数据本身（`reference/allmods/` 只读）。

## 需求

### [REQ-ENC-1] 构建期转换不得截断

转换后 `ranger.grp` 大小必须与源文件逐字节长度相同，且**零字段截断**。

- Given MOD `ranger.grp` 中某字段 UTF-8 形式超出字段宽度
- When 构建期转换
- Then 该字段内容完整写入 `ranger.str`，`ranger.grp` 中该位置为 hint

### [REQ-ENC-2] hint 唯一且可解析

每个 hint = 类别前缀 + 段内 4 位十进制 index，段内 index 上界必须 < 10000。

- Given 某段有 N 个字符串字段
- When 生成 hint
- Then 每个 hint 唯一，且 `index <= 9999`；超出则构建失败

### [REQ-ENC-3] 保留原 MOD 简繁体

不得做繁 → 简转换。

- Given 原值为繁体 `雪山飛狐`
- When 转换
- Then 旁路表值为 `雪山飛狐`（非 `雪山飞狐`）

### [REQ-ENC-4] 记录布局适配

MOD 激活时记录数与字段偏移必须按 MOD 布局计算。

- Given mingdong 激活
- When `LoadRecord(0)`
- Then `PersonNum=632`、`ThingNum=367`、`SceneNum=139`、`WugongNum=220`

### [REQ-ENC-5] 字符串读取链

- Given MOD 激活且存在旁路表
- When 读取字符串字段
- Then 优先 `rN.ovr` → `ranger.str` → 原始缓冲区

### [REQ-ENC-6] 字符串写入链

- Given MOD 激活，玩家修改字符串（如改名）
- When 保存存档
- Then 变化写入 `rN.ovr`，且重新读档得到新值

### [REQ-ENC-7] 零回归

- Given 未激活 MOD
- When 运行全量测试
- Then 全部通过，且 pascal 基线 `--verify-pascal` PASS

## 跟踪 ID

| ID | 说明 | 状态 |
|---|---|---|
| REQ-ENC-1 | 构建期零截断 | ✅ |
| REQ-ENC-2 | hint 唯一 < 10000 | ✅ |
| REQ-ENC-3 | 保留简繁体 | ✅ |
| REQ-ENC-4 | 记录布局适配 | ✅ |
| REQ-ENC-5 | 读取链 | ✅ |
| REQ-ENC-6 | 写入链 | ✅ |
| REQ-ENC-7 | 零回归 | ✅ |
