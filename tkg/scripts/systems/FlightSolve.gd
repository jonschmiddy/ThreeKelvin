class_name FlightSolve
extends RefCounted

## THE AUTOPILOT'S FLIGHT, SOLVED under the real pull of the stars and the
## giant on map time (ruling 20, Oct 30: "Prototype: twin:A giant:A"; Phase 13
## step 2, ruled Oct 29 "flight:N clock:map"). Data in, data out: no Nodes, no
## Callables, nothing shared but the read-only `MapGravity`, so it is safe on a
## `WorkerThreadPool` task, and the same inputs always give the same flight.
##
## A FLIGHT, from where the ship is to a place:
## 1. the ride: round its ring (a world's, a star's close orbit, or any circle
##    round a fixed point) at the ring's own pace for up to LEAD_MAX 4.4 s, and
##    past that sped up by a phasing burn whose push is held to THRUST
##    (`ShipFlight._step_phase` flies it); alongside a station, belt, hulk or
##    contact, holding there KEEP_HOLD 1 s;
## 2. the departure burn, in one direction, from the ring's own motion
##    (velocity continuous), at THRUST 40 px/s^2 but eased while the ship is
##    slow so it turns no tighter than R_BURN;
## 3. the coast, integrated through the stars and the moving giant (RK4 in
##    64-bit scalars, each step ETA of the nearest pull's own time);
## 4. the arrival burn, onto the target's ring at its speed either way round:
##    a constant pull of THRUST that ends exactly on the ring (`_const_burn`),
##    its end where that pull is exact; alongside, the coast's path plus a cubic
##    that ends exactly at the spot, its own pull at most THRUST and linear in
##    time. With gravity's change across the burn, at most THRUST_SLACK over.
## Keep-out (`MapGravity`) holds along the whole path: each step's closest
## approach on the cubic through its ends, and the arrival burn's own path. The
## flight's own departure and target world keep out only to their rings
## (OWN_GAP). No burn all but stops the ship and turns it round a point, which
## draws a cusp (V_CUSP).
##
## THE COST: engine work (the ride's phasing and both burns, px/s) + TIME_W x
## seconds from now to arrival. Flying inside a system costs no fuel; the cost
## only picks the path. TIME_W is the dial: more, faster flights that burn more.
##
## HOW IT IS FOUND (prototyped in tk-scratch/twin-build/solve-proto, measured):
## - conic guesses (Lambert about the star; in a twin about the pair's balance
##   point and about each star the flight leaves or reaches), priced from the
##   very point and moment the ship can leave, aimed at the target ring's
##   tangent point (where the ring's motion runs along the coast's own);
## - the cheapest refined by Newton (finite differences, then Broyden) on the
##   departure velocity until the coast meets that tangent point at its time;
## - in a twin always, otherwise when no conic flies clean: a scan of real
##   departures (SCAN_HEAD headings x four speeds, each leaving from the ring
##   point whose motion runs along it, or the end of the ride's reach; out of a
##   twin star's well to a place round both, faster: FAR_SPEED), the best
##   refined by a minimum-norm Newton on the signed miss at the coast's pass of
##   the target (its time free: along-track timing is the sensitive direction
##   of an arc), from the point it left; then a second scan between the
##   first's headings, and a third slower and faster;
## - last, the rest of the conics as they are. At most BUDGET integrations,
##   and one more for the samples;
## - when all of that finds nothing to T_CAP, THE FALLBACK (`_fallback`, ruling
##   21): the as-built search (all of the above to T_CAP_BACK at TIME_W_BACK,
##   BUDGET more) and a wider search to T_CAP_WIDE at TIME_W, its scan faster
##   and, out of a settled star orbit, toward the target (`_search_wide`,
##   BUDGET_WIDE more), the flight that arrives first kept; when both find
##   nothing, the wider search again at TIME_W_BACK. A flight found to T_CAP
##   whose samples cut a keep-out gets the fallback's look too, and the
##   fallback's flight is kept if it is clean (`_build_fresh`);
## - in a twin, when even that finds nothing, a flight in two legs (`_chain`):
##   the first aimed at a point round the pair, the second leaving free off its
##   coast before the first's arrival burn, so the ship never stops there, both
##   legs by the as-built search alone. One Result.
## A burn that all but stops the ship and turns it round (`V_CUSP`, `CUSP_TURN`),
## or an arrival burn the map would draw as a corner (`DRAW_K`), is not flown.
##
## MEASURED (SolveTest, Oct 30, this Mac's i5-8257U, with the LAYOUT branch's
## twins merged in; 10,362 plans, every start to every place): found and
## clean in 99.97% of 3,084 one-star plans, 100% of 3,768 with the giant at
## 1/10 and 1/4, 99.16% of 2,610 in the layout's own twins (8, the most bodies
## of four seeds, 6 line-ups), 98.9% of 900 in the prototype's twins built by
## hand. Each lands on its ring within 0.0001 px and 0.07 px/s; the drawn
## coast within 0.11 px of a plain RK4 at SAMPLE; 82% of arrivals onto a ring
## a constant burn. Planning median 13 ms one-star, 14 with a giant, 37 in a
## real twin; the worst 61, 70 and 136 ms (209 in the hand twins). A twin's
## plans are over DESIGN's median of 25 ms, so the game plans them on a worker
## while the ship rides its ring (a plan made on a worker is the same plan, bit
## for bit). The prototype's free twin flight (world a to world b at its best
## line-up, 9.2 s): 1.6 px/s in 9.3 s. The first build, on the same real
## twins: 89.8% found (the planner review), its rides phasing at up to 436
## px/s^2 for free and its arrival burns three times their least.
##
## THE PAIR TURNS (ruling 23, Jon, Nov 1, "Orbiting pair: after4:D"): a
## binary's suns circle their balance point at four times Kepler, every world
## round one sun carried with it. The coast reads both suns at each step's
## start, middle and end (one cos and sin a place for both); keep-outs, the
## arrival burn's checks and the pull a burn is held to read them, and every
## circle carried with one, where they are then; a place round one sun -- a
## world, its close orbit, a settled orbit round it (`host`) -- rides with it
## (`_dhs`, `_ths`); a conic about a sun is solved in its own frame and asks by
## the sun's index whether the target is that sun (`_lam`, `_aims`). A sun
## that holds still -- one alone, a pair held still (`-- pair=0`) -- runs the
## very same arithmetic as before: SolveTest's one-star, giant, hand-twin and
## real-twin sweeps print the same numbers to the last digit at pair=0.
## Turning (SolveTest, Nov 2, this PC, other jobs beside it): found and clean
## in 3,022 of 3,024 real wide-pair plans (the two misses free starts, a
## harness's), 3,024 of 3,024 close, 1,080 of 1,080 hand twins, and 1,872 of
## 1,872 in the pair-phase sweep (three of the busiest pairs at 8 angles a
## lap, from a settled orbit round each sun too); every landing within 0.0001
## px and 0.07 px/s of the ring where the layout's Body has it; the drawn coast
## within 0.13 px of plain RK4 through `MapGravity.acc`; every replay and
## worker plan the same. An RK4 step through a turning pair costs a tenth to a
## fifth more (the prototype's bench, `tk-scratch/orbiting-pair/autopilot`).
##
## USE
##   var G := MapGravity.from_layout(L)          # once per system; shareable
##   var r := FlightSolve.solve(G, dep, tgt, t)   # or (..., prefer = r.choice)
##   dep: {kind: &"ring", place: int, rt: float, ang: float, w: float}
##          place: a body index, -1 star A, SystemLayout.STAR_B, or -9 with
##          c: Vector2, a fixed centre (a settled star orbit); w signed rad/s
##          (a star's rt: `star_orbit_r`). A -9 round one sun of a turning
##          pair also passes host: that sun's place id (`ShipFlight` f.cen_id);
##          the circle then rides with the sun and c is not read (-9, or none,
##          a fixed centre: the balance point, the edge as arrived)
##        {kind: &"keep", place: int, off: Vector2}   alongside, `off` from it
##        {kind: &"free", p: Vector2, v: Vector2}
##   tgt: {kind: &"ring", place: int, R: float, V: float, sense: 0 | 1 | -1}
##          R the radius it arrives on: a world's `ShipFlight.orbit_r(i)`, a
##          star's `FlightSolve.star_orbit_r(L, p)` (in a twin its rail, NOT
##          its ring - 8, which is inside its keep-out); V the ring speed (RAIL_V
##          35, a star's STAR_RAIL_V 45); sense 0 either way round
##        {kind: &"keep", place: int, off: Vector2}
##   t: map time now.
## The result (`Result`) fills a ShipFlight.FlightPlan: samp from t0 (after
## the ride, or the hold alongside) SAMPLE apart, burns per sample, end {body,
## p, v, a, arel, rv, t, keep, sense} (a: the ring's own pull, relative, so the
## insertion that follows flies none), lead and lead_k for rail.phase (a ride
## of up to 4.4 s: rail.phase {T: lead, k: lead_k} as it is; alongside, the
## ship holds at its spot for `lead`), dur, amax, esc_t (the departure burn),
## `legs` (2 for a flight in two legs, `wp` its point, `k_cut` and `t_cut` the
## sample and moment its second leaves) and `choice`. Passing that choice back
## as `prefer` rebuilds the same flight
## exactly (one integration) while it is the same flight (`_same_flight`) and
## its departure is still ahead: round a ring while the ride from where the
## ship is now reaches it at a phasing within THRUST (its ride may then phase
## harder than it did, at up to 2 THRUST lead / pi px/s more work), alongside
## while the hold lasts, free at the same moment and state. Otherwise the
## search starts from it and keeps that flight while it costs about what it
## did (WARM_K, WARM_ADD), so a preview does not flip between near equals; a
## flight the fallback found, rebuilt or searched from, only while a fresh
## search (C's own, else the fallback's two) finds none arriving sooner. A
## flight in two legs comes back from its legs (`_chain_again`: rebuilt while
## the first is the same flight, else searched from them, while it costs about
## what it did), and round a ring or alongside is kept only while a fresh plan
## (one leg, else two) finds none arriving sooner (`_sooner_of`), its own drawn
## flight too. A flight of one leg that took over from one in two carries those
## legs in its choice (`alt`), and they are tried again beside it each time it
## is planned again (searched again once their departure has gone by), so a
## later flight in two legs found afresh never stands where the old legs still
## fly sooner. A flight in two legs looked for again through its old point
## (`_chain`'s hint) is kept only while the first one found without it arrives
## no sooner.
## `found` false: nothing clean within the budget, and no samples (the caller
## falls back); `clean` false on a found plan only if its own samples cut a
## keep-out (none in the sweeps).

const THRUST := 40.0
## an arrival burn may pull this much over THRUST where gravity's own pull
## changes across it (its own pull holds to THRUST)
const THRUST_SLACK := 1.1
## an arrival burn's own pull may be this much over THRUST where its end is
## moved onto the sample grid (`_build`): a constant burn whose end moves by
## up to SAMPLE needs at most a few tenths of a percent more
const BURN_TOL := 0.01
## the arrival burn's path is checked every 0.05 s of it and kept this far
## (px) inside its keep-outs' edge: checked every 0.1 s, two arrivals onto a
## twin's close orbit cut 0.15 and 1.5 px in between the points
const BURN_PAD := 0.5
## an arrival burn starts at least this long (s) after the departure burn
## ends, so moving its end onto the sample grid (`_build`) cannot start it
## before: one did, by under a sample, and the flight's first samples carried
## its pull (0.18 px off the place it left, SolveTest)
const TB_PAD := 2.0 * (1.0 / 240.0)
## THE RIDE round to the departure point, at the ring's own pace, lasts at
## most this (s): twice `ShipFlight.LEAD_MAX`'s 2.2. Past it the ride phases
## (below). Priced honestly, phasing costs 2 V of engine work for each unit of
## k (70 px/s on a world's ring) where riding on costs TIME_W a second, 2.2 s
## of it for the same way round: at the as-built TIME_W of 0.5 riding was about
## sixty times cheaper, and at 16 (ruling 21) it is still half the price; held to
## 2.2 s and THRUST, the twins built by hand fell from 99.1% found to 95%
## (SolveTest, Oct 30). A ride's seconds are in the flight's time, so the cost
## keeps it short where it can.
const LEAD_MAX := 4.4
## THE PHASING BURN's top pace, in times the ring's own, at the most: the ride
## speeds round as `ShipFlight._step_phase` flies it, pace 1 + (k - 1) sin^2,
## and its push along the ring peaks at |w| (k - 1) pi rt / LEAD_MAX. That push
## is held to THRUST (`_kmax`): k at most 2.6 on a world's ring at RAIL_V,
## 2.25 on a star's close orbit at STAR_RAIL_V, its top speed under VMAX. The
## first build let k reach 8 within 2.2 s, which pushed at up to 436 px/s^2
## and whirled a ship round a twin's 17.6 px rings at up to 350 px/s, free in
## the cost (the planner review, Oct 30). Its work, 2 |k - 1| |w| rt, is in the
## cost.
const PHASE_K_MAX := 4.0
## `ShipFlight.VMAX`: the ride's top speed
const VMAX := 150.0
## ALONGSIDE, A FLIGHT LEAVES THIS LONG AFTER IT IS PLANNED (the ship holding
## alongside meanwhile), so the drawn flight is still ahead when it is clicked
## and is rebuilt exactly from its choice (a ring's ride does the same). With
## no hold, 48 of 48 clicks a quarter second after their preview flew another
## flight, by a median 17.8 px (the planner review, Oct 30).
const KEEP_HOLD := 1.0
## A FLIGHT'S OWN DEPARTURE AND TARGET WORLD keeps out only to its ring less
## this (px), not to r + 8: a twin's worlds round one star ride a 17.6 px ring,
## inside r + 8 for any world over 9.6 px (1 twin in 26), so nothing flew to
## or from them; where it did fit, it left a median 2.7 px
const OWN_GAP := 2.0
## A PREVIEW'S FLIGHT IS KEPT (`prefer`, its departure gone by) while it costs
## at most WARM_K more than it did, or WARM_ADD: past that the search runs, and
## the kept flight stays only if the search does not beat it by as much. With
## none, kept flights ran up to 81.6 over a fresh search (the planner review).
const WARM_K := 0.25
const WARM_ADD := 10.0
## a flight arrives within this of now: 16 s (ruling 21, Nov 1, "Flight length:
## C"), where ruling 20 built it to 30 (T_CAP_BACK, the fallback's)
const T_CAP := 16.0
## WHEN THE SEARCH FINDS NOTHING, A WIDER ONE (`_search_wide`): arriving within
## T_CAP_WIDE of now, the cheapest conics to then refined, and a scan of
## WIDE_HEAD headings whose departures are at least as fast as crossing to the
## target in WIDE_T takes (`_wide_need`) -- out of a settled star orbit, across
## WIDE_SPAN either side of the target's bearing -- within BUDGET_WIDE more
## integrations. Out of a settled star orbit the scan's speeds were its ring's
## own times 1 to 3.9, and a twin's settled orbits far out go round at 11 to 16
## px/s: 41 px/s at the most in its first pass, too slow to cross a two-star
## system inside T_CAP, and the edge as arrived (every visit's first flight) was
## found for 201 of 224 flights. Measured on FlightTest's game starts (Oct 31,
## three seeds): twins 1,432 found of 1,478 before, 1,460 with it; a heavy
## giant 913 of 921, 917; one star 694 of 696, the same. It runs only for
## flights nothing else found, so every flight found before is the same flight;
## those it finds take a median of 200 ms and at most about 250 (on a worker).
## Budgets of 400, 16 headings, headings within 30 or 45 deg of the bearing and
## a cap of 55 s found no more; what it still misses (18 twin flights of 1,478)
## leave a star's close orbit or a settled orbit far out for a station, belt,
## hulk or contact on the far side of the pair, which no departure burn and one
## coast reaches (the closest any of 1,260 departures came was 42 to 249 px):
## those fly in two legs (`_chain`). Those numbers are the as-built search's;
## at C the wider one looks beside it (`_fallback`).
const T_CAP_WIDE := 40.0
const WIDE_T := 20.0
const BUDGET_WIDE := 250
const WIDE_HEAD := 12
const WIDE_SPAN := PI * 75.0 / 180.0
## WHEN EVEN THAT FINDS NOTHING, IN A TWIN, A FLIGHT IN TWO LEGS (`_chain`):
## the first aimed at a point in open space (`_waypoints`), the second leaving
## free off its coast CHAIN_PRE s (each in turn) before its arrival burn, at
## least CHAIN_AFTER after its departure burn. The points: round the pair, half
## way round from the ship to where the place is CHAIN_T on, at CHAIN_R times
## the farther from the balance point, at least CHAIN_CLEAR separations out and
## within CHAIN_EDGE of the map's edge. Measured (FlightTest, Oct 31, three
## seeds' 36 twins, 1,790 plans): 37 fly in two legs -- every one of the 18 game
## starts one leg missed (a star's close orbit, a settled star orbit and the
## edge, to places round both on the far side of the pair), all 13 free starts
## it missed, 6 close by a world -- in a median of 45 s, at worst 57, planned in
## a median of 270 ms, at worst 530 (on a worker in the game), out to 0.98 of the
## edge at the farthest; the turn onto the second leg at worst 13 deg a px at
## zoom 1 (a corner is 20). SolveTest's real twins: 3,024 of 3,024 found (99.31%
## with one leg). The 24 left were all close by a world coasting fast: in 23,
## no burn at THRUST keeps the coast clear of a keep-out for a second (the one
## where a burn did, seed 7 system 110, is FlightTest's residual). Points all
## round the pair (12 bearings, two radii) and round the place found no more,
## nor, there, a first leg that was that burn and its coast.
const CHAIN_PRE := [0.5, 3.0, 6.0]
const CHAIN_AFTER := 0.5
const CHAIN_T := 15.0
const CHAIN_R := [1.0, 0.7]
const CHAIN_CLEAR := 1.5
const CHAIN_EDGE := 0.95
## px/s of engine work one second of flight is worth: Jon's dial. Ruling 21
## (Nov 1, "Flight length: C", picked from the Autopilot Flight Time page, eight
## flights played at game speed) set it to 16 with T_CAP 16. As built (ruling
## 20) it was 0.5 to a cap of 30 s, and a flight from place to place with one
## sun took a median of 23.5 s from the click to settled (FlightTest), the v2
## pick (B: 1, to 23 s) 18.9 s, and today's autopilot on main 6.9 s. At C it
## takes 10.8 s, 14.9 s for 9 in 10, at worst 20; every game start 13.4 s with
## one sun and 14.0 s in a twin. The engine works harder for it: a median of
## 157 px/s, where the as-built flight's was 91 (the study, Nov 1).
const TIME_W := 16.0
## THE AS-BUILT SEARCH, behind C's (`_fallback`): ruling 20's dials, T_CAP_BACK
## 30 s at TIME_W_BACK 0.5, with its own conic guesses and FAR_T. C's dials
## alone missed 10 of SolveTest's 12,648 flights that the as-built search finds
## (9 in twins, most from a settled star orbit to a station). Where C's own
## search finds nothing, this and the wider search at TIME_W both look and the
## flight that arrives first is kept. The as-built search alone held C's
## flights from the edge and settled star orbits to about 29 s, one game start
## in five to eight, where the wider one found quicker; the wider one alone let
## flights of up to 40 s stand where the as-built found one under 30. With
## both, C misses none of those A finds, finds one A misses, and never arrives
## after the as-built search's flight. A flight in two legs flies both by it,
## so those keep the as-built length: 30 of 1,790 twin plans, a median of 47 s.
const T_CAP_BACK := 30.0
const TIME_W_BACK := 0.5
const CONIC_TS_BACK := [6.0, 9.0, 13.0, 18.0, 24.0, 29.0]
const FAR_T_BACK := 18.0
const SAMPLE := 1.0 / 240.0
## the coast's step: ETA of the nearest pull's dynamical time sqrt(r^3/GM),
## clamped; a burn's steps at most H_BURN. Measured (SolveTest): at 0.1 and
## 0.25 s the drawn coast was within 0.013 px of a plain RK4 at SAMPLE; at 0.15
## and 0.5 s within 0.08 px, in half the steps, the same flights found
const ETA := 0.15
const H_MIN := 1.0 / 120.0
const H_MAX := 0.5
const H_BURN := 0.1
## the longest arrival burn (a constant one of 120 px/s): the coast is flown
## on this far past a keep-out it breaks, for an arrival whose burn starts
## before it
const D2_MAX := 3.0
## how far round a pass a coast is priced from the target (px past its ring)
const NEAR := 260.0
## a coast passing within this of the ring's virtual circle is priced at its
## closest even when it does not cross it
const GRAZE := 60.0
## THE SCAN (`_scan`): headings, and per pass the speeds (times the ring's
## own) a ring departure tries, or the kicks (px/s) on a place's own motion
## alongside or free; the third pass, when two find nothing, slower and faster
## (the first build's speeds, along the ring's motion only)
const SCAN_HEAD := 8
const SCAN_SPEED := [[1.0, 1.43, 2.0, 2.71], [1.2, 1.71, 2.34, 3.29], [0.66, 0.8, 1.57, 3.86]]
const SCAN_KICK := [[15.0, 35.0, 60.0], [7.0, 25.0, 47.0, 80.0], [12.0, 22.0, 100.0]]
## A TARGET FAR OUT OF A TWIN STAR'S WELL is scanned from at least the speed
## that climbs out to it in about FAR_T s (the as-built 18 s scaled to T_CAP,
## 9.6; the as-built search keeps FAR_T_BACK); a point is round a star where
## its pull is FAR_SHARE times the other's
const FAR_T := FAR_T_BACK * (T_CAP / T_CAP_BACK)
const FAR_SHARE := 3.0
## its scan's speeds per pass, in times that need
const FAR_SPEED := [[0.8, 1.1, 1.5, 2.0], [0.9, 1.25, 1.75, 2.4], [0.7, 1.0, 1.35, 2.9]]
## A RING DEPARTURE'S BURN is centred on its point (the ship comes off the
## ring half a burn sooner) only as far back as the ring turns this much (rad):
## further, the burn starts along a chord that dips inside the ring by about
## rt theta^2 / 8, 2.3 px for a 1.2 s burn on a twin star's close orbit, which
## is only 2 px outside its keep-out
const BACK_TURN := 0.25
## INTEGRATIONS A PLAN MAY TAKE: `_fly` flies no more past it, so a
## refinement under way stops there too (the first build only checked it
## between scan flights, and a plan took up to 144); the samples take one
## more, and a warm start that is not kept gives the search a budget of its
## own after it. A twin's flights are short and its search wide.
const BUDGET := 140
## THE CONIC GUESSES' FLIGHT TIMES (s): the as-built ones (CONIC_TS_BACK)
## scaled to T_CAP, x 16/30 (3.2, 4.8, 6.93, 9.6, 12.8, 15.47), and beside them
## the as-built ones under T_CAP (6, 9, 13). With the scaled ones alone, the
## v2 pick (B) flew longer than the as-built search in about a fifth of game
## starts (the review of Nov 1); with both, C does in 1 to 2%, by at most 6 s
const CONIC_TS := [6.0 * (T_CAP / T_CAP_BACK), 9.0 * (T_CAP / T_CAP_BACK), 6.0, 13.0 * (T_CAP / T_CAP_BACK), 9.0,
	18.0 * (T_CAP / T_CAP_BACK), 24.0 * (T_CAP / T_CAP_BACK), 13.0, 29.0 * (T_CAP / T_CAP_BACK)]
## the wider search's (`_search_wide`), to T_CAP_WIDE
const CONIC_TS_WIDE := [18.0, 24.0, 29.0, 34.0, 39.0]
## the conics the second stage re-solves from the real departure
const CONIC_KEEP := 6
## THE DEPARTURE BURN IS EASED WHILE THE SHIP IS SLOW (Jon: "why are there
## sharp angles on some of the trajectories?"): a ship at speed v turned by a
## pull a goes round a curve of v^2 / a, so out of a settled star orbit at 14 to
## 23 px/s a burn at THRUST across its motion bent it round 5 to 13 px, drawn at
## zoom 1 as tight as 0.7 px (the plane's slant shortens a curve seen end on to
## 0.38^2 of it): FlightTest counted a corner, over 20 deg a px, in 3 to 7 of a
## system's flights from a star orbit (Oct 31). So the pull is at most v^2 /
## R_BURN (a curve of R_BURN px at the least), never under P_MIN, and THRUST from
## about 24 px/s. The work is the same; the burn takes longer. Out of a
## settled star orbit only (a ring round a fixed point, place -9: the edge as
## arrived is one), whose pace is 14 to 40 px/s: a world's ring and a star's
## close orbit leave at 35 and 45, and eased there a burn deep in a star's well
## was too weak to climb out (SolveTest's star-to-star flights in the hand twins
## found 79%, against 90%); alongside, the ship leaves all but at rest and its
## first curve is under a pixel; free, only a harness leaves (SolveTest's free
## starts at 10 to 40 px/s were found 1.7% less often eased, Oct 31).
const R_BURN := 14.0
const P_MIN := 3.0
## A BURN THAT ALL BUT STOPS THE SHIP AND TURNS IT draws a cusp however gently
## it pulls: its speed (on the plane, where it is drawn) dipping under this
## mid-burn, below where it starts and ends, so the motion swings round a
## point tighter than R_BURN at P_MIN. Such a departure out of a ring (a
## world's, a star's close orbit or a settled star orbit) or an arrival is not
## flown: the search finds another. (At 12 px/s,
## before the burn was eased, it cut SolveTest's flights found from 99.97% to
## 96.2% one-star, Oct 31.)
const V_CUSP := 5.0
## and turned down this much above it (px/s): the burn's speed read here from
## the coast's nodes and a few points of the arrival, SolveTest's from every
## sample (one flight of 3,061 read just under 5 there and passed here, Oct 31)
const CUSP_PAD := 0.5
## A CUSP IS WHERE THE MOTION ALL BUT STOPS MID-BURN AND TURNS ROUND: its least
## speed inside the burn (CUSP_IN under both its ends) and the motion turned by
## more than CUSP_TURN while slower than V_SLOW. It was a least speed 2 px/s
## under both ends, which let through a departure out of a star orbit at 15.5
## px/s that burned down to 1.0 and left at 2.3 the other way: a turn of about
## 150 deg round a third of a pixel, 64 deg a px on screen at zoom 2
## (FlightTest, seed 4242 system 104, Oct 31). A burn that only slows (its
## least speed its end) still flies.
const CUSP_IN := 0.25
const CUSP_TURN := PI / 3.0
const V_SLOW := 2.0 * V_CUSP
## AN ARRIVAL BURN IS NOT FLOWN where its curve as the map draws it at zoom 1
## (`ShipFlight.TILT` 0.38: the plane's depth drawn at that) turns more than
## DRAW_K rad a px: FlightTest's corner is 20 deg a px over 2 px, a curve 1.43
## px across; this keeps 1.67.
const DRAW_TILT := 0.38
const DRAW_K := 0.6
## the version of `choice` this file writes and reads: 2 from the orbiting pair
## (ruling 23), whose choice carries the sun each circle rides with (`dhs`,
## `ths`), so no preview planned under the old meaning is rebuilt as it was
const CHOICE_V := 3
## THE FAST TRANSFERS (Jon, Nov 4-5: "almost 4 times slower than feels good",
## "Why is transferring between planets a straight line?"): every flight is
## solved on its own clock, tau = pace x map time, through a copy of the system
## whose bodies move pace times slower (`MapGravity.paced`), at today's THRUST,
## gravity and every other dial, then played back pace times faster (`solve`'s
## `pace`, `Result.to_map`): the same path, its pulls pace^2 stronger on the
## map, and the place met where it really is. The ring speeds the ship leaves
## and arrives at stay the map's own (RAIL_V 35 on the map, RAIL_V / pace in
## tau). Two paths (`DisplaySettings.autopilot`, AUTOPILOT: DIRECT . CURVED):
## DIRECT is ruling 21's C search (TIME_W 16 to T_CAP 16) at pace 4, about 11 s
## of tau played in about 2.8 s; CURVED is the as-built search (ruling 20's
## TIME_W_BACK 0.5 to T_CAP_BACK 30, its conic times and FAR_T_BACK) as the
## first look, at pace 8: slow, cheap flights that bend round the stars,
## about 24 s of tau played in about 3 s. Both keep the wider search and the
## flight in two legs behind them.
## ALONGSIDE, the hold before leaving (KEEP_HOLD in tau) is at least HOLD_MAP
## of map time: KEEP_HOLD 1 s of tau is an eighth of a second at pace 8.
const HOLD_MAP := 0.4
## THE RING SPEEDS ON THE FLIGHT'S CLOCK. A ring's speed divided by the pace
## left the ship all but at rest in tau (a star's close orbit, 45 px/s on the
## map, 5.6 at pace 8, deep in a well whose gravity the flight's clock leaves
## as it is), and from a star's close orbit or to one the solver found a
## third of the flights or none (SolveTest, Nov 5: twins 50%, close pairs
## 62%, at a floor of 20 px/s; 100% at 60). So a ring is left and arrived on
## in tau at its speed / pace but never under RING_TAU px/s, nor over its own
## speed: every ring the game has (worlds' 35 px/s, stars' 45, settled star
## orbits' 13 to 50) at its own speed. On the map the ship spins up round its
## ring to pace times that before it leaves (`ShipFlight._ride_shape`: it
## rides at the ring's own speed, spins up over SPIN_UP s and whirls round at
## the departure's for the ride's last part) and spins down onto the ring's
## own speed as it arrives (`ShipFlight.start_rail`'s spin, SPIN_S).
## `-- ringtau=X` sets it for a harness (0: speed / pace, as first built).
const RING_TAU := 60.0
## THE SPIN-UP's length on the map (s): the ship's rate eased from its ring's
## own to the departure's (`ShipFlight._ride_shape`). The ride on the flight's
## clock starts with it (`dep.w0`, the ring's own rate there, and `dep.spin`,
## SPIN_UP x pace tau-s: a smoothstep from w0 to w), so it lasts at least the
## spin and goes (w - w0) spin / 2 less far round: a flight left at once, as
## the solver first had it, could not be flown on the map, where the ship is
## still at its ring's own rate (IOTA TALLOW GATE V to IV, DIRECT: every plan
## made for a moment just ahead untakeable, and the ship put there). The spin
## is the clock's hand-off, not engine work, and is not priced.
const SPIN_UP := 0.3
static var ring_tau := -1.0


static func ring_floor() -> float:
	if ring_tau < 0.0:
		ring_tau = RING_TAU
		for a in OS.get_cmdline_user_args():
			if (a as String).begins_with("ringtau="):
				ring_tau = maxf(float((a as String).substr(8)), 0.0)
	return ring_tau


## A ring's speed v (px/s, signed) on a flight's clock at pace k (`RING_TAU`).
static func tau_speed(v: float, k: float) -> float:
	if k == 1.0:
		return v
	var a := absf(v)
	return signf(v) * minf(a, maxf(a / k, ring_floor()))


## A departure or a target on the flight's clock at pace k: a ring's or a
## target ring's speed by `tau_speed`, a free start's motion / k.
static func dep_tau(dep: Dictionary, k: float) -> Dictionary:
	var d := dep.duplicate()
	match StringName(d.get("kind", &"")):
		&"ring":
			var rt := float(d.rt)
			var w0 := float(d.w) / k
			d.w = tau_speed(float(d.w) * rt, k) / rt
			if absf(float(d.w) - w0) > 1e-12:
				d.w0 = w0
				d.spin = SPIN_UP * k
		&"free":
			d.v = (d.v as Vector2) / k
	return d


static func tgt_tau(tgt: Dictionary, k: float) -> Dictionary:
	var g := tgt.duplicate()
	if StringName(g.get("kind", &"")) == &"ring":
		g.V = tau_speed(float(g.V), k)
	return g


class Result:
	extends RefCounted
	var found := false
	var clean := false
	## &"solved", &"replay" (rebuilt from `prefer`), &"warm" (searched from it)
	var kind: StringName = &"solved"
	## map time samp[0] is at (the departure, after the ride)
	var t0 := 0.0
	var lead := 0.0
	var lead_k := 1.0
	var a_dep := 0.0
	var sdt := SAMPLE
	var samp := PackedVector3Array()
	var burns := PackedByteArray()
	var dur := 0.0
	## the hardest |second difference| / SAMPLE^2 (`FlightPlan.amax`, the flame)
	var amax := 1.0
	## the departure burn's length (s)
	var esc_t := 0.0
	var end: Dictionary = {}
	var choice: Dictionary = {}
	var cost := INF
	## the cost the search priced it at, before its end was moved onto the
	## sample grid
	var priced := INF
	## engine work, px/s: the ride's phasing, the departure burn and the
	## arrival burn
	var work := 0.0
	var dvp := 0.0
	var dv1 := 0.0
	var dv2 := 0.0
	## whether the arrival burn pulls the same way all through (onto a ring,
	## where it ends exactly; else the cubic, alongside or past BURN_TOL)
	var arr_const := false
	## seconds from now to arrival, and the arrival burn's length
	var T := 0.0
	var d2 := 0.0
	## the least margin to any keep-out along the samples, px
	var clear := 0.0
	var integrations := 0
	var steps := 0
	var usec := 0
	## of usec: the conic guesses, integrating, pricing arrivals, the samples
	var us_seed := 0
	var us_int := 0
	var us_price := 0
	var us_build := 0
	## A FLIGHT IN TWO LEGS (`_chain`): 2, the point its first leg is aimed at,
	## and the sample (of `samp`) and map time its second leaves free from
	var legs := 1
	var wp := Vector2.ZERO
	var k_cut := 0
	var t_cut := 0.0
	## THE CLOCK IT WAS SOLVED ON (`solve`'s pace) and the search (&"direct",
	## &"curved"); `tau` true while its times are still the flight's own clock
	## (`to_map` makes them map time)
	var pace := 1.0
	var path: StringName = &"direct"
	var tau := false

	## ITS TIMES ON THE MAP'S CLOCK: every time and length / pace, every speed
	## x pace, every pull x pace^2; positions as they are. Its choice stays in
	## tau, as `solve` reads it back (`prefer`).
	func to_map(k: float) -> void:
		if k == 1.0 or not tau:
			tau = false
			return
		tau = false
		t0 /= k
		lead /= k
		sdt /= k
		dur /= k
		esc_t /= k
		T /= k
		d2 /= k
		t_cut /= k
		amax *= k * k
		if not end.is_empty():
			end = end.duplicate()
			end.t = float(end.t) / k
			end.v = (end.v as Vector3) * k
			end.rv = (end.rv as Vector2) * k
			end.a = (end.a as Vector2) * (k * k)


# ---------------------------------------------------------------- the problem
var G: MapGravity
var t_now := 0.0
## the departure: 0 ring, 1 keep, 2 free; its place's circle
var _dk := 0
var _dhx := 0.0
var _dhz := 0.0
var _dorb := 0.0
var _dn := 0.0
var _dph := 0.0
var _drt := 0.0
var _dang := 0.0
var _dw := 0.0
## (a ring ridden at its own rate until a fast flight's ride spins up to _dw
## over _spin tau-s: `SPIN_UP`)
var _dw0 := 0.0
var _spin := 0.0
## the longest ride: LEAD_MAX, and never shorter than a fast flight's spin-up.
## (Held to 0.55 s on the map for DIRECT, LEAD_MAX's 4.4 tau-s at pace 8, the
## click to settled went from a median 4.1 s to 3.9 and twins lost flights and
## grew corners: FlightTest, Nov 5. Not kept.)
var _lmax := LEAD_MAX
var _doffx := 0.0
var _doffz := 0.0
var _dpx := 0.0
var _dpz := 0.0
var _dvx := 0.0
var _dvz := 0.0
var _dplace := -9
## THE SUN A CIRCLE RIDES WITH (ruling 23, the orbiting pair): the index in G
## of the star the departure's / target's circle is centred on where that star
## turns -- a world round one sun, a sun's close orbit, a settled orbit round
## one sun -- or -1 for a centre that holds still at _dhx, _dhz (_thx, _thz).
## Where it rides, _dhx (_thx) is the centre at t = 0, and `_dep_at` (`_tgt_at`)
## reads the star where it is at t.
var _dhs := -1
var _ths := -1
## the target: 0 ring, 1 keep
var _tk := 0
var _thx := 0.0
var _thz := 0.0
var _torb := 0.0
var _tn := 0.0
var _tph := 0.0
var _tR := 0.0
var _tV := 0.0
var _toffx := 0.0
var _toffz := 0.0
var _tplace := -9
var _tsense := 0
var _senses := PackedFloat64Array([1.0, -1.0])
var _twin := false
## (a departure out of a settled star orbit, round a fixed point or riding with
## one sun of a turning pair: its burn eased while slow, R_BURN)
var _ease := false
## the ride's top phasing (`_kmax`)
var _kmax := 1.0
## the keep-outs this flight holds: MapGravity's, its own departure and
## target world's cut to their rings (OWN_GAP)
var _wkeep := PackedFloat64Array()
var _gkeep := PackedFloat64Array()
var _budget := BUDGET
## the time cap this search flies to (T_CAP, T_CAP_BACK in the as-built one,
## or T_CAP_WIDE in the wider one), and whether the scan is the wider one's
var _tcap := T_CAP
var _wide := false
## the time weight this search prices with (TIME_W, or TIME_W_BACK in the
## as-built one), and whether it uses the as-built search's own times (its
## conic guesses, FAR_T_BACK)
var _tw := TIME_W
var _back := false
## CURVED (`solve`'s path): the as-built search is the first look, its cap
## `_cap0` (T_CAP_BACK; DIRECT's T_CAP), its weight TIME_W_BACK; and the hold
## alongside before leaving, in tau (`HOLD_MAP`)
var _curved := false
var _cap0 := T_CAP
var _hold := KEEP_HOLD
## THE PACE A FLIGHT IS SOLVED AT (`solve`), and the cusp's and the eased
## burn's speeds and least pull on its clock: V_CUSP, V_SLOW, CUSP_PAD, CUSP_IN
## and P_MIN over the pace, so a burn turned down as a cusp is one that slows
## to under V_CUSP on the map, as before (in tau a settled orbit's 13 px/s at
## the edge is 1.6, and at V_SLOW 10 every departure from it that turned read
## as one)
var _kp := 1.0
var _vc := V_CUSP
var _vsl := V_SLOW
var _cpad := CUSP_PAD
var _cin := CUSP_IN
var _pmin := P_MIN
## whether the flight kept was found by the search to T_CAP itself, not the
## fallback (`_build_fresh`)
var _own := false
## where the coast just flown first turns tighter than the map draws (`_coast_tight`)
var _tight_t := INF
## A LEG OF A FLIGHT IN TWO (`_chain`): 0 a flight of one, 1 the first (to a
## point in open space), 2 the second (leaving free off the first's coast, its
## burn eased while slow and kept from swinging round a point, as a settled star
## orbit's is); whether the wider search may run; whether `_setup` took the
## flight (so a chain is only looked for where a flight could be)
var _leg := 0
var _wide_ok := true
var _set := false

## a place's centre and motion (`_dep_at`, `_tgt_at` write these)
var _cx := 0.0
var _cz := 0.0
var _cvx := 0.0
var _cvz := 0.0

# ---------------------------------------------------------------- one coast
var _cT := PackedFloat64Array()
var _cX := PackedFloat64Array()
var _cZ := PackedFloat64Array()
var _cVX := PackedFloat64Array()
var _cVZ := PackedFloat64Array()
## the least keep-out margin up to each node
var _cCL := PackedFloat64Array()
var _cn := 0
var _tc0 := 0.0
var _t_bad := INF
var _n_integ := 0
var _n_steps := 0
## where the time goes (us): conic guesses, integrating, pricing arrivals, the samples
var _us_seed := 0
var _us_int := 0
var _us_price := 0
var _us_build := 0

# ---------------------------------------------------------------- the last flight flown
var _e_J := INF
var _e_td := 0.0
var _e_ad := 0.0
## the ring angle asked for, before the burn is centred on it (`_depart`)
var _e_a0 := 0.0
var _e_lead := 0.0
var _e_k := 1.0
## the ride's phasing work, px/s
var _e_ph := 0.0
var _e_x0 := 0.0
var _e_z0 := 0.0
var _e_vx0 := 0.0
var _e_vz0 := 0.0
var _e_dvx := 0.0
var _e_dvz := 0.0
var _e_te := 0.0
var _e_s := 1.0
var _e_phi := 0.0
var _e_d2 := 0.0
var _e_w2 := 0.0
## the arrival cubic's own top pull (THRUST, or less where gravity adds to it)
var _e_pk := THRUST
var _e_ux := 0.0
var _e_uz := 0.0
var _e_fix := false
var _e_afix := 0.0

# ---------------------------------------------------------------- the best so far
var _b_J := INF
var _b := {}


## THE FLIGHT from `dep` to `tgt` at map time t (see the head of this file).
## In a twin, where nothing is found, a flight in two legs (`_chain`).
## THE FLIGHT, on the map: dep and tgt in map units, t map time, `opts`
## {path: &"direct" | &"curved", pace: k} (`ShipFlight.flight_opts`); none is
## today's flight, DIRECT at pace 1, to the last digit. `grav` the system's
## MapGravity (at any pace: `paced(k)` is taken, a copy held already at k is
## used as it is). The search runs on the flight's own clock (tau = k t, from
## 0, so a choice made at one moment is read at the next): the ring's and a
## free start's speed / k, the target's ring speed / k. The Result comes back
## on the map's clock (`Result.to_map`) unless opts.tau. A `prefer` made on
## another path or pace is not read.
static func solve(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary = {}, opts: Dictionary = {}) -> Result:
	var k := float(opts.get("pace", 1.0))
	var path := StringName(opts.get("path", &"direct"))
	var curved := path == &"curved"
	var pf := prefer
	if not pf.is_empty() and (StringName(pf.get("path", &"direct")) != path or float(pf.get("pace", 1.0)) != k):
		pf = {}
	var r: Result
	if k == 1.0 and not curved:
		r = _solve_tau(grav, dep, tgt, t, pf)
	else:
		var d := dep_tau(dep, k)
		if curved:
			d["_curved"] = true
		if not d.has("_hold"):
			d["_hold"] = maxf(KEEP_HOLD, HOLD_MAP * k)
		if not d.has("_pace"):
			d["_pace"] = k
		var g := tgt_tau(tgt, k)
		# (at pace 1 -- CURVED at today's speed, or a harness already in tau -- the
		# system as it is given)
		r = _solve_tau(grav if k == 1.0 else grav.paced(k), d, g, t * k, pf)
	r.pace = k
	r.path = path
	r.tau = true
	if r.found:
		r.choice = r.choice.duplicate()
		r.choice["path"] = path
		r.choice["pace"] = k
	if not bool(opts.get("tau", false)):
		r.to_map(k)
	return r


## THE SHAPE OF A FLIGHT from its samples: [bend, turn] -- the farthest a
## sample strays from the straight line between its two ends over that line's
## length, and how far its motion turns in all (deg), read every 8th sample.
static func shape_of(samp: PackedVector3Array) -> PackedFloat64Array:
	var n := samp.size()
	if n < 3:
		return PackedFloat64Array([0.0, 0.0])
	var a := Vector2(samp[0].x, samp[0].z)
	var b := Vector2(samp[n - 1].x, samp[n - 1].z)
	var ch := (b - a).length()
	var far := 0.0
	var turn := 0.0
	var pv := Vector2.ZERO
	var step := maxi(1, n / 400)
	for j in range(0, n, step):
		var q := Vector2(samp[j].x, samp[j].z)
		if ch > 1e-6:
			far = maxf(far, absf((b - a).cross(q - a)) / ch)
		if j + step < n:
			var v := Vector2(samp[j + step].x - samp[j].x, samp[j + step].z - samp[j].z)
			if pv != Vector2.ZERO and v.length() > 1e-6:
				turn += absf(pv.angle_to(v))
			if v.length() > 1e-6:
				pv = v
	return PackedFloat64Array([far / maxf(ch, 1e-6), rad_to_deg(turn)])


## (the search on the flight's own clock: dep, tgt and t already in tau)
static func _solve_tau(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary = {}) -> Result:
	if grav.star_x0.size() > 1:
		var held := StringName(dep.get("kind", &"")) != &"free"
		if prefer.has("chain"):
			# A FLIGHT IN TWO LEGS DRAWN BEFORE: its own legs again while they hold,
			# else looked for afresh, its old point tried first (and kept only
			# while the first found without it arrives no sooner, `_chain`).
			# Held, it is kept only while a fresh plan, of one leg or else of two,
			# finds none that arrives sooner (`_sooner_of`), the rule a flight the
			# fallback found is kept by. Against one leg alone, legs searched from
			# their old ones each time their departure went by stood later than
			# two found afresh: in the review's replan chains (the overlay's
			# preview, 30 s, 16 line-ups), 89 drawn plans more than 1 s later, at
			# worst 18.8 s (seed 4242 node 281, orbit9 -9 to keep 5, line-up 1:
			# 139.8 kept where a fresh plan in two legs arrived 121.0; the fifth
			# review, Nov 1)
			var t_us := Time.get_ticks_usec()
			var rc := _chain_again(grav, dep, tgt, t, prefer)
			if rc == null:
				var ch: Dictionary = prefer.chain
				rc = _solve_or_chain(grav, dep, tgt, t, {}, ch.get("W", Vector2.INF))
			elif held:
				rc = _sooner_of(rc, _solve_or_chain(grav, dep, tgt, t, {}, Vector2.INF))
			rc.usec = Time.get_ticks_usec() - t_us
			return rc
		if prefer.has("alt") and held:
			# A FLIGHT OF ONE LEG THAT TOOK OVER FROM ONE IN TWO (`_sooner_of`):
			# itself from its choice as any flight is (else one found afresh, and
			# where one leg finds nothing, two found afresh), beside the old legs
			# again (`_chain_again`), the one that arrives first kept, the old
			# legs on a tie. Without them, the preview that went to one leg went
			# next, where one leg found nothing, to two found afresh, later than
			# its old legs flew (seed 31337 node 28, ring 1 to keep 5, line-up 10:
			# 486.1 drawn where the old legs arrived 463.4, the review of Nov 1).
			# Two found afresh are a fresh plan's, not tried through the old
			# legs' point first: the old legs stand beside them already, and
			# through that point first, where the old legs no longer held, the
			# first found stood later than a fresh plan's (seed 7 node 143, ring
			# 1 to keep 2, line-up 5: 291.63 where a fresh plan arrives 291.50;
			# seed 1999 node 150, star -1 to keep 2, line-up 1: 131.39 against
			# 127.84; the fifth review, Nov 1)
			var t_ua := Time.get_ticks_usec()
			var alt: Dictionary = prefer.alt
			var c1 := prefer.duplicate()
			c1.erase("alt")
			var ra := _chain_again(grav, dep, tgt, t, alt)
			var r := _solve_or_chain(grav, dep, tgt, t, c1, Vector2.INF)
			if ra != null:
				r = _sooner_of(ra, r)
			r.usec = Time.get_ticks_usec() - t_ua
			return r
	return _solve_or_chain(grav, dep, tgt, t, prefer, Vector2.INF)


## A FLIGHT IN TWO LEGS HELD FROM ITS CHOICE (`_chain_again`: rebuilt, or
## searched from its legs) against another plan, r1 (a fresh plan, of one leg
## as a first plan's is, else of two; or, from a flight of one leg that took
## over from them, that flight planned again, else two legs found afresh): the one
## that arrives first, the held legs where they arrive no later, and never a
## flight that is not clean. Held on their cost alone, a preview in two legs
## that began where one leg found nothing stayed in two legs while a fresh
## flight of one arrived far sooner: of every SolveTest fallback flight from a
## ring or alongside planned again 15 times as the overlay does, 63 steps (the
## review of Nov 1), at worst 50.9 s in two legs where one leg flew 13.5 (twin
## 300, ring 2 to star -1, line-up 4). Only round a ring or alongside, the ship
## still where the flight leaves from: free, it is on its way (or a harness's
## free start), and the flight is as `_chain_again` gives it. A flight of one
## leg kept carries the held legs' choice as its `alt` (`solve`): the legs as
## they were flown this time, so once their departure has gone by they are
## searched again from the last search's legs, priced against its cost, and may
## arrive later each time (seed 31337 node 28, ring 1 to keep 5, line-up 11:
## 483.95 to 516.62 over 7 replans, the review of Nov 1). That is kept: they
## are taken only where they arrive sooner than the one leg, and held to the
## arrival they had as one leg took over, or dropped once their departure went
## by, the overlay's preview drew later than this, net, for 12 to 28 s of its
## preview time in each sweep (16 line-ups, 30 s each, the fifth review), to
## save a median of about 90 integrations a replan carrying them. Its
## integrations are both plans'.
static func _sooner_of(rc: Result, r1: Result) -> Result:
	var n := rc.integrations + r1.integrations
	var st := rc.steps + r1.steps
	var out := rc
	if r1.found and r1.clean and float(r1.end.t) < float(rc.end.t) - 1e-6:
		out = r1
		if r1.legs == 1:
			out.choice = r1.choice.duplicate()
			out.choice.alt = rc.choice
	out.integrations = n
	out.steps = st
	return out


## The flight of one leg; in a twin where none is found, of two (`_chain`,
## `hint` its first point tried first).
static func _solve_or_chain(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary, hint: Vector2) -> Result:
	var fs := FlightSolve.new()
	var r := fs._solve(grav, dep, tgt, t, prefer)
	if r.found or not fs._twin or not fs._set:
		return r
	var t_us := Time.get_ticks_usec()
	var rc := _chain(grav, dep, tgt, t, hint)
	if rc == null:
		r.usec += Time.get_ticks_usec() - t_us
		return r
	rc.integrations += r.integrations
	rc.steps += r.steps
	rc.usec = r.usec + Time.get_ticks_usec() - t_us
	return rc


## THE RADIUS OF STAR p'S CLOSE ORBIT, ridden and arrived on (a ring's R and
## rt). One star: 8 inside its ring, as `ShipFlight.orbit_r(-1)` rides it. A
## twin's star: its rail (`star_rail_of`), 2 px outside the keep-out, since its
## ring is only 4 px out and ring - 8 is inside the keep-out (for every twin
## star of 1,710: none of 96 flights there was found, the planner review, Oct 30).
static func star_orbit_r(L: SystemLayout, p: int) -> float:
	if L.twin:
		return L.star_rail_of(p)
	return L.star_ring_of(p) - 8.0


func _solve(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary) -> Result:
	var t_us := Time.get_ticks_usec()
	G = grav
	t_now = t
	_twin = G.star_x0.size() > 1
	_curved = bool(dep.get("_curved", false))
	_cap0 = T_CAP_BACK if _curved else T_CAP
	_hold = float(dep.get("_hold", KEEP_HOLD))
	_kp = float(dep.get("_pace", 1.0))
	_vc = V_CUSP / _kp
	_vsl = V_SLOW / _kp
	_cpad = CUSP_PAD / _kp
	_cin = CUSP_IN / _kp
	_pmin = P_MIN / _kp
	if not _setup(dep, tgt):
		var bad := Result.new()
		bad.usec = Time.get_ticks_usec() - t_us
		return bad
	_set = true
	_tw = TIME_W_BACK if _curved else TIME_W
	var res: Result = null
	if not prefer.is_empty() and int(prefer.get("v", 0)) == CHOICE_V:
		_warm_tier(prefer)
		res = _replay(prefer)
		if res != null and _leg == 0 and _tcap > _cap0 + 1e-6:
			# A FLIGHT THE FALLBACK FOUND, REBUILT AS DRAWN, is kept by the rule it
			# is kept by warm (below): only while a fresh plan (its own budget)
			# finds none clean that arrives sooner. Rebuilt with no look, a preview of
			# the fallback's flight whose departure was still ahead held while a
			# fresh plan flew sooner: of every SolveTest fallback flight from a
			# ring or alongside planned again 15 times as the overlay does, 163
			# steps, at worst 7.9 s (twin 280, ring 0 to ring 2, line-up 11; the
			# review of Nov 1)
			_b_J = INF
			_b = {}
			_budget = _n_integ + BUDGET
			_fresh()
			if _b_J < INF:
				var rf := _build_fresh()
				if rf.found and rf.clean and float(rf.end.t) < float(res.end.t) - 1e-6:
					res = rf
		if res == null and _warm(prefer):
			# KEPT while it costs about what it did; else the search, and the kept
			# flight only if the search does not beat it by as much. A flight the
			# fallback found (its cap past T_CAP) is kept only while a fresh
			# search finds none that arrives sooner, the rule `_fallback` keeps
			# between its two, so the fresh search runs every time. Kept on its
			# own cost, one fallback while a preview was drawn held every later
			# plan of that errand to its slow flight, C's own search never looking
			# again; with C's own search alone looking, an as-built flight of
			# 29.0 s stood where the wider search found one of 18.2, and priced
			# against the fallback's flight with the warm slack, a wider flight of
			# 26.3 s where the as-built one found 23.9 (the reviews, Nov 1: each
			# of SolveTest's fallback flights from a ring or alongside planned
			# again 15 times as the overlay does, 1,790 of the 5,745 kept warm
			# were kept where a fresh plan arrived sooner; none now)
			var j_old := float(prefer.get("J", INF))
			var fell := _leg == 0 and _tcap > _cap0 + 1e-6
			if not fell and _b_J <= j_old + _warm_slack(j_old):
				res = _build(&"warm")
			else:
				var wj := _b_J
				var wb := _b.duplicate()
				var wcap := _tcap
				var wtw := _tw
				var wback := _back
				_b_J = INF
				_b = {}
				# (a budget of its own, so it finds what a fresh search would)
				_budget = _n_integ + BUDGET
				# (and the fallback when that finds nothing, as a fresh plan has:
				# without the wider search a kept flight of 359 stood where a fresh
				# one found 206, SolveTest Oct 31)
				_fresh()
				var keep := _b_J == INF
				if not keep and fell:
					keep = float(wb.te) <= float(_b.te) + 1e-6
				elif not keep:
					# (both at one weight: TIME_W where their searches priced them
					# at two, since at TIME_W_BACK a second costs 32 times less;
					# a leg's two are both the as-built search's)
					var fj := _b_J
					var kj := wj
					if absf(_tw - wtw) > 1e-9:
						fj = _at_time_w(_b_J, _b, _tw)
						kj = _at_time_w(wj, wb, wtw)
					keep = fj + _warm_slack(fj) >= kj
				if keep:
					_b_J = wj
					_b = wb
					_tcap = wcap
					_tw = wtw
					_back = wback
					res = _build(&"warm")
				else:
					res = _build_fresh()
	if res == null:
		# (a budget of its own after a warm start that flew nothing, so it finds
		# what a fresh plan does: on what the warm start had used, C's own search
		# ran short and a flight of 17.9 s the fallback found stood where a
		# fresh plan found one of 14.9, twin 280, orbit9 -9 to ring 1, line-up 4)
		_b_J = INF
		_b = {}
		_budget = _n_integ + BUDGET
		_fresh()
		res = _build_fresh()
	res.integrations = _n_integ
	res.steps = _n_steps
	res.us_seed = _us_seed
	res.us_int = _us_int
	res.us_price = _us_price
	res.us_build = _us_build
	res.usec = Time.get_ticks_usec() - t_us
	return res


static func _warm_slack(j: float) -> float:
	return maxf(WARM_ADD, WARM_K * j)


## A flight's cost j, priced at tw, priced again at TIME_W: its seconds to its
## arrival b.te at the setting's own weight.
func _at_time_w(j: float, b: Dictionary, tw: float) -> float:
	return j + (TIME_W - tw) * (float(b.te) - t_now)


## A CHOICE IS WARMED AS THE SEARCH THAT FOUND IT PRICED IT: to its own time
## cap (`cap`), and at TIME_W_BACK with the as-built search's times where the
## as-built search found it (past T_CAP, its `tw`), so the flight the fallback
## found is kept or beaten on its own terms.
func _warm_tier(c: Dictionary) -> void:
	if _curved:
		_tcap = clampf(float(c.get("cap", T_CAP_BACK)), T_CAP_BACK, maxf(T_CAP_WIDE, T_CAP_BACK))
		_tw = TIME_W_BACK
		_back = true
		return
	_tcap = clampf(float(c.get("cap", T_CAP)), T_CAP, maxf(T_CAP_WIDE, T_CAP_BACK))
	_tw = TIME_W
	_back = false
	if _tcap > T_CAP + 1e-6 and absf(float(c.get("tw", TIME_W)) - TIME_W_BACK) < 1e-9:
		_tw = TIME_W_BACK
		_back = true


func _setup(dep: Dictionary, tgt: Dictionary) -> bool:
	if not _setup_in(dep, tgt):
		return false
	# (keyed on the settled orbit, place -9, whatever it circles: one round a
	# sun of a turning pair rides with that sun, `_dhs`, at the same slow pace,
	# and eases the same. Its pull is read off the ship's speed on the plane,
	# where the curve is drawn, the sun's own motion in it)
	_ease = (_dk == 0 and _dplace == -9) or (_leg == 2 and _dk == 2)
	# THE RIDE'S PHASING, held to THRUST and VMAX on the ring being ridden
	_kmax = 1.0
	if _dk == 0:
		var vr := absf(_dw) * _drt
		_kmax = clampf(minf(1.0 + THRUST * _lmax / (PI * vr), VMAX / vr), 1.0, PHASE_K_MAX)
	# ITS OWN WORLDS keep out to their rings, not past them
	_wkeep = PackedFloat64Array()
	_wkeep.resize(G.wo_keep.size())
	for j in G.wo_keep.size():
		_wkeep[j] = G.wo_keep[j]
		var own := _own_r(G.wo_body[j])
		if own > 0.0:
			_wkeep[j] = maxf(minf(G.wo_keep[j], own - OWN_GAP), G.wo_r[j] + 1.0)
	_gkeep = PackedFloat64Array()
	_gkeep.resize(G.gi_keep.size())
	for j in G.gi_keep.size():
		_gkeep[j] = G.gi_keep[j]
		var own2 := _own_r(G.gi_body[j])
		if own2 > 0.0:
			_gkeep[j] = maxf(minf(G.gi_keep[j], own2 - OWN_GAP), G.gi_r[j] + 1.0)
	return true


## The radius this flight leaves or arrives on round body i, 0 when it is
## neither its departure nor its target.
func _own_r(i: int) -> float:
	var r := 0.0
	if i == _dplace and i >= 0:
		r = _drt if _dk == 0 else (sqrt(_doffx * _doffx + _doffz * _doffz) if _dk == 1 else 0.0)
	if i == _tplace and i >= 0:
		var rt := _tR if _tk == 0 else sqrt(_toffx * _toffx + _toffz * _toffz)
		r = rt if r == 0.0 else minf(r, rt)
	return r


func _setup_in(dep: Dictionary, tgt: Dictionary) -> bool:
	_dw0 = 0.0
	_spin = 0.0
	_lmax = LEAD_MAX
	match StringName(dep.get("kind", &"")):
		&"ring":
			_dk = 0
			if not _place_circle(int(dep.get("place", -9)), dep.get("c", Vector2.ZERO), true, int(dep.get("host", -9))):
				return false
			_drt = float(dep.rt)
			_dang = float(dep.ang)
			_dw = float(dep.w)
			_dw0 = float(dep.get("w0", _dw))
			_spin = float(dep.get("spin", 0.0)) if absf(_dw - _dw0) > 1e-12 else 0.0
			_lmax = maxf(LEAD_MAX, _spin)
			if absf(_dw) < 1e-6 or _drt <= 0.0:
				return false
		&"keep":
			_dk = 1
			if not _place_circle(int(dep.get("place", -9)), dep.get("c", Vector2.ZERO), true, int(dep.get("host", -9))):
				return false
			var o: Vector2 = dep.get("off", Vector2.ZERO)
			_doffx = o.x
			_doffz = o.y
		&"free":
			_dk = 2
			var p: Vector2 = dep.p
			var v: Vector2 = dep.v
			_dpx = p.x
			_dpz = p.y
			_dvx = v.x
			_dvz = v.y
		_:
			return false
	match StringName(tgt.get("kind", &"")):
		&"ring":
			_tk = 0
			_tR = float(tgt.R)
			_tV = float(tgt.V)
			var sn := int(tgt.get("sense", 0))
			_tsense = signi(sn)
			_senses = PackedFloat64Array([1.0, -1.0]) if sn == 0 else PackedFloat64Array([float(signi(sn))])
		&"keep":
			_tk = 1
			var o2: Vector2 = tgt.get("off", Vector2.ZERO)
			_toffx = o2.x
			_toffz = o2.y
			_tsense = 0
			_senses = PackedFloat64Array([1.0])
		_:
			return false
	return _place_circle(int(tgt.get("place", -9)), tgt.get("c", Vector2.ZERO), false, int(tgt.get("host", -9)))


## A place's circle into the departure's (dep) or the target's fields, and the
## sun it rides with (`_dhs`, `_ths`): a world round one sun of a turning pair
## its sun (MapGravity `pl_hs`), a sun's close orbit that sun, and a -9 circle
## the sun `host` names (a settled orbit round one sun: c is then not read, its
## centre being that sun wherever it is). Every other centre holds still.
func _place_circle(p: int, c: Vector2, dep: bool, host: int = -9) -> bool:
	var hx := c.x
	var hz := c.y
	var orb := 0.0
	var n := 0.0
	var ph := 0.0
	var hs := -1
	if p >= 0:
		if p >= G.pl_hx.size():
			return false
		hx = G.pl_hx[p]
		hz = G.pl_hz[p]
		orb = G.pl_orb[p]
		n = G.pl_n[p]
		ph = G.pl_ph[p]
		hs = G.pl_hs[p]
	elif p != -9:
		var k := G.star_index(p)
		if k < 0:
			return false
		hx = G.star_x0[k]
		hz = G.star_z0[k]
		if G.star_rad[k] != 0.0:
			hs = k
	elif host != -9:
		var kh := G.star_index(host)
		if kh >= 0 and G.star_rad[kh] != 0.0:
			hs = kh
			hx = G.star_x0[kh]
			hz = G.star_z0[kh]
	if dep:
		_dhs = hs
		_dplace = p
		_dhx = hx
		_dhz = hz
		_dorb = orb
		_dn = n
		_dph = ph
	else:
		_ths = hs
		_tplace = p
		_thx = hx
		_thz = hz
		_torb = orb
		_tn = n
		_tph = ph
	return true


## The departure's place at t into _cx, _cz and its motion into _cvx, _cvz:
## round its circle, and where the circle rides with a turning sun (`_dhs`), the
## sun where it is at t and its motion added (as `MapGravity.sx`, `svx` have it,
## one cos and sin for both). A centre that holds still is read as it always was.
func _dep_at(t: float) -> void:
	var a := _dph + _dn * t
	var c := cos(a)
	var s := sin(a)
	if _dhs < 0:
		_cx = _dhx + _dorb * c
		_cz = _dhz + _dorb * s
		_cvx = -_dorb * _dn * s
		_cvz = _dorb * _dn * c
		return
	var pa := G.star_ph[_dhs] + G.pair_n * t
	var rc := G.star_rad[_dhs] * cos(pa)
	var rs := G.star_rad[_dhs] * sin(pa)
	_cx = G.star_cx[_dhs] + rc + _dorb * c
	_cz = G.star_cz[_dhs] + rs + _dorb * s
	_cvx = -_dorb * _dn * s - rs * G.pair_n
	_cvz = _dorb * _dn * c + rc * G.pair_n


## The target's, as `_dep_at`.
func _tgt_at(t: float) -> void:
	var a := _tph + _tn * t
	var c := cos(a)
	var s := sin(a)
	if _ths < 0:
		_cx = _thx + _torb * c
		_cz = _thz + _torb * s
		_cvx = -_torb * _tn * s
		_cvz = _torb * _tn * c
		return
	var pa := G.star_ph[_ths] + G.pair_n * t
	var rc := G.star_rad[_ths] * cos(pa)
	var rs := G.star_rad[_ths] * sin(pa)
	_cx = G.star_cx[_ths] + rc + _torb * c
	_cz = G.star_cz[_ths] + rs + _torb * s
	_cvx = -_torb * _tn * s - rs * G.pair_n
	_cvz = _torb * _tn * c + rc * G.pair_n


# ---------------------------------------------------------------- the ride and the departure
## How far round its ring the ride reaches within LEAD_MAX (rad).
func _reach() -> float:
	return absf(_dw) * _lmax * (_kmax + 1.0) * 0.5 - _spin_short() - 1e-6


## How much less far round the spin-up takes a ride (rad): (w - w0) spin / 2.
func _spin_short() -> float:
	return absf(_dw - _dw0) * _spin * 0.5


## THE RIDE dang radians round, the spin-up first: [lead, phasing k] (at least
## the spin long: under it, slowed, and a k under RIDE_K_MIN cannot be flown).
func _ride_lead(dang: float) -> PackedFloat64Array:
	if _spin <= 0.0:
		return _lead_of(dang, absf(_dw))
	var w := absf(_dw)
	var d2 := dang + _spin_short()
	var nat := d2 / w
	if nat < _spin:
		return PackedFloat64Array([_spin, 1.0 + 2.0 * (d2 / (w * _spin) - 1.0)])
	if nat <= _lmax:
		return PackedFloat64Array([nat, 1.0])
	return PackedFloat64Array([_lmax, 1.0 + 2.0 * (d2 / (w * _lmax) - 1.0)])


## the least phasing a ride is flown at (`ShipFlight._takeable`'s)
const RIDE_K_MIN := 0.2


## The ride's phasing work at k (px/s): its push along the ring, up by
## |k - 1| |w| rt and back down.
func _phase_work(k: float) -> float:
	return 2.0 * absf(k - 1.0) * absf(_dw) * _drt


## The ride dang radians round at rate w (> 0): [lead, phasing k]
## (`ShipFlight._lead`'s law: up to LEAD_MAX it simply rides).
static func _lead_of(dang: float, w: float) -> PackedFloat64Array:
	var nat := dang / w
	if nat <= LEAD_MAX:
		return PackedFloat64Array([nat, 1.0])
	return PackedFloat64Array([LEAD_MAX, 1.0 + 2.0 * (dang / (w * LEAD_MAX) - 1.0)])


## The departure angle on the ring for a flight leaving along (ux, uz) relative
## to its place: the point whose ring motion runs along it, or the nearer end
## of the arc the ride reaches.
func _aligned(ux: float, uz: float) -> float:
	var dr := 1.0 if _dw >= 0.0 else -1.0
	var a := atan2(uz, ux) - dr * PI * 0.5
	var dang := fposmod(dr * (a - _dang), TAU)
	var reach := _reach()
	if dang > reach:
		a = _dang + dr * (reach if dang - reach < TAU - dang else 0.0)
	return a


## The ship on its ring at angle a after the ride there: _e_td, _e_lead, _e_k,
## _e_ad and the state _e_x0.. _e_vz0. False when the ride cannot reach it.
func _ride_to(a: float) -> bool:
	var dr := 1.0 if _dw >= 0.0 else -1.0
	var dang := fposmod(dr * (a - _dang), TAU)
	var lk := _ride_lead(dang)
	if lk[1] > _kmax + 1e-6 or lk[1] < RIDE_K_MIN:
		return false
	# (a ride slowed to hold its spin-up, its push held to THRUST as a sped one's)
	if lk[1] < 1.0 and (1.0 - lk[1]) * PI * absf(_dw) * _drt > THRUST * lk[0] + 1e-9:
		return false
	_e_lead = lk[0]
	_e_k = lk[1]
	_e_ph = _phase_work(_e_k)
	_e_td = t_now + _e_lead
	_e_ad = a
	_dep_at(_e_td)
	var ca := cos(a)
	var sa := sin(a)
	_e_x0 = _cx + _drt * ca
	_e_z0 = _cz + _drt * sa
	_e_vx0 = _cvx - _dw * _drt * sa
	_e_vz0 = _cvz + _dw * _drt * ca
	return true


## THE DEPARTURE for leaving with velocity (ux, uz) relative to its place (free:
## absolute), from ring angle a_fix if has_fix: its state and burn into _e_*.
## On a ring the burn is centred on the point the flight leaves from: the ship
## comes off the ring half a burn sooner (as far as the ride allows), so the
## finite burn does what an instant one would there.
func _depart(ux: float, uz: float, has_fix: bool, a_fix: float) -> bool:
	_e_ux = ux
	_e_uz = uz
	_e_fix = has_fix
	_e_afix = a_fix
	_e_ph = 0.0
	_e_a0 = 0.0
	if _dk == 2:
		_e_td = t_now
		_e_lead = 0.0
		_e_k = 1.0
		_e_ad = 0.0
		_e_x0 = _dpx
		_e_z0 = _dpz
		_e_vx0 = _dvx
		_e_vz0 = _dvz
		_e_dvx = ux - _dvx
		_e_dvz = uz - _dvz
		return true
	if _dk == 1:
		# (holding alongside for KEEP_HOLD first)
		_e_td = t_now + _hold
		_e_lead = _hold
		_e_k = 1.0
		_e_ad = 0.0
		_dep_at(_e_td)
		_e_x0 = _cx + _doffx
		_e_z0 = _cz + _doffz
		_e_vx0 = _cvx
		_e_vz0 = _cvz
		_e_dvx = ux
		_e_dvz = uz
		return true
	var a := a_fix if has_fix else _aligned(ux, uz)
	if not _ride_to(a):
		return false
	_e_a0 = a
	_e_dvx = _cvx + ux - _e_vx0
	_e_dvz = _cvz + uz - _e_vz0
	var d1 := sqrt(_e_dvx * _e_dvx + _e_dvz * _e_dvz) / THRUST
	var back := minf(minf(0.5 * d1, _e_lead), BACK_TURN / absf(_dw))
	if back > 1e-6:
		var a_b := a - _dw * back
		var keep := [_e_td, _e_lead, _e_k, _e_ad, _e_x0, _e_z0, _e_vx0, _e_vz0, _e_dvx, _e_dvz, _e_ph]
		if _ride_to(a_b) and _e_td <= float(keep[0]):
			_e_dvx = _cvx + ux - _e_vx0
			_e_dvz = _cvz + uz - _e_vz0
		else:
			_e_td = float(keep[0])
			_e_lead = float(keep[1])
			_e_k = float(keep[2])
			_e_ad = float(keep[3])
			_e_x0 = float(keep[4])
			_e_z0 = float(keep[5])
			_e_vx0 = float(keep[6])
			_e_vz0 = float(keep[7])
			_e_dvx = float(keep[8])
			_e_dvz = float(keep[9])
			_e_ph = float(keep[10])
	return true


## Fly the departure for (ux, uz) and price its arrival: the flight's cost, INF
## when it has no clean arrival. The coast stays in _c*, the flight in _e_*.
## No coast is flown (`_cn` 0) when the ride cannot reach the departure, or
## past the budget: everything that reads the coast checks for one.
func _fly(ux: float, uz: float, has_fix: bool, a_fix: float) -> float:
	_e_J = INF
	if _n_integ >= _budget or not _depart(ux, uz, has_fix, a_fix):
		_cn = 0
		return INF
	var t0 := Time.get_ticks_usec()
	_integrate(_e_td, _e_x0, _e_z0, _e_vx0, _e_vz0, _e_dvx, _e_dvz, t_now + _tcap)
	var t1 := Time.get_ticks_usec()
	# (a departure burn that swings the ship round a point is not flown: `V_CUSP`;
	# nor an eased one the map would draw as a hook, `_burn_tight`)
	if not ((_dk == 0 or _leg == 2) and _departure_cusps()) and not (_ease and _burn_tight()):
		_tight_t = _coast_tight()
		_price()
	_us_int += t1 - t0
	_us_price += Time.get_ticks_usec() - t1
	if _e_J < _b_J:
		_keep_best()
	return _e_J


## WHETHER THE DEPARTURE BURN JUST FLOWN draws a cusp (`V_CUSP`): its speed at
## the coast's nodes through the burn (H_BURN apart, gravity in), and the burn's
## own least speed between them, dipping under V_CUSP and under where it starts
## and ends.
func _departure_cusps() -> bool:
	if _cn < 2 or _tc0 <= _cT[0] + 1e-6:
		return false
	var v0 := sqrt(_cVX[0] * _cVX[0] + _cVZ[0] * _cVZ[0])
	var vmin := INF
	var kmin := 0
	var v1 := v0
	var k := 0
	while k + 1 < _cn and _cT[k] < _tc0 - 1e-9:
		var ax := (_cVX[k + 1] - _cVX[k])
		var az := (_cVZ[k + 1] - _cVZ[k])
		var aa := ax * ax + az * az
		# the least speed on the straight change of velocity across this step
		var tau := clampf(-(_cVX[k] * ax + _cVZ[k] * az) / aa, 0.0, 1.0) if aa > 1e-12 else 0.0
		var mx := _cVX[k] + ax * tau
		var mz := _cVZ[k] + az * tau
		var mv := sqrt(mx * mx + mz * mz)
		if mv < vmin:
			vmin = mv
			kmin = k
		k += 1
		v1 = sqrt(_cVX[k] * _cVX[k] + _cVZ[k] * _cVZ[k])
	return vmin < _vc + _cpad and vmin < minf(v0, v1) - _cin and _turn_round(kmin, k) > CUSP_TURN


## THE MOTION'S TURN ROUND THE BURN'S LEAST SPEED (rad), on step kmin of a burn
## ending at node kend: from the last node before it slower than V_SLOW (or the
## burn's start) to the first after it (or the burn's end).
func _turn_round(kmin: int, kend: int) -> float:
	var ka := kmin
	while ka > 0 and _cVX[ka] * _cVX[ka] + _cVZ[ka] * _cVZ[ka] < _vsl * _vsl:
		ka -= 1
	var kb := mini(kmin + 1, kend)
	while kb < kend and _cVX[kb] * _cVX[kb] + _cVZ[kb] * _cVZ[kb] < _vsl * _vsl:
		kb += 1
	return absf(Vector2(_cVX[ka], _cVZ[ka]).angle_to(Vector2(_cVX[kb], _cVZ[kb])))


## WHERE THE COAST FIRST TURNS TIGHTER THAN THE MAP CAN DRAW (DRAW_K at zoom
## 1), or INF; an arrival whose burn starts after it is not flown. A coast that
## all but stops at the top of its climb and falls back turns there round a
## fraction of a px: out of a settled star orbit, climbing to 1.0 px/s, it drew
## 66 deg a px at zoom 1 (FlightTest, seed 1999 system 226, Oct 31). Read on
## each step's straight change of velocity, at its slowest.
func _coast_tight() -> float:
	var k := 0
	while k < _cn - 1 and _cT[k] < _tc0 - 1e-9:
		k += 1
	return _tight_in(k, _cn - 1)


## WHETHER THE EASED DEPARTURE BURN JUST FLOWN TURNS TIGHTER THAN THE MAP CAN
## DRAW (DRAW_K at zoom 1, as the coast and the arrival are held to): the one
## part of a flight with no such check. Out of a settled orbit round a close
## pair's balance point to star A's close orbit, a burn that dipped to 5.8 px/s,
## over the cusp test's 5.5, bent round 4 px and drew 20 deg a px (FlightTest,
## seed 4242 system 208, Nov 2); found without it, 14.55 s against 8.16, bent
## round 20.7 px. In every system, one sun included (Jon, Nov 2, "Pair calls:
## 2Y"), so a one-sun flight it flags is no longer the one flown before this
## branch. Out of a settled star orbit to world 1, seed 7 system 125 drew a
## tight U-turn as it left the orbit, at zoom 1 and 2: 11.83 s became 13.70 s,
## riding further round first. It changes 0 of 3888 SolveTest plans round one
## sun, 3 of 4656 with a heavy giant, and 1 of 899 and 1 of 1162 FlightTest
## flights (review 2).
func _burn_tight() -> bool:
	if _cn < 2:
		return false
	var k := 0
	while k < _cn - 1 and _cT[k] < _tc0 - 1e-9:
		k += 1
	return _tight_in(0, k) < INF


## Where the coast's nodes k to kend first turn tighter than DRAW_K, or INF (see
## `_coast_tight`).
func _tight_in(k: int, kend: int) -> float:
	while k < kend:
		var h := _cT[k + 1] - _cT[k]
		if h > 1e-9:
			var dvx := _cVX[k + 1] - _cVX[k]
			var dvz := _cVZ[k + 1] - _cVZ[k]
			var dd := dvx * dvx + dvz * dvz
			var u := clampf(-(_cVX[k] * dvx + _cVZ[k] * dvz) / dd, 0.0, 1.0) if dd > 1e-12 else 0.0
			var vx := _cVX[k] + dvx * u
			var vz := _cVZ[k] + dvz * u
			var dn := pow(vx * vx + DRAW_TILT * DRAW_TILT * vz * vz, 1.5)
			if dn > 1e-12 and DRAW_TILT * absf(vx * dvz - vz * dvx) / h / dn > DRAW_K:
				return _cT[k] + u * h
		k += 1
	return INF


## Whether the arrival burn ending at te (`_arrival`'s [.., d, dxx, dxz, dux,
## duz, ..]) draws a cusp: the coast's motion plus the burn's, sampled at 17
## points, its least speed read between each two as well. The points alone are
## 1/16 of the burn apart, and a fast arrival's burn is long: from alongside a
## station to world 0 (SolveTest, seed 4242 node 281, line-up 3, at ruling
## 21's C) a 6.2 s burn took the ship from 111 px/s down to 4.4 and out at
## 34.5, turned round 177 deg, and was flown, since the points either side of
## its least speed, 0.39 s apart, read 7.5 and 6.4 px/s (Nov 1).
func _arrival_cusps(te: float, ar: PackedFloat64Array) -> bool:
	var d := ar[2]
	if d <= 1e-6:
		return false
	var dxx := ar[3]
	var dxz := ar[4]
	var dux := ar[5]
	var duz := ar[6]
	var Ax := 3.0 * dxx - dux * d
	var Az := 3.0 * dxz - duz * d
	var Bx := dux * d - 2.0 * dxx
	var Bz := duz * d - 2.0 * dxz
	var vmin := INF
	var jmin := 0
	var v0 := 0.0
	var v1 := 0.0
	var vs := PackedVector2Array()
	var lefts := PackedFloat64Array()
	var ex := 0.0
	var ez := 0.0
	for j in 17:
		var tau := float(j) / 16.0
		var tq := te - d + tau * d
		var c := _coast_at(tq)
		var vx := c[2] + (2.0 * Ax * tau + 3.0 * Bx * tau * tau) / d
		var vz := c[3] + (2.0 * Az * tau + 3.0 * Bz * tau * tau) / d
		vs.append(Vector2(vx, vz))
		# A BURN TURNING THE SHIP TIGHTER THAN THE MAP CAN DRAW: its curve as
		# drawn at zoom 1 (the plane tilted, TILT), the stars' and the giant's
		# pull and the burn's together. Arriving at 19 px/s, a constant burn
		# at THRUST across the motion bent it round 9 px, seen end on 1.3 px
		# across: 22 deg a px (FlightTest, seed 4242 system 291, Oct 31).
		# (Alongside, the line ends where the ship stops: its last px and a
		# half, where it slows to the place's own crawl, is not a turn drawn)
		var px := c[0] + Ax * tau * tau + Bx * tau * tau * tau
		var pz := c[1] + Az * tau * tau + Bz * tau * tau * tau
		if j == 0:
			var ce := _coast_at(te)
			ex = ce[0] + Ax + Bx
			ez = ce[1] + Az + Bz
		var left := Vector2(ex - px, DRAW_TILT * (ez - pz)).length()
		lefts.append(left)
		if _tk != 1 or left > 1.5:
			_acc_at(px, pz, tq)
			var ax := _ax + (2.0 * Ax + 6.0 * Bx * tau) / (d * d)
			var az := _az + (2.0 * Az + 6.0 * Bz * tau) / (d * d)
			var dn := pow(vx * vx + DRAW_TILT * DRAW_TILT * vz * vz, 1.5)
			if dn > 1e-9 and DRAW_TILT * absf(vx * az - vz * ax) / dn > DRAW_K:
				return true
		var sp := sqrt(vx * vx + vz * vz)
		if j == 0:
			v0 = sp
		elif j == 16:
			v1 = sp
		elif sp < vmin:
			vmin = sp
			jmin = j
	var ja := jmin
	var jb := jmin
	# (between each two: the least speed on the straight change of velocity
	# across the step, as `_departure_cusps` reads a departure's. Alongside,
	# not where that least speed falls in the last px and a half left (the
	# step's two lefts, taken at its point), where the ship falls in with the
	# place's own crawl: it all but stops there and turns with the place, which
	# is no turn drawn. Read there, it lost 7 of SolveTest's 8,544 one-sun
	# and giant flights and flew 135 others another way (117 of them over
	# 0.3 s longer), every one arriving alongside; and skipped only where a
	# step started in that last px and a half, the last step (from 1.5 to
	# 4.5 px out, to the end) still read the crawl and turned down 9 giant
	# plans of 4,656 and 4 of FlightTest's 3,832 flights that are no cusp,
	# Nov 1)
	for j in 16:
		if _tk == 1 and lefts[j] <= 1.5:
			continue
		var gx := vs[j + 1].x - vs[j].x
		var gz := vs[j + 1].y - vs[j].y
		var gg := gx * gx + gz * gz
		if gg < 1e-12:
			continue
		var u := -(vs[j].x * gx + vs[j].y * gz) / gg
		if u > 0.0 and u < 1.0:
			if _tk == 1 and lerpf(lefts[j], lefts[j + 1], u) <= 1.5:
				continue
			var su := Vector2(vs[j].x + gx * u, vs[j].y + gz * u).length()
			if su < vmin:
				vmin = su
				ja = j
				jb = j + 1
	if not (vmin < _vc + _cpad and vmin < minf(v0, v1) - _cin):
		return false
	# (the turn round it while slower than V_SLOW, as `_turn_round` reads a departure)
	while ja > 0 and vs[ja].length() < _vsl:
		ja -= 1
	while jb < 16 and vs[jb].length() < _vsl:
		jb += 1
	return absf(vs[ja].angle_to(vs[jb])) > CUSP_TURN


func _keep_best() -> void:
	_b_J = _e_J
	_b = {"ux": _e_ux, "uz": _e_uz, "fix": _e_fix, "afix": _e_afix, "a0": _e_a0, "td": _e_td, "ad": _e_ad,
		"x0": _e_x0, "z0": _e_z0, "vx0": _e_vx0, "vz0": _e_vz0, "dvx": _e_dvx, "dvz": _e_dvz,
		"te": _e_te, "s": _e_s, "phi": _e_phi, "d2": _e_d2, "w2": _e_w2, "lead": _e_lead, "k": _e_k, "ph": _e_ph, "pk": _e_pk}


# ---------------------------------------------------------------- the coast
## THE FLIGHT FROM (x, z, vx, vz) AT td: a burn of (dvx, dvz) at THRUST, then the
## coast, to t_now + T_CAP (or on past a broken keep-out for D2_MAX, or out of
## the system). Fixed-step RK4 in scalars, the pull summed inline (two stars
## and a giant at most take the fast path), each step's closest approach to
## every keep-out on the cubic through its ends.
func _integrate(td: float, x: float, z: float, vx: float, vz: float, dvx: float, dvz: float, t_end: float) -> void:
	_n_integ += 1
	var cap := 4096
	if _cT.size() < cap:
		_cT.resize(cap)
		_cX.resize(cap)
		_cZ.resize(cap)
		_cVX.resize(cap)
		_cVZ.resize(cap)
		_cCL.resize(cap)
	var ns := G.star_x0.size()
	var ng := G.gi_hx.size()
	var nw := G.wo_hx.size()
	# (a coast flown with no flight set up, as a bench does: MapGravity's own)
	if _wkeep.size() != nw:
		_wkeep = G.wo_keep
	if _gkeep.size() != ng:
		_gkeep = G.gi_keep
	var fast := ns <= 2 and ng <= 1
	var s0x := G.star_x0[0] if ns > 0 else 0.0
	var s0z := G.star_z0[0] if ns > 0 else 0.0
	var s0g := G.star_gm[0] if ns > 0 else 0.0
	var s0k := G.star_keep[0] if ns > 0 else 0.0
	var s1x := G.star_x0[1] if ns > 1 else 0.0
	var s1z := G.star_z0[1] if ns > 1 else 0.0
	var s1g := G.star_gm[1] if ns > 1 else 0.0
	var s1k := G.star_keep[1] if ns > 1 else 0.0
	# THE PAIR TURNS (ruling 23): both suns on their circle round the balance
	# point, read as the giant is at the step's start (carried from the last
	# step's end), middle and end; one cos and sin a place for both, since they
	# share one angle (MapGravity `star_ph`, their signed `star_rad` along the
	# line). A sun that holds still -- one alone, a pair held still -- is read
	# as it always was.
	var spin := ns == 2 and G.pair_n != 0.0 and G.star_rad[0] != 0.0 and G.star_rad[1] != 0.0
	var pcx0 := G.star_cx[0] if spin else 0.0
	var pcz0 := G.star_cz[0] if spin else 0.0
	var pcx1 := G.star_cx[1] if spin else 0.0
	var pcz1 := G.star_cz[1] if spin else 0.0
	var pr0 := G.star_rad[0] if spin else 0.0
	var pr1 := G.star_rad[1] if spin else 0.0
	var pph := G.star_ph[0] if spin else 0.0
	var pnn := G.pair_n if spin else 0.0
	if spin:
		var ca := cos(pph + pnn * td)
		var sa := sin(pph + pnn * td)
		s0x = pcx0 + pr0 * ca
		s0z = pcz0 + pr0 * sa
		s1x = pcx1 + pr1 * ca
		s1z = pcz1 + pr1 * sa
	var ghx := G.gi_hx[0] if ng > 0 else 0.0
	var ghz := G.gi_hz[0] if ng > 0 else 0.0
	# (the star giant 0's circle is carried round with, -1 none: in the layout's
	# twins every giant circles both suns, but a harness may carry one)
	var ghs := G.gi_hs[0] if ng > 0 and spin else -1
	var gor := G.gi_orb[0] if ng > 0 else 0.0
	var gnn := G.gi_n[0] if ng > 0 else 0.0
	var gph := G.gi_ph[0] if ng > 0 else 0.0
	var ggm := G.gi_gm[0] if ng > 0 else 0.0
	var gkp := _gkeep[0] if ng > 0 else 0.0
	# THE DEPARTURE BURN: dv delivered along its own way, its pull eased while
	# the ship is slow (R_BURN), held for each step of at most H_BURN
	var dv := sqrt(dvx * dvx + dvz * dvz)
	var bux := dvx / dv if dv > 1e-9 else 0.0
	var buz := dvz / dv if dv > 1e-9 else 0.0
	var rem := dv if dv > 1e-9 else 0.0
	var t := td
	var lost2 := pow(G.edge * 1.6, 2.0)
	_tc0 = td + dv / THRUST
	_t_bad = INF
	var clear := INF
	_cT[0] = t
	_cX[0] = x
	_cZ[0] = z
	_cVX[0] = vx
	_cVZ[0] = vz
	_cCL[0] = INF
	var n := 1
	var k := 0
	# the giant's place at the step's start (carried from the last step's end)
	var gx0 := 0.0
	var gz0 := 0.0
	if ng > 0:
		var gcx := ghx if ghs < 0 else (s0x if ghs == 0 else s1x)
		var gcz := ghz if ghs < 0 else (s0z if ghs == 0 else s1z)
		gx0 = gcx + gor * cos(gph + gnn * t)
		gz0 = gcz + gor * sin(gph + gnn * t)
	while t < t_end - 1e-9 and n < cap:
		var h := 0.0
		var ax_t := 0.0
		var az_t := 0.0
		var burn_ends := false
		if rem > 0.0:
			var pull := THRUST
			if _ease:
				var sp0 := sqrt(vx * vx + vz * vz)
				pull = clampf(sp0 * sp0 / R_BURN, _pmin, THRUST)
			h = minf(H_BURN, rem / pull)
			ax_t = bux * pull
			az_t = buz * pull
			rem -= pull * h
			if rem <= 1e-9:
				rem = 0.0
				burn_ends = true
		else:
			# a tenth of the nearest pull's own time
			var tau2 := INF
			if ns > 0:
				var ex := s0x - x
				var ez := s0z - z
				var q2 := ex * ex + ez * ez
				tau2 = q2 * sqrt(q2) / s0g
			if ns > 1:
				var ex1 := s1x - x
				var ez1 := s1z - z
				var q21 := ex1 * ex1 + ez1 * ez1
				tau2 = minf(tau2, q21 * sqrt(q21) / s1g)
			if ng > 0:
				var exg := gx0 - x
				var ezg := gz0 - z
				var q2g := exg * exg + ezg * ezg
				tau2 = minf(tau2, q2g * sqrt(q2g) / ggm)
			h = clampf(ETA * sqrt(tau2), H_MIN, H_MAX)
			if t + h > t_end:
				h = t_end - t
		var hh := 0.5 * h
		# the suns at the step's middle (m) and end (e)
		var m0x := s0x
		var m0z := s0z
		var m1x := s1x
		var m1z := s1z
		var e0x := s0x
		var e0z := s0z
		var e1x := s1x
		var e1z := s1z
		if spin:
			var cm := cos(pph + pnn * (t + hh))
			var sm := sin(pph + pnn * (t + hh))
			m0x = pcx0 + pr0 * cm
			m0z = pcz0 + pr0 * sm
			m1x = pcx1 + pr1 * cm
			m1z = pcz1 + pr1 * sm
			var ce := cos(pph + pnn * (t + h))
			var se := sin(pph + pnn * (t + h))
			e0x = pcx0 + pr0 * ce
			e0z = pcz0 + pr0 * se
			e1x = pcx1 + pr1 * ce
			e1z = pcz1 + pr1 * se
		# the giant at the step's middle and end
		var gxm := gx0
		var gzm := gz0
		var gx1 := gx0
		var gz1 := gz0
		if ng > 0:
			var am := gph + gnn * (t + hh)
			var a1 := gph + gnn * (t + h)
			if ghs < 0:
				gxm = ghx + gor * cos(am)
				gzm = ghz + gor * sin(am)
				gx1 = ghx + gor * cos(a1)
				gz1 = ghz + gor * sin(a1)
			else:
				gxm = (m0x if ghs == 0 else m1x) + gor * cos(am)
				gzm = (m0z if ghs == 0 else m1z) + gor * sin(am)
				gx1 = (e0x if ghs == 0 else e1x) + gor * cos(a1)
				gz1 = (e0z if ghs == 0 else e1z) + gor * sin(a1)
		var a1x := ax_t
		var a1z := az_t
		var a2x := ax_t
		var a2z := az_t
		var a3x := ax_t
		var a3z := az_t
		var a4x := ax_t
		var a4z := az_t
		var x2 := x + hh * vx
		var z2 := z + hh * vz
		var x3 := 0.0
		var z3 := 0.0
		var x4 := 0.0
		var z4 := 0.0
		var v2x := 0.0
		var v2z := 0.0
		var v3x := 0.0
		var v3z := 0.0
		var v4x := 0.0
		var v4z := 0.0
		if fast:
			# k1
			var dx := s0x - x
			var dz := s0z - z
			var r2 := dx * dx + dz * dz
			var f := s0g / (r2 * sqrt(r2))
			a1x += f * dx
			a1z += f * dz
			if ns > 1:
				dx = s1x - x
				dz = s1z - z
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a1x += f * dx
				a1z += f * dz
			if ng > 0:
				dx = gx0 - x
				dz = gz0 - z
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a1x += f * dx
				a1z += f * dz
			v2x = vx + hh * a1x
			v2z = vz + hh * a1z
			# k2
			dx = m0x - x2
			dz = m0z - z2
			r2 = dx * dx + dz * dz
			f = s0g / (r2 * sqrt(r2))
			a2x += f * dx
			a2z += f * dz
			if ns > 1:
				dx = m1x - x2
				dz = m1z - z2
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a2x += f * dx
				a2z += f * dz
			if ng > 0:
				dx = gxm - x2
				dz = gzm - z2
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a2x += f * dx
				a2z += f * dz
			x3 = x + hh * v2x
			z3 = z + hh * v2z
			v3x = vx + hh * a2x
			v3z = vz + hh * a2z
			# k3
			dx = m0x - x3
			dz = m0z - z3
			r2 = dx * dx + dz * dz
			f = s0g / (r2 * sqrt(r2))
			a3x += f * dx
			a3z += f * dz
			if ns > 1:
				dx = m1x - x3
				dz = m1z - z3
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a3x += f * dx
				a3z += f * dz
			if ng > 0:
				dx = gxm - x3
				dz = gzm - z3
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a3x += f * dx
				a3z += f * dz
			x4 = x + h * v3x
			z4 = z + h * v3z
			v4x = vx + h * a3x
			v4z = vz + h * a3z
			# k4
			dx = e0x - x4
			dz = e0z - z4
			r2 = dx * dx + dz * dz
			f = s0g / (r2 * sqrt(r2))
			a4x += f * dx
			a4z += f * dz
			if ns > 1:
				dx = e1x - x4
				dz = e1z - z4
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a4x += f * dx
				a4z += f * dz
			if ng > 0:
				dx = gx1 - x4
				dz = gz1 - z4
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a4x += f * dx
				a4z += f * dz
		else:
			var g1 := G.acc(x, z, t)
			a1x += g1[0]
			a1z += g1[1]
			v2x = vx + hh * a1x
			v2z = vz + hh * a1z
			var g2 := G.acc(x2, z2, t + hh)
			a2x += g2[0]
			a2z += g2[1]
			x3 = x + hh * v2x
			z3 = z + hh * v2z
			v3x = vx + hh * a2x
			v3z = vz + hh * a2z
			var g3 := G.acc(x3, z3, t + hh)
			a3x += g3[0]
			a3z += g3[1]
			x4 = x + h * v3x
			z4 = z + h * v3z
			v4x = vx + h * a3x
			v4z = vz + h * a3z
			var g4 := G.acc(x4, z4, t + h)
			a4x += g4[0]
			a4z += g4[1]
		var h6 := h / 6.0
		var nx := x + h6 * (vx + 2.0 * v2x + 2.0 * v3x + v4x)
		var nz := z + h6 * (vz + 2.0 * v2z + 2.0 * v3z + v4z)
		var nvx := vx + h6 * (a1x + 2.0 * a2x + 2.0 * a3x + a4x)
		var nvz := vz + h6 * (a1z + 2.0 * a2z + 2.0 * a3z + a4z)
		_n_steps += 1
		# KEEP-OUT between the steps: only where the step comes near enough
		var reach := h * (sqrt(vx * vx + vz * vz) + sqrt(nvx * nvx + nvz * nvz)) * 0.5 + 1.0
		var deep := false
		for j in ns:
			# (each sun where it is at the step's middle, as the giant is)
			var ox := m0x if j == 0 else (m1x if j == 1 else G.sx(j, t + hh))
			var oz := m0z if j == 0 else (m1z if j == 1 else G.sz(j, t + hh))
			var kp := s0k if j == 0 else (s1k if j == 1 else G.star_keep[j])
			var dd := sqrt((nx - ox) * (nx - ox) + (nz - oz) * (nz - oz))
			if dd < 0.5 * kp:
				deep = true
			if dd - kp < reach + 40.0:
				var m := _step_min(x, z, vx, vz, nx, nz, nvx, nvz, h, ox, oz) - kp
				clear = minf(clear, m)
				if m < 0.0 and _t_bad == INF:
					_t_bad = t
		for j in ng:
			var ox2 := gxm if j == 0 else G.giant_at(j, t + hh)[0]
			var oz2 := gzm if j == 0 else G.giant_at(j, t + hh)[1]
			var kp2 := gkp if j == 0 else _gkeep[j]
			var dd2 := sqrt((nx - ox2) * (nx - ox2) + (nz - oz2) * (nz - oz2))
			if dd2 < 0.5 * kp2:
				deep = true
			if dd2 - kp2 < reach + 40.0:
				var m2 := _step_min(x, z, vx, vz, nx, nz, nvx, nvz, h, ox2, oz2) - kp2
				clear = minf(clear, m2)
				if m2 < 0.0 and _t_bad == INF:
					_t_bad = t
		for j in nw:
			# (cheap first: how far the step is from the world's whole orbit,
			# round where its centre is at the step's middle: a world round one
			# sun of a turning pair rides with it, `wo_hs`)
			var whs := G.wo_hs[j]
			var whx: float = G.wo_hx[j] if whs < 0 else (m0x if whs == 0 else (m1x if whs == 1 else G.sx(whs, t + hh)))
			var whz: float = G.wo_hz[j] if whs < 0 else (m0z if whs == 0 else (m1z if whs == 1 else G.sz(whs, t + hh)))
			var rh := sqrt((nx - whx) * (nx - whx) + (nz - whz) * (nz - whz))
			var kp3: float = _wkeep[j]
			if absf(rh - G.wo_orb[j]) - kp3 > reach + 40.0:
				continue
			var aw := G.wo_ph[j] + G.wo_n[j] * (t + hh)
			var ox3 := whx + G.wo_orb[j] * cos(aw)
			var oz3 := whz + G.wo_orb[j] * sin(aw)
			var dd3 := sqrt((nx - ox3) * (nx - ox3) + (nz - oz3) * (nz - oz3))
			if dd3 - kp3 < reach + 40.0:
				var m3 := _step_min(x, z, vx, vz, nx, nz, nvx, nvz, h, ox3, oz3) - kp3
				clear = minf(clear, m3)
				if m3 < 0.0 and _t_bad == INF:
					_t_bad = t
		x = nx
		z = nz
		vx = nvx
		vz = nvz
		t += h
		k += 1
		if burn_ends:
			_tc0 = t
		gx0 = gx1
		gz0 = gz1
		s0x = e0x
		s0z = e0z
		s1x = e1x
		s1z = e1z
		_cT[n] = t
		_cX[n] = x
		_cZ[n] = z
		_cVX[n] = vx
		_cVZ[n] = vz
		_cCL[n] = clear
		n += 1
		# ON PAST A BROKEN KEEP-OUT for as long as an arrival burn lasts: an
		# arrival that starts its burn before it never flies the rest
		if _t_bad < INF and (t > _t_bad + D2_MAX or deep):
			break
		# (lost past 1.6 edges from the plane's origin, star A's place at t 0: a
		# frame that holds still while a pair turns, as the map's edge does)
		if x * x + z * z > lost2:
			break
	_cn = n


## The least distance to (ox, oz) over one step, on the cubic through its ends
## (a golden-section search where the step passes its closest).
static func _step_min(x0: float, z0: float, vx0: float, vz0: float, x1: float, z1: float, vx1: float, vz1: float, h: float, ox: float, oz: float) -> float:
	var d0 := sqrt((x0 - ox) * (x0 - ox) + (z0 - oz) * (z0 - oz))
	var dd1 := sqrt((x1 - ox) * (x1 - ox) + (z1 - oz) * (z1 - oz))
	var best := minf(d0, dd1)
	var r0 := (x0 - ox) * vx0 + (z0 - oz) * vz0
	var r1 := (x1 - ox) * vx1 + (z1 - oz) * vz1
	if r0 < 0.0 and r1 > 0.0:
		var a := 0.0
		var b := 1.0
		var g := 0.6180339887498949
		for _i in 14:
			var c := b - g * (b - a)
			var d := a + g * (b - a)
			var xc := _herm(x0, vx0, x1, vx1, h, c) - ox
			var zc := _herm(z0, vz0, z1, vz1, h, c) - oz
			var xd := _herm(x0, vx0, x1, vx1, h, d) - ox
			var zd := _herm(z0, vz0, z1, vz1, h, d) - oz
			if xc * xc + zc * zc < xd * xd + zd * zd:
				b = d
			else:
				a = c
		var u := 0.5 * (a + b)
		var xm := _herm(x0, vx0, x1, vx1, h, u) - ox
		var zm := _herm(z0, vz0, z1, vz1, h, u) - oz
		best = minf(best, sqrt(xm * xm + zm * zm))
	return best


static func _herm(p0: float, v0: float, p1: float, v1: float, h: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * h * v0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * h * v1


static func _hermd(p0: float, v0: float, p1: float, v1: float, h: float, u: float) -> float:
	var u2 := u * u
	return ((6.0 * u2 - 6.0 * u) * p0 + (3.0 * u2 - 4.0 * u + 1.0) * h * v0 + (-6.0 * u2 + 6.0 * u) * p1 + (3.0 * u2 - 2.0 * u) * h * v1) / h


## The coast at time tq (inside it): [x, z, vx, vz], and the node it is after in _qk.
var _qk := 0
func _coast_at(tq: float) -> PackedFloat64Array:
	# binary search on the nodes
	var lo := 0
	var hi := _cn - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _cT[mid] <= tq:
			lo = mid
		else:
			hi = mid
	_qk = lo
	return _coast_k(lo, tq)


func _coast_k(k: int, tq: float) -> PackedFloat64Array:
	var k1 := mini(k + 1, _cn - 1)
	var h := _cT[k1] - _cT[k]
	if h <= 0.0:
		return PackedFloat64Array([_cX[k], _cZ[k], _cVX[k], _cVZ[k]])
	var u := (tq - _cT[k]) / h
	return PackedFloat64Array([_herm(_cX[k], _cVX[k], _cX[k1], _cVX[k1], h, u), _herm(_cZ[k], _cVZ[k], _cZ[k1], _cVZ[k1], h, u),
		_hermd(_cX[k], _cVX[k], _cX[k1], _cVX[k1], h, u), _hermd(_cZ[k], _cVZ[k], _cZ[k1], _cVZ[k1], h, u)])


# ---------------------------------------------------------------- the arrival
## THE RING POINT A CONSTANT-THRUST BURN WOULD END ON from the coast's state (r,
## u) relative to the target at te, sense s, its pull pk: [radial mismatch g,
## angle phi, burn length d]. A constant burn of length d ends at r_T, u_T
## exactly when r_T - u_T d/2 = r - u d/2 (the virtual point q), and |r_T - u_T
## d/2| is the same all round the ring, so phi follows from q's angle and g is
## the miss. Into _vg, _vphi, _vd (it runs at every node near the target, so it
## takes a few rounds of d, not the exact one: `_const_burn` is that).
var _vg := 0.0
var _vphi := 0.0
var _vd := 0.0
func _virt(rx: float, rz: float, ux: float, uz: float, s: float, rounds: int = 3, pk: float = THRUST) -> void:
	var d := 0.0
	var phi := atan2(rz, rx)
	var R := _tR
	var V := _tV
	for _i in rounds:
		var qx := rx - ux * d * 0.5
		var qz := rz - uz * d * 0.5
		phi = atan2(qz, qx) + s * atan2(V * d * 0.5, R)
		var tx := -sin(phi) * s * V
		var tz := cos(phi) * s * V
		d = sqrt((tx - ux) * (tx - ux) + (tz - uz) * (tz - uz)) / pk
	var qx2 := rx - ux * d * 0.5
	var qz2 := rz - uz * d * 0.5
	_vg = sqrt(qx2 * qx2 + qz2 * qz2) - sqrt(R * R + V * d * 0.5 * V * d * 0.5)
	_vphi = phi
	_vd = d


## THE CONSTANT BURN THAT ENDS ON THE RING AT te EXACTLY, from the coast's
## state (r, u) relative to the target there, sense s. A constant pull a for d
## seconds on top of the coast ends at r + a d^2/2, u + a d: on the ring at its
## speed when r - u d/2 = R e(phi) - s V d/2 e'(phi), whose size is sqrt(R^2 +
## V^2 d^2/4) all round, so d is a root of
##   (|u|^2 - V^2)/4 d^2 - (r.u) d + |r|^2 - R^2 = 0
## (the one nearest d_near) and phi follows from the angle. Into _kd, _kphi and
## _ka, the pull |du| / d it takes; false when there is no root.
var _kd := 0.0
var _kphi := 0.0
var _ka := 0.0
func _const_burn(rx: float, rz: float, ux: float, uz: float, s: float, d_near: float) -> bool:
	var R := _tR
	var V := _tV
	var a2 := 0.25 * (ux * ux + uz * uz - V * V)
	var b1 := -(rx * ux + rz * uz)
	var c0 := rx * rx + rz * rz - R * R
	var d := -1.0
	if absf(a2) < 1e-9:
		if absf(b1) > 1e-12:
			d = -c0 / b1
	else:
		var disc := b1 * b1 - 4.0 * a2 * c0
		if disc < 0.0:
			return false
		var sq := sqrt(disc)
		# (the pair of roots that loses no digits)
		var q := -0.5 * (b1 + (sq if b1 >= 0.0 else -sq))
		var r1 := q / a2
		var r2 := c0 / q if absf(q) > 1e-300 else -1.0
		if r1 > 1e-6 and (r2 <= 1e-6 or absf(r1 - d_near) <= absf(r2 - d_near)):
			d = r1
		elif r2 > 1e-6:
			d = r2
	if d <= 1e-6:
		return false
	var qx := rx - ux * d * 0.5
	var qz := rz - uz * d * 0.5
	var phi := atan2(qz, qx) + s * atan2(V * d * 0.5, R)
	var dux := -sin(phi) * s * V - ux
	var duz := cos(phi) * s * V - uz
	_kd = d
	_kphi = phi
	_ka = sqrt(dux * dux + duz * duz) / d
	return true


## The pull of the constant burn ending at te (`_const_burn`), NAN where there
## is none or it would start before the departure burn ends.
## (d_near < 0: the virtual point's own d)
func _ka_at(te: float, s: float, d_near: float) -> float:
	if te > _cT[_cn - 1] or te < _tc0:
		return NAN
	var c := _coast_at(te)
	_tgt_at(te)
	var rx := c[0] - _cx
	var rz := c[1] - _cz
	var ux := c[2] - _cvx
	var uz := c[3] - _cvz
	if d_near < 0.0:
		_virt(rx, rz, ux, uz, s, 3)
		d_near = _vd
	if not _const_burn(rx, rz, ux, uz, s, d_near) or te - _kd < _tc0:
		return NAN
	return _ka


## WHERE THE ARRIVAL'S CONSTANT BURN PULLS pk EXACTLY: a secant on te from te0
## (where the coast's virtual point crosses the ring's, found between nodes),
## the pull falling as the arrival comes later. te0 when it finds none. Found
## between nodes alone, the crossing left the burn up to some px off a
## constant one, and the burn that held its pull then lasted three times as
## long, pulling against its own change for the first third (the planner
## review, Oct 30).
func _te_for(te0: float, s: float, pk: float, d_near: float) -> float:
	var lo := _tc0
	var hi := minf(_cT[_cn - 1], t_now + _tcap)
	var t1 := te0
	var f1 := _ka_at(t1, s, d_near) - pk
	if is_nan(f1):
		return te0
	if absf(f1) < 1e-5 * pk:
		return t1
	var dn := _kd
	var t2 := clampf(t1 + (0.01 if f1 > 0.0 else -0.01), lo, hi)
	var f2 := _ka_at(t2, s, dn) - pk
	for _i in 6:
		if is_nan(f2) or f2 == f1:
			break
		dn = _kd
		if absf(f2) < 1e-5 * pk:
			return t2
		var t3 := clampf(t2 - f2 * (t2 - t1) / (f2 - f1), lo, hi)
		t1 = t2
		f1 = f2
		t2 = t3
		f2 = _ka_at(t2, s, dn) - pk
	if not is_nan(f2) and absf(f2) < 1e-3 * pk:
		return t2
	return te0


## THE ARRIVAL BURN for a change of position (dxx, dxz) and velocity (dux, duz)
## off the coast: P(tau) = A tau^2 + B tau^3 on top of the coast, A = 3 dx -
## du d, B = du d - 2 dx; its pull (2A + 6B tau) / d^2 is linear, so at most
## pk means at both ends. [d, engine work], d the least that holds, or empty
## past 64 s. No burn that holds to pk changes the velocity by |du| in less
## than |du| / pk; there, it holds only as a constant burn (dx = du d/2), and
## just past it only in a window a few percent wide (one end's pull falls as
## the burn lengthens and the other's rises), or not at all where the miss is
## across the motion. So the least pull is looked for there first (to BURN_TOL
## over), and only then further out, where the pull turns over: it first pulls
## against du, then with it, from about three times as long. The first build
## doubled its way out from 0.05 s and so always stepped over the window, and
## every arrival burn lasted three times the least (the planner review).
static func _cubic_burn(dxx: float, dxz: float, dux: float, duz: float, pk: float = THRUST) -> PackedFloat64Array:
	var du := sqrt(dux * dux + duz * duz)
	var lb := maxf(du / pk, 1e-3)
	var d := -1.0
	var pl := _peak(dxx, dxz, dux, duz, lb)
	if pl <= pk:
		d = lb
	else:
		# near the least: the lowest peak, golden section on [lb, 1.5 lb], where
		# it falls to a point and then rises
		var a := lb
		var b := 1.5 * lb
		var gr := 0.6180339887498949
		var c := b - gr * (b - a)
		var e := a + gr * (b - a)
		var fc := _peak(dxx, dxz, dux, duz, c)
		var fe := _peak(dxx, dxz, dux, duz, e)
		for _i in 18:
			if fc < fe:
				b = e
				e = c
				fe = fc
				c = b - gr * (b - a)
				fc = _peak(dxx, dxz, dux, duz, c)
			else:
				a = c
				c = e
				fc = fe
				e = a + gr * (b - a)
				fe = _peak(dxx, dxz, dux, duz, e)
		var dm := c if fc < fe else e
		var pm := minf(fc, fe)
		if pm <= pk:
			# the least that holds, between lb (over) and dm
			var lo := lb
			var hi := dm
			for _i in 20:
				var m := 0.5 * (lo + hi)
				if _peak(dxx, dxz, dux, duz, m) > pk:
					lo = m
				else:
					hi = m
			d = hi
		elif pm <= pk * (1.0 + BURN_TOL):
			d = dm
		else:
			var lo2 := 1.5 * lb
			var hi2 := 1.5 * lo2
			while _peak(dxx, dxz, dux, duz, hi2) > pk:
				lo2 = hi2
				hi2 *= 1.5
				if hi2 > 64.0:
					return PackedFloat64Array()
			for _i in 22:
				var m2 := 0.5 * (lo2 + hi2)
				if _peak(dxx, dxz, dux, duz, m2) > pk:
					lo2 = m2
				else:
					hi2 = m2
			d = hi2
	return PackedFloat64Array([d, _cubic_work(dxx, dxz, dux, duz, d)])


static func _peak(dxx: float, dxz: float, dux: float, duz: float, d: float) -> float:
	var ax := 6.0 * dxx - 2.0 * dux * d
	var az := 6.0 * dxz - 2.0 * duz * d
	var bx := 4.0 * dux * d - 6.0 * dxx
	var bz := 4.0 * duz * d - 6.0 * dxz
	return maxf(sqrt(ax * ax + az * az), sqrt(bx * bx + bz * bz)) / (d * d)


## THE CUBIC BURN'S ENGINE WORK, exactly: its pull p + q u (u 0 to 1) is linear,
## and the integral of its size sqrt(A u^2 + 2 B u + C) is closed (Simpson on
## four steps read 1.167 |du| for a burn whose pull passes through nothing,
## against 1.25).
static func _cubic_work(dxx: float, dxz: float, dux: float, duz: float, d: float) -> float:
	var px := (6.0 * dxx - 2.0 * dux * d) / (d * d)
	var pz := (6.0 * dxz - 2.0 * duz * d) / (d * d)
	var qx := (4.0 * dux * d - 6.0 * dxx) / (d * d) - px
	var qz := (4.0 * duz * d - 6.0 * dxz) / (d * d) - pz
	var A := qx * qx + qz * qz
	var C := px * px + pz * pz
	if A < 1e-18:
		return sqrt(C) * d
	var B := px * qx + pz * qz
	var w0 := B / A
	var w1 := 1.0 + w0
	var k2 := maxf(C / A - w0 * w0, 0.0)
	return d * sqrt(A) * (_half_hyp(w1, k2) - _half_hyp(w0, k2))


## The integral of sqrt(w^2 + k2) from 0 to w.
static func _half_hyp(w: float, k2: float) -> float:
	var s := sqrt(w * w + k2)
	if k2 < 1e-24:
		return 0.5 * w * absf(w)
	var k := sqrt(k2)
	var x := absf(w) / k
	var ash := log(x + sqrt(x * x + 1.0))
	return 0.5 * (w * s + k2 * (ash if w >= 0.0 else -ash))


## The arrival ending at te from the coast's state (x, z, vx, vz) there, sense
## s: [work, phi, d, dxx, dxz, dux, duz, constant (1 or 0)], or empty. Onto a
## ring the constant burn ending there (`_const_burn`) where its pull is
## within BURN_TOL of pk; the cubic otherwise, and alongside.
func _arrival(te: float, x: float, z: float, vx: float, vz: float, s: float, pk: float = THRUST) -> PackedFloat64Array:
	_tgt_at(te)
	var rx := x - _cx
	var rz := z - _cz
	var ux := vx - _cvx
	var uz := vz - _cvz
	var phi := 0.0
	var dxx := 0.0
	var dxz := 0.0
	var dux := 0.0
	var duz := 0.0
	if _tk == 1:
		dxx = _toffx - rx
		dxz = _toffz - rz
		dux = -ux
		duz = -uz
	else:
		_virt(rx, rz, ux, uz, s, 3, pk)
		if _const_burn(rx, rz, ux, uz, s, _vd) and _ka <= pk * (1.0 + BURN_TOL):
			phi = _kphi
			dxx = _tR * cos(phi) - rx
			dxz = _tR * sin(phi) - rz
			dux = -sin(phi) * s * _tV - ux
			duz = cos(phi) * s * _tV - uz
			return PackedFloat64Array([_ka * _kd, phi, _kd, dxx, dxz, dux, duz, 1.0])
		phi = _vphi
		dxx = _tR * cos(phi) - rx
		dxz = _tR * sin(phi) - rz
		dux = -sin(phi) * s * _tV - ux
		duz = cos(phi) * s * _tV - uz
	var cb := _cubic_burn(dxx, dxz, dux, duz, pk)
	if cb.is_empty():
		return PackedFloat64Array()
	return PackedFloat64Array([cb[1], phi, cb[0], dxx, dxz, dux, duz, 0.0])


## WHERE AN ARRIVAL ALONGSIDE (or a graze of a ring) IS BEST, between the nodes
## round node kk: the time its virtual point passes closest to the spot (the
## ring's virtual circle), golden section on the coast. Found only at a node, it
## was up to half a step (some 25 px of the coast) off, and the burn made up
## the rest.
func _te_near(kk: int, s: float) -> float:
	var a := _cT[maxi(kk - 1, 0)]
	var b := _cT[mini(kk + 1, _cn - 1)]
	a = maxf(a, _tc0)
	b = minf(b, t_now + _tcap)
	if b <= a:
		return _cT[kk]
	var gr := 0.6180339887498949
	var c := b - gr * (b - a)
	var e := a + gr * (b - a)
	var fc := _miss_at(c, s)
	var fe := _miss_at(e, s)
	for _i in 14:
		if fc < fe:
			b = e
			e = c
			fe = fc
			c = b - gr * (b - a)
			fc = _miss_at(c, s)
		else:
			a = c
			c = e
			fc = fe
			e = a + gr * (b - a)
			fe = _miss_at(e, s)
	return c if fc < fe else e


## How far the virtual point is from the spot alongside (or outside the ring's
## virtual circle) at tq.
func _miss_at(tq: float, s: float) -> float:
	var c := _coast_at(tq)
	_tgt_at(tq)
	var rx := c[0] - _cx
	var rz := c[1] - _cz
	var ux := c[2] - _cvx
	var uz := c[3] - _cvz
	if _tk == 1:
		var dk := sqrt(ux * ux + uz * uz) / THRUST
		var qx := rx - ux * dk * 0.5 - _toffx
		var qz := rz - uz * dk * 0.5 - _toffz
		return sqrt(qx * qx + qz * qz)
	_virt(rx, rz, ux, uz, s, 3)
	return absf(_vg)


## The least keep-out margin along an arrival burn's path (the coast plus the
## cubic, at n points); and into _bthr the most the engine pulls there: the
## cubic's own (2A + 6B tau) / d^2 and the change of gravity's pull between the
## coast and the burn's path (close to a star or a heavy giant it is not small).
var _bthr := 0.0
func _burn_clear(te: float, d: float, dxx: float, dxz: float, dux: float, duz: float, n: int = 16) -> float:
	var Ax := 3.0 * dxx - dux * d
	var Az := 3.0 * dxz - duz * d
	var Bx := dux * d - 2.0 * dxx
	var Bz := duz * d - 2.0 * dxz
	var least := INF
	var tb := te - d
	_bthr = 0.0
	_coast_at(tb)
	var k := _qk
	for j in range(0, n + 1):
		var tau := float(j) / float(n)
		var tq := tb + tau * d
		# (the coast walked forward, not searched for, point by point)
		while k + 2 < _cn and _cT[k + 1] <= tq:
			k += 1
		var h := _cT[k + 1] - _cT[k]
		var u := (tq - _cT[k]) / h if h > 0.0 else 0.0
		var cx := _herm(_cX[k], _cVX[k], _cX[k + 1], _cVX[k + 1], h, u)
		var cz := _herm(_cZ[k], _cVZ[k], _cZ[k + 1], _cVZ[k + 1], h, u)
		var yx := cx + Ax * tau * tau + Bx * tau * tau * tau
		var yz := cz + Az * tau * tau + Bz * tau * tau * tau
		if j > 0:
			least = minf(least, _margin(yx, yz, tq))
		var px := (2.0 * Ax + 6.0 * Bx * tau) / (d * d)
		var pz := (2.0 * Az + 6.0 * Bz * tau) / (d * d)
		# gravity's change between the coast and the burn's path, only where it
		# could matter: its gradient times how far the burn has moved it
		var off2 := (yx - cx) * (yx - cx) + (yz - cz) * (yz - cz)
		if off2 * _grad2(yx, yz, tq) > 1.0:
			_acc_at(cx, cz, tq)
			var gcx := _ax
			var gcz := _az
			_acc_at(yx, yz, tq)
			px += gcx - _ax
			pz += gcz - _az
		_bthr = maxf(_bthr, sqrt(px * px + pz * pz))
	return least


## `MapGravity.margin`, a world's place worked out only when it is near
## enough for its orbit to matter. The suns, and every circle carried round
## with one (`gi_hs`, `wo_hs`), where they are at t (`_sun_cs`).
func _margin(x: float, z: float, t: float) -> float:
	var least := INF
	_sun_cs(t)
	for k in G.star_x0.size():
		var qx := G.star_x0[k]
		var qz := G.star_z0[k]
		if G.star_rad[k] != 0.0:
			qx = G.star_cx[k] + G.star_rad[k] * _pc
			qz = G.star_cz[k] + G.star_rad[k] * _ps
		least = minf(least, sqrt((x - qx) * (x - qx) + (z - qz) * (z - qz)) - G.star_keep[k])
	for k in G.gi_hx.size():
		var a := G.gi_ph[k] + G.gi_n[k] * t
		var hx := G.gi_hx[k]
		var hz := G.gi_hz[k]
		var hs := G.gi_hs[k]
		if hs >= 0:
			hx = G.star_cx[hs] + G.star_rad[hs] * _pc
			hz = G.star_cz[hs] + G.star_rad[hs] * _ps
		var gx := hx + G.gi_orb[k] * cos(a) - x
		var gz := hz + G.gi_orb[k] * sin(a) - z
		least = minf(least, sqrt(gx * gx + gz * gz) - _gkeep[k])
	for k in G.wo_hx.size():
		var wcx := G.wo_hx[k]
		var wcz := G.wo_hz[k]
		var ws := G.wo_hs[k]
		if ws >= 0:
			wcx = G.star_cx[ws] + G.star_rad[ws] * _pc
			wcz = G.star_cz[ws] + G.star_rad[ws] * _ps
		var rh := sqrt((x - wcx) * (x - wcx) + (z - wcz) * (z - wcz))
		if absf(rh - G.wo_orb[k]) - _wkeep[k] >= least:
			continue
		var aw := G.wo_ph[k] + G.wo_n[k] * t
		var wx := wcx + G.wo_orb[k] * cos(aw) - x
		var wz := wcz + G.wo_orb[k] * sin(aw) - z
		least = minf(least, sqrt(wx * wx + wz * wz) - _wkeep[k])
	return least


## THE PAIR'S ANGLE AT t as its cos and sin, into _pc, _ps (0 and 0 where it
## holds still, so a still star's circle reads its own place): both suns share
## one angle (MapGravity `star_ph`), so one pair serves every star and every
## circle carried with one, at the same numbers `MapGravity.sx` gives.
var _pc := 0.0
var _ps := 0.0
func _sun_cs(t: float) -> void:
	if G.pair_n == 0.0 or G.star_ph.is_empty():
		_pc = 0.0
		_ps = 0.0
		return
	var pa := G.star_ph[0] + G.pair_n * t
	_pc = cos(pa)
	_ps = sin(pa)


## The pull at (x, z) at t into _ax, _az (`MapGravity.acc` without its array).
var _ax := 0.0
var _az := 0.0
func _acc_at(x: float, z: float, t: float) -> void:
	_ax = 0.0
	_az = 0.0
	_sun_cs(t)
	for k in G.star_x0.size():
		var qx := G.star_x0[k]
		var qz := G.star_z0[k]
		if G.star_rad[k] != 0.0:
			qx = G.star_cx[k] + G.star_rad[k] * _pc
			qz = G.star_cz[k] + G.star_rad[k] * _ps
		var dx := qx - x
		var dz := qz - z
		var r2 := dx * dx + dz * dz
		var f := G.star_gm[k] / (r2 * sqrt(r2))
		_ax += f * dx
		_az += f * dz
	for k in G.gi_hx.size():
		var a := G.gi_ph[k] + G.gi_n[k] * t
		var hx := G.gi_hx[k]
		var hz := G.gi_hz[k]
		var hs := G.gi_hs[k]
		if hs >= 0:
			hx = G.star_cx[hs] + G.star_rad[hs] * _pc
			hz = G.star_cz[hs] + G.star_rad[hs] * _ps
		var dx := hx + G.gi_orb[k] * cos(a) - x
		var dz := hz + G.gi_orb[k] * sin(a) - z
		var r2 := dx * dx + dz * dz
		var f := G.gi_gm[k] / (r2 * sqrt(r2))
		_ax += f * dx
		_az += f * dz


## The square of how fast the pull changes with place there (2 GM / r^3 of
## the nearest-felt body, summed loosely): an upper bound for a few px. The
## suns and giants where they are at t, as `_acc_at`.
func _grad2(x: float, z: float, t: float) -> float:
	var g := 0.0
	_sun_cs(t)
	for k in G.star_x0.size():
		var qx := G.star_x0[k]
		var qz := G.star_z0[k]
		if G.star_rad[k] != 0.0:
			qx = G.star_cx[k] + G.star_rad[k] * _pc
			qz = G.star_cz[k] + G.star_rad[k] * _ps
		var r2 := (qx - x) * (qx - x) + (qz - z) * (qz - z)
		g += 2.0 * G.star_gm[k] / (r2 * sqrt(r2))
	for k in G.gi_hx.size():
		var a := G.gi_ph[k] + G.gi_n[k] * t
		var hx := G.gi_hx[k]
		var hz := G.gi_hz[k]
		var hs := G.gi_hs[k]
		if hs >= 0:
			hx = G.star_cx[hs] + G.star_rad[hs] * _pc
			hz = G.star_cz[hs] + G.star_rad[hs] * _ps
		var dx := hx + G.gi_orb[k] * cos(a) - x
		var dz := hz + G.gi_orb[k] * sin(a) - z
		var r2 := dx * dx + dz * dz
		g += 2.0 * G.gi_gm[k] / (r2 * sqrt(r2))
	return g * g


## THE CHEAPEST CLEAN ARRIVAL ON THE COAST into _e_*: where the coast's virtual
## point crosses the ring's virtual circle, or passes closest to it within
## GRAZE (for a station, belt, hulk or contact: comes closest to its spot);
## each priced by its burn, the coast clean up to the burn and the burn's own
## path clean. _e_J stays INF when there is none.
func _price() -> void:
	if _cn < 2:
		return
	var t_lim := minf(_cT[_cn - 1], t_now + _tcap)
	var ns := _senses.size()
	var keepd := _tk == 1
	# per sense: the last two g and the last node
	var g1 := PackedFloat64Array()
	var g2 := PackedFloat64Array()
	var k1 := PackedInt32Array()
	# (and whether the last g is only its lower bound)
	var ap := PackedByteArray()
	g1.resize(ns)
	g2.resize(ns)
	k1.resize(ns)
	ap.resize(ns)
	for j in ns:
		k1[j] = -1
	var cands := PackedFloat64Array()
	for k in _cn:
		var tk := _cT[k]
		if tk > t_lim:
			break
		if tk < _tc0:
			continue
		_tgt_at(tk)
		var rx := _cX[k] - _cx
		var rz := _cZ[k] - _cz
		var r := sqrt(rx * rx + rz * rz)
		if r > _tR + NEAR + sqrt(_toffx * _toffx + _toffz * _toffz):
			for j in ns:
				k1[j] = -1
			continue
		var ux := _cVX[k] - _cvx
		var uz := _cVZ[k] - _cvz
		# A LOWER BOUND ON THE MISS, cheap: the burn is at most (|u| + V) / THRUST
		# long, so the virtual point is at most |u| d/2 off the coast and the
		# virtual circle at most rho_max across. Far above GRAZE, no sense can
		# cross or graze here, and the solve is skipped (most nodes of a twin's
		# compact flights are within NEAR of everything)
		var mu := sqrt(ux * ux + uz * uz)
		var lb := 0.0
		if keepd:
			lb = sqrt((rx - _toffx) * (rx - _toffx) + (rz - _toffz) * (rz - _toffz)) - mu * mu / (2.0 * THRUST)
		else:
			var dmax := (mu + _tV) / THRUST
			lb = r - mu * dmax * 0.5 - sqrt(_tR * _tR + 0.25 * _tV * _tV * dmax * dmax)
		if lb > GRAZE + 1.0:
			for j in ns:
				if k1[j] >= 0:
					g2[j] = g1[j]
				else:
					g2[j] = INF
				g1[j] = lb
				k1[j] = k
				ap[j] = 1
			continue
		for j in ns:
			var s := _senses[j]
			var g := 0.0
			if keepd:
				var dk := sqrt(ux * ux + uz * uz) / THRUST
				var qx := rx - ux * dk * 0.5 - _toffx
				var qz := rz - uz * dk * 0.5 - _toffz
				g = sqrt(qx * qx + qz * qz)
			else:
				# (two rounds find where it crosses; the arrival takes three)
				_virt(rx, rz, ux, uz, s, 2)
				g = _vg
			if k1[j] >= 0:
				var gk1 := g1[j]
				if ap[j] == 1 and not keepd and g <= 0.0:
					# crossing from a bounded node: its own miss, for the place
					var kp := k1[j]
					_tgt_at(_cT[kp])
					_virt(_cX[kp] - _cx, _cZ[kp] - _cz, _cVX[kp] - _cvx, _cVZ[kp] - _cvz, s, 2)
					gk1 = _vg
				if not keepd and (gk1 > 0.0) != (g > 0.0):
					cands.append(float(k1[j]))
					cands.append(gk1 / (gk1 - g))
					cands.append(s)
					cands.append(1.0)
				elif g2[j] < INF and gk1 < g2[j] and gk1 <= g and (keepd or gk1 > 0.0) and gk1 < GRAZE:
					cands.append(float(k1[j]))
					cands.append(0.0)
					cands.append(s)
					cands.append(0.0)
				g2[j] = gk1
			else:
				g2[j] = INF
			g1[j] = g
			k1[j] = k
			ap[j] = 0
	# EACH CANDIDATE'S ARRIVAL TIME made exact (a crossing: where its constant
	# burn pulls THRUST; alongside or a graze: where it passes closest), priced
	# (cheap), then its path checked cheapest first, so the first clean is the one
	var priced: Array = []
	for c in range(0, cands.size(), 4):
		var kk := int(cands[c])
		if kk + 1 >= _cn:
			continue
		var s := cands[c + 2]
		if cands[c + 3] > 0.5:
			# a crossing, roughly: the constant burn's size where the virtual point
			# says (made exact only when it is checked: it moves little)
			var te0 := _cT[kk] + cands[c + 1] * (_cT[kk + 1] - _cT[kk])
			if te0 > t_now + _tcap:
				continue
			var st0 := _coast_k(kk, te0)
			_tgt_at(te0)
			var ux0 := st0[2] - _cvx
			var uz0 := st0[3] - _cvz
			_virt(st0[0] - _cx, st0[1] - _cz, ux0, uz0, s, 3)
			if te0 - _vd < _tc0 + TB_PAD:
				continue
			var dux0 := -sin(_vphi) * s * _tV - ux0
			var duz0 := cos(_vphi) * s * _tV - uz0
			priced.append([sqrt(dux0 * dux0 + duz0 * duz0) + _tw * (te0 - t_now), c, te0])
			continue
		var te := _te_near(kk, s)
		if te > t_now + _tcap or te < _tc0:
			continue
		var st := _coast_at(te)
		var ar := _arrival(te, st[0], st[1], st[2], st[3], s)
		if ar.is_empty() or te - ar[2] < _tc0 + TB_PAD:
			continue
		priced.append([ar[0] + _tw * (te - t_now), c, te])
	priced.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var best := INF
	for pc in priced:
		if float(pc[0]) >= best:
			break
		var c: int = pc[1]
		var s2 := cands[c + 2]
		var crossing := cands[c + 3] > 0.5
		var te: float = pc[2]
		if crossing:
			te = _te_for(te, s2, THRUST, -1.0)
			if te > t_now + _tcap:
				continue
		# WHERE GRAVITY'S PULL CHANGES ACROSS THE BURN (close to a star or a heavy
		# giant) the engine pulls more than the burn's own: a gentler burn then,
		# its own pull cut by what it overshot (onto a ring, ending where that
		# pull is exact), up to three times
		var pk := THRUST
		var ok := false
		var ar := PackedFloat64Array()
		var cost := INF
		for _try in 4:
			var st := _coast_at(te)
			ar = _arrival(te, st[0], st[1], st[2], st[3], s2, pk)
			if ar.is_empty():
				break
			var tb := te - ar[2]
			if tb < _tc0 + TB_PAD or tb > _tight_t:
				break
			cost = ar[0] + _tw * (te - t_now)
			if cost >= best:
				break
			# the coast clean up to the burn, and the burn's own path
			_coast_at(tb)
			if _cCL[mini(_qk + 1, _cn - 1)] < 0.0:
				break
			if _burn_clear(te, ar[2], ar[3], ar[4], ar[5], ar[6], clampi(ceili(ar[2] / 0.05), 16, 64)) < BURN_PAD:
				break
			if _bthr <= THRUST * THRUST_SLACK:
				ok = not _arrival_cusps(te, ar)
				break
			pk *= THRUST / _bthr
			if crossing:
				te = _te_for(te, s2, pk, ar[2])
				if te > t_now + _tcap:
					break
		if not ok:
			continue
		best = cost
		_e_te = te
		_e_s = s2
		_e_phi = ar[1]
		_e_d2 = ar[2]
		_e_w2 = ar[0]
		_e_pk = pk
	if best < INF:
		_e_J = sqrt(_e_dvx * _e_dvx + _e_dvz * _e_dvz) + _e_ph + best


# ---------------------------------------------------------------- refining
## THE TANGENT POINT the coast should meet at te: the ring point (relative to
## the target) whose ring motion for sense s runs along the coast's own (u),
## and the constant burn onto it. Its miss, q - aim: [fx, fz], or empty.
func _qres(te: float, s: float) -> PackedFloat64Array:
	if _cn < 2 or te > _cT[_cn - 1] or te < _tc0:
		return PackedFloat64Array()
	var c := _coast_at(te)
	_tgt_at(te)
	var rx := c[0] - _cx
	var rz := c[1] - _cz
	var ux := c[2] - _cvx
	var uz := c[3] - _cvz
	var m := sqrt(ux * ux + uz * uz)
	if _tk == 1:
		var dk := m / THRUST
		return PackedFloat64Array([rx - ux * dk * 0.5 - _toffx, rz - uz * dk * 0.5 - _toffz])
	if m < 1e-6:
		return PackedFloat64Array()
	var hx := ux / m
	var hz := uz / m
	var phi := atan2(-s * hx, s * hz)
	var d := absf(m - _tV) / THRUST
	return PackedFloat64Array([rx - _tR * cos(phi) - (m - _tV) * hx * d * 0.5, rz - _tR * sin(phi) - (m - _tV) * hz * d * 0.5])


## NEWTON ON THE DEPARTURE so the coast meets the target ring's tangent point at
## te (the conic's arrival time): a finite-difference Jacobian, then Broyden,
## a step that does worse taken a quarter as far.
func _refine_at(ux: float, uz: float, has_fix: bool, a_fix: float, te: float, s: float, iters: int = 4) -> void:
	var fd := 1.0
	_fly(ux, uz, has_fix, a_fix)
	var F := _qres(te, s)
	if F.is_empty():
		return
	_fly(ux + fd, uz, has_fix, a_fix)
	var Fa := _qres(te, s)
	_fly(ux, uz + fd, has_fix, a_fix)
	var Fb := _qres(te, s)
	if Fa.is_empty() or Fb.is_empty():
		return
	var j11 := (Fa[0] - F[0]) / fd
	var j21 := (Fa[1] - F[1]) / fd
	var j12 := (Fb[0] - F[0]) / fd
	var j22 := (Fb[1] - F[1]) / fd
	for _it in iters:
		var det := j11 * j22 - j12 * j21
		if absf(det) < 1e-9:
			return
		var dx := -(j22 * F[0] - j12 * F[1]) / det
		var dz := -(-j21 * F[0] + j11 * F[1]) / det
		var st := sqrt(dx * dx + dz * dz)
		var lim := 0.5 * maxf(10.0, sqrt(ux * ux + uz * uz))
		if st > lim:
			dx *= lim / st
			dz *= lim / st
		_fly(ux + dx, uz + dz, has_fix, a_fix)
		var Fn := _qres(te, s)
		if Fn.is_empty() or Fn[0] * Fn[0] + Fn[1] * Fn[1] > F[0] * F[0] + F[1] * F[1]:
			dx *= 0.25
			dz *= 0.25
			_fly(ux + dx, uz + dz, has_fix, a_fix)
			Fn = _qres(te, s)
		if Fn.is_empty():
			return
		var yx := Fn[0] - F[0]
		var yz := Fn[1] - F[1]
		var jx := j11 * dx + j12 * dz
		var jz := j21 * dx + j22 * dz
		var den := dx * dx + dz * dz
		if den < 1e-18:
			return
		j11 += (yx - jx) * dx / den
		j12 += (yx - jx) * dz / den
		j21 += (yz - jz) * dx / den
		j22 += (yz - jz) * dz / den
		ux += dx
		uz += dz
		F = Fn
		if F[0] * F[0] + F[1] * F[1] < 0.09:
			return


## THE COAST'S PASS OF THE TARGET, its time free: where an arrival burn along
## its own motion would start (r.u_hat = (|u| - V) d/2), and the signed miss
## there, r.left(u_hat) + s R (0: it meets the ring's tangent point). NAN when
## it does not pass.
func _pass_miss(s: float) -> float:
	var keepd := _tk == 1
	var R := 0.0 if keepd else _tR
	var V := 0.0 if keepd else _tV
	var ox := _toffx if keepd else 0.0
	var oz := _toffz if keepd else 0.0
	if _cn < 2:
		return NAN
	var t_lim := minf(_cT[_cn - 1], t_now + _tcap)
	var hp := NAN
	for k in _cn:
		var tk := _cT[k]
		if tk > t_lim:
			break
		if tk < _tc0:
			continue
		_tgt_at(tk)
		var rx := _cX[k] - _cx - ox
		var rz := _cZ[k] - _cz - oz
		var ux := _cVX[k] - _cvx
		var uz := _cVZ[k] - _cvz
		var mu := sqrt(ux * ux + uz * uz)
		if mu < 1e-6:
			hp = NAN
			continue
		var d := absf(mu - V) / THRUST
		var hcur := (rx * ux + rz * uz) / mu - (mu - V) * d * 0.5
		if not is_nan(hp) and hp < 0.0 and hcur >= 0.0:
			var u := hp / (hp - hcur)
			var tq := _cT[k - 1] + u * (tk - _cT[k - 1])
			var c := _coast_k(k - 1, tq)
			_tgt_at(tq)
			var qx := c[0] - _cx - ox
			var qz := c[1] - _cz - oz
			var wx := c[2] - _cvx
			var wz := c[3] - _cvz
			var mw := sqrt(wx * wx + wz * wz)
			if mw < 1e-6:
				return NAN
			return (-qx * wz + qz * wx) / mw + s * R
		hp = hcur
	return NAN


## MINIMUM-NORM NEWTON on the signed miss at the pass (one number, its time
## free), from a scanned departure: the step along the miss's gradient that
## clears it, the gradient by finite differences and then Broyden.
func _refine_pass(ux: float, uz: float, has_fix: bool, a_fix: float, s: float, iters: int = 5) -> void:
	var fd := 1.0
	_fly(ux, uz, has_fix, a_fix)
	var m := _pass_miss(s)
	if is_nan(m):
		return
	_fly(ux + fd, uz, has_fix, a_fix)
	var ma := _pass_miss(s)
	_fly(ux, uz + fd, has_fix, a_fix)
	var mb := _pass_miss(s)
	if is_nan(ma) or is_nan(mb):
		return
	var gx := (ma - m) / fd
	var gz := (mb - m) / fd
	for _it in iters:
		var g2 := gx * gx + gz * gz
		if g2 < 1e-12:
			return
		var dx := -m * gx / g2
		var dz := -m * gz / g2
		var st := sqrt(dx * dx + dz * dz)
		var lim := 0.5 * maxf(10.0, sqrt(ux * ux + uz * uz))
		if st > lim:
			dx *= lim / st
			dz *= lim / st
		_fly(ux + dx, uz + dz, has_fix, a_fix)
		var mn := _pass_miss(s)
		if is_nan(mn) or absf(mn) > absf(m):
			dx *= 0.25
			dz *= 0.25
			_fly(ux + dx, uz + dz, has_fix, a_fix)
			mn = _pass_miss(s)
		if is_nan(mn):
			return
		var den := dx * dx + dz * dz
		if den < 1e-18:
			return
		var e := (mn - m) - (gx * dx + gz * dz)
		gx += e * dx / den
		gz += e * dz / den
		ux += dx
		uz += dz
		m = mn
		if absf(m) < 0.3:
			return


## At the coast's closest pass of the target: [distance, the sense it passes in].
func _pass_side() -> PackedFloat64Array:
	var best := INF
	var sb := 1.0
	var ox := _toffx if _tk == 1 else 0.0
	var oz := _toffz if _tk == 1 else 0.0
	for k in _cn:
		if _cT[k] < _tc0:
			continue
		_tgt_at(_cT[k])
		var rx := _cX[k] - _cx - ox
		var rz := _cZ[k] - _cz - oz
		var d := sqrt(rx * rx + rz * rz)
		if d < best:
			best = d
			var lf := -rx * (_cVZ[k] - _cvz) + rz * (_cVX[k] - _cvx)
			sb = -1.0 if lf > 0.0 else 1.0
	return PackedFloat64Array([best, sb])


# ---------------------------------------------------------------- the search
## Every way it tries, cheapest kept in _b, within the budget of integrations.
func _search() -> void:
	var t0 := Time.get_ticks_usec()
	var seeds := _seeds()
	_us_seed += Time.get_ticks_usec() - t0
	var nsd := floori(seeds.size() / 9.0)
	# the cheapest conic, refined; the next two as they are
	if nsd > 0:
		_refine_at(seeds[1], seeds[2], seeds[6] > 0.5, seeds[7], seeds[8], seeds[5])
	if not _twin:
		for i in range(1, mini(3, nsd)):
			_fly(seeds[i * 9 + 1], seeds[i * 9 + 2], seeds[i * 9 + 6] > 0.5, seeds[i * 9 + 7])
		if _b_J < INF:
			return
	# A SCAN OF REAL DEPARTURES (in a twin always: its cheap flights come from the
	# two stars' pull, which no conic sees), the best refined at their pass from
	# the very ring point each left from
	if _scan_passes():
		return
	# last, the rest of the conics as they are
	for i in range(1, nsd):
		if _n_integ >= _budget:
			return
		_fly(seeds[i * 9 + 1], seeds[i * 9 + 2], seeds[i * 9 + 6] > 0.5, seeds[i * 9 + 7])


## The scan's three passes (`_scan`), each one's best refined at its pass: true
## once one finds a flight.
func _scan_passes() -> bool:
	for pass_i in 3:
		var scan := _scan(pass_i)
		var rows: Array = []
		for i in range(0, scan.size(), 4):
			if _n_integ >= _budget:
				break
			var jj := _fly(scan[i], scan[i + 1], scan[i + 2] > 0.5, scan[i + 3])
			if _cn == 0:
				continue
			var side := _pass_side()
			var sc := jj if jj < INF else 1e8 + side[0]
			rows.append([sc, i, _e_s if jj < INF else side[1], _e_a0])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
		var nfix := 2 if pass_i == 0 else 3
		for r in rows.slice(0, nfix):
			if _n_integ >= _budget:
				break
			var i2: int = r[1]
			_refine_pass(scan[i2], scan[i2 + 1], _dk == 0, float(r[3]), float(r[2]) if _tk == 0 else 1.0)
		if _b_J < INF:
			return true
	return false


## A FRESH SEARCH into _b: to T_CAP at TIME_W, and where that finds nothing,
## the fallback (`_fallback`). A leg of a flight in two (`_chain`) is searched
## by the as-built search alone (T_CAP_BACK at TIME_W_BACK), so those flights
## keep the as-built length.
func _fresh() -> void:
	_own = false
	_back = false
	if _leg > 0:
		_tcap = T_CAP_BACK
		_tw = TIME_W_BACK
		_back = true
		_search()
		_back = false
		return
	if _curved:
		# CURVED: the as-built search first (its own budget, `_search_back`)
		_search_back()
		if _b_J < INF:
			_own = true
			return
		_fallback()
		return
	_tcap = T_CAP
	_tw = TIME_W
	_search()
	if _b_J < INF:
		_own = true
		return
	_fallback()


## NOTHING FOUND TO T_CAP: THE SOONER OF TWO. The as-built search to T_CAP_BACK
## (`_search_back`) and the wider search to T_CAP_WIDE at TIME_W both look, a
## budget each, and the flight that arrives first is kept. Where both find
## nothing, the wider search again at TIME_W_BACK, with FAR_T_BACK (its scan
## reads it). (The study, Nov 1: the wider search first let flights of up to
## 40 s stand where the as-built one found one under 30; the as-built one first
## held flights from the edge and settled star orbits to about 29 s, where the
## wider one found quicker ones in one game start in five to eight.)
func _fallback() -> void:
	if _curved:
		# (CURVED's own look was the as-built search: the wider one behind it,
		# at its weight, as the as-built fallback had it)
		if not _wide_ok:
			return
		_back = true
		_search_wide(TIME_W_BACK)
		_back = false
		return
	_search_back()
	if not _wide_ok:
		return
	var kj := _b_J
	var kb := _b.duplicate()
	var kcap := _tcap
	var ktw := _tw
	_b_J = INF
	_b = {}
	_search_wide(TIME_W)
	if kj < INF and (_b_J == INF or float(kb.te) <= float(_b.te) + 1e-6):
		_b_J = kj
		_b = kb
		_tcap = kcap
		_tw = ktw
	if _b_J == INF:
		_back = true
		_search_wide(TIME_W_BACK)
		_back = false


## THE AS-BUILT SEARCH (ruling 20's), to T_CAP_BACK at TIME_W_BACK with its own
## conic guesses and FAR_T_BACK, a budget of its own.
func _search_back() -> void:
	_tcap = T_CAP_BACK
	_tw = TIME_W_BACK
	_budget = _n_integ + BUDGET
	_back = true
	_search()
	_back = false
	if _b_J == INF:
		_tcap = T_CAP
		_tw = TIME_W


## A FRESH SEARCH'S FLIGHT AS SAMPLES (`_build`). Where the search to T_CAP
## found it and its samples cut a keep-out (the search priced it clear; the
## samples are checked again once built), the fallback looks as it would had
## nothing been found, and its flight is kept if it is clean.
## Without it, a harness's free start at seed 4242 system 291 (FlightTest, to
## place 1, one sun) kept an 11.8 s flight 0.72 px into a keep-out, found and
## not clean, and the fallback never ran; with it, the wider search's clean
## flight of 18.4 s (Nov 1).
func _build_fresh() -> Result:
	var res := _build(&"solved")
	if not res.found or res.clean or not _own:
		return res
	_b_J = INF
	_b = {}
	_fallback()
	if _b_J == INF:
		return res
	var res2 := _build(&"solved")
	return res2 if res2.clean else res


## THE WIDER LOOK (T_CAP_WIDE), priced at tw. The scan again, its departures
## at least as fast as crossing to the target in WIDE_T (`_wide_need`), its
## arrival up to T_CAP_WIDE on, within BUDGET_WIDE more integrations.
func _search_wide(tw: float) -> void:
	_tcap = T_CAP_WIDE
	_tw = tw
	_budget = _n_integ + BUDGET_WIDE
	_wide = true
	# the cheapest conics to T_CAP_WIDE, refined
	var seeds := _seeds()
	for i in mini(2, floori(seeds.size() / 9.0)):
		if _n_integ >= _budget:
			break
		_refine_at(seeds[i * 9 + 1], seeds[i * 9 + 2], seeds[i * 9 + 6] > 0.5, seeds[i * 9 + 7], seeds[i * 9 + 8], seeds[i * 9 + 5])
	if _b_J == INF:
		_scan_passes()
	_wide = false


## DEPARTURES TO FLY AS THEY ARE, pass 0, 1 or 2: SCAN_HEAD headings, the
## first toward where the target is, each at SCAN_SPEED times the departure's
## own speed scale (its ring's, or its place's motion plus SCAN_KICK px/s).
## Round a ring each leaves from the point whose motion runs along it (or the
## end of the ride's reach nearer it), so a heading the ride cannot bring
## round leaves across the ring's motion. The first build left only along the
## ring's motion from points across the ride's reach, which a ride held to
## THRUST no longer makes a full lap, and its departures out of a twin star's
## well were too slow for places round both (the planner review, Oct 30).
## Flat: [ux, uz, has_fix, a_fix] each.
func _scan(pass_i: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var off: float = [0.0, 0.5, 0.25][pass_i]
	var th0 := _toward()
	var nh := SCAN_HEAD
	var need := _far_need()
	if _wide:
		need = maxf(need, _wide_need())
		nh = WIDE_HEAD
	if _dk == 0:
		# (walking round the way the ride goes: the first headings are the
		# ride's own reach, leaving along the ring's motion)
		var dr := 1.0 if _dw >= 0.0 else -1.0
		var vr := absf(_dw) * _drt
		var speeds := PackedFloat64Array()
		for m: float in (SCAN_SPEED[pass_i] if need <= 0.0 else FAR_SPEED[pass_i]):
			speeds.append(vr * m if need <= 0.0 else maxf(0.66 * vr, need * m))
		# THE WIDER SCAN OUT OF A SETTLED STAR ORBIT looks toward the target: its
		# ride all but stands still (a twin's far out goes round at 11 to 16
		# px/s), so the ring's own way is no guide, and headings a full turn apart
		# by 45 deg passed a target 2,000 px off by hundreds of px
		var toward := _wide and _dplace == -9
		if toward:
			th0 = _bearing()
		for j in nh:
			var hd := th0 + dr * TAU * (float(j) + off) / float(nh)
			if toward:
				hd = th0 + WIDE_SPAN * (2.0 * (float(j) + off) / float(nh) - 1.0)
			for sp in speeds:
				out.append_array(PackedFloat64Array([sp * cos(hd), sp * sin(hd), 0.0, 0.0]))
	else:
		var vx := _dvx if _dk == 2 else 0.0
		var vz := _dvz if _dk == 2 else 0.0
		if pass_i == 0:
			out.append_array(PackedFloat64Array([vx, vz, 0.0, 0.0]))
		for kk: float in (SCAN_KICK[pass_i] if need <= 0.0 else FAR_SPEED[pass_i]):
			var sp := kk if need <= 0.0 else need * kk
			for j in nh:
				var hd := th0 + TAU * (float(j) + off) / float(nh)
				out.append_array(PackedFloat64Array([vx + sp * cos(hd), vz + sp * sin(hd), 0.0, 0.0]))
	return out


## From where the ship is now to where the target is half WIDE_T on (rad).
func _bearing() -> float:
	_dep_at(t_now)
	var px := _cx + _drt * cos(_dang)
	var pz := _cz + _drt * sin(_dang)
	_tgt_at(t_now + WIDE_T * 0.5)
	return atan2(_cz + _toffz - pz, _cx + _toffx - px)


## The scan's first heading: round a ring, its own motion where the ship is
## now (leaving at once); else from the departure's place to where the target
## is in a typical flight's time.
func _toward() -> float:
	if _dk == 0:
		var dr := 1.0 if _dw >= 0.0 else -1.0
		return _dang + dr * PI * 0.5
	var px := _dpx
	var pz := _dpz
	if _dk != 2:
		_dep_at(t_now)
		px = _cx
		pz = _cz
	_tgt_at(t_now + 12.0)
	return atan2(_cz - pz, _cx - px)


## THE SPEED A FLIGHT OUT OF A TWIN STAR'S WELL TO A PLACE ROUND BOTH TAKES
## (px/s, relative to the place it leaves), or 0 for any other flight: what
## climbing out to it in about FAR_T takes, vis-viva about the star with the
## pair's whole pull (roughly what the ship feels on the way), less the
## place's own motion round the star. Such flights were 84% of the first
## build's misses in real twins, from a world's ring or a star's close orbit
## to the stations, belts, hulks and worlds round both; a brute scan flew them
## at 60 to 110 px/s off the ring (the planner review, Oct 30). So their scan
## speeds bracket this (FAR_SPEED), not the ring's own. The as-built search
## climbs out in FAR_T_BACK.
func _far_need() -> float:
	if not _twin or _dk == 2:
		return 0.0
	_dep_at(t_now)
	var px := _cx + (_drt * cos(_dang) if _dk == 0 else _doffx)
	var pz := _cz + (_drt * sin(_dang) if _dk == 0 else _doffz)
	var k := G.star_index(_star_of(px, pz, t_now))
	if k < 0:
		return 0.0
	# (the place's own motion round that star, and the star where it is now and
	# far_t on: in a turning pair it moves with its worlds)
	var ovx := _cvx
	var ovz := _cvz
	var k1x := G.star_x0[k]
	var k1z := G.star_z0[k]
	var far_t := FAR_T_BACK if _back else FAR_T
	var k2x := k1x
	var k2z := k1z
	if G.star_rad[k] != 0.0:
		ovx -= G.svx(k, t_now)
		ovz -= G.svz(k, t_now)
		k1x = G.sx(k, t_now)
		k1z = G.sz(k, t_now)
		k2x = G.sx(k, t_now + far_t)
		k2z = G.sz(k, t_now + far_t)
	var own := sqrt(ovx * ovx + ovz * ovz)
	var r1 := sqrt((px - k1x) * (px - k1x) + (pz - k1z) * (pz - k1z))
	_tgt_at(t_now + far_t)
	# (only to a place round both: one round a star is in that star's own well)
	if _star_of(_cx, _cz, t_now + far_t) != -2:
		return 0.0
	var r2 := sqrt((_cx - k2x) * (_cx - k2x) + (_cz - k2z) * (_cz - k2z))
	if r2 < 2.0 * r1 + 60.0:
		return 0.0
	var v2 := 2.0 * SystemLayout.GM_SHIP * (1.0 / r1 - 1.0 / r2) + pow((r2 - r1) / far_t, 2.0)
	return maxf(sqrt(maxf(v2, 0.0)) - own, 20.0)


## THE WIDER SCAN'S LEAST SPEED (px/s, relative to the place it leaves): from
## where the ship is now to where the target is WIDE_T on, in WIDE_T, and never
## under twice its ring's own pace (`_search_wide`).
func _wide_need() -> float:
	var px := _dpx
	var pz := _dpz
	var own := 0.0
	if _dk != 2:
		_dep_at(t_now)
		px = _cx + (_drt * cos(_dang) if _dk == 0 else _doffx)
		pz = _cz + (_drt * sin(_dang) if _dk == 0 else _doffz)
		if _dk == 0:
			own = absf(_dw) * _drt
	_tgt_at(t_now + WIDE_T)
	var d := sqrt((_cx - px) * (_cx - px) + (_cz - pz) * (_cz - pz))
	return maxf(maxf(d / WIDE_T, 2.0 * own), 20.0)


## The star a point is round at t: in a twin, the one whose pull there is the
## greater, if it is the greater by FAR_SHARE; else none (-2). The suns where
## they are at t (in a turning pair the answer moves with them).
func _star_of(x: float, z: float, t: float) -> int:
	if G.star_x0.size() < 2:
		return G.star_id[0] if G.star_x0.size() > 0 else -2
	var x0 := G.sx(0, t)
	var z0 := G.sz(0, t)
	var x1 := G.sx(1, t)
	var z1 := G.sz(1, t)
	var f0 := G.star_gm[0] / ((x - x0) * (x - x0) + (z - z0) * (z - z0))
	var f1 := G.star_gm[1] / ((x - x1) * (x - x1) + (z - z1) * (z - z1))
	if f0 > FAR_SHARE * f1:
		return G.star_id[0]
	if f1 > FAR_SHARE * f0:
		return G.star_id[1]
	return -2


# ---------------------------------------------------------------- conic guesses
## CONIC GUESSES, cheapest first, priced from where the ship can really leave.
## Stage 1 from the place's centre now (a world's ring is small beside the
## flight; round a star, from two points on its ring), every length in CONIC_TS
## and both ways round; stage 2 the CONIC_KEEP cheapest again from the very
## point and moment it would leave, aimed at the target ring's tangent point.
## Flat: [price, ux, uz, T, way, s, has_fix, a_fix, te] each.
## A CONIC ABOUT A SUN OF A TURNING PAIR is solved in that sun's own frame
## (`_lam`): its centre is the sun's index (a centre's fourth number; -1 a
## centre that holds still), and whether the target is the sun it is about is
## asked by that index, not by place, since the sun at the arrival is not
## where it was when the conic was laid (`_aims`).
func _seeds() -> PackedFloat64Array:
	var centres := PackedFloat64Array()
	if _twin:
		# the pair's balance point with their whole pull, and each star the
		# flight leaves from or goes to with its own (a flight out of one star's
		# well is that star's conic first), where it is now
		centres.append_array(PackedFloat64Array([G.bary.x, G.bary.y, SystemLayout.GM_SHIP, -1.0]))
		var own := PackedInt32Array()
		var px := _dpx
		var pz := _dpz
		if _dk != 2:
			_dep_at(t_now)
			px = _cx
			pz = _cz
		own.append(G.star_index(_star_of(px, pz, t_now)))
		_tgt_at(t_now)
		own.append(G.star_index(_star_of(_cx, _cz, t_now)))
		var had := -1
		for k in own:
			if k >= 0 and k != had:
				had = k if had < 0 else had
				var turns := G.star_rad[k] != 0.0
				centres.append_array(PackedFloat64Array([G.sx(k, t_now), G.sz(k, t_now), G.star_gm[k], float(k) if turns else -1.0]))
	else:
		for k in G.star_x0.size():
			centres.append_array(PackedFloat64Array([G.star_x0[k], G.star_z0[k], G.star_gm[k], -1.0]))
	var p1s := PackedFloat64Array()
	if _dk == 2:
		p1s.append_array(PackedFloat64Array([_dpx, _dpz, 0.0, 0.0]))
	elif _dk == 0 and _dorb == 0.0:
		# a star's close orbit (or a circle round a fixed point): from the ring;
		# round a turning sun, round where it is now, at its motion
		var dr := 1.0 if _dw >= 0.0 else -1.0
		var hx := _dhx
		var hz := _dhz
		var hvx := 0.0
		var hvz := 0.0
		if _dhs >= 0:
			_dep_at(t_now)
			hx = _cx
			hz = _cz
			hvx = _cvx
			hvz = _cvz
		for j in 2:
			var a := _dang + dr * _reach() * (float(j) + 0.5) / 2.0
			p1s.append_array(PackedFloat64Array([hx + _drt * cos(a), hz + _drt * sin(a), hvx, hvz]))
	else:
		_dep_at(t_now)
		var ox := _doffx if _dk == 1 else 0.0
		var oz := _doffz if _dk == 1 else 0.0
		p1s.append_array(PackedFloat64Array([_cx + ox, _cz + oz, _cvx, _cvz]))
	var rough: Array = []
	for T: float in (CONIC_TS_WIDE if _wide else (CONIC_TS_BACK if _back else CONIC_TS)):
		for pi in range(0, p1s.size(), 4):
			for ci in range(0, centres.size(), 4):
				var ck0 := int(centres[ci + 3])
				for way: float in [1.0, -1.0]:
					var aims := _aims(t_now + T, p1s[pi], p1s[pi + 1], centres[ci], centres[ci + 1], way, ck0)
					for ai in range(0, aims.size(), 2):
						var sol := _lam(ck0, centres[ci], centres[ci + 1], centres[ci + 2], t_now, p1s[pi], p1s[pi + 1], aims[ai], aims[ai + 1], T, way)
						if sol.is_empty():
							continue
						var pr := _price_conic(t_now + T, sol[0] - p1s[pi + 2], sol[1] - p1s[pi + 3], sol[0], sol[1], sol[2], sol[3], false, 0.0, 0.0)
						rough.append([pr + _tw * T, T, ci, way, pi, ai, sol[2], sol[3]])
	rough.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for r in rough.slice(0, CONIC_KEEP):
		var T: float = r[1]
		var ci: int = r[2]
		var way: float = r[3]
		var pi: int = r[4]
		var cx := centres[ci]
		var cz := centres[ci + 1]
		var gm := centres[ci + 2]
		var ck := int(centres[ci + 3])
		var aims0 := _aims(t_now + T, p1s[pi], p1s[pi + 1], cx, cz, way, ck)
		var ai: int = r[5]
		var sol0 := _lam(ck, cx, cz, gm, t_now, p1s[pi], p1s[pi + 1], aims0[ai], aims0[ai + 1], T, way)
		if sol0.is_empty():
			continue
		var ux := sol0[0] - p1s[pi + 2]
		var uz := sol0[1] - p1s[pi + 3]
		# where and when it really leaves
		var px := 0.0
		var pz := 0.0
		var vx := 0.0
		var vz := 0.0
		var td := t_now
		if _dk == 0:
			var a := _aligned(ux, uz)
			if not _ride_to(a):
				continue
			if _dorb == 0.0:
				# round a star too, off the ring along its motion: the point whose
				# motion runs along the conic's, found by solving again from it
				for _it in 2:
					var aa := _aims(t_now + T, _e_x0, _e_z0, cx, cz, way, ck)
					var s2 := _lam(ck, cx, cz, gm, _e_td, _e_x0, _e_z0, aa[0], aa[1], T - _e_lead, way)
					if s2.is_empty() or T - _e_lead < 3.0:
						break
					# (the conic's velocity relative to the place it leaves: on the
					# plane, less the place's own motion then -- none where it holds
					# still, a turning sun's where it rides with one)
					ux = s2[0]
					uz = s2[1]
					if _dhs >= 0:
						_dep_at(_e_td)
						ux -= _cvx
						uz -= _cvz
					if not _ride_to(_aligned(ux, uz)):
						break
			td = _e_td
			px = _e_x0
			pz = _e_z0
			vx = _e_vx0
			vz = _e_vz0
		elif _dk == 1:
			td = t_now + _hold
			_dep_at(td)
			px = _cx + _doffx
			pz = _cz + _doffz
			vx = _cvx
			vz = _cvz
		else:
			px = _dpx
			pz = _dpz
			vx = _dvx
			vz = _dvz
		var Te := T - (td - t_now)
		if Te < 3.0:
			continue
		var te := td + Te
		var cvdx := 0.0
		var cvdz := 0.0
		if _dk != 2:
			_dep_at(td)
			cvdx = _cvx
			cvdz = _cvz
		_tgt_at(te)
		var u2x: float = float(r[6]) - _cvx
		var u2z: float = float(r[7]) - _cvz
		# (the target is the star this conic is about: by its index where the
		# pair turns, since that sun at te is not where this centre has it now)
		var own := _tk == 0 and _torb == 0.0 and ((ck >= 0 and _ths == ck) or (ck < 0 and _ths < 0 and absf(_thx - cx) < 1.0 and absf(_thz - cz) < 1.0))
		for s: float in _senses:
			var aims := _aims(te, px, pz, cx, cz, way, ck)
			var p2x := aims[0]
			var p2z := aims[1]
			if _tk == 0 and not own:
				# a ring (a world's, or a star's the conic is not about): its
				# tangent point for the conic's own arrival
				_tgt_at(te)
				var m := sqrt(u2x * u2x + u2z * u2z)
				if m < 1e-6:
					continue
				var phi := atan2(-s * u2x / m, s * u2z / m)
				p2x = _cx + _tR * cos(phi)
				p2z = _cz + _tR * sin(phi)
			var sol := _lam(ck, cx, cz, gm, td, px, pz, p2x, p2z, Te, way)
			if sol.is_empty():
				continue
			var pr := _price_conic(te, sol[0] - cvdx, sol[1] - cvdz, sol[0], sol[1], sol[2], sol[3], true, vx, vz)
			out.append([pr + _tw * T, sol[0] - (cvdx if _dk != 2 else 0.0), sol[1] - (cvdz if _dk != 2 else 0.0), T, way, s, 0.0, 0.0, te])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var flat := PackedFloat64Array()
	for o in out:
		flat.append_array(PackedFloat64Array(o))
	return flat


## Where a conic aims at te: the target's centre (or its spot alongside); to
## a star's close orbit round this centre, the ring point most of a half lap on.
## ck: the turning sun the conic is about (-1 a centre that holds still). That
## sun is asked by index (THE CONIC'S "OWN STAR" AIM, ruling 23): the sun at te
## is not where the centre was laid (by some px in a flight), so asked by place
## the aim went to the sun's centre, through its keep-out, not round its ring.
## The ring point is round where the sun is at te, most of a half lap on from p1
## as seen from the centre now.
func _aims(te: float, p1x: float, p1z: float, cx: float, cz: float, way: float, ck: int = -1) -> PackedFloat64Array:
	_tgt_at(te)
	if _tk == 1:
		return PackedFloat64Array([_cx + _toffx, _cz + _toffz])
	if ck >= 0:
		if _torb == 0.0 and _ths == ck:
			var b1 := atan2(p1z - cz, p1x - cx) + way * (PI - 0.4)
			return PackedFloat64Array([_cx + _tR * cos(b1), _cz + _tR * sin(b1)])
		return PackedFloat64Array([_cx, _cz])
	if _torb == 0.0 and _ths < 0 and absf(_cx - cx) < 1.0 and absf(_cz - cz) < 1.0:
		var a1 := atan2(p1z - cz, p1x - cx) + way * (PI - 0.4)
		return PackedFloat64Array([cx + _tR * cos(a1), cz + _tR * sin(a1)])
	return PackedFloat64Array([_cx, _cz])


## The engine work a conic would need: leaving (aligned on a world's ring, or
## from the state given) and arriving onto the ring at its speed.
func _price_conic(te: float, ux: float, uz: float, v1x: float, v1z: float, v2x: float, v2z: float, at: bool, vx: float, vz: float) -> float:
	var c1 := 0.0
	if at:
		c1 = sqrt((v1x - vx) * (v1x - vx) + (v1z - vz) * (v1z - vz))
	elif _dk == 0:
		c1 = absf(sqrt(ux * ux + uz * uz) - absf(_dw) * _drt)
	elif _dk == 1:
		c1 = sqrt(ux * ux + uz * uz)
	else:
		c1 = sqrt((v1x - _dvx) * (v1x - _dvx) + (v1z - _dvz) * (v1z - _dvz))
	_tgt_at(te)
	var u2x := v2x - _cvx
	var u2z := v2z - _cvz
	var c2 := sqrt(u2x * u2x + u2z * u2z)
	if _tk == 0:
		c2 = absf(c2 - _tV)
	return c1 + c2


## THE CONIC ABOUT CENTRE ck from p1 at t1 to p2 T later: [v1x, v1z, v2x,
## v2z] on the plane, or empty. ck -1: about the fixed (cx, cz), as
## `_lambert_gm`. ck a turning sun's index: solved in that sun's own frame --
## p1 from where it is at t1, p2 from where it is at t1 + T -- and its motion
## then added back to each end (the sun's own pull round the balance point,
## some thousandths of a px/s^2, is left out: these are guesses Newton refines).
func _lam(ck: int, cx: float, cz: float, gm: float, t1: float, p1x: float, p1z: float, p2x: float, p2z: float, T: float, way: float) -> PackedFloat64Array:
	if ck < 0:
		return _lambert_gm(cx, cz, gm, p1x, p1z, p2x, p2z, T, way)
	var a1 := G.star_ph[ck] + G.pair_n * t1
	var a2 := G.star_ph[ck] + G.pair_n * (t1 + T)
	var rr := G.star_rad[ck]
	var c1x := G.star_cx[ck] + rr * cos(a1)
	var c1z := G.star_cz[ck] + rr * sin(a1)
	var c2x := G.star_cx[ck] + rr * cos(a2)
	var c2z := G.star_cz[ck] + rr * sin(a2)
	var sol := _lambert_gm(c1x, c1z, gm, p1x, p1z, p2x - c2x + c1x, p2z - c2z + c1z, T, way)
	if sol.is_empty():
		return sol
	sol[0] += -rr * G.pair_n * sin(a1)
	sol[1] += rr * G.pair_n * cos(a1)
	sol[2] += -rr * G.pair_n * sin(a2)
	sol[3] += rr * G.pair_n * cos(a2)
	return sol


## THE CONIC about (cx, cz) of pull gm from p1 to p2 in T, way 1 counter-
## clockwise (the worlds' way), -1 clockwise: [v1x, v1z, v2x, v2z], or empty.
## Within 7 degrees of a half lap (or none) a conic has no plane: aimed as far
## round as the ring's own size, or just out of that zone.
func _lambert_gm(cx: float, cz: float, gm: float, p1x: float, p1z: float, p2x: float, p2z: float, T: float, way: float) -> PackedFloat64Array:
	var r1x := p1x - cx
	var r1z := (p1z - cz) * way
	var r2x := p2x - cx
	var r2z := (p2z - cz) * way
	var dth := fposmod(atan2(r2z, r2x) - atan2(r1z, r1x), TAU)
	if absf(sin(dth)) < 0.12:
		var rr := sqrt(r2x * r2x + r2z * r2z)
		if rr < 1.0:
			return PackedFloat64Array()
		var da0 := maxf(0.13, minf((_tR if _tk == 0 else 20.0) / rr, 0.3))
		var da := 0.0
		if absf(sin(dth + da0)) >= 0.12 and dth + da0 > 0.0 and dth + da0 < TAU:
			da = da0
		elif absf(sin(dth - da0)) >= 0.12 and dth - da0 > 0.0 and dth - da0 < TAU:
			da = -da0
		else:
			return PackedFloat64Array()
		var ca := cos(da)
		var sa := sin(da)
		var nx := r2x * ca - r2z * sa
		r2z = r2x * sa + r2z * ca
		r2x = nx
		dth += da
	var sq := sqrt(gm)
	var sol := lambert(r1x, r1z, r2x, r2z, dth, T * sq)
	if sol.is_empty():
		return sol
	return PackedFloat64Array([sol[0] * sq, sol[1] * sq * way, sol[2] * sq, sol[3] * sq * way])


## The universal variables' time of flight at z (mu 1), NAN where the conic
## does not exist (Stumpff's C and S worked out once).
static func _tof(z: float, r1: float, r2: float, A: float) -> float:
	var c := 0.5
	var sv := 1.0 / 6.0
	if z > 1e-6:
		var q := sqrt(z)
		c = (1.0 - cos(q)) / z
		sv = (q - sin(q)) / (q * q * q)
	elif z < -1e-6:
		var q2 := sqrt(-z)
		c = (cosh(q2) - 1.0) / -z
		sv = (sinh(q2) - q2) / (q2 * q2 * q2)
	var y := r1 + r2 + A * (z * sv - 1.0) / sqrt(c)
	if not (y > 0.0):
		return NAN
	var yc := y / c
	return yc * sqrt(yc) * sv + A * sqrt(y)


static func _y_of(z: float, r1: float, r2: float, A: float) -> float:
	var c := 0.5
	var sv := 1.0 / 6.0
	if z > 1e-6:
		var q := sqrt(z)
		c = (1.0 - cos(q)) / z
		sv = (q - sin(q)) / (q * q * q)
	elif z < -1e-6:
		var q2 := sqrt(-z)
		c = (cosh(q2) - 1.0) / -z
		sv = (sinh(q2) - q2) / (q2 * q2 * q2)
	return r1 + r2 + A * (z * sv - 1.0) / sqrt(c)


## LAMBERT'S PROBLEM by universal variables, mu 1, counterclockwise, in 64-bit
## scalars (`ShipFlight.lambert`'s solver, whose Vector3 inputs are 32-bit):
## the conic from r1 to r2 sweeping dth in tof: [v1x, v1z, v2x, v2z], or empty.
static func lambert(r1x: float, r1z: float, r2x: float, r2z: float, dth: float, tof: float) -> PackedFloat64Array:
	var r1 := sqrt(r1x * r1x + r1z * r1z)
	var r2 := sqrt(r2x * r2x + r2z * r2z)
	if r1 < 1.0 or r2 < 1.0:
		return PackedFloat64Array()
	var A := sin(dth) * sqrt(r1 * r2 / (1.0 - cos(dth)))
	var zhi := 4.0 * PI * PI - 1e-3
	var lo := -100.0
	var tlo := _tof(lo, r1, r2, A)
	if is_nan(tlo):
		# where the conic starts to exist: a coarse step up, then a bisection
		var prev := lo
		var found := false
		for j in range(1, 41):
			var z := -100.0 + (zhi + 100.0) * float(j) / 40.0
			if not is_nan(_tof(z, r1, r2, A)):
				var bad := prev
				var good := z
				for _e in 24:
					var mz := 0.5 * (bad + good)
					if is_nan(_tof(mz, r1, r2, A)):
						bad = mz
					else:
						good = mz
				lo = good
				tlo = _tof(lo, r1, r2, A)
				found = true
				break
			prev = z
		if not found:
			return PackedFloat64Array()
	var hi := zhi
	var thi := _tof(hi, r1, r2, A)
	if is_nan(thi) or tlo > tof or thi < tof:
		return PackedFloat64Array()
	for _it in 46:
		var m := 0.5 * (lo + hi)
		var tm := _tof(m, r1, r2, A)
		if is_nan(tm) or tm < tof:
			lo = m
		else:
			hi = m
	var zb := 0.5 * (lo + hi)
	var y := _y_of(zb, r1, r2, A)
	var fl := 1.0 - y / r1
	var g := A * sqrt(y)
	var gd := 1.0 - y / r2
	if absf(g) < 1e-9:
		return PackedFloat64Array()
	return PackedFloat64Array([(r2x - r1x * fl) / g, (r2z - r1z * fl) / g, (r2x * gd - r1x) / g, (r2z * gd - r1z) / g])


# ---------------------------------------------------------------- replay
## Whether a choice was made for this very flight: the same departure (kind,
## place, ring or spot, centre, the sun it rides with) and the same target
## (kind, place, ring and speed or spot, centre, sun), its sense one the target
## allows. The first build checked only the places and the ring, so a choice
## made for another radius, spot or sense was rebuilt as it was (the planner
## review, Oct 30). A settled orbit round a sun of a turning pair is a -9
## circle whose centre moves: it is the same flight by its sun (`dhs`), its
## centre at t = 0 being that sun's, not by where the ship saw the sun.
func _same_flight(c: Dictionary) -> bool:
	if int(c.get("dk", -1)) != _dk or int(c.get("dp", -99)) != _dplace or int(c.get("tp", -99)) != _tplace or int(c.get("tk", -1)) != _tk:
		return false
	if int(c.get("dhs", -9)) != _dhs or int(c.get("ths", -9)) != _ths:
		return false
	if _dk == 0 and not (_near(c.get("w", NAN), _dw) and _near(c.get("rt", NAN), _drt)):
		return false
	if _dk == 1 and not (_near(c.get("dox", NAN), _doffx) and _near(c.get("doz", NAN), _doffz)):
		return false
	if _dk != 2 and _dplace == -9 and not (_near(c.get("dhx", NAN), _dhx) and _near(c.get("dhz", NAN), _dhz)):
		return false
	if _tk == 0 and not (_near(c.get("R", NAN), _tR) and _near(c.get("V", NAN), _tV)):
		return false
	if _tk == 1 and not (_near(c.get("tox", NAN), _toffx) and _near(c.get("toz", NAN), _toffz)):
		return false
	if _tplace == -9 and not (_near(c.get("thx", NAN), _thx) and _near(c.get("thz", NAN), _thz)):
		return false
	return float(c.get("s", 0.0)) in _senses


## (NAN, a missing number, is never near)
static func _near(a: Variant, b: float) -> bool:
	return absf(float(a) - b) <= 1e-9


## THE SAME FLIGHT AGAIN from its choice, one integration, every number as it
## was: round a ring, while its departure is still ahead and the ride from
## where the ship is now reaches it at a phasing within THRUST; alongside,
## while it is still ahead (the ship holds there, KEEP_HOLD); free, at the
## same moment from the same state. Null when it cannot be.
func _replay(c: Dictionary) -> Result:
	if not _same_flight(c):
		return null
	var td := float(c.td)
	var lead := td - t_now
	if lead < -1e-9:
		return null
	lead = maxf(lead, 0.0)
	var ad := float(c.get("ad", 0.0))
	var k := 1.0
	if _dk == 0:
		var dr := 1.0 if _dw >= 0.0 else -1.0
		var dang := fposmod(dr * (ad - _dang), TAU)
		if lead < 1e-6:
			# (nor one that must still spin up, `_spin`)
			if (dang > 1e-4 and dang < TAU - 1e-4) or _spin > 0.0:
				return null
		else:
			# the ride's phasing over the lead that is left, its push at most
			# THRUST and its speed under VMAX (its spin-up first, over what is
			# left of the ride if that is shorter, as `ShipFlight._ride_shape`
			# flies it)
			k = 2.0 * dang / (absf(_dw) * lead) - 1.0
			if _spin > 0.0:
				# (the ship rides at its ring's own rate until its spin-up, which
				# may start any time the ride allows: from where it reaches the
				# departure at the ride's own pace, as `ShipFlight._ride_shape`
				# flies it, a phasing k only for what that cannot make up)
				var w := absf(_dw)
				var w0 := absf(_dw0)
				var sp := minf(_spin, lead)
				var lf := clampf((dang - w0 * lead + (w - w0) * sp * 0.5) / (w - w0), sp, lead)
				var plain := w0 * (lead - lf) + w * lf - (w - w0) * sp * 0.5
				k = 1.0 + 2.0 * (dang - plain) / (w * lead)
			var vr := absf(_dw) * _drt
			if absf(k - 1.0) > THRUST * lead / (PI * vr) + 1e-9 or k * vr > VMAX + 1e-6 or k < 0.2:
				return null
		_dep_at(td)
		_e_x0 = _cx + _drt * cos(ad)
		_e_z0 = _cz + _drt * sin(ad)
		_e_vx0 = _cvx - _dw * _drt * sin(ad)
		_e_vz0 = _cvz + _dw * _drt * cos(ad)
	elif _dk == 1:
		_dep_at(td)
		_e_x0 = _cx + _doffx
		_e_z0 = _cz + _doffz
		_e_vx0 = _cvx
		_e_vz0 = _cvz
	else:
		if lead > 1e-9 or _dpx != float(c.get("x0", NAN)) or _dpz != float(c.get("z0", NAN)) or _dvx != float(c.get("vx0", NAN)) or _dvz != float(c.get("vz0", NAN)):
			return null
		_e_x0 = _dpx
		_e_z0 = _dpz
		_e_vx0 = _dvx
		_e_vz0 = _dvz
	_e_td = td
	_e_ad = ad
	_e_lead = lead
	_e_k = k
	_e_ph = _phase_work(k) if _dk == 0 else 0.0
	_e_dvx = float(c.dvx)
	_e_dvz = float(c.dvz)
	_e_ux = float(c.get("ux", 0.0))
	_e_uz = float(c.get("uz", 0.0))
	_e_fix = bool(c.get("fix", false))
	_e_afix = float(c.get("afix", 0.0))
	_e_a0 = float(c.get("a0", 0.0))
	_e_te = float(c.te)
	_e_s = float(c.s)
	_e_phi = float(c.get("phi", 0.0))
	_e_d2 = float(c.get("d2", 0.0))
	_e_w2 = float(c.get("w2", 0.0))
	_e_pk = float(c.get("pk", THRUST))
	_e_J = float(c.get("J", 0.0))
	_keep_best()
	return _build(&"replay")


## FROM A CHOICE THAT CANNOT BE REBUILT (its departure gone by, or open
## space), for the same places: its departure flown again, toward its old
## arrival time, from its old ring point while the ride still reaches it (or
## else from wherever its motion runs along the flight's). True when it flies;
## `_solve` keeps it only while it costs about what it did. The first build
## kept any flight that flew, from any departure place (the planner review).
func _warm(c: Dictionary) -> bool:
	if int(c.get("dk", -1)) != _dk or int(c.get("dp", -99)) != _dplace or int(c.get("tp", -99)) != _tplace or int(c.get("tk", -1)) != _tk:
		return false
	# (nor from a flight out of a settled orbit round another centre: round a
	# sun of a turning pair against round the balance point, say)
	if int(c.get("dhs", -9)) != _dhs or int(c.get("ths", -9)) != _ths:
		return false
	var ux := float(c.get("ux", 0.0))
	var uz := float(c.get("uz", 0.0))
	var te := float(c.get("te", 0.0))
	var s := float(c.get("s", 1.0))
	if not s in _senses:
		s = _senses[0]
	var fix := bool(c.get("fix", false))
	var afix := float(c.get("afix", 0.0))
	if fix and _dk == 0 and not _ride_to(afix):
		# (its ring point gone past the ride's reach: a ride to it would read
		# a coast that was never flown, a SCRIPT ERROR in the first build)
		fix = false
	if te > t_now + 1.0:
		_refine_at(ux, uz, fix, afix, te, s, 3)
	else:
		_fly(ux, uz, fix, afix)
	return _b_J < INF


# ---------------------------------------------------------------- the result
## THE BEST FLIGHT AS SAMPLES: flown once more (the same integration), then the
## coast and the arrival burn sampled SAMPLE apart from the departure, the
## arrival's end on the sample grid (its burn worked out again there).
func _build(kind: StringName) -> Result:
	var t_b := Time.get_ticks_usec()
	var res := _build_in(kind)
	_us_build += Time.get_ticks_usec() - t_b
	return res


func _build_in(kind: StringName) -> Result:
	var res := Result.new()
	res.kind = kind
	if _b_J == INF or _b.is_empty():
		return res
	var b := _b
	# (to just past its arrival, so a replay made later flies the very same
	# steps: the last step before the time cap is cut short to meet it)
	_integrate(float(b.td), float(b.x0), float(b.z0), float(b.vx0), float(b.vz0), float(b.dvx), float(b.dvz), float(b.te) + 0.5)
	var td := float(b.td)
	var s := float(b.s)
	# THE END ON THE SAMPLE GRID: the next sample after the arrival, where the
	# constant burn onto a ring pulls a little less than it did (its pull falls
	# as the arrival comes later), else the one before; the burn worked out
	# again there, constant within BURN_TOL or else the cubic
	var n0 := maxi(2, ceili((float(b.te) - td) / SAMPLE - 1e-6))
	var n := n0
	var ar := PackedFloat64Array()
	for nn: int in [n0, n0 - 1]:
		if nn < 2 or td + float(nn) * SAMPLE > _cT[_cn - 1]:
			continue
		var tq := td + float(nn) * SAMPLE
		var sq := _coast_at(tq)
		var aq := _arrival(tq, sq[0], sq[1], sq[2], sq[3], s, float(b.pk))
		if aq.is_empty() or tq - aq[2] < _tc0:
			continue
		if ar.is_empty() or (aq[7] > 0.5 and ar[7] < 0.5):
			ar = aq
			n = nn
		if ar[7] > 0.5 or _tk == 1:
			break
	if ar.is_empty():
		return res
	var te := td + float(n) * SAMPLE
	var phi := ar[1]
	var d2 := ar[2]
	var dxx := ar[3]
	var dxz := ar[4]
	var dux := ar[5]
	var duz := ar[6]
	var tb := te - d2
	var Ax := 3.0 * dxx - dux * d2
	var Az := 3.0 * dxz - duz * d2
	var Bx := dux * d2 - 2.0 * dxx
	var Bz := duz * d2 - 2.0 * dxz
	res.samp.resize(n + 1)
	res.burns.resize(n + 1)
	var least := INF
	var j := 0
	var h := 1.0
	for k in n + 1:
		var tq := td + float(k) * SAMPLE
		while j + 2 < _cn and _cT[j + 1] <= tq:
			j += 1
		h = _cT[j + 1] - _cT[j]
		var u := (tq - _cT[j]) / h if h > 0.0 else 0.0
		var u2 := u * u
		var u3 := u2 * u
		var h00 := 2.0 * u3 - 3.0 * u2 + 1.0
		var h10 := (u3 - 2.0 * u2 + u) * h
		var h01 := -2.0 * u3 + 3.0 * u2
		var h11 := (u3 - u2) * h
		var x := h00 * _cX[j] + h10 * _cVX[j] + h01 * _cX[j + 1] + h11 * _cVX[j + 1]
		var z := h00 * _cZ[j] + h10 * _cVZ[j] + h01 * _cZ[j + 1] + h11 * _cVZ[j + 1]
		var lit := tq < _tc0
		if tq >= tb:
			var tau := (tq - tb) / d2
			x += Ax * tau * tau + Bx * tau * tau * tau
			z += Az * tau * tau + Bz * tau * tau * tau
			lit = true
		res.samp[k] = Vector3(x, 0.0, z)
		res.burns[k] = 1 if lit else 0
		# (the coast was held clear step by step as it was flown; the burn's
		# samples are checked here)
		if tq >= tb and (k % 4 == 0 or k == n):
			least = minf(least, _margin(x, z, tq))
	# the coast clean up to the burn (between samples too) and the burn's samples
	_coast_at(tb)
	least = minf(least, _cCL[mini(_qk + 1, _cn - 1)])
	var amax := 1.0
	for k in range(1, n, 2):
		amax = maxf(amax, (res.samp[k + 1] - 2.0 * res.samp[k] + res.samp[k - 1]).length() / (SAMPLE * SAMPLE))
	res.amax = amax
	res.clear = least
	res.clean = least >= -0.05
	res.found = true
	res.t0 = td
	res.lead = float(b.lead)
	res.lead_k = float(b.k)
	res.a_dep = float(b.ad)
	res.dur = float(n) * SAMPLE
	res.esc_t = _tc0 - td
	res.dvp = float(b.ph)
	res.dv1 = sqrt(float(b.dvx) * float(b.dvx) + float(b.dvz) * float(b.dvz))
	res.dv2 = ar[0]
	res.arr_const = ar[7] > 0.5
	res.work = res.dvp + res.dv1 + res.dv2
	res.d2 = d2
	res.T = te - t_now
	res.cost = res.work + _tw * res.T
	res.priced = _b_J
	_tgt_at(te)
	var keepd := _tk == 1
	var arx := _toffx if keepd else _tR * cos(phi)
	var arz := _toffz if keepd else _tR * sin(phi)
	var rvx := 0.0 if keepd else -sin(phi) * s * _tV
	var rvz := 0.0 if keepd else cos(phi) * s * _tV
	var cen := -(_tV * _tV) / _tR if not keepd and _tR > 0.0 else 0.0
	res.end = {"body": _tplace, "p": Vector3(_cx + arx, 0.0, _cz + arz), "v": Vector3(_cvx + rvx, 0.0, _cvz + rvz),
		"a": Vector2(cen * cos(phi), cen * sin(phi)) if not keepd else Vector2.ZERO, "arel": Vector2(arx, arz),
		"rv": Vector2(rvx, rvz), "t": te, "keep": keepd, "sense": s if not keepd else 0.0}
	res.choice = {"v": CHOICE_V, "dk": _dk, "dp": _dplace, "tp": _tplace, "tk": _tk, "w": _dw, "rt": _drt,
		"dox": _doffx, "doz": _doffz, "dhx": _dhx, "dhz": _dhz, "R": _tR, "V": _tV, "tox": _toffx, "toz": _toffz,
		"thx": _thx, "thz": _thz, "sn": _tsense, "dhs": _dhs, "ths": _ths,
		"td": td, "ad": float(b.ad), "a0": float(b.a0), "dvx": float(b.dvx), "dvz": float(b.dvz), "ux": float(b.ux), "uz": float(b.uz),
		"x0": float(b.x0), "z0": float(b.z0), "vx0": float(b.vx0), "vz0": float(b.vz0),
		"fix": bool(b.fix), "afix": float(b.afix), "te": float(b.te), "s": s, "phi": float(b.phi), "d2": float(b.d2),
		"w2": float(b.w2), "pk": float(b.pk), "J": res.cost, "cap": _tcap, "tw": _tw}
	return res


# ---------------------------------------------------------------- a flight in two legs
## A FLIGHT IN TWO LEGS, in a twin, where one departure burn and one coast
## reach nothing (the wider search too): its first leg aimed at a point in open
## space (`_waypoints`: a keep target at place -9, c that point), its second
## leaving free off the first's coast CHAIN_PRE s before the first's arrival
## burn would start, so the ship never stops there -- a coast, a burn that
## turns it, a coast, the arrival. One Result, one set of samples SAMPLE apart
## from the first's departure: drawn, previewed and flown as any other. Its
## choice is the first leg's with `chain` {W, k, pre, c1, c2}, so the same
## flight comes back (`_chain_again`): the first leg rebuilt from c1 as any
## flight is, the second then leaving from the very same state is rebuilt from
## c2 as a free one is. The first found is kept; with a `hint` (an old flight's
## point, tried first), the flight through it only while the first found
## without it (a fresh plan's) arrives no sooner. Through the hint alone, a
## flight in two legs looked for again where its legs no longer held stood
## later than a fresh plan's (seed 31337 node 28, orbit9 -9 to keep 2, line-up
## 4, planned again 14 times: 243.82 against 242.54; the fifth review, Nov 1).
static func _chain(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, hint: Vector2) -> Result:
	var rh: Result = null
	if hint.is_finite():
		rh = _chain_try(G, dep, tgt, t, hint, CHAIN_PRE)
	for W in _waypoints(G, dep, tgt, t):
		var rj := _chain_try(G, dep, tgt, t, W, CHAIN_PRE)
		if rj != null:
			if rh == null:
				return rj
			var keep := rh if float(rh.end.t) <= float(rj.end.t) + 1e-6 else rj
			keep.integrations = rh.integrations + rj.integrations
			keep.steps = rh.steps + rj.steps
			return keep
	return rh


## The flight in two legs through W, its second leaving `pres` s (each in
## turn) before the first's arrival burn: null when none is found and clean.
static func _chain_try(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, W: Vector2, pres: Array) -> Result:
	var l1 := FlightSolve.new()
	l1._leg = 1
	l1._wide_ok = false
	var r1 := l1._solve(G, dep, _wp_target(W), t, {})
	if not r1.found or not r1.clean:
		return null
	var tried := -1
	for pre: float in pres:
		# (each cut once: one past the first's departure burn stands for all
		# before it)
		var k := _cut_k(r1, pre)
		if k == tried:
			continue
		tried = k
		var rj := _leg_two(G, l1, r1, tgt, t, W, pre, k, {})
		if rj != null:
			return rj
	return null


## The sample of the first leg its second leaves from, `pre` s before the
## first's arrival burn and at least CHAIN_AFTER after its departure burn.
static func _cut_k(r1: Result, pre: float) -> int:
	var tb := r1.t0 + r1.dur - r1.d2
	return floori((maxf(tb - pre, r1.t0 + r1.esc_t + CHAIN_AFTER) - r1.t0) / SAMPLE)


## A keep target at the fixed point W.
static func _wp_target(W: Vector2) -> Dictionary:
	return {"kind": &"keep", "place": -9, "c": W, "off": Vector2.ZERO}


## THE SECOND LEG off the first (r1, flown by l1): free from its coast at sample
## k (k < 0: `pre` s before its arrival burn, and after its departure burn by
## CHAIN_AFTER), `c2` its choice to rebuild it from; joined into one flight.
static func _leg_two(G: MapGravity, l1: FlightSolve, r1: Result, tgt: Dictionary, t: float, W: Vector2, pre: float, k_fix: int, c2: Dictionary) -> Result:
	var tb := r1.t0 + r1.dur - r1.d2
	var k := k_fix if k_fix >= 0 else _cut_k(r1, pre)
	if k < 1 or k >= r1.samp.size() - 1 or r1.t0 + float(k) * SAMPLE > tb - SAMPLE:
		return null
	var tc := r1.t0 + float(k) * SAMPLE
	var st := l1._coast_at(tc)
	var l2 := FlightSolve.new()
	l2._leg = 2
	l2._wide_ok = false
	var d2 := {"kind": &"free", "p": Vector2(st[0], st[1]), "v": Vector2(st[2], st[3]), "_pace": l1._kp}
	var r2 := l2._solve(G, d2, tgt, tc, c2)
	if not r2.found or not r2.clean:
		return null
	return _join(r1, k, r2, t, W, tb - tc)


## THE TWO LEGS AS ONE FLIGHT: the first's samples up to sample k, then the
## second's (its first sample is the first's state there), its end, the work of
## both (the first's arrival burn never flown), and the choice to rebuild it.
static func _join(r1: Result, k: int, r2: Result, t: float, W: Vector2, pre: float) -> Result:
	var res := Result.new()
	res.found = true
	res.clean = r1.clean and r2.clean
	res.kind = &"replay" if r1.kind == &"replay" and r2.kind == &"replay" else &"solved"
	res.legs = 2
	res.wp = W
	res.k_cut = k
	res.t_cut = r1.t0 + float(k) * SAMPLE
	res.t0 = r1.t0
	res.lead = r1.lead
	res.lead_k = r1.lead_k
	res.a_dep = r1.a_dep
	res.sdt = SAMPLE
	res.samp = r1.samp.slice(0, k)
	res.samp.append_array(r2.samp)
	res.burns = r1.burns.slice(0, k)
	res.burns.append_array(r2.burns)
	var n := res.samp.size() - 1
	res.dur = float(n) * SAMPLE
	var amax := 1.0
	for j in range(1, n, 2):
		amax = maxf(amax, (res.samp[j + 1] - 2.0 * res.samp[j] + res.samp[j - 1]).length() / (SAMPLE * SAMPLE))
	res.amax = amax
	res.esc_t = r1.esc_t
	res.end = r2.end.duplicate()
	res.dvp = r1.dvp
	res.dv1 = r1.dv1
	res.dv2 = r2.dv2
	res.work = r1.dvp + r1.dv1 + r2.dv1 + r2.dv2
	res.arr_const = r2.arr_const
	res.d2 = r2.d2
	res.T = float(r2.end.t) - t
	res.cost = res.work + TIME_W * res.T
	res.priced = res.cost
	res.clear = minf(r1.clear, r2.clear)
	res.integrations = r1.integrations + r2.integrations
	res.steps = r1.steps + r2.steps
	res.choice = r1.choice.duplicate()
	res.choice.J = res.cost
	res.choice.chain = {"W": W, "k": k, "pre": pre, "c1": r1.choice, "c2": r2.choice}
	return res


## A FLIGHT IN TWO LEGS FROM ITS CHOICE: the first leg from c1 (rebuilt as any
## flight is while its departure is ahead, else searched from it), the second
## off it -- at the very sample it left from when the first is the same flight,
## so it is rebuilt too, else as long before the first's arrival burn -- from
## c2. Kept while it costs about what it did (WARM_K, WARM_ADD); else null, and
## the caller looks again. Kept, `solve` holds it against a fresh plan of one
## leg (`_sooner_of`).
static func _chain_again(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, c: Dictionary) -> Result:
	var ch: Dictionary = c.chain
	var W: Vector2 = ch.get("W", Vector2.INF)
	if not W.is_finite():
		return null
	var l1 := FlightSolve.new()
	l1._leg = 1
	l1._wide_ok = false
	var r1 := l1._solve(G, dep, _wp_target(W), t, ch.get("c1", {}))
	if not r1.found or not r1.clean:
		return null
	var same := r1.kind == &"replay"
	var rj := _leg_two(G, l1, r1, tgt, t, W, float(ch.get("pre", 0.0)), int(ch.get("k", -1)) if same else -1, ch.get("c2", {}))
	if rj == null:
		return null
	if rj.kind == &"replay":
		return rj
	rj.kind = &"warm"
	var j_old := float(c.get("J", INF))
	if rj.cost > j_old + _warm_slack(j_old):
		return null
	return rj


## WHERE THE SHIP IS NOW, as it leaves (round its ring, alongside, or free).
func _dep_pos(t: float) -> Vector2:
	if _dk == 2:
		return Vector2(_dpx, _dpz)
	_dep_at(t)
	if _dk == 1:
		return Vector2(_cx + _doffx, _cz + _doffz)
	return Vector2(_cx + _drt * cos(_dang), _cz + _drt * sin(_dang))


## THE POINTS A FLIGHT IN TWO LEGS IS AIMED THROUGH, best first: round the
## pair's balance point, half way round from where the ship is to where the
## place will be in CHAIN_T, the short way then the long, at CHAIN_R times the
## farther of the two from it (never closer than CHAIN_CLEAR times the stars'
## separation, nor past CHAIN_EDGE of the map's edge from star A).
static func _waypoints(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var fs := FlightSolve.new()
	fs.G = G
	fs.t_now = t
	if G.star_x0.size() < 2 or not fs._setup_in(dep, tgt):
		return out
	var pd := fs._dep_pos(t)
	fs._tgt_at(t + CHAIN_T)
	var pt := Vector2(fs._cx + fs._toffx, fs._cz + fs._toffz)
	var c := G.bary
	var qd := pd - c
	var qt := pt - c
	var gap := wrapf(qt.angle() - qd.angle(), -PI, PI)
	# (the suns' distance apart at t 0: a turning pair is rigid, so it is the
	# same at every t, as the balance point is where it is)
	var sep := Vector2(G.star_x0[1] - G.star_x0[0], G.star_z0[1] - G.star_z0[0]).length()
	var e := CHAIN_EDGE * G.edge
	for way in 2:
		var a := qd.angle() + (gap if way == 0 else gap - signf(gap) * TAU) * 0.5
		var u := Vector2(cos(a), sin(a))
		# (as far out as the map allows along u: |c + u r| = e)
		var cu := c.dot(u)
		var r_hi := -cu + sqrt(maxf(cu * cu - c.length_squared() + e * e, 0.0))
		for rk: float in CHAIN_R:
			var r := clampf(maxf(qd.length(), qt.length()) * rk, CHAIN_CLEAR * sep, r_hi)
			out.append(c + u * r)
	return out
