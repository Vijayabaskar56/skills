# Verifying on the device

Use the argent tools and the `verify-on-device` skill if it is installed; this file only adds
what layered motion needs.

## Prepare

1. `list-devices`. Use a simulator no other agent is driving; at most one simulator and one
   Android device. Stop any you start.
2. Reload the app on its own Metro. Read the port from the dev client's URL; other checkouts may
   run their own Metro.
3. Open the config's `deepLink`. After every reload, check the screen you are on before you judge
   it; reopen the link if the app moved.

## Look at rest

Take a full resolution `screenshot` (scale 1) and crop to the object. The image returned after an
action is scaled down and hides fringes and smudges.

## Look in motion

A swing settles in about a second. Record and tile:

1. `screen-recording-start` with `showTouches: false` and a limit a few seconds over the action.
2. Drag a part hard with one `run-sequence` swipe (about 200 ms), then wait for it to settle.
3. `screen-recording-stop`, then
   `scripts/contact-sheet.sh <video> <sheet.png> 4 <w:h:x:y crop around the object>`.
4. Pull the widest frames at full size with `ffmpeg -ss <t> -i <video> -frames:v 1 <frame.png>`.

At the widest swing, look for a mark left on the surface, colour sliding with a part, a shadow
that stops partway, seams, and a shadow past the surface edge.

## Complaints

When the user sends a screenshot of a defect, compare its time with when the layers were
installed, and its screen with the deep link, before changing anything. Match the user's
marked area to a layer with the swing sheet.

## Clean up

Delete recordings and frames this run made. Stop the simulator servers for the devices you used.
