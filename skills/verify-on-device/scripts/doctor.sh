#!/usr/bin/env bash
# Usage: doctor.sh [ios|android|both]
# Checks what verify-on-device needs. Prints "ok <item> <detail>", "missing <item> <fix>",
# "optional <item> <note>" or "session <item> <what to confirm>". Exits 1 when anything is missing.
# Install steps: references/setup.md.
set -euo pipefail

platform="${1:-ios}"
here="$(cd "$(dirname "$0")" && pwd)"
cfg() { "$here/config.sh" "$@"; }
missing=0

check() {
  local item="$1" cmd="$2" fix="$3" out
  if out="$(eval "$cmd" 2>&1)" && [ -n "$out" ]; then echo "ok $item ${out%%$'\n'*}"
  else echo "missing $item $fix"; missing=1; fi
}

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$root/.verify-on-device.json" ]; then echo "ok config $root/.verify-on-device.json"
else echo "missing config run the first-run setup (references/first-run.md)"; missing=1; fi

check jq "jq --version" "brew install jq"
check argent "argent --version" "npx @swmansion/argent@latest init -y"
check ffmpeg "ffmpeg -version" "brew install ffmpeg"

if [ "$platform" = ios ] || [ "$platform" = both ]; then
  check xcrun "xcrun simctl help >/dev/null && xcodebuild -version" "install Xcode"
  app="$(cfg '.ios.simulatorApp')"
  if [ -n "$app" ]; then
    if [ -d "$app" ]; then echo "ok simulator-app $app"
    else echo "missing simulator-app $app not found; install that Xcode or fix ios.simulatorApp"; missing=1; fi
  else
    echo "optional simulator-app none configured; the default Simulator is used"
  fi
fi

if [ "$platform" = android ] || [ "$platform" = both ]; then
  check adb "adb version" "install Android Studio platform-tools and put them on PATH"
  start="$(cfg '.android.start')"
  if [ -n "$start" ]; then
    tool="${start%% *}"
    check "$tool" "command -v $tool" "install $tool, or clear android.start to fall back to argent boot-device"
  fi
fi

echo "session argent-mcp confirm the argent MCP tools (list-devices, describe, flow-execute) are callable"
exit "$missing"
