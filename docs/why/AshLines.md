The reasoning behind `tkg/scripts/data/AshLines.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ash lines

Above `const MOMENTS: Dictionary = {`:

```text
A.S.H.'S LINES, the thirty Jon and Ashlee kept over two rounds (Oct 17), by the
moment each was written for. The source of truth is `docs/ash_lines.json` at
the repo root, outside the game's folder; this is that file as the game reads
it (plus `VOICE`, her recorded take of each), and `-- sheet=AshTest` fails if the two ever differ by a character. More
lines are more entries here and nothing else (`docs/ash.md`: "from a data
table, like the cards, so more lines never need code").

WHEN EACH MOMENT COMES (`Ash`, which decides):
  launch  a new run's first launch, on LOCAL once the ship has come to rest
  greed   one more wreck: the third wreck you open since you last docked,
          and every third after it
  haul    a big haul: a credit chit of HAUL_CREDITS or more, or an epic or
          better part, taken aboard
  hot     over the heat limit in a fight
  hull    moving to a new hull, the first time she is up in it
  hurt    hull failing: a quarter or less of the hull left, alive
  doubt   once in a long while, on arriving in a new system
```

## Ash voice

Above `const INTRO := &"launch_04"`:

```text
HER VOICE, line by line: Jon's picks of her warm voice (Oct 17: ElevenLabs,
voice W1_2, the subtle Cortana chain; trimmed to 30 ms before the first word
and 80 ms after the last, levelled to -18.3 LUFS). A line's id is its moment
and its place in that moment's list, from 1 (`id_of`); its file is
`VOICE_DIR` + the name here. A line with "" has no take and is said as text
alone (`AshPortrait.say`). A new take is its file and its entry here and
nothing else: the typing follows each file's own length.
HER INTRODUCTION (Jon, Oct 18, "intro:A"; every new run since Oct 20): a new
run's launch says this one, whatever the bag holds (`Ash.pick_line`); a run
picked up with CONTINUE does not, and every other launch line is the bag's,
this line among them. `Ash.gd`'s header has the rule.
```
