---
name: ship-builds
description: Use when asked for a TestFlight build, a test build for testers, or an APK to share from a React Native or Expo app. Builds iOS and Android locally in parallel, uploads iOS with short What to Test notes, invites beta groups, and saves the APK. Not for EAS builds or App Store releases; use eas-app-stores.
argument-hint: "platforms, groups or notes to override for this run"
---

# Ship builds

A repo release doc (for example `docs/*testflight*.md`) overrides this file wherever they differ.
`scripts/` means this skill's base directory plus `scripts/`. Call them by absolute path from the
app's repo root, and trust their exit code over their output. If a script fails, look up its
message in `references/troubleshooting.md`. `<scratch>` is one `mktemp -d` directory per run.

## 0. Check tools

Run `scripts/doctor.sh <ios|android|both>`. Use `both` when no config exists yet.

If it reports anything missing, look up the fix in `references/setup.md` and ask once with
`AskUserQuestion`: install it (recommended), the user installs it, or skip that platform this run.
Confirm each `session` line yourself before the step that needs it.

**Done when** doctor exits 0 for every platform this run builds.

## 1. Load the config

Read `.ship-builds.json` at the repo root. If it is missing, follow `references/first-run.md`,
which detects what it can and asks the rest in one question round. Anything the user named in
this request overrides the config for this run only.

**Done when** the config exists and every field this run needs is filled.

## 2. Run the preflight checks

1. Run the config's `validate` command. If it fails, stop the run and show the failure.
2. `git status --short`. Tell the user uncommitted work ships but falls outside the next diff base.
3. For Expo without `ios/` or `android/`, run `npx expo prebuild`.

**Done when** validate exits 0.

## 3. Check performance

Skip this step when the config has no `perf` block. Otherwise, with Metro running and the dev
build on the simulator:

```bash
scripts/perf-measure.sh <scratch>/perf-current.json
scripts/perf-compare.mjs <perf.baseline> <scratch>/perf-current.json <perf.thresholdPct>
```

- If `perf.baseline` does not exist, skip compare: copy `perf-current.json` to `perf.baseline`,
  report "first baseline" and continue.
- If measure exits 2 because a build is busy, wait and rerun. If Metro, a simulator or argent is
  missing, say so, then ask to start it or skip (`perf.whenUnavailable: ask`, the default) or skip.
- If compare exits 1, stop the run and show its table. Ship anyway only when the user says so for
  this build. `references/perf.md` covers what the numbers mean, flaky runs and the baseline.

**Done when** compare exits 0, the first baseline is saved, or a skip or override has a reason.

## 4. Bump the iOS build number

Run `scripts/resume-state.sh <appId> <version> <scheme> <tagPrefix>` first. If its last line is
`resume upload <N> <commit>`, a run archived or uploaded N and died: skip the bump and the iOS
archive, and carry N and the commit into steps 6 and 7. If it is `resume bump`, run
`N=$(scripts/bump-ios-build.sh <appId> <version> <infoPlist>)`.

**Done when** resume-state or the bump script printed N.

## 5. Start both builds in the background

With `signing: manual`, first run `scripts/check-signing.sh <project> <target>`. If it exits 1,
a prebuild wiped manual signing: re-apply it with `references/signing.md` and rerun the check.

```bash
scripts/build-ios.sh <workspace> <scheme> <scratch>/ios.log [xcodebuild flags]   # prints "<N> <commit>"
scripts/build-android.sh <apk|aab> <scratch>/android.log                          # prints the artifact path
```

Budget 20 to 40 minutes each. Draft the notes while they run.

**Done when** build-ios prints the same N with its commit and build-android prints a path.

## 6. Draft the test notes

Diff base is `git describe --tags --match '<tagPrefix>*' --abbrev=0`. If there is no tag, match
the last upload time from `asc builds list --app <appId>` against `git log` and say the base is a
guess. Cover `<base>..HEAD` (`<base>..<commit>` on a resume) plus uncommitted work. For a large
diff, send a subagent and ask for one line per tester-visible change as `Screen: change (file)`.

Write the notes minimal, fragments over grammar:

```
- Dashboard: new video carousel. Swipe down to close a video
- Settings: dark mode switch
- Text size capped at 1.3x
- Known issue: payments not wired, offline screen placeholder
- Please check: play and close videos. Toggle dark mode on every tab
```

One line per change. Merge cosmetic tweaks and skip refactors. Carry unresolved known issues from
`asc builds test-notes list --app <appId> --latest`. End with one `Please check:` line. Use
straight quotes and no em dashes, and keep it near 1200 characters. Run `unslop` on it, save it as
`<scratch>/notes.txt` and run `scripts/check-notes.sh <scratch>/notes.txt`. Then follow
`notes.review`: `show-and-continue` prints the draft and takes edits that arrive before upload.

**Done when** `<scratch>/notes.txt` exists and check-notes exits 0.

## 7. Upload iOS and invite groups

```bash
BUILD_ID=$(scripts/upload-ios.sh <appId> <version> <scheme> <N> <scratch>/notes.txt <locale> [exportOptions])
asc builds add-groups --build-id "$BUILD_ID" --group <groupIds> [--submit --confirm]   # --submit if any group is external
asc builds groups list --build-id "$BUILD_ID" --output table
git rev-parse -q --verify "refs/tags/<tagPrefix><N>" >/dev/null || git tag <tagPrefix><N> <commit>
```

`<commit>` is the one printed with N. If build N is already in App Store Connect, upload-ios.sh
only sets the notes. If step 3 measured this run, copy its `perf-current.json` over
`perf.baseline`, so the baseline is always the last shipped build.

**Done when** groups list shows every configured group and the tag exists.

## 8. Save the Android artifact

`scripts/copy-apk.sh <apkPath> <outputDir> <name> <version>`. The name is the app label or the
package.json name. It prints path, size, package line and signer.

**Done when** the file exists at the printed path.

## Hard rules

- Read a build log only with `grep -c` or `tail`, never whole.
- Commit only when this request asks. Tag locally and never push the tag unasked.
- Install tools only after a yes.
- Invite only groups from the config or this request. The first-run answer counts as consent.
- Create an App Store Connect app or an Android keystore only when the user asks.
- `upload-ios.sh` uploads for real. Test a change to it with a stub `asc` first on PATH, never
  against a real App Store Connect app.

## Report

Reply with this list, quoting the values the scripts and `asc` printed:

- Commit and tag shipped
- Perf: the compare PASS/FAIL line and every REGRESSED row, or why the step was skipped
- Resume: the `resume` line, and every `warn` line resume-state printed
- iOS: build N, the `processing` state upload-ios printed, groups (external ones wait on beta review)
- Android: path, size, versionCode, signer. Debug-signed means sideload only, not Play
- Skipped steps, each with its reason
