"""Original fixture generation requires no private inputs or third-party packages."""
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from generate_project_example import generate_project, artwork


class ProjectFixtureTests(unittest.TestCase):
    def test_complete_original_project_and_refusal(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / 'project'
            generate_project(directory)
            project = json.loads((directory / 'project.json').read_text())
            self.assertEqual(project['version'], 1)
            self.assertEqual(project['timing']['offsetMilliseconds'], 25)
            self.assertFalse(project['visibility']['volume'])
            self.assertFalse(project['visibility']['bottom'])
            for value in project['inputs'].values():
                self.assertTrue((directory / value).is_file())
            lyrics = (directory / 'lines.lrc').read_text()
            self.assertIn('[offset:+100]', lyrics)
            self.assertIn('|', lyrics)
            self.assertIn('[00:03.125]\n', lyrics)
            with self.assertRaises(FileExistsError):
                generate_project(directory)

    def test_artwork_is_deterministic_color_tagged_png(self):
        with tempfile.TemporaryDirectory() as temporary:
            a, b = Path(temporary) / 'a.png', Path(temporary) / 'b.png'
            artwork(a); artwork(b)
            data = a.read_bytes()
            self.assertEqual(data, b.read_bytes())
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            position, chunks = 8, {}
            while position < len(data):
                length = struct.unpack('>I', data[position:position+4])[0]
                kind = data[position+4:position+8]
                payload = data[position+8:position+8+length]
                crc = struct.unpack('>I', data[position+8+length:position+12+length])[0]
                self.assertEqual(crc, zlib.crc32(kind + payload))
                chunks[kind] = payload
                position += length + 12
            self.assertEqual(chunks[b'sRGB'], b'\0')
            self.assertEqual(len(zlib.decompress(chunks[b'IDAT'])), 256*(1+256*3))
