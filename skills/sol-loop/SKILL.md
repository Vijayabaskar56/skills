---
name: sol-loop
description: Use when the user says "sol loop", or another skill asks for a Sol review. Has OpenAI's GPT Sol review a change in a loop, read-only, until both agents agree, with a 3-round budget and a findings ledger. Not for three-provider review; use council. Not for a same-provider review; use smart-review.
---

# sol-loop

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

Have GPT Sol review your change in a loop, before or after filing a PR. Make the smallest changes
that satisfy the reviewer. Watch for scope creep and push back when a finding is wrong.

## Budget

- Default: 3 rounds. Round 1 is full; later rounds check only changed code and open findings.
- Extend to 5 only for security, permissions, auth, data loss, or state and concurrency, while a
  blocker or should stays open with evidence, or when the user asks.
- Stop early if a round returns only nits. Declined nits and comment, doc or format-only fixes need
  no new round.
- One reviewer only. Sol must not start subagents or reviewers.
- Keep a ledger: id, severity, outcome, and usage if returned. Never guess it.

## 1. Scope the change

Run `git status --short`. Do not stash, discard or include unrelated changes. Limit review to the
change's paths if they separate cleanly; otherwise stop and ask.

Find the base after `git fetch origin`:

- PR: `gh pr view <n> --json baseRefName,headRefOid` (or `pull_request_read` in T3). Check out the
  branch only if clean. Confirm `HEAD` is the PR head, or ahead only by this change. Base:
  `git merge-base HEAD origin/<baseRefName>`.
- Local: `git merge-base HEAD origin/<default-branch>`. No remote: a base the user names, or `HEAD`
  for uncommitted changes only.

The change is base to working tree in those paths, with untracked files. Use one diff command for
every round. State intent and what is out of scope in one or two sentences. Run the covering
checks; do not send code the change breaks, and note missing or already-failing checks in the brief.

**Done when** you have the base SHA, the diff command, the intent line and the check results.

## 2. Start Sol

In T3 Code, call `orchestrator_capabilities` and pick the latest Sol unless the user named a
version or their `CLAUDE.md` or `AGENTS.md` names a reviewer model. Do not hardcode an ID. Record
provider, model and effort only if exposed. Use `delegate_task` every round (`role: "review"`,
`mode: "async"`) with a new `clientRequestId`, and save the `taskId`. Do not use `t3_thread_send`,
`create_threads` or `t3_thread_launch` for review.

Outside T3, use a native Sol subagent and keep its ID. In Claude Code, use a custom subagent only if
it is set up to run Sol. If no route runs Sol, report the blocker; do not substitute a model.

Do not edit scoped files while review runs. Wait for the notice; do not poll or start a second
reviewer. A timeout, error or no reply is not approval. On failure, cancel, confirm it stopped, and
restart with the ledger.

Round 1 brief (T3 children get no history):

```
Review only. Do not edit, commit, push, comment on PRs, or start subagents.
Repo: <abs path> Base: <sha> Intent: <intent> Out of scope: <scope> Checks: <results>
See: git diff <base> [-- <paths>]; git status --short (read untracked).
Read surrounding code. Find bugs, broken callers, mismatch with intent.
Skip style unless it hides a bug. Hold to the smallest change. Flag code,
tests, or guards the intent does not need. Other paths, rare cases, small
perf, extra compat: nits.
blocker = intended case wrong. should = real bug callers will hit, in intent. nit = rest.
Reply:
VERDICT: APPROVE or CHANGES
S1 [blocker|should|nit] <file>:<line> <claim>. Fix: <suggestion> (stable ids)
```

**Done when** a Sol review task is running and its ID is in the ledger.

## 3. Answer findings

Check each finding and its severity yourself. Another path, a rare case or a small cost is a nit,
whatever label it came with.

- Agree: make the smallest fix. Prefer deleting or narrowing over a new lock, cache, helper or
  option. Fix the case that happened. Add one focused test that fails without the fix, if the
  intent needs it.
- Disagree: say why, with evidence (file:line, test, output).
- Out of scope or nit: decline in one line and list it as a follow-up.

Update the ledger. Re-run checks and `git diff --shortstat <base>`. If review grew the diff, cut
first. Do not agree only to end the loop.

**Done when** every finding in the ledger is fixed, disputed with evidence, or declined.

## 4. Run the next round

Start one only if budget remains and a blocker or should is open, behavior code changed, or the
approval does not cover the current behavior diff. Use a fresh `delegate_task` in T3, or follow up
the saved native ID. Send the round 1 brief, the ledger (`fixed:` / `disagree:` / `declined:` with
evidence), the same base diff and the change since the last round. Tell Sol to check open ids and
changed code only, and to mark each old id `resolved` or `still open: <reason>`.

**Done when** the round's verdict is in the ledger.

## 5. Stop and ship

Agreed: APPROVE on the current behavior diff, no blocker or should open, and no concern of your
own. Stuck: an item stays disputed after two replies, or the budget ends. Show both sides in two or
three lines each and let the user decide. Budget end is not approval.

Push after agreement only if the user asked to push, ship or update the PR. If you push to a PR,
add this line to its description: `Reviewed with sol-loop: <N> rounds with <model>. Sol verdict:
approved`. Add `on <effort>` only if verified.

**Done when** the loop ended agreed or stuck, and the PR line is added if you pushed.

## Hard rules

- Never push during the loop.
- Never substitute another model for Sol without the user's say-so.
- Never pick Fable for the reviewer unless the user asks for it.

## Report

- Rounds, model, and effort if verified
- What Sol changed, and the diff size before and after
- Findings fixed and declined, with reasons
- Usage if exposed, or say it was not
- Whether you pushed
