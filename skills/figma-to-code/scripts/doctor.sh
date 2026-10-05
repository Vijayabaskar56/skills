#!/usr/bin/env bash
# Usage: doctor.sh <react-native|web>
# Checks what figma-to-code needs on this machine. Prints "ok <item> <detail>" or
# "missing <item> <how to fix>" per line, "optional ..." for extras, then "session <item> <what to confirm>" for the checks
# only the agent can do. Exits 1 when anything is missing. Setup steps: references/setup.md.
set -euo pipefail

platform="${1:?usage: doctor.sh <react-native|web>}"
missing=0

check() {
  local item="$1" cmd="$2" fix="$3" out
  if out="$(eval "$cmd" 2>&1)" && [ -n "$out" ]; then echo "ok $item ${out%%$'\n'*}"
  else echo "missing $item $fix"; missing=1; fi
}

check node "node -v" "install Node 18+ (nvm, mise or brew install node)"
check python3 "python3 --version" "xcode-select --install, or brew install python"
check ffmpeg "ffmpeg -version" "brew install ffmpeg"
check ffprobe "ffprobe -version" "brew install ffmpeg"

case "$platform" in
  react-native)
    check argent "argent --version" "npx @swmansion/argent@latest init -y (references/setup.md)"
    check xcrun "xcrun --version" "install Xcode for the iOS simulator" ;;
  web)
    check agent-browser "agent-browser --version" "npm i -g agent-browser && agent-browser install" ;;
  *) echo "platform must be react-native or web" >&2; exit 2 ;;
esac

if curl -s -m 2 -o /dev/null -X POST http://127.0.0.1:3845/mcp; then
  echo "ok figma-desktop-mcp listening on 127.0.0.1:3845"
else
  echo "optional figma-desktop-mcp not reachable; open the Figma desktop app with Dev Mode MCP server enabled (references/setup.md); needed only for 'my selection' and desktop asset writes"
fi

echo "session figma-remote-mcp confirm the Figma MCP tools (get_metadata, get_screenshot, get_design_context, use_figma) are callable in this session"
echo "session figma-critic confirm a figma-critic agent exists, or use references/visual-loop.md's fallback prompt"
exit "$missing"
