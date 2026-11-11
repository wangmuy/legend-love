#!/usr/bin/env bash
#
# render-music.sh — 用真实音色库把 MOD 的 MIDI 预渲染成 OGG
#
# 为什么需要这个脚本
# ------------------
# LÖVE 11.5 通过内置的 libmodplug.so.1（336 KB）合成 MIDI，实测它**完全忽略
# 外部音色库**——把 128 个 GUS .pat 全指向同一个低音鼓采样，输出仍逐字节相同。
# 因此 LÖVE 直放 MIDI 只能听到内置的薄合成音色：
#
#   libmodplug 直放 MIDI      过零率 4749 Hz  差分/RMS 0.338
#   timidity + FluidR3 → OGG  过零率 2208 Hz  差分/RMS 0.154   ← 与无损基准一致
#
# 高频能量差 2.1 倍，主观上就是「刺耳、单薄、电子味重」。唯一可行的修法是
# 离线渲染：用 timidity + 真实 SoundFont 生成 .ogg，放进 mods/<slug>/music/。
# 运行时 lib_love.lua 的探测顺序是 .ogg → .mp3 → .mid，所以 .ogg 会自动
# 优先，无需改任何游戏代码。
#
# 产物
# ----
#   game/mods/<slug>/music/game<NN>.ogg
#
# 这些文件不会被 mod_build.lua 的 rmdirp() 删除（该脚本已加保护逻辑）。
#
# 用法
# ----
#   ./tools/render-music.sh Dragon          # 渲染单个 MOD
#   ./tools/render-music.sh --all           # 渲染全部已构建的 MOD
#   ./tools/render-music.sh --all --force   # 重新渲染（覆盖已有 ogg）
#   ./tools/render-music.sh --list          # 只列出待渲染情况
#
# 环境变量
#   TIMIDITY     timidity 可执行文件（默认 timidity）
#   OGG_QUALITY  ffmpeg libvorbis 质量档 0..10（默认 3；实测 q3 音质偏差 +0.1%）
#
# 依赖：timidity（含 SoundFont 配置）、ffmpeg（libvorbis 编码）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"
MODS_DIR="$GAME_DIR/mods"
SRC_DIR="$ROOT_DIR/reference/allmods"

TIMIDITY="${TIMIDITY:-timidity}"
OGG_QUALITY="${OGG_QUALITY:-3}"

info()  { echo "[info] $*"; }
ok()    { echo "[ ok ] $*"; }
warn()  { echo "[warn] $*" >&2; }
die()   { echo "[fail] $*" >&2; exit 1; }

# ---------- 依赖检查 ----------
command -v "$TIMIDITY" >/dev/null 2>&1 || die "找不到 timidity，请安装：sudo apt install timidity fluid-soundfont-gm"
command -v ffmpeg    >/dev/null 2>&1 || die "找不到 ffmpeg，请安装：sudo apt install ffmpeg"

# timidity 必须能找到 SoundFont，否则渲染出来依旧是空音色
find_timidity_cfg() {
    local d
    for d in /etc/timidity /usr/share/timidity /usr/local/share/timidity /usr/share/midi; do
        if [ -r "$d/timidity.cfg" ]; then echo "$d"; return 0; fi
    done
    return 1
}
CFG_DIR="$(find_timidity_cfg || true)"
if [ -z "$CFG_DIR" ]; then
    warn "找不到 timidity.cfg，timidity 会退化为无音色渲染。"
    warn "  sudo apt install fluid-soundfont-gm"
    die  "中断：没有音色库时渲染毫无意义"
fi
info "音色库配置: $CFG_DIR/timidity.cfg"

# ---------- 工具函数 ----------
# 列出已构建的 MOD（mods/ 下有 music/ 的目录）
list_built_mods() {
    local d
    for d in "$MODS_DIR"/*/; do
        [ -d "$d" ] || continue
        [ -d "$d/music" ] || continue
        basename "$d"
    done
}

# 源侧 MIDI 数量
count_src_mid() {
    local slug="$1"
    find "$SRC_DIR/kys-$slug/music" -maxdepth 1 -type f -name '*.mid' 2>/dev/null | wc -l
}

# 已渲染 OGG 数量
count_ogg() {
    local slug="$1"
    find "$MODS_DIR/$slug/music" -maxdepth 1 -type f -name '*.ogg' 2>/dev/null | wc -l
}

# 渲染单个 MOD
render_one() {
    local slug="$1" force="${2:-0}"
    local music="$MODS_DIR/$slug/music"
    local n_src n_ogg
    n_src="$(count_src_mid "$slug")"
    n_ogg="$(count_ogg "$slug")"

    if [ "$n_src" -eq 0 ]; then
        info "$slug: 无源 MIDI，跳过"
        return 0
    fi
    if [ "$force" -eq 0 ] && [ "$n_ogg" -ge "$n_src" ]; then
        info "$slug: 已渲染 $n_ogg/$n_src，跳过（--force 可重渲染）"
        return 0
    fi

    info "$slug: 渲染 $n_src 首 MIDI -> OGG (q=$OGG_QUALITY)"
    local mid name out tmpwav
    local done_n=0 skip_n=0 fail_n=0
    for mid in "$music"/*.mid; do
        [ -f "$mid" ] || continue
        name="$(basename "$mid" .mid)"
        local target="$music/$name.ogg"
        if [ "$force" -eq 0 ] && [ -s "$target" ]; then
            skip_n=$((skip_n + 1)); continue
        fi
        tmpwav="${TMPDIR:-/tmp}/render_$$_$name.wav"
        # timidity 无法控制 ogg 质量（-q 对其无效，实测体积恒定），
        # 所以先出无损 WAV，再用 ffmpeg 编码 vorbis。
        if ! "$TIMIDITY" -Ow -o "$tmpwav" "$mid" >/dev/null 2>&1; then
            warn "$slug/$name: timidity 渲染失败"
            fail_n=$((fail_n + 1)); rm -f "$tmpwav"; continue
        fi
        if ! ffmpeg -y -v quiet -i "$tmpwav" -c:a libvorbis -q:a "$OGG_QUALITY" "$target" 2>/dev/null; then
            warn "$slug/$name: ffmpeg 编码失败"
            fail_n=$((fail_n + 1)); rm -f "$tmpwav" "$target"; continue
        fi
        rm -f "$tmpwav"
        done_n=$((done_n + 1))
    done
    ok "$slug: 新渲染 $done_n，跳过 $skip_n，失败 $fail_n（现有 ogg $(count_ogg "$slug")/$n_src）"
    [ "$fail_n" -eq 0 ] || return 1
    return 0
}

# ---------- 参数解析 ----------
MODE="one"; TARGET=""; FORCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --all)   MODE="all"; shift ;;
        --list)  MODE="list"; shift ;;
        --force) FORCE=1; shift ;;
        -h|--help) sed -n '2,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "未知参数: $1" ;;
        *)  TARGET="$1"; shift ;;
    esac
done

case "$MODE" in
    list)
        printf '%-18s %8s %8s\n' "MOD" "源MIDI" "已渲染"
        local_total_mid=0; local_total_ogg=0
        for slug in $(list_built_mods); do
            n_src="$(count_src_mid "$slug")"; n_ogg="$(count_ogg "$slug")"
            printf '%-18s %8s %8s\n' "$slug" "$n_src" "$n_ogg"
            local_total_mid=$((local_total_mid + n_src))
            local_total_ogg=$((local_total_ogg + n_ogg))
        done
        echo "--------------------------------------------"
        printf '%-18s %8s %8s\n' "合计" "$local_total_mid" "$local_total_ogg"
        [ "$local_total_ogg" -ge "$local_total_mid" ] && echo "状态: 已全部渲染" || echo "状态: 尚未全部渲染"
        ;;
    one)
        [ -n "$TARGET" ] || die "请指定 MOD 名，或用 --all / --list"
        slug="${TARGET#kys-}"
        [ -d "$MODS_DIR/$slug" ] || die "MOD 未构建: $MODS_DIR/$slug（先运行 tools/run-mod.sh 或 mod_build.lua）"
        render_one "$slug" "$FORCE"
        ;;
    all)
        any_fail=0
        for slug in $(list_built_mods); do
            render_one "$slug" "$FORCE" || any_fail=1
        done
        exit "$any_fail"
        ;;
esac
