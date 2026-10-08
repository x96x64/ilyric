"""Original synthetic candidates. No media, model, or reference timestamps required."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError,source
from alignment.full_song import review,to_ttml,validate,unassigned_audio
from alignment.passage_search import POLICY,search_windows,assess,reconcile,prepare,central_lines


def candidate(name,a,b,score=.9):
    return dict(id=name,lines=[[a,b]],agreement=score,similarity=score,unresolved=[],window_bounds_us=[0,60000000])


class PassageSearchTests(unittest.TestCase):
    def test_automatic_windows_and_exact_tail(self):
        w=search_windows(75000123)
        self.assertEqual([r['start_us'] for r in w],[0,15000000,30000000,45000000,60000000])
        self.assertEqual(w[-1]['end_us'],75000123)
        self.assertTrue(all(r['end_us']-r['start_us']<=30000000 for r in w))
        for bad in [True,0,600000001]:
            with self.assertRaises(AlignmentError):search_windows(bad)

    def test_global_reconciliation_prevents_greedy_displacement(self):
        groups=[[candidate('early',1000000,2000000,.85),candidate('late',30000000,31000000,.99)],
                [candidate('following',4000000,5000000,.95)]]
        before=copy.deepcopy(groups);out=reconcile(groups,60000000)
        self.assertEqual(out['selected_path'],[(0,'early'),(1,'following')])
        self.assertEqual(groups,before)
        self.assertEqual(out,reconcile(copy.deepcopy(groups),60000000))

    def test_repeated_occurrences_cannot_reuse_one_acoustic_interval(self):
        locations=[candidate('first',1000000,2000000),candidate('second',10000000,11000000)]
        out=reconcile([locations,locations],60000000)
        self.assertEqual(out['selected_path'],[(0,'first'),(1,'second')])
        self.assertTrue(all(x['state']=='supported' for x in out['passages']))
        out=reconcile([locations,locations,locations],60000000)
        self.assertEqual(len(out['selected_path']),2)
        self.assertIn('skipped',[x['state'] for x in out['passages']])
        self.assertIn('ambiguous',[x['state'] for x in out['passages']])

    def test_ambiguous_locations_and_overlap_duplicates(self):
        groups=[[candidate('a',1000000,2000000),candidate('duplicate',1010000,2010000,.89),candidate('b',10000000,11000000)]]
        out=reconcile(groups,60000000)['passages'][0]
        self.assertEqual(out['state'],'ambiguous');self.assertEqual(out['margin'],0)
        duplicate=next(x for x in out['alternatives'] if x['id']=='duplicate')
        self.assertFalse(duplicate['eligible']);self.assertEqual(duplicate['duplicate_of'],'a')

    def test_failed_skipped_and_misordered_support(self):
        bad=candidate('invalid',0,0);self.assertFalse(assess(bad,60000000)['eligible'])
        silent=candidate('weak',1000000,2000000,.1)
        out=reconcile([[silent],[candidate('later',9000000,10000000)],[candidate('earlier',3000000,4000000,.8)]],60000000)
        self.assertEqual([p['state'] for p in out['passages']],['unresolved','supported','skipped'])
        nan=candidate('bad',1000000,2000000);nan['agreement']=float('nan')
        self.assertIn('invalid_score',assess(nan,60000000)['reasons'])

    def raw(self):
        src=source(b'Bright wind\nSoft river\n\nBright wind\nSoft river\n')
        a=candidate('a',1000000,2000000);a['lines'].append([2500000,3500000])
        b=candidate('b',41000000,42000000);b['lines'].append([42500000,43500000])
        return dict(format='ilyric-tifa-candidates-1',source=src,audio=dict(sha256='a'*64,duration_us=60000000),
                    provenance=dict(model='synthetic-TIFA-output-not-inference'),windows=search_windows(60000000),groups=[[a,b],[a,b]])

    def test_review_correction_and_ttml_reuse(self):
        raw=self.raw();before=copy.deepcopy(raw);result=prepare(raw);self.assertEqual(raw,before)
        self.assertEqual([r['id'] for r in result['lines']],[0,1,2,3])
        self.assertEqual(result['engine']['model_grid_us'],10000)
        with self.assertRaises(AlignmentError):to_ttml(result)
        out=review(result,[dict(line=i,note='Synthetic review assertion') for i in range(4)])
        out=review(out,[dict(line=0,interval_us=[1000123,1999999],note='Synthetic exact correction')])
        self.assertEqual(result['lines'][0]['estimate'],out['lines'][0]['estimate'])
        self.assertIn('1.000123s',to_ttml(out));self.assertIn('Bright wind<br/>Soft river',to_ttml(out))
        self.assertEqual(unassigned_audio(out)[-1],[43500000,60000000])
        self.assertEqual(validate(json.loads(json.dumps(out)))['proposal_sha256'],out['proposal_sha256'])

    def test_ambiguous_export_requires_explicit_resolution(self):
        raw=self.raw();raw['source']=source(b'Bright wind\nSoft river\n');raw['groups']=raw['groups'][:1]
        result=prepare(raw);self.assertTrue(all(r['estimate'] is None for r in result['lines']))
        self.assertTrue(all(r['correspondence']['state']=='ambiguous' for r in result['lines']))
        with self.assertRaises(AlignmentError):review(result,[dict(line=0,note='No supported interval')])
        corrected=review(result,[dict(line=0,interval_us=[1000000,2000000],note='Synthetic resolution'),dict(line=1,interval_us=[2500000,3500000],note='Synthetic resolution')])
        self.assertIn('<p ',to_ttml(corrected))

    def test_context_mapping_retains_occurrences_and_skipped_outer_words(self):
        text='Bright wind\n\nBright wind\nSoft river\n\nBright wind'
        words=['Bright','wind','Bright','wind','Soft','river','Bright','wind']
        times=[(0,0),(0,0),(100,200),(200,300),(400,500),(500,600),(0,0),(0,0)]
        units=[dict(text=t,begin_us=a,end_us=b) for t,(a,b) in zip(words,times)]
        values,owners,center,flags=central_lines(text,1,units,1000)
        self.assertEqual(values,[[100,300],[400,600]]);self.assertEqual(flags,[])
        self.assertEqual(center,{1,2});self.assertEqual(owners[3],1);self.assertEqual(owners[7],3)
        units[3]['end_us']=200
        self.assertIn('missing_central_line',central_lines(text,1,units,1000)[3])
        units[3]['text']='Wrong'
        self.assertIn('model_source_coverage',central_lines(text,1,units,1000)[3])

    def test_candidate_limits_and_order_independence(self):
        choices=[candidate('a',100,200),candidate('b',1000000,2000000)]
        self.assertEqual(reconcile([choices],60000000),reconcile([list(reversed(choices))],60000000))
        for bad in [[],[choices]*65,[[choices[0],choices[0]]]]:
            with self.assertRaises(AlignmentError):reconcile(bad,60000000)
        for value in [True,2,-.1]:
            c=candidate('bad',100,200);c['agreement']=value
            self.assertFalse(assess(c,60000000)['eligible'])

    def test_scoring_reports_false_qualification_without_changing_selection(self):
        from evaluate_passage_search import compare
        raw=self.raw();out=prepare(raw)
        refs=[dict(text=row['text'],interval_us=row['estimate'].copy()) for row in out['lines']]
        refs[0]['interval_us']=[5000000,6000000]
        before=copy.deepcopy(raw)
        metrics=compare(out,out,raw,refs)
        self.assertEqual(metrics['qualified_reference_nonoverlap']['revised'],1)
        self.assertEqual(metrics['paragraphs_with_any_complete_overlapping_candidate'],1)
        self.assertEqual(raw,before)

    def test_missing_assets_do_not_create_output(self):
        script=Path(__file__).resolve().parents[2]/'scripts/search_tifa_passages.py'
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);text=root/'lyrics.txt';text.write_text('Original supplied text')
            command=[sys.executable,str(script),'--audio',str(root/'audio.wav'),'--lyrics',str(text),'--model',str(root/'model'),'--tifa-source',str(root/'vendor'),'--output',str(root/'out')]
            r=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(r.returncode,3,r.stderr);self.assertFalse((root/'out').exists())


if __name__=='__main__':unittest.main()
