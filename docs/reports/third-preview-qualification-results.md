# Third Preview Qualification Results

## Outcome

October 12, 2026. **Every pooled criterion was met on 80 unseen JamendoLyrics++ recordings, but three recordings fell below the per-recording threshold of 80% placement, so the locked criteria are narrowly not met.** One of the three is a hard failure caused by an unsupported apostrophe character in the lyrics text, not by alignment. The evaluation followed the [Third Preview Qualification Procedure](third-preview-qualification-procedure.md) with `ilyrics` built from commit `e0ab92a`, and, as the maintainer decided, concludes the preview qualification.

## Qualification Measures

3,005 scored lines over 80 recordings; nine vocable-only lines were excluded and are reported below.

| Criterion | Threshold | Result | Met |
| --- | --- | ---: | --- |
| Placement accuracy | ≥ 95% | 95.9% | Yes |
| Wrong placement | ≤ 2% | 0.5% | Yes |
| Unresolved rate | ≤ 5% | 3.6% | Yes |
| Word containment | ≥ 95% | 98.1% | Yes |
| Recordings below 80% placement | none | 3 | No |
| Run time relative to duration | ≤ 2 | ≤ 0.26 | Yes |

Peak memory was at most 1.6 GB. Of the 79 recordings that completed, placement was 100% for 45 and at least 90% for 72. All nine vocable-only lines were aligned and correctly placed.

The three recordings below 80% are:

1. **A hard failure (0%).** The lyrics of one recording use the modifier letter apostrophe U+02BC (ʼ) in contractions. The command accepts only ASCII letters and apostrophes in alignment text, so it stopped with "Full-song CTC currently supports English ASCII letters and contractions only" and its 45 lines count as unresolved. This is a text-normalization defect, not an alignment result.
2. **Two recordings at 70.8% and 76.0%**, whose remaining lines were unresolved or misplaced.

Without the hard failure, the pooled placement over the 79 completed recordings is 97.4%, with 2.1% unresolved.

## Diagnostics

Against the manual word timing, pooling per-recording medians weighted by count:

| Measure | Median absolute error | Share above 500 ms |
| --- | ---: | ---: |
| Line onset (2,897 lines) | about 104 ms | 7.0% |
| Line offset | about 119 ms | 9.4% |
| Word onset (18,751 words) | about 100 ms | 3.9% |

The medians are a weighted mean of per-recording medians, not a pooled median.

## Comparison with Earlier Qualifications

| | First (MUSDB18 test) | Second (MUSDB18 training) | Third (JamendoLyrics++) |
| --- | ---: | ---: | ---: |
| Placement accuracy | 82.5% | 88.0% | 95.9% |
| Wrong placement | 0.9% | 0.8% | 0.5% |
| Unresolved rate | 16.5% | 11.2% | 3.6% |

The sets, annotations, and criteria differ: the third evaluation excludes vocable-only lines and scores lines against manual word timing rather than one-second sections, and its recordings, mainly pop and rock with a single lead singer, are closer to the material the product targets. The comparison indicates direction, not a controlled effect.

## Consequences

Under the locked criteria the preview does not qualify, by the per-recording criterion alone. The maintainer decided beforehand that this evaluation is the basis of the preview decision; the decision is the maintainer's. The apostrophe defect is fixed separately; the fix cannot change these results.

## Limitations

JamendoLyrics++ states no license and was used only for local evaluation. The line onset and offset errors measure the command's line intervals, which include vocal-activity refinement, against the first and last annotated words. Results are aggregated without lyric text.
