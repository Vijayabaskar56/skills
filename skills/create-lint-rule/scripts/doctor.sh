#!/usr/bin/env bash
# Usage: doctor.sh
# Run from the shadcn-x repo root. Prints one line per dependency of create-lint-rule:
# "ok", "missing <fix>" or "optional <fix>". Exits 1 when any line is missing.
set -euo pipefail

status=0
ok() { echo "ok $*"; }
missing() { echo "missing $*"; status=1; }
optional() { echo "optional $*"; }

if [ -f package.json ] && grep -q '"name": "shadcn-x"' package.json && [ -f src/lint/index.ts ]; then
  ok "shadcn-x repo root ($(pwd))"
else
  echo "missing shadcn-x repo root: cd to the shadcn-x checkout and rerun"
  exit 1
fi

if command -v bun >/dev/null 2>&1; then
  ok "bun $(bun --version)"
else
  missing "bun: install from https://bun.sh"
fi

if [ -x node_modules/.bin/oxlint ] && [ -x node_modules/.bin/vitest ]; then
  ok "node_modules (oxlint, vitest)"
else
  missing "node_modules: run 'bun install' in the repo root"
fi

check_link() {
  local path="$1" probe="$2" level="$3"
  if [ -d "$path/$probe" ]; then
    ok "$path -> $(readlink "$path" 2>/dev/null || echo "$path")"
  else
    "$level" "$path: clone the repo and symlink it, see references/README.md in shadcn-x"
  fi
}
check_link references/base-ui packages/react missing
check_link references/ui apps/v4/registry/bases/base/ui missing
check_link references/coss apps/ui optional

if [ -d docs/stylex-docs ]; then
  ok "docs/stylex-docs"
else
  missing "docs/stylex-docs: tracked in git; run 'git checkout -- docs/stylex-docs'"
fi

exit "$status"
