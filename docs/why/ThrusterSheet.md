The reasoning behind `tkg/scripts/sim/ThrusterSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Thruster sheet

Above `const PLAYER := ["hull_light_s", "hull_medium_c", "hull_medium_s", "hull_heavy_s"]`:

```text
THE CODED ENGINE FLAME BESIDE TODAY'S, for Jon to pick a look (Oct 13).
  godot --path . --windowed --position 3840,0 -- sheet=ThrusterSheet out=<dir>
      [ships=hull_light_s,...,ship_armedtrader,...] [frames=150]
One film per ship, at the game's own pixel size (1x), each frame a grid:
columns TODAY | A OVERLOAD | B DRIVE | C SPILL (ThrusterFx.Look), rows IDLE,
CRUISE, FULL (ThrusterFx.Thrust). TODAY on a player hull is what the game
shows: no flame at idle (the engines are off in a fight -- ShipView `_burning`)
and the rigged PixelLab strips at cruise and full (the chassis select, the
arrival and departure), composited the way ShipView does it: `back` strips,
then the hull, then the rest, the strip frame at FLAME_HZ. TODAY on a pool
ship is no flame at all; they have none.

Drawn into a SubViewport as big as the grid, so a heavy's four columns fit
at 1x. Every clock is the film's, stepped 1/30 s a frame: f_####.png at 30
fps is true speed. No bob, so the flicker measures the flame alone.
Each folder gets layout.json: every tile's rect, and per coded look its
nozzles, its lengths, the ms to build its pictures, and the CPU a frame its
`draw` costs (measured round the calls, per ship).
```

## Nozzle check

Above `func _opening(img: Image, pts: PackedVector2Array) -> int:`:

```text
THE NOZZLE CHECK (Jon, Oct 13: the coded flame must leave from where the
PixelLab flame leaves). Measured on what each draws, not on the rig:
  today  each strip's VISIBLE start -- per frame, the last column holding a
         strip pixel that shows (a `back` strip's pixels under the hull do
         not); the most common one over the frames; the rows showing there in
         at least half of them.
  coded  each look's flame picture at every thrust: its last lit column and
         the rows lit there.
FAIL when the column is more than 1 px off, or the flame's START HEIGHT is
more than 1 px off its nozzle's mouth read off the hull (or the strip's
height 2-6 px out, on a flat stern): "a bit bigger than the nozzle" (Jon on
light A and heavy A) is what the strip-height rule did to real nozzles. The row span used to have to match
the strip's start rows, which are its narrowest, and every blunt stern got
a thin stream out of a big engine (Jon, Oct 13: "too small on the main body").
Also counts flame pixels on a hull pixel the strip leaves visible (one it
does not cover in every frame); that must be 0 (heavy S's dome).
A NOZZLE'S OPENING, read off the hull alone: the rows round the nozzle's
middle whose stern edge (the first hull pixel, from well behind it) is within
1 px of that row's, less the outline rows at either end -- a row whose 4 px
from the edge into the hull are all dark (lightness under 0.15) is the
nozzle's rim drawn as a line, not its opening.
```

Inside `_check_starts()`, above `var sx := -(1 << 20)`:

```text
THE FIRST COLUMN against the opening: how many rows are lit
in the flame's own first two columns (its start column and
the next), which must not be more than the nozzle's opening
inside its outline (Jon on light B's top pipe: "still
slightly bigger than nozzle")
```

Inside `_check_starts()`, above `var rim_x := 1 << 20`:

```text
Only a hull with a bell: a strip that laps the hull's edge by a pixel
covers a few hull pixels the stream is not meant to fill.
And at IDLE (Jon: "The flame should extend slightly out of the ship ...
that little depression is the entire exhaust"): the bell at least 90% lit
and the flame at least 8 px past the rim, at the idle length and at the
shortest its flicker takes it to.
```

Inside `_check_starts()`, above `var fx9: ThrusterFx = looks[0].fx`:

```text
THE MAIN DRIVE IS NOT OUTBURNED (Jon on light B: the main flame read
"short and stubby" beside the top pipe's): the hull's main drive (its
biggest strip) is never shorter at full burn than a secondary engine, and
of two engines in the same role the bigger mouth is never the shorter.
```

Inside `_check_starts()`, above `var same_role := bool(a9.get("main", false)) == bool(b9.get("main", false))`:

```text
mouths are compared within a role: the rig names the main drive (its
biggest strip), and light B's main nozzle reads 6 rows against its
top pipe's 9 (the pipe's two outline rows count as mouth) while Jon
wants the main drive the longer flame
```
