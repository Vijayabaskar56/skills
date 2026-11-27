#!/usr/bin/env python3
"""Check a built loop before anyone sees it; exits 1 on a failed check.

Usage: audit.py <art.png> <frames dir> <anim.avif> [--budget-kb 300] [--still-is-art] [--once]
                [--protect mask.png] [--out DIR]

Checks:
  first_frame   frame 0 equals the art (max channel difference <= 2). Fails only with
                --still-is-art: when the app shows the original art as the still. encode.sh's still
                is the AVIF's own frame 0, which needs no match.
  loop_wrap     last frame to frame 0 is no bigger a jump than the largest step inside the loop.
  static_drift  pixels that never move stay the art (mean difference <= 3).
  key_spill     few half-transparent pixels are strongly green (a fringe left by a green key).
  size          the AVIF is within the budget.
  protected     with --protect (white = must stay the art): no frame changes a protected pixel by
                more than 2. Use it for the parts the request keeps still (a base tile, the other
                objects); static_drift alone can miss a builder that repainted them.
  avif_match    the encoded AVIF's first and middle frames are close to the PNG frames (mean
                difference <= 4), so the checks above describe what ships.
Also writes <out>/audit-light.png and <out>/audit-dark.png (six frames on each background); open
both, since fringes and holes show on dark and halos on light.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument("art")
p.add_argument("frames", type=Path)
p.add_argument("avif", type=Path)
p.add_argument("--budget-kb", type=int, default=300)
p.add_argument("--still-is-art", action="store_true")
p.add_argument("--once", action="store_true")
p.add_argument("--protect", type=Path)
p.add_argument("--out", type=Path)
a = p.parse_args()

art = np.asarray(Image.open(a.art).convert("RGBA")).astype(int)
paths = sorted(a.frames.glob("f*.png"))
if len(paths) < 2:
    sys.exit(f"no fNNN.png frames in {a.frames}")
frames = [np.asarray(Image.open(q).convert("RGBA")).astype(int) for q in paths]
if frames[0].shape != art.shape:
    sys.exit(f"frame size {frames[0].shape[:2]} differs from the art {art.shape[:2]}")

stack = np.stack(frames)
changed = (np.abs(stack - art).max(-1) > 6).any(0)
steps = [np.abs(frames[i + 1] - frames[i]).mean() for i in range(len(frames) - 1)]
wrap = float(np.abs(frames[-1] - frames[0]).mean())
visible = art[..., 3] > 0
first = int(np.abs(frames[0] - art)[visible].max()) if visible.any() else 0
never = visible & ~changed
drift = float(np.abs(stack[:, never] - art[never]).mean()) if never.any() else 0.0
semi = (stack[..., 3] > 10) & (stack[..., 3] < 245)
greenish = semi & (stack[..., 1] > stack[..., 0] + 40) & (stack[..., 1] > stack[..., 2] + 40)
spill = float(greenish.sum() / max(1, semi.sum()) * 100)
kb = a.avif.stat().st_size / 1024
protect = None
if a.protect:
    keep = np.asarray(Image.open(a.protect).convert("L").resize((art.shape[1], art.shape[0]))) > 127
    # Compare premultiplied colour: RGB under alpha 0 is invisible and may differ freely.
    pre = lambda x: np.concatenate([x[..., :3] * x[..., 3:] // 255, x[..., 3:]], -1)
    protect = int(np.abs(pre(stack[:, keep]) - pre(art[keep])).max()) if keep.any() else 0
decoded = []
with tempfile.TemporaryDirectory() as tmp:
    for i in sorted({0, len(frames) // 2}):
        out_png = Path(tmp) / f"{i}.png"
        if subprocess.run(["avifdec", "--index", str(i), str(a.avif), str(out_png)], capture_output=True).returncode == 0:
            got = np.asarray(Image.open(out_png).convert("RGBA")).astype(int)
            if got.shape == frames[i].shape:
                vis = (frames[i][..., 3] > 0) | (got[..., 3] > 0)
                decoded.append(float(np.abs(got - frames[i])[vis].mean()) if vis.any() else 0.0)

checks = {
    "first_frame": {"value": first, "pass": bool(not a.still_is_art or first <= 2)},
    "loop_wrap": {"value": round(wrap, 2), "largest_step": round(max(steps), 2), "pass": bool(a.once or wrap <= max(steps) * 1.25 + 0.5)},
    "static_drift": {"value": round(drift, 2), "pass": bool(drift <= 3)},
    "key_spill_pct": {"value": round(spill, 2), "pass": bool(spill <= 2)},
    "size_kb": {"value": round(kb), "budget": a.budget_kb, "pass": bool(kb <= a.budget_kb)},
    "avif_match": {"value": round(max(decoded), 2) if decoded else None, "pass": bool(decoded and max(decoded) <= 4)},
}
if protect is not None:
    checks["protected"] = {"value": protect, "pass": bool(protect <= 2)}
out = a.out or a.frames.parent
out.mkdir(parents=True, exist_ok=True)
picks = [frames[round(i * (len(frames) - 1) / 5)] for i in range(6)]
H, W = art.shape[:2]
for name, bg in (("light", (0xF2, 0xEC, 0xE2)), ("dark", (0x18, 0x18, 0x18))):
    board = Image.new("RGBA", (W * 3, H * 2), bg + (255,))
    for i, f in enumerate(picks):
        board.alpha_composite(Image.fromarray(f.astype(np.uint8)), ((i % 3) * W, (i // 3) * H))
    board.convert("RGB").save(out / f"audit-{name}.png")
ok = bool(all(c["pass"] for c in checks.values()))
print(json.dumps({"pass": ok, "frames": len(frames), "moving_pct": round(100 * (changed & visible).sum() / max(1, visible.sum()), 1),
                  "checks": checks, "boards": [str(out / "audit-light.png"), str(out / "audit-dark.png")]}, indent=2))
sys.exit(0 if ok else 1)
