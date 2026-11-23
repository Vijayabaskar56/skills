---
name: babysit-pr
description: Use when the user asks to monitor, watch or babysit a PR. Waits with T3's watch_pull_request or the bundled pr-wait, verifies review-bot findings (Greptile, Macroscope, CodeRabbit), fixes real ones and keeps the PR rebased. Works in Claude Code and Codex. Not for a quick Claude-only CI fix pass without a watcher; use pstack's babysit.
argument-hint: "PR number or URL"
---

# Babysit PR

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT). Needs an authenticated
`gh` and `python3`.

Many repos have AI review bots. They help, even when they are wrong.

## 1. Handle what is already there

Read the PR's checks, reviews and unresolved threads. Act only on checks and comments newer than
the latest push. Verify every bot finding against the source before changing code. Fix real
findings and CI failures, and tell repository failures apart from infrastructure flakes.

- If the repo has `.macroscope/check-run-agents/*.md`, read those rules before you reply to a
  Macroscope finding. Its findings cite them.
- CodeRabbit is advisory. Treat its findings like any other, but never wait for it and never hold a
  merge for it.
- When a finding is not worth fixing, reply with a written reason and resolve the thread. Format
  every comment with `leaving-pr-comments`.
- When a fix changes what users see, add before and after evidence to the PR description by
  [../file-pr/references/evidence.md](../file-pr/references/evidence.md).

Keep the PR at the size the goal needs. Review loops grow a PR one cheap-looking fix at a time.
Fix real bugs in the intended case. Decline the rest with a written reason and list them as
follow-ups: unneeded tests, guards for edge cases that do not matter, extra compatibility, small
performance costs. Prefer the fix that deletes or narrows code.

**Done when** each current finding is fixed and pushed, or answered with a reason.

## 2. Wait with one watcher

Use one watcher per PR: `watch_pull_request` in T3 Code, `pr-wait` everywhere else. Never run both
on the same PR; every watcher on a GitHub account shares one rate limit.

**In T3 Code:** call `watch_pull_request` and end your turn. T3 wakes you when a check fails, the
required checks pass, someone comments or reviews, or the branch conflicts.

- Only the thread that owns the PR watches it. A delegated child (a reviewer, a Sol round, any
  `delegate_task` child) never calls `watch_pull_request`.
- A wake is news, not a merge decision. Check the merge gate yourself.
- When you stop (ready, blocked, or asking a question), call `unwatch_pull_request` first. A merge
  or close ends the watch on its own.
- "Stopped watching, could not read it" usually means the GitHub rate limit is used up. Run
  `gh api rate_limit --jq .resources.graphql`. If `remaining` is near 0, wait for `reset` with one
  background command, then watch again.

**Everywhere else:** run [scripts/pr-wait](scripts/pr-wait) by its absolute path:

```sh
pr-wait <pr> [--repo owner/name] [--until ready|green|any-change]
```

It prints one line per real event and exits 0 when the `--until` condition is met or the PR merges,
1 when it needs you (a required check failed, conflicts, unresolved threads, PR closed), and 2 on
bad input. `ready` (default) waits for green required checks, a Greptile or Macroscope review of
the head and no unresolved threads; `green` waits for required checks only, for repos without
those bots; `any-change` exits on the first event. In Claude Code, run it with the Monitor tool
(`timeout_ms: 3600000`) so each line wakes you.

Start it again after you push, after you handle an exit 1, and after a resume; it remembers what it
already reported. If it says another pid already watches the PR, do not start a second one.

When an event needs no action, end your turn without a message.

**Done when** the watcher exits 0, or T3 reports the required checks passed and step 3 passes.

## 3. Keep the base current

`pr-wait` reports when new base commits touch this PR's files, and when the PR becomes BEHIND or
DIRTY. `watch_pull_request` reports conflicts only, so check for BEHIND yourself before calling the
PR ready. If an overlapping PR makes this one obsolete, stop watching, report it, and ask before
closing the PR unless closing was explicitly authorized.

**Done when** the branch is up to date with its base and GitHub reports it mergeable.

## GitHub rate limits

`gh pr create`, `gh pr view` and `gh pr checks` use GraphQL. When GraphQL is used up, the REST
limit is separate and usually has room: `gh api repos/<owner>/<repo>/pulls/<n>` reads a PR and
`gh api repos/<owner>/<repo>/commits/<sha>/check-runs` reads checks. In T3 Code prefer the
`pull_request_*` tools.

## Hard rules

- Never write your own watcher, polling loop or `sleep` loop.
- Never post or say "still waiting", and never post filler comments.
- Merge only when the user explicitly asked for it. Right before a merge, run `git fetch` and check
  the PR again. Never merge when it is BEHIND or DIRTY, or when base commits that landed after the
  last green run touch this PR's files: rebase, push and wait for green again.

## Report

- The PR link, head SHA, and the state of checks and reviews
- Each finding with its outcome: fixed (commit), or declined (reason)
- Whether the PR is ready, merged, or blocked, and on what
