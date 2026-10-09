# M2 Locked Evaluation

## Outcome and Scope

October 10, 2026. **M2 does not pass.** The frozen separated-vocal CTC pipeline with vocal-activity rules was evaluated once on fourteen human-annotated English recordings never used in development. No song satisfied every condition. The pipeline placed 406 of 637 lines at the correct occurrence and left 231 unresolved, against 154 correct placements for the complete-sequence mixture baseline. **No retained estimate was displaced**: every one of the 406 estimates overlapped its own reference line. Onset accuracy largely met the targets; coverage and offset accuracy did not.

A post-hoc diagnostic identifies the dominant coverage loss: 222 of the 229 lines rejected for weak lexical agreement had raw proposals at the correct occurrence. This finding defines the next development gate; it does not change the result recorded here.

The locked set, lock procedure, and conditions are defined in the [revised qualification procedure](m2-qualification-procedure.md). The pipeline and rules were frozen at commit `dc91751`, as described in the [vocal-activity rules report](vocal-activity-rules.md). Production rendering, project formats, and the correction format are unchanged.

## Locked Set

The set comprises fourteen English recordings from [JamendoLyrics](https://huggingface.co/datasets/jamendolyrics/jamendolyrics) at revision `de188c963fd4539bc769b3feb83582e5a9595e36`, labeled EN-J01 through EN-J14, with 637 human-annotated lines across multiple performers and genres. Recordings flagged for polyphonic or overlapping vocals were excluded, as were the three recordings used in development. EN-J03, EN-J08, and EN-J09 are flagged as containing non-lexical vocals. Audio files matched their published SHA-256 object identifiers. Each recording carries its own Creative Commons license, recorded in the numerical record; audio and lyrics remain unpublished local material. Paragraphs longer than four lines were split without changing any line.

## Results

| Condition | Songs Passing (of 14) |
| --- | ---: |
| At least 95% of lines at the correct occurrence | 0 |
| At most 5% unresolved | 0 |
| No unflagged displacement | 14 |
| Onset median ≤ 100 ms | 13 |
| Onset p95 ≤ 250 ms | 12 |
| Onset errors > 500 ms ≤ 5% | 14 |
| Offset median ≤ 100 ms | 2 |
| Offset p95 ≤ 250 ms | 1 |
| Offset errors > 500 ms ≤ 5% | 5 |
| No unflagged error > 2 s | 10 |
| Preparation ≤ 2 × duration | 14 |

| Case | Lines | Correct (Pipeline / Mixture) | Unresolved | Onset Median / p95 (ms) | Offset Median / p95 (ms) | Signed Offset Median (ms) |
| --- | ---: | ---: | ---: | --- | --- | ---: |
| EN-J01 | 58 | 31 / 8 | 27 | 57 / 280 | 197 / 1,021 | −195 |
| EN-J02 | 27 | 21 / 5 | 6 | 29 / 136 | 141 / 301 | −140 |
| EN-J03 | 46 | 34 / 0 | 12 | 20 / 108 | 336 / 568 | −336 |
| EN-J04 | 42 | 5 / 0 | 37 | 64 / 353 | 178 / 268 | −178 |
| EN-J05 | 37 | 20 / 3 | 17 | 141 / 212 | 301 / 526 | −301 |
| EN-J06 | 30 | 18 / 7 | 12 | 63 / 140 | 131 / 255 | −131 |
| EN-J07 | 82 | 76 / 65 | 6 | 28 / 85 | 68 / 209 | −45 |
| EN-J08 | 20 | 6 / 0 | 14 | 44 / 76 | 261 / 980 | −261 |
| EN-J09 | 50 | 29 / 17 | 21 | 32 / 129 | 132 / 599 | −132 |
| EN-J10 | 43 | 16 / 2 | 27 | 25 / 137 | 196 / 591 | −196 |
| EN-J11 | 31 | 18 / 0 | 13 | 27 / 137 | 390 / 1,809 | −390 |
| EN-J12 | 72 | 44 / 22 | 28 | 29 / 61 | 87 / 350 | −85 |
| EN-J13 | 53 | 49 / 18 | 4 | 46 / 186 | 157 / 644 | −153 |
| EN-J14 | 46 | 39 / 7 | 7 | 40 / 108 | 161 / 757 | −158 |

Errors use retained estimates. Seven unflagged errors exceeded two seconds across four songs, all within estimates that still overlapped their references. Preparation took 0.28–0.53 times recording duration, and peak process RSS was 2.65–3.03 GB, within the proposed operational targets. The host slept during EN-J10 through EN-J12; recorded process timers exclude sleep. The [numerical record](alignment-data/v16/m2-evaluation.json) contains complete per-song statistics, licenses, and the freeze record.

## Interpretation

1. **Correspondence is reliable when accepted.** Zero displacements across 637 lines on unseen recordings is the strongest evidence yet that separated-vocal CTC places supplied lines at the correct occurrence.
2. **The lexical-agreement gate rejects mostly correct proposals.** All but two unresolved lines carry the weak-lexical-agreement flag. Of 229 such lines, 222 raw proposals overlapped their reference, with median absolute onset error of 74 ms and p95 of 2,262 ms. The greedy speech-model transcription used for that gate is unreliable on singing even when the forced path is correct; median similarity was 0.39 for overlapping proposals and 0.24 for the seven nonoverlapping ones. This diagnostic was computed after the locked run and cannot select thresholds evaluated on this set.
3. **Offsets end early.** Signed median offset error is negative on all fourteen songs, from −45 to −390 ms, reproducing the bias observed in development. Because these annotations were not used in development, the bias is unlikely to be only a development-set artifact, although all evaluated annotations share the JamendoLyrics convention.
4. **Onsets are close to target.** Thirteen songs meet the 100-ms onset median and twelve meet the 250-ms onset p95.

## Next Gate

M3 and the public preview remain blocked on M2. The next development gate should replace the greedy-similarity acceptance with an acceptance rule that uses evidence independent of the forced path, such as forced-path posterior support on the separated stem, vocal activity, duration plausibility, and neighbor consistency, and should model offset placement explicitly. Development may use EN-F01 through EN-F03 and, now that it has been observed, the EN-J set. Requalification therefore needs a new unseen set. JamendoLyrics has no remaining eligible English recordings; candidates are the maintainer's own recordings annotated with the revised tool, or another lawfully obtainable human-annotated dataset, subject to approval.

Neither automatic synchronization, release readiness, nor native iOS 27 Music fidelity is established.
