The reasoning behind `tkg/scripts/sim/SubjectShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Subject photography

Above `var _args: PackedStringArray`:

```text
AN ENCOUNTER'S SUBJECT ON LOCAL, photographed (`LocalSubject`):
  godot --path . --windowed --position 3840,0 -- sheet=SubjectShot keepwindow
      subject=<id>[,<id>...]|all out=<dir> [style=...] [seed=N] [wait=90] [noband] [wrecks=N]
For each encounter asked for (`all`: every one that carries a `subject`), a run
at a system holding just that option, LOCAL opened with the event up as the map
sends you there, and the game's picture saved as `<dir>/<id>.png` once the
scene has settled. `noband` drops the event's band (NOT NOW) before the shot,
so the subject is seen as it is while you are parked at it. Prints each
subject's pieces and where they landed. `wrecks=N` leaves N dead hulls in the
system first, as a fight there would, to see the subject keep clear of them.
`clip=<dir> [clipframes=300]`: then films the scene, your ship hidden, for
`frames.py` -- one subfolder per encounter, `f_####.png` of LOCAL's view at
the game's own 960x540, the subject's clock (`ShipView.shot_clock`) stepped
1/30 s a frame; run it with `--fixed-fps 30` so the sky steps the same. Each
folder gets `crop.json`, the subject's drawn box in those frames (grown by
the drift and the tumble), to measure the subject alone. `subjectonly` hides
everything else in the view, the sky too; `keepship` keeps your ship in (a
clamp that grips it); `clipstart=S` starts the clock at S s (default 20).
`atplace`: the system given the sky
the option's gates ask for and the ship parked where the option sits (the
giant, the star's close orbit), as the map's GO leaves it. `take=N`: where
the encounter keeps more than one take of its thing (`pick`), draw take N
(from 0) instead of the system's own pick, to photograph each.
Needs a window.
```
