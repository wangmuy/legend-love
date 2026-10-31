---
status: active
created: 2026-10-30
---
# Spec: allmods-music-ogg-verify

## [REQ-MOV-1] `mod_audit` 必须看得见转换产物

「改了但审计说没改」是本项目明令禁止的假象。

### Scenario: `music` 分支存在

- **Given** 变更前 `grep -c 'topdir == "music"' game/tools/mod_audit.lua` = **0**
- **When** 本 change 完成
- **Then** `productCandidates` 对 `music/<id>.mid` 返回候选 `mods/<mod>/sound/game<id+1>.ogg`
- **And** 该计数 ≥ 1

### Scenario: 分类归口正确

- **Given** `music/26.mid` 被 mingdong 引用且已转码
- **When** 执行 `mod_audit`
- **Then** 其类别为 `REQUIRED_CONVERTED`，`in_product = true`
- **And** `music/mid.sf2` 类别为 `BUILD_INPUT`（音色输入，非产物）
- **And** `music/24.mp3`、`music/37.mp3` 类别为 `LEGACY`（引擎零播放路径）
- **And** 未被引用的 `.mid` 仍为 `PENDING`（不是 `LEGACY`）

### Scenario: 删除产物能被发现（鉴别力）

- **Given** `mods/mingdong/sound/game27.ogg` 存在
- **When** 临时删除该文件后执行 `mod_audit --mod mingdong`
- **Then** 对应记录的 `in_product` 变为 `false`
- **And** 恢复文件后数字回到原值
- **And** 三个状态互相排斥（存在=true / 删除=false / 恢复=true）

## [REQ-MOV-2] 产物逐项验证

### Scenario: 数量与命名精确匹配

- **Given** `M.REQUIRED_MIDS = { mingdong = 26 项, awaken = 15 项 }`
- **When** 检查 `mods/mingdong/sound/` 与 `mods/awaken/sound/`
- **Then** ogg 文件数分别为 **26** 与 **15**
- **And** 文件名集合 == `{ string.format("game%02d.ogg", id+1) }`
- **And** 无 `game082.ogg` 这类三段补零错误

### Scenario: 格式可解码

- **Given** 41 个产物
- **When** 逐个 `ffprobe`
- **Then** 全部识别为 `vorbis`
- **And** 时长 > 0，与源 `.mid` 的 `Playing time` 相差 < 2 秒
- **And** 无 0 字节文件

## [REQ-MOV-3] 负向对照必须展示鉴别力

### Scenario: 音色库 A/B 可区分

- **Given** 同一 `.mid` 分别用 `mid.sf2` 与 `FluidR3_GM.sf2` 映射表转换
- **When** 比较产物
- **Then** md5 **不同**
- **And** 实测值分别记录（已知 `mid.sf2` → `b7c078ae…`）

### Scenario: 缺工具降级不误报成功

- **Given** `PATH=/nonexistent`
- **When** 执行 `--all`
- **Then** 退出码 **0**、有提示、**零产物**
- **And** 不得静默声称「转换成功」

## [REQ-MOV-4] 真实启动链路生效

### Scenario: mingdong 播放路径被重定向

- **Given** `mods/mingdong/sound/game27.ogg` 等 26 个 ogg 存在
- **When** 真实启动 mingdong
- **Then** `mod_data.lua:381-385` 的重定向分支**首次触发**
- **And** `CC.MIDIFile` == `mods/mingdong/sound/game%02d.ogg`
- **And** `RESULT mingdong: OK`，日志中无 `PlayMIDI error`

### Scenario: awaken 同样生效

- **Given** awaken 的 15 个 ogg 存在
- **When** 真实启动 awaken
- **Then** `RESULT awaken: OK`，无 `PlayMIDI error`

### Scenario: 无 ogg 的 MOD 保持原路径（零回归）

- **Given** pascal 无 `mods/pascal/sound/game*.ogg`
- **When** 真实启动 pascal
- **Then** `CC.MIDIFile` **仍是** `sound/game%02d.ogg`（未被改写）
- **And** `RESULT pascal: OK`

## [REQ-MOV-5] 审计数字闭合且可解释

### Scenario: 逐类闭合

- **Given** 变更前 `total=11220 PENDING=581 REQUIRED_CONVERTED=80 LEGACY=108 BUILD_INPUT=30`
- **When** 变更完成
- **Then** `PENDING = 537`（−41 `.mid` −1 `.sf2` −2 `.mp3`）
- **And** `REQUIRED_CONVERTED = 121`（+41）
- **And** `LEGACY = 110`（+2）
- **And** `BUILD_INPUT = 31`（+1）
- **And** `total` 恒 **11220**
- **And** `9185 + 121 + 110 + 2 + 1222 + 31 + 12 + 537 = 11220`

### Scenario: 残留 PENDING 有明确理由

- **Given** 剩余 537 条 `PENDING`
- **When** 检查构成
- **Then** 100% 是**未被引用的 `.mid`**
- **And** 报告明确说明「本 MOD 版本未引用」，而非「永不需要」
- **And** 无 `.bin` / `.mp3` / `.sf2` 残留

## [REQ-MOV-6] 文档与零回归

### Scenario: 8 门禁全绿

- **Given** 全部实施完成
- **When** 复跑 8 门禁
- **Then** G1 失败数 0（总数 ≥ 1957）、G2 PASS、G3 20 mods 0 failures、
  G4 20/20、G5 `unclassified=0 bad_evidence=0`、G6 `gaps=0`、G7 真实问题 0、G8 四禁改 0

### Scenario: 幂等

- **Given** 已全量构建
- **When** 再执行一次 `mod_build --all`
- **Then** `diff -rq` 为空
- **And** ogg 产物仍在且 md5 不变

### Scenario: 历史文档不被篡改

- **Given** `allmods-spike-effect-table`、`allmods-riverlake-activate` 等归档文档
- **When** 更新本轮文档
- **Then** 它们中的历史结论（如「硬编码 53 项」）**保持不变**
- **And** 本轮新知只写进本 change 的文档
