The reasoning behind `tkg/scripts/sim/OutcomeShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Outcome shots

Above `var _args: PackedStringArray`:

```text
WHAT YOU END UP WITH, photographed in every look (`OutcomeRow`):
  godot --path . -- sheet=OutcomeShot out=<dir> [cases=jon,gain,...] [looks=today,A,B,C,D,E]
      [layout=row|column|card]   (the band's layout; Jon's column when left out)
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
      -- sheet=OutcomeShot out=<dir> film=C case=mix
  godot --headless --path . -- sheet=OutcomeShot survey

REAL OUTCOMES, FOUND NOT MADE UP. Every authored choice is resolved through
`OptionResolve.take` -- the one rule -- on a fresh copy of one system from
the same starting ship, over a few seeds of the event stream, and each case
takes the first that does what it asks:
  jon      the Drifting Lifepod cracked open and its trap fired: hull only
  gain     credits and a part, nothing lost
  mix      credits up, fuel down, heat up
  card     a part alone: the only way an event offers a card is a part's
  nothing  a choice taken that moved nothing
  credits  credits and nothing else
  big      the outcome that moved the most
  data     a science reading: DATA up, the fuel it burned down
Then each is played on the real LOCAL: the event asked for as the map's GO
asks (`LocalEventDrawer.request`), the band up, the choice taken, and the
result drawn in every look, stills of the whole 1920x1080 window
(`<look>_<case>.png`) and the band cut out of it at that 2x
(`<look>_<case>_band.png`); C also mid-flight (`C_<case>_fly.png`). Writes
`index.json`: each still, its case, the option and choice and seed, the
entries as drawn with their boxes, and the band's.

`survey` prints every kind of change the authored choices make, and how
often, headless.
`film=C case=<id>` films that case under C at true speed: the band up, the
choice, the text arriving, the flights, then a second and a half. Prints
`mark <name> <frame>`.
Needs a window but for `survey`.
```
