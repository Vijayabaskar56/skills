#!/usr/bin/env python3
"""Measure how big a motion is where the app shows it, in display points.

Usage: display_size.py <asset.avif | frames dir> --display WxH [--card out.gif]

The art is scaled to fit the display box (contain). Reports, in points, the scale, the busiest
frame's changed area and the box everything that moves stays in. These numbers do not decide
whether the motion reads: a thin, high-contrast gull changes 50 pt^2 and reads, while churned
trash changes 600 pt^2 and does not. --card writes a GIF at the display size (1 px = 1 pt) on a
light background; open it at 100% and judge that.
"""
import argparse
import glob
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

p = argparse.ArgumentParser()
p.add_argument("src", type=Path)
p.add_argument("--display", required=True, help="display box in points, e.g. 211x200")
p.add_argument("--diff", type=float, default=25.0, help="per-pixel change that counts as motion (0-255)")
p.add_argument("--card", type=Path)
a = p.parse_args()

dw, dh = (float(v) for v in a.display.lower().split("x"))

if a.src.is_dir():
    files = sorted(glob.glob(str(a.src / "f*.png")))
else:
    tmp = Path(tempfile.mkdtemp())
    files = []
    for i in range(1000):
        out = tmp / f"f{i:03d}.png"
        if subprocess.run(["avifdec", "--index", str(i), str(a.src), str(out)], capture_output=True).returncode:
            break
        files.append(str(out))
if len(files) < 2:
    sys.exit("need at least two frames")

frames = [np.asarray(Image.open(f).convert("RGBA")).astype(float) for f in files]
H, W = frames[0].shape[:2]
scale = min(dw / W, dh / H)
pt2_per_px = scale * scale

base = frames[0]
areas = []
union = np.zeros((H, W), bool)
for f in frames[1:]:
    w = np.maximum(f[..., 3], base[..., 3]) / 255
    d = np.abs(f[..., :3] - base[..., :3]).max(-1) * w
    m = ndimage.binary_opening(d > a.diff)
    areas.append(m.sum() * pt2_per_px)
    union |= m
peak = int(np.argmax(areas)) + 1
ys, xs = np.where(union)
box = [round(v * scale, 1) for v in (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)] if len(xs) else None

if a.card:
    size = (max(1, round(W * scale)), max(1, round(H * scale)))
    imgs = []
    for f in frames:
        bg = Image.new("RGBA", size, (242, 236, 226, 255))
        bg.alpha_composite(Image.fromarray(f.astype(np.uint8)).resize(size, Image.LANCZOS))
        imgs.append(bg.convert("RGB"))
    imgs[0].save(a.card, save_all=True, append_images=imgs[1:], duration=83, loop=0)

report = {
    "art_px": [W, H],
    "display_pt": [dw, dh],
    "scale_pt_per_px": round(scale, 3),
    "peak_changed_pt2": round(max(areas), 1),
    "peak_frame": peak,
    "motion_box_pt": box,
}
print(json.dumps(report))
