import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from latin_core import fit_origin,errors

class LatinTests(unittest.TestCase):
    def test_case_balanced_origin_and_holdout(self):
        def rows(count):return [dict(line=i,baseline_proxy=790+125*i,origin_translation=[96,0]) for i in range(count)]
        fit=fit_origin({'a':rows(2),'b':rows(3)})
        self.assertAlmostEqual(fit['first_baseline'],790)
        self.assertAlmostEqual(fit['line_advance'],125)
        self.assertAlmostEqual(fit['origin_x'],96)
        self.assertLess(errors(rows(4),fit)['maximum'],1e-10)
        shifted=rows(2);shifted[0]['baseline_proxy']+=4
        self.assertAlmostEqual(errors(shifted,fit)['maximum'],4)

    def test_invalid_or_underidentified_proxies(self):
        for cases in [{},{'a':[]},{'a':[dict(line=0,baseline_proxy=790,origin_translation=[96,0])]}]:
            with self.assertRaises(ValueError):fit_origin(cases)

    def test_private_commands_report_unavailable(self):
        import latin_validation,latin_integration
        for module in [latin_validation,latin_integration]:
            with tempfile.TemporaryDirectory() as directory,patch.object(module,'private_root',return_value=Path(directory)):
                output=io.StringIO()
                with contextlib.redirect_stdout(output):module.main()
                self.assertEqual(json.loads(output.getvalue())['status'],'unavailable')
