#!/usr/bin/env python3
"""Usage: layer-lint.py <rig.json> [--layers <dir>] [--chroma 6] [--darken 0.04] [--dark-share 0.02] [--coverage 0.9]

Checks the mistakes that made layered photos look fake in motion. Prints "ok" or "fail" per check
and exits 1 on any fail.

- fragments: a part layer holds one body. Extra islands are slivers of a neighbour.
- cast: a part marked "neutral" carries no colour reflected from a neighbour (LAB chroma of its
  opaque pixels, p95, at most --chroma).
- stationary-shadow: a surface marked "receives" has no band beside the parts' rest position that
  is darker (by --darken) than the light fitted on the rest of the surface; at most --dark-share
  of that band may be. A dark band there stays behind when the parts swing away.
- shadow-length: when the rig has shadow layers, every part has shadow (from any of them) under
  or within 10 px of it, or of where its shadow lands (the "offset" [dx, dy] of the shadow layer
  that follows it), in at least --coverage of its rows. A photo only shows shadow where the
  part lay over the surface, so a shadow taken from the photo alone stops halfway down a part
  that hangs past the edge, and reads as half a shadow mid-swing.
"""

import argparse
import sys

import cv2
import numpy as np
from scipy import ndimage

import rig as rigs

parser = argparse.ArgumentParser()
parser.add_argument("rig")
parser.add_argument("--layers")
parser.add_argument("--chroma", type=float, default=6.0)
parser.add_argument("--darken", type=float, default=0.04)
parser.add_argument("--dark-share", type=float, default=0.02)
parser.add_argument("--coverage", type=float, default=0.9)
parser.add_argument("--min-area", type=int, default=40)
args = parser.parse_args()

_, layers = rigs.load(args.rig, args.layers)
named = rigs.by_name(layers)
failed = False


def report(ok, check, name, detail):
    global failed
    failed |= not ok
    print(f"{'ok' if ok else 'fail'} {check} {name} {detail}")


parts = [layer for layer in layers if layer.get("role") == "part"]
for part in parts:
    count, _, stats, _ = cv2.connectedComponentsWithStats((part["alpha"] > 0.5).astype(np.uint8), 8)
    islands = int((stats[1:, cv2.CC_STAT_AREA] >= args.min_area).sum())
    specks = int((stats[1:, cv2.CC_STAT_AREA] < args.min_area).sum())
    report(islands == 1, "fragments", part["name"], f"{islands} bodies, {specks} specks under {args.min_area}px")

    if part.get("neutral"):
        opaque = part["alpha"] > 0.9
        lab = cv2.cvtColor(part["bgr"].astype(np.float32), cv2.COLOR_BGR2LAB)
        chroma = np.hypot(lab[..., 1], lab[..., 2])[opaque]
        p95 = float(np.percentile(chroma, 95))
        report(p95 <= args.chroma, "cast", part["name"], f"chroma p95 {p95:.1f} (max {args.chroma})")

moving = np.zeros(layers[0]["alpha"].shape, bool)
for part in parts:
    moving |= part["alpha"] > 0.5
reach = ndimage.distance_transform_edt(~moving)
for surface in (layer for layer in layers if layer.get("receives")):
    face = ndimage.binary_erosion(surface["alpha"] > 0.98, iterations=14)
    base = np.median(surface["bgr"][face & (reach > 160)], 0)
    body = face & (np.abs(surface["bgr"] - base).max(-1) < 0.25)
    near = body & ~moving & (reach < 140)
    far = body & (reach > 160)
    if near.sum() < 100 or far.sum() < 100:
        report(False, "stationary-shadow", surface["name"], "too few pixels near or far from the parts to judge")
        continue
    lum = surface["bgr"].mean(-1)
    height, width = lum.shape
    ys, xs = np.mgrid[0:height, 0:width]
    basis = np.stack([np.ones_like(lum), xs / width, ys / height], -1)
    fit, *_ = np.linalg.lstsq(basis[far], lum[far], rcond=None)
    residual = ndimage.gaussian_filter(lum - basis @ fit, 3)
    share = float((residual[near] < -args.darken).mean())
    report(share <= args.dark_share, "stationary-shadow", surface["name"],
           f"{share:.1%} of the face beside the parts is darker than the fitted light (max {args.dark_share:.0%})")

shadows = [layer for layer in layers if layer.get("role") == "shadow"]
cast = np.zeros(layers[0]["alpha"].shape)
for shadow in shadows:
    cast = np.maximum(cast, shadow["alpha"])
for part in parts if shadows else []:
    body = part["alpha"] > 0.5
    rows = np.nonzero(body.any(1))[0]
    lands = body.copy()
    for shadow in shadows:
        if shadow.get("follows") == part["name"] and "offset" in shadow:
            dx, dy = shadow["offset"]
            lands |= ndimage.shift(body, (dy, dx), order=0)
    under = ndimage.binary_dilation(lands, iterations=10)
    shaded = ((cast > 0.05) & under).any(1)
    share = float(shaded[rows].mean())
    report(share >= args.coverage, "shadow-length", part["name"],
           f"shadow beside {share:.0%} of its rows (min {args.coverage:.0%})")

sys.exit(1 if failed else 0)
