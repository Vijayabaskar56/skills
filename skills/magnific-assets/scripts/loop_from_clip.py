#!/usr/bin/env python3
"""Build loop frames from a clip, taking only the pixels that move; the rest stays the art.

Usage: loop_from_clip.py <art.png> <clip.mp4> <out dir> [options]

Use it when the moving part stays inside the art's outline (water, smoke, lights, sparks, plants).
Pixels whose brightness varies across the clip form the motion mask; inside it the clip shows,
outside it and for alpha the art shows, so the style never drifts. Writes <out>/frames/fNNN.png,
<out>/report.json and <out>/sheet.png (art | mask | three frames), and prints the report.

Options:
  --start N / --end N   clip frames to use (default 36..120; --once starts at 0)
  --threshold T         motion std that counts as moving (default 3; 5 drops faint jitter)
  --alpha-min A         art alpha a moving pixel needs (default 200; 40 for smoke, soft edges)
  --box x0,y0,x1,y1     keep motion inside this art-pixel box
  --fps F               output frame rate (default 24, the clip's own rate)
  --once                play the action once from clip frame 0 instead of a crossfaded loop
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

CLIP_FPS = 24
CROSSFADE = 18
ONCE_EASE_IN = 3
CARD = (0xF2, 0xEC, 0xE2)

p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument("art")
p.add_argument("clip")
p.add_argument("out", type=Path)
p.add_argument("--start", type=int)
p.add_argument("--end", type=int, default=120)
p.add_argument("--threshold", type=float, default=3.0)
p.add_argument("--alpha-min", type=int, default=200)
p.add_argument("--box", type=lambda s: [int(v) for v in s.split(",")])
p.add_argument("--fps", type=int, default=24)
p.add_argument("--once", action="store_true")
a = p.parse_args()
start = a.start if a.start is not None else (0 if a.once else 36)

src = np.asarray(Image.open(a.art).convert("RGBA"))
H, W = src.shape[:2]
ref, alpha = src[..., :3].astype(float), src[..., 3]

tmp = Path(tempfile.mkdtemp())
subprocess.run(["ffmpeg", "-v", "error", "-i", a.clip, str(tmp / "%03d.png")], check=True)
paths = sorted(tmp.glob("*.png"))
end = min(a.end, len(paths))
if not a.once and end - start < CROSSFADE * 2 + 6:
    raise SystemExit(f"clip has {len(paths)} frames; frames {start}..{end} are too few for a loop")
frames = [np.asarray(Image.open(q).convert("RGB").resize((W, H), Image.LANCZOS)).astype(float) for q in paths[start:end]]

std = np.std(np.stack([f.mean(-1) for f in frames]), 0)
moving = (std > a.threshold) & (alpha >= a.alpha_min)
if a.box:
    x0, y0, x1, y1 = a.box
    boxed = np.zeros_like(moving)
    boxed[y0:y1, x0:x1] = True
    moving &= boxed
m = Image.fromarray(moving.astype(np.uint8) * 255)
m = m.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
m = m.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(3))
mask = np.asarray(m).astype(float) / 255 * (alpha >= a.alpha_min)
m = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.5))
mask = np.asarray(m).astype(float) / 255

n = len(frames)
looped = []
for i in range(n if a.once else n - CROSSFADE):
    f = frames[i]
    if i < CROSSFADE and not a.once:
        t = (i + 1) / (CROSSFADE + 1)
        f = frames[n - CROSSFADE + i] * (1 - t) + frames[i] * t
    looped.append(f)
looped = looped[:: max(1, round(CLIP_FPS / a.fps))]

out_frames = a.out / "frames"
out_frames.mkdir(parents=True, exist_ok=True)
for old in out_frames.glob("f*.png"):
    old.unlink()
composed = []
for k, f in enumerate(looped):
    if a.once:
        f = ref + (f - ref) * min(1.0, k / ONCE_EASE_IN)
    rgb = np.clip(np.round(ref * (1 - mask[..., None]) + f * mask[..., None]), 0, 255).astype(np.uint8)
    composed.append(rgb.astype(float))
    Image.fromarray(np.dstack([rgb, alpha])).save(out_frames / f"f{k:03d}.png")

opaque = alpha >= 200
inside = mask > 0.5
outside = opaque & (mask < 0.05)
consec = [np.abs(composed[i] - composed[i + 1])[inside].mean() for i in range(len(composed) - 1)] if inside.any() else [0]
report = {
    "frames": len(composed),
    "fps": a.fps,
    "mask_cover_pct": round(100 * inside.sum() / max(1, opaque.sum()), 1),
    "motion_in_mask": round(float(np.mean(consec)), 2),
    "loop_wrap": round(float(np.abs(composed[-1] - composed[0])[inside].mean()), 2) if inside.any() and not a.once else None,
    "clip_drift_static": round(float(np.abs(frames[0] - ref).mean(-1)[outside].mean()), 2),
    "frames_dir": str(out_frames),
}
(a.out / "report.json").write_text(json.dumps(report, indent=2))

picks = [composed[0], composed[len(composed) // 3], composed[2 * len(composed) // 3]]
tiles = [Image.fromarray(src), Image.fromarray((mask * 255).astype(np.uint8)).convert("RGBA")]
tiles += [Image.fromarray(np.dstack([f.astype(np.uint8), alpha])) for f in picks]
board = Image.new("RGBA", (W * len(tiles), H), CARD + (255,))
for i, t in enumerate(tiles):
    board.alpha_composite(t, (i * W, 0))
board.convert("RGB").resize((W * len(tiles) // 2, H // 2), Image.LANCZOS).save(a.out / "sheet.png")
report["sheet"] = str(a.out / "sheet.png")
print(json.dumps(report, indent=2))
