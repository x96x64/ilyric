import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError,source
from alignment.full_song import windows,review,to_ttml,fingerprint,validate
from alignment.audio_anchors import match,review_artifact
from alignment.whisper_anchors import convert,anchors,refinement_window,apply_refinement,reject_overlaps,DECODING
from alignment.audio_anchor_worker import infer
from alignment.worker import Unavailable


class WhisperAnchors(unittest.TestCase):
    def raw(self,a=1230,b=1450,text=' Bright'):
        return dict(result=dict(language='en'),params=dict(translate=False),transcription=[dict(text=text,offsets=dict(**{'from':a,'to':b}))])
    def test_exact_source_relative_grid(self):
        w=windows(16000*70)[1];items,rejected=convert(self.raw(),w,70000000)
        self.assertEqual([items[0]['begin_tick'],items[0]['end_tick']],[2723,2745]);self.assertFalse(rejected)
        self.assertEqual(anchors('a'*64,70000000,items)['timebase_hz'],100)
    def test_invalid_intervals_preserved_as_rejections(self):
        for a,b in [(0,0),(-10,100),(0,30010),(1231,1450)]:
            kept,bad=convert(self.raw(a,b),windows(480000)[0],30000000)
            self.assertFalse(kept);self.assertEqual(len(bad),1)
    def test_uncertainty_and_no_text_normalization(self):
        raw=self.raw(text=' [Music]');before=copy.deepcopy(raw)
        rows,_=convert(raw,windows(480000)[0],30000000)
        self.assertEqual(raw,before);self.assertEqual(rows[0]['text'],' [Music]')
        self.assertEqual(rows[0]['uncertainty'],['nonlexical_event_or_annotation'])
    def test_language_translation_refusal(self):
        raw=self.raw();raw['params']['translate']=True
        with self.assertRaises(AlignmentError):convert(raw,windows(480000)[0],30000000)
    def test_refinement_bound_and_integer_origin(self):
        self.assertEqual(refinement_window([1000123,1800000],3000000),[0,2800000])
        with self.assertRaises(AlignmentError):refinement_window([0,40000000],60000000)
    def prepared(self):
        root=Path(__file__).resolve().parents[2]/'fixtures/audio-anchors'
        return review_artifact(match(source((root/'lyrics.txt').read_bytes()),json.loads((root/'anchors.json').read_text())))
    def local(self,a,b):return dict(proposal=[a,b],estimate=[a,b],flags=[],quality={})
    def test_boundaries_do_not_become_automatic_acceptance(self):
        prepared=self.prepared();apply_refinement(prepared,0,self.local(0,1800000),0,2800000)
        self.assertIsNone(prepared['lines'][0]['estimate']);self.assertIn('boundary_censored',prepared['lines'][0]['flags'])
        apply_refinement(prepared,0,self.local(1000000,1800000),0,2800000)
        prepared['proposal_sha256']=fingerprint(prepared);validate(prepared)
        corrected=review(prepared,[dict(line=0,interval_us=[1000123,1800000],note='Synthetic correction')])
        self.assertEqual(corrected['lines'][0]['proposal'],[1000000,1800000])
        self.assertEqual(corrected['lines'][0]['correction']['interval_us'][0],1000123)
        self.assertFalse(corrected['automatic_acceptance'])
    def test_overlaps_abstain_without_repair(self):
        p=self.prepared();apply_refinement(p,0,self.local(1000000,2400000),0,4000000)
        apply_refinement(p,1,self.local(2100000,2900000),0,4000000);reject_overlaps(p)
        self.assertTrue(all(r['estimate'] is None for r in p['lines'][:2]))
        self.assertEqual(p['lines'][0]['proposal'],[1000000,2400000])
    def test_missing_inputs_without_optional_imports(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'absent'
            with self.assertRaises(Unavailable):infer(p,p,p,p,p,Path(d)/'work')
    def test_determinism_and_context_settings(self):
        self.assertEqual(convert(self.raw(),windows(480000)[0],30000000),convert(self.raw(),windows(480000)[0],30000000))
        self.assertNotIn('--prompt',DECODING);self.assertEqual(DECODING[DECODING.index('-mc')+1],'0')
