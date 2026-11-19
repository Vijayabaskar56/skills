---
name: no-use-effect
description: Use when writing, editing, reviewing, fixing or refactoring any React or React Native component, or when useEffect, side effects, data fetching, state sync or component lifecycle come up. Always active. Replaces direct useEffect with derived state, handlers, useMemo, useSyncExternalStore, TanStack Query, key resets, callback refs or useMountEffect. Not for writing the API call or query hook itself; use native-data-fetching.
---

# No direct useEffect

Components never import or call `useEffect`. A direct `useEffect` lives only inside a reusable
custom hook: `useMountEffect` itself, or a `useData`-style hook when no fetching library fits.
Root `AGENTS.md` states the same rule. `references/patterns.md` has a worked bad/good example for
every row below; open it when the one-line answer is not enough.

## Pick the replacement

Before writing an effect, find your situation in this table and write the right-hand column.

| If you are about to... | Write instead |
| --- | --- |
| Write `useEffect(() => setX(f(y)), [y])`, or keep state that mirrors other state or props | Compute it during render: `const x = f(y)`. Wrap in `useMemo` only if it takes over 1ms on a throttled CPU (measure with `console.time`). |
| Chain effects that set state that triggers the next effect | Derive what you can inline and do every update in the one event handler. |
| `fetch()` then `setState()`, or reimplement caching, retries or cancellation | A TanStack Query hook from `lib/api/hooks`. On React 19+, `use(promise)` inside `<Suspense>` also works. |
| Set a state flag so an effect does the real work ("set flag, effect runs, reset flag") | Do the work in the event handler. Procedural logic (validate, transform, submit) belongs there. Share logic between handlers with a plain function. |
| Call `onChange` or a parent callback from an effect | Update local state and call the parent in the same handler, or make the component fully controlled (preferred). If the child fetched the data, let the parent own the fetch and pass data down. |
| Subscribe to an external store or browser/device API by hand | `useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)`, wrapped in a custom hook. |
| Reset local state when an id or prop changes | Put `key={id}` on the component so it remounts fresh. This covers form fields and selections. |
| Adjust part of the state when a prop changes | Derive it during render (e.g. `items.find(...) ?? null`). If you cannot, compare with a `prevItems` state value and set state during render. |
| Guard an effect on a condition (`if (!isLoading) play()`) | Mount conditionally: the parent renders the child only when ready, and the child uses `useMountEffect`. |
| Measure, focus or initialise something when a node mounts | A callback ref (`useCallback((node) => ...)`). On React 19+ it can return a cleanup. |
| Run app initialisation once | Module-level code, or a module-level `didInit` guard inside `useMountEffect`. |
| Read the latest prop or state inside an effect without re-running it | `useEffectEvent`, inside a custom hook. |
| Add `hasRun.current`, `isMounted.current` or a latest-callback ref to control when an effect runs | Delete the ref and the effect, then pick the row above that fits. Strict Mode double-firing exists to surface missing cleanup; fix the effect so it survives a remount. |
| Set up and tear down an external system once per mount (DOM or native view integration, third-party widget, browser or device API subscription, "shown" analytics) | `useMountEffect`, below. |

## Use the escape hatch

`useMountEffect` is the only effect a component may call. Import it from the project hook:

```tsx
import { useMountEffect } from "@/hooks/use-mount-effect";

useMountEffect(() => {
  const subscription = subscribeToSomething();
  return () => subscription.remove();
});
```

- If the work happens because the component appeared (mount analytics, a widget, a
  subscription), use `useMountEffect`.
- If it happens because the user did something (submit, tap, navigate), put it in that handler.
- If it must restart when a value changes, give the component `key={value}` and keep
  `useMountEffect`; do not add dependencies.
- If `ref.current` may be null at mount because the node renders conditionally, use a callback
  ref instead.

A `useMountEffect` bug is loud: it ran once or not at all. A dependency-array bug shows up later
as flicker, loops or stale data. Choose the bug that is easy to find.

## Write a custom hook when nothing fits

If no row fits and you still need `useEffect`, write a named `use*` hook in `hooks/` (or beside
its only caller) that owns the effect and exposes a clean return value.

- Give every async effect a cleanup: a local `let ignore = false` set to `true` in the cleanup,
  never an `isMounted` ref.
- Keep any ref workaround (latest callback, React <19 callback-ref cleanup) inside the hook.
- If it fetches and TanStack Query cannot serve it, follow the `useData` example in
  `references/patterns.md`.

## Check your work

Run `npm run lint`. The `anti-slop/no-direct-use-effect` rule (`.oxlintrc.json`) fails on any
`useEffect` call outside a custom hook, including a hook defined inside a component.

## Hard rules

- Call `useEffect` only inside a named custom hook; in components, use a row above or
  `useMountEffect`.
- Import `useMountEffect` from `@/hooks/use-mount-effect`.
- Fetch through TanStack Query hooks in `lib/api/hooks`.
- Fix a misbehaving effect by removing it; never add a ref to stop double-firing, loops or stale
  reads.
- Run `npm run lint` before calling component work done.
