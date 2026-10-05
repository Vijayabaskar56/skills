#!/usr/bin/env bash
# Usage: doctor.sh
# Checks what btca needs. Prints "ok <item> <detail>" or "missing <item> <how to fix>" per line,
# then "session <item> <what to confirm>" for checks only the agent can make. Exits 1 when
# anything is missing. The references dir is $BTCA_REFERENCES_DIR, default ~/work/references.
set -euo pipefail

refs="${BTCA_REFERENCES_DIR:-$HOME/work/references}"
missing=0

if out="$(git --version 2>/dev/null)"; then echo "ok git $out"
else echo "missing git install git (xcode-select --install, or your package manager)"; missing=1; fi

if [ -d "$refs" ]; then
  count=0
  for d in "$refs"/*/; do [ -e "${d}.git" ] && count=$((count + 1)); done
  echo "ok references-dir $(cd "$refs" && pwd) ($count git repos)"
else
  echo "missing references-dir $refs does not exist; create it (mkdir -p) or set BTCA_REFERENCES_DIR to an existing folder"
  missing=1
fi

echo "session subagent confirm a read-only search subagent can be dispatched (Explore in Claude Code)"
echo "session model confirm the cheapest available model for that subagent (haiku in Claude Code)"
exit "$missing"
