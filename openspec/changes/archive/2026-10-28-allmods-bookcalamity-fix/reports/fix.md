---
status: done
created: 2026-10-18
---

# 天书劫 (BookCalamity) — 确认修改

## 逆向结论（根因）

MOD 作者把换行粘贴进定长字段，Thing 段 3 个字段尾部残留 CRLF（`0d 0a`），如 r196 物品说明 `大燕傳國玉璽\r\n`。

## 关键洞察

定长字段中的换行无语义，必须删除而非仅剥尾（awaken 存在内部 CRLF，证明不能只剥尾）。

## 修改清单

1. `game/tools/mod_encoding.lua` 新增 `M.TrimControl(raw)`：剥离尾部 C0 控制字节 + 折叠删除**内部** CR/LF
2. `M.ConvertRanger` 在 `DecodeBig5` 之前调用 `M.TrimControl`

## 验证证据

- `testTrimControlRealBookCalamityField`：真实字段 `大燕傳國玉璽` 从 `...0d0a` 还原
- `testConvertRangerNoControlCharsAllMods`：全 20 MOD 零控制符


## 修复前后量化对比（决定性证据）

对**未经构建的源数据** `reference/allmods/kys-BookCalamity/save/ranger.grp` 逐字段扫描
（Big5 感知：0x0d/0x0a 落在合法 Big5 trail 范围之外即为真换行）：

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 含真 CR/LF 的字节出现次数 | **1285** | **0** |
| 引擎启动链路读到控制符 | 有 | **0** |

> 修复前样例（hex）：
> - `Person.Name r120 = bef6004f0000bd0a70a8`（`bd0a` 为真 CR/LF）
> - `Thing.Desc r196 = ...a5c9c3a20d0a`（`大燕傳國玉璽\r\n`）

## 约束遵守

- **数据驱动**：无任何可执行代码按 MOD 名分支（仅有注释说明）。
- **文件大小不变**：20/20 MOD 源尺寸 vs 产物尺寸一致。
- **构建幂等**：连续两次 `mod_build.lua --all` 产物 md5 相同。
