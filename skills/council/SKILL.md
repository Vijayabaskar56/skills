---
name: council
description: Use when the user says "council". Gets read-only review or feedback from three strong models on three different providers, in parallel, fixes what they agree on and loops until they are satisfied. Not for a one-model review loop; use sol-loop or smart-review.
---

# Council

Adapted from [t3dotgg/tstack](https://github.com/t3dotgg/tstack) (MIT).

## 1. Get the change ready

Before an audit, answer outstanding PR comments, fix known issues and run the relevant checks. Give
the council the updated implementation; do not hold back known fixes until reviews return. If the
user wants to throw the implementation away and explore new ideas, skip fixes to code being
replaced.

**Done when** known issues are fixed and the checks have run.

## 2. Pick the members

Use one strong model from each of three providers, at high reasoning effort. If the user's
`CLAUDE.md` or `AGENTS.md` names council members, use those. Otherwise use the latest flagship
from each provider, for example Claude Opus, GPT Sol and Gemini Pro. Never pick Fable unless the
user asks for it.

In T3 Code, call `orchestrator_capabilities` once to resolve the models, then start one
`delegate_task` per member, in parallel. Elsewhere, use the harness's subagent tools. If you cannot
reach three providers, or a named member is unavailable, report it instead of substituting.

**Done when** three delegates are running, one per provider, or the gap is reported.

## 3. Review the results

Give each delegate the request and the context it needs, and keep review work read-only. For a code
review, ask each for a score out of 10. Count each full review pass as one round; a fresh review
after fixes starts a new round.

Do not wait idle. When a result arrives, check its findings against the code and decide what to fix
while the others run. Do not edit files while a delegate still reviews the same checkout. If the
user's instructions mark a delegate as non-blocking, do not wait for it; treat a late result as
feedback and do not record its score.

Make the changes you agree with, then ask for a fresh review. Continue until every member is
satisfied. Keep scope limited: repeated reviews invite scope creep, and fighting it is your job.

**Done when** every member is satisfied with the current change, or the disagreement is reported.

## 4. Record the outcome

If the work ends in a PR, put the results in its description, editing it if the PR is open. If
there is no PR, put the same table in the final reply only. If a delegate gives no score, write
`no score`. Copy the shape in [references/pr-table.md](references/pr-table.md).

**Done when** the table is in the PR description or the final reply.

## Hard rules

- Never invent a score.
- Never post the council results as a PR comment; edit the description.
- Never add an AI credit line ("Created with", "Generated with") to the PR. The council table is
  review evidence, not authorship.

## Report

- Members, with provider and model
- Rounds and the score table
- Findings fixed, findings declined with reasons, and any open disagreement
