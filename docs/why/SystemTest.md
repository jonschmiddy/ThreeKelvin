The reasoning behind `tkg/scripts/sim/SystemTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## System test promises

Above `const SEEDS := [4242, 7, 1999, 31337]`:

```text
Does the system map's layout keep its promises?
  godot --headless --path . -- systemtest

A GATE. `SystemLayout` is derived and never saved, so everything it gets
wrong is wrong silently: an option with no body is an encounter nobody can
click, an unstable layout is a planet that moves between a save and a load
(or sits in two places for two players), and an orbit run through a body is a
planet drawn on top of another. The five promises:

**Every option is on exactly one body** (or on the star itself, an event
sited there at a red or blue star), a station has its DOCK and the core its
custodian.
**Stable**: the same node lays out the same way twice in one run, and the same
seed lays out the same way in a fresh run.
**A gas giant if and only if the node has one** (never round a pulsar), and
every giant weighs 1/10 to 1/4 of its star (ruling 20) with its ring and dent
where they were.
**Orbits never cross a body**: neighbouring orbits are further apart than the
two bodies on them are wide.
**No shared stream is touched**: laying out a system draws only from
`Rng.derive`, so looking at the map cannot move what the run rolls next.
**One event to a world** (Jon, Oct 15: "A planet should only hold one event.
That should be a rule."): no planet, giant or star holds two options.
**The Hellbender has a place of its own** where it is anchored, last, past
every orbit, and every other body is where it would be without it.

AND TWO SUNS (ruling 20, Oct 30), about one ordinary system in four, and every
one of them under `twin=all`: a world round each star, inside the farthest
steady orbit round it (Holman and Wiegert); everything else round both, past
the nearest steady orbit round the pair (theirs, for the pair's own shares);
neighbours apart round each centre, not by index; each world round a star
with its ring clear of its star's close ring, of both stars' keep-clear and
of every ring it can meet; every ring round both clear of both stars' close
rings; each star's keep-clear the autopilot's keep-out at the zoom the layout
is fitted to, its close orbit and ring outside it, and that zoom never above
the one the map opens at; each world round a star standing 3 game px clear of
its sun's drawn disc beside it at the opening zoom, as SystemView draws both
in 2 px blocks; zones by distance from the light; Kepler round what each body
circles. Round both, as round one sun, the bodies are kept apart and not their
rings: how often a body sits inside a world's ring is printed, not promised.
THE TWO KINDS (Jon, Nov 1, "Binary kinds: close:B share:A"): a close pair at
about one binary in three, the rest wide (all the above is a wide pair's); a
close pair's own promises are `_close_checks`.
A SIGNED JOB AND THE HELLBENDER (`_comers`), put in every twin: they move no
other body and none of the stars' rings or keep-outs, and how far they push
the opening zoom past the layout's is measured against the drawn suns.
THE PAIR TURNS (ruling 23, Jon, Nov 1, "Orbiting pair: speed:A"; `_turn`):
at four times Kepler round the balance point, the worlds round one sun four
times Kepler round it (their own Kepler promise above is Kepler x 4) and
carried with it; every place a pure function of the layout and the map's
time, so two machines and a save and a load at the same t put it in the same
place; the rest pose (t 0) exactly the layout as laid out; the turn rigid at
eight angles round a lap (the suns `sep` apart about a still balance point,
each world round one sun its orbit from it, the edge past everything);
`MapGravity` reading the suns where the layout has them; and reduced motion
moving nothing. One sun is still at every t, every body exactly where the
old formula put it.
```

## Stations

Inside `run()`, above `var st_bodies := L.bodies.filter(func(b): return b.kind == &"station").size()`:

```text
ONE STATION TO A STATION SYSTEM AND NONE ELSEWHERE (Jon, Nov 3:
"two stations next to each other should never happen"), after
`MapGen._place_stations` turned some back into systems and moved others
```

## Pair speed

Inside `_turn_report()`, above `var asked := false`:

```text
THE RULED SPEED ITSELF (ruling 23, "speed:A"): four times Kepler, a wide
pair's lap 19 to 25 minutes and a close pair's 6 to 7 (the ruling's
rounding of 6.1 to 7.4: close pairs lie 150 to 170 px apart). Every rate
check above is against `pair_speed()`, which reads PAIR_K, so a changed
PAIR_K passed them all, and 0 skipped them (review 2). Only a harness's
`pair=` on the command line may ask for another speed
(THE WORLDS' PACE, Nov 5: the pair turns `SystemLayout.WORLD_PACE` times
faster again, so its laps are those minutes over it; `worldpace=` on the
command line asks for another)
```

## Comers

Above `func _comers(n: MapGen.MapNode, at: String) -> void:`:

```text
A SIGNED JOB AND THE HELLBENDER OUT PAST A TWIN'S EDGE (`Contracts.post_goal`
appends a job's event to the node; the Hellbender anchors or dies here): a
fetch's world, a hunt's contact and the Hellbender, alone and together. They
move no other body, and none of the stars' keep-outs, close orbits or rings
or the zoom the layout is fitted to, so a planned flight's keep-out is the
layout's whatever comes (`SystemLayout.keep_clear_of`). They do push the
edge out, and the map opens further out than the layout was fitted to while
one is there: how far the drawn suns then reach past the stars' rings and
toward the worlds is measured, not promised, since fitting to that zoom
cannot be had (`SystemLayout._twin`). First measured Oct 30 over the four
seeds' 1,068 twins: a hunt or the Hellbender alone left every star's ring 4.2
plane px outside its drawn sun and every world 1.9 game px off its sun; a
fetch's world, 3 of 2,136 rings up to 0.2 px inside and 3 worlds touching;
all three, 34 rings up to 2.3 px inside and worlds up to 1.1 game px over.
Over 24 seeds' 5,014 twins: a fetch, 22 of 10,028 rings up to 0.4 px inside
and 13 worlds up to 0.4 game px over; all three, 184 and 550, 2.5 and 1.2.
Leaves the node and the run as they were.
```

## Opening zoom

Inside `_twin_checks()`, above `var z := SystemLayout.open_zoom(L.edge)`:

```text
AT THE OPENING ZOOM, with no job or Hellbender out (`_comers` puts them in):
the map opens no further out than the layout was fitted to, each star's
close orbit is outside the keep-out there, and each world round a star
stands 3 game px clear of its sun's drawn disc beside it, both as drawn in 2
px blocks. At its near point, in front of the sun, it cannot -- the edge is
too far out for the zone it is in (`SystemLayout._twin`) -- so that is
measured, not promised.
```

## Close pair

Above `func _close_checks(n: MapGen.MapNode, L: SystemLayout, at: String) -> void:`:

```text
THE CLOSE PAIR'S PROMISES (Jon, Nov 1, "Binary kinds: close:B"), on one
close pair: its suns 150 to 170 px apart; every body round both, at the
balance point, past the first steady orbit round the pair; neighbours apart;
Kepler round both; each sun's keep-clear, close orbit and ring in order and
outside the autopilot's keep-out at the zoom the layout is fitted to; the two
suns' keep-outs apart, each sun's close orbit outside the other's keep-out,
and their capture rings apart; every world's ring RING_GAP clear of both
suns' close rings, every other body RING_CLEAR; the map opening no further
out than it was fitted to; zones by light. Counted: how many have a planet in
the middle band, what the first body is, and how often a body sits inside a
world's ring (as round one sun, printed, not promised).
```

## Comet pace

Above `func _comet_pace() -> void:`:

```text
COMETS KEEP TODAY'S SPEED (Jon, Nov 5: "I think the comet speed is perfect
though"): `SystemLayout.WORLD_PACE` turns the worlds and the pair faster and
nothing else. A comet's path is planned from the inner orbit's radius (which
the pace does not move) and aged by each frame's own time (`SkyWeather`'s
`ev.age += dt`), never by a body's period: at WORLD_PACE 1 and 4, in every
SYSTEM node of the last seed, the radii are the same and a comet planned off
them is at the very same place round its sun at every age of its 80 s.
```

## Where a science reading sits

Above `func _science_sites(n: MapGen.MapNode, L: SystemLayout, at: String) -> void:`:

```text
WHERE A SCIENCE READING SITS. A barren reading's text says the world has no
air, so its planet's world is one of `SystemLayout.DRY` for its zone (round a
pulsar, `DRY_PULSAR`) and the map's ATMOS for it reads NONE or FROZEN OUT. A
belt reading sits on the belt. And the override is all it does: the same
system laid out with an ordinary option in the reading's place (one that
wants a planet for a barren reading, a hazard for a belt one) is the same
layout, but for the barren world itself, so R drew exactly what it drew.
```
