"""Original annotation intake fixtures; no human evidence, private media, or model."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from alignment.core import AlignmentError
from alignment.vocal_annotations import load, validate, validate_review


class VocalAnnotationTests(unittest.TestCase):
    def fixture(self):
        return dict(format_version=1, classification='Original synthetic fixture, not human evidence',
                    source_id='synthetic', audio_sha256='a'*64, singer_group='synthetic-singer',
                    permission_reference='original-fixture', language='ja', accompanied=True,
                    sample_rate_hz=44100, source_total_samples=441000,
                    source_start_sample=44100, source_end_sample=88200, timing_unit='samples',
                    duration_samples=44100, annotation_resolution=1,
                    annotator='A', review_status='independent_pass',
                    independence=dict(audio_only=True, consulted_predictions=False, consulted_other_pass=False),
                    intervals=[dict(kind='instrumental', start_sample=0, end_sample=10000),
                               dict(kind='lead_singing', onset_earliest_sample=10000, onset_latest_sample=10001,
                                    offset_earliest_sample=30001, offset_latest_sample=30002),
                               dict(kind='ambiguous_reverberation', start_sample=30002, end_sample=31000)])

    def reviewed(self):
        a=self.fixture(); b=copy.deepcopy(a); b['annotator']='B'
        r=copy.deepcopy(a);r['review_status']='reviewed';r['reviewer']='B'
        r['initial_passes_sha256']=['b'*64,'c'*64]
        return r,a,b

    def test_exact_samples_unknown_support_and_nonmutation(self):
        r=self.fixture();before=copy.deepcopy(r);out=validate(r)
        self.assertEqual(r,before)
        self.assertEqual(out['time_denominator'],44100)
        self.assertEqual(out['unknown_intervals'],[[10000,10001],[30001,44100]])
        self.assertEqual(out['declared_clear_uncensored_pairs'],1)
        self.assertEqual(out['declared_nonvocal_gaps'],1)
        self.assertFalse(out['eligible_for_scoring'])
        self.assertEqual(out,validate(copy.deepcopy(r)))

    def test_two_pass_identity_and_participant_links(self):
        r,a,b=self.reviewed();out=validate_review(r,a,'b'*64,b,'c'*64)
        self.assertTrue(out['initial_pass_links_verified'])
        self.assertFalse(out['eligible_for_scoring'])
        for key,value in [('annotator','A'),('singer_group','other'),('source_end_sample',88201),('permission_reference','other')]:
            broken=copy.deepcopy(b);broken[key]=value
            with self.assertRaises(AlignmentError):validate_review(r,a,'b'*64,broken,'c'*64)
        with self.assertRaises(AlignmentError):validate_review(r,a,'d'*64,b,'c'*64)

    def test_uncertainty_order_overlap_and_missing_identity(self):
        for change in [lambda x:x.update(audio_sha256=None),lambda x:x.update(format_version=True),
                       lambda x:x.update(accompanied=1),lambda x:x.update(annotation_resolution=0),
                       lambda x:x['intervals'][1].update(onset_latest_sample=30003),
                       lambda x:x['intervals'][1].update(onset_earliest_sample=9999),
                       lambda x:x['intervals'][1].update(offset_latest_sample=44101),
                       lambda x:x['intervals'][1].update(onset_earliest_sample=True),
                       lambda x:x['independence'].update(consulted_predictions=True),
                       lambda x:x['independence'].update(audio_only=1)]:
            r=self.fixture();change(r)
            with self.assertRaises(AlignmentError):validate(r)

    def test_censored_and_ambiguous_pairs_are_not_clear(self):
        r=self.fixture();r['intervals']=r['intervals'][1:2]
        r['intervals'][0].update(onset_earliest_sample=0,censored=dict(onset=True,offset=False))
        self.assertEqual(validate(r)['declared_clear_uncensored_pairs'],0)
        r['intervals'][0]['censored']['onset']=False
        r['intervals'][0]['onset_latest_sample']=30001
        self.assertEqual(validate(r)['declared_clear_uncensored_pairs'],0)
        self.assertEqual(validate(r)['unknown_intervals'],[[0,44100]])

    def test_disagreement_preservation_and_no_averaging(self):
        r,a,b=self.reviewed();b['intervals'][1]['onset_latest_sample']=10002
        with self.assertRaises(AlignmentError):validate_review(r,a,'b'*64,b,'c'*64)
        r['intervals'][1]['onset_latest_sample']=10002
        r['disagreements']=[dict(start_sample=10001,end_sample=10002,disposition='unresolved',evidence_reference='review-01')]
        self.assertTrue(validate_review(r,a,'b'*64,b,'c'*64)['initial_pass_links_verified'])
        r['disagreements'][0]['end_sample']=10003
        with self.assertRaises(AlignmentError):validate(r)
        r['disagreements'][0]['disposition']='averaged'
        with self.assertRaises(AlignmentError):validate(r)

    def test_microsecond_profile_and_mixed_units(self):
        r=self.fixture();r.update(timing_unit='microseconds',duration_us=1000000)
        r.pop('duration_samples');r['intervals']=[dict(kind='silence',start_us=0,end_us=1000000)]
        self.assertEqual(validate(r)['unknown_intervals'],[])
        r['duration_us']=1000002
        with self.assertRaises(AlignmentError):validate(r)
        r['duration_us']=1000000;r['intervals'][0]['end_sample']=44100
        with self.assertRaises(AlignmentError):validate(r)

    def test_utf8_duplicate_fields_and_limits(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'record.json'
            for content in [b'\xff',b'{"a":1,"a":2}',b'{"a":NaN}',b' '*131073]:
                p.write_bytes(content)
                with self.assertRaises(AlignmentError):load(p)
            content=json.dumps(self.fixture()).encode();p.write_bytes(content)
            self.assertEqual(load(p)[1],hashlib.sha256(content).hexdigest())
        r=self.fixture();r['intervals']=[dict(kind='silence',start_sample=0,end_sample=1)]*2001
        with self.assertRaises(AlignmentError):validate(r)

    def test_cli_source_hash_missing_inputs_and_read_only(self):
        script=Path(__file__).resolve().parents[2]/'scripts/validate_vocal_annotations.py'
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);record=root/'record.json';audio=root/'audio.bin'
            def run():return subprocess.run([sys.executable,str(script),'--record',str(record),'--audio',str(audio)],capture_output=True,text=True)
            self.assertEqual(run().returncode,3)
            original=b'original synthetic source identity';audio.write_bytes(original)
            r=self.fixture();r['audio_sha256']=hashlib.sha256(original).hexdigest();record.write_text(json.dumps(r))
            before=record.read_bytes();result=run()
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse(json.loads(result.stdout)['eligible_for_scoring'])
            self.assertEqual(record.read_bytes(),before);self.assertEqual(audio.read_bytes(),original)
            audio.write_bytes(b'different');result=run()
            self.assertEqual(result.returncode,2);self.assertEqual(result.stdout,'')


if __name__=='__main__':unittest.main()
