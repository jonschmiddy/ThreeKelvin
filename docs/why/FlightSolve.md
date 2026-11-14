The reasoning behind `tkg/scripts/systems/FlightSolve.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Autopilot flight solver

Above `const THRUST := 40.0`:

```text
THE AUTOPILOT'S FLIGHT, SOLVED under the real pull of the stars and the
giant on map time (ruling 20, Oct 30: "Prototype: twin:A giant:A"; Phase 13
step 2, ruled Oct 29 "flight:N clock:map"). Data in, data out: no Nodes, no
Callables, nothing shared but the read-only `MapGravity`, so it is safe on a
`WorkerThreadPool` task, and the same inputs always give the same flight.

A FLIGHT, from where the ship is to a place:
1. the ride: round its ring (a world's, a star's close orbit, or any circle
   round a fixed point) at the ring's own pace for up to LEAD_MAX 4.4 s, and
   past that sped up by a phasing burn whose push is held to THRUST
   (`ShipFlight._step_phase` flies it); alongside a station, belt, hulk or
   contact, holding there KEEP_HOLD 1 s;
2. the departure burn, in one direction, from the ring's own motion
   (velocity continuous), at THRUST 40 px/s^2 but eased while the ship is
   slow so it turns no tighter than R_BURN;
3. the coast, integrated through the stars and the moving giant (RK4 in
   64-bit scalars, each step ETA of the nearest pull's own time);
4. the arrival burn, onto the target's ring at its speed either way round:
   a constant pull of THRUST that ends exactly on the ring (`_const_burn`),
   its end where that pull is exact; alongside, the coast's path plus a cubic
   that ends exactly at the spot, its own pull at most THRUST and linear in
   time. With gravity's change across the burn, at most THRUST_SLACK over.
Keep-out (`MapGravity`) holds along the whole path: each step's closest
approach on the cubic through its ends, and the arrival burn's own path. The
flight's own departure and target world keep out only to their rings
(OWN_GAP). No burn all but stops the ship and turns it round a point, which
draws a cusp (V_CUSP).

THE COST: engine work (the ride's phasing and both burns, px/s) + TIME_W x
seconds from now to arrival. Flying inside a system costs no fuel; the cost
only picks the path. TIME_W is the dial: more, faster flights that burn more.

HOW IT IS FOUND (prototyped in tk-scratch/twin-build/solve-proto, measured):
- conic guesses (Lambert about the star; in a twin about the pair's balance
  point and about each star the flight leaves or reaches), priced from the
  very point and moment the ship can leave, aimed at the target ring's
  tangent point (where the ring's motion runs along the coast's own);
- the cheapest refined by Newton (finite differences, then Broyden) on the
  departure velocity until the coast meets that tangent point at its time;
- in a twin always, otherwise when no conic flies clean: a scan of real
  departures (SCAN_HEAD headings x four speeds, each leaving from the ring
  point whose motion runs along it, or the end of the ride's reach; out of a
  twin star's well to a place round both, faster: FAR_SPEED), the best
  refined by a minimum-norm Newton on the signed miss at the coast's pass of
  the target (its time free: along-track timing is the sensitive direction
  of an arc), from the point it left; then a second scan between the
  first's headings, and a third slower and faster;
- last, the rest of the conics as they are. At most BUDGET integrations,
  and one more for the samples;
- when all of that finds nothing to T_CAP, THE FALLBACK (`_fallback`, ruling
  21): the as-built search (all of the above to T_CAP_BACK at TIME_W_BACK,
  BUDGET more) and a wider search to T_CAP_WIDE at TIME_W, its scan faster
  and, out of a settled star orbit, toward the target (`_search_wide`,
  BUDGET_WIDE more), the flight that arrives first kept; when both find
  nothing, the wider search again at TIME_W_BACK. A flight found to T_CAP
  whose samples cut a keep-out gets the fallback's look too, and the
  fallback's flight is kept if it is clean (`_build_fresh`);
- in a twin, when even that finds nothing, a flight in two legs (`FlightChain.chain`):
  the first aimed at a point round the pair, the second leaving free off its
  coast before the first's arrival burn, so the ship never stops there, both
  legs by the as-built search alone. One Result.
A burn that all but stops the ship and turns it round (`V_CUSP`, `CUSP_TURN`),
or an arrival burn the map would draw as a corner (`DRAW_K`), is not flown.

MEASURED (SolveTest, Oct 30, this Mac's i5-8257U, with the LAYOUT branch's
twins merged in; 10,362 plans, every start to every place): found and
clean in 99.97% of 3,084 one-star plans, 100% of 3,768 with the giant at
1/10 and 1/4, 99.16% of 2,610 in the layout's own twins (8, the most bodies
of four seeds, 6 line-ups), 98.9% of 900 in the prototype's twins built by
hand. Each lands on its ring within 0.0001 px and 0.07 px/s; the drawn
coast within 0.11 px of a plain RK4 at SAMPLE; 82% of arrivals onto a ring
a constant burn. Planning median 13 ms one-star, 14 with a giant, 37 in a
real twin; the worst 61, 70 and 136 ms (209 in the hand twins). A twin's
plans are over DESIGN's median of 25 ms, so the game plans them on a worker
while the ship rides its ring (a plan made on a worker is the same plan, bit
for bit). The prototype's free twin flight (world a to world b at its best
line-up, 9.2 s): 1.6 px/s in 9.3 s. The first build, on the same real
twins: 89.8% found (the planner review), its rides phasing at up to 436
px/s^2 for free and its arrival burns three times their least.

THE PAIR TURNS (ruling 23, Jon, Nov 1, "Orbiting pair: after4:D"): a
binary's suns circle their balance point at four times Kepler, every world
round one sun carried with it. The coast reads both suns at each step's
start, middle and end (one cos and sin a place for both); keep-outs, the
arrival burn's checks and the pull a burn is held to read them, and every
circle carried with one, where they are then; a place round one sun -- a
world, its close orbit, a settled orbit round it (`host`) -- rides with it
(`_dhs`, `_ths`); a conic about a sun is solved in its own frame and asks by
the sun's index whether the target is that sun (`_lam`, `_aims`). A sun
that holds still -- one alone, a pair held still (`-- pair=0`) -- runs the
very same arithmetic as before: SolveTest's one-star, giant, hand-twin and
real-twin sweeps print the same numbers to the last digit at pair=0.
Turning (SolveTest, Nov 2, this PC, other jobs beside it): found and clean
in 3,022 of 3,024 real wide-pair plans (the two misses free starts, a
harness's), 3,024 of 3,024 close, 1,080 of 1,080 hand twins, and 1,872 of
1,872 in the pair-phase sweep (three of the busiest pairs at 8 angles a
lap, from a settled orbit round each sun too); every landing within 0.0001
px and 0.07 px/s of the ring where the layout's Body has it; the drawn coast
within 0.13 px of plain RK4 through `MapGravity.acc`; every replay and
worker plan the same. An RK4 step through a turning pair costs a tenth to a
fifth more (the prototype's bench, `tk-scratch/orbiting-pair/autopilot`).

USE
  var G := MapGravity.from_layout(L)          # once per system; shareable
  var r := FlightSolve.solve(G, dep, tgt, t)   # or (..., prefer = r.choice)
  dep: {kind: &"ring", place: int, rt: float, ang: float, w: float}
         place: a body index, -1 star A, SystemLayout.STAR_B, or -9 with
         c: Vector2, a fixed centre (a settled star orbit); w signed rad/s
         (a star's rt: `star_orbit_r`). A -9 round one sun of a turning
         pair also passes host: that sun's place id (`ShipFlight` f.cen_id);
         the circle then rides with the sun and c is not read (-9, or none,
         a fixed centre: the balance point, the edge as arrived)
       {kind: &"keep", place: int, off: Vector2}   alongside, `off` from it
       {kind: &"free", p: Vector2, v: Vector2}
  tgt: {kind: &"ring", place: int, R: float, V: float, sense: 0 | 1 | -1}
         R the radius it arrives on: a world's `ShipFlight.orbit_r(i)`, a
         star's `FlightSolve.star_orbit_r(L, p)` (in a twin its rail, NOT
         its ring - 8, which is inside its keep-out); V the ring speed (RAIL_V
         35, a star's STAR_RAIL_V 45); sense 0 either way round
       {kind: &"keep", place: int, off: Vector2}
  t: map time now.
The result (`Result`) fills a ShipFlight.FlightPlan: samp from t0 (after
the ride, or the hold alongside) SAMPLE apart, burns per sample, end {body,
p, v, a, arel, rv, t, keep, sense} (a: the ring's own pull, relative, so the
insertion that follows flies none), lead and lead_k for rail.phase (a ride
of up to 4.4 s: rail.phase {T: lead, k: lead_k} as it is; alongside, the
ship holds at its spot for `lead`), dur, amax, esc_t (the departure burn),
`legs` (2 for a flight in two legs, `wp` its point, `k_cut` and `t_cut` the
sample and moment its second leaves) and `choice`. Passing that choice back
as `prefer` rebuilds the same flight
exactly (one integration) while it is the same flight (`_same_flight`) and
its departure is still ahead: round a ring while the ride from where the
ship is now reaches it at a phasing within THRUST (its ride may then phase
harder than it did, at up to 2 THRUST lead / pi px/s more work), alongside
while the hold lasts, free at the same moment and state. Otherwise the
search starts from it and keeps that flight while it costs about what it
did (WARM_K, WARM_ADD), so a preview does not flip between near equals; a
flight the fallback found, rebuilt or searched from, only while a fresh
search (C's own, else the fallback's two) finds none arriving sooner. A
flight in two legs comes back from its legs (`FlightChain.chain_again`: rebuilt while
the first is the same flight, else searched from them, while it costs about
what it did), and round a ring or alongside is kept only while a fresh plan
(one leg, else two) finds none arriving sooner (`_sooner_of`), its own drawn
flight too. A flight of one leg that took over from one in two carries those
legs in its choice (`alt`), and they are tried again beside it each time it
is planned again (searched again once their departure has gone by), so a
later flight in two legs found afresh never stands where the old legs still
fly sooner. A flight in two legs looked for again through its old point
(`FlightChain.chain`'s hint) is kept only while the first one found without it arrives
no sooner.
`found` false: nothing clean within the budget, and no samples (the caller
falls back); `clean` false on a found plan only if its own samples cut a
keep-out (none in the sweeps).
```

## Arrival burn checks

Above `const BURN_PAD := 0.5`:

```text
the arrival burn's path is checked every 0.05 s of it and kept this far
(px) inside its keep-outs' edge: checked every 0.1 s, two arrivals onto a
twin's close orbit cut 0.15 and 1.5 px in between the points
```

Above `const TB_PAD := 2.0 * (1.0 / 240.0)`:

```text
an arrival burn starts at least this long (s) after the departure burn
ends, so moving its end onto the sample grid (`_build`) cannot start it
before: one did, by under a sample, and the flight's first samples carried
its pull (0.18 px off the place it left, SolveTest)
```

## Ride length

Above `const LEAD_MAX := 4.4`:

```text
THE RIDE round to the departure point, at the ring's own pace, lasts at
most this (s): twice `ShipFlight.LEAD_MAX`'s 2.2. Past it the ride phases
(below). Priced honestly, phasing costs 2 V of engine work for each unit of
k (70 px/s on a world's ring) where riding on costs TIME_W a second, 2.2 s
of it for the same way round: at the as-built TIME_W of 0.5 riding was about
sixty times cheaper, and at 16 (ruling 21) it is still half the price; held to
2.2 s and THRUST, the twins built by hand fell from 99.1% found to 95%
(SolveTest, Oct 30). A ride's seconds are in the flight's time, so the cost
keeps it short where it can.
```

## Phasing burn

Above `const PHASE_K_MAX := 4.0`:

```text
THE PHASING BURN's top pace, in times the ring's own, at the most: the ride
speeds round as `ShipFlight._step_phase` flies it, pace 1 + (k - 1) sin^2,
and its push along the ring peaks at |w| (k - 1) pi rt / LEAD_MAX. That push
is held to THRUST (`_kmax`): k at most 2.6 on a world's ring at RAIL_V,
2.25 on a star's close orbit at STAR_RAIL_V, its top speed under VMAX. The
first build let k reach 8 within 2.2 s, which pushed at up to 436 px/s^2
and whirled a ship round a twin's 17.6 px rings at up to 350 px/s, free in
the cost (the planner review, Oct 30). Its work, 2 |k - 1| |w| rt, is in the
cost.
```

## Alongside hold

Above `const KEEP_HOLD := 1.0`:

```text
ALONGSIDE, A FLIGHT LEAVES THIS LONG AFTER IT IS PLANNED (the ship holding
alongside meanwhile), so the drawn flight is still ahead when it is clicked
and is rebuilt exactly from its choice (a ring's ride does the same). With
no hold, 48 of 48 clicks a quarter second after their preview flew another
flight, by a median 17.8 px (the planner review, Oct 30).
```

## Own world keep-out

Above `const OWN_GAP := 2.0`:

```text
A FLIGHT'S OWN DEPARTURE AND TARGET WORLD keeps out only to its ring less
this (px), not to r + 8: a twin's worlds round one star ride a 17.6 px ring,
inside r + 8 for any world over 9.6 px (1 twin in 26), so nothing flew to
or from them; where it did fit, it left a median 2.7 px
```

## Warm start

Above `const WARM_K := 0.25`:

```text
A PREVIEW'S FLIGHT IS KEPT (`prefer`, its departure gone by) while it costs
at most WARM_K more than it did, or WARM_ADD: past that the search runs, and
the kept flight stays only if the search does not beat it by as much. With
none, kept flights ran up to 81.6 over a fresh search (the planner review).
```

Inside `_solve()`, above `var j_old := float(prefer.get("J", INF))`:

```text
KEPT while it costs about what it did; else the search, and the kept
flight only if the search does not beat it by as much. A flight the
fallback found (its cap past T_CAP) is kept only while a fresh
search finds none that arrives sooner, the rule `_fallback` keeps
between its two, so the fresh search runs every time. Kept on its
own cost, one fallback while a preview was drawn held every later
plan of that errand to its slow flight, C's own search never looking
again; with C's own search alone looking, an as-built flight of
29.0 s stood where the wider search found one of 18.2, and priced
against the fallback's flight with the warm slack, a wider flight of
26.3 s where the as-built one found 23.9 (the reviews, Nov 1: each
of SolveTest's fallback flights from a ring or alongside planned
again 15 times as the overlay does, 1,790 of the 5,745 kept warm
were kept where a fresh plan arrived sooner; none now)
BOTH SIDES AS BUILT (Nov 7): a choice's J is its flight's cost as
built, on the sample grid, and the kept flight and a fresh search's
are weighed on that too. The search prices a flight at its exact
arrival, and an arrival burn alongside can cost a few px/s more or
less there than a sample on: within a few percent of the least pull
it is the short burn, just past it one about three times as long
(`FlightMath.cubic_burn`). Priced, at seed 7 node 199's close pair (CURVED,
ring 1 to keep 5, line-up 2, planned again 3 s on) the fresh flight
cost -162.5 against the kept one's -155.8, inside the slack; built,
-166.1, its burn 0.37 s and not 1.10 s, and the kept flight stood
0.3 past the slack (SolveTest short shard 3, every run at x12).
```

Inside `_solve()`, above `_fresh()`:

```text
(and the fallback when that finds nothing, as a fresh plan has:
without the wider search a kept flight of 359 stood where a fresh
one found 206, SolveTest Oct 31)
```

Inside `_solve()`, above `_b_J = INF`:

```text
(a budget of its own after a warm start that flew nothing, so it finds
what a fresh plan does: on what the warm start had used, C's own search
ran short and a flight of 17.9 s the fallback found stood where a
fresh plan found one of 14.9, twin 280, orbit9 -9 to ring 1, line-up 4)
```

Above `func _warm(c: Dictionary) -> bool:`:

```text
FROM A CHOICE THAT CANNOT BE REBUILT (its departure gone by, or open
space), for the same places: its departure flown again, toward its old
arrival time, from its old ring point while the ride still reaches it (or
else from wherever its motion runs along the flight's). True when it flies;
`_solve` keeps it only while it costs about what it did. The first build
kept any flight that flew, from any departure place (the planner review).
```

## Wider search

Above `const T_CAP_WIDE := 40.0`:

```text
WHEN THE SEARCH FINDS NOTHING, A WIDER ONE (`_search_wide`): arriving within
T_CAP_WIDE of now, the cheapest conics to then refined, and a scan of
WIDE_HEAD headings whose departures are at least as fast as crossing to the
target in WIDE_T takes (`_wide_need`) -- out of a settled star orbit, across
WIDE_SPAN either side of the target's bearing -- within BUDGET_WIDE more
integrations. Out of a settled star orbit the scan's speeds were its ring's
own times 1 to 3.9, and a twin's settled orbits far out go round at 11 to 16
px/s: 41 px/s at the most in its first pass, too slow to cross a two-star
system inside T_CAP, and the edge as arrived (every visit's first flight) was
found for 201 of 224 flights. Measured on FlightTest's game starts (Oct 31,
three seeds): twins 1,432 found of 1,478 before, 1,460 with it; a heavy
giant 913 of 921, 917; one star 694 of 696, the same. It runs only for
flights nothing else found, so every flight found before is the same flight;
those it finds take a median of 200 ms and at most about 250 (on a worker).
Budgets of 400, 16 headings, headings within 30 or 45 deg of the bearing and
a cap of 55 s found no more; what it still misses (18 twin flights of 1,478)
leave a star's close orbit or a settled orbit far out for a station, belt,
hulk or contact on the far side of the pair, which no departure burn and one
coast reaches (the closest any of 1,260 departures came was 42 to 249 px):
those fly in two legs (`FlightChain.chain`). Those numbers are the as-built search's;
at C the wider one looks beside it (`_fallback`).
```

## Flights in two legs

Above `const CHAIN_PRE := [0.5, 3.0, 6.0]` (`FlightChain.gd`):

```text
WHEN EVEN THAT FINDS NOTHING, IN A TWIN, A FLIGHT IN TWO LEGS (`FlightChain.chain`):
the first aimed at a point in open space (`FlightChain._waypoints`), the second leaving
free off its coast CHAIN_PRE s (each in turn) before its arrival burn, at
least CHAIN_AFTER after its departure burn. The points: round the pair, half
way round from the ship to where the place is CHAIN_T on, at CHAIN_R times
the farther from the balance point, at least CHAIN_CLEAR separations out and
within CHAIN_EDGE of the map's edge. Measured (FlightTest, Oct 31, three
seeds' 36 twins, 1,790 plans): 37 fly in two legs -- every one of the 18 game
starts one leg missed (a star's close orbit, a settled star orbit and the
edge, to places round both on the far side of the pair), all 13 free starts
it missed, 6 close by a world -- in a median of 45 s, at worst 57, planned in
a median of 270 ms, at worst 530 (on a worker in the game), out to 0.98 of the
edge at the farthest; the turn onto the second leg at worst 13 deg a px at
zoom 1 (a corner is 20). SolveTest's real twins: 3,024 of 3,024 found (99.31%
with one leg). The 24 left were all close by a world coasting fast: in 23,
no burn at THRUST keeps the coast clear of a keep-out for a second (the one
where a burn did, seed 7 system 110, is FlightTest's residual). Points all
round the pair (12 bearings, two radii) and round the place found no more,
nor, there, a first leg that was that burn and its coast. Round one sun
too since Nov 10, where the target is behind the ship's motion: the points
are `FlightChain._turn_waypoints`' (docs/why/FlightChain.md).
```

Above `static func chain(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, hint: Vector2) -> FlightSolve.Result:` (`FlightChain.gd`):

```text
A FLIGHT IN TWO LEGS, in a twin, where one departure burn and one coast
reach nothing (the wider search too): its first leg aimed at a point in open
space (`FlightChain._waypoints`: a keep target at place -9, c that point), its second
leaving free off the first's coast CHAIN_PRE s before the first's arrival
burn would start, so the ship never stops there -- a coast, a burn that
turns it, a coast, the arrival. One Result, one set of samples SAMPLE apart
from the first's departure: drawn, previewed and flown as any other. Its
choice is the first leg's with `chain` {W, k, pre, c1, c2}, so the same
flight comes back (`FlightChain.chain_again`): the first leg rebuilt from c1 as any
flight is, the second then leaving from the very same state is rebuilt from
c2 as a free one is. The first found is kept; with a `hint` (an old flight's
point, tried first), the flight through it only while the first found
without it (a fresh plan's) arrives no sooner. Through the hint alone, a
flight in two legs looked for again where its legs no longer held stood
later than a fresh plan's (seed 31337 node 28, orbit9 -9 to keep 2, line-up
4, planned again 14 times: 243.82 against 242.54; the fifth review, Nov 1).
```

Above `static func chain_again(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, c: Dictionary) -> FlightSolve.Result:` (`FlightChain.gd`):

```text
A FLIGHT IN TWO LEGS FROM ITS CHOICE: the first leg from c1 (rebuilt as any
flight is while its departure is ahead, else searched from it), the second
off it -- at the very sample it left from when the first is the same flight,
so it is rebuilt too, else as long before the first's arrival burn -- from
c2. Kept while it costs about what it did (WARM_K, WARM_ADD); else null, and
the caller looks again. Kept, `solve` holds it against a fresh plan of one
leg (`_sooner_of`).
```

## Time weight

Above `const TIME_W := 16.0`:

```text
px/s of engine work one second of flight is worth: Jon's dial. Ruling 21
(Nov 1, "Flight length: C", picked from the Autopilot Flight Time page, eight
flights played at game speed) set it to 16 with T_CAP 16. As built (ruling
20) it was 0.5 to a cap of 30 s, and a flight from place to place with one
sun took a median of 23.5 s from the click to settled (FlightTest), the v2
pick (B: 1, to 23 s) 18.9 s, and today's autopilot on main 6.9 s. At C it
takes 10.8 s, 14.9 s for 9 in 10, at worst 20; every game start 13.4 s with
one sun and 14.0 s in a twin. The engine works harder for it: a median of
157 px/s, where the as-built flight's was 91 (the study, Nov 1).
```

## As-built fallback

Above `const T_CAP_BACK := 30.0`:

```text
THE AS-BUILT SEARCH, behind C's (`_fallback`): ruling 20's dials, T_CAP_BACK
30 s at TIME_W_BACK 0.5, with its own conic guesses and FAR_T. C's dials
alone missed 10 of SolveTest's 12,648 flights that the as-built search finds
(9 in twins, most from a settled star orbit to a station). Where C's own
search finds nothing, this and the wider search at TIME_W both look and the
flight that arrives first is kept. The as-built search alone held C's
flights from the edge and settled star orbits to about 29 s, one game start
in five to eight, where the wider one found quicker; the wider one alone let
flights of up to 40 s stand where the as-built found one under 30. With
both, C misses none of those A finds, finds one A misses, and never arrives
after the as-built search's flight. A flight in two legs flies both by it,
so those keep the as-built length: 30 of 1,790 twin plans, a median of 47 s.
```

## Coast step

Above `const ETA := 0.15`:

```text
the coast's step: ETA of the nearest pull's dynamical time sqrt(r^3/GM),
clamped; a burn's steps at most H_BURN. Measured (SolveTest): at 0.1 and
0.25 s the drawn coast was within 0.013 px of a plain RK4 at SAMPLE; at 0.15
and 0.5 s within 0.08 px, in half the steps, the same flights found
```

## Ring departure burn

Above `const BACK_TURN := 0.25`:

```text
A RING DEPARTURE'S BURN is centred on its point (the ship comes off the
ring half a burn sooner) only as far back as the ring turns this much (rad):
further, the burn starts along a chord that dips inside the ring by about
rt theta^2 / 8, 2.3 px for a 1.2 s burn on a twin star's close orbit, which
is only 2 px outside its keep-out
```

## Integration budget

Above `const BUDGET := 140`:

```text
INTEGRATIONS A PLAN MAY TAKE: `_fly` flies no more past it, so a
refinement under way stops there too (the first build only checked it
between scan flights, and a plan took up to 144); the samples take one
more, and a warm start that is not kept gives the search a budget of its
own after it. A twin's flights are short and its search wide.
```

## Conic flight times

Above `const CONIC_TS := [6.0 * (T_CAP / T_CAP_BACK), 9.0 * (T_CAP / T_CAP_BACK), 6.0, 13.0 * (T_CAP / T_CAP_BACK), 9.0,`:

```text
THE CONIC GUESSES' FLIGHT TIMES (s): the as-built ones (CONIC_TS_BACK)
scaled to T_CAP, x 16/30 (3.2, 4.8, 6.93, 9.6, 12.8, 15.47), and beside them
the as-built ones under T_CAP (6, 9, 13). With the scaled ones alone, the
v2 pick (B) flew longer than the as-built search in about a fifth of game
starts (the review of Nov 1); with both, C does in 1 to 2%, by at most 6 s
```

## Eased departure burn

Above `const R_BURN := 14.0`:

```text
THE DEPARTURE BURN IS EASED WHILE THE SHIP IS SLOW (Jon: "why are there
sharp angles on some of the trajectories?"): a ship at speed v turned by a
pull a goes round a curve of v^2 / a, so out of a settled star orbit at 14 to
23 px/s a burn at THRUST across its motion bent it round 5 to 13 px, drawn at
zoom 1 as tight as 0.7 px (the plane's slant shortens a curve seen end on to
0.38^2 of it): FlightTest counted a corner, over 20 deg a px, in 3 to 7 of a
system's flights from a star orbit (Oct 31). So the pull is at most v^2 /
R_BURN (a curve of R_BURN px at the least), never under P_MIN, and THRUST from
about 24 px/s. The work is the same; the burn takes longer. Out of a
settled star orbit only (a ring round a fixed point, place -9: the edge as
arrived is one), whose pace is 14 to 40 px/s: a world's ring and a star's
close orbit leave at 35 and 45, and eased there a burn deep in a star's well
was too weak to climb out (SolveTest's star-to-star flights in the hand twins
found 79%, against 90%); alongside, the ship leaves all but at rest and its
first curve is under a pixel; free, only a harness leaves (SolveTest's free
starts at 10 to 40 px/s were found 1.7% less often eased, Oct 31).
```

## Cusp tests

Above `const V_CUSP := 5.0`:

```text
A BURN THAT ALL BUT STOPS THE SHIP AND TURNS IT draws a cusp however gently
it pulls: its speed (on the plane, where it is drawn) dipping under this
mid-burn, below where it starts and ends, so the motion swings round a
point tighter than R_BURN at P_MIN. Such a departure out of a ring (a
world's, a star's close orbit or a settled star orbit) or an arrival is not
flown: the search finds another. (At 12 px/s,
before the burn was eased, it cut SolveTest's flights found from 99.97% to
96.2% one-star, Oct 31.)
```

Above `const CUSP_PAD := 0.5`:

```text
and turned down this much above it (px/s): the burn's speed read here from
the coast's nodes and a few points of the arrival, SolveTest's from every
sample (one flight of 3,061 read just under 5 there and passed here, Oct 31)
```

Above `const CUSP_IN := 0.25`:

```text
A CUSP IS WHERE THE MOTION ALL BUT STOPS MID-BURN AND TURNS ROUND: its least
speed inside the burn (CUSP_IN under both its ends) and the motion turned by
more than CUSP_TURN while slower than V_SLOW. It was a least speed 2 px/s
under both ends, which let through a departure out of a star orbit at 15.5
px/s that burned down to 1.0 and left at 2.3 the other way: a turn of about
150 deg round a third of a pixel, 64 deg a px on screen at zoom 2
(FlightTest, seed 4242 system 104, Oct 31). A burn that only slows (its
least speed its end) still flies.
```

## Arrival draw limit

Above `const DRAW_TILT := 0.38`:

```text
AN ARRIVAL BURN IS NOT FLOWN where its curve as the map draws it at zoom 1
(`ShipFlight.TILT` 0.38: the plane's depth drawn at that) turns more than
DRAW_K rad a px: FlightTest's corner is 20 deg a px over 2 px, a curve 1.43
px across; this keeps 1.67.
```

## Sun a circle rides with

Above `var _dhs := -1`:

```text
THE SUN A CIRCLE RIDES WITH (ruling 23, the orbiting pair): the index in G
of the star the departure's / target's circle is centred on where that star
turns -- a world round one sun, a sun's close orbit, a settled orbit round
one sun -- or -1 for a centre that holds still at _dhx, _dhz (_thx, _thz).
Where it rides, _dhx (_thx) is the centre at t = 0, and `_dep_at` (`_tgt_at`)
reads the star where it is at t.
```

## Two-leg replans

Inside `solve()`, above `var t_us := Time.get_ticks_usec()`:

```text
A FLIGHT IN TWO LEGS DRAWN BEFORE: its own legs again while they hold,
else looked for afresh, its old point tried first (and kept only
while the first found without it arrives no sooner, `FlightChain.chain`).
Held, it is kept only while a fresh plan, of one leg or else of two,
finds none that arrives sooner (`_sooner_of`), the rule a flight the
fallback found is kept by. Against one leg alone, legs searched from
their old ones each time their departure went by stood later than
two found afresh: in the review's replan chains (the overlay's
preview, 30 s, 16 line-ups), 89 drawn plans more than 1 s later, at
worst 18.8 s (seed 4242 node 281, orbit9 -9 to keep 5, line-up 1:
139.8 kept where a fresh plan in two legs arrived 121.0; the fifth
review, Nov 1)
```

Inside `solve()`, above `var t_ua := Time.get_ticks_usec()`:

```text
A FLIGHT OF ONE LEG THAT TOOK OVER FROM ONE IN TWO (`_sooner_of`):
itself from its choice as any flight is (else one found afresh, and
where one leg finds nothing, two found afresh), beside the old legs
again (`FlightChain.chain_again`), the one that arrives first kept, the old
legs on a tie. Without them, the preview that went to one leg went
next, where one leg found nothing, to two found afresh, later than
its old legs flew (seed 31337 node 28, ring 1 to keep 5, line-up 10:
486.1 drawn where the old legs arrived 463.4, the review of Nov 1).
Two found afresh are a fresh plan's, not tried through the old
legs' point first: the old legs stand beside them already, and
through that point first, where the old legs no longer held, the
first found stood later than a fresh plan's (seed 7 node 143, ring
1 to keep 2, line-up 5: 291.63 where a fresh plan arrives 291.50;
seed 1999 node 150, star -1 to keep 2, line-up 1: 131.39 against
127.84; the fifth review, Nov 1). Where the old legs beat the one leg
planned again from its choice, they stand beside a fresh plan too, as
held legs do (`_sooner_of`): the one leg warmed from its choice can
arrive later than one found afresh, and the old legs were kept between
them (seed 4242 node 48, ring 2 to ring 3, line-up 1, CURVED, 15 s on:
47.00 s in two legs where a fresh plan of one flew 44.17; SolveTest on
G2's spiral worlds, Nov 10).
```

## Sooner of two plans

Above `static func _sooner_of(rc: Result, r1: Result) -> Result:`:

```text
A FLIGHT IN TWO LEGS HELD FROM ITS CHOICE (`FlightChain.chain_again`: rebuilt, or
searched from its legs) against another plan, r1 (a fresh plan, of one leg
as a first plan's is, else of two; or, from a flight of one leg that took
over from them, that flight planned again, else two legs found afresh): the one
that arrives first, the held legs where they arrive no later, and never a
flight that is not clean. Held on their cost alone, a preview in two legs
that began where one leg found nothing stayed in two legs while a fresh
flight of one arrived far sooner: of every SolveTest fallback flight from a
ring or alongside planned again 15 times as the overlay does, 63 steps (the
review of Nov 1), at worst 50.9 s in two legs where one leg flew 13.5 (twin
300, ring 2 to star -1, line-up 4). Only round a ring or alongside, the ship
still where the flight leaves from: free, it is on its way (or a harness's
free start), and the flight is as `FlightChain.chain_again` gives it. A flight of one
leg kept carries the held legs' choice as its `alt` (`solve`): the legs as
they were flown this time, so once their departure has gone by they are
searched again from the last search's legs, priced against its cost, and may
arrive later each time (seed 31337 node 28, ring 1 to keep 5, line-up 11:
483.95 to 516.62 over 7 replans, the review of Nov 1). That is kept: they
are taken only where they arrive sooner than the one leg, and held to the
arrival they had as one leg took over, or dropped once their departure went
by, the overlay's preview drew later than this, net, for 12 to 28 s of its
preview time in each sweep (16 line-ups, 30 s each, the fifth review), to
save a median of about 90 integrations a replan carrying them. Its
integrations are both plans'.
```

## Star orbit radius

Above `static func star_orbit_r(L: SystemLayout, p: int) -> float:`:

```text
THE RADIUS OF STAR p'S CLOSE ORBIT, ridden and arrived on (a ring's R and
rt). One star: 8 inside its ring, as `ShipFlight.orbit_r(-1)` rides it. A
twin's star: its rail (`star_rail_of`), 2 px outside the keep-out, since its
ring is only 4 px out and ring - 8 is inside the keep-out (for every twin
star of 1,710: none of 96 flights there was found, the planner review, Oct 30).
```

## Fallback flight rebuild

Inside `_solve()`, above `_b_J = INF`:

```text
A FLIGHT THE FALLBACK FOUND, REBUILT AS DRAWN, is kept by the rule it
is kept by warm (below): only while a fresh plan (its own budget)
finds none clean that arrives sooner. Rebuilt with no look, a preview of
the fallback's flight whose departure was still ahead held while a
fresh plan flew sooner: of every SolveTest fallback flight from a
ring or alongside planned again 15 times as the overlay does, 163
steps, at worst 7.9 s (twin 280, ring 0 to ring 2, line-up 11; the
review of Nov 1)
```

## Coast turn limit

Above `func _coast_tight() -> float:`:

```text
WHERE THE COAST FIRST TURNS TIGHTER THAN THE MAP CAN DRAW (DRAW_K at zoom
1), or INF; an arrival whose burn starts after it is not flown. A coast that
all but stops at the top of its climb and falls back turns there round a
fraction of a px: out of a settled star orbit, climbing to 1.0 px/s, it drew
66 deg a px at zoom 1 (FlightTest, seed 1999 system 226, Oct 31). Read on
each step's straight change of velocity, at its slowest.
```

## Burn turn limit

Above `func _burn_tight() -> bool:`:

```text
WHETHER THE DEPARTURE BURN JUST FLOWN OUT OF A RING TURNS TIGHTER THAN THE
MAP CAN DRAW (DRAW_K at zoom 1, as the coast and the arrival are held to):
the one part of a flight with no such check. Held to every departure out of
a ring (a world's, a star's close orbit, a settled star orbit) or a second
leg's, eased or not, since science (Phase 12, Nov 4) laid systems out anew:
out of a world's ring at 35 px/s a burn at THRUST slowed the ship to 13.5
and turned it, 28 deg a px at zoom 1 (FlightTest, seed 1999 system 234,
orbit 2 to 3: 10.68 s became 8.89), and to 10.5, 35 deg a px (seed 4242
system 297, orbit 2 to star B: 23.86 s became 12.71). Found and clean the
same in every sweep of both tests' full runs. Out of a settled orbit round a close
pair's balance point to star A's close orbit, a burn that dipped to 5.8 px/s,
over the cusp test's 5.5, bent round 4 px and drew 20 deg a px (FlightTest,
seed 4242 system 208, Nov 2); found without it, 14.55 s against 8.16, bent
round 20.7 px. In every system, one sun included (Jon, Nov 2, "Pair calls:
2Y"), so a one-sun flight it flags is no longer the one flown before this
branch. Out of a settled star orbit to world 1, seed 7 system 125 drew a
tight U-turn as it left the orbit, at zoom 1 and 2: 11.83 s became 13.70 s,
riding further round first. It changes 0 of 3888 SolveTest plans round one
sun, 3 of 4656 with a heavy giant, and 1 of 899 and 1 of 1162 FlightTest
flights (review 2).
```

## Arrival cusps

Above `func _arrival_cusps(te: float, ar: PackedFloat64Array) -> bool:`:

```text
Whether the arrival burn ending at te (`_arrival`'s [.., d, dxx, dxz, dux,
duz, ..]) draws a cusp: the coast's motion plus the burn's, sampled at 17
points, its least speed read between each two as well. The points alone are
1/16 of the burn apart, and a fast arrival's burn is long: from alongside a
station to world 0 (SolveTest, seed 4242 node 281, line-up 3, at ruling
21's C) a 6.2 s burn took the ship from 111 px/s down to 4.4 and out at
34.5, turned round 177 deg, and was flown, since the points either side of
its least speed, 0.39 s apart, read 7.5 and 6.4 px/s (Nov 1).
```

Inside `_arrival_cusps()`, above `var px := c[0] + Ax * tau * tau + Bx * tau * tau * tau`:

```text
A BURN TURNING THE SHIP TIGHTER THAN THE MAP CAN DRAW: its curve as
drawn at zoom 1 (the plane tilted, TILT), the stars' and the giant's
pull and the burn's together. Arriving at 19 px/s, a constant burn
at THRUST across the motion bent it round 9 px, seen end on 1.3 px
across: 22 deg a px (FlightTest, seed 4242 system 291, Oct 31).
(Alongside, the line ends where the ship stops: its last px and a
half, where it slows to the place's own crawl, is not a turn drawn)
```

Inside `_arrival_cusps()`, above `for j in 16:`:

```text
(between each two: the least speed on the straight change of velocity
across the step, as `_departure_cusps` reads a departure's. Alongside,
not where that least speed falls in the last px and a half left (the
step's two lefts, taken at its point), where the ship falls in with the
place's own crawl: it all but stops there and turns with the place, which
is no turn drawn. Read there, it lost 7 of SolveTest's 8,544 one-sun
and giant flights and flew 135 others another way (117 of them over
0.3 s longer), every one arriving alongside; and skipped only where a
step started in that last px and a half, the last step (from 1.5 to
4.5 px out, to the end) still read the crawl and turned down 9 giant
plans of 4,656 and 4 of FlightTest's 3,832 flights that are no cusp,
Nov 1)
```

Inside `_arrival_cusps()`, above `for j in 16:` (the first one, the tilted speed's least):

```text
THE TILTED CURVE BETWEEN TWO POINTS (Nov 8). Seen tilted, a burn's curve is
tightest where its speed across the screen is least: where the ship moves
up or down the screen, the plane's tilt squeezing that motion to 0.38. That
can fall between two of the 17 points. From world 2 to world 3 of seed 1999
system 103 (KAPPA BRINE-2, a giant, a game's start), at main's x12 pace with
science's layout, a 2.33 s arrival burn turned the ship 116 deg in 0.3 s at
54 px/s, drawn 28 deg a px at zoom 1. Over DRAW_K for 0.06 s, between points
0.146 s apart that read 0.14 and 0.10. So each step's least tilted speed,
on the straight change of velocity across it, is read too when it falls
inside the step, alongside's last px and a half left out as above.
```

## Coast integration

Above `func _integrate(td: float, x: float, z: float, vx: float, vz: float, dvx: float, dvz: float, t_end: float) -> void:`:

```text
THE FLIGHT FROM (x, z, vx, vz) AT td: a burn of (dvx, dvz) at THRUST, then the
coast, to t_now + T_CAP (or on past a broken keep-out for D2_MAX, or out of
the system). Fixed-step RK4 in scalars, the pull summed inline (two stars
and a giant at most take the fast path), each step's closest approach to
every keep-out on the cubic through its ends.
```

## Turning pair

Inside `_integrate()`, above `var spin := ns == 2 and G.pair_n != 0.0 and G.star_rad[0] != 0.0 and G.star_rad[1] != 0.0`:

```text
THE PAIR TURNS (ruling 23): both suns on their circle round the balance
point, read as the giant is at the step's start (carried from the last
step's end), middle and end; one cos and sin a place for both, since they
share one angle (MapGravity `star_ph`, their signed `star_rad` along the
line). A sun that holds still -- one alone, a pair held still -- is read
as it always was.
```

## Constant burn

Above `var _vg := 0.0`:

```text
THE RING POINT A CONSTANT-THRUST BURN WOULD END ON from the coast's state (r,
u) relative to the target at te, sense s, its pull pk: [radial mismatch g,
angle phi, burn length d]. A constant burn of length d ends at r_T, u_T
exactly when r_T - u_T d/2 = r - u d/2 (the virtual point q), and |r_T - u_T
d/2| is the same all round the ring, so phi follows from q's angle and g is
the miss. Into _vg, _vphi, _vd (it runs at every node near the target, so it
takes a few rounds of d, not the exact one: `_const_burn` is that).
```

Above `var _kd := 0.0`:

```text
THE CONSTANT BURN THAT ENDS ON THE RING AT te EXACTLY, from the coast's
state (r, u) relative to the target there, sense s. A constant pull a for d
seconds on top of the coast ends at r + a d^2/2, u + a d: on the ring at its
speed when r - u d/2 = R e(phi) - s V d/2 e'(phi), whose size is sqrt(R^2 +
V^2 d^2/4) all round, so d is a root of
  (|u|^2 - V^2)/4 d^2 - (r.u) d + |r|^2 - R^2 = 0
(the one nearest d_near) and phi follows from the angle. Into _kd, _kphi and
_ka, the pull |du| / d it takes; false when there is no root.
```

Above `func _te_for(te0: float, s: float, pk: float, d_near: float) -> float:`:

```text
WHERE THE ARRIVAL'S CONSTANT BURN PULLS pk EXACTLY: a secant on te from te0
(where the coast's virtual point crosses the ring's, found between nodes),
the pull falling as the arrival comes later. te0 when it finds none. Found
between nodes alone, the crossing left the burn up to some px off a
constant one, and the burn that held its pull then lasted three times as
long, pulling against its own change for the first third (the planner
review, Oct 30).
```

## Cubic burn

Above `static func cubic_burn(dxx: float, dxz: float, dux: float, duz: float, pk: float = FlightSolve.THRUST) -> PackedFloat64Array:` (`FlightMath.gd`):

```text
THE ARRIVAL BURN for a change of position (dxx, dxz) and velocity (dux, duz)
off the coast: P(tau) = A tau^2 + B tau^3 on top of the coast, A = 3 dx -
du d, B = du d - 2 dx; its pull (2A + 6B tau) / d^2 is linear, so at most
pk means at both ends. [d, engine work], d the least that holds, or empty
past 64 s. No burn that holds to pk changes the velocity by |du| in less
than |du| / pk; there, it holds only as a constant burn (dx = du d/2), and
just past it only in a window a few percent wide (one end's pull falls as
the burn lengthens and the other's rises), or not at all where the miss is
across the motion. So the least pull is looked for there first (to BURN_TOL
over), and only then further out, where the pull turns over: it first pulls
against du, then with it, from about three times as long. The first build
doubled its way out from 0.05 s and so always stepped over the window, and
every arrival burn lasted three times the least (the planner review).
```

Above `static func cubic_work(dxx: float, dxz: float, dux: float, duz: float, d: float) -> float:` (`FlightMath.gd`):

```text
THE CUBIC BURN'S ENGINE WORK, exactly: its pull p + q u (u 0 to 1) is linear,
and the integral of its size sqrt(A u^2 + 2 B u + C) is closed (Simpson on
four steps read 1.167 |du| for a burn whose pull passes through nothing,
against 1.25).
```

## Alongside arrival time

Above `func _te_near(kk: int, s: float) -> float:`:

```text
WHERE AN ARRIVAL ALONGSIDE (or a graze of a ring) IS BEST, between the nodes
round node kk: the time its virtual point passes closest to the spot (the
ring's virtual circle), golden section on the coast. Found only at a node, it
was up to half a step (some 25 px of the coast) off, and the burn made up
the rest.
```

## Fallback search

Above `func _fallback() -> void:`:

```text
NOTHING FOUND TO T_CAP: THE SOONER OF TWO. The as-built search to T_CAP_BACK
(`_search_back`) and the wider search to T_CAP_WIDE at TIME_W both look, a
budget each, and the flight that arrives first is kept. Where both find
nothing, the wider search again at TIME_W_BACK, with FAR_T_BACK (its scan
reads it). (The study, Nov 1: the wider search first let flights of up to
40 s stand where the as-built one found one under 30; the as-built one first
held flights from the edge and settled star orbits to about 29 s, where the
wider one found quicker ones in one game start in five to eight.)
```

## Fresh search samples

Above `func _build_fresh() -> Result:`:

```text
A FRESH SEARCH'S FLIGHT AS SAMPLES (`_build`). Where the search to T_CAP
found it and its samples cut a keep-out (the search priced it clear; the
samples are checked again once built), the fallback looks as it would had
nothing been found, and its flight is kept if it is clean.
Without it, a harness's free start at seed 4242 system 291 (FlightTest, to
place 1, one sun) kept an 11.8 s flight 0.72 px into a keep-out, found and
not clean, and the fallback never ran; with it, the wider search's clean
flight of 18.4 s (Nov 1).
```

## Departure scan

Above `func _scan(pass_i: int) -> PackedFloat64Array:`:

```text
DEPARTURES TO FLY AS THEY ARE, pass 0, 1 or 2: SCAN_HEAD headings, the
first toward where the target is, each at SCAN_SPEED times the departure's
own speed scale (its ring's, or its place's motion plus SCAN_KICK px/s).
Round a ring each leaves from the point whose motion runs along it (or the
end of the ride's reach nearer it), so a heading the ride cannot bring
round leaves across the ring's motion. The first build left only along the
ring's motion from points across the ride's reach, which a ride held to
THRUST no longer makes a full lap, and its departures out of a twin star's
well were too slow for places round both (the planner review, Oct 30).
Flat: [ux, uz, has_fix, a_fix] each.
```

Inside `_scan()`, above `var toward := _wide and _dplace == -9`:

```text
THE WIDER SCAN OUT OF A SETTLED STAR ORBIT looks toward the target: its
ride all but stands still (a twin's far out goes round at 11 to 16
px/s), so the ring's own way is no guide, and headings a full turn apart
by 45 deg passed a target 2,000 px off by hundreds of px
```

## Far target speed

Above `func _far_need() -> float:`:

```text
THE SPEED A FLIGHT OUT OF A TWIN STAR'S WELL TO A PLACE ROUND BOTH TAKES
(px/s, relative to the place it leaves), or 0 for any other flight: what
climbing out to it in about FAR_T takes, vis-viva about the star with the
pair's whole pull (roughly what the ship feels on the way), less the
place's own motion round the star. Such flights were 84% of the first
build's misses in real twins, from a world's ring or a star's close orbit
to the stations, belts, hulks and worlds round both; a brute scan flew them
at 60 to 110 px/s off the ring (the planner review, Oct 30). So their scan
speeds bracket this (FAR_SPEED), not the ring's own. The as-built search
climbs out in FAR_T_BACK.
```

## Conic guesses

Above `func _seeds() -> PackedFloat64Array:`:

```text
CONIC GUESSES, cheapest first, priced from where the ship can really leave.
Stage 1 from the place's centre now (a world's ring is small beside the
flight; round a star, from two points on its ring), every length in CONIC_TS
and both ways round; stage 2 the CONIC_KEEP cheapest again from the very
point and moment it would leave, aimed at the target ring's tangent point.
Flat: [price, ux, uz, T, way, s, has_fix, a_fix, te] each.
A CONIC ABOUT A SUN OF A TURNING PAIR is solved in that sun's own frame
(`_lam`): its centre is the sun's index (a centre's fourth number; -1 a
centre that holds still), and whether the target is the sun it is about is
asked by that index, not by place, since the sun at the arrival is not
where it was when the conic was laid (`_aims`).
```

## Conic aim

Above `func _aims(te: float, p1x: float, p1z: float, cx: float, cz: float, way: float, ck: int = -1) -> PackedFloat64Array:`:

```text
Where a conic aims at te: the target's centre (or its spot alongside); to
a star's close orbit round this centre, the ring point most of a half lap on.
ck: the turning sun the conic is about (-1 a centre that holds still). That
sun is asked by index (THE CONIC'S "OWN STAR" AIM, ruling 23): the sun at te
is not where the centre was laid (by some px in a flight), so asked by place
the aim went to the sun's centre, through its keep-out, not round its ring.
The ring point is round where the sun is at te, most of a half lap on from p1
as seen from the centre now.
```

## Conic about a turning sun

Above `func _lam(ck: int, cx: float, cz: float, gm: float, t1: float, p1x: float, p1z: float, p2x: float, p2z: float, T: float, way: float) -> PackedFloat64Array:`:

```text
THE CONIC ABOUT CENTRE ck from p1 at t1 to p2 T later: [v1x, v1z, v2x,
v2z] on the plane, or empty. ck -1: about the fixed (cx, cz), as
`_lambert_gm`. ck a turning sun's index: solved in that sun's own frame --
p1 from where it is at t1, p2 from where it is at t1 + T -- and its motion
then added back to each end (the sun's own pull round the balance point,
some thousandths of a px/s^2, is left out: these are guesses Newton refines).
```

## Same flight check

Above `func _same_flight(c: Dictionary) -> bool:`:

```text
Whether a choice was made for this very flight: the same departure (kind,
place, ring or spot, centre, the sun it rides with) and the same target
(kind, place, ring and speed or spot, centre, sun), its sense one the target
allows. The first build checked only the places and the ring, so a choice
made for another radius, spot or sense was rebuilt as it was (the planner
review, Oct 30). A settled orbit round a sun of a turning pair is a -9
circle whose centre moves: it is the same flight by its sun (`dhs`), its
centre at t = 0 being that sun's, not by where the ship saw the sun.
```

## Fast transfers

Above `const HOLD_MAP := 0.4`:

```text
THE FAST TRANSFERS (Jon, Nov 4-5: "almost 4 times slower than feels good",
"Why is transferring between planets a straight line?"): every flight is
solved on its own clock, tau = pace x map time, through a copy of the system
whose bodies move pace times slower (`MapGravity.paced`), at today's THRUST,
gravity and every other dial, then played back pace times faster (`solve`'s
`pace`, `Result.to_map`): the same path, its pulls pace^2 stronger on the
map, and the place met where it really is. The ring speeds the ship leaves
and arrives at stay the map's own (RAIL_V 35 on the map, RAIL_V / pace in
tau). Two paths (`DisplaySettings.autopilot`, AUTOPILOT: DIRECT . CURVED):
DIRECT is ruling 21's C search (TIME_W 16 to T_CAP 16) at pace 4, about 11 s
of tau played in about 2.8 s; CURVED is the as-built search (ruling 20's
TIME_W_BACK 0.5 to T_CAP_BACK 30, its conic times and FAR_T_BACK) as the
first look with its arc (`CURVED_ARC`, WIDE: Jon, Nov 7, "1C") at pace 8
(Nov 5 "Lets do 4X for both", then Nov 7 "double the speed for the wide"):
slow, cheap flights that bend round the stars, about 48 s of tau played in
about 6 s. Both keep the wider search and the flight in two legs behind them.
ALONGSIDE, the hold before leaving (KEEP_HOLD in tau) is at least HOLD_MAP
of map time: KEEP_HOLD 1 s of tau is an eighth of a second at pace 8.
```

## Ring speeds on the flight's clock

Above `const RING_TAU := 60.0`:

```text
THE RING SPEEDS ON THE FLIGHT'S CLOCK. A ring's speed divided by the pace
left the ship all but at rest in tau (a star's close orbit, 45 px/s on the
map, 5.6 at pace 8, deep in a well whose gravity the flight's clock leaves
as it is), and from a star's close orbit or to one the solver found a
third of the flights or none (SolveTest, Nov 5: twins 50%, close pairs
62%, at a floor of 20 px/s; 100% at 60). So a ring is left and arrived on
in tau at its speed / pace but never under RING_TAU px/s, nor over its own
speed: every ring the game has (worlds' 35 px/s, stars' 45, settled star
orbits' 13 to 50) at its own speed. On the map the ship spins up round its
ring to pace times that before it leaves (`ShipFlight._ride_shape`: it
rides at the ring's own speed, spins up over SPIN_UP s and whirls round at
the departure's for the ride's last part) and spins down onto the ring's
own speed as it arrives (`ShipFlight.start_rail`'s spin, SPIN_S).
`-- ringtau=X` sets it for a harness (0: speed / pace, as first built).
```

## Spin-up

Above `const SPIN_UP := 0.3`:

```text
THE SPIN-UP's length on the map (s): the ship's rate eased from its ring's
own to the departure's (`ShipFlight._ride_shape`). The ride on the flight's
clock starts with it (`dep.w0`, the ring's own rate there, and `dep.spin`,
SPIN_UP x pace tau-s: a smoothstep from w0 to w), so it lasts at least the
spin and goes (w - w0) spin / 2 less far round: a flight left at once, as
the solver first had it, could not be flown on the map, where the ship is
still at its ring's own rate (IOTA TALLOW GATE V to IV, DIRECT: every plan
made for a moment just ahead untakeable, and the ship put there). The spin
is the clock's hand-off, not engine work, and is not priced. 0.3 (Jon,
Nov 7, "2B", the softer spin, filmed beside 0.15). It was 0.15 from the
code review, Nov 5: 0.3 is the shortest ride before a departure and most
of the forced near offset in `_aligned` (its push at 0.15 about 2450
px/s^2 against the 7680 `ShipFlight.SPIN_PUSH_K` allows). Its measured
cost at 0.3: DIRECT's retarget move 23.9 px (17.4 at 0.15; limit 16).
`-- spinup=S` sets it for a harness.
```

## Eased last look

Inside `_fresh()`, above `if _b_J == INF and _kp > 1.0 and _dk == 0 and _leg == 0 and not _ease:`:

```text
EASED, AS A LAST LOOK, out of a ring on a flight's own clock: every
departure burn that hooks tighter than the map draws is turned down
(`_burn_tight`), and at one moment of seed 4242 system 50's giant ring 2
to world 0 nothing else was found, by CURVED with a spin-up of 0.15 s and
by DIRECT with 0.3 (FlightTest, Nov 5: 95 of 96, today's planner flying
it at today's speed). Then the burn eases while the ship is slow (R_BURN,
as out of a settled star orbit), so it bends round 14 px at the least, and
the choice says so (`ez`) for it to be rebuilt the same. Not first: eased,
a burn deep in a star's well was too weak to climb out (`R_BURN`).
```

## Arc reward

Above `func _arc_of(on: bool, k: int) -> float:`:

```text
The arc reward for arriving at node k (`_sweeps` read first): `_arcw` px/s
a radian swept (to `_aimsw`) and `_arcb` a unit of bend (to `_aim`), none
where the coast dips nearer the star than `_dip` of the nearer of its two
ends (a fall past the star, not an arc round it), nor where it swings out
past the map's edge (`_arc_out`: FlightTest's flights from the far side,
Nov 5, ran 38 px past it for the bend).
```

## Departure burns turned down

Inside `_fly()`, above `if not ((_dk == 0 or _leg == 2) and (_departure_cusps() or _burn_tight())) and not (_ease and _burn_tight()):`:

```text
(a departure burn that swings the ship round a point is not flown: `V_CUSP`;
nor an eased one the map would draw as a hook, `_burn_tight`, nor one out
of a ring on a flight's own clock: a burn 127 to 150 deg against the
ring's motion hooked round about 6 px, three game starts' corners at pace
4 and 8 that main never flew (the code review, Nov 5: seed 4242 systems
50 and 231). Not alongside: a burn from rest beside a slow station reads
as tight and every flight from there was put there)

Merged with science (Nov 8): science holds every departure out of a ring
or a second leg's to `_burn_tight`, eased or not, which covers main's
ring-on-the-flight's-clock case; the eased check stays as main had it.
A second leg's burn alongside is held to it too, as science had it.
```

## Solve

Above `static func solve(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary = {}, opts: Dictionary = {}) -> Result:`:

```text
THE FLIGHT from `dep` to `tgt` at map time t (see the head of this file).
In a twin, where nothing is found, a flight in two legs (`FlightChain.chain`).
THE FLIGHT, on the map: dep and tgt in map units, t map time, `opts`
{path: &"direct" | &"curved", pace: k} (`ShipFlight.flight_opts`); none is
today's flight, DIRECT at pace 1, to the last digit. `grav` the system's
MapGravity (at any pace: `paced(k)` is taken, a copy held already at k is
used as it is). The search runs on the flight's own clock (tau = k t, from
0, so a choice made at one moment is read at the next): the ring's and a
free start's speed / k, the target's ring speed / k. The Result comes back
on the map's clock (`Result.to_map`) unless opts.tau. A `prefer` made on
another path or pace is not read.
```

## Solve pace and cusp

Above `var _kp := 1.0`:

```text
THE PACE A FLIGHT IS SOLVED AT (`solve`), and the eased burn's least pull
on its clock (P_MIN over the pace). THE CUSP'S SPEEDS (V_CUSP, V_SLOW,
CUSP_PAD, CUSP_IN) ARE NOT SCALED: a cusp is the burn's turn radius, v^2 / a,
which the flight's clock leaves as it is (speeds / k, pulls / k^2), so the
limits that turn one down at pace 1 turn the same drawn hook down at any
pace. Divided by the pace (as first built, when the rings in tau were their
speed / pace and a settled orbit's 13 px/s at the edge was 1.6), the
smallest radius turned down was 64 times tighter at pace 8 (the code
review, Nov 5); RING_TAU put the rings back at their own speeds.
```

## Curved arc

Above `const CURVED_ARC := {`:

```text
CURVED'S ARC (Jon, Nov 5: "I was kinda expecting the curved to have more
of a bend... it still looks more like a direct path"): CURVED's first look
is the as-built search with these dials in place of T_CAP_BACK and
TIME_W_BACK: `cap` its time cap (tau-s), `tw` its time weight, and a reward
that takes off the cost `bend` px/s for each unit of the coast's bend
(`_bend_to`: the farthest it strays from the straight line between where it
leaves and where it arrives, over that line) up to `aim`, so the cheapest
flight that bends that much is taken, and none past it (a loop is not
worth more than an arc). None where the coast dips nearer the star than
`dip` of the nearer of its ends (`_arc_reward`): rewarded alone, the cheap
bent flight was a fall past the star and back out, a hairpin, not an arc
round it. (`arc` would pay a radian of sweep round the star instead, to
`aimsw`: the sweep the short way is the line-up's, so it bought only those
falls and loops the long way round. Neither TIME_W nor the cap alone bent
a flight: at TIME_W_BACK the cheapest flight is already near the least
work.) Its conic guesses run on past CONIC_TS_BACK to the cap (`_arc_ts`),
and each guess is priced with the reward on its two-body coast
(`_conic_arc`). THE ARC LOOK after it (`_arc_look`, Nov 7): that search
refines only its cheapest guess and keeps the first flight it finds, and
with the reward on, its cheapest guesses were long coasts that fall into a
keep-out the two-body conic does not see (out of a giant's well, into the
star), so a level's flight bent less than the level below's (seed 1999
ALPHA TALLOW III to I: mild 0.346, strong and wide 0.085). So `keep` guesses
ranked by plain cost and priced with the reward from where the ship really
leaves, the first `ref` of them refined on a budget of their own (a guess
that fails does so on its first flight), and the cheaper flight of the two
looks kept, the look's only where it bends ARC_GAIN more. No reward for a
coast that turns more than `tmax` degrees (a loop: the look found flights
of 430 deg). `bend` 800 (was 400): at 400 the steeper bend did not pay its
work and strong flew mild's flight. CaseScan, six seeds' world-to-world
flights, 504 a level: flights bent under 0.1 were 20 to 24% of each level,
now 5 to 6%. One dial picks the level
(`CURVED_ARC_LEVEL`; `-- arc=mild|strong|wide` for a harness, `arc_cap=`
`arc_tw=` `arc_b=` `arc_aim=` `arc_dip=` `arc_w=` `arc_sw=` `arc_ref=`
(0: no arc look) `arc_keep=` `arc_tmax=` `arc_s=` `arc_hook=` `arc_loop=`
`arc_wob=` to try others). A flight in two
legs keeps the as-built dials. A bend takes time (it grows with the flight's
own seconds squared), so each level flies longer on the map than the
as-built search.
THE SHAPE'S RULES (Nov 7, the review of the arc look): the bend rewarded is
the farther side's less `s` times the nearer side's (an S) and `hook` times
how far the coast runs on past either end (a hook: p75's flights passed the
target and turned back), and a coast that turns more than `tmax` costs
`loop` px/s more (with only its reward taken away, 48 of 690 FlightTest
flights still turned past 240 deg and 3 past 360). The look's flight is kept
by its bend as rewarded, uncapped (`_arc_look`; a capped reward kept any
mild first look already bent 0.13). CaseScan, six seeds, 504
world-to-world flights a level (mild / strong / wide): bend median 0.233 /
0.297 / 0.396, hooks over 0.05 2.2 / 2.2 / 7.5% (strong was 11.1%), none
turning past 300 deg (was 0.6%), seconds median 9.7 / 10.7 / 12.2. The
sweep round the star is the worlds' own line-up (median 83 deg at every
level); wide takes the long way round, a half orbit, where the target is
far enough ahead (a third of its flights sweep 120 deg or more, the 90th
percentile 221). Not kept: wide's aim at a half ellipse's own bend, 0.5
(sqrt(r1 r2) / (r1 + r2)): 0.409 median, but on the headline case it bought
a long coast past the target and an arrival burn that drags back (a hump
the coast's own shape does not see); `wob` (px/s a radian the coast turns
back on itself) at 100 and 200 left that flight as it was and made 3 to 5%
more flights flat (under 0.1).
```

## Warm slack curved

Above `const WARM_K_CURVED := 0.25`:

```text
CURVED's (`_slack`): its search prices a second at TIME_W_BACK, so flights
of near one cost bend round the stars very differently, and a preview
planned again as the ship rode its ring jumped between them (the code
review, Nov 5: the drawn line's biggest move in half a second, a median
41.9 px against DIRECT's 16.8 and today's 8.1). `-- warmk=X` sets it for a
harness.
```
