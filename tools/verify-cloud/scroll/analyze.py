#!/usr/bin/env python3
"""云滚动耦合 E2E 像素分析（配合 tools/verify-cloud/scroll/main.lua 使用）。

读数方法：
  * 云像素包围盒 = |with - without| 的 bbox —— 同一主角位置、同一帧条件下只把
    云的 img 置空，差集即云层像素。
  * 地形像素位移 = 刚体平移估计。直接对全图像素做 81×81 穷举太慢（分钟级），
    这里改用「投影互相关 + 全图像素复核」两步：
      1) 把中心区域压成列均值曲线（w 长）与行均值曲线（h 长），
         分别求使 L1 距离最小的 dx / dy —— O(range × (w+h))，毫秒级；
      2) 用得到的 (dx,dy) 在全图做一次 ImageChops 差集，输出残差供人工判断
         是否真的是平移（残差过大说明估计不可信）。
    地形/建筑是刚体平移，投影法对该场景是精确的（已与旧的全图穷举结果对拍）。

判定：云的位移必须与地形位移完全相等（云是世界锚定图层，随地形同步滚动）。

用法:
    bash tools/verify-cloud/run.sh scroll          # 跑驱动 + 本分析
    python3 tools/verify-cloud/scroll/analyze.py   # 只重跑分析（截图已存在）
"""
import os
import sys

from PIL import Image, ImageChops, ImageStat

IDENTITY = "cloud_scroll"
CROP = (120, 140, 900, 620)   # 避开对话框/状态栏等固定 UI
RADIUS = 40
RESIDUAL_MAX = 12.0           # 复核残差（0..255 平均差）超过即认为不是平移


def shot_dir():
    base = os.environ.get("LOVE_DATA")
    if base:
        return os.path.join(base, "love", IDENTITY)
    return os.path.expanduser("~/.local/share/love/" + IDENTITY)


def load(name):
    return Image.open(os.path.join(shot_dir(), "sc_%s.png" % name)).convert("RGB")


def cloud_bbox(pos):
    return ImageChops.difference(load(pos + "_with"), load(pos + "_without")).getbbox()


def _profile(img):
    """中心区域的列均值曲线与行均值曲线（亮度，长度 = 宽 / 高）。"""
    g = img.crop(CROP).convert("L")
    w, h = g.size
    cols = list(g.resize((w, 1), Image.BOX).getdata())
    rows = list(g.resize((1, h), Image.BOX).getdata())
    return cols, rows


def _best_shift(a, b, span):
    """返回使 sum|a[i-d]-b[i]| 最小的 d（重叠部分比较）。"""
    best_d, best_s = 0, None
    n = len(a)
    for d in range(-span, span + 1):
        lo, hi = max(0, d), min(n, n + d)
        if hi - lo < n // 2:      # 重叠太少，跳过
            continue
        s = sum(abs(a[i - d] - b[i]) for i in range(lo, hi))
        if best_s is None or s < best_s:
            best_d, best_s = d, s
    return best_d


def terrain_shift(a_name, b_name, radius=RADIUS):
    """返回地形在屏幕上从 a 到 b 的刚体位移 (dx, dy) 与复核残差。"""
    a, b = load(a_name), load(b_name)
    ca, ra = _profile(a)
    cb, rb = _profile(b)
    dx = _best_shift(ca, cb, radius)
    dy = _best_shift(ra, rb, radius)
    diff = ImageChops.difference(ImageChops.offset(a, dx, dy), b).crop(CROP)
    residual = ImageStat.Stat(diff.convert("L")).mean[0]
    return dx, dy, residual


def main():
    positions = ["p0", "p1", "p2", "p3"]
    labels = [
        ("p0", "p1", "按→ 主角 X+1"),
        ("p1", "p2", "按↓ 主角 Y+1"),
        ("p2", "p3", "按← 主角 X-1"),
    ]
    boxes = {p: cloud_bbox(p) for p in positions}
    for p in positions:
        print("%s 云像素 bbox = %s" % (p, boxes[p]))

    ok = True
    print()
    for a, b, desc in labels:
        if boxes[a] is None or boxes[b] is None:
            print("%-16s 差集为空，云未渲染，无法判定" % desc)
            ok = False
            continue
        cloud_dx = boxes[b][0] - boxes[a][0]
        cloud_dy = boxes[b][1] - boxes[a][1]
        terr_dx, terr_dy, resid = terrain_shift(a + "_without", b + "_without")
        same = (cloud_dx == terr_dx and cloud_dy == terr_dy)
        trusted = resid < RESIDUAL_MAX
        ok = ok and same and trusted
        print("%-16s 地形 d=(%+d,%+d) 云 d=(%+d,%+d) 残差=%.1f  %s"
              % (desc, terr_dx, terr_dy, cloud_dx, cloud_dy, resid,
                 "OK（云与地形同步滚动）" if same and trusted
                 else ("MISMATCH（云反向滑动）" if not same
                       else "地形位移不可信（残差过大）")))

    print("\n结论：" + ("云与地形滚动一致，无耦合偏移" if ok else "存在云/地形滚动不一致"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
