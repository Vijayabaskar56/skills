# Troubleshooting device runs

Read the exact error first, then find it below. Bundle ids come from
`scripts/config.sh .bundleId.ios`.

## The simulator is in DeviceHub

Symptoms: native devtools fail to start (`Native devtools failed to initialize … launchctl setenv
NATIVE_DEVTOOLS_IOS_CDP_SOCKET`), so a flow's `launch:` steps, `restart-app` and tree reads fail,
and taps land on the wrong thing. The window has DeviceHub's rounded title bar with a single expand
button instead of Home, Screenshot and Rotate buttons.

Cause: Xcode 27 replaces Simulator.app with DeviceHub, and argent cannot drive a simulator shown
there.

Fix: run `scripts/open-simulator.sh "$(scripts/config.sh .ios.device)"` before running any flow. It
quits DeviceHub and reopens the device in the configured Simulator app. If it exits 1 because
DeviceHub is still running, quit DeviceHub from its menu and rerun. If `ios.simulatorApp` is empty,
install an Xcode 26.x and set it (`setup.md`).

## Tree reads time out on Spotlight or WidgetRenderer

Symptom: tree reads time out with `ViewInspector RPC timed out: Application.getState`, and the
error lists `com.apple.Spotlight` or `com.apple.chrono.WidgetRenderer-Default` as connected.

Fix: run `xcrun simctl terminate <udid> <bundleId>` on each listed bundle, then `launch-app` the
app. A flow's `launch:` step can re-instrument Spotlight; if the timeout returns, open the app's
root deep link and run the flow without its `launch:` line.

## "No app is connected to native devtools"

```bash
argent run native-devtools-status --udid <udid> --bundleId "$(scripts/config.sh .bundleId.ios)"
```

If it reports `stale_process`, run `restart-app` again and recheck until `state` is `connected`. It
can take two tries.
