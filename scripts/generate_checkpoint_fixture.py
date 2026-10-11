#!/usr/bin/env python3
"""Write a tiny synthetic PyTorch checkpoint and its expected tensors for the native checkpoint reader tests.

The structure mimics a Demucs package: a class reference, arguments with a Fraction, and a half-precision state
dictionary including a non-contiguous tensor. No model weights are involved.
"""
import json
import sys
from collections import OrderedDict
from fractions import Fraction
from pathlib import Path
import torch


def main(directory):
    directory = Path(directory)
    g = torch.Generator().manual_seed(7)
    a = torch.randn(3, 4, generator=g).half()
    b = torch.randn(4, 3, generator=g).half().t()  # non-contiguous view
    c = torch.randn(6, 2, generator=g).float()
    state = OrderedDict(a=a, b=b, c=c)
    pkg = dict(klass=OrderedDict, args=[1], kwargs=dict(segment=Fraction(39, 5), name='synthetic'), state=state)
    torch.save(pkg, directory/'checkpoint.th')
    expected = {k: dict(shape=list(v.shape), values=v.float().contiguous().flatten().tolist()) for k, v in state.items()}
    (directory/'checkpoint.json').write_text(json.dumps(expected) + '\n')


if __name__ == '__main__':
    main(sys.argv[1])
