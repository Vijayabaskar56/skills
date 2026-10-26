#!/usr/bin/env bash
# Usage: contact-sheet.sh <video.mp4> <out.png> [fps] [crop]
# Tiles a recording into one 8x6 sheet at fps frames per second (default 4), each frame cropped
# with an ffmpeg crop expression (default the whole frame, e.g. "600:900:300:700" is w:h:x:y in
# video pixels) and scaled to 240 px wide. A swing settles in a second or two; single screenshots
# miss the extremes, the sheet does not. Pull one frame at full size with:
#   ffmpeg -ss <seconds> -i <video> -frames:v 1 <frame.png>
set -euo pipefail

video="$1" out="$2" fps="${3:-4}" crop="${4:-iw:ih:0:0}"
seconds="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video")"
frames="$(awk -v s="$seconds" -v f="$fps" 'BEGIN { printf "%d", s * f + 0.999 }')"
if [ "$frames" -gt 48 ]; then
  echo "fail ${seconds}s at $fps fps is $frames frames; one sheet holds 48. Lower fps or trim the video" >&2
  exit 1
fi
ffmpeg -loglevel error -y -i "$video" -vf "fps=$fps,crop=$crop,scale=240:-1,tile=8x6" -frames:v 1 "$out"
echo "sheet $out ($fps fps, 48 frames = $((48 / fps)) s)"
