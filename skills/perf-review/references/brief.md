# Area agent brief

Send this text to each area agent, with every `<...>` filled. Send it unchanged apart from the
fill-ins, so findings from different agents compare. The primitives agent gets the same brief with
`<area>` set to "shared primitives" and `<files>` set to the widest-reach list from
`diff-areas.sh`, plus any changed text component, press wrapper, list wrapper, provider or root
layout.

---

Performance regression review, read-only. Edit no files and run nothing that writes.

Repo: `<repo path>`. Stack: `<framework, platform, and the libraries that matter for frames, read
from package.json: animation, list, image, navigation, styling, state>`.
Range: `<base>..<head>` (`<how it was resolved>`). Only these files are yours: `<area>`:

```
<the area's lines from diff-areas.sh>
```

Diff with `git diff <base> <head> -- <path>`. Read files as shipped with `git show <head>:<path>`;
the working tree may differ, and `<head>` is what users run. Follow an import out of your area only
to learn what a changed call costs.

Earlier perf fixes this range could undo (read the ones that touch your area with
`git show <sha>`): `<perf commits from diff-areas.sh, plus any the user named>`.

Already found, so do not re-report; say if your area makes one worse: `<lead's list, or none>`.

Repo rules that bear on performance (list wrappers, animation rules, lint): `<lines from
AGENTS.md or CLAUDE.md, or none>`.

## What to look for

Report only what the range added or made worse. For each class, the React Native and web forms:

1. **Per-instance hooks and listeners in hot primitives.** A text, icon, button, row or card
   component that each instance subscribes to something.
   - RN: `useWindowDimensions`, `Dimensions.addEventListener`, `AppState`, `Keyboard`,
     `useColorScheme`, accessibility or font-scale listeners, a store selector per instance.
   - Web: `resize`, `scroll` or `matchMedia` listeners, a `ResizeObserver` or
     `IntersectionObserver` per item, `useMediaQuery` in a leaf.
   - Seen: a text-size cap hook added a window-size listener to every text node on every screen.
2. **Unvirtualised lists.** A long or growing sequence rendered all at once.
   - RN: `ScrollView` plus `.map`, a `FlatList` or list wrapper that lost `recycleItems`,
     `estimatedItemSize`, `getItemLayout` or a stable `keyExtractor`; index keys; a `key` change
     that remounts the whole list; `extraData` that changes every render.
   - Web: `.map` over a large array with no windowing (react-window, TanStack Virtual, Virtuoso),
     index keys on reorderable rows, `content-visibility` removed.
   - Seen: a new 28-card carousel rendered through a scroll view, all cards mounted at once.
3. **Heavy per-item effects.** Cost multiplied by the item count.
   - RN: `BlurView`, `MaskedView`, SVG paths or gradients, Skia canvases, Android `elevation` and
     shadows, one of these per card or several stacked on one card.
   - Web: `backdrop-filter`, `filter: blur`, large `box-shadow`, `mask-image`, big inline SVGs,
     `will-change` left on many elements.
   - Seen: each video card stacked eight full-size blur layers where one downscaled layer did.
4. **Full-resolution images.** Decoding more pixels than the box shows.
   - RN: remote images with no width and height or no resized source, no `recyclingKey` in a
     recycled list, `cachePolicy` removed, a large local asset in a thumbnail.
   - Web: no `srcset` and `sizes`, no `width` and `height`, `loading="lazy"` missing below the
     fold, a framework image component bypassed.
5. **Hidden heavy views mounting early or off-screen.** Paying for something the user cannot see.
   - RN: a `WebView`, video player, YouTube player or `MapView` inside a closed sheet, hidden tab,
     unfocused screen or a warm-up timer; mounting during a navigation transition.
   - Web: an `iframe` embed, `<video preload="auto">`, or map library initialised in a hidden tab,
     closed dialog or below the fold without lazy loading.
   - Seen: web document sheets warmed up 1.4 s after every page open, before anyone opened one.
6. **Animations during transitions, or looping forever.**
   - RN: `withRepeat(..., -1)`, Lottie `loop`, count-ups or digit rolls, animations that start
     while a screen transition, sheet open or map flight is running, animations keyed on unstable
     deps so they restart every render.
   - Web: CSS `infinite` animations, a `requestAnimationFrame` loop with no stop, animating
     `width`, `height`, `top` or `left` instead of `transform` and `opacity`, layout animations
     across many items.
   - Seen: gauge arcs and rolling digits animated while the map was still flying to the area.
7. **State updates on scroll or animation frames.** A React render per frame.
   - RN: `onScroll` calling `setState`, `runOnJS` or `scheduleOnRN` per frame,
     `useAnimatedReaction` calling back to JS, reading a shared value's `.value` in render.
   - Web: `setState` in `scroll`, `pointermove` or `wheel` handlers without throttling, layout reads
     after writes in one frame (forced reflow), non-passive scroll listeners.
8. **Wide context and store re-renders.** One change re-rendering a whole screen or app.
   - Both: a provider value object or function recreated every render; a context that mixes fast
     state (visibility, progress) with stable actions; a store selector returning a new object or
     the whole store; state hoisted to a root that only one leaf reads; `React.memo` or
     `useMemo` removed from a hot component; new inline objects or functions passed to a memoised
     child or a list's `renderItem`.
   - Seen: a toast hook exposed a context that changed on every toast, so each show or hide
     re-rendered every screen that could show one.
9. **Work in render.** Per item or per frame: `StyleSheet.flatten`, sorting, regex, date
   formatting, JSON parsing, building large arrays; `onLayout` that sets state and re-lays out.
10. **Undone earlier perf fixes.** A change that reverts, bypasses or duplicates around one of the
    perf commits listed above.

## Severity and reach

- Severity: **high** drops frames during a gesture, scroll, transition or animation the user is
  watching; **medium** is a one-off stall on mount, open or navigation; **low** is extra work
  unlikely to be seen.
- Reach: **wide** runs on most screens or every instance of a primitive; **screen** runs on one main
  screen or flow; **narrow** runs on a rare path.

## Return

Under 600 words. Findings ranked by severity, then reach, each as:

```
- [likely cause | minor] <cause in one line>
  file:line at <head>; diff: "<quoted added or removed line>"
  cost: <which thread, what triggers it, how often>
  felt: <screen and gesture>
  severity x reach: <high|medium|low> x <wide|screen|narrow>; confidence: <high|medium|low>
  fix: <smallest concrete change>; trade-off: <what the fix costs or changes>
```

Any claim that lint, a config or a wrapper already enforces or prevents something names the rule
and its file:line. If the area looks clean, say so in one line and name what you checked.
