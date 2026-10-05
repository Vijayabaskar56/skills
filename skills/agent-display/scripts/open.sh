#!/usr/bin/env bash
# Usage: open.sh [--vnc] <url>
# Reuse or start the :99 display and the headed Chromium on DevTools :9222, then open <url>.
# Prints: owner <token|none>, display started|reused, chrome started|reused, cdp <endpoint>.
# Pass the owner token to close.sh; "none" means another task owns the display, so leave it running.
set -euo pipefail

VNC=""
if [[ "${1:-}" == "--vnc" ]]; then VNC="--vnc"; shift; fi
URL="${1:?usage: open.sh [--vnc] <url>}"

AD="$(command -v agent-display || echo "$(dirname "$0")/agent-display")"
STATE="$HOME/.local/share/agent-display"
OWNER="$STATE/owner"
CDP="http://127.0.0.1:9222"
mkdir -p "$STATE"

display_up() { pgrep -f "X(vfb|tigervnc) :99( |$)" >/dev/null 2>&1; }
cdp_up() { curl -fsS --max-time 2 "$CDP/json/version" >/dev/null 2>&1; }

token="none"
if display_up; then
  mode="$(cat "$STATE/display.mode" 2>/dev/null || echo xvfb)"
  if [[ -n "$VNC" && "$mode" != "vnc" ]]; then
    echo "error: display :99 runs without VNC and another task may be using it; ask before restarting it" >&2
    exit 3
  fi
  echo "display reused"
else
  token="$(date +%s)-$$"
  "$AD" start $VNC >/dev/null
  echo "$token" >"$OWNER"
  echo "display started"
fi

if cdp_up; then
  curl -fsS --max-time 5 -X PUT "$CDP/json/new?$URL" >/dev/null
  echo "chrome reused"
else
  setsid nohup "$AD" chrome --new-window "$URL" >"$STATE/chrome.log" 2>&1 </dev/null &
  for _ in $(seq 1 40); do cdp_up && break; sleep 0.5; done
  if ! cdp_up; then
    echo "error: chromium did not open DevTools on :9222; see $STATE/chrome.log" >&2
    exit 1
  fi
  echo "chrome started"
fi

echo "owner $token"
echo "cdp $CDP"
