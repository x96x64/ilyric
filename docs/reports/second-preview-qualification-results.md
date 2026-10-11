# Second Preview Qualification Results

## Outcome

October 11, 2026. **English synchronization still does not meet the preview criteria, although every measure improved and misplacement remained below 1%.** The command built from commit `960944c`, with the version 3 [neighbour acceptance](neighbour-acceptance.md), was evaluated once on the 96 never-processed MUSDB18 training recordings, as locked in the [Second Preview Qualification Procedure](second-preview-qualification-procedure.md). One recording has no scored sections because all of its sung sections are marked `*`, which leaves 95 recordings and 1,940 scored sections.

## Qualification Measures

| Criterion | Threshold | First qualification | Second qualification | Met |
| --- | --- | ---: | ---: | --- |
| Placement accuracy | ≥ 95% | 82.5% | 88.0% | No |
| Wrong placement | ≤ 2% | 0.9% | 0.8% | Yes |
| Unresolved rate | ≤ 5% | 16.5% | 11.2% | No |
| Word containment | ≥ 95% | 99.1% | 99.3% | Yes |
| Recordings below 80% placement | none | 13 of 45 | 16 of 95 | No |
| Run time relative to duration | ≤ 2 | ≤ 0.20 | ≤ 0.24 | Yes |

Peak memory was at most 2.1 GB. Placement was 100% for 50 recordings and at least 90% for 70 of 95.

| Section type | Sections | Placement | Wrong | Unresolved | Word containment |
| --- | ---: | ---: | ---: | ---: | ---: |
| (a) one singer | 1,015 | 93.9% | 0.5% | 5.6% | 99.5% |
| (b) several singers, same phonemes | 666 | 80.8% | 1.5% | 17.7% | 99.1% |
| (c) several singers, different phonemes | 259 | 83.4% | 0.0% | 16.6% | 99.2% |

The first and second sets differ in recordings, so the comparison indicates direction rather than a controlled effect. The separator was trained on the second set's partition, which may favour it.

## Composition of Unresolved Sections

The 218 unresolved sections fall into three groups:

1. **Omitted vocable lines: 104 sections (5.4% of all).** Sections consisting only of vocables such as "ooh" or "yeah" that the evidence did not accept are omitted from the output by design, following the maintainer's earlier decision to drop untimed ad-libs. The procedure counts them as unresolved. With `--keep-ad-libs` they would be placed rather than omitted, which also counts as unresolved.
2. **Placed lines: 82 sections (4.2%).** Lines without accepted timing are spread between their neighbours; 43 of these placements still fall within the annotated section and its one-second tolerance.
3. **One recording longer than ten minutes: 32 sections (1.6%).** The command's documented limit of 600 seconds of audio stopped the alignment.

Counting placed lines whose steady fill falls in the right section, 90.2% of sections would be shown at the right place in a rendered video.

## Consequences

The public preview remains blocked under the locked criteria. The analysis identifies three further changes, each to be developed on observed data only:

- aligning vocable-only lines as ordinary lines when the evidence permits, instead of rejecting and then omitting them;
- aligning recordings longer than ten minutes in bounded passages;
- reducing the unresolved rate on sections with several singers, which account for most placed lines.

No further public English set with time-aligned lyrics and freely obtainable audio of comparable size was found, so a third unseen evaluation would need a new data source. Whether the preview criteria, which were set for this project rather than by an external standard, should count omitted vocable lines as failures is a decision for the maintainer.

## Limitations

As in the first qualification, the annotations measure placement at one-second resolution, not onset accuracy. The separator was trained on this partition. Two recordings were scored after correcting the scoring script, which compared report lines without the command's removal of a space before punctuation; their alignments were unaffected.
