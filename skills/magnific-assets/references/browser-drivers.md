# Browser drivers

Magnific has no free API: Relax mode exists only in its web app, and its bot protection refuses
plain HTTP clients and headless browsers. So generation runs in a real, signed-in browser window,
driven by whatever the person has. The skill ships no driver script, because tools and their flags
change; `scripts/find-browser.sh` finds the tool, and you write the script for it on this machine.

## What can drive it

| Driver | What it uses | Notes |
| --- | --- | --- |
| Ardia (`ardia browse`) | The person's own browser, tabs and logins | Commands mirror agent-browser. `ardia notes www.magnific.com` holds site notes from earlier runs. |
| agent-browser `--auto-connect` | A Chrome that is already running, with its logins | Chrome must expose remote debugging; see `agent-browser --help`. |
| agent-browser `--headed --profile Default` | The Chrome profile on disk, in a new window | Quit that browser first; the profile is locked while it runs. Always headed. |
| Computer use | Seeing the screen and clicking | Only when the person asks for it and no CLI driver works. Follow their own rules for who runs it (some route it to a separate agent); the brief needs the project, model, settings, prompt text and the file path. |

Follow the person's rules for who drives the browser. Some route all browser and computer-use
work, CLI drivers included, to a separate agent; then you write the brief (project, model,
prompt, start image path, generation limit, the Relax checks) and do the building yourself.
| Manual | The person clicks | Always works; see the end of this file. |

Playwright, Puppeteer or plain HTTP against Magnific's private endpoints: a headless browser gets a
403 page, and a headed one needs the person's cookies copied out of their browser. Use one of the
drivers above instead.

## Write the driver script for this machine

When find-browser names a driver and `~/.config/magnific-assets/drivers/<driver>.sh` does not exist,
write it from that tool's own `--help`, then test each function once on the live page:

- `open`: open https://www.magnific.com/app/ai-video-generator (or the category's tool page)
- `project`: print the project name the page header shows
- `start-image <png>`: fill `assets/page/set-start-image.js` with the file's base64 and run it
  through the driver's eval (file uploads through the driver's own upload command are often blocked)
- `prompt <text>` and `negative <text>`: fill the Prompt box; open "Negative prompt" first
- `relax`: run `assets/page/relax-status.js`; it prints `on`, `off` or `signed-out`
- `check`: print the Generate button's label; it must read "Relax mode" with no number
- `generate`: click Generate, only after `project`, `relax` and `check` pass

Reuse the script on later runs. If a function fails, read the page again (`snapshot -i`), fix that
function and note the change in the script's header.

## Several agents, one browser

When agents generate in parallel, each one uses its own scoped tab (Ardia:
`ardia browse --session <name> --pin-tab ...`), writes its driver script in its own work folder,
and never switches, closes or reads another session's tabs. Check sign-in through that exact
prefix: `scripts/find-browser.sh --magnific --cmd "<prefix>"`. Logins live in one browser profile,
so a new tab can open in a profile that is signed out. In Ardia a session's `open` most likely
lands in the profile the window shows at that moment, not the default one (unconfirmed: one run
read `signed-out` while Magnific was signed in under Work and the person had been using Personal;
the retry, with the window on Work, was signed in). Separately, `find-browser.sh` misread Ardia's
output wrapper as `signed-out` once; when it disagrees with the page, read `relax-status.js`
through the driver's JSON output instead. Before generating, read the window's profile with `ardia call windows` (`profileName`)
and the tab's with `ardia call tabs.get`; if it is not the signed-in one, close your tab and ask the
person to switch the window back, rather than retrying. Never switch the person's window yourself.

## Facts about the drivers (verify; tools change)

- Ardia refused `download` (its engine blocks `Browser.setDownloadBehavior`). Clicking the clip's
  MP4 button saved it to ~/Downloads; match the file by creation id and move it to the work folder.
- The Prompt box is contenteditable: `fill` does not clear it. Click "Clear prompt" (or select all
  and delete), then type with the driver's insert-text command.
- Pass large base64 (the start image) to `eval` on stdin (`eval --stdin`), not as an argument.

## Facts about the page (verify; the UI changes)

- The Relax switch sits next to Generate and reads ON or OFF. Clicking it toggles it: read it
  before clicking, and click only when it reads OFF.
- With Relax on and a free model, Generate reads "Relax mode"; otherwise it shows a credit number
  (Kling 2.5 at 720p showed "Generate 140" with Relax off).
- The project switcher is at the top left of the page; generations land in the selected project.
- Kling 2.5 in Relax mode accepts a start image only; an end image blocks Generate at 720p.
- A Relax video took about 8 minutes. When the Relax queue is full, wait for one to finish.
- The finished clip has a Download button; the MCP's `creation_status` also returns its URL.

## Manual

Give the person these steps, with the start image path and prompt texts filled in:

1. Open https://www.magnific.com/app/ai-video-generator and pick the project from step 1 in the
   switcher at the top left.
2. Model: Kling 2.5. Resolution: 720p. Length: 5 s. Relax switch: ON.
3. Start image: upload `<start.png>`. Leave the end image empty.
4. Paste the prompt; open "Negative prompt" and paste the negative prompt.
5. Check that Generate reads "Relax mode" with no credit number, then click it.
6. After about 8 minutes, download the clip and say where it is.
