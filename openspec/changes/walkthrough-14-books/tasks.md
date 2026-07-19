## 1. 解锁天书事件脚本
Traceability: [REQ-WT-003]

- [x] 1.1 解锁天宁寺连城诀事件（oldevent_605）
  Blast Radius: `["game/script/oldevent/oldevent_605.lua", "game/engine-web/dist/script/oldevent/oldevent_605.lua"]`
  DoD:
    - [x] `--function` 改为 `function`
    - [x] `--end` 注释取消
    - [x] Lua 语法验证通过

- [x] 1.2 解锁丐帮天龙八部事件（oldevent_523/524/525）
  Blast Radius: `["game/script/oldevent/oldevent_523.lua", "game/script/oldevent/oldevent_524.lua", "game/script/oldevent/oldevent_525.lua", "game/engine-web/dist/script/oldevent/oldevent_523.lua", "game/engine-web/dist/script/oldevent/oldevent_524.lua", "game/engine-web/dist/script/oldevent/oldevent_525.lua"]`
  DoD:
    - [x] 三个脚本全部解锁
    - [x] Lua 语法验证通过

- [x] 1.3 解锁桃花岛射雕英雄传事件（oldevent_466）
  Blast Radius: `["game/script/oldevent/oldevent_466.lua", "game/engine-web/dist/script/oldevent/oldevent_466.lua"]`
  DoD:
    - [x] `--function` 改为 `function`
    - [x] `--end` 注释取消
    - [x] Lua 语法验证通过

- [x] 1.4 解锁沙漠废墟白马啸西风事件（oldevent_654）
  Blast Radius: `["game/script/oldevent/oldevent_654.lua", "game/engine-web/dist/script/oldevent/oldevent_654.lua"]`
  DoD:
    - [x] `--function` 改为 `function`
    - [x] `--end` 注释取消
    - [x] Lua 语法验证通过

- [x] 1.5 解锁神龙教鹿鼎记事件（oldevent_607/608/609）
  Blast Radius: `["game/script/oldevent/oldevent_607.lua", "game/script/oldevent/oldevent_608.lua", "game/script/oldevent/oldevent_609.lua", "game/engine-web/dist/script/oldevent/oldevent_607.lua", "game/engine-web/dist/script/oldevent/oldevent_608.lua", "game/engine-web/dist/script/oldevent/oldevent_609.lua"]`
  DoD:
    - [x] 三个脚本全部解锁
    - [x] Lua 语法验证通过

- [x] 1.6 解锁黑木崖笑傲江湖事件（oldevent_316/318/323/324/325/326）
  Blast Radius: `["game/script/oldevent/oldevent_316.lua", "game/script/oldevent/oldevent_318.lua", "game/script/oldevent/oldevent_323.lua", "game/script/oldevent/oldevent_324.lua", "game/script/oldevent/oldevent_325.lua", "game/script/oldevent/oldevent_326.lua", "game/engine-web/dist/script/oldevent/oldevent_316.lua", "game/engine-web/dist/script/oldevent/oldevent_318.lua", "game/engine-web/dist/script/oldevent/oldevent_323.lua", "game/engine-web/dist/script/oldevent/oldevent_324.lua", "game/engine-web/dist/script/oldevent/oldevent_325.lua", "game/engine-web/dist/script/oldevent/oldevent_326.lua"]`
  DoD:
    - [x] 六个脚本全部解锁
    - [x] Lua 语法验证通过

- [x] 1.7 解锁回族部落书剑恩仇录事件（oldevent_620/624）
  Blast Radius: `["game/script/oldevent/oldevent_620.lua", "game/script/oldevent/oldevent_624.lua", "game/engine-web/dist/script/oldevent/oldevent_620.lua", "game/engine-web/dist/script/oldevent/oldevent_624.lua"]`
  DoD:
    - [x] 两个脚本全部解锁
    - [x] Lua 语法验证通过

- [x] 1.8 解锁侠客岛侠客行事件（oldevent_352/353）
  Blast Radius: `["game/script/oldevent/oldevent_352.lua", "game/script/oldevent/oldevent_353.lua", "game/engine-web/dist/script/oldevent/oldevent_352.lua", "game/engine-web/dist/script/oldevent/oldevent_353.lua"]`
  DoD:
    - [x] 两个脚本全部解锁
    - [x] Lua 语法验证通过

- [x] 1.9 解锁渤泥岛碧血剑事件（oldevent_635）
  Blast Radius: `["game/script/oldevent/oldevent_635.lua", "game/engine-web/dist/script/oldevent/oldevent_635.lua"]`
  DoD:
    - [x] `--function` 改为 `function`
    - [x] `--end` 注释取消
    - [x] Lua 语法验证通过

## 2. 天书获取测试实现
Traceability: [REQ-WT-003]

- [x] 2.1 天宁寺连城诀测试（P7 天宁寺步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p7.spec.js"]`
  DoD:
    - [x] 在 P7 天宁寺步骤中，天宁寺 NPC 对话 → 触发连城诀事件
    - [x] 验证终端输出包含连城诀相关文本
    - [x] 无 gameLoop error

- [x] 2.2 丐帮天龙八部测试（P7 丐帮步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p7.spec.js"]`
  DoD:
    - [x] 在 P7 丐帮步骤中，选择 NPC 对话 → 触发天龙八部事件
    - [x] 验证终端输出包含天龙八部相关文本
    - [x] 无 gameLoop error

- [x] 2.3 桃花岛射雕英雄传测试（P7 桃花岛步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p7.spec.js"]`
  DoD:
    - [x] 在 P7 桃花岛步骤中，黄蓉对话 → 触发射雕英雄传事件
    - [x] 验证终端输出包含射雕英雄传相关文本
    - [x] 无 gameLoop error

- [x] 2.4 沙漠废墟白马啸西风测试（P6 沙漠废墟步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p6.spec.js"]`
  DoD:
    - [x] 在 P6 沙漠废墟步骤中，NPC 对话 → 触发白马啸西风事件
    - [x] 验证终端输出包含白马啸西风相关文本
    - [x] 无 gameLoop error

- [x] 2.5 神龙教鹿鼎记测试（P6 神龙教步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p6.spec.js"]`
  DoD:
    - [x] 在 P6 神龙教步骤中，洪教主对话 → 触发鹿鼎记事件
    - [x] 验证终端输出包含鹿鼎记相关文本
    - [x] 无 gameLoop error

- [x] 2.6 黑木崖笑傲江湖测试（P7 黑木崖步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p7.spec.js"]`
  DoD:
    - [x] 在 P7 黑木崖步骤中，NPC 对话 → 触发笑傲江湖事件
    - [x] 验证终端输出包含笑傲江湖相关文本
    - [x] 无 gameLoop error

- [x] 2.7 回族部落书剑恩仇录测试（P2 回族部落步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p2.spec.js"]`
  DoD:
    - [x] 在 P2 回族部落步骤中，NPC 对话 → 触发书剑恩仇录事件
    - [x] 验证终端输出包含书剑恩仇录相关文本
    - [x] 无 gameLoop error

- [x] 2.8 古墓九阴真经/神雕侠侣测试（P3 古墓步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p3.spec.js"]`
  DoD:
    - [x] 在 P3 古墓步骤中，除了小龙女加入外，验证古墓 oldevent_442（九阴真经）可触发
    - [x] 验证终端输出包含九阴真经相关文本
    - [x] 无 gameLoop error

- [x] 2.9 侠客岛侠客行测试（P6 侠客岛步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p6.spec.js"]`
  DoD:
    - [x] 在 P6 侠客岛步骤中，龙岛主对话 → 触发侠客行事件
    - [x] 验证终端输出包含侠客行相关文本
    - [x] 无 gameLoop error

- [x] 2.10 光明顶倚天屠龙记测试（P5 光明顶步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p5.spec.js"]`
  DoD:
    - [x] 在 P5 光明顶步骤中，验证 tile event extra=82 可触发
    - [x] 验证终端输出包含倚天屠龙记相关文本
    - [x] 无 gameLoop error

- [x] 2.11 渤泥岛碧血剑测试（P6 渤泥岛步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p6.spec.js"]`
  DoD:
    - [x] 在 P6 渤泥岛步骤中，袁承志对话 → 触发碧血剑事件
    - [x] 验证终端输出包含碧血剑相关文本
    - [x] 无 gameLoop error

- [x] 2.12 苗人凤居飞狐外传测试（P4 苗人凤居步骤）
  Blast Radius: `["game/engine-web/tests/walkthrough-p4.spec.js"]`
  DoD:
    - [x] 在 P4 苗人凤居步骤中，tile event extra=30（退敌战斗）已验证
    - [x] 验证终端输出包含苗人凤相关文本
    - [x] 无 gameLoop error

## 3. 圣堂放置天书测试
Traceability: [REQ-WT-003]

- [x] 3.1 圣堂14个书架事件可操作
  Blast Radius: `["game/engine-web/tests/walkthrough-p10.spec.js"]`
  DoD:
    - [x] 在 P10 圣堂步骤中，look 查看显示 14 个"放置天书"事件
    - [x] 每个书架事件可 choose 触发，无 gameLoop error
    - [x] 验证终端输出包含"放置天书"或"是否使用物品"文本

## 4. 全量回归测试
Traceability: [REQ-WT-003]

- [x] 4.1 运行全部 P1-P10 + save-state 测试
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [x] 15 个测试全部通过
    - [x] 无 gameLoop error
    - [x] 每个 spec 在超时时间内完成

## 5. 剩余待处理天书
Traceability: [REQ-WT-004]

- [ ] 5.1 飞狐外传条件触发实现（苗人凤居，需胡斐+屠龙刀+金丝背心）
  Blast Radius: `["game/script/oldevent/oldevent_7.lua", "game/engine-web/dist/script/oldevent/oldevent_7.lua", "game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 分析飞狐外传获取条件（胡斐在队伍+屠龙刀+金丝背心）
    - [ ] 实现条件检查逻辑（队伍中是否有胡斐、物品中是否有屠龙刀和金丝背心）
    - [ ] 条件满足时触发 oldevent_7 给予飞狐外传天书
    - [ ] 添加 e2e 测试验证条件触发流程
    - [ ] 无 gameLoop error

- [ ] 5.2 光明顶倚天屠龙记数据修复（场景11 NPC数据缺失）
  Blast Radius: `["game/engine-web/data-web/scenes.json", "game/engine-web/dist/data-web/scenes.json", "game/tools/extract_web_data.lua"]`
  DoD:
    - [ ] 分析光明顶场景11的数据提取缺失原因
    - [ ] 检查 ranger.grp 中 Scene_S 结构，确认光明顶 NPC 数据位置
    - [ ] 修复数据提取脚本或手动补充 NPC 数据
    - [ ] 光明顶场景有正确的 NPC 事件可触发倚天屠龙记剧情
    - [ ] 添加 e2e 测试验证光明顶 NPC 对话
    - [ ] 无 gameLoop error