# Neighbour Acceptance

## Outcome

October 11, 2026. **Version 3 of the vocal rules accepts rejected lines that are framed by accepted neighbours, which raised placement on the development recordings from 87.5% to 93.0% while wrong placement stayed at 1.2%.** The change addresses the main failure of the [first preview qualification](preview-qualification-results.md): correct forced proposals rejected by conservative evidence thresholds.

## Development Data

All recordings were already observed: the 17 processed JamendoLyrics English recordings and the three Set A recordings, scored against human line annotations, and the 45 MUSDB18 test recordings, scored against their sections as in the [first procedure](preview-qualification-procedure.md). This gives 1,793 scored lines. A proposal is correct when it overlaps the annotated line, or, for MUSDB18, when its midpoint lies within the section extended by one second.

## Findings

The forced proposal was correct for 1,732 lines (96.6%), so the forced path itself is rarely wrong. Version 2 accepted 1,578 lines, ten of them wrongly, and rejected 215 lines with a proposal, of which 164 were correct. Among the 61 wrong proposals, the duration per character was usually implausible (median 484 ms against 127 ms for correct proposals), and acoustic support and lexical similarity were lower.

Raising or lowering the version 2 thresholds alone reached about 91% placement under song-level five-fold cross-validation, constrained to at most 1.2% wrong placement. Context was more informative: among rejected lines with a duration of at most one second per character, those whose nearest lines were both accepted were correct in 37 of 40 cases, and those with one accepted neighbour in 77 of 86.

## Rule

After the version 2 evidence is applied, a rejected line with a proposal is accepted, with the flag `neighbour_supported`, when its duration is at most one second per character and either both nearest lines are accepted by version 2, or one is and the line's greedy similarity is at least 0.05. Neighbour acceptance is decided against the version 2 result only, so accepted lines do not chain. Accepted lines then pass through the same vocal-activity refinement as other lines, and because they keep their rejection flags they fill steadily rather than word by word. The version 2 thresholds are unchanged; a cross-validated search over them together with the neighbour parameters selected the same base thresholds in four of five folds.

## Results

| Rules | Placement | Wrong placement | Unresolved |
| --- | ---: | ---: | ---: |
| Version 2 | 87.5% | 0.6% | 12.0% |
| Version 3 | 93.0% | 1.2% | 5.8% |
| Version 3, five-fold cross-validation (simulated) | 92.4% | 1.5% | 6.1% |

The measured version 3 figures come from running the command on all 62 recordings. Most remaining wrong placements come from one MUSDB18 recording whose forced path drifted, where only 31 of 52 proposals were correct.

## Limitations

The parameters were chosen on these recordings, so the measured figures are optimistic; the cross-validated estimate is the better guide, and the [second preview qualification](second-preview-qualification-procedure.md) evaluates the rule on unseen recordings. Version 2 remains the default of `alignLyrics` and `VocalRules.apply` and keeps exact parity with the Python reference; the command uses version 3.
