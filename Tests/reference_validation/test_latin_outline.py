import contextlib,io,json,math,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from latin_outline_core import decompose,relative_fit,residual_score

class LatinOutlineTests(unittest.TestCase):
 def test_common_translation_preserves_local_residuals(self):
  rows=[dict(line=i,shift=100+(i-1)*3) for i in range(3)]
  d=decompose(rows)
  self.assertEqual(d['translation'],100)
  self.assertEqual(d['line_bias'],{'0':-3,'1':0,'2':3})
  self.assertEqual(d['maximum'],3)
  self.assertEqual(d,decompose(list(reversed(rows))))
 def test_shared_coefficient_and_independent_holdout(self):
  rows=[dict(line=l,progress=t,residual=-4*(l-1)*(1-t)) for l in range(3) for t in [0,.25,.5,1]]
  p=relative_fit(rows);self.assertEqual(p,-4)
  held=[dict(line=l,progress=.75,residual=-4*(l-1)*.25) for l in range(3)]
  self.assertEqual(residual_score(held,p)['rmse'],0)
  changed=[dict(r,residual=r['residual']+2) for r in held]
  self.assertEqual(residual_score(changed,p)['rmse'],2)
 def test_invalid_support_and_bounded_fit(self):
  for rows in [[],[dict(line=0,shift=math.nan)]]:
   self.assertRaises(ValueError,decompose,rows)
  self.assertRaises(ValueError,relative_fit,[dict(line=1,progress=0,residual=0)])
  self.assertEqual(relative_fit([dict(line=2,progress=0,residual=20)]),10)
 def test_private_inputs_unavailable(self):
  import latin_outline
  with tempfile.TemporaryDirectory() as directory,patch.object(latin_outline,'private_root',return_value=Path(directory)):
   output=io.StringIO()
   with contextlib.redirect_stdout(output):latin_outline.main()
   self.assertEqual(json.loads(output.getvalue())['status'],'unavailable')
