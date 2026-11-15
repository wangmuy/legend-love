#!/usr/bin/env bash
#
# render-base-music.sh — 用真实音色库把**原版**（game/sound）的 MIDI 母带重新渲染成 OGG
#
# 为什么需要这个脚本
# ------------------
# game/sound/game01..25.ogg 是「转码的转码」：原始 MIDI → 某次渲染 → opus
# （Lavf62/libopus）→ ogg（Lavf60/libvorbis，~112 kbps）。两次有损压缩 + 当时的
# 响度处理留下了可测的损伤：
#
#   25 首里有 15 首解码后真峰值 > 0 dBFS（最高 +3.20 dBFS）——播出来就是削波
#   整体响度 -26.1 .. -7.9 LUFS，跨度 18.2 dB——曲目之间忽大忽小
#   game01 有 77.6% 的能量在 200 Hz 以下（真实音色库渲染只有 40.6%）——发闷
#
# 而 reference/allmods/kys-pascal 的原版 Pascal 程序（kys.exe）是
#   FluidSynth + 自带音色库 music/mid.sf2（Roland GS 16-bit，3.26 MB）
# 实时合成 MIDI 的——这正是用户认为「好听」的那一版。它的 music/1..23.mid 与
# 本仓库原版 MIDI 母带**逐字节相同**（23/25 精确 md5 命中）。
#
# 为什么是 32 kHz 而不是 48 kHz
# -------------------------------
# 解析原版音色库 music/mid.sf2 的 shdr 样本头：492/495 个样本是 **22050 Hz**
# （3 个 24000 Hz）。FluidSynth 的合成上限因此只有约 11 kHz。
# 母带实测印证：25 首里 >11 kHz 的相对能量在 -26 dB（最亮）到 -68 dB 之间，
# 平均约 -33 dB —— 即 48 kHz 容器里 11~24 kHz 装的基本是重采样镜像与量化噪声。
#
# 同一把尺子量（6 首代表曲逐频段比对）：
#   48 kHz q5  频谱形状偏差 0.26 dB  25 首 26.3 MB
#   32 kHz q4  频谱形状偏差 0.57 dB  25 首 20.1 MB   ← 选它
#   32 kHz q3  频谱形状偏差 0.67 dB  25 首 17.2 MB   （SNR 掉 2.7 dB，不划算）
#
# 即 32 kHz 把省下的码率全部用在有内容的 0~16 kHz 上，客观指标与 48 kHz 同档，
# 体积却少 23%。
#
# 所以修法不是「再转一次码」，而是**从 MIDI 母带重新渲染**：
#   MIDI 母带 (game/sound/gameNN.mid)
#     → FluidSynth + SoundFont
#     → 去尾部静音 / 响度归一化到 -16 LUFS、真峰值 ≤ -1.5 dBTP
#     → libvorbis q4 @ 32 kHz
#     → game/sound/gameNN.ogg
#
# 产物
# ----
#   game/sound/game<NN>.ogg   （覆盖旧的转码产物）
#
# MIDI 母带**不入 git**（用户要求，避免仓库膨胀）：本脚本按以下顺序现找母带
#   1) game/sound/game<NN>.mid              （手工放进去的，优先级最高）
#   2) reference/allmods/kys-*/music/*.mid  （按 md5 反查，该目录已 gitignore）
#   3) bak/sound/game25.MID                 （只对 game25 有效；目录若已删则跳过）
# 实测 25/25 都能从 2)/3) 找到（23 首在 kys-pascal，game01 在 kys-awaken/dream 等，
# game25 在 bak）。找不到时会明确报错并给出补救命令。
#
# 用法
# ----
#   ./tools/render-base-music.sh              # 渲染全部 25 首
#   ./tools/render-base-music.sh game01 game07  # 只渲染指定的几首
#   ./tools/render-base-music.sh --list       # 只报告现状
#
# 环境变量
#   SF2          音色库路径（默认：reference/allmods/kys-pascal/music/mid.sf2，
#                找不到时回退 /usr/share/sounds/sf2/FluidR3_GM.sf2）
#   FLUIDSYNTH   fluidsynth 可执行文件（默认 fluidsynth）
#   FFMPEG       ffmpeg 可执行文件（默认 ffmpeg）
#   OGG_QUALITY  libvorbis 质量档 0..10（默认 4）
#   SAMPLE_RATE  渲染与编码采样率（默认 32000，见上文「为什么是 32 kHz」）
#   GAIN         FluidSynth 渲染增益（默认 0.25；宁可后面提，也不要在合成阶段削波）
#   TARGET_LUFS  响度归一化目标（默认 -16）
#   TARGET_TP    真峰值上限 dBTP（默认 -2.0；libvorbis 编码会再把峰值抬高约
#                0.3~0.6 dB，所以留出余量，成品稳定落在 -1.5 dBTP 以下）
#
# 依赖：fluidsynth（含一个 SoundFont）、ffmpeg（libvorbis 编码 + loudnorm）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOUND_DIR="$ROOT_DIR/game/sound"

FLUIDSYNTH="${FLUIDSYNTH:-fluidsynth}"
FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"
OGG_QUALITY="${OGG_QUALITY:-4}"
GAIN="${GAIN:-0.25}"
TARGET_LUFS="${TARGET_LUFS:--16}"
TARGET_TP="${TARGET_TP:--2.0}"
SAMPLE_RATE="${SAMPLE_RATE:-32000}"
MANIFEST="$SCRIPT_DIR/base-music-manifest.tsv"

info() { echo "[info] $*"; }
ok()   { echo "[ ok ] $*"; }
warn() { echo "[warn] $*" >&2; }
die()  { echo "[fail] $*" >&2; exit 1; }

# ---------- 依赖检查 ----------
command -v "$FLUIDSYNTH" >/dev/null 2>&1 || die "找不到 fluidsynth，请安装（msys2: pacman -S mingw-w64-x86_64-fluidsynth）"
command -v "$FFMPEG"     >/dev/null 2>&1 || die "找不到 ffmpeg，请安装（msys2: pacman -S mingw-w64-x86_64-ffmpeg）"

# ---------- 音色库 ----------
pick_soundfont() {
    if [ -n "${SF2:-}" ]; then
        [ -r "$SF2" ] || die "SF2=$SF2 不可读"
        echo "$SF2"; return 0
    fi
    local c
    for c in \
        "$ROOT_DIR/reference/allmods/kys-pascal/music/mid.sf2" \
        /usr/share/sounds/sf2/FluidR3_GM.sf2 \
        /usr/share/soundfonts/FluidR3_GM.sf2 \
        /usr/share/sounds/sf2/default-GM.sf2
    do
        [ -r "$c" ] && { echo "$c"; return 0; }
    done
    return 1
}
SOUNDFONT="$(pick_soundfont || true)"
[ -n "$SOUNDFONT" ] || die "找不到 SoundFont；用 SF2=/path/to/x.sf2 指定（推荐原版 mid.sf2）"
info "音色库: $SOUNDFONT"
info "渲染增益: $GAIN   采样率: $SAMPLE_RATE Hz   响度目标: $TARGET_LUFS LUFS / 真峰值 ≤ $TARGET_TP dBTP   Vorbis q=$OGG_QUALITY"

# ---------- 工具函数 ----------
# 逐首渲染：FluidSynth 出无损 WAV → 去尾静音 + 两遍 loudnorm → Vorbis
render_one() {
    local stem="$1"
    local out="$SOUND_DIR/$stem.ogg"
    local mid
    if ! mid="$(ensure_master "$stem")"; then
        warn "$stem: 找不到母带（清单来源与 git 历史都没有）"
        warn "        手工放置：cp <某个 .mid> $SOUND_DIR/$stem.mid"
        return 1
    fi

    local tmpdir; tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/render_base_XXXXXX")"
    local raw="$tmpdir/raw.wav" adj="$tmpdir/adj.wav"

    # 1) 合成（-F fast-render 直接写 WAV，-ni 不要 MIDI 输入，-q 静音横幅）
    if ! "$FLUIDSYNTH" -ni -q -r "$SAMPLE_RATE" -g "$GAIN" -F "$raw" "$SOUNDFONT" "$mid" >/dev/null 2>&1; then
        warn "$stem: fluidsynth 渲染失败"; rm -rf "$tmpdir"; return 1
    fi

    # 2) 第一遍：只测量响度参数
    local measure
    measure="$("$FFMPEG" -hide_banner -nostats -i "$raw" \
        -af "silenceremove=stop_periods=-1:stop_duration=0.4:stop_threshold=-55dB,loudnorm=I=${TARGET_LUFS}:TP=${TARGET_TP}:LRA=11:print_format=json" \
        -f null - 2>&1 | sed -n '/{/,/}/p')"
    local in_i in_tp in_lra in_th
    in_i="$(printf '%s' "$measure"  | sed -n 's/.*"input_i" : "\([-0-9.]*\)".*/\1/p')"
    in_tp="$(printf '%s' "$measure" | sed -n 's/.*"input_tp" : "\([-0-9.]*\)".*/\1/p')"
    in_lra="$(printf '%s' "$measure"| sed -n 's/.*"input_lra" : "\([-0-9.]*\)".*/\1/p')"
    in_th="$(printf '%s' "$measure" | sed -n 's/.*"input_thresh" : "\([-0-9.]*\)".*/\1/p')"
    [ -n "$in_i" ] || { warn "$stem: loudnorm 测量失败"; rm -rf "$tmpdir"; return 1; }

    # 3) 第二遍：linear=true 尽量不动态压缩（实测这里都能线性完成）
    if ! "$FFMPEG" -y -v error -i "$raw" \
        -af "silenceremove=stop_periods=-1:stop_duration=0.4:stop_threshold=-55dB,loudnorm=I=${TARGET_LUFS}:TP=${TARGET_TP}:LRA=11:linear=true:measured_I=${in_i}:measured_TP=${in_tp}:measured_LRA=${in_lra}:measured_thresh=${in_th}" \
        -ar "$SAMPLE_RATE" -ac 2 -c:a pcm_s16le "$adj"; then
        warn "$stem: loudnorm 应用失败"; rm -rf "$tmpdir"; return 1
    fi

    # 4) 编码
    if ! "$FFMPEG" -y -v error -i "$adj" -ar "$SAMPLE_RATE" -ac 2 -c:a libvorbis -q:a "$OGG_QUALITY" "$out"; then
        warn "$stem: vorbis 编码失败"; rm -rf "$tmpdir"; return 1
    fi

    rm -rf "$tmpdir"
    return 0
}

report_one() {
    local stem="$1"
    local f="$SOUND_DIR/$stem.ogg"
    local dur br tp
    dur="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null || echo '?')"
    br="$("$FFPROBE" -v error -show_entries format=bit_rate -of csv=p=0 "$f" 2>/dev/null || echo '?')"
    tp="$("$FFMPEG" -hide_banner -nostats -i "$f" -af ebur128=peak=true -f null - 2>&1 \
        | sed -n 's/.*Peak: *\([-0-9.]*\) dBFS/\1/p' | tail -1)"
    printf '  %-8s dur=%6.1fs  %6s kbps  真峰值 %6s dBTP\n' \
        "$stem" "${dur%.*}" "$(( ${br:-0} / 1000 ))" "${tp:-?}"
}

# ---------- 参数解析 ----------
MODE="all"; TARGETS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --list) MODE="list"; shift ;;
        -h|--help) sed -n '2,74p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "未知参数: $1" ;;
        *) TARGETS+=("$1"); shift ;;
    esac
done

if [ ${#TARGETS[@]} -gt 0 ]; then
    MODE="some"
fi

# 清单里的全部曲目（不依赖 game/sound 下是否已有 .mid）
list_stems() {
    local stem md5 src _rest
    while IFS=$'	' read -r stem md5 src _rest; do
        case "$stem" in ''|'#'*) continue ;; esac
        echo "$stem"
    done < "$MANIFEST"
}

# 清单里某曲目的 md5（用于校验恢复出来的母带）
manifest_md5() {
    local want="$1" stem md5 src _rest
    while IFS=$'	' read -r stem md5 src _rest; do
        case "$stem" in ''|'#'*) continue ;; esac
        [ "$stem" = "$want" ] && { echo "$md5"; return 0; }
    done < "$MANIFEST"
    return 1
}

# 清单里某曲目的首选来源路径（"-" 表示走 git 历史）
manifest_src() {
    local want="$1" stem md5 src _rest
    while IFS=$'	' read -r stem md5 src _rest; do
        case "$stem" in ''|'#'*) continue ;; esac
        [ "$stem" = "$want" ] && { echo "$src"; return 0; }
    done < "$MANIFEST"
    return 1
}

md5_of() {
    if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then md5 -q "$1"
    else echo "nomd5"; fi
}

# 把某曲目的母带恢复/定位到 $SOUND_DIR/<stem>.mid。
# 顺序：已有且 md5 正确 -> 清单来源 -> git 历史。
ensure_master() {
    local stem="$1"
    local dst="$SOUND_DIR/$stem.mid"
    local want; want="$(manifest_md5 "$stem" || true)"

    if [ -r "$dst" ]; then
        if [ -z "$want" ] || [ "$(md5_of "$dst")" = "$want" ]; then
            echo "$dst"; return 0
        fi
        warn "$stem: 现有母带 md5 不符，尝试重新获取"
    fi

    local src; src="$(manifest_src "$stem" || true)"

    # 1) 清单来源（reference/ 下，已 gitignore）
    if [ -n "$src" ] && [ "$src" != "-" ] && [ -r "$ROOT_DIR/$src" ]; then
        mkdir -p "$SOUND_DIR"
        cp "$ROOT_DIR/$src" "$dst"
        if [ -z "$want" ] || [ "$(md5_of "$dst")" = "$want" ]; then
            echo "$dst"; return 0
        fi
        warn "$stem: 从 $src 复制的母带 md5 不符"
        rm -f "$dst"
    fi

    # 2) git 历史（转码前的那一份 MIDI 母带）
    #
    # 不能写死提交 SHA：历史一旦被 tools/purge-audio-history.sh 重写，SHA 全变。
    # 所以按**路径**在全部历史里回溯。同时兼顾历史上出现过的三种路径与大小写：
    #   bin/sound/gameNN.mid / .MID  （SDL 版）
    #   src/sound/gameNN.mid / .MID  （更早的 src/ 布局）
    if command -v git >/dev/null 2>&1 && [ -d "$ROOT_DIR/.git" ]; then
        local path sha
        for path in "bin/sound/$stem.mid" "bin/sound/$stem.MID"                     "src/sound/$stem.mid" "src/sound/$stem.MID"; do
            # 关键：必须用 `rev-list --full-history`，不能用 `git log -1 -- path`。
            # 后者会做「历史简化」，把「删除该文件」的那次提交当成终点返回，
            # 而那次提交里文件已经不存在 —— cat-file 必然失败。
            # rev-list --full-history 会列出所有触及该路径的提交，逐个试即可。
            mkdir -p "$SOUND_DIR"
            for sha in $(git -C "$ROOT_DIR" rev-list --all --full-history -- "$path" 2>/dev/null); do
                git -C "$ROOT_DIR" cat-file -e "$sha:$path" 2>/dev/null || continue
                if git -C "$ROOT_DIR" show "$sha:$path" > "$dst" 2>/dev/null; then
                    if [ -z "$want" ] || [ "$(md5_of "$dst")" = "$want" ]; then
                        echo "$dst"; return 0
                    fi
                fi
                rm -f "$dst"
            done
        done
    fi

    return 1
}

case "$MODE" in
    list)
        printf '%-10s %8s %10s %10s
' "曲目" "OGG" "本地母带" "恢复来源"
        have_local=0; have_ogg=0; total=0
        for stem in $(list_stems); do
            total=$((total+1))
            o="-"; [ -s "$SOUND_DIR/$stem.ogg" ] && { o="有"; have_ogg=$((have_ogg+1)); }
            if [ -s "$SOUND_DIR/$stem.mid" ]; then
                m="有"; have_local=$((have_local+1)); src="本地"
            else
                m="缺"
                src="$(manifest_src "$stem" || true)"
                case "$src" in
                    ''|'-') src="git 历史" ;;
                esac
            fi
            printf '%-10s %8s %10s %10s
' "$stem" "$o" "$m" "$(echo "$src" | sed 's|reference/allmods/||')"
        done
        echo "--------------------------------------------------------"
        printf '共 %d 首 | OGG %d | 本地母带 %d（其余可按清单自动恢复）
' "$total" "$have_ogg" "$have_local"
        ;;
    all|some)
        if [ "$MODE" = "all" ]; then
            TARGETS=($(list_stems))
        fi
        [ ${#TARGETS[@]} -gt 0 ] || die "没有可渲染的 MIDI 母带（$SOUND_DIR/game*.mid）"
        fail=0
        for stem in "${TARGETS[@]}"; do
            stem="${stem%.mid}"; stem="${stem%.ogg}"
            if render_one "$stem"; then
                report_one "$stem"
            else
                fail=$((fail+1))
            fi
        done
        echo "------------------------------------"
        if [ "$fail" -eq 0 ]; then
            ok "全部完成（${#TARGETS[@]} 首）"
        else
            warn "完成，但有 $fail 首失败"
            exit 1
        fi
        ;;
esac
