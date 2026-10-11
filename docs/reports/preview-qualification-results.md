# Preview Qualification Results

## Outcome

October 11, 2026. **Automatic English synchronization does not yet qualify for the public preview.** The released `ilyric` 0.1.0 was evaluated once, as locked in the [Preview Qualification Procedure](preview-qualification-procedure.md), on 45 never-processed MUSDB18 test recordings (Set B) and three never-processed polyphonic JamendoLyrics recordings (Set A). Lines that the command aligns are almost always placed correctly, but the acceptance rules leave too many lines unresolved, and one long recording failed outright.

## Set B: Qualification Measures

1,065 scored sections over 45 recordings, pooled:

| Criterion | Threshold | Result | Met |
| --- | --- | ---: | --- |
| Placement accuracy | ≥ 95% | 82.5% | No |
| Wrong placement | ≤ 2% | 0.9% | Yes |
| Unresolved rate | ≤ 5% | 16.5% | No |
| Word containment | ≥ 95% | 99.1% | Yes |
| Recordings below 80% placement | none | 13 | No |
| Run time relative to duration | ≤ 2 | 0.16 to 0.20 | Yes |

Peak memory was at most 1.9 GB per recording. By section type:

| Type | Sections | Placement | Wrong | Unresolved | Word containment |
| --- | ---: | ---: | ---: | ---: | ---: |
| (a) one singer | 462 | 83.3% | 0.9% | 15.8% | 99.5% |
| (b) several singers, same phonemes | 444 | 89.0% | 0.0% | 11.0% | 99.5% |
| (c) several singers, different phonemes | 159 | 62.3% | 3.8% | 34.0% | 96.3% |

Per recording, in the dataset's alphabetical order, placement accuracy was 100% for 13 recordings and at least 90% for 23. The thirteen recordings below 80% had placement of 0.0% (two recordings), 8.3%, 40.0% (two), 44.2%, 62.1%, 64.5%, 66.7%, 75.0% (two), 76.2%, and 77.3%. One recording reached 14.3% wrong placement; every other recording was at most 10%.

## Set A: Diagnostic

| Recording | Lines | Correct placement | Unresolved | Line onset median / p95 | Word onset median / p95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Kinematic, Peyote | 14 | 92.9% | 7.1% | 52 / 874 ms | 43 / 625 ms |
| Wordsmith, The Statement | 31 | 100% | 0% | 25 / 70 ms | 34 / 100 ms |
| The Rinn, Voices | 46 | 84.8% | 15.2% | 51 / 237 ms | 35 / 237 ms |

On the aligned lines of these polyphonic recordings, word onsets have a median error of 34 to 43 ms, which supports the word timing when a line is accepted.

## Failure Analysis

1. **Conservative acceptance.** Of the 1,065 scored sections, 176 were unresolved: 36 from the failed recording, 122 placed between neighbours, and 18 omitted as untimed vocable lines. Among the 140 unresolved sections of completed recordings, the most frequent rejection reasons were weak lexical agreement of the greedy transcription (116), an implausible duration per character (87), repeated text requiring review (78), and weak acoustic support (66); lines usually carry several reasons. The even placement between neighbours still overlapped the annotated section, with its one-second tolerance, for 102 of the 122 placed lines. As in the [M2 locked evaluation](m2-locked-evaluation.md), the greedy-similarity gate rejects many forced proposals that are correct.
2. **A hard failure on a long recording.** One recording stopped with "Full-song CTC trace exceeds 120 MB", a resource bound of the complete-sequence alignment, so none of its 36 sections were timed. The command must degrade, for example by aligning in bounded passages, instead of failing.
3. **Simultaneous different words.** Type (c) sections are the weakest, with 34% unresolved and 3.8% wrong placement, which is expected when several voices sing different words.
4. **Accuracy when aligned.** Wrong placement of 0.9% and word containment of 99.1% show that the errors are mostly omissions of timing rather than misplacements.

## Consequences

The public preview remains blocked. The next development gate addresses the acceptance rules and the long-recording failure on development data only: the 20 JamendoLyrics English recordings, now all observed, and the private development recordings. MUSDB18 test recordings and Set A are now observed and cannot qualify a later version; a new unseen set is required, for example drawn from the MUSDB18 training partition, which has English lyrics annotations for 96 recordings and was not used in this evaluation, subject to the separator's training-data limitation recorded in the procedure.

## Limitations

The section annotations have one-second resolution and boundaries at pauses, so Set B measures placement, not onset accuracy. The transcriptions are by non-native annotators. Whether the separator's training excluded the MUSDB18 test partition is unconfirmed. Set A contains only three recordings, all polyphonic. The MUSDB18 archive was deleted after extraction with the maintainer's approval; its MD5 matched the published `af06762477334799bfc5abf237648207`.
