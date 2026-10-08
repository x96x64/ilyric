"""Original synthetic tests: no model, optional dependencies, audio corpus, or network."""
import copy
from fractions import Fraction
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError
from alignment.veracity import frame_time, postprocess, THRESHOLD, RATE, HOP
from alignment.worker import Unavailable
import veracity_features


class VeracityTests(unittest.TestCase):
    def test_exact_native_grid(self):
        self.assertEqual(frame_time(1),Fraction(1,70))
        self.assertEqual(frame_time(4200),60)
        for x in [-1,True,1.5]:
            with self.assertRaises(AlignmentError):frame_time(x)

    def test_threshold_and_clipped_endpoint(self):
        samples=RATE
        self.assertEqual(postprocess([THRESHOLD]*71,samples)['intervals_samples'],[])
        self.assertEqual(postprocess([1.]*71,samples)['intervals_samples'],[[0,samples]])
        self.assertEqual(postprocess([1.]*71,samples+1)['intervals_samples'],[[0,samples+1]])

    def test_upper_median_and_replicated_edges(self):
        xs=[0.]*40+[1.]*61
        out=postprocess(xs,100*HOP)
        self.assertEqual(out['filtered_scores'][:40],[0.]*40)
        self.assertEqual(out['filtered_scores'][40:],[1.]*61)
        self.assertEqual(out['intervals_samples'],[[40*HOP,100*HOP]])
        self.assertEqual(postprocess([.8],1)['filtered_scores'],[.8])

    def test_validation_and_nonmutation(self):
        for xs,n in [([],1),([float('nan')],1),([float('inf')],1),([True],1),([-.1],1),([1.1],1),([0.],0),([0.],RATE*61)]:
            with self.assertRaises(AlignmentError):postprocess(xs,n)
        xs=[.1,.8]*40;before=copy.deepcopy(xs)
        a=postprocess(xs,79*HOP);self.assertEqual(xs,before)
        self.assertEqual(a,postprocess(xs,79*HOP))

    def test_random_order_determinism(self):
        cases={i:[random.Random(i+j).random() for j in range(i+1)] for i in [30,70,100]}
        expected={i:postprocess(xs,i*HOP) for i,xs in cases.items()}
        for i in [100,30,70,30,100]:self.assertEqual(postprocess(cases[i],i*HOP),expected[i])

    def test_missing_model_and_dependency(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)
            result=subprocess.run([sys.executable,'scripts/veracity_features.py','--audio',str(root/'missing.wav'),'--checkpoint',str(root/'missing.pt'),'--filter',str(root/'missing.npz'),'--output',str(root/'out.json')],capture_output=True,text=True)
            self.assertEqual(result.returncode,3)
            self.assertEqual(json.loads(result.stdout)['status'],'unavailable')
            self.assertFalse((root/'out.json').exists())
            (root/'audio').write_bytes(b'original');(root/'checkpoint').write_bytes(b'original')
            with patch('veracity_features.dependencies',side_effect=Unavailable('test missing dependency')), patch('veracity_features.sys.addaudithook'):
                with self.assertRaises(Unavailable):veracity_features.extract(root/'audio',root/'checkpoint',root/'checkpoint')
            self.assertEqual((root/'audio').read_bytes(),b'original')
