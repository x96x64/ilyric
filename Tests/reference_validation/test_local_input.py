import importlib.util
from pathlib import Path
import tempfile
import unittest
import wave


spec = importlib.util.spec_from_file_location('generate_local_audio', Path(__file__).resolve().parents[2] / 'scripts/generate_local_audio.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LocalFixtureTests(unittest.TestCase):
    def test_original_audio_bounds_and_distinct_channels(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'fixture.wav'
            result = module.generate(path, 48000, 1)
            with wave.open(str(path)) as source:
                self.assertEqual((source.getnchannels(), source.getframerate(), source.getnframes()), (2, 48000, 48000))
                first = source.readframes(100)
                self.assertEqual(first, bytes(400))
                source.setpos(16000)
                data = source.readframes(100)
                self.assertNotEqual(data[0:2], data[2:4])
            self.assertEqual(result['frames'], 48000)
            with self.assertRaises(ValueError):
                module.generate(path)
            with self.assertRaises(ValueError):
                module.generate(Path(folder) / 'bad.wav', 999999)
