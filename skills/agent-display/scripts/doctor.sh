#!/usr/bin/env bash
# Usage: doctor.sh
# Check what agent-display needs. Prints ok, missing (with the fix), optional or session per line.
# Exit 1 when anything required is missing.
set -euo pipefail

missing=0
need() {
  if command -v "$2" >/dev/null 2>&1; then echo "ok       $1"; else echo "missing  $1: $3"; missing=1; fi
}
want() {
  if command -v "$2" >/dev/null 2>&1; then echo "ok       $1"; else echo "optional $1: $3"; fi
}

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "missing  linux: agent-display runs on a Linux host; here, drive the browser headless"
  exit 1
fi
need agent-display agent-display "see references/setup.md"
need Xvfb Xvfb "install xorg-server-xvfb (Arch) or xvfb (Debian)"
need chromium chromium "install chromium"
need curl curl "install curl"
need setsid setsid "install util-linux"
want Xtigervnc Xtigervnc "install tigervnc, only for watching with --vnc"
want agent-browser agent-browser "npm i -g agent-browser, or drive Chromium with Playwright"
echo "session  display: $(agent-display status 2>/dev/null | tail -1 || echo unknown)"
echo "session  $("$(dirname "$0")/temp.sh" 100 || true)"
exit "$missing"
