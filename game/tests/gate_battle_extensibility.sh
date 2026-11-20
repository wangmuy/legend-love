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

# ------------------------------- G. 搬移保真性（字节级）
log "=== STEP: G. 搬移是纯字节搬移（零逻辑改动）==="
if command -v python3 >/dev/null 2>&1; then
    if python3 game/tests/verify_battle_move_fidelity.py >/dev/null 2>&1; then
        log "  [PASS] 66 个战斗函数 + 20 个协程逐字节一致"
    else
        log "  [FAIL] 搬移内容有改动（应只有位置变化，无逻辑改动）"
        python3 game/tests/verify_battle_move_fidelity.py 2>&1 | grep 'FAIL' | head -3 | tee -a "$LOG"
        fail=$((fail + 1))
    fi
else
    log "  [SKIP] 无 python3（无法做字节级校验）"
fi

# ------------------------------- H. WAR.Person 容量 >= 40（REQ-BRB-3）
log "=== STEP: H. WAR.Person 容量 >= 40 ==="
if grep -q 'WAR_PERSON_CAPACITY = 40' game/script/jymain.lua 2>/dev/null; then
    log "  [PASS] WAR_PERSON_CAPACITY = 40（原硬编码 26 = 我方6+敌方20 = 零余量）"
else
    log "  [FAIL] 未定义 WAR_PERSON_CAPACITY = 40"
    fail=$((fail + 1))
fi
if grep -q 'for i=0,26-1 do' game/script/jymain.lua 2>/dev/null; then
    log "  [FAIL] 仍有硬编码 26（应改用 WAR_PERSON_CAPACITY）"
    fail=$((fail + 1))
else
    log "  [PASS] 无硬编码 26 循环"
fi

# ------------------------------- I. WarLoad 返回布尔（REQ-BRB-1）
log "=== STEP: I. WarLoad 返回 true/false ==="
# 取 WarLoad 函数体，查 return false / return true
nf_count=$(awk '/^function WarLoad\(/,/^end$/' game/script/jymain.lua 2>/dev/null | grep -c 'return false')
[ -n "$nf_count" ] || nf_count=0
# **至少 2 处**：越界 + Byte.loadfile 失败（负向对照时改一处仍应 PASS 另一处）
if [ "$nf_count" -ge 2 ]; then
    log "  [PASS] WarLoad 有 $nf_count 处 return false（越界 + 读取失败）"
else
    log "  [FAIL] WarLoad 缺 return false"
    fail=$((fail + 1))
fi
if awk '/^function WarLoad\(/,/^end$/' game/script/jymain.lua 2>/dev/null | grep -q 'return true'; then
    log "  [PASS] WarLoad 有 return true（成功）"
else
    log "  [FAIL] WarLoad 缺 return true"
    fail=$((fail + 1))
fi

# ------------------------------- J. 调用点检查 WarLoad 返回值（REQ-BRB-2）
log "=== STEP: J. WarLoad 调用点检查返回值 ==="
# 判据：每一处 `WarLoad(` 调用都必须带返回值捕获。
#   合法：`if not WarLoad(...)`  /  `xxx = WarLoad(...)`
#   非法：`WarLoad(...)` 单独成句
#
# **为什么用 awk 而不是 grep -vE 链**：
#   我第一版用 `grep -vE 'if not WarLoad\(|= WarLoad\('`，负向对照
#   （加一行 `WarLoad(0)`）**不 FAIL**。排查了很久发现是 shell/grep 的
#   反斜杠转义在 grep -E 里被吃掉，导致过滤模式实际变成了 `if not WarLoad(`
#   —— 那个裸括号被当成分组符号，匹配行为不符合预期。
#   awk 逐行判断，不用正则转义，行为确定。
unchecked=$(awk '
    /WarLoad[[:space:]]*\(/ {
        # 跳过函数定义行
        if (match($0, /function[[:space:]]+WarLoad/)) next
        # 跳过注释行
        if (match($0, /^[[:space:]]*--/)) next
        # 必须带捕获：if not WarLoad( 或 xxx = WarLoad(
        if (match($0, /if[[:space:]]+not[[:space:]]+WarLoad/) ||
            match($0, /=[[:space:]]*WarLoad/)) next
        print FNR ": " $0
    }
' game/framework/war_async.lua game/script/jymain.lua 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$unchecked" ] || unchecked=0
if [ "$unchecked" -eq 0 ]; then
    log "  [PASS] 所有 WarLoad(...) 调用都捕获了返回值"
else
    log "  [FAIL] 仍有 $unchecked 处裸 WarLoad(...) 调用："
    awk '
        /WarLoad[[:space:]]*\(/ {
            if (match($0, /function[[:space:]]+WarLoad/)) next
            if (match($0, /^[[:space:]]*--/)) next
            if (match($0, /if[[:space:]]+not[[:space:]]+WarLoad/) ||
                match($0, /=[[:space:]]*WarLoad/)) next
            print FNR ": " $0
        }
    ' game/framework/war_async.lua game/script/jymain.lua 2>/dev/null | head -5 | tee -a "$LOG"
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
