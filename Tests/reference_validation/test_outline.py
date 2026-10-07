import contextlib
import io
import json
from pathlib import Path
import random
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from outline_core import crossing,treatment,fit,predict,residuals,vertical_edges


class OutlineTests(unittest.TestCase):
    def test_crossing_uses_original_pts_and_requires_a_bracket(self):
        self.assertEqual(crossing([(9,100),(19,170),(28,220)],195),dict(lower_pts=19,upper_pts=28))
        self.assertIsNone(crossing([(9,220),(19,230)],195))
        with self.assertRaises(ValueError):crossing([(10,0),(10,1)],.5)

    def test_bounded_arbitrary_age_is_order_independent(self):
        times=[-.1,0,.1,.8,4]
        expected={t:treatment(t,.19) for t in times}
        self.assertEqual(expected[-.1],1)
        self.assertTrue(all(0<=v<=1 for v in expected.values()))
        random.Random(7).shuffle(times)
        self.assertEqual({t:treatment(t,.19) for t in times},expected)
        with self.assertRaises(ValueError):treatment(0,0)

    def fixture(self):
        return [dict(line=l,age=t,level=150 if t<0 else 250,dy=1+.5*l+6*treatment(t,.19))
                for l in [0,1] for t in [-.2,0,.1,.3,.6,1.2]]

    def test_shared_fit_recovers_synthetic_treatment(self):
        result=fit(self.fixture(),'vertical')
        self.assertAlmostEqual(result['tau'],.19)
        for a,b in zip(result['coefficients'],[1,.5,6]):self.assertAlmostEqual(a,b)
        self.assertLess(result['training']['rmse'],1e-10)
        self.assertAlmostEqual(predict(dict(line=0,age=None),result),7)
        self.assertGreater(fit(self.fixture(),'fixed')['training']['rmse'],1)

    def test_held_out_geometry_is_not_registered_again(self):
        training=self.fixture();result=fit(training,'vertical')
        held=[dict(r,dy=r['dy']+2) for r in training]
        self.assertAlmostEqual(residuals(held,result)['rmse'],2)
        before=[predict(r,result) for r in held]
        residuals(held,result)
        self.assertEqual(before,[predict(r,result) for r in held])

    def test_incomplete_design_cannot_produce_a_model(self):
        with self.assertRaises(ValueError):fit([dict(line=0,dy=0)],'fixed')
        with self.assertRaises(ValueError):fit([],'fixed')

    def test_outline_displacement_and_missing_support(self):
        a=[[0,0,1,1,0,0]]*3;b=[[0,1,1,0,0,0]]*3
        self.assertEqual(vertical_edges(a,b)['mean_displacement'],-1)
        self.assertEqual(vertical_edges(a,[[0]*6]*3)['status'],'unavailable')
        self.assertEqual(vertical_edges(a,a)['rms_displacement'],0)

    def test_private_inputs_are_optional(self):
        import glyph_outline
        with tempfile.TemporaryDirectory() as directory,patch.object(glyph_outline,'private_root',return_value=Path(directory)):
            stream=io.StringIO()
            with contextlib.redirect_stdout(stream):glyph_outline.main()
            self.assertEqual(json.loads(stream.getvalue())['status'],'unavailable')

if __name__=='__main__':unittest.main()
