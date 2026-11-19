# OTA updates

An OTA (EAS Update) reaches every install whose runtime and channel match the update: every
TestFlight group, internal testers and App Store users on that runtime alike. TestFlight groups
cannot narrow it. The runtime the installed build reports is the target; a fingerprint computed on
this machine is a guess until `ota-preflight.sh` says `match`. `<cfg>` is `.ship-builds.json`,
`<scratch>` is one `mktemp -d` directory per run.

## 1. Pick the target builds

List the candidates from EAS, which records each build's runtime:

```bash
scripts/ota-builds.sh <ios|android> <cfg ota.channel> 5
```

For a build made outside EAS, read its runtime from the file instead:
`scripts/ota-runtime.sh file <path.ipa|.xcarchive>` (iOS only).

Ask one `AskUserQuestion` round, recommended options first, only for what is not settled:

1. Which build gets it (multiSelect when several runtimes are live): list each as
   `Build <N> (<channel>, runtime <first 8>)`, newest first. Say the update reaches every install of
   that runtime on the channel, all beta groups and store users included.
2. If `git status --short` is not empty: ship the whole working tree (recommended once validate
   passes) / commit first / stop. List the changed app files, and mark the ones this session did
   not write.
3. Source maps, only when step 3 needs an answer.

**Done when** each chosen build has a runtime from `ota-builds.sh` or `ota-runtime.sh`.

## 2. Match the runtime

For each chosen runtime `R`, from the directory you will publish from:

```bash
scripts/ota-preflight.sh <platform> <R> <cfg ota.env as NAME=value ...>
```

If it prints `mismatch`, find what differs:

- EAS build: `npx eas-cli fingerprint:compare --build-id <id> --environment <cfg ota.environment> --non-interactive`
- Local build: `git diff <build commit> -- app.json 'app.config.*' package.json patches plugins`

If every difference is native data the JS never reads (a permission text, display name, icon),
publish from a copy that has the build's version of those files:

```bash
COPY=$(scripts/ota-copy.sh <scratch>/copy <build commit> <file> [file ...])
```

Rerun `ota-preflight.sh` inside `$COPY` and publish from there. If any difference is code (a
native module, a patch, a plugin, a package version), stop: that build needs a new binary, so go
back to the build steps in `SKILL.md`.

**Done when** `ota-preflight.sh` prints `match` for every chosen runtime, in the tree or a copy.

## 3. Settle source maps

- If `package.json` has no `@sentry/react-native`, skip: report `Sentry: not installed`.
- If `ota.sentry` is `skip`, skip: report `Sentry: skipped by config`.
- If `ota.sentry` is `upload`, check that `SENTRY_AUTH_TOKEN` is in the env or in `.env.local`. If
  it is missing, ask once: add it now (recommended) / publish without source maps this run.
- If `ota.sentry` is unset, ask once: set up source-map upload (recommended) / skip this run /
  never for this repo. Save `upload` or `skip` to `<cfg>`.

To set it up, the user creates an organization auth token in Sentry (Settings, Auth Tokens) and adds
`SENTRY_AUTH_TOKEN=<token>` to `.env.local` themselves. Never take the token in chat. Read
`ota.sentryOrg` and `ota.sentryProject` from the `@sentry/react-native` plugin options in
`npx expo config --json`.

**Done when** the run is `upload` with a token present, or the report has the skip reason.

## 4. Check for a previous run

```bash
scripts/ota-served.sh <cfg ota.updatesUrl> <platform> <R> <cfg ota.channel>
npx eas-cli update:list --branch <cfg ota.channel> --runtime-version <R> --limit 5 --json --non-interactive
```

If the update served for `R` has this run's message, a previous run published it: skip to step 6.

**Done when** you know whether to publish or only verify.

## 5. Publish

Write the message as one line of fragments in the `references/notes.md` style. Run
`ota.publish` when the config names one (the repo's own script), else:

```bash
npx eas-cli update --channel <cfg ota.channel> --environment <cfg ota.environment> \
  --platform <platform> --non-interactive --message "<message>" > <scratch>/ota.log 2>&1
```

Pass `--platform` so each runtime gets only the bundle meant for it. Read the log with `tail` and
`grep -E 'Runtime version|Platform|update ID|Update group'`. With `ota.sentry: upload`, run
`npx sentry-expo-upload-sourcemaps dist` next with the token exported, unless the repo's publish
script already does (grep it for `sentry-expo-upload-sourcemaps`).

**Done when** the log prints an update group id and runtime `R` for each platform.

## 6. Verify from the build's side

```bash
scripts/ota-served.sh <cfg ota.updatesUrl> <platform> <R> <cfg ota.channel>   # must print the new update id
scripts/ota-sentry-check.sh dist <cfg ota.sentryOrg> <cfg ota.sentryProject>  # with ota.sentry: upload
```

Run the Sentry check in the directory you published from, before another export overwrites
`dist`. If `ota-served.sh` prints `none`, the update does not reach that build: go back to step 2.

**Done when** `ota-served.sh` prints this run's update id for every chosen runtime and
`ota-sentry-check.sh` exits 0 or was skipped with a reason.

## 7. Tell testers how to get it

Read `updates.checkAutomatically` and `updates.fallbackToCacheTimeout` in the app config. With the
defaults (check on launch, timeout 0) the app downloads the update in the background at launch and
runs it at the next launch: close the app fully and reopen it, twice if needed. If the app shows its update id
or label (a Profile or About screen), quote the value testers should see.

**Done when** the report says how testers pick it up and what they should see.

## Mistakes this workflow prevents

- 2026-11-03, Propsoch: the agent computed runtime `6258817e` on its own machine and published to
  it. The tree held an uncommitted `app.config.ts` permission-text change, and TestFlight build 8,
  made on EAS without it, reported `0365ee48`. The agent told the user the runtimes matched without
  reading build 8's, and the boss's phone got `NO_UPDATE_AVAILABLE` for 11 hours. Steps 1, 2 and 6
  now read the build's own runtime, compare before publishing and ask the update server afterwards.
- Same day: build 8's first OTA drew the home-map pins three times too large. A patched native
  marker read image density from `@3x` in the file name, and an OTA stores assets under hash
  names. Before the first OTA to a build, apply a test update on a scratch channel to a Release
  simulator copy (its `Expo.plist` channel changed) and look at every screen that hands images
  to native code; delete the channel and branch afterwards.
- Same run: the agent listed what the update contained from memory of the tree. Another session
  changed files between the first and second publish, so the second update shipped changes the list
  left out. Step 1 lists the changed files at publish time and marks the ones this session did not
  write; the report lists the files from the directory actually published.
