#!/usr/bin/env bash
# Usage: doctor.sh [--repo DIR]
# Checks what perf-check needs: adb with a connected Android device, python3 with the perfetto
# package, git, and DIR/.perf-check.json. Prints ok, missing with the fix, optional, or session.
# Exits 1 when anything required is missing.
set -euo pipefail

repo=.
if [ "${1:-}" = --repo ]; then repo="${2:?--repo needs a value}"; fi
missing=0
ok() { echo "ok       $*"; }
miss() { echo "missing  $*"; missing=1; }

command -v git >/dev/null 2>&1 && ok git || miss "git: install it with the system package manager"
if command -v adb >/dev/null 2>&1; then
  ok adb
  devices="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
  if [ -n "$devices" ]; then ok "android device: $(echo "$devices" | tr '\n' ' ')"; else miss "android device: connect one with USB debugging on (references/setup.md)"; fi
else
  miss "adb: install Android platform-tools (references/setup.md)"
fi
if command -v python3 >/dev/null 2>&1; then
  ok python3
  if python3 -c "import perfetto.trace_processor" >/dev/null 2>&1; then ok "python perfetto"; else miss "python perfetto: pip3 install --user perfetto"; fi
else
  miss "python3: install Python 3.9 or newer"
fi
if [ -f "$repo/.perf-check.json" ]; then ok ".perf-check.json"; else echo "optional .perf-check.json: the first run writes it (references/first-run.md)"; fi
echo "session  the device screen is on, unlocked and not used by another agent for the whole run"
exit "$missing"
