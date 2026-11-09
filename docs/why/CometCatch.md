The reasoning behind `tkg/scripts/ui/sysmap/CometCatch.gd`; each heading is referenced from the code by a `Why:` line.

## The catch

Above `extends Node`:

```text
Jon's C (Nov 9, "wait on its path"), with his note on the catch: "Shouldn't we
have the ship like right next to the comet... like it's approaching close to do
science?" The map offers three spots on the comet's path (`CometPath.SPOT_AGE`).
Each shows the race: IT, the seconds until the comet gets there, and YOU, the
seconds the autopilot needs to be settled there. A spot greys out TOO LATE once
the comet has gone by it or the ship cannot be settled there MARGIN (1 s) first.

The flight is the autopilot's own (`FlightSolve`), to a still point: a keep
target at place -9 with its centre at the origin and the spot as its offset.
`ShipFlight.center(-9)` is the origin too, so the arrival burn ends exactly on
the spot and the ship then holds there in keep mode. Leaving later is an
ordinary flight out of a keep. Nothing in ShipFlight or FlightSolve changes, so
every other flight is untouched (FlightTest, run on main and on this branch,
gives identical numbers but for wall-clock timings).

YOU comes from real plans: all three spots are planned on a worker thread every
half second from where the ship is (`FlightSolve` is pure data). A click flies
the last plan if it can still be taken, else one planned there and then, and
refuses one that would arrive too late. It never flies the ship anywhere else.

Waiting on the spot, the map watches the comet. When it is PASS_LEAD (0.4 s of
map time) from the spot, the spot is kept as the reading's (`set_caught`) and
the map goes down the zoom to LOCAL with the reading open, as GO does. LOCAL
draws the close pass (`LocalComet`). Back on the map the screen would put a
ship it cannot place (keep at -9) at the system's edge, so the catch puts it
back on its spot once.
```
