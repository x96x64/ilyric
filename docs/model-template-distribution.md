# Model Template Distribution

## Outcome

October 11, 2026. **The weightless model templates are distributed in the repository under `share/ilyric/templates`, after a pre-publication audit found and removed checkpoint-derived values that the HTDemucs template still contained.** The maintainer chose repository distribution over release assets so that a source checkout can install the alignment models without further downloads from this project.

## Audit Finding

[Native Model Installation and Decoding](native-model-installation.md) described both templates as free of checkpoint values. That statement was correct for the weight files but incomplete for the HTDemucs program. Core ML stores small constant tensors inline in the program file (`model.mlmodel`) rather than in the weight file. A comparison of every inline float tensor with the random-weight conversion of the same architecture showed:

| Template | Inline float tensors that differ from the random-weight program | Derived from the checkpoint |
| --- | ---: | ---: |
| HTDemucs | 25 (152 values) | 25 |
| wav2vec 2.0 | 0 | 0 |

The 25 HTDemucs tensors are convolution biases and group-normalization parameters of the residual branches in the outermost encoder and decoder layers, and one transposed-convolution bias; each has six or eight values and equals one checkpoint tensor exactly. The templates built before this audit were never committed or published.

## Correction

`scripts/build_separation_template.py` now replaces each checkpoint-derived inline tensor in the original program bytes with a pseudo-random sentinel of equal length, verifies that each sentinel occurs exactly once, and records the tensor's checkpoint key and the SHA-256 of the original program. Byte-level replacement is required because re-serializing the parsed program changes its field order. The build stops on any inline tensor that is neither weight-independent nor derived from the checkpoint.

`SeparationInstaller` restores the values from the downloaded checkpoint and refuses the result unless the program matches the reference conversion byte for byte. After correction, none of the 25 original value sequences occurs in the template; a fresh installation produced a compiled program (`model.mil`) and weight file identical to the earlier installation from the unsanitized template. Only the compile-time metadata file `coremldata.bin` differed.

## Distributed Files

| File | Size | Content |
| --- | ---: | --- |
| `htdemucs-template.mlpackage` | 0.56 MB | Network structure with sentinels |
| `weight-skeleton.bin.zlib` | 3.0 MB | Zero-filled weights, blob headers, and six weight-independent constants identical to the random-weight conversion |
| `weight-recipe.json` | 0.07 MB | Checkpoint keys, transforms, offsets, sentinels, and digests |
| `wav2vec2-template.mlpackage` | 0.14 MB | Network structure |
| `wav2vec2-skeleton.bin.zlib` | 0.37 MB | Zero-filled weights |
| `wav2vec2-recipe.json` | 0.11 MB | Keys, digests, the pinned vocabulary digest, and a self-test |
| `NOTICE.md` | — | Provenance and licenses |

The wav2vec 2.0 self-test contains outputs of the converted model on a synthetic signal; the model is released under the Apache License, Version 2.0. Demucs is released under the MIT License; its checkpoint is still downloaded from Meta rather than redistributed, as decided by the maintainer.

## Limitations

The audit covers float tensors stored inline and in the weight file. Integer constants were not compared, because the architectures' integer constants are shapes, axes, and permutations rather than trained values. The templates depend on the Core ML program format produced by coremltools 9.0.
