# First run in a repo

Run when `.ship-builds.json` is missing. Find facts yourself and ask the user only for choices.

## 1. Log in to asc if needed

If `scripts/doctor.sh` reported `missing asc-auth`, follow the asc-auth section of `setup.md`.

## 2. Detect

| Field | Source |
| --- | --- |
| bundleId | `ios.bundleIdentifier` in app.json or app.config.*, else `PRODUCT_BUNDLE_IDENTIFIER` in the pbxproj |
| appId | `asc apps list --output json`, matched on bundleId |
| workspace, scheme | `ls ios/*.xcworkspace`, then `xcodebuild -list -workspace <it>` |
| project, target | `ls ios/*.xcodeproj`; the app target from `xcodebuild -list -project <it>`, usually the scheme name |
| infoPlist | `ios/<scheme>/Info.plist` |
| version | `CFBundleShortVersionString`, or `version` in the app config |
| validate | package.json scripts: `validate`, else `check`, else `typecheck` and `test` |
| groups | `asc testflight groups list --app <appId> --output json` |
| signing | `automatic` if an archive signs without help, else `manual` (see `signing.md`) |
| ios.account | `DEVELOPMENT_TEAM` in the pbxproj or `ios.appleTeamId`, plus the team name from the signing identity |
| ios.prebuildEnv | env vars the app config reads to switch bundle id, `owner` or project id, when it has more than one identity |
| ota.channel, ota.environment, ota.env | `channel`, `environment` and `env` of the `eas.json` build profile testers install (usually `production`) |
| ota.updatesUrl | `updates.url` in `npx expo config --json` |
| ota.publish | a package.json script that wraps `eas update` (for example `update`), as the full command with `{message}`; else null |
| ota.sentryOrg, ota.sentryProject | `organization` and `project` of the `@sentry/react-native` plugin in `npx expo config --json` |
| android.eas | `owner`, `slug` and `extra.eas.projectId` from the app config; profile from `eas.json` `build`; `autoSubmit` true when `eas.json` has a `submit` profile of that name with an `android.track` |

If no app matches the bundle id, stop and tell the user. The app has to be created in App Store
Connect first.

## 3. Ask once

One `AskUserQuestion` call with only the questions detection could not settle, recommended first:

1. Platforms: iOS and Android / iOS only / Android only.
2. Beta groups (multiSelect). List external groups first. Internal groups with all-builds access
   get every build anyway. Say that external groups wait on Apple's beta review.
3. Android output: EAS build auto-submitted to Google Play (recommended for an Expo app with a
   `submit` profile) / EAS build only / APK in ~/Downloads / APK in another folder / AAB. For EAS,
   ask which account and profile when `eas whoami` lists several.
4. Accounts, when they differ by platform: which Apple team ships iOS and which Expo owner
   ships Android.
5. Notes: show the draft and upload unless I edit it / wait for my OK / no notes.

For an OTA run, `references/ota.md` asks its own questions (target builds, uncommitted work, source
maps) and saves `ota.sentry`. Leave `ota.sentry` null here.

## 4. Write the config

Start from `assets/ship-builds.example.json`, fill it in, save it as `.ship-builds.json` at the repo
root, and run the repo's formatter on it so validate still passes. It holds ids only. Tell the user
it exists and offer to commit it.
