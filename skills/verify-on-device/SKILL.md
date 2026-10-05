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

For iOS, run `scripts/open-simulator.sh "$(scripts/config.sh .ios.device)"`. It finds the device
by name, boots it if needed, quits DeviceHub (argent cannot drive a simulator shown there), opens
it in `ios.simulatorApp` and prints the UDID.

For Android, start `android.avd` with the config's `android.start` command; with none, use argent
`boot-device`.

**Done when** `open-simulator.sh` exits 0 and `list-devices` shows that UDID `Booted`, or for
Android `list-devices` shows the AVD's serial in state `device`.

## 2. Find a flow that reaches the screen

Run `scripts/find-flows.sh <area>`. Its kind column comes from the config's `flowKinds` globs
(defaults in the script): a `fragment` composes into others via `run:`, `edge-cases` holds
non-happy paths, `stress`, `profile` and `perf` are perf runs, `smoke` is a route sweep, and
`enter` gets you into a scope. A line marked `DEAD` runs one of the config's `deadFlows`; the notes
file says what replaces it. The last line says whether the flows folder is gitignored.

**Done when** you have picked a flow, or the script exits 1 and you go to step 4.

## 3. Run the flow

Call `flow-execute` with `project_root` (the absolute repo root). If `flowsDir` is
`.argent/flows`, pass `name`; otherwise pass `flow_path`, the flow's absolute path, because `name`
reads only `.argent/flows/<name>.yaml`. For a fragment, call `flow-read-prerequisite` with the same
flow source, put the app in that state, then set `prerequisiteAcknowledged: true`.

To record, call `screen-recording-start` before `flow-execute` and `screen-recording-stop` after
it, pass or fail, and keep the `video` path it returns. If start reports a recording already
running, call `screen-recording-stop` first and delete that video with `clean-media.sh`. For a
timing question, start with `trimStatic: false` and `showTouches: false`: trimmed timestamps do not
match the wall clock, and touch markers trip the scene detection in `references/frames.md`.

**Done when** `flow-execute` reports every step passed, or you have the failing step and its error.

## 4. Drive argent by hand when no flow reaches it

Open the screen with argent `open-url` and a deep link from the config's `deepLinks` catalog. If
the app supports `sectionParam`, add it to jump to a section instead of scrolling; a section
without a key gets one before you test it. Then use `describe`, `gesture-*`, `keyboard` and
`await-ui-element`. To test pasting, tap the field, then call argent `paste` with `text`. Use
`xcrun simctl pbcopy <udid>` only to seed the clipboard for an autofill suggestion.

**Done when** the screenshot after the last action shows the changed element in the state under
test.

## 5. Fold the check back into a flow

A check you only ran by hand is a check nobody runs again. Put the happy path into the area's flow,
a non-happy path into the matching `*-edge-cases`, and a shared prefix into a fragment. Read
`references/flow-steps.md` before writing YAML. If `find-flows.sh` printed `gitignored`, say so
when you add a flow.

**Done when** the flow you added or changed passes one full `flow-execute` run.

## 6. Read the result

Checkpoint screenshots are the evidence; open only the frames you need. For a timing question
(flicker, a jump, a dropped frame), pull cropped frames with ffmpeg as `references/frames.md`
shows instead of watching the video.

**Done when** you can name the screenshot or frame that shows the change working, or broken.

## 7. Clean up media

Run `scripts/clean-media.sh <video>...` with every `video` path this run's `screen-recording-stop`
returned. It deletes only those files and refuses, deleting nothing, if any path is outside the
config's `recordingsDir`. Delete frames you wrote to the scratchpad. If you started an Android
emulator, stop it with the config's `android.stop` command.

**Done when** `clean-media.sh` prints `removed N recordings`, or this run recorded nothing.

## Hard rules

- Reach a screen by deep link and a section by its section parameter. Never scroll to find
  something.
- Take tap targets from `describe` or the element tree an action returns; never guess coordinates.
- Use argent for every device action it offers, `paste` included; use `xcrun simctl` only to seed
  the clipboard for autofill and for recovery in `references/troubleshooting.md`.
- Keep `screen-recording-start` and `-stop` outside flows, and stop every recording you start.
- Delete only the recordings this run made, by passing their paths to `clean-media.sh`. Leave
  other recordings and the flows folder alone.

## Report

- Device: platform, name, OS, and UDID or AVD
- Each flow run: its name and the `flow-execute` result, with the failing step if any
- Each hand-driven check: the deep link opened and the argent actions taken
- Recordings made: each `video` path, and the start options if not the defaults
- Screenshots and frames looked at: path and what each shows
- Flows added or changed, noting whether the folder is gitignored
- The `clean-media.sh` output line
- Skipped steps, each with its reason
