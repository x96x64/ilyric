# Demonstration Lyrics

`lyrics.txt` is the text of "The Star" by Jane Taylor, first published in *Rhymes for the Nursery* (1806) and sung as "Twinkle, Twinkle, Little Star". The text is in the public domain. It is the input of the `DocumentationMedia` target, which renders `docs/media/demo.png` with synthetic, evenly spaced word timing and silent audio:

```bash
swift run DocumentationMedia fixtures/demo/lyrics.txt docs/media/demo.png
```
