#!/usr/bin/env python3
"""Build a weightless Japanese wav2vec2 Core ML template, its weight recipe, and a functional self-test.

Inputs (maintainer only): the pinned pytorch_model.bin and the files beside it from
jonatasgrosman/wav2vec2-large-xlsr-53-japanese. The publisher provides weights only as a PyTorch ZIP archive, so the
recipe locates every tensor as a byte range of a stored (uncompressed) archive entry; the installer on the user's Mac
then needs a ZIP reader, not a pickle parser. Output: the converted network without weights, a zero-filled skeleton,
and a recipe whose entries are verified by SHA-256, with a self-test from the reference conversion.
"""
import hashlib
import json
import pickle
import shutil
import struct
import sys
import zipfile
import zlib
from pathlib import Path
import numpy as np
import coremltools as ct
import torch
from transformers import Wav2Vec2ForCTC

WEIGHTS = 'Data/com.apple.CoreML/weights/weight.bin'


def entries(blob):
    """(header offset, data offset, size, dtype) of every MIL blob entry, in file order (as build_separation_template)."""
    out, pos = [], 64
    while pos + 64 <= len(blob):
        sentinel, dtype, size, offset = struct.unpack_from('<IIQQ', blob, pos)
        if sentinel != 0xDEADBEEF:
            break
        out.append((pos, offset, size, dtype))
        pos = (offset + size + 63) // 64 * 64
    return out


def self_test_input():
    """Two seconds of a deterministic synthetic signal, normalized as the feature extractor does."""
    t = np.arange(32000) / 16000
    x = 0.3 * np.sin(2 * np.pi * 220 * t) * np.sin(2 * np.pi * 3 * t) + 0.1 * np.sin(2 * np.pi * 1330 * t)
    return ((x - x.mean()) / np.sqrt(x.var() + 1e-7)).astype(np.float32)

REVISION = 'cf031e020336460d15a417eba710bbc5bb43be9a'
BASE = f'https://huggingface.co/jonatasgrosman/wav2vec2-large-xlsr-53-japanese/resolve/{REVISION}/'


def archive_tensors(path):
    """Name → (absolute byte offset, byte size, shape) of every contiguous float32 tensor in a PyTorch ZIP archive."""
    archive = zipfile.ZipFile(path)
    names = archive.namelist()
    root = names[0].split('/')[0]
    starts = {}
    with open(path, 'rb') as f:
        for info in archive.infolist():
            if info.compress_type != zipfile.ZIP_STORED:
                raise SystemExit(f'{info.filename} is compressed; the installer reads stored entries only')
            f.seek(info.header_offset)
            header = f.read(30)
            name_length, extra_length = struct.unpack_from('<HH', header, 26)
            starts[info.filename] = info.header_offset + 30 + name_length + extra_length

    class Storage:
        def __init__(self, key):
            self.key = key

    def rebuild(storage, offset, size, stride, *_):
        expected, step = [], 1
        for n in reversed(size):
            expected.insert(0, step)
            step *= n
        if list(stride) != expected and int(np.prod(size)) > 1:
            raise SystemExit(f'non-contiguous tensor in storage {storage.key}')
        return (storage.key, offset, tuple(size))

    class Reader(pickle.Unpickler):
        def find_class(self, module, name):
            if name == '_rebuild_tensor_v2':
                return rebuild
            if module == 'collections' and name == 'OrderedDict':
                import collections
                return collections.OrderedDict
            if name == 'FloatStorage' or name == 'UntypedStorage':
                return name
            return super().find_class(module, name)

        def persistent_load(self, pid):
            kind, storage_type, key, _location, _size = pid
            if storage_type not in ('FloatStorage',):
                raise SystemExit(f'unsupported storage type {storage_type}')
            return Storage(key)

    state = Reader(archive.open(f'{root}/data.pkl')).load()
    out = {}
    for name, (key, offset, shape) in state.items():
        entry = f'{root}/data/{key}'
        out[name] = (starts[entry] + 4 * offset, 4 * int(np.prod(shape)), shape)
    return out


def main(checkpoint_dir, out):
    checkpoint_dir, out = Path(checkpoint_dir), Path(out)
    archive = checkpoint_dir / 'pytorch_model.bin'
    raw = archive.read_bytes()
    located = archive_tensors(archive)
    tensors = {name: np.frombuffer(raw[o:o + n], '<f4').reshape(shape) for name, (o, n, shape) in located.items()}

    model = Wav2Vec2ForCTC.from_pretrained(checkpoint_dir, attn_implementation='eager').eval()

    class LogProbs(torch.nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m

        def forward(self, input_values):
            return torch.log_softmax(self.m(input_values).logits, dim=-1)

    x = self_test_input()
    with torch.no_grad():
        traced = torch.jit.trace(LogProbs(model).eval(), torch.from_numpy(x[None]))
    reference = ct.convert(
        traced, inputs=[ct.TensorType(name='input_values', shape=(1, ct.RangeDim(16000, 480000, default=32000)))],
        outputs=[ct.TensorType(name='log_probs')], compute_precision=ct.precision.FLOAT32,
        minimum_deployment_target=ct.target.macOS14, convert_to='mlprogram')
    staging = out / 'ja-wav2vec2-reference.mlpackage'
    if staging.exists():
        shutil.rmtree(staging)
    reference.save(str(staging))

    candidates = {}
    for name, v in tensors.items():
        candidates.setdefault(hashlib.sha256(np.ascontiguousarray(v).tobytes()).hexdigest(), dict(kind='tensor', key=name))
        if v.ndim == 2:
            candidates.setdefault(hashlib.sha256(np.ascontiguousarray(v.T).tobytes()).hexdigest(),
                                  dict(kind='permute', key=name, axes=[1, 0]))
    prefix = 'wav2vec2.encoder.pos_conv_embed.conv.'
    g, v = tensors[prefix + 'weight_g'], tensors[prefix + 'weight_v']
    normalized = v * (g / np.sqrt((v.astype(np.float64) ** 2).sum(axis=(0, 1), keepdims=True)).astype(np.float32))
    blob = (staging / WEIGHTS).read_bytes()
    skeleton = bytearray(blob)
    recipe = []
    for header, offset, size, dtype in entries(blob):
        data = blob[offset:offset + size]
        digest = hashlib.sha256(data).hexdigest()
        if dtype == 2 and digest in candidates:
            recipe.append(dict(offset=offset, size=size, sha256=digest, **candidates[digest]))
        elif dtype == 2 and size == normalized.nbytes and np.allclose(
                np.frombuffer(data, '<f4'), normalized.ravel(), rtol=1e-4, atol=1e-4):
            recipe.append(dict(offset=offset, size=size, kind='weight_norm', key=prefix + 'weight_v',
                               g=prefix + 'weight_g', dim=2))
        else:
            raise SystemExit(f'Unexplained weight entry at {offset} ({size} bytes); refusing to build a template')
        skeleton[offset:offset + size] = bytes(size)
    used = {r['key'] for r in recipe} | {r['g'] for r in recipe if 'g' in r}
    template = out / 'ja-wav2vec2-template.mlpackage'
    if template.exists():
        shutil.rmtree(template)
    shutil.copytree(staging, template, ignore=shutil.ignore_patterns('weight.bin'))
    (out / 'ja-wav2vec2-skeleton.bin.zlib').write_bytes(zlib.compress(bytes(skeleton), 9))
    expected = ct.models.MLModel(str(staging), compute_units=ct.ComputeUnit.CPU_ONLY).predict(
        {'input_values': x[None]})['log_probs'][0]
    vocabulary = (checkpoint_dir / 'vocab.json').read_bytes()
    manifest = dict(
        format='ilyrics-weight-recipe-1', model='wav2vec2-large-xlsr-53-japanese',
        checkpoint=dict(file='pytorch_model.bin', layout='pytorch-zip-stored',
                        sha256=hashlib.sha256(raw).hexdigest(), size=len(raw), url=BASE + 'pytorch_model.bin',
                        vocabulary_url=BASE + 'vocab.json', vocabulary_sha256=hashlib.sha256(vocabulary).hexdigest()),
        tensors={name: dict(offset=located[name][0], size=located[name][1], shape=list(located[name][2]))
                 for name in sorted(used)},
        weights=dict(size=len(blob), skeleton_sha256=hashlib.sha256(bytes(skeleton)).hexdigest()),
        # With 2,341 labels, every log-probability would make the recipe several megabytes; each frame's best label
        # and its log-probability verify the installed model as well.
        self_test=dict(samples=len(x), frames=int(expected.shape[0]), labels=int(expected.shape[1]),
                       best=[int(k) for k in expected.argmax(-1)],
                       best_log_probs=[float(v) for v in expected.max(-1)], tolerance=1e-3),
        entries=recipe)
    (out / 'ja-wav2vec2-recipe.json').write_text(json.dumps(manifest) + '\n')
    shutil.rmtree(staging)
    print(json.dumps(dict(entries=len(recipe), tensors=len(used),
                          kinds={k: sum(r['kind'] == k for r in recipe) for k in {r['kind'] for r in recipe}})))


if __name__ == '__main__':
    main(*sys.argv[1:3])
