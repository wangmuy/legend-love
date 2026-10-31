# Tasks: allmods-slice0b-sound-fallback

## 1. 构建期 sound 复制
Traceability: [REQ-SOUND-1]

- [x] 1.1 `collectDataFiles()` 新增 `walk(modDir .. "/sound", "", "sound")`
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `sound/` 下文件以 `kind="sound"` 进入文件列表
    - [x] `IGNORE_DIRS`/`IGNORE_FILES` 逻辑对 `sound/` 同样生效
    - [x] 不影响 `resource/`/`fight/`/`save/` 的现有行为

- [x] 1.2 `Build()` 新增 `outSound` 目录并 `mkdirp`
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `outSound = outRoot .. "/sound"`
    - [x] 构建后目录存在

- [x] 1.3 `flattenResources()` 路由 `kind=="sound"` 到 `outSound`
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `base = (f.kind=="sound" and outSound) or (f.kind=="save" and outSave) or outData`
    - [x] `sound/` 文件小写归一
    - [x] 返回计数区分 data/save/sound（或新增 soundCount）
    - [x] `sound/` 文件不出现在 `outData`

## 2. 运行时常量改写
Traceability: [REQ-SOUND-2], [REQ-SOUND-3]

- [x] 2.1 `ModData.RewriteConstants` 新增音频格式串前缀改写
  Blast Radius: `["game/framework/mod_data.lua"]`
  DoD:
    - [x] 对 `CC.ATKFile`/`CC.EFile`/`CC.MIDIFile` 做前缀改写（仿 `FightPicFile` 分支）
    - [x] 仅当 `mods/<slug>/sound/` 目录存在时改写
    - [x] 格式串部分（`%02d`、扩展名）不变
    - [x] 未激活 MOD 或 MOD 无 `sound/` → 保持 `sound/...`

- [x] 2.2 确认 `ModData.exists` 可用于目录存在性检查（或新增 `dirExists`）
  Blast Radius: `["game/framework/mod_data.lua"]`
  DoD:
    - [x] 有可靠的「目录是否存在」判定
    - [x] 在测试环境中可用（`tests/test_helper.lua` 的 EngineAPI.file mock 兼容）

## 3. 单元测试
Traceability: [REQ-SOUND-1], [REQ-SOUND-2], [REQ-SOUND-3]

- [x] 3.1 `test_mod_build.lua`：断言 `sound/` 复制
  Blast Radius: `["game/tests/unit/test_mod_build.lua"]`
  DoD:
    - [x] 临时 MOD 树含 `sound/atk00.wav`、`sound/e100.wav`、`sound/tit.wav`
    - [x] 断言产物 `mods/<slug>/sound/` 含这三个文件
    - [x] 断言 `mods/<slug>/data/` 不含 `.wav`
    - [x] 断言内容逐字节相同

- [x] 3.2 `test_mod_data.lua`：断言常量改写与回退
  Blast Radius: `["game/tests/unit/test_mod_data.lua"]`
  DoD:
    - [x] 激活（mock MOD 有 `sound/`）→ `CC.ATKFile`/`CC.EFile` 前缀为 `mods/<slug>/sound/`
    - [x] 未激活 → `CC.ATKFile == "sound/atk%02d.wav"`
    - [x] MOD 无 `sound/` → 保持原版路径
    - [x] `string.format(CC.EFile, 100)` 含 `e100.wav`

## 4. 集成验证
Traceability: [REQ-SOUND-1], [REQ-SOUND-2], [REQ-SOUND-4]

- [x] 4.1 重建全部 20 MOD 产物
  Blast Radius: `["game/mods/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua --all` → 0 build failures
    - [x] 每个 `game/mods/*/sound/` 文件数 == 源 MOD `sound/` 文件数

- [x] 4.2 运行时证明（激活 mingdong）
  Blast Radius: `["game/tests/unit/test_mod_e2e.lua"]`
  DoD:
    - [x] `CC.ATKFile == "mods/mingdong/sound/atk%02d.wav"`
    - [x] `CC.EFile == "mods/mingdong/sound/e%02d.wav"`
    - [x] `CC.MIDIFile == "sound/game%02d.ogg"`
    - [x] `game/mods/mingdong/sound/` 含 201 个文件

- [x] 4.3 零回归与基线
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] 无 `active_mod.txt` → `cd game && lua tests/test_runner.lua` 全绿
    - [x] `cd game && lua tools/mod_build.lua --verify-pascal` PASS
    - [x] `git diff game/engine-love2d/` 为空

## 5. 验证报告
Traceability: [REQ-SOUND-1]~[REQ-SOUND-4]

- [x] 5.1 产出 `verification.md`
  Blast Radius: `["openspec/changes/allmods-slice0b-sound-fallback/verification.md"]`
  DoD:
    - [x] 含 REQ 追溯矩阵（4 个 REQ 全覆盖）
    - [x] 含 Blast Radius 合规检查
    - [x] 含测试结果
    - [x] 总体判定 ✓ PASSED
