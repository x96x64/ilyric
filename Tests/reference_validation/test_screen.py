import contextlib,io,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from screen_core import half_open,compare_components,support_status
class ScreenTests(unittest.TestCase):
 def test_half_open(self):
  self.assertEqual(half_open(dict(x=96,y=276,width=216,height=216)),[96,276,312,492])
 def test_component_errors_are_not_registration(self):
  names={'artwork':'artwork_bounds','handle':'handle_bounds','progress':'progress_bounds','volume':'volume_bounds','singExpanded':'expanded_sing_control_bounds'}
  parts=[dict(part=k,bounds=dict(x=2,y=3,width=4,height=5)) for k in names]
  profile={'geometry':{v:dict(value=[1,2,5,7],uncertainty=2) for v in names.values()}}
  values=compare_components(parts,profile)
  self.assertEqual(values['artwork']['edge_errors'],[1,1,1,1])
 def test_private_unavailable(self):
  import screen_validation
  with tempfile.TemporaryDirectory() as d,patch.object(screen_validation,'private_root',return_value=Path(d)):
   stream=io.StringIO()
   with contextlib.redirect_stdout(stream):screen_validation.main()
   self.assertEqual(json.loads(stream.getvalue())['status'],'unavailable')

 def test_unreliable_support_is_explicit(self):
  self.assertEqual(support_status(None,[0,0,10,10]),'unavailable')
  self.assertEqual(support_status([1,0,9,9],[0,0,10,10]),'unreliable-window-boundary')
  self.assertEqual(support_status([1,1,9,9],[0,0,10,10],False),'not-visible-in-inspected-state')
  self.assertEqual(support_status([1,1,9,9],[0,0,10,10]),'supported-contrast-observation')
