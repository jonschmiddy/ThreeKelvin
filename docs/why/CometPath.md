The reasoning behind `tkg/scripts/systems/CometPath.gd`; each heading is referenced from the code by a `Why:` line.

## One pass

Above `class_name CometPath`:

```text
Phase 13's comet (Jon, Nov 9: "C", wait on its path, from the Comets brief in
tk-scratch/comets). A comet is a place you can see coming, not a world on a
circle. It makes ONE pass per visit: it comes in from the system's edge 5 to 15
s after the system's map first opens, swings past the star, and leaves at the
edge 60 to 80 s later. Then it is gone for good ("It comes back around in
ninety years"). One pass gives a reason to act now and keeps "events are taken
once" true without new rules.

It runs on the system's own map clock (`Run.map_t`), which starts at 0 the
first time the map opens and is kept when the map is put away, so a visit
later finds it where it was. The map clock is shared in co-op
(`Net.adopt_clock`), so every machine has it in the same place, which the
weather comet (on each machine's wall clock and its own rng) never was.

The pass is the weather comet's (`SkyWeather._p_comet`): the same parabola
(Barker's equation), the same perihelion against the inner orbit, the same 60
to 80 s. Jon on Nov 5: "I think the comet speed is perfect though". Where a
real comet is in the sky the weather comet stands down, so two never pass at
once.

It is not one of `SystemLayout.bodies`. Everything that walks the bodies (the
flight planner, MapGravity's keep-outs and pulls, the rings, the hit test, the
satellites list) assumes a circle, and the comet has no mass. Kept apart, no
existing flight, layout or test can see it. It has its own place id,
`SystemLayout.COMET` (-6).
```

## Own stream

Above `static func build(L: SystemLayout, n: MapGen.MapNode) -> CometPath:`:

```text
Every draw comes from `Rng.derive(&"comet", n.index)`, never the layout's own
stream R: one draw from R would move every world laid after it in every system
that has a comet, and the seed-pinned FlightTest, SolveTest and StationDeckTest
cases with them (science's first batch moved them that way). It is laid out
last, once `edge` is known, and changes nothing else. SystemTest's
`_comet_path` forces a comet into every system that may hold one and checks
that every layout prints the same as without it.

Where comes from: an option sited on a comet (`site = &"comet"`, Phase 13's
readings), or a harness's `cometpass`. Never at the core, a pulsar or a station.
```

## Clear of the suns

Above `for _try in TRIES:` in `build`:

```text
The weather comet could dive inside the star's close orbit or through a
binary's second sun: it was only a picture. A comet you fly to cannot, since
the ship waits on its path and the autopilot keeps out of every sun's
`keep_clear_of`. So perihelion is held at least CLEAR (12 px) outside star A's
keep-out, and a path that comes within CLEAR of any sun's keep-out at any of
160 points of its pass (star B where the pair has it then) is drawn again off
the same stream, up to 8 times. SystemTest reports the closest any comet comes.
```
