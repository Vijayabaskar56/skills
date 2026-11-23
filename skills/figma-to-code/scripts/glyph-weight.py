#!/usr/bin/env python3
"""Measure how far a glyph's visual weight sits from the centre of its box.

Usage: python3 glyph-weight.py <crop.png> [--scale N] [--step S] [--bg mode|edges] [--ink T]

<crop.png> is a capture cropped to the box the glyph is centred in: the icon frame plus a margin of
about 2 pt, centred on the container's centre (button-crop.py makes these crops). Pixels weigh by
their distance from the background colour, or by alpha on a transparent PNG.

--bg mode   the background is the crop's most common colour (a flat fill). Default.
--bg edges  the background is read per row from the crop's left and right edge pixels, for a glyph
            on a blur, wash or gradient. The margin must then be glyph-free on both sides.
--ink T     ignore pixels closer than T (0-1) to the background (default 0.04).
--scale     pixels per point or CSS px (3 for a 3x iPhone capture, 1 for a 1x browser capture).
--step      rounds the nudge (default 0.25).

Prints the box centre, the weight centre, the offset, and the nudge that moves the weight onto the
box centre (+x right, +y down) in points. Exits 1 when the crop holds no ink.
"""
import argparse
import sys
from collections import Counter

from PIL import Image


def distance(p, bg) -> float:
    return sum(abs(p[i] - bg[i]) for i in range(3)) / (3 * 255)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("png")
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--step", type=float, default=0.25)
    parser.add_argument("--bg", choices=["mode", "edges"], default="mode")
    parser.add_argument("--ink", type=float, default=0.04)
    args = parser.parse_args()

    image = Image.open(args.png).convert("RGBA")
    width, height = image.size
    pixels = list(image.getdata())
    transparent = sum(1 for p in pixels if p[3] < 255) > len(pixels) // 4

    if transparent:
        weights = [p[3] / 255 for p in pixels]
    elif args.bg == "edges":
        weights = []
        for y in range(height):
            left, right = pixels[y * width], pixels[y * width + width - 1]
            bg = tuple((left[i] + right[i]) / 2 for i in range(3))
            for x in range(width):
                d = distance(pixels[y * width + x], bg)
                weights.append(d if d > args.ink else 0.0)
    else:
        bg = Counter(p[:3] for p in pixels).most_common(1)[0][0]
        weights = []
        for p in pixels:
            d = distance(p, bg)
            weights.append(d if d > args.ink else 0.0)

    total = sum(weights)
    if total == 0:
        print("no ink found: check the crop", file=sys.stderr)
        return 1

    cx = sum(w * (i % width + 0.5) for i, w in enumerate(weights)) / total
    cy = sum(w * (i // width + 0.5) for i, w in enumerate(weights)) / total
    s = args.scale
    box = (width / 2 / s, height / 2 / s)
    weight = (cx / s, cy / s)
    dx, dy = box[0] - weight[0], box[1] - weight[1]

    def snap(v: float) -> float:
        return round(v / args.step) * args.step + 0.0

    print(f"box centre    {box[0]:.2f}, {box[1]:.2f}")
    print(f"weight centre {weight[0]:.2f}, {weight[1]:.2f}")
    print(f"offset        {-dx:+.2f} x, {-dy:+.2f} y  (weight relative to box)")
    print(f"nudge         x {snap(dx):+.2f}  y {snap(dy):+.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
