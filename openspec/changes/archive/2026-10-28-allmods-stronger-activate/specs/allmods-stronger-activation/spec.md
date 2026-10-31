# Spec: allmods-stronger-activation

> Change: `allmods-stronger-activate` · Slice: `allmods-slice3` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-STR-1 ~ REQ-STR-6

## REQ-STR-1: 构建成功

**Given** `reference/allmods/kys-stronger/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-stronger`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/stronger/data/`（221 个文件）
- `game/mods/stronger/script/oldevent/`（1018 个 `.lua`）
- `game/mods/stronger/script/oldtalk.grp` + `oldtalk.idx`（3727 条）
- `game/mods/stronger/save/`（6 个槽）
- `game/mods/stronger/sound/`（78 个文件）
- `game/mods/stronger/diff.md`

**And** `kysmod.ini` 被解析为 `CONFIG`/`CC` 覆盖，**不**复制到产物。

## REQ-STR-2: 逐文件穷举归类

**Given** stronger 的源目录
**When** 运行 `cd game && lua tools/mod_audit.lua --mod stronger`
**Then** 输出 `total=335 in_product=304 not_in_product=31 unclassified=0 bad_evidence=0`

**And** 类别分布：
| 类别 | 数 |
|------|--:|
| `REQUIRED` | 300 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 3 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |
| **Σ** | **335** |

**And** 「必需但未进产物」矛盾数 = 0。

## REQ-STR-3: 字节级覆盖

**Given** stronger 的产物二进制文件
**When** 运行 `cd game && lua tools/format_spec.lua --mod stronger`
**Then** 输出 `formats=12 checked=196 gaps=0`

**And** 每个字节归入具名字段，无「rest-only」字段。

## REQ-STR-4: 真实启动链路

**Given** 独立子进程，`active_mod.txt` 内容为 `stronger`
**When** 运行 `cd game && lua tests/unit/boot_one_mod.lua stronger 320 200 84 93 韋大寶`
**Then** 输出 `RESULT stronger: OK`

**And** 16 项断言全 PASS：
- `lib.init` / `JYMainAdapter.init` 无报错
- `CC.PersonSize=182` / `CC.ThingSize=190` / `CC.SceneSize=52` / `CC.WugongSize=136`
- `PersonNum=320` / `ThingNum=200` / `SceneNum=84` / `WugongNum=93`
- 主角姓名 = 韋大寶
- 扫描字段数 > 100
- 无 U+FFFD（0）
- 无控制符（0）
- 10 帧无报错

## REQ-STR-5: MOD 独有内容加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | stronger | pascal 基线 | 区分度 |
|------|----------|------------|--------|
| 主角姓名 | 韋大寶 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 程靈素 | （不同） | ✅ |

**And** 资源路径全部指向 `mods/stronger/`：
- `CC.MMAPPicFile[1]` = `mods/stronger/data/mmap.idx`
- `CC.TalkGrpFile` = `mods/stronger/script/oldtalk.grp`
- `CC.WarFile` = `mods/stronger/data/war.sta`

**And** 对话条目数 = 3727（与 pascal 2977 不同，有区分度）。

## REQ-STR-6: 零回归

**Given** 本 change 完成后
**When** 运行全部门禁
**Then**：

| 门禁 | 期望 |
|------|------|
| `lua tests/test_runner.lua` | 全绿 |
| `lua tools/mod_build.lua --verify-pascal` | `mismatches=0` |
| `lua tools/mod_build.lua --all` | `0 build failures` |
| `lua tools/mod_check.lua` | 20/20 |
| `lua tools/mod_audit.lua --all` | `unclassified=0` |
| `lua tools/format_spec.lua --all` | `gaps=0` |
