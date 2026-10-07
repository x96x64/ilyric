import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from slice_validation import events_for

class SliceTests(unittest.TestCase):
    def test_explicit_break_preserves_source_indices(self):
        values={str((l,c)):{str(t):dict(lower_pts=100+t,upper_pts=110+t) for t in [180,195,210]} for l in [0,1] for c in [0,1]}
        events=events_for('丸い\n窓辺',values)
        self.assertEqual([e['start'] for e in events],[0,1,3,4])
        self.assertEqual(events[0]['verticalEvent'],dict(numerator=305,denominator=600))
        self.assertEqual(events[0]['begin'],dict(numerator=280,denominator=600))

    def test_unavailable_crossings_are_not_invented(self):
        values={str((l,0)):{str(t):None for t in [180,195,210]} for l in [0,1]}
        self.assertTrue(all(e['begin'] is None and e['verticalEvent'] is None for e in events_for('丸\n点',values)))

    def test_missing_private_inputs_are_explicit(self):
        import slice_validation
        with tempfile.TemporaryDirectory() as directory,patch.object(slice_validation,'private_root',return_value=Path(directory)):
            stream=io.StringIO()
            with contextlib.redirect_stdout(stream):slice_validation.main()
            self.assertEqual(json.loads(stream.getvalue())['status'],'unavailable')
