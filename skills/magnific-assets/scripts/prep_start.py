#!/usr/bin/env python3
"""Make the start image Magnific gets: the art, scaled up, on a flat background.

Usage: prep_start.py <art.png> <out.png> [--bg green|white] [--scale 2]

green (0,177,64) keys out cleanly when the moving part has to be cut from the clip (it moves past
its outline in the art, or has white edges). white suits clips whose moving pixels stay inside the
art's outline. Prints the output size as JSON.
"""
import argparse
import json

from PIL import Image

BACKGROUNDS = {"green": (0, 177, 64), "white": (255, 255, 255)}

p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument("art")
p.add_argument("out")
p.add_argument("--bg", choices=sorted(BACKGROUNDS), default="green")
p.add_argument("--scale", type=float, default=2.0)
a = p.parse_args()

src = Image.open(a.art).convert("RGBA")
size = (round(src.width * a.scale), round(src.height * a.scale))
big = src.resize(size, Image.LANCZOS)
plate = Image.new("RGBA", size, BACKGROUNDS[a.bg] + (255,))
plate.alpha_composite(big)
plate.convert("RGB").save(a.out)
print(json.dumps({"start": a.out, "size": size, "bg": a.bg}))
