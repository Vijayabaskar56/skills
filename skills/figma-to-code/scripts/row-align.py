#!/usr/bin/env python3
"""Measure how a row's icon and label line up, from a capture plus the label frames.

Usage: python3 row-align.py <capture.png> --scale N [--side lead|trail] [--reach PT]
           [--points] NAME:LABEL[:SIBLING] [NAME:LABEL[:SIBLING] ...]

LABEL is the label text's frame X,Y,W,H, as fractions of the capture (0-1, as argent `describe`
prints them) or, with --points, in points. SIBLING is an optional second text frame on the same
row, such as the value text on the right of a key/value row.

For each row it finds the label's ink (cap top to baseline, descenders ignored), then the icon ink
within --reach points (default 28) on --side (lead: left of the label, default; trail: right),
inside a window of +-11 pt around the label's middle. It prints, in points (+ is down):

  icon-label   icon box centre minus the label's cap-top-to-baseline centre
  weight       icon ink centroid minus the same label centre
  base-sib     label baseline minus the sibling's baseline (only with SIBLING)
  icon-x       icon box centre x, for checking that a column of icons lines up

Reading it: an aligned row reads icon-label 0 to +0.33, one device pixel either way. A whole
column off by the same amount (every row +1.00) is a systematic cause such as tight leading, not
a per-icon problem. When base-sib is not 0 the label itself is off
its own line (tight lineHeight, a wrong baseline), so fix the label, not the icon. Exits 1 when a
row has no label or icon ink.
"""
import argparse
import sys

from PIL import Image

TEXT_INK = 0.25
ICON_INK = 0.08
WINDOW_PT = 11


def parse_frame(raw: str, width_pt: float, height_pt: float, points: bool) -> tuple:
    x, y, w, h = (float(v) for v in raw.split(","))
    if points:
        return x, y, w, h
    return x * width_pt, y * height_pt, w * width_pt, h * height_pt


def scan(px, size, scale, box_pt, threshold):
    width, height = size
    x0, x1, y0, y1 = (max(0, int(round(v * scale))) for v in box_pt)
    x1, y1 = min(x1, width), min(y1, height)
    rows, cols = {}, {}
    total = weighted_y = 0.0
    for y in range(y0, y1):
        background = max((px[x, y] for x in range(x0, x1)), key=sum, default=(255, 255, 255))
        for x in range(x0, x1):
            pixel = px[x, y]
            ink = sum(abs(pixel[i] - background[i]) for i in range(3)) / 765
            if ink > threshold:
                rows[y] = rows.get(y, 0) + 1
                cols[x] = cols.get(x, 0) + ink
                total += ink
                weighted_y += y * ink
    return rows, cols, total, weighted_y


def text_line(px, size, scale, x, y, w, h):
    rows, _, _, _ = scan(px, size, scale, (x, x + w, y, y + h), TEXT_INK)
    if not rows:
        return None
    peak = max(rows.values())
    ordered = sorted(rows)
    top = next(v for v in ordered if rows[v] > 0.03 * peak)
    base = max(v for v in ordered if rows[v] > 0.3 * peak)
    return top / scale, (base + 1) / scale


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture")
    parser.add_argument("rows", nargs="+")
    parser.add_argument("--scale", type=float, required=True)
    parser.add_argument("--side", choices=("lead", "trail"), default="lead")
    parser.add_argument("--reach", type=float, default=28)
    parser.add_argument("--points", action="store_true")
    args = parser.parse_args()

    image = Image.open(args.capture).convert("RGB")
    px = image.load()
    scale = args.scale
    width_pt, height_pt = image.size[0] / scale, image.size[1] / scale

    print(f"{'row':28}{'icon-label':>11}{'weight':>8}{'base-sib':>9}{'icon-x':>8}")
    failed = False
    for spec in args.rows:
        name, label, *rest = spec.split(":")
        x, y, w, h = parse_frame(label, width_pt, height_pt, args.points)
        line = text_line(px, image.size, scale, x, y, w, h)
        if line is None:
            print(f"{name:28}no label ink")
            failed = True
            continue
        top, base = line
        middle = (top + base) / 2

        sibling = ""
        if rest:
            sx, sy, sw, sh = parse_frame(rest[0], width_pt, height_pt, args.points)
            other = text_line(px, image.size, scale, sx, sy, sw, sh)
            sibling = f"{base - other[1]:+9.2f}" if other else f"{'none':>9}"

        reach = (x - args.reach, x - 1) if args.side == "lead" else (x + w + 1, x + w + args.reach)
        window = (middle - WINDOW_PT, middle + WINDOW_PT)
        rows, cols, total, weighted_y = scan(px, image.size, scale, (*reach, *window), ICON_INK)
        if not rows:
            print(f"{name:28}no icon ink{sibling}")
            failed = True
            continue
        ys, xs = sorted(rows), sorted(cols)
        box = (ys[0] + ys[-1] + 1) / 2 / scale
        weight = weighted_y / total / scale
        icon_x = (xs[0] + xs[-1] + 1) / 2 / scale
        print(f"{name:28}{box - middle:+11.2f}{weight - middle:+8.2f}{sibling or '':>9}{icon_x:8.2f}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
