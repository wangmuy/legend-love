#!/usr/bin/env python3
"""通用 grp 贴图帧渲染工具（RLE + 调色板，与 lib_love.lua LoadPic 一致）。

解码规则（见 game/engine-love2d/lib_love.lua 的 PicLoadFile/getPic/LoadPic）:
  idx 文件: 每条目 4 字节小端 u32 = 该图(0-based)结束偏移, 第 k 图范围 = entry[k-1]..entry[k]
  显示 picid(偶数) -> 图序号 slot = floor(picid/2)
  帧头 8 字节: w, h (u16), xoff, yoff (i16)
  RLE 每行: count=u8; while offset<count: trans=u8; solid=u8; solid 个调色板索引 u8
  调色板: 256 项 x 3 字节 (r,g,b) 0..63 -> *4

用法:
  python3 tools/render_frames.py <data目录> <输出目录> [picid...] [--prefix smap] [--pal mmap.col] [--scale N]

示例:
  python3 tools/render_frames.py game/data /tmp/frames 6890 4988
  python3 tools/render_frames.py game/data /tmp/frames 1000 --prefix mmap
  python3 tools/render_frames.py game/data /tmp/frames 6890 6932 --scale 4
"""
import argparse
import struct
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow: pip install pillow")


def load_palette(path):
    with open(path, "rb") as f:
        raw = f.read(256 * 3)
    return [(raw[i * 3] * 4, raw[i * 3 + 1] * 4, raw[i * 3 + 2] * 4) for i in range(256)]


def load_entries(path):
    with open(path, "rb") as f:
        raw = f.read()
    return [struct.unpack_from("<I", raw, i * 4)[0] for i in range(len(raw) // 4)]


def decode_frame(grp, a, b, pal):
    """解码 grp[a:b] 内一帧 -> (Image RGBA, xoff, yoff) 或 None"""
    buf = grp[a:b]
    if len(buf) < 8:
        return None
    w, h, xoff, yoff = struct.unpack_from("<HHhh", buf, 0)
    if not (1 <= w <= 4096 and 1 <= h <= 4096):
        return None
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    pos = 8
    for y in range(h):
        if pos >= len(buf):
            break
        count = buf[pos]; pos += 1
        x, off = 0, 0
        while off < count:
            if pos + 1 >= len(buf):
                break
            x += buf[pos]; pos += 1; off += 1
            solidnum = buf[pos]; pos += 1; off += 1
            for _ in range(solidnum):
                if pos >= len(buf):
                    break
                p = buf[pos] + 1  # 调色板索引 1-based (lua 1-based)
                pos += 1; off += 1
                if 1 <= p < len(pal) and 0 <= x < w:
                    px[x, y] = pal[p] + (255,)
                x += 1
    return img, xoff, yoff


def main():
    ap = argparse.ArgumentParser(description="grp 贴图帧渲染工具")
    ap.add_argument("datadir", help="data 目录 (含 *.grp/*.idx/mmap.col)")
    ap.add_argument("outdir", help="输出目录 (PNG)")
    ap.add_argument("picids", nargs="*", type=int, help="显示 picid (偶数, = 图序号*2)")
    ap.add_argument("--prefix", default="smap", help="grp/idx 文件名前缀 (默认 smap)")
    ap.add_argument("--pal", default="mmap.col", help="调色板文件名 (默认 mmap.col)")
    ap.add_argument("--scale", type=int, default=1, help="输出放大倍数 (默认 1)")
    args = ap.parse_args()

    data = Path(args.datadir)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    pal = load_palette(data / args.pal)
    entries = load_entries(data / f"{args.prefix}.idx")
    grp = (data / f"{args.prefix}.grp").read_bytes()
    print(f"prefix={args.prefix} entries={len(entries)} grp_len={len(grp)} grp_end={entries[-1] if entries else 0}")

    if not args.picids:
        args.picids = [entries and 0] or []
        sys.exit("需要至少一个 picid")

    for pic in args.picids:
        slot = pic // 2
        if slot >= len(entries):
            print(f"frame {pic} (slot {slot}): SKIP (超出 idx 条目数 {len(entries)})")
            continue
        a, b = entries[slot - 1] if slot >= 1 else 0, entries[slot]
        r = decode_frame(grp, a, b, pal)
        if r is None:
            print(f"frame {pic} (slot {slot}): EMPTY/BAD (a={a} b={b})")
            continue
        img, xoff, yoff = r
        if args.scale > 1:
            img = img.resize((img.width * args.scale, img.height * args.scale), Image.NEAREST)
        base = outdir / f"frame_{pic}"
        img.save(f"{base}.png")
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        bg.alpha_composite(img)
        bg.convert("RGB").save(f"{base}_white.png")
        bb = img.getbbox()
        print(f"frame {pic}: {img.width}x{img.height} xoff={xoff} yoff={yoff} bbox={bb} -> {base}.png")


if __name__ == "__main__":
    main()
