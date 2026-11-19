# Troubleshooting

| Symptom | Meaning and fix |
| --- | --- |
| `error screen is off` / `device is locked` | wake and unlock the phone; a dark screen draws no frames and scores as a perfect run |
| `invalid: only N frames` for an open | the screen went off, the app left the foreground or crashed mid-run; check the `crash` lines and rerun |
| `error the installed build is debuggable` | install the release build (`device-build.sh release`); debug native code is several times slower, so its numbers are not comparable |
| `error host load average` | a Gradle or Xcode build or another agent is using the CPU; wait, or pass `--allow-busy` and say so in the report |
| `install refused: ... different key` | the release variant is signed differently; ask the user before uninstalling, since it clears app data |
| `note back left the app` | back from the screen exited the app instead of returning home; the script relaunches, but check that `android.home` really lands on the first screen |
| Most janky frames are `Buffer Stuffing` | that is queued latency, not a dropped frame; the score uses only `App Deadline Missed` frames |
| `compare.py` exits 2 | the baseline came from another device or refresh rate; record a new baseline on this device |
| Numbers swing more than 15% between identical runs | another app or a build is competing; rerun with the device idle, and compare medians, not single runs |
| No `MountItemDispatcher` or `createViewUnsafe` slices | the app's own trace sections are missing; check `atrace_apps` in `assets/perfetto.cfg` names the package |
| `start state not reached` from bench-tap.py | the last round ended somewhere `before` does not return from; add a step that brings the start screen back, and scroll to the top before tapping near it |
| `tapToJsFreeMs` is 0 and `slideMissedMs` is 0 | the trace has no JS thread or the tap missed; check the round's trace and the tap target's bounds |
| Taps and swipes change nothing, but the user's finger works | `adb logcat -d \| grep "Inconsistent event"`: "pointers already down for device DeviceId(-1)" is a stuck injected touch, usually from an Android Studio mirror (`studio.screen.sharing` in `dumpsys display`). Kill the `com.android.tools.screensharing` process and reboot the phone with the user's yes |
| `device-build.sh` says `installed release` but the old build still runs | the APK's package differs from `android.package` (a prebuilt dev variant such as `<package>.dev`): check with `aapt2 dump badging <apk>` and benchmark the package it installs |
| Few or no frames in `actual_frame_timeline_slice` or gfxinfo, yet the screen moved | the app was not in front (Back left it, another app resumed), or the phone's frame timeline is sparse; confirm `topResumedActivity` before each round |
