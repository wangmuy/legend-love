---
status: done
created: 2026-10-16
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`kysmod.ini` 是原版 SDL3 引擎的 MOD 入口（`[system]`/`[constant]` 段），love2d 分支无对应机制。各 MOD 取值互不一致（`EXP_RATE=4` vs 原版 100、mingdong 分辨率 960x660、typo 键名 `SCENCEAMI`），需要一个容错解析器把 ini 映射为 `CONFIG.*`/`CC.*` 覆盖。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0/slice-proposal.md`（Contract A 的拥有方）
- 依赖: none

## What Changes

1. 新增 `game/framework/mod_ini.lua`：
   - `ModIni.Load(path)` → `{CONFIG={...}, CC={...}, unknown={...}}`（Contract A）
   - `ModIni.Apply(parsed)` → 把覆盖应用到已加载的 `CONFIG`/`CC` 默认值上
   - 键名映射表：`[system]`/`[constant]` 段键 → `CONFIG.*`/`CC.*`，typo 键名（如 `SCENCEAMI`）在映射表中显式登记
   - 容错：缺失段/缺失键 → 对应表缺项；未知/无法映射键 → `unknown`（警告，非错误）
2. 单元测试（`tests/unit/mod_ini_test.lua`）：
   - 覆盖 19 个 MOD 的真实 `kysmod.ini`（含 mingdong typo 键名、GodsDevils 差异值）
   - 抽样断言：mingdong 分辨率 960x660、GodsDevils `EXP_RATE=4`
   - 容错路径：空文件、缺段、未知键

## Scope Boundaries

### In Scope
- 纯解析 + 覆盖映射模块（framework，不依赖引擎）
- 对应单元测试

### Out of Scope
- MOD 激活机制（`active_mod.txt`）— 属于 allmods-data-fallback
- `ModIni` 在启动链路的接入 — 属于 allmods-data-fallback
- ini 中尚未在 love2d 侧有对应语义的键的引擎行为落地（只登记到 unknown）

## Capabilities

### New Capabilities
- `allmods-ini`: kysmod.ini 解析与 CONFIG/CC 覆盖映射（[REQ-INI-1]~[REQ-INI-3]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-INI-1] | `Load` 返回三表结构，19 个真实 ini 全部解析成功 |
| [REQ-INI-2] | 键名映射表可配置；typo 键名显式登记不报错 |
| [REQ-INI-3] | `Apply` 只覆盖 ini 中出现的键，未出现的键保持默认值 |

## DoD

1. `lua tests/test_runner.lua mod_ini` 全绿
2. 19 个 MOD 的 `kysmod.ini` 全部解析成功（含 typo 键名），无报错
3. 抽样值断言通过（mingdong 分辨率、GodsDevils `EXP_RATE`）
