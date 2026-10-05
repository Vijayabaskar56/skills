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

If no app matches the bundle id, stop and tell the user. The app has to be created in App Store
Connect first.

## 3. Ask once

One `AskUserQuestion` call with only the questions detection could not settle, recommended first:

1. Platforms: iOS and Android / iOS only / Android only.
2. Beta groups (multiSelect). List external groups first. Internal groups with all-builds access
   get every build anyway. Say that external groups wait on Apple's beta review.
3. Android output: APK in ~/Downloads / APK in another folder / AAB.
4. Notes: show the draft and upload unless I edit it / wait for my OK / no notes.

## 4. Write the config

Start from `assets/ship-builds.example.json`, fill it in, save it as `.ship-builds.json` at the repo
root, and run the repo's formatter on it so validate still passes. It holds ids only. Tell the user
it exists and offer to commit it.
