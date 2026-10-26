# Setup

Ask the user once before installing anything.

## Python with numpy, scipy and OpenCV

```bash
python3 -m venv ~/.venvs/png-sequence-animation
~/.venvs/png-sequence-animation/bin/pip install numpy scipy opencv-python-headless
```

Set `python` in `.png-sequence-animation.json` to the expanded path that
`echo ~/.venvs/png-sequence-animation/bin/python` prints; doctor runs the value literally, so a `~`
there fails.
A venv under `/tmp` disappears on reboot.

## ffmpeg and jq

```bash
brew install ffmpeg jq
```

## argent

The device steps need the argent MCP server: `npx @swmansion/argent@latest init -y`. Confirm the
tools answer with `list-devices`.
