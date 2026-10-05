#!/usr/bin/env bash
# Usage: open-simulator.sh [--resolve-only] <deviceName|udid> [simulatorApp]
# Resolves an iOS simulator by name (or UDID) from `xcrun simctl list devices -j`, preferring a
# booted one, then the newest runtime. With --resolve-only it prints "<udid> <state> <runtime>" and
# stops. Otherwise it boots the device if needed, quits DeviceHub, opens the device in simulatorApp
# (default: the config's ios.simulatorApp, else the default Simulator) and prints the UDID.
# Exits 1 when the device is not found or DeviceHub is still running afterwards. Safe to rerun.
set -euo pipefail

resolve_only=0
if [ "${1:-}" = --resolve-only ]; then resolve_only=1; shift; fi
device="${1:?Usage: open-simulator.sh [--resolve-only] <deviceName|udid> [simulatorApp]}"
here="$(cd "$(dirname "$0")" && pwd)"

match="$(xcrun simctl list devices -j | jq -r --arg d "$device" '
  [.devices | to_entries[] | .key as $rt | .value[]
    | select(.isAvailable == true and (.name == $d or .udid == $d))
    | . + {runtime: ($rt | sub("^com.apple.CoreSimulator.SimRuntime."; "")),
           version: ($rt | [scan("[0-9]+") | tonumber])}]
  | sort_by([(if .state == "Booted" then 1 else 0 end), .version]) | last
  | if . == null then empty else "\(.udid) \(.state) \(.runtime)" end')"
if [ -z "$match" ]; then
  echo "no available simulator named '$device'; run: xcrun simctl list devices available" >&2
  exit 1
fi
udid="${match%% *}"
if [ "$resolve_only" -eq 1 ]; then echo "$match"; exit 0; fi

app="${2:-$("$here/config.sh" '.ios.simulatorApp')}"
[ -z "$app" ] || [ -d "$app" ] || { echo "simulator app not found: $app" >&2; exit 1; }

xcrun simctl bootstatus "$udid" -b >/dev/null

if pgrep -x DeviceHub >/dev/null; then osascript -e 'quit app "DeviceHub"'; fi
if [ -n "$app" ]; then open -a "$app" --args -CurrentDeviceUDID "$udid"
else open -a Simulator --args -CurrentDeviceUDID "$udid"; fi

for _ in 1 2 3 4 5; do
  pgrep -x DeviceHub >/dev/null || { echo "$udid"; exit 0; }
  sleep 1
done
echo "DeviceHub is still running; quit it, then rerun (references/troubleshooting.md)" >&2
exit 1
