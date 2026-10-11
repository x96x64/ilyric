#!/usr/bin/env python3
"""Score `ilyrics align` reports for the preview qualification (docs/reports/preview-qualification-procedure.md).

  evaluate_preview.py jamendo REPORT.json LINES.csv WORDS.csv
  evaluate_preview.py musdb-input SECTIONS.txt LYRICS.txt
  evaluate_preview.py musdb REPORT.json SECTIONS.txt
  evaluate_preview.py musdb-revised REPORT.json SECTIONS.txt

`musdb-revised` applies docs/reports/revised-preview-criteria.md: vocable-only sections are excluded from scoring and
reported separately.

Outputs JSON numbers only; lyric text is read for matching and never printed.
"""
import csv
import json
import re
import statistics
import sys

US = 1_000_000


def load_report(path):
    report = json.load(open(path))
    if report.get('format') != 'ilyric-alignment-report-1':
        raise SystemExit('Unsupported report format')
    return report


def norm(text):
    # Whitespace is collapsed and, as ilyrics's lyrics normalization does, not kept before punctuation.
    return re.sub(r' ([,.;:!?])', r'\1', ' '.join(text.split()))


def hit(a, b):
    return min(a[1], b[1]) > max(a[0], b[0])


def errors_summary(values):
    if not values:
        return None
    a = sorted(abs(v) for v in values)
    p95 = a[min(len(a) - 1, int(round(0.95 * (len(a) - 1))))]
    return dict(count=len(a), median_ms=round(statistics.median(a) / 1000), p95_ms=round(p95 / 1000),
                above_500ms=sum(v > 500_000 for v in a) / len(a))


def jamendo(report_path, lines_path, words_path):
    report = load_report(report_path)
    reference = [dict(start=float(r['start_time']) * US, end=float(r['end_time']) * US, text=r['lyrics_line'])
                 for r in csv.DictReader(open(lines_path))]
    lines = report['lines']
    if len(lines) != len(reference) or any(norm(l['text']) != norm(r['text']) for l, r in zip(lines, reference)):
        raise SystemExit('Report lines do not correspond to the reference lines')
    words = [float(r['word_start']) * US for r in csv.DictReader(open(words_path))]
    correct = unresolved = 0
    onset, offset, word_onset, skipped_words, cursor = [], [], [], 0, 0
    for line, ref in zip(lines, reference):
        tokens = ref['text'].split()
        line_words = words[cursor:cursor + len(tokens)]
        cursor += len(tokens)
        if line['status'] != 'aligned':
            unresolved += 1
            continue
        a, b = line['interval_us']
        if hit([a, b], [ref['start'], ref['end']]):
            correct += 1
        onset.append(a - ref['start'])
        offset.append(b - ref['end'])
        estimated = [w['interval_us'][0] for w in (line['words'] or [])]
        if len(estimated) == len(line_words):
            word_onset += [e - r for e, r in zip(estimated, line_words)]
        else:
            skipped_words += len(line_words)
    if cursor != len(words):
        raise SystemExit('Word annotations do not correspond to the lyric lines')
    n = len(reference)
    return dict(lines=n, correct_placement=correct / n, unresolved=unresolved / n,
                line_onset=errors_summary(onset), line_offset=errors_summary(offset),
                word_onset=errors_summary(word_onset), words_scored=len(word_onset), words_skipped=skipped_words)


# Sections with simultaneous different words are prefixed with '*'.
SECTION = re.compile(r'^(\*?)\s*(\d+):(\d\d)\s+(\d+):(\d\d)\s+([abcd])\s*(.*)$')


def sections(path):
    out = []
    for raw in open(path, encoding='utf-8', errors='strict'):
        raw = raw.strip()
        if not raw:
            continue
        m = SECTION.match(raw)
        if not m:
            raise SystemExit('Unparsable section line')
        start = (int(m[2]) * 60 + int(m[3])) * US
        end = (int(m[4]) * 60 + int(m[5])) * US
        # Parenthesis characters are removed so that every section stays one aligned line rather than a background vocal.
        out.append(dict(start=start, end=end, kind=m[6], star=m[1] == '*', text=norm(re.sub(r'[()]', ' ', m[7]))))
    return [s for s in out if s['kind'] != 'd' and s['text']]


def musdb_input(sections_path, lyrics_path):
    sung = sections(sections_path)
    # One section per line; paragraphs are formed by ilyrics's normalization.
    open(lyrics_path, 'w', encoding='utf-8').write('\n'.join(s['text'] for s in sung) + '\n')
    return dict(lines=len(sung), scored=sum(not s['star'] for s in sung))


# The command's vocable pattern (TTMLExport.vocable).
VOCABLE = re.compile(r"^(?:h?m+(?:h?m+)*|mh?m+|a+h*|o+h*|u+h+|e+y+|a+y+|la+|na+|da+|whoa+|ha+|w?h?o+o+|ow+|hee+|ye+a+h*|hey+|shamone)$")


def vocable_only(text):
    words = [w.lower() for w in re.findall(r'[A-Za-z]+', text)]
    return bool(words) and all(VOCABLE.match(w) for w in words)


def musdb(report_path, sections_path, revised=False):
    report = load_report(report_path)
    sung = sections(sections_path)
    lines = report['lines']
    if len(lines) != len(sung) or any(norm(l['text']) != s['text'] for l, s in zip(lines, sung)):
        raise SystemExit('Report lines do not correspond to the annotated sections')
    tally = {k: dict(lines=0, placed=0, wrong=0, unresolved=0, words=0, contained=0) for k in ['all', 'a', 'b', 'c']}
    onset = []
    vocables = dict(sections=0, omitted=0, aligned=0, placed_correctly=0)
    for line, s in zip(lines, sung):
        if s['star']:
            continue
        if revised and vocable_only(s['text']):
            vocables['sections'] += 1
            vocables['omitted'] += line['status'] == 'omitted'
            if line['status'] == 'aligned':
                vocables['aligned'] += 1
                a, b = line['interval_us']
                vocables['placed_correctly'] += s['start'] - US <= (a + b) / 2 <= s['end'] + US
            continue
        lo, hi = s['start'] - US, s['end'] + US
        for key in ['all', s['kind']]:
            tally[key]['lines'] += 1
        if line['status'] != 'aligned':
            for key in ['all', s['kind']]:
                tally[key]['unresolved'] += 1
            continue
        a, b = line['interval_us']
        inside = lo <= (a + b) / 2 <= hi
        words = line['words'] or []
        contained = sum(lo <= (w['interval_us'][0] + w['interval_us'][1]) / 2 <= hi for w in words)
        for key in ['all', s['kind']]:
            tally[key]['placed' if inside else 'wrong'] += 1
            tally[key]['words'] += len(words)
            tally[key]['contained'] += contained
        onset.append(a - s['start'])
    result = {}
    for key, t in tally.items():
        if t['lines'] == 0:
            continue
        result[key] = dict(lines=t['lines'], placement_accuracy=t['placed'] / t['lines'], wrong_placement=t['wrong'] / t['lines'],
                           unresolved=t['unresolved'] / t['lines'], words=t['words'],
                           word_containment=t['contained'] / t['words'] if t['words'] else None, counts=t)
    result['section_onset_difference'] = errors_summary(onset)
    result['excluded_star_sections'] = sum(s['star'] for s in sung)
    result['duration_us'] = report['duration_us']
    if revised:
        result['vocable_only'] = vocables
    return result


if __name__ == '__main__':
    mode, args = sys.argv[1], sys.argv[2:]
    if mode == 'jamendo':
        print(json.dumps(jamendo(*args), indent=1))
    elif mode == 'musdb-input':
        print(json.dumps(musdb_input(*args)))
    elif mode == 'musdb':
        print(json.dumps(musdb(*args), indent=1))
    elif mode == 'musdb-revised':
        print(json.dumps(musdb(*args, revised=True), indent=1))
    else:
        raise SystemExit(__doc__)
