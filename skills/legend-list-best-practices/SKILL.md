---
name: legend-list-best-practices
description: Use when building, auditing or fixing LegendList or @legendapp/list usage in React, React Native or web, or when a list has virtualization, scroll blanking, mount cost, data identity, recycling, row invalidation, measurement, chat anchoring, drawDistance, visibility or performance regression problems. Applies Legend List's own contracts. Not for app-wide slowness outside a list; use argent-react-native-optimization.
---

# Legend List best practices

Apply Legend List's own contracts, not generic prop tuning. When installed source and types differ from the [docs](https://legendapp.com/open-source/list/v3/overview/) or [LLM index](https://legendapp.com/open-source/list/v3/llms.txt), trust the installed code.

## 1. Check the installed surface

- Read the installed version, platform, import, nearby usage, source and tests.
- Import React Native and React Native Web from `@legendapp/list/react-native` and React DOM from `@legendapp/list/react`. SectionList, keyboard, animated and Reanimated have their own entrypoints: `/section-list`, `/keyboard`, `/animated`, `/reanimated`.

**Done when** you can name the installed version, the entrypoint and every file in the row tree.

## 2. Pick the mode and scope

| Request | Do | Report |
| --- | --- | --- |
| Build | Settle keys, invalidation, row ownership, measurement, recycling and validation before writing code | Incidental findings only when they affect correctness |
| Audit or improve | Inspect the list and the complete row tree | Every evidence-backed improvement, sweeping architecture included, ranked by impact and confidence, measured problems apart from risks |
| Fix | Audit first, present a ranked plan, implement the approved scope | Incidental findings only when they affect correctness |
| Unrelated work nearby | Apply the relevant rules within scope | Incidental findings only when they affect correctness |

- If the bug or regression is unclear, reproduce and measure it before changing code.
- If the change is non-trivial, present the plan and wait for approval such as `go`.
- If the best fix needs broad ownership, a new dependency, row, recycling or scroll architecture, or a significant upgrade, stop at concrete options for the user.

**Done when** the mode is named and any non-trivial plan is approved.

## 3. Trace each finding

Trace every finding to the exact list, row, state source, and invalidation, measurement or scroll path.

| Symptom | Separate or inspect |
| --- | --- |
| Blanking | Range and draw-distance work, row commit cost, measurement |
| Slow mount | Data passes, key, type and size callbacks, initial estimates, row cost |
| Jumps or stale state | Identity, cached sizes, anchoring, recycling, remounts |
| Remounts or scroll resets | List and wrapper keys and returned component types before callback identity; behaviour around custom scroll renderers is version-specific |

**Done when** each finding names its list, row, state source and path.

## 4. Apply the contracts

### Identity and invalidation

- Use a stable, unique `keyExtractor`. If items can reorder, prepend, delete or recycle, avoid index keys: bad keys attach cached measurements and recycled state to the wrong item.
- `data` may be an array of keys looked up inside `renderItem`, but it stays an array; Legend List has no lazy data-source contract.
- When replacing the logical dataset and its layout state, change `dataKey`; it re-initializes internally with less overhead than a remount. When mutating the same array in place, change `dataVersion`, and prefer immutable updates when practical.
- Use `itemsAreEqual` only when same-key replacements are semantically unchanged, and cover every field that affects rendering or layout: returning `true` keeps the mounted row on the cheap path and can otherwise leave stale output.
- Use `extraData` only when an outside value intentionally makes every mounted item re-evaluate, including values `overrideItemLayout` reads. Keep it minimal and infrequent.

### Prop stability

- If the parent re-renders, audit every non-primitive list prop: callbacks, component types, configuration and style objects, arrays. Keep each identity stable while its meaning is unchanged, especially `renderItem`, key, type, size, equality and layout callbacks, viewability props, custom scroll renderers, and header, footer and separator components.
- Keep volatile selection, expansion, hover, input, playback and filter state out of list-level props when its only purpose is reaching rows.
- Mounted rows update from item or key changes, `extraData`, or their own state and subscriptions. Latest refs and stable callbacks keep event reads fresh but do not update rendered output.

### Row stability

- Return a named row component with narrow props. Put volatile state in the owning row or an item-scoped selector or subscription. If most rows truly change, use `extraData` honestly.
- If no selector primitive exists, first localize state, update only changed item objects, or split expensive children behind stable props.
- If broad invalidation stays materially expensive, offer item-keyed external state or a selector-capable state library as an architectural option: the project's existing one first, else `@legendapp/state`, disclosing that it shares maintainers with Legend List. State the expected re-render reduction and the migration and dependency cost.
- Inspect the `renderItem` callback, then every component in the returned row tree, recursively. Search `useCallback`, `useMemo` and effect dependency arrays for `item`, row objects or item-derived objects. If a data refresh replaces many item identities, these recreate values, rerun effects, defeat memoized boundaries and fan work across mounted rows. Trace each to its consumer before flagging it.
- Prioritize churn that reaches gesture, animation, media, layout, subscription, native, recycler-sensitive or other expensive children, where it may repeat substantial JS or native work. Fix ownership or stabilize the affected boundary without producing stale UI. Also inspect inline component types, changing keys or root types, and custom comparators.

### Recycling

Prefer `recycleItems={true}` (the default is `false`), especially on React Native, where recycling has the most value.

- For a new list or a requested audit or improvement, inspect the prop and the complete row tree. If it is omitted, enable it when the row is recycling-safe. If it is `false`, first look for behaviour that may rely on remounting when a mounted container receives a different item.
- Check item-dependent local state, refs, uncontrolled inputs, animations and shared values, timers, subscriptions, effects, media and native handles. Flag only what would become stale, leak or attach to the wrong item when the item changes without a remount.
- When reasonably fixable, use `useRecyclingState` for local state that resets with the item key and a stable `useRecyclingEffect` for cleanup or work when the item changes. Keep item-persistent state item-keyed or controlled, and key only the smallest subtree that truly needs a remount. Then enable recycling.
- Scope follows step 2. Within requested and approved scope, make the migration. Otherwise, in an audit or improvement request, recommend the exact changes and expected benefit; if correctness stays unclear or the migration is substantial, explain why `recycleItems={false}` should remain. For unrelated nearby work, leave it unchanged without comment unless the requested change would make it unsafe.

### Measurement and layout

- `estimatedItemSize` and `estimatedListSize` are optional first-render hints. The item estimate defaults to `100` in source (the type comment says `undefined`). Tune it only for materially different rows or better far-target initial offsets.
- Use `getFixedItemSize` only for truly fixed axis sizes and return `undefined` for dynamic items; the value must match wrapper spacing and visual geometry. Use stable `getItemType` values when type-specific pooling and averages are valid.
- Keep viewport sizing such as `flex: 1` on `style`; `contentContainerStyle` is for inner layout.
- For measurements, clear with `clearCaches({ mode: "sizes" })`; use `"full"` only when key, index and position caches are also invalid.
- Tune `drawDistance` (default `250` px) only after row cost and measurement are sound. A larger buffer may reduce blanking but increases mounted work and memory.

### Chat, scroll and visibility

- Prefer `initialScrollAtEnd`, `maintainScrollAtEnd`, `maintainVisibleContentPosition`, `anchoredEndSpace` and the documented keyboard and inset APIs over inverted lists or manual offset compensation. `initialScrollAtEnd` overrides `initialScrollIndex` and `initialScrollOffset`.
- In `maintainVisibleContentPosition`, size stabilization defaults on and data-change anchoring defaults off; `true` enables both. Keep initial placement, data anchoring, end following, composer space and keyboard avoidance as separate contracts.
- If only the leading item matters, use `onFirstVisibleItemChanged`; for broader visibility state, use viewability callbacks or hooks.
- For mixed-size lists, read `getState().start`, `end`, `startBuffered` and `endBuffered` instead of guessing from offsets or row heights.
- Imperative scroll methods are asynchronous. Verify lifecycle timing and layout readiness before declaring a target wrong.

**Done when** every changed or flagged list meets these contracts or the gap is in the report.

## 5. Validate app changes

Validate only behaviour the requested or approved change affects, or that a reported finding needs. On a simulator, use the `verify-on-device` skill.

- Exercise affected interactions with representative app data. For scrolling or blanking, include fast scrolls and large jumps.
- After identity or invalidation changes, verify insert, prepend, reorder, remove, update and dataset replacement as applicable, and confirm rows show the correct data.
- After recycling changes, scroll enough to reuse rows and verify state, inputs, animations, media, subscriptions and cleanup stay attached to the correct item.
- After measurement or anchoring changes, verify initial placement, dynamic size changes, prepend behaviour, end following and imperative targets as applicable.
- Back performance claims with before-and-after render or profiler evidence from the same interaction; the bottleneck is not inferable from `renderItem` alone.

**Done when** each affected behaviour was exercised and any performance claim has before and after evidence.

## 6. Escalate a library bug

If a focused reproduction or source trace shows correct app usage still fails inside Legend List, follow `references/library-bug.md`. Skip release archaeology for routine builds and audits.

**Done when** any upgrade recommendation cites release evidence or a focused reproduction.

## Hard rules

- Give each list either `data` plus `renderItem` or children, one mode only.
- Implement only requested and approved scope. Before substituting a smaller partial workaround, get approval and state what it would leave unresolved.
- Add a dependency, `@legendapp/state` included, only with approval.
- Signal updates through item changes, `dataKey`, `dataVersion` or `extraData`. A changing React `key` on the list or wrapper remounts the subtree and discards state and caches, and `renderItem` identity is not an invalidation signal.
- Keep every Hook dependency, and let `data`, `extraData` and any prop whose change is a real update signal change.
- Keep `extraData` rather than replacing it with a broad changing context read.
- Clear caches only after proving them stale.

## Report

- Installed version and entrypoint checked
- Each finding with its list, row, state source and path, ranked by impact and confidence, marked measured or risk
- Plan and approval, or the options offered when stopped at step 2
- Files changed, interactions exercised, and before and after profiler evidence for performance claims
- Rules left unapplied, each with its reason (for example `recycleItems={false}` kept)
