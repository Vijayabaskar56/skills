# First run

Write `.perf-check.json` at the app repo root. Detect every field you can; ask only for the
choices, in one round, recommended option first.

| Field | How to fill it |
| --- | --- |
| `android.package` | `applicationId` in `android/app/build.gradle`, or the Expo config's `android.package` |
| `android.serial` | empty picks the first connected device; set it when several are connected |
| `android.home` | the deep link to the app's first screen, from the linking config |
| `android.settleSeconds` | seconds from launch until the home screen has loaded (default 8) |
| `release.build` | command run from the repo root that builds a release APK signed with the same key as the installed app (ask if the release build uses a different key) |
| `release.apk` | path of that APK, relative to the repo root |
| `release.debugApk` | path of the development APK, to restore the device after the run |
| `screens[].name` | a short name for the report |
| `screens[].open` | deep link with `{id}` where the item id goes |
| `screens[].ids` | 2 or 3 real ids with different content; ask the user which items matter |
| `screens[].rounds` | opens per id (default 2; the first open of an id may fetch, later ones hit the cache) |
| `screens[].scroll` | true to also run the scroll benchmark on the first id |
| `interactions` | optional in-app taps to benchmark with `bench-tap.py`; fields in `interactions.md` |
| `baseline` | where the accepted run is stored; a git-ignored folder, since it is device-specific |
| `thresholds.pct`, `thresholds.absMs`, `thresholds.absPts` | regression gate (defaults 20, 5, 1.5) |
| `notes` | the repo's notes file for this skill: history, accepted trade-offs, open items |

`assets/perf-check.example.json` is a filled example. For Expo apps, an `EXPO_PUBLIC_*` value
changed only in the environment does not rebuild the JS bundle; add
`:app:createBundleReleaseJsAndAssets --rerun` to `release.build`.
