# Tasks — allmods-loving-test

## Blast Radius

允许修改/新增的文件路径：

- `game/tests/unit/test_mod_encoding.lua`
- `game/tests/unit/test_mod_ini.lua`
- `game/tests/test_runner.lua`
- `openspec/changes/allmods-slice-loving/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T3.1 新增 `testNegativeSceneIndexIgnored`（-1 忽略、正数生效）
- [x] T3.2 在 `test_mod_ini.lua` 的 `runAll` 注册
- [x] T3.3 **真实启动链路**（独立进程）：`boot_one_mod.lua loving` → 320/200/84/93，
      主角「莫言」，扫描 1417 字段，0 U+FFFD、0 控制符，10 帧无报错
- [x] T3.4 `testLovingNegativeBeginSceneDoesNotCrash`：`ModIni.Load` 真实产物
      确认 `-1` 被忽略（nil）、正值 `SoftStarBeginTalk=2547`/`ItemBeginPic=3501` 生效

## 测试报告

详见 [`reports/test.md`](reports/test.md)。

## Definition of Done

- [x] 修复已验证且无回归
