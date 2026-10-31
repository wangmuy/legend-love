---
status: abandoned
created: 2026-10-30
parent_slice: allmods-slice15-music-ogg
---
# Tasks: allmods-music-ogg-tool

## 组 1：工具骨架与依赖检测（[REQ-MOG-1]）

Blast Radius: `["game/tools/mid2ogg.lua"]`

- [ ] 1.1 创建 `game/tools/mid2ogg.lua`，导出 `M.checkDeps/convertOne/convertAll/main` 与 `M.REQUIRED_MIDS`
  DoD:
    - [ ] `lua -e 'assert(require("tools.mid2ogg").REQUIRED_MIDS)'` 退出码 0
    - [ ] `M.REQUIRED_MIDS.mingdong` 长度 = **26**，`M.REQUIRED_MIDS.awaken` 长度 = **15**
    - [ ] 表内容与 `slice15/change-manifest.md` Contract A 逐字一致
- [ ] 1.2 `checkDeps()` 检测 `timidity` 与 `ffmpeg`
  DoD:
    - [ ] 两者都在时返回 `true, {}`
    - [ ] 用 `PATH=/nonexistent` 运行时返回 `false, {"timidity","ffmpeg"}`（或子集）
    - [ ] 检测用 `io.popen("command -v timidity")`，不依赖 `os.execute` 退出码语义

## 组 2：音色库映射表生成（[REQ-MOG-2]，本 change 最大坑）

Blast Radius: `["game/tools/mid2ogg.lua"]`

- [ ] 2.1 `makeTimidityCfg(sf2Path, outPath)` 生成 `dir` + `bank 0` + 128 行 `%font` 映射
  DoD:
    - [ ] 生成文件首行含 `dir <sf2 所在目录>`
    - [ ] 含 `bank 0`
    - [ ] `%font` 行数 = **128**（program 0..127）
    - [ ] **不含** `soundfont` 字样（实测该写法被忽略）—— `grep -c '^soundfont' cfg` = 0
- [ ] 2.2 负向对照：证明映射表真被 timidity 读取（不是空跑）
  DoD:
    - [ ] 用 `mid.sf2` 映射表转 `kys-pascal/music/10.mid` → md5 = `b7c078ae…`（记录完整值）
    - [ ] 用 `FluidR3_GM.sf2` 映射表转同一文件 → md5 **不同**
    - [ ] 两者不同 ⇒ 映射表生效；若相同则判定失败并排查
    - [ ] 两条 md5 实测值写入 `verification.md`

## 组 3：单文件转换（[REQ-MOG-3]）

Blast Radius: `["game/tools/mid2ogg.lua"]`

- [ ] 3.1 `convertOne(midPath, outOggPath)` 两段式：`timidity -Ow` → `ffmpeg -c:a libvorbis -q:a 4`
  DoD:
    - [ ] 转换 `kys-pascal/music/10.mid` → 产物存在且 `stat -c%s` > 100 KB
    - [ ] `ffprobe` 识别为 `vorbis`
    - [ ] 中间 WAV 用 `os.tmpname()` 或 `/tmp` 临时文件，**转换后删除**（不留垃圾）
- [ ] 3.2 输出路径按 `game<id+1>` 规则，目录自动创建
  DoD:
    - [ ] id `26` → `game27.ogg`；id `81` → `game82.ogg`（**不是** `game082`）
    - [ ] 目标目录不存在时自动 `mkdir -p`
    - [ ] 用 `string.format("game%02d.ogg", id+1)` 生成，禁止手写拼串

## 组 4：批量与降级（[REQ-MOG-4]）

Blast Radius: `["game/tools/mid2ogg.lua"]`

- [ ] 4.1 `convertAll(opts)` 支持 `--all` / `--mod <slug>` / `--dry-run`
  DoD:
    - [ ] `--dry-run` 列出 41 个待转项，退出码 0，**零文件写入**
    - [ ] `--mod mingdong` 只处理 mingdong 的 26 个
    - [ ] `--all` 处理 41 个；汇总打印 `converted=N skipped=M failed=0`
- [ ] 4.2 外部工具缺失时降级
  DoD:
    - [ ] `PATH=/nonexistent lua tools/mid2ogg.lua --all` → 打印提示、**退出码 0**、零产物
    - [ ] 单文件失败不中断整批（记录进 `failed` 列表）
- [ ] 4.3 幂等
  DoD:
    - [ ] 连跑两次 `--mod mingdong`，第二轮产物 `diff -rq` 为空
    - [ ] 已存在且未变更的产物可跳过（`skipped` 计数）

## 组 5：单测与自检

Blast Radius: `["game/tests/unit/test_mid2ogg.lua", "game/tests/test_runner.lua"]`

- [ ] 5.1 新增纯逻辑单测（不依赖外部工具）
  DoD:
    - [ ] 测 `game<id+1>` 命名规则（26→game27、81→game82、9→game10）
    - [ ] 测 `makeTimidityCfg` 输出行数 = 130（dir + bank + 128）
    - [ ] 测 `REQUIRED_MIDS` 长度 26/15
    - [ ] `lua tests/test_runner.lua mid2ogg` 全通过
- [ ] 5.2 全量测试不回归
  DoD:
    - [ ] `lua tests/test_runner.lua` 通过数 **≥ 1957**，失败 **0**

## 组 6：实际产出

Blast Radius: `["game/mods/mingdong/sound/", "game/mods/awaken/sound/"]`

- [ ] 6.1 执行转换，产出 41 个 ogg
  DoD:
    - [ ] `ls game/mods/mingdong/sound/game*.ogg | wc -l` = **26**
    - [ ] `ls game/mods/awaken/sound/game*.ogg | wc -l` = **15**
    - [ ] 每个文件 `ffprobe` 均为 `vorbis`
    - [ ] `--dry-run` 与实跑数量一致（41）
- [ ] 6.2 确认不影响既有产物
  DoD:
    - [ ] `lua tools/mod_build.lua --all` 后 ogg 仍在（`mod_build` 的 `sound` walk 只搬源侧，源侧无 ogg）
    - [ ] `lua tools/mod_build.lua --all` 输出仍 `20 mods, 0 build failures`
