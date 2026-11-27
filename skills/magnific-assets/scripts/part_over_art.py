#!/usr/bin/env python3
"""Paste only the moving part of a green-key clip over the original art, frame by frame.

Usage: part_over_art.py <art.png> <clip.mp4> <out dir> --range S:E[:STEP] --seed-hue LO,HI
                        [--seed-sat 0.45] [--seed-val 0.5] [--zone x0,y0,x1,y1] [--erase-box x0,y0,x1,y1]
                        [--move 35] [--hang PX] [--forward | --cycle MIN]

Use it when the clip plays a whole action (a crane swings and lowers its load, an arm digs) and
Kling restyled the scene around it. Every pixel outside the moving part is the art's own pixel,
so the ground, base and buildings never shimmer or change colour. Needs a prep_start.py --bg green
start image.

How it finds the moving part, per frame (all in art pixels, after aligning the clip to the art):
  seeds   pixels of the part's main colour, as a hue range (a crane's yellow is about 30,60)
  motion  pixels that differ from the clip's median by more than --move, joined to a seed
  thin    long, thin moving lines touching the part (cables, ropes), kept at a lower threshold
  hang    with --hang PX, moving pixels on the line from the largest seed blob off the sky (a load) up to
          the part above it (a cable), and around the load itself
  sky     anything opaque where the clip's median is background, inside --zone
--zone limits all of it (default: the whole art). --erase-box clears the art inside the box wherever
the frame shows background, for a part that moves away from its pose in the art (a crane jib that
slews, a coin that stands up); without it the art's old pose stays as a ghost. The output plays --range out and back (ping-pong), once with
--forward, or with --cycle MIN one full swing: forward from S to the later frame whose pose best
matches S, so a rock or sway loops with no reversal. Writes <out>/frames/fNNN.png, <out>/mask0.png and <out>/report.json, and prints it.
report.json `outside_zone_max` must be about 0: that is the proof nothing else moved.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def box(text):
    return [int(v) for v in text.split(",")]


p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument("art")
p.add_argument("clip")
p.add_argument("out", type=Path)
p.add_argument("--range", required=True, help="S:E[:STEP] clip frames")
p.add_argument("--seed-hue", required=True, type=box, help="lo,hi hue in degrees of the part's main colour")
p.add_argument("--seed-sat", type=float, default=0.45, help="least saturation of a seed pixel (0..1)")
p.add_argument("--seed-val", type=float, default=0.5, help="least brightness of a seed pixel (0..1)")
p.add_argument("--zone", type=box)
p.add_argument("--erase-box", type=box)
p.add_argument("--move", type=float, default=35)
p.add_argument("--hang", type=int, default=0, metavar="PX",
               help="keep a hanging line PX wide from the load (largest seed blob off the sky) up to the part above it")
p.add_argument("--forward", action="store_true")
p.add_argument("--cycle", type=int, default=0, metavar="MIN",
               help="play forward from S to the frame (at least MIN steps in) whose pose best matches S")
a = p.parse_args()

art = np.asarray(Image.open(a.art).convert("RGBA")).astype(float)
H, W = art.shape[:2]
parts = [int(v) for v in a.range.split(":")]
start, end, step = parts[0], parts[1], parts[2] if len(parts) > 2 else 1

tmp = Path(tempfile.mkdtemp())
subprocess.run(["ffmpeg", "-loglevel", "error", "-i", a.clip, str(tmp / "%04d.png")], check=True)
raw_paths = sorted(tmp.glob("*.png"))[start:end:step]
clips = [Image.open(q).convert("RGB") for q in raw_paths]
first = np.asarray(clips[0]).astype(float)
key = np.median(np.concatenate([first[:20, :20].reshape(-1, 3), first[:20, -20:].reshape(-1, 3)]), axis=0)

zone = np.zeros((H, W), bool)
x0, y0, x1, y1 = a.zone or (0, 0, W, H)
zone[y0:y1, x0:x1] = True

# Align: find scale k and offset (ox, oy) so art pixel (x, y) sits at clip pixel (k(x+ox), k(y+oy)),
# matching the art on the key colour against the clip, outside the zone when there is room.
plate = Image.new("RGBA", (W, H), tuple(int(v) for v in key) + (255,))
plate.alpha_composite(Image.fromarray(art.astype(np.uint8)))
ref = np.asarray(plate.convert("L")).astype(float)
fit = (~zone) if (~zone).sum() > 0.1 * H * W else np.ones((H, W), bool)
gray = clips[0].convert("L")


def err(k, ox, oy, sub=2):
    c = np.asarray(gray.transform((W, H), Image.AFFINE, (k, 0, ox * k, 0, k, oy * k), Image.BILINEAR)).astype(float)
    return float(np.abs(c - ref)[::sub, ::sub][fit[::sub, ::sub]].mean())


k0 = gray.width / W
best = min((err(k, ox, oy, 4), k, ox, oy) for k in np.linspace(k0 * 0.94, k0 * 1.04, 21)
           for ox in range(-8, 9, 2) for oy in range(-8, 9, 2))
_, kb, oxb, oyb = best
best = min((err(k, ox, oy), k, ox, oy) for k in np.linspace(kb - 0.006 * k0, kb + 0.006 * k0, 13)
           for ox in np.arange(oxb - 2, oxb + 2.01, 0.5) for oy in np.arange(oyb - 2, oyb + 2.01, 0.5))
align_err, k, ox, oy = best


def aligned(im):
    return np.asarray(im.transform((W, H), Image.AFFINE, (k, 0, ox * k, 0, k, oy * k), Image.BICUBIC)).astype(float)


def keyed(f):
    alpha = np.clip((np.linalg.norm(f - key, axis=-1) - 90) / 70, 0, 1)
    f = f.copy()
    g, rb = f[..., 1], np.maximum(f[..., 0], f[..., 2])
    f[..., 1] = np.where(g > rb, rb + (g - rb) * alpha * 0.3, g)
    return f, alpha


frames_rgb = [aligned(im) for im in clips]
cycle_end = None
if a.cycle:
    d = [float(np.abs(f - frames_rgb[0])[zone].mean()) for f in frames_rgb]
    cycle_end = a.cycle + int(np.argmin(d[a.cycle:]))
    frames_rgb = frames_rgb[:cycle_end]
    a.forward = True
med = np.median(np.stack(frames_rgb), axis=0)
_, med_alpha = keyed(med)
background = (med_alpha < 0.5) & zone
erase = np.zeros((H, W), bool)
if a.erase_box:
    ex0, ey0, ex1, ey1 = a.erase_box
    erase[ey0:ey1, ex0:ex1] = True
    erase &= art[..., 3] > 0


def hsv(c):
    mx, mn = c.max(-1), c.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, (mx - mn) / np.maximum(mx, 1e-6), mx / 255


def seed_of(c, alpha):
    h, s_, v = hsv(c)
    lo, hi = a.seed_hue
    return (h >= lo) & (h <= hi) & (s_ >= a.seed_sat) & (v >= a.seed_val) & (alpha > 0.5) & zone



def part_mask(c, alpha):
    diff = np.abs(c - med).mean(-1)
    seeds = ndimage.binary_opening(seed_of(c, alpha))
    motion = ndimage.binary_opening((diff > a.move) & zone)
    lab, _ = ndimage.label(motion | seeds)
    ids = np.unique(lab[seeds])
    part = np.isin(lab, ids[ids > 0])
    near = ndimage.binary_dilation(part, iterations=3)
    tl, tn = ndimage.label((diff > a.move * 0.6) & zone)
    for i, sl in enumerate(ndimage.find_objects(tl), 1):
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        comp = tl[sl] == i
        if max(h, w) > 15 and max(h, w) ** 2 / comp.sum() > 25 and (near[sl] & comp).any():
            part[sl] |= comp
    if a.hang:
        sl2, n2 = ndimage.label(seeds)
        upper = part & background
        load = 0
        if n2 and upper.any():
            touching = np.unique(sl2[ndimage.binary_dilation(background, iterations=2)])
            sizes = np.bincount(sl2.ravel(), minlength=n2 + 1)
            sizes[0] = 0
            sizes[touching] = 0
            load = int(np.argmax(sizes))
        if n2 and upper.any() and load:
            ys, xs = np.where(sl2 == load)
            cx, top = int(np.median(xs)), int(ys.min())
            uy, ux = np.where(upper)
            j = int(np.argmin(np.abs(ux - cx) + 0.01 * np.abs(uy - top)))
            tx, ty = ux[j], uy[j]
            yy, xx = np.mgrid[:H, :W]
            dx, dy = cx - tx, top - ty
            t = np.clip(((xx - tx) * dx + (yy - ty) * dy) / max(dx * dx + dy * dy, 1), 0, 1)
            line = np.hypot(xx - (tx + t * dx), yy - (ty + t * dy)) < a.hang
            part |= line & (diff > a.move * 0.6)
            part |= ndimage.binary_dilation(sl2 == load, iterations=2) & (diff > a.move * 0.6)
    sky = (alpha > 0.5) & background
    sl_, sn = ndimage.label(sky)
    if sn:
        sizes = np.bincount(sl_.ravel())
        sky &= sizes[sl_] >= 8
    return ndimage.binary_dilation(ndimage.binary_fill_holes(part | sky), iterations=1)


out_frames = []
for i, c in enumerate(frames_rgb):
    rgb, alpha = keyed(c)
    m = part_mask(c, alpha) | (erase & ndimage.binary_dilation(alpha < 0.5, iterations=2))
    m = np.clip(ndimage.gaussian_filter(m.astype(float), 1.2) * 1.3, 0, 1)[..., None]
    pa = m * alpha[..., None] + (1 - m) * art[..., 3:] / 255
    prgb = m * rgb * alpha[..., None] + (1 - m) * art[..., :3] * art[..., 3:] / 255
    f = np.dstack([np.where(pa > 0, prgb / np.maximum(pa, 1e-6), 0), pa * 255]).clip(0, 255).astype(np.uint8)
    out_frames.append(f)
    if i == 0:
        a.out.mkdir(parents=True, exist_ok=True)
        Image.fromarray((m[..., 0] * 255).astype(np.uint8)).save(a.out / "mask0.png")

seq = out_frames if a.forward else out_frames + out_frames[-2:0:-1]
fdir = a.out / "frames"
fdir.mkdir(parents=True, exist_ok=True)
for i, f in enumerate(seq):
    Image.fromarray(f).save(fdir / f"f{i:03d}.png")
outside = max(float(np.abs(f.astype(float) - art)[~zone].max()) if (~zone).any() else 0.0 for f in out_frames)
changed = np.stack([np.abs(f.astype(float) - art).max(-1) > 8 for f in out_frames]).any(0)
report = {"frames": len(seq), "align": {"k": round(k, 4), "ox": ox, "oy": oy, "err": round(align_err, 2)},
          "key": key.round().tolist(), "changed_pct": round(100 * changed.mean(), 1),
          "outside_zone_max": outside, "mode": "cycle" if a.cycle else "forward" if a.forward else "pingpong",
          "cycle_end_step": cycle_end}
(a.out / "report.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
