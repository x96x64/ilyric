# Visual Qualification Plan

## Status

October 12, 2026. **Draft for the maintainer's review**; nothing in this plan has been run. It proposes how Stage 3 of the [roadmap](../roadmap-to-stable.md) qualifies the visual preset against the native Music Lyrics screen on the reference iPhone 16, reported iOS 27.0.1, exact build Unknown. Thresholds become binding only after the maintainer approves them and before any held-out capture is analysed.

## Held-Out Captures

The seventeen private screen recordings and the screenshots in `reference-private/` were all used to fit the current parameters, so they cannot qualify them. Qualification needs new captures, recorded by the maintainer on the reference device with the settings in the private reference notes:

- at least six screen recordings of complete songs with time-synced lyrics, covering one-line and multi-line paragraphs, background vocals, at least one instrumental gap, an overflowing title, and playback started from the beginning without interaction;
- the matching audio files, so that iLyrics can render the same songs with timing derived from the native screen;
- three screenshots each of the playing and paused states.

Captures remain private under `reference-private/`; only sanitized numbers are published.

## Method

For each held-out song, the native line and word timing is read from the capture itself (the moment each line takes focus and each word crosses half brightness), so that synchronization accuracy does not enter the visual comparison. iLyrics renders the song from that timing at the native canvas size, and the two videos are compared property by property with the existing measurement tools in `scripts/reference_validation/`, registered by the progress bar clock described in [Reference Clock Correction and Word Motion](reference-clock-and-word-motion.md).

## Properties and Proposed Thresholds

The proposed thresholds are about twice the residuals measured during development, so that a property fails only when the reconstruction is clearly worse on unseen material.

| Property | Measure | Development residual | Proposed threshold |
| --- | --- | --- | --- |
| Typography | Line ink width and wrapping per line | ±3 native px, wrapping exact | ±6 px; wrapping identical for every line |
| Focus motion | Scroll onset relative to focus change; 50% and 90% displacement times | 0.090-s time constant within 0.022 RMS | onset median within ±0.15 s; 50% and 90% times within ±0.05 s |
| Word fill | Half-brightness crossing of each word relative to native | median 0.05 s after native onset alignment | median within ±0.10 s; 90% of words within ±0.25 s |
| Controls | Symbol ink centres; auto-hide time | within 2 native px; 3.79 s | within 3 px; within ±0.2 s |
| Title marquee | Start delay, period, displacement | 0.54-px RMS over two cycles | delay and period within 5%; displacement RMS ≤ 2 px |
| Gap indicator | Appearance and exit times | about 0.4 s in, 0.15 s out | within ±0.1 s |
| Background | Mean colour and luminance spread over the frame | fitted on one paused and several playing captures | mean ΔE₀₀ ≤ 6; luminance standard deviation within 20% |
| Inactive lines | Blur and contrast diagnostics of non-focused lines | held-out improvement on V01–V03 | not worse than the development held-out errors |

Each property is reported per song and pooled. The preset qualifies when every property meets its threshold on the pooled measure and no song fails more than one property.

## Limitations

The reference is one device, one iOS version, and one set of accessibility settings; dark appearance, other text sizes, and other devices are outside the qualification. The thresholds are engineering choices, not perceptual measurements, and the maintainer may tighten or relax them before approval.
