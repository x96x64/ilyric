# iLyric Local Input Experiment Commands

## Original Fixture and Render

```sh
swift build -c release
mkdir -p artifacts/local-input
python3 scripts/generate_local_audio.py artifacts/local-input/source.wav
.build/release/LyricsInputProbe render \
  --lyrics fixtures/local-input/lines.lrc \
  --audio artifacts/local-input/source.wav \
  --output artifacts/local-input/lyrics.mp4
python3 scripts/validate_local_input.py \
  artifacts/local-input/lyrics.mp4 artifacts/local-input/source.wav 601
```

Use new output filenames. The LRC contains original Latin/Japanese text, supplied multiline boundaries, an empty gap, a +125-ms offset, and a final hold. The generator produces original 44.1-kHz stereo PCM with distinct channel tones, leading/trailing silence, and audio-only synchronization pulses. Those pulses are supplied fixture content; normal rendering adds neither synthetic replacement audio nor diagnostic flashes.

For independent local files, replace the two input paths. No network, subscription, private reference, FFmpeg, or Python dependency is needed by the Swift renderer. FFmpeg/ffprobe are needed by the validation commands. Read the [input contract](local-input-subset.md) before preparing files: this is a restricted LRC subset with an explicit `|` continuation extension, resource bounds, and line-only synchronization. It is not a stable public command or finalized project format.

## Public Verification

```sh
./scripts/test.sh
python3 -m unittest discover -s Tests/reference_validation -v
python3 scripts/check_local_input.py
```

The integration check generates WAV, AIFF, and AAC inputs in a temporary directory, renders each complete ten-second sequence, validates all video timestamps and supplied-audio content, and checks input errors, output refusal, and temporary-file cleanup. It requires the release build and local FFmpeg tools. Gain-independent waveform agreement accommodates the documented equal-weight stereo conversion and AAC quantization; it is not a lossless-audio claim. Audio-only marker alignment is measured at one-millisecond resolution. Synthetic state tests independently verify exact off-frame lyric timing, focus boundaries, final holds, cache eviction, and random-order raster equality.

The general `validate_media.py` remains dedicated to the original synthetic audiovisual-marker scenes. It must not be used to demand those flashes in normal local-input output. Existing probe, typography, appearance, motion, composition, private-input-unavailable, and export regressions remain applicable.
