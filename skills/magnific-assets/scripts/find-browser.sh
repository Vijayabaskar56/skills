#!/usr/bin/env bash
# Find a browser driver that can work Magnific's web app as the signed-in user.
# Usage:
#   find-browser.sh                 print the first driver that works, as JSON
#   find-browser.sh --magnific      also check it is signed in to Magnific and Relax mode is on
#   find-browser.sh --magnific --cmd "ardia browse --session mg-x --pin-tab"
#                                   check this exact command prefix instead of searching: the one
#                                   that will generate. Logins can differ per browser profile and
#                                   per tab, so an unscoped check can pass while your tab is
#                                   signed out.
#
# Prints {"driver": ..., "cmd": ..., "note": ...}. `cmd` is the command prefix to run browser
# commands with (open, eval, snapshot -i, fill, click: ardia and agent-browser share them), or
# null for driver "manual": then the person generates in the web app by hand.
# Order: Ardia (the user's own browser and logins), agent-browser attached to a running Chrome,
# agent-browser launching the Chrome profile, then manual. Magnific's bot protection refuses
# headless browsers, so agent-browser always runs headed.
set -uo pipefail

CHECK_MAGNIFIC=0 CMD=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --magnific) CHECK_MAGNIFIC=1; shift ;;
    --cmd) CMD=$2; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

emit() { printf '{"driver": "%s", "cmd": %s, "note": "%s"}\n' "$1" "$2" "$3"; }

works() { # run a harmless eval through the driver prefix in $@
  if command -v timeout >/dev/null 2>&1; then timeout 40 "$@" eval '1+1' >/dev/null 2>&1
  else "$@" eval '1+1' >/dev/null 2>&1; fi
}

magnific_ok() { # signed in and Relax on, checked from a magnific.com page
  "$@" open "https://www.magnific.com/app/ai-video-generator" >/dev/null 2>&1 || return 2
  "$@" wait 4000 >/dev/null 2>&1
  local out
  out=$("$@" eval '(async()=>{const x=decodeURIComponent(document.cookie.match(/XSRF-TOKEN=([^;]+)/)?.[1]||"");const h={accept:"application/json","x-xsrf-token":x};const v=await fetch("/app/api/auth/verify?lang=en_US",{headers:h});if(v.status!==200)return "signed-out "+v.status;const id=(await v.json()).userData?.fpId;if(!id)return "signed-out";const s=await (await fetch(`/app/api/unlimited-status?lang=en_US&user_id=${id}`,{headers:h})).json();return s.is_unlimited_mode_enabled?"ok":"relax-off"})()' 2>/dev/null | tail -1 | tr -d '"')
  echo "$out"
}

try() { # driver name, note, command prefix...
  local name=$1 note=$2; shift 2
  # A scoped tab (a pinned session) has no page until open, so check it through magnific_ok.
  if [[ -n "$CMD" && $CHECK_MAGNIFIC == 1 ]]; then :; else works "$@" || return 1; fi
  if (( CHECK_MAGNIFIC )); then
    local m; m=$(magnific_ok "$@")
    case "$m" in
      ok) note="$note; signed in to Magnific, Relax on" ;;
      relax-off) note="$note; signed in, but Relax mode is OFF: turn it on (the ON/OFF switch next to Generate) before generating" ;;
      *) note="$note; NOT signed in to Magnific ($m): sign in in this browser, then rerun" ;;
    esac
  fi
  local json; json=$(printf '"%s"' "$*")
  emit "$name" "$json" "$note"
  exit 0
}

if [[ -n "$CMD" ]]; then
  read -ra prefix <<< "$CMD"
  try "${prefix[0]}" "the command you gave" "${prefix[@]}"
  emit manual null "the command you gave did not answer: $CMD"
  exit 1
fi

if command -v ardia >/dev/null 2>&1; then
  try ardia "Ardia: your own browser, tabs and logins" ardia browse
fi

if command -v agent-browser >/dev/null 2>&1; then
  try agent-browser-attach "agent-browser attached to your running Chrome (its logins)" agent-browser --auto-connect
  for app in "Google Chrome" "Chromium" "Brave Browser" "Microsoft Edge"; do
    if [[ -d "/Applications/$app.app" ]]; then
      try agent-browser-profile "agent-browser opening $app's Default profile in a window; quit $app first so the profile is free" \
        agent-browser --headed --profile Default
      break
    fi
  done
fi

hint="no browser driver found"
command -v agent-browser >/dev/null 2>&1 || hint="$hint (install one: npm i -g agent-browser && agent-browser install)"
emit manual null "$hint; generate in the Magnific web app by hand (references/browser-drivers.md, Manual)"
