#!/bin/sh
# 引擎契约门禁（change: port-contract-completeness Task 11）
#
# 守的坑（全部有实测依据）：
#   [A] framework 里出现 lib.* 引擎调用 → 该函数没有契约，换引擎时靠猜
#   [B] framework 里出现 love.* 直接调用 → 绑死 LÖVE
#   [C] framework 里 require engine-*    → 绑死具体引擎
#   [D] 引擎里出现 RLE 解码逻辑          → 违反 ADR-PORT-013（解码应住 framework）
#   [E] 契约函数在某个引擎缺失          → 运行到那里才崩
#   [F] framework 里调用 script 定义的全局 → 层次倒置（Task 2 的目标）
#
# 用法: sh game/tests/gate_engine_contract.sh
#       日志: game/mods/_audit/gate_engine_contract.log
cd "$(dirname "$0")/../.." || exit 1
LOG=game/mods/_audit/gate_engine_contract.log
mkdir -p game/mods/_audit
: > "$LOG"
fail=0

log() { echo "$*" | tee -a "$LOG"; }

# **必须清 GREP_OPTIONS**：本机它含 `--exclude=*.git*`（会让 grep dotfile
# 永不命中），更坑的是它**覆盖 `--include`** —— 实测 `grep -r --include='*.lua'`
# 在 GREP_OPTIONS 非空时会把 `.js` 也搜进来（STEP I 因此误报过一次）。
# 清空后 `--include` 才生效。
GREP_OPTIONS=
export GREP_OPTIONS

# ---------------------------------------- A. framework 无 lib.* 引擎调用
log "=== STEP: A. framework 零 lib.* 绕过 ==="
# **历史**：async_globals.lua 曾经是主动 patch lib.Delay 的地方（3 处）。
# port-compat-layer-removal Task 4 之后补丁点已改到 `EngineAPI.time.sleep`，
# 那 3 处不再存在。保留 `-v async_globals` 只是为了给未来可能的引擎侧特例留口子；
# 若它长期为空，下次清理可直接删掉这条排除。
bad_a=$(grep -rn 'lib\.[A-Za-z]' game/framework/*.lua 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*--' \
        | grep -v 'framework/async_globals.lua' \
        | wc -l | tr -dc '0-9')
[ -n "$bad_a" ] || bad_a=0
if [ "$bad_a" -eq 0 ]; then
    log "  [PASS] framework/ 无 lib.* 引擎调用"
else
    log "  [FAIL] framework/ 有 $bad_a 处 lib.* 调用："
    grep -rn 'lib\.[A-Za-z]' game/framework/*.lua 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*--' | grep -v async_globals | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------------------- B. framework 无 love.* 直接调用
log "=== STEP: B. framework 零 love.* 直接调用 ==="
bad_b=$(grep -rn 'love\.' game/framework/*.lua 2>/dev/null \
        | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_b" ] || bad_b=0
if [ "$bad_b" -eq 0 ]; then
    log "  [PASS] framework/ 无 love.* 直接调用"
else
    log "  [FAIL] framework/ 有 $bad_b 处 love.*："
    grep -rn 'love\.' game/framework/*.lua | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------------------- C. framework 无 require engine-*
log "=== STEP: C. framework 零 require engine-* ==="
# **排除注释行**：注释里写「不 require("engine-*")」是说明文字，不是违规。
# （实测踩过：map_render.lua 的负约束注释触发了这条判据。）
bad_c=$(grep -rn 'require("engine' game/framework/*.lua 2>/dev/null        | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_c" ] || bad_c=0
if [ "$bad_c" -eq 0 ]; then
    log "  [PASS] framework/ 无 require engine-*"
else
    log "  [FAIL] framework/ 有 $bad_c 处 require engine-*"
    fail=$((fail + 1))
fi

# --------------------- D. 引擎里不得有 RLE 解码逻辑（ADR-PORT-013）
log "=== STEP: D. 引擎零 RLE 解码逻辑 ==="
# 判据：引擎实现里不应出现调色板逐像素解码的关键特征。
#
# **4 引擎全部纳入（含 engine-love2d）**：
#   port-legacy-picture-removal（2026-11-22）删掉了 lib_love 的 425 行旧贴图
#   子系统（含 LoadPic 的 119 行 RLE 解码 + picFileCache 链），因此原先
#   「engine-love2d 豁免」与「LoadPic 仍存在」两段说明都不再成立，已删除。
bad_d=$(grep -rn 'palletteIdx\|paletteIdx\|color32Pallette' \
        game/engine-love2d/lib_love.lua \
        game/engine-mud/engine_mud.lua \
        game/engine-web/engine_web.lua game/tests/engine_test.lua 2>/dev/null \
        | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_d" ] || bad_d=0
if [ "$bad_d" -eq 0 ]; then
    log "  [PASS] LÖVE/MUD/Web/Test 四引擎无 RLE 解码逻辑（都应住 framework/sprite_decoder.lua）"
else
    log "  [FAIL] 引擎里出现 RLE 解码特征 $bad_d 处（违反 ADR-PORT-013）"
    fail=$((fail + 1))
fi

# ---------------------------------------- D3. script/ 零 lib.Delay（含 fallback）
log "=== STEP: D3. script/ 零 lib.Delay（阻塞主线程）==="
# 判据：script/ 里 **一处** `lib.Delay(` 都不允许。
#
# 为什么比原来更严（port-compat-layer-removal Task 4）：
#   原来允许 `WaitFrame` 的 fallback 写 `function(m) lib.Delay(m) end`。
#   但 `_G.lib` 与 `EngineAPI` 是同一张表 → 事件期间 async_globals 把
#   `lib.Delay` 换成协程版后，fallback 拿到的**不是阻塞退路**，协程版内部
#   又回落 `EngineAPI.time.sleep` → 阻塞。两个补丁互相抵消。
#   现在 fallback 直接绑定 `EngineAPI.time.sleep`（契约），所以白名单归零。
#
# **用 awk 不用 grep -E**：grep -E 里 `\(` 的转义会被吃掉（同类坑已踩过一次，
# 见 gate_battle_extensibility.sh STEP J 的注释）。
bad_d3=$(awk '
    /lib\.Delay[[:space:]]*\(/ {
        # 跳过注释行
        if (match($0, /^[[:space:]]*--/)) next
        print FILENAME ":" FNR ": " $0
    }
' game/script/*.lua game/script/battle/*.lua game/script/newevent/*.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$bad_d3" ] || bad_d3=0
if [ "$bad_d3" -eq 0 ]; then
    log "  [PASS] script/ 零 lib.Delay（fallback 已绑定 EngineAPI.time.sleep）"
else
    log "  [FAIL] script/ 仍有 $bad_d3 处 lib.Delay（会阻塞主线程）："
    awk '
        /lib\.Delay[[:space:]]*\(/ {
            if (match($0, /^[[:space:]]*--/)) next
            print FILENAME ":" FNR ": " $0
        }
    ' game/script/*.lua game/script/battle/*.lua game/script/newevent/*.lua 2>/dev/null       | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# --------------------- D4. 延迟 require 的 framework 模块零全局函数
log "=== STEP: D4. 延迟 require 的 framework 模块零全局函数 ==="
# **只查「运行时才 require 的模块」**，不是全部 framework。
#
# 为什么必须区分：
#   LÖVE 的严格 `_G` metatable 在 `JYMainAdapter.init`（jymain_adapter.lua:172）
#   才装上。**init 之前**加载的模块（event_executor / game_states 等，main.lua
#   顶部 require）写全局函数不受影响 —— 那 33 处既有代码就是这么活的。
#
#   但**draw 时才 require** 的模块（map_render 由 map.drawMain/drawScene/drawBattle
#   延迟加载）在严格 _G 生效之后才执行 → 写全局会抛：
#     "attempt read write to undeclared variable drawTile"
#   而 `pcall(require)` 会把错误吞掉 → 静默回退旧实现 → **地图全黑且无日志**。
#
#   实测踩过：map_render.lua 的两个 helper 写成全局，摘掉双轨后战斗地图全黑，
#   排查很久才发现是 require 失败被 pcall 吞了。
LATE_MODULES="game/framework/map_render.lua"
bad_d4=$(awk '
    /^function [A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/ { print FILENAME ":" FNR ": " $0; next }
    /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*function/ { print FILENAME ":" FNR ": " $0 }
' $LATE_MODULES 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$bad_d4" ] || bad_d4=0
if [ "$bad_d4" -eq 0 ]; then
    log "  [PASS] 延迟 require 的模块零全局函数定义（全部 local）"
else
    log "  [FAIL] 延迟 require 的模块有 $bad_d4 处全局函数定义（严格 _G 会拒绝）："
    awk '
        /^function [A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/ { print FILENAME ":" FNR ": " $0; next }
        /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*function/ { print FILENAME ":" FNR ": " $0 }
    ' $LATE_MODULES 2>/dev/null | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# --------------------- D6. script/ 零 lib.*（无白名单）
log "=== STEP: D6. script/ 零 lib.* ==="
# 判据：script/ 代码里 `lib.xxx(` **一处都不允许**。
#
# 原来允许 `WaitFrame` 的 fallback 写 `lib.Delay`；Task 4 把 fallback 改成
# 绑定 `EngineAPI.time.sleep` 后，白名单归零（原因见 D3 的注释）。
#
# 为什么：`lib.*` 只在 LÖVE 存在（MUD/Web 只实现 EngineAPI，实测 MUD 缺 30/35
# 个常用 lib.* 函数）→ 只要 script 还在用 lib.*，「换引擎只需写 engine-xxx」
# 就不成立。
#
# **用 awk 不用 grep -E**：同类转义坑已踩过两次（见 D3 与 battle gate STEP J）。
bad_d6=$(awk '
    /lib\.[A-Za-z][A-Za-z0-9_]*[[:space:]]*\(/ {
        if (match($0, /^[[:space:]]*--/)) next
        print FILENAME ":" FNR ": " $0
    }
' game/script/*.lua game/script/battle/*.lua game/script/newevent/*.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$bad_d6" ] || bad_d6=0
if [ "$bad_d6" -eq 0 ]; then
    log "  [PASS] script/ 零 lib.*（全部走 EngineAPI）"
else
    log "  [FAIL] script/ 仍有 $bad_d6 处 lib.* 调用："
    awk '
        /lib\.[A-Za-z][A-Za-z0-9_]*[[:space:]]*\(/ {
            if (match($0, /^[[:space:]]*--/)) next
            print FILENAME ":" FNR ": " $0
        }
    ' game/script/*.lua game/script/battle/*.lua game/script/newevent/*.lua 2>/dev/null       | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# --------------------- D5. map_render 零 love.* 且零 picFileCache
log "=== STEP: D5. map_render 零引擎细节 ==="
# 判据两项：
#   ① 不调 love.*（否则等于换个地方写引擎代码）
#   ② 不碰 PicLoadCache / picFileCache（否则换引擎仍要重写 RLE 解码 —— 那是 C 的目标）
bad_d5a=$(grep -rnE '[^_A-Za-z]love\.' game/framework/map_render.lua 2>/dev/null           | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_d5a" ] || bad_d5a=0
if [ "$bad_d5a" -eq 0 ]; then
    log "  [PASS] map_render.lua 零 love.* 调用"
else
    log "  [FAIL] map_render.lua 有 $bad_d5a 处 love.* 调用"
    grep -rnE '[^_A-Za-z]love\.' game/framework/map_render.lua 2>/dev/null       | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

bad_d5b=$(grep -rnE 'PicLoadCache|picFileCache' game/framework/map_render.lua 2>/dev/null           | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_d5b" ] || bad_d5b=0
if [ "$bad_d5b" -eq 0 ]; then
    log "  [PASS] map_render.lua 零 picFileCache 依赖（契约真的透明了）"
else
    log "  [FAIL] map_render.lua 有 $bad_d5b 处 picFileCache / PicLoadCache 引用"
    grep -rnE 'PicLoadCache|picFileCache' game/framework/map_render.lua 2>/dev/null       | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------------------- E. sprite_decoder 零引擎依赖
# ---------------------------------------- D2. script 层零 lib.Pic*
log "=== STEP: D2. script/ 零 lib.Pic* ==="
# 判据：排除注释行；命中即 FAIL。
# 为什么是硬断言：script 层的 lib.Pic* 是「引擎可见 .idx/.grp」的最后一条通道。
# 它们存在时，换引擎必须再造一份 lib_love.lua 的 PicLoadFile/PicGetXY/PicLoadCache。
# 已全部迁到 SpriteAtlas（port-sprite-native-migration），所以本步可以变硬。
SCRIPT_PIC_FILES="game/script/jymain.lua game/script/battle/*.lua"
bad_d2=$(grep -rnE "lib\.Pic[A-Za-z]*\(" $SCRIPT_PIC_FILES 2>/dev/null \
         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_d2" ] || bad_d2=0
if [ "$bad_d2" -eq 0 ]; then
    log "  [PASS] script/ 零 lib.Pic*（贴图全部走 SpriteAtlas）"
else
    log "  [FAIL] script/ 仍有 $bad_d2 处 lib.Pic* 调用："
    grep -rnE "lib\.Pic[A-Za-z]*\(" $SCRIPT_PIC_FILES 2>/dev/null \
      | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

log "=== STEP: E. sprite_decoder 零引擎依赖 ==="
if [ -f game/framework/sprite_decoder.lua ]; then
    # 判据：love. 前面不能是下划线或字母（排除 lib_love.lua 的提及）
    bad_e=$(grep -rEn '[^_A-Za-z]love' game/framework/sprite_decoder.lua 2>/dev/null \
            | grep -vE '(^|:)[0-9]+:[[:space:]]*--' \
            | grep -c 'love[[:space:]]*\.' | tr -dc '0-9')
    if [ "$bad_e" -eq 0 ]; then
        log "  [PASS] sprite_decoder.lua 代码行无 love.* 调用"
    else
        log "  [FAIL] sprite_decoder.lua 有 $bad_e 处 love.*"
        fail=$((fail + 1))
    fi
    bad_e2=$(grep -c 'require("engine' game/framework/sprite_decoder.lua 2>/dev/null | tr -dc '0-9')
    [ -n "$bad_e2" ] || bad_e2=0
    if [ "$bad_e2" -eq 0 ]; then
        log "  [PASS] sprite_decoder.lua 无 require engine-*"
    else
        log "  [FAIL] sprite_decoder.lua 有 require engine-*"
        fail=$((fail + 1))
    fi
else
    log "  [FAIL] 缺 framework/sprite_decoder.lua"
    fail=$((fail + 1))
fi

# ---------------------------- F. framework 不调 script 定义的全局
log "=== STEP: F. framework 不调 script 全局 ==="
# 判据（用 grep -P 的 lookbehind，实测可用）：
#   ① 不是注释行
#   ② 不是函数定义行
#   ③ 调用前不能是 . 或 : —— 排除 framework 模块自调用 X.ShowMenu 形式
#
# 为什么必须用 lookbehind：`local _z = Cls()` 这种形态里 Cls 前面是空格，
# 用「前面不能是某些字符」的黑名单必然漏（实测漏判过）。
script_globals='DrawString|DrawBox|DrawStrBox|DrawStrBoxYesNo|DrawStrBoxWaitKey|Cls|ShowScreen|ShowMenu|ShowMenu2|WaitKey|TalkEx|GetMyPic|AddMyCurrentPic|SceneCanPass|PlayMIDI|PlayMPEG|FillColor|DrawRect'
F_CHECK=$(grep -rPn "(?<![.:])\b($script_globals)\(" game/framework/*.lua 2>/dev/null \
      | grep -vP ':(?!.*\bCls\b)[0-9]+:\s*(local )?function ' \
      | grep -vP '(^|:)[0-9]+:\s*--' \
      | grep -vP '(?<![.:])function ' || true)
n_f=$(printf '%s' "$F_CHECK" | grep -c . || true)
[ -n "$n_f" ] || n_f=0
if [ "$n_f" -eq 0 ]; then
    log "  [PASS] framework 零 script 全局调用（8 组目标函数全部走 facade）"
else
    log "  [FAIL] framework 仍调用 script 全局 $n_f 处："
    printf '%s\n' "$F_CHECK" | head -6 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------- G. facade 层纯度
log "=== STEP: G. facade 层不得读写游戏状态 ==="
for f in render_facade flow_facade game_hooks; do
    bad_g=$(grep -rPn "JY[.[]|WAR[.[]" "game/framework/$f.lua" 2>/dev/null \
            | grep -vP '(^|:)[0-9]+:\s*--' | wc -l | tr -dc '0-9')
    [ -n "$bad_g" ] || bad_g=0
    if [ "$bad_g" -eq 0 ]; then
        log "  [PASS] $f.lua 无游戏状态读写"
    else
        log "  [FAIL] $f.lua 有 $bad_g 处游戏状态读写（facade 必须纯转发）"
        grep -rPn "JY[.[]|WAR[.[]" "game/framework/$f.lua" \
            | grep -vP '(^|:)[0-9]+:\s*--' | head -3 | tee -a "$LOG"
        fail=$((fail + 1))
    fi
done

# ---------------------------- H. facade 模块必须存在
log "=== STEP: H. 三个 facade 模块存在 ==="
for f in render_facade flow_facade game_hooks; do
    if [ -f "game/framework/$f.lua" ]; then
        log "  [PASS] framework/$f.lua 存在"
    else
        log "  [FAIL] 缺 framework/$f.lua"
        fail=$((fail + 1))
    fi
done

# ---------------------------------------- I. 兼容层彻底删除
log     "=== STEP: I. _G.lib 兼容层已删除（port-compat-layer-removal）==="
# 判据三项：
#   ① 生产代码里没有 `_G.lib =`（tests/ 与 tools/ 为桩/调试脚本，豁免）
#   ② `lib_love.lua` 代码行零 `lib.`（它用 _ENV=M + __index=_G，写 lib.xxx
#      会经 _G 落到 _G.lib —— 那是循环依赖）
#   ③ framework/script/main 零 `rawget(_G, "lib")`
#
# 为什么：`_G.lib` 与 `EngineAPI` 曾被 setmetatable 变成**同一张表**，
# 于是 `lib.Delay = ...` 往 EngineAPI 写了一个契约外的键，
# `WaitFrame` 的 fallback 因此拿到协程版而非阻塞退路（两个补丁互相抵消）。
# 用 `-r --include='*.lua'`：不加引号的 `--include=*.lua` 会被 shell 展开
# （本机 GREP_OPTIONS 里还带 --exclude 规则，实测会把 .js 也算进来）。
bad_i1=$(grep -rn '_G.lib[[:space:]]*=' game --include='*.lua' 2>/dev/null         | grep -vE ':[0-9]+:[[:space:]]*--'         | grep -v 'game/tests/' | grep -v 'game/tools/'         | wc -l | tr -dc '0-9')
[ -n "$bad_i1" ] || bad_i1=0
if [ "$bad_i1" -eq 0 ]; then
    log "  [PASS] 生产代码零 _G.lib 赋值"
else
    log "  [FAIL] 生产代码仍有 $bad_i1 处 _G.lib 赋值："
    grep -rn '_G.lib[[:space:]]*=' game --include='*.lua' 2>/dev/null         | grep -vE ':[0-9]+:[[:space:]]*--'         | grep -v 'game/tests/' | grep -v 'game/tools/' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

bad_i2=$(grep -nE '(^|[^A-Za-z0-9_])lib\.[A-Za-z]' game/engine-love2d/lib_love.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_i2" ] || bad_i2=0
if [ "$bad_i2" -eq 0 ]; then
    log "  [PASS] lib_love.lua 代码行零 lib.*（无循环依赖）"
else
    log "  [FAIL] lib_love.lua 仍有 $bad_i2 处 lib.* 自引用（循环依赖）："
    grep -nE '(^|[^A-Za-z0-9_])lib\.[A-Za-z]' game/engine-love2d/lib_love.lua 2>/dev/null         | grep -vE ':[0-9]+:[[:space:]]*--' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

bad_i3=$(grep -rn 'rawget(_G, *"lib")' game/framework/*.lua game/script/*.lua         game/script/battle/*.lua game/main.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_i3" ] || bad_i3=0
if [ "$bad_i3" -eq 0 ]; then
    log "  [PASS] framework/script/main 零 rawget(_G, \"lib\")"
else
    log "  [FAIL] 仍有 $bad_i3 处 rawget(_G, \"lib\")："
    grep -rn 'rawget(_G, *"lib")' game/framework/*.lua game/script/*.lua         game/script/battle/*.lua game/main.lua 2>/dev/null         | grep -vE ':[0-9]+:[[:space:]]*--' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------------------- J. 旧贴图子系统彻底删除
log "=== STEP: J. lib_love 旧贴图子系统已删除（port-legacy-picture-removal）==="
# 判据 ①：`lib_love.lua` 代码行零这些符号（注释豁免）。
#   覆盖：RLE 解码入口（LoadPic）、档案链（PicLoad/PicGetXY/PicInit）、
#   缓存（picFileCache）、调色板逐像素（palletteIdx/color32Pallette）、
#   旧地图绘制（DrawMMap/DrawSMap/DrawWarMap —— 它们经 JY_LoadPic 读缓存）
bad_j=$(grep -nE 'LoadPic|PicLoad|PicGetXY|PicInit|picFileCache|palletteIdx|color32Pallette|DrawMMap|DrawSMap|DrawWarMap'         game/engine-love2d/lib_love.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_j" ] || bad_j=0
if [ "$bad_j" -eq 0 ]; then
    log "  [PASS] lib_love.lua 零旧贴图子系统符号（-920 行）"
else
    log "  [FAIL] lib_love.lua 仍有 $bad_j 处旧贴图子系统符号："
    grep -nE 'LoadPic|PicLoad|PicGetXY|PicInit|picFileCache|palletteIdx|color32Pallette|DrawMMap|DrawSMap|DrawWarMap'         game/engine-love2d/lib_love.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# 判据 ②：三个 map 绘制契约都必须先取 mapRender()（缺失即抛错，不再回退旧实现）
bad_j2=$(grep -c 'mapRender()' game/engine-love2d/engine_love2d.lua 2>/dev/null | tr -dc '0-9')
[ -n "$bad_j2" ] || bad_j2=0
if [ "$bad_j2" -ge 3 ]; then
    log "  [PASS] 三个 map 绘制契约都先取 mapRender()（缺失即抛错）"
else
    log "  [FAIL] map 绘制契约未全部走 mapRender()（实测 $bad_j2 处，应 >= 3）"
    fail=$((fail + 1))
fi

# --------------------------------------------------------------- 汇总
log "============================================"
if [ "$fail" -eq 0 ]; then
    log "[ ok ] 全部通过"
    exit 0
else
    log "[FAIL] $fail 项失败"
    exit 1
fi
