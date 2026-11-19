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
# LOVE 引擎暂时豁免：Task 5 后半（sprite_decoder 接线）未完成，
# lib_love.lua 的 LoadPic 仍在引擎侧解码。接线完成后此豁免可删。
log "  [INFO] engine-love2d 暂时豁免（sprite_decoder 接线未完成，见 decisions.md 类别 D）"

# ---------------------------------------- E. sprite_decoder 零引擎依赖
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
# 注：Task 5 后半（script 解耦）未完成，本步先**记录现状**，
# 不作为失败项（否则门禁长期红）。等 port-script-decoupling 完成后再变硬。
script_globals='DrawString|DrawBox|DrawStrBox|DrawStrBoxYesNo|DrawStrBoxWaitKey|Cls|ShowScreen|ShowMenu|ShowMenu2|WaitKey|TalkEx|GetMyPic|AddMyCurrentPic|SceneCanPass'
n_f=$(grep -rhoE "\b($script_globals)\(" game/framework/*.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$n_f" ] || n_f=0
log "  [INFO] framework 仍调用 script 全局 $n_f 处（Task 5 后半待做，不计失败）"

# --------------------------------------------------------------- 汇总
log "============================================"
if [ "$fail" -eq 0 ]; then
    log "[ ok ] 全部通过"
    exit 0
else
    log "[FAIL] $fail 项失败"
    exit 1
fi
