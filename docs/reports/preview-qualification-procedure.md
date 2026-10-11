# Preview Qualification Procedure

## Purpose and Lock

October 11, 2026. This procedure defines the unseen English evaluation that decides whether automatic synchronization qualifies for the public preview (Stage 2 of the [roadmap](../roadmap-to-stable.md)). It is committed before any evaluation audio is downloaded. The evaluated system is the released `ilyric` 0.1.0 (tag `v0.1.0`, commit `a5a999a`) with its default CPU inference, run as `ilyric align AUDIO LYRICS -o OUT.ttml --report OUT.json`. Nothing in the pipeline, its options, or the criteria below may change after the first evaluated recording is processed. Each recording is processed once.

Improvements suggested by the results are developed on development data and require a new unseen set, as the roadmap requires.

## Evaluation Sets

### Set A: Remaining JamendoLyrics English Recordings

[JamendoLyrics](https://huggingface.co/datasets/jamendolyrics/jamendolyrics) at revision `de188c963fd4539bc769b3feb83582e5a9595e36` lists 20 English recordings. Seventeen were used before: three in development and fourteen in the locked M2 evaluation, which made them development material. The remaining three, `Kinematic_-_Peyote`, `Wordsmith_-_The_Statement`, and `The_Rinn_-_Voices__2017_Version_`, were excluded from M2 because the dataset marks them as polyphonic. They have never been processed by iLyric. They carry human word annotations and are scored at word and line level, but because all three are polyphonic, Set A is reported as a diagnostic and does not decide qualification.

### Set B: MUSDB18 Test Recordings with English Lyrics

The [MUSDB18](https://zenodo.org/records/1117372) test partition contains 50 recordings, of which 45 have English lyrics transcribed in the [MUSDB18 lyrics extension](https://zenodo.org/record/3989267) (Schulze-Forster, Doire, Richard, and Badeau, 2021; CC BY-NC-SA 4.0). The transcription divides each song into sections of 3 to 12 seconds with start and end times at a resolution of one second, chosen at natural pauses, each labeled (a) one singer, (b) several singers on the same phonemes, (c) several singers on different phonemes, or (d) no singing; sections of type (c) marked `*` contain simultaneous different words. None of these recordings has been processed by iLyric. Set B decides qualification.

The separator's training data is a limitation: the released `htdemucs` checkpoint is documented as "Trained on MusDB + 800 songs" without stating whether the MUSDB18 test partition was excluded. Its publication reports results on that partition, which suggests exclusion, but this is not confirmed. The recognition model (wav2vec 2.0 trained on LibriSpeech) has not seen these recordings.

## Inputs

For Set A, the dataset's lyrics file is the input text. For Set B, each section of type (a), (b), or (c) becomes one input line in order, including `*` sections so that the sung sequence is complete; sections of type (d) are omitted. The text is used as transcribed, lowercase and without punctuation; `ilyric` splits it into paragraphs of at most four lines. The MUSDB18 mixture is the first audio track of each stem file and is extracted losslessly into a single-track file before processing; the stems are not used.

## Measures

A line's status is taken from the report: **aligned** lines have an estimate; **placed** and **omitted** lines are **unresolved**.

Set B, per section line, excluding `*` sections from scoring:

1. **Placement accuracy:** the share of scored lines that are aligned and whose estimated interval midpoint lies within the annotated section extended by one second on each side, to allow for the one-second resolution.
2. **Wrong placement:** the share of scored lines that are aligned but whose midpoint lies outside that tolerance.
3. **Unresolved rate:** the share of scored lines that are unresolved.
4. **Word containment:** among words of aligned scored lines, the share whose estimated interval midpoint lies within the extended section.
5. **Section onset difference** (diagnostic only): estimated line onset minus annotated section start; section boundaries are pauses, not sung onsets, so this is not a timing error.
6. **Run time and peak memory** per recording, relative to its duration.

Set A, against the human annotations: line placement at the correct occurrence, unresolved rate, and absolute onset and offset errors of lines and word onsets (median, 95th percentile, and share above 500 ms), as defined in the [M2 procedure](m2-qualification-procedure.md).

## Qualification Criteria

Automatic English synchronization qualifies for the public preview when, over all scored Set B lines pooled:

- placement accuracy is at least 95%,
- wrong placement is at most 2%,
- the unresolved rate is at most 5%,
- word containment is at least 95%,
- no recording has placement accuracy below 80%, and
- run time is at most twice the recording duration on the reference Mac.

Per-recording results are reported for every recording, together with results split by section type (a), (b), and (c). If the criteria are not met, the preview remains blocked and the failure analysis records which recordings and section types fail.

## Resources and Privacy

On October 11, 2026, the maintainer approved the downloads of both sets, raised the cumulative download ceiling to 8,000,000,000 bytes and the evaluation-storage ceiling to 30,000,000,000 bytes, and authorized deleting the MUSDB18 archive (4.7 GB) after the mixtures of the 45 test recordings are extracted and its digests recorded. Before this approval, measured evaluation storage was 21.763 GB, above the previous 20-GB ceiling, because rendered development videos had accumulated; three regenerable verification videos (1.09 GB) were deleted with the maintainer's approval.

All audio, lyrics, annotations, and per-line outputs remain in ignored `reference-private/preview/` and `artifacts/preview/`. Both datasets are licensed for non-commercial research, and the lyrics are copyrighted by their composers; published results contain only aggregate and per-recording numbers, identified by dataset name, without lyric text.
