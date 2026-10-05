#!/usr/bin/env bash
# Usage: copy-apk.sh <apkPath> <outputDir> <name> <version>
# Copies the APK to <outputDir>/<name>-<version>-<YYYY-MM-DD>.apk and prints its path, size,
# package line, and signer. "debug-signed" means it installs by sideload only, never via Play.
set -euo pipefail

apk="$1" out_dir="${2/#\~/$HOME}" name="$3" version="$4"
sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
tools="$(ls -d "$sdk"/build-tools/* | sort -V | tail -1)"

mkdir -p "$out_dir"
dest="$out_dir/$name-$version-$(date +%F).apk"
cp "$apk" "$dest"

echo "path $dest"
echo "size $(du -h "$dest" | cut -f1)"
echo "package $("$tools/aapt2" dump badging "$dest" | head -1)"
if "$tools/apksigner" verify --print-certs "$dest" 2>/dev/null | grep -q 'CN=Android Debug'; then
  echo "signer debug-signed"
else
  echo "signer release-signed"
fi
