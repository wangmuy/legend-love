---
status: done
created: 2026-10-29
---
# Tasks: allmods-list-bin-support

## 组 1：`list/*.bin` 进产物（[REQ-LBIN-1]）

Blast Radius: `["game/tools/mod_build.lua"]`

- [x] 1.1 在 `mod_build.lua` 的构建源文件列表中加入 `list/*.bin`
  （**仅** `effect.bin`、`match.bin`；`leave.bin`/`levelup.bin`/`*.txt` 不进）
  DoD:
    - [x] `lua tools/mod_build.lua kys-pascal` 后 `game/mods/pascal/data/effect.bin` 存在
    - [x] `stat -c%s game/mods/pascal/data/effect.bin` = `128`（== 源侧）
    - [x] `ls game/mods/pascal/data/leave.bin game/mods/pascal/data/levelup.bin` 报「无此文件」
    - [x] `diff <(md5sum < ../reference/allmods/kys-pascal/list/effect.bin | cut -d' ' -f1) <(md5sum < game/mods/pascal/data/effect.bin | cut -d' ' -f1)` 为空
- [x] 1.2 20 个 MOD 全量重建，逐 MOD 校验 `data/effect.bin` 存在且与源侧逐字节一致
  DoD:
    - [x] `lua tools/mod_build.lua --all` 输出 `20 mods, 0 build failures`
    - [x] `for m in $(ls -d ../reference/allmods/kys-*); do diff -q $m/list/effect.bin ../game/mods/$(basename $m|sed s/kys-//)/data/effect.bin; done` 无输出
    - [x] 逐字节比对数 = **20/20**

## 组 2：运行时惰性装载（[REQ-LBIN-2]、[REQ-LBIN-5]）

Blast Radius: `["game/framework/mod_data.lua", "game/framework/jymain_adapter.lua"]`

- [x] 2.1 `mod_data.lua` 新增 `M.LoadEffectTable()`：读 `data/effect.bin` → `CC.Effect`
  DoD:
    - [x] 函数存在且导出：`lua -e 'assert(require("framework.mod_data").LoadEffectTable)'`
    - [x] 读入后 `#CC.Effect` 反映该 MOD 条目数（pascal 64、BookCalamity 200）
    - [x] 文件不存在时函数返回 `false` 且 **`CC.Effect` 保持不变**（仍 53 项）
- [x] 2.2 在 `jymain_adapter.lua` 的 init 链调用（`CC` 已提升为全局之后）
  DoD:
    - [x] 真实启动 pascal：`lua tests/unit/boot_one_mod.lua pascal 320 200 84 93 小蝦米`
      → 全量断言 PASS
    - [x] 启动后 `CC.Effect[53]` 非 nil（64 项生效，超出旧硬编码范围）
    - [x] `grep -c 'CC\.[A-Za-z]* *=' game/script/jyconst.lua` 与改动前**数量相同**
- [x] 2.3 负向对照：证明装载器有鉴别力（不是空跑通过）
  DoD:
    - [x] 临时把 `data/effect.bin` 换成 3 项短文件 → 装载后 `#CC.Effect == 3`（非 53）
    - [x] 删除 `data/effect.bin` → 装载返回 false 且 `#CC.Effect == 53`（兜底生效）
    - [x] 两个对照结果都实测记录进 `verification.md`

## 组 3：`format_spec` 记录级验证（[REQ-LBIN-3]）

Blast Radius: `["game/tools/format_spec.lua", "game/tests/unit/test_format_spec.lua"]`

- [x] 3.1 `bin_table` 从「4 字节单元 + 隐式 tail」升级为记录级 uint16 验证
  DoD:
    - [x] `lua tools/format_spec.lua --all` 的 `checked` 不减少、`gaps=0`
    - [x] `.bin` 记录数 = `filesize / 2`，奇数字节 → 显式报 gap（不静默吞）
    - [x] 负向对照：构造 3 字节 `.bin` → `ok=false`
- [x] 3.2 新增单测覆盖记录级语义
  DoD:
    - [x] `lua tests/test_runner.lua format_spec` 全部通过
    - [x] 至少 3 条新断言：偶数/奇数/零字节

## 组 4：`mod_audit` 归类收口（[REQ-LBIN-4]）

Blast Radius: `["game/tools/mod_audit.lua", "game/tests/unit/test_mod_audit.lua"]`

- [x] 4.1 `list/effect.bin`、`list/match.bin` → `REQUIRED`，`in_product=true`
  DoD:
    - [x] `lua tools/mod_audit.lua --all --evidence` 中该 40 条 `category=REQUIRED`
    - [x] 同批记录 `in_product=true` 且证据指向 `mod_build.lua` 的搬运规则
- [x] 4.2 `list/leave.bin`、`list/levelup.bin`、`list/*.txt` → `LEGACY` + `evidence`
  DoD:
    - [x] 42 条 `category=LEGACY`（**勘误**：实测 `*.bin` 侧 40 条 = 20 leave + 20 levelup；`*.txt` 侧另有 40 条 = 20 end.txt + 20 start.txt）
    - [x] 每条 `evidence` 非空且 `kind=code`，`ref` 指向「引擎零引用」的 grep 位置
    - [x] `bad_evidence=0`
- [x] 4.3 `PENDING` 归零（音频类除外）
  DoD:
    - [x] `lua tools/mod_audit.lua --all --evidence` 的 `PENDING` 从 **663 → 581**
    - [x] 581 条全部是 `.mid`/`.mp3`/`.sf2`（可 grep 验证无 `.bin` 残留）
    - [x] `unclassified=0 bad_evidence=0` 仍成立

## 组 5：全量门禁复跑

Blast Radius: `[]`（只读验证）

- [x] 5.1 8 门禁全绿
  DoD:
    - [x] G1 `lua tests/test_runner.lua` → **1957 / 0 failed**（变更前 1914，+43）
    - [x] G2 `lua tools/mod_build.lua --verify-pascal` → `PASS`
    - [x] G3 `lua tools/mod_build.lua --all` → `20 mods, 0 build failures`
    - [x] G4 `timeout 900 lua tools/mod_check.lua` → `20/20`
    - [x] G5 `lua tools/mod_audit.lua --all --evidence` → `unclassified=0 bad_evidence=0`，`PENDING=581`
    - [x] G6 `lua tools/format_spec.lua --all` → `gaps=0`
    - [x] G7 存档槽 451 文件 / 真实问题 0（历史口径 `341/110/451`）
    - [x] G8 `git status --porcelain | grep -cE 'engine-love2d/|engine-mud/|reference/allmods/'` = **0**
    - [x] G8b `git diff game/script/jyconst.lua | grep -cE '^\+.*CC\.[A-Za-z]+ *='` = **0**
- [x] 5.2 幂等性：连续两次全量构建产物一致
  DoD:
    - [x] `lua tools/mod_build.lua --all` 两次后 `diff -rq game/mods /tmp/mods_snapshot` 为空
