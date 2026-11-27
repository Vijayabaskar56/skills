#!/usr/bin/env bash
# Usage: doctor.sh [--cmd "<browser command prefix>"]
#
# With --cmd, the browser line checks that exact prefix (a scoped or pinned tab) through
# find-browser.sh --cmd, instead of the first driver it finds.
#
# Checks what magnific-assets needs outside itself. Prints one line per item: ok, missing (with
# the fix), optional, or session (only the agent can confirm it). Exits 1 if anything is missing.
# Fixes are in references/setup.md; ask the user before installing anything.
set -uo pipefail

missing=0
ok() { echo "ok $1"; }
miss() { echo "missing $1: $2"; missing=1; }

for t in ffmpeg ffprobe avifenc avifdec; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t"; else
    case $t in
      ff*) miss "$t" "brew install ffmpeg" ;;
      avif*) miss "$t" "brew install libavif" ;;
    esac
  fi
done

py=${MAGNIFIC_PY:-python3}
if "$py" -c "import numpy, scipy, PIL" >/dev/null 2>&1; then
  ok "python ($py) with numpy, scipy, Pillow"
else
  miss "python with numpy, scipy, Pillow" "make a venv (references/setup.md) and export MAGNIFIC_PY=<venv>/bin/python"
fi

CMD=""
[[ "${1:-}" == "--cmd" ]] && CMD=${2:-}
here=$(cd "$(dirname "$0")" && pwd)
args=()
[[ -n "$CMD" ]] && args=(--magnific --cmd "$CMD")
driver=$("$here/find-browser.sh" ${args[@]+"${args[@]}"} 2>/dev/null | sed -n 's/.*"driver": "\([^"]*\)".*/\1/p')
if [[ -n "$driver" && "$driver" != manual ]]; then
  ok "browser driver: $driver"
else
  echo "optional browser driver: none found; generation is the manual web step (references/browser-drivers.md)"
fi

echo "session Magnific sign-in and Relax mode: run scripts/find-browser.sh --magnific --cmd \"<the exact prefix that will generate>\", or check the web app by hand"
echo "session Magnific MCP (optional, read-only checks): confirm a magnific tool such as creations_cost answers"
exit $missing
