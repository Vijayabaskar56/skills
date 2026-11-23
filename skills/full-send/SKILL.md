---
name: full-send
description: Use when the user says "full send". Takes a change all the way to a merged PR with nobody watching: finishes it, proves it, reviews it with sol-loop, files it, babysits it and merges it. Not for stopping with the PR ready for the user to merge; use full-stop.
---

# Full Send

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

The user said "full send" because they are not watching this thread. They want the work done
end to end on its own. Your updates and your final message go unread until long after you stop.
You own the work from its current state to a merged PR.

If the user did not clearly ask for "full send", do not assume this autonomy.

## What "full send" grants

- Merge the PR once the merge gate passes.
- Force-push the PR's own branch with `--force-with-lease` after a rebase.
- Use the test methods Proof needs without asking first: browser automation, simulators and
  devices, running the app or a dev server, screenshots and visual checks. This replaces any
  project rule that says to ask first or to leave testing to the user, for this task only.

Rules about how to test still apply: use the command, fixture or check they name. The grant covers
only the tests this task needs. It does not cover anything under "Ask the user", and it does not
skip a harness or system approval prompt.

## 1. Finish the change

Complete the goal with the smallest change that works. Fix the case that happened, not every case
that could. If you are on the default branch, create a branch first.

**Done when** the diff does what the request asked and nothing more.

## 2. Prove it

Proof is evidence you saw yourself in this session. Use the most direct proof the change allows:

- Reproduce the original failure, apply the fix, and watch the same reproduction pass.
- Run the checks the repo's CI runs (typecheck, lint, tests).
- When the behavior has no test and the repo has a test setup, add one focused test that fails
  without the fix.
- For UI and runtime behavior, run the app and look at the change. Green mocked tests do not prove
  the user experience works. Capture evidence by [../file-pr/references/evidence.md](../file-pr/references/evidence.md).

If you cannot find a way to prove a change, you do not have full confidence. Ask the user.

**Done when** every change in the diff has proof you observed.

## 3. Get review

Run the `sol-loop` skill on the change. If sol-loop reports that no route can run Sol, run
`smart-review` instead and say so in the report.

**Done when** the reviewer approved the current diff, or each open finding is fixed or declined
with a reason.

## 4. File the PR

Rebase onto the latest default branch, then file it with the `file-pr` skill, including its
evidence section. Add one line that says how you proved the change.

**Done when** GitHub returned the PR URL.

## 5. Babysit the PR

Follow the `babysit-pr` skill. Fix real findings and CI failures, and prove each fix before you
push it. Stay active from step 1 to step 6: if you end your turn while checks or bots are pending,
nobody prompts you again. Wait with babysit-pr's watcher (`watch_pull_request` in T3 Code). If you
stop before the merge, call `unwatch_pull_request` first.

**Done when** the merge gate below passes on the latest commit.

## 6. Merge

Full confidence means all of these hold on the latest commit:

- Your proof covers every change in the diff.
- Required checks are green.
- Review bots have finished, and each finding is fixed or dismissed with a written reason.
- No human review still requests changes.
- The branch is up to date with the default branch, and GitHub reports it mergeable.

Merge with the method the repo uses; check the allowed methods and recent merged PRs. With a merge
queue or auto-merge, stay until GitHub reports the PR merged. You may ignore an automated
"needs human review" request when you have high confidence in the change.

**Done when** GitHub reports the PR merged and you have the merge commit SHA.

## Ask the user

A question in a normal message goes unseen and the thread looks done. Ask with the harness's
question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex), with all the
context in the question: the PR link, what blocks you, and the options with your recommendation
first. Ask only when:

- You cannot prove the change.
- The merge gate cannot pass and you cannot fix that yourself.
- The next step is outside the grant: deleting data, touching production, changing things outside
  the repo, closing a PR, or force-pushing any other branch.
- The goal is ambiguous in a way that changes the result.
- Another PR makes this one obsolete.

Decide everything else yourself and list those decisions in the report. If no question tool is
available or it returns no answer, leave the PR open and unmerged and start your final message
with the question.

## Hard rules

- Never merge with `--admin` or any other branch-protection bypass.
- Never credit an AI tool or model in commits, the PR or comments beyond what
  `leaving-pr-comments` requires.
- Unwatch the PR before you stop short of a merge.

## Report

- The PR link and the merge commit
- Your proof: commands with results, and the evidence URLs
- The reviewer outcome: rounds, model, findings fixed and declined
- Each decision you made for the user
