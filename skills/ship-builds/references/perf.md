# Performance check

Step 3 profiles a fixed set of argent flows on the iOS simulator, reduces each run to a few
numbers, and compares the medians with the last shipped build. It is scripted end to end through
the argent CLI (`argent run <tool> --json` and `argent flow run`), so no MCP session is needed.

## Config

The step runs only when `.ship-builds.json` has this block:

```json
"perf": {
  "flows": ["perf-dashboard", "perf-property"],
  "baseline": ".argent/perf/baseline.json",
  "thresholdPct": 20,
  "runs": 3,
  "ready": "screen_home",
  "device": "iPhone 17",
  "metroPort": 8081,
  "retries": 2,
  "flowsDir": ".argent/flows"
}
```

| Field | Meaning |
| --- | --- |
| flows | argent flow names under `flowsDir`, each a fragment that starts on the `ready` screen |
| baseline | medians of the last shipped build, written by `perf-measure.sh` |
| thresholdPct | how much a metric may grow before compare fails (default 20) |
| runs | runs per flow; the median is stored (default 3) |
| ready | testID of the first screen after a cold launch; the profiler starts once it shows |
| device | booted simulator name or UDID; empty picks the first booted simulator |
| retries | extra attempts per flow when a run fails (default 2) |

## Before measuring

- Metro is running on `metroPort` and the simulator has a dev build of the app. The profiler
  reads React commits through the DevTools hook, which release builds do not have.
- The app is signed in and past onboarding, so a cold launch lands on `ready`.
- No Xcode or Gradle build is running. A build competes for the same CPU and inflates every
  number, so the script refuses to start while one uses the CPU (`PERF_ALLOW_BUSY=1` overrides
  and marks the output `busyCpu`). Step 3 runs before step 5 for this reason.
- Nobody is editing app source. Metro reloads the app on every save, which ends the profiling
  session and changes the JS under test. The script retries a run that a reload broke and marks
  the output `source.changedDuringRun` when the tree moved.
- The argent CLI resolves: `argent` on PATH, or the npx cache (`npx --no-install @swmansion/argent`).

## What one run does

`scripts/perf-measure.sh` does this for every flow and run. A failed run is discarded and
retried, up to `perf.retries` (default 2) extra attempts per flow, then the script exits 1:

1. `restart-app`, then `await-ui-element` on `ready` (cold start every run, so caches do not carry
   over). Then it terminates every other app on the simulator: a suspended instrumented app
   such as Spotlight makes the flow runner time out reading the UI tree.
2. `react-profiler-start` (Hermes CPU sampling plus React commit capture).
3. `argent flow run <flow> --device <udid>`. A flow must not contain `launch:`: relaunching kills
   the JS runtime and the profiling session with it.
4. `react-profiler-stop`, then `react-profiler-analyze`, which writes the session files and a
   markdown report.
5. `scripts/perf-reduce.mjs` turns stop and analyze output into `metrics.json`.

Raw files for every run stay in `<out>.runs/<timestamp>/<flow>-<n>/`: `flow.json` is the flow
report, `analyze.json` names the markdown report and session files. To dig into a regression,
`profiler-load` that session and use `profiler-commit-query` and `profiler-cpu-query`
(the `argent-react-native-profiler` skill).

## Metrics

| Metric | Source | Noise floor in compare |
| --- | --- | --- |
| commits | React commits in the run | 5 |
| fiberRenders | component renders across all commits | 50 |
| slowCommits | commits of 16 ms or more (one frame) | 2 |
| slowCommitMs | summed duration of those commits | 30 |
| maxCommitMs | longest commit | 10 |
| jsBusyMs | Hermes CPU samples that were not idle | 100 |
| gcMs | samples in the garbage collector | 30 |
| durationMs | wall time of the run; printed, never gated | - |

A metric regresses when it grows by more than `thresholdPct` and by more than its floor. The floor
keeps a 1 to 2 slow-commit wobble from failing a ship. `spread` in the JSON holds each metric's
min and max over the runs; a wide spread means the flow waits on something variable. `topRenders`
counts renders inside slow commits, for reading only.

## When compare fails

1. Re-measure only the failing flows: `scripts/perf-measure.sh <scratch>/recheck.json perf-zone`,
   then compare again. Simulator runs vary by 10 to 15 percent; a regression that does not
   reproduce is noise.
2. If it reproduces, open the markdown report named in the run's `analyze.json` and name the
   component or function behind the slowest commits.
3. Show the table and the finding. Ship only on the user's word.

## Moving the baseline

The baseline is the last shipped build. Step 7 copies the check's output over it after an
upload. To rebuild it by hand, check out the shipped tag's JS (Metro serves the working tree),
run `scripts/perf-measure.sh <baseline>`, and keep the `sha` it records. A baseline measured on a
different simulator model or iOS runtime is not comparable; the `device` field says which.

## Frame stalls (optional, manual)

The profiler sees JS work, not dropped frames on the UI thread or GPU. For a flow whose fix was
about animation or blur, record it with `screen-recording-start` and `-stop` around
`argent flow run`, then read frame stalls with the repo's own tool if it has one (for example
`.argent/tools/stall.sh <video>`). Compare the longest stall against a recording of the baseline
build by eye; it is not part of the gate.

## Limits

- Dev builds run JS about three times slower than release. Compare dev with dev only; the
  absolute numbers are not what users feel.
- The gate catches extra React work: more renders, longer commits, more JS CPU, such as a
  carousel mounting 28 heavy cards or a listener on every text node. It misses native and GPU
  cost (blur layers, hidden WebViews rendering, map tiles), memory, and network latency.
- Live API data changes what a screen renders. A backend change can move numbers with no app
  change; check `spread` and the flow's data before blaming code.
