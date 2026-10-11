#!/usr/bin/env python3
"""Build a weightless HTDemucs Core ML template and its weight recipe.

Inputs (maintainer only, private): a reference conversion of the HTDemucs network made from the pinned checkpoint,
a conversion of the same architecture with random weights, and the pinned checkpoint. Output: the converted model
without any checkpoint-derived values, a zero-filled weight skeleton compressed with zlib, and a recipe that lets
iLyric rebuild the exact weight file from the official checkpoint on the user's Mac (docs/core-ml-port-feasibility.md).

Every weight entry must be either derived from the checkpoint by a recorded transform or a constant that is
byte-identical in the random-weight conversion; anything else stops the build.
"""
import hashlib
import json
import shutil
import struct
import sys
import zlib
from itertools import permutations
from pathlib import Path
import numpy as np
import torch
from demucs.states import load_model

WEIGHTS = 'Data/com.apple.CoreML/weights/weight.bin'


def entries(blob):
    """(header offset, data offset, size, dtype) of every MIL blob entry, in file order."""
    out, pos = [], 64
    while pos + 64 <= len(blob):
        sentinel, dtype, size, offset = struct.unpack_from('<IIQQ', blob, pos)
        if sentinel != 0xDEADBEEF:
            break
        out.append((pos, offset, size, dtype))
        pos = (offset + size + 63) // 64 * 64
    return out


def key(a):
    return hashlib.sha256(np.ascontiguousarray(a, dtype=np.float32).tobytes()).hexdigest()


def main(reference, random_reference, checkpoint, out):
    reference, random_reference, out = Path(reference), Path(random_reference), Path(out)
    pkg = torch.load(checkpoint, map_location='cpu', weights_only=False)
    model = load_model(pkg).eval()
    state = {k: v.detach().float().numpy() for k, v in model.state_dict().items()}
    candidates = {}

    def add(array, recipe):
        candidates.setdefault(key(array), recipe)
    for name, v in state.items():
        add(v, dict(kind='tensor', key=name))
        for axes in permutations(range(v.ndim)):
            if v.ndim >= 2 and axes != tuple(range(v.ndim)):
                add(v.transpose(axes), dict(kind='permute', key=name, axes=list(axes)))
        if v.ndim >= 1 and v.shape[0] % 3 == 0:
            third = v.shape[0] // 3
            for i in range(3):
                add(v[i * third:(i + 1) * third], dict(kind='rows', key=name, start=i * third, end=(i + 1) * third))
            add(v[third:], dict(kind='rows', key=name, start=third, end=v.shape[0]))
    # The frequency embedding is folded into one expanded constant at conversion.
    frames, bins = 336, 512
    with torch.no_grad():
        emb = model.freq_emb(torch.arange(bins)).t()[None, :, :, None].expand(1, -1, bins, frames) * model.freq_emb_scale
    add(emb.numpy(), dict(kind='frequency_embedding', key='freq_emb.embedding.weight', bins=bins, frames=frames,
                          scale=float(model.freq_emb.scale), outer_scale=float(model.freq_emb_scale)))
    blob = (reference / WEIGHTS).read_bytes()
    random_blob = (random_reference / WEIGHTS).read_bytes()
    random_values = {hashlib.sha256(random_blob[o:o + s]).hexdigest() for _, o, s, _ in entries(random_blob)}
    skeleton = bytearray(blob)
    recipe, constants = [], 0
    for header, offset, size, dtype in entries(blob):
        digest = hashlib.sha256(blob[offset:offset + size]).hexdigest()
        if dtype == 2 and digest in candidates:  # 2: float32 in the MIL blob format
            skeleton[offset:offset + size] = bytes(size)
            recipe.append(dict(offset=offset, size=size, **candidates[digest]))
        elif digest in random_values:
            constants += 1  # weight-independent: kept in the skeleton
        else:
            raise SystemExit(f'Unexplained weight entry at {offset} ({size} bytes); refusing to build a template')
    template = out / 'htdemucs-template.mlpackage'
    if template.exists():
        shutil.rmtree(template)
    shutil.copytree(reference, template, ignore=shutil.ignore_patterns('weight.bin'))
    (out / 'weight-skeleton.bin.zlib').write_bytes(zlib.compress(bytes(skeleton), 9))
    manifest = dict(format='ilyric-weight-recipe-1', model='htdemucs', checkpoint=dict(
        file='955717e8-8726e21a.th', sha256=hashlib.sha256(Path(checkpoint).read_bytes()).hexdigest(),
        url='https://dl.fbaipublicfiles.com/demucs/hybrid_transformer/955717e8-8726e21a.th'),
        weights=dict(size=len(blob), sha256=hashlib.sha256(blob).hexdigest(),
                     skeleton_sha256=hashlib.sha256(bytes(skeleton)).hexdigest()),
        derived_entries=len(recipe), constant_entries=constants, entries=recipe)
    (out / 'weight-recipe.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print(json.dumps(dict(derived=len(recipe), constants=constants,
                          kinds={k: sum(r['kind'] == k for r in recipe) for k in {r['kind'] for r in recipe}})))


if __name__ == '__main__':
    main(*sys.argv[1:5])
