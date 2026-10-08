"""Model-free structural checks for private human singing-activity annotations.

This is a research intake profile of the existing annotation format, not a
renderer schema. Declarations about rights and independent listening are not
certified by these checks. No annotation, partition, or timing is modified.
"""
import hashlib
import json
import re
from fractions import Fraction
from .core import AlignmentError

VOCAL = {'lead_singing', 'backing_singing', 'overlapping_singers', 'humming', 'sung_ad_lib'}
NEGATIVE = {'instrumental', 'silence'}
UNKNOWN = {'breath', 'spoken_interjection', 'ambiguous_reverberation', 'unresolved'}
HASH = re.compile(r'[0-9a-f]{64}\Z')


def integer(value, name, minimum=0):
    if type(value) is not int or value < minimum:
        raise AlignmentError(f'{name} must be an integer >= {minimum}')
    return value


def identifier(value, name):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}', value):
        raise AlignmentError(f'{name} requires a neutral identifier of at most 64 characters')
    return value


def sha(value, name):
    if not isinstance(value, str) or not HASH.fullmatch(value):
        raise AlignmentError(f'{name} requires a real SHA-256 identity; illustrative null identities are unavailable')
    return value


def load(path):
    if not path.is_file():
        from .worker import Unavailable
        raise Unavailable('Human annotation input is unavailable')
    if path.stat().st_size > 131072:
        raise AlignmentError('Annotation exceeds 128 KiB')
    data = path.read_bytes()
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise AlignmentError('Duplicate annotation field')
            value[key] = item
        return value
    try:
        value = json.loads(data.decode('utf-8'), object_pairs_hook=unique,
                           parse_constant=lambda _: (_ for _ in ()).throw(AlignmentError('Nonfinite JSON value')))
    except (UnicodeError, json.JSONDecodeError, RecursionError) as e:
        raise AlignmentError('Annotation requires valid UTF-8 JSON') from e
    return value, hashlib.sha256(data).hexdigest()


def validate(record):
    if not isinstance(record, dict) or type(record.get('format_version')) is not int or record['format_version'] != 1:
        raise AlignmentError('Only annotation format_version 1 is supported')
    allowed = {'format_version', 'classification', 'source_id', 'singer_group', 'permission_reference',
               'annotator', 'reviewer', 'audio_sha256', 'language', 'accompanied', 'sample_rate_hz',
               'source_total_samples', 'source_start_sample', 'source_end_sample', 'timing_unit',
               'duration_samples', 'duration_us', 'annotation_resolution', 'review_status',
               'independence', 'initial_passes_sha256', 'intervals', 'disagreements', 'notes'}
    if set(record)-allowed:
        raise AlignmentError('Unsupported annotation field')
    for key in ['source_id', 'singer_group', 'permission_reference', 'annotator']:
        identifier(record.get(key), key)
    sha(record.get('audio_sha256'), 'audio_sha256')
    if record.get('language') not in ['en', 'ja'] or type(record.get('accompanied')) is not bool:
        raise AlignmentError('Declare en/ja language and accompanied Boolean')
    rate = integer(record.get('sample_rate_hz'), 'sample_rate_hz', 1)
    if rate > 192000:
        raise AlignmentError('Annotation sample rate exceeds 192 kHz')
    total = integer(record.get('source_total_samples'), 'source_total_samples', 1)
    start = integer(record.get('source_start_sample'), 'source_start_sample')
    end = integer(record.get('source_end_sample'), 'source_end_sample', 1)
    if not start < end <= total or end-start > rate*60:
        raise AlignmentError('Require in-bounds source-sample excerpt of at most 60 seconds')
    unit = record.get('timing_unit', 'microseconds')
    if unit == 'samples':
        if 'duration_us' in record:
            raise AlignmentError('Do not mix sample and microsecond duration fields')
        duration = integer(record.get('duration_samples'), 'duration_samples', 1)
        denominator = rate
        if duration != end-start:
            raise AlignmentError('duration_samples differs from source excerpt bounds')
    elif unit == 'microseconds':
        if 'duration_samples' in record:
            raise AlignmentError('Do not mix sample and microsecond duration fields')
        duration = integer(record.get('duration_us'), 'duration_us', 1)
        denominator = 1000000
        if abs(Fraction(duration, denominator)-Fraction(end-start, rate)) > Fraction(1, denominator):
            raise AlignmentError('duration_us differs from exact source-sample duration by more than one microsecond')
    else:
        raise AlignmentError('timing_unit requires samples or microseconds')
    resolution = integer(record.get('annotation_resolution'), 'annotation_resolution', 1)
    if resolution > duration:
        raise AlignmentError('Annotation resolution exceeds duration')
    status = record.get('review_status')
    if status not in ['independent_pass', 'reviewed']:
        raise AlignmentError('review_status requires independent_pass or reviewed')
    if status == 'independent_pass':
        if record.get('disagreements') or 'initial_passes_sha256' in record:
            raise AlignmentError('Initial passes must precede review and cross-pass comparisons')
        declaration = record.get('independence')
        expected = {'audio_only': True, 'consulted_predictions': False, 'consulted_other_pass': False}
        if not isinstance(declaration, dict) or declaration != expected or any(type(v) is not bool for v in declaration.values()):
            raise AlignmentError('Initial pass requires explicit independent audio-only listening declarations')
    else:
        reviewer = identifier(record.get('reviewer'), 'reviewer')
        if reviewer == record['annotator']:
            raise AlignmentError('Annotator and reviewer must be distinct participants')
        hashes = record.get('initial_passes_sha256')
        if not isinstance(hashes, list) or len(hashes) != 2 or len(set(sha(x, 'initial pass') for x in hashes)) != 2:
            raise AlignmentError('Reviewed record requires two distinct initial-pass hashes')
    values = record.get('intervals')
    if not isinstance(values, list) or len(values) > 2000:
        raise AlignmentError('Supply at most 2000 annotation intervals')
    suffix = '_sample' if unit == 'samples' else '_us'
    previous = 0
    unknown = []
    pairs = gaps = instrumental = 0
    for row in values:
        if not isinstance(row, dict):
            raise AlignmentError('Annotation interval must be an object')
        kind = row.get('kind')
        if not isinstance(kind, str):
            raise AlignmentError('Annotation class must be a string')
        boundary_keys = (['onset_earliest', 'onset_latest', 'offset_earliest', 'offset_latest']
                         if kind in VOCAL else ['start', 'end'])
        allowed_row = {'kind', 'tags', 'review'} | {k+suffix for k in boundary_keys}
        if kind in VOCAL: allowed_row.add('censored')
        if set(row)-allowed_row:
            raise AlignmentError('Unsupported or mixed-unit annotation interval field')
        if kind in VOCAL:
            points = [integer(row.get(k+suffix), k+suffix) for k in
                      ['onset_earliest', 'onset_latest', 'offset_earliest', 'offset_latest']]
            a, b, c, d = points
            if not a <= b <= c <= d or a == d:
                raise AlignmentError('Vocal uncertainty bands are not ordered')
            censored = row.get('censored', {'onset': False, 'offset': False})
            if not isinstance(censored, dict) or set(censored) != {'onset', 'offset'} or any(type(v) is not bool for v in censored.values()):
                raise AlignmentError('Censored boundaries require onset/offset Booleans')
            if censored['onset'] and a != 0 or censored['offset'] and d != duration:
                raise AlignmentError('Censored boundary must touch the excerpt edge')
            if b == c:
                unknown.append([a, d])
            else:
                if a < b: unknown.append([a, b])
                if c < d: unknown.append([c, d])
                if not any(censored.values()): pairs += 1
        elif kind in NEGATIVE | UNKNOWN:
            a = integer(row.get('start'+suffix), 'start'+suffix)
            d = integer(row.get('end'+suffix), 'end'+suffix, 1)
            if a >= d:
                raise AlignmentError('Empty or reversed annotation interval')
            if kind in UNKNOWN: unknown.append([a, d])
            else:
                gaps += 1
                instrumental += kind == 'instrumental'
        else:
            raise AlignmentError('Unsupported annotation class')
        if a < previous or d > duration:
            raise AlignmentError('Annotation envelopes overlap, are unordered, or exceed excerpt bounds')
        if a > previous: unknown.append([previous, a])
        previous = d
    if previous < duration: unknown.append([previous, duration])
    unknown.sort()
    merged = []
    for a, b in unknown:
        if merged and a <= merged[-1][1]: merged[-1][1] = max(b, merged[-1][1])
        else: merged.append([a, b])
    disagreements = record.get('disagreements', [])
    if not isinstance(disagreements, list) or len(disagreements) > 2000:
        raise AlignmentError('Supply at most 2000 review disagreements')
    for row in disagreements:
        if not isinstance(row, dict) or set(row) != {'start'+suffix, 'end'+suffix, 'disposition', 'evidence_reference'}:
            raise AlignmentError('Disagreement requires bounds, disposition, and evidence reference')
        a = integer(row['start'+suffix], 'disagreement start')
        d = integer(row['end'+suffix], 'disagreement end', 1)
        if not 0 <= a < d <= duration:
            raise AlignmentError('Disagreement is outside excerpt')
        identifier(row['evidence_reference'], 'disagreement evidence reference')
        if row['disposition'] == 'unresolved':
            if not any(c <= a and d <= e for c, e in merged):
                raise AlignmentError('Unresolved disagreement must remain wholly unknown')
        elif row['disposition'] != 'resolved_by_listening':
            raise AlignmentError('Unsupported disagreement disposition; averaging is not a resolution')
    return dict(status='structurally_valid', timing_unit=unit, time_denominator=denominator,
                duration=duration, unknown_intervals=merged,
                declared_clear_uncensored_pairs=pairs, declared_nonvocal_gaps=gaps,
                declared_instrumental_gaps=instrumental, review_status=status,
                eligible_for_scoring=False,
                limitations='Rights, performer independence, actual listening, disagreement preservation, and partition integrity require separate human verification; structural validity cannot freeze a corpus')


def validate_review(record, pass_a, hash_a, pass_b, hash_b):
    summary = validate(record)
    validate(pass_a); validate(pass_b)
    if record['review_status'] != 'reviewed' or any(p['review_status'] != 'independent_pass' for p in [pass_a, pass_b]):
        raise AlignmentError('Supply a reviewed record and two independent initial passes')
    if set(record['initial_passes_sha256']) != {sha(hash_a, 'pass A'), sha(hash_b, 'pass B')}:
        raise AlignmentError('Reviewed record does not identify the supplied original passes')
    if pass_a['annotator'] == pass_b['annotator'] or {pass_a['annotator'], pass_b['annotator']} != {record['annotator'], record['reviewer']}:
        raise AlignmentError('Initial passes require the two declared distinct participants')
    identity = ['source_id', 'audio_sha256', 'sample_rate_hz', 'source_total_samples',
                'source_start_sample', 'source_end_sample', 'singer_group', 'language', 'accompanied', 'permission_reference']
    if any(p.get(k) != record.get(k) for p in [pass_a, pass_b] for k in identity):
        raise AlignmentError('Initial passes differ in source, excerpt, performer, or permission identity')
    if pass_a['intervals'] != pass_b['intervals'] and not record.get('disagreements'):
        raise AlignmentError('Different initial passes require a separate disagreement record')
    summary['initial_pass_links_verified'] = True
    return summary
