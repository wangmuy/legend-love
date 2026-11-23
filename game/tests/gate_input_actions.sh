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
# 所以判定注释必须匹配 ':[0-9]+:[[:space:]]*--' —— 用 '^[[:space:]]*--' 是抓不到的（实测踩过）。
bad_a=$(grep -rn 'jy\.' game/framework/*.lua 2>/dev/null \
        | grep -v 'jyconst' \
        | grep -vE ':[0-9]+:[[:space:]]*--' \
        | wc -l | tr -dc '0-9')
[ -n "$bad_a" ] || bad_a=0
if [ "$bad_a" -eq 0 ]; then
    log "  [PASS] framework/ 无游戏动作词汇（注释里的说明性提及不计）"
else
    log "  [FAIL] framework/ 有 $bad_a 处游戏词汇引用："
    grep -rn 'jy\.' game/framework/*.lua 2>/dev/null \
        | grep -v 'jyconst' | grep -vE ':[0-9]+:[[:space:]]*--' | head -3 | tee -a "$LOG"
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
bad_c=$(grep -n 'synthetic *=' game/framework/*.lua 2>/dev/null | grep -v '^[[:space:]]*--' | wc -l | tr -dc '0-9')
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
        | sed 's/^[0-9]*://' | grep -v '^[[:space:]]*--' | grep -v '：' | wc -l | tr -dc '0-9')
[ -n "$bad_d" ] || bad_d=0
if [ "$bad_d" -eq 0 ]; then
    log "  [PASS] virtual_pad 逻辑层不直连 love.*"
else
    log "  [FAIL] virtual_pad 有 $bad_d 处 love.* 调用（绘制必须经 EngineAPI）"
    grep -n 'love\.' game/framework/virtual_pad.lua | sed 's/^[0-9]*://' | grep -v '^[[:space:]]*--' | head -3 | tee -a "$LOG"
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
        | grep -vE '^[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
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
# **用 `+` 不用 `*`**：`VK_` 后面必须至少有一个字符才算引用。
# 原写法 `VK_[A-Z0-9_]*` 会把注释里的 `VK_*` 通配写法抓成「未定义常量 VK_」
# —— 实测踩过（2026-11-22 自己写注释时触发的假阳性）。
for vk in $(grep -rohE 'VK_[A-Z0-9_]+' game/framework/*.lua game/script/*.lua 2>/dev/null | sort -u); do
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


# ------------------------ F2. getKey 的键码归一化契约必须写明
# **背景**（2026-11-22 复核）：契约原本只有一行 `@return number 按键码` ——
# 没说什么体系的码。而实际值是「ASCII + SDL2 keycode 高区」混杂。
# Godot 的 KEY_UP=4194320、Unreal 的 EKeys::Up 都不等于 1073741906，
# 直接返回原生值 → 方向键判定全部失效，且**不报错**（Lua 比较不抛异常）。
log "--- F2. getKey 键码归一化契约 ---"
EAPI="game/engine-love2d/engine_api.lua"
if grep -q 'SDL2 keycode' "$EAPI" 2>/dev/null; then
    log "  [PASS] engine_api.lua 写明 getKey 返回 SDL2 keycode"
else
    log "  [FAIL] engine_api.lua 未写明 getKey 的键码体系（新引擎会静默失效）"
    fail=$((fail + 1))
fi
# 4 个宿主的映射对照必须都在（LÖVE/Godot/Unreal/Web）
for host in "LÖVE" "Godot" "Unreal" "Web"; do
    if grep -q "$host" "$EAPI" 2>/dev/null; then
        log "  [PASS] 契约含 $host 的映射对照"
    else
        log "  [FAIL] 契约缺 $host 的键码映射对照"
        fail=$((fail + 1))
    fi
done
# jyconst 必须交叉引用（否则读常量的人不知道归一化要求）
if grep -q 'input.getKey` 契约' game/script/jyconst.lua 2>/dev/null    || grep -q 'engine_api.lua.*input.getKey' game/script/jyconst.lua 2>/dev/null; then
    log "  [PASS] jyconst.lua 的 SDLK_* 处有交叉引用"
else
    log "  [FAIL] jyconst.lua 缺交叉引用（读常量的人看不到归一化要求）"
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
# ------------------------ G. VK 迁移进度（分层判据）
# **分层而不是一刀切**（2026-11-23）：
#   · framework/ 的 VK 引用必须 = 0 → 硬断言（框架必须能复用到其它游戏）
#   · script/ 的**活路径**（battle_flow_coroutines）= 0 → 硬断言
#   · script/ 的**原版参考实现**（jymain 的 Game_MMap/ShowPersonStatus/
#     SelectThing、battle_action/battle_flow）→ 只统计，不断言
#
# 为什么不给后者加硬断言：它们全部位于「被 async_globals 替换 / JY_Main
# 从未被调用」的函数里，改它们等于修改无法运行、无法验证的代码。
log "=== STEP: G. VK 迁移进度（framework 硬断言 / script 原版参考只统计）==="
fw_vk=$(grep -rn 'VK_' game/framework/*.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$fw_vk" ] || fw_vk=0
if [ "$fw_vk" -eq 0 ]; then
    log "  [PASS] framework/ 零 VK 引用（全部走语义动作）"
else
    log "  [FAIL] framework/ 仍有 $fw_vk 处 VK 引用："
    grep -rn 'VK_' game/framework/*.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | head -5 | tee -a "$LOG"
    fail=$((fail + 1))
fi

# script 的活路径（战斗协程）必须归零
live_vk=$(grep -n 'VK_' game/script/battle/battle_flow_coroutines.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$live_vk" ] || live_vk=0
if [ "$live_vk" -eq 0 ]; then
    log "  [PASS] script 活路径（battle_flow_coroutines）零 VK"
else
    log "  [FAIL] script 活路径仍有 $live_vk 处 VK（这是战斗的可达代码）"
    fail=$((fail + 1))
fi

# script 的原版参考实现：只统计
dead_vk=$(grep -rn 'VK_' game/script/jymain.lua game/script/battle/battle_action.lua         game/script/battle/battle_flow.lua 2>/dev/null         | grep -vE '(^|:)[0-9]+:[[:space:]]*--' | wc -l | tr -dc '0-9')
[ -n "$dead_vk" ] || dead_vk=0
log "  [INFO] script/ 原版参考实现仍有 $dead_vk 处 VK（不可达，保留作原版对照）"
if [ "${STRICT_SCRIPT_VK:-0}" = "1" ] && [ "$dead_vk" -ne 0 ]; then
    log "  [FAIL] --strict-script-vk 模式下 script/ 也必须归零（实测 $dead_vk）"
    fail=$((fail + 1))
fi

log "============================================"
if [ "$fail" -eq 0 ]; then
    log "[ ok ] 全部通过"
    exit 0
else
    log "[FAIL] $fail 项失败"
    exit 1
fi
