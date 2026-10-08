"""Independent checks of original boundary fixtures and deterministic generation."""
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from generate_enhanced_example import generate_project


class EnhancedFixtureTests(unittest.TestCase):
    def test_supplied_boundary_contract(self):
        root = Path(__file__).resolve().parents[2] / 'fixtures/enhanced-lrc'
        text = (root / 'lines.lrc').read_text()
        lines = [line for line in text.splitlines() if '<' in line]
        self.assertEqual(len(lines), 5)
        previous = 0
        for line in lines:
            boundaries = re.findall(r'<([0-9]{2}):([0-9]{2})\.([0-9]{3})>', line)
            times = [int(m)*60000 + int(s)*1000 + int(ms) for m, s, ms in boundaries]
            self.assertTrue(all(a < b for a, b in zip(times, times[1:])))
            self.assertTrue(all(b < 10003 for b in times))
            self.assertTrue(line.endswith('>'))
            self.assertGreater(times[0], previous)
            previous = times[-1]
        self.assertIn('[00:03.125]\n', text)
        self.assertIn('AV <00:00.950>office, ', text)
        stress = (root / 'unicode.lrc').read_bytes()
        for original in ['e\u0301', '👩‍💻', '✈️']:
            self.assertIn(original.encode(), stress)

    def test_example_is_reproducible_and_explicit(self):
        with tempfile.TemporaryDirectory() as folder:
            a, b = Path(folder)/'a', Path(folder)/'b'
            self.assertEqual(generate_project(a), generate_project(b))
            for name in ['project.json', 'lines.lrc', 'source.wav', 'artwork.png']:
                self.assertEqual((a/name).read_bytes(), (b/name).read_bytes())
            project = json.loads((a/'project.json').read_text())
            self.assertEqual(project['version'], 2)
            self.assertEqual(project['inputs']['lyricsFormat'], 'enhanced-lrc')
            self.assertEqual(project['timing']['highlighting'], 'enabled')
            self.assertTrue(all(not Path(value).is_absolute() for key, value in project['inputs'].items() if key != 'lyricsFormat'))
            with self.assertRaises(FileExistsError):
                generate_project(a)
