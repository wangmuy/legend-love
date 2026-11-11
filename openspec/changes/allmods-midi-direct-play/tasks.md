---
status: done
created: 2026-10-30
---
# Tasks: allmods-midi-direct-play

## 组 1：`lib_love.lua` 路径解析与扩展名探测

Blast Radius: `["game/engine-love2d/lib_love.lua"]`

- [x] 1.1 `audioFileExists()` / `hasExtension()` / `firstExisting()` 辅助函数
  DoD:
    - [x] `io.open(path,"rb")` 探测成功返回 true
    - [x] 打包环境（`love.filesystem.getInfo`）也能探测
    - [x] `hasExtension("1.mid")`=true；`hasExtension("game27")`=false
- [x] 1.2 `MUSIC_EXTS = {".ogg",".mid",".mp3"}`，`.ogg` 优先
  DoD:
    - [x] 原版路径含扩展名 ⇒ 直接返回，不探测（保证零回归）
    - [x] 无扩展名 ⇒ 按 `.ogg → .mid → .mp3` 探测
- [x] 1.3 `bundledFallback()`：MOD 缺失时回退 `sound/` 同 basename
  DoD:
    - [x] `mods/BookCalamity/music/game25` → `sound/game25.ogg`
    - [x] 已在 `sound/` 下时不递归回退
- [x] 1.4 前缀修正：只有**裸文件名**（不含 `/`）才加 `CONFIG.SoundPath`
  DoD:
    - [x] `mods/x/sound/game27.ogg` 拼成 `mods/x/sound/game27.ogg`（修前误拼 `sound/mods/...`）
    - [x] `sound/game17.ogg` 保持不变
    - [x] `atk00.wav`（裸名）→ `sound/atk00.wav`
- [x] 1.5 `PlayWAV` 同步修正（同源 bug）
  DoD:
    - [x] MOD 音效路径不再被误加前缀

## 组 2：`mod_data.lua` music 重定向

Blast Radius: `["game/framework/mod_data.lua"]`

- [x] 2.1 新增 `ModData.MUSIC_DIR = "music/"`
- [x] 2.2 `RewriteConstants` 增加 MIDI 重定向分支
  DoD:
    - [x] 触发条件：`CC.MIDIFile` 以 `sound/` 开头 **且** 以 `.ogg` 结尾 **且** `mods/<slug>/music/` 有 `game%d+%.mid`
    - [x] 结果去掉 `.ogg` 后缀：`sound/game%02d.ogg` → `mods/<slug>/music/game%02d`
    - [x] 未激活 MOD ⇒ 空操作（原版零回归）
    - [x] MOD 无 `.mid` ⇒ 不改写

## 组 3：`mod_build.lua` 搬运 music

Blast Radius: `["game/tools/mod_build.lua"]`

- [x] 3.1 `flattenMusic(modDir, outMusic)`：`<id>.mid` → `game<id+1>.mid`
  DoD:
    - [x] `26.mid` → `game27.mid`
    - [x] `81.mid` → `game82.mid`（`%02d` 是最小宽度，**不是** `game082`）
    - [x] `0.mid` → `game01.mid`
    - [x] `.sf2` **不复制**（BUILD_INPUT）
    - [x] `.mp3` **复制**（第二轮追加，用户要求）
- [x] 3.2 接入 `flattenResources`（新增 `outMusic` 参数）与 `Build`
  DoD:
    - [x] 产物含 `mods/<slug>/music/`
    - [x] `report.music` 计数正确
- [x] 3.3 全量验证
  DoD:
    - [x] 20/20 MOD 产物 music 合计 **578**，与源侧 578 **相等**
    - [x] `mod_build --all` → `20 mods, 0 build failures`

## 组 4：单元测试

Blast Radius: `["game/tests/unit/test_mod_data.lua"]`

- [x] 4.1 `testRewriteAudioMidiRedirect`（正向）
  DoD:
    - [x] `CC.MIDIFile` → `mods/mingdong/music/game%02d`
    - [x] id 26 → `game27`；id 81 → `game82`（非 `game082`）
- [x] 4.2 `testRewriteAudioMidiNoMidNoRedirect`（负向对照）
  DoD:
    - [x] 目录存在但无 `game*.mid` ⇒ `CC.MIDIFile` 不变
- [x] 4.3 `testRewriteAudioMidiNoActiveIsNoop`（零回归对照）
  DoD:
    - [x] 未激活 MOD 时**即使**检测到 mid 也不改写
    - [x] `MIDIFile` / `ATKFile` / `EFile` 三者全部不变
- [x] 4.4 测试数从 1957 → **1965**（+8），0 失败

## 组 5：兼容性验证（用户核心要求）

Blast Radius: `[]`（只读）

- [x] 5.1 原版零回归
  DoD:
    - [x] `激活MOD = nil` 时 `CC.MIDIFile = sound/game%02d.ogg`
    - [x] 25 个 ogg 路径被改变数 = **0**
    - [x] 1093 个 wav 路径被改变数 = **0**
    - [x] `boot_one_mod.lua pascal` → `RESULT: OK`
- [x] 5.2 20 MOD 覆盖
  DoD:
    - [x] 逐 MOD 列出 `CC.MIDIFile` / refs / resolved
    - [x] 19/20 MOD 100% 覆盖
    - [x] BookCalamity 15 MOD + 1 内置 + 19 静音（未变差）
- [x] 5.3 真实播放出声（LÖVE 实跑）
  DoD:
    - [x] `mingdong game27.mid` dur 122.00s RMS 0.1022 出声
    - [x] `awaken game82.mid` dur 89.00s RMS 0.1075 出声
    - [x] 内置 `game25.ogg` dur 119.55s RMS 0.0960 出声（对照）
- [x] 5.4 真实启动 4 个代表 MOD
  DoD:
    - [x] pascal / mingdong / awaken / BookCalamity 全部 `RESULT: OK`

## 组 6：门禁与幂等

Blast Radius: `[]`（只读）

- [x] 6.1 G1 测试 `1965 / 0 failed`
- [x] 6.2 G2 `pascal baseline: PASS`
- [x] 6.3 G3 `20 mods, 0 build failures, 5 annotated-problematic`
- [x] 6.4 G4 `20 MOD, 通过 20, 失败 0`
- [x] 6.5 G5 `total=11220 in_product=9285 ... unclassified=0 bad_evidence=0`（未变）
- [x] 6.6 G6 `formats=14 checked=6838 gaps=0`
- [x] 6.7 G7 存档真实问题 0
- [x] 6.8 G8 `jyconst` 的 `CC.*=` = **0**、`reference/allmods` 改动 = **0**
- [x] 6.9 幂等：二次构建 `diff -rq` = **0**
  DoD:
    - [x] 注：须在测试套件**之前**做，测试会删 `save/` 模板导致假差异

## 组 7：文档与会话收口

Blast Radius: `["openspec/**"]`

- [x] 7.1 本 change 的 proposal / tasks / spec 产出
- [x] 7.2 `allmods-slice15-music-ogg` 全部文档标记 `abandoned`（被本 change 取代）
- [x] 7.3 待办：更新 epic.md 的 Slice 15 段（改为「已改用直接播放」）
- [x] 7.4 待办：更新 TODO.md 音频域条目

## 遗留（明确的未完成项）

| # | 项 | 性质 |
|:-:|---|---|
| 1 | BookCalamity 19 个 id 无源文件（引用 24–51，仅有 0–23） | **MOD 原始数据缺陷**，不可修复 |
| 2 | ~~`.mp3` 2 个未使用~~ | **已支持**（第二轮）：能播，但源数据未引用 |
| 3 | `mid.sf2` 音色无法在 LÖVE 生效 | libmodplug 忽略自定义 SoundFont（实测三写法 md5 全同） |
| 4 | 578 个 mid 全部进产物（含未被引用的 537 个） | 仅 7.5 MB，保持完整性 > 精简 |

## 组 8：MP3 支持（第二轮追加）

Blast Radius: `["game/tools/mod_build.lua", "game/tests/unit/test_mod_build.lua"]`

- [x] 8.1 确认 LÖVE 能播 `.mp3`（实测）
  DoD:
    - [x] `dream/24.mp3` dur 266.72s RMS 0.1511 出声
    - [x] `pineapple/37.mp3` dur 248.08s RMS 0.1656 出声
- [x] 8.2 全量重扫音乐 id 来源（修正第一轮漏洞）
  DoD:
    - [x] 纳入 `instruct_66(id)` —— `awaken` 用了 48 个 id（第一轮完全漏掉）
    - [x] `instruct_66` 参数全为字面量（`grep -v "instruct_66([0-9]*)"` 为空）⇒ 无漏扫
    - [x] 确认两个 mp3 编号（dream 24 / pineapple 37）未被引用
- [x] 8.3 `flattenMusic` 支持 `.mp3`
  DoD:
    - [x] `24.mp3` → `game25.mp3`；`37.mp3` → `game38.mp3`
    - [x] `.sf2` 仍排除
    - [x] **踩坑修正**：Lua pattern 无 `|` 选择符，改扩展名白名单比较
- [x] 8.4 无编号冲突验证
  DoD:
    - [x] 全库 `*.mp3` 的同号 `.mid` 扫描 = **0 冲突**
- [x] 8.5 产物字节级对账
  DoD:
    - [x] `.mid` 578 = 源 578；`.mp3` 2 = 源 2；`.sf2` 0
    - [x] md5：`game25.mp3` = `39c4c26b…`、`game38.mp3` = `d02246c5…`（与源一致）
- [x] 8.6 运行时解析到产物 `.mp3`
  DoD:
    - [x] `mods/dream/music/game25` → `game25.mp3`
    - [x] `mods/pineapple/music/game38` → `game38.mp3`
- [x] 8.7 LÖVE 播放**产物**文件出声（非源文件）
  DoD:
    - [x] `game25.mp3` dur 266.72s RMS 0.1511 出声
    - [x] `game38.mp3` dur 248.08s RMS 0.1656 出声
- [x] 8.8 加 5 个构建测试
  DoD:
    - [x] `testMusicWalkInSource`（接线）
    - [x] `testMusicPatternHasNoLuaAlternation`（守 `|` 陷阱）
    - [x] `testMusicPatternMatchesRealNames`（含 3 个负向：`.sf2`/`.txt`/`game27.mid`）
    - [x] `testMusicRenumberingFormula`（含 `game82` 最小宽度、`game38.mp3`）
    - [x] `testMusicArtifactsIfBuilt`（产物数 + 字节级 md5）
- [x] 8.9 鉴别力验证（负向对照必须能 FAIL）
  DoD:
    - [x] 植入 `(mid|mp3)` ⇒ 2 个测试 FAIL ✅
    - [x] 删除 `game25.mp3` ⇒ 2 个测试 FAIL ✅
- [x] 8.10 门禁复跑
  DoD:
    - [x] G1 **1987 / 0 failed**（1965 → 1987，+22）
    - [x] G2 `PASS`；G4 **20/20**；G5/G6 未变
    - [x] 幂等 diff = **0**
    - [x] 原版 `CC.MIDIFile` 仍 `sound/game%02d.ogg`（零回归）
    - [x] dream / pineapple 真实启动 `RESULT: OK`

## 组 9：`tools/run-mod.sh` 音频就绪（第三轮）

Blast Radius: `["tools/run-mod.sh", "game/tests/gate_run_mod.sh"]`

- [x] 9.1 发现并确认脚本缺陷
  DoD:
    - [x] 旧逻辑 `[ ! -d "$MODS_OUT_DIR/$SELECTED" ]` 只看目录存在
    - [x] 实测：删掉 `mods/pig/music` 后脚本报「MOD 数据包已存在」并跳过构建，
          `music/` **再也不会回来**（缺陷确认）
- [x] 9.2 新增 `mod_ready()` 完整性判定
  DoD:
    - [x] 目录存在 + `data/` 非空
    - [x] 源侧有 `.mid`/`.mp3` 时，产物 `music/` 必须存在且数量 ≥ 源侧
    - [x] 不完整 ⇒ 自动重建；重建后仍不完整 ⇒ 报错退出
- [x] 9.3 新增 `report_audio()` 音频就绪报告
  DoD:
    - [x] 输出 `mid=N mp3=N ogg=N`
    - [x] `music/` 为空时 warn 提示会回退内置曲
    - [x] 音频不阻塞启动（缺失只 warn，不 die）
- [x] 9.4 `--list` 增加 music 列
  DoD:
    - [x] 已构建显示 `mid/mp3`（如 `dream 24/1`、`pineapple 34/1`）
    - [x] 已构建但缺 `music/` 显示 `缺`（黄色）
    - [x] 未构建显示 `src:N`（源侧音频数）
- [x] 9.5 4 种场景实测
  DoD:
    - [x] music 缺失 ⇒ `MOD 产物不完整（缺 music/ 等新产物），正在重建` ⇒ music 恢复 23 个
    - [x] 产物完整 ⇒ `MOD 数据包已存在且完整` 并跳过重建
    - [x] 带 mp3 的 MOD ⇒ `音频就绪: mid=34 mp3=1 ogg=0`
    - [x] 全新 MOD ⇒ `MOD 数据包未构建，正在构建` + 构建后音频报告
- [x] 9.6 兼容性回归
  DoD:
    - [x] `--vanilla` 仍正确删除 `active_mod.txt`
    - [x] `--no-build` 仍正确跳过构建检查（不重建、不报音频）
    - [x] `--list` / `bash -n` 语法正常
- [x] 9.7 新增门禁 `game/tests/gate_run_mod.sh`（7 项）
  DoD:
    - [x] 语法检查、`mod_ready` 存在性/`music/` 校验/数量比对
    - [x] 负向对照：旧逻辑 `[ ! -d $MODS_OUT_DIR/$SELECTED ]` 不得残留
    - [x] 负向对照：`mod_build.lua` 不得出现 `(mid|mp3)` alternation
    - [x] 产物/源侧音频总数对账 + 逐 MOD 核对 + `--list` 可运行
    - [x] 负向对照实测：删 `mods/pig/music` ⇒ `GATE_FAIL (1 项)` ✅
    - [x] 负向对照实测：改回旧判断 ⇒ `GATE_FAIL (1 项)` ✅
- [x] 9.8 门禁复跑
  DoD:
    - [x] G1 **1987 / 0 failed**
    - [x] 幂等 diff = **0**
    - [x] 逐 MOD 音频数核对：不一致 MOD 数 **0**

## 组 10：libmodplug 警告治理（第四轮）

Blast Radius: `["tools/run-mod.sh", "game/tests/gate_run_mod.sh"]`

- [x] 10.1 定位警告来源
  DoD:
    - [x] 确认来自 libmodplug C 层，直写 **stderr**（`2>&1 >/dev/null` 才看得到）
    - [x] Lua 无法捕获 ⇒ 只能用 stderr 层处理
- [x] 10.2 全量统计（578 首）
  DoD:
    - [x] `load_pat` 578 首（每曲 1 条）
    - [x] `Meta event not at end of track` 519 首
    - [x] `melody/drum ends with note on` 309 + 20 首
- [x] 10.3 `load_pat` 是否有害（决定性对照）
  DoD:
    - [x] 设 `MMPAT_PATH_TO_CFG=/etc/timidity` ⇒ 警告 578 → 0
    - [x] 逐样本哈希：不设/设/指向不存在目录 **全部 = 172447810**
    - [x] 换 `FluidR3_GM.sf2` / `TimGM6mb.sf2` 哈希**仍相同** ⇒ libmodplug 忽略 SF2
    - [x] 结论：纯路径噪声，**不代表音色缺失**
- [x] 10.4 `load_mid` 是否丢内容（timidity 逐首对账）
  DoD:
    - [x] 渲染 521 首对照，按**衰减曲线形状**判定而非只看 RMS
    - [x] 衰减拖尾 505 (96.9%)、近乎静音 11 (2.1%)、LÖVE 不短 5 (1.0%)
    - [x] **内容缺失 0 (0%)**
    - [x] 典型证据 `m0403`：0.3336→0.0581→0.0076→0.0006 单调衰减
    - [x] 勘误：中途误判 245 首「真截断」，加入衰减形状判定后归零
- [x] 10.5 `run-mod.sh` 实现
  DoD:
    - [x] `find_timidity_cfg_dir()` 自动探测 `/etc/timidity` 等 4 个候选
    - [x] 未设置时 `export MMPAT_PATH_TO_CFG`
    - [x] 找不到 cfg 时 warn 并说明「不影响音质 + 安装命令」
    - [x] `quiet_libmodplug()` 仅过滤 `load_pat > ` / `load_mid > ` 前缀行
    - [x] `FUZZY_MIDI_WARN=0` 可关闭过滤
- [x] 10.6 实测
  DoD:
    - [x] `love .`（Dragon）⇒ `load_` 行数 **10**
    - [x] `./tools/run-mod.sh Dragon` ⇒ **0**
    - [x] 过滤后正常输出未被吞（`SIG` 行/hash 仍出现）
- [x] 10.7 门禁扩展
  DoD:
    - [x] `gate_run_mod.sh` 增加 `MMPAT_PATH_TO_CFG` 与过滤逻辑检查
    - [x] 负向对照：移除过滤 ⇒ 门禁 FAIL

## 组 11：音质修复 —— OGG 预渲染（第五轮）

Blast Radius: `["game/engine-love2d/lib_love.lua", "game/tools/mod_build.lua", "tools/render-music.sh", "game/tests/unit/test_mod_data.lua", "game/tests/gate_run_mod.sh"]`

- [x] 11.1 确认「音质差」的根因
  DoD:
    - [x] 证明 AppImage 自带 `libmodplug.so.1`（336 KB），与系统音色库无关
    - [x] 决定性对照：128 个音色全指向同一鼓采样，PCM **逐字节相同**
    - [x] 结论：libmodplug 的 MIDI 合成完全不读外部音色 ⇒ `load_pat` 警告是误导
- [x] 11.2 客观量化音质
  DoD:
    - [x] libmodplug 直放：过零率 4749 Hz，差分/RMS 0.338
    - [x] 预渲染 OGG：过零率 2215 Hz，差分/RMS 0.154
    - [x] 无损 WAV 基准：过零率 2214 Hz ⇒ OGG 与基准一致
    - [x] 高频能量差 2.1 倍，与「刺耳」主观感受吻合
- [x] 11.3 格式选型（OGG vs MP3）
  DoD:
    - [x] 同源实测：OGG q3（1017 KB，+0.1%）优于 MP3 q:a 7（1014 KB，+2.0%）
    - [x] OGG q1（728 KB，+2.8%）优于 MP3 q:a 9（781 KB，+10.7%）
    - [x] 结论：同体积下 OGG 明显更好，MP3 无优势
- [x] 11.4 探测顺序改为 .ogg → .mp3 → .mid
  DoD:
    - [x] `MUSIC_EXTS = { ".ogg", ".mp3", ".mid" }`（用户指定 mid 放最后）
    - [x] 更新注释说明「为何 mid 必须最后」
    - [x] 3 个单元测试：顺序正确 / .mid 不得第一 / 无重复
    - [x] 负向对照三组全部 FAIL（mid 第一、删 ogg、制造重复）
- [x] 11.5 修复重建删除 OGG 的缺陷
  DoD:
    - [x] 确认 `mod_build.lua` 的 `rmdirp(outRoot)` 会删掉 music/ 下所有 ogg
    - [x] 实现 `preservedOgg`：rmdirp 前暂存，flattenMusic 后写回
    - [x] `report.renderedOgg` 报告恢复数量
    - [x] 负向对照：移除保护 ⇒ ogg 被删除
- [x] 11.6 新增 `tools/render-music.sh`
  DoD:
    - [x] `--all` / `--list` / `--force` / 单 MOD
    - [x] 依赖检查 timidity + ffmpeg + timidity.cfg（无音色库则拒绝渲染）
    - [x] 增量渲染（已存在则跳过），`--force` 可重渲
    - [x] 因 timidity 的 `-q` 对 OGG 无效，改为 WAV + ffmpeg libvorbis
- [x] 11.7 Dragon 试点
  DoD:
    - [x] 24 首渲染耗时 **1 分 57 秒**
    - [x] 体积 MIDI 288 KB → +OGG **18 MB**
    - [x] LÖVE 实际选中 `game01.ogg`（探测顺序生效）
    - [x] 播放后过零率 **2215 Hz**（直放 MIDI 为 4749 Hz）
    - [x] 增量补渲验证：只补 1 首缺失，其余 23 首跳过
- [x] 11.8 门禁强化
  DoD:
    - [x] 9 项新增检查（顺序、保护字段、脚本可执行/语法）
    - [x] **行为验证**：植入标记 ogg → 真实重建 → 检查存活
    - [x] 负向对照：清空恢复循环 ⇒ `GATE_FAIL (1 项)`
    - [x] 记录弱点：纯文本检查查不出「代码在但逻辑被架空」
- [x] 11.9 全量回归
  DoD:
    - [x] G1: **2002 / 0 失败**（+15）
    - [x] gate_run_mod.sh: `GATE_PASS`
    - [x] G2 pascal baseline: PASS
    - [x] G5 audit: `total=11220 … unclassified=0 bad_evidence=0`
    - [x] G6 format_spec: `formats=14 checked=6838 gaps=0`
    - [x] 禁改三项均为 0

- [x] 11.10 全量渲染（用户试听通过后）
  DoD:
    - [x] 20/20 MOD、578/578 MIDI 全部渲染
    - [x] 失败 0、警告 0
    - [x] 渲染总耗时约 53 分钟
    - [x] 逐 MOD 独立 `find` 对账：不一致 **0**
    - [x] OGG 总体积 476.3 MB（中位 729 KB/首）
    - [x] 抽检 9 个 MOD 过零率 2079~2752 Hz（真实音色区间）
    - [x] 重建保护实测：重建后 OGG 仍为 578，无丢失
    - [x] 回归：G1 2002/0、门禁 GATE_PASS、G2 PASS、G5/G6 未变、禁改全 0
