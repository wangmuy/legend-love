## Context

Web MUD 的 Slice 0~6 和事件系统集成已完成，所有 basic 游戏功能可用。但缺乏"从开局到通关"的整体验证。攻略测试按 `quick_pass_game.md` 速通攻略顺序，以玩家身份走完整条主线，在每个节点验证输出来确认集成正确性。

## Goals / Non-Goals

**Goals:**
- Phase 1: 5 步，开局入门（南贤 → 田伯光 → 唐诗 → 闫基战斗）
- Phase 2: 7 步，队友招募（铁掌帮 → 段誉 → 无量山洞 → 回族部落 → 胡斐 → 冰火岛 → 绝情谷）
- Phase 3: 13 步，天书收集
- 所有步骤使用纯用户命令，无注入

**Non-Goals:**
- 覆盖 100% 游戏内容（按攻略已有 >40 步）
- 验证战斗 AI 策略正确性
- 与 Love2D 版的行为一致性验证

## Architecture Decision Records

### ADR-001: 攻略路径定义为数据而非代码

- **Context**: 攻略测试的步骤序列按 `quick_pass_game.md` 定义，可能调整。
- **Decision**: 将攻略路径定义为 JavaScript 数组，每个元素包含 `action` 和 `verify` 函数。
- **Consequences**: 修改路径只需改数据表，不改测试框架。

### ADR-002: 所有阶段在同一测试文件中

- **Context**: 所有阶段是同一份攻略的连续步骤。
- **Decision**: 所有 Phase 在同一个 `main-quest.spec.js` 中，通过 `test.describe` 分组。
- **Consequences**: 减少文件数量，每个 Phase 可独立运行。

### ADR-003: 纯用户命令，零注入

- **Context**: 测试应模拟真实玩家操作，不应用 luaEval 或测试专用代码操纵游戏状态。
- **Decision**: 所有 steps 只使用 `cmd(page, 'choose N')`、`cmd(page, 'leave')`、`cmd(page, 'list')` 等用户命令。验证只检查终端输出。
- **Consequences**: 测试更接近真实用户体验，但需要游戏功能完整才能推进。

## 黄金路径（按 quick_pass_game.md）

```javascript
// 完整攻略路径（31+ 步，跨 4 个 spec 文件）
```

### 已完成的 Phase

```
P1 (8 steps):  开局 → 南贤 → 田伯光 → 闫基 → 高升 → 回族 → 胡斐
P2 (7 steps):  冰火岛 → 铁掌山 → 无量 → 昆仑 → 燕子 → 泰山 → 苗人凤
P3 (5 steps):  悦来 → 明教 → 光明 → 百花 → 绝情
P4 (11 steps): 绝情谷底 → 古墓 → 华山 → 武当 → 嵩山 → 神龙 →
               成昆 → 沙漠 → 灵蛇
P5 (ongoing):  浡泥岛 → 圣堂 → 桃花岛 → 黑木崖 → 丐帮 → ... → 通关
```

## Review Checklist

1. 所有 spec 独立运行，纯用户命令，无 luaEval
2. 每个 spec 在 5 分钟内完成
3. 所有步骤不产生 gameLoop error
4. `gotoScene` 用正则从终端输出解析场景编号，不依赖固定索引
