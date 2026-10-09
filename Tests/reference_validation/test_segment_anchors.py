import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError,source
from alignment.audio_anchors import match,review_artifact,observations
from alignment.full_song import windows,review,to_ttml
from alignment.whisper_anchors import DECODING
from alignment.segment_anchors import SEGMENT_DECODING,convert_segments,segment_evidence,project


class SegmentAnchors(unittest.TestCase):
    def row(self,text=' Bright wind',a=1000,b=3000,tokens=None):
        return dict(text=text,offsets={'from':a,'to':b},tokens=tokens or [])
    def raw(self,rows):return dict(result=dict(language='en'),params=dict(translate=False),transcription=rows)
    def evidence(self,rows,duration=10000000):
        w=windows((duration*16000+999999)//1000000)[0]
        return segment_evidence('a'*64,duration,[convert_segments(self.raw(rows),w,duration)])
    def test_invalid_token_times_do_not_destroy_segment_text(self):
        row=self.row(tokens=[dict(text=' Bright',offsets={'from':1000,'to':1000}),dict(text=' wind')])
        before=copy.deepcopy(row);e=self.evidence([row]);a,rejected=project(e)
        self.assertEqual(row,before);self.assertEqual(e['windows'][0]['segments'][0]['token_timing_issues'],{'invalid':1,'missing':1})
        self.assertEqual(a['observations'][0]['text'],' Bright wind');self.assertFalse(rejected)
        self.assertEqual([t['interval_us'] for t in observations(a)[0]],[[1000000,3000000]]*2)
    def test_missing_invalid_and_outside_support_remains_unassigned(self):
        rows=[self.row(a=1000,b=1000),self.row(a=-10),self.row(b=11000),self.row(a=1231),dict(text='Exact text',tokens=[])]
        e=self.evidence(rows);a,b=project(e)
        self.assertEqual(len(b),5);self.assertFalse(a['observations'])
        self.assertEqual([s['text'] for s in e['windows'][0]['segments']],[r['text'] for r in rows])
        self.assertEqual(e['windows'][0]['segments'][-1]['support']['status'],'missing')
    def test_non_frame_aligned_exact_support(self):
        a,_=project(self.evidence([self.row(a=1230,b=2340)]));r=a['observations'][0]
        self.assertEqual([r['begin_tick'],r['end_tick']],[123,234]);self.assertEqual(a['timebase_hz'],100)
    def test_unicode_text_is_never_normalized(self):
        text=' e\u0301 花\ufe0f 👩\u200d🎤';e=self.evidence([self.row(text)])
        a,_=project(e);self.assertEqual(a['observations'][0]['text'],text)
        self.assertFalse(observations(a)[0]);self.assertEqual(e['granularity'],'segment')
    def test_nonchronological_support_is_ambiguous(self):
        e=self.evidence([self.row(a=3000,b=4000),self.row(a=1000,b=2000)])
        a,rejected=project(e);self.assertEqual(len(a['observations']),1)
        self.assertEqual(rejected[0]['reason'],'segment_timing_ambiguous')
    def test_shared_segment_does_not_fabricate_two_line_intervals(self):
        a,_=project(self.evidence([self.row('Bright wind soft river')]))
        r=match(source(b'Bright wind\nSoft river'),a)
        self.assertLess(sum(d['state']=='supported' for d in r['decisions']),2)
        self.assertTrue(all(x['estimate'] is None for x in review_artifact(r)['lines']))
    def test_repeated_occurrences_keep_identity(self):
        a,_=project(self.evidence([self.row(),self.row(a=6000,b=8000)]))
        r=match(source(b'Bright wind\n\nBright wind'),a)
        self.assertEqual([d['occurrence'] for d in r['decisions']],[0,1]);self.assertTrue(all(d['state']=='supported' for d in r['decisions']))
        self.assertNotEqual(r['decisions'][0]['region_us'],r['decisions'][1]['region_us'])
    def test_extra_repeated_segment_stays_ambiguous(self):
        a,_=project(self.evidence([self.row(),self.row(a=6000,b=8000)]))
        r=match(source(b'Bright wind'),a);self.assertEqual(r['decisions'][0]['state'],'ambiguous')
    def test_midpoint_window_ownership_unchanged(self):
        plan=windows(16000*55000//1000)
        e=segment_evidence('a'*64,55000000,[convert_segments(self.raw([self.row(a=27000,b=29000)]),plan[0],55000000),
            convert_segments(self.raw([self.row(a=1000,b=3000)]),plan[1],55000000)])
        a,_=project(e);tokens,bad=observations(a)
        self.assertEqual(len(tokens),2);self.assertEqual(tokens[0]['window'],1);self.assertEqual(len(bad),1)
    def test_correction_reuse_preserves_source_and_evidence(self):
        e=self.evidence([self.row()]);before=copy.deepcopy(e);a,_=project(e)
        r=review_artifact(match(source(b'Bright wind'),a));fixed=review(r,[dict(line=0,interval_us=[1000123,2500000],note='Original synthetic correction')])
        self.assertIn('1.000123s',to_ttml(fixed));self.assertIsNone(fixed['lines'][0]['estimate']);self.assertEqual(e,before)
        self.assertEqual(match(source(b'Bright wind'),a),match(source(b'Bright wind'),a))
    def test_altered_support_and_resource_limits_fail(self):
        e=self.evidence([self.row()]);e['windows'][0]['segments'][0]['support']['source_ticks']=[1,2]
        with self.assertRaises(AlignmentError):project(e)
        with self.assertRaises(AlignmentError):self.evidence([self.row('x'*2001)])
    def test_only_segment_split_parameter_changes(self):
        a=list(SEGMENT_DECODING);a[a.index('-ml')+1]='1';self.assertEqual(a,DECODING)
    def test_lexical_diagnostic_does_not_supply_timestamps(self):
        from evaluate_segment_anchors import lexical_support
        self.assertTrue(lexical_support(['bright','wind'],['music','bright','wind','music']))
        self.assertFalse(lexical_support(['soft','river'],['bright','wind']))
        self.assertFalse(lexical_support(['wind'],['wind']))
    def test_reference_scoring_is_separate_and_preserves_unresolved_timing(self):
        from evaluate_segment_anchors import evaluate
        from alignment.full_song import fingerprint as prepared_fingerprint
        from alignment.audio_anchors import fingerprint
        e=self.evidence([self.row()]);a,_=project(e);r=match(source(b'Bright wind'),a)
        old=review_artifact(r);prepared=copy.deepcopy(old)
        prepared['engine']['segment_evidence_sha256']=fingerprint(e)
        prepared['proposal_sha256']=prepared_fingerprint(prepared)
        before=copy.deepcopy(prepared)
        out=evaluate(e,r,prepared,r,old,old,[dict(text='Bright wind',interval_us=[1200000,2800000])])
        self.assertEqual(out['segment_correspondence']['eligible_candidate_reference_overlap'],1)
        self.assertFalse(out['m1_pass']);self.assertEqual(out['segment_refinement']['estimated'],0)
        self.assertEqual(prepared,before)
