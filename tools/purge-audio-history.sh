#!/usr/bin/env bash
#
# purge-audio-history.sh — 把音乐资源从 git 历史里彻底移除，缩小仓库
#
# ⚠️ 这是**破坏性操作**：它会重写所有提交的 SHA。执行前必读：
#
#   1. 所有协作者必须重新 clone（旧 clone 无法正常 pull）
#   2. 远程需要 force push（`git push --force --all` + `--tags`）
#   3. 已有的 PR / issue 里指向提交的链接会失效
#   4. 必须在**所有人都不在推送**的时间窗执行
#
# 为什么需要
# ----------
# 原版 BGM 曾经以 `.ogg`（19.4 MB）形式入库，另有 `bak/sound/*.opus`（25.0 MB）
# 与历史里的 `src/sound/*.ogg`（19.4 MB）——三者是同一批曲子的不同代产物。
# 即使现在把它们删掉，旧提交里仍然留着这些 blob，仓库依旧 88 MB。
#
# 实测（在 mirror clone 上跑过）：
#   清理前 .git = 88 MB
#   只删 bak/sound            -> 61 MB
#   删 bak/sound + 全部 ogg   -> **16 MB**
#
# 做法
# ----
# 用 git-filter-repo（单文件 Python 脚本，无需安装）从所有提交里移除：
#   * bak/                  （整个目录，含坏 opus）
#   * *.ogg / *.opus / *.mp3（历史所有代压缩音频）
# 保留：
#   * bin/sound/*.mid       （24 首原始 MIDI 母带，game25 也在别的路径保留）
#   * game/sound/*.wav      （音效，1.1 MB）
#   * 全新 32k q4 的 game/sound/*.ogg 会在清理**之后**重新加入
#
# 用法
# ----
#   ./tools/purge-audio-history.sh --dry-run          # 只在镜像里试跑，报告体积
#   ./tools/purge-audio-history.sh --apply            # 真的重写当前仓库
#   ./tools/purge-audio-history.sh --apply --no-backup
#
# 环境变量
#   FILTER_REPO  git-filter-repo 路径（默认找 PATH，找不到就下载到 /tmp）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="dry-run"
BACKUP=1
for a in "$@"; do
    case "$a" in
        --dry-run) MODE="dry-run" ;;
        --apply)   MODE="apply" ;;
        --no-backup) BACKUP=0 ;;
        -h|--help) sed -n '2,50p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "[fail] 未知参数: $a" >&2; exit 1 ;;
    esac
done

info() { echo "[info] $*"; }
ok()   { echo "[ ok ] $*"; }
warn() { echo "[warn] $*" >&2; }
die()  { echo "[fail] $*" >&2; exit 1; }

# ---------- git-filter-repo ----------
find_filter_repo() {
    if [ -n "${FILTER_REPO:-}" ] && [ -r "$FILTER_REPO" ]; then
        echo "$FILTER_REPO"; return 0
    fi
    if command -v git-filter-repo >/dev/null 2>&1; then
        command -v git-filter-repo; return 0
    fi
    local cached="${TMPDIR:-/tmp}/git-filter-repo"
    if [ -r "$cached" ]; then echo "$cached"; return 0; fi
    return 1
}

ensure_filter_repo() {
    local fr
    if fr="$(find_filter_repo)"; then echo "$fr"; return 0; fi
    command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 \
        || die "需要 python3 来运行 git-filter-repo"
    local py; py="$(command -v python3 || command -v python)"
    local dst="${TMPDIR:-/tmp}/git-filter-repo"
    info "下载 git-filter-repo 到 $dst ..." >&2
    command -v curl >/dev/null 2>&1 || die "需要 curl 下载 git-filter-repo"
    curl -sSL -o "$dst" https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo \
        || die "下载失败；可手工下载后设 FILTER_REPO=<path>"
    chmod +x "$dst"
    echo "$dst"
}

FILTER_REPO_BIN="$(ensure_filter_repo)"
PYTHON_BIN="$(command -v python3 || command -v python)"

# ---------- 清理规则 ----------
# 只按扩展名与目录，不按具体文件名 —— 这样每一代产物都被覆盖到。
purge_args() {
    cat <<'ARGS'
--invert-paths
--path-glob=*.ogg
--path-glob=*.opus
--path-glob=*.mp3
--path=bak
ARGS
}

repo_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

count_audio_blobs() {
    git -C "$1" rev-list --objects --all 2>/dev/null \
        | grep -Eci '\.(ogg|opus|mp3)$' || true
}

# ---------- dry-run：在镜像克隆上试跑 ----------
do_dry_run() {
    local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/purge_dry_XXXXXX")"
    info "镜像克隆到 $tmp/repo.git ..."
    git clone --mirror "$ROOT_DIR" "$tmp/repo.git" >/dev/null 2>&1 \
        || die "镜像克隆失败"

    local before after n_before n_after
    before="$(repo_size "$tmp/repo.git")"
    n_before="$(count_audio_blobs "$tmp/repo.git")"
    info "清理前: $before，音频 blob ${n_before:-0} 个"

    info "在镜像上执行 filter-repo ..."
    ( cd "$tmp/repo.git" && "$PYTHON_BIN" "$FILTER_REPO_BIN" $(purge_args) --force ) >/dev/null 2>&1 \
        || die "filter-repo 执行失败"

    after="$(repo_size "$tmp/repo.git")"
    n_after="$(count_audio_blobs "$tmp/repo.git")"
    ok "清理后: $after，音频 blob ${n_after:-0} 个"

    # 完整性：提交总数与分支列表
    local n_commits n_branches
    n_commits="$(git -C "$tmp/repo.git" rev-list --all --count 2>/dev/null || echo '?')"
    n_branches="$(git -C "$tmp/repo.git" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | tr '\n' ' ')"
    info "提交数 $n_commits，分支: ${n_branches:-（无）}"

    cat <<EOF

================================================================
dry-run 结论
  仓库体积  $before  ->  $after
  音频 blob ${n_before:-0}  ->  ${n_after:-0}
  提交数    $n_commits（与清理前一致才对）
  分支      ${n_branches:-（无）}

镜像保留在: $tmp/repo.git
  · 可以先 `git clone $tmp/repo.git /tmp/check` 验证代码完整性
  · 确认无误后再执行: ./tools/purge-audio-history.sh --apply
================================================================
EOF
}

# ---------- apply：真的重写当前仓库 ----------
do_apply() {
    cd "$ROOT_DIR"
    git rev-parse --git-dir >/dev/null 2>&1 || die "当前目录不是 git 仓库"

    # 安全检查 1：工作树必须干净（否则重写会丢改动）
    if [ -n "$(git status --porcelain)" ]; then
        die "工作树不干净。请先提交或 stash（本次改动含二进制文件，强烈建议先提交）"
    fi

    # 安全检查 2：不能在未推送的提交上执行（会一并改写）
    local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
    info "当前分支: $branch"

    # 安全检查 3：确认备份
    if [ "$BACKUP" -eq 1 ]; then
        local bak="$(dirname "$ROOT_DIR")/$(basename "$ROOT_DIR").git-backup-$(date +%Y%m%d-%H%M%S)"
        info "备份到 $bak（--mirror，含全部引用）"
        git clone --mirror "$ROOT_DIR" "$bak" >/dev/null 2>&1 || die "备份失败"
        ok "备份完成: $bak"
        info "  回滚方法: rm -rf .git && cp -a \"$bak\" .git"
    else
        warn "已跳过备份（--no-backup）——一旦出错无法回滚"
    fi

    local before after
    before="$(repo_size .git)"
    info "清理前 .git = $before"

    info "执行 filter-repo（这会重写所有提交 SHA）..."
    cd "$ROOT_DIR"
    "$PYTHON_BIN" "$FILTER_REPO_BIN" $(purge_args) --force 2>&1 | tail -5

    after="$(repo_size .git)"
    ok "清理后 .git = $after"

    # filter-repo 会移除 origin 远程，需要手动加回
    if ! git remote | grep -qx 'origin'; then
        warn "filter-repo 移除了 origin 远程，请手动加回："
        warn "  git remote add origin <原 URL>"
        warn "  $ROOT_DIR"
    fi

    cat <<EOF

================================================================
完成。接下来必须做：

1) 重新加入刚生成的音乐资源（它们已被历史清理一并移除）
     ./tools/render-base-music.sh          # 从母带重渲染 32k q4
     git add game/sound/*.ogg
     git commit -m "audio: 用 32k q4 重渲染原版 BGM"

2) 强制推送（会覆盖远程历史！先通知所有协作者）
     git push --force --all
     git push --force --tags

3) 让每个协作者重新 clone（旧 clone pull 会立刻冲突）

4) 提醒协作者：旧 PR 里的提交链接会失效

⚠️  GitHub 上的旧对象不会立刻删除，需要联系支持或在仓库 Settings 里
    等待 GC；也可以新建仓库重新推送以彻底干净。
================================================================
EOF
}

case "$MODE" in
    dry-run) do_dry_run ;;
    apply)   do_apply ;;
esac
