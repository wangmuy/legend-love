#!/bin/sh
# 原版音乐（game/sound）回归门禁
#
# 守的是这次踩到的坑：原版 25 首 BGM 曾是「渲染 → opus → ogg」两次有损转码的产物，
# 且带削波与巨大的响度差：
#
#   25 首里 15 首解码后真峰值 > 0 dBFS（最高 +3.20 dBFS）
#   整轨响度 -26.1 .. -7.9 LUFS，跨度 18.2 dB
#   game01 有 77.6% 的能量在 73 Hz 以下（真实音色库渲染只有 40.6%）——发闷
#
# 修法是保留 MIDI 母带、用 FluidSynth + 原版 mid.sf2 重渲染（tools/render-base-music.sh）。
# 本门禁把这些性质变成机器可验证的断言，防止将来又被「转码产物」覆盖回去。
#
# 用法: sh game/tests/gate_base_music.sh
#       日志: game/mods/_audit/gate_base_music.log
# 依赖: ffmpeg/ffprobe 可选——缺失时自动跳过响度断言并在日志里标注 SKIP。
cd "$(dirname "$0")/../.." || exit 1
LOG=game/mods/_audit/gate_base_music.log
mkdir -p game/mods/_audit
: > "$LOG"
fail=0
skip=0

log() { echo "$*" | tee -a "$LOG"; }

FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"
have_ff() {
    command -v "$FFMPEG" >/dev/null 2>&1 && command -v "$FFPROBE" >/dev/null 2>&1
}

# ------------------------------------------------------------ 1. 清单完整性
# MIDI 母带**不入 git**（避免仓库膨胀）。母带的来源与 md5/时长记录在
# tools/base-music-manifest.tsv，渲染时由脚本按清单现取。所以这里守的是：
#   (a) 清单存在、25 行、字段齐全
#   (b) 已 git 跟踪的文件里**没有** game/sound/*.mid
#       （.mid 是 render-base-music.sh 的正常工作文件，跑过渲染后必然在盘上；
#        所以断言的是「不进 git」而不是「文件不存在」）
log "=== STEP: 母带清单完整性 ==="
MANIFEST=tools/base-music-manifest.tsv
if [ -f "$MANIFEST" ]; then
    n_rows=$(grep -vc '^#' "$MANIFEST" 2>/dev/null || echo 0)
    n_rows=$(printf '%s' "$n_rows" | tr -dc '0-9')
    [ -n "$n_rows" ] || n_rows=0
    if [ "$n_rows" -eq 25 ]; then
        log "  [PASS] 清单 25 行"
    else
        log "  [FAIL] 清单应为 25 行，实测 $n_rows"
        fail=$((fail + 1))
    fi
    # 每行必须 4 列（曲目/md5/来源/时长）
    bad_cols=$(grep -v '^#' "$MANIFEST" | awk -F'	' 'NF != 4 { n++ } END { print n+0 }')
    if [ "$bad_cols" -eq 0 ]; then
        log "  [PASS] 每行 4 列"
    else
        log "  [FAIL] $bad_cols 行列数不对"
        fail=$((fail + 1))
    fi
else
    log "  [FAIL] 缺 $MANIFEST"
    fail=$((fail + 1))
fi

# 母带不得被 git 跟踪（注意：不是「不得存在」）
#
# game/sound/gameNN.mid 是 render-base-music.sh 的工作文件（ensure_master 的
# 最高优先级来源）。跑过渲染脚本后必然存在 25 个，那是**正常**的。
# 这里断言的是「git 没有跟踪它们」，靠 .gitignore 与 git ls-files 双重校验。
n_tracked=$(git ls-files 'game/sound/*.mid' 2>/dev/null | wc -l | tr -dc '0-9')
[ -n "$n_tracked" ] || n_tracked=0
if [ "$n_tracked" -eq 0 ]; then
    log "  [PASS] git 未跟踪任何 game/sound/*.mid"
else
    log "  [FAIL] git 跟踪了 $n_tracked 个 game/sound/*.mid（母带不应入 git）"
    fail=$((fail + 1))
fi

# .gitignore 必须真的挡住它们（用 git check-ignore 实测，而不是 grep 文件内容）
#
# 为什么不用 grep .gitignore：本机环境变量 GREP_OPTIONS 含 `--exclude=*.git*`，
# 会让 `grep anything .gitignore` 永远不命中（文件名本身匹配排除模式）。
# 这是实测踩到的坑，git check-ignore 直接问 git 更可靠，也跳过这个陷阱。
if git check-ignore -q game/sound/__probe__.mid 2>/dev/null; then
    log "  [PASS] .gitignore 生效：game/sound/*.mid 被忽略"
else
    log "  [FAIL] .gitignore 未挡住 game/sound/*.mid（母带会被误提交）"
    fail=$((fail + 1))
fi

# ------------------------------------------- 2. 清单来源可解析（本地有则校验 md5）
log "=== STEP: 清单来源可用性 ==="
if [ -f "$MANIFEST" ]; then
    n_src=0; n_ok=0; n_bad=0
    while IFS=$'	' read -r stem md5 src dur; do
        case "$stem" in ''|'#'*) continue ;; esac
        [ "$src" = "-" ] && continue
        [ -r "$src" ] || continue
        n_src=$((n_src + 1))
        got=""
        if command -v md5sum >/dev/null 2>&1; then
            got=$(md5sum "$src" | cut -d' ' -f1)
        elif command -v md5 >/dev/null 2>&1; then
            got=$(md5 -q "$src")
        fi
        if [ -z "$got" ]; then
            n_bad=$((n_bad + 1))     # 没 md5 工具时不算失败，仅计数
        elif [ "$got" = "$md5" ]; then
            n_ok=$((n_ok + 1))
        else
            log "  [FAIL] $src 的 md5 与清单不符（清单 $md5 / 实际 $got）"
            n_bad=$((n_bad + 1))
        fi
    done < "$MANIFEST"
    if [ "$n_src" -eq 0 ]; then
        log "  [SKIP] 本地没有 reference/allmods，无法校验清单来源"
        skip=$((skip + 1))
    elif [ "$n_bad" -eq 0 ]; then
        log "  [PASS] $n_ok/$n_src 个来源 md5 校验通过"
    else
        log "  [FAIL] $n_bad 个来源异常"
        fail=$((fail + 1))
    fi
else
    log "  [SKIP] 无清单"
    skip=$((skip + 1))
fi

# --------------------------------------------------- 3. 时长必须贴近母带长度
# 原版转码产物比母带长 3.4%..21.2%（多出来的正是尾静音与速度偏移）；
# 32k q4 重渲染后 0.99..1.08。阈值 [0.90, 1.15]：旧产物有多首越界，新产物全部在内。
#
# 母带长度直接取自 tools/base-music-manifest.tsv 的第 4 列（由 tools/midiinfo.lua
# 预先算好），因此**不需要母带在盘上**，也不需要 lua。
log "=== STEP: OGG 时长 / 母带长度 比值 ∈ [0.90, 1.15] ==="
if ! have_ff; then
    log "  [SKIP] 无 ffprobe"
    skip=$((skip + 1))
elif [ ! -f "$MANIFEST" ]; then
    log "  [FAIL] 缺 $MANIFEST"
    fail=$((fail + 1))
else
    n_ratio=0; n_bad_ratio=0
    worst_dev=""; worst_name=""
    while IFS=$'	' read -r stem md5 src midur; do
        case "$stem" in ''|'#'*) continue ;; esac
        ogg="game/sound/$stem.ogg"
        if [ ! -s "$ogg" ]; then
            log "  [FAIL] 缺 OGG: $ogg"
            n_bad_ratio=$((n_bad_ratio + 1))
            continue
        fi
        odur=$(printf '%s' "$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$ogg" 2>/dev/null)" | tr -d '
')
        if [ -z "$odur" ] || [ -z "$midur" ]; then
            log "  [FAIL] $stem: 时长不可读（ogg=$odur midi=$midur）"
            n_bad_ratio=$((n_bad_ratio + 1))
            continue
        fi
        n_ratio=$((n_ratio + 1))
        ratio=$(awk -v a="$odur" -v b="$midur" 'BEGIN { printf "%.4f", a / b }')
        bad=$(awk -v r="$ratio" 'BEGIN { print (r < 0.90 || r > 1.15) ? 1 : 0 }')
        dev=$(awk -v r="$ratio" 'BEGIN { d = r - 1; if (d < 0) d = -d; printf "%.4f", d }')
        if [ "$bad" -eq 1 ]; then
            log "  [FAIL] $stem: ogg=${odur}s midi=${midur}s ratio=$ratio（被转码/加了尾静音）"
            n_bad_ratio=$((n_bad_ratio + 1))
        fi
        if [ -z "$worst_dev" ]; then
            worst_dev="$dev"; worst_name="$stem"
        else
            better=$(awk -v a="$dev" -v b="$worst_dev" 'BEGIN { print (a > b) ? 1 : 0 }')
            if [ "$better" -eq 1 ]; then worst_dev="$dev"; worst_name="$stem"; fi
        fi
    done < "$MANIFEST"
    if [ "$n_bad_ratio" -eq 0 ]; then
        log "  [PASS] $n_ratio 首比值全部在区间内（最大偏离 ${worst_dev} @ ${worst_name}）"
    else
        log "  [FAIL] $n_bad_ratio/$n_ratio 首越界（重渲染：./tools/render-base-music.sh）"
        fail=$((fail + 1))
    fi
fi

# ------------------------------------------- 4. 真峰值不得超标（削波检测）
# 旧产物 15/25 首 > 0 dBFS。新产物全部 ≤ -1.0 dBTP。
log "=== STEP: 真峰值 ≤ -1.0 dBTP ==="
if have_ff; then
    n_clip=0
    n_tp=0
    worst=-99
    worst_name=""
    for ogg in game/sound/game*.ogg; do
        [ -f "$ogg" ] || continue
        n_tp=$((n_tp + 1))
        tp=$("$FFMPEG" -hide_banner -nostats -i "$ogg" -af ebur128=peak=true -f null - 2>&1 \
             | sed -n 's/.*Peak: *\([-0-9.]*\) dBFS/\1/p' | tail -1)
        if [ -z "$tp" ]; then
            log "  [FAIL] $ogg 真峰值测量失败"
            n_clip=$((n_clip + 1))
            continue
        fi
        over=$(awk -v a="$tp" -v b="-1.0" 'BEGIN { print (a > b) ? 1 : 0 }')
        if [ "$over" -eq 1 ]; then
            log "  [FAIL] $ogg 真峰值 $tp dBTP > -1.0"
            n_clip=$((n_clip + 1))
        fi
        worst=$(awk -v a="$tp" -v b="$worst" 'BEGIN { print (a > b) ? a : b }')
        worst_name="$ogg"
    done
    if [ "$n_clip" -eq 0 ]; then
        log "  [PASS] $n_tp 首全部达标（最高 $worst dBTP @ $worst_name）"
    else
        log "  [FAIL] $n_clip/$n_tp 首真峰值超标（最快修法：./tools/render-base-music.sh）"
        fail=$((fail + 1))
    fi
else
    log "  [SKIP] 无 ffmpeg"
    skip=$((skip + 1))
fi

# ------------------------------------------------ 5. 响度跨度不得过大
# 旧产物跨度 18.2 LU（-26.1..-7.9）。新产物 1.6 LU。阈值 4 LU。
log "=== STEP: 整轨响度跨度 ≤ 4 LU ==="
if have_ff; then
    lo=""; hi=""
    for ogg in game/sound/game*.ogg; do
        [ -f "$ogg" ] || continue
        I=$("$FFMPEG" -hide_banner -nostats -i "$ogg" -af ebur128=peak=true -f null - 2>&1 \
            | sed -n 's/.*I: *\([-0-9.]*\) LUFS.*/\1/p' | tail -1)
        [ -n "$I" ] || continue
        if [ -z "$lo" ]; then lo="$I"; hi="$I"; else
            lo=$(awk -v a="$I" -v b="$lo" 'BEGIN { print (a < b) ? a : b }')
            hi=$(awk -v a="$I" -v b="$hi" 'BEGIN { print (a > b) ? a : b }')
        fi
    done
    if [ -z "$lo" ]; then
        log "  [FAIL] 一首响度都没测出来"
        fail=$((fail + 1))
    else
        span=$(awk -v a="$hi" -v b="$lo" 'BEGIN { printf "%.2f", a - b }')
        over=$(awk -v s="$span" 'BEGIN { print (s > 4) ? 1 : 0 }')
        if [ "$over" -eq 1 ]; then
            log "  [FAIL] 响度跨度 ${span} LU（${lo}..${hi} LUFS）> 4 LU"
            fail=$((fail + 1))
        else
            log "  [PASS] 响度跨度 ${span} LU（${lo}..${hi} LUFS）"
        fi
    fi
else
    log "  [SKIP] 无 ffmpeg"
    skip=$((skip + 1))
fi

# ---------------------------------------------------- 6. 负向对照：旧特征必须消失
# 断言「旧产物的指纹」不再出现：OGG 里不能再有统一的 ~112 kbps / 48 kHz 组合下
# 真峰值 > 0 的样本（已被第 4 步覆盖）。这里改为守渲染脚本本身的关键参数，
# 防止有人把归一化 / 去静音 / 音色库又改回去。
log "=== STEP: 渲染脚本参数 ==="
RS=tools/render-base-music.sh
if [ -x "$RS" ]; then
    log "  [PASS] $RS 可执行"
else
    log "  [FAIL] $RS 缺失或不可执行"
    fail=$((fail + 1))
fi
if bash -n "$RS" 2>>"$LOG"; then
    log "  [PASS] 语法正确"
else
    log "  [FAIL] 语法错误"
    fail=$((fail + 1))
fi
if grep -q 'silenceremove' "$RS"; then
    log "  [PASS] 保留去尾部静音"
else
    log "  [FAIL] 缺 silenceremove（会带回 3 s 尾静音）"
    fail=$((fail + 1))
fi
if grep -q 'loudnorm' "$RS"; then
    log "  [PASS] 保留响度归一化"
else
    log "  [FAIL] 缺 loudnorm（会带回 18 dB 响度差）"
    fail=$((fail + 1))
fi
if grep -q 'mid.sf2' "$RS"; then
    log "  [PASS] 默认使用原版 mid.sf2 音色库"
else
    log "  [FAIL] 未默认使用原版 mid.sf2"
    fail=$((fail + 1))
fi

# --------------------------------------------------------------- 汇总
log "============================================"
if [ "$fail" -eq 0 ]; then
    log "[ ok ] 全部通过（跳过 $skip 项）"
    exit 0
else
    log "[FAIL] $fail 项失败（跳过 $skip 项）"
    exit 1
fi
