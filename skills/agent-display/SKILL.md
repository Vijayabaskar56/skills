---
name: agent-display
description: Use when a task needs a headed browser or a GUI app on a Linux host with agent-display, such as a site that blocks headless Chrome, a visual check, a login the user watches, or desktop automation. Brings up a virtual display only for the task, attaches drivers to one headed Chromium over DevTools :9222, and stops what it started. Not for headless scraping, tests or screenshots; run headless Chrome or Playwright directly.
argument-hint: "url or task needing a headed browser"
---

# Agent display

A headed browser on a laptop with its lid shut runs on a virtual X display (`:99`) that exists only
while a task needs it. Nothing graphical runs at idle, which keeps the machine cool. `scripts/` and
`references/` are relative to this skill's directory.

## 0. Check setup

Run `scripts/doctor.sh`. If it reports `missing linux`, stop using this skill and drive the browser
headless. Fix any other `missing` line with `references/setup.md`, asking before installing.

**Done when** doctor exits 0.

## 1. Choose headless or headed

Use headless Chrome, Playwright or `agent-browser` without `--headed` for scraping, tests,
screenshots, PDFs and most automation. Choose this skill only when headless fails or the task
needs a real window: a site that blocks headless browsers, a visual or layout check, an extension,
a login or captcha the user completes, or a GUI app other than the browser.

**Done when** you can name why the task needs a window. If you cannot, stay headless.

## 2. Check the temperature

Run `scripts/temp.sh 85`. If it exits 1, tell the user the machine is hot and ask before starting a
headed browser.

**Done when** temp.sh printed a value under the limit, or the user said to go ahead.

## 3. Open the page

Run `scripts/open.sh <url>`, or `scripts/open.sh --vnc <url>` when the user wants to watch. Keep the
`owner` line it prints. `owner none` means another task already runs the display; work in your own
tab and leave it running at the end. If it exits 3, the display runs without VNC for another task:
ask the user before restarting it.

**Done when** open.sh exited 0 and printed `cdp http://127.0.0.1:9222`.

## 4. Drive it

Attach to the running Chromium over DevTools, as `references/drivers.md` shows for agent-browser,
Playwright and raw DevTools. For a GUI app other than the browser, run it with `DISPLAY=:99` and
stop it yourself when done. If the user asked to watch, give them the tunnel command from
`references/drivers.md`.

**Done when** the task's own check passes (the page state, the file, the screenshot).

## 5. Stop what you started

Run `scripts/close.sh <owner-token>` as soon as the task is done or abandoned, including after an
error. With `owner none`, run `scripts/close.sh none`, which leaves the other task's display
running. Use `scripts/close.sh --force` only when the user asks to clear everything.

**Done when** close.sh printed `stopped`, or `left running` for a display another task owns.

## Hard rules

- Start a headed browser only through `scripts/open.sh`, and attach to it over DevTools :9222.
- Run `agent-browser` with `--cdp 9222` here, never with `--headed`.
- Leave the desktop session alone: start no compositor, window manager or login session, and use
  only display `:99`.
- Run `scripts/close.sh` with your owner token at the end of every task that ran open.sh.
- Ask the user before a headed run when `scripts/temp.sh 85` exits 1.

## Report

- Why the task needed a window (step 1), or that it stayed headless
- The `display`, `chrome` and `owner` lines open.sh printed
- The temperature before the run and after close.sh
- close.sh's last line
