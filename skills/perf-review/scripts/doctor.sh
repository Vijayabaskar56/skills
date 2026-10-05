#!/usr/bin/env bash
# Usage: doctor.sh [--repo DIR]
# Checks what perf-review needs: git (with git grep), awk, sed, sort -z, and that DIR is a git
# work tree. Prints one line per check: ok, missing with the fix, optional, or session for what
# only the agent can confirm. Exits 1 when anything required is missing.
set -euo pipefail

repo=.
if [ "${1:-}" = --repo ]; then repo="${2:?--repo needs a value}"; fi
missing=0
ok() { echo "ok       $*"; }
miss() { echo "missing  $*"; missing=1; }

for tool in git grep awk sed sort tr paste cut; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else miss "$tool: install it with the system package manager"; fi
done
if printf 'b\0a\0' | sort -z 2>/dev/null | tr '\0' '\n' | head -1 | grep -qx a; then
  ok "sort -z"
else
  miss "sort -z: install GNU or BSD sort with -z support (coreutils)"
fi

if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "git work tree at $(git -C "$repo" rev-parse --show-toplevel)"
  if git -C "$repo" grep -q -e . HEAD 2>/dev/null; then ok "git grep at HEAD"; else miss "git grep at HEAD: the repo needs at least one commit"; fi
  if [ -f "$(git -C "$repo" rev-parse --show-toplevel)/.perf-review.json" ]; then
    ok ".perf-review.json"
  else
    echo "optional .perf-review.json: step 1 writes it once the build tag prefix is known"
  fi
else
  miss "git work tree: pass --repo <app repo>"
fi

echo "session  a subagent tool (Agent or Task) that can run several general-purpose agents in parallel; without one, review alone (step 3)"
exit "$missing"
