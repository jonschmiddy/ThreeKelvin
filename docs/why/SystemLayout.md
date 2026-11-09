The reasoning behind `tkg/scripts/systems/SystemLayout.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Layout rules

Above `const HI := 900.0`:

```text
WHAT IS IN A SYSTEM, AND WHERE: its star, the bodies going round it, and
which body each of the system's options sits on.

DERIVED, NEVER SAVED. Everything here comes from `Rng.derive(&"system",
n.index)` and the node's own facts, so the same system lays out the same way
every time it is asked, on every machine, with nothing in the save -- the way
`_roll_foes` needs no save. The option list, the claim ids (`OPTION_SITE + i`)
and the results are untouched: this only says where on the map each option is
drawn.

Ported from the approved system-map mockup (`layout()` in the scratchpad's
`sysmap/template.html`), rule for rule:

- one body for every option, chosen by its tags: a fight with nothing to
  salvage is a CONTACT in open space; salvage and hazard together, or hazard
  alone, is a BELT (one belt holds all of them); salvage alone is a DERELICT
  or a belt; anything else -- a contract, a signal, fauna -- is a PLANET;
- a gas giant if and only if the node has one (never round a pulsar);
- a station's station as a body of its own, with DOCK on it;
- about a third of the systems with no belt get one anyway, as scenery, and
  a pulsar or the core always does;
- ONE EVENT TO A WORLD (Jon, Oct 15: "A planet should only hold one event.
  That should be a rule."): every option that wants a planet gets its own,
  and the giant and the star each hold one at most -- a second that wanted
  them takes its place by its tags. A place is where a fight leaves its
  wrecks (`Jetsam.site`), so one event to a place is one fight's wrecks to a
  place. A belt still holds every option that wanted a belt;
- no padding: one body is always there, and a system has as many more as
  its options, its giant, its station and its belt make -- one, two or three
  is normal (Jon: "I like the diversity and scarcity");
- the core's custodian as a contact on the outermost orbit;
- the Hellbender, while it is anchored here or its wreck lies here, as a
  contact of its own past every orbit, added last so no other body moves
  (Jon, Oct 15: the system's contact at a place of its own, so you fly there
  to fight it and its wrecks are its own);
- at about one ordinary system in four, TWO SUNS (ruling 20), of two kinds
  (Jon, Nov 1, "Binary kinds: close:B share:A"): two in three a WIDE PAIR, a
  world round each sun and everything else round both (`_twin`); one in
  three a CLOSE PAIR, every body round both (`_close`).

Orbits are spread from just outside the star (further out round a red giant
and the black hole) to `HI`; periods follow Kepler, the square of the period
going as the cube of the orbit, so the inner bodies go round faster.
```

## Ship gravity

Above `const GM_KEPLER := 61.685`:

```text
THE PULL A SHIP FEELS, on map time (Phase 13, ruled Oct 29 "clock:map", and
ruling 20, Oct 30): a system's whole star mass pulls a ship with this GM
(px^3/s^2), whatever its kind. It is KAPPA times the Kepler GM that turned the
worlds at a pace of 1 (GM_KEPLER: a world 100 px out lapped in 800 s; at
`WORLD_PACE` they go round faster, in `kepler_s`), because on map time a
ship flies about a hundred times faster than the worlds move. A ship riding
170 px out at RAIL_V 35 px/s is on a circular orbit under it. Only autopilot
flights feel it; flying by hand has no gravity (Jon, Oct 3).
```

## Two suns

Above `const TWIN_SHARE_LO := 0.52`:

```text
TWO SUNS: THE NUMBERS (ruling 20, Oct 30; `of` lays them out, `_twin`).
Star A's share of the pair's mass, rolled. The build asked 0.52 to 0.65. The
higher the share, the smaller star B's steady zone (0.255 of the separation
at 0.55, 0.243 at 0.58, 0.236 at 0.60, 0.217 at 0.65), and its world has to
stand clear of B's drawn sun at the opening zoom, which spreading the pair
lowers in turn: near 0.60 the two almost keep pace, and a pair runs away.
Measured in a model of this fit on the 1,633 twins of eight seeds (layout
review, Oct 30): capped at 0.60, 5% of pairs went past 380 px, the widest to
564 px and an opening zoom of 0.158; at 0.59, 1% and 435 px; at 0.58, none
past 380 and the least zoom 0.229.
```

Above `const TWIN_SEP_LO := 320.0`:

```text
How far apart the two stars are, rolled (px). A pair whose worlds would not
fit is moved further apart until they do (`_twin`): about a third of them in
a model of the fit, and none past 380 in 24 seeds' 5,014 twins (Oct 30).
```

Above `const P_LIMIT := 2.423`:

```text
THE NEAREST STEADY ORBIT ROUND BOTH, as a share of the separation from the
balance point (`p_limit`): Holman and Wiegert's circumbinary limit for
circular orbits, HW_P0 + HW_P1 mu - HW_P2 mu^2 with mu star B's share, and
never under the build's 2.423. The formula peaks at 2.434 at mu 0.40 (star A
at 0.60) and is 2.405 at mu 0.48, so 2.423 alone sat inside it for star A
above about 0.555 (layout review, Oct 30). The first world round both goes a
few percent past it.
```

Above `var twin: bool = false`:

```text
TWO STARS (ruling 20, Oct 30). Star A is `star`, at the origin at map time
0 as the one star always was; star B at `star2_at0` then. THE PAIR TURNS
(ruling 23, Jon, Nov 1, "Orbiting pair: after4:D speed:A stacked:A"): both
suns circle the balance point, which holds still, so where either is at t is
`star_pos(p, t)`. Off (`twin` false) every field here keeps its one-star
value and nothing changes.
```

## Close pair

Above `const CLOSE_SHARE := 1.0 / 3.0`:

```text
THE CLOSE PAIR (Jon, Nov 1, "Binary kinds: close:B share:A", from the
binary-kinds sheet): one binary in three, rolled off a stream of its own
(`is_close`), so a wide pair keeps every draw it makes today. Its suns are
rolled 150 to 170 px apart (the sheet's B), off the "twin" stream's
separation draw, and every body goes round both (`_close`). At B, on the 55
binaries of seed 7: the two suns 19 to 33 game px apart edge to edge at the
opening zoom (A's 90 to 110 touched and read as one sun); a hot world first
in all but 2; 43 of 55 with a world in the middle band (C's 230 to 250 had
no hot world at all); each sun's close orbit as a wide pair's. Over
SystemTest's 343 close pairs the two keep-outs stay 64 px apart or more, a
sun's close orbit 62 px off the other's keep-out, the capture rings 56 apart
(70, 68 and 62 before a close pair kept room to arrive in, `_close`).
```

Inside `_past_the_edge()`, above `if least > 0.0:`:

```text
A CLOSE PAIR'S ROOM TO ARRIVE IN (`_close`) past what was put out here too:
`least` counts only the bodies laid out before the jobs and the Hellbender,
so with the Hellbender out past them the edge stopped short of a circle
clear of it, and a ship jumping in was put inside the first world beside
the suns (seed 1999's THETA ABYSSAL MINOR, every system two suns, once
stations were halved on Nov 3: at 322 px, where the clear circle is 1000)
```

Above `static func _close(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator, jobs: Array[int]) -> void:`:

```text
A CLOSE PAIR (Jon, Nov 1, "Binary kinds: close:B"). Star A at the origin
and star B `sep` from it at map time 0, 150 to 170 px (`CLOSE_SEP_LO`),
a little smaller, as in a wide pair. Every body goes round both (P-type),
circling the balance point past the nearest steady orbit round the pair, and
none round one sun: round one, the steady orbits end 43 to 51 px out, inside
its close orbit's ring. The real close pairs Kepler-16 and Kepler-47 have
this shape, planets round both suns.

LAID OUT AS ROUND ONE SUN (`of`'s rules): by ratio from that first steady
orbit (`p_limit`, P_MARGIN past it; never nearer than a one-sun system's
first, which it always is past) out to HI, each body at least as far from the
last as the two could be wide (`_reach_most`: their worlds are rolled after,
by their light), and each world's ring RING_GAP clear of both suns' close-
orbit rings. Zones by light (`zone_of`), as a wide pair's: the middle band is
about 490 to 830 px out, so the first body is hot in all but 2 of seed 7's 55
close pairs and 43 of them have a planet in the middle band, where a city, a
green world or an ocean can be. THE COST (the sheet's): the bodies are packed
between about 440 and 900 px, not 243 to 900, so a world's ring holds a
neighbour about twice as often as round one sun; the bodies never meet.

Each sun keeps its keep-out, close orbit and ring, a wide pair's ladder
(`_twin_ladder`) at the zoom this layout is fitted to (`fit_zoom`), which
takes in the room past the worlds a ship arrives in: at 150 px apart the two
keep-outs, and each sun's close orbit and the other's keep-out, are 62 px or
more apart.

Draws: `_twin`'s, in its order: the "twin" stream's share, separation, side
and turn; R's three a body (where in its slot, its period's jitter, its
phase); then its world.
```

Inside `_close()`, above `var arrive := 0.0`:

```text
ROOM PAST THE WORLDS FOR A SHIP TO ARRIVE IN (`ShipFlight.arrival_r`): the
edge out far enough that a circle round both suns clears every world's
ring inside it (`arrive_reach`). Packed from about 440 px, a close pair's
rings left no clear circle out there in 53 of the 56 close pairs of seeds
7, 4242 and 1999, and in 43 a ship jumping in was put inside the first
world beside the suns, at 0.30 to 0.43 of the edge, where one sun's arrive
at 0.98 (the built stills, Nov 2). It costs those 53 some opening zoom, a
median 5% further out and 12% at the most: as the map opens the two suns
stand 17 to 34 game px apart edge to edge (20 to 36 before; TwinSiteTest)
```

## Twin star ladder

Above `const TWIN_KEEP := 10.0`:

```text
EACH TWIN STAR'S KEEP-OUT, CLOSE ORBIT AND RING (`_twin_ladder`), in plane
px from its centre, all fitted to the zoom the layout is fitted to
(`fit_zoom`), where the sun is drawn widest on the plane it ever is with no
job or Hellbender out (the map never zooms out past its opening zoom):
- keep-clear (`keep_clear_of`): RING_OUT outside the drawn sun, the
  autopilot's keep-out round a sun (the drawn sun + 6, ruling 20's build),
  and never under TWIN_KEEP past its surface. One source: the planner's
  keep-out (the larger of this and the drawn sun + 6) is exactly this, so
  long as it measures the sun at `fit_zoom` and not at the zoom the map
  opens at, which a job or the Hellbender lowers.
- the close orbit a ship rides (`star_rail_of`): TWIN_RIDE outside that, so a
  ship parked there starts every flight outside the keep-out.
- the ring a ship is taken onto it inside (`star_ring_of`): TWIN_TAKE past it.
One star keeps 48, 60 and 95 (r + 32, + 44, + 79), made for a 243 px first
orbit; a twin's world is 65 to 110 px out, so the three sit 2 px apart. The
first fit (r + 10, r + 14 and the drawn sun + 6) left the close orbit inside
the drawn sun at every twin's opening zoom and the ring on the keep-out
itself, so nothing ridable was outside it (layout review, Oct 30). These 4 px
cost a median opening zoom of 0.254 against 0.256, in a model of the fit.
```

## Twin side gap

Above `const SIDE_GAP := 3.0`:

```text
AT THE OPENING ZOOM a world round one star stands this far (game px) clear of
its sun's drawn disc beside it, as drawn: SystemView holds both in 2 px
blocks (`held_most`), so a world at its 5 px floor is drawn at 6 and a sun
up to HOLD_PX over its true size. The first fit counted 4 game px of the
true sizes, which drawn came to 2.75 (layout review, Oct 30). (At its near
point, in front of the sun, it cannot: see `_twin`.)
```

Above `static func _side_need(r: float, z: float) -> float:`:

```text
The least orbit that keeps a world SIDE_GAP clear of its sun beside it, both
at the most SystemView draws them (`held_most`), at zoom z AND at every
nearer zoom, since the map can open nearer than the layout was fitted to.
The world's distance grows with the zoom but the held sun steps up 2 px at
a time: just past z its next step can take back what the zoom gave (fitted at
a sun of 10.58 game px, held at 10, a twin opened at a sun past 10.6, held at
12, and its world stood 1.8 game px off). Past that step the next ones come
too far apart to matter (`_side_need` takes the first only: a sun of r 16
steps again at 0.48 zoom, needing half the orbit).
```

## Twin zones

Above `const ZONE_NEAR := 380.0`:

```text
ZONES BY DISTANCE FROM THE LIGHT, in a twin (a one-star system's go by index,
as they always have): a body's light, as the distance from a lone sun that
would give it as much, under 380 px is near and under 600 the middle. Those
are where a one-star system's index rule puts them (its orbits 243 to 900 px
by ratio, a third and seven tenths of the way out). A star's light goes as its
drawn area: star A as a lone sun's, star B as (r_B / 16)^2 of it.
```

## Body centres

Above `var host0: Vector2 = Vector2.ZERO`:

```text
THE CENTRE OF ITS CIRCLE on the plane (x, z) AT MAP TIME 0: star A at the
origin in a one-star system and for a world round star A; star B's place
for a world round star B; the pair's balance point for a world round both
(P-type). THE PAIR TURNS (ruling 23, Jon, Nov 1: "Orbiting pair"), so a
world round one sun of a pair is carried round with it: where its centre
is at t is `host_at(t)`. Named for its time so a reader that wants "where
it is now" cannot take it by mistake; one sun, a close pair and every
world round both hold still here at every t.
```

## Fit zoom

Above `var fit_zoom: float = 0.0`:

```text
THE ZOOM THE LAYOUT IS FITTED TO: the opening zoom (`open_zoom`) of the
system with no signed job and no Hellbender out past its edge, which come and
go and must move nothing. The map opens there or nearer, and only further out
while one of them is posted. A twin's star rings are fitted to it, and the
autopilot's keep-out round a sun should be measured at it too, so the
keep-out is the layout's and not moved by a job (`keep_clear_of`).
```

## Star positions

Above `func star_pos(p: int, t: float) -> Vector2:`:

```text
WHERE STAR p IS ON THE PLANE (x, z) AT MAP TIME t. One sun: the origin.
Two: both on one line through the balance point, star B `share x sep` out
from it and star A `(1 - share) x sep` on the far side, turned `pair_n * t`
from where the layout put them, so at t = 0 they are exactly there (A at
the origin, B at `star2_at0`). t has no default: a caller that does not say
which moment it means is a caller that has not been thought about.
```

## Star rail

Above `func star_rail_of(p: int = -1) -> float:`:

```text
STAR p'S CLOSE ORBIT, the rail (the black hole's lens reaches far past its
disc, so its close orbit sits outside it), and the ring a ship is taken onto
it inside. One star: today's numbers, star_r + 44 and + 79, and `ShipFlight`
rides 8 inside the ring. In a twin (`_twin_ladder`) the rail IS the orbit to
ride, 2 px outside the keep-out, and the ring 2 px past it: ring - 8 there is
inside the keep-out, and rail-derived radii such as ShipFlight's bumper
(rail + 25) land past the ring.
```

## Pair box

Above `func pair_box(t: float) -> Rect2:`:

```text
THE PAIR'S OWN PART OF A WIDE BINARY (Jon, Nov 1, "gap:A"), which its map
opens framed on (`SystemMapScreen.open_view`): the two suns and the worlds
that circle one of them, each world by its whole orbit and reach. Fitted to
the whole system, a wide pair's world round one sun was drawn as little as
5 px from its sun's disc (seed 7, the binary-gap prototype); framed on the
pair, 28 to 45 px (the wide pairs of seeds 7, 4242 and 1999). On the
plane (x across, y deep), star A at the origin: centred on the middle of the
suns' discs and those orbits, and reaching from there PAIR_SUN_PAD past each
sun's disc and past every such orbit, and PAIR_PAD more all round. Empty for one sun and for a close pair, which
nothing circles one sun of: they open on their whole system as they did.
AT MAP TIME t: the pair turns (ruling 23), so the box is the pair as it
stands then; at t 0 it is the box the binary-gap sheet measured.
```

## Twin worlds

Inside `of()`, above `if L.twin and order.filter(func(o): return o.kind == &"planet").size() < 2:`:

```text
A WORLD ROUND EACH SUN, always (ruling 20: the flight from one to the
other is why a twin is there): its first two planets go round its two
stars, so where the options bring one a bare second goes in beside it.
A CLOSE PAIR GETS IT TOO, round both: the binary-kinds sheet's numbers that
Jon picked on were measured with it (43 of seed 7's 55 with a world in the
middle band; 35 without it), and it keeps R's draws as a wide pair's
```

## Orbit spacing

Inside `of()`, above `var lo := L.star_r + (62.0 if L.star == StarKind.RED else (84.0 if L.star == StarKind.CORE else 46.0))`:

```text
ORBITS, spread out from clear of the star, each at least as far from the
last as the two bodies on them are wide. The mockup spread them evenly and
sized the bodies afterwards, so a ringed giant beside a large world could
overlap it -- by 24 px at worst, measured by `-- systemtest`.
The first orbit is far enough out that a world at the front of it, seen at
the map's slant, sits clear of the star's disc (Jon: "the first planet of a
system is always SUPER CLOSE to the sun"). Each body then takes its own
slot between there and `HI`, spaced by ratio as real systems are, and
lands anywhere in it, so the first is not always on the inner edge.
```

## Pair speed

Above `const PAIR_K := 4.0`:

```text
THE PAIR'S SPEED (ruling 23, Jon, Nov 1, "speed:A"): four times the game's
own Kepler rate (`GM_KEPLER`: 800 s a lap at 100 px with the whole mass, as
the worlds go). A wide pair laps in 19 to 25 minutes of map time and a close
pair in 6 to 7; at Kepler (77 to 99 and 25 to 30 minutes) nobody would see it
move in a visit. The worlds round one sun go four times faster too, so each
still laps its sun 5.4 to 7.6 times a lap of the pair, as a steady world
round one sun of a real binary does (any speed-up of the pair alone past
about x1.1 breaks that rule). Worlds round both, giants and map time itself
keep their speed. (Those lap times are at a `WORLD_PACE` of 1: the pair and
every world go WORLD_PACE times faster again, so the ratios hold.)
```

## Pair turning

Above `static func spin_pair(L: SystemLayout) -> void:`:

```text
THE PAIR TURNS (ruling 23): its rate (`pair_n`), angle at t = 0 and star
A's distance from the balance point, and each world round one sun carried
round with its sun (`Body.hc` .. `hph`) at `pair_speed` times its own Kepler
rate. A pair turns as one rigid thing, so every distance from a sun to its
world, from the balance point to anything, and between the suns is the same
at every t: the steady zones, ladders, keep-outs, rails and rings laid out
at t = 0 hold at every angle. Laid last, once the layout is done; a harness
that builds a pair by hand calls it too. One sun: nothing.
```

## Wide pair

Above `static func _twin(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator, jobs: Array[int]) -> void:`:

```text
A WIDE PAIR, two binaries in three (ruling 20, Oct 30: "Prototype: twin:A";
the close pair is `_close`). Star A stays at the origin;
star B `sep` from it at `star2_at0`, a little smaller (as laid out, at map
time 0: the pair then turns round its balance point, `spin_pair`). The first two
planets go round one star each (S-type), inside the farthest steady orbit round
it, at 0.70 to 0.90 of it. Everything else -- the giant, the belt, any further
world, a contact, a signed job, the Hellbender -- goes round both (P-type),
past the nearest steady orbit round the pair, circling the balance point. So
index order is not radial order here: there are three centres.

FITTED TO THE MAP AT ITS OPENING ZOOM (`fit_zoom`). A world round one star is
65 to 110 px from it and the whole system 1,000 to 1,400 px across the frame's
half, so the map opens at about a quarter zoom, where a sun is drawn at its 10
px floor (40 plane px, against its own 16) and a world at 5. So each star's
keep-out sits RING_OUT outside its drawn sun, its close orbit and ring just
past that (`_twin_ladder`), each world's ring RING_CLEAR outside the star's,
and each world stands SIDE_GAP clear of its sun's disc beside it as drawn.
Where a pair's worlds would not fit, the stars move further apart; that moves
the edge and so the opening zoom, so the two are solved together
(`_twin_edge_most`, `_twin_fit`).
A SIGNED JOB OR THE HELLBENDER out past the edge opens the map further out
than `fit_zoom` while it is there, and the suns are drawn wider on the plane
than the rings were fitted to: by up to about 10 px with a fetch's world out
(systemtest measures it). Fitting to that instead cannot be done: the fit is
a fixed point (the worlds need about 19 / zoom px from their sun, and the zoom
falls as the pair spreads) whose slope is about 0.82, so the 271 px that a
fetch, a hunt and the Hellbender can add came back about five times over, and
in a model of 1,633 twins 98% of pairs went past 380 px apart and the median
opening zoom fell from 0.26 to 0.13 (layout review, Oct 30). So the keep-out
stays the layout's (`keep_clear_of`), and nothing moves when they come.
IN FRONT OF ITS SUN, at its orbit's near point, a world round one star cannot
clear the drawn disc at the opening zoom, for any numbers: it is a z SLANT
below the sun there, and with anything round both the edge is at least 2.8
times the separation while a is at most 0.30 of it, so that is at most 13
game px against the sun's 10 and the world's 5. It passes over the sun's lower
edge (systemtest measures it: 5.6 to 10 game px of overlap as drawn in 2 px
blocks, 4 to 8 of the true sizes) and clears it from a zoom of about 0.6.

Draws: the "twin" stream for the pair (its first draw is MapGen's, whether
there are two suns at all), then R in a twin's own order -- the orbits' three
draws a body first, since where a body is decides its zone, then its world.
```

Inside `_twin()`, above `var sep := sep0`:

```text
THE SEPARATION, as rolled or as far apart as the worlds round each star
need: never shrunk, and moving it out moves the opening zoom (smaller, so
a sun's floor is wider on the plane). Near the answer each step of going
out by what the worlds need closes only 7 to 9% of the distance left, and
the first fit's 32 such steps ran out short in about half the spread pairs,
its rings fitted to the step before (layout review, Oct 30). So it is
bisected: from a separation that fits, halved toward the rolled one 48
times, and everything below is fitted to the one it ends on.
```

Above `static func _twin_edge_most(L: SystemLayout, sep: float, lim_a: float, lim_b: float, outer: Array[int], jit: PackedFloat64Array) -> float:`:

```text
How far out a twin reaches from star A at the most, for separation `sep`,
with every world as big as it can be: its opening zoom can then only be this
or nearer, and nearer only clears the suns more. Not the Hellbender's place
or a signed job's: they come and go, and must move nothing when they do
(systemtest, contracttest), and room kept for them always cannot be had (see
`_twin`), so while one is out past the edge the map opens further out than
the layout's `fit_zoom` and the suns are drawn wider than it.
```

## Orbits round both

Above `static func _p_orbits(L: SystemLayout, sep: float, outer: Array[int], jit: PackedFloat64Array) -> PackedFloat64Array:`:

```text
The orbits round both stars, in index order: spread by ratio from just past
the nearest steady one, each at least as far from the last as the two bodies
could be wide (`_reach_most`: the spacing is fixed before the worlds are
rolled, so it cannot depend on them). As round one sun, the bodies are kept
apart, not their rings: a giant's 131 px ring holds its neighbours round both
far more often than round one sun, where the orbits spread 3.7 times from the
first (systemtest prints how often). Keeping every body out of the giant's
ring cost, in a model of 1,633 twins, the least opening zoom 0.229 to 0.145
and pushed 9% of pairs past 380 px apart (layout review, Oct 30).
```

## Body names

Above `func name_order() -> Array[int]:`:

```text
THE BODIES IN THE ORDER OF THEIR NAMES (I, II, III ...): the panel's
SATELLITES list (Jon, Nov 1, "list:C"). Round one sun every body is named by
its index (`ROMAN[i]`), so this is the order they were made in and nothing
there moves. In a binary they are named out from the suns (star A's world,
star B's world, then those round both, `_twin`), not in the order they were
made: SIGMA KESTREL PRIME on seed 7 read III, IV, I, V, II, VI. By the numeral
each name ends in; a tie (past X, which `ROMAN` stops at) by index.
```

## World pace

Above `const WORLD_PACE := 4.0`:

```text
THE WORLDS' PACE (Jon, Nov 4: "orbits could be faster"; the fast-transfers
design, Nov 5): every body's period and the pair's turn go WORLD_PACE times
the game's old Kepler rate (`kepler_s`: 800 / WORLD_PACE s a lap at 100 px),
so a world 100 px out laps in 200 s at 4, where it took 800. Applied where
each period is set. NOT the map's clock: the sun's breath, pulsars, the
sky's events and the comets keep their own time (Jon, Nov 5: "I think the
comet speed is perfect though"; SkyWeather ages them by the frame's dt);
nor the ship's parked orbit (`ShipFlight.STAR_PACE` keeps its own 800: "my
ships orbit is fine actually"). A game constant, not a setting: every peer
must turn the worlds alike (`NetSession.PROTOCOL` 17). 4: Jon's pick from
the films (Nov 5, "3D"), the binary pair with them.
```
