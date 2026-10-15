# Demonstration Lyrics

`timed-example.ttml` contains original English text and synthetic timing for the [local rendering example](../../docs/rendering-example.md). It is separate from the public-domain text used for the README image below. The local example uses generated tones, not singing, and makes no alignment-accuracy claim.

`lyrics.txt` is the text of "The Star" by Jane Taylor, first published in *Rhymes for the Nursery* (1806) and sung as "Twinkle, Twinkle, Little Star". The text is in the public domain. It is the input of the `DocumentationMedia` target, which renders `docs/media/demo.png` with synthetic, evenly spaced word timing and silent audio:

```bash
swift run DocumentationMedia fixtures/demo/lyrics.txt docs/media/demo.png
```
