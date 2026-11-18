#!/bin/sh
# 输入动作层回归门禁（change: input-action-layer）
#
# 守的坑（全部有实测依据）：
#   [A] framework 通用层出现游戏词汇 → 框架不可复用于仙剑等其它游戏
#   [B] framework 内置 move/aim → 把 Hades 玩法强加给所有游戏
#   [C] synthetic 脏标记残留 → 消费方无法判断事件来源
#   [D] 虚拟手柄直连 love.* → 无法换引擎
#   [E] 触摸用 0.10.x 的老 API → 在 LÖVE 11.5 上直接崩
#   [F] 业务代码引用未定义的 VK_* → 比较恒 false，静默失效
#
# 用法: sh game/tests/gate_input_actions.sh
#       日志: game/mods/_audit/gate_input_actions.log
cd "$(dirname "$0")/../.." || exit 1
LOG=game/mods/_audit/gate_input_actions.log
mkdir -p game/mods/_audit
: > "$LOG"
fail=0

log() { echo "$*" | tee -a "$LOG"; }

# -------------------------------------------------------------------------
# 注意：本机 GREP_OPTIONS 含 --exclude=*.git*，会让 grep dotfile 永不命中。
# 本门禁不 grep 任何 dotfile，全部 grep .lua 源码。
# -------------------------------------------------------------------------

# -------------------------------------- A. framework 通用层不得有游戏词汇
log "=== STEP: A. framework 通用层零游戏词汇 ==="
# 注意：-rn 输出是 "文件:行号:内容"，注释行形态是 "文件:行号:--..."。
# 所以判定注释必须匹配 ':[0-9]+:\s*--' —— 用 '^\s*--' 是抓不到的（实测踩过）。
bad_a=$(grep -rn 'jy\.' game/framework/*.lua 2>/dev/null \
        | grep -v 'jyconst' \
        | grep -vE ':[0-9]+:\s*--' \
        | wc -l | tr -dc '0-9')
[ -n "$bad_a" ] || bad_a=0
if [ "$bad_a" -eq 0 ]; then
    log "  [PASS] framework/ 无游戏动作词汇（注释里的说明性提及不计）"
else
    log "  [FAIL] framework/ 有 $bad_a 处游戏词汇引用："
    grep -rn 'jy\.' game/framework/*.lua 2>/dev/null \
        | grep -v 'jyconst' | grep -vE ':[0-9]+:\s*--' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# framework 动作常量必须是 ui. 前缀
log "=== STEP: A2. 动作常量前缀 ==="
if grep -q 'InputActions.UP *= *"ui.up"' game/framework/input_actions.lua 2>/dev/null; then
    log "  [PASS] 动作常量用 ui. 前缀"
else
    log "  [FAIL] 动作常量未用 ui. 前缀"
    fail=$((fail + 1))
fi
if grep -q 'InputActions.ACCEPT *= *"ui.accept"' game/framework/input_actions.lua 2>/dev/null; then
    log "  [PASS] 确认动作是 ui.accept（不是 confirm）"
else
    log "  [FAIL] 确认动作必须是 ui.accept"
    fail=$((fail + 1))
fi

# ---------------------------------------- B. framework 不得内置 move/aim
log "=== STEP: B. framework 不得内置 move/aim ==="
bad_b=$(grep -n 'defineVector("move"\|defineVector("aim"' game/framework/input_bindings.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$bad_b" ] || bad_b=0
if [ "$bad_b" -eq 0 ]; then
    log "  [PASS] framework 未内置 move/aim（只内置 ui.cursor）"
else
    log "  [FAIL] framework 内置了 $bad_b 个玩法语义向量"
    fail=$((fail + 1))
fi
if grep -q 'defineVector(InputActions.CURSOR' game/framework/input_bindings.lua 2>/dev/null; then
    log "  [PASS] 内置 ui.cursor（跨游戏通用）"
else
    log "  [FAIL] 缺内置 ui.cursor"
    fail=$((fail + 1))
fi

# -------------------------------------------- C. synthetic 脏标记已清除
log "=== STEP: C. synthetic 已清除 ==="
# 只统计"实际使用"（赋值/读取），排除注释说明
bad_c=$(grep -n 'synthetic *=' game/framework/*.lua 2>/dev/null | grep -v '^\s*--' | wc -l | tr -dc '0-9')
[ -n "$bad_c" ] || bad_c=0
if [ "$bad_c" -eq 0 ]; then
    log "  [PASS] 无 synthetic 字段赋值"
else
    log "  [FAIL] 仍有 $bad_c 处 synthetic 赋值（应改用 source）"
    fail=$((fail + 1))
fi
if grep -q 'source *= *"compat"' game/framework/input_manager.lua 2>/dev/null; then
    log "  [PASS] enqueueKeyEvent 用 source=compat 取代 synthetic"
else
    log "  [FAIL] enqueueKeyEvent 未用 source 标记"
    fail=$((fail + 1))
fi

# ---------------------------- D. 虚拟手柄不得直连 love.*（排除注释行）
log "=== STEP: D. virtual_pad 不直连 love.* ==="
bad_d=$(grep -n 'love\.' game/framework/virtual_pad.lua 2>/dev/null \
        | sed 's/^[0-9]*://' | grep -v '^\s*--' | grep -v '：' | wc -l | tr -dc '0-9')
[ -n "$bad_d" ] || bad_d=0
if [ "$bad_d" -eq 0 ]; then
    log "  [PASS] virtual_pad 逻辑层不直连 love.*"
else
    log "  [FAIL] virtual_pad 有 $bad_d 处 love.* 调用（绘制必须经 EngineAPI）"
    grep -n 'love\.' game/framework/virtual_pad.lua | sed 's/^[0-9]*://' | grep -v '^\s*--' | head -3 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# -------------------------------- E. 触摸用 11.5 的 getTouches（非老 API）
log "=== STEP: E. 触摸 API 用 11.5 形态 ==="
if grep -q 'love.touch.getTouches' game/engine-love2d/engine_love2d.lua 2>/dev/null; then
    log "  [PASS] 使用 getTouches()"
else
    log "  [FAIL] 未使用 getTouches()"
    fail=$((fail + 1))
fi
bad_e=$(grep -n 'getTouchCount\|love.touch.getTouch(' game/engine-love2d/engine_love2d.lua 2>/dev/null \
        | grep -vE '^[0-9]+:\s*--' | wc -l | tr -dc '0-9')
[ -n "$bad_e" ] || bad_e=0
if [ "$bad_e" -eq 0 ]; then
    log "  [PASS] 未用 0.10.x 的 getTouchCount/getTouch(i)（11.5 上是 nil）"
else
    log "  [FAIL] 仍用老触摸 API（$bad_e 处，11.5 上会崩）"
    fail=$((fail + 1))
fi

# ------------------------ F. 业务代码不得引用未定义的 VK_* 常量
log "=== STEP: F. 无未定义 VK 常量 ==="
undef=0
for vk in $(grep -roh 'VK_[A-Z0-9_]*' game/framework/*.lua game/script/*.lua 2>/dev/null | sort -u); do
    if ! grep -q "$vk *=" game/script/jyconst.lua 2>/dev/null; then
        log "  [FAIL] $vk 被引用但 jyconst.lua 未定义（比较恒 false，静默失效）"
        undef=$((undef + 1))
    fi
done
if [ "$undef" -eq 0 ]; then
    log "  [PASS] 所有引用的 VK_* 都有定义"
else
    fail=$((fail + 1))
fi

# ------------------------------------------ G. 四引擎 input 函数齐全
log "=== STEP: G. 四引擎 input 函数齐全 ==="
for fn in getKey waitForKey setKeyRepeat mousePosition mouseButton \
          getAxis getCapabilities getPointerPosition pollAction getTouches; do
    for f in game/engine-love2d/engine_love2d.lua game/engine-mud/engine_mud.lua \
             game/engine-web/engine_web.lua game/tests/engine_test.lua; do
        if ! grep -q "input\.$fn" "$f" 2>/dev/null; then
            log "  [FAIL] $f 缺 input.$fn"
            fail=$((fail + 1))
        fi
    done
done
if [ "$fail" -eq 0 ]; then
    log "  [PASS] 四引擎 input 10 个函数齐全"
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
