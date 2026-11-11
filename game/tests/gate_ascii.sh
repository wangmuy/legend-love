#!/bin/sh
# ASCII 修复回归门禁：7 项 + save 完整性
# 用法: sh tests/gate_ascii.sh   （日志: mods/_audit/gate_ascii.log）
cd "$(dirname "$0")/.."
LOG=mods/_audit/gate_ascii.log
: > "$LOG"
step() {
    echo "=== STEP: $2 ===" >> "$LOG"
    timeout 280 lua $1 >> "$LOG" 2>&1
    echo "exit=$?" >> "$LOG"
}
step "tools/mod_build.lua --verify-pascal" "1 verify-pascal"
step "tools/mod_build.lua --all" "2 build-all"
step "tools/mod_check.lua" "3 mod_check"
step "tools/mod_audit.lua --all" "4 audit-all"
step "tools/mod_audit.lua --all --evidence" "5 audit-evidence"
step "tools/format_spec.lua --all" "6 format_spec-all"
step "tests/scratch_save_integrity.lua" "7 save-integrity"
echo "GATE_DONE" >> "$LOG"
