# Word Confidence Fallback

## Outcome and Scope

October 11, 2026. **Lines whose word timing is unreliable now fill steadily across the whole line instead of word by word, and lines made only of interjections are omitted.** The maintainer observed that, in the second half of Man in the Mirror, ad-libs and exclamations were often filled too early or too late. Improving the alignment of passages dominated by ad-libs and backing vocals would require a new alignment method and evaluation; this change instead avoids presenting word timing where the alignment itself reports low confidence.

## Evidence

Word onsets on the seventeen human-annotated development recordings ([Word-Level Alignment](word-level-alignment.md)) were grouped by each line's greedy lexical similarity on separated vocals:

| Line Similarity | Lines | Median Word Error | Words over 300 ms |
| --- | ---: | ---: | ---: |
| 0.7–1.0 | 358 | 37 ms | 1% |
| 0.5–0.7 | 201 | 43 ms | 4% |
| 0.4–0.5 | 66 | 44 ms | 7% |
| 0.3–0.4 | 38 | 71 ms | 13% |
| Below 0.3 | 36 | 64 ms | 14% |

Lines flagged `uncertain_boundary` misplaced 17% of their words by more than 300 ms. In Man in the Mirror, 13 of the 15 lines below these thresholds lie in the second half, where ad-libs and a backing choir dominate the separated vocals.

## Rules

- **Fallback.** With word granularity, a line with similarity below 0.4, or flagged `uncertain_boundary`, `weak_acoustic_support`, or `weak_separated_support`, is exported as a single span covering the line, so the renderer fills it at a steady pace over the estimated line interval.
- **Interjections.** The vocable rule for omitting standalone lines now also covers interjections such as woo, hoo, ow, hee, yeah, hey, and the ad-lib "shamone". Lines that mix them with lexical words are kept.

In Man in the Mirror, four lines are omitted and fifteen fall back to steady fill; the other lines keep word timing. Tests cover the single-span fallback and the extended interjection rule.

## Limitations

Line intervals of low-confidence lines may themselves be inaccurate; steady fill hides only the word-level errors. Omitting interjection lines departs from the native screen, which displays some of them. The thresholds were chosen from development data and have not been requalified on unseen recordings.

Neither automatic synchronization nor release readiness is established.
