import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from state_core import stable_intervals,affine_landmarks,summarize,spacing_holdout


class StateTests(unittest.TestCase):
    def test_actual_pts_and_observed_duration(self):
        samples=[dict(pts=p,geometry=[10,20]) for p in [0,10,19,29]]
        result=stable_intervals(samples,'1/600',[0,0],.04,.02)
        self.assertEqual(result[0]['duration_seconds'],29/600)
        self.assertEqual(result[0]['count'],4)
        self.assertEqual(stable_intervals(samples,'1/600',[0,0],2,.02),[])

    def test_missing_or_ineligible_observations_break_runs(self):
        samples=[dict(pts=p,geometry=[10]) for p in [0,10,20,100,110,120]]
        self.assertEqual(len(stable_intervals(samples,'1/600',[0],.03,.02)),2)
        samples[1]['geometry']=None
        self.assertEqual(len(stable_intervals(samples,'1/600',[0],.03,.02)),1)

    def test_slow_drift_is_not_misclassified_as_stable(self):
        samples=[dict(pts=i*10,geometry=[i*.5]) for i in range(60)]
        self.assertEqual(stable_intervals(samples,'1/600',[2],.5),[])

    def test_invalid_or_reordered_observations_are_rejected(self):
        with self.assertRaises(ValueError):
            stable_intervals([dict(pts=10,geometry=[1]),dict(pts=0,geometry=[1])],'1/600',[2])
        with self.assertRaises(ValueError):stable_intervals([dict(pts=0,geometry=[float('nan')])],'1/600',[2])
        with self.assertRaises(ValueError):summarize([])

    def test_translation_is_separate_from_spacing(self):
        reference=[10,30,50,70,90]
        fit=affine_landmarks(reference,[v*1.02+3 for v in reference])
        self.assertAlmostEqual(fit['scale'],1.02)
        self.assertAlmostEqual(fit['translation'],3)
        self.assertLess(fit['rmse'],1e-12)
        self.assertGreater(fit['translation_only_rmse'],.5)
        self.assertEqual(fit,affine_landmarks(reference,[v*1.02+3 for v in reference]))
        with self.assertRaises(ValueError):affine_landmarks([1]*3,[2]*3)

    def test_spacing_holdout_does_not_fit_excluded_scale(self):
        reference=[10,30,50,70,90]
        pairs={'a':dict(reference=reference,observed=[1.02*x+3 for x in reference]),
               'b':dict(reference=reference,observed=[1.06*x-5 for x in reference])}
        result=spacing_holdout(pairs)
        self.assertAlmostEqual(result['b']['scale'],1.02)
        self.assertGreater(result['b']['rmse'],1)
        self.assertEqual(result,spacing_holdout(dict(reversed(list(pairs.items())))))
        with self.assertRaises(ValueError):spacing_holdout({'a':pairs['a']})

    def test_missing_state_corpus_is_unavailable(self):
        import state_typography
        with tempfile.TemporaryDirectory() as directory, patch.object(state_typography,'private_root',return_value=Path(directory)), patch.object(sys,'argv',['state_typography.py']):
            stream=io.StringIO()
            with contextlib.redirect_stdout(stream):state_typography.main()
            self.assertEqual(json.loads(stream.getvalue())['status'],'unavailable')

if __name__=='__main__':unittest.main()
