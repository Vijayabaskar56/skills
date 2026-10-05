#!/usr/bin/env bash
# Usage: check-rule.sh <rule-name>
# Run from the shadcn-x repo root. Checks that a lint rule is registered everywhere it must be:
# rule file, import + rules entry + recommended entry in src/lint/index.ts, oxlint.config.ts,
# both rule lists in AGENTS.md (## On-system rules and the src/lint/ bullet in ## Layout),
# and a test file in tests/lint/ or tests/lint/rules/. Prints ok/missing per check and the
# configured level. Exits 1 when any check is missing, 2 on bad usage.
set -euo pipefail

name="${1:?usage: check-rule.sh <rule-name>}"
printf '%s' "$name" | grep -qE '^[a-z][A-Za-z-]*$' || { echo "error rule name must be letters and hyphens: $name"; exit 2; }
[ -f src/lint/index.ts ] || { echo "error run from the shadcn-x repo root"; exit 2; }

status=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok $label"; else echo "missing $label"; status=1; fi
}

check "src/lint/rules/$name.ts" test -f "src/lint/rules/$name.ts"
check "index.ts import" grep -qF "from \"./rules/$name.ts\"" src/lint/index.ts
check "index.ts rules entry" grep -qE "^[[:space:]]*\"$name\":" src/lint/index.ts
check "index.ts recommended entry" grep -qF "\"shadcn-x/$name\":" src/lint/index.ts
check "oxlint.config.ts entry" grep -qF "\"shadcn-x/$name\":" oxlint.config.ts

level="$(grep -F "\"shadcn-x/$name\":" oxlint.config.ts | head -1 | sed -E 's/.*: *"?([a-z]+)"?.*/\1/' || true)"
[ -z "$level" ] || echo "level $level"

section_has() {
  awk -v want="$1" '/^## /{s=$0} index(s, want)==1' AGENTS.md | grep -qF "\`$name\`"
}
check "AGENTS.md ## On-system rules" section_has "## On-system rules"
check "AGENTS.md ## Layout src/lint/ list" section_has "## Layout"

if [ -f "tests/lint/$name.test.ts" ]; then
  echo "ok tests/lint/$name.test.ts"
elif [ -f "tests/lint/rules/$name.test.ts" ]; then
  echo "ok tests/lint/rules/$name.test.ts"
else
  echo "missing test file (tests/lint/$name.test.ts or tests/lint/rules/$name.test.ts)"
  status=1
fi

exit "$status"
