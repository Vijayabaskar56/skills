#!/usr/bin/env bash
# Usage: clone-ref.sh <git-url> [name]
# Run only after the user said yes to cloning in this request. Shallow-clones <git-url> into
# <references dir>/<name> (name defaults to the URL's last segment without .git). If that folder
# is already a git repo, reuses it without touching the network. Prints the absolute path.
# Exits 1 when the folder exists but is not a git repo, or the clone fails.
set -euo pipefail

url="${1:?usage: clone-ref.sh <git-url> [name]}"
name="${2:-$(basename "${url%/}" .git)}"
refs="${BTCA_REFERENCES_DIR:-$HOME/work/references}"
[ -d "$refs" ] || { echo "references dir $refs does not exist; run doctor.sh" >&2; exit 1; }
target="$(cd "$refs" && pwd)/$name"

if [ -e "$target/.git" ]; then
  echo "reused $target" >&2
elif [ -e "$target" ]; then
  echo "$target exists and is not a git repo; pick another name" >&2
  exit 1
else
  git clone --depth=1 --quiet "$url" "$target" >&2
  echo "cloned $target" >&2
fi
echo "$target"
