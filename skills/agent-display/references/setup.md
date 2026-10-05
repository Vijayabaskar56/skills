# Setting up agent-display

Ask the user before installing anything.

## Packages

| Need | Arch / Omarchy | Debian / Ubuntu |
| --- | --- | --- |
| Virtual display | `sudo pacman -S xorg-server-xvfb` | `sudo apt install xvfb` |
| Watching over VNC (optional) | `sudo pacman -S tigervnc` | `sudo apt install tigervnc-standalone-server` |
| Browser | `sudo pacman -S chromium` | `sudo apt install chromium` |

## The command

This skill ships `scripts/agent-display`. Put it on PATH so every agent and shell finds the same
copy:

```sh
mkdir -p ~/.local/bin
ln -sf "<this skill's directory>/scripts/agent-display" ~/.local/bin/agent-display
```

Skip the link when `agent-display` is already on PATH; `open.sh` and `close.sh` prefer the copy on
PATH and fall back to the bundled one.

## Drivers (optional)

- agent-browser: `npm i -g agent-browser`, then attach with `--cdp 9222`.
- Playwright: already present if `npx playwright --version` works; attach with `connectOverCDP`.

Run `scripts/doctor.sh` again; every required line should print `ok`.
