# Third Preview Qualification Procedure

## Purpose and Lock

October 12, 2026. This procedure defines the third unseen English evaluation for the public preview, after the [second qualification](second-preview-qualification-results.md), and applies the [revised criteria](revised-preview-criteria.md). It is committed before the evaluation data is obtained. The evaluated system is `ilyrics` built from commit `e0ab92a`, which renames the project and keeps the version 3 vocal rules and twenty-minute support, run with default CPU inference as `ilyrics align AUDIO LYRICS -o OUT.ttml --report OUT.json`. Nothing in the pipeline, its options, or the criteria may change after the first recording is processed, and each recording is processed once. The maintainer decided that this evaluation concludes the preview qualification: its result, whether passed or narrowly failed, is the basis for the preview decision.

## Evaluation Set

[JamendoLyrics++](https://github.com/tikick/JamendoLyricspp) (Kick, Grötschla, Lanzendörfer, and Wattenhofer, NeurIPS 2024 workshop) adds 80 Jamendo recordings with manual word timing to JamendoLyrics. None of its file names or source URLs occurs in the JamendoLyrics set used before, and none has been processed by iLyrics. The repository states no license; its recordings come from Jamendo under Creative Commons licenses. The data is used for local evaluation only and is not redistributed. Its recordings are not known to be part of the separator's or the recognizer's training data.

## Inputs and Reference

The dataset's lyrics file of each recording is the input text, with parenthesis characters removed so that every line remains one aligned line, as in the earlier procedures. Each reference line interval runs from the start of its first annotated word to the end of its last, following the dataset's word annotations and line ends. Lines are vocable-only when every word matches the command's vocable pattern. *Clarification recorded after the data was obtained and before any recording was processed:* the word annotations have no line-end column; their word count equals the whitespace-separated words of every lyrics file, so each lyric line takes its words in order, and lines without letters are skipped as the command skips them. No lyrics file contains parentheses or section labels.

## Measures and Criteria

A line's status is taken from the report: aligned, or unresolved (placed or omitted). Vocable-only lines are excluded from the scored lines and reported separately. Over all scored lines pooled:

- **placement accuracy**, the share of lines aligned with an interval that overlaps the reference line interval, at least 95%;
- **wrong placement**, aligned lines without overlap, at most 2%;
- **unresolved rate** at most 5%;
- **word containment**, the share of words of aligned scored lines whose estimated midpoint lies within their reference line interval extended by 0.5 seconds on each side, at least 95%;
- no recording below 80% placement; and
- run time at most twice the recording duration.

Line onset and offset errors and word onset errors (median, 95th percentile, and share above 500 ms) are reported as diagnostics, together with per-recording results.

## Resources

On October 12, 2026, the maintainer approved downloading JamendoLyrics++ (about 0.4 GB) and raising the cumulative download ceiling to 13,000,000,000 bytes. The previous ceiling of 8,000,000,000 bytes had been exceeded: the MUSDB18 archive was downloaded twice, bringing the cumulative transfer to about 11.6 GB, which this approval ratifies. Before the download, regenerable outputs and superseded experiment material were deleted with the maintainer's approval, reducing evaluation storage from 21.8 GB to 14.8 GB.
