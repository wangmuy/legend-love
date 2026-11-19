# Tasks: battle-extensibility

> 父 slice: `engine-portability`
> 两阶段策略（ADR-BE-003）：**阶段 1 纯搬移（零逻辑改动）**，阶段 2 才改结构。
> 每阶段一个 commit，阶段 1 出问题可完全回退。

## Task 1：搬移前的依赖测绘

**Blast Radius**：`openspec/changes/battle-extensibility/deps.md`（新）

**DoD**：
- [ ] 列出 54 个 `War_*` 函数的定义位置与调用者
- [ ] 列出 19 个 `War_*Coroutine` 的定义位置与调用者
- [ ] 标出互相引用的环（若有）
- [ ] 标出 `Rnd` / `GetWarMap` / `SetWarMap` / `WarDrawMap` 的调用分布
- [ ] 确认哪些 `War_*` 读 `JY` / `WAR` 全局（这些必须保留全局访问方式）

---

## Task 2：阶段 1 — 纯搬移到 script/battle/（零逻辑改动）

**Blast Radius**：`game/script/battle/*.lua`（5 个新文件）、
`game/framework/war_async.lua`、`game/script/jymain.lua`

**DoD**：
- [ ] 新建 `script/battle/battle_flow.lua` —— 搬入战斗流程入口
- [ ] 新建 `script/battle/battle_rules.lua` —— 阶段 1 只放一个占位
      （`return { kind = "turnbased" }`），不含逻辑
- [ ] 新建 `script/battle/battle_ai.lua` —— 搬入敌方 AI（`War_AutoSelectEnemy` 等）
- [ ] 新建 `script/battle/battle_action.lua` —— 搬入动作执行
      （`War_CalMoveStep` / `War_MovePerson` / `War_Fight_Sub` /
      `War_WugongHurtLife` / `War_WugongHurtNeili` 等）
- [ ] 新建 `script/battle/battle_render.lua` —— 搬入战斗绘制（`WarDrawMap` 等）
- [ ] **所有 `War_*` 函数名不变**（仍用 `function War_Xxx()` 全局定义形式，
      因为阶段 1 不改调用方）
- [ ] `framework/war_async.lua` 的 19 个 `War_*Coroutine` 搬到 `battle_flow.lua`
- [ ] `script/jymain.lua` 里对应的 54 个 `War_*` 删除（已搬到 battle 目录）
- [ ] `script/jymain.lua` 或 `battle_flow.lua` 里补 `require`/`dofile` 让
      全局函数在新位置能加载到
- [ ] **逻辑一字不改**（git diff 应只有"移动"与"删除原位置"）
- [ ] Lua 5.1/5.3/5.4/5.5 全量测试零失败
- [ ] **实机验证**：手动战斗一场、自动战斗一场，结果与改造前一致
- [ ] 一个 commit

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
- [ ] A. `framework/` 无 `War_*` 算法定义（`grep -c '^function War_' framework/` = 0）
- [ ] B. `script/battle/` 五模块都存在
- [ ] C. `battle_rules.lua` 有 `kind` 字段
- [ ] D. `framework/war_async.lua` 无伤害公式特征
      （`War_WugongHurt|War_CalMoveStep|War_AutoSelectEnemy` = 0）
- [ ] **负向对照 4 组**：
      往 framework 加一个 `function War_Test()` → FAIL
      删掉 `battle_render.lua` → FAIL
      去掉 `kind` 字段 → FAIL
      往 war_async 加 `War_WugongHurtLife` 调用 → FAIL

---

## Task 7：MOD 覆盖验证（本 change 的**核心验收**）

**Blast Radius**：`game/mods/_battle_ext_probe/script/battle/battle_rules.lua`（新，测试用 MOD）

**DoD**：
- [ ] 建一个最小测试 MOD，只放 `script/battle/battle_rules.lua`，
      `kind = "realtime"` + 空 tick + 日志
- [ ] 激活该 MOD，进入战斗
- [ ] 断言：加载的是 MOD 的 `battle_rules`（日志出现 / kind 被读到 realtime）
- [ ] 删除该测试 MOD（不留产物）
- [ ] **这是「战斗可扩展」的唯一硬证据** —— 其余断言都只是准备工作

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
