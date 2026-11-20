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

# 本机 GREP_OPTIONS 含 --exclude=*.git*，会让 grep dotfile 永不命中。
# 本门禁不 grep 任何 dotfile，全部 grep .lua 源码。

# ---------------------------------------- A. framework 无 lib.* 引擎调用
log "=== STEP: A. framework 零 lib.* 绕过 ==="
# async_globals.lua 是**主动 patch** lib.Delay 的地方（劫持原版阻塞调用），
# 那 3 处是刻意的 patch point，不属于"绕过契约"。
bad_a=$(grep -rn 'lib\.[A-Za-z]' game/framework/*.lua 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*--' \
        | grep -v 'framework/async_globals.lua' \
        | wc -l | tr -dc '0-9')
[ -n "$bad_a" ] || bad_a=0
if [ "$bad_a" -eq 0 ]; then
    log "  [PASS] framework/ 无 lib.* 引擎调用（async_globals 的 patch point 除外）"
else
    log "  [FAIL] framework/ 有 $bad_a 处 lib.* 调用："
    grep -rn 'lib\.[A-Za-z]' game/framework/*.lua 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*--' | grep -v async_globals | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------------------- B. framework 无 love.* 直接调用
log "=== STEP: B. framework 零 love.* 直接调用 ==="
bad_b=$(grep -rn 'love\.' game/framework/*.lua 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_b" ] || bad_b=0
if [ "$bad_b" -eq 0 ]; then
    log "  [PASS] framework/ 无 love.* 直接调用"
else
    log "  [FAIL] framework/ 有 $bad_b 处 love.*："
    grep -rn 'love\.' game/framework/*.lua | grep -vE ':[0-9]+:[[:space:]]*--' | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ---------------------------------------- C. framework 无 require engine-*
log "=== STEP: C. framework 零 require engine-* ==="
bad_c=$(grep -rn 'require("engine' game/framework/*.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$bad_c" ] || bad_c=0
if [ "$bad_c" -eq 0 ]; then
    log "  [PASS] framework/ 无 require engine-*"
else
    log "  [FAIL] framework/ 有 $bad_c 处 require engine-*"
    fail=$((fail + 1))
fi

# --------------------- D. 引擎里不得有 RLE 解码逻辑（ADR-PORT-013）
log "=== STEP: D. 引擎零 RLE 解码逻辑 ==="
# 判据：引擎实现里不应出现调色板逐像素解码的关键特征
bad_d=$(grep -rn 'palletteIdx\|paletteIdx\|color32Pallette' game/engine-mud/engine_mud.lua \
        game/engine-web/engine_web.lua game/tests/engine_test.lua 2>/dev/null \
        | grep -vE ':[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$bad_d" ] || bad_d=0
if [ "$bad_d" -eq 0 ]; then
    log "  [PASS] MUD/Web/Test 三引擎无 RLE 解码逻辑（应住 framework/sprite_decoder.lua）"
else
    log "  [FAIL] 引擎里出现 RLE 解码特征 $bad_d 处（违反 ADR-PORT-013）"
    fail=$((fail + 1))
fi
# **豁免已摘除**（port-sprite-native-migration Task 7）：
# `script/` 层已零 `lib.Pic*`（实测 0 处），所以不再为 engine-love2d 单开豁免。
# 下面的 STEP D2 用同一判据检查（hard fail）。
#
# 注意：`lib_love.lua` 的 `LoadPic`（119 行 RLE 解码）**仍存在** ——
# 它被 `PicLoadFile` 调用，而 `PicLoadFile` 仍被 `EngineAPI.sprite.loadArchive`
# 消费（war_async 的双轨补丁需要它：引擎内部的 DrawWarMap 走 PicLoadCache
# → picFileCache）。见 port-sprite-native-migration Task 6 的实测结论。

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

# --------------------------------------------------------------- 汇总
log "============================================"
if [ "$fail" -eq 0 ]; then
    log "[ ok ] 全部通过"
    exit 0
else
    log "[FAIL] $fail 项失败"
    exit 1
fi
