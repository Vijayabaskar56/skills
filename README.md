# Skills

Agent skills by Vijayabaskar, for Claude Code, Codex, OpenCode and any agent
[skills.sh](https://skills.sh) supports.

| Skill | Use it for |
| --- | --- |
| `agent-display` | A headed browser or GUI app on a Linux host on demand, on a virtual display that stops after the task |
| `babysit-pr` | Watching a PR through CI and review bots with one watcher, and fixing the real findings |
| `btca` | Answering "how does library X work" from cloned source in `~/work/references` |
| `council` | Read-only review from three models on three providers, looped until they agree |
| `figma-to-code` | Building pixel-accurate React or React Native UI from a Figma node |
| `file-pr` | Filing a short, problem-first PR with before and after evidence from `fleet upload-file` |
| `full-send` | Taking a change to a merged PR unattended: prove, review, file, babysit, merge |
| `full-stop` | The full-send flow, stopping with the PR ready for you to merge |
| `html-report` | One-table HTML reports for clients and other teams, with a Markdown mirror |
| `leaving-pr-comments` | Writing GitHub comments an agent posts for you, in your voice |
| `legend-list-best-practices` | Building and fixing Legend List lists by the library's own contracts: virtualization, recycling, measurement |
| `magnific-assets` | Credit-free Magnific art in Relax mode: subtle looping AVIF animations, images, video, audio and 3D, with loop judging and audits |
| `modernize` | Rebasing an old PR and deciding whether it should still exist |
| `no-use-effect` | Replacing `useEffect` with derived state, event handlers and data-fetching libraries |
| `perf-check` | Benchmarking a screen's open and scroll frames on an Android phone against a baseline, with trace triage |
| `perf-review` | Ranking the likely causes of a React or React Native performance regression |
| `png-sequence-animation` | Splitting a photo into PNG layers that swing or move on their own, with shadows and reflections that follow the parts |
| `ship-builds` | Local iOS TestFlight and Android APK builds for testers |
| `sol-loop` | A GPT Sol review loop with a round budget and a findings ledger |
| `takeover` | Finishing someone else's PR, branch or thread while keeping their credit |
| `verify-on-device` | Checking a React Native change on a simulator with argent |
| `write-great-skills` | Writing, restructuring and linting agent skills |

The PR workflow skills (`babysit-pr`, `council`, `file-pr`, `full-send`, `full-stop`,
`leaving-pr-comments`, `modernize`, `sol-loop`, `takeover`) are adapted from
[t3dotgg/tstack](https://github.com/t3dotgg/tstack), MIT License, Copyright (c) 2026 Theo Browne; see `LICENSE-tstack`.

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
