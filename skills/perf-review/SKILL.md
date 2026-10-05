---
name: perf-review
description: Use when a React or React Native (Expo) app got laggy, janky or slow after a change or a new build, or when asked to review a branch, commit range or two builds for performance regressions. Fans out read-only agents per area, verifies the top findings and returns a ranked, file-cited list of likely causes with fixes. Not for profiling (use argent-react-native-profiler), fixing the code, or general review (use code-review).
argument-hint: "range: a branch, BASE..HEAD, two build tags, or 'last build'"
---

# Perf review

Reads a diff and names the changes most likely to cost frames. It never edits code; the user picks
the fixes. Scripts are in this skill's `scripts/`; run them by absolute path with `--repo <app
repo>`. The repo's AGENTS.md or CLAUDE.md wins over this file.

## 0. Check the setup

Run `scripts/doctor.sh --repo <repo>`. If it prints `missing`, apply the fix it names or stop.
Confirm the `session` line yourself; without a subagent tool, review alone in step 3.

**Done when** doctor exits 0 and you know whether subagents are available.

## 1. Resolve the range

If `<repo>/.perf-review.json` exists, its `tagPrefix` is the build tag prefix; a prefix or refs in
the request override it for this run. Pick the form that matches the request and run
`scripts/diff-areas.sh --repo <repo> <range>`:

| Request | Range argument |
| --- | --- |
| a branch, commit or explicit range | `BASE..HEAD`, or `main..<branch>` for a branch |
| two shipped builds | `--builds <tagPrefix>` for the two newest, or `<tag>..<tag>` |
| last build vs now, builds are tagged | `--since-build <tagPrefix>` |
| last build vs now, no tags | `--since-time "<upload time>"` |

With no config, find the prefix with `git tag -l --sort=-creatordate | head`; once a run with it
succeeds, write `{"tagPrefix": "<prefix>"}` to `<repo>/.perf-review.json`. For `--since-time`,
take the upload time from the store (App Store Connect, Play Console) or ask the user; the base is
the last commit before that time, so it is a guess and the report says so. If the request names
builds you cannot map to refs, ask once which refs they are.

If the script exits 1, read its `error` line:

- `the newest build is HEAD`: rerun with `--builds <tagPrefix>`.
- `no file changes in range ...; try the next older pair: A..B`: rerun with `A..B`, and report
  that the newer pair changed no files.
- Anything else, or a pair that also has no changes: ask once which refs to compare.

**Done when** the script exited 0 and printed `range`, `basis`, `native` and the areas. Save the
output; later steps quote it.

## 2. Gather the brief's fill-ins

- Stack: read package.json for the framework, platform and the libraries that decide frames
  (animation, lists, images, navigation, styling, state).
- Repo rules: lines in AGENTS.md or CLAUDE.md about lists, animation, effects or lint.
- Perf commits: the script's last section, plus any fix the user named.
- If `native` lists files, note that a native or config change can cost frames outside what this
  review reads, and say so in the report.

**Done when** the brief text each agent will get (below the rule in `references/brief.md`)
contains no `{{`.

## 3. Plan the agents

- One agent per area that holds code. Drop areas with only docs, tests or assets. Merge an area
  under about 30 changed lines into its nearest neighbour. Stop at 8 area agents.
- One primitives agent for the widest reach: the top of the script's `widest reach` list,
  skipping constant, id-catalog, type and config modules (importing them costs no frames), plus
  any changed text, icon, press, list or image wrapper, provider, root layout or app entry.
- If the whole diff is under about 150 lines, skip the fan-out and apply the brief yourself.

**Done when** every changed code file is on exactly one agent's list, or you are reviewing alone.

## 4. Send the agents in parallel

Send all agents in one message, each with `references/brief.md` filled for its area. Use a
general-purpose subagent type; the brief keeps it read-only. If an agent returns nothing usable,
send it once more with the same brief.

**Done when** every agent has returned findings or "clean".

## 5. Verify the top findings

Merge duplicates (the primitives agent and an area agent often report one cause twice). Then, for
every finding marked likely cause or high severity, take `<base>` and `<head>` from the `range`
line and run:

1. `scripts/verify-finding.sh --repo <repo> <base> <head> <path> <from> <to>`. It prints the
   lines as shipped, exits 1 when the range did not touch them, and prints an approximate
   importer count. Add `--reach '<pattern>'` to count uses of a symbol or prop instead.
2. For any claim that lint does or does not enforce something, run
   `scripts/find-lint-rule.sh --repo <repo> '<rule pattern>'` and read the matched line's severity.
   A claim about a config, wrapper or prop that "already handles" it gets opened and read.

Drop a finding when verify-finding exits 1. Downgrade one whose `reach` line or claim does not
hold. Mark each row verified or not.

**Done when** every likely-cause row says `verified` or gives the reason it could not be.

## 6. Rank and report

Rank by severity, then reach, using the scales in `references/brief.md`. A finding is a likely
cause only when it is high or medium severity with screen or wide reach and verified; everything
else is minor. For each fix, name its trade-off (memory, a later first paint, a lost animation,
more code).

If a likely cause is uncertain, recommend a measurement and do not block the report on it: for
React Native the `argent-react-native-profiler` skill (React commits and CPU on a device) or the
performance monitor; for the web the browser's Performance panel, the React DevTools Profiler and
INP from web-vitals.

**Done when** the reply follows the Report section.

## Hard rules

- Stay read-only: edit, stage and commit nothing, and leave the fixes to the user. The one write
  is `.perf-review.json` in step 1.
- Cite file:line at the range's head, not the working tree.
- Label a time-matched base as a guess until the user confirms it.
- Call a finding a likely cause only after step 5 verified it.

## Report

- Range, basis (say "guess" when time-matched), commit count and the `native` line
- The `dirty` line, if printed, and that those uncommitted files were not reviewed
- Agents sent, by area, and the areas that came back clean
- **Likely cause** table: # | cause | where felt (screen, gesture) | severity x reach | file:line | fix | trade-off
- **Minor** table with the same columns
- Findings dropped or left unverified in step 5, each with its reason
- Measurements recommended, if any, and what each would settle
