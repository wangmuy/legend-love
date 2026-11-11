---
status: done
created: 2026-10-18
---

# 金庸水浒传dos版 (pig3dos) — 测试验证

## 测试模块

mod_encoding（跳过字段中和用例）

## 用例与结果

| 用例 | 断言内容 | 结果 |
|------|----------|------|
| `testConvertRangerSkipsNumericFields` | Person 外号 @18 判定为非字符串跳过（607 条）；姓名 @8 全部转换 |
| `（同一测试）` | Person 段恰好 1 个共享空字符串条目；Person[0] 外号槽位被写入可解析 hint `N0000` |
| `testSkippedFieldNeutralisedForAllMods` | 全 20 MOD 凡有跳过字段的段均被中和（命中 ptt/pineapple/dream/HeavenSword/GodsDevils/lyff/pig3dos） |
| `testFullBootChainForProblematicMods/pig3dos` | 独立进程真实启动：607/242/133/202，主角「主角」，扫描 2275 字段，0 U+FFFD、0 控制符 |

## 运行命令

```bash
cd game && rm -f active_mod.txt && lua tests/test_runner.lua          # 全量 364/364
cd game && lua tests/unit/test_mod_encoding.lua                        # mod_encoding 45/45
cd game && lua tests/unit/test_mod_ini.lua                             # mod_ini 81/81
cd game && lua tests/unit/boot_one_mod.lua pig3dos ...                  # 单 MOD 真实启动链路
cd game && rm -f active_mod.txt && lua tests/test_runner.lua mod_boot  # 5 MOD 启动链路（子进程）
```

## 结论

全部用例通过，且**真实启动链路**（独立进程 `lib.init → LoadRecord(0)`）验证
分段记录数、主角姓名与全量字符串合法性。**0 回归**：全 20 MOD 自检 20/20，
pascal 基线 PASS，全量测试 364/364。
