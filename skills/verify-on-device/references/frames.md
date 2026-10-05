# Reading frames from a recording

Use for timing questions (flicker, a jump, a dropped frame): pull frames with ffmpeg instead of
watching the video. Crop to the element under test, because full-screen frames are large and mostly
noise. Take every frame of a short clip, and 1-2 fps or scene changes only from a long one. Write
frames to the scratchpad.

```bash
# only the frames where the region changed: a few images instead of hundreds
ffmpeg -i clip.mp4 -vf "crop=W:H:X:Y,select='gt(scene,0.015)',showinfo" -fps_mode passthrough f_%03d.png
# every frame of a known 1-2 s window, tiled into one contact sheet
ffmpeg -ss 11.2 -t 1.5 -i clip.mp4 -vf "crop=W:H:X:Y,scale=545:-1" -fps_mode passthrough f_%03d.png
ffmpeg -i f_%03d.png -vf "tile=3x15:margin=4:padding=4" -frames:v 1 sheet.png
```

If the notes file names a project tool for frame drops, run it on the recording.
