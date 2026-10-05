# Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `X does not support provisioning profiles` | profile passed as a global xcodebuild flag | scope it to the app target (`signing.md`) |
| `has conflicting provisioning settings` | identity passed globally | put `CODE_SIGN_IDENTITY` in the target's Release block |
| `Signing for "X" requires a development team` | no team set | set `DEVELOPMENT_TEAM` (Expo: `ios.appleTeamId`) |
| `Sandbox: node(…) deny(1) file-read-data` | `ENABLE_USER_SCRIPT_SANDBOXING = YES` blocks the RN bundling phase | set it to `NO` for the app target |
| `build.db: disk I/O error` or `Mkdtemp` errors | corrupt DerivedData | ask the user, then delete that app's DerivedData folder |
| `expo config --json exited with non-zero code` | env validation runs without dotenv | set the repo's skip flag, for example `SKIP_ENV_VALIDATION=1` |
| `archive has build X, expected N` | the archive predates the bump | rerun steps 3 and 4 |
| `export renumbered build N to M` | N is already in App Store Connect | rerun `upload-ios.sh`, which takes the notes-only path |
| `bundle version must be higher` | a stale IPA was uploaded by hand | use `upload-ios.sh`, never a bare `asc builds upload` |
| apply refuses, `receipt.json already exists` | a previous signing apply left its receipt | rename the receipt (`signing.md`) |
| build hangs with no output after importing a certificate | keychain prompt waiting | the user clicks Always Allow |
| Android `createBundleReleaseJsAndAssets` fails with `Failed to get the SHA-1 for ... .worklets/...js` | the iOS archive or a running Metro rewrote the worklets cache mid-bundle | `build-android.sh` retries once automatically; if it fails again, stop Metro and rerun Android alone |
