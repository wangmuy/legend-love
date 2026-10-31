---
status: active
created: 2026-10-30
---
# Spec: allmods-music-ogg-tool

## [REQ-MOG-1] 依赖检测与降级

工具必须检测外部依赖，缺失时降级而非失败。

### Scenario: 依赖齐备

- **Given** `timidity` 与 `ffmpeg` 都在 `PATH` 中
- **When** 调用 `M.checkDeps()`
- **Then** 返回 `true, {}`

### Scenario: 依赖缺失（降级）

- **Given** `PATH` 中无 `timidity`
- **When** 执行 `lua tools/mid2ogg.lua --all`
- **Then** 打印明确的缺失提示
- **And** 退出码为 **0**（不是非零）
- **And** 不产出任何文件
- **And** 不中断、不抛 Lua 错误

## [REQ-MOG-2] 音色库映射表必须真正生效

严禁使用被静默忽略的 `soundfont` 整库写法。

### Scenario: 生成合法映射表

- **Given** 音色库路径 `reference/allmods/kys-pascal/music/mid.sf2`
- **When** 调用 `M.makeTimidityCfg(sf2Path, outPath)`
- **Then** 输出文件含 `dir <目录>` 一行、`bank 0` 一行、`%font` 映射 **128** 行
- **And** 输出文件**不含** `^soundfont` 行

### Scenario: 映射表生效可被区分（负向对照）

- **Given** 同一源文件 `kys-pascal/music/10.mid`
- **When** 分别用 `mid.sf2` 与系统 `FluidR3_GM.sf2` 生成的映射表转换
- **Then** 两个产物 md5 **必须不同**
- **And** 若相同，判定为「映射表未生效」并**视为验证失败**

## [REQ-MOG-3] 两段式转码与命名规则

- **Given** `timidity -Oo` 未编译进本机版本（`Playmode 'o' is not compiled in`）
- **When** 转换任一 `.mid`
- **Then** 必须走 `timidity -Ow` 出 WAV → `ffmpeg -c:a libvorbis -q:a 4` 出 OGG

### Scenario: 输出命名符合引擎期望

- **Given** 被引用 id = `id`
- **When** 生成输出文件名
- **Then** 文件名 = `string.format("game%02d.ogg", id + 1)`
- **And** id `26` → `game27.ogg`、id `81` → `game82.ogg`（**不是** `game082.ogg`）
- **And** 输出目录 = `game/mods/<slug>/sound/`，不存在时自动创建

### Scenario: 中间文件不残留

- **Given** 一次成功转换
- **When** 转换结束
- **Then** 临时 WAV 已被删除
- **And** 目标目录中只有最终 `.ogg`

## [REQ-MOG-4] 只转被引用的 id，且幂等

### Scenario: 范围受限于引用集

- **Given** `M.REQUIRED_MIDS = { mingdong = {26,…,52}, awaken = {26,…,81} }`
- **When** 执行 `--all`
- **Then** 只转换这 **41** 个 `.mid`
- **And** 不转换其余 **537** 个未被引用的 `.mid`
- **And** 不转换任何 `.mp3`（实测未被引用，且引擎无 MP3 音乐通道）
- **And** 不转换 `.sf2`（它是音色输入，不是被播放的音频）

### Scenario: 幂等

- **Given** 已成功转换一次
- **When** 再次执行相同命令
- **Then** 产物逐字节一致（`diff -rq` 为空）
- **And** 已存在的等价文件计入 `skipped` 而非重复转码

### Scenario: dry-run 零副作用

- **Given** `--dry-run`
- **When** 执行
- **Then** 列出 **41** 个待转项
- **And** **不写入任何文件**
- **And** 退出码 0

## [REQ-MOG-5] 不侵入既有构建流程

### Scenario: 主构建流程不变

- **Given** `mid2ogg.lua` 已存在
- **When** 执行 `lua tools/mod_build.lua --all`
- **Then** 输出仍为 `20 mods, 0 build failures`
- **And** **不调用** `mid2ogg`（保持「构建期纯 Lua」）
- **And** 已产出的 ogg 不被删除或改写

### Scenario: 零禁改

- **Given** 本 change 全部完成后
- **When** 检查改动范围
- **Then** `engine-love2d/**`、`engine-mud/**` 改动数 = **0**
- **And** `script/jyconst.lua` 的 `CC.*=` 赋值改动数 = **0**
- **And** `reference/allmods/**` 改动数 = **0**
