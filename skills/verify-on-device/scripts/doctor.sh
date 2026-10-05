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

repo_file() {
  local item="$1" path
  path="$(cfg "$2")"
  if [ -z "$path" ]; then echo "optional $item none configured"
  elif [ -e "$root/$path" ]; then echo "ok $item $path"
  else echo "missing $item $path not found; fix $2 in .verify-on-device.json"; missing=1; fi
}
repo_file notes .notes
repo_file deep-links .deepLinks

rec="$(cfg '.recordingsDir' .argent/recordings)"
argent_rec="$(cd "$root" && argent config get recordings.directory 2>/dev/null || true)"
case "$argent_rec" in
  "" | "(unset)") argent_rec=.argent/recordings ;;
esac
if [ "$argent_rec" = "$rec" ] || [ "$argent_rec" = "$root/$rec" ]; then echo "ok recordings-dir $rec"
else echo "missing recordings-dir argent saves to $argent_rec but recordingsDir is $rec; make them match"; missing=1; fi

if [ "$platform" = ios ] || [ "$platform" = both ]; then
  check xcrun "xcrun simctl help >/dev/null && xcodebuild -version" "install Xcode"
  device="$(cfg '.ios.device')"
  if [ -z "$device" ]; then echo "missing ios-device set ios.device in .verify-on-device.json"; missing=1
  else check ios-device "'$here/open-simulator.sh' --resolve-only '$device'" \
    "no simulator named '$device'; create it in Xcode or fix ios.device"; fi
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
  check emulator "command -v emulator" "put the Android SDK emulator directory on PATH"
  avd="$(cfg '.android.avd')"
  if [ -z "$avd" ]; then echo "missing android-avd set android.avd in .verify-on-device.json"; missing=1
  elif command -v emulator >/dev/null && emulator -list-avds 2>/dev/null | grep -qxF -- "$avd"; then
    echo "ok android-avd $avd"
  else
    echo "missing android-avd '$avd' is not in emulator -list-avds; create it or fix android.avd"; missing=1
  fi
  start="$(cfg '.android.start')"
  if [ -n "$start" ]; then
    tool="${start%% *}"
    check "$tool" "command -v $tool" "install $tool, or clear android.start to fall back to argent boot-device"
  fi
fi

echo "session argent-mcp confirm the argent MCP tools (list-devices, describe, flow-execute) are callable"
exit "$missing"
