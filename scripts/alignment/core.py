"""Lossless source mapping, review, and bounded line-level TTML preparation.

The JSON artifact is experimental. Inference estimates are not calibrated timing.
All times are integer microseconds; engine frame precision is recorded separately.
"""
import copy
import hashlib
import json
import re
import unicodedata
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN
from xml.sax.saxutils import escape


class AlignmentError(ValueError):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def micros(value):
    """Convert decimal seconds once, nearest microsecond, ties to even."""
    try:
        d = Decimal(str(value))
    except InvalidOperation as e:
        raise AlignmentError('Invalid decimal boundary') from e
    if not d.is_finite() or not 0 <= d <= 60:
        raise AlignmentError("Alignment times must be finite and within 0–60 seconds")
    return int((d * 1_000_000).to_integral_value(rounding=ROUND_HALF_EVEN))


def source(data):
    if len(data) > 65536:
        raise AlignmentError("Lyrics exceed 64 KiB")
    try:
        text = data.decode('utf-8')
    except UnicodeError as e:
        raise AlignmentError("Lyrics must be UTF-8") from e
    # Preserve original bytes/text in the artifact; only file delimiters differ in display.
    display = text.removeprefix('\ufeff').replace('\r\n', '\n')
    if any(ord(c) < 32 and c not in '\n\t' or ord(c) == 127 for c in display):
        raise AlignmentError("Unsupported control character or bare CR")
    paragraphs = []
    for part in re.split(r'\n\n+', display.strip('\n')):
        if not part or not part.strip():
            raise AlignmentError("Lyrics must contain nonempty paragraphs")
        if len(part.encode('utf-16-le')) // 2 >= 500 or len(part.split('\n')) > 4:
            raise AlignmentError("Paragraph exceeds 499 UTF-16 units or four explicit lines")
        if any(not line.strip() for line in part.split('\n')):
            raise AlignmentError("Whitespace-only lines are unsupported")
        paragraphs.append(part)
    if len(paragraphs) > 64:
        raise AlignmentError("At most 64 paragraphs are supported")
    return {'text': text, 'sha256': digest(data), 'paragraphs': paragraphs}


def canonical(text):
    """Alignment-side case/punctuation filter, never a display rewrite.

    No Unicode normalization, transliteration, accent stripping, or G2P is done here.
    Each retained code point maps back to its original UTF-16 range.
    """
    result, mapping, offset = [], [], 0
    for c in text:
        width = len(c.encode('utf-16-le')) // 2
        if unicodedata.category(c)[0] in 'LNM':
            lowered = c.lower()
            result.extend(lowered)
            mapping.extend([(offset, width)] * len(lowered))
        elif not (c.isspace() or unicodedata.category(c)[0] == 'P'):
            raise AlignmentError("Unsupported alignment symbol; source text is preserved")
        offset += width
    return ''.join(result), mapping


def make_result(src, audio_hash, duration_us, engine, units, diagnostics=None):
    """Map ordered acoustic units back to complete source lines, without guessing.

    Units retain model text, estimated begin/end and optional diagnostic scores.
    A mismatch or skipped unit leaves explicit unresolved lines, never fabricated time.
    """
    lines, wanted, owners = [], '', []
    for p, paragraph in enumerate(src['paragraphs']):
        offset = 0
        for text in paragraph.split('\n'):
            normalized, mapping = canonical(text)
            line = {'id': len(lines), 'paragraph': p, 'start_utf16': offset,
                    'length_utf16': len(text.encode('utf-16-le')) // 2,
                    'text': text, 'alignment_text': normalized, 'range_map': mapping,
                    'estimate': None, 'correction': None, 'review': 'pending'}
            lines.append(line)
            wanted += normalized
            owners.extend([line['id']] * len(normalized))
            offset += line['length_utf16'] + 1
    if len(units) > 3000:
        raise AlignmentError('At most 3,000 acoustic units are supported')
    unresolved, prior = [], 0
    for u in units:
        if any(type(u.get(k)) is not int for k in ['begin_us', 'end_us']):
            raise AlignmentError('Raw model boundaries must be integer microseconds')
        if not 0 <= prior <= u['begin_us'] < u['end_us'] <= duration_us:
            unresolved.append('Invalid, skipped, overlapping, or out-of-bounds acoustic units')
        prior = u['end_us']
    got = ''.join(canonical(u['text'])[0] for u in units)
    if got != wanted or not wanted:
        unresolved.append('Model/source text coverage mismatch; no positional guessing applied')
    elif not unresolved:
        pos, ranges = 0, [[] for _ in lines]
        for u in units:
            n = len(canonical(u['text'])[0])
            line_ids = set(owners[pos:pos+n]); pos += n
            if len(line_ids) != 1 or u['begin_us'] >= u['end_us']:
                unresolved.append('Skipped acoustic unit or unit crossing an explicit source line')
                continue
            ranges[next(iter(line_ids))].append(u)
        for line, matches in zip(lines, ranges):
            if ''.join(canonical(u['text'])[0] for u in matches) == line['alignment_text'] and matches:
                line['estimate'] = [matches[0]['begin_us'], matches[-1]['end_us']]
            else:
                unresolved.append('Unaligned source line {}'.format(line['id']))
    estimates_hash = digest(json.dumps([x['estimate'] for x in lines], separators=(',', ':')).encode())
    return {'estimated_timing_sha256': estimates_hash, 'version': 1, 'source': src, 'audio': {'sha256': audio_hash, 'duration_us': duration_us},
            'granularity': 'line', 'time_unit': 'microsecond', 'engine': engine,
            'units': units, 'lines': lines, 'unresolved': sorted(set(unresolved)),
            'diagnostics': diagnostics or [], 'history': []}


def interval(line):
    return line['correction']['interval_us'] if line['correction'] is not None else line['estimate']


def validate(result, ready=False):
    try:
        if result['version'] != 1 or result['granularity'] != 'line' or result['time_unit'] != 'microsecond':
            raise AlignmentError("Unsupported alignment artifact")
        src = source(result['source']['text'].encode('utf-8'))
        if src != result['source']:
            raise AlignmentError("Source text/hash/paragraph structure changed")
        duration = result['audio']['duration_us']
        if type(duration) is not int or not 0 < duration <= 60_000_000:
            raise AlignmentError("Audio duration must be within 0–60 seconds")
        if not re.fullmatch('[0-9a-f]{64}', result['audio']['sha256']):
            raise AlignmentError("Invalid audio identity")
        if not result['engine'].get('identity') or type(result['engine'].get('precision_us')) is not int or result['engine']['precision_us'] <= 0:
            raise AlignmentError("Missing engine provenance")
        raw_check = make_result(src, result['audio']['sha256'], duration, result['engine'], result['units'])
        if raw_check['unresolved'] and not result['unresolved']:
            raise AlignmentError('Unresolved model support was silently removed')
        # Rebuild text/range ownership, independently of editable estimates.
        expected = make_result(src, result['audio']['sha256'], duration, result['engine'], [])['lines']
        if len(result['lines']) != len(expected) or len(result['units']) > 3000:
            raise AlignmentError("Line coverage or acoustic-unit resource limit")
        if result['estimated_timing_sha256'] != digest(json.dumps([x['estimate'] for x in result['lines']], separators=(',', ':')).encode()):
            raise AlignmentError('Original estimates changed; use correction fields')
        prior = 0
        for a, b in zip(result['lines'], expected):
            for key in ['id', 'paragraph', 'text', 'start_utf16', 'length_utf16', 'alignment_text', 'range_map']:
                # JSON turns range tuples into arrays.
                if json.dumps(a[key]) != json.dumps(b[key]):
                    raise AlignmentError("Source range mapping changed")
            if a['review'] not in ['pending', 'accepted', 'corrected']:
                raise AlignmentError("Invalid review state")
            if a['correction'] is not None:
                if a['review'] != 'corrected' or not a['correction'].get('note') or a['correction'].get('origin') != 'manual':
                    raise AlignmentError("Correction requires provenance and note")
            if a['review'] != 'pending':
                events = [x for x in result['history'] if x.get('line') == a['id']]
                if not events or events[-1].get('action') != a['review'] or events[-1].get('interval_us') != interval(a) or not events[-1].get('note'):
                    raise AlignmentError('Reviewed timing requires a matching history entry')
            v = interval(a)
            if v is None:
                if ready:
                    raise AlignmentError("Missing line boundaries require correction")
                continue
            if not isinstance(v, list) or len(v) != 2 or any(type(t) is not int for t in v):
                raise AlignmentError("Boundaries must be two integer microseconds")
            if not 0 <= v[0] < v[1] <= duration or v[0] < prior:
                raise AlignmentError("Invalid, overlapping, or nonmonotonic line interval")
            prior = v[1]
            if ready and a['review'] == 'pending':
                raise AlignmentError("Estimated boundaries require explicit review before TTML export")
        if ready and result['unresolved'] and any(x['review'] != 'corrected' for x in result['lines']):
            raise AlignmentError("Unresolved engine output requires correction of every source line")
    except (KeyError, TypeError, UnicodeError, IndexError, AttributeError) as e:
        raise AlignmentError("Malformed alignment artifact") from e
    return result


def review(result, line_id, begin=None, end=None, note=''):
    validate(result)
    if not note.strip() or len(note) > 1000 or type(line_id) is not int or not 0 <= line_id < len(result['lines']):
        raise AlignmentError("Review requires a valid line ID and a nonempty note")
    r = copy.deepcopy(result); line = r['lines'][line_id]
    if (begin is None) != (end is None):
        raise AlignmentError("Supply both correction boundaries")
    if begin is None:
        if line['estimate'] is None or line['correction'] is not None:
            raise AlignmentError("Cannot accept a missing or previously corrected estimate")
        line['review'] = 'accepted'
    else:
        line['correction'] = {'interval_us': [micros(begin), micros(end)], 'note': note, 'origin': 'manual'}
        line['review'] = 'corrected'
    r['history'].append({'line': line_id, 'action': line['review'], 'interval_us': interval(line), 'note': note})
    return validate(r)


def to_ttml(result):
    validate(result, ready=True)
    def stamp(t):
        return '{}.{:06d}s'.format(t // 1_000_000, t % 1_000_000)
    paragraphs = []
    for p, text in enumerate(result['source']['paragraphs']):
        lines = [x for x in result['lines'] if x['paragraph'] == p]
        paragraphs.append('<p begin="{}" end="{}">{}</p>'.format(
            stamp(interval(lines[0])[0]), stamp(interval(lines[-1])[1]),
            '<br/>'.join(escape(x) for x in text.split('\n'))))
    value = '<tt xmlns="http://www.w3.org/ns/ttml" xml:space="preserve"><body><div>' + ''.join(paragraphs) + '</div></body></tt>\n'
    if len(value.encode('utf-8')) > 65536:
        raise AlignmentError("Prepared TTML exceeds importer resource limit")
    return value
