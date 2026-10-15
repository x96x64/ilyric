# Japanese Alignment

Date: October 15, 2026

## Summary

iLyrics 1.3.0 aligns Japanese plain lyrics with `--language ja` as an experimental feature. The first Japanese recognition model, a speech-trained XLSR fine-tune, recognized too little of sung Japanese to support alignment. The ReazonSpeech wav2vec 2.0 model recognized substantially more, and with acceptance of every forced alignment it produced timing that the maintainer judged usable after reviewing rendered videos, with known limitations. No locked quantitative criterion was defined or met; this report records an engineering decision, not a qualification.

## Material

The evaluation used five songs from one commercially released Japanese pop album, supplied privately by the maintainer as lossless audio at 96 kHz with lyrics files written by the maintainer. Audio, lyrics, outputs, and review videos remain under the ignored `reference-private/` directory; this report contains no lyrics and does not name the recordings. The songs contain 306 lyric lines in total, of which one song with 56 lines was used for the visual reviews. No manual reference timing was measured, so line and word accuracy is not quantified.

Environment: Apple M4, 16 GB memory, macOS 27.0.1, Swift 6.4, CPU inference.

## Alignment Method

Each Japanese character known to the model is one alignment unit with its own CTC label, without word separators, because the Japanese models rarely emit their delimiter. A word containing a character unknown to the model is aligned as one unit by its hiragana reading, obtained from `CFStringTokenizer` and converted with `CFStringTransform`; the readings used are recorded in the alignment report because tokenizer output may change between macOS versions. Runs of digits known to the model are aligned as labels. Runs of Latin letters cannot be recognized by the model and are timed by interpolation: each run lasts its estimated syllable count multiplied by the line's pace, the median duration of its aligned units clamped to 120–400 ms. Latin words that begin a line may extend back to 100 ms after the start of the previous line's last aligned character, and the previous line ends there. The fill of each unit is bridged to the next aligned unit so that characters do not flash.

## Recognition Models

| Model | Labels | Characters matched by greedy recognition on separated vocals of one song | Lines accepted by the English acceptance rules |
| --- | --- | --- | --- |
| `jonatasgrosman/wav2vec2-large-xlsr-53-japanese` | 2,341 | about 4% | 27 of 306 (five songs) |
| `reazon-research/japanese-wav2vec2-large-rs35kh` | 3,003 | 29 of 86 emitted characters, about 34% precision | 11 of 56 (one song) |

With the XLSR model, acoustic support on separated vocals had a median of −7.4 against the English acceptance threshold of −3.0. Replacing written kanji with kana readings for the whole line did not change the result on the reviewed song, so the target representation was not the main limitation. With ReazonSpeech the median support was −5.0. The ReazonSpeech model is released under the Apache License, Version 2.0, at revision `2162c9edb97f362f7623d6b3a2e417458e879bca`; its training corpus may be used solely for the purposes of Article 30-4 of the Japanese Copyright Act. Its Core ML conversion differed from the PyTorch reference by at most 6.5 × 10⁻⁵ in log-probability and took 2.73 seconds per 30 seconds of audio on the CPU.

## Acceptance Policy

The English acceptance thresholds rejected most Japanese lines even where the forced path looked plausible, and they are not calibrated for Japanese. Japanese alignment therefore accepts every complete forced proposal and keeps word timing only where it lies inside its line. A warning on every Japanese run states the known limitations.

## Review Results

| Configuration | Lines aligned on the reviewed song | Maintainer judgement |
| --- | --- | --- |
| XLSR, every proposal accepted | 55 of 56 | About 70% of lines felt misaligned; instrumental breaks were not recognized |
| ReazonSpeech, every proposal accepted | 55 of 56 | Substantially accurate; English-led lines started late and characters flashed |
| ReazonSpeech with Latin interpolation and bridged fill | 55 of 56 | Flashing resolved; English-led lines and line changes remained imperfect |

The remaining omitted line is a vocable-only line. With the installed model, the reviewed song took 4.5 seconds to decode, 29.1 seconds to separate, and 20.6 seconds to align.

## Limitations and Next Steps

Lines that begin with English words may still start late, and line changes may come slightly early or late. Acceptance is not evidence-based, so misaligned lines are not flagged. The evaluation covered one album and one reviewer, without reference timing. Japanese typography, line wrapping, and fill have not been compared with the native screen on iOS 27. The Japanese timing limitations are currently targeted for v1.4.0; a quantitative Japanese qualification would require reference timing measured on our side.
