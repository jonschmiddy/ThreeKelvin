The reasoning behind `tkg/scripts/sim/PairLocalTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pair in LOCAL and save

Above `const TILT := 0.07`:

```text
THE PAIR AS THE MAP LEFT IT, IN LOCAL AND THROUGH A SAVE (ruling 23, Jon,
Nov 1: "Orbiting pair"), headless:
  godot --headless --fixed-fps 60 --path . -- sheet=PairLocalTest
A binary's suns turn round their balance point on the system's map clock,
and map time does not run off the map, so LOCAL holds the pair where the map
left it (`LocalSky._hold_pair`) and the map opens on that angle again.
 1. AT 8 OF THE PAIR'S ANGLES round a lap, a wide pair (the ship at the world
    round star B) and a close one (the ship in star B's close orbit): LOCAL
    built at that kept clock holds that clock and that angle; star B on the
    band on the side of star A the map has it, and the nearer sun the one
    nearer on the map (drawn over the farther, stacked:A); a wide pair's B
    where the band puts the pair's line from A, a close pair's pushed clear
    of A's disc only while the pair lies within TWIN_TURN of level, and not
    at all end on (the suns one in front of the other); the lit sun the one
    lighting the ship's place (its own); a world round star B within its
    orbit of B on the band, and still there a minute of LOCAL's clock on.
 2. MAP -> LOCAL -> MAP: the map's clock goes into LOCAL whole, LOCAL holds it
    while it is up, and the map opens on it again, the ship where it rode
    round star B (review 2). IN CO-OP, a partner's map
    clock 10 s ahead, with the zoom ladder off and on: at both handovers
    the picture coming up has the clock of the one going (LOCAL does not take
    the party's from its map, the map does not take it from LOCAL), the kept
    clock never goes back, and the map then catches up with the party, a
    little faster than time and never by a jump (review 1), level within
    LEVEL_S. Ten minutes on instead, too far to catch up (CATCH_CUT), the
    map out of LOCAL takes the party's clock at once. And three rounds of
    4 s on the map and 4 s in LOCAL, the partner's map running: the gap
    shrinks round by round (review 2).
    OPENED ANY OTHER WAY (out of the chart), a map and LOCAL take the
    party's clock at once, and a ship parked settled round star B goes with
    B (review 2).
 3. A SAVE: the clock written, the run's clocks scrambled, the save read back:
    LOCAL opens on the very angle.
 4. ONE SUN: star A at the band's anchor and nothing turned, at any clock.
```

## Co-op catch up

Above `const LEVEL_S := 25.0`:

```text
2b. In co-op, a partner's clock ahead by `lead`: under CATCH_CUT the
handovers keep one clock and the map then catches up, level within
LEVEL_S; further on, the map out of LOCAL takes the party's at once
(`NetSession.handed_clock`, review 2: caught up at CATCH_K alone, 10
minutes in LOCAL took 40 to come level).
```

## Co-op rounds

Above `func _coop_rounds() -> void:`:

```text
2c. MAP AND LOCAL IN TURN, in co-op, with a partner whose map runs on (its
clock said every frame, a frame on): three rounds of 4 s on the map and 4 s
in LOCAL from 16 s behind. LOCAL holds the clock each time while the
partner's runs, and the map must win back more than that: the gap shrinks
round by round and never reaches CATCH_CUT (review 2: at CATCH_K alone it
grew by about 3 s a round, for good).
```

## Co-op cold open

Above `func _coop_opened_cold() -> void:`:

```text
2d. OPENED ANY OTHER WAY, IN CO-OP: a map or LOCAL opened after something
that showed no angle of the pair (here the chart) takes the party's clock at
once (`Router.show_system`'s and `LocalSky._hold_pair`'s `adopt_clock`),
and a ship parked settled round star B goes with B to where it stands then
(`NetSession.carry_parked`). Cut either call and the gate stayed green while
two machines opened the pair at two angles (review 2).
```
