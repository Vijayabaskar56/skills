#!/usr/bin/env bash
# Usage: device-build.sh --repo DIR release|debug [--skip-build]
# release: runs the build command from DIR/.perf-check.json (release.build), installs release.apk
#          over the app on the device with install -r, and relaunches it.
# debug:   reinstalls release.debugApk so the device is back on the development build.
# Prints the installed APK path and its build time. Exits 1 when the build or install fails.
set -euo pipefail

repo=""; mode=""; skip_build=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo needs a value}"; shift 2 ;;
    --skip-build) skip_build=1; shift ;;
    release|debug) mode="$1"; shift ;;
    *) echo "error unknown argument $1"; exit 1 ;;
  esac
done
[ -n "$repo" ] && [ -n "$mode" ] || { echo "error usage: device-build.sh --repo DIR release|debug [--skip-build]"; exit 1; }
config="$repo/.perf-check.json"
[ -f "$config" ] || { echo "error $config is missing: follow references/first-run.md"; exit 1; }

field() { python3 -c "import json,sys; c=json.load(open(sys.argv[1])); v=c; [v:=v.get(k, {}) for k in sys.argv[2].split('.')]; print(v if isinstance(v, str) else '')" "$config" "$1"; }
package="$(field android.package)"
serial="$(field android.serial)"
[ -n "$serial" ] || serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
[ -n "$serial" ] || { echo "error no Android device connected"; exit 1; }

if [ "$mode" = release ]; then
  apk="$repo/$(field release.apk)"
  if [ "$skip_build" = 0 ]; then
    log="$(mktemp -t perf-check-build).log"
    echo "build running: $(field release.build)"
    if ! (cd "$repo" && bash -c "$(field release.build)") >"$log" 2>&1; then
      echo "error release build failed; last lines of $log:"; tail -15 "$log"; exit 1
    fi
  fi
else
  apk="$repo/$(field release.debugApk)"
fi
[ -f "$apk" ] || { echo "error $apk does not exist"; exit 1; }

out="$(adb -s "$serial" install -r "$apk" 2>&1 | tail -1)"
case "$out" in
  Success*) ;;
  *UPDATE_INCOMPATIBLE*) echo "error install refused: $mode is signed with a different key than the installed app; references/troubleshooting.md"; exit 1 ;;
  *) echo "error install failed: $out"; exit 1 ;;
esac
adb -s "$serial" shell am force-stop "$package"
adb -s "$serial" shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
echo "installed $mode $apk built $(date -r "$apk" '+%Y-%m-%d %H:%M')"
