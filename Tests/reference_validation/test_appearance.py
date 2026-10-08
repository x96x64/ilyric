import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from appearance_core import progression

class AppearanceTests(unittest.TestCase):
    def test_spatial_direction_bounds_and_temporal_difference(self):
        self.assertGreater(progression(.2,0,'spatial'),progression(.8,0,'spatial'))
        self.assertEqual(progression(.2,0,'temporal'),progression(.8,0,'temporal'))
        for mode in ['baseline','spatial','temporal']:
            self.assertEqual(progression(.5,-10,mode),0)
            self.assertEqual(progression(.5,10,mode),1)
            self.assertEqual(progression(.5,0,mode),.5)

    def test_time_order_and_monotonicity(self):
        times=[-2,-1,0,1,2]
        expected=[progression(.5,t,'spatial',scale=3) for t in times]
        self.assertEqual(expected,sorted(expected))
        self.assertEqual([progression(.5,times[i],'spatial',scale=3) for i in [4,0,2,1,3]], [expected[i] for i in [4,0,2,1,3]])

    def test_invalid_parameters(self):
        for options in [dict(scale=0),dict(softness=0),dict(offset=float('nan')),dict(advance=0)]:
            with self.assertRaises(ValueError):progression(.5,0,'spatial',**options)

    def test_unavailable_without_optional_dependencies(self):
        import appearance_validation
        with tempfile.TemporaryDirectory() as directory,patch.object(appearance_validation,'private_root',return_value=Path(directory)):
            output=io.StringIO()
            with contextlib.redirect_stdout(output):appearance_validation.main()
            self.assertEqual(json.loads(output.getvalue())['status'],'unavailable')

    def test_baseline_changes_are_rejected(self):
        from appearance_validation import verify_baseline
        verify_baseline({'rows':[1,2],'aggregate':3},{'rows':[1,2]})
        with self.assertRaises(ValueError):verify_baseline({'rows':[1,2]},{'rows':[1,3]})
