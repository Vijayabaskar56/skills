---
name: file-pr
description: Use when the user asks to file, open or create a pull request. Writes a short title and a description that leads with the problem, attaches before and after evidence through `fleet upload-file`, and opens a real PR. Not for watching a PR through CI and review; use babysit-pr.
---

# File PR

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

## 1. Check the branch

Check whether a PR for this branch already exists; update it instead of opening a second one.
Review the diff against the base branch (usually `origin/main`) and confirm it matches the goal.

**Done when** you know the base branch, the head SHA, and whether a PR already exists.

## 2. Write the title

PR titles usually become commit messages, so follow the repo's title conventions. Look at recently
merged PRs and the Git history for examples. Prefer a short, human-readable title that says why the
change matters:

> Bad: perf(server): negotiate permessage-deflate on the websocket
>
> Good: perf(server): cut websocket frame size by 70%+ with gzipping

**Done when** the title follows the repo's convention and names the effect, not the mechanism.

## 3. Write the description

Open with a plain explanation of the problem, based on the user's original request, then briefly
explain the fix. Do not lead with a list of everything you changed:

> Bad: Removed implicit workspace carry-over from every "new thread" entry point (cmd+n,
> sidebar buttons, command palette). Deleted buildContextualThreadOptions and the seed-context
> machinery.
>
> Good: My "new worktree" default was ignored when starting new threads on existing worktrees.
> Super unintuitive. Now your preferences always apply.

Then add what the reviewer needs: how you reproduced it, the tests you ran with their results, and
what the change leaves out.

**Done when** the first paragraph states the problem in the user's terms.

## 4. Attach evidence

Follow [references/evidence.md](references/evidence.md): before and after screenshots for any
visible change, a short linked clip only when a still image cannot show the bug, and no media for
changes nobody can see. Upload with `fleet upload-file` and paste its markdown into an
`## Evidence` section.

**Done when** the description has evidence that fits the change, or says why it has none.

## 5. Open the PR

Check the title, description, quotes and attachments for secrets and private details. Open a real
PR, not a draft, so review bots run. In T3 Code use `pull_request_create`; elsewhere use
`gh pr create`. If `gh pr create` fails because the GraphQL rate limit is used up, open it through
REST: `gh api repos/<owner>/<repo>/pulls -f title=... -f head=... -f base=... -F body=@<file>`.

If the user also asked to babysit it, continue with the `babysit-pr` skill.

**Done when** GitHub returned the PR URL.

## Hard rules

- Never credit an AI tool or model in the title, description or commits: no "Created with", no
  `Co-Authored-By` for an agent, no session link. Credit human contributors only.
- Check every attachment for secrets and private details before upload.
- Post a follow-up PR comment only when it serves the user's request, and format it with
  `leaving-pr-comments`.

## Report

- The PR URL and head SHA
- The title, and the first line of the description
- The evidence attached: each uploaded URL, or why there is none
