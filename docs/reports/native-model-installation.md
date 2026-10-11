# Native Model Installation and Decoding

## Outcome and Scope

October 11, 2026. **Both alignment models now install on the user's Mac from their official files, and the native pipeline runs end to end from an audio file without FFmpeg or Python.** This report follows [Native Alignment Pipeline](native-alignment-pipeline.md), which established exact parity of the Swift implementation with the Python reference and the on-device rebuilding of the HTDemucs weights.

Measurements: Apple M4, macOS 27.0.1, Core ML on the CPU.

## Recognition Model Installation

`scripts/build_recognition_template.py` strips the weights from the Core ML conversion of `facebook/wav2vec2-base-960h`. Of 211 weight entries, 210 are tensors of the pinned `model.safetensors` file, copied unchanged; one is the positional convolution weight, which conversion folds from its weight-norm parameters as v·g/‖v‖. The template keeps a 0.37-MB compressed skeleton, the recipe, and a self-test: two seconds of a synthetic signal with the reference conversion's log-probabilities.

`RecognitionInstaller` verifies the safetensors file's SHA-256, reads it, copies each direct entry and checks its SHA-256, recomputes the weight-normalized convolution in double precision, compiles the model, and requires the self-test to reproduce every frame label and every log-probability within 10⁻³. Installation took 1.5 s. With both models installed this way, the recording used throughout aligned identically to the Python pipeline in all 72 lines and 501 word boundaries.

## Downloads

`ModelStore` downloads a pinned file into the user's Application Support directory, keeps it only when its SHA-256 matches, and reuses a verified copy. Header requests confirmed that the Demucs and Hugging Face URLs serve files of the pinned sizes, 84,141,911 and 377,607,901 bytes, and that the Hugging Face ETag equals the pinned SHA-256. Tests cover download, replacement of a corrupted cache entry, and refusal of a mismatched pin.

## Decoding Without FFmpeg

`readStereo44k` decodes and resamples with AVFoundation at mastering quality. On the same five-minute recording, decoded from its original 96-kHz Apple Lossless file:

| Measure | Result |
| --- | ---: |
| Line estimates identical to the FFmpeg-decoded Python reference | 71 of 72 (the other differs by one 20-ms frame) |
| Word boundaries identical / within 20 ms / within 100 ms | 496 / 499 / 500 of 501 |
| Largest word boundary difference | 0.18 s |
| Decoding / separation / recognition and alignment | 6.6 / 42.6 / 11.5 s |
| Peak memory | 3.6 GB |

The differences are well below the accuracy measured against human annotations, so FFmpeg is not required.

## Limitations

The decoding comparison covers one recording. Peak memory is high because intermediate signals are held in double precision. The converted templates are produced on the maintainer's machine and are not yet distributed; distribution of the HTDemucs template, which contains no checkpoint values, and the license notices for wav2vec2 remain to be settled before release.

Neither release readiness nor native iOS 27 Music fidelity is established.
