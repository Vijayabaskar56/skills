---
name: full-stop
description: Use when the user says "full stop", even as a closing "Full stop." that reads like emphasis. Does the full-send work (finish, prove, review, file, babysit) but stops with the PR ready for the user to merge and never merges. Not for merging unattended; use full-send.
---

# Full Stop

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

Do the same work as `full-send`, but stop with the PR ready for the user to merge.

## 1. Follow full-send

Read [full-send](../full-send/SKILL.md) and follow its steps 1 to 5, its proof rules and its
testing grant. A "full stop" request is the permission for that work, including the test methods
Proof needs, even where a project file says to ask first. Full-send's merge permission does not
apply; the rules below take precedence.

**Done when** the PR is filed with proof and review covering the final diff.

## 2. Keep it from merging

You may commit, push, rebase, fix conflicts, and use `--force-with-lease` on this task's branch.
Before work begins, turn off any existing auto-merge and take the PR out of any merge queue. Check
again before each push, and report these changes. If you cannot stop automatic merging, report the
blocker before going on.

**Done when** auto-merge is off and the PR is in no merge queue.

## 3. Stop at the gate

Use full-send's merge gate as the readiness check. Recheck behavior changes and real conflict fixes
before the handoff. Fetch the target branch and check the live PR's head, base, checks, reviews and
mergeability. Confirm it is open, not a draft, and not set to merge without the user. If someone
else merged it, report that instead.

- **Ready to merge:** the gate passes. Leave the PR open and unmerged.
- **Waiting for required approval:** only human approval remains. Confirm that is the real blocker.
- **Blocked:** say what prevents readiness, what you tried and what is needed. Follow full-send's
  rules for asking the user.

In T3 Code, call `unwatch_pull_request` before the handoff or a question.

**Done when** the PR has one of the three verdicts above and no watcher is left running.

## Hard rules

- Never merge, enable auto-merge, enter a merge queue, push to the default branch, bypass branch
  protection, or hand any of those to another agent.

## Report

- The PR link and final head SHA
- The verdict: ready, waiting for approval, or blocked
- Proof, reviewer outcome and remaining risks
- Whether the PR is still open and unmerged
