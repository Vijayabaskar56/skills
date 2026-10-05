# Rule idioms for shadcn-x lint rules

Background for steps 3 to 7 of the skill. Paths are relative to the shadcn-x root.

## Two shapes to copy

- `src/lint/rules/no-raw-design-values.ts`: bans a raw literal form and allows the token form.
- `src/lint/rules/no-raw-html.ts`: bans a host tag and allows it where no primitive covers it.

The full design arc, including wrong turns, is `src/lint/rules/no-manual-overflow.ts` with
`tests/lint/no-manual-overflow.test.ts`.

## Forms: the no-manual-overflow example

The scrollable-overflow pattern takes three forms, carried by two visitors:

1. `stylex.create({ root: { overflow: "auto" } })`: a `Property` inside a `CallExpression`
   whose callee is `*.create`.
2. `<Foo sx={{ overflow: "auto" }} />`: a `Property` inside a `JSXAttribute`.
3. `<Box overflow="auto" />`: a `JSXAttribute` whose name is the property.

A form with no visitor is a hole in the fence: the rule passes code it was written to stop.

## Ban, allow, gate

```
ban:    a raw literal form        (hex string, physical property, 'auto')
allow:  a tokenized or named form (token, logical property, scroll.auto)
gate:   a narrow carve-out        (defineVariants, scroll-area.tsx via context.filename)
```

Prefer a tokenized opt-in for `allow`: ban the raw literal and accept a member of a
`stylex.defineConsts` or `stylex.defineVars` export, the way `no-raw-design-values` rejects raw
hex and accepts a token. The import then records the deliberate choice at the call site. In
`no-manual-overflow`, `overflowY: scroll.auto` passes because the value is a `MemberExpression`,
not a string `Literal`; `scroll` is defined in `src/styles/tokens.stylex.ts`.

An exception like "Base UI menus that need native overflow" has no signal: detecting it would
mean tracing which StyleX key lands on which element. "The value is a `defineConsts` member" is a
signal. When no signal exists, ship at `warn` or fence the prop type with `StyleXStylesWithout`
(`docs/stylex-docs/api/types/StyleXStylesWithout.mdx`) and rely on review. A rule that flags
legitimate code teaches people to disable rules.

## Key on structure

Names are conventions, not contracts: one key name can mean a CSS pseudo-element in one component
and a slot in another. Detect on node type, the ancestor chain, or the value form, so a rename
cannot slip past the rule and an unrelated key with the same name is not flagged.

## Rule anatomy and helpers

- `defineRule({ meta, createOnce })` from `@oxlint/plugins`. `src/lint/index.ts` wraps the plugin
  in `eslintCompatPlugin`, so the same rule runs under oxlint and ESLint.
- `createOnce(context)` runs once per rule, not per file. `context.options` is `null` there, and
  `context.filename` belongs to a file, so read both inside `before()` or a visitor.
- `src/lint/rule-kit.ts` exports:
  - `perFileOption(context, defaults)`: call `option.before()` in the rule's `before()` hook, then
    read `option.current` in visitors.
  - `findAncestor(node, predicate, stopWhen?)`: walk `node.parent`. `stopWhen` cuts the walk at a
    boundary, for example stop at `JSXElement` so a literal in JSX children is not mistaken for
    one inside a JSX attribute.
  - `matchesSource(value, sources)`: import-path matching, where `"pkg"` matches `"pkg/sub"`.
- Common visitors: `JSXAttribute`, `JSXOpeningElement`, `Property`, `Literal`,
  `ImportDeclaration`, `CallExpression`. Grep `src/lint/rules/` for one before inventing a shape.

## Tests

The setup in `tests/lint/no-manual-overflow.test.ts`:

- `new RuleTester({ languageOptions: { parser: tsParser, parserOptions: { ecmaFeatures: { jsx: true } } } })`
- `const rule = plugin.rules["<rule-name>"] as never`, with `plugin` from `@/lint/index`.
- `ruleTester.run(name, rule, { valid, invalid })` directly inside `describe(...)`. RuleTester
  registers its own suites, so it must not run inside an `it()`.

False-positive traps worth a valid case each: a plain object literal that is not CSS, a computed
key, a name that looks like the target but is not, and the token form of the value.

## Fixing violations

Each existing site is real debt (migrate it to the replacement) or a legitimate exception (use
the token, or an inline `// oxlint-disable-next-line shadcn-x/<rule-name> -- <reason>` that cites
the framework constraint). A file-level allow-list in `oxlint.config.ts` also exempts every new
violation in that file and hides the reason, so keep exceptions at the site.
