---
status: abandoned
created: 2026-10-30
parent_slice: allmods-slice15-music-ogg
---
# Proposal: allmods-music-ogg-verify

## Why

`allmods-music-ogg-tool` 会产出 41 个 ogg，但「文件存在」不等于「功能正确」。
本项目已多次踩到「0 gaps ≠ 结构正确」「文档表格未排序却被声称降序」的坑。
本 change 的职责是**用有鉴别力的断言**证明：

1. 产物确实被运行时框架识别并播放（不是躺在磁盘上）
2. 音色库确实按映射表加载（不是静默回退系统音源）
3. `mod_audit` 真的「看见」了这次变化（不是改了但审计说没改）

## What Changes

1. **`mod_audit` 新增 `music` 分支**（`productCandidates`）—— 否则产物对审计不可见
2. **逐项验证 41 个产物**（数量、命名、格式、时长、可解码）
3. **负向对照 3 组**（音色库 A/B、删除文件回退、缺工具降级）
4. **真实启动链路验证**（mingdong / awaken 各一次）
5. **审计归口复核**（`PENDING` / `REQUIRED_CONVERTED` / `LEGACY` 三项数字）
6. **文档收口**：`verification.md` + epic / TODO 更新

## In Scope

- `game/tools/mod_audit.lua` 的 `productCandidates` 新增 `music` 分支（**唯一代码改动**）
- `game/tests/unit/test_mod_audit.lua` 新增对应单测
- `openspec/changes/allmods-music-ogg-verify/**`
- `openspec/epics/2026-10-allmods-compat/{epic.md,TODO.md}` 更新
- 14 个既有 MOD 的 `verification.md` 中「音频 PENDING」表述复核

## Out of Scope

- **转换工具本身**（属 `allmods-music-ogg-tool`）
- **引擎改动**（四禁改路径）
- **`jyconst.lua` 常量**
- **`reference/allmods/**`**
- **BookCalamity 20 个 id** —— 源侧无 `.mid`，只能文档记录
- **音色艺术效果评判** —— 只证明「音色库按映射加载」，不评判好坏

## 预期数字（实测为准，不以本表为准）

| 项 | 前 | 后 |
|---|---:|---:|
| `PENDING` | 581 | **537** |
| `REQUIRED_CONVERTED` | 80 | **121** |
| `LEGACY` | 108 | **110** |
| `BUILD_INPUT` | 30 | **31** |
| `total` | 11220 | **11220** |
| `in_product` | 9285 | **9326** |

闭合校验：`9185 + 121 + 110 + 2 + 1222 + 31 + 12 + 537 = 11220` ✅

## Definition of Done

- 41 个产物逐项验证表（数量/命名/格式/时长），**全绿**
- **3 组负向对照**全部展示鉴别力（不是空跑通过）
- `mod_audit` 的 `music` 分支有单测覆盖，且**删除产物后能被检测到**
- mingdong 与 awaken 各一次真实启动，`RESULT: OK`，且日志无 `PlayMIDI error`
- 审计数字与上表一致（实测校准）
- 8 门禁全绿；测试数 ≥ 1957 + 新增
- 四禁改 = **0**
- `verification.md` 每节含「实测命令 + 输出 + 结论」
