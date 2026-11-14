The reasoning behind `tkg/scripts/sim/SolveTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Solve sweeps

Above `const SEEDS := [4242, 7, 1999, 31337]`:

```text
THE AUTOPILOT'S SOLVED FLIGHTS (ruling 20, Oct 30), planned and measured:
  godot --headless --path . -- sheet=SolveTest [systems=N] [lineups=N] [twins=N]
    [twinlineups=N] [worker=N] [only=one|giant|twin|rtwin|rclose|phase|proto] [short]
    [shard=K/N] [shapes=<jsonl>]
`shard=K/N`: every Nth case from the Kth (`Harness.mine`), the pair-phase
sweep's among them, the rest of the run (the bench, the prototype's flight,
the conic's aim) in shard 1; the shares of a sweep and of the replans are
summed across the shards by `ShardSum`.
`short`: the gate's run, every sweep at fewer systems and line-ups
(systems=1 lineups=4 twins=1 twinlineups=3 worker=100; the phase sweep at
PHASES_SHORT angles of two pairs).
THE TWO PATHS (the fast transfers, Nov 5: AUTOPILOT DIRECT . CURVED,
`FlightSolve.solve`'s opts): `path=direct|curved|both` (both unless asked)
and `pace=K` (each path's own `ShipFlight.FLIGHT_PACE`, DIRECT 4 and CURVED
4, unless asked). Every case is built on the map as before and then put on
the flight's own clock, tau = pace x map time (its ring's and a free start's
speed / pace, the target's ring speed / pace, the system as
`MapGravity.paced`), and every check below reads it there, the layout's own
Body read at tau / pace (`centre`): the same thresholds hold in tau. Each
sweep is judged per path (its name with " curved" after it for CURVED).
`path=direct pace=1` is today's run, number for number. Each path prints
its flights' bend (the farthest a flight strays from the straight line
between its ends, over that line) and its coast's whole turn, and CURVED's
median bend must be at least BEND_MARGIN times DIRECT's where both ran.
`FlightSolve` from every start to every place, at line-ups (map times), in
four sweeps:
  one    real one-star systems from systemtest's four seeds (SYSTEM, PULSAR
         and STATION nodes, N of each seed, those with a giant first), the
         giant pulling nothing;
  giant  the same systems' giants set by hand to 1/10 and 1/4 of the star;
  rtwin  the layout's own two-star systems: per seed the `twins` with the
         most bodies (each SYSTEM node asked for two suns, as `-- twin=all`
         does), their giants as rolled, each laid out a WIDE pair. None until
         the layout makes twins: the sweep says so and is not judged;
  rclose the same systems laid out as CLOSE PAIRS (Jon, Nov 1, "Binary
         kinds: close:B"; `SystemLayout.close_force`), every body round both
         suns 150 to 170 px apart, per seed the `twins` with the most bodies;
  twin   two-star systems built by hand to the prototype's geometry (stars
         280 px apart, A 0.55 of the pull, world a 80 px round A and b 70 px
         round B with 38.4 px rings, c round both at 680 px with a 70.4 px
         ring) and the same at 300 and 380 px apart, each star's keep-out,
         close orbit and ring as the layout's ladder sets them. Its worlds
         round one star sit at 0.98 of the steady limit, past the layout's
         0.90, with rings twice the layout's: the prototype's case, not the
         game's (rtwin is that);
  phase  THE PAIR-PHASE SWEEP (ruling 23, the orbiting pair; the review of
         the plan, Nov 1): the busiest wide pair of seeds 7 and 4242 and the
         busiest close pair of seed 7, each planned at PHASES map times a full
         lap of the pair apart (whatever its speed, `-- pair=K`), so every
         angle the suns stand at is flown, and from a settled orbit round
         each sun (a -9 circle riding with it, `host`) beside the starts
         above. The twin sweeps' line-ups (40 s on, 37 s apart) see the pair
         turn a sixth of a lap at the most in a wide pair.
Every two-star sweep's pair turns as the game's does (`SystemLayout.pair_speed`;
`-- pair=0` holds it still as before ruling 23).
Starts: each world's ring, each star's close orbit, a settled star orbit
(round the star, or round both stars' balance point: a ring round a fixed
point, where every visit's ship arrives, `ShipFlight.setup`), alongside a
station, belt, hulk or contact, and flying free. Targets: each world's ring (either
way round), each star's close orbit, each station, belt, hulk and contact.
For each plan: found; clean (every keep-out held along the samples);
starts where the ship is (on its ring at the departure, at the ring's own
motion); lands (the last sample on the ring at ring speed, or alongside at
the place's motion, within LAND_PX and LAND_V, the place where the layout's
own Body has it, not MapGravity's copy); its pull at most THRUST in a burn
and none on the coast (from the samples, every SPAN); the ride's phasing
push at most THRUST; engine work, time, integrations and milliseconds.
A sample of plans flown again at SAMPLE by plain RK4 through
`MapGravity.acc` (the physics; the departure burn eased while slow
wherever the solver eased it, a settled orbit's or a choice found eased,
`ez`: G2's seed 4242 node 22, ring 0 to keep 4, line-up 5, an eased last
look, strayed 838.8 px flown at full pull, 0.13 eased, Nov 10); rebuilt
from their own choice (the same samples bit for bit, now, half a second
on round a ring, and half a second on alongside, unless a flight the
fallback found gave way to a fresh one arriving sooner); planned again 3 s on with the old choice (the overlay's
preview in orbit), every one found and none kept that a fresh search beats
by more than the warm slack, nor a flight the fallback found, rebuilt or
warm, where a fresh plan arrives sooner; flights in two legs planned again
as the overlay does, none kept in two legs where a fresh plan (of one leg,
else of two) arrives sooner, nor any flight later than its old legs flown
again; and every
plan of the first `worker` cases solved again on WorkerThreadPool (the same
results). Also the prototype's a-to-b flight at its best line-up, and the
conic's "own star" aim by the sun's index where the pair turns (`_aim_check`).
PASS: found and clean in at least 99% of each sweep (DESIGN), but 97% of
the hand twins, whose geometry the layout never builds: their worlds round
one star sit at 0.98 of the steady limit (the layout's at most 0.90), their
rings twice the layout's reach the star's close orbit, and two of the three
pairs are closer than the layout's 300 px; flights between their stars'
close orbits, 2 px outside the keep-out as the layout puts them, are the
misses (65 of 72 found). The pair-phase sweep is held to 99%, as the
layout's own twins are. Every found plan starting and landing, no burn in
it swinging the ship round a point (`FlightSolve.V_CUSP`, read off its
samples), every replay and worker result the same. Planning time is measured and judged in
the log (median 25 ms, worst 150 ms: DESIGN), not failed on: this Mac's load
varies.
```

## Phase sweep

Above `const PHASES := 8`:

```text
the pair-phase sweep's angles round a lap (the review of the plan: 8), and
in `short` (the gate's run) PHASES_SHORT of them, for the close pair of seed
7 and the wide one of seed 4242 only: at full size the sweep took the gate's
run from about 170 s to 370 s alone, past its 300 s limit (review 1)
```

## Two leg replans

Above `const TWO_PINS := [`:

```text
[system label's head, start, target, line-up]: real-twin flights past the
line-ups SolveTest plans by default, planned again with the flights in two
legs (`_replans`) wherever their system is in the run. On 9875260b each,
gone to one leg, went next to two legs found afresh, later than its old
legs flew: 16.0 s and 6.6 s (twinlineups=12 over every two-leg flight from
a ring or alongside planned again 15 times: 5 such steps, none here)
```

## Hand twins

Above `static func twin_layout(sep: float, pha: float = 4.584536085992015, phb: float = 3.7905025599699775, phc: float = 0.0) -> SystemLayout:`:

```text
A TWO-STAR SYSTEM BY HAND, the prototype's geometry scaled to `sep`: star
A (0.55) at the origin, B at (sep, 0), world a round A and b round B on the
prototype's small-rock rings, c round both. Each star's keep-out, close
orbit and ring as the layout's ladder sets them (`SystemLayout._twin_ladder`
on the LAYOUT branch): the keep-out the larger of r + 10 and the drawn sun
at the opening zoom + 6, the rail (the close orbit ridden and arrived on) 2
px outside it, the ring 2 px further.
```

## Settled orbit

Above `func _settled_round(L: SystemLayout, G: MapGravity, st: Array, t: float, lu: int, si: int, ti: int) -> Dictionary:`:

```text
A SETTLED ORBIT ROUND ONE SUN (start "orbitS", star st[1]), as
`ShipFlight._dep_of` hands it over: a -9 circle whose host is the sun, so it
rides with a turning one (c, where the sun is now, is not read). Inside 0.9
of the sun's steady zone (`ShipFlight._zone`), from 12 px outside its close
orbit, at the sun's own settled pace (STAR_PACE times Kepler for its share), w for the
worlds' way round (the case turns it); clear of everything where it starts.
Empty for any other start, or where the zone has no room (a close pair).
```

## Clean check

Inside `_report()`, above `var own := [int(c.dep.get("place", -9)), int(c.tgt.get("place", -9))]`:

```text
CLEAN AS MAPGRAVITY HAS IT, not on the solver's word (`r.clean`): the
flight's own samples against every keep-out where it stands at each
sample's time. The solver's keep-out reads (`_sun_cs`) taken at the
plan's start passed this sweep with 16 plans 9 px inside (review 2)
(the departure's and the target's own keep-outs are the solver's to
keep to their rings, `FlightSolve._setup`: left out, every sun's in)
```

## Replays

Above `func _replays() -> void:`:

```text
REBUILT FROM ITS OWN CHOICE: every 5th found plan, at once; round a ring
(its departure still 0.6 s or more ahead, not phasing) half a second on with
the ship ridden on round; alongside, half a second on (the ship holding
there): the very same samples, or, for a flight the fallback found, a fresh
plan of one leg, clean, that arrives sooner (`_fell_sooner`: the rule such
a flight is kept by, rebuilt or warm).
```

Above `static func _fell_sooner(r: FlightSolve.Result, r2: FlightSolve.Result) -> bool:`:

```text
A FLIGHT THE FALLBACK FOUND (r, its cap past T_CAP) that, rebuilt from its
choice, gave way to a fresh plan of one leg, clean and arriving sooner (r2):
the rule it is kept by (`FlightSolve._solve`), so the drawn flight changes.
AND A FLIGHT IN TWO LEGS (`FlightChain.chain`) that gave way to a fresh
plan, of one leg or two, clean and arriving sooner: held round a ring or
alongside, it is kept only while none does (`FlightSolve._sooner_of`). Not
met here until stations were halved on Nov 3 and seed 7 node 199 came into
the phase sweep: orbitS -4 to keep 4, line-up 3, two legs to 544.32, half a
second on a fresh plan to 540.71.
```

## Replans

Above `func _replans() -> void:`:

```text
THE PREVIEW IN ORBIT, PLANNED AGAIN 3 s ON WITH ITS OLD CHOICE (the overlay
does this every 3 s): every 7th found ring plan, the ship ridden on round.
Its departure has often gone by, and on a ring of over about 50 px the ride
no longer reaches it, so the old choice is warm-started (the first build's
SCRIPT ERROR was here). Every one must be found where a fresh search finds
one, and a flight of C's own kept warm may cost no more than a fresh
search's plus the warm slack, or than its own old cost plus the slack, all
at TIME_W (an as-built flight's seconds at TIME_W_BACK cost 32 times less:
read at the two weights, the review's previews planned again 15 times had
14 kept flights past it, 13 arriving sooner than the fresh plan and the
other costing less at TIME_W). (One still ahead is rebuilt as drawn, its
ride phasing harder over the lead left, within THRUST: the drawn flight is
the flown one, at up to about 22 px/s more.) And no flight the fallback
found (its cap past T_CAP) is kept warm where a fresh plan arrives sooner:
kept on its own cost, 55 of the 95 kept were, by up to 7.5 s; with C's own
search alone looking beside it, 35 of 75, 5 of them the as-built search's
(the reviews of Nov 1); nor rebuilt as drawn, where a fresh plan beside it
is clean (9875260b kept 6 of 54 so, one at seed 1999 node 304, ring 3 to
keep 5, line-up 2: 21.0 s against 15.6). And every flight in two legs
(`FlightChain.chain`) from a ring or alongside, planned again as the
overlay does TWO_STEPS times (every 3 s round a world's ring or a star's
close orbit, every second round a settled star orbit or alongside), each
from the last one's choice: none
kept in two legs where a fresh plan of one leg arrives sooner. Held on their
own cost (6e6e563c), the full run's 20 such flights, planned again 15 times,
kept two legs 105 times where one leg flew sooner, by up to 41.4 s (seed
1999 node 150, star -1 to keep 2, line-up 1: 51.4 s in two legs against
10.0 in one); planned again TWO_STEPS times, 24 of 100. Nor kept in two
legs where a fresh plan in two legs arrives sooner: held against one leg
alone, legs searched again from their old ones as their departure went by
stood later than two found afresh (a033b05a kept 8 of 78 so, one at seed
4242 node 281, orbit9 -9 to keep 5, line-up 1: 46.83 s against 41.80; 13 of
168 over 15 replans, by up to 18.8 s; the fifth review, Nov 1). And none
kept, in one leg or two, that arrives later than the last legs kept flown
again from here (`FlightChain.chain_again`), as a flight of one leg that
took over from two holds them (`alt`).
```

## Prototype flight

Above `func _prototype() -> void:`:

```text
WORLD a TO WORLD b at the prototype's best line-up (a at 4.5845 rad round A,
b at 3.7905 round B at t 0, the ship leaving a's ring at 3.6115 clockwise):
the prototype found it free in 9.2 s; and over 12 line-ups (the worlds'
places and the ship's turned by golden-angle steps) against its typical
3.6 px/s (a 60 s cap's figure, an upper bound). Judged with the pair held
still, as the prototype flew it: turning (ruling 23), worlds a and b go
round their suns four times as fast, the line-up is no longer a free one
(62.7 px/s in 8.2 s at x4), and the turning pair's figures are only shown.
```

## Spin not replayed

Inside `_replays()`, above `if StringName(dep.kind) == &"ring" and float(dep.get("spin", 0.0)) > 0.0:`:

```text
(NOT ON A FLIGHT'S OWN CLOCK, `dep.spin`: a plan made for now has its
ride spin up from now, and a ship left riding its ring at its own
rate half a second is that much short of it. The game never asks it:
its plans are made a moment ahead, PLAN_AHEAD or PREVIEW_AHEAD, the
ship at its own rate until then, and FlightTest's clicks on the drawn
flight a moment on hold that)
```
