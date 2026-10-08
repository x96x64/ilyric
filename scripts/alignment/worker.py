"""Optional local-only inference. Dependencies and weights are never downloaded here."""
import hashlib
import importlib.metadata
import os
import pathlib
import subprocess
import sys
import time
import wave
from fractions import Fraction

from .core import AlignmentError, canonical, digest, make_result, micros


class Unavailable(AlignmentError):
    pass


def file_hash(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def decode(audio, destination):
    if not audio.is_file() or audio.stat().st_size > 256 * 1024 * 1024:
        raise AlignmentError('Audio must be a readable local file no larger than 256 MiB')
    try:
        # Read at most 60 s plus one sample: reject, never silently trim a longer recording.
        subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-i', str(audio), '-map', '0:a:0',
                        '-vn', '-ac', '1', '-ar', '48000', '-t', '60.000021', '-c:a', 'pcm_s16le',
                        '-n', str(destination)], check=True, capture_output=True, timeout=90)
    except FileNotFoundError as e:
        raise Unavailable('FFmpeg is unavailable; install it separately') from e
    except subprocess.SubprocessError as e:
        raise AlignmentError('Audio decode failed or exceeded the time limit') from e
    with wave.open(str(destination)) as w:
        samples = w.getnframes()
    if not 0 < samples <= 2_880_000:
        raise AlignmentError('Prototype accepts complete recordings of at most 60 seconds; no automatic chunking')
    return round(Fraction(samples * 1_000_000, 48000))


def ctc_path(emissions, targets, blank=0):
    """CTC Viterbi alignment, including required blanks between repeated labels.

    The small trellis uses bounded standard-library storage.
    Blank frames may fill gaps. This is forced correspondence, not mismatch detection.
    """
    import math
    if not targets or len(targets) > 1500 or not emissions or len(emissions) > 3000:
        raise AlignmentError('CTC target/frame resource limit')
    labels = [blank]
    for target in targets:
        if target == blank or type(target) is not int or not 0 <= target < len(emissions[0]):
            raise AlignmentError('Invalid CTC target')
        labels.extend((target, blank))
    n = len(labels); scores = [-math.inf] * n; scores[0] = 0.0
    trace = []
    for emission in emissions:
        if len(emission) != len(emissions[0]) or any(math.isnan(float(x)) for x in emission):
            raise AlignmentError('Invalid acoustic emissions')
        choices = bytearray(n); following = [-math.inf] * n
        for j, label in enumerate(labels):
            value = scores[j]
            if j > 0 and scores[j-1] > value:
                value = scores[j-1]; choices[j] = 1
            if j > 1 and label != blank and label != labels[j-2] and scores[j-2] > value:
                value = scores[j-2]; choices[j] = 2
            following[j] = value + float(emission[label])
        trace.append(choices); scores = following
    state = n - 1 if scores[-1] >= scores[-2] else n - 2
    if not math.isfinite(scores[state]):
        raise AlignmentError('No complete CTC path; supplied text remains unaligned')
    intervals = [[] for _ in targets]
    for t in range(len(emissions) - 1, -1, -1):
        if state % 2:
            intervals[state // 2].append(t)
        state -= trace[t][state]
    if any(not x for x in intervals):
        raise AlignmentError('Incomplete CTC path')
    return [(min(x), max(x) + 1) for x in intervals]


def speech(audio, paragraphs, model):
    import numpy as np
    import torch
    from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
    import soundfile as sf
    import scipy.signal
    start = time.perf_counter()
    processor = Wav2Vec2Processor.from_pretrained(str(model), local_files_only=True)
    net = Wav2Vec2ForCTC.from_pretrained(str(model), local_files_only=True).eval()
    initialization = time.perf_counter() - start
    signal, rate = sf.read(audio)
    signal = scipy.signal.resample_poly(signal, 1, 3).astype(np.float32)
    words = []
    import re
    for paragraph in paragraphs:
        # Retain contractions as tokens; accents/other scripts explicitly unsupported.
        for word in re.findall(r"[A-Za-z]+(?:['’][A-Za-z]+)*", paragraph):
            words.append(word)
    expected = canonical('\n'.join(paragraphs))[0]
    if canonical(''.join(words))[0] != expected:
        raise AlignmentError('English speech baseline requires ASCII letters with optional apostrophes')
    text = '|'.join(w.replace('’', "'").upper() for w in words)
    vocab = processor.tokenizer.get_vocab()
    if any(c not in vocab for c in text):
        raise AlignmentError('Speech model cannot represent supplied pronunciation text')
    with torch.inference_mode():
        values = processor(signal, sampling_rate=16000, return_tensors='pt').input_values
        emissions = net(values).logits[0].log_softmax(-1).numpy()
    spans = ctc_path(emissions.tolist(), [vocab[c] for c in text], net.config.pad_token_id)
    units, index = [], 0
    for word in words:
        s = spans[index:index + len(word)]
        # 320 input samples per model step. No fitted phase correction.
        units.append({'text': word, 'begin_us': s[0][0] * 20000, 'end_us': s[-1][1] * 20000})
        index += len(word) + 1
    return units, {'initialization_seconds': initialization, 'model_grid_us': 20000,
                   'raw_mean_best_log_probability': float(emissions.max(axis=1).mean()),
                   'confidence_semantics': 'uncalibrated acoustic diagnostic; forced paths can be wrong'}


def singing(audio, paragraphs, model, vendor, language):
    import torch
    import onnxruntime
    onnxruntime.disable_telemetry_events()
    import lightning.pytorch as pl
    sys.path.insert(0, str(vendor.resolve()))
    from inference.api import load_inference_model
    from inference.data import AudioTextDataset
    from inference.module import ForcedAlignmentInferenceModule
    # Capture raw integer-frame intervals before upstream TextGrid repair/omission.
    class Capture(pl.Callback):
        def __init__(self):
            self.results = []
        def on_predict_batch_end(self, trainer, pl_module, outputs, batch, *args, **kwargs):
            self.results.extend(outputs)
    start = time.perf_counter()
    backend, vocabulary, config = load_inference_model(model / 'model.pt', scope=1)
    initialization = time.perf_counter() - start
    audio.with_suffix('.txt').write_text('\n'.join(paragraphs), encoding='utf-8')
    # Explicit local reduced dictionary prevents g2pflow's automatic full download.
    import unidic_lite
    for converter in config.g2p.converters:
        if converter.id == 'japanese-mecab':
            converter.kwargs['unidic_dir'] = unidic_lite.DICDIR
    dataset = AudioTextDataset({'input': audio}, config.g2p, model, vocabulary,
                              backend.sample_rate, language=[language], oov_handling='raise')
    item = dataset[0]
    if item.get('skip') or item.get('error'):
        return [], {'initialization_seconds': initialization, 'model_grid_us': 10000,
                    'phones': [], 'unavailable_alignment': item.get('error', item.get('warning', 'G2P rejected input'))}
    if item['words'].numel() > 3000 or item['paths'].numel() > 100000:
        raise AlignmentError('Pronunciation lattice exceeds bounded inference resources')
    capture = Capture()
    module = ForcedAlignmentInferenceModule(backend, score_unit='levenshtein', skip_penalty=0.5)
    trainer = pl.Trainer(accelerator='cpu', devices=1, logger=False, enable_checkpointing=False,
                         enable_progress_bar=True, callbacks=[capture], precision='32-true')
    loader = torch.utils.data.DataLoader([item], batch_size=1, num_workers=0, collate_fn=dataset.collate)
    trainer.predict(module, loader)
    if len(capture.results) != 1:
        raise AlignmentError('TIFA produced no complete result; check language, pronunciation, and dependencies')
    r = capture.results[0]
    frames = r['spans'].tolist(); ids = r['words'].tolist()
    step = Fraction(str(backend.timestep))
    if step != Fraction(1, 100):
        raise AlignmentError('Unsupported TIFA feature grid')
    units, skipped = [], 0
    for i, text in enumerate(r['texts'], 1):
        selected = [s for s, owner in zip(frames, ids) if owner == i]
        if not selected or any(a >= b for a, b in selected):
            skipped += 1
            units.append({'text': text, 'begin_us': 0, 'end_us': 0})
        else:
            units.append({'text': text, 'begin_us': int(selected[0][0]) * 10000,
                          'end_us': int(selected[-1][1]) * 10000})
    phones = [{'label': ph, 'word_index': owner - 1, 'begin_us': int(a) * 10000, 'end_us': int(b) * 10000}
              for ph, (a, b), owner in zip(r['phonemes'], frames, ids)]
    return units, {'initialization_seconds': initialization, 'model_grid_us': 10000,
                   'skipped_word_units': skipped, 'phones': phones,
                   'confidence_semantics': 'no calibrated confidence; skipped units retained as unresolved'}


def infer(audio, src, engine, model, vendor, language, work):
    normalized = ''.join(canonical(p)[0] for p in src['paragraphs'])
    if not normalized or len(normalized) > 1500:
        raise AlignmentError('At most 1,500 retained alignment characters are supported')
    audio = audio.resolve(); model = model.resolve() if model else None
    vendor = vendor.resolve() if vendor else None; work = work.resolve()
    # Disallow implicit Hub/network retrieval. TIFA model G2P resources must be local.
    os.environ.update(HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1', TOKENIZERS_PARALLELISM='false',
                      MPLCONFIGDIR=str(work / 'matplotlib'), NUMBA_CACHE_DIR=str(work / 'numba'))
    required = ['model.safetensors', 'config.json', 'vocab.json'] if engine == 'ctc' else ['model.pt', 'config.yaml', 'vocabulary.json']
    if model is None or any(not (model / x).is_file() for x in required):
        raise Unavailable('Local model/configuration files unavailable; download separately after license review')
    if engine == 'tifa' and (vendor is None or not (vendor / 'inference/api.py').is_file()):
        raise Unavailable('Pinned local TIFA source unavailable')
    import json
    manifest = pathlib.Path(__file__).resolve().parents[2] / 'docs/alignment-data/v1/model-assets.json'
    assets = json.loads(manifest.read_text())
    prefix = 'wav2vec2/' if engine == 'ctc' else 'TIFA-1.0-ST/'
    for asset in assets:
        if asset['asset'].startswith(prefix):
            path = model / asset['asset'][len(prefix):]
            if not path.is_file():
                raise Unavailable('Required local model asset unavailable: ' + asset['asset'])
            if path.stat().st_size != asset['bytes'] or file_hash(path) != asset['sha256']:
                raise AlignmentError('Unsupported model asset revision: ' + asset['asset'])
    if engine == 'tifa':
        fingerprint = hashlib.sha256()
        files = sorted(vendor.rglob('*.py'))
        if len(files) > 300 or sum(f.stat().st_size for f in files) > 2_000_000:
            raise AlignmentError('Unsupported TIFA source tree')
        for path in files:
            fingerprint.update(path.relative_to(vendor).as_posix().encode() + b'\0' + path.read_bytes() + b'\0')
        if fingerprint.hexdigest() != 'e05742f6c2bf250537bb6582461467c7b39b2d13ef705d9505767c55fe1e9bd8':
            raise AlignmentError('Unsupported TIFA source revision')
    if engine == 'ctc' and language != 'en':
        raise AlignmentError('Selected speech baseline supports English only')
    try:
        import torch
    except ImportError as e:
        raise Unavailable('Optional alignment environment unavailable; public tests do not require inference') from e
    def deny_network(event, args):
        if event in ('socket.connect', 'socket.getaddrinfo'):
            raise Unavailable('Inference attempted network access; prepare dependencies separately')
    sys.addaudithook(deny_network)
    torch.set_num_threads(4); torch.manual_seed(0)
    torch.use_deterministic_algorithms(True)
    if not audio.is_file() or audio.stat().st_size > 256 * 1024 * 1024:
        raise AlignmentError('Audio must be a readable local file no larger than 256 MiB')
    before = file_hash(audio)
    duration = decode(audio, work / 'input.wav')
    start = time.perf_counter()
    previous_directory = pathlib.Path.cwd()
    try:
        os.chdir(work)
        with open(work / 'worker.log', 'w') as log:
            from contextlib import redirect_stdout, redirect_stderr
            with redirect_stdout(log), redirect_stderr(log):
                units, metadata = (speech(work / 'input.wav', src['paragraphs'], model) if engine == 'ctc'
                                   else singing(work / 'input.wav', src['paragraphs'], model, vendor, language))
    except ImportError as e:
        raise Unavailable('Optional inference dependency unavailable: ' + str(e)) from e
    finally:
        os.chdir(previous_directory)
    if file_hash(audio) != before:
        raise AlignmentError('Source audio identity changed during inference')
    import resource
    metadata['inference_seconds_including_initialization'] = time.perf_counter() - start
    metadata['peak_rss_bytes'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * (1 if sys.platform == 'darwin' else 1024)
    weights = model / required[0]
    provenance = {'identity': engine, 'revision': ('22aad52d435eb6dbaf354bdad9b0da84ce7d6156' if engine == 'ctc' else '614a277d2580efe5e4b84faf4c34753dbc5a062c'),
                  'model_release': ('facebook/wav2vec2-base-960h' if engine == 'ctc' else 'TIFA-1.0-ST'),
                  'config_sha256': file_hash(model / ('config.json' if engine == 'ctc' else 'config.yaml')), 'weights_sha256': file_hash(weights), 'language': language,
                  'precision_us': metadata['model_grid_us'], 'device': 'cpu',
                  'dependencies': {p: importlib.metadata.version(p) for p in (['torch', 'numpy', 'transformers', 'scipy'] if engine == 'ctc' else ['torch', 'numpy', 'lightning', 'g2pflow', 'unidic-lite', 'onnxruntime'])},
                  'preprocessing': 'FFmpeg mono 48-kHz PCM16 copy; CTC additionally polyphase 16-kHz resampling',
                  'metadata': metadata}
    result = make_result(src, before, duration, provenance, units)
    # Preserve bad model output; never repair invalid ordering or out-of-audio bounds.
    prior = 0
    for line in result['lines']:
        v = line['estimate']
        if v is not None and not 0 <= prior <= v[0] < v[1] <= duration:
            result['unresolved'].append('Invalid model interval for line {}'.format(line['id']))
            line['estimate'] = None
        elif v is not None:
            prior = v[1]
    import json
    result['estimated_timing_sha256'] = digest(json.dumps([x['estimate'] for x in result['lines']], separators=(',', ':')).encode())
    return result
