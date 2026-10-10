"""Original synthetic annotations; no media or reference assets."""
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
sys.path.insert(0,str(Path(__file__).resolve().parent))
from alignment.core import AlignmentError
from evaluate_word_timing import annotated_lines,evaluate,summarize
import test_full_song


class WordTimingEvaluation(unittest.TestCase):
    def test_annotation_lines_and_summary(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'w.csv';p.write_text('word_start,word_end,line_end\n1.0,1.2,nan\n1.3,1.5,1.5\n2.0,2.4,2.4\n')
            self.assertEqual(annotated_lines(p),[[(1.0,1.2),(1.3,1.5)],[(2.0,2.4)]])
        s=summarize([10,-30,250]);self.assertEqual(s['n'],3);self.assertEqual(s['median_absolute_ms'],30)
        self.assertAlmostEqual(s['within_200_ms'],2/3);self.assertEqual(summarize([]),dict(n=0))

    def test_word_errors_against_own_estimates(self):
        r=test_full_song.WordTiming().fixture()
        ref=[[(w['interval_us'][0]/1e6,w['interval_us'][1]/1e6) for w in row['word_estimates']] for row in r['lines']]
        out=evaluate(r,ref);self.assertEqual(out['counts']['compared'],2)
        self.assertTrue(all(abs(x)<1e-6 for x in out['onset']+out['offset']))
        out=evaluate(r,[ref[0],ref[1][:1]]);self.assertEqual(out['counts']['word_count_mismatch'],1)
        with self.assertRaises(AlignmentError):evaluate(r,ref[:1])


if __name__=='__main__':unittest.main()
