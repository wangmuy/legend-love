## Context

Lua 引擎的音频加载路径（`game/engine-love2d/lib_love.lua`）：

```lua
function PlayMIDI(filename)
    local filepath = filename
    if not filepath:match("^/") and not filepath:match("^%a:") then
        if not filepath:match("^sound/") then
            filepath = CONFIG.SoundPath .. filepath   -- "sound/"
        end
    end
    love.audio.newSource(filepath, "stream")
end
```

调用方（`game/script/jymain.lua:2160-2185`）用 `CC.*` 格式串拼接：

```lua
lib.PlayMIDI(string.format(CC.MIDIFile, id+1))   -- CC.MIDIFile = "sound/game%02d.ogg"
lib.PlayWAV(string.format(CC.ATKFile, id))       -- CC.ATKFile  = "sound/atk%02d.wav"
lib.PlayWAV(string.format(CC.EFile, id))         -- CC.EFile    = "sound/e%02d.wav"
```

因此运行时只有一个注入点：**改写这三个 `CC.*` 常量的前缀**。

### 现状证据（实测）

| 验证 | 结果 |
|------|------|
| `mod_build.lua` 是否 walk `sound/` | 否（只 walk `resource/`、`fight/`、`save/`） |
| `ModData.RewriteConstants` 是否处理 `MIDIFile`/`ATKFile`/`EFile` | 否（`singles` 表不含它们） |
| `game/mods/mingdong/` 下是否有 `sound/` | 否 |
| 各 MOD `sound/` 文件名前缀 | 全为 `atk*`/`e*`（+ BookCalamity/Dragon 各 1 个 `tit.wav`） |
| 编号位数 | `atk` 全 2 位（max 70）；`e` 2~3 位（BookCalamity/mingdong 有 `e100`~`e1xx`） |
| `string.format("%02d", 100)` | `"100"`（Lua `%02d` 是最少 2 位，3 位数原样输出）→ **格式串无需改** |
| mingdong 独有音效 | 123 个 |
| mingdong 同名音效中内容不同 | 52 个（MOD 定制被原版覆盖） |
| pascal 同名音效中内容不同 | 0（逐字节相同 → 命名体系一致） |

## Goals / Non-Goals

**Goals:**

- MOD 音效在激活时从 `mods/<mod>/sound/` 加载，不再被原版覆盖。
- 未激活 MOD 时行为与现状完全一致。
- 复用现有 `RewriteConstants` 的「格式串前缀改写」范式，保持代码风格统一。

**Non-Goals:**

- 不转换 `music/*.mid`（格式/槽位不匹配，另立 spike）。
- 不改 `lib_love.lua` 的音频加载与 `pcall` 兜底逻辑。
- 不做 per-file 回退（`love.audio.newSource` 只接受单路径）。
- 不处理 `[music]` 段的 ini 音量参数（Slice 0 已覆盖）。

## Architecture Decision Records

### ADR-001: 复制 `sound/` 到平级目录，而非拍平进 `data/`

- **Context**: `resource/`、`fight/`、`save/` 都被拍平到 `mods/<mod>/data/`。`sound/` 是否也拍平进 `data/`？
- **Decision**: 平级目录 `mods/<mod>/sound/`。
- **Alternatives Considered**:
  - **拍平进 `data/`**：**否决**——引擎的音频路径前缀是 `CONFIG.SoundPath = "sound/"`，不是 `data/`；拍平进 `data/` 会导致 `CC.ATKFile` 得写成 `data/atk%02d.wav`，与 `CONFIG.SoundPath` 语义冲突，且 `lib_love.lua` 的 `match("^sound/")` 守卫会失效。
  - **复制到 `mods/<mod>/data/sound/`**：**否决**——多一层无意义嵌套，且与 `CONFIG.SoundPath` 仍不匹配。
- **Consequences**:
  - ✅ 与 `CONFIG.SoundPath` 语义对齐；前缀改写逻辑最简单（`sound/` → `mods/<slug>/sound/`）。
  - ✅ 与 `data/`、`script/` 平级，产物布局一致。
  - ⚠️ 需在 `Build()` 中新增 `outSound` 目录与 `mkdirp`。

### ADR-002: 复用 `FightPicFile` 的前缀改写范式

- **Context**: `CC.ATKFile` 等是含 `%02d` 的**格式串**，不能做字面 `exists()` 检查。
- **Decision**: 仿照 `RewriteConstants` 中已有的 `FightPicFile` 分支（该分支正是「只改前缀目录，不做字面存在检查」），对三个音频常量做同样处理。
- **Alternatives Considered**:
  - **对 `%02d` 展开后逐个检查存在性**：**否决**——需知道编号上限，且展开成 200+ 次 `exists()` 调用，慢且脆。
  - **改 `Resolve` 支持格式串**：**否决**——`Resolve` 的契约是「给定文件名返回路径」，格式串不是文件名；会污染 API。
- **Consequences**:
  - ✅ 代码风格与现有 `FightPicFile` 一致；逻辑简单。
  - ⚠️ 前缀改写只在「`mods/<slug>/sound/` 目录存在」时生效；MOD 内缺失的具体编号文件由 `pcall` 兜底（与原版行为一致）。

### ADR-003: 不做 per-file 回退

- **Context**: 若 MOD 有 `sound/` 但缺某个编号（如 MOD 只有 `atk00`~`atk24`，引擎请求 `atk30`），是否回退到原版 `sound/atk30.wav`？
- **Decision**: 不做。保持现有 `pcall` 静默兜底。
- **Alternatives Considered**:
  - **逐文件回退**：**否决**——`love.audio.newSource` 只接受单路径，要做回退必须改 `lib_love.lua` 的 `PlayWAV`/`PlayMIDI` 在失败后重试原版路径。这扩大了 blast radius（引擎层），且原版行为本就是「文件缺失 → 静默无声」。用户目标（让 MOD 音效生效）已由前缀改写满足。
- **Consequences**:
  - ✅ blast radius 保持在 `tools/` + `framework/`，不动引擎。
  - ✅ 与原版「缺失即无声」行为一致。
  - ⚠️ 若某 MOD 部分缺失音效，那些编号会无声（而非回退原版）——这是可接受的，且 MOD 通常成套提供。

## Negative Constraints

- **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
- **不得修改** `reference/allmods/**`。
- **不得修改** `game/script/jyconst.lua` 中 `CC.MIDIFile`/`CC.ATKFile`/`CC.EFile` 的**定义**（它们已正确）。
- **不得**改 `CC.MIDIFile` 的前缀为 MOD（本 change 不处理 music；`game%02d.ogg` 保持原版）。
  - 注：仅当 MOD 提供 `sound/*.ogg` 时才考虑；经扫描，20/20 MOD 的 `sound/` 只有 `atk*`/`e*`/`tit`，**无 `gameNN.ogg`**，故 `MIDIFile` 前缀改写不会命中（保留在改写列表中作为对称处理，实际不生效）。
- **不得**改 `lib_love.lua` 的 `PlayWAV`/`PlayMIDI`/`PlayMPEG`。
- **不得**引入新的第三方依赖或音频库。
- **不得**把 `sound/` 拍平进 `data/`。

## Alignment Check

对照 `openspec/project/profile.md`：

- **构建期处理原则**：`sound/` 复制在构建期。✓
- **回退链一致性**：新增 `sound/` 回退，与 `data/`、`script/` 模式同构（MOD 优先 → 原版）。✓
- **零回归**：未激活 MOD 时常量不变。✓
- **引擎层不动**：只在 `ModData` 改写常量，`lib_love.lua` 不改。✓

无违规。唯一需注意：本 change 是**首次**为 `data/`、`script/` 之外的目录类型（`sound/`）建立回退链，设计上刻意保持与既有模式同构。

## Decisions

- **`kind` 命名**：`collectDataFiles` 中 `sound/` 用 `kind="sound"`（区别于 `"data"`/`"save"`/`"save-template"`），`flattenResources` 据此路由到 `outSound`。
- **小写归一**：与 `data/` 一致，`sound/` 文件名也小写归一（源 MOD 已全小写，归一为幂等）。
- **`tit.wav`**：忠实复制（不特殊处理）。引擎不引用它，但复制无害且保持「忠实拷贝」原则。
- **`MIDIFile` 是否纳入改写**：纳入（对称、低成本），但经扫描 MOD 无 `sound/game*.ogg`，实际不生效。文档中明确说明。

## Risks

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 产物体积增加（每 MOD 3~10MB 音频） | 高 | 低 | `game/mods/` 已被 `.gitignore` 忽略，不进仓库 |
| `%02d` 无法处理 3 位编号 | 已排除 | — | 实测 `string.format("%02d",100)=="100"` |
| MOD 部分缺失音效导致无声 | 中 | 低 | 与原版行为一致；ADR-003 明确不做 per-file 回退 |
| 误改 `MIDIFile` 前缀导致音乐路径错 | 低 | 中 | MOD 无 `sound/game*.ogg`；测试断言 `MIDIFile` 保持 `sound/` |
| 与 smap-rename 在 `mod_build.lua` 上冲突 | 中 | 中 | 本 change 依赖 smap-rename 先完成（manifest 已声明 Depends On） |
