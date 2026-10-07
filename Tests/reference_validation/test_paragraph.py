import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts/reference_validation'))
from paragraph_core import match_paragraph,paragraph_geometry,registered_spacing,common_registration,relative_line_shift
from state_core import stable_intervals
from paragraph_typography import candidate_errors


class ParagraphTests(unittest.TestCase):
    def test_complete_ordered_support_is_required(self):
        bounds=[[10,200,210,280],[11,330,171,410]]
        ranges=[(190,210),(150,170)]
        self.assertEqual(match_paragraph(bounds[::-1],ranges,(120,140)),bounds)
        self.assertIsNone(match_paragraph(bounds[:1],ranges,(120,140)))
        self.assertIsNone(match_paragraph(bounds,ranges,(80,110)))
        with self.assertRaises(ValueError):match_paragraph(bounds,[],(120,140))

    def test_ambiguous_paragraphs_are_not_best_fit(self):
        bounds=[[10,200,210,280],[10,330,170,410],[10,700,210,780],[10,830,170,910]]
        self.assertIsNone(match_paragraph(bounds,[(190,210),(150,170)],(120,140)))

    def test_second_line_motion_breaks_joint_stability(self):
        samples=[dict(pts=10*i,geometry=paragraph_geometry([[10,200,210,280],[10,330+i,170,410+i]])) for i in range(60)]
        self.assertEqual(stable_intervals(samples,'1/600',[2]*6,.5),[])

    def test_incomplete_threshold_support_cannot_win_selection(self):
        bounds=[[10,200,210,280],[10,330,170,410]]
        observations=[dict(measurements={'25-100':[dict(bounds=b) for b in bounds]}),dict(measurements={})]
        result=candidate_errors(bounds,observations,'25-100',2)
        self.assertFalse(result['structure_matches'])
        self.assertEqual(result['width_error'],[0,0])

    def test_external_scale_is_not_refitted(self):
        x=[10,30,50,70];y=[1.04*v+9 for v in x]
        result=registered_spacing(x,y,1.01)
        self.assertEqual(result['scale'],1.01)
        self.assertGreater(result['rmse'],.6)
        self.assertLess(registered_spacing(x,y,1.04)['rmse'],1e-12)
        with self.assertRaises(ValueError):registered_spacing(x,y,float('nan'))

    def test_common_origin_exposes_line_advance_error(self):
        first={(10,10),(11,10),(10,11)}
        second={(10,30),(11,30),(10,31)}
        shifted=[{(x+2,y+1) for x,y in first},{(x+2,y+4) for x,y in second}]
        result=common_registration([first,second],shifted,5)
        self.assertLess(result['iou'],1)
        correct=[{(x+2,y+1) for x,y in line} for line in [first,second]]
        self.assertEqual(common_registration([first,second],correct,5)['iou'],1)
        with self.assertRaises(ValueError):common_registration([first],[],5)

    def test_relative_vertical_shift_rejects_common_motion_explanation(self):
        common=relative_line_shift([50,180],[43,173])
        self.assertEqual(common['relative_to_first'],[0,0])
        relative=relative_line_shift([50,180],[50,174])
        self.assertEqual(relative['relative_to_first'],[0,-6])
        self.assertEqual(relative['translation_only_rmse'],3)
        with self.assertRaises(ValueError):relative_line_shift([50],[43])

    def test_absent_multiline_corpus_is_unavailable(self):
        import paragraph_typography
        with tempfile.TemporaryDirectory() as directory, patch.object(paragraph_typography,'private_root',return_value=Path(directory)):
            stream=io.StringIO()
            with contextlib.redirect_stdout(stream):paragraph_typography.main()
            self.assertEqual(json.loads(stream.getvalue())['status'],'unavailable')

if __name__=='__main__':unittest.main()
