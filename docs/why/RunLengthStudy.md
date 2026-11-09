The reasoning behind `tkg/scripts/sim/RunLengthStudy.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Run length study

Above `const TANK := 45`:

```text
THE SHORTEST WAY IN (balance/run-length, Oct 22):
  godot --headless --path . -- sheet=RunLengthStudy [seeds=12] [depthcap=N]
      [radrim=X raddeep=Y] [dump=<dir>]
(`depthcap=` is the game's two rings a jump unless given; 0 is no cap)

Kevin, the first outside playtester, reached the core in seven jumps. This
measures what the galaxy allows: for `seeds` galaxies of every kind
(`GalaxyGen.KINDS`), and each Korvan weight at grade C with its starter kit,
the fewest jumps from the start to the core under the rule the ship flies --
a star must be in the dish (`sense_radius_of`, the core always is) and in
reach (`reachable_from`) -- and then the same with the 45 tank: the fewest
jumps that fuel allows, with a dock stop (a full tank) at any station flown
through, and how many dock stops that takes.

A MEASUREMENT, never a gate; it passes either way. The study flags are
`RunState.study_*` and are off unless given here.

`dump=<dir>` writes one JSON a galaxy (the first seed of each kind) with
every system's place and its fewest jumps from the start, for drawing.
```
