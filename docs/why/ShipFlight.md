The reasoning behind `tkg/scripts/ui/sysmap/ShipFlight.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ship flight design

Above `const THRUST := 40.0`:

```text
YOUR SHIP ON THE SECTOR MAP, flown (Jon: "can we have WASD move the little
ship? Just for fun, like can the player fly around the sector"). Jon's pick
of the six mocked (scratchpad `shipflight`, option F, "Arcade orbits"):

OPEN SPACE flies like a little ship and not like a planet. A and D turn the
nose, W thrusts along it and fades out at a top speed, S brakes, and letting
go coasts to a stop. There is no pull from the star: real gravity made every
pass at the star or a giant a fight with the stick (Jon: "the sun's gravity
is too much and makes flying feel clumsy and awkward"). The star is a soft
bumper instead -- fly at it and your motion is turned sideways round it.

A WORLD'S RING IS A RAIL. Let go inside it slower than CAPTURE and the ship
eases onto a circular orbit round the world and stays there with no input;
the panel opens that world. On the rail A and D take the orbit closer or
wider, and W leaves along it (and the ring will not take you back for a
moment, so leaving is easy). Belts, stations, derelicts and contacts hold you
ALONGSIDE the same way; the star has a close-orbit ring of its own. Holding
W never captures, so you can cruise across the system past a world.

THE DOTTED LINE is where you will END UP if you let go now: the same step the
ship flies, run forward, to the capture -- where it bends onto the orbit you
will be on -- or to where the coast dies out. A capture the line is showing
holds until you are STICKY over the capture speed, and the ship keeps to the
same rule, so the line cannot say one thing and the ship do another. Measured
in the mock over 303 approaches: the answer changed in the last two seconds
before arrival 7 times, and matched what happened 300 times.

EVERY AUTO-FLIGHT IS A MANOEUVRE (Jon: "when you double click on a planet,
the trajectory should be actually orbitally sound", and "instead of flying
straight to the planet ... more convincing orbital mechanics on the auto fly
to a planet"). Out of an orbit, an ESCAPE: a prograde burn spiralling out of
the ring to where it leaves along the transfer; then the TRANSFER, a Lambert
conic round the star, prograde, engine off, faster near the star, a short
burn at each end blending the motions; when no direct arc is clean, round a
WAYPOINT outside with a burn there; then the ARRIVAL, met with the world's
own motion, and the insertion any capture flies, onto the orbit. There is
no straight or swooping fallback any more.

SINCE RULING 20 (Oct 30, "Prototype: twin:A giant:A") THE COAST IS SOLVED
(`FlightSolve`): from the ring the ship rides (a world's, a star's close
orbit, a settled star orbit), alongside, or free, through the real pull of
the stars and the moving giant on map time, a burn at THRUST onto the
target's ring at its own speed, landing on it exactly. The ride round to the
departure point is `rail.phase` (round a world or a star close in), the
flight's own first samples (round a settled star orbit, `_with_ride`) or the
hold alongside (`keep.hold`); its last stretch, the burn onto the place, is
flown as the insertion was (`_arrive`: at the place, burning on). The Lambert
manoeuvres above are kept only as the fallback, in a system of one star, for
the under 1% of flights the solver finds nothing clean for (`_old_plan`);
failing that, the ship is put in orbit there. In a twin, where one leg
reaches nothing, the solver flies two (`FlightSolve._chain`: aimed through a
point round the pair, turning off that coast before it would stop), one
FlightPlan like any other. The preview and the click plan
on a worker (`plan_bg`, `fly_bg`), the fallback and the line's layout there
too: a twin's plan takes a median of about 40 ms, the worst about 140, and
one the solver's wider search was needed for up to about 250, too long for a
frame. Flying by hand still feels no pull
(Jon, Oct 3). In a twin each star is a bumper with a close ring of its own,
and letting go settles round the nearer star inside its steady zone, else
round both.

All in the plane's own units (x across, z toward you); the view projects
it. Nothing here is saved: where the ship is in a system
lives for the session (`SystemMapScreen._flights`).
```

Above `const THRUST := 40.0`:

```text
THE FEEL, measured in the mock (a run of test players: steer at a world, then
let go, brake, or wait for the line; 303 of 303 ended in orbit, none crashed,
and crossing the system on W took 14 s).
```

## Star settle

Above `const SETTLE_A := 90.0`:

```text
THE STAR HOLDS YOU WHEN NOTHING ELSE DOES (Jon: "If I'm not orbiting a
planet, can't I orbit the star?"). Let go of thrust out of every ring and the
ship turns (SETTLE_TURN) and burns, at most SETTLE_A, into a circle round the
star at the distance it is, going the way the worlds go, at STAR_PACE times
the worlds' own pace there (they keep Kepler's: 800 s a lap at 100 px, so
7.85 / sqrt(r) px/s; fifty times that is 39 px/s at 100 px, 20 at 400 and 13
at the edge -- a lap in a minute or two). Settled within SETTLED_DV.
```

Inside `free_step()`, above `st.acc = Vector2.ZERO`:

```text
COASTING SETTLES ONTO THE STAR (it used to drag to a stop): the nose turns
for SETTLE_TURN, then a burn eases in, at most SETTLE_A. Round the star, or
in a twin round the nearer star or both (`_settle_centre`), chosen as the
coast starts. ROUND A SUN OF A TURNING PAIR all of it is in that sun's own
frame: the ship's motion against the sun's (`cv`, nought for one sun and
round both, so those move to the bit as they did), and the sun's carried
on top, so a ship settled round star B rides round the balance point with
it and keeps its radius (a fixed centre left it at up to 1.1 px/s)
```

## Star caches

Above `var _s_pos := PackedVector2Array()`:

```text
EACH STAR'S OWN NUMBERS, in `_stars`' order, kept from `setup` too: where it
is, its bumper, its keep-clear, its close ring, and the radius a ship is held
out at (a twin's keep-clear, else star_r + 8). Free flight read them through
the layout's lookups every step of both forecast lines, which in a twin, its
two stars and its lines that run their whole 6 s settling, cost the frame
about twice one sun's (MapPerfTest, Oct 31: 5.2 to 6.1 ms a pair against 2.2
to 3.4).
```

Above `var _sp_at := PackedVector2Array()`:

```text
WHERE EACH STAR IS AT t AND HOW FAST IT MOVES, in `_stars`' order, for free
flight's step (ruling 23: the pair turns). One sun, a still pair, or t 0: the
cached places, still. A turning pair: worked out for the step's own t, one
cos/sin for both suns, in `SystemLayout.star_pos`'s and `star_vel`'s very
arithmetic, so the bumper, the hold out of the keep-out and the close rings
ride their sun exactly where the map draws it. Worked out into buffers of
their own (`_sp_buf`, never the cache: a packed array is shared, not
copied), once a step, as the two forecast lines' 360 steps a frame need it
(MapPerfTest holds that frame to a budget, the `_s_pos` cache above).
```

## Settle centre

Above `func _follow(st: FreeState, moving: bool) -> Vector2:`:

```text
THE SETTLE'S CENTRE WHERE IT IS AT t, and how fast it moves: round a sun of
a turning pair it rides with that sun (`cen_id`, read again every step: a
fixed point there was left behind at up to 1.1 px/s, and the ship's circle
with it); the balance point and one sun hold still. Reads `_sp_at`/`_sv_at`
as `_stars_at` left them for this t (`moving` its answer).
```

Above `const PULL_V := 30.0`:

```text
THE PULL BACK ONTO A HELD RADIUS is at most this (px/s). A ship settled
round one star is held within a few px of where it settled, under 3 px/s of
pull, so this never reaches it; a twin's ship let go past where its circle
round both stars may run (`_settle_centre`) is brought in up to 340 px, at
1.2 px/s a px that was 400 px/s.
```

Above `func _settle_centre(st: FreeState, t: float) -> void:`:

```text
WHAT A SHIP LET GO AT st.p SETTLES ROUND (Jon's pick for the twins, ruling
20's DESIGN): one star, the star. In a twin, the nearer star when the ship is
inside its steady zone (`SystemLayout.s_limit` of the other star's share,
times the separation), at that star's own pace; else both stars, round their
balance point at their whole pace, on a circle outside the pair (clear of
each star's capture ring, `_bary_out`) and inside the map (`_bary_in`).
Let go inside the pair but outside both zones, it settles at the edge of the
nearer zone, or out on the pair's least circle, whichever is the shorter way;
and never nearer its star than STAR_ORBIT_GAP outside the star's capture
ring, as the circle round both keeps (`_bary_out`). A close pair's zones
(Jon, Nov 1, "Binary kinds: close:B") end 43 to 51 px out, 0 to 6 px past the
ring: settled on the edge a ship let go between the stars drifted into it and
was taken onto that star's close orbit (FlightTest, 5 of 30 such lets-go in
close pairs); sent out round both instead it spiralled out past a sun and was
taken there (8 of 16). A wide pair's zones end 78 px out or more (320 px
apart), its rings about 50, so it settles as it did.
The circle round both used to be any clear radius, in or out: let go between
the stars, a ship circled the empty balance point a few px across at the
pace's floor, 88 px/s, was thrown out at 45 to 63 px/s and was taken by
whichever star's or world's ring it came to, 18 of 18 times; and let go out
on the far side from star B its circle ran up to 337 px past the map's edge,
the ship pinned on the edge burning for minutes (the flight review, Oct 31).
THE PAIR AS IT STANDS AT t (ruling 23: it turns): each sun's distance and
zone measured from where that sun is then, the circle round both from the
balance point, which holds still. Settled round a sun, the centre then rides
with it (`_follow`, every step).
```

Above `func _clear_both(r: float, lo: float, hi: float) -> float:`:

```text
A CIRCLE OF RADIUS r ROUND A TWIN'S BALANCE POINT, moved off the band of
every place round both suns that can take a ship (a world's or giant's ring,
alongside a station, belt, hulk or contact: `SystemLayout.arrive_reach`, as
the arrival orbit keeps clear of them, `arrival_r`), the nearest radius from
lo to hi clear of all of them (r if there is none): let go out on the far
side, a ship pulled in to `_bary_in` was taken onto the world or giant
ringing that radius, while it was pulled in or once it had settled (seed 1999
system 309; 267 of 1,310 twin layouts put that radius inside such a ring), or
alongside a contact 22 px inside it (seed 4242 system 173, Nov 2).
```

## Place centres

Above `func center(i: int, t: float) -> Vector3:`:

```text
Where a place is at time t: a star, a world, or for a belt the point its
beacon rides; every body round its own centre (a world round star B, or round
both stars, circles there; the belt rule used to circle the origin, and 236
arrivals at a twin's belt landed more than 0.5 px off its beacon). A turning
pair's suns where the pair has them at t, and a world round one of them
carried with it (ruling 23, `SystemLayout.star_pos`, `Body.host_at`).
```

## Step and held clock

Above `func step(dt: float, t: float, k: Dictionary) -> float:`:

```text
Moves the ship on by `dt` real seconds; `t` is the system's clock now. Keys:
{w, a, s, d} as held. Returns the thrust loop's level for this frame.
A FLIGHT PLANNED ON A WORKER IS TAKEN IN AFTER THE STEP (`_poll_jobs`), with
the ship where it is at t: before it, the ride round the ring was still last
frame's, an error of |w| dt against the take-in's 0.05 rad, and every click
from a twin's world round one star at 30 fps (|w| 2 rad/s) came in stale and
was planned again (the flight review, Oct 31).
BY NO TIME (dt 0: the map's clock held for a move, `SystemMapScreen.
clock_held`; Jon, Nov 2, "Pair calls: 4A"): the ship holds, its ride, nose
and flame as they were, the keys not read and the thrust as loud, but for
a key let go (`_let_go_held`). On a ring, alongside or on its way it is
still put where that is at t: a map built ahead is held from its first
frame, and a ship put back on a ring had no place until its first step (134
px off it, CalmLadderTest chart -> map). Coasting free it already is where
it is (and `free_step` divides by dt). A flight planned on a worker is still
taken in.
```

Above `func _let_go_held(k: Dictionary, lvl0: float) -> void:`:

```text
A KEY LET GO WHILE THE SHIP HOLDS goes quiet at once, as it always did
(review of "Pair calls: 4A"): W held into a move and let go in it kept the
burn roaring and the flame lit to the move's end, up to 2 s. A key pressed
in the hold still starts nothing, as the ship does not move for it. Coasting
free, the level and the flame are those of the keys still held of the ones
that made them; anywhere else, once none is, the ship's own keyless level
at the held clock (`lvl0`: a flight's burn, a settle onto its place). The
level of no keys (a settle's burn coasting free, a flight's) is held as it
was, with the picture.
```

## Capture rules

Inside `_step_mode()`, above `if not (f.r_want > 0.0 and f.coast > SETTLE_TURN) and capture_ahead(f, t):`:

```text
OPEN SPACE: a step
WHETHER THE COAST IS GOING INTO A RING anyway, held half a second. Not
once the settle's own burn is bringing the ship onto a radius it chose
(`_settle_centre`'s r_want, past the band of the world round that sun):
that motion is the settle's, not where the ship was let go toward, and
taking it for an aim stopped the settle half way and coasted the ship
on into the world it was being kept clear of. Let go 3 to 25 px off a
wide pair's balance point, a ship pulled 50 px in onto star A's circle
was taken by the world round A, 3 of 30 with the pair at the angles it
turns to by the moments FlightTest flies at (none at the angle it was
laid out at, which only happened to keep that world off the line)
```

Inside `free_step()`, above `var take := {}`:

```text
A RING THAT TAKES YOU (Jon's twins put 30% of the worlds round both stars
inside another's ring, 29% inside the giant's; one star 13%): of every ring
that holds a slow ship -- a world's, a star's close one, alongside a
station, belt, hulk or contact -- the one the line shows you going into
(`stick`), else the nearest. It took the first world by index, so letting
go by a hulk near the giant put you on the giant. A ring crossed too fast
is said only when none takes you.
```

Above `func _star_takes(s: int, v: Vector2, rh: Vector2) -> bool:`:

```text
WHETHER STAR s'S CLOSE RING CAN TAKE A SHIP moving v at rh (the way out from
the star): one star, always; a twin's only coming in at up to STAR_IN_V, which
its insertion can turn in the 4 px between its ring and its keep-out. Faster
in, its bumper turns it first. Taken at 150 px/s straight in, the insertion
dipped to about 31 px from a sun whose keep-out is 47 (the flight review).
```

## Arrival burn

Above `const ARRIVE_MIN := 0.5`:

```text
WHEN A SOLVED FLIGHT TURNS ONTO ITS PLACE: its arrival burn (onto the ring at
its speed, or to the spot alongside), never less than ARRIVE_MIN of its end,
so a flight arriving at nearly the ring's own speed still shows, and is
counted, burning onto the orbit; and never more than the longest insertion
(INSERT_T), so the ship counts as at the place (`orbit_body`, and from it
LOCAL, the station and a ship parked on a Tab) only where an insertion had
it. The whole arrival burn had a twin's ship there up to 338 px off its ring
and 9.7 s before it ended (the flight review, Oct 31). A flight on its own
clock is held to them there and played pace times faster: on the map an
eighth of them at pace 8. Held on the map's clock, the ship counted as at the
place for 0.5 s of a 1.5 s flight, up to 140 px off, and at pace 10 its
arrival began 0.13 s after it left (the code review, Nov 5).
```

## Insertion curve

Above `func _plan_insert(p0: Vector2, v0: Vector2, rt: float, w: float, b: SystemLayout.Body, acc0 := Vector2.ZERO, star := -1) -> void:`:

```text
THE INSERTION'S CURVE in the world's frame: from `p0` moving `v0` (no burn
yet) to the circle of radius `rt` at angular rate `w`, arriving with the
circle's own velocity and pull. Its length by distance and speed; its end
angle a sweep on from where it starts, the approach's own turning and the
orbit's averaged. Kept clear of the world's disc: shorter, then longer, until
its closest is outside it.
```

Above `static func _polar_ins(p0: Vector2, v0: Vector2, acc0: Vector2, rt: float, w: float, T: float, a1: float) -> Dictionary:`:

```text
AN INSERTION IN POLAR TERMS round the place (Jon: "why are there sharp
angles on some of the trajectories?"): its angle and its radius each a
quintic from the approach -- where it is, how it moves, its pull -- to the
circle at angle a1. As a curve in x and y, an approach coming in nearly
head-on had to turn so hard it drew a hairpin; round the place it spirals in,
its angle never turning back.
```

## Rail restore

Above `func rail_back(body: int, rel: Vector2, dir: float, t: float) -> void:`:

```text
PUT BACK ON ITS RING WHERE IT RODE: `rel` the offset from the place's centre
it was kept at, `dir` the way it rode (+1 or -1), on its ring at its speed,
so no insertion. With the map's clock kept the suns and worlds come back
where they were, and a ship put at +x of its place (`place_at`) alone jumped
across its world or sun on a Tab back (review 2). Alongside, or with no
offset to go by, as `place_at`.
```

## Arrival orbit

Above `func arrival_r(r0: float) -> float:`:

```text
THE STAR ORBIT A SHIP ARRIVES ON: radius r0 if every place's ring is well
clear of it (a world's, a station's or belt's reach), else the nearest radius
that is -- outward first, never past the edge, then inward. Round the star,
or in a twin round both stars' balance point: there each body's circle is
round its own host, so what it sweeps is a band of distances from the
balance point (a world round one star, from that star's distance less its
orbit to more), and each star's ring is kept clear too. How far from each
body's orbit is the layout's (`SystemLayout.arrive_reach`), which leaves a
close pair room for it past its worlds.
```

## Free step

Above `func free_step(st: FreeState, k: Dictionary, t: float, dt: float, stick: int, real: bool, cs := PackedVector3Array()) -> Dictionary:`:

```text
ONE STEP OF OPEN-SPACE FLIGHT, for the ship and for its line alike, so the
line can only show what the ship will do. Returns a capture (&"rail",
&"keep"), a ring crossed too fast (&"fast"), or {}.
`cs`: every place's centre at `t` (`center`), when the caller has them
(`_centres`); empty, each is worked out here.
```

## Twin bumper

Inside `free_step()`, above `kk = clampf((bm - r) / maxf(bm - _s_keep[si], 1.0), 0.0, 1.0)`:

```text
A TWIN'S BUMPER IS 12 PX DEEP (a world round its star may ring it
that close): it turns the ship from nothing at its edge to all of it
by the keep-out, hard enough to turn VMAX in that, and the ship is
held there. Ramped over the whole bumper as one star's is, W held at
a sun drove the ship 18 to 22 px into a 41 to 44 px drawn sun (the
flight review, Oct 31)
```

## Map edge

Inside `free_step()`, above `var rr := st.p.length()`:

```text
THE MAP'S EDGE, round the origin: the circle the layout measures the edge
on (`SystemLayout._past_the_edge`, from star A's place at t 0) and the
fabric is drawn out to. It stays there as the pair turns: the balance
point holds still, and every circle round it and round each sun stays
inside this one at every angle of the pair (the layout's promise), so a
circle round the balance point, the arrival orbit (`arrival_r`) and the
widest settle (`_bary_in`) among them, is clear of it at every t. Round
the balance point, as the review of the plan asked, the ship would either
stop short of the drawn edge on one side by up to twice the balance
point's distance from star A (about 300 px in a wide pair), or fly past it
on the other.
```

## Centre table

Above `var _ctab: Array = []`:

```text
THE PLACES BOTH LINES STEP PAST, worked out once a frame (`predict`): the line
and the held line step through the same moments, and each step looked up every
world's centre twice and every station's, belt's and hulk's once more -- about
6,800 calls a frame for one answer per place a step. Step i: [its t, every
place's centre then]; a step is taken from here only at the very t it was
worked out for. (`centre_table` off: each worked out where it is needed, as
before, for `-- sheet=MapPerfTest` to hold the two lines to each other.)
```

## Flight choice

Above `func heading_to() -> int:`:

```text
A FLIGHT TO PLACE i: the first manoeuvre that is clean -- direct, then round
a waypoint -- trying coasts of different lengths and both sides of the ring;
strictly first (under 1,200 px/s and 5,000 px/s²), then only clear. If none
is, the least bad, marked `unclean` (the measure counts them: none so far).
WHETHER A FLIGHT CAN START NOW (Jon: "You have to be IN AN ORBIT ... AND
THEN CLICK to go to another planet"): settled in an orbit -- round a world,
alongside a station, belt or contact, round the star close in, or on the
star orbit a ship coasts onto. Not mid-flight, not burning onto an orbit, not
under thrust or still settling.
The place a flight under way is taking the ship to (riding round to leave,
flying, or burning onto its orbit), or -9.
```

Above `func make_plan(i: int, t: float, prefer: Dictionary = {}, ahead := 0.0) -> FlightPlan:`:

```text
THE FLIGHT TO PLACE i FROM WHERE THE SHIP IS, at map time t, on this thread:
solved (`FlightSolve`), `prefer` the choice of the flight drawn so the same
flight comes back while it can (in a twin, in two legs where one reaches
nothing: `FlightSolve._chain`); when nothing is clean (under 1% of plans),
today's planner (`_old_plan`; in a twin only its near hop, `_twin_near`);
null when neither finds one.
`ahead`: made for that moment on, as a worker's is (`PLAN_AHEAD`).
```

## Departure state

Above `func _dep_of(t: float, ahead := 0.0) -> Dictionary:`:

```text
WHAT A FLIGHT LEAVES FROM, as `FlightSolve` takes it: riding a world's ring
or a star's close orbit (its rail, as ridden), settled on a star orbit (a
circle round a fixed centre, at its settled radius), alongside a place (where
the ship comes to rest there), or free. {} when the ship is in no state to
plan from (flying, burning onto an orbit, riding round to leave).
`ahead` s on: where the ship will be on its ring then (a plan made on a
worker is made for a moment just ahead, PLAN_AHEAD, so its departure is still
to come when it is taken in); free, only now.
```

Inside `_dep_of()`, above `if L.twin and SystemLayout.is_star(f.cen_id):`:

```text
ROUND ONE SUN OF A PAIR, which sun (`host`, the place id): the
planner rides the circle round that sun where it is at each
moment (FlightSolve's -9 with a host, as its star's close orbit
rides it), `c` then where the sun is at the plan's moment (a
circle round a fixed point there is right at that moment, and only
a sun's own motion, about 1 px/s, off it after). The balance point
and one sun hold still: no host, a fixed centre as before
```

## Plan lead time

Above `const PLAN_AHEAD := 0.25`:

```text
HOW FAR AHEAD A PLAN MADE ON A WORKER IS MADE FOR (s): the worker's plan
(a twin's worst about 140 ms, a median of 40) and the frame that takes it in
are over by then, so the flight it plans has not yet left. Made for now, a
flight leaving at once was gone by the time it came in.
```

Above `const PREVIEW_AHEAD := 1.0`:

```text
A PREVIEW IS MADE FOR A MOMENT FURTHER AHEAD (s): a flight whose ride must
phase can only be flown from where the ship is while it can still phase
within THRUST, and planned 0.25 s ahead the drawn one stopped being that
about a quarter second after, so the overlay planned it again about four
times a second (FlightTest, Oct 31); planned this far ahead it holds for
about this long. A click on it flies it as drawn; a click with none drawn
plans PLAN_AHEAD on.
```

## Planning on workers

Above `const LINE_N := 1600`:

```text
THE LINE THE MAP DRAWS A FLIGHT AS, laid out on the worker that plans it
(`lay_out`, `SystemOverlay.PV_N`): a click's own plan too, so the frame the
flight starts in does not lay it out (3 to 8 ms on this thread, the flight
review's timing, Oct 31) when no preview was drawn to fly
```

Above `func plan_bg(i: int, t: float, prefer: Dictionary, use: StringName, lay := 0) -> bool:`:

```text
A PLAN FOR PLACE i MADE ON A WORKER (`FlightSolve` touches no Node: pure
arrays, `MapGravity` read only, its inputs copied), from the ship as it is
at t, for a moment just ahead. When nothing is solved, today's planner there
too (in a twin only its near hop, `_twin_near`), from a snapshot of the ship
as it will be then (`_snapshot`): it ran here, in the frame that took the plan in, for 60
to 275 ms (the flight review, Oct 31), and every 2 s again while such a
place stayed selected. `lay` > 0: the line laid out there too, to that many
points (`lay_out`), so the frame that takes it in does not (3 to 8 ms).
False when one for this use is already being made, or the ship is in no
state to plan from.
```

Above `static func lay_out(pl: FlightPlan, n: int) -> Array:`:

```text
A WHOLE FLIGHT LAID OUT ALONG ITS LENGTH, as the map draws it
(`SystemOverlay._plan_line`): n points at even distances along it (its
samples, then the stretch drawn after), whether the engine burns at each,
and how far through the flight each is (u). Pure arrays, so the worker that
made the plan lays it out (`plan_bg`): on the map's thread it took 3 to 8 ms
a plan (the flight review, Oct 31).
```

## Old planner

Above `func _fallback(i: int, t: float, prefer: Dictionary) -> FlightPlan:`:

```text
NOTHING CLEAN SOLVED: today's planner, from the same state, in a system of
one star; null when that finds nothing either, and the caller puts the ship
in orbit there. Never in a twin: its coasts are Lambert conics round star A
alone, and there, failing, it ran up to 1.15 s on this thread (FlightTest,
Oct 31) for flights that were then thrown out for crossing star B.
```

Above `func _twin_near(i: int, t: float, prefer: Dictionary) -> FlightPlan:`:

```text
IN A TWIN, NOTHING SOLVED IN ONE LEG OR TWO, FOR A SHIP CLOSE BY A WORLD AND
NOT IN AN ORBIT: today's near hop (`_near_hop`, a short hop in the world's
own frame, which DESIGN lets stay kinematic), as a system of one star's
fallback starts. Coasting at up to 170 px/s a few px outside a keep-out (a
harness's start: the map flies only out of an orbit), no burn at THRUST
keeps its coast clear for even half a second, so no solved flight can leave
from there (FlightTest's twin near starts, Oct 31: 26 of 32 that one leg
missed, two legs too). Never today's conics round star A alone: null.
```

## Plan reuse

Above `func _takeable(pl: FlightPlan, t: float) -> Dictionary:`:

```text
A FLIGHT PLAN STILL GOOD TO FLY NOW, from where the ship is: a solved one
while its departure is still ahead and the ship is where it was planned from
-- on the same ring (its ride round to the point then phasing within THRUST,
as `FlightSolve._replay` holds it), alongside the same spot, on the same star
orbit, or free at the very moment and state; today's planner's the same way
when it was made ahead (`ahead`, on a worker), else only at the moment it was
made. {} when it is not; else the ride {T, k, a0, w}.
```

Inside `_takeable()`, above `var same_c: bool = (f.cen_id == int(d.host)) if d.has("host") else (f.cen == (d.c as Vector2))`:

```text
(round the same centre: round a sun of a pair by which sun it is
(`_dep_of`'s host), since a turning one is somewhere else every
frame and the preview round it was thrown out and planned again
each one; round the balance point or one sun, the very point. The
ride is then measured round the centre where it is now, in its
own frame, as the plan's departure angle is)
```

## Star orbit ride

Above `func _with_ride(pl: FlightPlan, rd: Dictionary, t: float) -> FlightPlan:`:

```text
THE RIDE ROUND A SETTLED STAR ORBIT TO A SOLVED FLIGHT'S DEPARTURE, as the
flight's first samples (`_step_phase`'s law, round the fixed centre): from
where the ship is, eased onto the circle it was planned on, phasing by k, to
the departure exactly, then the flight. Its samples sit on the flight's own
time grid (from SAMPLE steps back from its departure), so the flight itself
is not resampled.
```

## Hand over

Above `func hand_over() -> Dictionary:`:

```text
THE ERRAND OF A FLIGHT UNDER WAY, handed to the ship that replaces this one
as the map is drawn again round it (`SystemMapScreen.show_system`: another
rendering style, GRAPHICS LOW): {to, done, prefer}, where it is going, what
is to happen there (a GO's event, DOCK, ENGAGE, the place opened) and the
choice it was planned with. This ship never calls `done` after. Empty when
nothing is on its way, or the flight was let go of (W off the ring or the
burn drops its callback).
```

## Freed mid-plan

Above `func _notification(what: int) -> void:`:

```text
FREED MID-PLAN (the map left, another system shown): its tasks are reaped as
they finish, not waited for. It waited, which held the frame for what was
left of the plan, up to about 140 ms in a twin (the flight review, Oct 31);
a task holds only copies and its own snapshot of the ship (`_snapshot`), so
it can outlive the ship. (A ship with none, a snapshot freed on a worker
among them, touches nothing shared.)
```

## Quit crash

Above `static func drain() -> void:`:

```text
EVERY TASK STILL OUT, WAITED FOR, as the game quits (`Router`: the window's
close, and its own PREDELETE, which comes after every screen's): a ship's
plans as well as the ones let go of. A task never waited for kept its lambda
until the engine's own cleanup freed it, after GDScript had shut down, and
that crashed the quit (signal 11, exit 134): the scroll check 3 of 3 times
with a plan out, and a window closed on a map with a place selected
(previews are planned again every second) some of the time (Oct 31). A plan
is bounded: each search in it stops at its own budget of integrations
(`FlightSolve.BUDGET`, `BUDGET_WIDE`). At C (ruling 21) a plan that runs C's
own search, the as-built one and the wider one (a fresh plan, a preview of
the fallback's flight planned again, rebuilt as drawn too, or a preview in
two legs planned again, which runs a fresh plan, of one leg and else of two,
beside its own legs, or one of one leg that took over from two, its old
legs beside it),
or flies in two legs, takes up to about 750 ms in a twin (the study on the Mac, one Godot at
a time: 734 to 768 ms, where the as-built search alone took 503 to 510); on
the Windows PC (Nov 1), with other Godots running beside it, 0.48 to 1.3 s.
A preview in two legs planned again, a fresh plan in two legs beside it as
well (the fifth review, Nov 1), a median of 433 ms, at most 625 (905
integrations), with no other Godot running, where beside one leg alone it
took 316 and 636 (782); one of one
leg that took over from two, its old legs beside it, a median of 177 ms, at
most 414 (849 integrations), with two others. A
task waited for here is let go of by whoever held it (`_done`, `_wait`).
```

## Click to fly

Above `func fly_bg(i: int, t: float, done: Callable, prefer: Dictionary = {}, pv: FlightPlan = null) -> bool:`:

```text
THE CLICK (`SystemMapScreen._fly`): the flight to place i, the one drawn
(`pv`, the preview, flown as it is while its departure is ahead), else one
asked for on a worker -- the preview's own if it is being made for this
place now -- and flown the frame it comes in, the ship going on as it was
meanwhile. `done` once it is on the orbit (or alongside); if nothing can be
planned, the ship is put there. False when no flight can start now.
```

## Harness placement

Above `func settle_at(t: float, p: Vector2, sense := 1.0) -> void:`:

```text
A SHIP PUT ON A SETTLED STAR ORBIT AT p AT MAP TIME t (a harness): round
what letting go there then settles round (`_settle_centre`: a turning pair's
suns where they are at t), at its radius, its pace, the way `sense` says, as
if it had settled there, moving with its centre round a sun of a turning
pair. t comes first and has no default, so a call from before the pair
turned fails rather than settling round where a sun was at t 0.
```

## Restore free

Above `func restore_free(t: float, p: Vector2, v: Vector2, head: float, cen_id := -99, r := -1.0, sense := 0.0) -> void:`:

```text
A SHIP PUT BACK IN OPEN SPACE (`SystemMapScreen._restore_ship`, a Tab back
from LOCAL, another rendering style, a save loaded): where it was, and on
the wide orbit it was settled on where the record says which (round
`cen_id` -- -1 star A, the star; `SystemLayout.STAR_B`; -9 both suns -- at
`orbit_r`, the way `sense` goes) and this system still has that centre;
else coasting on from there at `v`, to settle again from where it is. Put
back with only its point, it kept the arrival orbit `setup` had just made,
whose radius (round the balance point in a twin) it was then pulled onto
round its own star: settled round star B at 69 px, back on a 318 px circle
that ran through star A's keep-out, and every flight from there planned off
that circle, up to 818 px from the ship (the seams and saves reviews, Oct
31; one sun the same, r 300 back at 223).
AT MAP TIME t (ruling 23: the pair turns), the map's clock as it shows the
system again (`Run.map_clock`, kept with the ship, so p means what it meant):
round a sun, round where that sun is then, and following it after
(`_follow`). Put back round a sun of a turning pair it is put on its circle
round where that sun is, on the line from the sun to where it was: a clock
that ran on without the ship (a map built ahead and dropped, `ZoomLadder`)
had moved the sun on up to about 1 px a second, and the ship would have come
back off its orbit by that much. t comes first, with no default, so a call
from before the pair turned fails.
```

## Escape point

Inside `_escape()`, above `if SystemLayout.is_place(int(st.body)):`:

```text
FROM THE BEST POINT ON THE RING for this place, not from wherever the ship
is (Jon: "the predictive path updates every time the ship rotates around
the planet"): leaving along the way the transfer goes (out of the star's
close orbit, three tenths of a lap short of the place), the escape a sweep
round the ring before that, spiralling out; the ship rides round to it
first. Angle and radius each a quintic, so it starts with the orbit's own
motion and pull.
```

## Approach side

Inside `_manoeuvre()`, above `var side_eff := side`:

```text
WHICH SIDE OF THE WORLD, AND SO WHICH WAY ROUND IT (Jon: "why is this
happening sometimes ... it's weirdly shaped"): the side that keeps the
coast's own turn going -- the world on the inside of the bend it is
already making, so the insertion carries the curve on round instead of
overshooting and hooking back the other way. Side 1 is that side, -1
the other; a coast that hardly bends keeps the plain order.
```

## Hohmann transfer

Above `func _hohmann(p: Vector3, sense: float, ra: float, T: float) -> Dictionary:`:

```text
A HOHMANN HALF-ELLIPSE round the star from p (Jon: "going to the star's
close orbit from the star orbit should be the most textbook manoeuvre in the
game"): an apsis where it starts, along the ship's own way round (`sense`),
the other half a lap on at radius `ra` -- tangent at both ends, so one burn
onto it, the coast speeding up (or slowing) as it falls in (or climbs), one
burn off it. In the shape `_lam` gives, shown over T.
```

Above `func _star_transfer(i: int, t: float, st: Dictionary, prefer: Dictionary) -> FlightPlan:`:

```text
OUT OF THE STAR ORBIT TO WORLD i: the ship rides round its orbit to the
departure point (a phasing burn speeds it there when that is far, as out of
a world's orbit: `_lead`), then a coast that leaves along the orbit, tangent,
across half a lap to the world -- a Hohmann half-ellipse. The departure is
chosen once and kept (`prefer` carries its place and time), so the drawn plan
holds its shape while the ship rides round to it; the ride is the plan's own
first stretch. Null when no clean one is found.
```

## Near hop

Above `func _near_hop(i: int, t: float, st: Dictionary, pick: Dictionary = {}) -> FlightPlan:`:

```text
THE SHORT HOP TO A WORLD ALREADY CLOSE (within a little over two of its
rings): in the world's own frame, from where the ship is and how it moves to
a point on the ring a little round from it, along the ring -- angle and
radius each a quintic, so it curves in one way -- and the insertion from
there. The gentlest of its tries that keeps off the world and the star; null
if none (or the place is not that close).
```

## Plan tail

Inside `_tail()`, above `if pl.res != null:`:

```text
A SOLVED FLIGHT COMES TO REST ALONGSIDE in its own samples: the line ends
there. The second it then holds alongside, drawn on, was half a px of the
place's own crawl off at an angle to the way it came in, a corner of 53 to
86 deg a px at zoom 2 (FlightTest, Oct 31: 3 of the one-star system's 10
from the game's starts)
```

## Unclean score

Above `func _clearance(pl: FlightPlan, st: Dictionary, i: int) -> float:`:

```text
HOW BAD an unclean plan is, as a score (higher is better): how clear it
keeps of the star's disc and every world's (the least, in px, counted up to
20; the ring it leaves and the one it comes to excepted as `_clean` does),
less a penalty for speed over 1,200 px/s and pull over 5,000 px/s² -- so the
one flown neither cuts a disc nor jumps. (One sun only, at the origin, as
`_clean` reads it.)
```

## Click on a late preview

Above `const CLICK_LATE := 0.45`:

```text
THE DRAWN FLIGHT LEAVING LATE (a fast flight's: on its own clock, pace > 1;
today's, at pace 1, as it was): a click on a preview that leaves more than
CLICK_LATE s on plans a fresh flight from the click, PLAN_AHEAD on, as a
click with none drawn does, and flies it when it arrives CLICK_GAIN s
sooner (the line drawn again at the click); else the drawn one. Planned 1 s
ahead and kept until its departure is PLAN_AHEAD off, a preview left 0.25 to
1 s after the click plus its ride: in a 2.95 s flight 1.18 s of it was the
wait (the code review, Nov 5).
```

## Said path

Above `func said_path(t0: float, dt: float) -> Array:`:

```text
THE FLIGHT UNDER WAY AS IT WILL BE FLOWN from map time t0, a point every dt
s (a partner is told it, PROTOCOL 17, `SystemMapScreen._report_flight`):
the ride round its ring to its departure (or the hold alongside), the flight
itself, and onto its ring after (`_tail`, the spin-down, TAIL_S of it) when
a solved flight lands on it. [pts (plane), lit, dep_s, arr_s (s from t0 to
its departure and its arrival)], or [] when nothing is under way.
```

## W during a spin-up

Inside `_step_rail()`, above `var ph: Dictionary = rail.phase`:

```text
W: the flight is off; leave the orbit as W always does -- from the
ring's own rate: a fast flight's ride, spinning up (`ke`), is spun
down to it first, over SPIN_S, from the rate it has
(`_spin_down`), and W takes it off after. Let go at once, a
whirl at up to 280 px/s dropped to the ring's 35 in a frame (the
code review, Nov 5)
```

## Ride shape

Above `static func _ride_shape(dang: float, w: float, T: float, ke: float) -> Dictionary:`:

```text
THE RIDE'S SHAPE round to a fast flight's departure, dang radians in T s
at the ring's rate w (> 0) and leaving at ke times it: the solver had the
ship ride at the ring's own rate until the moment it was planned for
(`ahead`, `_dep_of`) and at the departure's after (`FlightSolve.dep_tau`),
and the ship rides its ring at its own until the click. So it rides at w,
spins up over `sp` s (smoothstep, SPIN_UP at the most) and rides on at
ke w, the spin starting `ls` s before it leaves: the angle w T + (ke - 1) w
(ls - sp / 2). ls is chosen so that is dang with no phasing; past the ride's
own length, or short of a spin, a phasing k makes up the rest. Returns the
ride's dictionary entries {k, ke, ls, sp}. ke 1: the phasing k alone.
```

## Ride flyable

Above `static func _ride_flyable(rd: Dictionary, pk: float, vr: float) -> bool:`:

```text
WHETHER A RIDE rd ROUND A RING (its speed vr px/s) CAN BE FLOWN for a flight
at pace pk: its push within THRUST (VMAX with the same slack: a plan whose
ride the solver held to exactly VMAX read as over it by a rounding. A flight
on its own clock held its ride to THRUST and VMAX there: on the map, pace^2
and pace of them; the spin-up's push beside the phasing's, SPIN_PUSH_K), and
its phasing k no less than `FlightSolve.RIDE_K_MIN` (under nought the ship
would run backwards round its ring).
```

## Spin up and down

Above `const SPIN_S := 0.3`:

```text
SPIN-UP AND SPIN-DOWN ROUND A RING (`FlightSolve.RING_TAU`): a fast flight
leaves its ring at `ke` times the ring's own speed (pace times its speed on
the flight's clock), reached as the ship rides round to leave
(`_ride_shape`), and arrives on its target ring that much faster, eased
down to the ring's own speed over SPIN_S (`start_rail`'s spin,
`_step_rail`).
```

## Look aids

Above `const FLAME_MIN := 0.25`:

```text
THE LOOK AIDS while a fast flight plays (CURVED's burns at pace 8 last a
tenth of a second, three frames): the flame fades out over FLAME_MIN s
after a burn, the nose held on the burn's way while it does; and the nose
turns no faster than NOSE_RATE (rad/s) from the ride before a fast flight
until NOSE_SLOW_S after it lands. Today's flights turn it at about 260
deg/s at the most; a fast flight's spring turned it at up to 1,200, and an
arrival and its spin-down flipped it 455 deg in 1.2 s, a tumble (the look
review, Nov 5). A nose lead (it started onto a burn 0.3 s before it lit,
as first built) read as a skid, the ship turned broadside unpowered: gone.
`-- lookaids=0` turns them off (a film's comparison).
```

## Flight pace

Above `const FLIGHT_PACE := {&"direct": 4.0, &"curved": 12.0}`:

```text
THE FAST TRANSFERS (Jon, Nov 4-5): each solved flight is planned on its own
clock, this many times faster than the map's (`FlightSolve.solve`'s pace),
for the AUTOPILOT setting's path (`DisplaySettings.autopilot`): DIRECT,
ruling 21's C at 4 (about 11 s of the flight's clock in about 2.8 s), and
CURVED, the as-built search with its arc, at 8 (Jon, Nov 5: "Lets do 4X
for both", then Nov 7, with WIDE picked: "Let's double the speed for the
wide, so it matches the direct better"). Its shape is the flight's clock's:
the arc's dials are in tau, so x8 flies WIDE's bend in half x4's seconds
(CaseScan, six seeds, 504 one-sun flights: bend median 0.400 at x4, 0.394
at x8; turned past 240 deg 7.3 / 7.9%; seconds median 12.1 / 6.0). The
x8 that flew flat on Nov 5 (bend 0.06) was before the arc had its reward.
Then x12 (Jon, Nov 7, "3B": faster still): CaseScan at SPIN_UP 0.3, bend
median 0.394 at x8, 0.365 at x12, under 0.1 on 40 / 49 of 504, seconds
median 6.0 / 3.9; FlightTest click to settled median 4.97 / 3.32 s.
The ship's own parked
ring and its ride round it stay at the map's RAIL_V and STAR_RAIL_V. A
harness's `-- flight_pace=K` sets the pace for either path; `-- autopilot=
direct|curved` the path.
```
