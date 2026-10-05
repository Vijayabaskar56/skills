---
name: create-lint-rule
description: Use when adding or changing a rule in the shadcn-x lint plugin (src/lint/), or when asked to ban or enforce an on-system pattern in shadcn-x. Takes the rule from goal and reference check through every form, mechanical exceptions, code, registration, tests and AGENTS.md. Not for adding a component or its raw-HTML guardrail; use create-component.
argument-hint: "pattern to ban or enforce, or the rule name to change"
---

# Create a shadcn-x lint rule

This skill is written for one repo, the public shadcn-x component library, and names its paths and
rules on purpose. It does not apply to other lint setups. Run every command and script from the
shadcn-x root; the scripts live in this skill's `scripts/` folder. The shadcn-x `AGENTS.md`
overrides this file where they disagree.

The plugin in `src/lint/` keeps app code on-system: a rule bans an off-system form and names the
replacement. Steps 1 to 4 are design and decide whether a rule should exist at all; skipping them
ships a rule that misses forms or flags legitimate code. Read `references/rule-idioms.md` the first
time you use this skill. Track each step as a todo.

## 0. Check setup

Run `scripts/doctor.sh`. Fix each `missing` line with `references/setup.md`, asking once before
running `bun install` or creating symlinks.

**Done when** doctor exits 0.

## 1. State the goal in one sentence

Write the goal as a ban plus its replacement: "Use `<ScrollArea>` instead of manual overflow", not
"discourage overflow in some places". If it does not fit one sentence, the rule is not ready.

**Done when** the sentence names both the banned form and the replacement.

## 2. Read the reference before designing

Find out how the canonical sources treat the pattern before deciding what to ban:

- Base UI source at `references/base-ui/packages/react/src/`: read the primitive that owns the
  behavior. Example: Select's popup and list apply `overflowY: 'auto'` inline through
  `LIST_FUNCTIONAL_STYLES` in `select/popup/utils.ts`, so a blanket overflow ban fights Select.
  shadcn-x answered with the `scroll` constants in `src/styles/tokens.stylex.ts`.
- shadcn/ui and coss at `references/ui` and `references/coss`.
- StyleX docs at `docs/stylex-docs/`: check for a type-level fence or a tokenization hook. Example:
  `learn/static-types.mdx` shows a user-written `NoLayout` type, built with `StyleXStylesWithout`,
  that omits `overflow`; StyleX itself does not classify the key. `api/javascript/defineConsts.mdx`
  is the tokenization hook.

If the reference shows the banned form is the canonical API, plan a tokenized opt-in (step 4) or
drop the rule.

**Done when** you can cite a file and line where a canonical source endorses or rejects the pattern.

## 3. Enumerate every form the bad pattern takes

Grep `src`, `tests` and `references/base-ui` for the pattern, then list each syntactic shape with
one code example and the AST node that carries it. `references/rule-idioms.md` shows the three
forms `no-manual-overflow` covers. Each form becomes a visitor.

**Done when** the written list has an example per form and every grep hit maps to a listed form.

## 4. Find a mechanical signal for every exception

Each exception needs an AST predicate: node type, ancestor chain, value form, import source, or
`context.filename`. Prefer a tokenized opt-in (ban the raw literal, allow a `defineConsts` or
`defineVars` member) over structural detection. `references/rule-idioms.md` has the ban, allow and
gate idiom.

If an exception has no such signal, stop: ship the rule at `warn`, or use a `StyleXStylesWithout`
type plus review, and say why in the report.

**Done when** each exception is written down as an AST predicate, or the report states why a rule
is the wrong tool.

## 5. Write or update the rule

Read `src/lint/index.ts`, `src/lint/rule-kit.ts` and one existing rule end to end first. If
`src/lint/rules/<rule-name>.ts` exists, edit it; otherwise create it. Use
`defineRule({ meta, createOnce })` from `@oxlint/plugins`, a one-sentence
`meta.docs.description` naming the replacement, `meta.messages` with `{{placeholders}}`, and
`meta.schema` when the rule takes options. Resolve options with `perFileOption`. The helper and
visitor catalogue is in `references/rule-idioms.md`.

**Done when** `bunx oxlint --type-aware src tests` runs with no plugin-load error.

## 6. Register and enable the rule

Run `scripts/check-rule.sh <rule-name>` and add only the entries it reports missing:

- `src/lint/index.ts`: the import, the `rules` entry, and `"shadcn-x/<rule-name>": "error"` in
  `recommended`.
- `oxlint.config.ts`: `"shadcn-x/<rule-name>"` under `rules`, at `error`, or `warn` while
  existing violations are migrated.

**Done when** check-rule prints `ok` for the rule file, the three `index.ts` lines and the
`oxlint.config.ts` entry.

## 7. Write tests

If check-rule finds a test file, edit it. Otherwise create `tests/lint/<rule-name>.test.ts`
(some rules keep theirs in `tests/lint/rules/`). Copy the `RuleTester` setup from
`tests/lint/no-manual-overflow.test.ts`. Write one invalid case per form from step 3, one valid
case per allowed value or context, and the false-positive traps from `references/rule-idioms.md`.

**Done when** `bunx vitest run <test file>` passes and the invalid cases cover every listed form.

## 8. Fix the existing violations

Count the sites first: `bunx oxlint --type-aware src tests 2>&1 | grep -c "<rule-name>"`. Migrate
real debt to the replacement. For a legitimate exception, use the token, or add
`// oxlint-disable-next-line shadcn-x/<rule-name> -- <reason>` citing the framework constraint.

**Done when** the same count prints 0.

## 9. Run the repo checks

Run every command in the shadcn-x `AGENTS.md` `## Verify` section, then
`bunx knip --use-tsconfig-files`. If one fails, fix it and rerun the whole set.

**Done when** every command exits 0 (oxlint warnings are allowed, per `AGENTS.md`).

## 10. Document the rule in AGENTS.md

`AGENTS.md` names rules in two lists. Add each only if missing:

- `## On-system rules`: a bullet stating the rule as the action to take, ending with
  `` (`<rule-name>`) ``.
- `## Layout`: append `` `<rule-name>` `` to the `src/lint/` bullet's `Rules:` list.

**Done when** `scripts/check-rule.sh <rule-name>` exits 0.

## Hard rules

- Call `ruleTester.run` at the top level of a `describe` callback, outside any `it()`.
- Read `context.filename` and `context.options` inside `before()` or a visitor; `context.options`
  is `null` at `createOnce` setup time.
- Key detection on AST structure (node type, ancestor chain, value form), never on identifier or
  key names.
- Grant exceptions at the site with a token or an inline disable carrying a reason. Leave
  `oxlint.config.ts` overrides and file allow-lists for the rule out.

## Report

- Rule file path, and whether it was created or updated
- Level in `oxlint.config.ts` (check-rule prints `level`)
- The forms from step 3, each with its invalid-case count, and the valid-case count
- Violation count for the rule before and after step 8
- Each inline disable added: file, line and reason
- Exit code of each step 9 command and of the final `scripts/check-rule.sh`
- Skipped steps, each with its reason
