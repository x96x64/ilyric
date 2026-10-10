# Word-Level Alignment

## Outcome and Scope

October 10, 2026. **Separated-vocal CTC alignment places word onsets within a median 42 ms of human annotations, with 92.6% within 200 ms, across 4,365 words in seventeen recordings.** Word intervals are derived from the forced character spans that already time each line, so word timing adds no model, download, or inference pass. A baseline that divides each estimated line among its words by character count reaches a median of 175 ms and 53.7% within 200 ms. Word timing can now be exported as TTML spans and rendered with the native word fill described in [Reference Clock Correction and Word Motion](reference-clock-and-word-motion.md).

These are development estimates on the seventeen recordings already used to select the [version 2 vocal rules](separated-vocal-acceptance.md); no unseen requalification has occurred.

## Method

`proposals()` groups the forced CTC character spans of each line into runs that correspond, in order, to the words matched by the pattern used to build the alignment targets, and records each word's UTF-16 source range. When version 2 rules accept a line, `word_estimates()` clamps the word spans into the refined line interval: the first word starts at the line onset, the last word ends at the line offset, and each word starts no earlier than the previous word ends. A line whose clamping would empty a word keeps its line estimate without word estimates. The artifact validator checks that word estimates are ordered within the line estimate.

`align_full_song.py export --granularity word` writes one TTML paragraph per sung line, with one parent-relative span per word that also carries the following separator text, so the spans cover the line as the importer requires. Corrected lines and lines without word estimates remain line-timed. The TTML importer now accepts up to 1,536 spans and 4,096 elements; the 64-KiB input bound is unchanged. A complete five-minute song with 501 words exports to 24 KiB.

`scripts/evaluate_word_timing.py` compares word estimates line by line with JamendoLyrics word annotations at revision de188c963fd4539bc769b3feb83582e5a9595e36. Lines without word estimates and lines whose word counts differ are counted and excluded; no line was excluded for a count difference.

## Results

| Measure | Onset | Offset | Even-Split Onset |
| --- | ---: | ---: | ---: |
| Words | 4,365 | 4,365 | 4,365 |
| Median absolute error | 42 ms | 66 ms | 175 ms |
| 90th / 95th percentile | 164 / 238 ms | 203 / 315 ms | 742 / 1,034 ms |
| Within 100 ms | 79.4% | 67.8% | 35.1% |
| Within 200 ms | 92.6% | 89.6% | 53.7% |
| Signed median | +31 ms | −51 ms | +124 ms |

Word estimates were available for 699 of 777 lines; the remaining 78 lines are unresolved or withheld at line level. Per-recording median onset errors range from 29 to 156 ms; two recordings exceed 100 ms. The [numerical record](alignment-data/v18/words.json) lists per-recording results.

## Verification

Python tests cover word grouping and UTF-16 ranges, clamping and withdrawal, validation of malformed word estimates, line and word TTML export including corrected lines, annotation parsing, summary statistics, and exact agreement of the evaluator with its own estimates. A Swift test confirms that the importer accepts 1,536 spans and rejects one more.

## Limitations

Words are delimited by the alignment's letter pattern, so a hyphenated or numeric token in another tokenization could differ; no such difference occurred here. Word offsets inherit the line offset at the last word and the short forced spans elsewhere, which end a median 51 ms early. Syllable timing within long words is not estimated.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
