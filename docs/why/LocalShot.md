The reasoning behind `tkg/scripts/sim/LocalShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Local shot

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
LOCAL, photographed: the side-on view (`SectorScreen`, `EncounterView`) in a
system of a chosen sky, quiet or mid-fight, in the style on the command line.

  godot --path . --windowed --position 3840,0 -- sheet=LocalShot keepwindow
      [style=simplified|painted|radiant] [graphics=low] [seed=N]
      [sky=emission|reflection|planetary|remnant|dark|calm|pulsar|core] [node=I]
      [combat [fire]] [approach] [wait=F] [out=<png>] [skyout=<png>]
      [clip=<dir> clipframes=61 clipms=33 cliph=297] [stats=<json>] [bare=<png>] [reduced]
      [orbit=giant|world|star|edge|belt|derelict] [dustcheck] [nodust] [clipfull] [dustonly]

`out=` is the whole screen, `skyout=` the backdrop alone (its own picture,
one pixel a block), `clip=` that picture frame after frame for the flicker
measure (`frames.py`), `stats=` how readable the ships and labels are
against the backdrop right round them (`_readable`), and how bright the play
(game y 140 to 330) and the band above it are.
`orbit=` puts the ship where the sector map would have left it
(`SystemMapScreen._parked`): in orbit of a ringed giant (or any giant), of a
world, of the star close in, alongside a belt or a wreck, or free at the
system's edge; `giant` looks for a system of the sky with a ringed giant.
TWO SUNS (ruling 20, Oct 30): `twin` looks for a two-sun system of the sky
(with `-- twin=all` every ordinary one is), and `orbit=` also takes `starb`
(star B's close orbit, place -4), `worlda` and `worldb` (the world circling
star A or star B).
`dustcheck` (with `combat fire`): a fight's frames, each taken with the
foreground dust and again without it, and what the dust covered of the ships'
pictures and of every label and gauge printed -- the worst frame's share.
`nodust` turns the dust off; `clipfull` films the whole view, ships and all;
`dustonly` films the dust alone over the view's plain wash. `fightat=N`
opens a fight on the clip's Nth frame (with `clipfull`, the screen change
from LOCAL into it is filmed).
Needs a window.
```

## Readability stats

Above `const RING := 6`:

```text
HOW READABLE the ships and labels are against what is right behind them:
for each, its own pixels (where the whole picture differs from the bare
backdrop) against the backdrop in a band RING px wide round its OUTLINE (not
its box: the sky the eye sets its edge against) -- the difference of their
mean OKLab lightness (`dL`), and how busy the backdrop in that band is
(`busy`: the spread of its fine detail, each pixel's lightness against the
5x5 round it -- a smooth fall of light is not busy, a field of specks is).
The worst of each, and each ship's own. REPORTED, NOT A GATE: it counts
lightness alone, so a blue-grey hull on pink gas of the same lightness
scores near 0 and reads plainly; Jon judges by eye.
```
