---
name: modernize
description: Use when asked to rebase an old PR, bring one up to date, or "modernize" it. Checks whether the PR's idea still belongs on the current base, picks MODERNIZE, REWORK or CLOSE, and rebases with --force-with-lease only for MODERNIZE. Not for finishing someone else's PR; use takeover.
argument-hint: "PR number or URL"
---

# Modernize

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

Modernize the idea, not just the branch. A clean rebase does not prove the PR still belongs in the
product.

## 1. Pull the latest

Fetch the latest origin for the PR branch, the base branch and any branch related to the work.
Treat existing worktree changes as the user's; use a disposable worktree when the active one is
dirty or in use.

**Done when** the base and PR head are freshly fetched and you work in a clean tree.

## 2. Establish the PR's intent

Record the PR's URL, state, base, head repository and branch, head SHA, author, checks and review
state. Read the title, body, linked issues, commits, review threads and complete diff. State the
smallest coherent goal the PR was trying to reach before judging its implementation. Record the
merge base so the original PR and later base changes can be compared separately.

**Done when** you have written the PR's goal in one sentence and recorded the merge base.

## 3. Check what changed around it

Inspect the commits and diffs added to the base since the PR diverged. Search merged and open PRs
when titles, code paths or behavior suggest a replacement or competing implementation. Look past
overlapping lines:

- Has the same user-facing problem already been solved?
- Did APIs, types, schemas, dependencies or architectural boundaries change?
- Do both sides now claim the same behavior or invariant?
- Was the code being changed deleted, moved or deliberately simplified?
- Would landing the PR bring back old behavior or create two ways to do one thing?
- Is the original benefit still worth the maintenance cost?

Git reporting no conflicts does not make a PR current.

**Done when** each question above has an answer backed by a commit or PR.

## 4. Choose a disposition

- **MODERNIZE**: the goal is still useful and the implementation is still the right shape. Rebase,
  resolve conflicts, test and update the branch.
- **REWORK**: the goal is still useful, but a mechanical rebase would keep the wrong
  implementation. Explain the smallest credible rewrite and stop before pushing, unless the user
  also asked for the rework.
- **CLOSE**: the PR is superseded, obsolete, wrong in direction or no longer worth its cost. Cite
  concrete evidence and stop. Do not rebase an obsolete branch.

Be willing to recommend CLOSE. Age alone is not evidence, and sunk effort is not a reason to keep a
PR alive.

**Done when** you have picked one disposition with its evidence.

## 5. Rebase without losing intent

For MODERNIZE only:

1. Create a safe local branch or disposable worktree at the recorded PR head.
2. Rebase its commits onto the freshly fetched base.
3. Resolve each conflict by the PR's intent and the base's newer invariants. If a conflict shows a
   product or architecture disagreement, stop and reconsider the disposition instead of guessing.
4. Compare the commit series before and after with `git range-diff`, and inspect the final diff.
   Confirm no intended behavior disappeared and no already-landed behavior came back.
5. Run the repo's focused checks for the touched area. Tell real failures apart from pre-existing
   or infrastructure ones.
6. Push with `--force-with-lease=<branch>:<recorded head SHA>`. If the lease fails, fetch and
   reassess rather than overwrite new work.

**Done when** the push succeeded with the lease, and the range-diff shows no lost or revived
behavior.

## Hard rules

- Modernizing authorizes rebasing and updating the PR branch only. Never merge, close, change the
  base branch or expand scope without the user's say-so.
- Never force-push without a lease tied to the head SHA you recorded.
- Post a PR comment only when the user asked for one, formatted with `leaving-pr-comments`.

## Report

Lead with MODERNIZE, REWORK or CLOSE and the reason, then:

- Meaningful changes on the base branch
- Conceptual conflicts, or confirmation that none were found
- The rebase and push result, if performed
- Checks run and their results
- The remaining decision or work, with a link to the PR

Separate observed facts from judgment, and say what you could not verify.
