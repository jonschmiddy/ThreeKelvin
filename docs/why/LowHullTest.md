The reasoning behind `tkg/scripts/sim/LowHullTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Low hull test scope

Above `var _tree: SceneTree`:

```text
THE HULL FAILING (`LowHull`, `low_hull.gdshader`, `HullScramble`,
`low_hull_mask.gdshader`, `VoiceGlitch`), headless:
  godot --headless --path . --fixed-fps 60 -- sheet=LowHullTest
From a run under way, animated (`Router.animate_in_harness`):
  * the state: off at half the hull; on at TIER1_AT exactly and stepping up
    at TIER2_AT; easing in over EASE_S (part way at half of it, whole after
    it) and out the same way when the hull is repaired; off at 0 hull, on the
    title and with no run;
  * every place a run is played: LOCAL, the sector map, the star chart, a
    fight, the station -- scrambling at each;
  * the red breathes, and never past its preset's edge;
  * THE WORDS: none above the line; at 30, 20, 10, 5 and 1% of the hull the
    scramble rises (runs started, letters scrambled at once), under its
    ceiling, a small share of the letters on screen even at 5%; the hull
    readout among the texts that scramble;
  * NOTHING MOVES: every text control's rect and minimum size, and every
    control that takes the mouse, unchanged on every frame of all of it (the
    screen's own movement measured first, with the hull sound, and not
    counted), and the glass ignores the mouse;
  * NOTHING IS REWRITTEN: every text read while it scrambles is its real
    text, and after a repair nothing is left (no cell, no canvas item, no
    mask), every SignalText's noise cleared;
  * hand-drawn text (`LowHull.scr`): the string drawn is as wide as the real
    one to the pixel, its letters' places unchanged, and the real one kept;
  * a tooltip scrambles; the escape menu never, and nothing at all while it
    is open;
  * reduced motion: the red still and faint (REDUCED_RED), no scramble;
  * the cost: its frame time at 5% against with the hull sound;
  * her voice: every preset's plan inside her words, each window short
    enough not to cover a word, apart, under MOST_SHARE; glitches a second
    rising 30 -> 20 -> 10 -> 5%; a stutter or a chop first; rendered through
    Godot's decoder the take keeps its length to the sample, is untouched
    outside its windows, and starts and ends each window without a step; her
    portrait slips once for each glitch (none under reduced motion, where her
    voice keeps the subtle preset's glitches); baked on a worker.
No pixels are looked at (headless draws nothing): the films are
`-- sheet=LowHullFilm`'s.
```
