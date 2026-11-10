#!/usr/bin/env bash
# 主地图飘云子系统（DrawClouds）运行时取证
#
# 这些脚本以「一个独立 LÖVE 工程」的方式运行：把 game/ 下的资源与源码软链进
# 临时目录，再把本目录里的 main.lua/conf.lua 拷进去。之所以不在仓库里直接放
# 软链，是因为 `tools/build-love.sh` 用 `7z a ./game/*` 打包，7z 会跟随软链，
# 一个 tests/scratch_xxx/data -> ../../data 的软链就能把 .love 从 31M 顶到 800M。
#
# 用法:
#   bash tools/verify-cloud/run.sh probe    # 单帧截图：云在建筑/地形之上 + 有色差
#   bash tools/verify-cloud/run.sh e2e      # 真实启动链：云在漂移 + MMAPAMI=0 冻结 + 云在主角之上
#   bash tools/verify-cloud/run.sh scroll   # 云与地形滚动一致性（含像素分析）
#   bash tools/verify-cloud/run.sh all
#
# 依赖: LÖVE 11.x（默认 /home/woodfish/bin/love.AppImage，可用 LOVE=... 覆盖）、
#       scroll 的像素分析需要 python3 + Pillow、%DISPLAY% 可用（无头会失败）。
#
# 截图落盘: ~/.local/share/love/<identity>/（identity 见各 conf.lua）
set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC="$ROOT/tools/verify-cloud"
LOVE=${LOVE:-/home/woodfish/bin/love.AppImage}
GAME="$ROOT/game"
MODE=${1:-all}

# 与 game/ 运行时同构的资源与源码入口
LINKS="data pic sound script framework engine-love2d simsun.ttf product.env"

run_one() {
    local name=$1
    local work
    work=$(mktemp -d "${TMPDIR:-/tmp}/verify-cloud-XXXXXX")
    trap 'rm -rf "$work"' RETURN

    for l in $LINKS; do
        [ -e "$GAME/$l" ] || continue
        ln -s "$GAME/$l" "$work/$l"
    done
    cp "$SRC/$name/main.lua" "$SRC/$name/conf.lua" "$work/"

    echo "=== verify-cloud: $name (work=$work) ==="
    ( cd "$work" && DISPLAY=${DISPLAY:-:0.0} timeout 300 "$LOVE" . )
    local rc=$?

    if [ "$name" = "scroll" ]; then
        echo "--- scroll 像素分析 ---"
        python3 "$SRC/scroll/analyze.py"
    fi
    return $rc
}

case "$MODE" in
    probe|e2e|scroll) run_one "$MODE" ;;
    all)
        fail=0
        for m in probe e2e scroll; do
            run_one "$m" || fail=$((fail + 1))
        done
        [ "$fail" -eq 0 ] && echo "=== 全部取证脚本执行完毕 ===" || echo "=== 有 $fail 个脚本失败 ==="
        ;;
    *)
        sed -n '2,20p' "$0"
        exit 2
        ;;
esac
