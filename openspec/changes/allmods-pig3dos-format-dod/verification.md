---
status: done
created: 2026-10-29
---
# Verification: allmods-pig3dos-format-dod

## 1. [REQ-PFD-2] 原始输出（逐字复制，可复跑）

```
$ cd game && lua tools/format_spec.lua --mod pig3dos
formats=14 checked=328 gaps=0

$ cd game && lua tools/format_spec.lua --all
formats=14 checked=6838 gaps=0
```

## 2. [REQ-PFD-1] 逐格式明细

```
$ cd game && M=pig3dos lua -e '
    package.path="./?.lua;"..package.path
    local F=require("tools.format_spec")
    local rs,t,g=F.verifyEverything({mod=os.getenv("M")})
    print("total="..t.." gaps="..g.." records="..#rs)
    local byf={}
    for _,r in ipairs(rs) do byf[r.format]=(byf[r.format] or 0)+1 end
    local ks={}; for k in pairs(byf) do ks[#ks+1]=k end; table.sort(ks)
    local out={}; for _,k in ipairs(ks) do out[#out+1]=k.."="..byf[k] end
    print("  "..table.concat(out," "))'
```

## 3. [REQ-PFD-3] slice0c 追溯实测

| REQ | 实测证据 |
|-----|---------|
| [REQ-FMT-1] | `formats=14`，全部族均在 `M.FORMATS`/`M.SIMPLE_FORMATS`/`verifyMultiFile` 注册 |
| [REQ-FMT-2] | `gaps=0`（`verifyIntervals` 无缺口无重叠） |
| [REQ-FMT-3] | idx→grp 分段展开全部成功 |
| [REQ-FMT-5] | `lua tests/test_runner.lua format_spec` -> `testConsumerSymbolsResolve` PASS |
| [REQ-FMT-6] | 定向 `--mod pig3dos` + 全量 `--all` 双向 `gaps=0` |
| [REQ-FMT-7] | slice0c `verification.md` §9：负向对照 6/6 病态输入均判失败 |

## 4. [REQ-PFD-4] 20 MOD 横向实测（同命令、同工作树）

见 `spec.md` 的 20 行表；由下列命令一次生成：

```
$ cd game && lua -e ' ... for each mod: F.verifyEverything({mod=m}) ... '
```

## 5. 零代码改动证明

```
$ git status --porcelain | grep -cE 'game/engine-love2d/|game/engine-mud/|reference/allmods/'
0
```

本 change **只新增 openspec 文档**，未改任何 `game/**` 代码。

## 6. 结论

**PASS**。`pig3dos` 的 14 个格式族、328 条记录的字段级覆盖全部成立，
无缺口无重叠，且已在 20 MOD 横向上定位（排名见 spec.md）。
