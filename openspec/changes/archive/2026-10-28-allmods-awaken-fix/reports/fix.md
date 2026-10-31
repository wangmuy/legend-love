---
status: done
created: 2026-10-18
---

# 真龙苏醒 (awaken) — 确认修改

## 逆向结论（根因）

Thing 段 6 个字段含控制符，其中 r89 是**内部** CRLF（`七傷拳\r\n譜`），r187 是孤立 `\r`。

## 关键洞察

内部 CRLF 证明修复必须**折叠删除**所有 CR/LF，而不能只剥尾部。

## 修改清单

1. 与 BookCalamity 共用 `M.TrimControl`（内部 + 尾部 CR/LF 一并处理）

## 验证证据

- `testTrimControlInteriorCrLf`：`七傷拳\r\n譜` → `七傷拳譜`
- `testConvertRangerNoControlCharsAllMods` 覆盖 awaken


## 修复前后量化对比（决定性证据）

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 含真 CR/LF 的字节出现次数 | **11** | **0** |
| 引擎启动链路读到控制符 | 有 | **0** |

> 修复前样例（hex，均为**内部** CRLF，证明不能只剥尾）：
> - `Thing.Name  r88 = b6b7c0b1a473afabb4780d0a`（`破壞王拳\r\n`）
> - `Thing.Name  r89 = a443b6cbaeb10d0ac3d0`（`七傷拳\r\n譜` ← 内部 CRLF）

## 约束遵守

- **数据驱动**：无任何可执行代码按 MOD 名分支（仅有注释说明）。
- **文件大小不变**：20/20 MOD 源尺寸 vs 产物尺寸一致。
- **构建幂等**：连续两次 `mod_build.lua --all` 产物 md5 相同。
