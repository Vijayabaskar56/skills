# Skills

Agent skills by Vijayabaskar, for Claude Code, Codex, OpenCode and any agent
[skills.sh](https://skills.sh) supports.

| Skill | Use it for |
| --- | --- |
| `btca` | Answering "how does library X work" from cloned source in `~/work/references` |
| `create-lint-rule` | Adding a guardrail rule to the shadcn-x lint plugin |
| `figma-to-code` | Building pixel-accurate React or React Native UI from a Figma node |
| `html-report` | One-table HTML reports for clients and other teams, with a Markdown mirror |
| `perf-review` | Ranking the likely causes of a React or React Native performance regression |
| `ship-builds` | Local iOS TestFlight and Android APK builds for testers |
| `verify-on-device` | Checking a React Native change on a simulator with argent |
| `write-great-skills` | Writing, restructuring and linting agent skills |

## Install

```sh
npx skills add Vijayabaskar56/skills -g                  # pick skills interactively
npx skills add Vijayabaskar56/skills -g -s figma-to-code # one skill
```

Pin a commit with `Vijayabaskar56/skills#<sha>`.

## Layout

Each skill is a folder under `skills/` with a `SKILL.md` and its own `references/`, `scripts/`
and `assets/`. Check a skill with:

```sh
bash skills/write-great-skills/scripts/lint-skill.sh skills/<name>
```
