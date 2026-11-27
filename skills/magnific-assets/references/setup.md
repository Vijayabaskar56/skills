# Setup

Ask the user once before installing anything.

## Command-line tools

- ffmpeg and ffprobe: `brew install ffmpeg`
- avifenc and avifdec: `brew install libavif`

## Python

The build scripts need numpy, scipy and Pillow. Keep them out of the system Python:

```bash
python3 -m venv ~/.venvs/magnific-assets
~/.venvs/magnific-assets/bin/pip install numpy scipy pillow
export MAGNIFIC_PY=~/.venvs/magnific-assets/bin/python   # agent shells: put this in ~/.zshenv
```

## Magnific account

Sign in to https://www.magnific.com in the browser the driver uses. Relax mode (credit-free
generations on selected models) needs a plan that includes it; the switch next to Generate shows
ON or OFF. If the account has no Relax mode, stop: every generation would cost credits.

## Browser driver (optional)

Without one, generation is the manual web step. To automate it, install one of the tools in
`browser-drivers.md` (agent-browser: `npm i -g agent-browser && agent-browser install`).

## Magnific MCP (optional)

Connected through Executor or directly, it lists projects (`folders_list`), finds creations
(`creations_search`, `creation_status`) and reads what each cost (`creations_cost`). Its generate
tools charge credits; the skill never calls them.
