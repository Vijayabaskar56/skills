# Setup for create-lint-rule

`scripts/doctor.sh` checks these from the shadcn-x root. Ask the user once before installing or
linking anything.

| Doctor line | Fix |
| --- | --- |
| `missing shadcn-x repo root` | `cd` to the shadcn-x checkout and rerun. |
| `missing bun` | Install bun from https://bun.sh. |
| `missing node_modules` | Run `bun install` in the repo root. |
| `missing references/base-ui`, `missing references/ui` | Clone the repo and create the symlink, as `shadcn-x/references/README.md` describes. |
| `optional references/coss` | Same; coss is a second opinion, so the skill runs without it. |
| `missing docs/stylex-docs` | The docs are tracked in git; restore them with `git checkout -- docs/stylex-docs`. |

The three `references/` entries in shadcn-x are gitignored per-machine symlinks to clones outside
the repo. `shadcn-x/references/README.md` lists each target and the `ls` commands that confirm it.
