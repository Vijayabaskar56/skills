# Audio: sound effects, music, voice

Magnific lists Sound Effect Generator, Audio Generator, Music Generator, Voice Generator, Voice
Cloning and Voice Changer. Whether any of them is free in Relax mode was not verified: open the
tool, turn Relax on, and read the Generate button. If it shows a credit number, stop and tell the
person; do not generate.

## Inputs

- Say the length in seconds, the mood, and what it plays over (a tap, a success state, a loop
  under a screen).
- For UI sounds, ask for a short, dry sound with no reverb tail, and trim silence locally.

## After generating

1. Download every candidate into the work folder.
2. Trim leading silence and normalise loudness with ffmpeg
   (`ffmpeg -i in.wav -af "silenceremove=start_periods=1:start_threshold=-50dB,loudnorm=I=-16" out.m4a`).
3. Listen to each against the screen it belongs to, and play the shortlist to the person.
4. Ship the format the project already uses for sounds (find one in the asset folder).

Judging: it matches the request's mood, starts on the beat with no silence, has no clicks at the
cut, and fits the file budget.
