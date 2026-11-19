#!/bin/sh
# 战斗可扩展性门禁（change: battle-extensibility Task 6）
#
# 守的坑：
#   [A] framework/ 出现 War_* 算法定义 → 战斗代码不可被 MOD 覆盖
#   [B] script/battle/ 五模块缺失 → 扩展点不存在
#   [C] battle_rules 缺 kind 字段 → 策略接口失效
#   [D] framework/war_async.lua 含伤害公式特征 → 逻辑回流到 framework
#   [E] battle 文件未被 jymain 加载 → MOD 覆盖了但没生效
#
# 用法: sh game/tests/gate_battle_extensibility.sh
cd "$(dirname "$0")/../.." || exit 1
LOG=game/mods/_audit/gate_battle_extensibility.log
mkdir -p game/mods/_audit
: > "$LOG"
fail=0
log() { echo "$*" | tee -a "$LOG"; }

# ------------------------------- A. framework 不得有 War_* 算法定义
log "=== STEP: A. framework 零 War_* 算法定义 ==="
bad_a=$(grep -rPn '^\s*function War_' game/framework/*.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$bad_a" ] || bad_a=0
if [ "$bad_a" -eq 0 ]; then
    log "  [PASS] framework/ 无 War_* 算法定义（战斗代码应在 script/battle/）"
else
    log "  [FAIL] framework/ 有 $bad_a 个 War_* 定义："
    grep -rPn '^\s*function War_' game/framework/*.lua | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ------------------------------- B. script/battle/ 五模块 + rules
log "=== STEP: B. script/battle/ 模块齐全 ==="
for f in battle_data battle_render battle_action battle_ai battle_flow battle_rules; do
    if [ -f "game/script/battle/$f.lua" ]; then
        log "  [PASS] script/battle/$f.lua 存在"
    else
        log "  [FAIL] 缺 script/battle/$f.lua"
        fail=$((fail + 1))
    fi
done

# ------------------------------- C. battle_rules 必须有 kind
log "=== STEP: C. battle_rules 有 kind 字段 ==="
if grep -q 'kind' game/script/battle/battle_rules.lua 2>/dev/null; then
    log "  [PASS] battle_rules.lua 含 kind 字段"
else
    log "  [FAIL] battle_rules.lua 缺 kind 字段（策略接口失效）"
    fail=$((fail + 1))
fi
# kind 的三个合法值必须都出现（不限定书写形式：
#   `kind = "turnbased"` 或 `KIND_TURNBASED = "turnbased"` 都算）
for k in turnbased atb realtime; do
    if grep -qE "\"$k\"" game/script/battle/battle_rules.lua 2>/dev/null; then
        log "  [PASS] 合法 kind 值存在: $k"
    else
        log "  [FAIL] 缺合法 kind 值: $k"
        fail=$((fail + 1))
    fi
done

# ------------------------------- D. war_async 不含伤害公式特征
log "=== STEP: D. war_async.lua 无伤害公式特征 ==="
bad_d=$(grep -P '(?<![.:\w])(War_WugongHurtLife|War_CalMoveStep|War_AutoSelectEnemy|War_AnqiHurt)\s*\(' \
        game/framework/war_async.lua 2>/dev/null \
        | grep -vP ':[0-9]+:\s*--' | wc -l | tr -dc '0-9')
[ -n "$bad_d" ] || bad_d=0
if [ "$bad_d" -eq 0 ]; then
    log "  [PASS] war_async.lua 不直接调伤害/移动/AI 算法（阶段 2C 已完成）"
else
    log "  [FAIL] war_async.lua 仍调 $bad_d 处战斗算法（应住在 script/battle/）"
    grep -P '(?<![.:\w])(War_WugongHurtLife|War_CalMoveStep|War_AutoSelectEnemy|War_AnqiHurt)\s*\('         game/framework/war_async.lua 2>/dev/null | grep -vP ':[0-9]+:\s*--' | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# ------------------------------- E. jymain 必须加载 battle 模块
log "=== STEP: E. jymain 加载 battle 模块 ==="
if grep -q 'battle_data.*battle_render.*battle_action.*battle_ai.*battle_flow' \
        game/script/jymain.lua 2>/dev/null; then
    log "  [PASS] jymain.lua 按依赖顺序加载 5 个 battle 模块"
else
    log "  [FAIL] jymain.lua 未加载 battle 模块（MOD 覆盖不会生效）"
    fail=$((fail + 1))
fi
if grep -q 'battle_rules' game/script/jymain.lua 2>/dev/null; then
    log "  [PASS] jymain.lua 加载 battle_rules（策略模块）"
else
    log "  [FAIL] jymain.lua 未加载 battle_rules"
    fail=$((fail + 1))
fi

# ------------------------------- F. 加载走 ScriptLoader（MOD 回退链）
log "=== STEP: F. battle 加载走 MOD 回退链 ==="
if grep -q 'BattleLoader' game/script/jymain.lua 2>/dev/null; then
    log "  [PASS] 用 ScriptLoader.load（经 ModData.ScriptFile → MOD 可覆盖）"
else
    log "  [FAIL] 未用 ScriptLoader（MOD 无法覆盖）"
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
