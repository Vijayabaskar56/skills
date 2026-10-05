---
name: btca
description: "Use when asked how a library works internally, to find an implementation in its source, 'look at the source of X', 'use btca' or 'check references'. Dispatches a scoped read-only subagent over a cloned reference repo and relays its cited answer. Not for code in the current repo or conceptual questions; read the repo or the docs."
argument-hint: "library name and the question about its source"
---

# btca

Answers source questions by sending a cheap read-only subagent into one cloned repo in the
references dir. The main context reads only the subagent's answer, never the source files.

The references dir is `$BTCA_REFERENCES_DIR`, default `~/work/references`. The scripts resolve
it; take the path from their output instead of typing it.

## 0. Check setup

Run `scripts/doctor.sh`. Fix each `missing` line as it says, asking before creating a folder, and
confirm each `session` line yourself: a read-only search subagent (Explore in Claude Code) and the
cheapest available model for it (haiku in Claude Code).

**Done when** doctor exits 0 and prints the references dir.

## 1. Resolve the repo

Run `scripts/resolve-ref.sh <name>` with the library the user named.

- Exit 0: it printed one absolute path. Use it.
- Exit 2: it printed several candidates. Ask the user which one, then rerun with that name.
- Exit 1: no repo matches, and stderr lists what is there. Ask the user whether to clone it and
  from which URL. If they say yes, go to step 2; if no, stop and suggest the official docs.

**Done when** resolve-ref.sh prints exactly one absolute path.

## 2. Clone the repo if missing

Only after the user said yes in this request, run `scripts/clone-ref.sh <git-url> [name]`. It
reuses the folder when it is already a git repo, otherwise shallow-clones it, and prints the path.
Then rerun step 1.

**Done when** resolve-ref.sh prints the new repo's absolute path.

## 3. Write the subagent prompt

Build the prompt from:

- The absolute path from step 1, with "Search only inside this directory. Read no file outside it."
- The user's question, restated with enough context for judgment calls.
- A request for `path:line` references for every claim.
- A length cap: under 300 words, or under 600 for a deep dive.
- Breadth: "medium" for a few files, "very thorough" for a sweep across areas and naming
  conventions.

**Done when** the prompt contains the absolute path, the question, the citation request, the cap
and the breadth.

## 4. Dispatch the subagent

Dispatch the read-only search subagent (Explore in Claude Code) with the cheapest available model
(haiku in Claude Code) and the prompt from step 3. Example:

```
Agent({
  description: "plate slash menu source dive",
  subagent_type: "Explore",
  model: "haiku",
  prompt: "Search only inside <absolute path from resolve-ref.sh>. Read no file outside it.
    Question: how is the slash command menu implemented? Cover trigger detection, the menu
    component and how items are registered. Cite path:line for each point. Under 400 words.
    Breadth: medium."
})
```

**Done when** the subagent returns an answer with at least one `path:line` reference.

## 5. Relay the answer

Relay the answer and quote its `path:line` references verbatim so they stay clickable. For a
follow-up that needs more depth, dispatch again with a refined prompt instead of reading the
source yourself.

**Done when** the reply quotes at least one `path:line` from the subagent.

## Hard rules

- Clone or pull only after the user says yes in this request.
- Clone only into the references dir, through `scripts/clone-ref.sh`.
- Search only inside the resolved repo path; pass that absolute path to the subagent.
- Leave source reading to the subagent; the main context reads its answer only.
- When the answer is in the current working directory, read it there instead of using this skill.

## Report

- Repo path printed by `resolve-ref.sh`
- Commit read: `git -C <path> rev-parse --short HEAD`
- Whether the repo was cloned or pulled this run, and the user's yes that allowed it
- The subagent's `path:line` list, verbatim
