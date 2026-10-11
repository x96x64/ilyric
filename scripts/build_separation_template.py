#!/usr/bin/env python3
"""Build a weightless HTDemucs Core ML template and its weight recipe.

Inputs (maintainer only, private): a reference conversion of the HTDemucs network made from the pinned checkpoint,
a conversion of the same architecture with random weights, and the pinned checkpoint. Output: the converted model
without any checkpoint-derived values, a zero-filled weight skeleton compressed with zlib, and a recipe that lets
iLyric rebuild the exact weight file from the official checkpoint on the user's Mac (docs/reports/core-ml-port-feasibility.md).

Every weight entry must be either derived from the checkpoint by a recorded transform or a constant that is
byte-identical in the random-weight conversion; anything else stops the build. Small tensors that Core ML stores
inline in the program (model.mlmodel) are treated the same way: checkpoint-derived values are replaced by recorded
sentinel values of equal length in the original bytes, which the installer restores, and any other difference from the random-weight
program stops the build.
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
from coremltools.proto import Model_pb2
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


PROGRAM = 'Data/com.apple.CoreML/model.mlmodel'


def inline_tensors(spec):
    """Inline float tensor constants of an ML program, by output name."""
    out = {}

    def walk(block):
        for op in block.operations:
            if op.type == 'const':
                value = op.attributes['val']
                if value.WhichOneof('value') == 'immediateValue' and value.immediateValue.WhichOneof('value') == 'tensor':
                    tensor = value.immediateValue.tensor
                    if tensor.WhichOneof('value') == 'floats':
                        out[op.outputs[0].name] = tensor.floats
            for inner in op.blocks:
                walk(inner)
    for function in spec.mlProgram.functions.values():
        for block in function.block_specializations.values():
            walk(block)
    return out


def sanitize_program(template, random_reference, candidates):
    """Replace checkpoint-derived inline tensors of the template program with unique sentinels."""
    path = template / PROGRAM
    original = path.read_bytes()
    spec, random_spec = Model_pb2.Model(), Model_pb2.Model()
    spec.ParseFromString(original)
    random_spec.ParseFromString((random_reference / PROGRAM).read_bytes())
    weightless = {tuple(np.float32(v) for v in values.values) for values in inline_tensors(random_spec).values()}
    recipe, sanitized = [], bytearray(original)
    for name, values in inline_tensors(spec).items():
        array = np.array(values.values, dtype=np.float32)
        if tuple(array) in weightless:
            continue
        derivation = candidates.get(key(array))
        if derivation is None:
            raise SystemExit(f'Unexplained inline constant {name}; refusing to build a template')
        # Packed repeated floats are stored contiguously, so the values are replaced in the original bytes;
        # re-serializing the parsed program would not preserve its byte order.
        found = bytes(sanitized).count(array.tobytes())
        if found != 1:
            raise SystemExit(f'Inline constant {name} occurs {found} times; refusing to build a template')
        sentinel = np.random.default_rng(len(recipe) + 1).uniform(-1e6, 1e6, array.size).astype(np.float32)
        position = bytes(sanitized).index(array.tobytes())
        sanitized[position:position + len(sentinel.tobytes())] = sentinel.tobytes()
        recipe.append(dict(name=name, count=int(array.size), sentinel=sentinel.tobytes().hex(), **derivation))
    for entry in recipe:
        if bytes(sanitized).count(bytes.fromhex(entry['sentinel'])) != 1:
            raise SystemExit(f'Sentinel for {entry["name"]} is not unique')
    path.write_bytes(bytes(sanitized))
    return recipe, hashlib.sha256(original).hexdigest()


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
    inline, program_sha256 = sanitize_program(template, random_reference, candidates)
    manifest = dict(format='ilyric-weight-recipe-1', model='htdemucs', checkpoint=dict(
        file='955717e8-8726e21a.th', sha256=hashlib.sha256(Path(checkpoint).read_bytes()).hexdigest(),
        url='https://dl.fbaipublicfiles.com/demucs/hybrid_transformer/955717e8-8726e21a.th'),
        weights=dict(size=len(blob), sha256=hashlib.sha256(blob).hexdigest(),
                     skeleton_sha256=hashlib.sha256(bytes(skeleton)).hexdigest()),
        program=dict(sha256=program_sha256, inline_entries=inline),
        derived_entries=len(recipe), constant_entries=constants, entries=recipe)
    (out / 'weight-recipe.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print(json.dumps(dict(derived=len(recipe), constants=constants, inline=len(inline),
                          kinds={k: sum(r['kind'] == k for r in recipe) for k in {r['kind'] for r in recipe}})))


if __name__ == '__main__':
    main(*sys.argv[1:5])
