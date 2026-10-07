# Running the iLyric Architecture Spike

These are experimental developer commands for the synthetic fixture, not a production CLI or installation guide. The package uses Apple frameworks and has no third-party dependencies. It declares macOS 14 as its deployment floor; only the environment recorded in the [spike report](architecture-spike.md) has been exercised.

## Tests and Optimized Build

```sh
./scripts/test.sh
swift build -c release
mkdir -p artifacts
```

The test wrapper supplies missing Swift Testing compiler-plugin and runtime discovery paths when the selected Command Line Tools contain that framework. It does not install or modify a toolchain. The package uses Swift 5 language mode with Swift 6 tooling; strict Swift 6 concurrency checking is not a validated part of the spike.

## Still Frames and Determinism

```sh
.build/release/ilyric frame 5 4 artifacts/seek.png
.build/release/ilyric determinism
```

The two integers specify an exact rational output timestamp in seconds. The command accepts nonnegative numerators up to one billion and positive denominators up to one million. Time arithmetic is intended for the bounded synthetic experiment, not arbitrary untrusted project input. The determinism command compares full-resolution raw BGRA hashes in sequential, shuffled, repeated, and fresh-renderer evaluations. Run it in separate processes and compare its output to check process-to-process repeatability.

## Video and Media Validation

```sh
/usr/bin/time -l .build/release/ilyric video artifacts/spike.mp4
python3 scripts/validate_media.py artifacts/spike.mp4
```

The default video is four seconds, 240 frames, 1080×1920, exactly 60 fps, H.264 with mono 48 kHz AAC audio. The renderer supplies Rec.709 pixels and metadata. The original artwork, text, controls, transitions, materials, word timings, and audio are synthetic. Nothing establishes native iOS 27 behavior.

The optional positional scale is `1` or `2`; the optional frame count is from `1` through `36000`. Longer runs repeat the four-second scene and PCM fixture while preserving monotonic output timestamps. These arguments exist only for scalability and memory experiments.

```sh
.build/release/ilyric video artifacts/scale.mp4 2 240
python3 scripts/validate_media.py artifacts/scale.mp4 2160 3840 240
```

A ten-minute repetition exercises sustained memory and timestamp drift:

```sh
/usr/bin/time -l .build/release/ilyric video artifacts/long.mp4 1 36000
python3 scripts/validate_media.py artifacts/long.mp4 1080 1920 36000
python3 scripts/compare_frame.py artifacts/seek.png artifacts/spike.mp4 75
```

The validation scripts require local `ffmpeg` and `ffprobe`; rendering itself does not. The frame comparison uses the still at `5/4` seconds and video frame 75, with explicit synthetic compression tolerances. Plain decoded PNGs may lack the original transfer profile; use FFmpeg’s `colorspace=all=bt709:trc=srgb:format=yuv444p` filter for an sRGB viewing copy, not for the nonlinear Rec.709 pixel comparison.

Outputs must not already exist. Video output is finalized at a temporary sibling path before being moved into place. Still output is written directly; interruption may leave a partial PNG. Generated media and diagnostic logs belong in ignored `artifacts/` and must not be committed.

## Fixture Timing

| Output Time | Synthetic Behavior |
|---|---|
| 0 s | Latin focus; first word begins highlighting; audio and visual marker |
| 1 s | Focus starts moving toward Japanese; marker |
| 1.25 s | Media seeks to 0.25 s; focus motion is interrupted with continuous position and velocity; marker |
| 3 s | Focus moves toward Japanese again; marker |
| 3.6 s | Explicit lyric gap dims both paragraphs |

Eight Latin words have authored quarter-second media intervals. The highlight clips the cached paragraph raster using Core Text offsets without reshaping at timing boundaries. This mapping is sufficient for the original Latin fixture; it does not implement general bidirectional text, ligature splitting, syllable timing, or a native interchange schema.
