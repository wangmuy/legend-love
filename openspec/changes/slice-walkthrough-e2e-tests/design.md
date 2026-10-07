## Context

Web MUD 已完成 Slice 0~6 的功能实现和事件系统集成，1018 个 oldevent 脚本可在 Web MUD 中执行。但缺乏对**完整游戏流程**的自动化验证。现有 e2e 测试验证单个交互点（如 NPC 对话），不覆盖多步骤组成的游戏进程。

## Goals / Non-Goals

**Goals:**
- 存档跳转机制：每个攻略步骤独立可重复执行
- 快速通关主线（Phase 1）：8-10 步覆盖核心通关路径
- 完整攻略（Phase 2）：20-30 步覆盖主线全部节点
- 测试失败不级联：任一步骤可单独重跑

**Non-Goals:**
- 覆盖 1018 个 oldevent 逐一测试（已由 event-flow-tests 覆盖泛化执行）
- 像素级 UI 验证
- 战斗 AI 正确性验证（仅验证战斗可触发和完成）

## Architecture Decision Records

### ADR-001: 存档跳转而非长链测试

- **Context**: 攻略测试的多个步骤之间有状态依赖。长链测试（单 test 包含所有步骤）中间失败难以定位，且 Playwright timeout 30s 限制不利于长链。
- **Decision**: 采用存档跳转模式。每个步骤：
  1. 加载前一步保存的存档
  2. 执行本步骤的操作
  3. 保存状态到本步骤槽位
- **Consequences**: 
  - 每个测试独立可重跑
  - 失败不级联
  - 需要 save/load 工具函数
  - 测试执行时间更长（每次 reload + 读档）

### ADR-002: 基于现有存档系统，不新增序列化机制

- **Context**: Web MUD 已有 `saveGameState(slot)` / `loadGameState(slot)` 基于 IndexedDB 的存档系统，存档数据为 Lua 表的 `encodeSimpleJSON` 序列化。
- **Decision**: 测试存档直接复用同一系统。`saveTestState(slot)` 封装为调用 `saveGameState(slot)` + 等待完成；`loadTestState(slot)` 封装为 reload page → `loadGameState(slot)`。
- **Consequences**: 与玩家存档使用同一路径，存档可手动加载验证。不需要额外的序列化/反序列化代码。

### ADR-003: 攻略路径定义为测试数据而非硬编码

- **Context**: 攻略路径（场景列表、操作序列、预期输出）如果硬编码在测试函数中，修改路径需要改测试代码。
- **Decision**: 将攻略步骤定义为数据表（数组），每个步骤包含 `{ action, expected }`。测试框架遍历数据表执行。后续可切换不同路线（正派/邪派/速通）只需换数据。
- **Consequences**: 需要设计攻略步骤数据格式。新增路线时不需要新测试文件。

## 存档跳转流程

```lua
-- 测试 save/load 工具函数设计

-- 保存当前游戏状态到槽位
-- 原理: 调用 saveGameState(slot)，等待 IndexedDB 写入完成
-- slot: 数字 1~20
function saveTestState(slot)
    return saveGameState(slot)
end

-- 从槽位加载游戏状态
-- 原理: reload 页面 → 等待 worker 就绪 → loadGameState(slot)
-- slot: 数字 1~20
-- 返回: true/false
function loadTestState(slot)
    -- page.reload()
    -- waitForPageReady()
    -- return loadGameState(slot)
end
```

## 攻略步骤数据格式

```javascript
// 攻略路径定义（数据）
const mainQuestPath = [
  {
    step: 1,
    name: "开局-选择新游戏",
    action: async (page) => {
      await typeCmd(page, 'choose 1');
      await page.waitForTimeout(3000);
      await typeCmd(page, 'choose 1');
    },
    verify: async (page) => {
      const lines = await getTermLines(page);
      expect(lines.join('\n')).toContain('新游戏开始');
    },
    saveSlot: 1,
    loadSlot: null  // 第一步不需要加载
  },
  {
    step: 2,
    name: "与软体娃娃对话",
    loadSlot: 1,    // 加载上一步存档
    action: async (page) => {
      await typeCmd(page, 'choose 1'); // 选择软体娃娃
      await page.waitForTimeout(1000);
      await typeCmd(page, 'choose 1'); // 选对话
    },
    verify: async (page) => {
      const lines = await getTermLines(page);
      expect(lines.join('\n')).toContain('软体娃娃');
    },
    saveSlot: 2
  },
  // ... 后续步骤
];
```

## 攻略主线路径（按 quick_pass_game.md 顺序）

```
Phase 1: 开局入门 (Steps 1-5)
═══════════════════════════════════════════

 1. 开局 → 选择新游戏 → 确认属性
 2. 主角的家 → leave → MMAP → 南贤居
 3. 与南贤对话（获得初始指引）
 4. 田伯光加入 → 拿鸯刀
 5. 闫基居 → 战斗 → 胡家刀法

Phase 2: 队友招募 (Steps 6-12)
═══════════════════════════════════════════

 6. 铁掌帮 → 大燕族谱
 7. 高升客栈 → 段誉加入
 8. 无量山洞 → 凌波微步
 9. 回族部落
10. 胡斐居 → 胡斐加入
11. 冰火岛 → 金毛
12. 绝情谷 → 玉玺/断肠草

Phase 3: 天书收集 (Steps 13-25)
═══════════════════════════════════════════
昆仑仙境 → 神雕洞 → 古墓/《神雕侠侣》 → 燕子坞 →
泰山派 → 苗人凤居 → 悦来客栈令狐冲 → 黑龙潭 →
一灯居 → 药王庄 → 衡山派 → 雪山派 → 金轮寺 → 明教分舵

Phase 4: 后期 (Steps 26-40)
═══════════════════════════════════════════
光明顶 → 华山派 → 金蛇洞 → 武当山 → 嵩山 →
神龙教/《鹿鼎记》 → 冰火岛 → 闯王山洞/《雪山飞狐》 →
破庙 → 成昆居 → 沙漠废墟/《白马啸西风》 → 北丑居 →
冰火岛(屠龙刀) → 光明顶(龙王) → 回族部落/《书剑恩仇录》

Phase 5: 通关 (Steps 40+)
═══════════════════════════════════════════
灵蛇岛 → 渤泥岛/《碧血剑》 → 鸳鸯岛/《鸳鸯刀》 →
侠客岛/《侠客行》 → 福威镖局 → 天宁寺/《连城诀》 →
梅庄 → 光明顶/《倚天屠龙记》 → 黑木崖/《笑傲江湖》 →
丐帮/《天龙八部》 → 苗人凤/《飞狐外传》 →
桃花岛/《射雕英雄传》 → 华山论剑 → 圣堂(通关)
```

## Review Checklist

1. `saveTestState(1)` + `loadTestState(1)` 往返后游戏状态一致（金钱、物品、位置）
2. Phase 1 全部通过且总执行时间 < 5 分钟
3. 所有攻略测试不产生 gameLoop error
4. 每个场景交互使用纯用户命令（`list`、`choose N`、`leave`）
