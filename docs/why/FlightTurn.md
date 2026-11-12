The reasoning behind `tkg/scripts/systems/FlightTurn.gd`; each heading is referenced from the code by a `Why:` line.

## Turn-around waypoints

Above `const BEHIND := PI * 0.5`:

```text
A TARGET BEHIND THE SHIP'S MOTION, ROUND ONE SUN (Jon's GA, Nov 10: fix the
solver, keep the check). A departure is one burn of one direction, so its
change of velocity is a straight line from the ship's velocity v0 to the one
it leaves at, and the least speed on it is at least |v0| sin(turn) only as the
new speed grows without bound: turned far past a right angle the line runs
close by zero and the burn swings round a point, which the departure check
turns down (`V_CUSP`, `FlightSolve._departure_cusps`). Seed 4242 system 135
(BETA TALLOW GATE) on G2's worlds, DIRECT at pace 4: the ship on its star
orbit 703 px out at 14.8 px/s, a station 207 px away 160 deg off its way.
Of 670 tries 277 were cusps (turns of 152 to 159 deg, the very ones aimed at
it, passing within 1 px), and the 392 flown came no nearer than 77.7 px
(turns of 147 deg at most), past GRAZE, so no arrival was priced and today's
planner flew it. The gate's short FlightTest found 55 of 56 so.
TWO LEGS GO ROUND INSTEAD (`FlightSolve._chain`, a twin's machinery): the
first leaves at a turn one burn makes cleanly (LEG1_TURN, 110, 95 then 80
deg) to a waypoint off the motion's side of the line, the apex of the
isosceles triangle on the ship-to-target line, and the second leaves free off
the first's coast and bends the rest, twice the apex's half-angle (at most
PHI_MAX, past which the apex runs off the map). Waypoints inside the map's
edge (CHAIN_EDGE) and clear of the sun (CHAIN_CLEAR its keep-out). Only where
one leg found nothing and the target is behind the motion (BEHIND), so the
common case plans as before. That flight is found in two legs, 12.8 s from
the click to settled, where today's planner took 9.3.
```
