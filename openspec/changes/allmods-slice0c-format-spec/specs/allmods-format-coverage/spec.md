# Spec: allmods-format-coverage

> Change: `allmods-slice0c-format-spec` · Slice: `allmods-slice0c`
> 需求前缀：`REQ-FMT-*`（与 `proposal.md` 一一对应）

## 概述

为每种二进制格式定义**无缺口的字段表**，并以 `verifyCoverage()` 断言
`Σ(字段区间) == 文件大小`，从而保证"每个字节都被归类"。

---

## [REQ-FMT-1] 字段表完整覆盖，无缺口

#### Scenario: hdgrp 覆盖完整
- **GIVEN** `reference/allmods/kys-pascal/resource/hdgrp.idx`（460 字节）与 `hdgrp.grp`（249276 字节）
- **WHEN** `verifyCoverage("hdgrp.idx", SPEC.hdgrp.idx)` 与 `verifyCoverage("hdgrp.grp", SPEC.hdgrp.grp)`
- **THEN** 两者均 `ok=true`，`gaps={}`，且 `Σ(records) + tail == 249276`

#### Scenario: 20 MOD 的 hdgrp 均覆盖完整
- **GIVEN** 20 个 MOD 各自的 `hdgrp.idx`/`hdgrp.grp`
- **WHEN** `verifyAll()`
- **THEN** 20/20 `ok=true`，`gaps=0`

#### Scenario: 定长格式覆盖完整
- **GIVEN** `earth.002`（460800 字节）
- **WHEN** 验证
- **THEN** `Σ(字段) == 460800`，`gaps={}`

---

## [REQ-FMT-2] 缺口必须被报告

#### Scenario: 构造缺口被检测
- **GIVEN** 一个字段表 `{ {offset=0,size=100}, {offset=200,size=100} }` 与 300 字节文件
- **WHEN** `verifyCoverage`
- **THEN** `ok=false`，`gaps == {{start=100, end=200}}`

#### Scenario: 重叠被检测
- **GIVEN** 字段表 `{ {offset=0,size=150}, {offset=100,size=200} }` 与 300 字节文件
- **WHEN** `verifyCoverage`
- **THEN** `ok=false`，报告重叠区间

#### Scenario: 起始缺口被检测
- **GIVEN** 字段表首个字段 `offset=10`
- **WHEN** `verifyCoverage`
- **THEN** `ok=false`，`gaps` 含 `{start=0, end=10}`

#### Scenario: 尾部缺口被检测
- **GIVEN** 字段表覆盖到 `filesize - 5`
- **WHEN** `verifyCoverage`
- **THEN** `ok=false`，`gaps` 含 `{start=filesize-5, end=filesize}`

---

## [REQ-FMT-3] 变长记录族

#### Scenario: RLE 记录由 offset 表展开
- **GIVEN** `hdgrp.idx` 的 115 项 offset 表
- **WHEN** 展开 `records`
- **THEN** 得到 115 个区间 `[offsets[i], offsets[i+1])`，
  末项延伸到 `filesize`，`Σ == grpsize`

#### Scenario: 文本格式（talk）
- **GIVEN** `talk.idx`（11908 字节 = 2977 × 4）与 `talk.grp`（186513 字节）
- **WHEN** 验证
- **THEN** 2977 个文本区间覆盖完整，`tail == 0`

#### Scenario: 指令流格式（kdef）
- **GIVEN** `kdef.idx`（4072 字节 = 1018 × 4）与 `kdef.grp`（121214 字节）
- **WHEN** 验证
- **THEN** 1018 个指令流区间覆盖完整，`tail == 0`

#### Scenario: 无 .idx 后缀的 offset 表（sdx/smp）
- **GIVEN** `resource/sdx`（17472 字节 = 4368 × 4）与 `resource/smp`（4349778 字节）
- **WHEN** 验证
- **THEN** `sdx` 自身即 offset 表，4368 个区间覆盖 `smp` 完整，`tail == 0`

---

## [REQ-FMT-4] 多段 offset 表被识别

#### Scenario: mmap 两段
- **GIVEN** `mmap.idx`（34924 字节 = 8731 × 4）
- **WHEN** 检查 spec
- **THEN** 含 `seg1`（3731 项，offset 0）与 `seg2`（5000 项，offset 3731×4），
  且 `(3731 + 5000) * 4 == 34924`

#### Scenario: mmap 覆盖完整
- **GIVEN** `mmap.idx` 与 `mmap.grp`（1572545 字节）
- **WHEN** 验证
- **THEN** `ok=true`，`gaps={}`

---

## [REQ-FMT-5] 每个字段标注 `needed` 与 `consumer`

#### Scenario: 字段元数据完整
- **GIVEN** 任意 spec 中的任意字段
- **WHEN** 检查
- **THEN** 含 `needed`（bool）；`needed=true` 时含非空 `consumer`（引擎符号名）

#### Scenario: consumer 指向真实符号
- **GIVEN** `hdgrp.grp` 的 `rle_records` 字段 `consumer="lib_love.PicLoadFile"`
- **WHEN** 在 `game/engine-love2d/lib_love.lua` grep
- **THEN** 找到 `PicLoadFile` 定义

---

## [REQ-FMT-6] 20 MOD 全覆盖

#### Scenario: 全量验证无缺口
- **GIVEN** 20 个 MOD 的全部格式文件
- **WHEN** 运行 `lua tools/format_spec.lua --all`
- **THEN** 退出码 0，输出 `formats=<N> checked=<M> gaps=0`

#### Scenario: 覆盖的格式族齐全
- **GIVEN** 实测文件全集
- **WHEN** 统计被 spec 覆盖的格式族
- **THEN** ≥ 13 族：`idx_grp_rle`、`idx_grp_text`、`idx_grp_bytecode`、
  `bare_idx_grp`、`smap_grid`、`sta_table`、`palette`、`bin_table`、
  `ini_kv`、`ranger_seg`、`save_grid`、`wav_pcm`、`png_image`

---

## [REQ-FMT-7] 零回归

#### Scenario: 全量测试仍全绿
- **GIVEN** 本 change 已实施
- **WHEN** 运行 `cd game && lua tests/test_runner.lua`
- **THEN** 全部通过

#### Scenario: 构建与基线不受影响
- **GIVEN** 本 change 已实施
- **WHEN** 运行 `lua tools/mod_build.lua --all` 与 `--verify-pascal`
- **THEN** `0 build failures`，pascal baseline `PASS`
