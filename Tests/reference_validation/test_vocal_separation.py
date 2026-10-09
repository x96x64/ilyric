import sys
import tempfile
import unittest
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError
from alignment.worker import Unavailable
from alignment import vocal_separation as vs


class VocalSeparation(unittest.TestCase):
    def test_separation_is_optional(self):
        self.assertIsNone(vs.require_separator(None))

    def test_missing_checkpoint_is_unavailable(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(Unavailable):vs.require_separator(Path(d)/vs.MODEL_FILE)

    def test_checkpoint_identity_is_enforced(self):
        with tempfile.TemporaryDirectory() as d:
            for name in [vs.MODEL_FILE,'other.th']:
                f=Path(d)/name;f.write_bytes(b'not the pinned checkpoint')
                with self.assertRaises(AlignmentError):vs.require_separator(f)

    def test_policy_is_deterministic_and_recognition_only(self):
        self.assertEqual(vs.POLICY['shifts'],0);self.assertEqual(vs.POLICY['device'],'cpu')
        self.assertEqual(vs.POLICY['stem'],'vocals')
        self.assertTrue(vs.MODEL_SHA256.startswith(vs.MODEL_FILE.split('-')[1].split('.')[0]))

    def test_exact_recognition_sample_count(self):
        self.assertEqual(vs.recognition_samples(0),0)
        self.assertEqual(vs.recognition_samples(44100),16000)
        self.assertEqual(vs.recognition_samples(44101),16001)
        with self.assertRaises(AlignmentError):vs.recognition_samples(-1)
        with self.assertRaises(AlignmentError):vs.recognition_samples(1.0)

    def test_downmix_averages_without_normalization(self):
        stem=np.array([[0.5,-0.25],[0.1,0.25]],dtype=np.float32)
        np.testing.assert_allclose(vs.downmix(stem),[0.3,0.0])
        np.testing.assert_allclose(vs.downmix(stem[:1]),[0.5,-0.25])
        for bad in [np.zeros(4),np.zeros((3,4))]:
            with self.assertRaises(AlignmentError):vs.downmix(bad)

    def test_length_alignment_is_bounded(self):
        x=np.arange(10,dtype=np.float32)
        self.assertEqual(len(vs.align_length(x,9)),9)
        padded=vs.align_length(x,12);self.assertEqual(len(padded),12);self.assertEqual(padded[-1],0)
        np.testing.assert_array_equal(padded[:10],x)
        with self.assertRaises(AlignmentError):vs.align_length(x,13)
        with self.assertRaises(AlignmentError):vs.align_length(x,7)

    def test_worker_keeps_mixture_for_refinement(self):
        text=(Path(__file__).resolve().parents[2]/'scripts/alignment/audio_anchor_worker.py').read_text()
        self.assertIn("recognition[w['start_sample']:w['end_sample']]",text)
        self.assertIn("processor(signal[",text)
        self.assertNotIn("processor(recognition[",text)


if __name__=='__main__':unittest.main()
