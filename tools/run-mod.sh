#!/usr/bin/env bash
#
# run-mod.sh — 启动金庸群侠传 Love2D（支持 allmods MOD 选择）
#
# 功能：
#   1. 检测 love 可执行文件（love / love2d / love.AppImage / 环境变量 LOVE）
#   2. 统计并列出可用 MOD（reference/allmods/kys-*）
#   3. 交互式（或命令行参数）选择 MOD
#   4. 若 MOD 数据包未构建（或产物不完整，如缺 music/）则自动重建
#   5. 报告音频就绪情况（mid/mp3/ogg 数量）
#   6. 写入 game/active_mod.txt 并启动游戏
#
# 用法：
#   ./tools/run-mod.sh                 # 交互式选择 MOD
#   ./tools/run-mod.sh mingdong        # 直接启动指定 MOD（接受 mingdong 或 kys-mingdong）
#   ./tools/run-mod.sh --list          # 只列出 MOD，不启动
#   ./tools/run-mod.sh --vanilla       # 不激活任何 MOD（原版，删除 active_mod.txt）
#   ./tools/run-mod.sh --no-build      # 跳过自动构建检查
#   LOVE=/path/to/love ./tools/run-mod.sh mingdong
#
# 环境变量：
#   LOVE        love 可执行文件路径（优先）
#   NO_BUILD    设为 1 等同 --no-build
#
set -euo pipefail

# ---------- 定位仓库根（脚本位于 <root>/tools/） ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GAME_DIR="$ROOT_DIR/game"
MODS_SRC_DIR="$ROOT_DIR/reference/allmods"
MODS_OUT_DIR="$GAME_DIR/mods"
ACTIVE_FILE="$GAME_DIR/active_mod.txt"

# ---------- 颜色（非 tty 时禁用） ----------
if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
    C_BLU=$'\033[34m'; C_BLD=$'\033[1m';  C_RST=$'\033[0m'
else
    C_RED=; C_GRN=; C_YEL=; C_BLU=; C_BLD=; C_RST=
fi
info()  { printf '%s\n' "${C_BLU}[info]${C_RST} $*"; }
ok()    { printf '%s\n' "${C_GRN}[ ok ]${C_RST} $*"; }
warn()  { printf '%s\n' "${C_YEL}[warn]${C_RST} $*"; }
die()   { printf '%s\n' "${C_RED}[fail]${C_RST} $*" >&2; exit 1; }

# ---------- 1. 检测 love ----------
find_love() {
    if [ -n "${LOVE:-}" ]; then
        [ -x "$LOVE" ] || die "LOVE 环境变量指向的文件不可执行: $LOVE"
        echo "$LOVE"; return 0
    fi
    local cand
    for cand in \
        "$ROOT_DIR/love.AppImage" \
        "$HOME/bin/love.AppImage" \
        "$HOME/.local/bin/love.AppImage" \
        "/usr/local/bin/love" \
        "/usr/bin/love" \
        "/snap/bin/love"; do
        if [ -x "$cand" ]; then echo "$cand"; return 0; fi
    done
    for cand in love love2d; do
        if command -v "$cand" >/dev/null 2>&1; then
            command -v "$cand"; return 0
        fi
    done
    # 兜底：在常见目录里搜 love*.AppImage
    local found
    found="$(find "$HOME" -maxdepth 3 -type f -iname 'love*.AppImage' 2>/dev/null | head -n1 || true)"
    if [ -n "$found" ] && [ -x "$found" ]; then echo "$found"; return 0; fi
    return 1
}

LOVE_BIN="$(find_love || true)"
if [ -z "$LOVE_BIN" ]; then
    die "未找到 love 可执行文件。请安装 LÖVE，或用 LOVE=/path/to/love 指定，或放置 love.AppImage 于仓库根目录。"
fi
info "love 可执行文件: ${C_BLD}${LOVE_BIN}${C_RST}"

# ---------- 2. 收集 MOD ----------
# 返回行格式：<slug>|<中文名>
collect_mods() {
    [ -d "$MODS_SRC_DIR" ] || return 0
    local ini="$MODS_SRC_DIR/games.ini"
    # 从 games.ini 取中文名（去掉标注括号内容作为显示名）
    if [ -f "$ini" ]; then
        python3 - "$ini" "$MODS_SRC_DIR" <<'PY'
import os, re, sys
ini, src = sys.argv[1], sys.argv[2]
try:
    raw = open(ini, 'rb').read().decode('utf-8-sig')
except Exception:
    raw = ''
names = {}
for line in raw.splitlines():
    m = re.match(r'^\s*\d+\s*=\s*(.*?)\s*:\s*(kys-\S+)\s*$', line)
    if m:
        disp, dirname = m.group(1), m.group(2)
        disp = re.sub(r'[（(].*?[)）]', '', disp).strip()  # 去掉（好像有问题）等标注
        names[dirname] = disp
for d in sorted(os.listdir(src)):
    if not d.startswith('kys-'):
        continue
    slug = d[4:]
    print(f"{slug}|{names.get(d, slug)}")
PY
    else
        local d
        for d in "$MODS_SRC_DIR"/kys-*; do
            [ -d "$d" ] || continue
            local base; base="$(basename "$d")"
            echo "${base#kys-}|${base#kys-}"
        done
    fi
}

# 读取到数组
MOD_SLUGS=(); MOD_NAMES=()
while IFS='|' read -r slug name; do
    [ -n "$slug" ] || continue
    MOD_SLUGS+=("$slug"); MOD_NAMES+=("$name")
done < <(collect_mods)

MOD_COUNT="${#MOD_SLUGS[@]}"

# 列出 MOD。音频列把「产物是否就绪」一目了然地显示出来：
#   mid / mp3 = 已构建到 mods/<slug>/music/ 的音频数；
#   "-" = 未构建；"src:N" = 源侧有 N 个音频但产物未构建。
list_mods() {
    echo "${C_BLD}可用 MOD（共 ${MOD_COUNT} 个）${C_RST}"
    echo "  index  slug            名称                              music(mid/mp3)"
    echo "  -----  --------------  ------------------------------  --------------"
    local i
    for i in "${!MOD_SLUGS[@]}"; do
        local slug="${MOD_SLUGS[$i]}"
        local dir="$MODS_OUT_DIR/$slug/music"
        local audiostr
        if [ -d "$dir" ]; then
            local mid mp3
            mid=$(find "$dir" -maxdepth 1 -type f -name '*.mid' 2>/dev/null | wc -l)
            mp3=$(find "$dir" -maxdepth 1 -type f -name '*.mp3' 2>/dev/null | wc -l)
            audiostr="${mid}/${mp3}"
        elif [ -d "$MODS_OUT_DIR/$slug" ]; then
            audiostr="${C_YEL}缺${C_RST}"
        else
            local nsrc
            nsrc=$(find "$MODS_SRC_DIR/kys-$slug/music" -maxdepth 1 -type f \
                    \( -name '*.mid' -o -name '*.mp3' \) 2>/dev/null | wc -l)
            audiostr="src:${nsrc}"
        fi
        printf "  %5d  %-14s  %-30s  %s\n" "$((i + 1))" "$slug" "${MOD_NAMES[$i]}" "$audiostr"
    done
    echo "      0  (vanilla)       原版（不激活 MOD）           sound/*.ogg"
    echo
    echo "  ${C_YEL}缺${C_RST}=已构建但缺 music/（下次启动会自动重建）；src:N=未构建，源侧有 N 个音频"
}

# ---------- 3. 解析参数 ----------
DO_LIST=0; DO_VANILLA=0; NO_BUILD_FLAG=0; SELECTED=""
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            sed -n '3,23p' "$0" | sed -n 's/^# \{0,1\}//p'
            exit 0 ;;
        -l|--list) DO_LIST=1 ;;
        -v|--vanilla) DO_VANILLA=1 ;;
        --no-build) NO_BUILD_FLAG=1 ;;
        -*) die "未知参数: $arg（用 --help 查看用法）" ;;
        *) SELECTED="$arg" ;;
    esac
done
[ "${NO_BUILD:-0}" = "1" ] && NO_BUILD_FLAG=1

if [ "$DO_LIST" = "1" ]; then
    list_mods
    exit 0
fi

# ---------- 4. 确定选择 ----------
if [ "$DO_VANILLA" = "1" ]; then
    SELECTED=""
elif [ -n "$SELECTED" ]; then
    # 归一化：允许 kys-xxx / xxx
    SELECTED="${SELECTED#kys-}"
    # 校验存在
    local_ok=0
    for s in "${MOD_SLUGS[@]}"; do
        [ "$s" = "$SELECTED" ] && local_ok=1 && break
    done
    [ "$local_ok" = "1" ] || die "未知 MOD: $SELECTED（用 --list 查看可用列表）"
else
    # 交互式
    if [ ! -t 0 ]; then
        die "非交互环境，请显式指定 MOD：$0 <slug>  或  $0 --list"
    fi
    list_mods
    echo
    printf '%s' "${C_BLD}请选择 MOD（输入序号，0=原版，回车=原版）: ${C_RST}"
    read -r choice
    if [ -z "$choice" ] || [ "$choice" = "0" ]; then
        SELECTED=""
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$MOD_COUNT" ]; then
        SELECTED="${MOD_SLUGS[$((choice - 1))]}"
    else
        # 允许直接输入 slug
        SELECTED="${choice#kys-}"
        local_ok=0
        for s in "${MOD_SLUGS[@]}"; do
            [ "$s" = "$SELECTED" ] && local_ok=1 && break
        done
        [ "$local_ok" = "1" ] || die "无效选择: $choice"
    fi
fi

# 检查某个 MOD 产物是否完整（而不只是目录存在）。
#
# 为什么不能只看 [ -d "$dir" ]：mods/<slug>/ 一旦构建过就永久存在，
# 所以只要新增了任何构建产物类型（例如 music/），旧目录会被误判为「已就绪」
# 而跳过重建，导致新产物永远缺失（实测：删掉 mods/pig/music 后 run-mod.sh
# 报「MOD 数据包已存在」并跳过构建，music/ 再也不会回来）。
#
# 判定标准：目录存在 + data/ 非空 + 源侧有 music/ 时产物也必须有非空 music/。
mod_ready() {
    local slug="$1"
    local out="$MODS_OUT_DIR/$slug"
    [ -d "$out" ] || return 1
    # data/ 是非空目录（基本完整性）
    [ -d "$out/data" ] || return 1
    [ -n "$(ls -A "$out/data" 2>/dev/null | head -n1)" ] || return 1
    # 源侧有 MIDI/MP3 时，产物必须有 music/
    local src_music="$MODS_SRC_DIR/kys-$slug/music"
    if [ -d "$src_music" ]; then
        local n_src
        n_src="$(find "$src_music" -maxdepth 1 -type f \( -name '*.mid' -o -name '*.mp3' \) 2>/dev/null | wc -l)"
        if [ "${n_src:-0}" -gt 0 ]; then
            [ -d "$out/music" ] || return 1
            local n_out
            n_out="$(find "$out/music" -maxdepth 1 -type f \( -name '*.mid' -o -name '*.mp3' \) 2>/dev/null | wc -l)"
            [ "${n_out:-0}" -ge "$n_src" ] || return 1
        fi
    fi
    return 0
}

# 报告某 MOD 的音频就绪情况（.mid/.mp3/.ogg 数量）。
# 音频不阻塞启动：缺失只是没声音，不应让脚本失败。
report_audio() {
    local slug="$1"
    local dir="$MODS_OUT_DIR/$slug/music"
    if [ ! -d "$dir" ]; then
        warn "该 MOD 无 music/ 产物（源侧可能没有 MIDI/MP3）"
        return 0
    fi
    local mid mp3 ogg
    mid=$(find "$dir" -maxdepth 1 -type f -name '*.mid' 2>/dev/null | wc -l)
    mp3=$(find "$dir" -maxdepth 1 -type f -name '*.mp3' 2>/dev/null | wc -l)
    ogg=$(find "$dir" -maxdepth 1 -type f -name '*.ogg' 2>/dev/null | wc -l)
    ok "音频就绪: mid=${mid} mp3=${mp3} ogg=${ogg}"
    if [ "$((mid + mp3 + ogg))" -eq 0 ]; then
        warn "music/ 为空：该 MOD 场景会回退到内置 sound/gameNN.ogg"
        return 0
    fi
    # 音质提示：LÖVE 自带的 libmodplug 忽略 SoundFont，直放 .mid 会明显刺耳
    # （实测过零率 4749Hz，而真实音色库渲染是 2215Hz）。预渲染 .ogg 会优先播放。
    # 这里只提示、不自动渲染：全量渲染约需 78 分钟，不该藏在启动流程里。
    if [ "$mid" -gt 0 ] && [ "$ogg" -lt "$mid" ]; then
        warn "音质提示: 有 $mid 首 .mid 尚无预渲染 .ogg，将用 LÖVE 内置薄音色播放。"
        warn "  想要真实音色库效果：./tools/render-music.sh $slug   （约 $((mid * 5)) 秒）"
    fi
}

# ---------- 5. 构建（如需要） ----------
if [ -n "$SELECTED" ] && [ "$NO_BUILD_FLAG" != "1" ]; then
    if ! mod_ready "$SELECTED"; then
        if [ -d "$MODS_OUT_DIR/$SELECTED" ]; then
            info "MOD 产物不完整（缺 music/ 等新产物），正在重建 kys-$SELECTED ..."
        else
            info "MOD 数据包未构建，正在构建 kys-$SELECTED ..."
        fi
        ( cd "$GAME_DIR" && lua tools/mod_build.lua "kys-$SELECTED" ) \
            || die "构建失败: kys-$SELECTED"
        mod_ready "$SELECTED" || die "构建后产物仍不完整: game/mods/$SELECTED"
        ok "已构建 game/mods/$SELECTED"
        report_audio "$SELECTED"
    else
        info "MOD 数据包已存在且完整: game/mods/$SELECTED"
        report_audio "$SELECTED"
    fi
fi

# ---------- 6. 写入 active_mod.txt ----------
if [ -n "$SELECTED" ]; then
    printf '%s\n' "$SELECTED" > "$ACTIVE_FILE"
    ok "已激活 MOD: ${C_BLD}${SELECTED}${C_RST}  (写入 game/active_mod.txt)"
else
    rm -f "$ACTIVE_FILE"
    ok "未激活 MOD（原版路径）"
fi

# 若 MOD 引用 MIDI 而系统无 timidity 配置，libmodplug 会往 stderr 刷
# "load_pat > can not open /usr/local/share/timidity/timidity.cfg"。
# 设 MMPAT_PATH_TO_CFG 指向真实配置目录可消除它。
# 实测（|Dragon/game01.mid|）：设与不设的逐样本哈希完全相同
# （n=3219456 rms=0.153938 hash=172447810）⇒ 只消噪声，零音质变化。
find_timidity_cfg_dir() {
    local d
    for d in \
        /etc/timidity \
        /usr/share/timidity \
        /usr/local/share/timidity \
        /usr/share/midi; do
        if [ -r "$d/timidity.cfg" ]; then echo "$d"; return 0; fi
    done
    return 1
}

# ---------- 7. 启动 ----------
CFG_DIR="$(find_timidity_cfg_dir || true)"
if [ -n "$CFG_DIR" ]; then
    if [ -z "${MMPAT_PATH_TO_CFG:-}" ]; then
        export MMPAT_PATH_TO_CFG="$CFG_DIR"
        info "已设置 MMPAT_PATH_TO_CFG=$CFG_DIR（抑制 libmodplug 的 timidity.cfg 警告）"
    fi
else
    warn "未找到 timidity.cfg：启动时会出现 'load_pat > can not open ...' 警告"
    warn "该警告不影响音质（libmodplug 回退内置波形合成，实测逐样本哈希一致）"
    warn "如需安装：sudo apt install timidity fluid-soundfont-gm"
fi

# "Meta event not at end of track" / "ends with note on" 来自 libmodplug
# 解析 MOD 作者的不规范 MIDI（MIDI 规范要求 EOT 后再无数据）。这些警告由
# C 层直写 stderr，Lua 无法捕获，只能用 stderr 过滤。
#
# 实测 578 首：Meta 519 首、ends-with-note-on 309 首，但拿 timidity 渲染
# 521 首逐首对账，**没有一首存在内容缺失**：所有“LÖVE 更短”的超出段都是
# 最后一音的自然衰减拖尾（m0403 超出段 RMS 0.33→0.058→0.0076→0.0006）。
# 因此这些警告只是噪声，不影响听感。
# FUZZY_MIDI_WARN=0 可关闭过滤（用于排查）。
quiet_libmodplug() {
    [ "${FUZZY_MIDI_WARN:-1}" = "0" ] && return 0
    if [ -t 1 ]; then
        info "已过滤 libmodplug 解析噪声（FUZZY_MIDI_WARN=0 可关闭）"
    fi
    exec 3>&1
    exec 1>&3 2> >(grep -vE '^(load_pat|load_mid) > ' >&2)
}

info "启动游戏：cd game && $LOVE_BIN ."
echo
cd "$GAME_DIR"
quiet_libmodplug
exec "$LOVE_BIN" .
