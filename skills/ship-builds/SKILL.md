---
name: ship-builds
description: Use when asked for a TestFlight build, a test build for testers, or an APK to share from a React Native or Expo app. Builds iOS and Android locally in parallel, uploads iOS with short What to Test notes, invites beta groups, and saves the APK. Not for EAS builds or App Store releases; use eas-app-stores.
argument-hint: "platforms, groups or notes to override for this run"
---

# Ship builds

A repo release doc (for example `docs/*testflight*.md`) overrides this file wherever they differ.
`scripts/` means this skill's base directory plus `scripts/`. Call them by absolute path from the
app's repo root, and trust their exit code over their output.
Never read a build log whole. Use `grep -c` or `tail`.

## 0. Check tools

Run `scripts/doctor.sh <ios|android|both>`. Use `both` when no config exists yet.

If it reports anything missing, ask once with `AskUserQuestion`: install with Homebrew
(recommended), the user installs it, or skip that platform this run. Xcode, Android Studio and
Homebrew itself need the user. Give the link and continue with the other platform.

**Done when** doctor exits 0 for every platform this run builds.

## 1. Load the config

Read `.ship-builds.json` at the repo root. If it is missing, follow `references/first-run.md`,
which detects what it can and asks the rest in one question round. Anything the user named in
this request overrides the config for this run only.

**Done when** the config exists and every field this run needs is filled.

## 2. Preflight

1. Run the config's `validate` command. If it fails, stop the run and show the failure.
2. `git status --short`. Uncommitted work ships but falls outside the next build's diff base, so
   tell the user.
3. For Expo without `ios/` or `android/`, run `npx expo prebuild`.

**Done when** validate exits 0.

## 3. Check performance

Skip this step when the config has no `perf` block. Otherwise, with Metro running and the dev
build on the simulator:

```bash
scripts/perf-measure.sh <scratch>/perf-current.json
scripts/perf-compare.mjs <perf.baseline> <scratch>/perf-current.json <perf.thresholdPct>
```

If compare exits 1, stop the run and show its table. Ship anyway only when the user says so for
this build. `references/perf.md` covers what the numbers mean, flaky runs and moving the baseline.

**Done when** compare exits 0, or the user has accepted the regression it printed.

## 4. Bump the iOS build number

`N=$(scripts/bump-ios-build.sh <appId> <version> <infoPlist>)`. With `signing: manual`, confirm
the app target's Release block still has manual signing, because a prebuild wipes it.
`references/signing.md` has the re-apply steps.

**Done when** the script prints N.

## 5. Start both builds in the background

```bash
scripts/build-ios.sh <workspace> <scheme> <scratch>/ios.log [xcodebuild flags]   # prints the archived N
scripts/build-android.sh <apk|aab> <scratch>/android.log                          # prints the artifact path
```

Budget 20 to 40 minutes each. Draft the notes while they run.

**Done when** build-ios prints the same N and build-android prints a path.

## 6. Draft the test notes

Diff base is `git describe --tags --match '<tagPrefix>*' --abbrev=0`. If there is no tag, match
the last upload time from `asc builds list --app <appId>` against `git log` and say the base is a
guess. Cover `<base>..HEAD` plus uncommitted work. For a large diff, send a subagent and ask for
one line per tester-visible change as `Screen: change (file)`.

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
straight quotes and no em dashes, and keep it near 1200 characters (4000 at most). Run `unslop`
on it. Then follow `notes.review`: `show-and-continue` prints the draft and takes edits that
arrive before upload.

**Done when** the notes file exists.

## 7. Upload iOS and invite groups

```bash
BUILD_ID=$(scripts/upload-ios.sh <appId> <version> <scheme> <N> <notesFile> <locale> [exportOptions])
asc builds add-groups --build-id "$BUILD_ID" --group <groupIds> [--submit --confirm]   # --submit if any group is external
asc builds groups list --build-id "$BUILD_ID" --output table
git tag <tagPrefix><N> <archived commit>
```

The upload script is rerun-safe. If build N is already in App Store Connect, it only sets the notes.
If step 3 ran, copy its `perf-current.json` over `perf.baseline`, so the baseline is always the
last shipped build.

**Done when** groups list shows every configured group and the tag exists.

## 8. Save the Android artifact

`scripts/copy-apk.sh <apkPath> <outputDir> <name> <version>`. The name is the app label or the
package.json name. It prints path, size, package line and signer.

**Done when** the file exists at the printed path.

## Hard rules

- Commit only when this request asks. Tag locally and never push the tag unasked.
- Install tools only after a yes.
- Invite only groups from the config or this request. The first-run answer counts as consent.
- Create an App Store Connect app or an Android keystore only when the user asks.
- `upload-ios.sh` uploads for real. To test a change to it, use an app with no testers.

## Report

Reply with this list, quoting the values the scripts and `asc` printed:

- Commit and tag shipped
- Perf: the compare PASS/FAIL line and every REGRESSED row, or why the step was skipped
- iOS: build N, processing state, groups (external ones wait on beta review)
- Android: path, size, versionCode, signer. Debug-signed means sideload only, not Play
- Skipped steps, each with its reason
