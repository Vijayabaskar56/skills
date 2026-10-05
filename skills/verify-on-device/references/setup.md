# Setup

Run `scripts/doctor.sh <ios|android|both>` and fix each `missing` line. Ask the user once before
installing anything.

| Tool | Needed for | Install |
| --- | --- | --- |
| argent | every device action, flows, recording | `npx @swmansion/argent@latest init -y`, then read its `argent-device-interact` skill |
| jq | reading `.verify-on-device.json` | `brew install jq` (macOS 15+ ships it) |
| ffmpeg | frames and crops from recordings | `brew install ffmpeg` |
| Xcode | iOS simulators, `xcrun simctl` | App Store. Install the Xcode named in `ios.simulatorApp` too, if the config sets one |
| adb, emulator | Android | Android Studio's platform-tools and emulator on PATH |
| the Android start tool | booting emulators the project's way | whatever `android.start` names; without it, argent `boot-device` is used |

## Why a second Xcode

Xcode 27 replaces Simulator.app with DeviceHub, and argent cannot drive a simulator shown in a
DeviceHub window. Keep an Xcode 26.x install for its classic Simulator app and point
`ios.simulatorApp` at `/Applications/Xcode-26.x.app/Contents/Developer/Applications/Simulator.app`.
The active toolchain (`xcode-select -p`) can stay on the newer Xcode.
