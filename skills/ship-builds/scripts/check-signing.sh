#!/usr/bin/env bash
# Usage: check-signing.sh <xcodeproj> <target>
# Checks that the target's Release build settings sign manually: CODE_SIGN_STYLE = Manual and a
# CODE_SIGN_IDENTITY. A prebuild wipes both. Exits 1 when either is missing; references/signing.md
# has the re-apply steps.
set -euo pipefail

project="${1:?usage: check-signing.sh <xcodeproj> <target>}" target="${2:?usage: check-signing.sh <xcodeproj> <target>}"
pbxproj="$project/project.pbxproj"
[ -f "$pbxproj" ] || { echo "no $pbxproj" >&2; exit 1; }

settings="$(plutil -convert json -o - "$pbxproj" | jq --arg t "$target" '
  .objects as $o
  | [$o | to_entries[] | select(.value.isa == "PBXNativeTarget" and .value.name == $t) | .value][0] as $target
  | if $target == null then null
    else [$o[$target.buildConfigurationList].buildConfigurations[] | $o[.]
          | select(.name == "Release") | .buildSettings][0]
    end')"
[ "$settings" != null ] || { echo "no Release configuration for target $target in $pbxproj" >&2; exit 1; }

style="$(jq -r '.CODE_SIGN_STYLE // empty' <<<"$settings")"
identity="$(jq -r '[to_entries[] | select(.key | startswith("CODE_SIGN_IDENTITY")) | .value][0] // empty' <<<"$settings")"
profile="$(jq -r '.PROVISIONING_PROFILE_SPECIFIER // empty' <<<"$settings")"

bad=0
[ "$style" = Manual ] || { echo "$target Release has CODE_SIGN_STYLE '${style:-unset}', expected Manual" >&2; bad=1; }
[ -n "$identity" ] || { echo "$target Release has no CODE_SIGN_IDENTITY" >&2; bad=1; }
[ "$bad" -eq 0 ] || exit 1
echo "ok signing $target Release: Manual, '$identity', profile ${profile:-unset}"
