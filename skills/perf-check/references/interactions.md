# Interactions

`bench.py` opens screens by deep link, so it never sees work that a tap does before navigating:
a filter applied, a store written or a camera moved in the same handler. Those stalls are what users
call "laggy navigation". Benchmark them as interactions with `scripts/bench-tap.py`.

## Config

Each entry in `.perf-check.json` `interactions`:

| Field | Meaning |
| --- | --- |
| `name` | short name for the report |
| `before` | steps that bring the app to the start state every round, run in order |
| `expect` | test id that must be on screen before the tap, or the round stops with exit 1 |
| `tap` | test id to tap; `prefix*` taps ids that start with `prefix` |
| `tapIndex` | which `prefix*` match to tap, from 0 (default 0) |
| `rounds` | traced taps (default 8; the first is often slower) |
| `slideMs` | how long the transition runs (default 500) |
| `traceSeconds` | trace length (default 6) |

A step is one of `{"link": url}`, `{"tap": id}`, `{"scrollTop": swipes}`, `{"scrollDown": swipes}`
(each about 30% of the screen) or `{"key": keycode}`,
each with an optional `"wait"` in seconds (default 3). A tap step also takes `tapIndex`, and
`"optional": true` skips it when the id is not on screen, so one `before` list works from either
end state of the previous round. Test ids are Android `resource-id`s, which
React Native sets from `testID`.

Write `before` so it reaches the start state from wherever the last round ended: after a tap that
leaves screen A, `before` must bring A back. Prefer an in-app tap over a deep link: a link to a
screen already in the stack can push a second copy, and Android back can be consumed by the screen.
Scroll to the top first when the next tap target sits near the top of a long screen.

## Reading the numbers

- `tapToJsFreeMs` is the freeze before anything moves: the end of the JS thread's first busy
  block, merging runs less than 60 ms apart (a press handler can wait on the UI thread before its
  render) and skipping blocks under 10 ms. A tap that changes shared state and
  navigates in one handler shows it as one long JS block (250 ms is typical of a filter rewrite that
  re-renders a map). The frame timeline does not show it: press feedback keeps frames coming.
- `slideMissedMs` is jank the user watches. Anything above a frame or two means work runs during the
  transition: deferred sections mounting early, a camera flight, a store change applied mid-slide.
- `afterMissedMs` is what moved out of the transition. It is felt only if the user scrolls
  straight away; moving cost here from `slideMissedMs` is the usual, intended trade.
- `slideViews` above the screen's first mount means a reveal or a lazy mount fired during the slide.

Compare medians of two builds on the same phone; one round varies by 100 ms or more.

## Pitfalls

- A screen's own "settled" signal can read true on the frame it mounts, before its open animation
  starts (react-native-screen-transitions reports `settled === 1` until the animation flips it), so
  work gated on it runs during the slide. `slideViews` catches this.
- Screen recordings cannot time a tap: `show_touches` dots often do not appear in `screenrecord`,
  and the frame where content starts moving is only half of the measurement. Use the trace.
- When the React profiler cannot attach (no CDP target, a second app on the same Metro, a busy
  host), wrap the screens in a temporary `<Profiler>` in a debug build and log `actualDuration` to
  logcat; for per-component cost, walk the committed fiber tree from
  `__REACT_DEVTOOLS_GLOBAL_HOOK__.onCommitFiberRoot` and sum `selfBaseDuration` of fibers with the
  PerformedWork flag. Remove the probes before measuring a release build.
- Dev-build render times run about 3x release. Use them to find which components render, never to
  report frame numbers.
