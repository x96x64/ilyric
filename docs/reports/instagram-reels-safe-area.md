# Instagram Reels Safe Area

## Outcome and Scope

October 14, 2026. **Instagram Reels crops 51 pixels from each side of a 1080 × 1920 video on an iPhone with a 1179 × 2556 display, which places iLyrics's lyrics and header within a few pixels of the screen edges; `ilyrics render --safe-area reels` now keeps every control and lyric line inside the visible width.** The crop was measured on one screenshot of a published reel in the maintainer's account. Instagram's own interface over the video, such as the header, the action buttons, and the caption, is outside the scope of this change; the maintainer chose to address the side crop only.

## Measurement

A frame of the published video was decoded from the source file and fitted to the screenshot by least squares over a region without Instagram interface elements, at the 8-bit gray level. The best fit scales the video by 1.204 and offsets it by −61 pixels horizontally and −2 pixels vertically on the 1179 × 2556 screenshot, with a residual of 10.8 gray levels. The background moves between the screenshot and the decoded frame, which accounts for most of the residual.

- **Height.** The video is scaled to the height of the player, which ends at the top of the bottom navigation bar: 1,920 video pixels occupy 2,312 screen pixels. Nothing is cropped vertically.
- **Width.** The scaled video is 1,300 screen pixels wide, so 61 screen pixels are cropped from each side: video columns 0–50 and 1,030–1,079 are not shown. The visible width is 979 of 1,080 video pixels.
- **Effect on the default layout.** The left edge of the lyrics and the header artwork fall about 4 screen pixels from the screen edge, and the More button about 40 pixels from the right edge.

The screenshot is the account owner's view of the reel; other viewers' interface differs below the video. The Instagram app version is Unknown. Devices with other display aspect ratios crop by different amounts.

## Implementation

`LyricsCanvas.reels` is a 1,304-pixel layout centered in the 1,440 × 2,560 frame of the existing video adaptation, with a 68-pixel inset on each side; 68 frame pixels are the 51 measured video pixels. The layout extends the native 1,179-pixel canvas by 125 pixels with the same anchors as `LyricsCanvas.video`, so wrapping, header clipping, and right-anchored controls follow the narrower width. `LyricsScreen.frameWidth` is the layout width plus both insets; the background, static or artwork-derived, fills the whole frame, and the renderer draws every other component translated by the inset. `--safe-area none`, the default, produces the established layout.

## Verification

Tests check the canvas constants, unchanged paragraph text and timing events, wrapping within the 1,112-pixel paragraph width, that every component and runtime symbol maps inside video columns 51–1,029, that the frame is fully covered, and that the side margins match the `.video` background. A song rendered with `--safe-area none` decoded to frames identical to the same song rendered by iLyrics 1.1.0 at four timestamps. A render with `--safe-area reels`, scaled and cropped as measured, keeps the header and lyrics at their native distance from the visible edges.

## Limitations

The inset rests on one screenshot from one device and one Instagram version. Other players, such as YouTube Shorts and TikTok, were not measured. Instagram's interface still covers parts of the header, the right side of the lower lyrics and controls, and the bottom of the video.
