#!/usr/bin/env python3
"""Build a weightless wav2vec2 Core ML template, its weight recipe, and a functional self-test.

Inputs (maintainer only): the reference Core ML conversion of facebook/wav2vec2-base-960h and the pinned
model.safetensors. Output: the converted network without weights, a zero-filled skeleton, and a recipe that rebuilds
the weights from the published safetensors file on the user's Mac. Directly copied entries are verified by SHA-256;
the weight-normalized positional convolution is recomputed and verified, with the whole model, by a self-test whose
expected log-probabilities come from the reference conversion.
"""
import hashlib
import json
import shutil
import sys
import zlib
from pathlib import Path
import numpy as np
import coremltools as ct
from safetensors.numpy import load_file
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_separation_template import WEIGHTS, entries

REVISION = '22aad52d435eb6dbaf354bdad9b0da84ce7d6156'
BASE = f'https://huggingface.co/facebook/wav2vec2-base-960h/resolve/{REVISION}/'


def self_test_input():
    """Two seconds of a deterministic synthetic signal, normalized as the feature extractor does."""
    t = np.arange(32000) / 16000
    x = 0.3 * np.sin(2 * np.pi * 220 * t) * np.sin(2 * np.pi * 3 * t) + 0.1 * np.sin(2 * np.pi * 1330 * t)
    return ((x - x.mean()) / np.sqrt(x.var() + 1e-7)).astype(np.float32)


def main(reference, weights, out):
    reference, out = Path(reference), Path(out)
    state = {k: v.astype(np.float32) for k, v in load_file(weights).items()}
    candidates = {}
    for name, v in state.items():
        candidates.setdefault(hashlib.sha256(np.ascontiguousarray(v).tobytes()).hexdigest(), dict(kind='tensor', key=name))
        if v.ndim == 2:
            candidates.setdefault(hashlib.sha256(np.ascontiguousarray(v.T).tobytes()).hexdigest(),
                                  dict(kind='permute', key=name, axes=[1, 0]))
    prefix = 'wav2vec2.encoder.pos_conv_embed.conv.'
    g, v = state[prefix + 'weight_g'], state[prefix + 'weight_v']
    normalized = v * (g / np.sqrt((v.astype(np.float64) ** 2).sum(axis=(0, 1), keepdims=True)).astype(np.float32))
    blob = (reference / WEIGHTS).read_bytes()
    skeleton = bytearray(blob)
    recipe = []
    for header, offset, size, dtype in entries(blob):
        data = blob[offset:offset + size]
        digest = hashlib.sha256(data).hexdigest()
        if dtype == 2 and digest in candidates:
            recipe.append(dict(offset=offset, size=size, sha256=digest, **candidates[digest]))
        elif dtype == 2 and size == normalized.nbytes and np.allclose(np.frombuffer(data, '<f4'), normalized.ravel(), rtol=1e-5, atol=1e-7):
            recipe.append(dict(offset=offset, size=size, kind='weight_norm', key=prefix + 'weight_v', g=prefix + 'weight_g', dim=2))
        else:
            raise SystemExit(f'Unexplained weight entry at {offset} ({size} bytes); refusing to build a template')
        skeleton[offset:offset + size] = bytes(size)
    template = out / 'wav2vec2-template.mlpackage'
    if template.exists():
        shutil.rmtree(template)
    shutil.copytree(reference, template, ignore=shutil.ignore_patterns('weight.bin'))
    (out / 'wav2vec2-skeleton.bin.zlib').write_bytes(zlib.compress(bytes(skeleton), 9))
    x = self_test_input()
    model = ct.models.MLModel(str(reference), compute_units=ct.ComputeUnit.CPU_ONLY)
    expected = model.predict({'input_values': x[None]})['log_probs'][0]
    manifest = dict(format='ilyric-weight-recipe-1', model='wav2vec2-base-960h',
                    checkpoint=dict(file='model.safetensors', sha256=hashlib.sha256(Path(weights).read_bytes()).hexdigest(),
                                    url=BASE + 'model.safetensors', vocabulary_url=BASE + 'vocab.json'),
                    weights=dict(size=len(blob), skeleton_sha256=hashlib.sha256(bytes(skeleton)).hexdigest()),
                    self_test=dict(samples=len(x), frames=int(expected.shape[0]), labels=int(expected.shape[1]),
                                   log_probs=[float(v) for v in expected.ravel()], tolerance=1e-3),
                    entries=recipe)
    (out / 'wav2vec2-recipe.json').write_text(json.dumps(manifest) + '\n')
    print(json.dumps(dict(entries=len(recipe), kinds={k: sum(r['kind'] == k for r in recipe) for k in {r['kind'] for r in recipe}})))


if __name__ == '__main__':
    main(*sys.argv[1:4])
