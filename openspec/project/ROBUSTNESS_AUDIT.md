# 原版健壮性审计（2026-11-20）

> 触发问题：「War_WugongHurtNeili 的 while true 会死循环」。
> 结论：**位置记错了** —— 那个 `while true` 在 `War_WugongHurtLife`，
> `War_WugongHurtNeili` 没有循环。但顺着查下去找到 8 个缺陷。

## 一、已修（根因修复，非补丁）

| # | 位置 | 缺陷 | 根因 | 可达性 |
|---|------|------|------|--------|
| 1 | `jymain.lua` `Rnd()` | `Rnd(0)` 跨版本不一致 | `math.random(0)` 在 5.4+ 返回随机整数，5.1/5.3 抛错 | **高**（105 处调用，任一参数算成 0 即中招） |
| 2 | `battle_action` `War_WugongHurtLife` | `while true` 无显式下界 | 靠 level 递减到负退出；`消耗=0 且 内力<0` 时恒真 | 中（内力被直写为负时） |
| 3 | `battle_action` `War_WugongHurtNeili` | 缺 level 钳制 | 与 HurtLife 不对称（后者有递减，前者没有） | 中（左右互搏第二次攻击） |
| 4 | `battle_ai` `War_AutoMove` | 回溯循环无进度守卫 | 靠"总能找到 i-1"的隐含假设，目标不可达时不成立 | **高**（敌人/我方被围住时必走） |
| 5 | `battle_flow` `War_EndPersonData` | 除 `liveNum` 无零守卫 | 信任外部 `warStatus` 参数 | 中（异常流程传 (1,1) 且我方全灭） |
| 6 | 15 处等级计算 | `武功等级` 无上界钳制 | 字段只定义 1..10 档，代码不检查 | 中（存档/MOD 直写 >= 1000） |
| 7 | `jymain.lua:1351` | `200/xnum` 无零守卫 | `CC.MenuThingXnum` 可被 MOD 设为 0 | 低（但后果是索引无限增长） |
| 8 | `game_states.lua:590` | `elapsed/frameDuration` 无守卫 | `CC.AnimationFrame` 可被设为 0 | 低（表现为动画静默失效） |

### 共同的根因模式

**「信任上游数据的合法性」**。原版是 C 移植而来，那时数据都是内置常量；
现在是 Lua + MOD 体系，同一份代码要面对：
- MOD 改数据（`war.sta` / `wugong.sta` / `jyconst` 常量）
- 存档被编辑
- 事件脚本 `instruct_*` 直接写字段
- 跨 Lua 版本（5.4 的 `math.random(0)` 语义变了）

所以修复策略统一为：**在单点做钳制/守卫，而不是在调用点逐个补 if**。

## 二、确认有界、无需修改

| 位置 | 退出条件 | 为什么有界 |
|------|---------|-----------|
| `battle_flow` 升级判定 | `tmplevel >= CC.Level` | tmplevel 单调 +1 |
| `battle_flow` 随机练物 | `enough[makeID]==1` | `num2 < num1` 保证必有空位 |
| `battle_flow` `War_Manual` | `abs(r) ~= 1` | r 必返回数值；"移动后继续"是**设计意图** |
| `battle_flow_coroutines` `War_ManualCoroutine` | `abs(r) ~= 7` | 同上 |
| `battle_flow` 队伍选择 | `WAR.PersonNum > 0` | 玩家必选至少一个 |
| `battle_action` 方向选择 | `direct >= 0` | 四个方向键必命中其一 + ESC 退出 |

## 三、跨版本行为差异（重要）

实测验证（同脚本，四个解释器）：

```
math.random(0):
  5.1 → error "bad argument #1 to 'random' (interval is empty)"
  5.3 → error 同上
  5.4 → 返回 8426388018768443949   ← 不报错
  5.5 → 返回 5087305168877803784   ← 不报错

1/0:
  所有版本 → inf（不报错）
  inf 经 limitX(0, max) → max（静默钳到上限）
```

**教训**：不要假设"非法输入会抛错"。5.4 的 `math.random(0)` 和所有版本的
`1/0` 都会**静默返回错误值**，这类缺陷比崩溃更难查。

## 四、仍未处理（记录在 TODO）

| 项 | 原因 |
|----|------|
| `battle_render.lua` 的 `lib.PicGetXY / PicLoadCache / DrawWarMap` 与 `SpriteAtlas` 双轨 | 需整体迁移，属独立 change |
| `jymain.lua` 33 处 `lib.Pic*` | 同上 |
| `WarLoad` 的 `warid` 越界只 JY_Error 不返回错误码 | 调用方无法区分"加载成功"与"静默失败" |
| `WAR.Person` 固定 26 槽，`WarSelectEnemy` 最多加 20 + `WarSelectTeam` 最多 6 = 26 | **刚好够，无余量**；MOD 改 `TeamNum` 或敌方数量即越界 |
