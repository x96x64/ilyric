import unittest,sys,subprocess,tempfile,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from motion_core import shape,score,crossing

class MotionTests(unittest.TestCase):
 def test_analytic_boundaries(self):
  for m in ['critical','hermite','quintic']:
   self.assertEqual(shape(-1,0,.1,m),0)
   self.assertAlmostEqual(shape(20,0,.1,m),1)
   self.assertEqual(shape(.05,0,.1,m),shape(.05,0,.1,m))
  self.assertRaises(ValueError,shape,0,0,.1,'unknown')
 def test_phase_and_holdout(self):
  p=dict(model='critical',onset=1,scale=.081,offset=900,amplitude=-325)
  track=[(i/60,900-325*shape(i/60,1,.081,'critical')) for i in range(180)]
  shifted=[(t+.125,y) for t,y in track]
  shift=crossing(shifted)-crossing(track)
  self.assertAlmostEqual(shift,.125)
  self.assertLess(score(shifted,p,shift)['maximum'],1e-9)
  self.assertGreater(score(shifted,p,shift+.0167)['maximum'],20)
  self.assertRaises(ValueError,crossing,[(0,1)]*9)

 def test_unavailable(self):
  import motion_composition,contextlib,io
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as directory,patch.object(motion_composition,'private_root',return_value=Path(directory)):
   output=io.StringIO()
   with contextlib.redirect_stdout(output):motion_composition.main()
   self.assertEqual(json.loads(output.getvalue())['status'],'unavailable')
