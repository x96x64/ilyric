"""Public synthetic refinement tests; no inference, corpus, or optional dependency."""
import copy
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError, source, make_result, review, to_ttml, validate
from alignment.pronunciation import validate_overrides, read_overrides, pfml, suggest_long_vowels
from alignment.endpoints import endpoint, quality_gate, rms_frames, fit_review_threshold, confusion


def fixture(text='光が戻る。\n\n光が戻る。', paragraph=1, selected='光', reading='ヒカリ'):
    src=source(text.encode())
    doc=dict(version=1,source_sha256=src['sha256'],overrides=[dict(paragraph=paragraph,start_utf16=0,
        length_utf16=len(selected.encode('utf-16-le'))//2,text=selected,reading=reading,note='Original synthetic reading')])
    return src,doc


def convert(text):
    # Synthetic phonemes have no acoustic meaning. Preserve all marks as one group.
    return [NS(readings=[NS(paths=[[NS(phonemes=['h','i'])]])])]


class RefinementTests(unittest.TestCase):
    def test_occurrence_and_source_identity(self):
        src,doc=fixture();value=pfml(src,doc,convert)
        self.assertTrue(value.startswith('光が戻る。\n<word'))
        self.assertEqual(src['paragraphs'],['光が戻る。','光が戻る。'])
        bad=copy.deepcopy(doc);bad['source_sha256']='0'*64
        with self.assertRaises(AlignmentError):validate_overrides(src,bad)
        bad=copy.deepcopy(doc);bad['overrides'][0]['text']='海'
        with self.assertRaises(AlignmentError):validate_overrides(src,bad)

    def test_combining_sequence_and_long_vowel(self):
        src,doc=fixture('カ\u3099ー',0,'カ\u3099ー','カ\u3099ー')
        seen=[]
        pfml(src,doc,lambda s:(seen.append(s) or convert(s)))
        self.assertEqual(seen,['ガー']);self.assertEqual(src['text'],'カ\u3099ー')
        for a,n in [(0,1),(1,2)]:
            bad=copy.deepcopy(doc);r=bad['overrides'][0];r.update(start_utf16=a,length_utf16=n,text=src['text'][a:a+n])
            with self.assertRaises(AlignmentError):validate_overrides(src,bad)

    def test_unsupported_ranges_and_readings(self):
        for text in ['👩\u200d💻','❤️','A','海\n光']:
            src,doc=fixture(text,0,text,'ヒカリ')
            with self.assertRaises(AlignmentError):validate_overrides(src,doc)
        src,doc=fixture()
        for key,val in [('reading',''),('reading','light'),('start_utf16',True),('paragraph',8),('note','')]:
            bad=copy.deepcopy(doc);bad['overrides'][0][key]=val
            with self.assertRaises(AlignmentError):validate_overrides(src,bad)
        bad=copy.deepcopy(doc);bad['overrides']*=2
        with self.assertRaises(AlignmentError):validate_overrides(src,bad)

    def test_strict_documents(self):
        src,doc=fixture()
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'overrides.json';p.write_text(json.dumps(doc))
            self.assertEqual(read_overrides(p,src),doc)
            p.write_text('{"version":1,"version":1}')
            with self.assertRaises(AlignmentError):read_overrides(p,src)
            p.write_text(' '*65537)
            with self.assertRaises(AlignmentError):read_overrides(p,src)
        bad=copy.deepcopy(doc);bad['timing']=1
        with self.assertRaises(AlignmentError):validate_overrides(src,bad)

    def test_preserved_text_provenance_and_review(self):
        src,doc=fixture()
        units=[dict(text=p,begin_us=(i*2+1)*1000000,end_us=(i*2+2)*1000000) for i,p in enumerate(src['paragraphs'])]
        r=make_result(src,'a'*64,6000000,dict(identity='synthetic',precision_us=10000,pronunciation_overrides=doc),units)
        validate(r)
        with self.assertRaises(AlignmentError):to_ttml(r)
        for i in range(2):r=review(r,i,note='Synthetic acceptance')
        self.assertEqual(to_ttml(r).count('光が戻る。'),2)
        changed=copy.deepcopy(r);changed['engine']['pronunciation_overrides']['overrides'][0]['text']='別'
        with self.assertRaises(AlignmentError):validate(changed)

    def test_energy_decline_and_unsupported_background(self):
        signal=[.5]*80+[.001]*40+[.5]*80
        d=endpoint(signal,100000,950000,-20,160,250)
        self.assertEqual(d['candidate_us'],800000)
        self.assertTrue(d['review_required'])
        background=endpoint([.4]*200,100000,950000)
        self.assertIsNone(background['candidate_us']);self.assertTrue(background['review_required'])
        self.assertEqual(endpoint([0]*200,100000,950000)['status'],'no_local_energy_support')

    def test_no_invented_excerpt_endpoint_or_short_dip(self):
        self.assertIsNone(endpoint([.4]*200,100000,2000000)['candidate_us'])
        self.assertTrue(endpoint([.4]*200,100000,2000000)['end_at_capture_boundary'])
        self.assertIsNone(endpoint([.4]*80+[.001]*3+[.4]*117,100000,950000)['candidate_us'])
        for bad in [[],[float('nan')],[-1]]:
            with self.assertRaises(AlignmentError):endpoint(bad,0,10000)

    def test_scores_are_review_flags_not_probabilities(self):
        self.assertEqual(quality_gate(None,.5),'review_required')
        self.assertEqual(quality_gate(.9,.5,True),'review_required')
        self.assertEqual(quality_gate(.5,.5),'not_flagged')
        self.assertEqual(quality_gate(-4,-3),'review_required')

    def test_random_order_diagnostics(self):
        signal=[.5]*80+[.001]*40+[.5]*80
        times=[900000,1000000,800000,1000000,900000]
        expected={t:endpoint(signal,100000,t) for t in set(times)}
        self.assertEqual([endpoint(signal,100000,t) for t in times],[expected[t] for t in times])

    def test_missing_analysis_media(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FileNotFoundError):rms_frames(Path(d)/'missing.wav')

    def test_negative_controls_are_required_for_thresholds(self):
        train=[dict(score=.8,matched=True),dict(score=.4,matched=False),dict(score=.9,matched=False)]
        t=fit_review_threshold(train)
        self.assertAlmostEqual(t,.6)
        self.assertEqual(confusion(train,t)['false_acceptance'],1)
        held=[dict(score=.5,matched=True),dict(score=.7,matched=False),dict(score=None,matched=False,unresolved=True)]
        self.assertEqual(confusion(held,t),dict(matched=1,mismatched=2,false_acceptance=1,false_rejection=1,unresolved=1))
        with self.assertRaises(AlignmentError):fit_review_threshold(train[:1])

    def test_long_vowel_suggestion_is_unapplied_and_strict(self):
        src=source('コーラス。\n\nコーラス。'.encode())
        units=[dict(text='コーラス'),dict(text='コラス')]
        v=suggest_long_vowels(src,units)
        self.assertEqual(v['overrides'][0]['paragraph'],1)
        self.assertEqual(v['overrides'][0]['reading'],'コーラス')
        self.assertEqual(src['paragraphs'][1],'コーラス。')
        self.assertIsNone(suggest_long_vowels(src,[dict(text='別の歌')]))
        self.assertIsNone(suggest_long_vowels(src,[dict(text='コーラスコーラス')]))

    def test_example_and_optional_evaluation_availability(self):
        root=Path(__file__).resolve().parents[2]
        src=source((root/'fixtures/alignment/pronunciation.txt').read_bytes())
        self.assertEqual(read_overrides(root/'fixtures/alignment/pronunciation.json',src)['overrides'][0]['paragraph'],1)
        from evaluate_alignment_refinement import evaluate
        from alignment.worker import Unavailable
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(Unavailable):evaluate(Path(d)/'absent.json')
