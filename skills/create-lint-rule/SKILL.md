---
name: create-lint-rule
description: Use when adding a guardrail to the shadcn-x lint plugin (src/lint/), or when the user asks to "ban" or "enforce" an on-system pattern. Encodes the full process — name the goal, enumerate every form the bad pattern takes, find a mechanical signal for exceptions, then write the rule + tests.
---

# Create a shadcn-x Lint Rule

shadcn-x's lint plugin (`src/lint/`) is the **escape-hatch fence**: it makes
off-system code inexpressible. A rule here is an _opinion enforcer_, not a
syntax checker. The work is in the thinking before the code — steps 1–4 are
the front-loaded design discipline, and a rule that skips them ships as a sieve.

Rules are authored with oxlint's `createOnce` API and run under both oxlint
(primary/fast) and ESLint (the hedge, and the path into consumer repos).

Read first (once per session): `src/lint/index.ts` (registration),
`src/lint/rule-kit.ts` (`perFileOption` / `findAncestor` / `matchesSource`),
and one existing rule end-to-end. The two idiomatic shapes are:

- **`no-raw-design-values.ts`** — ban a raw literal form, allow a token form.
- **`no-raw-html.ts`** — ban a tag, allow when a primitive covers it.

Worked example of the full design arc (including the wrong turns):
`src/lint/rules/no-manual-overflow.ts` + `tests/lint/no-manual-overflow.test.ts`.

## Checklist (make a TodoWrite item per step)

### 1. State the goal in one sentence

If you can't, the rule isn't ready. "Use `<ScrollArea>` instead of manual
overflow." Not "discourage overflow in some places."

**Completion criterion:** the goal fits in one sentence and names the
replacement, not just the ban.

### 2. Read the reference BEFORE designing

This is the step that kills premature rules. Before deciding what to ban, find
out how the canonical source treats the pattern:

- The Base UI source lives at `references/base-ui/` (symlinked). Read the
  primitive that owns the behavior. Does it force consumers to set the
  property? (Base UI's `Popup` forces `overflowY: auto` on consumers — so
  banning it would fight the framework.)
- The shadcn/coss reference: `references/ui`, `references/coss`.
- The StyleX docs: `docs/stylex-docs/` — does StyleX already classify the
  property (e.g. `overflow` is a "layout-changing" key in
  `StyleXStylesWithout`), or offer a tokenization hook (`defineConsts`)?

If the reference reveals the bad pattern is actually the canonical API, stop
and reconsider — the rule may need a tokenization opt-in (step 3) rather than
a blanket ban, or it may be a bad fit for a rule entirely.

**Completion criterion:** you can cite, with file path + line, where the
canonical source either endorses or rejects the pattern.

### 3. Enumerate EVERY form the bad pattern takes

Coverage is the difference between a fence and a sieve. List every syntactic
shape before writing visitors. For `overflow` it was three:

1. `stylex.create({ root: { overflow: "auto" } })` — `Property` inside a
   `CallExpression`
2. `<Foo sx={{ overflow: "auto" }}>` — `Property` inside a `JSXAttribute`
3. `<Box overflow="auto">` — a `JSXAttribute` directly

Each form becomes a visitor. Miss one and the rule is a false sense of safety.

**Completion criterion:** the list is exhaustive — you've grepped the
codebase AND the reference for the pattern and accounted for each shape.

### 4. Find a MECHANICAL signal for every exception

This is the hardest step and where most rules die. An exception needs a
_machine-detectable_ signal, not a vibe.

- ❌ "Base UI menus that need native overflow" — not detectable; would require
  data-flow analysis (trace which stylex key lands on which JSX element).
- ✅ "Values that resolve to a `defineConsts`/`defineVars` named export" —
  detectable (member expression, not a string literal), and the import name
  documents intent at the call site.

This is the rule idiom — **ban** / **allow** / **gate**:

```
ban:    a raw literal form        (hex string, physical property, 'auto')
allow:  a tokenized/named form    (token, logical property, scroll.auto)
gate:   a narrow carve-out        (defineVariants, scroll-area.tsx via context.filename)
```

The preferred `allow` is **tokenization opt-in**: ban the raw literal, allow the
named form — mirroring `no-raw-design-values` (raw hex bad, token good) so "I
need this deliberately" is a traceable declaration, not a stray string. Reach
for tokenization before structural detection.

**Key on structure, never on identifiers.** Names are conventions, not
contracts — the `content` key meant a CSS pseudo-element in one component and a
slot in another. Detect on AST node type, ancestor chain, or value form, so a
rename can't slip past the fence.

If your exception has no positive, structural signal, you don't have a rule
yet — ship a `warn` or rely on `StyleXStylesWithout`-style type guards + code
review. A false-positive-prone rule erodes trust in every other rule.

**Completion criterion:** every exception has a detector expressible as an
AST predicate, OR you've documented why a rule is the wrong tool.

### 5. Write the rule

File: `src/lint/rules/<rule-name>.ts`. Follow the established anatomy:

- `defineRule({ meta, createOnce })` from `@oxlint/plugins`.
- `meta.docs.description` — one sentence, names the replacement.
- `meta.messages` — template with `{{placeholders}}`.
- `meta.schema` — JSON Schema if the rule takes options.
- `createOnce(context)` returns a visitor object with a `before()` hook when
  you need per-file option resolution.
- Use `perFileOption(context, defaults)` from `rule-kit.ts` for options —
  `context.options` is `null` at `createOnce` setup time, only populated
  per-file. Read `context.filename` inside `before()` or a visitor, never at
  `createOnce` top level (it throws there).

Helpers in `rule-kit.ts`:
- `findAncestor(node, predicate, stopWhen?)` — walk parents; the `stopWhen`
  arg prevents the walk escaping a boundary (e.g. stop at `JSXElement` so a
  literal in JSX _children_ isn't mistaken for one in a JSX _attribute_).
- `matchesSource(value, sources)` — import-path matching.

Available visitors include `JSXAttribute`, `JSXOpeningElement`, `Property`,
`Literal`, `ImportDeclaration` — see existing rules for the idioms.

**Completion criterion:** `bunx oxlint --type-aware src tests` runs the rule
with no plugin-load errors.

### 6. Register + enable

Edit `src/lint/index.ts`:
- Import the rule.
- Add to the `rules` object inside `definePlugin({...})`.
- Add to the `recommended` config: `"shadcn-x/<rule-name>": "error"`.

Edit `oxlint.config.ts`: add `"shadcn-x/<rule-name>": "error"` (or `"warn"`
while migrating) under `rules`.

**Completion criterion:** the rule is enabled at `error` (or deliberately
`warn`) in both configs.

### 7. Write tests

File: `tests/lint/<rule-name>.test.ts`. Use the ESLint `RuleTester` pattern
(see `tests/lint/no-manual-overflow.test.ts`):

- `new RuleTester({ languageOptions: { parser: tsParser, parserOptions: { ecmaFeatures: { jsx: true } } } })`
- `ruleTester.run(name, plugin.rules["<rule-name>"] as never, { valid, invalid })`
  at the **top level of a `describe`** — never inside an `it()`
  (`ruleTester.run` is suite-scoped).
- Cover every visitor (one invalid case per form from step 3).
- Cover every allowed value / context (one valid case each).
- Cover false-positive traps: plain object literals that aren't CSS,
  computed keys, names that look like the target but aren't.

**Completion criterion:** `bunx vitest run tests/lint/<rule-name>.test.ts`
passes, and the test file has at least one invalid case per form enumerated
in step 3.

### 8. Fix the existing violations

Run `bunx oxlint --type-aware src tests 2>&1 | grep "<rule-name>"` to find
every site the rule now flags. Each violation is either:

- **Real debt** → migrate to the replacement (e.g. wrap in `<ScrollArea>`,
  swap to a token). Verify with the full `Verify` block before moving on.
- **Legitimate exception** → opt into the escape hatch (e.g. use the
  `scroll.auto` token, or add `// oxlint-disable-next-line shadcn-x/<rule-name>
  -- <reason>` with a justification that cites the framework constraint).

Avoid file-level allow-lists in the rule config — they hide debt and silently
exempt _new_ violations in those files. Inline disables or tokens keep the
justification visible at the site.

**Completion criterion:** `bunx oxlint --type-aware src tests` reports **zero**
violations from the new rule.

### 9. Verify (all must pass)

```sh
bunx tsc --noEmit
bunx oxlint --type-aware src tests   # exit 0; warnings ok
bunx knip --use-tsconfig-files       # exit 0
bunx vitest run                      # all green
```

### 10. Update `AGENTS.md`

Add the rule to the "On-system rules" list with a one-line description, so
the next agent knows the fence exists.
