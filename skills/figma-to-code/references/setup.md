# Setup

Run `scripts/doctor.sh <react-native|web>` and fix each `missing` line. Installing anything needs
the user's yes; ask once for the whole list.

## Tools

| Tool | Needed for | Install |
| --- | --- | --- |
| Node 18+ | `scripts/text-diff.mjs` | nvm, mise or `brew install node` |
| python3 | reading pixel rows during measurement | `xcode-select --install` or `brew install python` |
| ffmpeg, ffprobe | cropping captures, reading sizes and pixel rows | `brew install ffmpeg` |
| argent | React Native capture, describe, native frames | `npx @swmansion/argent@latest init -y`, then read its `argent-device-interact` skill |
| agent-browser | web capture, snapshot, DOM measurement | `npm i -g agent-browser && agent-browser install` |

Only the verification tool for the configured platform is required.

## Figma MCP servers

Two servers expose the same core tools. Setup, differences and failure fixes are in
`figma-mcp-servers.md`.

| Server | Address | Needed for |
| --- | --- | --- |
| Remote | `https://mcp.figma.com/mcp` | every run: metadata, screenshot, design context, the raw read through `use_figma` |
| Desktop | `http://127.0.0.1:3845/mcp` | "my selection" with no link, and writing assets straight to disk |

Claude Code: install the Figma plugin (`figma@claude-plugins-official`) for the remote server, and
add the desktop one with `claude mcp add --transport http figma-desktop http://127.0.0.1:3845/mcp`.
Other agents: add both URLs as HTTP MCP servers in their config. The desktop server runs only
while the Figma desktop app is open with the Dev Mode MCP server turned on in its preferences.

## Critic agent

Step 5 hands the visual judgement to a critic that sees only the two images. In Claude Code, copy
`assets/figma-critic.md` to `~/.claude/agents/figma-critic.md` (or the repo's `.claude/agents/`)
once. Its tool list names the Figma screenshot tool of the desktop server; change it to the remote
server's tool name if only the remote server is set up. Without the agent file, use the fallback
in `visual-loop.md`.
