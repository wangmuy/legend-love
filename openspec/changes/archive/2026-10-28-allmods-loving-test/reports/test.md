---
status: done
created: 2026-10-18
---

# 问情篇 (loving) — 测试验证

## 测试模块

mod_ini（NON_NEGATIVE_KEYS 守卫）

## 用例与结果

| 用例 | 断言内容 | 结果 |
|------|----------|------|
| `testLovingNegativeBeginSceneDoesNotCrash` | `BEGIN_SCENE=-1`/`BEGIN_EVENT=-1` 被忽略 → 引擎保留默认 70/691 |
| `（同一测试）` | 正值仍生效：SoftStarBeginTalk=2547、ItemBeginPic=3501 |
| `testModIniNegativeValuesSkipped` | 非负键守卫对全 4 个键生效 |
| `testFullBootChainForProblematicMods/loving` | 独立进程真实启动：320/200/84/93，主角「莫言」，扫描 1417 字段，0 U+FFFD、0 控制符 |

## 运行命令

```bash
cd game && rm -f active_mod.txt && lua tests/test_runner.lua          # 全量 364/364
cd game && lua tests/unit/test_mod_encoding.lua                        # mod_encoding 45/45
cd game && lua tests/unit/test_mod_ini.lua                             # mod_ini 81/81
cd game && lua tests/unit/boot_one_mod.lua loving ...                  # 单 MOD 真实启动链路
cd game && rm -f active_mod.txt && lua tests/test_runner.lua mod_boot  # 5 MOD 启动链路（子进程）
```

## 结论

全部用例通过，且**真实启动链路**（独立进程 `lib.init → LoadRecord(0)`）验证
分段记录数、主角姓名与全量字符串合法性。**0 回归**：全 20 MOD 自检 20/20，
pascal 基线 PASS，全量测试 364/364。
