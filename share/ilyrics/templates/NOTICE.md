# Model Templates

These files let iLyrics rebuild its two alignment models on the user's Mac. They contain the converted Core ML network structures, zero-filled weight skeletons, and recipes, but no trained weights.

## HTDemucs

`htdemucs-template.mlpackage`, `weight-skeleton.bin.zlib`, and `weight-recipe.json` describe the HTDemucs vocal separation network of [Demucs](https://github.com/facebookresearch/demucs) by Meta AI Research, released under the MIT License. Every checkpoint-derived value, including small tensors stored inline in the program, is replaced by zeros or a recorded sentinel. Installation downloads the pinned checkpoint `955717e8-8726e21a.th` from Meta, verifies its SHA-256, restores the values, and requires the rebuilt program and weights to match the reference conversion byte for byte.

## wav2vec 2.0

`wav2vec2-template.mlpackage`, `wav2vec2-skeleton.bin.zlib`, and `wav2vec2-recipe.json` describe [facebook/wav2vec2-base-960h](https://huggingface.co/facebook/wav2vec2-base-960h) by Meta AI, released under the Apache License, Version 2.0. Installation downloads `model.safetensors` and `vocab.json` at a pinned revision from Hugging Face, verifies their SHA-256, and requires the rebuilt model to pass a recorded self-test. The self-test expectations in the recipe are outputs of the converted model on a synthetic signal.

## Reproduction

The templates are produced from reference conversions by `scripts/build_separation_template.py` and `scripts/build_recognition_template.py`.
