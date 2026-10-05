# Figma MCP servers and asset access

Read this from step 1 when choosing a server is not obvious, when a server is missing or refuses
connections, or when a tool rejects an argument or the asset directory.

## Choose the server

Two servers expose Figma tools. Pick by task before the first call. Do not fetch the same node
from both. The names below are the usual ones; the local config may call them something else.

| Server | Tools | Reach |
| --- | --- | --- |
| Desktop (`figma-desktop`, `127.0.0.1:3845`) | Read-only: `get_design_context`, `get_metadata`, `get_screenshot`, `get_variable_defs`, `get_motion_context`, `get_figjam` | The user's LIVE SELECTION in the open desktop app, or a node id |
| Remote (`plugin:figma:figma`, `mcp.figma.com`) | Same reads, plus writes (`use_figma`, `generate_figma_design`, `create_new_file`), assets (`download_assets`, `upload_assets`, `export_video`), Code Connect suite, `search_design_system` | Any figma.com URL; works with the desktop app closed |

Selection rules:

- "Implement / check my selection" with no URL given goes to **desktop**. It is the only server
  that can read the current selection.
- Any write to Figma goes to **remote**, whether that is pushing code to a file, variables,
  components or diagrams. Desktop has no write tools.
- Asset downloads at scale go to **remote** `download_assets`. Desktop writes assets only into an
  allow-listed directory (below).
- Both read the same cloud file, so read results are equivalent. Never re-fetch a node from the
  other server to double-check. Resolve conflicts against the screenshot.
- If desktop refuses connections, have the user turn it on (next section) with the app running.
  Fall back to remote only when a URL or node id is already known, since remote cannot see
  selections.

## Set up the servers

Remote server:

- Install the Figma plugin for the agent (in Claude Code, from the `/plugin` marketplace), or add
  the server by hand: `claude mcp add --transport http figma https://mcp.figma.com/mcp`.
- Authenticate when prompted (in Claude Code, `/mcp` then the server's login). The user does this;
  it opens a browser.

Desktop server:

- In the Figma desktop app, open the Figma menu, Preferences, and turn on **Enable Dev Mode MCP
  Server**. If the label differs, check Figma's current docs. It serves on `127.0.0.1:3845` while
  the app is open.
- Register it once: `claude mcp add --transport http figma-desktop http://127.0.0.1:3845/mcp`. If
  that path does not connect, check Figma's current docs for the endpoint.

Confirm each is reachable before the first real call:

1. Its tools appear in the tool list (`mcp__figma-desktop__*`, `mcp__plugin_figma_figma__*`, or
   the names the local config gives). If they are missing, the server is not registered or failed
   to connect; restart the agent session after adding it.
2. A `get_metadata` call on a known node id succeeds (desktop: with a frame selected, no id
   needed). On remote, `whoami` also confirms the login.

## Connector schemas differ

- Desktop Figma MCP may require `dirForAssetWrites`.
- Remote Figma connectors may return short-lived asset URLs and expose no write directory argument.

Inspect the active tool schema and pass only supported arguments. For desktop asset writes, pass
the directory in config `figmaDownloadDir` when it is allow-listed in Figma. If desktop Figma rejects it,
ask the user to add it in Figma, Dev Mode, MCP panel, Allowed directories. Do not bypass the
allow-list.

## Remote server and the raw read

The remote server is the only route to raw effects and gradients: `use_figma` with
[`raw-node.js`](raw-node.js), after loading the `figma-use` skill. It is read-only as written;
never mutate the design file from this skill.
