#!/usr/bin/env bash
# Usage: close.sh <owner-token|none> | close.sh --force
# Stop the headed Chromium and the :99 display if this task started them (the token open.sh printed).
# "none" or another task's token leaves everything running. --force stops it regardless.
set -euo pipefail

ARG="${1:?usage: close.sh <owner-token|none> | close.sh --force}"
AD="$(command -v agent-display || echo "$(dirname "$0")/agent-display")"
STATE="$HOME/.local/share/agent-display"
OWNER="$STATE/owner"
PROFILE="$STATE/chrome-profile"

running() { pgrep -f "X(vfb|tigervnc) :99( |$)|--user-data-dir=$PROFILE" >/dev/null 2>&1; }

if ! running; then
  rm -f "$OWNER"
  echo "stopped"
  exit 0
fi

if [[ "$ARG" != "--force" ]]; then
  current="$(cat "$OWNER" 2>/dev/null || true)"
  if [[ "$ARG" == "none" || "$ARG" != "$current" ]]; then
    echo "left running: another task owns display :99"
    exit 0
  fi
fi

pkill -f -- "--user-data-dir=$PROFILE" 2>/dev/null || true
"$AD" stop >/dev/null
rm -f "$OWNER"
for _ in $(seq 1 20); do
  running || break
  sleep 0.25
done
if running; then
  echo "error: display or chromium still running after stop" >&2
  exit 1
fi
echo "stopped"
