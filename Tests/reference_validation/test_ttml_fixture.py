"""Independent exact timing and original asset checks for the bounded TTML fixture."""
from fractions import Fraction
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from generate_ttml_example import generate_project


class TTMLFixtureTests(unittest.TestCase):
    root = Path(__file__).resolve().parents[2]
    def test_cross_format_exact_timing_and_structure(self):
        def time(value):
            if ':' in value:
                h, m, s = value.split(':')
                return Fraction(h)*3600 + Fraction(m)*60 + Fraction(s)
            return Fraction(value[:-1])
        ns = '{http://www.w3.org/ns/ttml}'
        xml = ET.parse(self.root/'fixtures/ttml/lines.ttml')
        paragraphs = xml.findall('.//'+ns+'p')
        self.assertEqual(len(paragraphs), 4)
        self.assertIsNone(paragraphs[1].text)
        rows = (self.root/'fixtures/enhanced-lrc/lines.lrc').read_text().splitlines()[2:]
        reconstructed = []
        for p in [paragraphs[0], paragraphs[2], paragraphs[3]]:
            begin = time(p.attrib['begin'])
            segments, text = [], ''
            for node in p:
                if node.tag == ns+'br':
                    text += '\n'; continue
                start = begin + time(node.attrib['begin'])
                end = begin + time(node.attrib['end']) if 'end' in node.attrib else start + time(node.attrib['dur'])
                segments.append((node.text, start, end)); text += node.text
            reconstructed.extend(segments)
            if len(p) == 1:
                self.assertEqual(text, ''.join(p.itertext()))
        expected = []
        for row in rows:
            tags = list(re.finditer(r'<(\d+):(\d+\.\d+)>', row))
            for a, b in zip(tags, tags[1:]):
                start = Fraction(a[1])*60+Fraction(a[2])+Fraction(1,8)
                end = Fraction(b[1])*60+Fraction(b[2])+Fraction(1,8)
                expected.append((row[a.end():b.start()], start, end))
        self.assertEqual(reconstructed, expected)
        self.assertTrue(any((start*60).denominator != 1 for _, start, _ in reconstructed))
        stress = ET.parse(self.root/'fixtures/ttml/unicode.ttml')
        self.assertIn('e\u0301, 👩‍💻 ✈️, AV office.', ''.join(stress.getroot().itertext()))
        negative = json.loads((self.root/'fixtures/ttml/invalid.json').read_text())
        self.assertEqual(len(negative), 30)
        self.assertIn('<!DOCTYPE', negative['external-dtd'])
        self.assertIn('<!ENTITY', negative['entity-declaration'])

    def test_generation_is_reproducible_and_local(self):
        with tempfile.TemporaryDirectory() as temp:
            a, b = Path(temp)/'a', Path(temp)/'b'
            self.assertEqual(generate_project(a), generate_project(b))
            for name in ['project.json', 'lines.ttml', 'source.wav', 'artwork.png']:
                self.assertEqual((a/name).read_bytes(), (b/name).read_bytes())
            value = json.loads((a/'project.json').read_text())
            self.assertEqual(value['version'], 3)
            self.assertEqual(value['inputs']['lyricsFormat'], 'ttml')
            self.assertTrue(all(not Path(path).is_absolute() for key, path in value['inputs'].items() if key != 'lyricsFormat'))
            with self.assertRaises(FileExistsError): generate_project(a)
