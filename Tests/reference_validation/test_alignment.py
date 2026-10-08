"""Alignment preparation tests require no models, media, NumPy, or network."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from alignment.core import AlignmentError, canonical, make_result, micros, review, source, to_ttml, validate
from alignment.worker import ctc_path


def fixture(text='Light returns.\nQuiet water.\n\n光が戻る。'):
    src = source(text.encode())
    units = [{'text': x, 'begin_us': 125_000 + i * 2_000_000, 'end_us': 1_125_000 + i * 2_000_000}
             for i, x in enumerate(text.replace('\n\n', '\n').split('\n'))]
    return make_result(src, 'a' * 64, 7_000_000, {'identity': 'synthetic-test', 'precision_us': 20_000}, units)


class AlignmentTests(unittest.TestCase):
    def test_lossless_unicode(self):
        text = '\ufeffCafe\u0301, 海。\r\n\r\nA & B < C!\r\n'
        s = source(text.encode())
        self.assertEqual(s['text'], text)
        self.assertEqual(s['paragraphs'], ['Cafe\u0301, 海。', 'A & B < C!'])
        normalized, mapping = canonical('Cafe\u0301, 海。')
        self.assertEqual(normalized, 'cafe\u0301海')
        self.assertEqual(mapping[-1], (7, 1))

    def test_invalid_text(self):
        for data in [b'\xff', b'', b' ', b'a\rb', b'a\x00', b'a' * 65537, b'a' * 500, b'a\nb\nc\nd\ne']:
            with self.subTest(data=data[:8]), self.assertRaises(AlignmentError):
                source(data)
        for text in ['👩\u200d💻', '♪', '❤️']:
            with self.assertRaises(AlignmentError): canonical(text)

    def test_exact_time_conversion(self):
        self.assertEqual(micros('0.123456'), 123456)
        self.assertEqual(micros('0.1234565'), 123456)
        self.assertEqual(micros('0.1234575'), 123458)
        for value in ['NaN', 'Infinity', '-1', '60.01']:
            with self.assertRaises(AlignmentError): micros(value)

    def test_pending_review(self):
        r = fixture(); validate(r)
        with self.assertRaises(AlignmentError): to_ttml(r)
        for i in range(3): r = review(r, i, note='Synthetic test acceptance')
        root = ET.fromstring(to_ttml(r)); ns = {'t': 'http://www.w3.org/ns/ttml'}
        ps = root.findall('.//t:p', ns)
        self.assertEqual(len(ps), 2)
        self.assertEqual(ps[0].attrib, {'begin': '0.125000s', 'end': '3.125000s'})
        self.assertEqual(len(ps[0].findall('t:br', ns)), 1)
        self.assertEqual(ps[1].attrib['begin'], '4.125000s')

    def test_correction_reuse_and_history(self):
        r = fixture(); original = copy.deepcopy(r)
        r = review(r, 0, '.130123', '1.100456', note='Boundary corrected')
        self.assertEqual(r['lines'][0]['estimate'], original['lines'][0]['estimate'])
        self.assertEqual(r['lines'][0]['correction']['interval_us'], [130123, 1100456])
        self.assertEqual(len(r['history']), 1)
        self.assertEqual(original['lines'][0]['review'], 'pending')
        validate(json.loads(json.dumps(r)))

    def test_invalid_intervals(self):
        for interval in [[0, 0], [-1, 1], [10, 5], [0, 7_000_001], [False, 100]]:
            r = fixture(); r['lines'][0]['estimate'] = interval
            with self.assertRaises(AlignmentError): validate(r)
        r = fixture(); r['lines'][1]['estimate'] = [1000, 2000]
        with self.assertRaises(AlignmentError): validate(r)

    def test_source_tampering(self):
        for key, value in [('text', 'Different'), ('start_utf16', 2), ('id', 9)]:
            r = fixture(); r['lines'][0][key] = value
            with self.assertRaises(AlignmentError): validate(r)
        r = fixture(); r['source']['text'] = 'Different'
        with self.assertRaises(AlignmentError): validate(r)

    def test_repeated_phrases_are_occurrences(self):
        r = fixture('Again.\n\nAgain.\n\nAgain.')
        self.assertEqual([x['estimate'][0] for x in r['lines']], [125000, 2125000, 4125000])
        self.assertEqual([x['id'] for x in r['lines']], [0, 1, 2])

    def test_mismatch_and_skips_are_unresolved(self):
        r = fixture(); r = make_result(r['source'], 'a'*64, 7_000_000, r['engine'], [])
        self.assertTrue(r['unresolved']); self.assertTrue(all(x['estimate'] is None for x in r['lines']))
        with self.assertRaises(AlignmentError): review(r, 0, note='Cannot accept absent estimate')
        for i in range(3): r = review(r, i, str(i*2+.1), str(i*2+1), note='Supplied manual correction')
        self.assertIn('<br/>', to_ttml(r))
        r = fixture(); r['units'][1]['end_us'] = r['units'][1]['begin_us']
        r = make_result(r['source'], 'a'*64, 7_000_000, r['engine'], r['units'])
        self.assertIsNone(r['lines'][1]['estimate'])

    def test_raw_overlap_preserved_as_unresolved(self):
        r = fixture(); units = r['units']; units[1]['begin_us'] = 500000
        bad = make_result(r['source'], 'a'*64, 7000000, r['engine'], units)
        self.assertTrue(bad['unresolved'])
        self.assertTrue(all(x['estimate'] is None for x in bad['lines']))
        validate(bad)
        bad['unresolved'] = []
        with self.assertRaises(AlignmentError): validate(bad)

    def test_error_summary(self):
        from alignment.metrics import summarize
        r = summarize([-1000, 0, 1000, 1000000])
        self.assertEqual(r['median_ms'], 1)
        self.assertEqual(r['over_500_ms_fraction'], .25)
        self.assertEqual(summarize([])['count'], 0)

    def test_cross_line_units_rejected(self):
        r = fixture('Light\nreturns')
        r = make_result(r['source'], 'a'*64, 7_000_000, r['engine'], [{'text': 'Lightreturns', 'begin_us': 1, 'end_us': 2000}])
        self.assertTrue(r['unresolved']); self.assertIsNone(r['lines'][0]['estimate'])

    def test_ctc_repeats_and_gaps(self):
        rows = [[0, -20], [-20, 0], [-20, 0], [0, -20], [0, -20], [-20, 0], [0, -20]]
        self.assertEqual(ctc_path(rows, [1, 1]), [(1, 3), (5, 6)])
        self.assertEqual(ctc_path(rows, [1, 1]), ctc_path(rows, [1, 1]))
        with self.assertRaises(AlignmentError): ctc_path([[-1, 0]], [1, 1])
        with self.assertRaises(AlignmentError): ctc_path(rows, [0])

    def test_cli_missing_model_and_correction(self):
        root = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as d:
            p = Path(d); (p/'input.txt').write_text('Light returns.')
            args = [sys.executable, str(root/'scripts/align_lyrics.py')]
            result = subprocess.run(args + ['align', '--audio', str(p/'missing.wav'), '--lyrics', str(p/'input.txt'),
                                           '--engine', 'ctc', '--language', 'en', '--model', str(p/'absent'), '--output', str(p/'out.json')], capture_output=True, text=True)
            self.assertEqual(result.returncode, 3)
            self.assertEqual(json.loads(result.stderr)['status'], 'unavailable')
            self.assertFalse((p/'out.json').exists())
            (p/'in.json').write_text(json.dumps(fixture()))
            result = subprocess.run(args + ['review', str(p/'in.json'), '--line', '0', '--note', 'Synthetic review', '--output', str(p/'out.json')], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads((p/'out.json').read_text())['lines'][0]['review'], 'accepted')
