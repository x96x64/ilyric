import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
import analyze
import calibrate

class PolicyTests(unittest.TestCase):
    def test_private_path_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory).resolve()
            self.assertEqual(analyze.safe_path(root,root/'analysis.json'),root/'analysis.json')
            with self.assertRaises(ValueError):analyze.safe_path(root,root/'../outside')
            (root/'escape').symlink_to(root.parent)
            with self.assertRaises(ValueError):analyze.safe_path(root,root/'escape/outside')
    def test_missing_corpus_is_unavailable(self):
        # This path exits before optional image or numerical dependencies load.
        with tempfile.TemporaryDirectory() as directory, patch.object(analyze,'private_root',return_value=Path(directory)), patch.object(sys,'argv',['analyze.py']):
            output=io.StringIO()
            with contextlib.redirect_stdout(output):analyze.main()
            self.assertEqual(json.loads(output.getvalue())['status'],'unavailable')
    def test_missing_typography_corpus_is_unavailable(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(calibrate,'private_root',return_value=Path(directory)), patch.object(sys,'argv',['calibrate.py']):
            output=io.StringIO()
            with contextlib.redirect_stdout(output):calibrate.main()
            self.assertEqual(json.loads(output.getvalue())['status'],'unavailable')
    def test_unrelated_root_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):analyze.private_root(Path(directory))

if __name__=='__main__':unittest.main()
