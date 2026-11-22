# Design: port-audio-semantics

## ADR-PORT-022：音乐「按编号」与「按文件名」是两个契约，不能合并

### Context

现状（实测 2026-11-21）：

```lua
-- 契约层（engine_api.lua）
function M.audio.playMusic(filename) end
function M.audio.playSequence(id, opts) end      -- 0 处调用（死契约）

-- script 层（jymain.lua:2315）
function PlayMIDI(id)
    JY.CurrentMIDI = id
    if JY.EnableMusic == 0 then return end
    if id >= 0 then
        EngineAPI.audio.playMusic(string.format(CC.MIDIFile, id+1))
    end
end

-- 引擎层（lib_love.lua:826）
function PlayMIDI(filename)
    -- 裸文件名 → 拼 CONFIG.SoundPath
    -- 无扩展名 → 按 {.ogg, .mp3, .mid} 找
    -- 找不到 → 回落 sound/ 同名
end
```

三处都叫「播音乐」，但各持一半语义：

| 职责 | 现在住在哪 |
|------|-----------|
| 编号 → 文件名模板（`game%02d`） | `jyconst.lua`（游戏常量） |
| 编号 +1 | `jymain.lua`（script） |
| 扩展名候选 `{ogg, mp3, mid}` | `lib_love.lua`（引擎） |
| MOD 回落 `sound/` | `lib_love.lua`（引擎） |
| 是否该播（`EnableMusic`） | `jymain.lua`（script） |
| 当前音乐 id 心智 | `jymain.lua`（script） |

换引擎时，新实现必须**猜**扩展名候选与 MOD 回落规则 —— 因为契约没写。

### Decision

**两个契约，职责边界明确**：

```lua
--- 按游戏的音乐编号播放（编号由游戏定义，引擎不解释编号含义）
--
-- 引擎 SHALL：
--   1. 用游戏提供的模板（经 app.setMusicTemplate 或构造参数）把 id 转成文件名
--   2. 按 {.ogg, .mid, .mp3} 顺序找候选（顺序与既有 lib_love 一致）
--   3. 找不到时回落「打包内置 sound/ 同名」
--   4. 循环播放
-- @param id number 游戏音乐编号（可为负数表示停止）
function M.audio.playSequence(id) end

--- 按完整文件名播放（不推测扩展名、不做路径回落）
--
-- 消费者：工具/测试/未来的剧情音效。
-- 游戏内 BGM SHALL 走 playSequence。
-- @param filename string 完整路径（含扩展名）
function M.audio.playMusic(filename) end
```

`app` 模块新增一个**模板注册**契约（引擎要拼接就必须知道模板）：

```lua
--- 注册音乐文件名模板（游戏启动时调用一次）
--
-- 为什么必须显式注册而不是引擎自己读 CC：
--   CC 是游戏常量表，引擎不该知道它的字段名（ADR-PORT-013 的同一条原则）。
--   引擎拿到的只是一个「printf 风格模板 + 起始偏移」。
--
-- @param template string 例如 "sound/game%02d"（**不含扩展名**）
-- @param startOffset number id → 模板参数的偏移（实测游戏用 +1）
function M.app.setMusicTemplate(template, startOffset) end
```

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 只留 `playMusic(filename)`，script 继续拼 | 扩展名候选/MOD 回落永远留在引擎，新引擎必须自己发现 |
| 只留 `playSequence(id)` | 工具/测试没有「编号」概念；造一个假 id 表很别扭 |
| 引擎读 `CC.MIDIFile` | 引擎依赖游戏常量表 = 上一轮刚消除的耦合 |
| 把「+1 偏移」写死在引擎 | 这是游戏资产约定（MOD 构建期改名的产物），不该硬编码进引擎 |

### Consequences

**Positive**

- 新引擎实现 `playSequence` 只需「拿模板 + 找扩展名 + 回落」，规则全在契约注释里
- `CC.MIDIFile` 不再带 `.ogg` 硬编码，模板与扩展名解耦
- `playMusic` 语义收窄后，测试桩可以精确断言

**Negative**

- `app.setMusicTemplate` 是**新契约**（契约数 +1）
- 启动顺序有依赖：必须 `init` 之后、第一次 `PlayMIDI` 之前注册
  → 由 `JYMainAdapter.init` 负责（它已经在那里初始化精灵）

## ADR-PORT-023：`EnableMusic==0` 必须调 `stopMusic`，而不是「不调播放」

### Context

```lua
function PlayMIDI(id)
    JY.CurrentMIDI = id
    if JY.EnableMusic == 0 then
        return                        -- ← 什么都不做
    end
    ...
end
```

`JY.EnableMusic` 是存档字段（`jymain.lua:167`，随 `SaveRecord` 持久化）。
玩家在存档里关掉音乐后，再次进入游戏时**已在播的 BGM 不会被停**，
且每次 `PlayMIDI` 只是不切换 —— 表现是「音乐开关无效，重启才生效」。

### Decision

```lua
if JY.EnableMusic == 0 then
    EngineAPI.audio.stopMusic()
    return
end
```

### 依据

- `EngineAPI.audio.stopMusic` 已存在且 4 引擎都有实现（LÖVE：`lib.PlayMIDI("")`）
- `JY.CurrentMIDI` 已经记录 id，恢复时 `PlayMIDI(JY.CurrentMIDI)` 即可
- 这是**行为修复**，不是语义重设计：原版 Pascal 的 `PlayMIDI` 在
  `EnableMusic=0` 时也是停止当前音乐（`kys_main.pas` 的 `if JY.EnableMusic=0 then StopMIDI`）

### Consequences

**Positive**：音乐开关立即生效（无需重启）
**Negative**：每次 `PlayMIDI` 都可能在关闭状态下多调一次 `stopMusic`
（无害：LÖVE 的 `stop` 对 nil source 是 no-op；但 `lib_love.PlayMIDI("")`
在 `currentMusic == nil` 时直接 return，所以零开销）

## ADR-PORT-024：`playVideo` 保留名字，契约写清「视频优先，无能力回退音频」

### Context

实测：

```
$ find game -iname '*.mpg' → 0 命中
$ grep 'function PlayMPEG' lib_love.lua:897 → function PlayMPEG(filename) PlayMIDI(filename) end
```

两个调用点（`jymain.lua:232` / `jymain_adapter.lua:403`）都传
`CONFIG.DataPath .. "start.mpg"` —— **文件不存在**，每次启动都在
「用音频解码器载入 .mpg」上失败一次（`pcall` 吞掉，无日志）。

### Decision

- **保留** `audio.playVideo(filename, skipKey)` 契约（不删）
- 契约注释改为：**「引擎应尝试真视频播放；无能力时回退音频（可能失败，不得抛错）」**
- LÖVE 实现：显式写「无视频能力 → 尝试音频；失败则记日志返回 false」
- **新增返回语义**：`boolean` 已定义为「是否完整播放」。无能力时返回 `false`
  （当前实现无条件 `return true`，语义错）

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 删掉 `playVideo` 契约 | 游戏有真实的开场视频意图（原版有 .mpg），将来加 FFmpeg 要用 |
| 保持「只播音频」 | 契约名与实际行为不符，会误导新引擎实现者 |
| 让 script 删掉这两个调用 | 会丢掉「原版有开场视频」这个信息；且不是本 change 的职责 |

### Consequences

**Positive**：契约名与意图一致；返回值有意义
**Negative**：需要引擎能区分「文件不存在」与「无视频能力」两种情况（日志区分即可）

## Negative Constraints

- **不得**让 `playSequence` 收字符串（否则与 `playMusic` 又重叠）
- **不得**硬编码 `id+1` 到引擎（属游戏资产约定）
- **不得**在引擎里读 `CC.*` / `JY.*`（`setMusicTemplate` 就是为消除这个）
- **不得**改动音量语义（0..128 线性，ADR-AS-003 已定案）

## Review Checklist

- [ ] `engine_api.lua` 的 audio 段：`playMusic` 只收完整文件名、`playSequence` 只收编号
- [ ] `app.setMusicTemplate(template, startOffset)` 在 4 引擎都有
- [ ] `JYMainAdapter.init` 里注册模板（在 `PlayMIDI` 首次调用之前）
- [ ] `EnableMusic==0` → `stopMusic`，有单测
- [ ] `playVideo` 返回 false（无能力/文件缺失），有单测
- [ ] `gate_run_mod.sh` 20 MOD 通过（模板变更最大的回归面）
