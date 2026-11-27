#!/usr/bin/env bash
# Usage: contact_sheet.sh <clip.mp4> <out.png> [--every N] [--first M] [--cols C] [--width W] [--crop w:h:x:y]
#
# A grid of every Nth frame (default 10) of the first M frames (default all), each W px wide
# (default 240), C per row (default 6). Read it to see how far and where the clip moves before
# building anything; --first 15 --every 2 shows the opening, where Kling's motion is smallest.
set -euo pipefail

[[ $# -ge 2 ]] || { sed -n '2,7p' "$0"; exit 2; }
clip=$1 out=$2; shift 2
every=10 first=0 cols=6 width=240 crop=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --every) every=$2; shift 2 ;;
    --first) first=$2; shift 2 ;;
    --cols) cols=$2; shift 2 ;;
    --width) width=$2; shift 2 ;;
    --crop) crop="crop=$2,"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

total=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$clip")
span=$total
(( first > 0 && first < total )) && span=$first
picked=$(( (span + every - 1) / every ))
rows=$(( (picked + cols - 1) / cols ))
ffmpeg -v error -y -i "$clip" \
  -vf "select='lt(n\,$span)*not(mod(n\,$every))',${crop}scale=$width:-1,tile=${cols}x${rows}" \
  -frames:v 1 "$out"
echo "{\"sheet\": \"$out\", \"clip_frames\": $total, \"shown\": $picked, \"every\": $every}"
