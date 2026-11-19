---
name: ship-builds
description: Use when asked for a TestFlight build, a test build or APK for testers, or an OTA (EAS Update) push to installed builds of a React Native or Expo app. Builds iOS locally and Android locally or on EAS, uploads with What to Test notes and invites beta groups, or publishes an OTA to the exact runtime the installed build reports. Not for EAS iOS builds or App Store releases; use eas-app-stores.
argument-hint: "platforms, groups or notes to override for this run"
---

# Ship builds

A repo release doc (for example `docs/*testflight*.md`) overrides this file wherever they differ.
`scripts/` means this skill's base directory plus `scripts/`. Call them by absolute path from the
app's repo root, and trust their exit code over their output. If a script fails, look up its
message in `references/troubleshooting.md`. `<scratch>` is one `mktemp -d` directory per run.

If the request is an OTA or JS-only update, run steps 0 and 1 and the validate check in step 2, then
follow `references/ota.md` instead of the rest.

## 0. Check tools

Run `scripts/doctor.sh <ios|android|both|ota>`. Use `both` when no config exists yet.

If it reports anything missing, look up the fix in `references/setup.md` and ask once with
`AskUserQuestion`: install it (recommended), the user installs it, or skip that platform this run.
Confirm each `session` line yourself before the step that needs it.

**Done when** doctor exits 0 for every platform this run builds.

## 1. Load the config

Read `.ship-builds.json` at the repo root. If it is missing, follow `references/first-run.md`,
which detects what it can and asks the rest in one question round. Anything the user named in
this request overrides the config for this run only.

`ios.account` (the Apple team) and `android.eas.owner` (the Expo account) can differ. Ship only to
accounts the config or this request names, and confirm with `eas whoami` that the Expo login can
reach `android.eas.owner`.

**Done when** the config exists and every field this run needs is filled.

## 2. Run the preflight checks

1. Run the config's `validate` command. If it fails, stop the run and show the failure.
2. `git status --short`. Tell the user uncommitted work ships but falls outside the next diff base.
3. For Expo without `ios/` or `android/`, run `npx expo prebuild`. When `ios.prebuildEnv` is set,
   run the iOS prebuild as `<prebuildEnv> IOS_BUILD_NUMBER=<N> npx expo prebuild --clean -p ios`
   after step 4 instead, and check that the pbxproj `PRODUCT_BUNDLE_IDENTIFIER` equals
   `ios.bundleId`. Skip the Android prebuild when `android.builder` is `eas`.

**Done when** validate exits 0.

## 3. Check performance

Skip this step when the config has no `perf` block. Otherwise run the measure and compare
scripts as `references/perf.md` says, which also covers flaky runs and the baseline.

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

With `android.builder: eas`, skip build-android.sh and queue the build as `references/eas-android.md`
says.

**Done when** build-ios prints the same N with its commit, and build-android prints a path or EAS
prints a build id.

## 6. Draft the test notes

Diff base is `git describe --tags --match '<tagPrefix>*' --abbrev=0`. If there is no tag, match
the last upload time from `asc builds list --app <appId>` against `git log` and say the base is a
guess. Cover `<base>..HEAD` (`<base>..<commit>` on a resume) plus uncommitted work. For a large
diff, send a subagent and ask for one line per tester-visible change as `Screen: change (file)`.

Write them as `references/notes.md` shows: one fragment line per tester-visible change, carried
known issues, one `Please check:` line, near 1200 characters. Run `unslop` on it, save it as
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
only sets the notes. Record the runtime an OTA for this build must target with
`scripts/ota-runtime.sh file .asc/artifacts/<scheme>.xcarchive`. If step 3 measured this run, copy
its `perf-current.json` over `perf.baseline`, so the baseline is always the last shipped build.

**Done when** groups list shows every configured group and the tag exists.

## 8. Save the Android artifact

With `android.builder: eas`, read the build and its Play submission as `references/eas-android.md`
says. With a local builder, run `scripts/copy-apk.sh <apkPath> <outputDir> <name> <version>` (name:
the app label or package.json name); it prints path, size, package line and signer.

**Done when** the EAS build and any submission are FINISHED, or the file exists at the printed path.

## Hard rules

- Read a build log only with `grep -c` or `tail`, never whole.
- Publish an OTA only to a runtime `ota-preflight.sh` matched, with consent from this request or the
  `references/ota.md` step 1 answer. Leave `runtimeVersion` alone; a mismatch means a copy or a build.
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
- Accounts: the Apple team and the Expo owner each platform shipped to
- iOS: build N, the `processing` state upload-ios printed, the runtime ota-runtime printed, and
  groups (external ones wait on beta review)
- Android: path, size, versionCode, signer. Debug-signed means sideload only, not Play. For EAS:
  account, project, profile, build id, status, artifact URL, and the submission's status, track
  and release status
- OTA: per runtime, the update group and id, the `ota-served.sh` line, the `ota-sentry-check.sh`
  lines or the skip reason, and the app files that changed in the directory published
- Skipped steps, each with its reason
