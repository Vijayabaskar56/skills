#!/usr/bin/env python3
"""Usage: swing-sim.py <rig.json> <out.png> [--layers <dir>] [--angles=-18,-9,0,9,18] [--background 0.93]

Poses the rig offline at each angle (every part turns by angle * its swing about its pivot,
shadows ride their part and are clipped to their receiver) and tiles the frames side by side,
cropped to the stack. Read the sheet before installing anything: whatever stays put while the
parts move is baked into the wrong layer, and gaps show up where a hidden area was never filled.
"""

import argparse

import cv2
import numpy as np

import rig as rigs

parser = argparse.ArgumentParser()
parser.add_argument("rig")
parser.add_argument("out")
parser.add_argument("--layers")
parser.add_argument("--angles", default="-18,-9,0,9,18")
parser.add_argument("--background", type=float, default=0.93)
args = parser.parse_args()

_, layers = rigs.load(args.rig, args.layers)
angles = [float(a) for a in args.angles.split(",")]
frames, union = [], np.zeros(layers[0]["alpha"].shape, bool)
for angle in angles:
    posed = rigs.pose(layers, angle)
    stack, coverage = rigs.composite(posed, args.background)
    frames.append((angle, stack))
    union |= coverage > 0.02

ys, xs = np.nonzero(union)
top, bottom = max(ys.min() - 20, 0), ys.max() + 20
left, right = max(xs.min() - 20, 0), xs.max() + 20
tiles = []
for angle, stack in frames:
    tile = (np.clip(stack[top:bottom, left:right], 0, 1) * 255).astype(np.uint8)
    cv2.putText(tile, f"{angle:+.0f} deg", (16, 48), cv2.FONT_HERSHEY_SIMPLEX, 1.4, (40, 40, 40), 3)
    tiles.append(tile)
cv2.imwrite(args.out, np.hstack(tiles))
print(f"sheet {args.out} angles {args.angles}")
