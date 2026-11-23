#!/usr/bin/env python3
"""Crop the glyph frame centred in a container, then measure its weight with glyph-weight.py.

Usage: python3 button-crop.py <capture.png> --scale N --out DIR [--bg mode|edges] [--margin PT]
           NAME:X,Y,W,H:GLYPH [NAME:X,Y,W,H:GLYPH ...]

X,Y,W,H is the container's frame (the button, badge or circle) as fractions of the capture
(0-1, as argent `describe` prints them) or, with --points, in points. GLYPH is the icon size in
points. The crop is the GLYPH box plus --margin (default 2 pt) on each side, centred on the
container's centre, so the crop centre is the container centre.

Writes DIR/NAME.png for each container and prints one line per container:
  NAME  offset dx, dy  nudge nx, ny
dx, dy is where the weight sits relative to the container centre (+x right, +y down); nx, ny is
the shift that moves it onto the centre. Open the crops: a neighbour, label, badge or overlay in a
crop makes its numbers wrong.
"""
import argparse
import os
import re
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("png")
    parser.add_argument("targets", nargs="+")
    parser.add_argument("--scale", type=float, required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--bg", choices=["mode", "edges"], default="mode")
    parser.add_argument("--margin", type=float, default=2.0)
    parser.add_argument("--points", action="store_true")
    args = parser.parse_args()

    image = Image.open(args.png).convert("RGB")
    width, height = image.size
    os.makedirs(args.out, exist_ok=True)
    status = 0
    for target in args.targets:
        try:
            name, frame, glyph = target.split(":")
            x, y, w, h = (float(v) for v in frame.split(","))
            glyph = float(glyph)
        except ValueError:
            print(f"{target}: expected NAME:X,Y,W,H:GLYPH", file=sys.stderr)
            return 2
        if args.points:
            cx, cy = (x + w / 2) * args.scale, (y + h / 2) * args.scale
        else:
            cx, cy = (x + w / 2) * width, (y + h / 2) * height
        half = (glyph / 2 + args.margin) * args.scale
        box = tuple(int(round(v)) for v in (cx - half, cy - half, cx + half, cy + half))
        path = os.path.join(args.out, f"{name}.png")
        image.crop(box).save(path)
        run = subprocess.run(
            [sys.executable, os.path.join(HERE, "glyph-weight.py"), path,
             "--scale", str(args.scale), "--bg", args.bg],
            capture_output=True, text=True,
        )
        if run.returncode != 0:
            print(f"{name:20} {run.stderr.strip()}")
            status = 1
            continue
        offset = re.search(r"offset\s+([-+\d.]+) x, ([-+\d.]+) y", run.stdout)
        nudge = re.search(r"nudge\s+x ([-+\d.]+)\s+y ([-+\d.]+)", run.stdout)
        print(f"{name:20} offset {offset.group(1)}, {offset.group(2)}   "
              f"nudge {nudge.group(1)}, {nudge.group(2)}")
    return status


if __name__ == "__main__":
    sys.exit(main())
