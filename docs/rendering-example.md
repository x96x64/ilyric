# Rendering a Supplied-Timing Example

This local example uses original English text, synthetic timing, and generated stereo tones. It demonstrates input and video export, not automatic synchronization or measured singing accuracy. It requires an installed `ilyrics` command, a repository checkout, and Python 3 for the existing audio generator. Python is needed only to generate this fixture; iLyrics itself remains native Swift and Core ML.

## Generate and Render

From the repository root, use a new output directory:

```bash
mkdir -p artifacts
mkdir artifacts/quick-start
python3 scripts/generate_local_audio.py artifacts/quick-start/source.wav
ilyrics render artifacts/quick-start/source.wav fixtures/demo/timed-example.ttml \
  -o artifacts/quick-start/video.mp4 --title "Paper Skies" --artist "iLyrics Example" \
  --report artifacts/quick-start/render.json
```

For a source checkout without an installed command, build with `swift build -c release --product ilyrics` and substitute `.build/release/ilyrics` for `ilyrics`. Run these commands from the repository root. If `artifacts/quick-start` already exists, choose a different new directory; the audio generator refuses to overwrite its output.

## Expected Result

The output is a 1080 × 1920 H.264 video at 60 fps with stereo AAC audio. The generated audio lasts 10.003 seconds, producing 601 video frames, approximately 10.017 seconds. The command reports separation and alignment as skipped and does not install or run alignment models. The sound consists of tones and short markers; no voice sings the displayed words.

`Paper skies` has supplied timing from 0.5 to 2.5 seconds, and `Morning light` from 3 to 5.5 seconds. The renderer applies its normal focus and fill presentation to these intervals. The report has format `ilyrics-render-report-1` and contains export metrics without an `alignment` object. See [Input Formats](input-formats.md) and [Reviewing an Alignment](reviewing-alignment.md).

Generated audio, reports, and videos remain in ignored `artifacts/`. This procedure does not add a public demonstration video or extend the existing policy on public media. The command resolves SF Symbols on the local Mac; the existing [rights notice](../README.md#sf-symbols-and-rights) continues to apply.
