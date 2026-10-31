#!/bin/sh
# 分模块跑测试：用法 split_run.sh <group>
# group=a: 10 个快速非 MOD 模块
# group=b: 9 个 MOD 模块
cd "$(dirname "$0")/.."
case "$1" in
    a) LOG=mods/_audit/split_a.log
       MODS="state_machine input_manager event_bridge coroutine_scheduler byte_io script_loader item_async war_async engine_api engine_test" ;;
    b) LOG=mods/_audit/split_b.log
       MODS="mod_ini mod_data mod_encoding mod_build mod_resources mod_audit format_spec mod_e2e mod_boot" ;;
    *) echo "usage: split_run.sh a|b"; exit 2 ;;
esac
: > "$LOG"
for m in $MODS; do
    out=$(lua tests/test_runner.lua "$m" 2>&1)
    p=$(printf '%s\n' "$out" | grep -c '^\[PASS\]')
    f=$(printf '%s\n' "$out" | grep -c '^\[FAIL\]')
    echo "$m pass=$p fail=$f" >> "$LOG"
    printf '%s\n' "$out" | grep '^\[FAIL\]' | head -30 >> "$LOG"
done
echo "GROUP_DONE" >> "$LOG"
