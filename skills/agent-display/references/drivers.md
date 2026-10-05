# Driving the headed Chromium

`open.sh` leaves one Chromium on display `:99` with DevTools at `http://127.0.0.1:9222`. Attach to
it; never launch a second browser.

## agent-browser

```sh
agent-browser --cdp 9222 snapshot
agent-browser --cdp 9222 open https://example.com
agent-browser --cdp 9222 screenshot page.png
```

Never pass `--headed`: it starts its own browser outside the virtual display.

## Playwright

```js
import { chromium } from "playwright"
const browser = await chromium.connectOverCDP("http://127.0.0.1:9222")
const context = browser.contexts()[0]
const page = context.pages()[0] ?? (await context.newPage())
await page.goto("https://example.com")
await browser.close() // disconnects only; close.sh stops Chromium
```

## Raw DevTools

```sh
curl -s http://127.0.0.1:9222/json/list            # open tabs
curl -s -X PUT "http://127.0.0.1:9222/json/new?https://example.com"
```

## Another GUI app

Run it against the same display, and stop it yourself before `close.sh`:

```sh
DISPLAY=:99 <app> &
```

## Watching it

Start with `open.sh --vnc <url>`, then on the viewing machine:

```sh
ssh -L 5999:localhost:5999 <user>@<host>
```

and point a VNC client at `localhost:5999`. The VNC server listens on localhost only and has no
password, so the SSH tunnel is the only way in.
