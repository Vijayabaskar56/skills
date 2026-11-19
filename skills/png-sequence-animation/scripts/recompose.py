#!/usr/bin/env python3
"""Usage: recompose.py <rig.json> <source.png> [--layers <dir>] [--max-alpha 0.01] [--max <mean error>] [--heatmap <out.png>]

Stacks every layer at rest, in rig order, and compares the result with the source photo. Prints
"mean <colour error>/255 p99 <colour error>/255 alpha <coverage error>". Exits 1 when the
coverage error is above --max-alpha (a hole or an extra fringe in the silhouette), or, when --max
is given, when the mean colour error is above it. Gate colour only on a straight extraction: once
a layer is repainted on purpose (lighting removed, a reflection neutralised), colour no longer
matches the photo there by design. --heatmap writes the per-pixel colour error so you can check
that it is bright only where you repainted.
"""

import argparse
import sys

import cv2
import numpy as np

import rig as rigs

parser = argparse.ArgumentParser()
parser.add_argument("rig")
parser.add_argument("source")
parser.add_argument("--layers")
parser.add_argument("--max", type=float)
parser.add_argument("--max-alpha", type=float, default=0.01)
parser.add_argument("--heatmap")
args = parser.parse_args()

_, layers = rigs.load(args.rig, args.layers)
source = cv2.imread(args.source, cv2.IMREAD_UNCHANGED)
if source is None:
    sys.exit(f"cannot read {args.source}")
if source.shape[:2] != layers[0]["alpha"].shape:
    sys.exit("source and canvas differ in size; layers must sit on the source's own pixel grid")
source_bgr = source[..., :3] / 255.0
source_alpha = source[..., 3] / 255.0 if source.shape[2] == 4 else np.ones(source.shape[:2])

stack, coverage = rigs.composite(rigs.pose(layers, 0))
opaque = source_alpha > 0.98
error = np.abs(stack - source_bgr).mean(-1) * 255
mean, p99 = error[opaque].mean(), np.percentile(error[opaque], 99)
alpha_error = np.abs(coverage - source_alpha).mean()
print(f"mean {mean:.2f}/255 p99 {p99:.1f}/255 alpha {alpha_error:.4f}")

if args.heatmap:
    heat = np.clip(error * 8 * (source_alpha > 0), 0, 255).astype(np.uint8)
    cv2.imwrite(args.heatmap, cv2.applyColorMap(heat, cv2.COLORMAP_INFERNO))
    print(f"heatmap {args.heatmap}")

failed = False
if alpha_error > args.max_alpha:
    print(f"fail coverage error above {args.max_alpha}")
    failed = True
if args.max is not None and mean > args.max:
    print(f"fail mean colour error above {args.max}/255")
    failed = True
sys.exit(1 if failed else 0)
