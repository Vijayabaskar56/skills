---
name: perf-check
description: Use when a React Native screen must be checked for frame drops after a UI change or redesign, or asked whether a screen still holds 60fps when opened and scrolled. Benchmarks a release build on an Android phone, gates it against a saved baseline and names known culprits from the trace. Not for reading a diff for likely causes; use perf-review.
argument-hint: "screen name from .perf-check.json, or 'baseline' to accept this run"
---

# Perf check

Measures what a user feels, on a real phone: frames missed while a screen opens, and frame time
while it scrolls. Scripts are in this skill's `scripts/`; call them by absolute path from the app
repo root. The repo's `.perf-check.json` holds every project fact and its `notes` file holds the
history: read the notes before step 4. `<out>` is one `mktemp -d` directory per run.

## 0. Check setup

Run `scripts/doctor.sh --repo .`. Fix each `missing` line with `references/setup.md`, asking once
before installing anything. Confirm the `session` line: ask the user to keep the phone awake,
unlocked and untouched for about ten minutes.

**Done when** doctor exits 0 and the user has confirmed the phone is free.

## 1. Load the config

Read `.perf-check.json`. If it is missing, follow `references/first-run.md`. A screen or id named
in the request overrides the config for this run.

**Done when** the config exists and names at least one screen with two ids.

## 2. Install a release build

Run `scripts/device-build.sh --repo . release`. Pass `--skip-build` only when the APK at
`release.apk` was built from the current tree. If the build fails, stop and show its last lines.

**Done when** it prints `installed release`.

## 3. Benchmark

Run `scripts/bench.py --repo . --out <out>` (add `--screen <name>` for one screen). It refuses a
dark or locked screen, a debuggable build and a busy host with exit 2: fix the cause it prints and
rerun. Exit 1 means every open was invalid; read its reason and the `crash` lines.

**Done when** it prints `run <out>/run.json`.

For a tap that navigates (opening, leaving or switching screens in-app), or when the request is
about laggy navigation, also run `scripts/bench-tap.py --repo . --out <out>` (add
`--interaction <name>`). It needs `interactions` in the config: `references/interactions.md`.
Gate its medians by hand against the previous run: it writes `<out>/interactions.json`, which
compare.py does not read.

## 4. Gate against the baseline

If the file at `baseline` is missing, copy `<out>/run.json` there, say "first baseline", and go to
step 6. Otherwise run `scripts/compare.py <baseline> <out>/run.json` with `--pct`, `--abs-ms` and
`--abs-pts` from `thresholds`. Exit 2 means the baseline came from another device or refresh rate:
record a new baseline only with the user's yes.

**Done when** compare printed `PASS` or `FAIL` with its table.

## 5. Triage regressions

For each REGRESSED row and each `crash` line, read the `culprit` and `frame` lines bench printed
for that screen, then `references/culprits.md` for the matching id. Run `scripts/triage.py` on a
second trace from `<out>` to check the culprit repeats. Name the file and the change that caused
it, with the trace evidence. Fix only when the user asks; after a fix, rerun steps 2 to 4.

**Done when** every regressed metric has a culprit with evidence, or is reported as unexplained.

## 6. Accept or keep the baseline

If the request said `baseline`, or the user accepts this run after a PASS or an agreed trade-off,
copy `<out>/run.json` over `baseline`. Add any new finding or accepted trade-off to the notes file.

**Done when** the baseline is the accepted run and the notes name any new trade-off.

## 7. Restore the device

Run `scripts/device-build.sh --repo . debug` unless the user wants to keep the release build.

**Done when** it prints `installed debug`, or the user chose to keep the release build.

## Hard rules

- Measure release builds on a physical phone. Use debug builds and simulators to find causes,
  never to report frame numbers.
- Score a run only with the device awake, unlocked and in the app; bench.py enforces this.
- Overwrite the baseline only on the request's `baseline`, or the user's yes after the report.
- Uninstall the app only with the user's yes; it clears the signed-in session.

## Report

- `device` line from bench.py: model, size, refresh rate, debuggable
- The compare table and its `PASS` or `FAIL` line, or "first baseline"
- Each REGRESSED metric with its culprit id, cost in ms and the file that caused it
- Every `crash` line, with the exception
- Whether the baseline was updated, and where the device was left (release or debug)
- Skipped steps, each with its reason
