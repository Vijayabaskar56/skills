#!/usr/bin/env bash
# Usage: encode.sh <frames dir> <out dir> <name> [--once] [--fps 24] [--quality 60] [--qalpha 90] [--still-lossless]
#
# Encodes fNNN.png frames into <out>/<name>.avif (loops forever, or plays once and holds the last
# frame with --once), <out>/<name>-still.webp (the AVIF's own decoded frame 0 as WebP q90: close to
# the first frame, not pixel-exact; --still-lossless makes it exact and larger) and
# <out>/<name>-preview.gif (light and dark backgrounds side by side) for review. --qalpha is the alpha plane's quality and often the biggest size lever: a mostly opaque
# scene with a soft edge holds up at --quality 50 --qalpha 50. Needs avifenc, avifdec, ffmpeg and Python with Pillow ($MAGNIFIC_PY or python3).
set -euo pipefail

[[ $# -ge 3 ]] || { sed -n '2,8p' "$0"; exit 2; }
frames=$1 out=$2 name=$3; shift 3
fps=24 quality=60 qalpha=90 repeat=infinite still_opts="quality=90"
while [[ $# -gt 0 ]]; do
  case $1 in
    --once) repeat=0; shift ;;
    --fps) fps=$2; shift 2 ;;
    --quality) quality=$2; shift 2 ;;
    --qalpha) qalpha=$2; shift 2 ;;
    --still-lossless) still_opts="lossless=True, exact=True"; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
py=${MAGNIFIC_PY:-python3}
mkdir -p "$out"
shopt -s nullglob
list=("$frames"/f*.png)
(( ${#list[@]} > 1 )) || { echo "no fNNN.png frames in $frames" >&2; exit 1; }

avifenc -j all -s 6 -q "$quality" --qalpha "$qalpha" --yuv 420 --timescale "$fps" --duration 1 \
  --repetition-count "$repeat" "${list[@]}" "$out/$name.avif" >/dev/null
first=$(mktemp -t first).png
avifdec --index 0 "$out/$name.avif" "$first" >/dev/null
"$py" -c "import sys; from PIL import Image; Image.open(sys.argv[1]).convert('RGBA').save(sys.argv[2], 'WEBP', $still_opts)" \
  "$first" "$out/$name-still.webp"

read -r w h < <("$py" -c "import sys; from PIL import Image; s=Image.open(sys.argv[1]).size; print(s[0]+s[0]%2, s[1]+s[1]%2)" "${list[0]}")
ffmpeg -v error -y -framerate "$fps" -stream_loop 2 -i "$frames/f%03d.png" -filter_complex \
  "[0]split[x][y];color=0xF2ECE2:s=${w}x${h}[l];color=0x181818:s=${w}x${h}[d];[l][x]overlay=shortest=1[ll];[d][y]overlay=shortest=1[dd];[ll][dd]hstack,scale=$((w)):-1,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
  "$out/$name-preview.gif"

kb=$(( $(wc -c < "$out/$name.avif") / 1024 ))
echo "{\"avif\": \"$out/$name.avif\", \"still\": \"$out/$name-still.webp\", \"preview\": \"$out/$name-preview.gif\", \"frames\": ${#list[@]}, \"fps\": $fps, \"avif_kb\": $kb, \"repeat\": \"$repeat\", \"quality\": $quality, \"qalpha\": $qalpha}"
