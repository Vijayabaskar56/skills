#!/usr/bin/env bash
# Usage: perf-measure.sh <out.json> [flow ...]
# From the app's repo root. Profiles each flow in .ship-builds.json perf.flows (or the flows named)
# perf.runs times on the booted iOS simulator and writes per-metric medians to out.json.
# Needs Metro running and a dev build installed. Prints one line per run; raw data goes to <out>.runs/.
set -euo pipefail

out="${1:?usage: perf-measure.sh <out.json> [flow ...]}"
shift
here="$(cd "$(dirname "$0")" && pwd)"
cfg=.ship-builds.json
jq -e '.perf.flows | length > 0' "$cfg" >/dev/null || { echo "no perf.flows in $cfg"; exit 2; }

bundle="$(jq -r '.ios.bundleId' "$cfg")"
runs="$(jq -r '.perf.runs // 3' "$cfg")"
retries="$(jq -r '.perf.retries // 2' "$cfg")"
ready="$(jq -r '.perf.ready' "$cfg")"
port="$(jq -r '.perf.metroPort // 8081' "$cfg")"
device="$(jq -r '.perf.device // empty' "$cfg")"
flows_dir="$(jq -r '.perf.flowsDir // ".argent/flows"' "$cfg")"
if [ "$#" -gt 0 ]; then flows="$*"; else flows="$(jq -r '.perf.flows | join(" ")' "$cfg")"; fi

if command -v argent >/dev/null; then A=(argent); else A=(npx --no-install @swmansion/argent); fi
"${A[@]}" --version >/dev/null || { echo "argent CLI not found; see references/perf.md"; exit 2; }
curl -fsS -m 3 "http://localhost:$port/status" | grep -q running ||
  { echo "Metro is not running on port $port"; exit 2; }

udid="$("${A[@]}" run list-devices --json | jq -r --arg name "$device" '
  [.devices[] | select(.platform == "ios" and .state == "Booted" and (.kind // "simulator") != "device")
   | select($name == "" or .name == $name or .udid == $name)][0].udid // empty')"
[ -n "$udid" ] || { echo "no booted iOS simulator matching '${device:-any}'"; exit 2; }

busy="$(ps -Ao pcpu=,comm= | awk '$1 > 20' | grep -E 'xcodebuild|[Gg]radle|java|clang|swift-frontend|kotlin' || true)"
if [ -n "$busy" ] && [ "${PERF_ALLOW_BUSY:-0}" != 1 ]; then
  echo "a build is using the CPU, numbers would read high; wait for it or set PERF_ALLOW_BUSY=1:"
  echo "$busy"
  exit 2
fi

raw="${out%.json}.runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$raw"
started=$(date +%s)
tree_hash() { { git status --porcelain; git diff; } | shasum | cut -c1-12; }
tree_before="$(tree_hash)"

# The flow runner times out reading the UI tree while another instrumented app (Spotlight, a
# widget renderer) sits suspended, and a restart can respawn them, so clear them every run.
clear_other_apps() {
  xcrun simctl spawn "$udid" launchctl list | sed -nE 's/.*UIKitApplication:([^[]+)\[.*/\1/p' |
    grep -vxF "$bundle" | while read -r other; do xcrun simctl terminate "$udid" "$other" || true; done
}

# One profiled run into $1. Returns 1 with a reason on stdout when the run must be retried
# (a Metro reload or a failed step ends the profiling session).
measure_once() {
  local dir="$1" yaml="$2"
  mkdir -p "$dir"
  "${A[@]}" run restart-app --udid "$udid" --bundleId "$bundle" --json >"$dir/restart.json" ||
    { echo "restart failed"; return 1; }
  "${A[@]}" run await-ui-element --udid "$udid" --condition visible \
    --selector-json "{\"identifier\":\"$ready\"}" --timeoutMs 120000 --json >"$dir/ready.json" || true
  jq -e '.success' "$dir/ready.json" >/dev/null 2>&1 || { echo "$ready never appeared"; return 1; }
  clear_other_apps
  "${A[@]}" run react-profiler-start --device_id "$udid" --port "$port" --json >"$dir/start.json" 2>&1 || true
  jq -e '.startedAtEpochMs' "$dir/start.json" >/dev/null 2>&1 || { echo "profiler did not start"; return 1; }
  local flow_ok=1
  "${A[@]}" flow run "$yaml" --device "$udid" --json >"$dir/flow.json" 2>"$dir/flow.err" || flow_ok=0
  "${A[@]}" run react-profiler-stop --device_id "$udid" --port "$port" --json >"$dir/stop.json" 2>&1 ||
    { echo "profiler stop failed (reload?), see $dir/stop.json"; return 1; }
  [ "$flow_ok" -eq 1 ] || { echo "flow failed, see $dir/flow.json"; return 1; }
  "${A[@]}" run react-profiler-analyze --device_id "$udid" --port "$port" --project_root "$PWD" \
    --platform ios --json >"$dir/analyze.json" || { echo "analyze failed"; return 1; }
  node "$here/perf-reduce.mjs" "$dir/stop.json" "$dir/analyze.json" >"$dir/metrics.json" ||
    { echo "reduce failed"; return 1; }
}

for flow in $flows; do
  yaml="$flows_dir/$flow.yaml"
  [ -f "$yaml" ] || { echo "missing $yaml"; exit 2; }
  good=0
  attempt=0
  while [ "$good" -lt "$runs" ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -le $((runs + retries)) ] || { echo "$flow: $retries retries used up"; exit 1; }
    dir="$raw/$flow-a$attempt"
    if reason="$(measure_once "$dir" "$yaml")"; then
      good=$((good + 1))
      echo "$flow run $good: $(jq -c 'del(.topRenders)' "$dir/metrics.json")"
    else
      echo "$flow attempt $attempt discarded: $reason"
    fi
  done
done

for flow in $flows; do
  jq -s --arg flow "$flow" '
    . as $all
    | (.[0] | to_entries | map(select(.value | type == "number")) | map(.key)) as $keys
    | { ($flow): (reduce $keys[] as $k ({};
          .[$k] = ([$all[] | .[$k]] | sort | if length % 2 == 1 then .[length / 2 | floor]
                   else (.[length / 2 - 1] + .[length / 2]) / 2 end))
        + { spread: (reduce $keys[] as $k ({}; .[$k] = ([$all[] | .[$k]] | [min, max]))),
            topRenders: $all[0].topRenders }) }
  ' "$raw/$flow"-a*/metrics.json
done | jq -s \
  --arg sha "$(git rev-parse --short HEAD)" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg device "$("${A[@]}" run list-devices --json | jq -r --arg u "$udid" '.devices[] | select(.udid == $u) | "\(.name) \(.runtime | split(".") | last)"')" \
  --argjson runs "$runs" \
  --argjson busy "$([ -n "$busy" ] && echo true || echo false)" \
  --arg head "$(git rev-parse HEAD)" \
  --argjson status "$(git status --porcelain | grep -vE '^##| \.|\.md"?$' | jq -R . | jq -s .)" \
  --argjson moved "$([ "$(tree_hash)" != "$tree_before" ] && echo true || echo false)" \
  '{ sha: $sha, source: { head: $head, status: $status, changedDuringRun: $moved }, busyCpu: $busy,
     date: $date,
     device: $device, runs: $runs,
     flows: add }' >"$out"
echo "wrote $out in $(( $(date +%s) - started ))s"
jq -r 'if .source.changedDuringRun then "warn source files changed while measuring; numbers mix two trees" else empty end,
  if .busyCpu then "warn a build was using the CPU; numbers read high" else empty end' "$out"
