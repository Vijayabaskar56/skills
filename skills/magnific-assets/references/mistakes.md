# Mistakes to avoid

Each of these cost a round on a real run. Read before the first generation.

## Credits

- **The Magnific MCP and API charge credits.** Their cost check reports
  `unlimitedAppliesHere: false`: Relax mode applies only in the web app, so its generate tools
  spend credits. Use the MCP only for read-only calls (`folders_list`, `creations_search`, `creation_status`, `creations_cost`).
- **The Relax switch toggles on click.** Clicking it to "make sure" it is on turns it off. Read
  it first (`assets/page/relax-status.js`), and click only when it reads OFF.
- **An end image blocks free Kling 2.5.** Leave the end image empty; build the return locally.
- **Check `creations_cost` after each generation.** It should show 0; if not, stop and tell the
  person.
- **The account is shared with the team.** `creations_search` lists everyone's work, and older
  clips with a similar prompt can also show `mine: true`. Match the full prompt and the project,
  then confirm the id against the creation URL in your tab before reading cost or downloading.

## Project and files

- **Generations land in the selected project.** Confirm the project name in the page header
  before Generate, every run, not only the first.
- **Keep work files in the work folder**, never in the app's asset folder, and install only the
  finished AVIF and still.

## Generating

- **Kling overshoots "slight".** The first half-second is often the usable part; pick frames from
  the opening contact sheet before retrying. When the whole clip plays one good action, use it.
- **The canvas has little margin.** Art trimmed tight to its outline leaves no room for a part
  that swings out; Kling's clip crops it at the frame edge. Pad the art before `prep_start.py`
  when the part will move past the outline, and crop back after building.
- **"Rolls" makes things roll away; "moves" makes them travel.** Describe a rotation in place
  ("rocks a few degrees right, then back, staying in the same spot").
- **Animate only what was asked.** When the request names one object ("only the fallen one"),
  every other object stays exactly the art, even similar objects next to it.
- **A rotating part crosses what stands in front of it.** A crane jib asked to swing passed
  through the building's top floor: in isometric art the depth Kling invents is wrong. Keep long
  parts still and move a small part along a clear path (the hook and its load, beside the
  building), and say where it must not go.
- **An object should not appear from nowhere.** For a one-shot action, start with the object
  already in the scene and play once, rather than looping it in and out.

## Building

- **A white background makes a poor key.** White edges and highlights vanish with it, which
  shows as notches on dark mode. Use the green start image when the moving part is cut from the
  clip.
- **The art's own alpha clips motion that leaves the outline.** For a part that tips or sways
  out, take its pixels and alpha from the keyed clip, and everything that did not move from the
  art.
- **A "still" mask from the whole clip is wrong when the clip drifts.** Build the moved-pixels
  mask from the frames you use, not the full clip.
- **Look at the clips before claiming a result.** Read the contact sheets yourself; a passing
  number does not mean it moves the way the person asked.
- **Whole Kling frames break consistency.** A loop cut from the full clip frame looked right on
  its own, but the base tile and ground came out lighter and softer than the art and the person
  saw it at once. Take only the moving part from the clip (`part_over_art.py`).
- **A mask box cuts what crosses its edge.** A coin that stood up past its traced region showed a
  straight cut and a hole. Size the zone for the part's widest pose across the frames you use.
- **The art's old pose stays unless you erase it.** When the part leaves its pose in the art, the
  original shows through as a ghost; use `--erase-box`.
- **Smoke and steam stop in a straight line at the canvas edge.** Art trimmed to its outline
  (and sometimes the design itself) cuts rising smoke flat at the top. Fade the frames' alpha to
  0 over the top 40 to 110 px so the smoke dissipates; a new generation hits the same edge unless
  the art is padded first.
- **Judging at full size.** A landfill excavator swinging its arm looked fine in the 633 px
  preview and read as nothing on the 211 pt card: the arm is 2 pt thick there, and the trash it
  stirred is texture. Size the motion in display points before generating (SKILL.md step 2).
- **Too small is a failure too.** Keeping only the first four frames of a coin tip passed every
  number and read as nothing. Show the person, and use more of the clip when it plays well.
- **Procedural fakes of rigid motion look fake when they uncover something.** Rotating a
  cut-out and filling in what it covered was rejected. A sprite moving over empty space, so it
  uncovers nothing, passed: a crane's hook and basket on a drawn cable, over sky. Otherwise use
  procedural for glows, pulses and blinks.

## Checking and shipping

- **A play-once art plays when it decodes, not when it is seen.** In a carousel, a card that
  starts offscreen showed only the held last frame by the time it was swiped in. Check where the
  art sits; a play-once there needs the app to restart it when the card becomes visible.
- **Check dark mode.** Fringes and halos show only on dark. `audit.py` writes both boards.
- **Older Android may not animate AVIF.** On the project that built this skill, devices below
  API 31 showed only the first frame; verify for the app's image library. Frame 0 must work as a
  still either way; the still WebP is that frame.
- **Gist previews stop at about 1 MB.** For a shared gallery of several AVIFs, serve the raw files
  through a CDN proxy (raw.githack.com) instead of the gist preview.

## Browsers

- **Headless browsers and plain HTTP get blocked**, and copying cookies out of the person's
  browser is not allowed. Drive the person's real browser through a driver, or give manual steps.
- **Start no headed browser or desktop session yourself** when the person's own rules route that
  through another tool or agent; follow their rules.
