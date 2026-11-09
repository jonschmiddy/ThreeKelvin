The reasoning behind `tkg/scripts/sim/GalaxyDump.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Dump outputs

Above `var out := "user://galaxydump"`:

```text
Every galaxy kind as data, for mocking up a new rendering of the star chart:
  godot --path . -- sheet=GalaxyDump out=<dir> [kinds=0,3,8]
  godot --path . -- sheet=GalaxyDump out=<dir> pulls   (systems at three arm pulls)

For seed 4242 and each kind GalaxyGen can roll (forced the way ChartShot's
`kind=N` does it: roll the kind, regenerate the map), writes
  <dir>/kind_NN.json  the rolled parameters, the chart's own star field
                      (`_star_pos`/`_star_col`/`_star_big`, in galaxy units
                      where 1.0 is the disc radius, the space MapNode.gal
                      speaks), the turning core's particles, the clouds, the
                      systems with their colours and whether the chart shows
                      them, the ship and its two rings;
  <dir>/kind_NN_full.png  the chart's rect at the default view (zoom 0.42,
                      pan zero), systems drawn;
  <dir>/kind_NN_sky.png   the same with the systems hidden;
  <dir>/kind_NN_core_max.png  the core at the chart's closest zoom (6.0),
                      systems hidden.
Needs a window; input is switched off while it runs.
```

Above `func _nebulae() -> void:`:

```text
`nebulae`: where the clouds sit, RIDGE against FIT (`NebulaField.placement`),
every kind forced onto the pinned seeds (90210 + i, `rolls=`, 120), plus
maptest's natural 120 (skip with `nonatural`). Per kind and placement: each
cloud's share inside the arm band (`NebulaField.arm_share`; mean, lowest, and
how many clouds have under half) -- the cloud put over the core is left out,
it sits in the bulge on purpose -- pulsars per galaxy, and unflyable / mean
jumps (maptest's rule). Writes <dir>/nebulae.json. Runs headless.
```

Above `func _spread() -> void:`:

```text
`spread`: the arm pull (PULL, 0.9 / 3.0) against SPREAD (`MapGen.placement`),
every kind forced onto the same pinned seeds (90210 + i, `rolls=`, 120), plus
maptest's own natural 120. Per kind and placement: unflyable count and mean
jumps to the core (maptest's rule), each system's nearest neighbour on the
chart in ring gaps (min, 5th percentile, median, share under 0.3 -- the
piles), the share of systems on an arm against the share of the ring that is
arm, and the largest hole in the arms (the farthest a point within an arm's
half-width of its ridge sits from any system, in ring gaps). `floor=` / `gap=` / `width=` set SPREAD's `arm_floor` /
`spread_gap` / `arm_width` (here and for the pictures), and
`only=after` skips the PULL pass, `nonatural` maptest's natural 120. Writes <dir>/spread.json. Runs headless.
```

## Pinned seeds

Inside `_pulls()`, above `var fails := 0`:

```text
flyability, as maptest asks it: its rolls, its rule
The same 120 galaxies for every setting. maptest's own `Rng.reseed`
does not pin them: `start_new_run` rolls a fresh master seed unless
`Rng.forced` is set, so its rolls differ run to run.
```
