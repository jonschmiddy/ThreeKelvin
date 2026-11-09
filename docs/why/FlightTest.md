The reasoning behind `tkg/scripts/sim/FlightTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test overview

Above `const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")`:

```text
EVERY AUTO-FLIGHT ON THE SECTOR MAP, planned, clicked and flown, measured and
judged (ruling 20, Oct 30: the solved flight, `FlightSolve`, in every system):
  godot --headless --path . -- sheet=FlightTest [seeds=N] [seed=N] [systems=N]
    [only=one|giant|twin|close] [worker=N] [out=<json>] [why=sys:start:target]
For systems of N runs' maps (SYSTEM, PULSAR and STATION nodes; `systems` of
each sweep a run, 12 unless asked, spread evenly through the map: seed 4242's
holds 610, and flying all of them ran past 43 minutes for the one run;
`systems=999` flies them all): one-star systems without a giant (`one`), with
one (`giant`, every giant pulling at its rolled 1/10 to 1/4 of the star), and
the ordinary systems again with two suns (`twin`, the node asked for them as
`-- twin=all` does, each a wide pair), and again as close pairs (`close`,
Jon's "Binary kinds: close:B", Nov 1: every body round both suns 150 to 170
px apart; `SystemLayout.close_force`) -- from every
start (in orbit of each world; in each star's close orbit; settled on a star
orbit, round a star or round both; flying free; at the edge as arrived;
close by a world; alongside a station, belt, hulk or contact) to every place
(each star, each world, each station, belt, hulk and contact):
- the plan the map's worker makes for its preview (`ShipFlight.make_plan`,
  PREVIEW_AHEAD on, as `plan_bg` makes it), timed on this thread: solved,
  today's planner as the fallback, or none;
- found and clean (every keep-out held), how close to a star's surface and a
  world's disc, top speed, flight time and engine work, and its drawn path's
  tightest bend and corners at zoom 1 and 2 (`_turn_max`, `_gait`);
- THE CLICK, a moment later (before its departure, as the map keeps the drawn
  flight ahead of the ship): flown through `ShipFlight.fly` with the drawn
  plan, as `fly_bg` flies it -- whether it flew that very flight, and how far
  each flown frame was from the drawn point for its moment;
- FLOWN through `ShipFlight.step` at 60 a second until it is on the orbit:
  landed, the biggest change of velocity from one frame to the next, and
  how long from the click to settled (printed, not judged: ruling 21's
  measure of flight length).
Then the captures that change under the new rule against the old (first by
index), a slow ship let go inside each place's ring, and `worker` plans made
on WorkerThreadPool (`plan_bg`): the same flights bit for bit, how long each
took there, its take-in on this thread, and this thread's frames meanwhile.
Then THE CLICKS THROUGH THE MAP'S OWN PATH (`_click_phase`, `clicks=N`): some
of the game's starts clicked through `fly_bg` at 60 and 30 frames a second
in the map's order, the preview kept as the overlay keeps it, paced to the
wall clock while anything is planned -- every click flown and landed with
its callback once, W letting go of one still being planned, nothing planned
on this thread in a frame, every flight flown on the line drawn for it, no
engine error. And FLYING BY HAND IN A TWIN (`_hand_phase`, `hand=0` to skip):
let go far out on the far side and between the stars, it settles inside the
map and taken by no ring; W at a sun never takes it inside its keep-out. And
THE TURNING PAIR (`_orbit_phase`, ruling 23; skipped with the hand phase): a
rail and a settle carried round star B, parked and put back round it across a
reopened map, a preview round it kept and rebuilt as the ship rides on, and
the edge as arrived at eight angles of the pair.
PASS, per sweep, on the flights the game can start (out of an orbit, a
star's close orbit, a settled star orbit or the edge as arrived, or
alongside: free and close-by starts, coasting at up to 170 px/s, only this
measure makes, and they are printed apart): at least 99% found and clean
(DESIGN); no corner in a solved flight's drawn path at zoom 1 or 2 (a ring
drawn so small its own ends turn faster, a twin's world round one star at
zoom 1, left out where it is ridden, and counted). From every start: every
planned flight landed; no frame's velocity change a snap; every click flew
the drawn flight to within DRAWN_PX; every solved flight ends where the
ship's own `center` puts its place; every worker plan the same. A game start
the first frame takes onto a ring is counted and not planned (the map would
refuse the click there).
THE FAR PLACES AND THE CORE (`_places_phase`): the Hellbender laid out
(`Run.hellbender_at`), where a job's place goes too, past every orbit, in
systems of one sun and of two, and the core's black hole and the start
system, which no sweep holds: every game start to each, found (in a twin by
the solver; with one sun today's planner the fallback), and no flight in the
core inside the black hole's keep-out (`MapGravity.keep_out_star`, its lens).
`short`: the gate's run (seeds=1 systems=4 worker=24 clicks=6, the far places
in 4 systems a sweep), one star, giant and twin, the clicks and the hand
phase, in about 95 s. The gate runs it as two: `short clicks=0` (no clicks)
in the pool, and `clicks` alone (the same systems' starts gathered, nothing
else planned, then only the clicks, which time the step against 20 ms and
pace to the wall clock: one of the gate's SOLO_UNITS).
Other modes: `retarget` (another place chosen on the way, PASS/FAIL) and
`starride` (out of star orbits, held as the ship rides).
`shard=K/N`: every Nth system of the sweeps from the Kth (`Harness.mine`),
and the far places, the worker plans, the clicks and the hand phase (the
turning pair's `_orbit_phase` with it) dealt round the shards the same way
(the 1st, 2nd, 3rd and 4th). The shards that
make the worker plans, the clicks or the hand phase pick their flights from
every system as an unsplit run does (`_pick_only`), so those are the same
flights however the run is split; a sweep's found-and-clean share and its
flights put there are summed across the shards by `ShardSum`.
`phase=hand`: ONLY the hand phase (and the turning pair's with it), its
systems picked from every system as a shard without the sweeps' systems
picks them (`_pick_only`: nothing else flown, judged or reported; any
`shard=` ignored); `phase=rest`: everything but it (`hand=0`). The gate
and the battery run the hand phase this way, as its own row beside the
shards run with `phase=rest`: about 205 s at x12, where it held its shard
past the gate's 300 s (Jon, Nov 8, "split: yes").
```

## Flight time cap

Above `const FLY_MAX := 45.0`:

```text
the longest a flight may take, from the click to on its orbit: from its plan
to its arrival T_CAP 16 s, ride and all (ruling 21; T_CAP_BACK 30 s where
the as-built search behind it flies it, T_CAP_WIDE 40 s for the few only the
wider search finds), the plan made up to PREVIEW_AHEAD 1 s on, the
insertion or the stop alongside, and slack. It was 16 s when flights were
time-scaled conics of 4 to 12 s; on map time they take up to 16, 30 or 40.
```

## Unleavable starts

Above `const CLEAR_S := 1.0`:

```text
A START NO FLIGHT CAN LEAVE: flying free, no burn at THRUST (CLEAR_HEAD
headings, each of CLEAR_DV) keeps its coast clear of every keep-out for this
long (s). Close by a twin's world round one star, coasting at up to 170 px/s
a few px outside a keep-out, a burn changes the motion by 4 px/s in a tenth
of a second: the coast is into the keep-out first. (No dv of nought: the coast
with no burn is not a departure, and one grazing a keep-out by 3.7 px read as
clear for 30 s)
```

## Measured residual

Above `const PUT_LEFT := 6`:

```text
AND THE MEASURED RESIDUAL past those, every one a harness's free or near start
(the map flies only out of an orbit: `can_fly` in free mode is a star orbit),
at the most, and only from the starts named in PUT_LEFT_CASES. A game start
put there with no flight is never excused (`_clear_for` is INF for it): none
may be. On Oct 31 (three seeds, 1 of 1,790 twin plans) it was seed 7 system
110, close by world 1 round star B, which no longer comes up. THE PAIR
TURNING (ruling 23, measured Nov 2, three seeds: 6 of 1,790 twin plans, from
two free starts; every game start found): seed 1999 system 177, 138 px
outside star B's keep-out coming at it at 116 px/s, to 4 places, and seed 7
system 209, 89 px outside star B's at 77 px/s, to 2. The misses are the
arrivals, not the departures: from 177 the search flew 192 departures that hit
no keep-out (one heading, 90 deg, keeps clear for 30 s at every burn) and
found no arrival for any; from 257 (close, below) wide windows keep clear for
30 s and the scan's own heading lies in one. Only 209 has a narrow window
out. No gap in the solver for a turning pair was found.
```

Above `const PUT_LEFT_CLOSE := 6`:

```text
AND A CLOSE PAIR'S (Nov 1, three seeds: 5 of 1,789 plans, every one from a
harness's start; every game start found): a free start 223 px from star A
diving at the pair at 149 px/s, to star A and to world 3 (found 1 and 2 s
on), and one to star B; two close by a world, coasting at 106 and 114 px/s,
that the next half second takes onto the place itself or alongside (found 2 s
on). With the suns 150 to 170 px apart a harness's free start lands nearer
them than in a wide pair, aimed at them more often. THE PAIR TURNING (ruling
23, measured Nov 2: 6 of 1,789 plans, all from a harness's starts): seed 1999
system 257's free start, 165 px outside star B's keep-out diving at the pair
at 149 px/s, to 5 places; and seed 4242 system 24's near start, 23 px
outside world 4's ring at 106 px/s, to world 4. STATIONS HALVED (Nov 3,
S3): more systems may have two suns, so the sweep picks other close pairs
(every so many of a seed's binaries), and neither of those comes up. Seed
4242 system 297, SIGMA KESTREL WATCH, does: 3 of 427 plans in its shard,
its free start to star A, star B and world 0, where the best burn keeps
clear for 30 s, so it is the arrivals that miss, as from 257. Every game
start found.
```

## Far places

Above `func _places_phase(seeds: Array) -> void:`:

```text
THE FAR PLACES AND THE CORE, from the game's starts (out of each world's
orbit, each star's close orbit, a settled star orbit, the edge as arrived,
alongside): the Hellbender laid out in `_places` systems a sweep of one sun
and of two (a job's place is laid out the same way, past every orbit:
`SystemLayout.of`), flown to; and the core and the start system, every
place. A twin's flight to the Hellbender found nothing 17% of the time from
the edge before flights in two legs (the one-sun review, Oct 31), and the
core's solved flights dove inside the black hole's lens, 33 of 252 inside its
close orbit, where today's planner never went.
```

## Taken starts

Inside `_case()`, above `if (key == "free" or key == "near") and fl.mode != &"free":`:

```text
(nor is a harness's free or near start the first frame took onto another
place's ring or alongside it: it is being taken in, with no departure to
plan from, and the map would refuse the click as above. A turning pair
carries its worlds and stations about, and seed 1999 system 177's near
start for world 2 was put inside station 3's reach, taken alongside it
and then counted as a flight put there; counted with the game's, not
planned)
```

## Clean measure

Inside `_case()`, above `var Gq: MapGravity = _gq.get(L.get_instance_id(), null)`:

```text
CLEAN AS MAPGRAVITY HAS IT at each sample's own time, not on the
solver's word: a solver reading the suns at the plan's start passed
this measure with flights 9 px inside a keep-out (review 2)
```

## Flight end place

Inside `_case()`, above `if pl.res != null:`:

```text
WHERE IT ENDS, against where the ship's own `center` puts the place then
(the solver's place is MapGravity's copy of the layout's; a belt's beacon
rides round the belt's host, which `center` once took for the origin)
```

## The click

Inside `_case()`, above `var R := RandomNumberGenerator.new()`:

```text
THE CLICK, up to CLICK_S on (the ship riding its ring, holding alongside,
or round its star orbit meanwhile), on the flight drawn then: planned
again as the overlay plans it (`SystemOverlay._draw_paths`: every 3 s on a
ring, every second otherwise, as its departure comes up, and once it can no
longer be flown -- a ride that had to phase falls behind if it is not
flown), each from the last one's choice. Here each comes in at once; on the
map a few frames later, and a click meanwhile flies the one being made.
```

## Click and flight

Above `func _fly(fl, i: int, t0: float, drawn, undrawn := false) -> Dictionary:`:

```text
THE CLICK AND THE FLIGHT, at 60 a second through the ship's own step: the
drawn plan given to `fly` as the map's click gives it (`fly_bg`); whether
the ship flew that very flight, each flown frame from its departure to its
arrival against the drawn point for its moment and, after it, against the
drawn insertion; on the orbit at the end; the biggest frame-to-frame change
of velocity (against the frames either side, a snap's tell) and of the nose.
```

## Capture rules

Above `func _captures(L: SystemLayout, seed: int) -> Array:`:

```text
THE CAPTURES THAT CHANGE under the new rule (the place the line goes into,
else the nearest ring) against the old (the first world by index, then the
star, then a station's), as letting go there takes the ship: a slow ship put
inside each place's ring (a world's at 0.2 to 0.95 of it, a station's,
belt's, hulk's or contact's within its reach as seen, a star's close ring) at
six points round it, one step of `free_step` each way: [how many were held
by two rings or more, how many of those the new rule took elsewhere, of how
many]. Where one ring holds the ship the two rules are the same rule.
```

## Click phase

Above `func _click_phase() -> void:`:

```text
THE CLICK AS THE MAP MAKES IT (the flight review, Oct 31: no harness clicked
through `fly_bg`, and none in a twin): for some of the game's starts in each
sweep, at 60 and at 30 frames a second, in the map's own order -- the click
before the frame's clock moves, then the clock, the ship's step, and the
overlay's draw (its preview asked for on a worker, laid out there, taken in
when done and kept while it can be flown, as `SystemOverlay._draw_paths`
does) -- paced to the wall clock while anything is being planned, so a plan
comes in as many frames late as it would. Some clicks come while the preview
is still being made (the click takes its job over), some let go with W while
their plan is still coming. Counted: flown, landed, the callback once on the
orbit, put there, stale take-ins, a frame the step took over 20 ms (a plan
made on this thread), frames from the click to the flight, and each flown
frame against the line the overlay drew (the polyline `ShipFlight.lay_out`
laid out, which is what is on screen).
```

## Hand flying in a twin

Above `func _hand_phase() -> void:`:

```text
FLYING BY HAND IN A TWIN, as the flight review let go and held W (Oct 31),
in each twin the clicks used: let go out on the far side from star B (0.99 of
the edge, drifting 8 px/s along), it settles round both stars on a circle
inside the map and stays off the edge, and a flight from there stays inside
it; let go between the stars (3 and 25 px off their balance point, at rest),
it settles, taken by no ring; W held at each star at 150 px/s, it never comes
inside its keep-out (6 px outside its sun as drawn at the opening zoom). The
pair as it stands at each row's moment: it turns (ruling 23). Then the
turning pair's own checks (`_orbit_phase`; `hand=0` skips both).
```

Inside `_hand_phase()`, above `var taken_far := ""`:

```text
(and taken by no ring, while pulled in or once settled: in about one
twin layout in five the far side's circle lay inside the ring of a world
or giant round both suns, and the ship was put on it, Nov 2)
```

## Turning pair

Above `const ORBIT_S := 60.0`:

```text
THE PAIR TURNS (ruling 23, Jon, Nov 1, "Orbiting pair: after4:D speed:A
stacked:A"): both suns circle their balance point at four times Kepler and
each world round one sun is carried with it, so a ship round star B is round
something that moves. Over the twins the clicks used (three wide pairs, two
close ones), each at the clicks' moment:
- A CARRIED RAIL: on star B's close orbit, and on the orbit of the world round
  B, for 60 s, the ship on its radius from where the map draws the place at
  each frame's moment, its frame-to-frame motion its own velocity (no frame
  left behind by the sun), and the place carried meanwhile;
- A CARRIED SETTLE: let go at rest beside star B, inside its steady zone,
  and put there by `settle_at`: it settles round B and keeps its radius
  within SETTLED_PX of where B is, every frame of 60 s, its centre on B;
- PARKED AND PUT BACK round B across a reopened map (`restore_free` at the
  kept clock, `Run.map_clock`, and the record through the save's own rows
  with the clock's): on its orbit round B, where it was, 30 s on still; and
  with the clock run on 5 s without it (a map built ahead and dropped), on its
  circle round where B is then, no further from where it was than B moved;
- A PREVIEW ROUND B, from that settle to star A, to a world round each sun
  and to one round both: still takeable a quarter second and a second on, or
  the last frame the overlay keeps it before its departure if sooner
  (`_takeable`, by the sun's id, not its place: else it was planned again
  every frame), rebuilt from its choice then as the very same flight (kind
  replay, its samples: FlightSolve's choice must name the sun too), and
  clicked a quarter second on, flown as drawn and landed;
- THE EDGE AS ARRIVED AT EIGHT ANGLES OF THE PAIR, a lap apart in eighths
  (the review of the plan: the arrival point and the edge stand still while
  the pair turns under them, so a flight from there is another flight at
  every angle): every place planned as the preview is and flown, found and
  clean, landed, on the drawn line, no snap; and each one at star B or the
  world round B landed on its ring within ON_RING_PX with no insertion.
`-- pair=0` holds the pair still: every check holds there too (the place
then not carried).
```

## Carried settle

Inside `_orbit_phase()`, above `var r_set := _settle_r(L)`:

```text
A CARRIED SETTLE round star B: let go there at rest, and put there. (In
a wide pair the world round B rings the whole of B's steady zone past
STAR_ORBIT_GAP: a ship settled there is taken onto that world, or
turned off its disc, the first time it passes, within seconds, as it
should be. For the settle and the put-back alone that world is off the
map, its `world` cleared and put back after, so 60 s of the settle
itself are flown; the preview below flies with it there.) In a close
pair B's zone ends 0 to 6 px past its ring, so a ship let go or put
beside it settles at the ring's STAR_ORBIT_GAP (`_settle_centre`)
```

## Giving way

Above `static func _gave_way(r: FlightSolve.Result, r2: FlightSolve.Result) -> bool:`:

```text
A FLIGHT THE FALLBACK FOUND (its choice's cap past its path's own first
look's: T_CAP for DIRECT, T_CAP_BACK for CURVED, `SolveTest._cap0`) GIVING
WAY, rebuilt from its choice, to a fresh one in one leg arriving sooner:
kept only while none does (ruling 21's reviews, `FlightSolve._solve`), so not
the same flight, and right. This is the one-leg half of SolveTest's
`_fell_sooner`; that one also lets a two-leg flight give way, as
`FlightSolve._sooner_of` does, and this one does not yet. (Against T_CAP for
both, every CURVED flight read as the fallback's, cap 30, and every one
that gave way was forgiven: the code review, Nov 5.)
```

## Judged flights

Inside `_report()`, above `var g_n := 0`:

```text
JUDGED ON THE FLIGHTS THE GAME CAN START: out of an orbit, a star's
close orbit, a settled star orbit (the edge as arrived is one) or
alongside (Jon: "You have to be IN AN ORBIT ... AND THEN CLICK");
flying free and close by a world, coasting at up to 170 px/s, only
this measure asks for, and they are printed on their own
```

## Put there

Inside `_report()`, above `var excused := 0`:

```text
IN A TWIN NO FLIGHT IS PUT THERE (the ship jumped to the place with no
flight: 63 of 1,790 before a flight in two legs, 18 of them from the
game's starts), from any start this measure makes -- but one no burn
at THRUST can leave without crossing a keep-out within CLEAR_S, each
listed with how long its best burn keeps clear
```

## Retarget

Above `func _run_retarget() -> void:`:

```text
ANOTHER PLACE CHOSEN ON THE WAY (Jon: "You have to be IN AN ORBIT ... AND
THEN CLICK to go to another planet"): flights out of a world's orbit and out
of the star orbit, flown frame by frame. Counted: frames where a flight could
start while it should not (on the way, burning onto an orbit, riding round
to leave); then, once settled, the plan to another place -- none, degenerate
(not a number, off the map, through a star), how far out it swings and
turns, how much it moves as the map replans it every half second for 3 s --
and whether it lands. Flights on map time take up to 16 s from their
departure (ruling 21; 30 s where the as-built search behind it flies them,
40 for the wider search) and their ride up to 4.4 s first (ruling 20), so
the waits for settling and landing are FLY_MAX, not the 30 s and 20 s of the
time-scaled conics; what is counted is the same.
```

## Star ride

Above `func _run_starride() -> void:`:

```text
OUT OF THE STAR ORBIT (Jon: "the projected orbit path is updating constantly
and can create some WEIRD shapes"): star orbits at three sizes, the ship at
six points round each, to every world. Each plan measured as drawn (turning in
all, S-bends, lobes, tightest bend away from the rings) and then held: the
ship rides on for 3 s and the map's replan (every half second, keeping its
choice) is compared with the last -- how far its line moved.
```

## Ring skips

Above `func _ring_skip(fl, L: SystemLayout, pl, path3: PackedVector3Array, i: int, from_b: int, zoom: float) -> PackedByteArray:`:

```text
THE STRETCHES OF A DRAWN PATH THAT ARE A RING'S OWN CURVE, as `_turn_max`
skips them at `zoom`: on the ring it leaves (while it leaves) or the one it
arrives on (as it arrives, and the ring drawn after), within 1.25 of that
ring, where that ring is drawn so small its own ends turn faster than CORNER
-- a ring of radius R is drawn as an ellipse whose ends curve at TILT^2 R
zoom px, 2.5 px for a twin's world round one star (R 17.6) at zoom 1, 22 deg
a px. The ring is the world's, drawn as such; the flight on and off it is
still measured, and corners there are counted apart (`ring corners`).
```

## Two paths

Above `const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")`:

```text
THE TWO PATHS (the fast transfers, Nov 5: AUTOPILOT DIRECT . CURVED): both
unless `autopilot=direct|curved` names one, each at its own pace
(`ShipFlight.FLIGHT_PACE`, or `flight_pace=K`). The sweeps and the far places
run once a path, each sweep judged on its own (its name with " curved" after
it for CURVED); the worker plans, the clicks and the hand and pair phases
run on the last path asked for (CURVED, the game's default, unless only
DIRECT is). `autopilot=direct flight_pace=1 worldpace=1` is the run of
before the fast transfers. Each sweep prints how long from the click to
settled in real seconds (map time is real time), from the edge as arrived
(a jump's first flight) apart, each flight's bend and turn
(`FlightSolve.shape_of`), and how many went to today's planner; at the
path's own pace the times are judged (`CLICK_MED`, `CLICK_P90`,
`CLICK_EDGE`).
```

## Drawn line held

Above `const MOVE_MED := 16.0`:

```text
THE DRAWN LINE HELD while the ship rides its orbit, judged (the code review,
Nov 5): the median of each flight's biggest move in half a second at most
twice today's (`autopilot=direct flight_pace=1 worldpace=1`: 8.11 px). Nov
5: DIRECT 11.7, CURVED 29.0 (its search prices a second at TIME_W_BACK, so
flights of near one cost bend round the stars very differently; a warm slack
of 0.5 or 1 for it, `-- warmk=`, made 26.1 and 23.9). Left failing for Jon.
```

## Near line

Above `static func _near_line(p: Vector2, line: PackedVector3Array, j0: int) -> Array:`:

```text
How far p is from a laid-out line (plane px), looking on from point j0:
[distance, the segment it is nearest]. It looks 64 points on, and on again
while the nearest is at the end of what it looked at: CURVED at x12 in a
30 fps frame moves about 65 of the line's 1600 points, so a fixed 64 lost
the ship and read it 9.05 px off a line it was on to 0.00 (seed 4242 system
50's twin, close -1 to 0; Nov 7).
```

## Click limits

Above `const CLICK_MED := {&"direct": 4.5, &"curved": 6.5}`:

```text
from the click to settled at the path's own pace, s, each path its own: the
median and 90th of the game's starts, and the median from the edge as
arrived (a jump's first). Jon's ruling (Nov 7, "5A"): each path's limits
just over what it flies, where one set of 3.6 / 4.5 / 5.0 failed both. The
worst shards measured (FlightTest short clicks=0, 4 shards, Nov 7): CURVED
(WIDE x12) 5.67 / 7.62 / 7.40, DIRECT (x4) 4.10 / 5.52 / 5.20.
```

## The harnesss starts the residual may

Above `const PUT_LEFT_CASES := {`:

```text
the harness's starts the residual may come from, "seed:system:start" a sweep
(any other start put there fails, whatever the count). SCIENCE (Phase 12,
Nov 4) put a reading in place of one option in about three systems in eight,
and those systems alone lay out anew (checked system by system against the
layouts before): two of them, seed 1999 system 258's near start (THE RACE
COURSE on its belt) and seed 7 system 328's free start (THE TARGET RANGE on
its dry world), each to one place, now leave a twin's residual, the best burn
from each keeping clear for 30 s, so again the arrivals miss. At the study's
1 in 6 (Nov 4) about half of all systems hold one, and one more does: seed
1999 system 74's near start (THE FIRST LOOK on its dry world, a reading it
does not hold at 1 in 8; its list is main's but for that slot), to one place,
the best burn keeping clear for 30 s again
```
