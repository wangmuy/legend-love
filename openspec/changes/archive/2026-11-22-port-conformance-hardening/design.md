---
status: active
created: 2026-11-22
---
# Design: port-conformance-hardening

## ADR-PORT-040：为什么必须「源码级」校验引擎完整性

### Context

`test_engine_conformance` 原本这样检查「4 引擎有没有实现全部契约」：

```lua
for _, e in ipairs(engines) do
    local ok, mod = pcall(require, e.path)
    for _, d in ipairs(contract) do
        if mod[d.mod][d.fn] == nil then missing[...] = ... end
    end
end
```

看起来完全正确 —— require 引擎、查表、缺了就报。**实际是空转的。**

### 根因

三个引擎都这样开头：

```lua
local EngineAPI = require("engine-love2d.engine_api")
```

而 `engine_api.lua` 为**每个**契约都声明了空桩：

```lua
function M.file.read(filename) end     -- 返回 nil
function M.app.quit() end
```

于是：

```
engine_mud     == engine_api   (true)   ← 同一张表
engine_test    == engine_api   (true)
engine_love2d  == engine_api   (true)
engine_web     == engine_api   (false)  ← 唯一例外，自己 local EngineAPI = {}
```

`mod[d.mod][d.fn]` 永远是那个空桩函数，**永不为 nil** → 检查永远 PASS。

**实测证据**：MUD 当时实缺 7 个契约

```
app.quit, file.createDirectory, file.lines, file.openFile,
file.read, file.write, time.getTimeSeconds
```

全部靠空桩继承，而空桩返回 nil —— 意味着「调用成功但什么也没干」。
这条断言照样 PASS。

### Decision

**改用源码级检查**：读引擎源码，找

```
EngineAPI.file.read = function
function EngineAPI.file.read(
```

两种形态任一即算实现。这与 `test_engine_api.lua` 里已有的 `newFns`
检查（「不能只靠 engine_api 空桩继承」）是同一手法 —— 本次是把那条
经验从「新契约」推广到「全部契约」。

同时把检查范围从 3 引擎扩到 **4 引擎**（原来漏了 LÖVE）。

### Alternatives

**（A）改成每个引擎 `local EngineAPI = {}` 起表。**
最彻底（测试可真正隔离），但要动 4 个引擎的全部实现方式，且 95 个契约
的继承关系要重写。风险远大于收益 —— 生产运行时只加载一个引擎，
共享表**没有实际危害**；危害只出现在「同进程加载多个引擎」的测试场景，
而那已被源码级断言规避。

**（B）保留查表，但先 `EngineAPI.sprite = {}` 清空再 require。**
更 hack，且会破坏引擎之间的合法共享（Web 也依赖部分 framework 常量）。

**（C，选中）源码级断言。**

### Consequences

- ✅ 三代漏洞（缺 7 个 / 缺 3 个）一次暴露
- ✅ 负向对照真的能 FAIL（删掉 MUD 的 `file.read` → 「MUD 缺 1 个契约实现」）
- ⚠️ 源码级检查有「文本匹配」的固有弱点：注释里写 `EngineAPI.x.y = function`
  会误判为「已实现」。本项目的注释风格是 `--` 开头整行，实测未误判；
  真出问题时用 `stripComments` 处理（已有现成函数）。

## ADR-PORT-041：注入点返回 nil 是合法语义，调用方必须用 getMyPicOr

### Context

`GameHooks.getMyPic()` 的文档明确写：

```
-- **未注册时的行为**：返回 nil / 哨兵值，**不抛错**。
--   调用方必须能容忍这种状态（单元测试环境就是这样）。
```

但 8 个调用点都直接写 `JY.MyPic = GameHooks.getMyPic()` —— 把 nil 灌进
一个**下游要做算术**的字段（`map_render.buildingSort` 里 `mypic * 2`）。

**实测复现**：`test_auto_move.lua` 单模块跑必崩

```
attempt to compare number with nil  (:475)
```

而全量跑不暴露 —— 因为 `mod_boot` 先跑、注册了 hook。
**这类「只在特定执行顺序下炸」的缺陷最难查。**

### Decision

保留 `getMyPic()` 的 nil 语义（它是对的：`sprite_anim` 的测试依赖它），
新增显式入口：

```lua
GameHooks.getMyPicOr(fallback)   -- 拿不到就返回 fallback
```

8 个调用点全部改用它，并传当前值作 fallback：

```lua
JY.MyPic = GameHooks.getMyPicOr(JY.MyPic)      -- 退化为「不变」
EngineAPI.map.drawMain(x, y, GameHooks.getMyPicOr(JY.MyPic))
```

### Alternatives

- **改 `getMyPic()` 返回默认值**：会破坏 `test_sprite_anim` 的
  「未注册时返回 nil」断言，且让「未注册」这个状态不可检测。
- **每个调用点写 `local v = getMyPic(); if v then ... end`**：8 处重复，
  且下次新增调用点时极易忘（正是本次缺陷的成因）。

### Consequences

- ✅ 调用方不可能再把 nil 灌进 `JY.MyPic`
- ✅ 「未注册」状态仍可检测（`getMyPic()` 语义不变）
- ⚠️ fallback 本身也可能是 nil（`JY.MyPic` 初始值为 nil 时）——
  所以 `getMyPicOr` 不承诺「一定返回 number」，只承诺「不把 nil 变成
  一个新的 nil 来源」。真正保证 number 的是调用方传的 fallback。

## ADR-PORT-042：为什么 mod_data 的 io.open 必须补（不只是「兜底」）

### Context

`port-engine-boot` Task 6 的 DoD 是「4 处主路径 io/os 收进契约」，
做完后审计发现 `framework` 里还有 7 处 `io.open`。逐条看：

| 位置 | 性质 |
|---|---|
| `mod_data.exists` / `readFileRaw` / `writeFile` / `readActiveFile` | 已 EngineAPI 优先 ✓ |
| `mod_ini.readFile` | 已 EngineAPI 优先 ✓ |
| **`mod_data.readActiveFile`** | **io.open 唯一通道** |
| **`mod_data.WarRecordCount`** | **io.open 唯一通道** |

后两处不是兜底，是**主路径**。

### Decision

两处都改成「EngineAPI 优先 + io.open 兜底」：

- `readActiveFile` → `EngineAPI.file.read`
- `WarRecordCount` → `EngineAPI.file.getSize`（只问大小，不该打开文件）

### Consequences

- ✅ `.love` 打包 / Android 下 MOD 能正常激活（原来静默失败）
- ⚠️ `readActiveFile` 的契约返回 nil 时**不能立刻 return nil** ——
  测试里常把 `file.read` mock 成只认某个白名单，直接把 nil 返回会让
  那些测试挂。所以保留「契约说读不到 → 仍试 io.open」这一步。
