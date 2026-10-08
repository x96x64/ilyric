"""Original deterministic controls; no models, private corpus, or network."""
import copy
import json
from pathlib import Path
import random
import subprocess
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError, source, make_result, review, to_ttml
from alignment.coverage import intervals, difference, active_intervals, coverage, lexical_disagreement, fit_threshold, flagged, confusion
from diagnose_acoustic_coverage import assess
from evaluate_acoustic_coverage import freeze, score


class CoverageTests(unittest.TestCase):
    def fixture(self):
        a=make_result(source(b'Quiet light.\n\nQuiet light.'),'a'*64,6000000,
                      dict(identity='synthetic',language='en',precision_us=20000),
                      [dict(text='Quiet light.',begin_us=1000000,end_us=2000000),dict(text='Quiet light.',begin_us=3000000,end_us=4000000)])
        f=dict(version=1,audio_sha256='a'*64,duration_us=6000000,greedy_text='QUIET LIGHT QUIET LIGHT',
               spectral_activity_us=[[1000000,2000000],[3000000,4000000]],ctc_activity_us=[[1000000,2000000],[3000000,4000000]],
               provenance={'source_conditioning':'audio only; no supplied text'})
        return a,f

    def test_half_open_union_and_difference(self):
        self.assertEqual(intervals([[30,40],[10,30]],100),[(10,40)])
        self.assertEqual(difference([[0,100]],[[20,30],[40,60]],100),[[0,20],[30,40],[60,100]])
        self.assertEqual(difference([[20,30]],[[0,20],[30,40]],100),[[20,30]])

    def test_invalid_bounds_and_limits(self):
        for xs in [[[True,20]],[[0,0]],[[20,10]],[[0,101]],[[0,1]]*6001]:
            with self.assertRaises(AlignmentError):intervals(xs,100)
        for duration in [True,0,60000001]:
            with self.assertRaises(AlignmentError):intervals([],duration)

    def test_exact_grid_and_no_frame_rounding(self):
        self.assertEqual(active_intervals([True,False,True],10000,29999),[(0,10000),(20000,29999)])
        with self.assertRaises(AlignmentError):active_intervals([1],10000,10000)
        with self.assertRaises(AlignmentError):active_intervals([True],10000,1000000)

    def test_gap_and_omission_are_not_equivalent(self):
        normal=coverage([[10,20],[40,60]],[[10,20],[40,60]],100)
        self.assertEqual(normal['score'],0)
        missing=coverage([[10,20],[40,60]],[[10,20]],100)
        self.assertEqual(missing['unexplained_activity_us'],[[40,60]])
        self.assertAlmostEqual(missing['score'],2/3)
        # The same evidence can be an instrument: no automatic singing label.
        self.assertIn('neither vocal',missing['semantics'])

    def test_unsupported_terminal_extension(self):
        d=coverage([[10,50]],[[10,90]],100)
        self.assertEqual(d['unsupported_estimate_us'],[[50,90]])
        self.assertEqual(d['score'],.5)
        self.assertIsNone(coverage([],[[10,90]],100)['score'])

    def test_lexical_repeat_omission_order(self):
        self.assertEqual(lexical_disagreement('Quiet light, quiet light.','QUIET LIGHT QUIET LIGHT'),0)
        self.assertGreater(lexical_disagreement('Quiet light.','QUIET LIGHT QUIET LIGHT'),0)
        self.assertGreater(lexical_disagreement('Light quiet.','QUIET LIGHT'),0)
        self.assertIsNone(lexical_disagreement('Light',''))
        with self.assertRaises(AlignmentError):lexical_disagreement('光','LIGHT')
        with self.assertRaises(AlignmentError):lexical_disagreement('a'*1501,'a')

    def test_development_separation_and_unknown_scores(self):
        rows=[dict(role='development',matched=m,score=s) for m,s in [(True,.2),(False,.5),(False,.1)]]
        self.assertEqual(fit_threshold(rows),.35)
        with self.assertRaises(AlignmentError):fit_threshold(rows+[dict(role='reserved',matched=True,score=.9)])
        self.assertFalse(flagged(.35,.35));self.assertIsNone(flagged(None,.35))
        with self.assertRaises(AlignmentError):flagged(float('nan'),.35)

    def test_confusion_and_uncertainty(self):
        d=confusion([dict(matched=m,flag=f) for m,f in [(False,True),(True,True),(True,False),(False,False),(True,None)]])
        self.assertEqual([d[x] for x in ['TP','FP','TN','FN','unavailable']],[1,1,1,1,1])
        self.assertEqual(d['mismatch_recall'],.5)
        self.assertGreater(d['false_rejection_wilson95'][1],.8)

    def test_source_and_estimates_are_unchanged(self):
        a,f=self.fixture();before=copy.deepcopy(a)
        r=assess(a,f);self.assertEqual(r['lexical_score'],0);self.assertFalse(r['automatic_acceptance']);self.assertEqual(a,before)
        with self.assertRaises(AlignmentError):to_ttml(a)
        f['audio_sha256']='b'*64
        with self.assertRaises(AlignmentError):assess(a,f)

    def test_corrections_reusable_without_inference(self):
        a,f=self.fixture();a=review(a,0,'1','2.1',note='Original synthetic boundary correction');a=review(a,1,note='Synthetic review')
        self.assertIn('2.100000',to_ttml(a));old=assess(a,f);new=assess(a,f,True)
        self.assertEqual(old['spectral']['score'],0);self.assertGreater(new['spectral']['score'],0)
        self.assertEqual(a['lines'][0]['estimate'],[1000000,2000000]);self.assertTrue(a['history'])

    def test_repeat_and_random_order(self):
        a,f=self.fixture();requests=[False,True]*5;random.Random(32).shuffle(requests)
        expected={v:json.dumps(assess(a,f,v),sort_keys=True) for v in [False,True]}
        for v in requests:self.assertEqual(json.dumps(assess(a,f,v),sort_keys=True),expected[v])

    def test_frozen_inputs_and_unavailable_combination(self):
        rows=[]
        for engine in ['ctc','tifa']:
            for matched,value in [(True,.1),(False,.5)]:
                rows.append(dict(engine=engine,role='development',case='EN01',variant='matched' if matched else 'absent',
                                 matched=matched,spectral=value,ctc_activity=value,lexical=value,legacy_flag=False))
        frozen=freeze(rows)
        held=dict(engine='tifa',role='reserved',case='JA04',variant='absent',matched=False,
                  spectral=None,ctc_activity=None,lexical=None,legacy_flag=True)
        result=score(rows+[held],frozen)
        cell=next(x for x in result['results'] if x['engine']=='tifa' and x['role']=='reserved' and x['candidate']=='spectral_or_legacy')
        self.assertEqual(cell['confusion']['TP'],1)
        changed=copy.deepcopy(rows);changed[0]['spectral']=.2
        with self.assertRaises(AlignmentError):score(changed+[held],frozen)

    def test_missing_optional_assets(self):
        root=Path(__file__).resolve().parents[2]
        for cmd in [[sys.executable,'scripts/coverage_features.py','--audio','absent.wav','--model','absent','--output','absent.json'],
                    [sys.executable,'scripts/diagnose_acoustic_coverage.py','absent.json','absent-features.json','--output','absent.json']]:
            r=subprocess.run(cmd,cwd=root,capture_output=True,text=True)
            self.assertEqual(r.returncode,3);self.assertEqual(json.loads(r.stdout)['status'],'unavailable')

if __name__=='__main__':unittest.main()
