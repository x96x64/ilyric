# Anchored Realignment

## Outcome

October 12, 2026. **Realigning unaccepted runs of lines between accepted anchors did not improve synchronization, so the change was not adopted.** On the thirteen observed MUSDB18 recordings with the lowest placement, it changed one section from unresolved to correctly placed among 225 scored sections; the remaining unresolved lines are limited by recognition, not by drift of the alignment path.

## Motivation

Development measurements under the [revised criteria](revised-preview-criteria.md) placed 94.7% of the scored sections of the MUSDB18 training recordings correctly, with nine recordings below 80%. In those recordings, the complete-sequence forced path was displaced by tens of seconds, in one case by about two minutes, and the vocal rules correctly rejected the displaced lines. Because accepted lines are almost always correct, aligning each unaccepted run again within the frames between its accepted neighbours could have recovered lines that a single drift had displaced.

## Method

Each maximal run of lines without an estimate was aligned again with the same Viterbi search, restricted to the frames between the end of the preceding accepted line and the start of the following one (or the recording's ends). New proposals were scored with the version 3 [neighbour acceptance](neighbour-acceptance.md), and a realigned line replaced the original only when accepted. The thirteen recordings below 80% placement, nine from the training partition and four from the test partition, all previously observed, were processed again with the change.

## Results

| | Placement | Wrong | Unresolved | Scored sections |
| --- | ---: | ---: | ---: | ---: |
| Version 3 | 56.9% | 14 | 83 | 225 |
| Version 3 with anchored realignment | 57.3% | 14 | 82 | 225 |

After realignment, the unresolved lines still had low acoustic support, usually below −3.5, and greedy similarity mostly at or near zero; for most of them even the realigned proposal fell outside the annotated section. The recognizer does not hear these words as transcribed, in heavily mixed or shouted vocals and in sections with several singers, so constraining the search does not create the missing evidence.

## Consequences

The change was removed to keep the alignment unchanged and simple. Further gains on these recordings require stronger acoustic evidence, for example a recognition model trained on singing, rather than a different search over the same evidence.
