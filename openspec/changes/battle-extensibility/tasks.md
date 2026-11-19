# Tasks: battle-extensibility

> 父 slice: `engine-portability`
> 两阶段策略（ADR-BE-003）：**阶段 1 纯搬移（零逻辑改动）**，阶段 2 才改结构。
> 每阶段一个 commit，阶段 1 出问题可完全回退。

## Task 1：搬移前的依赖测绘

**Blast Radius**：`openspec/changes/battle-extensibility/deps.md`（新）

**DoD**：
- [x] 列出 54 个 `War_*` 函数的定义位置与调用者
- [x] 列出 19 个 `War_*Coroutine` 的定义位置与调用者
- [x] 标出互相引用（30 个函数有交叉调用，必须整体搬）
- [x] 标出 `Rnd` / `GetWarMap` / `SetWarMap` / `WarDrawMap` 的调用分布
- [x] 确认哪些 `War_*` 读 `JY` / `WAR` 全局（全部通过全局访问，保留原形式）
- [x] 实测体积：战斗代码约 2560 行（jymain 1501 + war_async 1651 中的战斗部分）
- [x] 发现 7 个「零调用」函数其实是**菜单回调引用**（无括号），不是死代码

---

## Task 2：阶段 1 — 纯搬移到 script/battle/（零逻辑改动）

**Blast Radius**：`game/script/battle/*.lua`（5 个新文件）、`game/script/jymain.lua`

> **实施后的范围调整**：原计划还要搬 `framework/war_async.lua` 的 19 个协程。
> 实测发现它**不是纯字节搬移**：
>   - 用 40 处 framework 模块引用（FlowFacade / MenuAsync / InputAsync 等）
>   - 有 20 个 `local` 前向声明
>   - 导出 `WarAsync.XXXCoroutine` 供 async_globals 消费
> 要搬必须改造成「模块 + 依赖注入」，那是结构改造，属于阶段 2。
> **因此阶段 1 只搬 script/jymain.lua 的 66 个全局函数**，
> 协程搬移并入 Task 5（war_async 降为适配层）。

**DoD**：
- [x] 新建 `script/battle/battle_data.lua` —— 4 个地图数据函数
- [x] 新建 `script/battle/battle_render.lua` —— 3 个绘制函数
- [x] 新建 `script/battle/battle_action.lua` —— 17 个动作函数
- [x] 新建 `script/battle/battle_ai.lua` —— 18 个 AI 函数
- [x] 新建 `script/battle/battle_flow.lua` —— 24 个流程/菜单函数
      （**注：阶段 1 只含全局函数，19 个协程仍在 war_async，见 Task 5**）
- [x] **所有 66 个函数名不变**（仍是 `function War_X()` 全局定义形式）
- [x] `script/jymain.lua` 删除战斗区块（7348 → 4716 行）
- [x] `jymain.lua` 末尾用 `ScriptLoader.load` 加载 5 个 battle 文件
      （经 `ModData.ScriptFile` ⇒ MOD 可覆盖）
- [x] **逻辑一字不改**（切分后逐块 `luac -p` 验证 66/66 通过）
- [x] 66 个战斗函数实测全部可用（逐个查 `_G`）
- [x] Lua 5.1/5.3/5.4/5.5 全量测试零失败（3556/0）
- [ ] **实机验证**：手动战斗一场、自动战斗一场（需用户配合）
- [x] 一个 commit

---

## Task 3：阶段 2A — battle_rules 策略接口

**Blast Radius**：`game/script/battle/battle_rules.lua`、`game/script/battle/battle_flow.lua`

**DoD**：
- [ ] `battle_rules.lua` 实现 ADR-BE-002 的六字段契约
      （`kind` / `init` / `tick` / `requestAction` / `onKey` / `isOver`）
- [ ] `kind = "turnbased"` 的完整实现（复刻现有回合制行为）
- [ ] `kind = "atb"` 与 `kind = "realtime"` 只留**接口骨架**（返回 true，无实际逻辑）
- [ ] `battle_flow.lua` 在战斗开始时读 `battle_rules.kind`，按 kind 选路径
- [ ] 全量测试零失败
- [ ] 实机验证：回合制战斗零回归

---

## Task 4：阶段 2B — dt 传播

**Blast Radius**：`game/framework/war_async.lua`、`game/framework/event_bridge.lua`

**DoD**：
- [ ] `war_async.tick(dt)` 新增：战斗进行中时调 `battle_rules.tick(ctx, dt)`
- [ ] `EventBridge:update(dt)` 里加一行 `pcall(WarAsync.tick, dt)`
- [ ] turnbased 下 tick 为空实现（零开销）
- [ ] 单元测试：注入 dt 后 `battle_rules.tick` 被调用且收到正确值
- [ ] 全量测试零失败
- [ ] 实机验证：回合制战斗零回归

---

## Task 5：阶段 2C — war_async 降为适配层

**Blast Radius**：`game/framework/war_async.lua`

**DoD**：
- [ ] `war_async.lua` 不再定义战斗算法（只有协程调度 + tick 转发）
- [ ] `grep -c 'function War_' game/framework/war_async.lua` = 0
- [ ] `grep -cE 'War_(CalMoveStep|MovePerson|WugongHurt|AutoSelectEnemy)'`
      `game/framework/war_async.lua` = 0
- [ ] 全量测试零失败
- [ ] 实机验证：回合制战斗零回归
- [ ] 一个 commit

---

## Task 6：门禁 `gate_battle_extensibility.sh`

**Blast Radius**：`game/tests/gate_battle_extensibility.sh`（新）

**DoD**：
- [x] A. `framework/` 无 `War_*` 算法定义
- [x] B. `script/battle/` 六个模块都存在
- [x] C. `battle_rules.lua` 有 `kind` 且值在合法集合
- [x] D. `framework/war_async.lua` 无伤害公式特征（当前 INFO，阶段 2 变 FAIL）
- [x] E. jymain 按依赖顺序加载 battle 模块 + 单独加载 battle_rules
- [x] F. battle 加载走 ScriptLoader（MOD 回退链）
- [x] **负向对照 3 组实测生效**：
      加 `function War_TestAlgo()` → FAIL（framework 有 War_ 定义）
      删 `battle_ai.lua` → FAIL（模块缺失）
      改 `battle_rules` 成 `return {}` → FAIL（缺 kind）

---

## Task 7：MOD 覆盖验证（本 change 的**核心验收**）

**Blast Radius**：`game/mods/_battle_probe/script/battle/battle_rules.lua`（新，测试用 MOD）

**DoD**：
- [x] 建一个最小测试 MOD，只放 `script/battle/battle_rules.lua`
      （`return { kind = "realtime", probe = true }`）
- [x] 激活该 MOD，调 `ScriptLoader.load("script/battle/battle_rules.lua")`
- [x] **实测断言通过**：
      激活 MOD → `kind = realtime, probe = true`（MOD 版本生效）
      未激活   → `kind = turnbased`（原版生效）
- [x] 删除该测试 MOD（不留产物）
- [x] **这是「战斗可扩展」的唯一硬证据**

---

## Task 8：全量验证

**DoD**：
- [ ] Lua 5.1/5.3/5.4/5.5 全量测试全绿（记录断言数）
- [ ] `luac5.1 -p` / `luac55 -p` 全仓零失败
- [ ] LÖVE 11.5 启动冒烟无报错
- [ ] 四组门禁全 PASS（`gate_engine_contract` / `gate_battle_extensibility` /
      `gate_input_actions` / `gate_base_music` / `gate_ascii`）
- [ ] **实机完整走查**：手动战斗（移动/攻击/武功/道具/中毒/结束）、
      自动战斗、战斗结算（经验/升级/掉落）
