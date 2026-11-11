## 1. 攻略路径定义
Traceability: [REQ-WT-002]

- [x] 1.1 定义速通攻略黄金路径
  Blast Radius: `["game/engine-web/tests/walkthrough/*"]`
  DoD:
    - [x] 路径按 `quick_pass_game.md` 顺序定义
    - [x] 每步有明确的操作序列和验证点
    - [x] 路径定义为数据表，与执行逻辑分离
    - [x] 纯用户命令，零注入

## 2. Phase 1 测试实现（开局入门）
Traceability: [REQ-WT-002]

- [x] 2.1 创建 `tests/walkthrough/main-quest.spec.js`
  Blast Radius: `["game/engine-web/tests/walkthrough/main-quest.spec.js"]`
  DoD:
    - [x] 包含 Phase 1 的 5 个测试步骤（单 test 链式执行）
    - [x] 使用 `saveTestState`/`loadTestState` 管理状态
    - [x] 每步验证终端输出包含预期内容
    - [x] 无 gameLoop error

- [x] 2.2 Step 1-3: 开局到南贤
  Blast Radius: `["game/engine-web/tests/walkthrough/main-quest.spec.js"]`
  DoD:
    - [x] choose 1 → 属性确认 → choose 1 → 进入游戏
    - [x] leave → list → 南贤居 → 进入
    - [x] 与南贤对话验证

- [x] 2.3 Step 4-5: 田伯光与闫基战斗
  Blast Radius: `["game/engine-web/tests/walkthrough/main-quest.spec.js"]`
  DoD:
    - [x] 田伯光加入/鸯刀
    - [x] 闫基居 → 格子事件 → 战斗触发

## 3. Phase 2 测试实现（队友招募）
Traceability: [REQ-WT-002]

- [x] 3.1 Step 6-12: 铁掌帮到绝情谷
  Blast Radius: `["game/engine-web/tests/walkthrough/main-quest.spec.js"]`
  DoD:
    - [x] 铁掌帮/大燕族谱
    - [x] 高升客栈/段誉加入
    - [x] 无量山洞/凌波微步
    - [x] 回族部落
    - [x] 胡斐加入
    - [x] 冰火岛/金毛
    - [x] 绝情谷/玉玺

## 4. Phase 3 测试实现（天书收集-上）
Traceability: [REQ-WT-002]

- [x] 4.1 Step 13-20: 场景导航
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] 燕子坞 → 泰山派 → 苗人凤 → 悦来客栈 → 明教分舵 → 光明顶 → 百花谷 → 绝情谷
    - [x] 纯用户命令，独立 spec

- [x] 4.2 Step 21-31: 更多场景
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] 绝情谷底 → 古墓 → 华山 → 武当 → 嵩山 → 神龙 → 成昆 → 沙漠 → 灵蛇
    - [x] 浡泥岛 → 圣堂（需确认名称字符）

## 5. Phase 4 测试实现（场景全覆盖）
Traceability: [REQ-WT-002]

- [x] 5.1 P6: 12 个剩余场景
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] 五毒教、北丑居、破廟、程瑛居、摩天崖、少林寺、星宿海、有間客棧、金蛇山洞、明教地道、高昌迷宮、龍門客棧、重陽宮、薛慕華居
    - [x] 12/14 找到，4.0 分钟
    - [x] 纯用户命令

- [x] 5.2 P7: 剩余场景
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] 云鶴崖、大輪寺、峨嵋派、崆峒派、崑侖仙境、平一指居、思過崖、擂鼓山、海邊小屋、白駝山、洪七公居、萬鱷島、霹靂堂、青城派
    - [x] 13/14 找到，3.6 分钟
    - [x] 纯用户命令

- [x] 5.3 跨 spec save/load 验证
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] P8 从 bridge-p7.json 加载存档
    - [x] loadTestState(99) 成功恢复游戏状态
    - [x] look → leave 纯用户命令流程正常
    - [x] 跨 spec 状态持久化机制可用

- [x] 5.2 通关验证
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] P10 测试创建（武道大会→霹雳堂→圣堂）
    - [x] 华山论剑对话触发
    - [x] 霹雳堂孔八拉交互
    - [x] 圣堂入口（出口系统已完善，P10 测试通过 leave→圣堂→进入）
    - [x] 无 gameLoop error
