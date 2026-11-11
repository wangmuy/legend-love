# Tasks: allmods-slice0c-format-spec

## 1. 覆盖验证核心

- [x] 1.1 实现区间物化：静态字段 + 动态展开（`from="offsets"`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 静态 `{offset,size}` 直接产出 `[start,end)`
    - [x] 动态 `{from,to}` 由 offset 表展开
    - [x] 末项延伸到 `filesize`

- [x] 1.2 实现 `verifyCoverage(path, spec)` → `ok, gaps`
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 排序后断言无重叠、无缺口、首起 0、末至 filesize
    - [x] 缺口以 `{start,end}` 列表返回
    - [x] 重叠单独报告

- [x] 1.3 实现 offset 表读取（uint32 LE）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 支持多段（`segments = {{offset,count},...}`）
    - [x] 断言 `Σ(段字节) == idx 文件大小`

## 2. 格式规格表

- [x] 2.1 `idx_grp_rle` 族：`hdgrp`、`eft`、`warfld`、`cloud`、`title`、`fight/*`
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] `idx` 规格 + `grp` 规格（`rle_header` + `records` + 强制 `tail`）
    - [x] `consumer` 指向 `lib_love.PicLoadFile` 等
    - [x] 实测 tail == 0

- [x] 2.2 `idx_grp_text`（`talk`）与 `idx_grp_bytecode`（`kdef`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 记录字段类型分别为 `text_big5`、`int16_stream`
    - [x] `consumer` 指向 `jymain.ReadTalk`、`kdef` 执行器

- [x] 2.3 `bare_idx_grp`（`sdx`/`smp`、`wdx`/`wmp`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] idx 无后缀，spec 声明 `idx_file="sdx"`, `grp_file="smp"`
    - [x] 与别名目标（`smap.idx`/`smap.grp`）对应关系注释

- [x] 2.4 `smap_grid`（`.002` × 5）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 字段拆到 `grid_cell` 级（uint16），不得用"rest"
    - [x] `Σ == 460800`（= MWidth × MHeight × 2）
    - [x] `consumer` 指向 `lib_love.LoadMMap_Sub`

- [x] 2.5 `sta_table`（`war.sta`）、`palette`（`mmap.col`）、`bin_table`（`list/*.bin`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] `war.sta`：`Σ == 26040`，`consumer` 指向 `jymain.WarLoad`
    - [x] `mmap.col`：768 字节 = 256 × RGB
    - [x] `list/*.bin`：字段拆到记录级（非"rest"）

- [x] 2.6 `ini_kv`（`kysmod.ini`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 按行区间覆盖，`Σ == 文件大小`
    - [x] `consumer` 指向 `framework.mod_ini`

- [x] 2.7 `ranger_seg`（`save/ranger.*`、`save/rN.*`）与 `save_grid`（`save/allsin.*`、`alldef.*`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] `ranger.idx` 6 段索引，段记录大小随 MOD 变化（读自 MOD 布局）
    - [x] `Σ(段记录) + 索引 == 文件大小`
    - [x] 覆盖原版（202/260/62/146）与 MOD（182/190/52/136）两种布局
    - [x] **（2026-10-28 补全）`save_grid`（allsin/alldef）与 `save_slot`（rN/sN/dN 共 9 槽）已注册**
      - 实测命令：`lua tools/format_spec.lua --all`
      - 实测输出：`formats=14 checked=6826 gaps=0`（补全前 `formats=12 checked=6773`）
      - 新增覆盖：allsin 14 + alldef 14 + r1..3 10 + s1..3 9 + d1..3 6 = **53 个格式实例**
      - 配套断言：`testSaveGridRegistered` / `testSaveSlotRegistered` /
        `testSaveFamilyCoverageNoGaps` / `testHeavenSwordOrphanSaveIdx` /
        `testSaveFamilyCountIncreased`

  > **勘误（2026-10-28）**：本节初版被标为 `[x]` 但 `save_grid` **实际未实现**——
  > `FORMATS` 表只注册了 `ranger`，源侧 `save/` 的 451 个文件中 **411 个**
  > （allsin 34 / alldef 34 / rN·sN·dN 335 / save.zip 1 / ranger-副本 1 等）
  > 从未做过字段级覆盖验证。补全时复用既有 `verifyPair`（三者与 ranger 同为
  > uint32 offset 表 + 分段负载），**无需新解析器**，证明缺口是「注册遗漏」而非
  > 「能力缺失」。补全过程另抓到 1 个真实 MOD 打包残留：
  > `kys-HeavenSword/save/r1.idx`（24B，内容与 `ranger.idx` 逐字节相同）
  > 有 idx 无 grp，已与 `fight/` 同约定归为 `ORPHAN_IDX` 而非缺口。

- [x] 2.8 `wav_pcm`（`sound/*.wav`）与 `png_image`（PNG 族）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] WAV：RIFF chunk 遍历，`Σ(chunks) == 文件大小`
    - [x] PNG：IHDR/IDAT/IEND chunk 遍历，`Σ == 文件大小`

## 3. 批量验证

- [x] 3.1 实现 `verifyAll()`：20 MOD × 全部格式
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] 输出 `formats=<N> checked=<M> gaps=0`
    - [x] 任一缺口 → 收集并最终 `os.exit(1)`

- [x] 3.2 CLI 入口（`--all`、`--format <name>`）
  Blast Radius: `["game/tools/format_spec.lua"]`
  DoD:
    - [x] `--all` 全量验证
    - [x] `--format hdgrp` 单格式

## 4. 测试

- [x] 4.1 `test_format_spec.lua`：20 MOD 全格式覆盖
  Blast Radius: `["game/tests/unit/test_format_spec.lua"]`
  DoD:
    - [x] 每格式至少 1 个 MOD 断言 + 抽样全量
    - [x] 全部 `ok=true`

- [x] 4.2 负例：缺口/重叠/起始/尾部缺口均被报告
  Blast Radius: `["game/tests/unit/test_format_spec.lua"]`
  DoD:
    - [x] 4 个负例场景（对应 REQ-FMT-2 的 4 个 Scenario）

- [x] 4.3 `mmap` 多段断言
  Blast Radius: `["game/tests/unit/test_format_spec.lua"]`
  DoD:
    - [x] `seg1=3731`、`seg2=5000`，`Σ×4 == 34924`

- [x] 4.4 `consumer` 符号可解析
  Blast Radius: `["game/tests/unit/test_format_spec.lua"]`
  DoD:
    - [x] 对每个 `needed=true` 字段的 `consumer`，在源码 grep 到定义

- [x] 4.5 注册进 `test_runner.lua`
  Blast Radius: `["game/tests/test_runner.lua"]`
  DoD:
    - [x] `require` + `runAll` + `runModule` 分支

## 5. 验证

- [x] 5.1 跑 `lua tools/format_spec.lua --all`，确认 `gaps=0`
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] 退出码 0

- [x] 5.2 跑全量测试与构建基线
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] `test_runner.lua` 全绿；`--all` 0 failures；`--verify-pascal` PASS

- [x] 5.3 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-slice0c-format-spec/verification.md"]`
  DoD:
    - [x] 含 REQ 追溯矩阵（FMT-1~7）
    - [x] 含每格式覆盖实测表
    - [x] 含 Blast Radius 合规检查
