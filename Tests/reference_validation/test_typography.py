import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from typography_core import line_strings, geometry_loss, select, leave_one_out, baseline_fit


def record(errors, matches=True):
    return dict(width_error=errors,structure_matches=matches)


class TypographyTests(unittest.TestCase):
    def test_utf16_ranges_preserve_clusters_and_explicit_breaks(self):
        self.assertEqual(line_strings('A😀e\u0301\n静かな光',[
            dict(start=0,length=6),dict(start=6,length=4)]),['A😀e\u0301','静かな光'])

    def test_wrap_mismatch_is_ineligible_even_with_perfect_widths(self):
        records={'a':{'small':record([0],False),'large':record([2])},
                 'b':{'small':record([0]),'large':record([1])}}
        self.assertEqual(select(records,['a','b'])['candidate'],'large')

    def test_case_balance_does_not_weight_long_paragraphs_more(self):
        records={'short':{'a':record([0]),'b':record([3])},
                 'long':{'a':record([2]*10),'b':record([0]*10)}}
        self.assertEqual(select(records,['short','long'])['candidate'],'a')
        self.assertEqual(select(records,['long','short']),select(records,['short','long']))

    def test_exclusion_exposes_unseen_wrap_failure(self):
        records={'a':{'small':record([0]),'large':record([2])},
                 'b':{'small':record([0],False),'large':record([1])}}
        excluded=leave_one_out(records,['a','b'])['b']
        self.assertFalse(excluded['held_out_structure_matches'])
        self.assertIsNone(excluded['held_out_width_rmse'])

    def test_tied_widths_do_not_conceal_underidentification(self):
        records={'a':{'narrow':record([0]),'wide':record([0])},
                 'b':{'narrow':record([1]),'wide':record([0],False)}}
        result=leave_one_out(records,['a','b'])['b']
        self.assertEqual(result['equally_scored_candidates'],['narrow','wide'])
        self.assertEqual(result['tied_held_out_structure_matches'],{'narrow':True,'wide':False})

    def test_shared_parameter_is_required(self):
        with self.assertRaises(ValueError):
            select({'a':{'one':record([0])},'b':{'two':record([0])}},['a','b'])
        with self.assertRaises(ValueError): leave_one_out({},['a'])
        with self.assertRaises(ValueError): geometry_loss(record([float('nan')]))

    def test_baseline_proxy_fit_keeps_residuals(self):
        result=baseline_fit([790,920,1044])
        self.assertEqual(result['line_advance'],127)
        self.assertEqual(result['residuals'],[-1,2,-1])
        self.assertEqual(result['first_baseline'],791)
        self.assertIsNone(baseline_fit([790])['line_advance'])
        with self.assertRaises(ValueError): baseline_fit([])


if __name__=='__main__':unittest.main()
