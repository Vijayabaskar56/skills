# Flow steps that hold up

Read before writing or editing a flow in the config's `flowsDir`.

- Directives (`tap`, `await`, `assert`, `type`) resolve the full native hierarchy, so an `id` works
  even where `describe` collapses it. Prefer them to raw `tool: gesture-tap` coordinates.
- A text field's contents are not in the directive tree. `assert: { text: { in: … } }` reads the
  accessibility label. To assert what a field displays, use the raw tool, which sees the AX value.
  A failed condition stops the run, so it works as an assertion:

  ```yaml
  - tool: await-ui-element
    args:
      condition: text
      selector: { identifier: phone_input }
      expectedText: "Phone number 555 0100" # label and value, joined by a space
      textMatch: equals
  ```

- Persisted app state (Zustand, MMKV, AsyncStorage) survives a relaunch, so fields arrive prefilled. Clear them with a
  `run-sequence` of backspaces before typing, and reuse that block through a YAML anchor
  (`- &clear` … `- *clear`).
- Gate every transition with `await:`. Add `wait: 250` after focusing a field, because a cold
  keyboard drops characters. Type with `delayMs` around 90. An OTP field may need about 250.
- Disabled state is not in the tree. Assert it by behaviour: tap Continue, then
  `assert: { visible: { id: screen_… } }` to prove nothing navigated.
- Keep `screen-recording-start` and `-stop` out of flows. A failing step skips the stop and wedges
  the next run. Record around `flow-execute` from outside.
- Skip `snapshot:` baselines on screens with a live map or other pixels that change between runs.
