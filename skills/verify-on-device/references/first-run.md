# First run in a repo

Run when `.verify-on-device.json` is missing. Detect facts yourself; ask only for choices.

## 1. Detect

| Field | Source |
| --- | --- |
| bundleId.ios, bundleId.android | `ios.bundleIdentifier` and `android.package` in app.json / app.config.*, else the Xcode project and `android/app/build.gradle` |
| scheme | `scheme` in app.json / app.config.* |
| deepLinks | the file that lists the app's deep links (a `DeepLinks` or `linking` object), if any |
| sectionParam | a query parameter screens read to scroll to a section, if the code has one |
| flowsDir, recordingsDir | `.argent/flows` and `.argent/recordings` unless the repo keeps them elsewhere |
| deadFlows | flows that no longer run (removed demo logins, deleted screens); empty at first |
| ios.device | the simulator named in the repo's docs, else the newest booted iPhone |
| ios.simulatorApp | an installed Xcode 26.x Simulator.app when the active Xcode is 27+, else `null` |
| android.avd | `emulator -list-avds`, or the one named in the repo's docs |
| android.start, android.stop | the repo's emulator command if AGENTS.md names one, else `null` |

Read the repo's AGENTS.md, CLAUDE.md and README first and prefer what they say.

## 2. Ask once

One `AskUserQuestion` call, only for what detection did not settle: which device and AVD to use,
and where the notes file goes (default `docs/verify-on-device.md`).

## 3. Write the config

Start from `assets/verify-on-device.example.json`, save it as `.verify-on-device.json` at the repo
root, and run the repo's formatter on it. Create the notes file with the project facts you found
(test accounts, skip buttons, which flows replace dead ones). Tell the user both exist and offer
to commit them.
