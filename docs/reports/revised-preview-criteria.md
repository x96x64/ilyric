# Revised Preview Criteria

## Decision

October 12, 2026. After the [second preview qualification](second-preview-qualification-results.md), the maintainer decided to continue improving synchronization and to revise how the preview criteria treat lines that consist only of vocables. This document fixes the revised scoring before any further qualification run; it does not change the results of the two completed qualifications, which remain failed under the criteria they were run with.

## Vocable-Only Sections

The command omits a line from the output when it consists only of vocables, such as "ooh", "yeah", or "na na", and its timing was not accepted. This follows the maintainer's earlier decision that untimed ad-libs should not be shown. Under the locked criteria, every such omission counted as an unresolved line, so a deliberate product behaviour was scored as a synchronization failure; in the second qualification these omissions were 104 of 1,940 scored sections.

From the next qualification onward:

- A section is **vocable-only** when every word of its text matches the command's vocable pattern (`TTMLExport.nonlexical`). The classification depends on the text alone, so it is fixed before any audio is processed.
- Vocable-only sections are excluded from the scored sections for placement accuracy, wrong placement, unresolved rate, word containment, and the per-recording placement criterion.
- They are reported separately: their count, the share omitted, and, of those aligned, the share correctly placed.

All other definitions and thresholds of the [first procedure](preview-qualification-procedure.md) are unchanged: placement accuracy at least 95%, wrong placement at most 2%, unresolved rate at most 5%, word containment at least 95%, no recording below 80% placement, and run time at most twice the recording duration.

## Rationale and Risk

An omitted vocable line leaves an ad-lib unshown; it cannot display wrong lyrics at a wrong time. Excluding these sections narrows the criteria to the lyrics the command commits to timing. The exclusion could hide a failure in which lexical lines are misclassified as vocables; the vocable pattern contains only interjections and syllable repetitions, and the separate report makes the excluded share visible.

## Next Evaluation Data

Both public English sets with time-aligned lyrics and freely obtainable audio, JamendoLyrics and the MUSDB18 lyrics extension, have now been observed. A third qualification therefore requires a new data source, which will be proposed to the maintainer before any data is obtained. Until then, results on observed recordings are reported as development measurements and cannot qualify a version.
