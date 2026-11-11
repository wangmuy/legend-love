# 金庸群侠传 20 合 1 MOD 适配说明

本文档说明本项目（love2d-event-driven 分支）对「金庸群侠传 20 合 1」MOD 包的适配情况：包含哪些 MOD、如何激活、构建链怎么走、`kysmod.ini` 有多少真正生效、以及**已知缺陷与已知问题 MOD 的真实根因**。

> 本文所有数字均为仓库实测，每条结论附「实测命令 + 输出」。文档与代码冲突时，**以代码为准**。

---

## 1. 出处

| 项 | 值 |
|---|---|
| 论坛主题 | <https://tiexuedanxin.net/t/topic/190342> |
| 标题 | 【安卓PC双版本】金庸群侠传20合1震撼发布 |
| topic id | `190342` |
| 创建时间 | `2025-07-30T13:11:28Z` |
| 最后回复 | `2026-10-14T10:05:14Z` |
| 回复数 / 浏览 | `224` / `64554` |
| 讨论群 | `910723737`、`894828328` |
| PC 下载 | <https://pan.baidu.com/s/1nv9R5rz> |
| 作者说明 | 机器猫出品，把 20 个 DOS MOD 融为一炉；附带安卓版配置工具（改配置/改存档）；安卓版需从 QQ 群下载 |

仓库内的素材来源是 `reference/allmods/`（已 gitignore）：

```bash
$ ls reference/allmods/
AllMod-Launcher.exe  games.ini  kys-BookCalamity/ ... kys-stronger/  play.bat  UPedit/
$ ls -l reference/allmods/games.ini reference/allmods/AllMod-Launcher.exe reference/allmods/play.bat
-rw-rw-r-- 1 woodfish woodfish 25600 Apr  3  2026 reference/allmods/AllMod-Launcher.exe
-rw-rw-r-- 1 woodfish woodfish   792 Apr  3  2026 reference/allmods/games.ini
-rw-rw-r-- 1 woodfish woodfish  1817 Nov 15  2025 reference/allmods/play.bat
```

编码实测（踩坑须知，脚本读取时必须处理）：

```bash
$ python3 -c "d=open('reference/allmods/games.ini','rb').read(); print('BOM:',d[:3]==b'\xef\xbb\xbf','CRLF:',d.count(b'\r\n'))"
BOM: True CRLF: 26                       # UTF-8 BOM + CRLF
$ python3 -c "d=open('reference/allmods/play.bat','rb').read(); d.decode('utf-8')"
UnicodeDecodeError: 'utf-8' codec can't decode byte 0xb0 in position 51
$ python3 -c "d=open('reference/allmods/play.bat','rb').read(); d.decode('gbk'); print('GBK OK')"
GBK OK                                    # play.bat 是 GBK，不是 UTF-8
```

`games.ini` 的 20 条与论坛原文**逐条一致**（含「（好像有问题）」等注解）：

```bash
$ python3 -c "
d=open('reference/allmods/games.ini','rb').read().decode('utf-8-sig')
print(sum(1 for l in d.split('\n') if l.strip()[:1].isdigit()))"
20
```

### 1.1 三份清单各说各话（别合并成一张表）

`reference/allmods/` 里有 **3 个地方**各自列出 MOD，口径必须分别说清：

| 来源 | 条目数 | 格式 | 谁在用 |
|---|---:|---|---|
| `games.ini` | **20** | `0 = 原版: kys-pascal`，UTF-8 **BOM + CRLF**，末尾多一行 `current =0` | `AllMod-Launcher.exe`（原版启动器） |
| `play.bat` | **20** | GBK，`ECHO. 0 原版` + `if "%id%"=="0" goto cmd0` + `:cmd0` / `cd kys-pascal` | 原版 Windows 批处理启动菜单 |
| `game/active_mod.sample.txt` | **20** | UTF-8，`mingdong      名动天下` 两列 | 本项目的 MOD 激活说明 |

三者的 20 个 slug **完全一致**（含大小写：`kys-SweeOan`、`kys-RiverLake`、`kys-pig3dos`），**差异只在排序和注解**：

| 来源 | 排序 |
|---|---|
| `games.ini` / `play.bat` | 原版 0..19 顺序（`pascal` → `Dragon` → … → `stronger`） |
| `game/active_mod.sample.txt` | 按「常用程度」人工重排（`mingdong` 首位、`pascal` 第二，其后是各 MOD） |
| `./tools/run-mod.sh --list` | **Python `sorted()` 字母序、区分大小写**（大写字母在前：`BookCalamity`…`SweeOan` 先，再 `awaken`…`zheng`） |

```bash
$ python3 -c "
import re
s=open('game/active_mod.sample.txt',encoding='utf-8').read()
head=s.split('# 可用 MOD slug')[1].split('# ↓↓↓')[0]
ss=[m.group(1) for m in re.finditer(r'^#\s+([A-Za-z0-9]+)\s+\S+', head, re.M)]
print('sample 顺序:', ss[:5], '...')
print('是否字母序:', ss==sorted(ss))"
sample 顺序: ['mingdong', 'pascal', 'Dragon', 'RiverLake', 'ptt'] ...
是否字母序: False

$ bash tools/run-mod.sh --list | sed -n '5,24p' | awk '{print $2}' | tr '\n' ' '
BookCalamity Dragon GodsDevils HeavenSword RiverLake SweeOan awaken books dream ...
```

> 排序不同**不影响功能**：`active_mod.txt` 只取第一个有效行，`run-mod.sh --list` 的序号只用于交互选择。但**抄文档时别把 `--list` 的序号当成 `games.ini` 的序号**——两边的「第 N 个」不是同一个 MOD。

```bash
$ python3 -c "
import re
d=open('reference/allmods/play.bat','rb').read().decode('gbk')
print('ECHO 菜单项:', len([l for l in d.splitlines() if l.upper().startswith('ECHO.')]))
print('if 分支:', len([l for l in d.splitlines() if l.startswith('if \"%id%\"')]))
print(':cmd 标签:', len([l for l in d.splitlines() if l.startswith(':cmd')]))"
ECHO 菜单项: 20
if 分支: 20
:cmd 标签: 20
```

> **`play.bat` 末尾硬编码 `start ..\\kys-pascal\\kys.exe`**：无论选哪一项，脚本只负责 `cd` 到对应目录，最后一行**永远启动 `kys-pascal\kys.exe`**（因为 20 个 MOD 共用同一份 `kys.exe`，各目录只有数据）。这解释了为什么 §5.1 的 `strings` 分析只针对 `kys-pascal/kys.exe`——它就是全部 20 个 MOD 的引擎。

---

## 2. 20 个 MOD 总览

### 2.1 清单 + 状态注解

`games.ini` 中的注解直接用中文写在名字里（`mod_build.lua:58` 的 `PROBLEM_MARKERS = { "有问题", "正常" }` 就是拿它判定「已知问题 MOD」）：

| # | 名称 | slug | `games.ini` 注解 |
|---:|---|---|---|
| 0 | 原版 | `pascal` | — |
| 1 | 苍龙逐日 | `Dragon` | — |
| 2 | 再战江湖 | `RiverLake` | — |
| 3 | PTT | `ptt` | — |
| 4 | 再破菠萝 | `pineapple` | — |
| 5 | 笑梦游记 | `dream` | — |
| 6 | 小猪闯江湖 | `pig` | — |
| 7 | 天书奇侠试玩 | `books` | — |
| 8 | 天书劫 | `BookCalamity` | **好像有问题** |
| 9 | 魏征传奇 | `zheng` | **好像不太正常** |
| 10 | 问情篇 | `loving` | **好像不太正常** |
| 11 | 真龙苏醒 | `awaken` | **不确定正不正常** |
| 12 | 瑞安群侠传 | `SweeOan` | — |
| 13 | 倚天剑 | `HeavenSword` | — |
| 14 | 失传天书-越女剑 | `lostbook` | — |
| 15 | 天龙八部 | `GodsDevils` | — |
| 16 | 刘亦纷飞版 | `lyff` | — |
| 17 | 金庸水浒传dos版 | `pig3dos` | **不可能正常** |
| 18 | 名动天下 | `mingdong` | — |
| 19 | 威力加强版 | `stronger` | — |

### 2.2 数据规模（源侧 + 构建产物）

`hdgrp` = `data/hdgrp.idx` 条目数；`fightNN` = `data/fight*.grp` 文件数；`oldevent` = 构建出的 `script/oldevent/*.lua` 数量；`槽` = `save/ranger.idx` 首段推出的物品槽数（见 §6）。

| # | 名称 | slug | 源文件 | hdgrp | fightNN | oldevent | mid | ogg | mp3 | 物品槽 | 产物 |
|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 原版 | `pascal` | 651 | 115 | 92 | 1018 | 23 | 23 | 0 | 200 | 101 MB |
| 1 | 苍龙逐日 | `Dragon` | 811 | 267 | 209 | 1087 | 24 | 24 | 0 | 200 | 123 MB |
| 2 | 再战江湖 | `RiverLake` | 699 | 252 | 219 | 1232 | 23 | 23 | 0 | 200 | 96 MB |
| 3 | PTT | `ptt` | 596 | 204 | 162 | 1229 | 23 | 23 | 0 | 200 | 91 MB |
| 4 | 再破菠萝 | `pineapple` | 529 | 300 | 154 | 1068 | 34 | 34 | 1 | **456** | 116 MB |
| 5 | 笑梦游记 | `dream` | 416 | 484 | 122 | 4569 | 24 | 24 | 1 | 200 | 137 MB |
| 6 | 小猪闯江湖 | `pig` | 440 | 173 | 137 | 1288 | 23 | 23 | 0 | 200 | 88 MB |
| 7 | 天书奇侠试玩 | `books` | 525 | 696 | 178 | 573 | 23 | 23 | 0 | 200 | 83 MB |
| 8 | 天书劫 | `BookCalamity` | 978 | 373 | 326 | 1701 | 24 | 24 | 0 | **400** | 143 MB |
| 9 | 魏征传奇 | `zheng` | 349 | 126 | 92 | 1119 | 23 | 23 | 0 | 200 | 91 MB |
| 10 | 问情篇 | `loving` | 361 | 128 | 107 | 1264 | 23 | 23 | 0 | 200 | 64 MB |
| 11 | 真龙苏醒 | `awaken` | 703 | 353 | **220** | 1227 | 84 | 84 | 0 | 200 | 233 MB |
| 12 | 瑞安群侠传 | `SweeOan` | 334 | 115 | 92 | 1018 | 23 | 23 | 0 | 200 | 61 MB |
| 13 | 倚天剑 | `HeavenSword` | 335 | 125 | 93 | 1066 | 23 | 23 | 0 | 200 | 57 MB |
| 14 | 失传天书-越女剑 | `lostbook` | 342 | 115 | 97 | 1071 | 23 | 23 | 0 | 200 | 57 MB |
| 15 | 天龙八部 | `GodsDevils` | 615 | 129 | 92 | 1123 | 23 | 23 | 0 | 200 | 67 MB |
| 16 | 刘亦纷飞版 | `lyff` | 425 | 178 | 138 | 1358 | 23 | 23 | 0 | 200 | 67 MB |
| 17 | 金庸水浒传dos版 | `pig3dos` | 568 | 412 | 180 | 1107 | 23 | 23 | 0 | 200 | 115 MB |
| 18 | 名动天下 | `mingdong` | 1208 | 115 | 267 | 1654 | 66 | 66 | 0 | **400** | 194 MB |
| 19 | 威力加强版 | `stronger` | 335 | 115 | 92 | 1018 | 23 | 23 | 0 | 200 | 62 MB |
| | **合计** | | | | | | **578** | **578** | **2** | | **2.0 GB**（2046 MB） |

> **`fightNN` 列的口径**：这一列数的是**引擎实际可见**的 `^fight[0-9]+\.grp$` 文件（`framework/mod_data.lua:278` 的 `listDir(modDir, "^fight%d+%.grp$")`），不是目录里 `.grp` 总数。
> 只有 `awaken` 两者不等：目录里 237 个 `.grp`，其中 **17 个命名不合规**——8 个 `fightNNN..grp`（如 `fight000..grp`、`fight178..grp`）+ 9 个 `fightNNN_MM.grp`（如 `fight030_02.grp`）。这些文件被构建链原样拷进 `mods/awaken/data/`，但 `^fight%d+%.grp$` 匹配不到，**引擎永远不会加载它们**（`ModData.FightFiles()` 实测返回 220 条）。
>
> 逐文件 md5 对照（`NN..grp` / `NN_MM.grp` 与同名合规的 `NN.grp` 比）：
>
> | 不合规文件 | 数量 | 与基线 md5 相同（纯重复，无信息损失） | md5 不同（**内容被丢弃**） |
> |---|---:|---|---|
> | `fightNNN..grp`（双点） | 8 | 3（`094`/`101`/`112`） | 5（`000`/`079`/`104`/`105`/`178`） |
> | `fightNNN_MM.grp` | 9 | 7（`030`/`097`/`105`/`118`/`144`/`145`/`150`） | 2（`099`/`137`） |
> | **合计** | **17** | **10** | **7** |
>
> ```bash
> $ cd game/mods/awaken/data && python3 -c "
> import os,re,hashlib
> md5=lambda p: hashlib.md5(open(p,'rb').read()).hexdigest()
> bad=[f for f in os.listdir('.') if re.match(r'^fight.*\.grp$',f) and not re.match(r'^fight\d+\.grp$',f)]
> same=diff=0
> for f in bad:
>     b=re.match(r'^(fight\d+)',f).group(1)+'.grp'
>     if md5(f)==md5(b): same+=1
>     else: diff+=1
> print('不合规=%d 同md5=%d 不同md5=%d'%(len(bad),same,diff))"
> 不合规=17 同md5=10 不同md5=7
> ```
>
> 即 **7 个文件的内容在 love2d 里彻底看不到**（原版 `kys.exe` 是否加载取决于它自己的目录扫描规则，未逆向）。这是上游 MOD 的数据缺陷，非本文档适配问题。

复现命令：

```bash
cd /home/woodfish/project/legend-love
# 源文件数与产物体积
$ du -sm game/mods/*/ | grep -v _audit | wc -l
20
$ du -sm game/mods/*/ | grep -v _audit | awk '{s+=$1} END{print s}'
2046                                     # 表里「合计」用的就是这个口径（逐目录向上取整后相加）
$ du -sm game/mods | cut -f1
2038                                     # 父目录口径：总字节数一次性向上取整，比逐项相加小 8
# 音频总数
$ find game/mods -name '*.mid' | wc -l; find game/mods -name '*.ogg' | wc -l; find game/mods -name '*.mp3' | wc -l
578
578
2
# fight 文件：引擎可见数 vs 目录内总数（只有 awaken 不等）
$ cd game && lua -e 'package.path="./?.lua;"..package.path
  local M=require("framework.mod_data"); M.SetActive("awaken")
  print("engine-visible="..#M.FightFiles())'      # → engine-visible=220
$ ls mods/awaken/data | grep -cE '^fight.*\.grp$'  # 237
$ ls -d mods/*/ | grep -v _audit | wc -l            # 20（另有 _audit 审计目录，不算 MOD）
$ du -sm mods/*/ | grep -v _audit | awk '{s+=$1} END{print s}'   # 2046
$ du -sm mods/*/ | awk '{s+=$1} END{print s}'                    # 2050（含 _audit）
# hdgrp 条目数
$ python3 -c "import os;print(os.path.getsize('game/mods/Dragon/data/hdgrp.idx')//4)"
267
```

### 2.3 存档段记录数（`ranger.idx` 反推）

`ranger.idx` 是 6 个 u32 的**累积偏移**，相邻差值即该段字节数。除 Base 段外，各段字节数 ÷ MOD 记录尺寸（Person 182 / Thing 190 / Scene 52 / Wugong 136，见 `framework/mod_data.lua:443` 的 `MOD_SIZES`）= 记录数。

| # | 名称 | slug | Base 段字节 | **物品槽** | Person | Thing | Scene | Wugong |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| 0 | 原版 | `pascal` | 836 | 200 | 320 | 200 | 84 | 93 |
| 1 | 苍龙逐日 | `Dragon` | 836 | 200 | 589 | 237 | 106 | 114 |
| 2 | 再战江湖 | `RiverLake` | 836 | 200 | 325 | 249 | 84 | 96 |
| 3 | PTT | `ptt` | 836 | 200 | 385 | 214 | 90 | 108 |
| 4 | 再破菠萝 | `pineapple` | **1860** | **456** | 720 | 344 | 118 | 174 |
| 5 | 笑梦游记 | `dream` | 836 | 200 | 409 | 192 | 122 | 102 |
| 6 | 小猪闯江湖 | `pig` | 836 | 200 | 320 | 200 | 84 | 93 |
| 7 | 天书奇侠试玩 | `books` | 836 | 200 | 382 | 200 | 84 | 100 |
| 8 | 天书劫 | `BookCalamity` | **1636** | **400** | 800 | 550 | 139 | 398 |
| 9 | 魏征传奇 | `zheng` | 836 | 200 | 320 | 200 | 84 | 93 |
| 10 | 问情篇 | `loving` | 836 | 200 | 320 | 200 | 84 | 93 |
| 11 | 真龙苏醒 | `awaken` | 836 | 200 | 720 | 237 | 153 | 163 |
| 12 | 瑞安群侠传 | `SweeOan` | 836 | 200 | 320 | 200 | 84 | 93 |
| 13 | 倚天剑 | `HeavenSword` | 836 | 200 | 320 | 200 | 84 | 93 |
| 14 | 失传天书-越女剑 | `lostbook` | 836 | 200 | 320 | 200 | 84 | 93 |
| 15 | 天龙八部 | `GodsDevils` | 836 | 200 | 320 | 200 | 84 | 93 |
| 16 | 刘亦纷飞版 | `lyff` | 836 | 200 | 326 | 200 | 84 | 93 |
| 17 | 金庸水浒传dos版 | `pig3dos` | 836 | 200 | 607 | 242 | 133 | 202 |
| 18 | 名动天下 | `mingdong` | **1636** | **400** | 632 | 367 | 139 | 220 |
| 19 | 威力加强版 | `stronger` | 836 | 200 | 320 | 200 | 84 | 93 |

> **`zheng` 这一行为何与 mod_check 一致但 idx 算不出来**：`zheng` 上游 `save/ranger.idx` 是错的（末值 138596 ≠ `ranger.grp` 实际 114242，见 §7）。直接按原 idx 差值反推会得到 358/201/94/216；构建期 `RepairIdx`（`mod_build.lua:784`）重写偏移后，`game/mods/zheng/data/ranger.idx` 与 pascal 完全相同，实际加载到的记录数是 320/200/84/93。表里填的是**构建后**的值（以 `lua tools/mod_check.lua zheng` 为准）。
>
> ```bash
> $ python3 -c "import struct
> for p in ['reference/allmods/kys-zheng/save/ranger.idx','game/mods/zheng/data/ranger.idx']:
>     print(p, struct.unpack('<6I', open(p,'rb').read()))"
> reference/allmods/kys-zheng/save/ranger.idx (836, 65992, 104182, 109070, 138446, 138596)   ← 上游错值
> game/mods/zheng/data/ranger.idx          (836, 59076, 97076, 101444, 114092, 114242)   ← RepairIdx 修好
> ```

`物品槽 = (Base 段字节 - 36) / 4`，其中 36 是 Base_S 的固定头（乘船/无用/人X/人Y/人X1/人Y1/人方向/船X/船Y/船X1/船Y1/船方向/队伍1..6 共 18 个 int16）。

复现：

```bash
$ python3 -c "
import struct
for s in ['pascal','pineapple','BookCalamity','mingdong']:
    d=open(f'reference/allmods/kys-{s}/save/ranger.idx','rb').read()
    o=struct.unpack('<6I',d); seg=[o[0]]+[o[i]-o[i-1] for i in range(1,6)]
    print(s, seg[0], (seg[0]-36)//4)"
pascal 836 200
pineapple 1860 456
BookCalamity 1636 400
mingdong 1636 400
```

---

## 3. 快速开始

### 3.1 用 `run-mod.sh`（推荐）

```bash
./tools/run-mod.sh                 # 交互式选择 MOD（自动构建缺失产物）
./tools/run-mod.sh mingdong        # 直接启动指定 MOD
./tools/run-mod.sh --list          # 只列清单
./tools/run-mod.sh --vanilla       # 回到原版（删除 active_mod.txt）
./tools/run-mod.sh --no-build      # 跳过构建检查
LOVE=/path/to/love ./tools/run-mod.sh Dragon
```

`--list` 实测输出（`music(mid/mp3)` 列即音频就绪情况）：

```bash
$ ./tools/run-mod.sh --list
[info] love 可执行文件: /home/woodfish/bin/love.AppImage
可用 MOD（共 20 个）
  index  slug            名称                              music(mid/mp3)
      1  BookCalamity    天书劫                       24/0
      ...
     20  zheng           魏征传奇                    23/0
      0  (vanilla)       原版（不激活 MOD）           sound/*.ogg
```

### 3.2 手工激活（`active_mod.txt`）

```bash
cp game/active_mod.sample.txt game/active_mod.txt
# 改最后一行为目标 slug（说明文字可整份保留）
cd game && love .
```

规则（`framework/mod_data.lua:95` `firstMeaningfulLine`）：

| 输入 | 结果 |
|---|---|
| 空文件 / 只有 `#` 注释 | 未激活（原版路径，零回归） |
| `mingdong` | 激活 mingdong |
| `kys-mingdong` | 等价（自动去 `kys-` 前缀） |
| 多行、含注释 | **只取第一个有效行** |
| 前后空白、`\r\n` | 自动忽略 |

`active_mod.txt` 是运行时状态，已 gitignore（`.gitignore:47`）。

### 3.3 三渠道对照

| 渠道 | 适用 | 说明 |
|---|---|---|
| `./tools/run-mod.sh <slug>` | 日常开发 | 自动构建 + 写 active_mod.txt + 启动 |
| `game/active_mod.txt` | 手工/CI | 只影响 `cd game && love .` |
| `game/tools/mod_check_one.lua` | 自检 | 读环境变量 `MOD_SLUG`，进程内不调动 |

> **⚠ 没有游戏内 MOD 切换 UI。** 正常运行路径是 `ModData.Active()` 读 `active_mod.txt`（`framework/mod_data.lua:121-128`）；
> `ModData.SetActive()`（`:115`）只在**测试/工具**里被调用——生产代码调用点只有 `tools/mod_check_one.lua:47`，
> 其余全在 `tests/unit/`（`test_mod_data.lua`、`test_mod_boot.lua`、`test_mod_e2e.lua`、`boot_one_mod.lua`）。
> 游戏启动后无法切换 MOD，必须退出改文件重开。
>
> ```bash
> $ cd game && grep -rn "ModData.SetActive" --include=*.lua . | grep -v "framework/mod_data.lua" | grep -v "/tests/"
> ./tools/mod_check_one.lua:47:    ModData.SetActive(slug)
> ```
> （仅一行——游戏本体零调用点）

---

## 4. 构建链

`game/tools/mod_build.lua` 把 `reference/allmods/kys-<slug>/` 拍平成 `game/mods/<slug>/`：

```
kys-<slug>/resource/*   ┐
kys-<slug>/fight/*      ├─→ mods/<slug>/data/      （小写化 + 拍平）
kys-<slug>/save/*       ┘
kys-<slug>/script/kdef.grp ─→ mods/<slug>/script/oldevent/oldevent_0..n-1.lua
kys-<slug>/script/talk.grp ─→ mods/<slug>/script/old_talk.lua
kys-<slug>/music/*         ─→ mods/<slug>/music/
kys-<slug>/sound/*         ─→ mods/<slug>/sound/
```

常用命令：

```bash
cd game
lua tools/mod_build.lua kys-mingdong      # 构建单个
lua tools/mod_build.lua --all             # 构建全部（有问题的 MOD 会 exit 1）
lua tools/mod_build.lua --verify-pascal   # 原版基线校验
```

`--verify-pascal` 实测：

```bash
$ lua tools/mod_build.lua --verify-pascal
  [known] event 655: 原版提取器丢弃了 2 个 instruct_43 守卫（二进制中存在）
  [known] event 691: 原版提取器丢弃了重复的 instruct_27（二进制中存在）
[mod_build] pascal baseline: PASS
```

### 4.1 目录映射规则（踩坑点）

| 规则 | 内容 |
|---|---|
| `IGNORE_DIRS = { head, item, eft }`（`mod_build.lua:567`） | `head/` 是 UPedit 导出的 PNG 副产物（头像真身在 `hdgrp.grp`）；`item/`、`eft/` 同理，**不进产物** |
| `ALIAS_MAP`（`mod_build.lua:645`） | `sdx→smap.idx`、`smp→smap.grp`、`wdx→wmap.idx`、`wmp→wmap.grp`（旧命名 → 新命名） |
| `PROBLEM_MARKERS = { "有问题", "正常" }`（`mod_build.lua:58`） | 构建仍尽力完成，但 `--all` 结束时向 stderr 报告并 **exit 1** |
| `preservedOgg`（`mod_build.lua:1240-1269`） | 重建前先暂存 `music/*.ogg`，`rmdirp()` 后写回，**不丢已渲染的音乐** |

实测哪些 MOD 带这些特殊目录：

```bash
$ cd reference/allmods && ls -d */head */item */eft */cc
kys-Dragon/head   kys-GodsDevils/head   kys-mingdong/head   kys-pascal/head
kys-GodsDevils/item   kys-pascal/item
kys-ptt/eft
kys-pascal/cc
```

- `cc/` 是 OpenCC 词典（`STCharacters.txt` 等），属 `BUILD_INPUT`，UTF-8 项目不需要简繁转换 → 不进产物。
- `eft/` 仅 ptt 有，同样不进产物（特效走 `data/eft.grp`）。

20 个源目录的顶层结构差异：

```bash
$ cd reference/allmods && for d in kys-*/; do printf '%-18s %s\n' "$(basename $d)" \
    "$(ls -d $d*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"; done
kys-awaken        fight list music resource save script sound
kys-BookCalamity  fight list music resource save script sound
kys-books         fight list music resource save script sound
kys-Dragon        fight head list music resource save script sound
kys-dream         fight list music resource save script sound
kys-GodsDevils    fight head item list music resource save script sound
kys-HeavenSword   fight list music resource save script sound
kys-lostbook      fight list music resource save script sound
kys-loving        fight list music resource save sound          ← 唯一没有 script/
kys-lyff          fight list music resource save script sound
kys-mingdong      fight head list music resource save script sound
kys-pascal        cc fight head item list music resource save script sound
kys-pig           fight list music resource save script sound
kys-pig3dos       fight list music resource save script sound
kys-pineapple     fight list music resource save script sound
kys-RiverLake     fight list music resource save script sound
kys-stronger      fight list music resource save script sound
kys-SweeOan       fight list music resource save script sound
kys-zheng         fight list music resource save script sound
kys-ptt           eft fight list music resource save script sound
```

| 目录 | `script/` | `head/` | `item/` | `eft/` | `cc/` |
|---|:-:|:-:|:-:|:-:|:-:|
| `kys-pascal` | ✅ | ✅ | ✅ | — | ✅ |
| `kys-loving` | **❌（唯一没有）** | — | — | — | — |
| `kys-Dragon` / `kys-mingdong` | ✅ | ✅ | — | — | — |
| `kys-GodsDevils` | ✅ | ✅ | ✅ | — | — |
| `kys-ptt` | ✅ | — | — | ✅ | — |
| 其余 **14** 个（books/dream/HeavenSword/lostbook/lyff/pig/pig3dos/pineapple/RiverLake/stronger/SweeOan/zheng/awaken/BookCalamity） | ✅ | — | — | — | — |

> **`loving` 没有源侧 `script/` 目录**，但**不影响构建**：`kdef.grp`/`talk.grp` 实际在 `resource/` 下（`mod_build.lua:968` / `:992` 读的就是 `resource/kdef.idx`、`resource/talk.idx`），所以 `game/mods/loving/script/oldevent/` 照样有 **1264** 个事件文件。
>
> ```bash
> $ ls reference/allmods/kys-loving/resource/kdef.* reference/allmods/kys-loving/resource/talk.*
> -rw-rw-r-- 1 woodfish woodfish 183060 Aug  6  2008 .../kdef.grp
> -rw-rw-r-- 1 woodfish woodfish   5056 Aug  6  2008 .../kdef.idx
> -rw-rw-r-- 1 woodfish woodfish 342123 Sep 21  2005 .../talk.grp
> -rw-rw-r-- 1 woodfish woodfish  19992 Sep 21  2005 .../talk.idx
> $ ls game/mods/loving/script/oldevent | wc -l
> 1264
> ```
>
> 源侧 `script/` 目录本身是**上游遗留**：20 个 MOD 里有 19 个含 `script/`，但内容只是单个 `1.lua`（`function f1() clear(); f2(); …` 这种 Pascal 风格片段），`mod_build.lua` **完全不读它**，构建后 `game/mods/<slug>/` 里也找不到 `1.lua`（`find game/mods -name '1.lua' | wc -l` = **0**）。真正的 `script/` 产物由 `resource/kdef.grp` 生成。
>
> ```bash
> $ cd reference/allmods && for d in kys-*/; do [ -d "$d/script" ] && ls "$d/script"; done | sort | uniq -c
>      19 1.lua
> $ cd ../.. && find game/mods -name '1.lua' | wc -l
> 0
> ```

---

## 5. `kysmod.ini` 到底生效多少？（三层口径）

这是最容易误判的地方。必须区分三层，**混为一谈会得出「ini 已适配」的错误结论**：

```
第一层：解析并映射    54 个源键 → 66 个目标   ✅ 全部实现
第二层：目标被引擎读取  6 个目标               ⚠ 仅 6/66（60 个零消费）
第三层：数值语义一致    部分不一致             ❌ 见 §6
```

### 5.1 第一层：解析与映射

`game/framework/mod_ini.lua` 的 `SECTION_MAP`：

| 段 | 源键数 |
|---|---:|
| `system` | 30 |
| `constant` | 22 |
| `music` | 2 |
| **合计** | **54** |

54 个源键去重后 → **50 个唯一静态目标**（48 个 `CC.*` + 2 个 `CONFIG.*`）；再加动态处理 `MaxProList43..58`（`mod_ini.lua:212` `lookupMapping`）**16 个** → **66 个唯一目标**。

实测：

```bash
$ cd game && lua -e '
package.path="./?.lua;"..package.path
local P=require("framework.mod_ini"); local M=P.Mapping()
local uni,raw={},0
for sec,m in pairs(M) do for k,arr in pairs(m) do raw=raw+1
  for _,t in ipairs(arr) do uni[t[1].."."..t[2]]=true end end end
local n=0 for _ in pairs(uni) do n=n+1 end
print("源键="..raw.." 静态唯一目标="..n.." 含动态MaxProList="..(n+16))'
源键=54 静态唯一目标=50 含动态MaxProList=66
```

设计上的刻意取舍：

| 键 | 处理 | 原因 |
|---|---|---|
| `system.resolutionx` / `resolutiony` | **不映射** | 原版 C 引擎从不读 ini，窗口只来自 `config.lua` 的 `CONFIG.Width/Height`（1024×768）；这两键是 `AllMod-Launcher.exe` 的窗口提示。映射过去会把窗口缩到 640×440，属错误适配。详见 `openspec/changes/allmods-ini-parser/reports/resolution-mapping.md` |
| `music.sound3d` | **不映射** | LÖVE 无 3D 音效概念 |
| `constant.begin_scence` | 映射到 `CC.NewGameSceneID`（同 `begin_scene`） | 拼写变体 |
| `system.scenceami` | 映射到 `CC.SceneAmi`（同 `sceneami`） | 拼写变体（mingdong 用前者） |
| 负值（如 loving `BEGIN_SCENE=-1`） | **丢弃**（`NON_NEGATIVE_KEYS`，`mod_ini.lua:106`） | 负场景 ID 会让 `JY.Scene[-1]` 崩 |

未映射键的实测清单（只有 3 类）：

```bash
$ cd game && lua -e '
package.path="./?.lua;"..package.path
local P=require("framework.mod_ini")
for _,s in ipairs({"pascal","Dragon","RiverLake","ptt","pineapple","dream","pig","books","BookCalamity","zheng","loving","awaken","SweeOan","HeavenSword","lostbook","GodsDevils","lyff","pig3dos","mingdong","stronger"}) do
  local r=P.Load("../reference/allmods/kys-"..s.."/kysmod.ini")
  for _,u in ipairs(r.unknown or {}) do print(s, u.section.."."..u.key) end end' | awk '{print $2}' | sort | uniq -c
     20 music.sound3d
     14 system.resolutionx
     14 system.resolutiony
```

### 5.2 第二层：目标真的被读取了吗？——只有 6 个

把 `script/ framework/ engine-love2d/ engine-mud/` 全部扫一遍，逐目标找**读取点**（排除映射层 `mod_ini.lua`/`mod_data.lua`、排除 `jyconst.lua`/`config.lua` 的定义行、排除注释行）：

| 目标 | 读取点 | 位置 |
|---|---:|---|
| `CC.MyThingNum` | 20 处 | `jyconst.lua:159`、`jymain.lua:1224/1230/3550/3867/3882/3896/3900/3901/4958/6401/6407/6674/7272/7292`、`item_async.lua:43/331`、`war_async.lua:1458`、`async_globals.lua:187`、`newevent/scene_1_event_19.lua:27` |
| `CC.MoneyID` | 5 处 | `jymain.lua:3868/4417`、`newevent/scene_1_event_19.lua:53/83/107` |
| `CC.NewGameEvent` | 5 处 | `jymain.lua:209/210`、`jymain_adapter.lua:385/401/402` |
| `CC.NewGameSceneID` | 2 处 | `jymain.lua:195`、`jymain_adapter.lua:355` |
| `CC.NewGameSceneX` | 2 处 | `jymain.lua:197`、`jymain_adapter.lua:357` |
| `CC.NewGameSceneY` | 2 处 | `jymain.lua:198`、`jymain_adapter.lua:358` |
| **零消费** | **60 个目标** | — |

即：**66 个目标里 6 个有真实消费，60 个零消费（其中 42 个 `CC.*` 静态 + 16 个 `MaxProList*` + 2 个 `CONFIG.*`）**。

```bash
$ cd game && lua /tmp/v_final_stats.lua    # 脚本见附录 A
=== 有真实消费的目标 ===
CC.MoneyID              5 处  ...
CC.MyThingNum          20 处  ...
CC.NewGameEvent         5 处  ...
CC.NewGameSceneID       2 处  ...
CC.NewGameSceneX        2 处  ...
CC.NewGameSceneY        2 处  ...

唯一目标=66  有消费=6  零消费=60
```

**42 个零消费 `CC.*` 目标全名单**：

```
BattleSpeed, BeginBattleRolePic, BeginLeaveEvent, ChineseFontSize, CompassID,
EnglishFontSize, ExitGame, ExpRate, ExpandGround, Glhr, HiresText, ItemBeginPic,
KdefScript, LifeHurt, MMapAmi, MODVersion, MaxAddPro, MaxHP, MaxItemAmount,
MaxLevel, MaxMP, MaxPhysicalPower, MaxWeaponMatch, MinKnowledge, NightEffect,
PoisonHurt, Renderer, SceneAmi, SemiReal, Simple, Smooth, SoftStarBeginTalk,
SoftStarNumTalk, VirtualAX, VirtualAY, VirtualBX, VirtualBY, VirtualCrossX,
VirtualCrossY, WMP4Pic, WalkSpeed, WalkSpeed2
```

**更彻底的证据**：`SECTION_MAP` 的 **50 个静态目标**里，只有 6 个在 `script/jyconst.lua` 里真有 `CC.<名字> =` 定义，其余 **42 个 `CC.*` 目标连定义都没有**——`ModIni.Apply` 只是往 `CC` 表上新塞字段，全仓没人读。

```bash
# 逐目标查 jyconst.lua 里有没有 `CC.<名字> =`
$ cd game && for n in $(cat /tmp/targets.txt); do      # targets.txt = 50 个静态目标名（48 CC + 2 CONFIG）
    d=$(grep -cE "^\s*CC\.$n\s*=" script/jyconst.lua); [ "$d" = 0 ] && echo "$n"; done | wc -l
44                                       # 42 个零消费 CC + 2 个 CONFIG（CONFIG 本就不在 jyconst.lua 里，属"找错地方"的假命中）
```

所以「**连定义都没有**」的准确数字是 **43 = 42（CC）+ 1（CONFIG.MasterVolume）**，而不是 44：

| 目标 | 定义位置 | 有消费？ |
|---|---|---|
| 6 个 `CC.*`（`MoneyID`/`MyThingNum`/`NewGameEvent`/`NewGameSceneID`/`NewGameSceneX`/`NewGameSceneY`） | `jyconst.lua` | ✅ 有 |
| 42 个 `CC.*` | **无定义**（`ModIni.Apply` 动态塞进去的） | ❌ 无 |
| 16 个 `CC.MaxProList43..58` | **无定义**，`grep -c MaxProList script/jyconst.lua` = 0 | ❌ 无 |
| `CONFIG.MasterVolume` | **无定义**（`mod_ini.Apply` 动态创建） | ❌ 无 |
| `CONFIG.SoundVolume` | **有定义**（`framework/config.lua:63` `=32`） | ❌ 无（唯一「有定义但零读取」的目标） |

```bash
$ cd game && grep -n "MasterVolume\|SoundVolume" framework/config.lua
63:CONFIG.SoundVolume=32;            --设置播放音效的音量(0-128)      # 有定义、零读取
$ grep -rn "MasterVolume" --include=*.lua script framework engine-love2d engine-mud | grep -v mod_ini
(无输出)                                                              # 只有 mod_ini.Apply 动态创建
$ grep -rn "setVolume" --include=*.lua script framework engine-love2d engine-mud
(无输出)                                                              # 连实现都没有
```

**结论（必须写清楚，不能含糊）**：`HIRES_TEXT` / `CHINESE_FONT_SIZE` / `ENGLISH_FONT_SIZE` / `EXP_RATE` / `NIGHT_EFFECT` / `RENDERER` / `SMOOTH` / `WALK_SPEED` / `MAX_LEVEL` / `MAX_HP` / `MAX_MP` 等键 **全部不生效**。引擎侧对应实现是硬编码的：

| ini 键 | 被期望的效果 | love2d 引擎实际 |
|---|---|---|
| `CHINESE_FONT_SIZE`（仅 zheng = 19） | 中文字号 19 | 恒 `CC.DefaultFont`：`CONFIG.Type==0` → 16，`==1` → 24（`jyconst.lua:527/542`） |
| `HIRES_TEXT`（**5 个文件写过**：pascal=0/Dragon=1/RiverLake=1/pineapple=1/GodsDevils=0） | 高清文字 | 无实现 |
| `EXP_RATE`（**8 个文件写过**：pascal=100 为基准；Dragon/RiverLake/pineapple/awaken/lyff/mingdong=1，GodsDevils=4） | 经验倍率 | 恒 `CC.Exp` 固定表（`jyconst.lua:387`） |
| `MAX_LEVEL`（**5 个偏离**：Dragon=60/RiverLake=60/awaken=60/pineapple=99/ptt=99，其余 15 个与 pascal 同为 30） | 等级上限 | 恒 `CC.Level=30`（`jyconst.lua:386`），`jymain.lua:933/4798/4807` 消费 |
| `MAX_HP` / `MAX_MP`（**7 / 9 个偏离**：HP 为 ptt/pineapple/loving/awaken/lyff/pig3dos/mingdong=9999；MP 再加 Dragon=9999、BookCalamity=3000） | 生命/内力上限 | 恒 `CC.PersonAttribMax["生命最大值"]=999` / `["内力最大值"]=999`（`jyconst.lua:471/474`） |
| `VOLUME` / `VOLUMEWAV`（20 个 MOD 全有） | 主音量 / 音效音量 | **引擎根本没有音量实现**——`lib_love.lua`、`engine_love2d.lua` 全仓零 `setVolume` 调用；`CONFIG.SoundVolume` 只在 `config.lua:63` 定义、无人读 |

```bash
$ cd game && grep -rn "setVolume" --include=*.lua script framework engine-love2d engine-mud
(无输出)                                  # 只有 tests/ 里的 stub
$ grep -rn "CONFIG.SoundVolume" --include=*.lua script framework engine-love2d engine-mud | grep -v "config.lua:63"
(无输出)                                  # 定义了但零消费
```

> **原版对照**：`reference/allmods/kys-pascal/kys.exe` 的 `strings` 输出（23527 行）里，54 个源键的命中情况是：
>
> | 口径 | 命中 | 说明 |
> |---|---:|---|
> | 整行**大写**完全相同 | **39 / 54**（去重 37） | 原版 Delphi 把 ini 键名当大写常量写进二进制 |
> | **大小写不敏感子串** | **48 / 54** | 宽松口径，会命中更长符号里的片段 |
>
> ```bash
> $ strings reference/allmods/kys-pascal/kys.exe > /tmp/kys_strings.txt
> $ wc -l < /tmp/kys_strings.txt
> 23527
> # 宽松口径也找不到的 6 个键
> $ for k in begin_scence exit_game glhr scenceami sceneami volume2; do
>     printf '%-14s %s\n' "$k" "$(grep -ic "$k" /tmp/kys_strings.txt)"; done
> begin_scence   0
> exit_game      0
> glhr           0
> scenceami      0
> sceneami       0
> volume2        0
> ```
>
> 也就是说：**`BEGIN_SCENCE`（RiverLake/mingdong 的拼写变体）、`SCENEAMI`/`SCENCEAMI`、`GLHR`、`EXIT_GAME`、`VOLUME2` 这 6 个键，在原版 `kys.exe` 里连字符串都没有**。前两个纯属 love2d 侧为了容错才登记（`mod_ini.lua:141-142`、`:168`），原版引擎大概率压根不认。反过来说，**48 个键确实在原版引擎里出现过**——这是「love2d 复刻版没实现」而非「原版也不支持」的硬证据。

### 5.3 各 MOD 的 ini 特例（哪些键偏离原版默认）

**基准 = `reference/allmods/kys-pascal/kysmod.ini`（原版）**，下表逐键与它比。原版默认值：`MAX_LEVEL=30`、`MAX_HP=999`、`MAX_MP=999`、`MAX_ITEM_AMOUNT=200`、`EXP_RATE=100`、`BEGIN_EVENT=691`、`BEGIN_SCENE=70`、`BEGIN_Sx=20`、`BEGIN_Sy=19`、`MONEY_ID=174`、`WALK_SPEED=20`、`VOLUME=5`、`VOLUMEWAV=10`。

> **注意 `BEGIN_Sx=20` / `BEGIN_Sy=19`**（不是 19/20）。ini 里的注释是「起始坐标（与游戏里的 x,y 方向相反…）」，`mod_ini.lua:171-172` 因此**故意交叉映射**：`begin_sx → CC.NewGameSceneY`、`begin_sy → CC.NewGameSceneX`。所以 pascal 映射后是 `NewGameSceneX=19`（来自 `BEGIN_Sy`）、`NewGameSceneY=20`（来自 `BEGIN_Sx`）。

★ = **第二层已消费**（6 个：`MONEY_ID`/`MAX_ITEM_AMOUNT`/`BEGIN_EVENT`/`BEGIN_SCENE`/`BEGIN_Sx`/`BEGIN_Sy`），但**值本身未必被尊重**——见 §5.2「第三层」。
`(新键)` = pascal 里没有这个键，只有该 MOD 自己加的。
`MaxProList` 合并成一行（这 16 个键全部零消费，逐项列出来只会淹没重点）。
**`MODVERSION` 刻意不列入**：pascal 没写这个键，其余 **16 个 MOD 都写了**（`awaken=81`、`BookCalamity=71`、`books=21`、`Dragon=12`、`dream=23`、`GodsDevils=100`、`loving=91`、`lyff=11`、`mingdong=72`、`pig=11`、`pig3dos=13`、`pineapple=22`、`ptt=41`、`RiverLake=31`、`SweeOan=100`、`zheng=51`；`HeavenSword`/`lostbook`/`stronger`/`pascal` 四个没写）。它已被 `mod_ini.lua` 映射到 `CC.MODVersion`（`NON_NEGATIVE_KEYS` 白名单里也有），但 `grep -c "CC\.MODVersion" script/jyconst.lua` = **0**（无定义、零消费），纯元数据，故不在「偏离原版默认」的语义表里逐行列出。

```bash
$ cd reference/allmods && for d in kys-*/; do s=$(basename $d | sed 's/^kys-//');
    v=$(grep -i '^MODVERSION' $d/kysmod.ini | tr -d '\r' | sed 's/.*=//;s/ //g'); printf '%-14s %s\n' "$s" "${v:--}"; done
awaken         81
BookCalamity   71
books          21
Dragon         12
dream          23
GodsDevils     100
HeavenSword    -
lostbook       -
loving         91
lyff           11
mingdong       72
pascal         -
pig            11
pig3dos        13
pineapple      22
ptt            41
RiverLake      31
stronger       -
SweeOan        100
zheng          51
```

| # | 名称 | slug | 偏离原版默认的键（`MaxProList` 已合并） |
|---:|---|---|---|
| 0 | 原版 | `pascal` | — |
| 1 | 苍龙逐日 | `Dragon` | `SMOOTH=0`、`SEMIREAL=0`、`SIMPLE=0`、`EXPAND_GROUND=0`、`WMP_4_PIC=1`、`HIRES_TEXT=1`、`EXP_RATE=1`、`ITEM_BEGIN_PIC=4131`、★`BEGIN_Sx=31`、★`BEGIN_Sy=16`、`BEGIN_LEAVE_EVENT=100`、`MAX_LEVEL=60`、`MAX_MP=9999`、`POISON_HURT=1`(新键)、`MaxProList` ×13 → 999 |
| 2 | 再战江湖 | `RiverLake` | `WALK_SPEED=10`、`SMOOTH=0`、`GLHR=0`、`SEMIREAL=0`、`WALK_SPEED2=0`、`SIMPLE=0`、`BATTLE_SPEED=0`、`EXP_RATE=1`、`HIRES_TEXT=1`、`VOLUME=10`、`VOLUMEWAV=30`、`ITEM_BEGIN_PIC=4420`、`BEGIN_SCENCE=70`(新键，**拼写变体**)、★`BEGIN_Sx=13`、★`BEGIN_Sy=54`、`BEGIN_LEAVE_EVENT=1`、`MAX_LEVEL=60`、`MIN_KNOWLEDGE=10`、`MAX_ADD_PRO=0`、`MaxProList` ×9 → 200/800 |
| 3 | PTT | `ptt` | `WALK_SPEED=10`、`SEMIREAL=0`、`WALK_SPEED2=9`、`SIMPLE=0`、`BATTLE_SPEED=23`、`VOLUME=10`、`VOLUMEWAV=30`、`BEGIN_LEAVE_EVENT=1050`、`MAX_LEVEL=99`、`LIFE_HURT=100`、`MAX_HP=9999`、`MAX_MP=9999`、`MaxProList` ×13 → 9999 |
| 4 | 再破菠萝 | `pineapple` | `WALK_SPEED=10`、`RESOLUTIONY=480`、`SEMIREAL=0`、`WALK_SPEED2=11`、`SIMPLE=0`、`BATTLE_SPEED=14`、`WMP_4_PIC=1`、`KDEF_SCRIPT=1`、`HIRES_TEXT=1`、`EXP_RATE=1`、`VOLUME=17`、`VOLUMEWAV=30`、`ITEM_BEGIN_PIC=3753`、★`BEGIN_EVENT=600`、★`BEGIN_SCENE=33`、★`BEGIN_Sx=42`、★`BEGIN_Sy=20`、★`MONEY_ID=342`、`COMPASS_ID=-1`、`BEGIN_LEAVE_EVENT=1`、`MAX_LEVEL=99`、`MAX_WEAPON_MATCH=58`、★`MAX_ITEM_AMOUNT=456`、`MAX_HP=9999`、`MAX_MP=9999`、`MAX_ADD_PRO=0`、`MaxProList` ×12 → 600 |
| 5 | 笑梦游记 | `dream` | `WALK_SPEED=40`、`RESOLUTIONY=480`、`VOLUME=10`、`VOLUMEWAV=30`、`ITEM_BEGIN_PIC=4131`、★`BEGIN_EVENT=300`、★`BEGIN_SCENE=121`、★`BEGIN_Sx=29`、★`BEGIN_Sy=43`、★`MONEY_ID=0`（无金钱物品）、`COMPASS_ID=1`、`BEGIN_LEAVE_EVENT=1`、`MAX_WEAPON_MATCH=16`、`MIN_KNOWLEDGE=10` |
| 6 | 小猪闯江湖 | `pig` | `SEMIREAL=0`、`WALK_SPEED2=21`、`SIMPLE=0`、`BATTLE_SPEED=12`、`EXPAND_GROUND=0`、`MAX_ADD_PRO=0`、`MaxProList` ×15 → 999 |
| 7 | 天书奇侠试玩 | `books` | `WALK_SPEED=10`、`WALK_SPEED2=11`、`SIMPLE=0`、`BATTLE_SPEED=10`、`EXPAND_GROUND=0`、`VOLUME=10`、`VOLUMEWAV=30`、`BEGIN_LEAVE_EVENT=1`、`MAX_ADD_PRO=0`、`MaxProList` ×3 → 255 |
| 8 | 天书劫 | `BookCalamity` | `WALK_SPEED=5`、`SEMIREAL=0`、`ITEM_BEGIN_PIC=4131`、`BEGIN_LEAVE_EVENT=100`、`MAX_WEAPON_MATCH=99`、`MIN_KNOWLEDGE=1`、★`MAX_ITEM_AMOUNT=400`、`MAX_MP=3000`、`MaxProList` ×9 → 200/250 |
| 9 | 魏征传奇 | `zheng` | `WALK_SPEED=10`、`SEMIREAL=0`、`CHINESE_FONT_SIZE=19`(新键)、`ENGLISH_FONT_SIZE=19`(新键)、`WALK_SPEED2=18`、`SIMPLE=0`、`BATTLE_SPEED=0`、`EXPAND_GROUND=0`、`VOLUME=10`、`VOLUMEWAV=30`、`MIN_KNOWLEDGE=0`、`MAX_ADD_PRO=0` |
| 10 | 问情篇 | `loving` | `WALK_SPEED=10`、`SMOOTH=0`、`EXIT_GAME=0`、`WALK_SPEED2=15`、`BATTLE_SPEED=15`、`SIMPLE=0`、`VOLUME=10`、`VOLUMEWAV=30`、★`BEGIN_EVENT=-1`、★`BEGIN_SCENE=-1`（**负值被 `NON_NEGATIVE_KEYS` 丢弃 → `nil`**）、`LIFE_HURT=100`、`MAX_HP=9999`、`MAX_MP=9999`、`MAX_ADD_PRO=0`、`MaxProList` ×13 → 999 |
| 11 | 真龙苏醒 | `awaken` | `WALK_SPEED=22`、`SMOOTH=0`、`SEMIREAL=0`、`KDEF_SCRIPT=1`、`WALK_SPEED2=22`、`SIMPLE=0`、`BATTLE_SPEED=21`、`EXPAND_GROUND=0`、`WMP_4_PIC=1`、`EXP_RATE=1`、`VOLUME=17`、`VOLUMEWAV=33`、`ITEM_BEGIN_PIC=4131`、★`BEGIN_Sx=31`、★`BEGIN_Sy=16`、`BEGIN_LEAVE_EVENT=100`、`MAX_LEVEL=60`、`MAX_HP=9999`、`MAX_MP=9999`、`POISON_HURT=1`(新键)、`MaxProList` ×13 → 999 |
| 12 | 瑞安群侠传 | `SweeOan` | `SIMPLE=0`、`EXPAND_GROUND=0` |
| 13 | 倚天剑 | `HeavenSword` | `SEMIREAL=0`、`SIMPLE=0`、`EXPAND_GROUND=0` |
| 14 | 失传天书-越女剑 | `lostbook` | — |
| 15 | 天龙八部 | `GodsDevils` | `SIMPLE=0`、`EXP_RATE=4` |
| 16 | 刘亦纷飞版 | `lyff` | `SEMIREAL=0`、`WALK_SPEED2=18`、`SIMPLE=0`、`BATTLE_SPEED=17`、`EXPAND_GROUND=0`、`EXP_RATE=1`、`MAX_HP=9999`、`MAX_MP=9999`、`MAX_ADD_PRO=0`、`MaxProList` ×15 → 999 |
| 17 | 金庸水浒传dos版 | `pig3dos` | `ITEM_BEGIN_PIC=5720`、★`BEGIN_EVENT=301`、★`BEGIN_SCENE=0`、`MAX_HP=9999`、`MAX_MP=9999`、`MaxProList` ×11 → 200/999 |
| 18 | 名动天下 | `mingdong` | `WALK_SPEED=28`、`RESOLUTIONX=960`、`RESOLUTIONY=660`、`SCENCEAMI=2`(新键)、`SEMIREAL=0`、`WALK_SPEED2=23`、`SIMPLE=0`、`BATTLE_SPEED=28`、`EXPAND_GROUND=0`、`EXP_RATE=1`、`VOLUME=22`、`VOLUMEWAV=26`、`SOUND3D=0`、`ITEM_BEGIN_PIC=2001`、`BEGIN_SCENCE=70`(新键，拼写变体)、`MAX_WEAPON_MATCH=99`、`MIN_KNOWLEDGE=10`、★`MAX_ITEM_AMOUNT=330`、`MAX_HP=9999`、`MAX_MP=9999`、`MAX_ADD_PRO=0`、`MaxProList` ×8 → 500/999 |
| 19 | 威力加强版 | `stronger` | — |

**逐列计数**（只数「偏离原版」的 MOD 个数，`MaxProList` 另计）：

| 键 | 偏离的 MOD | 个数 | 消费情况 |
|---|---|---:|---|
| `MAX_LEVEL` | Dragon=60、RiverLake=60、awaken=60、pineapple=99、ptt=99 | 5 | ❌ 恒 `CC.Level=30` |
| `MAX_HP` | ptt、pineapple、loving、awaken、lyff、pig3dos、mingdong = 9999 | 7 | ❌ 恒 999 |
| `MAX_MP` | Dragon=9999、ptt=9999、pineapple=9999、loving=9999、awaken=9999、lyff=9999、pig3dos=9999、mingdong=9999、BookCalamity=3000 | 9 | ❌ 恒 999 |
| `MAX_ITEM_AMOUNT` | pineapple=456、BookCalamity=400、mingdong=330 | 3 | ⚠ 已消费，但 `Base_S` 不扩容（§6） |
| `EXP_RATE` | Dragon=1、RiverLake=1、pineapple=1、awaken=1、lyff=1、mingdong=1、GodsDevils=4 | 7 | ❌ 恒 `CC.Exp` |
| `HIRES_TEXT` | pascal=0（基准）、Dragon=1、RiverLake=1、pineapple=1、GodsDevils=0（**与基准相同**） | 3 | ❌ 无实现 |
| `CHINESE_FONT_SIZE` / `ENGLISH_FONT_SIZE` | zheng=19（20 个 MOD 里唯一写过这两个键的） | 1 | ❌ 恒 `CC.DefaultFont` |
| `WALK_SPEED` | BookCalamity=5、books=10、loving=10、pineapple=10、ptt=10、RiverLake=10、zheng=10、awaken=22、mingdong=28、dream=40 | 10 | ❌ 恒 `CC.WalkSpeed` 族 |
| `VOLUME` / `VOLUMEWAV` | **20 个 MOD 全都有**（100% 覆盖），其中 `VOLUME` 偏离 9 个（RiverLake/books/dream/loving/ptt/zheng=10、awaken/pineapple=17、mingdong=22）、`VOLUMEWAV` 偏离 9 个（同 9 个 MOD，值 26~33） | 20 有 / 9 偏离 | ❌ 引擎无 `setVolume`（§5.2） |
| `MaxProList43..58` | **20 个 MOD 全部写了全部 16 个键**；其中 12 个 MOD 的取值与 pascal 不同（pig/lyff 各 15 个键不同、Dragon/awaken/loving/ptt 各 13 个），另 8 个（GodsDevils/HeavenSword/SweeOan/dream/lostbook/pascal/stronger/zheng）与基准完全一致 | 16 键 × 20 MOD | ❌ 全仓零定义、零引用 |

> **`HIRES_TEXT` 别数成 5**：全 20 个 ini 里只有 **5 个文件**写了这个键——
> `pascal=0`（基准）、`Dragon=1`、`RiverLake=1`、`pineapple=1`、`GodsDevils=0`。
> 其中 `GodsDevils=0` 与基准**取值相同**，不算偏离，所以「偏离原版」= **3**。
> 同理 `MaxProList43..58` **20 个 MOD 全都写满 16 个键**（共 320 行赋值），但**一个都没被消费**——写的人多不代表生效。
> 顺带纠一个常见误读：「pig/lyff 各 15 项、ptt 13 项」说的是**取值与 pascal 不同的键数**，不是「写了几个键」（每个 MOD 都是 16 个）。
>
> ```bash
> $ python3 - <<'EOF'
> import glob,re,os
> def keys(p):
>     d={}
>     for l in open(p,'rb').read().decode('latin-1').splitlines():
>         m=re.match(r'\s*MaxProList(\d+)\s*=\s*(-?\d+)',l,re.I)
>         if m: d[int(m.group(1))]=int(m.group(2))
>     return d
> base=keys('reference/allmods/kys-pascal/kysmod.ini')
> for d in sorted(glob.glob('reference/allmods/kys-*/')):
>     s=os.path.basename(d.rstrip('/'))[4:]
>     k=keys(d+'kysmod.ini')
>     print(f"{s:14} 写了{len(k):2}个键  与pascal偏离{sum(1 for n,v in k.items() if base.get(n)!=v):2}个")
> EOF
> BookCalamity   写了16个键  与pascal偏离 9个
> Dragon         写了16个键  与pascal偏离13个
> GodsDevils     写了16个键  与pascal偏离 0个
> HeavenSword    写了16个键  与pascal偏离 0个
> RiverLake      写了16个键  与pascal偏离 9个
> SweeOan        写了16个键  与pascal偏离 0个
> awaken         写了16个键  与pascal偏离13个
> books          写了16个键  与pascal偏离 3个
> dream          写了16个键  与pascal偏离 0个
> lostbook       写了16个键  与pascal偏离 0个
> loving         写了16个键  与pascal偏离13个
> lyff           写了16个键  与pascal偏离15个
> mingdong       写了16个键  与pascal偏离 8个
> pascal         写了16个键  与pascal偏离 0个
> pig            写了16个键  与pascal偏离15个
> pig3dos        写了16个键  与pascal偏离11个
> pineapple      写了16个键  与pascal偏离12个
> ptt            写了16个键  与pascal偏离13个
> stronger       写了16个键  与pascal偏离 0个
> zheng          写了16个键  与pascal偏离 0个
> ```
> 这两处是本文档最容易口算出错的地方，一律以 `grep -i '^KEY[[:space:]]*=' reference/allmods/kys-*/kysmod.ini` 的原文为准。


复现（逐键 diff，不依赖任何脚本）：

```bash
$ cd /home/woodfish/project/legend-love && python3 - <<'EOF'
import glob, os
def parse(p):
    d={}
    for line in open(p, encoding="latin-1"):
        line=line.split(";")[0].strip()
        if "=" in line:
            k,v=line.split("=",1); d[k.strip().lower()]=v.strip()
    return d
base=parse("reference/allmods/kys-pascal/kysmod.ini")
for m in ["pascal","Dragon","RiverLake","ptt","pineapple","dream"]:
    d=parse(f"reference/allmods/kys-{m}/kysmod.ini")
    print(m, {k:(base.get(k),v) for k,v in d.items() if base.get(k)!=v and not k.startswith("maxprolist")})
EOF
pascal {}                                                  # 基准，零偏离
Dragon {'modversion': (None, '12'), 'smooth': ('1','0'), 'begin_sx': ('20','31'), ...}
RiverLake {'modversion': (None, '31'), 'walk_speed': ('20','10'), 'begin_sx': ('20','13'), ...}
ptt {'modversion': (None, '41'), 'walk_speed': ('20','10'), 'max_level': ('30','99'), ...}
pineapple {'modversion': (None, '22'), 'walk_speed': ('20','10'), 'max_item_amount': ('200','456'), ...}
dream {'modversion': (None, '23'), 'walk_speed': ('20','40'), 'begin_sx': ('20','29'), ...}
```

> **`MODVersion` 不是配置，是版本号**（11..100），`SECTION_MAP` 里映射到 `CC.MODVersion` 但零消费，上表已略过。

★ 组的实测确认（映射后 `CC.*` 的实际取值）：

```bash
$ cd game && lua -e '
package.path="./?.lua;"..package.path
local P=require("framework.mod_ini")
for _,s in ipairs({"pascal","pineapple","dream","loving","pig3dos","mingdong"}) do
  local c=P.Load("../reference/allmods/kys-"..s.."/kysmod.ini").CC
  print(s, c.NewGameEvent, c.NewGameSceneID, c.NewGameSceneX, c.NewGameSceneY, c.MoneyID, c.MyThingNum) end'
pascal     691  70   19  20  174  200
pineapple  600  33   20  42  342  456
dream      300  121  43  29  0    200
loving     nil  nil  19  20  174  200          # -1 被 NON_NEGATIVE_KEYS 丢弃
pig3dos    301  0    19  20  174  200
mingdong   691  70   19  20  174  330
```

> **注意 `dream` 的 `MONEY_ID=0`**：`0` 是合法物品 ID，会被写入 `CC.MoneyID` 且 `jymain.lua:3868` 会拿它比对背包——这符合该 MOD「无金钱系统」的设计，非缺陷。

---

## 6. 已知缺陷：物品槽 200 上限（`MyThingNum` vs `CC.Base_S`）

### 6.1 现象

`CC.MyThingNum`（背包槽数）会被 ini 覆盖为 456 / 400 / 330，但 `CC.Base_S`（二进制结构定义表）**在 ini 应用之前就已经按 200 建好，之后从不重建**。于是所有 > 200 槽的访问都拿到 `nil`。

| 环节 | 位置 | 行为 |
|---|---|---|
| 建立结构表 | `script/jyconst.lua:139` `CC.MyThingNum=200`；`:159-162` `for i=1,CC.MyThingNum do CC.Base_S["物品"..i]=...` | 建 200 槽 |
| 调用顺序 | `framework/jymain_adapter.lua:66 SetGlobalConst()` → `:75 ModData.LoadIni()` | ini 在结构表建好**之后**才 Apply |
| 覆盖 | `framework/mod_ini.lua` `ModIni.Apply` → `CC.MyThingNum=456` | 只改数字，不重建 `CC.Base_S` |

实测（`pascal` 200 槽 vs `pineapple` 456 槽）：

```bash
$ cd game && lua /tmp/v_slot2.lua pineapple
pineapple     ini=true MyThingNum: 200→456  Base_S物品槽=200  Base_S[物品456]=nil  Base_S[物品201]=nil
$ lua /tmp/v_slot2.lua pascal
pascal        ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
```

20 个 MOD 全扫（`Base_S物品槽` 恒 200；只有 3 个 MOD 的 `MyThingNum` 超过 200，它们的「末槽」才是 `nil`）：

```bash
$ cd game && for s in pascal Dragon GodsDevils HeavenSword RiverLake SweeOan awaken books dream \
    lostbook loving lyff mingdong pig pig3dos pineapple ptt stronger zheng BookCalamity; do
    lua /tmp/v_slot2.lua "$s" 2>&1 | head -1; done
BookCalamity  ini=true MyThingNum: 200→400  Base_S物品槽=200  Base_S[物品400]=nil  Base_S[物品201]=nil   ← 受影响
Dragon        ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
GodsDevils    ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
HeavenSword   ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
RiverLake     ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
SweeOan       ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
awaken        ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
books         ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
dream         ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
lostbook      ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
loving        ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
lyff          ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
mingdong      ini=true MyThingNum: 200→330  Base_S物品槽=200  Base_S[物品330]=nil  Base_S[物品201]=nil   ← 受影响
pascal        ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
pig           ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
pig3dos       ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
pineapple     ini=true MyThingNum: 200→456  Base_S物品槽=200  Base_S[物品456]=nil  Base_S[物品201]=nil   ← 受影响
ptt           ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
stronger      ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
zheng         ini=true MyThingNum: 200→200  Base_S物品槽=200  Base_S[物品200]=table: 0x...  Base_S[物品201]=nil
```

> `Base_S[物品201]=nil` 在**所有** MOD 上都成立——对 17 个 200 槽 MOD 那是「正确行为」，对 3 个 >200 槽 MOD 才是缺陷。判断缺陷要看「末槽 `物品N` 是不是 `nil`」，不能看 201。

### 6.2 三条崩溃路径

| 路径 | 触发 | 实测报错 |
|---|---|---|
| ① 直接写越界槽 | `JY.Base["物品201"]=5` | `script/jymain.lua:2035: attempt to index a nil value (local 't')`（`SetDataFromStruct` 里 `CC.Base_S[key]` 为 nil） |
| ② 物品用尽左移压缩 | `instruct_32(id,-1)`（`jymain.lua:3896-3901` 的 shift 分支） | `tests/mod_boot_harness.lua:10: attempt to perform arithmetic on a nil value (local 'a')`（`Byte.set16` → `bit32.band(nil,…)`） |
| ③ 背包遍历比较 | `framework/item_async.lua:43-45` `if id >= 0` | `attempt to compare number with nil` |

复现命令：

```bash
$ cd game && SLUG=pineapple lua /tmp/probe_write.lua
MyThingNum=456  Base_S物品槽=200
写 物品201 -> ok=false err=./script/jymain.lua:2035: attempt to index a nil value (local 't')

$ cd game && lua /tmp/v_shift2.lua pineapple     # 强制触发 shift 分支
pineapple: MyThingNum=456 物品1=342 物品数量1=100
   shift 触发 -> ok=false err=./tests/mod_boot_harness.lua:10: attempt to perform arithmetic on a nil value (local 'a')

$ cd game && lua /tmp/v_item.lua pineapple        # 复刻 item_async.lua:43-45
pineapple     MyThingNum=456  item_async 循环 -> ok=false err=attempt to compare number with nil
```

对照：200 槽的 MOD 三条路径全部 `ok=true`（`pascal` / `Dragon` / `stronger`）。

### 6.3 为什么说这是**缺陷**而不是「MOD 数据错」

铁证：**存档格式本身就支持 > 200 槽**。

`ranger.idx` 首段字节数 = `36 + 4*N`，20 个 MOD 的实测值只有三种：

| N | Base 段字节 | 涉及 MOD |
|---:|---:|---|
| 200 | 836 | 17 个（pascal/Dragon/RiverLake/ptt/dream/pig/books/zheng/loving/awaken/SweeOan/HeavenSword/lostbook/GodsDevils/lyff/pig3dos/stronger） |
| 400 | 1636 | BookCalamity、mingdong |
| 456 | 1860 | pineapple |

也就是说 `reference/allmods` 的原始存档**真实预留了 456 / 400 槽**，MOD 作者按原版 C 引擎（读 `MAX_ITEM_AMOUNT` 分配）的真实容量做的数据；只有 `jyconst.lua` 把它写死 200。

`mingdong` 更是**三重不一致**：

| 来源 | 值 |
|---|---|
| `save/ranger.idx` Base 段 | 1636 B → **400 槽** |
| `kysmod.ini` `MAX_ITEM_AMOUNT` | **330** |
| `CC.MyThingNum`（映射后） | **330** |
| `CC.Base_S` 实际槽数 | **200** |

### 6.4 目前为什么还没炸

新鲜存档里 **> 200 槽全为空槽**（`0`/`-1`/`65535`）：

```bash
$ python3 -c "
import struct
for s in ['pineapple','BookCalamity','mingdong','pascal']:
    d=open(f'reference/allmods/kys-{s}/save/ranger.idx','rb').read()
    n=(struct.unpack('<I',d[:4])[0]-36)//4
    g=open(f'reference/allmods/kys-{s}/save/ranger.grp','rb').read()
    filled=sum(1 for i in range(1,n+1) if struct.unpack('<h',g[36+4*(i-1):36+4*(i-1)+2])[0] not in (0,-1,65535))
    hi=sum(1 for i in range(201,n+1) if struct.unpack('<h',g[36+4*(i-1):36+4*(i-1)+2])[0] not in (0,-1,65535))
    print(f'{s:14} slots={n:4} 有值={filled:4} 其中>200={hi}')"
pineapple      slots= 456 有值=   4 其中>200=0
BookCalamity   slots= 400 有值=   0 其中>200=0
mingdong       slots= 400 有值=   0 其中>200=0
pascal         slots= 200 有值=   3 其中>200=0
```

缺陷「潜伏」：只要玩家把背包填过 200 格（或在 3 个 MOD 里触发一次物品用尽压缩），立即命中 §6.2 的路径 ②。

### 6.5 测试盲区（为什么套件全绿）

现有测试**只验 ini→`CC.MyThingNum` 的映射值，没有一条断言 `CC.Base_S` 槽数与之相等**：

| 测试 | 断言内容 |
|---|---|
| `tests/unit/test_mod_boot.lua:190` | `assertEquals(330, CC.MyThingNum)` — 只验数字 |
| `tests/unit/test_mod_ini.lua:57` | `MAX_ITEM_AMOUNT=330` 解析 |
| `tests/unit/test_mod_ini.lua:65-66/209` | ini→`CC.MaxItemAmount`/`CC.MyThingNum` 映射 |
| `tests/unit/test_mod_e2e.lua:41/84` | 同上 |

`grep -r "Base_S" openspec/` 无任何 TODO/风险记录。→ **套件 2349 全绿但缺陷存活**，这是典型的「断言无鉴别力」。

### 6.6 影响面与分级

| 项 | 内容 |
|---|---|
| 受影响 MOD | `pineapple`(456)、`BookCalamity`(400)、`mingdong`(330) |
| 不影响 | 其余 17 个（`MyThingNum=200` = `Base_S` 槽数） |
| 触发条件 | ① 背包占满前 200 格后继续拾取 ② 任意物品用尽（走 shift 压缩）③ 打开物品菜单遍历 |
| 严重度 | 高（存档相关，一旦写入越界值可能污染存档） |
| 修复方向 | `ModIni.Apply` 之后按新的 `CC.MyThingNum` 重建 `CC.Base_S["物品"..i]`/`["物品数量"..i]`（`{36+4*(i-1),0,2}` / `{36+4*(i-1)+2,0,2}`）。原型见下，**尚未合入** |
| 相关但独立 | `MaxLevel`/`MaxHP`/`MaxMP`/`ExpRate` 的数值错位（§5.2「第三层」）同属「ini 已映射但引擎用别的常量」，需分别立项 |

#### 6.6.1 修复原型实测（临时树 `/tmp/bsp`，未进仓库）

改动只有 8 行，插在 `ModData.LoadIni()` 里 `ModIni.Apply()` 之后：

```lua
-- /tmp/bsp/framework/mod_data.lua:751-758
local CC = rawget(_G, "CC")
if CC and CC.Base_S then
    local n = tonumber(CC.MyThingNum) or 200
    for i = 1, n do
        CC.Base_S["物品" .. i]     = {36 + 4 * (i - 1),     0, 2}
        CC.Base_S["物品数量" .. i] = {36 + 4 * (i - 1) + 2, 0, 2}
    end
end
```

同一批探针，仓库 vs 原型树逐格对照：

| 探针 | MOD | 仓库（现状） | 原型树（修复后） |
|---|---|---|---|
| `v_slots3` 槽数 | pineapple / BookCalamity / mingdong | `MyThingNum=456/400/330` 但 `Base_S物品槽=**200**`、`物品N=nil` | `Base_S物品槽=**456/400/330**`、`物品N=table` ✅ |
| `v_read` 越界槽 | pineapple | `物品201=nil`、`物品N=nil` | `物品201=-1`、`物品N=-1` ✅ |
| `v_read` 菜单遍历 | BookCalamity / mingdong | `ok=false` — `attempt to compare number with nil` | `ok=true` ✅ |
| `v_full2` 满包拾取 | pineapple / BookCalamity / mingdong | `ok=false` — `bit32.band(nil)`，物品**没进包** | `ok=true`，物品落到**第 200 槽** ✅ |
| 对照（本来就正常） | pascal / Dragon / stronger | `ok=true` | `ok=true`（无变化，零回归） |

```bash
# 槽数（先看这一条，最直观）
$ cd game && for s in pascal pineapple BookCalamity mingdong; do lua /tmp/v_slots3.lua $s; done
pascal        MyThingNum=200  Base_S物品槽=200  物品N=table: 0x...   # 一致
pineapple     MyThingNum=456  Base_S物品槽=200  物品N=nil            # 456 ≠ 200
BookCalamity  MyThingNum=400  Base_S物品槽=200  物品N=nil            # 400 ≠ 200
mingdong      MyThingNum=330  Base_S物品槽=200  物品N=nil            # 330 ≠ 200
$ cd /tmp/bsp && for s in pascal pineapple BookCalamity mingdong; do lua /tmp/v_slots3.lua $s; done
pascal        MyThingNum=200  Base_S物品槽=200  物品N=table: 0x...
pineapple     MyThingNum=456  Base_S物品槽=456  物品N=table: 0x...
BookCalamity  MyThingNum=400  Base_S物品槽=400  物品N=table: 0x...
mingdong      MyThingNum=330  Base_S物品槽=330  物品N=table: 0x...

# 菜单遍历：仓库（现状）3 个 MOD 崩
$ cd game && for s in pascal pineapple BookCalamity mingdong; do lua /tmp/v_read.lua $s; done
pascal        MyThingNum=200  物品200=-1  物品201=nil  物品N=-1   菜单遍历 -> ok=true
pineapple     MyThingNum=456  物品200=-1  物品201=nil  物品N=nil  菜单遍历 -> ok=true   # slot1 有值即 break，被掩盖
BookCalamity  MyThingNum=400  物品200=-1  物品201=nil  物品N=nil  菜单遍历 -> ok=false attempt to compare number with nil
mingdong      MyThingNum=330  物品200=-1  物品201=nil  物品N=nil  菜单遍历 -> ok=false attempt to compare number with nil

# 原型树（修复后）：4 个 MOD 全不崩
$ cd /tmp/bsp && for s in pascal pineapple BookCalamity mingdong; do lua /tmp/v_read.lua $s; done
pascal        MyThingNum=200  物品200=-1  物品201=nil    物品N=-1   菜单遍历 -> ok=true   # 200 槽，201 仍是 nil（正确）
pineapple     MyThingNum=456  物品200=-1  物品201=-1     物品N=-1   菜单遍历 -> ok=true
BookCalamity  MyThingNum=400  物品200=-1  物品201=-1     物品N=-1   菜单遍历 -> ok=true
mingdong      MyThingNum=330  物品200=-1  物品201=-1     物品N=-1   菜单遍历 -> ok=true
```

> **注意 `pascal` 在原型树里 `物品201` 仍是 `nil`**——它不是「被修好了」，而是本来就只有 200 槽、201 本就该是 `nil`。这正好说明修复**没有把 200 槽的 MOD 误扩成 456**。
>
> **这条对照是必须的**：只看 3 个坏 MOD 变好，无法排除「顺手把所有 MOD 都扩到 456」这种错误实现。

合入时要补的两件事（缺一不可）：

1. **断言**：`tests/unit/test_mod_boot.lua` 增加 `forEachMod: Base_S 物品槽数 == CC.MyThingNum`（现有 2349 条断言**一条都没有**，见 §6.5）。
2. **负向对照**：反向把重建循环注释掉，确认该断言**真的会红**——否则又是一条「永远不可能失败」的断言。

### 6.7 与之独立、但同样命中的第二个缺陷：**背包满时物品静默丢失**

> 这条**不是** §6.1 那个「槽数不够」的缺陷，**20 个 MOD 全部命中**（含 `MyThingNum=200` 的 17 个）。两者根因不同、修复方案也不同，别混为一谈。

先把代码摊开（`script/jymain.lua:3880-3903`，**注意全文没有一条 `return`**）：

```lua
function instruct_32(thingid, num)          -- 增加物品
    local p = 1;
    for i = 1, CC.MyThingNum do
        if JY.Base["物品" .. i] == thingid then          -- ① 同 id：累加数量
            JY.Base["物品数量" .. i] = JY.Base["物品数量" .. i] + num
            p = i; break;
        elseif JY.Base["物品" .. i] == -1 then           -- ② 有空槽：放进去
            JY.Base["物品" .. i] = thingid;
            JY.Base["物品数量" .. i] = num;
            p = 1; break;
        end
    end
    -- ③ 两个分支都没命中时，循环正常跑完，p 仍是初始值 1，
    --    thingid 从未被写入任何槽 —— 目标物品直接消失
    if JY.Base["物品数量" .. p] <= 0 then                -- ④ 而槽 1 若恰好数量<=0，还会执行一次左移压缩
        for i = p + 1, CC.MyThingNum do
            JY.Base["物品" .. i - 1] = JY.Base["物品" .. i];
            JY.Base["物品数量" .. i - 1] = JY.Base["物品数量" .. i];
        end
        JY.Base["物品" .. CC.MyThingNum] = -1;           -- 末槽置空
        JY.Base["物品数量" .. CC.MyThingNum] = 0;
    end
end                                                   -- 无 return → 返回 nil
```

所以满包时**有两条不同的坏路径**，比「一句话概括」更糟：

| 路径 | 前置条件 | 实际发生 | 损失 |
|---|---|---|---|
| **A** 什么都不做 | 200 槽全满、槽 1 数量 > 0 | 循环跑完，`p` 停在 1，`物品数量[1] > 0` 使 ④ 的 `if` 不成立 → **函数体一行都没改动背包** | 目标物品消失 |
| **B** 静默挤掉一件 | 200 槽全满、槽 1 数量 ≤ 0 | ④ 的左移压缩执行：槽 `i-1` ← 槽 `i`，末槽置 `-1`/`0` | 目标物品消失 **+ 槽 1 原有物品被覆盖丢失** |

而且 `instruct_32` **不返回值**（`return` 语句数为 0），调用方拿到的永远是 `nil`——「静默」是双重的：既没有异常、也没有可判断的返回码，上层连想提示都无法提示（`grep -rn "instruct_32(" script/ framework/` 共 184 行 = 1 处定义 + **183 处调用**，没有一处判断返回值）。

实测（`/tmp/v_loss8.lua`：只在前 200 槽里玩，避开 §6 的越界缺陷；末槽先放哨兵 `9000`，便于观察压缩）：

```bash
$ cd game && for s in pascal Dragon stronger pineapple BookCalamity mingdong; do lua /tmp/v_loss8.lua $s; done
pascal        [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
pascal        [B 槽1数量0] 目标进包=false 末槽物品=-1(应9000)   哨兵9000还在=true 原有800号还有0个
Dragon        [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
Dragon        [B 槽1数量0] 目标进包=false 末槽物品=-1(应9000)   哨兵9000还在=true 原有800号还有0个
stronger      [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
stronger      [B 槽1数量0] 目标进包=false 末槽物品=-1(应9000)   哨兵9000还在=true 原有800号还有0个
pineapple     [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
pineapple     [B 槽1数量0] 目标进包=false 末槽物品=9000(应9000) 哨兵9000还在=true 原有800号还有0个
BookCalamity  [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
BookCalamity  [B 槽1数量0] 目标进包=false 末槽物品=9000(应9000) 哨兵9000还在=true 原有800号还有0个
mingdong      [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
mingdong      [B 槽1数量0] 目标进包=false 末槽物品=9000(应9000) 哨兵9000还在=true 原有800号还有0个
```

读法（20/20 全一致）：

- **A 行**：`目标进包=false`、`末槽物品=9000` 纹丝不动、`总占用=200` → 背包**一格都没变**，目标凭空消失。
- **B 行**（pascal/Dragon/stronger）：`末槽物品=-1`（哨兵被挤到槽 199，故「哨兵还在」）、**`原有800号还有0个`** → 槽 1 的物品 `800` 被覆盖丢掉；`MyThingNum=200` 时压缩只在这 200 格内滚动，末槽被清空。
- **B 行**（pineapple/BookCalamity/mingdong）：`末槽物品=9000` 未变、`800号还有0个` → 压缩碰到了第 201 格（`nil`），但因为**只在前 200 格内测**，没有继续把 `nil` 往下传；`800` 同样已被覆盖丢失。**这 3 个 MOD 的真实生产路径会继续滚到第 456/400/330 格并撞上 §6.2 的 `bit32.band(nil)` 崩溃**（见 A.4 的输出），所以对它们来说「静默丢」只是崩溃的前半段。

| 项 | 内容 |
|---|---|
| 受影响 MOD | **20 / 20 全部**（`MyThingNum=200` 的 17 个静默丢；>200 的 3 个先丢再崩） |
| 触发条件 | 背包格全满，且拾取的物品**不在背包里**（若同 id 已在包内，走分支 ①「累加」，只加数量不占新槽，不丢） |
| 表现 | 物品消失、**无异常、无提示**；`instruct_32` 无 `return`，调用方拿到 `nil`，无法感知失败 |
| 代码位置 | `script/jymain.lua:3880-3903`；两个 `break` 都没命中时，`:3893` 的 `for` 正常结束、之后**不再写任何槽**（仅 `:3895-3902` 在槽 1 数量 ≤0 时才补一次左移压缩） |
| 修复方向 | 需要产品决策：① 加 `return false` 让上层提示「背包已满」② 保留在剧情变量里不落地 ③ 溢出到新槽。**三选一都要改 `instruct_32` 的返回值契约**（当前 183 处调用无一判断返回值，加返回值是纯增量、不破坏现有调用），影响面比 §6.1 大，故未在本文档内给原型 |
| 与 §6.1 的关系 | **独立且不会互相修复**：§6.1 是「槽数被写死 200 导致写越界」，本条是「满了之后既不上报也不落地，还会顺手挤掉一件」。修好 §6.1 只会让 `MyThingNum` 真正生效，**满包行为依旧静默丢** |
| 测试盲区 | 现有 2349 条断言里**没有一条**覆盖「背包满时拾取」的返回值语义（也没有任何测试断言 `instruct_32` 的返回值） |

---

## 7. 已知问题 MOD 的真实根因

`games.ini` 标注了 5 个问题 MOD。**构建链已全部适配，5 个都能完整启动**（`lua tests/unit/boot_one_mod.lua <slug> ...` 各 16 项 PASS），标注只是上游作者的历史遗留。

| # | MOD | `games.ini` 注解 | 真实根因（逆向结论） | 当前处理 |
|---:|---|---|---|---|
| 8 | `BookCalamity` | 好像有问题 | **Thing 段定长字段内混入 CRLF**：`物品说明` r196/r197 尾部 `0d 0a`、`物品名2` r212 尾部 `0d 0a`。MOD 作者在编辑器里按了回车，换行符被写进定长字段 | `tools/mod_encoding.lua` 折叠/剥离字段内 CR/LF |
| 9 | `zheng` | 好像不太正常 | **`ranger.idx` 描述的不是自身 `.grp`**：idx 末值 `138596`，`ranger.grp` 实际 `114242`（差 24354 字节） | 构建期 `RepairIdx`（`mod_build.lua:784`）重建偏移 |
| 10 | `loving` | 好像不太正常 | **数据本身干净**，问题是 `BEGIN_SCENE=-1` / `BEGIN_EVENT=-1`，引擎会无条件 `JY.Scene[-1]` | `mod_ini.lua` `NON_NEGATIVE_KEYS` 丢弃负值 → 回落默认场景 70 |
| 11 | `awaken` | 不确定正不正常 | 与 BookCalamity 同源，但 **r89 是内部 CRLF**（`七傷拳\r\n譜`），不是尾部 | 必须折叠字段内**所有** CR/LF，不能只剥尾部 |
| 17 | `pig3dos` | 不可能正常 | **DOS 版 Person 结构没有外号字段**。UPedit 标准布局假定 `@18` 是外号，pig3dos 在那里放的是 int16 属性值 | `mod_encoding.lua` 的 `isStringField` 要求「含高位字节或 ≥2 个可打印 ASCII」，避免把数值当字符串 |

反向验证（`BookCalamity` 的字段级证据）：

```bash
$ cd openspec/changes/archive/2026-10-28-allmods-bookcalamity-reverse
$ sed -n '14,24p' reports/reverse.md
| Thing | r196 | 物品说明(@42) | `a46abf50b6c7b0eaa5c9c3a20d0a` | `大燕傳國玉璽\r\n` |
| Thing | r197 | 物品说明(@42) | `a46abf50b6c7b0eaa5c9c3a20d0a` | `大燕皇帝世襲圖表\r\n` |
| Thing | r212 | 物品名2(@22) | `bc71b3e7b4b2b4b5a6b2a6e7` + `0d0a` | `廣陵散琴曲\r\n` |
```

`zheng` 的 idx 错位：

```bash
$ python3 -c "
import struct,os
for s in ['zheng','mingdong','pascal']:
    o=struct.unpack('<6I',open(f'reference/allmods/kys-{s}/save/ranger.idx','rb').read())
    print(s,'idx末值=',o[-1],'grp实际=',os.path.getsize(f'reference/allmods/kys-{s}/save/ranger.grp'))"
zheng idx末值= 138596 grp实际= 114242      ← 错位 24354 字节
mingdong idx末值= 223688 grp实际= 223688
pascal idx末值= 114242 grp实际= 114242
```

---

## 8. 音乐：MIDI / OGG / MP3

LÖVE 11.5 内置 `libmodplug` 能直放 MIDI，但合成质量很差（实测过零率 4749 Hz、差分/RMS 0.338，高频能量比真实音色库高 2.1 倍，主观上「刺耳、单薄」）。

因此管线是：**优先 `.ogg`（真实音色库离线渲染）→ 其次 `.mp3` → 最后 `.mid`**（`engine-love2d/lib_love.lua:615` `MUSIC_EXTS = { ".ogg", ".mp3", ".mid" }`）。

```bash
./tools/render-music.sh --list        # 查看待渲染情况
./tools/render-music.sh mingdong      # 渲染单个 MOD
./tools/render-music.sh --all         # 全部
./tools/render-music.sh --all --force # 强制重渲
```

现状：**20/20 MOD 全部已渲染，578 首 MIDI → 578 首 OGG，约 476 MB**；仅 `pineapple`、`dream` 各额外带 1 个 `.mp3`。

```bash
$ find game/mods -name '*.mid' | wc -l; find game/mods -name '*.ogg' | wc -l
578
578
$ find game/mods -name '*.mp3'
game/mods/dream/music/game25.mp3           # 源 reference/allmods/kys-dream/music/24.mp3
game/mods/pineapple/music/game38.mp3       # 源 reference/allmods/kys-pineapple/music/37.mp3
```

> **注意源文件名是 0 基、产物是 1 基**：构建期统一重命名为 `game<N+1>.<ext>`（源 `0.mid` → 产物 `game01.mid`），所以源 `24.mp3` 落地成 `game25.mp3`、源 `37.mp3` 落地成 `game38.mp3`。查产物时别按源编号找。
>
> 另：`reveal` 一个易误读点——`mid` 与 `ogg` 数量相等（578/578）**不是因为「每首 MIDI 都渲染成功」**，而是因为 `render-music.sh` 渲染后保留 `.mid` 原件、`.ogg` 走 `preservedOgg` 保护不被重建删除。`.mp3` 的 2 个是**源侧原本就有的 MP3**（非渲染产物），且它们在产物里**没有同名 `.mid`**（`dream` 是 `game25.mp3` 而 `game24.mid`/`game24.ogg` 另有其人），属独立曲目；播放侧按 `MUSIC_EXTS` 顺序 `.ogg > .mp3 > .mid` 择优。

`.ogg` 由 `preservedOgg` 逻辑保护，`mod_build.lua` 重建数据时**不会删除**已渲染的音乐。

> **构建期纯 Lua 承诺**：项目本身（`mod_build.lua` / `mod_check.lua` / 测试套件）不依赖 timidity 等外部二进制；`render-music.sh` 是可选的离线增强步骤，不跑也能玩（会回落到 libmodplug 直放 MIDI）。

---

## 9. 自检与门禁

### 9.1 常用命令

```bash
cd game

# 1) 单 MOD 适配自检（20 MOD × 布局/Person/Thing/Scene/Wugong/字符串/事件/存档）
lua tools/mod_check.lua                    # 全量
lua tools/mod_check.lua Dragon             # 单个

# 2) 单 MOD 全启动链路（独立进程，最接近真实启动）
lua tests/unit/boot_one_mod.lua BookCalamity 800 550 139 398 主角

# 3) 构建基线
lua tools/mod_build.lua --verify-pascal

# 4) 二进制格式覆盖
lua tools/format_spec.lua --all

# 5) 资源穷举审计
lua tools/mod_audit.lua --all --evidence

# 6) 全量单元测试
lua tests/test_runner.lua

# 7) 门禁（含 active_mod.txt 解析容错、ogg 保留、音频数量一致性）
bash tests/gate_run_mod.sh
```

> **跑全量测试/探针前必须 `rm -f active_mod.txt`**——残留的 `mingdong` 会让 8 条无关测试 FAIL。

### 9.2 当前基线（HEAD `951aa33` 实测）

| 检查 | 结果 |
|---|---|
| `lua tools/mod_check.lua` | **20 MOD，通过 20，失败 0** |
| `lua tools/mod_build.lua --verify-pascal` | `PASS`（2 个 `[known]` 已知偏差） |
| `lua tools/format_spec.lua --all` | `formats=14 checked=6838 gaps=0` |
| `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9285 not_in_product=1935 unclassified=0 bad_evidence=0` |
| `lua tests/test_runner.lua` | **2349 测试 / 2349 通过 / 0 失败** |
| `bash tests/gate_run_mod.sh` | `GATE_PASS` |

`mod_check.lua` 实测输出（记录数一栏可与 §2.3 交叉核对）：

```bash
$ rm -f active_mod.txt && lua tools/mod_check.lua
MOD            布局  Person Thing  Scene  Wugong 字符串 事件    存档
--------------------------------------------------------------------------------------------
BookCalamity   OK      800    550    139    398    OK        OK        OK
Dragon         OK      589    237    106    114    OK        OK        OK
...
mingdong       OK      632    367    139    220    OK        OK        OK
...
总计: 20 MOD, 通过 20, 失败 0
```

### 9.3 资源分类审计

`MOD_RESOURCE_AUDIT.md`（由 `mod_audit.lua` 生成，**勿手改**）：

| 类别 | 文件数 | 进产物 |
|---|---:|---|
| `REQUIRED` | 9185 | 是（原名） |
| `REQUIRED_CONVERTED` | 80 | 是（构建期转换） |
| `LEGACY` | 108 | 否（C 引擎/编辑器遗留） |
| `DEAD_FILE` | 2 | 否 |
| `EDITOR_DUMP` | 1222 | 否（UPedit 副产物） |
| `BUILD_INPUT` | 30 | 否（构建器消费） |
| `PLATFORM_ARTIFACT` | 12 | 否（`.dll`/`.exe`） |
| `PENDING` | 581 | 待归类 |
| **合计** | **11220** | — |

---

## 10. 已知限制汇总（诚实清单）

| # | 限制 | 影响 | 状态 |
|---:|---|---|---|
| 1 | **物品槽 200 上限** | `pineapple`/`BookCalamity`/`mingdong` 三条崩溃路径 | 已定位根因，修复原型已验证，**未合入** |
| 2 | **60/66 ini 目标零消费** | `HIRES_TEXT`/`EXP_RATE`/`MAX_LEVEL`/`MAX_HP`/`MAX_MP`/`CHINESE_FONT_SIZE`/`WALK_SPEED`… 全部不生效 | 已知差距（原版 `kys.exe` 会读，love2d 未实现） |
| 3 | **音量键零实现** | `VOLUME`/`VOLUMEWAV`（20 MOD 全有）不生效；引擎无 `setVolume` | 已知差距 |
| 4 | **无游戏内 MOD 切换 UI** | 必须改 `active_mod.txt` 后重启 | 设计如此 |
| 5 | **`MaxProList43..58` 零消费** | 16 个键（每个 MOD 都有）完全无效 | 已知差距 |
| 6 | **文档/`.md`/`.txt` 不进产物** | `build-html` 排除 `*.md`/`*.txt`，玩家拿到的东西里没有本文档 | 设计如此 |
| 7 | `zheng` 场景/武功数偏少 | idx 描述自身 grp 错位，`RepairIdx` 修偏移后记录数退化为 320/200/84/93（与 pascal 相同） | 上游数据缺陷，已容错 |
| 8 | **背包满时物品静默丢失** | 背包格全满且拾取的物品不在包内时，`instruct_32` 的两个 `break` 分支都不命中，循环空转跑完 → 物品不落地；若此时槽 1 数量 ≤0，还会执行左移压缩把**槽 1 原有物品一并挤掉**。函数**没有 `return` 语句**（返回 `nil`），既无异常也无返回码，183 处调用无一判断返回。**20 个 MOD 全部命中**（17 个静默丢，3 个 `MyThingNum>200` 先丢再撞 §6.1 崩溃）。与 §6.1 是两个独立缺陷 | 未修复（需产品决策：报错 / 不落地 / 溢出到新槽） |
| 9 | **`awaken` 有 17 个引擎永不加载的 fight 文件** | 8 个 `fightNNN..grp`（双点）+ 9 个 `fightNNN_MM.grp`，`ModData.FightFiles()` 的 `^fight\d+\.grp$` 匹配不到 → 引擎可见 220 项 vs 目录 237 个 `.grp`。**其余 19 个 MOD 两者相等**。上游数据遗留 | 记入已知，未修正（改文件名会与 `.idx` 偏移耦合，需单独验证） |
| 10 | **`RiverLake` / `mingdong` 用拼写变体 `BEGIN_SCENCE`** | `mod_ini.lua` 已登记 typo 别名，能正常映射；但若上游再改拼写则静默失效 | 已兼容 |
| 11 | **`RESOLUTIONX/Y` 刻意不映射** | `pineapple`/`dream`（`RESOLUTIONY=480`）、`mingdong`（`960×660`）的窗口尺寸不生效，固定 1024×768 | 设计如此（见 `resolution-mapping.md`） |
| 12 | **`music.sound3d` 刻意不映射** | 20/20 MOD 全有，LÖVE 无 3D 音频 | 设计如此 |

---

## 附录 A：本文用到的探针脚本

全部在 `game/` 目录下运行，**每次运行前后都要 `rm -f active_mod.txt`**（否则 `ModData` 会读到上一次的 slug）。

公共前置（4 个探针完全一致，只用真实引擎初始化链路，不 mock）：

```lua
package.path = "./?.lua;./?/init.lua;" .. package.path
require("tests.mod_boot_harness").setup()
local ModData = require("framework.mod_data")
ModData.SetActive(arg[1])
_G.EngineAPI = require("tests.engine_test")
local EB = require("framework.event_bridge")
require("framework.config")
_G.Byte = require("framework.lib_Byte")
require("engine-love2d.lib_love")
_G.lib = require("engine-love2d.engine_love2d")
pcall(function() lib.init() end)
EB.getInstance():init()
require(CONFIG.ScriptPath .. "jymain")
pcall(function() require("framework.jymain_adapter").init() end)   -- ← 这里才会 Apply ini
pcall(function() return LoadRecord(0) end)                          -- ← 这里才会读存档
```

> **顺序不能改**：`jymain_adapter.init()` 内部是 `SetGlobalConst()`（建 `Base_S` 200 槽）→ `LoadIni()`（Apply ini，缺陷就在这两步之间，见 §6.1）。在 `init()` 之前读 `CC.MyThingNum` 永远是 200。

**A.1 `v_slots3.lua` — 槽数 vs `MyThingNum`（最直观的那条）**

```lua
-- 接公共前置
local CC = rawget(_G, "CC")
local n = 0
for k in pairs(CC.Base_S) do if k:match("^物品%d+$") then n = n + 1 end end
print(string.format("%-13s MyThingNum=%-4s Base_S物品槽=%-4d 物品N=%s",
  arg[1], tostring(CC.MyThingNum), n,
  tostring(CC.Base_S["物品" .. tostring(CC.MyThingNum)])))
```

```bash
$ cd game && for s in pascal pineapple BookCalamity mingdong; do lua /tmp/v_slots3.lua $s; done
pascal        MyThingNum=200  Base_S物品槽=200  物品N=table: 0x...
pineapple     MyThingNum=456  Base_S物品槽=200  物品N=nil
BookCalamity  MyThingNum=400  Base_S物品槽=200  物品N=nil
mingdong      MyThingNum=330  Base_S物品槽=200  物品N=nil
```

**A.2 `v_read.lua` — 照抄 `item_async.lua:43-45` 的真实遍历**

```lua
-- 接公共前置
local CC = _G.CC
local ok, err = pcall(function()
    for i = 0, CC.MyThingNum - 1 do
        local id = JY.Base["物品" .. i + 1]
        if id >= 0 then break end        -- ← item_async.lua:44 原样
    end
end)
print(string.format("%-13s MyThingNum=%-4d 物品200=%-6s 物品201=%-6s 物品N=%-6s 菜单遍历 -> ok=%-5s %s",
  arg[1], CC.MyThingNum, tostring(JY.Base["物品200"]), tostring(JY.Base["物品201"]),
  tostring(JY.Base["物品" .. CC.MyThingNum]), tostring(ok), ok and "" or tostring(err)))
```

> **这个探针单独看 `pineapple` 会误判**：它 slot1 就有物品 → 第一轮 `break`，根本走不到第 201 槽。必须配 A.3 才能暴露。

**A.3 `v_empt.lua` — 先清空前 200 槽再遍历（去掉掩盖）**

```lua
-- 接公共前置
local CC = _G.CC
for i = 1, 200 do JY.Base["物品"..i] = -1; JY.Base["物品数量"..i] = 0 end
local ok, err = pcall(function()
    for i = 0, CC.MyThingNum - 1 do
        local id = JY.Base["物品" .. i + 1]
        if id >= 0 then break end
    end
end)
print(string.format("%-13s 清空200槽后遍历 -> ok=%-5s %s", arg[1], tostring(ok), ok and "" or tostring(err)))
```

```bash
$ cd game && for s in pascal pineapple BookCalamity mingdong; do lua /tmp/v_empt.lua $s; done
pascal        清空200槽后遍历 -> ok=true
pineapple     清空200槽后遍历 -> ok=false  attempt to compare number with nil
BookCalamity  清空200槽后遍历 -> ok=false  attempt to compare number with nil
mingdong      清空200槽后遍历 -> ok=false  attempt to compare number with nil
```

**A.4 `v_full2.lua` — 满包拾取会不会踩到第 201 格（暴露 §6.2 崩溃）**

```lua
-- 接公共前置
local CC = rawget(_G, "CC")
local target = 1
for i = 1, 200 do JY.Base["物品"..i] = 800+i; JY.Base["物品数量"..i] = 5 end   -- 填满前 200 槽
for i = 1, 200 do if JY.Base["物品"..i] == target then JY.Base["物品"..i] = -1 end end  -- 确保包内无 target
JY.Base["物品数量1"] = 0                    -- 临界条件：让 instruct_32 进 ④ 的左移压缩分支
local function find(id) for i = 1, 200 do if JY.Base["物品"..i] == id then return i end end end
local ok, err = pcall(function() instruct_32(target, 1) end)
print(string.format("%-13s N=%-4d 满包+槽1数量0 -> ok=%-5s 目标id=%-3s 加入后槽=%s %s",
    arg[1], CC.MyThingNum, tostring(ok), tostring(target), tostring(find(target)), ok and "" or tostring(err)))
```

```bash
$ cd game && for s in pascal Dragon stronger pineapple BookCalamity mingdong; do lua /tmp/v_full2.lua $s; done
pascal        N=200  满包+槽1数量0 -> ok=true   目标id=1   加入后槽=nil
Dragon        N=200  满包+槽1数量0 -> ok=true   目标id=1   加入后槽=nil
stronger      N=200  满包+槽1数量0 -> ok=true   目标id=1   加入后槽=nil
pineapple     N=456  满包+槽1数量0 -> ok=false  bit32.band(nil)
BookCalamity  N=400  满包+槽1数量0 -> ok=false  bit32.band(nil)
mingdong      N=330  满包+槽1数量0 -> ok=false  bit32.band(nil)
```

> **`ok=true` 但 `加入后槽=nil` 的那三个（pascal/Dragon/stronger）是另一个独立缺陷**：`jymain.lua:3880-3903` 里两个 `break` 分支都不命中时循环空转跑完，目标物品从未写入任何槽，函数又**没有 `return`**（返回 `nil`），所以 `pcall` 说 `ok` 而物品已消失。详版见 §6.7 与 A.5。

**A.5 `v_loss8.lua` — 满包拾取的两条坏路径（A：什么都不做 / B：顺手挤掉槽 1）**

```lua
-- 接公共前置
local CC = rawget(_G, "CC")
local N = math.min(CC.MyThingNum, 200)          -- 只玩前 200 槽，避开 §6 的越界缺陷
local function occ(id) local n = 0 for i = 1, N do if JY.Base["物品"..i] == id then n = n + 1 end end return n end
local target
for id = 1, 60 do if JY.Thing[id] and occ(id) == 0 then target = id break end end   -- 包内没有的物品

local function fill(q1)
    for i = 1, N do JY.Base["物品"..i] = 800 + i; JY.Base["物品数量"..i] = 5 end
    JY.Base["物品"..N] = 9000; JY.Base["物品数量"..N] = 7      -- 末槽哨兵，便于看压缩
    JY.Base["物品数量1"] = q1
end

fill(5)                                          -- 情形 A：槽 1 数量 > 0
pcall(function() instruct_32(target, 1) end)
print(string.format("%-13s [A 槽1数量5] 目标进包=%s 末槽物品=%s 末槽数量=%s 总占用=%d",
    arg[1], tostring(occ(target) > 0), tostring(JY.Base["物品"..N]),
    tostring(JY.Base["物品数量"..N]), N))

fill(0)                                          -- 情形 B：槽 1 数量 = 0
pcall(function() instruct_32(target, 1) end)
print(string.format("%-13s [B 槽1数量0] 目标进包=%s 末槽物品=%s 哨兵9000还在=%s 原有800号还有%d个",
    arg[1], tostring(occ(target) > 0), tostring(JY.Base["物品"..N]),
    tostring(occ(9000) > 0), occ(800)))
```

```bash
$ cd game && for s in pascal Dragon stronger pineapple BookCalamity mingdong; do lua /tmp/v_loss8.lua $s; done
pascal        [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
pascal        [B 槽1数量0] 目标进包=false 末槽物品=-1(应9000)   哨兵9000还在=true 原有800号还有0个
Dragon        [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
Dragon        [B 槽1数量0] 目标进包=false 末槽物品=-1(应9000)   哨兵9000还在=true 原有800号还有0个
stronger      [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
stronger      [B 槽1数量0] 目标进包=false 末槽物品=-1(应9000)   哨兵9000还在=true 原有800号还有0个
pineapple     [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
pineapple     [B 槽1数量0] 目标进包=false 末槽物品=9000(应9000) 哨兵9000还在=true 原有800号还有0个
BookCalamity  [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
BookCalamity  [B 槽1数量0] 目标进包=false 末槽物品=9000(应9000) 哨兵9000还在=true 原有800号还有0个
mingdong      [A 槽1数量5] 目标进包=false 末槽物品=9000(应9000) 末槽数量=7 总占用=200
mingdong      [B 槽1数量0] 目标进包=false 末槽物品=9000(应9000) 哨兵9000还在=true 原有800号还有0个
```

> **为什么必须用「末槽哨兵 + `occ(800)`」而不是只回查目标 id**：早期版本的探针（`/tmp/v_loss3.lua`）只打印「目标进包了没有」，20 个 MOD 输出全是 `目标进包=false`，看起来像一条整齐的结论，**但完全看不出路径 A 和路径 B 的差别，也看不出槽 1 的物品被挤掉了**。加上哨兵和 `occ(800)` 之后才暴露出「A 行背包一格没动 / B 行末槽被清空且丢了 800 号」这两种完全不同的损失形态。这是「断言必须有鉴别力」的又一次实例。
>
> 与 A.4 的区别：A.4 不设目标物品，专测「压缩会不会踩到第 201 格而崩」（>200 槽的 3 个 MOD 会崩）；A.5 才是「物品有没有真的进包」。**两条测的是同一函数的不同侧面，都要跑。**

**A.6 `v_final_stats.lua` — ini 目标消费点统计**

完整脚本在 `/tmp/v_final_stats.lua`（核心：对 `script/ framework/ engine-love2d/ engine-mud/` 逐行扫描，排除 `mod_ini.lua`/`mod_data.lua` 自身、定义行与注释行，统计每个映射目标的**读取**点）。产出即 §5.2 的「6 个有消费 / 60 个零消费」分界。

---

## 附录 B：相关文档

| 文档 | 内容 |
|---|---|
| [`GAME_MODIFICATION_GUIDE.md`](GAME_MODIFICATION_GUIDE.md) | 修改游戏要动哪些文件 |
| [`MOD_RESOURCE_AUDIT.md`](MOD_RESOURCE_AUDIT.md) | 11220 个源文件的逐文件归类（自动生成） |
| [`DATA_FILES.md`](DATA_FILES.md) | `game/data/` 数据格式说明 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 事件驱动架构 |
| `openspec/epics/2026-10-allmods-compat/epic.md` | 本适配工作的 epic（15 个 slice） |
| `openspec/changes/allmods-ini-parser/reports/resolution-mapping.md` | 为什么 `RESOLUTIONX/Y` 不映射 |
| `openspec/changes/archive/2026-10-28-allmods-*-reverse/reports/reverse.md` | 5 个问题 MOD 的逆向分析原文 |
