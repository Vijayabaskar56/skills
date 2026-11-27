#!/usr/bin/env python3
"""Loop a small motion that leaves the art's outline: play it out and back, then rest.

Usage: keyed_pingpong.py <art.png> <clip.mp4> <out dir> [--last N] [--swing S] [--rest R] [--fps F]

For a clip made from prep_start.py --bg green, when the moving part rolls, tips or sways past its
outline in the art. Kling overshoots any "slight" motion after about a second, so take only clip
frames 0..last (default 12: the opening half-second) and find `last` on a contact sheet first.
The background colour is read from the clip's corners and keyed out. Pixels the clip changed come
from the keyed clip; every other pixel comes from the art, so frame 0 is the art exactly and the
still swaps in with no jump. Writes <out>/frames/fNNN.png and prints a JSON summary.

  --swing S   seconds for the out-and-back (default 1.6)
  --rest R    seconds to hold the art afterwards (default 1.2)
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

KEY_SOFT, KEY_HARD = 90.0, 160.0  # distance from the key colour: clear below, solid above
MOVED = 12  # brighter or darker than clip frame 0 by this much counts as moving

p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument("art")
p.add_argument("clip")
p.add_argument("out", type=Path)
p.add_argument("--last", type=int, default=12)
p.add_argument("--swing", type=float, default=1.6)
p.add_argument("--rest", type=float, default=1.2)
p.add_argument("--fps", type=int, default=12)
a = p.parse_args()

src = np.asarray(Image.open(a.art).convert("RGBA")).astype(float)
H, W = src.shape[:2]
tmp = Path(tempfile.mkdtemp())
subprocess.run(["ffmpeg", "-v", "error", "-i", a.clip, "-frames:v", str(a.last + 1), str(tmp / "%03d.png")], check=True)
clip = [np.asarray(Image.open(q).convert("RGB").resize((W, H), Image.LANCZOS)).astype(float) for q in sorted(tmp.glob("*.png"))]
if len(clip) < a.last + 1:
    raise SystemExit(f"clip has only {len(clip)} frames")
c0 = clip[0]
key = np.median(np.concatenate([c0[:12, :12], c0[:12, -12:], c0[-12:, :12], c0[-12:, -12:]]).reshape(-1, 3), 0)


def keyed(rgb):
    """Premultiplied colour and alpha (0..1) with the key colour removed and its spill cleaned."""
    al = np.clip((np.linalg.norm(rgb - key, axis=-1) - KEY_SOFT) / (KEY_HARD - KEY_SOFT), 0, 1)
    fg = (rgb - key * (1 - al[..., None])) / np.maximum(al[..., None], 1e-3)
    dominant = int(np.argmax(key))
    others = [c for c in range(3) if c != dominant]
    #! Key spill on edges: no foreground pixel is more key-coloured than its other channels.
    fg[..., dominant] = np.minimum(fg[..., dominant], fg[..., others].max(-1))
    return np.clip(fg, 0, 255) * al[..., None], al


layers = [keyed(c) for c in clip]
src_a = src[..., 3] / 255
src_pm = src[..., :3] * src_a[..., None]


def frame(pos):
    i = int(pos)
    t = pos - i
    j = min(i + 1, a.last)
    pm = layers[i][0] * (1 - t) + layers[j][0] * t
    al = layers[i][1] * (1 - t) + layers[j][1] * t
    rgb = clip[i] * (1 - t) + clip[j] * t
    moved = (np.abs(rgb - c0).max(-1) > MOVED) & ((al > 0.02) | (layers[0][1] > 0.02))
    moved = ndimage.binary_dilation(ndimage.binary_opening(moved, iterations=1), iterations=2)
    m = np.clip(ndimage.gaussian_filter(moved.astype(float), 1.5) * 1.5, 0, 1)
    out_pm = pm * m[..., None] + src_pm * (1 - m[..., None])
    out_a = al * m + src_a * (1 - m)
    return np.dstack([out_pm / np.maximum(out_a[..., None], 1e-3), out_a * 255])


swing = max(2, round(a.swing * a.fps))
frames = [src] + [frame((1 - np.cos(2 * np.pi * k / swing)) / 2 * a.last) for k in range(1, swing)]
frames += [src] * round(a.rest * a.fps)
out_frames = a.out / "frames"
out_frames.mkdir(parents=True, exist_ok=True)
for old in out_frames.glob("f*.png"):
    old.unlink()
for k, f in enumerate(frames):
    Image.fromarray(np.clip(np.round(f), 0, 255).astype(np.uint8)).save(out_frames / f"f{k:03d}.png")
print(json.dumps({"frames": len(frames), "fps": a.fps, "key": key.round().tolist(), "clip_frames_used": a.last + 1,
                  "frames_dir": str(out_frames)}))
