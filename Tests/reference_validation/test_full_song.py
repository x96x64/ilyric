"""Original synthetic acoustic scores; no model, media, or reference assets."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError,source
from alignment.full_song import artifact,windows,text_targets,path,proposals,review,to_ttml,validate,load,owned_frames,unassigned_audio


class FullSongTests(unittest.TestCase):
    def fixture(self):
        src=source(b'Go\nNow\n\nGo\n\nStay\n')
        _,tokens,owners=text_targets(src)
        vocab={c:i+1 for i,c in enumerate(sorted(set(tokens)))};vocab['']=0
        emissions=[]
        for i,c in enumerate(tokens):
            if i%3==0:
                for _ in range(5):emissions.append([0.]+[-9.]*(len(vocab)-1))
            e=[-9.]*len(vocab);e[vocab[c]]=0.
            emissions.extend([e.copy(),e.copy()])
            emissions.append([0.]+[-9.]*(len(vocab)-1))
        emissions.extend([[0.]+[-9.]*(len(vocab)-1) for _ in range(10)])
        spans=path(emissions,[vocab[x] for x in tokens]);duration=len(emissions)*20000
        rows=proposals(src,duration,emissions,tokens,owners,spans,vocab)
        result=artifact(src,'a'*64,duration,dict(model_grid_us=20000),windows(duration*16000//1000000),rows)
        return result,emissions,tokens,vocab

    def test_window_bounds_overlap_and_owned_coverage(self):
        for samples in [400,480000,480001,16000*181+17,9600000]:
            plan=windows(samples);self.assertEqual(plan[0]['keep_start_sample'],0)
            self.assertEqual(plan[-1]['keep_end_sample'],samples)
            for i,row in enumerate(plan):
                self.assertLessEqual(row['end_sample']-row['start_sample'],480000)
                self.assertLessEqual(row['start_sample'],row['keep_start_sample'])
                self.assertLessEqual(row['keep_end_sample'],row['end_sample'])
                if i:self.assertEqual(plan[i-1]['keep_end_sample'],row['keep_start_sample'])
        with self.assertRaises(AlignmentError):windows(9600001)

    def test_frame_ownership_preserves_grid_without_blending(self):
        expected=0
        plan=windows(16000*181+17)
        for row in plan:
            frames=(row['end_sample']-row['start_sample']-400)//320+1
            selected=owned_frames(row,frames,expected)
            self.assertTrue(selected)
            expected+=len(selected)
        self.assertEqual(expected,9049)
        with self.assertRaises(AlignmentError):owned_frames(plan[1],1499,0)

    def test_repeated_occurrences_gaps_and_terminal_blanks(self):
        r,e,t,v=self.fixture();self.assertEqual([x['id'] for x in r['lines']],[0,1,2,3])
        self.assertLess(r['lines'][0]['estimate'][1],r['lines'][2]['estimate'][0])
        self.assertIn('repeated_occurrence_requires_review',r['lines'][2]['flags'])
        self.assertLess(r['lines'][-1]['estimate'][1],r['audio']['duration_us'])
        for row in r['lines']:self.assertEqual(row['review'],'pending')
        self.assertEqual(path(e,[v[c] for c in t]),path(e,[v[c] for c in t]))

    def test_unsupported_correspondence_is_not_an_estimate(self):
        src=source(b'Absent words\n');_,tokens,owners=text_targets(src)
        vocab={c:i+1 for i,c in enumerate(sorted(set(tokens)))};vocab['']=0
        e=[[0.]+[-10.]*(len(vocab)-1) for _ in range(100)]
        spans=path(e,[vocab[c] for c in tokens]);rows=proposals(src,2000000,e,tokens,owners,spans,vocab)
        self.assertIsNone(rows[0]['estimate']);self.assertIsNotNone(rows[0]['proposal'])
        self.assertIn('weak_lexical_agreement',rows[0]['flags'])
        rows=proposals(src,2000000,e,tokens,owners,None,vocab)
        self.assertIn('no_complete_path',rows[0]['flags'])

    def test_review_preserves_proposals_and_complete_ttml(self):
        from align_full_song import unique_fields
        with self.assertRaises(AlignmentError):unique_fields([('line',0),('line',1)])
        r,_,_,_=self.fixture();before=copy.deepcopy(r)
        with self.assertRaises(AlignmentError):to_ttml(r)
        decisions=[dict(line=x['id'],note='Synthetic review assertion') for x in r['lines']]
        out=review(r,decisions);self.assertEqual(r,before)
        xml=to_ttml(out);self.assertIn('Go<br/>Now',xml);self.assertEqual(xml.count('<p '),3)
        self.assertEqual(out['proposal_sha256'],r['proposal_sha256'])
        out=review(out,[dict(line=0,interval_us=[1,100001],note='Synthetic correction')])
        self.assertEqual(out['lines'][0]['estimate'],r['lines'][0]['estimate'])
        self.assertEqual(out['lines'][0]['correction']['origin'],'manually_corrected')
        self.assertIn('0.000001s',to_ttml(out))
        with self.assertRaises(AlignmentError):review(r,[dict(line=0,interval_us=[0,99999999],note='Invalid')])
        with self.assertRaises(AlignmentError):review(r,[dict(line=0,note='a'),dict(line=0,note='b')])

    def test_source_precision_and_artifact_integrity(self):
        r,_,_,_=self.fixture()
        for key,value in [('estimate',[0,2]),('text','changed'),('id',42)]:
            bad=copy.deepcopy(r);bad['lines'][0][key]=value
            with self.assertRaises(AlignmentError):validate(bad)
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'result.json';p.write_text(json.dumps(r));self.assertEqual(load(p)['proposal_sha256'],r['proposal_sha256'])
        for text in [b'123', '日本語'.encode(), 'cafe\u0301'.encode()]:
            with self.assertRaises(AlignmentError):text_targets(source(text))

    def test_bounded_paths_and_repeated_characters(self):
        self.assertIsNone(path([[0.,-1.]], [1,1]))
        spans=path([[0.,-9.],[-9.,0.],[0.,-9.],[-9.,0.],[0.,-9.]],[1,1])
        self.assertEqual(spans,[[1,2],[3,4]])
        with self.assertRaises(AlignmentError):path([[float('nan'),0.]],[1])
        with self.assertRaises(AlignmentError):path([[0.,-1.]]*30001,[1])
        with self.assertRaises(AlignmentError):path([[0.,-1.]]*30000,[1]*6000)

    def test_unassigned_audio_and_scoring_do_not_certify_gaps(self):
        from evaluate_full_song import score
        r,_,_,_=self.fixture();before=copy.deepcopy(r)
        gaps=unassigned_audio(r)
        self.assertEqual(gaps[0][0],0)
        self.assertEqual(gaps[-1][1],r['audio']['duration_us'])
        refs=[dict(text=x['text'],interval_us=x['proposal']) for x in r['lines']]
        measured=score(r,refs)
        self.assertEqual(measured['raw_onset']['p95_absolute_ms'],0)
        self.assertEqual(measured['proposals_without_reference_overlap'],0)
        self.assertEqual(r,before)
        refs[0]['text']='Changed supplied source'
        with self.assertRaises(AlignmentError):score(r,refs)

    def test_missing_assets_and_no_overwrite(self):
        script=Path(__file__).resolve().parents[2]/'scripts/align_full_song.py'
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);text=root/'text.txt';text.write_text('Original words')
            audio=root/'audio.wav';audio.write_bytes(b'synthetic placeholder')
            out=root/'out.json'
            command=[sys.executable,str(script),'align','--audio',str(audio),'--lyrics',str(text),'--model',str(root/'missing'),'--output',str(out)]
            result=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(result.returncode,3,result.stderr);self.assertFalse(out.exists())
            out.write_text('preserved');result=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(result.returncode,2);self.assertEqual(out.read_text(),'preserved')




class VocalRules(unittest.TestCase):
    def rows(self,proposals,text='Bright wind',support=-1.0,similarity=0.8):
        from alignment.full_song import text_targets
        from alignment.core import source
        rows=text_targets(source(text.encode()))[0]
        for r,p in zip(rows,proposals):
            r.update(proposal=p,estimate=list(p) if p else None,flags=[],
                     quality=dict(forced_mean_log_support=support,greedy_similarity=similarity))
        return rows

    def test_acceptance_uses_separated_evidence(self):
        from alignment.full_song import apply_vocal_rules
        ok=self.rows([[0,1000000]]);apply_vocal_rules(ok,[0.0]*50+[-80.0]*50,0.0)
        self.assertEqual(ok[0]['estimate'],[0,1000000])
        for kwargs,flag in [(dict(support=-3.6),'weak_separated_support'),(dict(similarity=0.1),'weak_separated_lexical_agreement')]:
            r=self.rows([[0,1000000]],**kwargs);apply_vocal_rules(r,[0.0]*100,0.0)
            self.assertIsNone(r[0]['estimate']);self.assertIn(flag,r[0]['flags']);self.assertEqual(r[0]['proposal'],[0,1000000])

    def test_rate_bounds_withhold_estimates(self):
        from alignment.full_song import apply_vocal_rules,MINIMUM_US_PER_CHARACTER,MAXIMUM_US_PER_CHARACTER
        short=self.rows([[0,MINIMUM_US_PER_CHARACTER*10-20000]]);apply_vocal_rules(short,[0.0]*400,0.0)
        self.assertIsNone(short[0]['estimate']);self.assertIn('implausible_duration',short[0]['flags'])
        long=self.rows([[0,MAXIMUM_US_PER_CHARACTER*10+20000]]);apply_vocal_rules(long,[0.0]*400,0.0)
        self.assertIsNone(long[0]['estimate']);self.assertIn('implausible_rate',long[0]['flags'])

    def test_onset_moves_past_leading_inactivity_only(self):
        from alignment.full_song import apply_vocal_rules
        level=[-80.0]*50+[-10.0]*50
        rows=self.rows([[0,2000000]]);apply_vocal_rules(rows,level,0.0)
        self.assertEqual(rows[0]['estimate'][0],1000000);self.assertEqual(rows[0]['quality']['vocal_onset_trim_us'],1000000)
        rows=self.rows([[1200000,2000000]]);apply_vocal_rules(rows,level,0.0)
        self.assertEqual(rows[0]['estimate'][0],1200000);self.assertNotIn('vocal_onset_trim_us',rows[0]['quality'])

    def test_offset_extends_through_activity_within_bounds(self):
        from alignment.full_song import apply_vocal_rules,MAXIMUM_OFFSET_EXTENSION_US
        level=[-5.0]*60+[-80.0]*40
        rows=self.rows([[0,1000000]]);apply_vocal_rules(rows,level,0.0)
        self.assertEqual(rows[0]["estimate"],[0,1200000])
        loud=[-5.0]*200
        rows=self.rows([[0,1000000]]);apply_vocal_rules(rows,loud,0.0)
        self.assertEqual(rows[0]['estimate'][1],1000000+MAXIMUM_OFFSET_EXTENSION_US)
        two=self.rows([[0,1000000],[1100000,2000000]],text='Bright wind\nSoft river');apply_vocal_rules(two,loud,0.0)
        self.assertEqual(two[0]['estimate'][1],1100000)

    def test_inactive_estimates_are_withheld(self):
        from alignment.full_song import apply_vocal_rules
        rows=self.rows([[0,1000000]]);apply_vocal_rules(rows,[-80.0]*100,0.0)
        self.assertIsNone(rows[0]['estimate']);self.assertIn('no_vocal_activity',rows[0]['flags'])

    def test_slow_lines_are_flagged_but_kept(self):
        from alignment.full_song import apply_vocal_rules
        rows=self.rows([[0,500000],[600000,1100000],[1200000,4000000]],text='Bright wind\nSoft river\nBright wind')
        apply_vocal_rules(rows,[0.0]*400,0.0)
        self.assertIn('uncertain_boundary',rows[2]['flags']);self.assertIsNotNone(rows[2]['estimate'])
        self.assertNotIn('uncertain_boundary',rows[0]['flags'])

    def test_unresolved_rows_are_unchanged(self):
        from alignment.full_song import apply_vocal_rules
        rows=self.rows([None]);apply_vocal_rules(rows,[0.0]*10,0.0)
        self.assertIsNone(rows[0]['estimate']);self.assertEqual(rows[0]['flags'],[])

    def test_activity_level_is_deterministic(self):
        import numpy as np
        from alignment.full_song import vocal_activity_db
        x=np.concatenate([np.zeros(3200),np.full(3200,0.5)])
        level,ref=vocal_activity_db(x)
        self.assertEqual(len(level),20);self.assertAlmostEqual(level[-1],20*np.log10(0.5),6)
        self.assertEqual((level,ref),vocal_activity_db(x))


if __name__=='__main__':unittest.main()
