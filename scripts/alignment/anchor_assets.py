"""Read-only preflight for the proposed runtime; never downloads, builds, or executes it."""
import os
from .core import AlignmentError
from .worker import Unavailable, file_hash

SOURCE_REVISION = 'd1be6fde11ac6e0407606b4e42fe72d34add8037'
MODEL_REVISION = '5359861c739e955e79d9a303bcbc70fb988958b1'
MODEL_BYTES = 487601967
MODEL_SHA256 = '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b'


def require_assets(runtime, model):
    if not runtime.is_file() or not os.access(runtime, os.X_OK):
        raise Unavailable('Optional pinned whisper.cpp CPU executable unavailable; provisioning requires approval')
    if not model.is_file():
        raise Unavailable('Optional local multilingual Whisper small checkpoint unavailable')
    if model.stat().st_size != MODEL_BYTES or file_hash(model) != MODEL_SHA256:
        raise AlignmentError('Whisper checkpoint identity differs from the pinned artifact')
    return dict(runtime_sha256=file_hash(runtime),model_sha256=MODEL_SHA256,
                model_revision=MODEL_REVISION,source_revision=SOURCE_REVISION,
                status='assets_present_runtime_build_provenance_still_requires_verification')
