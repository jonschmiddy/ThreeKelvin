The reasoning behind `tkg/scripts/systems/MapGravity.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pull and keep-outs

Above `const STAR_MARGIN := 6.0`:

```text
WHAT PULLS A SHIP IN A SYSTEM, on map time, and what its autopilot must keep
out of (ruling 20, Oct 30: "Prototype: twin:A giant:A"). Pure data: no Nodes,
no textures, nothing changed after it is built, so one can be shared by a
`FlightSolve` on a `WorkerThreadPool` task.

THE PULL. One star holds still at the origin. TWO TURN (ruling 23, Jon, Nov
1, "Orbiting pair"): both circle the pair's balance point at the layout's
`pair_n` (`SystemLayout.spin_pair`, four times Kepler), each where
`SystemLayout.star_pos` has it at map time t (`sx`, `sz`), and every world
round one of them is carried with it (`wo_hs`, `pl_hs`). Together they pull
with `SystemLayout.GM_SHIP` in every system, star A with `star_share` of it.
A giant pulls with its own `Body.gm` (gm_frac of GM_SHIP) and moves on its
circle while the ship flies, exactly (`orbit`, `period`, `phase` about its
centre). Worlds, stations and belts pull nothing. Flying by hand never reads this (Jon, Oct 3: the sun's pull made
flying "clumsy and awkward").

THE KEEP-OUT, in plane px from each centre:
- a star: the larger of `L.keep_clear_of(p)` and the sun's drawn radius at
  the zoom the layout is fitted to, plus STAR_MARGIN 6 (`keep_out_star`);
- a giant: its drawn radius r + GIANT_MARGIN 3;
- every other world (planets): its disc, r + WORLD_MARGIN 8, as
  `ShipFlight._clean` keeps them. They pull nothing; they are only in the way.
  (A flight's own departure and target world keep less: `FlightSolve`.)

Positions and pulls are 64-bit scalars throughout (GDScript's float):
Vector2 and Vector3 are 32-bit in Godot 4, too coarse for the finite
differences the planner takes.

Built from a layout with `from_layout`, or by hand for a harness with
`add_star`, `add_giant`, `add_world` and `add_place`.
```

## Keep-out zoom

Above `static func keep_zoom(L: SystemLayout) -> float:`:

```text
THE ZOOM A STAR'S KEEP-OUT IS MEASURED AT: the layout's own `fit_zoom` (the
opening zoom with no signed job and no Hellbender out) where the layout has
one, else the opening zoom. A job or the Hellbender out past the edge opens
the map further out and draws the suns wider, but moves no ring: measured
there, the keep-out grew past a twin star's close orbit in 44 of 1,710 stars
with the Hellbender in, by up to 3.9 px, so nothing could fly to or from it
(planner review, Oct 30). So it is the layout's, and a sun drawn wider while
one is out may be crossed by up to that much.
```

## Star keep-out

Above `static func keep_out_star(L: SystemLayout, p: int) -> float:`:

```text
A STAR'S KEEP-OUT, plane px from its centre: the larger of the layout's
keep-clear and the sun as drawn at `keep_zoom` plus STAR_MARGIN. Drawn
(`SystemView._star_k_raw`): a sun at sqrt((r z)^2 + 10^2) screen
px, eased up to its floor; the black hole at r max(z, 1); a pulsar at 4/3 r
(`PULSAR_OPEN_K` at the zoom it opens at). Screen px over the zoom is plane
px across the map (the slant only shortens it top to bottom). A one-star
sun of r 16 in a system of edge 930 opens at z 0.345: drawn 11.4 screen px,
33.1 plane px, 39.1 with the margin, under its keep-clear 48. A twin's
keep-clear is this already (the layout's `_twin_ladder`), so there the two
agree exactly: its close orbit (`star_rail_of`) is 2 px outside it.
THE BLACK HOLE keeps a flight out of its lens, not its disc: STAR_MARGIN
inside its close orbit (`star_rail_of`, 150, set there because "the black
hole's lens reaches far past its disc"), 144. Kept to its disc as drawn
(52 px) the solved flights dove across the shadow and the lens -- 33 of 252
of the core's flights from the game's starts inside 150 px, 8 under 70,
where today's planner never came inside 161 (the one-sun review, Oct 31) --
and the Custodian's ENGAGE flies there in every won run.
```
