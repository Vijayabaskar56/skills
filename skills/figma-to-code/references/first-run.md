# First run in a repo

Run when `.figma-to-code.json` is missing. Detect facts yourself; ask the user only for choices.

## 1. Detect

| Field | Source |
| --- | --- |
| platform | `react-native` or `expo` in package.json dependencies gives `react-native`; `react-dom` alone gives `web` |
| tokenFile | the CSS or theme file that defines colours: `global.css`, `app/globals.css`, `tailwind.config.*`, `theme/*` |
| textComponent | a shared text wrapper (`AppText`, `Text`, `Typography`) if every screen uses one, else `null` |
| componentDirs | folders holding shared UI: `components/`, `src/components/`, `components/ui/` |
| validate | package.json scripts: `validate`, else `check`, else `lint` plus `typecheck` |
| assetDir | the repo folder images already live in: `assets/`, `public/`, `src/assets/` |
| verify.open | React Native: the app's deep link scheme from app.json / app.config.* (`scheme`). Web: the dev server URL from the dev script (`http://localhost:3000`) |
| verify.device / viewport | React Native: the simulator the repo's docs name. Web: the Figma frame width, height from the frame |

Read the repo's AGENTS.md, CLAUDE.md and README for anything they already say about Figma, assets,
tokens or verification, and prefer it.

## 2. Ask once

One `AskUserQuestion` call, only for what detection did not settle, recommended option first:

1. Figma download directory: the desktop MCP server writes assets only to directories
   allow-listed in Figma (Dev Mode, MCP panel, Allowed directories). Ask which one to use.
2. Platform, if the repo has both React Native and web targets.
3. Notes file: where to keep project facts this skill should know (fonts, shared shells, known
   platform constraints). Default `docs/figma-to-code.md`.

## 3. Write the config

Start from `assets/figma-to-code.example.json`, fill it in and save it as `.figma-to-code.json` at
the repo root. Run the repo's formatter on it. Create the notes file if it does not exist, with a
heading and whatever project facts you already found. Tell the user both files exist and offer to
commit them.
