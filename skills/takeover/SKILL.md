---
name: takeover
description: Use when the user asks to take over a PR, branch or agent thread, or asks for a takeover. Finishes someone else's work toward its original goal on a new branch, keeps the original contributors' Git credit, verifies it independently and files it. Not for only rebasing an old PR; use modernize.
argument-hint: "PR, branch or thread to take over"
---

# Takeover

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

Take responsibility for finishing the original goal while keeping the original contributors'
credit. Do not defend an implementation just because another agent already built it.

## 1. Read what you inherit

Read the source PR, branch or thread, including review findings and the user's later corrections.
In T3 Code read a thread with `t3_thread_read`. Resolve the handoff to the actual code and current
head, and account for uncommitted work. Treat the handoff as context, not proof.

**Done when** you know the source's head SHA, its goal, and its open findings.

## 2. Set up the continuation

For a replacement PR, bring the original commits onto a new branch and add your fixes as separate
commits. If the user asked for an in-place or stacked continuation, do that instead. Do not
overwrite unrelated work or change the original PR without authorization.

Keep Git authorship and existing human co-author trailers. If the work will be squashed, keep human
author and co-author credit in the merge commit too, using verified identities rather than guessed
emails.

**Done when** the new branch holds the original commits with their authors unchanged.

## 3. Bring it up to date

Use `modernize` to update the continuation against its intended base and current architecture.
Rework what is needed to finish the same goal, not unrelated features. Simplify without dropping
intended behavior or surfaces. Recheck the source PR too: it may have improved while you worked.

**Done when** the branch is rebased on the current base and modernize's checks pass.

## 4. Verify it yourself

Reproduce the original failure and the realistic workflows, following the repo's guidance and
permissions. Green mocked tests do not prove the user experience works. State what stays
unverified.

**Done when** you have proof for the goal, and a list of what you did not verify.

## 5. File and babysit

When the finish includes a PR, use `file-pr` to file or update it, crediting the original
contributors and linking the original PR. Then follow `babysit-pr` instead of stopping at creation.
Use `leaving-pr-comments` for replies.

**Done when** the PR is filed and babysit-pr is watching it, or the user did not ask for a PR.

## Hard rules

- Merge or close the original PR only when authorized.
- Credit human contributors by their verified Git identities. Never add an AI credit line, and
  never treat one as a substitute for contributor credit.

## Report

- What you inherited, with its head SHA and link
- What you changed, and how you verified it
- How the original contributors' credit was kept
- Any remaining decision
