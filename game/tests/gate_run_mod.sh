#!/bin/sh
# run-mod.sh 音频就绪回归门禁
#
# 守的是两个真实踩过的坑：
#   [A] run-mod.sh 曾用 `[ -d mods/<slug> ]` 判断「已构建」，导致新增产物类型
#       （music/）后旧目录被误判为就绪而跳过重建，音频永远缺失。
#   [B] mod_build 的 flattenMusic 曾用 `(mid|mp3)` 做扩展名匹配，而 Lua pattern
#       没有 alternation 操作符，静默匹配 0 个文件 ⇒ 产物 music/ 全空。
#
# 用法: sh tests/gate_run_mod.sh      （日志: mods/_audit/gate_run_mod.log）
cd "$(dirname "$0")/../.." || exit 1
LOG=game/mods/_audit/gate_run_mod.log
mkdir -p game/mods/_audit
: > "$LOG"
fail=0

log() { echo "$*" | tee -a "$LOG"; }

# ---------------------------------------------------------------- A. 语法
log "=== STEP: bash -n tools/run-mod.sh ==="
if bash -n tools/run-mod.sh 2>>"$LOG"; then
    log "  [PASS] 语法正确"
else
    log "  [FAIL] 语法错误"
    fail=$((fail + 1))
fi

# ------------------------------------------------- B. mod_ready 存在且不再只看目录
log "=== STEP: mod_ready 逻辑 ==="
if grep -q '^mod_ready()' tools/run-mod.sh; then
    log "  [PASS] mod_ready 函数存在"
else
    log "  [FAIL] 缺少 mod_ready 函数（退回到只看目录的旧逻辑）"
    fail=$((fail + 1))
fi
if grep -q '\[ -d "\$out/music" \]' tools/run-mod.sh; then
    log "  [PASS] mod_ready 校验 music/ 目录"
else
    log "  [FAIL] mod_ready 未校验 music/"
    fail=$((fail + 1))
fi
if grep -q 'n_out.*-ge.*n_src' tools/run-mod.sh; then
    log "  [PASS] mod_ready 比对产物数与源侧数"
else
    log "  [FAIL] mod_ready 未比对数量"
    fail=$((fail + 1))
fi

# ----------------------------------- C. 负向对照：旧写法必须已消失
log "=== STEP: 负向对照（旧的只看目录逻辑不得残留） ==="
if grep -q 'if \[ ! -d "\$MODS_OUT_DIR/\$SELECTED" \]' tools/run-mod.sh; then
    log "  [FAIL] 仍存在旧逻辑 [ ! -d \$MODS_OUT_DIR/\$SELECTED ]"
    fail=$((fail + 1))
else
    log "  [PASS] 旧逻辑已移除"
fi

# --------------------------------------- D. Lua pattern 无 alternation
log "=== STEP: flattenMusic 不得用 (mid|mp3) ==="
if grep -q 'midd|mp3\|mid|mp3' game/tools/mod_build.lua; then
    log "  [FAIL] mod_build 出现 Lua 不支持的 alternation 写法"
    fail=$((fail + 1))
else
    log "  [PASS] 无 alternation 写法"
fi

# ------------------------------------------------ E. 音频产物就绪
log "=== STEP: 音频产物就绪 ==="
n_mid=$(find game/mods -path '*/music/*.mid' -type f 2>/dev/null | wc -l)
n_mp3=$(find game/mods -path '*/music/*.mp3' -type f 2>/dev/null | wc -l)
s_mid=$(find reference/allmods -path '*/music/*.mid' -type f 2>/dev/null | wc -l)
s_mp3=$(find reference/allmods -path '*/music/*.mp3' -type f 2>/dev/null | wc -l)
log "  mid: 产物=$n_mid 源=$s_mid"
log "  mp3: 产物=$n_mp3 源=$s_mp3"
if [ "$n_mid" -eq "$s_mid" ] && [ "$n_mp3" -eq "$s_mp3" ]; then
    log "  [PASS] 音频零丢失"
else
    log "  [FAIL] 音频数量不一致（未构建？跑 lua tools/mod_build.lua --all）"
    fail=$((fail + 1))
fi

# -------------------------------------- F. 每个 MOD 逐一核对
log "=== STEP: 逐 MOD 核对 mid 数 ==="
bad=0
for d in game/mods/*/music; do
    [ -d "$d" ] || continue
    slug=$(echo "$d" | sed 's|game/mods/||;s|/music||')
    o=$(find "$d" -maxdepth 1 -type f -name '*.mid' | wc -l)
    s=$(find "reference/allmods/kys-$slug/music" -maxdepth 1 -type f -name '*.mid' 2>/dev/null | wc -l)
    if [ "$o" != "$s" ]; then
        log "  [FAIL] $slug 产物=$o 源=$s"
        bad=$((bad + 1))
    fi
done
if [ "$bad" -eq 0 ]; then
    log "  [PASS] 全部 MOD 音频数与源侧一致"
else
    fail=$((fail + bad))
fi

# ------------------------------------------------ G. --list 可运行
log "=== STEP: run-mod.sh --list ==="
if ./tools/run-mod.sh --list >/dev/null 2>>"$LOG"; then
    log "  [PASS] --list 正常运行"
else
    log "  [FAIL] --list 运行失败"
    fail=$((fail + 1))
fi


# ---------------------------------- H. libmodplug 警告治理
log "=== STEP: libmodplug 警告治理 ==="
if grep -q 'find_timidity_cfg_dir()' tools/run-mod.sh; then
    log "  [PASS] find_timidity_cfg_dir 存在"
else
    log "  [FAIL] 缺少 MMPAT_PATH_TO_CFG 自动探测"
    fail=$((fail + 1))
fi
if grep -q 'MMPAT_PATH_TO_CFG=' tools/run-mod.sh; then
    log "  [PASS] 会 export MMPAT_PATH_TO_CFG"
else
    log "  [FAIL] 未 export MMPAT_PATH_TO_CFG"
    fail=$((fail + 1))
fi
if grep -q 'quiet_libmodplug()' tools/run-mod.sh; then
    log "  [PASS] quiet_libmodplug 存在"
else
    log "  [FAIL] 缺少 stderr 过滤"
    fail=$((fail + 1))
fi
# 负向对照：过滤必须只针对这两个前缀，不能无条件吞掉 stderr
if grep -q "grep -vE '\^(load_pat|load_mid) > '" tools/run-mod.sh; then
    log "  [PASS] 过滤模式仅匹配 load_pat/load_mid 前缀"
else
    log "  [FAIL] 过滤模式缺失或过宽"
    fail=$((fail + 1))
fi
if grep -q 'FUZZY_MIDI_WARN' tools/run-mod.sh; then
    log "  [PASS] 过滤可关闭（FUZZY_MIDI_WARN=0）"
else
    log "  [FAIL] 过滤无开关，排查时不便"
    fail=$((fail + 1))
fi


# ------------------------------------------ I. 音乐探测顺序与 OGG 渲染管线
log "=== STEP: 音乐探测顺序 .ogg -> .mp3 -> .mid ==="
ORDER="$(grep -o 'MUSIC_EXTS = {[^}]*}' game/engine-love2d/lib_love.lua | head -1)"
case "$ORDER" in
    *'.ogg", ".mp3", ".mid'*)
        log "  [PASS] 顺序为 .ogg,.mp3,.mid（.mid 兜底）" ;;
    *)
        log "  [FAIL] 顺序错误: $ORDER"
        fail=$((fail + 1)) ;;
esac
# 负向守门：.mid 不得排第一
case "$ORDER" in
    *'{ ".mid"'*)
        log "  [FAIL] .mid 排在第一位，预渲染 ogg 会失效"
        fail=$((fail + 1)) ;;
    *)
        log "  [PASS] .mid 不是第一优先" ;;
esac

log "=== STEP: mod_build 保留已渲染 ogg ==="
if grep -q 'preservedOgg' game/tools/mod_build.lua; then
    log "  [PASS] 存在 preservedOgg 保护"
else
    log "  [FAIL] 重建会删除已渲染 ogg"
    fail=$((fail + 1))
fi
if grep -q 'report.renderedOgg' game/tools/mod_build.lua; then
    log "  [PASS] 报告 renderedOgg 数量"
else
    log "  [FAIL] 未报告恢复数量"
    fail=$((fail + 1))
fi

log "=== STEP: render-music.sh ==="
if [ -x tools/render-music.sh ]; then
    log "  [PASS] 可执行"
else
    log "  [FAIL] 缺失或不可执行"
    fail=$((fail + 1))
fi
if bash -n tools/render-music.sh 2>>"$LOG"; then
    log "  [PASS] 语法正确"
else
    log "  [FAIL] 语法错误"
    fail=$((fail + 1))
fi


log "=== STEP: 行为验证——重建后已渲染 ogg 仍存活 ==="
# 文本检查无法发现「恢复循环被改成空循环」，所以这里做真实构建验证：
# 植入标记 ogg -> mod_build 重建 -> 检查标记是否还在。
BMOD=""
for d in game/mods/*/; do
    [ -d "$d/music" ] || continue
    if find "$d/music" -maxdepth 1 -name '*.mid' | grep -q .; then
        BMOD="$(basename "$d")"; break
    fi
done
if [ -z "$BMOD" ]; then
    log "  [SKIP] 没有已构建且含 MIDI 的 MOD"
else
    BMARK="$BMOD.behavior_marker_$$.ogg"
    printf 'GATE_OGG_MARKER' > "game/mods/$BMOD/music/$BMARK"
    ( cd game && lua tools/mod_build.lua "kys-$BMOD" ) >/dev/null 2>&1 || true
    if [ -f "game/mods/$BMOD/music/$BMARK" ] && \
       [ "$(cat "game/mods/$BMOD/music/$BMARK")" = "GATE_OGG_MARKER" ]; then
        log "  [PASS] $BMOD: 重建后标记 ogg 存活（保护逻辑真实生效）"
        rm -f "game/mods/$BMOD/music/$BMARK"
    else
        log "  [FAIL] $BMOD: 重建后标记 ogg 丢失（保护逻辑无效）"
        fail=$((fail + 1))
        rm -f "game/mods/$BMOD/music/$BMARK"
    fi
fi

# -------------------------- J. active_mod.txt 解析（注释行容错）
# 回归：旧实现用 gsub("\n","") 把所有行拼接，active_mod.sample.txt
# 直接复制会得到 2000+ 字符乱串并静默回退到原版。
log ""
log "--- J. active_mod.txt 解析容错 ---"

if [ -f game/active_mod.sample.txt ]; then
    SAMPLE_RESULT=$( cd game && lua -e '
package.path="./?.lua;./?/init.lua;"..package.path
local f=io.open("active_mod.sample.txt","rb")
if not f then print("NOFILE") os.exit(0) end
local c=f:read("*a"); f:close()
local MD=require("framework.mod_data")
MD.readActiveFile=function() return c end
local s=MD.Active()
if s==nil then print("NIL") else print(s.."|"..#s) end
' 2>/dev/null )

    SAMPLE_SLUG=${SAMPLE_RESULT%%|*}
    SAMPLE_LEN=${SAMPLE_RESULT##*|}

    if [ "$SAMPLE_SLUG" = "NIL" ] || [ "$SAMPLE_SLUG" = "NOFILE" ]; then
        log "  [FAIL] sample 文件复制后解析为 nil（应能激活 MOD）"
        fail=$((fail + 1))
    elif [ "$SAMPLE_LEN" -ge 40 ] 2>/dev/null; then
        log "  [FAIL] sample 解析出 $SAMPLE_LEN 字符的乱串（注释行未跳过）"
        fail=$((fail + 1))
    else
        log "  [PASS] sample 文件可直接复制生效（slug=$SAMPLE_SLUG, ${SAMPLE_LEN} 字符）"
    fi

    # 全注释 / 空文件必须回退原版
    for CASE in "comment:# 只有注释" "empty:"; do
        NAME=${CASE%%:*}; CONTENT=${CASE#*:}
        R=$( cd game && CONTENT="$CONTENT" lua -e '
package.path="./?.lua;./?/init.lua;"..package.path
local MD=require("framework.mod_data")
local c=os.getenv("CONTENT")
MD.readActiveFile=function() return c end
print(MD.Active()==nil and "NIL" or MD.Active())
' 2>/dev/null )
        if [ "$R" = "NIL" ]; then
            log "  [PASS] $NAME 文件 -> 未激活（原版路径）"
        else
            log "  [FAIL] $NAME 文件 -> 解析出 '$R'（应为 nil）"
            fail=$((fail + 1))
        fi
    done
else
    log "  [FAIL] 缺少 game/active_mod.sample.txt"
    fail=$((fail + 1))
fi

log ""
if [ "$fail" -eq 0 ]; then
    log "GATE_PASS"
else
    log "GATE_FAIL ($fail 项)"
fi
exit "$fail"
