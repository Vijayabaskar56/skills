---
name: magnific-assets
description: Use when making app art with Magnific without spending credits - animating an illustration into a subtle looping AVIF, or generating an image, video, audio or 3D asset in Relax mode - or when a generated loop looks off (moves too much, slides, rough cut-out edges). Picks the project, drives the web app, judges the motion, builds and audits the loop. Not for paid generation through the Magnific MCP or API.
argument-hint: "<art file or folder> <what should move>"
---

# Magnific assets

Generate in Magnific's web app in Relax mode (0 credits), then build the asset locally. Scripts are
in `scripts/`; run Python ones with `$MAGNIFIC_PY` (a venv with numpy, scipy, Pillow). Project facts
(asset folder, size budget, last Magnific project, how the app wires art) live in the repo's
`.magnific-assets.json` and the notes file it names; `references/first-run.md` builds them.

## 0. Check setup

Run `scripts/doctor.sh`. Fix each `missing` line with `references/setup.md`, asking once before
installing anything. If `.magnific-assets.json` is missing, follow `references/first-run.md`.

**Done when** doctor exits 0 and the repo has `.magnific-assets.json`.

## 1. Ask which Magnific project to use

Ask on every run, before anything is generated, with the config's `project.name` as the
recommended option. List the choices with the Magnific MCP's `folders_list` (`onlyProjects: true`)
when it is connected, otherwise read them from the web app's project switcher. Save the answer to
`project` in the config.

**Done when** the user picked a project this run and the config holds its name and reference.

## 2. Pick the category

Read the one reference for the asset: `references/video.md` (animate an illustration, the main
flow), `references/image.md`, `references/audio.md` or `references/3d.md`. Each says which models
are free and how to judge the output. Read `references/mistakes.md` before the first generation of
the session.

Then size the idea to where it is shown. Read the config's `displaySize` (the box, in points,
the app draws the asset in) and work out how big the art's parts are there: scale = display width
/ art width. On a 211 pt card a 633 px art is shown at a third, so a 6 px wire is 2 pt and a 90 px
excavator is 30 pt. Pick a motion the eye catches at that size (`references/judging.md`, check 3);
if the named part is too small, propose a bigger part or another motion before generating.

**Done when** you have named the category, the model and, for video, what moves, its size and its
travel in display points.

## 3. Find a browser driver

Run `scripts/find-browser.sh --magnific`, with `--cmd "<prefix>"` when you will drive a scoped tab
(a named or pinned session): it checks that exact tab. Follow the person's rules for who drives
the browser; some send it to another agent with a brief. If it prints a driver, open `references/browser-drivers.md`
and use or write that tool's driver script for this machine. If it prints `manual`, give the person
the manual steps from the same file and wait for the downloaded file.

**Done when** find-browser reports `signed in to Magnific, Relax on`, or the person has the manual
steps.

## 4. Generate in Relax mode

Prepare inputs with the category reference (for video: `scripts/prep_start.py`, then the prompt
pattern). Before clicking Generate, the driver confirms three things on the page: the project
switcher shows the project from step 1, the Generate button reads "Relax mode" with no credit
number, and the model and resolution are the free ones. If any differs, stop and fix it in the page.
After it finishes, confirm the cost with the MCP's `creations_cost` when connected.

**Done when** the clip or file is downloaded into the run's work folder and its cost reads 0.

## 5. Judge the output

For video, run `scripts/contact_sheet.sh` on each clip (and `--first 15 --every 2` for the
opening), then score it with `references/judging.md`. Pick the clip and the frame range to use,
or write a new prompt and generate again; stop after three tries per art and report.

**Done when** you have one clip and its frame range, with the rubric's reason, or a report of why
none works.

## 6. Build the asset

Pick the builder in `references/video.md`: `scripts/loop_from_clip.py` when the motion stays
inside the art's outline, `scripts/keyed_pingpong.py` for a small motion that leaves it, and
`scripts/part_over_art.py` for a whole action or full swing. Every builder keeps each unmoving
pixel from the art; never ship whole clip frames. Then run `scripts/encode.sh` (add `--once` for
an action that plays once and holds; lower `--qalpha` when the file is over budget).

**Done when** encode prints the AVIF, still and preview paths.

## 7. Audit and show it

Run `scripts/display_size.py <avif> --display <displaySize> --card <work>/card.gif` and open
the card GIF at 100%: it is the asset at the size a phone shows it. Run `scripts/audit.py` with
the config's `sizeBudgetKB`, `--protect <mask.png>` covering what
the request keeps still (white = must stay the art), and `--still-is-art` if the app shows the
original art as the still. If it exits 1, fix the build and rerun. Open both audit boards and the
preview GIF yourself, then show the user the preview and the numbers before installing anything.

**Done when** audit exits 0, you have looked at both boards and the card GIF, and the user has
seen the preview.

## 8. Install into the project

Copy the AVIF and still to the config's `assetDir` and wire them the way the notes file describes.
Then follow the project's own rules for checking on a device and for committing.

**Done when** the files are in `assetDir`, the notes file's wiring is done, and the project's
checks ran.

## Hard rules

- Generate only in the web app's Relax mode; the Magnific MCP's generate tools charge credits even
  on an unlimited plan. Use the MCP only to list projects, find creations and read their cost.
- Generate only after step 1's project question was answered in this run.
- Clone or change a real person's voice only with that person's consent.
- Show the user every generated clip or a contact sheet of it before saying what it does.
- Keep frame 0 or the still identical to what the app shows before the animation loads.
- Drive only the user's own signed-in browser through a driver they have; leave their cookies and
  sessions in the browser.

## Report

- Magnific project used, model, resolution, and each creation's cost from `creations_cost` (or
  "Generate read Relax mode" when the MCP is not connected)
- For each clip tried: the judging score and the frame range kept or the reason it was dropped
- The audit JSON (`pass`, each check value), AVIF size and frame count
- Paths of the preview GIF and the installed files
- Skipped steps, each with its reason
