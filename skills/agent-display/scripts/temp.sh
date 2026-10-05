#!/usr/bin/env bash
# Usage: temp.sh [limit-celsius]
# Print the hottest thermal zone as "temp <N>C". Exit 1 when it is at or above the limit (default 90).
set -euo pipefail

LIMIT="${1:-90}"
max=0
for zone in /sys/class/thermal/thermal_zone*/temp; do
  [[ -r "$zone" ]] || continue
  value=$(( $(cat "$zone") / 1000 ))
  (( value > max )) && max=$value
done
if (( max == 0 )); then
  echo "temp unknown"
  exit 0
fi
echo "temp ${max}C"
(( max < LIMIT ))
