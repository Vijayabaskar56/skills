#!/usr/bin/env bash
# Usage: doctor.sh
# Checks what html-report needs outside itself. Prints "ok", "missing" with the fix, or "session"
# for what only the agent can confirm. Exits 1 when anything is missing.
set -euo pipefail

status=0
if command -v python3 >/dev/null 2>&1; then
  version="$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
  if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
    echo "ok python3 $version"
  else
    echo "missing python3 >= 3.9 (found $version): see references/setup.md"
    status=1
  fi
else
  echo "missing python3 >= 3.9: see references/setup.md"
  status=1
fi
echo "session Artifact tool: confirm it is in your tool list before step 6 (publish)"
exit "$status"
