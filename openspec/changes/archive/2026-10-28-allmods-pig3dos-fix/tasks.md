# Tasks — allmods-pig3dos-fix

## Blast Radius

允许修改/新增的文件路径：

- `game/tools/mod_encoding.lua`（`ConvertRanger` 的字符串守卫）
- `game/tools/mod_build.lua`（若需）
- `openspec/changes/allmods-slice-pig3dos/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T2.1 守卫改为 `hasHighByte(raw)`
- [x] T2.2 重建全 20 MOD，确认 `mod_check.lua` 从 13/20 升到 20/20
- [x] T2.3 确认 pig3dos 外号槽位全部跳过（607 条），姓名全部转换
- [x] T2.4 **【启动链路新发现】** 跳过字段必须写入解析为 `""` 的 hint 中和槽位，
      否则原始 int16 字节仍被引擎 `Byte.getstr` 当字符串读出 → 565 个控制符。
      修复：`ConvertRanger` 为每个含跳过字段的段生成一个共享空条目（`side.__meta[seg][i].empty=true`），
      并在 `.grp` 中写入对应 hint（如 `N0000`）。
- [x] T2.5 新增回归测试：`testConvertRangerSkipsNumericFields` 断言外号槽位为可解析 hint、
      共享空条目恰好 1 个；`testSkippedFieldNeutralisedForAllMods` 断言全 20 MOD
      凡有跳过字段的段均被中和（实际命中 ptt/pineapple/dream/HeavenSword/GodsDevils/lyff/pig3dos）。
- [x] T2.6 真实启动链路验证（独立进程）：`boot_one_mod.lua pig3dos` →
      `LoadRecord(0)` 无报错，607/242/133/202，主角「主角」，扫描 2275 字段，
      **0 U+FFFD、0 控制符**，运行时 10 帧无报错。

## 修改报告

详见 [`reports/fix.md`](reports/fix.md)。

## Definition of Done

- [x] 修复已验证且无回归
