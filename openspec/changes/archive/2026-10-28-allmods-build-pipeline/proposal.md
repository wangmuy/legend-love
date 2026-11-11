---
status: done
created: 2026-10-16
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

事件/对话是构建期内容适配：`oldevent/*.lua` 是从原版 `kdef.grp` 提取的静态产物，每个 MOD 的 kdef 不同，必须对每个 MOD 重新走提取流程（用户已拍板构建期提取）。现有工具链（`convertkdef2.lua` + `tools/extract_*.lua`）只跑过原版，且 `convertkdef2.lua` 依赖 fishedit 的 kdefout.txt 文本格式——需要先解决这个依赖。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0/slice-proposal.md`（Contract C 的拥有方）
- 依赖: none（构建期工具，与运行时改造独立）

## What Changes

新增 `game/tools/mod_build.lua <kys-<mod>>`（Contract C）：

1. **资源拍平**：`resource/ + fight/` → `game/mods/<mod>/data/`，文件名小写归一；`save/` 拆分为：基础模板（`ranger.*`/`alldef.*`/`allsin.*`/`allsinbk.*`）→ `data/`，用户存档（`rN/dN/sN.grp`）→ `game/mods/<mod>/save/`（MOD 存档隔离）；拷贝 `kysmod.ini` 到 `mods/<mod>/data/`；忽略 `head/`、`item/`、`eft/` 等编辑器副产物
2. **kdef 提取**：`kdef.grp` → `game/mods/<mod>/script/oldevent/oldevent_0..n-1.lua`（n = kdef 条目数）
   - 改造 `convertkdef2.lua`：解决对 fishedit kdefout.txt 文本格式的依赖（逆向 kdef.grp → 文本这一步，或直接读 grp 二进制）
   - 复用/改造 `tools/extract_*.lua` 的事件→lua 转换
3. **talk 提取**：`talk.grp` → `game/mods/<mod>/script/old_talk.lua`
4. **数据差异报告**：产出 `game/mods/<mod>/diff.md`，必含：文件增删清单（vs `game/data/`）、hdgrp 条目数、fight 数量、ini 差异表
5. **原版基准校验**：对 kys-pascal 跑管线，提取产物应与现有 `script/oldevent/` 内容一致（提取正确性的回归基准）

## Scope Boundaries

### In Scope
- 构建期工具与产物布局（Contract C 全部）
- 对 19 个 MOD 产出 `game/mods/<mod>/diff.md` 并排序（排序结果写入 epic TODO.md）

### Out of Scope
- 运行时加载 `mods/<mod>/data/`/`mods/<mod>/script/` — 属于 allmods-data-fallback
- MOD 数据内容修复（数据异常只记录到 diff 报告 + 非 0 退出码，不修复源数据）
- CI/CD 集成

## Capabilities

### New Capabilities
- `allmods-build`: MOD 数据拍平 + kdef/talk 构建期提取 + 差异报告（[REQ-BUILD-1]~[REQ-BUILD-5]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-BUILD-1] | 资源拍平：小写归一、kysmod.ini 拷贝、副产物目录忽略 |
| [REQ-BUILD-2] | kdef 提取不依赖 fishedit 文本格式，事件数 = kdef 条目数 |
| [REQ-BUILD-3] | talk 提取产出 old_talk.lua |
| [REQ-BUILD-4] | data-diff 报告含文件增删/hdgrp 条目数/fight 数/ini 差异 |
| [REQ-BUILD-5] | kys-pascal 基准：提取产物与现有 script/oldevent/ 一致 |

## DoD

1. `lua tools/mod_build.lua kys-mingdong` 跑通，四产物齐备（`mods/mingdong/data/`、`mods/mingdong/script/oldevent/`、`mods/mingdong/script/old_talk.lua`、`mods/mingdong/diff.md`）
2. 对 kys-pascal 跑管线，`mods/pascal/script/oldevent/` 与现有 `script/oldevent/` 内容一致（diff 为空或仅注释差异）
3. 19 个 MOD 全部产出 `game/mods/<mod>/diff.md`，排序写入 epic TODO.md
4. 数据异常的 MOD（games.ini 标注"有问题"的 5 个）退出码非 0 且 stderr 说明原因

## 完成情况

- DoD 1：✅ `mods/mingdong/` 四产物齐备（data 33 项、oldevent 1654、old_talk 5184 行、diff.md）
- DoD 2：✅ `lua tools/mod_build.lua --verify-pascal` → PASS，1015/1018 结构精确匹配；3 个白名单事件（320 if/else 等价形式；655/691 原版提取器丢弃指令，本工具忠实于二进制）
- DoD 3：✅ 20 个 MOD 全部产出 `diff.md`，按数据形态距离排序写入 `openspec/epics/2026-10-allmods-compat/TODO.md`
- DoD 4：✅ `lua tools/mod_build.lua --all` 退出码 1，stderr 列出 5 个 games.ini 标注异常的 MOD

详见 [tasks.md](tasks.md)。
