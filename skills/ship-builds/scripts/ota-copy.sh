#!/usr/bin/env bash
# Usage: ota-copy.sh <newDir> <buildCommit> <file> [file ...]
# From the app's repo root. Copies the working tree (with .git, without node_modules, ios,
# android and dist) to <newDir>, links node_modules back, and restores each <file> to its
# content at <buildCommit>, so the copy's runtime matches a build whose only difference is
# in those files. <newDir> must not exist. The working tree is never changed. Prints the copy path.
set -euo pipefail

dest="$1" commit="$2"; shift 2
[ $# -gt 0 ] || { echo "name at least one file to restore" >&2; exit 2; }
[ -e "$dest" ] && { echo "$dest exists; pass a new directory" >&2; exit 2; }
root="$(git rev-parse --show-toplevel)"
git cat-file -e "$commit^{commit}" || { echo "unknown commit $commit" >&2; exit 2; }

mkdir -p "$dest"
rsync -a --exclude node_modules --exclude /ios --exclude /android --exclude /dist "$root/" "$dest/"
ln -s "$root/node_modules" "$dest/node_modules"
for file in "$@"; do
  git -C "$root" show "$commit:$file" >"$dest/$file"
  echo "restored $file from ${commit:0:8}" >&2
done
echo "$dest"
