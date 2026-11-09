The reasoning behind `tkg/scripts/ui/BoardCommercial.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Animated commercials

Above `const LENGTH := 6.0`:

```text
LITTLE ANIMATED COMMERCIALS for the marketplace screen's ad slot (Jon: "Maybe
even a little animated commercial ad?"). Every third turn of the slot plays
one of these in place of a still ad: a few seconds of a scene, the words
arriving on cue, and a video's progress bar along its foot.

Each is drawn in the slot's box, (0, 0) to `sz` (about 107x170), at `t`
seconds into it, 0 to LENGTH. Everything lands on whole pixels, so nothing
smears; the Silkscreen font only at 8 and 16, about 6 and 12 pixels a letter.
```
