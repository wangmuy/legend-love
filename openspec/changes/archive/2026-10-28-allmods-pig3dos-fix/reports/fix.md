---
status: done
created: 2026-10-18
---

# 金庸水浒传dos版 (pig3dos) — 确认修改

## 逆向结论（根因）

Person 段 `@18`（标准布局的「外号」槽位）在 pig3dos 中是 int16 数值 stat 数组，不含任何 Big5 高位字节；`@46` 同理（`ffffffff`）。原判据「首字节是 Big5 lead」会把 `?陽刀氣` 这类 ASCII 前缀字段误判为非字符串。

## 关键洞察

**字符串判据改为「字段含任意高位字节」（`hasHighByte`）**，一个判据同时修好「数值槽位」与「ASCII+Big5 混合字段」两个问题。

**追加修复（本轮启动链路新发现）**：跳过字段后原始数值字节仍留在 `.grp`，而引擎结构表仍把该偏移声明为字符串 → `Byte.getstr` 把 `07 00 07 00...` 当文本读出 → 565 个控制符。跳过的字段必须写入解析为 `""` 的 hint 中和槽位。

## 修改清单

1. `M.ConvertRanger` 字符串守卫改为 `raw ~= "" and hasHighByte(raw)`
2. **新增**：跳过字段时写入共享空 hint（`side.__meta[seg][i].empty=true`），`.grp` 中写 `N0000` 等可解析 hint
3. `game/tools/mod_build.lua` 使用同一判据

## 验证证据

- `testConvertRangerSkipsNumericFields`：skipped=607、Person.converted=607、外号槽位=`N0000`
- `testSkippedFieldNeutralisedForAllMods`：全 20 MOD，命中 ptt/pineapple/dream/HeavenSword/GodsDevils/lyff/pig3dos，全部中和
- 真实启动链路 2275 字段 0 控制符（修复前 565）


## 修复前后量化对比（决定性证据）

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| Person 外号槽位（@18）含控制字节的记录数 | **565** | **0** |
| 引擎启动链路读到控制符 | **565** | **0** |

> 根因：外号槽位在 pig3dos 中是 int16 stat（`07 00 07 00 07 00 0a 00 00 00`），
> 不含任何 Big5 高位字节 → 构建期正确跳过转换。但**原始字节留在 `.grp`**，
> 引擎结构表仍把该偏移声明为字符串 → `Byte.getstr` 把二进制当文本。
> 修复：跳过的字段写入解析为 `""` 的 hint（`N0000`）中和槽位。

## 约束遵守

- **数据驱动**：无任何可执行代码按 MOD 名分支（仅有注释说明）。
- **文件大小不变**：20/20 MOD 源尺寸 vs 产物尺寸一致。
- **构建幂等**：连续两次 `mod_build.lua --all` 产物 md5 相同。
