import contextlib,io,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from inactive_core import progression,parameters,quadratic_error,select,score
class InactiveTests(unittest.TestCase):
 def test_boundaries_and_order(self):
  values=[progression(t,.15) for t in [-1,0,.075,.15,1]]
  self.assertEqual(values,[0,0,.5,1,1])
  self.assertEqual([progression(t,.15) for t in [1,0,.075,-1,.15]],[1,0,.5,0,1])
 def test_support_loss(self):
  self.assertAlmostEqual(quadratic_error([4,2,1],.5),0)
  self.assertEqual(parameters(-1,'interpolated',8,.42,1,.15),(8,.42))
  self.assertEqual(parameters(1,'interpolated',8,.42,1,.15),(0,1))
 def test_fit_independent_synthetic_repetition(self):
  def record(t):
   radius,gain=parameters(t,'interpolated',8,.3,.7,.15)
   return dict(elapsed=t,terms=[[1,gain,gain*gain+(b-radius)**2] for b in range(11)])
  training=[record(t) for t in [-.5,-.3,0,.075,.15,.6,.8]]
  fit=select(training,'interpolated')
  self.assertEqual(fit['blur'],8);self.assertEqual(fit['duration'],.15)
  self.assertAlmostEqual(score([record(t) for t in [-.8,.075,.7]],fit),0)
 def test_private_unavailable(self):
  import inactive_validation
  with tempfile.TemporaryDirectory() as d,patch.object(inactive_validation,'private_root',return_value=Path(d)):
   stream=io.StringIO()
   with contextlib.redirect_stdout(stream):inactive_validation.main()
   self.assertEqual(json.loads(stream.getvalue())['status'],'unavailable')
