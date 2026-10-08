import copy
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError, source, digest
from alignment.audio_anchors import FORMAT, match, validate, observations, ticks_us, review_artifact, fingerprint
from alignment.full_song import review, to_ttml


def anchors(phrases, duration=60000000):
    return dict(format=FORMAT,audio=dict(sha256='a'*64,duration_us=duration),language='en',timebase_hz=100,resolution_ticks=1,
                provenance=dict(producer='original-synthetic-fixture',revision='0'*40,model='no-inference',weights_sha256='0'*64,
                                origin='synthetic',decoding=dict(lyric_prompt=False,previous_text_context=False,translation=False)),
                observations=[dict(id=f'o{i}',window=0 if a<2800 else 1,text=text,begin_tick=a,end_tick=b,uncertainty=[])
                              for i,(text,a,b) in enumerate(phrases)])


class AudioAnchorTests(unittest.TestCase):
    def test_exact_grid_and_boundary_validation(self):
        self.assertEqual(ticks_us(123,100),1230000)
        self.assertEqual(ticks_us(123,1000000),123)
        for v,r in [(True,100),(1,3),(-1,100),(60001,100)]:
            with self.assertRaises(AlignmentError):ticks_us(v,r)
        a=anchors([('Bright wind',101,299)],duration=60000001)
        self.assertEqual(observations(a)[0][0]['interval_us'],[1010000,2990000])
        a['observations'][0]['end_tick']=3100
        with self.assertRaises(AlignmentError):validate(a)

    def test_source_identity_punctuation_and_nonmutation(self):
        src=source('Bright wind!\n\nWe’re awake.\n'.encode())
        a=anchors([('Bright wind',100,200),("we're awake",300,400)])
        before=copy.deepcopy((src,a));out=match(src,a)
        self.assertEqual((src,a),before)
        self.assertEqual([d['state'] for d in out['decisions']],['supported','supported'])
        self.assertEqual(out['source'],src)
        self.assertEqual(out['source_tokens'][1][0]['length_utf16'],5)
        self.assertEqual(out['anchor_sha256'],fingerprint(a))
        src['sha256']='f'*64
        with self.assertRaises(AlignmentError):match(src,a)

    def test_repeated_occurrences_and_extra_repetition(self):
        a=anchors([('Bright wind',100,200),('Bright wind',1000,1100)])
        out=match(source(b'Bright wind\n\nBright wind'),a)
        self.assertEqual([d['region_us'] for d in out['decisions']],[[1000000,2000000],[10000000,11000000]])
        self.assertEqual([d['state'] for d in out['decisions']],['supported','supported'])
        out=match(source(b'Bright wind\n\nBright wind\n\nBright wind'),a)
        self.assertEqual(sum(d['candidate'] is not None for d in out['decisions']),2)
        self.assertTrue(any(d['state']=='ambiguous' for d in out['decisions']))
        self.assertTrue(any(d['state']=='skipped' for d in out['decisions']))

    def test_one_line_two_choruses_abstains(self):
        out=match(source(b'Bright wind'),anchors([('Bright wind',100,200),('Bright wind',1000,1100)]))
        self.assertEqual(out['decisions'][0]['state'],'ambiguous')
        self.assertEqual(out['decisions'][0]['margin'],0)
        self.assertTrue(out['decisions'][0]['competing_path'])

    def test_omissions_extras_and_instrumental_gap(self):
        a=anchors([('Bright wind',100,200),('Unexpected singing',500,600),('Soft river',1600,1700)])
        out=match(source(b'Bright wind\n\nAbsent words\n\nSoft river'),a)
        self.assertEqual([d['state'] for d in out['decisions']],['supported','unresolved','supported'])
        self.assertIn('o1',out['unassigned_observations'])
        self.assertEqual(out['unassigned_audio_regions_us'],[[0,1000000],[2000000,16000000],[17000000,60000000]])
        self.assertEqual(out['decisions'][1]['diagnostic'],'missing_candidate_coverage')
        # A long internal gap cannot support a single continuous line.
        out=match(source(b'Bright wind soft river'),anchors([('Bright wind',100,200),('Soft river',1600,1700)]))
        self.assertEqual(out['decisions'][0]['state'],'unresolved')
        self.assertTrue(any('internal_audio_gap' in c['reasons'] for c in out['groups'][0]))

    def test_misordering_does_not_force_both(self):
        out=match(source(b'Soft river\n\nBright wind'),anchors([('Bright wind',100,200),('Soft river',300,400)]))
        self.assertEqual(sum(d['candidate'] is not None for d in out['decisions']),1)
        self.assertTrue(any(d['state']=='skipped' for d in out['decisions']))

    def test_neighboring_context_resolves_local_repeat_without_displacement(self):
        a=anchors([('Bright wind',100,200),('Soft river',400,500),('Bright wind',1000,1100)])
        out=match(source(b'Bright wind\n\nSoft river'),a)
        self.assertEqual([d['state'] for d in out['decisions']],['supported','supported'])
        self.assertEqual(out['decisions'][0]['region_us'],[1000000,2000000])
        self.assertIn('o2',out['unassigned_observations'])

    def test_small_recognition_errors_and_preserved_raw_evidence(self):
        a=anchors([('Bright quiet wind opens',100,400)])
        out=match(source(b'Bright gentle wind opens'),a)
        c=next(c for c in out['groups'][0] if c['eligible'])
        self.assertEqual(c['edits'],1);self.assertEqual(c['matches'],3)
        self.assertEqual(out['anchors'],a)

    def test_overlapping_windows_do_not_duplicate_votes(self):
        a=anchors([('Bright wind',2700,2800),('Bright wind',2800,2900)])
        a['observations'].append(dict(id='other',window=1,text='Bright wind',begin_tick=2700,end_tick=2800,uncertainty=[]))
        _,rejected=observations(a)
        self.assertEqual(rejected,[dict(observation='other',reason='outside_central_window_ownership')])
        out=match(source(b'Bright wind'),a)
        self.assertEqual(out['decisions'][0]['state'],'ambiguous')

    def test_unsupported_uncertain_and_empty_recognition(self):
        a=anchors([('朝の風',100,200),('Bright wind',300,400)])
        a['observations'][1]['uncertainty']=['timestamp_unresolved']
        out=match(source(b'Bright wind'),a)
        self.assertEqual(out['decisions'][0]['state'],'unresolved')
        self.assertEqual(len(out['rejected_observations']),2)
        self.assertEqual(match(source(b'Bright wind'),anchors([]))['decisions'][0]['state'],'unresolved')
        self.assertEqual(match(source(b'Wind'),anchors([('Wind',100,200)]))['decisions'][0]['state'],'unresolved')
        for text in ['Br\u200dight wind','Bright wind\ufe0f','Bright wi\u0301nd','Bright wind 👩‍🚀']:
            original=anchors([(text,100,200)])
            checked=match(source(b'Bright wind'),original)
            self.assertEqual(checked['rejected_observations'][0]['reason'],'unsupported_recognition_text')
            self.assertEqual(checked['anchors'],original)

    def test_strict_schema_and_unconditioned_provenance(self):
        a=anchors([('Bright wind',100,200)])
        for mutate in [lambda r:r.update(version=2),lambda r:r.update(language='ja'),lambda r:r.update(resolution_ticks=0),
                       lambda r:r['audio'].update(duration_us=True),lambda r:r['audio'].update(sha256='bad'),
                       lambda r:r['provenance']['decoding'].update(lyric_prompt=True),
                       lambda r:r['observations'].append(copy.deepcopy(r['observations'][0])),
                       lambda r:r['observations'][0].update(text='x\ud800'),
                       lambda r:r['observations'][0].update(uncertainty=[float('nan')])]:
            bad=copy.deepcopy(a);mutate(bad)
            with self.assertRaises(AlignmentError):validate(bad)

    def test_random_access_serialization_and_input_order(self):
        a=anchors([('Bright wind',100,200),('Soft river',400,500)])
        src=source(b'Bright wind\n\nSoft river');expected=match(src,a)
        for seed in range(5):
            other=copy.deepcopy(a);random.Random(seed).shuffle(other['observations'])
            actual=match(src,other)
            # Raw evidence order/hash is preserved; semantic matching is order-independent.
            for k in ['tokens','groups','decisions','selected_path']:
                self.assertEqual(actual[k],expected[k])
        self.assertEqual(json.dumps(expected,sort_keys=True),json.dumps(match(src,json.loads(json.dumps(a))),sort_keys=True))

    def test_correction_reuse_does_not_promote_coarse_timing(self):
        matched=match(source(b'Bright wind'),anchors([('Bright wind',100,300)]))
        prepared=review_artifact(matched)
        self.assertIsNone(prepared['lines'][0]['estimate'])
        with self.assertRaises(AlignmentError):review(prepared,[dict(line=0,note='Coarse is not refined')])
        fixed=review(prepared,[dict(line=0,interval_us=[1000123,2999999],note='Original synthetic manual correction')])
        self.assertIn('1.000123s',to_ttml(json.loads(json.dumps(fixed))))
        self.assertIsNone(fixed['lines'][0]['estimate'])
        matched['decisions'][0]['state']='unresolved'
        with self.assertRaises(AlignmentError):review_artifact(matched)

    def test_resource_limits_and_scoring_do_not_change_selection(self):
        from evaluate_audio_correspondence import compare
        a=anchors([('Bright wind',100,200)])
        bad=copy.deepcopy(a);bad['observations']*=10001
        with self.assertRaises(AlignmentError):validate(bad)
        out=match(source(b'Bright wind'),a);baseline=review_artifact(out)
        before=copy.deepcopy(out)
        refs=[dict(text='Bright wind',interval_us=[1000000,2000000])]
        metrics=compare(out,baseline,refs)
        self.assertEqual(metrics['eligible_candidate_reference_overlap'],1)
        self.assertTrue(metrics['m1_temporal_screen_pass'])
        refs[0]['interval_us']=[5000000,6000000]
        metrics=compare(out,baseline,refs)
        self.assertEqual(metrics['supported_reference_nonoverlap'],1)
        self.assertFalse(metrics['m1_temporal_screen_pass'])
        self.assertEqual(out,before)

    def test_work_budgets_fail_without_partial_results(self):
        from unittest.mock import patch
        from alignment.audio_anchors import POLICY
        for key in ['maximum_cells','maximum_candidates','maximum_reconciliation_work']:
            with patch.dict(POLICY,{key:0}):
                with self.assertRaises(AlignmentError):
                    match(source(b'Bright wind'),anchors([('Bright wind',100,200)]))

    def test_optional_model_preflight_never_provisions(self):
        from alignment.anchor_assets import require_assets
        from alignment.worker import Unavailable
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);runtime=root/'runtime';model=root/'model'
            with self.assertRaises(Unavailable):require_assets(runtime,model)
            runtime.write_text('Synthetic placeholder, never executed');runtime.chmod(0o700)
            with self.assertRaises(Unavailable):require_assets(runtime,model)
            model.write_bytes(b'Invalid synthetic weights')
            with self.assertRaises(AlignmentError):require_assets(runtime,model)
            self.assertEqual(len(list(root.iterdir())),2)

    def test_cli_missing_inputs_duplicate_fields_and_audio_identity(self):
        script=Path(__file__).resolve().parents[2]/'scripts/match_audio_anchors.py'
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);audio=root/'audio';audio.write_bytes(b'Original synthetic bytes')
            lyrics=root/'lyrics';lyrics.write_text('Bright wind')
            record=root/'anchors.json';output=root/'output.json'
            command=[sys.executable,str(script),'--anchors',str(record),'--lyrics',str(lyrics),'--audio',str(audio),'--output',str(output)]
            r=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(r.returncode,3);self.assertFalse(output.exists())
            record.write_text('{"format":1,"format":2}')
            self.assertEqual(subprocess.run(command,capture_output=True).returncode,2)
            a=anchors([('Bright wind',100,200)]);record.write_text(json.dumps(a))
            self.assertEqual(subprocess.run(command,capture_output=True).returncode,2)
            a['audio']['sha256']=digest(audio.read_bytes());record.write_text(json.dumps(a))
            r=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertEqual(json.loads(r.stdout)['timing_estimates'],0)
            self.assertEqual(subprocess.run(command,capture_output=True).returncode,2)


if __name__=='__main__':unittest.main()
