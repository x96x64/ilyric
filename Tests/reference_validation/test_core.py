import importlib.util
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('core',Path(__file__).resolve().parents[2]/'scripts/reference_validation/core.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)

class ReferenceTests(unittest.TestCase):
    def test_actual_pts(self):
        self.assertEqual(c.timing([0,10,19,29])['interval_counts'],{'1/60':2,'3/200':1})
        with self.assertRaises(ValueError):c.timing([0,10,10])
    def test_uniform_native_transform(self):
        self.assertAlmostEqual(c.transform((1179,2556),(1080,1920),'contain')['x'],97.18309859)
        self.assertLess(c.transform((1179,2556),(1080,1920),'cover')['y'],0)
        with self.assertRaises(ValueError):c.transform((1179,2556),(1080,1920),'adapt')
    def test_fit_and_held_out(self):
        p=dict(model='hermite',onset=.2,duration=.8,offset=710,amplitude=-290)
        samples=[(i/60,c.evaluate(p,i,60)) for i in range(90)]
        f=c.fit(samples[::2],'hermite',[.1,.2,.3],[.7,.8,.9])
        self.assertLess(c.errors(samples[1::2],f)['max_error'],1e-9)
        expected=[c.evaluate(f,i,60) for i in range(90)]
        self.assertEqual(expected,list(reversed([c.evaluate(f,i,60) for i in reversed(range(90))])))
        self.assertEqual(c.evaluate(f,1,2),c.evaluate(f,30,60))
    def test_model_mismatch_is_visible(self):
        p=dict(model='critical',onset=.2,duration=.12,offset=900,amplitude=-400)
        samples=[(i/60,c.evaluate(p,i,60)) for i in range(90)]
        wrong=c.fit(samples,'hermite',[.1,.2,.3],[.4,.6,.8])
        self.assertGreater(wrong['rmse'],3)
    def test_local_registration(self):
        a={(1,1),(2,1),(1,2)}; b={(3,2),(4,2),(3,3)}
        self.assertEqual(c.registered_mask(a,b),{'dx':-2,'dy':-1,'iou':1.0})
    def test_degenerate_data(self):
        with self.assertRaises(ValueError):c.fit([(0,1)]*4,'hermite',[1],[1])

if __name__=='__main__':unittest.main()
