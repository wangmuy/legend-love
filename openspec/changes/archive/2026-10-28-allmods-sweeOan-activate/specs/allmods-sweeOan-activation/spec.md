# Spec: allmods-sweeOan-activation

> Change: `allmods-sweeOan-activate` · Slice: `allmods-slice2` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-SWEE-1 ~ REQ-SWEE-6

## REQ-SWEE-1: 构建成功

**Given** `reference/allmods/kys-SweeOan/` 存在且完整
**When** 执行 `lua tools/mod_build.lua kys-SweeOan`
**Then** 退出码为 0，且输出包含 `events=1018`

**And** 产物目录包含：
- `game/mods/SweeOan/data/`（220 个文件）
- `game/mods/SweeOan/script/`（`oldevent/` 1018 个 + `oldtalk.grp`/`.idx`）
- `game/mods/SweeOan/save/`（6 个存档槽）
- `game/mods/SweeOan/sound/`（78 个音效）
- `game/mods/SweeOan/diff.md`

## REQ-SWEE-2: 逐文件穷举归类完整

**Given** SweeOan 构建完成
**When** 执行 `lua tools/mod_audit.lua --mod SweeOan`
**Then** 输出 `total=334`、`unclassified=0`、`bad_evidence=0`

**And** 类别分布为：
| 类别 | 文件数 |
|------|-------:|
| `REQUIRED` | 298 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 4 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |

**And** **不存在「必需类但未进产物」矛盾**：
对每个 `in_product=false` 的记录，`IN_PRODUCT_BY_CATEGORY[category]` 必须为 `false`/`nil`。

## REQ-SWEE-3: 字节级覆盖无缺口

**Given** SweeOan 构建完成
**When** 执行 `lua tools/format_spec.lua --mod SweeOan`
**Then** 输出 `formats=12 checked=196 gaps=0`

**And** 每个被检查文件的字节被区间集合完全覆盖（首起 0、末至 filesize、无重叠）。

## REQ-SWEE-4: 真实启动链路通过

**Given** SweeOan 构建完成
**When** 在独立进程中执行 `lua tests/unit/boot_one_mod.lua SweeOan 320 200 84 93 王小石`
**Then** 输出 `RESULT SweeOan: OK`（0 个 FAIL）

**And** 具体断言：
| 断言 | 期望 |
|------|------|
| `lib.init` | 无报错 |
| `JYMainAdapter.init` | 无报错 |
| `CC.PersonSize` | 182（MOD 布局） |
| `CC.ThingSize` | 190（MOD 布局） |
| `CC.SceneSize` | 52（MOD 布局） |
| `CC.WugongSize` | 136（MOD 布局） |
| `LoadRecord(0)` | 无报错 |
| `JY.PersonNum` | 320 |
| `JY.ThingNum` | 200 |
| `JY.SceneNum` | 84 |
| `JY.WugongNum` | 93 |
| `JY.Person[0]["姓名"]` | 王小石 |
| 扫描字段数 | > 100 |
| U+FFFD 计数 | 0 |
| 控制符计数 | 0 |
| 运行时 10 帧 | 无报错 |

## REQ-SWEE-5: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时资源路径与内容
**Then**：
- `CC.MMAPPicFile[1]` = `mods/SweeOan/data/mmap.idx`
- `CC.SMAPPicFile[1]` = `mods/SweeOan/data/smap.idx`
- `CC.WMAPPicFile[1]` = `mods/SweeOan/data/wmap.idx`
- `CC.TalkGrpFile` = `mods/SweeOan/script/oldtalk.grp`
- `CC.WarFile` = `mods/SweeOan/data/war.sta`

**And** MOD 独有内容：
- 对话条目数 = 2977
- `mods/SweeOan/script/oldevent/*.lua` = 1018 个
- `JY.Person[1]["姓名"]` = 衛悲回、`JY.Person[2]["姓名"]` = 伊小深（非 pascal 人物）

## REQ-SWEE-6: 零回归

**Given** 无 `active_mod.txt`
**When** 执行 `lua tests/test_runner.lua`
**Then** 全部测试通过

**And**：
- `lua tools/mod_build.lua --verify-pascal` → `events=1018 mismatches=0`
- `lua tools/mod_build.lua --all` → `0 build failures`
- `lua tools/mod_check.lua` → `20 MOD, 通过 20, 失败 0`
- `lua tools/mod_audit.lua --all` → `total=11220 unclassified=0`
- `lua tools/format_spec.lua --all` → `gaps=0`
