---
name: btca
description: Source-first research over locally cloned reference repos in ~/work/references. Use when the user asks how a library/framework works internally, wants to find an implementation, asks "look at the source of X", says "use btca" or "check references", or any question best answered by reading a real codebase rather than docs (e.g. plate.js, Kvaesitso, super-app-showcase, SuperCmd).
---

# btca

Answers source-first questions by dispatching a cheap subagent to read a specific cloned repo under `~/work/references`. Your main context never reads the source files directly — only the subagent's distilled answer comes back.

## Workflow

1. **List what's available.** Always start by running `ls ~/work/references` to see the current set of cloned repos. Do not assume — the folder changes.

2. **Pick the target folder.**
   - If the user named a library that matches one of the entries, use it.
   - If multiple could be relevant, ask the user (don't guess).
   - If nothing matches, tell the user and ask whether to clone a new repo into that directory before proceeding. Use `git clone --depth=1 <url> ~/work/references/<name>` when they confirm.

3. **Verify the path exists** before dispatching:
   ```bash
   test -d ~/work/references/<name> && echo ok
   ```

4. **Dispatch an `Explore` subagent** scoped to that exact folder. Use `model: "haiku"` for cost. The prompt must:
   - State the absolute path to search in and tell the agent **not to read files outside it**.
   - Restate the user's question with enough surrounding context that the agent can make judgment calls.
   - Ask for file paths + line numbers in the answer so the user can jump to source.
   - Cap the response length (e.g. "under 300 words" or "under 600 words for deep dives").

   Breadth guidance for the `Explore` agent:
   - "quick" — single targeted lookup (one symbol, one file).
   - "medium" — moderate exploration across a few files.
   - "very thorough" — multi-area sweep across naming conventions.

5. **Relay the agent's answer** to the user. Quote `path:line` references verbatim so they're clickable. Do not re-read the source yourself unless the user asks a follow-up that needs more depth — in which case dispatch again with a refined prompt.

## Example dispatch

For "how does plate.js implement the slash command menu?":

```
ls ~/work/references
# → confirms `plate` is present
test -d ~/work/references/plate && echo ok

Agent({
  description: "plate slash menu source dive",
  subagent_type: "Explore",
  model: "haiku",
  prompt: "Search ONLY inside ~/work/references/plate (do not read files outside this directory). Question: how is the slash command menu implemented? I want to understand the trigger detection, the menu component, and how items are registered. Report key files with path:line references and a short explanation of how the pieces connect. Under 400 words. Breadth: medium."
})
```

## When NOT to use this skill

- The answer is in the user's own working directory — just read it.
- The library isn't cloned and the user doesn't want to clone it — fall back to WebFetch on official docs.
- The question is conceptual ("what is X") rather than implementation-level — docs/web search is faster.

## Notes

- The references directory is **the** cache. Do not clone elsewhere.
- Shallow clones (`--depth=1`) are fine; full history is rarely needed for source reading.
- If a repo is stale, `git -C ~/work/references/<name> pull` before dispatching — but only when the user signals they want fresh source.
