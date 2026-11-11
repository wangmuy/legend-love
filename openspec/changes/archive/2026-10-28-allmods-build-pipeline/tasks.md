# Tasks — allmods-build-pipeline

## Blast Radius

允许修改/新增的文件路径：

- `game/tools/mod_build.lua`（新增，构建工具主体）
- `game/tools/talk_big5.lua`（新增，Big5→UTF-8 码表）
- `game/mods/**`（新增，构建产物，可重新生成）
- `openspec/changes/allmods-build-pipeline/**`
- `openspec/epics/2026-10-allmods-compat/TODO.md`（写入排序结果）

**不允许**修改：`game/framework/**`、`game/engine-love2d/**`、`game/script/**`、`game/tests/**`
（运行时改造属于 allmods-data-fallback）。

## 任务

### T1 资源拍平（REQ-BUILD-1）

- [x] T1.1 `resource/ + fight/` → `mods/<mod>/data/`，文件名小写归一；`save/` 拆分：基础模板（`ranger.*`/`alldef.*`/`allsin.*`）→ `data/`，用户存档（`rN/dN/sN.grp`）→ `mods/<mod>/save/`
- [x] T1.2 忽略编辑器副产物目录 `head/`、`item/`、`eft/`
- [x] T1.3 `kysmod.ini` 原样拷贝到 `mods/<mod>/data/`
- [x] T1.4 子目录（fight/）保留相对结构
- [x] T1.5 `isSaveSlotFile` 判定用户存档（Lua 模式无 `|` 交替，用 `^[rds]%d+%.(grp|idx)$` 拆写）；构建摘要输出 `saves=N`

### T2 kdef 提取，不依赖 fishedit 文本（REQ-BUILD-2）

- [x] T2.1 逆向 kdef.idx（4 字节小端 uint32 offset 数组）+ kdef.grp（int16 指令流）
- [x] T2.2 从 `oldevent_*.lua` 并集推导完整 arity 表（66 opcodes，与二进制零冲突）
- [x] T2.3 解析器：opcode 占 2 字节（`i = i + 2 + ar*2`），`ff ff`(-1) 终止
- [x] T2.4 事件数 = kdef 条目数（pascal 1018、mingdong 1654）

### T3 talk 提取（REQ-BUILD-3）

- [x] T3.1 破解编码：`~big5`（16 位按位取反）+ 特殊单字节表（`0xd5`=`*` 换行 等）
- [x] T3.2 生成并提交 Big5→UTF-8 码表 `talk_big5.lua`（13710 条）
- [x] T3.3 解码器：尾部 `0xff`/`0x00` 终止符循环去除
- [x] T3.4 产出 `mods/<mod>/script/old_talk.lua`（`oldtalk[n]=[==[...]==]`）
- [x] T3.5 与 6 个 MOD 的 `talkutf8.txt` ground truth 比对（覆盖率 94.9%+）

### T4 事件块结构还原（REQ-BUILD-5 关键）

- [x] T4.1 条件跳转方向：最后参数 ==0 → `==false`，非零 → `==true`
- [x] T4.2 跳转偏移 = 第一个非零参数（index ≥ K(op)）；K 表逐 opcode 搜索确定
- [x] T4.3 块结束 = op7 终止符位置（若存在），否则跳转目标
- [x] T4.4 区分扁平守卫链（event 655）与嵌套无 op7 块（event 530）
- [x] T4.5 迭代式块结束计算（从后向前），消除深递归栈溢出

### T5 数据差异报告（REQ-BUILD-4）

- [x] T5.1 `mods/<mod>/diff.md`：文件增删清单（vs `game/data/`）
- [x] T5.2 hdgrp 条目数、fight 数量、ini 差异表
- [x] T5.3 解析 `games.ini`，标注"有问题"的 MOD 退出码非 0 + stderr 说明

### T6 原版基准校验（REQ-BUILD-5）

- [x] T6.1 `--verify-pascal` 子命令：逐事件结构签名比对
- [x] T6.2 1015/1018 结构精确匹配；3 个已记录的原版提取器缺陷（320/655/691）白名单
- [x] T6.3 基准校验 PASS

### T7 全量构建 + 排序（DoD 3）

- [x] T7.1 `--all` 构建 games.ini 全部 20 个 MOD
- [x] T7.2 20 个 `diff.md` 全部产出
- [x] T7.3 按数据形态距离排序，写入 epic TODO.md

## DoD（机器可验证）

1. `cd game && lua tools/mod_build.lua kys-mingdong` 退出 0，且
   `mods/mingdong/data/`、`mods/mingdong/script/oldevent/`（1654 文件）、
   `mods/mingdong/script/old_talk.lua`、`mods/mingdong/diff.md` 四产物齐备。
2. `cd game && lua tools/mod_build.lua --verify-pascal` 输出 `PASS`，退出 0；
   仅 3 个已记录缺陷事件（320/655/691）为白名单差异。
3. `cd game && lua tools/mod_build.lua --all` 产出 20 个 `diff.md`；
   排序结果已写入 `openspec/epics/2026-10-allmods-compat/TODO.md`。
4. `lua tools/mod_build.lua --all` 退出码为 1（5 个 games.ini 标注异常的 MOD），
   stderr 逐条列出 MOD + 标注原因。
