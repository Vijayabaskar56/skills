---
name: write-great-skills
description: Use when writing a new agent skill, restructuring one that is long or unreliable, or reviewing a SKILL.md before it ships. Covers when to write a skill, file layout, splitting a shared core from project config, a setup check for tools and MCP servers, scripts for checks the agent must not skip, safe reruns, questions, claim checks, and a lint script. Not for measuring a skill's trigger rate with evals; use skill-creator.
argument-hint: "skill to write or path of a skill to restructure"
---

# Write great skills

A skill is a prompt the agent may skim. Anything that must happen goes in a script; the prose
decides the order and the judgment calls. `references/lessons.md` has the reasoning behind the
rules below and a before-and-after example for most of them.

## 0. Check setup

Run `scripts/doctor.sh`. Fix each `missing` line before going on, asking the user before installing
anything, and confirm each `session` line yourself.

**Done when** doctor exits 0 and each `session` line is confirmed or listed as skipped in the report.

## 1. Decide it should be a skill

On your first use of this skill, read `references/lessons.md` now. Write a skill for a repeated
multi-step task with judgment calls. A one-line preference belongs in AGENTS.md or CLAUDE.md, and
a fully mechanical task belongs in a script. If an existing skill covers it, extend that one.

**Done when** you have written down the trigger phrase and the finished state, one sentence each.

## 2. Write the description

Start with "Use when" and the triggers, collapse synonyms into one branch, then say in a sentence
what it does. End with the nearest wrong match: "Not for X; use Y." Stay under 450 characters.
Add `argument-hint` when the user passes something at invocation.

**Done when** lint prints no `description` warning and every phrase left carries a real trigger.

## 3. Lay out the files

Start from `assets/SKILL.template.md`. Keep in `SKILL.md` only what every run needs, and aim for
under 150 lines. Move the rest:

| Material | Goes to |
| --- | --- |
| Needed once per repo or machine, or only when something fails | a `references/` file (first-run.md, troubleshooting.md) |
| A check the agent must never skip, or any exact command sequence | `scripts/*.sh` with a `Usage:` header |
| Templates, example configs | `assets/` |

**Done when** lint prints no `points to` error and every file in the skill is named in a step.

## 4. Separate the generic core from project facts

Decide who shares the skill. If more than one repo or person will use it, keep in the skill only
what holds everywhere, and move every project fact out:

| Project fact | Goes to |
| --- | --- |
| Paths, component names, tokens, fonts, URLs, device names, personal directories | a per-repo config (for example `.<skill>.json`) the first run writes |
| Prose facts: history, known constraints, house conventions | a notes file the config names |
| Repo files the skill runs (a diff tool, an agent definition) | copied into the skill's `scripts/` or `assets/` |
| Behaviour that differs by platform or stack | one shared step plus one reference per platform |

Give each distinct concept its own config field, even when two look alike: a download folder the
tool allows is not the repo folder assets live in. The first run detects every field it can from
the repo and asks only for the rest (step 9).

**Done when** a grep of the skill for the repo's paths and component names finds nothing, lint
prints no `machine-specific path` warning, and a first-run reference names every config field.

## 5. Ship a setup check

List everything the skill needs outside itself: CLIs, runtimes, MCP servers, apps that must be
running, agent definitions, logins. Write `<skill>/scripts/doctor.sh` to check each one and print `ok`,
`missing` with the fix, `optional`, or `session` for what only the agent can confirm (an MCP tool
answering). Make it step 0 of the skill, and put install and connection steps in
`<skill>/references/setup.md`. Installing anything needs the user's yes.

**Done when** doctor, run with one dependency off `PATH`, prints `missing` with the fix and exits 1.

## 6. Turn rules into scripts

Each "always check", "never forget" or "note that X lies" in the draft becomes a script that does
the check and exits non-zero. Before writing one, search the repo's lint rules, tests and hooks
for the same check; if one exists, point the step at it instead of duplicating it. Scripts use
`set -euo pipefail`, take arguments instead of reading prose, print only what the agent needs next,
and hide long logs behind a file path.

**Done when** each "always", "never" or "check" sentence in the steps names a script or a lint rule.

## 7. Write the steps

- Number the steps and give each a verb heading: "Bump the build number", not "Versioning".
- Put the condition before the instruction: "If validate fails, stop the run."
- State the rule; add a reason only when the rule looks wrong without one.
- End each step with a **Done when** line naming an observable fact: a file, an exit code, a value.
- Tell the agent what to look up instead of restating the environment in tables.

**Done when** lint prints no `has no Done when line` warning and each heading starts with a verb.

## 8. Make reruns safe

Ask what happens when the previous run died halfway. Every write step checks the current state
first and skips or reconciles: reuse a number that was not consumed, update instead of create,
tag only if the tag is missing.

**Done when** a second run right after the first changes no file, tag or remote record (diff them).

## 9. Ask little, remember answers

The agent finds facts itself and asks the user only for choices. Ask one round of at most four
questions (AskUserQuestion in Claude Code, a plain numbered question elsewhere), recommended option
first. Save the answers to the config file from step 4 so the next run asks nothing, and let the
request override it for one run.

**Done when** the config file holds every answer and a second run asks no questions.

## 10. Collect hard rules and fix the report

Put every never-rule in one `## Hard rules` section, each phrased as the action to take. Irreversible
or outward-facing actions (publishing, uploading, deleting, inviting people) need a consent source:
the request, a saved config answer, or a question. End with a `## Report` list of the evidence to
quote, not a summary of feelings.

**Done when** SKILL.md has a `## Hard rules` and a `## Report` section and lint exits 0.

## 11. Check claims, lint and test safely

Check every claim the skill makes about the world against the world: each repo path and
component it names exists, each "lint enforces X" names the rule and its config line, each number
agrees across files, and each command runs on the installed version. A claim you cannot check
becomes "calibrate" or "verify", never a fact.

Run `scripts/lint-skill.sh <skillDir>`. Fix every error; fix each warning or state why it stays.
Test scripts on copies and failure paths first. Never test a script that publishes against a real
account: the refusal you expect may not fire.

**Done when** each claim has a verdict, lint exits 0, and every script has run on real input.

## Hard rules

- Write skills with straight quotes and no em or en dashes. Run `unslop` on the prose.
- Ship a skill only after lint exits 0.
- Install a shared skill from one source: a skills.sh install pinned to a commit
  (`npx skills add owner/repo#<sha>`) or a symlink to one checkout. Never hand-copy a skill folder.

## Report

- The last line `scripts/lint-skill.sh` printed, and any warning left with its reason
- SKILL.md line count and description character count
- Each claim checked in step 11, with its verdict: true, fixed, or reworded to "calibrate"
- Each skipped step or unconfirmed `session` line, with its reason
