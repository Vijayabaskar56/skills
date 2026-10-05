#!/usr/bin/env bash
# Usage: find-color-token.sh <color> [cssFile]
# Run from the repo root. <color> is #rgb, #rrggbb, #rrggbbaa, rgb(r,g,b) or rgba(r,g,b,a).
# Prints every line of cssFile (default global.css) whose colour has exactly the same RGB channels,
# in hex or rgb()/rgba() notation, so the token and its alpha can be read. Exits 1 when nothing
# matches exactly: add a token or ask the user; never take the nearest-looking token.
set -euo pipefail

color="${1:?Usage: find-color-token.sh <color> [cssFile]}"
css="${2:-global.css}"
[ -f "$css" ] || { echo "no $css; run from the repo root or pass the css file" >&2; exit 2; }

input="$(printf '%s' "$color" | tr 'A-F' 'a-f' | tr -d ' ')"
case "$input" in
  \#???) h="${input:1}"; hex="${h:0:1}${h:0:1}${h:1:1}${h:1:1}${h:2:1}${h:2:1}" ;;
  \#??????|\#????????) hex="${input:1:6}" ;;
  rgb*)
    nums="$(printf '%s' "$input" | sed -nE 's/^rgba?\(([0-9]+),([0-9]+),([0-9]+)[,)].*/\1 \2 \3/p')"
    [ -n "$nums" ] || { echo "unrecognised colour '$color'" >&2; exit 2; }
    read -r r g b <<<"$nums"
    hex="$(printf '%02x%02x%02x' "$r" "$g" "$b")" ;;
  *) echo "unrecognised colour '$color'" >&2; exit 2 ;;
esac
[[ "$hex" =~ ^[0-9a-f]{6}$ ]] || { echo "unrecognised colour '$color'" >&2; exit 2; }

r=$((16#${hex:0:2})); g=$((16#${hex:2:2})); b=$((16#${hex:4:2}))
pattern="#${hex}([0-9a-f]{2})?([^0-9a-f]|\$)"
pattern+="|rgba?\\( *${r} *[, ] *${g} *[, ] *${b} *[,/)]"
if [ "${hex:0:1}" = "${hex:1:1}" ] && [ "${hex:2:1}" = "${hex:3:1}" ] && [ "${hex:4:1}" = "${hex:5:1}" ]; then
  pattern+="|#${hex:0:1}${hex:2:1}${hex:4:1}[0-9a-f]?([^0-9a-f]|\$)"
fi

if ! grep -inE "$pattern" "$css"; then
  echo "no exact token for #${hex} (rgb ${r}, ${g}, ${b}) in $css; add a token or ask the user"
  exit 1
fi
