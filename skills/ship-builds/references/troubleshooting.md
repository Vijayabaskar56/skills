# Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `X does not support provisioning profiles` | profile passed as a global xcodebuild flag | scope it to the app target (`signing.md`) |
| `has conflicting provisioning settings` | identity passed globally | put `CODE_SIGN_IDENTITY` in the target's Release block |
| `Signing for "X" requires a development team` | no team set | set `DEVELOPMENT_TEAM` (Expo: `ios.appleTeamId`) |
| `Sandbox: node(…) deny(1) file-read-data` | `ENABLE_USER_SCRIPT_SANDBOXING = YES` blocks the RN bundling phase | set it to `NO` for the app target |
| `build.db: disk I/O error` or `Mkdtemp` errors | corrupt DerivedData | ask the user, then delete that app's DerivedData folder |
| `expo config --json exited with non-zero code` | env validation runs without dotenv | set the repo's skip flag, for example `SKIP_ENV_VALIDATION=1` |
| `sentry-cli - error: Auth token is required` in the bundle phase | Xcode doesn't read `.env` files | export `SENTRY_AUTH_TOKEN` from the repo's env file in the shell that runs `build-ios.sh` |
| a flood of `error: sentry-cli - …` lines | sentry-cli trace output labelled `error:` | ignore them; read the last `sentry-cli - error:` line and the failed-commands list |
| `archive has build X, expected N` | the archive predates the bump | rerun steps 4 and 5 |
| `export renumbered build N to M` | N is already in App Store Connect | rerun `upload-ios.sh`, which takes the notes-only path |
| check-signing.sh: `expected Manual` or `no CODE_SIGN_IDENTITY` | a prebuild wiped manual signing | re-apply it (`signing.md`), then rerun check-signing.sh |
| check-notes.sh: over 4000 characters, em dash or curly quote | notes too long or pasted from a rich text editor | cut the notes or replace the listed characters, then rerun |
| resume-state.sh warns a build has no tag and no matching archive | that build was uploaded from another machine or by hand | `resume bump` is right; tag that build by hand only if it was this repo's |
| `asc builds wait exited` | processing failed or timed out | quote the `processing` state; for a timeout, rerun `upload-ios.sh`, which finds the build and waits again |
| `bundle version must be higher` | a stale IPA was uploaded by hand | use `upload-ios.sh`, never a bare `asc builds upload` |
| apply refuses, `receipt.json already exists` | a previous signing apply left its receipt | rename the receipt (`signing.md`) |
| build hangs with no output after importing a certificate | keychain prompt waiting | the user clicks Always Allow |
| Android `createBundleReleaseJsAndAssets` fails with `Failed to get the SHA-1 for ... .worklets/...js` | the iOS archive or a running Metro rewrote the worklets cache mid-bundle | `build-android.sh` retries once automatically; if it fails again, stop Metro and rerun Android alone |
| `ota-preflight.sh` prints `mismatch` | the tree's native inputs differ from the build's (an uncommitted `app.config.ts` edit counts) | follow `ota.md` step 2: copy for data-only differences, a new build otherwise |
| `ota-served.sh` prints `none NO_UPDATE_AVAILABLE` after a publish | the update went to another runtime or channel | compare the publish log's `Runtime version` with `ota-builds.sh`, then redo `ota.md` step 2 |
| `eas update` fails with `getaddrinfo ENOTFOUND update-assets-upload-production.storage.googleapis.com` | DNS blip on the asset upload host; nothing was published | check with `dscacheutil -q host -a name <host>`, then rerun once |
| `eas update` in a copy asks to run `git init` | the copy has no `.git` | make copies with `ota-copy.sh`, which keeps `.git`; or set `EAS_NO_VCS=1` |
| `ota-sentry-check.sh` prints `missing <platform> no-debug-id` | the bundle was exported without the Sentry metro plugin | use `getSentryExpoConfig` in `metro.config`, then publish again |
| Android `SDK location not found` | `expo prebuild --clean` deleted `android/local.properties` | write `sdk.dir=$HOME/Library/Android/sdk` (or `$ANDROID_HOME`) to `android/local.properties`, then rerun |
| EAS `git clone ... failed` for a `git+ssh` dependency in Install dependencies | the EAS account has no access to that private repo | ask the user: a read-only `GITHUB_TOKEN` EAS secret plus an `eas-build-pre-install` hook that rewrites `git@github.com:` to HTTPS, repo access for that account, or a local build |
| Gradle `JVM garbage collector is thrashing` or `running out of JVM heap space` | `expo prebuild --clean` reset `org.gradle.jvmargs` to 2 GB, or the iOS archive ran at the same time | `./gradlew --stop`, set `org.gradle.jvmargs=-Xmx6g -XX:MaxMetaspaceSize=1g` in `android/gradle.properties`, rerun Android alone |
