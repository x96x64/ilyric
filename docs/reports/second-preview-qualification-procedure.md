# Second Preview Qualification Procedure

## Purpose and Lock

October 11, 2026. This procedure defines the second unseen English evaluation for the public preview, after the [first qualification](preview-qualification-results.md) failed. It is committed before the audio of the new set is obtained. The evaluated system is `ilyric` built from commit `960944c`, which adds the version 3 neighbour acceptance and the packed CTC trace to version 0.1.0, run with default CPU inference as `ilyric align AUDIO LYRICS -o OUT.ttml --report OUT.json`. Nothing in the pipeline, its options, or the criteria may change after the first recording of the new set is processed, and each recording is processed once.

## Evaluation Set

Set C is the MUSDB18 training partition: 100 recordings, of which 96 have English lyrics in the [MUSDB18 lyrics extension](https://zenodo.org/record/3989267), with 2,050 sung sections, 1,940 of them scored after excluding sections marked `*` (types (a) 1,015, (b) 666, (c) 259). None has been processed by iLyric, and the version 3 rule was developed without them.

**Limitation.** The released `htdemucs` separator was trained on MUSDB18, and its training partition is certainly included. Vocal separation on Set C is therefore likely better than on unseen music, and Set C results may overstate synchronization quality. No other public English set with time-aligned lyrics and freely obtainable audio of sufficient size was found; the result is reported with this qualification, and the maintainer decides whether it suffices for the preview.

## Inputs, Measures, and Criteria

Inputs, measures, and qualification criteria are those of the [first procedure](preview-qualification-procedure.md), unchanged: each sung section becomes one input line with parenthesis characters removed; placement accuracy at least 95%, wrong placement at most 2%, unresolved rate at most 5%, and word containment at least 95%, pooled over scored sections; no recording below 80% placement; and run time at most twice the recording duration. Results are also reported by section type and per recording.

## Resources

The maintainer pre-approved downloading the MUSDB18 archive again within the 8,000,000,000-byte download and 30,000,000,000-byte storage ceilings, and deleting it after the mixtures are extracted.
