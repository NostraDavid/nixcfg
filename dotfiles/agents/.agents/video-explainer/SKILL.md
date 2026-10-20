---
name: video
description: Create narrated explanatory animations with a local Manim, Piper and FFmpeg pipeline. Use for video explainers or when motion and narration improve understanding. Exclude general video editing and publication.
---

# Explanatory video

Create a video when motion, timing, and narration help the person understand the
subject. Choose its length from the learning goals; there is no fixed duration
limit. Respect an explicitly requested format. Use `write` for clear language
and preserve the sources and uncertainties behind the explanation.

## Prepare the explanation

1. Establish the few things the viewer should understand. Check claims against
   the provided material or primary sources before turning them into visuals.
2. Write a storyboard with one explanatory step per scene. Build on the
   preceding scene, keep labels readable, and make motion demonstrate a
   mechanism rather than decorate the screen.
3. Write narration in the conversation language. Dutch uses the local Pim voice.
   For another language, select an existing matching Piper model with `--model`;
   if none is available, report that missing prerequisite. The Dutch
   pronunciation rules apply only to Dutch. Do not translate narration merely to
   make it fit the default voice.

## Render locally

Use the `video-explainer` command, or invoke the `video-explainer` flake output
from the nixcfg checkout containing this skill:

```bash
nix run path:/path/to/nixcfg#video-explainer -- check
nix run path:/path/to/nixcfg#video-explainer -- render manifest.json --output new-output
```

Resolve that checkout from this skill's real file path; substitute it for the
example path. This loads the pinned tools on demand without installing them into
the user's profile. `render --dry-run` validates prerequisites and inputs
without creating the output directory. `unit-test` runs isolated helper tests.

Create a self-contained `scenes.py` using Manim Community's `Scene`, `Text`, and
vector objects with the Cairo renderer. Use `DejaVu Sans` for labels. Do not
require LaTeX, Blender, OpenGL, network downloads, local helper imports, or
external asset files. Put diagrams and animation logic in this source file.
Python scene files execute code: write or review them before rendering.

Create a UTF-8 manifest next to the source:

```json
{
  "source": "scenes.py",
  "language": "nl",
  "scenes": [
    { "scene": "Start", "narration": "Hier begint de uitleg." },
    { "scene": "Mechanism", "narration": "Daarna laten we zien hoe het werkt." }
  ]
}
```

`source` is relative to the manifest. Scene names identify classes in that file;
the list determines playback order. `language` defaults to `nl` and must match
the selected voice. Every scene needs nonempty narration.

The renderer produces H.264 1920×1080 video at 30 fps with AAC narration. It
holds the last frame or adds silence to fit the longer of animation and
narration, without truncating either. Time the scene's explanatory changes to
the narration; automatic padding only aligns scene boundaries. It does not align
individual spoken words to animation events.

Each render needs a new output directory. A failure leaves the copied sources,
logs, and completed intermediate files for diagnosis; choose a new directory
after fixing the cause. Each external render process has a six-hour timeout,
independent of the video's duration.

## Verify and deliver

Inspect the actual `explanation.mp4`, not just a successful exit status. Use
ffprobe to check streams and duration. Inspect representative frames from every
scene and each transition, and listen to narration when audio inspection is
available. Check factual claims, label clipping, pacing, and whether narration
and visual changes explain the same step. Fix defects and render again into a
new directory. State any checks the environment could not perform.

Deliver the MP4, scene-level `explanation.srt`, `transcript.txt`, and the
reproducible `sources/` directory together. Subtitles and the transcript retain
the original words, including names changed only for pronunciation. Subtitles
are scene-level cues, not word-aligned captions. Preserve uncertainties in all
formats. Render locally without publishing, uploading, or starting playback.
