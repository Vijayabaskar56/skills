---
name: verify-on-device
description: Use when a change alters what a React Native app renders, or when asked to check, test or QA a screen on a simulator or emulator. Verifies it with argent - reuse or write a saved flow, drive the app by deep link when no flow reaches it, read recordings with ffmpeg, and clean up media. Not for a saved regression test from acceptance criteria; use argent-qa-flows.
argument-hint: "screen or area to verify, e.g. settings profile section"
---

# Verify on device

Typecheck and lint prove the code compiles, not that the screen is right. Project facts (bundle
ids, deep link scheme, flows folder, devices) live in the repo's `.verify-on-device.json` and the
notes file it names; the repo's AGENTS.md wins over this file. Scripts are in this skill's
`scripts/`; `scripts/config.sh <jq path>` reads one config value. If an argent call fails, read the
exact error and follow `references/troubleshooting.md`.

## 0. Check setup

Run `scripts/doctor.sh <ios|android|both>`. If the config is missing, follow
`references/first-run.md`. Fix other `missing` lines with `references/setup.md`, asking once
before installing anything.

**Done when** doctor exits 0 and the argent MCP tools answer.

## 1. Open the device

For iOS, boot `ios.device`. If the config sets `ios.simulatorApp`, open the device in that
Simulator app, because argent cannot drive a simulator shown in Xcode 27's DeviceHub:

```bash
osascript -e 'quit app "DeviceHub"'
open -a "$(scripts/config.sh .ios.simulatorApp)" --args -CurrentDeviceUDID <udid>
```

For Android, start `android.avd` with the config's `android.start` command; with none, use argent
`boot-device`.

**Done when** `list-devices` shows the device running, and an iOS window has Home, Screenshot and
Rotate buttons rather than DeviceHub's single expand button.

## 2. Find a flow that reaches the screen

Run `scripts/find-flows.sh <area>`. The name says what a flow is: `*-fragment` composes into
others via `run:`, `*-edge-cases` holds non-happy paths, `*-stress` and `*-profile` are perf runs,
`*-smoke` is a route sweep, and `enter-*` gets you into a scope. A line marked `DEAD` runs one of
the config's `deadFlows`; the notes file says what replaces it.

**Done when** you have picked a flow, or the script exits 1 and you go to step 4.

## 3. Run the flow

Run it with `flow-execute`. A fragment also needs `prerequisiteAcknowledged: true`. To record, call
`screen-recording-start` before `flow-execute` and `screen-recording-stop` after it, pass or fail.

**Done when** `flow-execute` reports every step passed, or you have the failing step and its error.

## 4. Drive argent by hand when no flow reaches it

Open the screen with argent `open-url` and a deep link from the config's `deepLinks` catalog. If
the app supports `sectionParam`, add it to jump to a section instead of scrolling; a section
without a key gets one before you test it. Then use `describe`, `gesture-*`, `keyboard` and
`await-ui-element`.

Two checks need `xcrun simctl`, because argent has no equivalent: clipboard paste and autofill
(`xcrun simctl pbcopy <udid>` first), and recovery in `references/troubleshooting.md`.

**Done when** the screenshot after the last action shows the changed element in the state under
test.

## 5. Fold the check back into a flow

A check you only ran by hand is a check nobody runs again. Put the happy path into the area's flow,
a non-happy path into the matching `*-edge-cases`, and a shared prefix into a fragment. Read
`references/flow-steps.md` before writing YAML. If the flows folder is gitignored, say so when you
add a flow.

**Done when** the flow you added or changed passes one full `flow-execute` run.

## 6. Read the result

Checkpoint screenshots are the evidence; open only the frames you need. For a timing question
(flicker, a jump, a dropped frame), pull cropped frames with ffmpeg as `references/frames.md`
shows instead of watching the video.

**Done when** you can name the screenshot or frame that shows the change working, or broken.

## 7. Clean up media

Run `scripts/clean-media.sh` to empty the recordings folder, and delete frames you wrote to the
scratchpad. If you started an Android emulator, stop it with the config's `android.stop` command.

**Done when** `clean-media.sh` prints `removed N entries` or `nothing to clean`.

## Hard rules

- Reach a screen by deep link and a section by its section parameter. Never scroll to find
  something.
- Take tap targets from `describe` or the element tree an action returns; never guess coordinates.
- Use argent for every device action it offers; use `xcrun simctl` only for clipboard and recovery.
- Keep `screen-recording-start` and `-stop` outside flows, and stop every recording you start.
- Delete only media in cleanup; leave the flows folder alone.

## Report

- Device: platform, name, OS, and UDID or AVD
- Each flow run: its name and the `flow-execute` result, with the failing step if any
- Each hand-driven check: the deep link opened and the argent actions taken
- Screenshots and frames looked at: path and what each shows
- Flows added or changed, noting whether the folder is gitignored
- The `clean-media.sh` output line
- Skipped steps, each with its reason
