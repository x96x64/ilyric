# iLyric Singing-Alignment Refinement

## Decision and Scope

**Go for explicit Japanese pronunciation overrides and source-ownership diagnostics; no-go for automatic full-song segmentation or unattended synchronization.** The two previously unresolved Japanese examples now produce usable outer line estimates under supplied pronunciation hypotheses. Accepted-case acoustic accuracy is essentially unchanged. English endpoint accuracy does not improve, and held-out negative controls defeat both fitted score gates. The mandatory product requirement remains incomplete.

This gate changes only the optional Python preparation and diagnostic layer. Swift rendering, typography, focus motion, appearance, project versions 1–3, TTML validation, audio encoding, and production `ilyric` behavior remain unchanged. Timing review remains mandatory. No inference runs during frame evaluation or export. The iPhone 16 reference remains reported iOS 27.0.1, build **Unknown**, with no new physical measurement or native-fidelity claim.

## Baseline, Assets, and Protocol

The repository began clean on `main` at `b36e38c`, equal to `origin/main`. The planning baseline, requirements, acquisition study, alignment report, input contracts, implementation, tests, and relevant history were reviewed. All twelve archived model unit sequences and line estimates reproduced **exactly before modification**. Original source/audio hashes and pinned model/source fingerprints passed; the [reproduction record](alignment-data/v2/baseline.json) preserves new run times without replacing historical results.

The [prospective protocol](alignment-data/v2/protocol.json) retains the previous line-boundary targets: median absolute error ≤100 ms, p95 ≤250 ms, at most 5% above 500 ms, and no unmatched lines. EN01 and JA01–JA02 remain development material; EN02–EN03 and JA03–JA06 retain their held-out classifications. The previous rejection of JA06 was already known, so its recovery is a corrective reuse of a known failure, not newly independent coverage validation. No reference timestamps selected pronunciation alternatives. Endpoint parameters and score thresholds were fixed from development cases before held-out scoring.

The environment remains Apple M4, 16 GiB, macOS 27.0.1, Python 3.12, CPU inference with four PyTorch threads, PyTorch 2.8.0, Lightning 2.5.5, Transformers 4.57.1, g2pflow 0.3.1, unidic-lite 1.0.8, and ONNX Runtime 1.30.0. Model identities, revisions, asset hashes, dependencies, corpus attribution, and licenses remain those in the [historical experiment](automatic-alignment.md) and its [asset manifest](alignment-data/v1/model-assets.json).

TIFA source is MIT; its 1.0 ST weights are CC BY-NC-SA 4.0. The English wav2vec2 checkpoint declares Apache-2.0. Corpus and individual recording permissions remain separate. No weights, audio, lyrics, annotations, or third-party implementation are redistributed. No additional downloads, global environment changes, or system-package installations occurred. The continuing 2-GB download and 6-GB storage ceilings were not reset; retained earlier downloads are approximately 1,065 MiB plus small metadata. Inputs, inference logs, and generated media remain ignored.

## Japanese Pronunciation and Source Ownership

Direct source inspection identified two distinct failures in the pinned conversion path:

1. **JA02:** an unknown katakana compound is decomposed into kana units. The converter gives `ー` an empty phoneme path and omits its text ownership. Other long-vowel marks inside recognized whole words remain represented. The model's returned text therefore fails the strict original-text coverage check, even though the acoustic phone path exists.
2. **JA06:** nonstandard small-kana combinations are absent from the kana-to-phoneme dictionary. Conversion stops before acoustic inference. This is a dictionary/reading limitation, not measured evidence of an acoustic mismatch.

A separate, source-hashed JSON document supplies paragraph-relative UTF-16 ranges, exact source text, kana readings, and explanatory notes. Ranges are ordered, nonoverlapping, occurrence-specific, and restricted to contiguous Japanese text. Combining and variation boundaries cannot be split. The converter normalizes only separately supplied readings to NFC; original display text, paragraph breaks, and source identity remain intact. Internal PFML preserves each overridden range as its ownership label while retaining its pronunciation groups. No arbitrary user PFML is parsed. The [command contract](alignment-refinement-commands.md) specifies limits and error behavior.

For JA02, the fixed-source candidate uses the original kana reading and retains the omitted mark in source ownership. Its **80 phone labels and every phone interval are identical to the original output**. Recovery therefore comes from lossless mapping, not a better acoustic model or shifted timestamps. A second candidate explicitly repeats the final vowel; it adds a phone but leaves the outer line boundaries unchanged. A narrow mechanical suggestion detects otherwise exact text differing only by dropped `ー` marks and proposes a same-script kana range. Its range/reading equals the fixed candidate; it is never applied automatically. Other discrepancies suppress the suggestion.

For JA06, two prespecified linguistic hypotheses compare expansion of small kana with common palatalized approximations. Both preserve the source spelling, produce different phone sequences, and return identical outer line boundaries. Neither is newly verified by a human listening annotation. Agreement at the line endpoints cannot identify the correct sung reading or validate internal phone timing. These hypotheses remain explicit user/evaluator inputs, not universal pronunciation rules.

| Case and Candidate | Onset Error | Offset Error | Coverage and Interpretation |
| --- | ---: | ---: | --- |
| JA02 fixed source ownership | −27.709 ms | −13.310 ms | Previously unresolved; same acoustic phone path |
| JA02 explicit repeated vowel | −27.709 ms | −13.310 ms | One additional phone; no outer-boundary advantage |
| JA06 expanded kana | +2.495 ms | +6.895 ms | Previously unavailable; supplied linguistic hypothesis |
| JA06 palatalized approximation | +2.495 ms | +6.895 ms | Different phone sequence; reading remains ambiguous |
| JA03 identity-reading control | +13.946 ms | +10.204 ms | Original phone labels and intervals unchanged |

Conditional Japanese coverage rises from **4/6 to 6/6** with the explicit overrides. Across the four historically held-out utterances, onset median/p95 is **8.221/17.261 ms** and offset median/p95 is **6.871/9.708 ms**, with no boundary above 500 ms. This is coverage recovery within the same single-singer corpus; it does not establish broader Japanese accuracy. JA02 fixed versus mechanically suggested runs and repeated JA06 expanded runs produce identical units and line intervals. The [numerical record](alignment-data/v2/pronunciation.json) preserves all candidates, counts, and qualifications.

## English Endpoint Investigation

The large errors are not confined to the recording endpoint. EN02 TIFA's second line ends **995.940 ms late**, with a final consonant interval placed after the independent line boundary. Its first line ends 345.828 ms early. EN02 CTC starts the third line 3,205.780 ms early. Final excerpt offsets are comparatively close; EN02's censored final offset remains excluded from aggregate acceptance statistics. A global terminal trim cannot repair these interior correspondence errors.

These observations separate measured residuals from possible causes. Sustained vowels, final consonants, accompaniment, reverb, and uncertain annotation conventions can all influence boundaries. The present data do not isolate which signal component causes each error. Phonetic annotation, audible vocal decay, and a desirable visual highlight endpoint remain different quantities. No annotation was moved to improve agreement.

Three bounded treatments were compared:

| Treatment | Procedure | Held-Out Consequence |
| --- | --- | --- |
| Baseline | Preserve original onsets and offsets | Historical errors reproduced |
| Silence-aware candidate | Whole-mixture RMS in 10-ms windows; nearest sustained low-energy run within a bounded window; require an observed decline rather than an excerpt edge | No held-out endpoint changes under the selected parameters; no accuracy gain |
| Conservative uncertainty | Preserve timestamps and flag missing local silence evidence or an endpoint touching capture bounds | All 18 examined English model/line combinations require review; unsuitable as a correctness classifier |

The development grid tested relative thresholds −20/−30/−40 dB, low-energy durations 80/160 ms, and search radii 250/500/1,000 ms. The local reference is the 90th-percentile RMS within the search window. EN01, pooled across both engines, selected −20 dB, 160 ms, and 250 ms; ties prefer the smaller radius and longer low-energy support. Seventeen of eighteen grid settings make no development changes. The only setting that moves a boundary increases development error. Parameters were not retuned on EN02 or EN03.

The selected candidate finds no sustained low-energy decline in the tested English windows. Continuous mixture energy is not proof of continuous vocals: instruments can obscure a vocal endpoint. No speech VAD, vocal separator, model download, or unsupported claim of vocal activity was introduced. Treating absent mixture silence as a rejection would flag every matched example, including accurate intervals. The diagnostic is therefore retained outside active timing preparation.

| Held-Out Engine | Onset Median / p95 | Offset Median / p95 | Maximum Onset / Offset |
| --- | ---: | ---: | ---: |
| CTC | 129.907 / 2,454.335 ms | 135.828 / 240.119 ms | 3,205.780 / 264.060 ms |
| TIFA | 127.890 / 339.371 ms | 325.727 / 865.918 ms | 345.828 / 995.940 ms |

Both endpoint candidates preserve these errors. CTC has 1/6 onsets above 500 ms; TIFA has 1/5 uncensored offsets above 500 ms. No new unmatched lines arise in these positive examples. The [endpoint record](alignment-data/v2/endpoints.json) includes the full development grid, individual residuals, censoring, and unsupported evidence.

## Incorrect-Text Controls and Failure Detection

Forty model/input combinations comprise eight matched positives and 32 deliberately mismatched controls. Each underlying case retains its exact original audio. Negative text either omits a middle phrase, duplicates a phrase, substitutes an independently authored absent phrase, or ends before the actual vocal passage. Japanese one-line text is divided into code-point thirds only to construct controlled omissions/repetitions; these cuts are not asserted to be linguistic or timing boundaries. The private corpus text remains unpublished. Public synthetic tests exercise the same classification and unresolved-result logic without models.

The worker now records TIFA's token-agreement and aligned-span similarity diagnostics and the CTC mean forced-token log support. TIFA agreement is computed from a text-conditioned model; CTC support averages the forced character paths. Neither is a calibrated probability of correct lyrics or complete vocal coverage. Scores can remain high for omitted or repeated material.

For each engine, development includes matched and mismatched inputs. The separator is placed halfway between the lowest matched score and the highest lower-scoring negative, preserving zero observed development false rejections. Higher-scoring mismatches remain inseparable by that rule. Frozen thresholds are **−2.598406** for CTC and **0.989473** for TIFA. Unresolved model output always requires review. The [public evaluator](../scripts/evaluate_alignment_refinement.py) reproduces the calculation from a private manifest and reports unavailable inputs explicitly.

| Candidate Gate | Development False Acceptance | Held-Out False Acceptance | Held-Out False Rejection |
| --- | ---: | ---: | ---: |
| CTC structural completion alone | 4/4 | 8/8 | 0/2 |
| CTC fitted score gate | 1/4 | **7/8** | 0/2 |
| TIFA structural completion alone | 6/8 | 11/12 | 0/3 |
| TIFA fitted score gate | 2/8 | **4/12** | 0/3 |

Here “false acceptance” means a known mismatch left **unflagged by the experimental gate**, not automatic export permission. The existing mandatory review still blocks unreviewed artifacts. TIFA's held-out misses include omitted, duplicated, and prematurely ended English text and an omitted Japanese phrase. CTC's development/held-out score shift further limits transfer across recordings. Two development and one held-out TIFA negatives have structural unresolved output; this is counted separately in the [failure-detection record](alignment-data/v2/failure-detection.json).

Zero false rejection on only two or three positives does not establish specificity. Lower average timing error on accepted examples does not detect catastrophic correspondence errors. Neither threshold is promoted into automatic preparation or export. Missing source support remains unresolved; plausible timestamps are not interpolated into rejected regions.

## Correction Burden and Implementation

The new capability avoids manual timestamp entry for the two recovered Japanese line intervals in this experiment. It requires one explicit range for JA02 and two ranges for JA06; the JA02 range can be proposed mechanically. This is a count of interventions, not measured editing time or demonstrated user-effort reduction. No timed usability study was conducted. English correction burden is not reduced, and all estimates still require review. Corrected intervals retain their original estimate and correction history; preparation never silently repairs a model path.

Implemented changes are limited to strict source-preserving pronunciation documents, local PFML generation, unapplied long-vowel ownership suggestions, additional raw diagnostics, deterministic endpoint/threshold analysis, and synthetic tests. No acoustic checkpoint, original file, pronunciation dictionary, corpus annotation, or historical measurement was modified. Failed endpoint and acceptance candidates remain diagnostic functions only.

## Performance and Verification

Pronunciation experiments took approximately 16.4–18.5 seconds per process, with peak RSS approximately 1,047–1,100 MiB. Baseline reproduction and extended positive runs retain the same models and four-thread CPU policy. Cold dictionary construction plus PFML generation measured approximately 0.250 ms; 100 repeated generations averaged approximately 0.062 ms. Whole-mixture energy extraction took approximately 18–29 ms for the English excerpts. These microbenchmarks exclude model imports and inference; run-to-run process variation does not establish a speed improvement. The negative-control runs took 2.779–3.108 seconds and 1,173–1,337 MiB for CTC, and 16.013–17.650 seconds and 1,046–1,090 MiB for TIFA. Input variants differ, so these are operational ranges rather than speed comparisons. The [performance record](alignment-data/v2/performance.json) preserves individual observations. Continuing evaluation storage, including both public checkout artifacts, was approximately 3,784 MiB, below the 6-GB ceiling.

Public verification and the estimated-timing video demonstration are recorded in the [validation record](alignment-data/v2/validation.json). The demonstration uses the recovered JA06 estimate after explicit review against independent annotations, without timestamp correction. The video contains 720 frames/12 seconds at 1080×1920 and 60 fps, H.264 limited-range Rec.709, and mono 48-kHz AAC. Every video timestamp passed; supplied-audio correlation was 0.999720 with zero best lag at a 16-sample search step. Rendering took 17.377 seconds (41.435 frames/s), an isolated run without a speedup claim. Decoded frames at 5.0 and 11.5 seconds show the unchanged source across three wrapped lines, focused then inactive, with the established `contain` geometry. Technical video validity remains separate from the measured acoustic residuals and uncertain internal pronunciation.

All 61 Swift and 99 Python tests passed, including 13 new refinement tests. Release builds, repeated renderer determinism, random-order reference-probe checks, and existing TTML audiovisual/refusal checks passed. A fresh public checkout repeated both complete suites and exported the 601-frame synthetic preparation fixture without models or private media. Missing optional evaluation/reference inputs returned explicit unavailable results. One sandboxed Core Image determinism attempt failed; the authorized repeat passed without changing source, renderer, or toolchain. Public history contains only original fixtures, code, documentation, and sanitized numbers. Original media, model assets, corpus text, and private diagnostics remain ignored.

## Next Mandatory Gate

**Do not proceed to automatic full-song segmentation yet.** Short-clip English correspondence errors and unflagged mismatches remain material. The smallest further experiment is an independent acoustic-coverage diagnostic on the four TIFA held-out misses and matched controls, with newly reserved positives/negatives before any threshold promotion. It must detect unexplained sung material and incorrect repetitions rather than reuse a text-conditioned agreement score. Reuse local models where feasible; evaluate a separately approved singing-aware vocal-evidence or separation candidate only if mixture contamination demonstrably prevents discrimination. Do not start a new broad aligner survey.

Separately verify the ambiguous Japanese readings against a qualified listener or pronunciation reference before claiming phone-level correctness. Retain explicit source mapping and the improved line coverage. Once mismatch detection and English boundaries meet the unchanged criteria, the next full-song experiment should use recordings longer than one minute, additional held-out singers, unannotated clip boundaries, repeated choruses, instrumental sections, and uncertain segment correspondence. No such full-song claim is supported by this gate. Deferred visual and product features remain deferred.
