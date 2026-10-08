"""Explicit Japanese reading overrides; display text and timing remain separate."""
import itertools
import json
import unicodedata
from xml.sax.saxutils import escape, quoteattr
from .core import AlignmentError


def boundaries(text):
    """Conservative Japanese-range boundaries, not a general grapheme segmenter."""
    offsets, n = {0: 0}, 0
    for i, c in enumerate(text):
        n += len(c.encode('utf-16-le')) // 2
        offsets[n] = i + 1
    return {k: i for k, i in offsets.items()
            if not (i < len(text) and (unicodedata.category(text[i]).startswith('M') or text[i] == '\u200d'))
            and not (i and text[i-1] == '\u200d')}


def validate_overrides(src, value):
    if not isinstance(value, dict) or set(value) != {'version', 'source_sha256', 'overrides'} or type(value['version']) is not int or value['version'] != 1:
        raise AlignmentError('Unsupported pronunciation override document')
    if value['source_sha256'] != src['sha256']:
        raise AlignmentError('Pronunciation source identity differs')
    rows = value['overrides']
    if not isinstance(rows, list) or not 1 <= len(rows) <= 64:
        raise AlignmentError('Supply 1–64 explicit pronunciation ranges')
    prior = (-1, 0)
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'paragraph', 'start_utf16', 'length_utf16', 'text', 'reading', 'note'}:
            raise AlignmentError('Unknown or missing pronunciation range field')
        p, a, size = (row[k] for k in ['paragraph', 'start_utf16', 'length_utf16'])
        if any(type(x) is not int for x in [p, a, size]) or not 0 <= p < len(src['paragraphs']) or a < 0 or size <= 0:
            raise AlignmentError('Invalid pronunciation range')
        text = src['paragraphs'][p]; b = a + size; allowed = boundaries(text)
        if a not in allowed or b not in allowed or (p, a) < prior:
            raise AlignmentError('Overlapping, unordered, or unsupported Unicode boundary')
        selected = text[allowed[a]:allowed[b]]
        if selected != row['text'] or not selected or len(selected) > 256:
            raise AlignmentError('Pronunciation range text differs from source')
        # Bound the supported language and avoid claiming full Unicode segmentation.
        if any(not ('\u3041' <= c <= '\u30fa' or '\u3400' <= c <= '\u9fff' or c in '々ー') for c in selected):
            raise AlignmentError('Only contiguous Japanese source ranges are supported')
        reading = row['reading']
        if not isinstance(reading, str) or not 1 <= len(reading) <= 256 or any(
                not ('\u3041' <= c <= '\u3096' or '\u30a1' <= c <= '\u30fa' or c in '\u3099\u309aー') for c in reading):
            raise AlignmentError('Pronunciation reading must contain kana only')
        if not isinstance(row['note'], str) or not row['note'].strip() or len(row['note']) > 1000:
            raise AlignmentError('Pronunciation override requires a bounded explanation')
        prior = (p, b)
    return value


def read_overrides(path, src):
    if path.stat().st_size > 65536:
        raise AlignmentError('Pronunciation overrides exceed 64 KiB')
    def pairs(items):
        result = {}
        for k, v in items:
            if k in result: raise AlignmentError('Duplicate pronunciation JSON field')
            result[k] = v
        return result
    return validate_overrides(src, json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs))


def pfml(src, value, convert):
    """Generate internal PFML using local kana conversion, never reference times.

    convert(reading) returns words containing complete G2P reading/path/group objects.
    The explicit source range is one ownership group regardless of phone count.
    """
    validate_overrides(src, value)
    output = []
    for p, text in enumerate(src['paragraphs']):
        allowed = boundaries(text); cursor = 0; fragments = []
        for row in [r for r in value['overrides'] if r['paragraph'] == p]:
            a = allowed[row['start_utf16']]; b = allowed[row['start_utf16'] + row['length_utf16']]
            fragments.append(escape(text[cursor:a]))
            # NFC is confined to the separately supplied reading, never displayed text.
            words = convert(unicodedata.normalize('NFC', row['reading']))
            alternatives = [[path for reading in w.readings for path in reading.paths] for w in words]
            count = 1
            for paths in alternatives: count *= len(paths)
            if not alternatives or not 1 <= count <= 64:
                raise AlignmentError('Empty or excessive pronunciation alternatives')
            paths = []
            for choice in itertools.product(*alternatives):
                groups = [g for part in choice for g in part]
                if not any(g.phonemes for g in groups): raise AlignmentError('Empty pronunciation')
                paths.append('<path>' + ''.join('<group phonemes=' + quoteattr(' '.join(g.phonemes)) + '/>' for g in groups) + '</path>')
            fragments.append('<word language="ja" text=' + quoteattr(row['text']) + '>' + ''.join(paths) + '</word>')
            cursor = b
        fragments.append(escape(text[cursor:])); output.append(''.join(fragments))
    return '\n'.join(output)


def suggest_long_vowels(src, units):
    """Suggest source-ownership overrides only for otherwise exact dropped ー marks.

    Never applied automatically. Does not infer missing phonemes or timestamps.
    Any other text discrepancy suppresses the suggestion.
    """
    from .core import canonical
    wanted, locations = '', []
    for p, paragraph in enumerate(src['paragraphs']):
        text, mapping=canonical(paragraph);wanted+=text
        locations.extend((p,a) for a,_ in mapping)
    got=''.join(canonical(u['text'])[0] for u in units)
    j=0;missing=[]
    for i,c in enumerate(wanted):
        if j<len(got) and c==got[j]:j+=1
        elif c=='ー':missing.append(locations[i])
        else:return None
    if j!=len(got) or not missing:return None
    ranges=set()
    for p,offset in missing:
        text=src['paragraphs'][p];allowed=boundaries(text)
        if offset not in allowed:return None
        a=b=allowed[offset]
        previous=text[max(0,a-1)]
        katakana='\u30a1'<=previous<='\u30fa'
        def kana(c):return ('\u30a1'<=c<='\u30fa' if katakana else '\u3041'<=c<='\u3096') or c in 'ー\u3099\u309a'
        while a>0 and kana(text[a-1]):a-=1
        while b<len(text) and kana(text[b]):b+=1
        ranges.add((p,a,b))
    rows=[]
    for p,a,b in sorted(ranges):
        text=src['paragraphs'][p]
        rows.append(dict(paragraph=p,start_utf16=len(text[:a].encode('utf-16-le'))//2,
                         length_utf16=len(text[a:b].encode('utf-16-le'))//2,text=text[a:b],reading=text[a:b],
                         note='Automatically suggested source ownership for dropped long-vowel marks; pronunciation requires review'))
    value=dict(version=1,source_sha256=src['sha256'],overrides=rows)
    try:return validate_overrides(src,value)
    except AlignmentError:return None
