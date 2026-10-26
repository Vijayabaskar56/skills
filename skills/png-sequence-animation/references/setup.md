# Setup

Ask the user once before installing anything.

## Python with numpy, scipy and OpenCV

```bash
python3 -m venv ~/.venvs/png-sequence-animation
~/.venvs/png-sequence-animation/bin/pip install numpy scipy opencv-python-headless
```

Set `python` in `.png-sequence-animation.json` to `~/.venvs/png-sequence-animation/bin/python` as an absolute path.
A venv under `/tmp` disappears on reboot.

## ffmpeg and jq

```bash
brew install ffmpeg jq
```

## argent

The device steps need the argent MCP server: `npx @swmansion/argent@latest init -y`. Confirm the
tools answer with `list-devices`.
