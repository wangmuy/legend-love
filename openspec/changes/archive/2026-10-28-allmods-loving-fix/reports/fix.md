---
status: done
created: 2026-10-18
---

# 问情篇 (loving) — 确认修改

## 逆向结论（根因）

字段级数据完全干净；异常是 `kysmod.ini` 的 `BEGIN_SCENE = -1` / `BEGIN_EVENT = -1`。引擎执行 `JY.SubScene = CC.NewGameSceneID` 后索引 `JY.Scene[-1]` → 崩溃。

## 关键洞察

`-1` 在该 MOD 中表示「未设置」，语义上不应覆盖引擎默认值（70 / 691）。

## 修改清单

1. `game/framework/mod_ini.lua` 新增 `NON_NEGATIVE_KEYS` 守卫（`CC.NewGameSceneID`/`NewGameEvent`/`SoftStarBeginTalk`/`BeginLeaveEvent`）
2. `Map` 中当值为负时跳过映射（数据驱动，不按 MOD 名分支）

## 验证证据

- `ModIni.Load("mods/loving/data/kysmod.ini")`：`CC.NewGameSceneID=nil`、`CC.NewGameEvent=nil`（保留默认）
- 同一产物中 `SoftStarBeginTalk=2547`、`ItemBeginPic=3501` 正常生效
- `testLovingNegativeBeginSceneDoesNotCrash`、`testNegativeSceneIndexIgnored` 通过


## 修复前后量化对比（决定性证据）

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| `CC.NewGameSceneID` | **-1**（→ `JY.Scene[-1]` 崩溃） | 保留引擎默认 **70** |
| `CC.NewGameEvent` | **-1** | 保留引擎默认 **691** |
| `CC.SoftStarBeginTalk` | 2547 | 2547（正常生效） |
| `CC.ItemBeginPic` | 3501 | 3501（正常生效） |
| 字段级缺陷 | 0（本就干净） | 0 |

> 用真实产物 `ModIni.Load("mods/loving/data/kysmod.ini")` 验证：
> `parsed.CC.NewGameSceneID == nil`、`parsed.CC.NewGameEvent == nil`。

## 约束遵守

- **数据驱动**：无任何可执行代码按 MOD 名分支（仅有注释说明）。
- **文件大小不变**：20/20 MOD 源尺寸 vs 产物尺寸一致。
- **构建幂等**：连续两次 `mod_build.lua --all` 产物 md5 相同。
