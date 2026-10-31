---
status: done
created: 2026-10-18
---

# 魏征传奇 (zheng) — 测试验证

## 测试模块

mod_encoding（41→45 断言）

## 用例与结果

| 用例 | 断言内容 | 结果 |
|------|----------|------|
| `testRepairIdxDetectsZhengLayout` | RepairIdx 从文件大小推导出精确 idx `836,59076,97076,101444,114092,114242` |
| `testRepairIdxLeavesGoodIdxUntouched` | 已正确打包的 MOD（pascal）不被触碰，reason=nil |
| `testDetectLayoutZhengExact` | DetectLayout 对 zheng 精确命中 6 个段边界 |
| `testIdxIsConsistentRejectsOvershoot` | idx 末值 138596 > grp 114242 被判定不一致 |
| `testFullBootChainForProblematicMods/zheng` | 独立进程真实启动：320/200/84/93，主角「小蝦米」，扫描 1417 字段，0 U+FFFD、0 控制符 |

## 运行命令

```bash
cd game && rm -f active_mod.txt && lua tests/test_runner.lua          # 全量 364/364
cd game && lua tests/unit/test_mod_encoding.lua                        # mod_encoding 45/45
cd game && lua tests/unit/test_mod_ini.lua                             # mod_ini 81/81
cd game && lua tests/unit/boot_one_mod.lua zheng ...                  # 单 MOD 真实启动链路
cd game && rm -f active_mod.txt && lua tests/test_runner.lua mod_boot  # 5 MOD 启动链路（子进程）
```

## 结论

全部用例通过，且**真实启动链路**（独立进程 `lib.init → LoadRecord(0)`）验证
分段记录数、主角姓名与全量字符串合法性。**0 回归**：全 20 MOD 自检 20/20，
pascal 基线 PASS，全量测试 364/364。
