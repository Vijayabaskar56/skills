#!/usr/bin/env bash
# Usage: doctor.sh
# Checks what write-great-skills needs outside itself. Prints one line per dependency:
# "ok", "missing" with the fix, "optional", or "session" for what only the agent can confirm.
# Exits 1 when anything required is missing.
set -euo pipefail

missing=0
need() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "ok $1"
  else
    echo "missing $1: $2"
    missing=1
  fi
}

need bash "install bash 3.2 or later"
need find "install findutils"
for tool in grep sed awk tr wc cut; do
  need "$tool" "install the POSIX $tool utility"
done

if command -v shellcheck >/dev/null 2>&1; then
  echo "ok shellcheck"
else
  echo "optional shellcheck: deeper checks for skill scripts (brew install shellcheck or apt install shellcheck)"
fi

echo "session unslop: confirm the unslop skill is in your skill list; the hard rules run it on the prose"

exit "$missing"
