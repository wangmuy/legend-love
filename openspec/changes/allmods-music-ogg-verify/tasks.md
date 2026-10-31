---
status: abandoned
created: 2026-10-30
parent_slice: allmods-slice15-music-ogg
---
# Tasks: allmods-music-ogg-verify

## 组 1：`mod_audit` 新增 `music` 分支（[REQ-MOV-1]）

Blast Radius: `["game/tools/mod_audit.lua", "game/tests/unit/test_mod_audit.lua"]`

- [ ] 1.1 `productCandidates()` 新增 `music` 分支
  DoD:
    - [ ] `music/<id>.mid` → 候选 `mods/<mod>/sound/game<id+1>.ogg`
    - [ ] `music/<id>.mp3`、`music/mid.sf2` → **无候选**（前者 LEGACY，后者 BUILD_INPUT）
    - [ ] `grep -c 'topdir == "music"' game/tools/mod_audit.lua` ≥ 1（改前实测为 0）
- [ ] 1.2 分类调整：A 类 `.mid` → `REQUIRED_CONVERTED`，`mid.sf2` → `BUILD_INPUT`，`.mp3` → `LEGACY`
  DoD:
    - [ ] `EXACT` 或 `BY_KIND` 中新增对应规则（`music|.mid` / `music|.sf2` / `music|.mp3`）
    - [ ] 每条规则带 `evidence`（`kind=code`，`ref` 指向工具或引擎代码行）
    - [ ] 未被引用的 537 个 `.mid` **仍为 `PENDING`**（不是「永不需要」，是「本 MOD 版本未引用」）
    - [ ] `lua tools/mod_audit.lua --all --evidence` → `bad_evidence=0 unclassified=0`
- [ ] 1.3 新增单测
  DoD:
    - [ ] 测 `productCandidates("mingdong","music/26.mid")` 含 `sound/game27.ogg`
    - [ ] 测 `productCandidates("dream","music/24.mp3")` 为**空表**
    - [ ] 测 `classify({mod="pascal",path="music/mid.sf2"})` = `BUILD_INPUT`
    - [ ] 测 `classify({mod="dream",path="music/24.mp3"})` = `LEGACY`
    - [ ] `lua tests/test_runner.lua mod_audit` 全通过（改前 280 条）

## 组 2：产物逐项验证（[REQ-MOV-2]）

Blast Radius: `[]`（只读）

- [ ] 2.1 数量与命名
  DoD:
    - [ ] mingdong `sound/game*.ogg` = **26** 个，id 集合与 `REQUIRED_MIDS.mingdong` 一一对应
    - [ ] awaken = **15** 个，最大为 `game82.ogg`
    - [ ] 全部文件名匹配 `^game%d%d+\.ogg$`，**无** `game082.ogg` 这类错误补零
    - [ ] 用 `string.format("game%02d.ogg", id+1)` 生成期望集再 `diff`，结果为空
- [ ] 2.2 格式与可解码
  DoD:
    - [ ] 41 个文件 `ffprobe -show_format` 全部识别为 `vorbis`
    - [ ] 每个文件时长 > 0 且与源 `.mid` 的 `Playing time` 相差 < 2 秒
    - [ ] 无 0 字节文件
- [ ] 2.3 逐个 md5 记录
  DoD:
    - [ ] 41 个文件 md5 全表写入 `verification.md`
    - [ ] 相邻两次转换 md5 一致（幂等）

## 组 3：负向对照（[REQ-MOV-3]，证明断言有鉴别力）

Blast Radius: `[]`（只读 + /tmp）

- [ ] 3.1 音色库 A/B 对照
  DoD:
    - [ ] `mid.sf2` 映射表转 `pascal/10.mid` → md5 = `b7c078ae…`（实测已知值）
    - [ ] `FluidR3_GM.sf2` 映射表转同一文件 → md5 = `379f412e…`
    - [ ] **两者不同** ⇒ 映射表生效；相同则判定失败
- [ ] 3.2 删除产物 → 审计能发现
  DoD:
    - [ ] 备份 `mods/mingdong/sound/game27.ogg` 后删除
    - [ ] `mod_audit --mod mingdong` 的 `in_product` 下降 / 该条转 `not_in_product`
    - [ ] 恢复后数字回到原值（三者互斥，非空跑）
- [ ] 3.3 缺工具降级
  DoD:
    - [ ] `PATH=/nonexistent lua tools/mid2ogg.lua --all` → 退出码 **0**、有提示、零产物
    - [ ] 该行为记入 `verification.md`

## 组 4：真实启动链路（[REQ-MOV-4]）

Blast Radius: `[]`（只读）

- [ ] 4.1 mingdong 真实启动
  DoD:
    - [ ] `lua tests/unit/boot_one_mod.lua mingdong 632 367 139 220 小蝦米` → `RESULT mingdong: OK`
    - [ ] 启动日志中 **无** `PlayMIDI error`
    - [ ] 断言 `CC.MIDIFile` 已被改写为 `mods/mingdong/sound/game%02d.ogg`
      （`mod_data.lua:381-385` 的重定向分支首次真正触发）
- [ ] 4.2 awaken 真实启动
  DoD:
    - [ ] `lua tests/unit/boot_one_mod.lua awaken 720 237 153 163 北辰月` → `RESULT awaken: OK`
    - [ ] 无 `PlayMIDI error`
- [ ] 4.3 pascal 零回归
  DoD:
    - [ ] `lua tests/unit/boot_one_mod.lua pascal 320 200 84 93 小蝦米` → `RESULT pascal: OK`
    - [ ] pascal 无 ogg ⇒ `CC.MIDIFile` **仍是** `sound/game%02d.ogg`（未被改写）

## 组 5：审计归口复核（[REQ-MOV-5]）

Blast Radius: `[]`（只读）

- [ ] 5.1 全量审计数字校准
  DoD:
    - [ ] `PENDING` = **537**（−41 `.mid` −1 `.sf2` −2 `.mp3`）
    - [ ] `REQUIRED_CONVERTED` = **121**（+41）
    - [ ] `LEGACY` = **110**（+2）
    - [ ] `BUILD_INPUT` = **31**（+1）
    - [ ] `total` 恒 **11220**；逐类相加闭合
    - [ ] `in_product` 记录实测值（预期 9326）
    - [ ] `unclassified=0 bad_evidence=0`
- [ ] 5.2 PENDING 残留说明
  DoD:
    - [ ] 确认剩余 537 条**全部**是未被引用的 `.mid`
    - [ ] 显式记录「为何不转」：本 MOD 版本未引用，非「永不需要」
    - [ ] `grep` 确认无 `.bin` / `.mp3` / `.sf2` 残留于 `PENDING`

## 组 6：文档收口

Blast Radius: `["openspec/**"]`

- [ ] 6.1 `verification.md` 产出
  DoD:
    - [ ] 含 6 节：产物验证 / 负向对照 / 启动链路 / 审计归口 / 门禁 / 遗留
    - [ ] 每节含「实测命令 + 原始输出 + 结论」
    - [ ] 41 个产物 md5 全表
- [ ] 6.2 更新 `epic.md` 与 `TODO.md`
  DoD:
    - [ ] `TODO.md` 音频域条目从 `[ ]` 改为 `[x]` 并附实测块
    - [ ] `epic.md` 门禁数字更新（`PENDING` 581→537 等）
    - [ ] **保留历史记录不篡改**：`allmods-spike-effect-table`、`allmods-riverlake-activate` 等
      文档中的「硬编码 53 项」「引擎不读」作为历史结论保留
- [ ] 6.3 BookCalamity 无法修复项记录
  DoD:
    - [ ] 明确记录 20 个 id 源侧无 `.mid`，转换流水线**无法修复**
    - [ ] 定级为「MOD 原始缺陷」而非「本 epic 缺口」

## 组 7：8 门禁复跑

Blast Radius: `[]`（只读）

- [ ] 7.1
  DoD:
    - [ ] G1 `lua tests/test_runner.lua` → 失败 **0**，总数 ≥ 1957
    - [ ] G2 `lua tools/mod_build.lua --verify-pascal` → `PASS`
    - [ ] G3 `lua tools/mod_build.lua --all` → `20 mods, 0 build failures`
    - [ ] G4 `timeout 900 lua tools/mod_check.lua` → `20/20`
    - [ ] G5 `lua tools/mod_audit.lua --all --evidence` → `unclassified=0 bad_evidence=0`
    - [ ] G6 `lua tools/format_spec.lua --all` → `formats=14 checked=6838 gaps=0`
    - [ ] G7 存档槽 451 文件 / 真实问题 0
    - [ ] G8 四禁改 `0`；`jyconst` 的 `CC.*=` 赋值 `0`
- [ ] 7.2 幂等
  DoD:
    - [ ] `lua tools/mod_build.lua --all` 两次 → `diff -rq game/mods /tmp/snap` 为空
    - [ ] ogg 产物在两次构建后仍在且 md5 不变
