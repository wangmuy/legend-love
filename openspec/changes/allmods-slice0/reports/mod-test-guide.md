# 各 MOD 适配状态与手动测试指南

> 目的：回答「各个 MOD 是否都适配了」以及「每个 MOD 怎么手动测试，才能测到 MOD 独有的东西」。
>
> 生成依据：`game/tools/mod_check.lua`（自动自检）+ 真实数据实测（`reference/allmods/kys-*`、`game/mods/*`）。
> 复现命令一律在 `game/` 目录下执行。

---

## 一、总览：20 个 MOD 全部适配通过

自动自检命令：

```bash
cd game && lua tools/mod_check.lua
```

最近一次结果：**20 MOD，通过 20，失败 0**。

| MOD | 布局 | Person | Thing | Scene | Wugong | 字符串 | 事件 | 存档 |
|---|---|---|---|---|---|---|---|---|
| awaken | OK | 720 | 237 | 153 | 163 | OK | OK | OK |
| BookCalamity | OK | 800 | 550 | 139 | 398 | OK | OK | OK |
| books | OK | 382 | 200 | 84 | 100 | OK | OK | OK |
| Dragon | OK | 589 | 237 | 106 | 114 | OK | OK | OK |
| dream | OK | 409 | 192 | 122 | 102 | OK | OK | OK |
| GodsDevils | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| HeavenSword | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| lostbook | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| loving | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| lyff | OK | 326 | 200 | 84 | 93 | OK | OK | OK |
| mingdong | OK | 632 | 367 | 139 | 220 | OK | OK | OK |
| pascal | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| pig | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| pig3dos | OK | 607 | 242 | 133 | 202 | OK | OK | OK |
| pineapple | OK | 720 | 344 | 118 | 174 | OK | OK | OK |
| ptt | OK | 385 | 214 | 90 | 108 | OK | OK | OK |
| RiverLake | OK | 325 | 249 | 84 | 96 | OK | OK | OK |
| stronger | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| SweeOan | OK | 320 | 200 | 84 | 93 | OK | OK | OK |
| zheng | OK | 358 | 201 | 94 | 216 | OK | OK | OK |

「布局 / 字符串 / 事件 / 存档」四项含义：

| 检查项 | 含义 | 判据 |
|---|---|---|
| 布局 | MOD 记录尺寸（`182/190/52/136`）与段偏移正确 | 各段字节数能被 MOD 记录尺寸整除，记录数与旁路表一致 |
| 字符串 | Big5→UTF-8 转换正确、无 hint 泄漏 | 抽样字段均为合法 UTF-8，且不残留 `P0000` 之类 hint || 事件 | 起始事件脚本可从 MOD 目录加载并执行 | `EventExecutor.startEvent(BEGIN_EVENT)` 在协程调度器内跑完 |
| 存档 | 存档写入 MOD 自身 `mods/<slug>/save/`，覆盖表往返正确 | 改名→`rN.ovr`→重读得到改名值；`game/save/` 不被写 |

### 基线未受影响（原版）

```bash
cd game && lua tools/mod_build.lua --verify-pascal   # → PASS（结构零差异）
cd game && rm -f active_mod.txt && lua tests/test_runner.lua   # → 285/285 全绿
```

未激活 MOD 时实测：布局 `202/260/62/146`（原版值）、记录数 `320/200/84/93`、
`Person[0].姓名=徐小俠`、`Scene[0].名称=胡斐居`、`ModData.Active()=nil`。

---

## 二、5 个 MOD 在 `games.ini` 中被标注「有问题」

`game/tools/mod_build.lua --all` 会输出：

```
all: 20 mods, 0 build failures, 5 annotated-problematic
```

这 5 个与 `reference/allmods/games.ini` 的标注一一对应：

| MOD | games.ini 标注 | 实测结论 |
|---|---|---|
| BookCalamity | 天书劫（好像有问题） | 构建/加载/事件/存档均 OK；标注来自原作者，非本流水线引入 |
| zheng | 魏征传奇（好像不太正常） | **源数据记录布局非标准**（见下） |
| loving | 问情篇（好像不太正常） | `BEGIN_SCENE=-1`（源 ini 指定无效场景），引擎容忍 |
| awaken | 真龙苏醒（不确定正不正常） | 构建/加载/事件/存档均 OK |
| pig3dos | 金庸水浒传dos版（不可能正常） | `BEGIN_SCENE=0`，构建/加载/事件/存档均 OK |

### `zheng` 的源数据异常（证据）

对全部 20 个 MOD 的 Thing 段前 50 字节做 Big5 高位字节分布探测：

- **19 个 MOD** 的 Thing 字符串位于偏移 **2 / 22 / 42**（标准 UPedit 布局）。
- **`zheng`** 的 Thing 字符串位于偏移 **0-3 / 10-13** —— 完全不同的记录布局。
- `zheng` 的 Scene 段前 22 字节**没有任何 Big5 数据**，即场景名不在标准位置。

因此 `zheng` 的 Thing/Scene 字符串提取会出现乱码，这是**源 MOD 自身的记录布局与 UPedit 标准不符**，
与 `games.ini` 的「好像不太正常」标注一致。Person 段（布局标准）提取正常。

> 说明：流水线按 `UPedit.ini` 的 `[R_Modify]` 权威布局处理，`zheng` 的异常属于源数据问题，
> 已在 `--all` 汇总中标注，不会静默污染其他 MOD。

### 已修复：CP950 扩展码位缺失（影响 14 个 MOD）

**现象**：`ranger.grp` 字符串字段出现 `�`（U+FFFD），14/20 MOD 共 87 个字段。
典型例子：mingdong 的 `恒山掌門` 首字变 `�`。

**根因**：`game/tools/mod_big5_trad.lua` 由 plain big5 生成，缺少 **CP950 扩展 42 个码位**
（`f9xx` 段 + `a3e1`）。其中 `0xf9da` = `恒`（Windows CP950 环境下 MOD 编辑器会产出）。

**修复**：向表追加 42 个码位（13710 → 13752）。修复后 19/20 MOD 的 U+FFFD 归零；
仅 `zheng` 残留 15 个（源布局损坏，与上节同一原因）。

> talk（对话）提取**不受影响**（全部 MOD 的 `talk.grp` 中 f9xx 出现 0 次）。
> 详见 `openspec/changes/allmods-encoding-convert/reports/encoding-reverse.md` 附录。

### 手动核对字符串质量（可选）

```bash
cd game
# 统计每个 MOD 旁路表中的 U+FFFD 数量（应全部为 0，除 zheng）
for m in $(ls mods); do
  n=$(python3 -c "
import sys
c=0
for line in open('mods/$m/data/ranger.str', encoding='utf-8'):
    if line.startswith('#'): continue
    p=line.rstrip().split(',',4)
    if len(p)<5: continue
    if '\ufffd' in p[4]: c+=1
print(c)")
  printf '  %-14s U+FFFD=%s\n' "$m" "$n"
done
```

---

## 三、每个 MOD 的独有内容 & 手动测试路径

### 3.1 通用手动测试方法

> **推荐入口：`tools/run-mod.sh`** —— 这是手动测试 MOD 的**唯一必需工具**。
> 它会自动检测 love、按需构建 MOD 数据包、写入 `game/active_mod.txt`、启动游戏。
> 不需要任何其它脚本。

```bash
# 在仓库根目录执行

# 0) 查看可用 MOD 列表（含中文名）
./tools/run-mod.sh --list

# 1) 启动指定 MOD（交互式选择）
./tools/run-mod.sh

# 2) 直接启动指定 MOD（接受 mingdong 或 kys-mingdong）
./tools/run-mod.sh mingdong

# 3) 不激活任何 MOD（原版，删除 active_mod.txt）
./tools/run-mod.sh --vanilla

# 4) 跳过自动构建检查（数据包已存在时更快）
./tools/run-mod.sh --no-build mingdong

# 5) 自定义 love 路径
LOVE=/path/to/love ./tools/run-mod.sh mingdong
```

`run-mod.sh` 支持的参数：

| 参数 | 作用 |
|---|---|
| （无） | 交互式选择 MOD |
| `<slug>` | 直接启动指定 MOD（`kys-` 前缀可省） |
| `--list` / `-l` | 只列出 MOD，不启动 |
| `--vanilla` / `-v` | 不激活 MOD（原版） |
| `--no-build` | 跳过自动构建检查 |
| `--help` / `-h` | 显示用法 |

环境变量：`LOVE`（love 可执行文件路径）、`NO_BUILD=1`（等同 `--no-build`）。

**无图形界面时的替代方案**（服务器 / CI）：

```bash
cd game
lua tools/mod_check.lua              # 全部 20 MOD 自检
lua tools/mod_check.lua mingdong      # 单个 MOD 自检
MOD_SLUG=mingdong lua tools/mod_check_one.lua   # 单 MOD 详细输出
```

**「测到 MOD 独有内容」的 4 个观察点**（按可靠性排序）：

1. **主角姓名 + 起始场景名** —— 每个 MOD 都不同，进入游戏第一屏即可看到（数据旁路表解码的直接体现）。
2. **起始剧情事件** —— 每个 MOD 的 `BEGIN_EVENT` 会播放自己的开场剧情/对话（MOD 自带事件脚本）。
3. **MOD 自带头像/大地图** —— 所有 MOD 都提供自己的 `hdgrp.grp`（头像与其它 MOD 不同）；
   大地图 `mmap.grp` 在 15/20 个 MOD 中与原版不同（pascal、stronger、SweeOan、GodsDevils、HeavenSword
   这 5 个 MOD 的大地图沿用原版）。
4. **MOD 独有事件数** —— MOD 事件脚本数超过原版 1018 的部分即 MOD 新增剧情。

### 3.2 各 MOD 独有内容速查表

| MOD | 主角 | 起始场景（id） | 起始事件 | 独有事件数 | 独有物品示例 |
|---|---|---|---|---|---|
| pascal | 小蝦米 | 小蝦米居 (70) | 691 | 0（数据型 MOD） | 康倍特 |
| mingdong | 小蝦米 | 小蝦米居 (70) | 691 | 636 | 大可樂 |
| Dragon | 資 | 小村 (70) | 691 | 69 | 小還丹 |
| RiverLake | 茲 | 茲居 (70) | 691 | 214 | 半夏 |
| ptt | 鄉民 | 阿兩居 (70) | 691 | 211 | 千面人蠻牛 |
| pineapple | 蘿卜大 | 基地 (33) | 600 | 50 | 小續命丹 |
| dream | 隨小破 | 主角居 (121) | 300 | 3551 | 銀兩 |
| pig | 小小豬 | 群俠之家 (70) | 691 | 270 | 火云掌譜 |
| books | 古天奇 | 宜興 (70) | 691 | 0（数据型 MOD） | 腐骨穿心膏 |
| BookCalamity | 主角 | 武林之家 (70) | 691 | 683 | 小還丹 |
| zheng | 小蝦米 | (70，名称空) | 691 | 101 | 銀兩 |
| loving | 莫言 | -1（无效，源标注异常） | -1 | 246 | 康倍特 |
| awaken | 北辰月 | 小村 (70) | 691 | 209 | 小還丹 |
| SweeOan | 王小石 | 愁石齋 (70) | 691 | 0（数据型 MOD） | 康倍特 |
| HeavenSword | 楊千葉 | 主角的家 (70) | 691 | 48 | 康倍特 |
| lostbook | 金迷 | 金迷居 (70) | 691 | 53 | 康倍特 |
| GodsDevils | 蝦米 | 蝦米居 (70) | 691 | 105 | 康倍特 |
| lyff | AAA | AAA居 (70) | 691 | 340 | 左右互搏之術Ⅱ |
| pig3dos | 主角 | 小村 (0) | 301 | 89 | 銀兩 |
| stronger | 韋大寶 | 家 (70) | 691 | 0（数据型 MOD） | 碧蚕毒蠱 |

> **数据型 MOD**（pascal / books / SweeOan / stronger）：**独有事件数 = 0**，即它们不新增事件脚本，
> 而是复用原版事件 + 替换数据（人物/物品/场景/武功/地图/对话）。测试这类 MOD 应关注
> **主角、起始场景、物品名、对话文本** 是否为其独有版本，而非新剧情。

### 3.3 按 MOD 分类的推荐测试路径

**A. 剧情型 MOD（独有事件多）** —— dream(3551)、BookCalamity(683)、mingdong(636)、lyff(340)、pig(270)、loving(246)、RiverLake(214)、ptt(211)、awaken(209)

1. `./tools/run-mod.sh <slug>` 启动。
2. 观察开场剧情（`BEGIN_EVENT` 事件），确认对话是 MOD 独有文本。
3. 进入起始场景，与 NPC 对话，验证 MOD 新增剧情线。
4. 打开人物状态/物品界面，确认 MOD 独有角色与物品。

**B. 数据型 MOD（独有事件 0）** —— pascal、books、SweeOan、stronger

1. `./tools/run-mod.sh <slug>` 启动。
2. 第一屏确认**主角姓名与起始场景名**是 MOD 版本（这是最直接的独有内容证据）。
3. 查看物品栏/人物列表，确认 MOD 替换的数据。
4. 与 NPC 对话，确认对话表（`oldtalk.grp`）为 MOD 版本。

**C. 标注异常 MOD** —— zheng、loving、pig3dos、BookCalamity、awaken

1. 优先用 `lua tools/mod_check.lua <slug>` 确认基础链路是否 OK。
2. `loving`：起始场景为 `-1`，引擎会容忍；若画面异常属源数据问题。
3. `zheng`：Thing/Scene 文本可能乱码（源布局非标准），Person 相关功能正常。
4. `pig3dos`：起始场景 `0`（小村），事件 `301`。

---

## 四、MOD 独有资源清单（各 MOD 都提供的覆盖文件）

每个 MOD 产物 `game/mods/<slug>/` 都包含以下**自己的**资源（与原版不同）：

| 资源 | 路径 | 说明 |
|---|---|---|
| 基础数据 | `data/ranger.grp` / `.idx` | MOD 记录布局（182/190/52/136） |
| 字符串旁路表 | `data/ranger.str` | Big5→UTF-8 后的真实字符串 |
| 头像 | `data/hdgrp.grp` / `.idx` | MOD 独有头像图（20/20 MOD 均与原版不同） |
| 大地图 | `data/mmap.grp` / `.idx` | MOD 独有世界地图（15/20 MOD 与原版不同；pascal/stronger/SweeOan/GodsDevils/HeavenSword 沿用原版） |
| 战斗图 | `data/fight*.grp` / `.idx` | MOD 独有战斗动画 |
| 战场 | `data/warfld.grp`、`war.sta` | MOD 独有战场与战斗数据 |
| 对话 | `script/oldtalk.grp` / `.idx` | MOD 独有对话（UTF-8） |
| 事件 | `script/oldevent/oldevent_*.lua` | MOD 独有事件脚本 |
| MOD 配置 | `data/kysmod.ini` | MOD 常量（分辨率**不**参与映射，见下） |

> 物品图（`thing.grp`）**没有任何 MOD 提供**，一律回退到原版 `data/thing.grp` —— 这是设计如此。

---

## 五、关于分辨率（对应问题 1）

- `kysmod.ini` 的 `RESOLUTIONX/Y` **不再映射**到 `CONFIG.Width/Height`。
- 原版 C 引擎从不读取 `kysmod.ini`，窗口尺寸只来自 `conf.lua`/`config.lua` 的 `1024x768`。
- 实测：pascal / mingdong / dream / pineapple 等所有 MOD 启动分辨率均为 **1024×768**。
- 详见 `openspec/changes/allmods-ini-parser/reports/resolution-mapping.md`。

---

## 六、一键复核命令汇总

```bash
cd game

# 1) 单元/集成测试（285 项）
rm -f active_mod.txt && lua tests/test_runner.lua

# 2) 全 MOD 适配自检（20 项）
lua tools/mod_check.lua

# 3) 原版基线零回归
lua tools/mod_build.lua --verify-pascal

# 4) 全 MOD 构建汇总
lua tools/mod_build.lua --all

# 5) 图形界面手动测试
./tools/run-mod.sh --list
./tools/run-mod.sh mingdong
```
