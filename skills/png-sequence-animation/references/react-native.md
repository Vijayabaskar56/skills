# Rigging layers in React Native

## Placement

- Scale every layer by `width / canvas.width` and place each with the same box. Layers on one
  canvas need no per-layer offsets.
- Rotate with `transform: [{ rotateZ }]` and `transformOrigin` set to the pivot in scaled pixels.
  Rotating about the view's centre and translating back drifts.
- Nest: a stage view rotates everything about the hanging point; each part rotates by its own
  angle minus the stage's, about its own pivot. A shadow uses its part's animated style, so it
  turns with the part.

## Motion

- Run the physics in a Reanimated `useFrameCallback` on the UI thread, a damped pendulum per
  object with a fixed step; never set angles from JS state per frame.
- Give each independent object its own pendulum and its own period, with a soft limit so parts
  do not fly apart.
- Hit-test parts at touch-down (`onBegin`), against each part's own shape after rotation.

## Input: gyro, touch or both

Offer three modes on one rig: `motion` (tilt), `touch` (drag and tap) and `both`. Each feeds the
same pendulums, so none needs its own physics:

- **Motion.** Create `useAnimatedSensor(SensorType.ACCELEROMETER)` and `GYROSCOPE` with
  `interval: "auto"` in the component body, and read only their `.sensor.value` inside the frame
  callback. The accelerometer gives the down direction (smooth
  it, then let the hanging direction follow it slowly, and push the parts by the difference); the
  gyroscope's z rate adds a spin push. Android and iOS report acceleration with opposite signs;
  flip one with a `Platform.OS` constant. Treat a reading near zero as "no sensor" and fall back
  to plain gravity, so a simulator hangs still instead of falling sideways.
- **Touch.** A pan gesture grabs the part hit at touch-down and pulls it with a spring; a tap
  kicks the part nearest the finger. Inside a scroll view or sheet, set `activeOffsetX` and
  `failOffsetY` so vertical scrolls win.
- **Both.** Mount the sensors and enable the gestures together. This is the right default for
  a decorative footer.
- **Sleep only without sensors.** A touch-only rig may stop its frame work when every angle and
  speed is below a rest threshold, and wake on the next gesture. A motion rig must keep running:
  waking on a tilt threshold ignores small tilts, and sensor noise cannot be tuned on a
  simulator. Mount a motion rig only where it is seen (an expanded sheet, a footer), since it
  costs work on every frame.
- **Remount on mode change.** Key the stage by mode so sensors and gesture state start clean.

## Haptics

Match a haptic to a scripted motion, such as a nudge that jingles the parts when they scroll into
view:

- Fire it from the same frame-callback step that applies the nudge, with
  `scheduleOnRN(play)` (react-native-worklets), so it lands on the motion and not on a timer.
- Write it as a composed pattern of sharp transients rather than a preset. With
  react-native-pulsar, `usePatternComposer(pattern)` takes `discretePattern` ticks
  (`time` in ms, `amplitude` and `frequency` 0 to 1) and a faint `continuousPattern`. A metal
  jingle is about eight high-frequency ticks over 600 ms that start fast and loud, then fade and
  slow, over a ring-out that dies by 650 ms.
- Check the app's haptics preference before playing, and silence any sound the library pairs
  with haptics.
- Haptics and gyro cannot be judged on a simulator. Verify there that nothing throws and the
  motion still plays, then ask the user to feel it on a phone.

## Nested parts

A part with a `parent` is a child view inside the parent's rotated view, rotated about its own
pivot by its angle relative to the parent. Simulate the child as a pendulum on a moving support:
its relative acceleration gets minus the parent's acceleration, scaled by the pivot's reach, so it
lags. A stop on the relative angle is where it strikes: bounce it there and fire the haptic from
that contact, gated on impact speed and a short gap, so a hard ring dings and a drift does not.

A `mask` layer becomes the mask element of a `MaskedView` inside the parent's view, with the child
inside it.

## Masks

Use `@react-native-masked-view/masked-view` with `androidRenderingMode="hardware"`:

- shadows inside a mask made from the receiving surface's PNG, so they never show past its edge;
- a glint or reflection inside a mask made from the part's PNG.

On iOS a mask element sized with `absoluteFill` is misplaced and the masked content disappears.
Give the mask element an explicit box: React Native `Image` with the scaled canvas width and
height and `resizeMode="stretch"`. To debug a mask, give the masked children a solid colour: no
colour means the mask is wrong, colour in the wrong place means the content is.

## Draw order

Back to front, as in the rig: surface, shadows (masked by the surface), the back part, the front
part (each with its glint), then anything that passes in front of the parts, such as a ring.

## Readiness

Expose a locator once the first layer has drawn (`onDisplay` on expo-image, `onLoad` on React
Native's `Image`), on an accessible
element, so tests and verification wait for it instead of sleeping.
