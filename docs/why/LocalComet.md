The reasoning behind `tkg/scripts/ui/LocalComet.gd`; each heading is referenced from the code by a `Why:` line.

## On the band

Above `extends Node2D`:

```text
LOCAL lays the system's worlds out on its band from where the map has them
(`LocalSky._step_worlds`). The comet goes on the band the same way, so it is
in the sky where it truly is: "it must make sense where it stands". It is drawn
as the map draws it (`SkyWeather.Comet`): a white head and coma, a straight
blue ion tail and a curved warm dust tail, in 2x2 blocks on the sky's grid.

It is held at the clock LOCAL holds (`LocalSky._tm`). The map's clock does not
run while LOCAL is up (PairLocalTest), so a comet that moved on in LOCAL would
jump back on the map. The worlds' slow drift on the band hides that; a comet
crossing the system in about a minute would not.

The band draws the whole system smaller than the map does (`_s`), and it is
flat (TILT 0.07), so the map's tail lengths left specks. The ion tail is
held to at least ION_MIN blocks.

The comet up close (a nucleus with LocalFx's lit tails, as `the_comet` draws
one) belongs to Phase 13's catch, when the ship waits on its path and it goes
by. That is part 5 of the build.
```

## Dust on the band

Above `var trail := ...` in `_draw`:

```text
The map draws the dust tail where the dust it shed is now (its past places,
pushed off the light). On LOCAL's flat band the comet's past places lie behind
its motion, which near the star is back toward the star, so that tail pointed
at the sun (the first render, Nov 9). The band draws the classic shape instead:
out along the away line, bending (DUST_BEND, px per block squared) to the side
the comet trails from, warm, and widening past its first third.
```
