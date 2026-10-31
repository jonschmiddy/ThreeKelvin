class_name SystemLayout
extends RefCounted

## WHAT IS IN A SYSTEM, AND WHERE: its star, the bodies going round it, and
## which body each of the system's options sits on.
##
## DERIVED, NEVER SAVED. Everything here comes from `Rng.derive(&"system",
## n.index)` and the node's own facts, so the same system lays out the same way
## every time it is asked, on every machine, with nothing in the save -- the way
## `_roll_foes` needs no save. The option list, the claim ids (`OPTION_SITE + i`)
## and the results are untouched: this only says where on the map each option is
## drawn.
##
## Ported from the approved system-map mockup (`layout()` in the scratchpad's
## `sysmap/template.html`), rule for rule:
##
## - one body for every option, chosen by its tags: a fight with nothing to
##   salvage is a CONTACT in open space; salvage and hazard together, or hazard
##   alone, is a BELT (one belt holds all of them); salvage alone is a DERELICT
##   or a belt; anything else -- a contract, a signal, fauna -- is a PLANET;
## - a gas giant if and only if the node has one (never round a pulsar);
## - a station's station as a body of its own, with DOCK on it;
## - about a third of the systems with no belt get one anyway, as scenery, and
##   a pulsar or the core always does;
## - ONE EVENT TO A WORLD (Jon, Oct 15: "A planet should only hold one event.
##   That should be a rule."): every option that wants a planet gets its own,
##   and the giant and the star each hold one at most -- a second that wanted
##   them takes its place by its tags. A place is where a fight leaves its
##   wrecks (`Jetsam.site`), so one event to a place is one fight's wrecks to a
##   place. A belt still holds every option that wanted a belt;
## - no padding: one body is always there, and a system has as many more as
##   its options, its giant, its station and its belt make -- one, two or three
##   is normal (Jon: "I like the diversity and scarcity");
## - the core's custodian as a contact on the outermost orbit;
## - the Hellbender, while it is anchored here or its wreck lies here, as a
##   contact of its own past every orbit, added last so no other body moves
##   (Jon, Oct 15: the system's contact at a place of its own, so you fly there
##   to fight it and its wrecks are its own);
## - at about one ordinary system in four, TWO SUNS (ruling 20): a world round
##   each, everything else round both (`_twin`).
##
## Orbits are spread from just outside the star (further out round a red giant
## and the black hole) to `HI`; periods follow Kepler, the square of the period
## going as the cube of the orbit, so the inner bodies go round faster.

## THREE TIMES THE OLD SPREAD (Jon: "can the solar system also be a bit more
## zoomed out? with further away orbits?" -- "even 3x would be good"), so there is
## room to fly between worlds. The first orbit still sits just clear of the star;
## the rest are spaced by ratio out to here. The map opens zoomed out to fit it.
const HI := 900.0
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## The star's look: a sun, a red hypergiant, a blue hypergiant, a pulsar, the
## core's black hole.
enum StarKind { ORDINARY, RED, BLUE, PULSAR, CORE }

## The star's drawn radius, and how deep its well sinks the fabric under it.
const STAR_R := {StarKind.ORDINARY: 16.0, StarKind.RED: 48.0, StarKind.BLUE: 24.0, StarKind.PULSAR: 3.0, StarKind.CORE: 16.0}
const STAR_MASS := {StarKind.ORDINARY: 46.0, StarKind.RED: 62.0, StarKind.BLUE: 56.0, StarKind.PULSAR: 66.0, StarKind.CORE: 110.0}

## THE PULL A SHIP FEELS, on map time (Phase 13, ruled Oct 29 "clock:map", and
## ruling 20, Oct 30): a system's whole star mass pulls a ship with this GM
## (px^3/s^2), whatever its kind. It is KAPPA times the Kepler GM that turns the
## worlds (GM_KEPLER: a world 100 px out laps in 800 s), because on map time a
## ship flies about a hundred times faster than the worlds move. A ship riding
## 170 px out at RAIL_V 35 px/s is on a circular orbit under it. Only autopilot
## flights feel it; flying by hand has no gravity (Jon, Oct 3).
const GM_KEPLER := 61.685
const KAPPA := 3376.0
const GM_SHIP := 208250.0
## A GIANT'S WEIGHT against its star (ruling 20: "1/4 - 1/10 ... purely because
## it's more fun"), rolled per giant; every autopilot flight feels it.
const GIANT_MIN := 0.10
const GIANT_MAX := 0.25
## STAR B'S PLACE. A place in a system is an int: a body's index (0 or more),
## -1 star A (the star, its close orbit), STAR_B star B. -2 is "nowhere", -3
## the edge as arrived, -9 open space, -10 a co-op arrival, -99 SITE_ANY, so
## star B takes -4, which nothing used. Test with `is_star` / `is_place`, never
## `>= -1` or `< 0`.
const STAR_B := -4

## TWO SUNS: THE NUMBERS (ruling 20, Oct 30; `of` lays them out, `_twin`).
## Star A's share of the pair's mass, rolled. The build asked 0.52 to 0.65; past
## 0.60 star B's steady zone (0.236 of the separation at 0.60, 0.217 at 0.65) is
## too small for its world to stand clear of B's drawn sun at the opening zoom
## without pushing the pair 650 px apart (measured in the layout's own model:
## at 0.65, 19 to 39% of twins had to be spread, up to 720 px; at 0.60, 2 to 6%,
## up to about 400).
const TWIN_SHARE_LO := 0.52
const TWIN_SHARE_HI := 0.60
## How far apart the two stars are, rolled (px). A pair whose worlds would not
## fit is moved further apart until they do (`_twin`), a few percent of them.
const TWIN_SEP_LO := 320.0
const TWIN_SEP_HI := 380.0
## Star B is never more than this (radians, 40 degrees) off the map's level line
## from star A: seen at the map's slant a pair one above the other stands 0.38 of
## its distance apart, and two suns that close on screen read as one. At 40
## degrees they stand 0.80 of it apart.
const TWIN_TURN := 0.6981317
## THE FARTHEST STEADY ORBIT ROUND ONE STAR OF A PAIR (Holman and Wiegert 1999,
## circular orbits): a = (HW_0 - HW_MU mu) x separation, mu the OTHER star's
## share. 0.293 round A and 0.255 round B at a 0.55 share.
const HW_0 := 0.464
const HW_MU := 0.380
## Where in that zone a world round one star goes: 0.70 to 0.90 of the limit.
const S_LO := 0.70
const S_HI := 0.90
## THE NEAREST STEADY ORBIT ROUND BOTH: 2.423 x the separation from the balance
## point (about 2.42 for every share in range), and the first world round both
## a few percent past it.
const P_LIMIT := 2.423
const P_MARGIN := 1.03
## The worlds round both are spread by ratio over this much of their first
## orbit, as a one-star system's are over lo to HI (3.7 times): kept close,
## because every pixel out shrinks the whole map at its opening zoom.
const P_SPREAD := 1.25
## A WORLD'S RING ROUND ONE STAR OF A PAIR (px). A one-star world's is 62 to 91
## (`soi_of`), and the steady zone round a star is 70 to 105 px: the prototype's
## 38.4 did not fit inside it. 20 holds the ship 17.6 px out (`ORBIT_K`), clear
## of the largest world drawn (12, a broken one).
const S_RING := 20.0
## Each twin star's keep-clear, close-orbit rail and the least ring past the
## rail (px past its surface). One star keeps 32, 44 and 35, made for a 243 px
## first orbit; a twin's world is 65 to 110 px out. The ring is also kept 6 px
## outside the star's drawn sun at the opening zoom (`_twin_ring`), where the
## autopilot's keep-out round a sun is (the drawn sun + 6), so a ship on the
## ring is not drawn on the sun and a flight passing the star stays off it.
## Moving it out from 4 to 6 moved two of systemtest's eight tabled pairs, by
## 0.3 px at most: most worlds are held further out by the drawn-disc rule.
const TWIN_KEEP := 10.0
const TWIN_RAIL := 14.0
const TWIN_RING := 12.0
const RING_OUT := 6.0
## How far a world's ring keeps from its star's close-orbit ring (px).
const RING_CLEAR := 8.0
## AT THE OPENING ZOOM a world round one star stands this far (game px) clear of
## its sun's drawn disc, either side of the star: 3, and 1 more for the blocks
## the sun and the world are drawn in. (At its near point, in front of the sun,
## it cannot: see `_twin`.)
const SIDE_PX := 4.0
## The map's drawing, which the twins' numbers are fitted to: the sun's floor of
## screen radius (`SystemView.STAR_FLOOR`), a world's least drawn radius on the
## plane and on screen (`SystemView.min_r`, `MIN_SCREEN_R`), the largest world
## drawn round one star of a pair (a broken one's r), and the frame the opening
## zoom is fitted to before the screen is laid out (`SystemMapScreen._fit_zoom`).
const SUN_FLOOR := 10.0
const WORLD_MIN_R := 10.0
const WORLD_FLOOR := 5.0
const S_WORLD_MOST := 12.0
const FIT_FRAME := Vector2(655.0, 420.0)
## ZONES BY DISTANCE FROM THE LIGHT, in a twin (a one-star system's go by index,
## as they always have): a body's light, as the distance from a lone sun that
## would give it as much, under 380 px is near and under 600 the middle. Those
## are where a one-star system's index rule puts them (its orbits 243 to 900 px
## by ratio, a third and seven tenths of the way out). A star's light goes as its
## drawn area: star A as a lone sun's, star B as (r_B / 16)^2 of it.
const ZONE_NEAR := 380.0
const ZONE_FAR := 600.0

## EVERY WORLD IN THE MIX, by how far out it is: the scorched and burning close
## in, the living in the middle, the frozen far out. The names are the planet
## painter's.
const POOLS := [
	[&"lava", &"iron", &"desert", &"rock", &"toxic", &"cracked", &"volcanic", &"scorched", &"carbonA", &"carbonB", &"eyeball"],
	[&"verdant", &"ocean", &"desert", &"iron", &"rock", &"toxic", &"crystal", &"hurricane", &"haze", &"biolum", &"aurora", &"lightning", &"swamp", &"eyeball", &"carbonC"],
	[&"ice", &"moon", &"rock", &"ice", &"crystal", &"europa", &"carbonC", &"rogue"],
]
const GIANTS := [&"banded", &"icegiant", &"storm", &"violet"]
## A giant close in is a hot one, glowing or boiling away.
const HOT_GIANTS := [&"hotjup", &"comet"]
const CORE_WORLDS := [&"moon", &"rock", &"lava", &"crystal", &"shattered", &"cracked", &"scorched"]
const PULSAR_WORLDS := [&"iron", &"rock", &"moon", &"scorched", &"shattered"]
const BELT_KINDS := ["ROCK AND METAL", "ICE AND DUST", "CARBON, DARK", "NICKEL-IRON"]


## One beacon: an option of the system's, the station's DOCK, or the core's custodian.
class Beacon extends RefCounted:
	var opt: int = -1
	var dock: bool = false
	var core: bool = false
	## The Hellbender, anchored here (or dead here: its wreck's place).
	var hellbender: bool = false


class Body extends RefCounted:
	## planet, giant, belt, station, derelict, contact
	var kind: StringName = &"planet"
	var beacons: Array[Beacon] = []
	var orbit: float = 0.0
	## Seconds for one turn round the star.
	var period: float = 1.0
	## Where on its orbit it starts, in radians.
	var phase: float = 0.0
	## 0 near, 1 middle, 2 far: which pool its world is drawn from.
	var zone: int = 0
	var index: int = 0
	var name: String = ""
	## The planet painter's world, for a planet or a giant; empty otherwise.
	var world: StringName = &""
	## The painter's seed for this world.
	var seed: int = 0
	## Drawn radius in game pixels.
	var r: float = 0.0
	## Round a pulsar only the bare, scorched cores of planets survive.
	var scorched: bool = false
	## What a belt is made of, for its panel.
	var comp: String = ""
	## The dent it makes in the fabric: how deep, and how wide.
	var mass: float = 0.0
	var well_w: float = 10.0
	## Its ring: let go inside it slow enough and you are on its orbit
	## (`ShipFlight`). Worlds only; 0 for everything else.
	var soi: float = 0.0
	## THE CENTRE OF ITS CIRCLE on the plane (x, z): star A at the origin in a
	## one-star system and for a world round star A; star B's place for a world
	## round star B; the pair's balance point for a world round both (P-type).
	## The stars hold still (ruling 20's build: the pair turns once an hour on
	## map time, and each visit starts the map's clock again), so this is fixed.
	var host: Vector2 = Vector2.ZERO
	## Which: -1 star A, STAR_B star B, -9 both (round the balance point).
	var host_id: int = -1
	## The pull a ship feels from it (px^3/s^2): a giant's, `gm_frac` of the
	## stars' whole GM_SHIP; 0 for every other body (worlds pull nothing).
	var gm: float = 0.0
	## A giant's weight against its star or stars (GIANT_MIN to GIANT_MAX); 0
	## for every other body. The fabric's dent (`mass`) and the capture ring
	## (`soi`) do not follow it.
	var gm_frac: float = 0.0

	## Where it is at time `t`, on the plane: x across, z toward the viewer.
	## Its footprint on the plane: where it is at time t, x across, z toward the viewer.
	func pos(t: float) -> Vector2:
		var p := point3(t)
		return Vector2(p.x, p.z)

	## Where it is at time t, as the flight's (x, 0, z): every world is on the
	## plane (Jon: "we can get rid of planets with tilted orbits, it doesn't
	## work on a flat plane for this game").
	func point3(t: float) -> Vector3:
		return orbit_point(phase + t / period * TAU)

	func orbit_point(a: float) -> Vector3:
		return Vector3(host.x + cos(a) * orbit, 0.0, host.y + sin(a) * orbit)


var star: StarKind = StarKind.ORDINARY
var star_r: float = 16.0
var star_mass: float = 46.0
var bodies: Array[Body] = []
## The events on the star itself (an option whose `site` is the star, at a red
## or blue star): open from a close orbit of it, body -1 everywhere a place is
## asked for.
var star_beacons: Array[Beacon] = []
## How far out the outermost orbit reaches, plus a margin: from star A, round
## whatever centre each body circles.
var edge: float = HI + 30.0

## TWO STARS (ruling 20, Oct 30). Star A is `star`, at the origin as the one
## star always was; star B holds still at `star2_at`. Off (`twin` false) every
## field here keeps its one-star value and nothing changes.
var twin: bool = false
var star2: StarKind = StarKind.ORDINARY
var star2_r: float = 0.0
var star2_at: Vector2 = Vector2.ZERO
## Star A's share of the stars' mass (1 alone); star B has the rest.
var star_share: float = 1.0
## The pair's balance point, which worlds round both stars circle.
var bary: Vector2 = Vector2.ZERO
## The stars' distance apart (0 alone).
var sep: float = 0.0
## Each star's close-orbit rail, ring and keep-clear, set where the layout is
## built (`star_rail_of`). A one-star system keeps today's numbers.
var _rail := {}
var _ring := {}
var _keep := {}


static func is_star(p: int) -> bool:
	return p == -1 or p == STAR_B


## A place a ship can be at: a body, star A or star B.
static func is_place(p: int) -> bool:
	return p >= -1 or p == STAR_B


## The stars a system has, as places: [-1] or [-1, STAR_B].
func stars() -> Array[int]:
	var out: Array[int] = [-1]
	if twin:
		out.append(STAR_B)
	return out


## Where star p is on the plane (x, z).
func star_pos(p: int) -> Vector2:
	return star2_at if p == STAR_B else Vector2.ZERO


func star_radius(p: int) -> float:
	return star2_r if p == STAR_B else star_r


func star_kind_of(p: int) -> StarKind:
	return star2 if p == STAR_B else star


## The pull a ship feels from star p (px^3/s^2).
func star_gm(p: int) -> float:
	return GM_SHIP * ((1.0 - star_share) if p == STAR_B else star_share)


## STAR p'S CLOSE ORBIT, as `ShipFlight` rides it: the rail (the black hole's
## lens reaches far past its disc, so its close orbit sits outside it), and the
## ring a ship is taken onto it inside, 35 px further out. One star: today's
## numbers, star_r + 44 and + 79.
func star_rail_of(p: int = -1) -> float:
	if _rail.has(p):
		return _rail[p]
	if star == StarKind.CORE:
		return 150.0
	return star_radius(p) + 44.0


## (a twin's ring is set on its own, 12 px or more past the rail: 35 would not
## fit inside its world's orbit)
func star_ring_of(p: int = -1) -> float:
	if _ring.has(p):
		return _ring[p]
	return star_rail_of(p) + 35.0


## How far a flight keeps from star p's centre. One star: star_r + 32.
func keep_clear_of(p: int = -1) -> float:
	if _keep.has(p):
		return _keep[p]
	return star_radius(p) + 32.0


## The farthest steady orbit round one star of a pair, as a share of the
## separation; `mu` is the OTHER star's share (Holman and Wiegert 1999).
static func s_limit(mu: float) -> float:
	return HW_0 - HW_MU * mu


## THE ZOOM A SYSTEM OPENS AT for its edge: `SystemMapScreen._fit_zoom`, with
## the frame it is fitted to before the screen is laid out.
static func open_zoom(edge: float) -> float:
	return clampf(minf(FIT_FRAME.x / (2.0 * (edge + 20.0)), FIT_FRAME.y / (2.0 * (edge + 20.0) * SLANT + 60.0)), 0.1, 1.0)


## A sun's drawn radius on screen (game px) at zoom z: the floor the map eases
## it up to (`SystemView._star_k_raw`, every style but LEGACY).
static func sun_drawn(r: float, z: float) -> float:
	return sqrt(pow(r * z, 2.0) + SUN_FLOOR * SUN_FLOOR)


## A planet's drawn radius on screen (game px) at zoom z (`SystemView._draw_r_raw`).
static func world_drawn(b: Body, z: float) -> float:
	return maxf(maxf(b.r, WORLD_MIN_R) * z, WORLD_FLOOR)


static func star_kind(n: MapGen.MapNode) -> StarKind:
	if n.type == MapGen.NodeType.CORE:
		return StarKind.CORE
	if n.type == MapGen.NodeType.PULSAR:
		return StarKind.PULSAR
	match n.star:
		MapGen.Star.RED:
			return StarKind.RED
		MapGen.Star.BLUE:
			return StarKind.BLUE
	return StarKind.ORDINARY


## The layout of node `n`. Cheap enough to call whenever it is wanted: a few
## dozen draws, no allocation worth caching.
static func of(n: MapGen.MapNode) -> SystemLayout:
	OptionTable.ensure(n)
	var R := Rng.derive(&"system", n.index)
	var L := SystemLayout.new()
	L.star = star_kind(n)
	L.star_r = STAR_R[L.star]
	L.star_mass = STAR_MASS[L.star]
	# TWO SUNS where the node has them, and only where it may (`MapGen.twin_ok`)
	L.twin = n.twin and MapGen.twin_ok(n)

	# what each option wants to sit on
	var want: Array = []
	# WHERE THE TEXT SAYS IT IS (an option's `site`, `OptionTable`): an event
	# whose text has the giant filling the sky sits on the giant, one in a red
	# or blue star's glare on the star itself -- not on a belt LOCAL draws as
	# rocks. Only where the system has that giant or that star; otherwise it
	# takes its place by its tags, as every other option does.
	var on_giant: Array[int] = []
	var giant_here := n.gas_giant and L.star != StarKind.PULSAR
	var hot_star := L.star == StarKind.RED or L.star == StarKind.BLUE
	# A SIGNED JOB'S EVENT (`OptionTable.is_job`) is laid out after everything
	# else, past the last orbit, so posting it moves nothing already there
	var jobs: Array[int] = []
	for i in n.options.size():
		if OptionTable.is_job(n.options[i]):
			jobs.append(i)
			continue
		var site := StringName(OptionTable.by_id(n.options[i]).get("site", &""))
		if site == &"giant" and giant_here and on_giant.is_empty():
			on_giant.append(i)
			continue
		if site == &"star" and hot_star and L.star_beacons.is_empty():
			var sb := Beacon.new()
			sb.opt = i
			L.star_beacons.append(sb)
			continue
		var tags: Array = OptionTable.by_id(n.options[i]).get("tags", [])
		var k := &"planet"
		if tags.has(&"fight") and not tags.has(&"salvage"):
			k = &"contact"
		elif tags.has(&"salvage") and tags.has(&"hazard"):
			k = &"belt"
		elif tags.has(&"salvage"):
			k = &"derelict" if R.randf() < 0.5 else &"belt"
		elif tags.has(&"hazard"):
			k = &"belt"
		want.append([i, k])

	# the order out from the star. FEW BODIES ARE FINE (Jon: "1, 2, or 3 is fine.
	# I like the diversity and scarcity"; "sometimes two planets or three planets
	# is fine, too"): options that want a world share one about half the time,
	# so one planet can hold two or three encounters, and the planet that is
	# always there is only added when no option brought one
	var order: Array = []
	if n.type == MapGen.NodeType.STATION:
		order.append({"kind": &"station", "r": 4.0})
	for w in want:
		if w[1] == &"planet":
			order.append({"kind": &"planet", "opt": w[0]})
		else:
			order.append({"kind": w[1], "opt": w[0], "r": 3.0 if w[1] == &"derelict" else 0.0})
	if not order.any(func(o): return o.kind == &"planet"):
		order.insert(0, {"kind": &"planet"})
	# A WORLD ROUND EACH SUN, always (ruling 20: the flight from one to the
	# other is why a twin is there): its first two planets go round its two
	# stars, so where the options bring one a bare second goes in beside it
	if L.twin and order.filter(func(o): return o.kind == &"planet").size() < 2:
		for k in order.size():
			if order[k].kind == &"planet":
				order.insert(k + 1, {"kind": &"planet"})
				break
	if n.gas_giant and L.star != StarKind.PULSAR:
		order.insert(mini(order.size(), 2 + int(R.randf() * 2.0)), {"kind": &"giant", "also": on_giant})
	var has_belt := order.any(func(o): return o.kind == &"belt")
	if not has_belt:
		var roll := R.randf()
		if roll < 0.33 or L.star == StarKind.CORE or L.star == StarKind.PULSAR:
			order.insert(1 + int(R.randf() * float(order.size() - 1)), {"kind": &"belt"})

	# one belt holds every option that wanted a belt
	var belt: Body = null
	for o in order:
		if o.kind == &"belt" and belt != null:
			if o.has("opt"):
				var bb := Beacon.new()
				bb.opt = o.opt
				belt.beacons.append(bb)
			continue
		var b := Body.new()
		b.kind = o.kind
		b.r = float(o.get("r", 0.0))
		if o.has("opt"):
			var bo := Beacon.new()
			bo.opt = o.opt
			b.beacons.append(bo)
		for extra in o.get("also", []):
			var be := Beacon.new()
			be.opt = int(extra)
			b.beacons.append(be)
		if b.kind == &"belt":
			belt = b
		L.bodies.append(b)
	if L.star == StarKind.CORE:
		var cb := Body.new()
		cb.kind = &"contact"
		var bcore := Beacon.new()
		bcore.core = true
		cb.beacons.append(bcore)
		L.bodies.append(cb)
	if n.type == MapGen.NodeType.STATION:
		for b in L.bodies:
			if b.kind == &"station":
				var bd := Beacon.new()
				bd.dock = true
				b.beacons.append(bd)
	if L.twin:
		_twin(L, n, R, jobs)
		_weigh_giant(L, n)
		return L

	# where each body falls, out from the star: which pool its world comes from
	for i in L.bodies.size():
		var f := 0.0 if L.bodies.size() == 1 else float(i) / float(L.bodies.size() - 1)
		L.bodies[i].zone = 0 if f < 0.34 else (1 if f < 0.7 else 2)
		L.bodies[i].index = i

	# what each world is
	_worlds(L, n, R)
	# ORBITS, spread out from clear of the star, each at least as far from the
	# last as the two bodies on them are wide. The mockup spread them evenly and
	# sized the bodies afterwards, so a ringed giant beside a large world could
	# overlap it -- by 24 px at worst, measured by `-- systemtest`.
	# The first orbit is far enough out that a world at the front of it, seen at
	# the map's slant, sits clear of the star's disc (Jon: "the first planet of a
	# system is always SUPER CLOSE to the sun"). Each body then takes its own
	# slot between there and `HI`, spaced by ratio as real systems are, and
	# lands anywhere in it, so the first is not always on the inner edge.
	var lo := L.star_r + (62.0 if L.star == StarKind.RED else (84.0 if L.star == StarKind.CORE else 46.0))
	lo = maxf(lo, (L.star_r + CLEAR) / SLANT)
	# OUT IN PROPORTION TO THE WIDER SYSTEM (Jon: "planets don't have to be so
	# hella close to their star"): the first orbit was set when the system
	# reached 300; at 900 it sat at a ninth of it. Now a quarter and more (more
	# again round a red giant or the core), and every world's ring kept clear of
	# the star's close-orbit ring
	lo = maxf(lo, HI * (0.32 if L.star == StarKind.RED or L.star == StarKind.CORE else 0.27))
	var star_ring := L.star_ring_of(-1)
	var sysname := MapGen.star_name(n)
	var short := " ".join(sysname.split(" ").slice(0, 2))
	var last := -INF
	var last_reach := 0.0
	for i in L.bodies.size():
		var b := L.bodies[i]
		var f := (float(i) + 0.5 + (R.randf() - 0.5) * 0.7) / float(L.bodies.size())
		var want_at := lo * pow(HI / lo, f)
		var reach := reach_of(b)
		if i > 0:
			want_at = maxf(want_at, last + last_reach + reach + GAP)
		if b.world != &"":
			want_at = maxf(want_at, star_ring + soi_of(b) + RING_GAP)
		b.orbit = want_at
		b.period = 800.0 * pow(b.orbit / 100.0, 1.5) * (0.95 + R.randf() * 0.1)
		b.phase = R.randf() * TAU
		b.name = "%s %s" % [short, ROMAN[mini(i, ROMAN.size() - 1)]]
		last = b.orbit
		last_reach = reach
	L.edge = maxf(HI, last + last_reach) + 30.0
	# A SIGNED CONTRACT'S WORK, each on a place of its own past every orbit
	# (`Contracts.post_goal`): a hunt's target is a contact, a fetch's pickup a
	# world. Drawn off its own stream and added after the system's own bodies,
	# like the Hellbender below, so the worlds you saw before you signed are
	# the worlds you see after.
	for k in jobs.size():
		var jr := Rng.derive(&"job_place", n.index * 8 + k)
		var jb := _job_body(L, n, jobs[k], jr)
		var at := maxf(HI, last + last_reach) + reach_of(jb) + GAP + 24.0
		if jb.world != &"":
			at += soi_of(jb)
		jb.orbit = at
		jb.period = 800.0 * pow(jb.orbit / 100.0, 1.5) * (0.95 + jr.randf() * 0.1)
		jb.phase = jr.randf() * TAU
		jb.name = "%s %s" % [short, ROMAN[mini(jb.index, ROMAN.size() - 1)]]
		L.bodies.append(jb)
		last = jb.orbit
		last_reach = reach_of(jb) + (soi_of(jb) if jb.world != &"" else 0.0)
		L.edge = jb.orbit + last_reach + 30.0
	# THE HELLBENDER'S OWN PLACE, past every orbit and last in the list, so
	# nothing else moves when it comes or goes
	if hellbender_here(n):
		var hb := _hellbender_body(L, n)
		hb.orbit = maxf(HI, last + last_reach) + reach_of(hb) + GAP + 24.0
		hb.period = 800.0 * pow(hb.orbit / 100.0, 1.5)
		hb.phase = float(Rng.derive(&"hellbender_place", n.index).randf()) * TAU
		hb.name = "%s %s" % [short, ROMAN[mini(hb.index, ROMAN.size() - 1)]]
		L.bodies.append(hb)
		L.edge = hb.orbit + reach_of(hb) + 30.0
	# EACH WORLD'S RING, sized by how much it weighs (giants biggest, small rocks
	# least) and spread for the wider system; nothing else has one
	for b in L.bodies:
		if b.world != &"":
			b.soi = soi_of(b)
	_weigh_giant(L, n)
	return L


## WHAT EACH WORLD IS: its painter's world and size by its zone, and the dent it
## makes in the fabric. Its zone is set first, by index round one star, by
## distance from the light round two (`_twin`).
static func _worlds(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator) -> void:
	for b in L.bodies:
		b.seed = n.index * 31 + b.index * 7 + 1
		if b.kind == &"planet":
			var pool: Array = POOLS[b.zone]
			var w: StringName = pool[int(R.randf() * pool.size())]
			if b.zone == 1 and (n.development == MapGen.Development.CITY or n.development == MapGen.Development.CAPITAL) and R.randf() < 0.6:
				w = &"megacity" if n.development == MapGen.Development.CAPITAL and R.randf() < 0.5 else &"city"
			# now and then, a world broken to pieces
			if R.randf() < 0.025:
				w = &"shattered"
			if L.star == StarKind.CORE:
				w = CORE_WORLDS[int(R.randf() * CORE_WORLDS.size())]
			if L.star == StarKind.PULSAR:
				w = PULSAR_WORLDS[int(R.randf() * PULSAR_WORLDS.size())]
				b.scorched = true
			b.world = w
			# a broken world is drawn bigger, so its pieces read
			if w == &"shattered":
				b.r = 10.0 + R.randf() * 2.0
			elif b.scorched:
				b.r = 3.5 + R.randf() * 2.5
			else:
				b.r = 5.0 + R.randf() * 4.0 + (1.5 if b.zone == 1 else 0.0)
		elif b.kind == &"giant":
			if b.zone == 0:
				b.world = HOT_GIANTS[int(R.randf() * HOT_GIANTS.size())]
			else:
				b.world = &"banded" if R.randf() < 0.5 else GIANTS[int(R.randf() * GIANTS.size())]
			b.r = 15.0 + R.randf() * 4.0
		elif b.kind == &"belt":
			b.comp = "RUBBLE, GLAZED BY THE BEAM" if L.star == StarKind.PULSAR else BELT_KINDS[int(R.randf() * BELT_KINDS.size())]
		match b.kind:
			&"giant":
				b.mass = 24.0
				b.well_w = 34.0
			&"planet":
				b.mass = 3.0 + b.r * 0.9
				b.well_w = 14.0 + b.r * 1.6
			&"station":
				b.mass = 1.2
				b.well_w = 9.0
			&"derelict":
				b.mass = 0.8
				b.well_w = 8.0


## A signed job's place, before it is put on an orbit, drawn off its own stream
## `jr`; the caller goes on to draw its period and phase from it.
static func _job_body(L: SystemLayout, n: MapGen.MapNode, i: int, jr: RandomNumberGenerator) -> Body:
	var jb := Body.new()
	var tags: Array = OptionTable.by_id(n.options[i]).get("tags", [])
	jb.kind = &"contact" if tags.has(&"fight") else &"planet"
	var bj := Beacon.new()
	bj.opt = i
	jb.beacons.append(bj)
	jb.index = L.bodies.size()
	jb.zone = 2
	jb.seed = n.index * 31 + jb.index * 7 + 1
	if jb.kind == &"planet":
		if L.star == StarKind.PULSAR:
			jb.world = PULSAR_WORLDS[int(jr.randf() * PULSAR_WORLDS.size())]
			jb.scorched = true
			jb.r = 3.5 + jr.randf() * 2.5
		else:
			var pool: Array = POOLS[2]
			jb.world = pool[int(jr.randf() * pool.size())]
			jb.r = 5.0 + jr.randf() * 3.0
		jb.mass = 3.0 + jb.r * 0.9
		jb.well_w = 14.0 + jb.r * 1.6
	return jb


## The Hellbender's place, before it is put on an orbit.
static func _hellbender_body(L: SystemLayout, n: MapGen.MapNode) -> Body:
	var hb := Body.new()
	hb.kind = &"contact"
	var bh := Beacon.new()
	bh.hellbender = true
	hb.beacons.append(bh)
	hb.index = L.bodies.size()
	hb.zone = 2
	hb.seed = n.index * 31 + hb.index * 7 + 1
	return hb


## A GIANT'S WEIGHT (ruling 20: "1/4 - 1/10 ... purely because it's more fun"),
## in every system with one, one sun or two: rolled off a stream of its own, so
## nothing else a layout rolls moves, and kept off `mass` and `soi`, so no orbit
## moves either.
static func _weigh_giant(L: SystemLayout, n: MapGen.MapNode) -> void:
	for b in L.bodies:
		if b.kind == &"giant":
			b.gm_frac = lerpf(GIANT_MIN, GIANT_MAX, Rng.derive(&"giant_mass", n.index).randf())
			b.gm = b.gm_frac * GM_SHIP


## TWO SUNS (ruling 20, Oct 30: "Prototype: twin:A"). Star A stays at the origin;
## star B holds still `sep` from it at `star2_at`, a little smaller. The first two
## planets go round one star each (S-type), inside the farthest steady orbit round
## it, at 0.70 to 0.90 of it. Everything else -- the giant, the belt, any further
## world, a contact, a signed job, the Hellbender -- goes round both (P-type),
## past the nearest steady orbit round the pair, circling the balance point. So
## index order is not radial order here: there are three centres.
##
## FITTED TO THE MAP AT ITS OPENING ZOOM. A world round one star is 65 to 110 px
## from it and the whole system 1,000 to 1,400 px across the frame's half, so the
## map opens at about a quarter zoom, where a sun is drawn at its 10 px floor (40
## plane px, against its own 16) and a world at 5. So each star's close-orbit ring
## sits RING_OUT outside its drawn sun, each world's ring RING_CLEAR outside that,
## and each world stands SIDE_PX clear of its sun's disc beside it. Where a
## pair's worlds would not fit, the stars move further apart; that moves the edge
## and so the opening zoom, so the two are solved together (`_twin_edge_most`).
## IN FRONT OF ITS SUN, at its orbit's near point, a world round one star cannot
## clear the drawn disc at the opening zoom, for any numbers: it is a z SLANT
## below the sun there, and with anything round both the edge is at least 2.8
## times the separation while a is at most 0.30 of it, so that is at most 13
## game px against the sun's 10 and the world's 5. It passes over the sun's lower
## edge (systemtest measures it: 4 to 8 game px of overlap) and clears it from a
## zoom of about 0.6.
##
## Draws: the "twin" stream for the pair (its first draw is MapGen's, whether
## there are two suns at all), then R in a twin's own order -- the orbits' three
## draws a body first, since where a body is decides its zone, then its world.
static func _twin(L: SystemLayout, n: MapGen.MapNode, R: RandomNumberGenerator, jobs: Array[int]) -> void:
	var tw := Rng.derive(&"twin", n.index)
	tw.randf()
	L.star_share = lerpf(TWIN_SHARE_LO, TWIN_SHARE_HI, tw.randf())
	var sep0 := lerpf(TWIN_SEP_LO, TWIN_SEP_HI, tw.randf())
	var theta := (0.0 if tw.randf() < 0.5 else PI) + (tw.randf() * 2.0 - 1.0) * TWIN_TURN
	L.star2 = StarKind.ORDINARY
	L.star2_r = STAR_R[StarKind.ORDINARY] * pow((1.0 - L.star_share) / L.star_share, 0.8)
	var N := L.bodies.size()
	for i in N:
		L.bodies[i].index = i
	var jit := PackedFloat64Array()
	var pj := PackedFloat64Array()
	var ph := PackedFloat64Array()
	for i in N:
		jit.append(R.randf())
		pj.append(R.randf())
		ph.append(R.randf())
	# which world goes round which star: the first two planets, A's then B's
	var sa := -1
	var sb := -1
	var outer: Array[int] = []
	for i in N:
		if L.bodies[i].kind == &"planet" and sa < 0:
			sa = i
		elif L.bodies[i].kind == &"planet" and sb < 0:
			sb = i
		else:
			outer.append(i)
	var lim_a := s_limit(1.0 - L.star_share)
	var lim_b := s_limit(L.star_share)
	var hb_here := hellbender_here(n)
	# THE SEPARATION, as rolled or as far apart as the worlds round each star
	# need: never shrunk, and moving it out moves the opening zoom (smaller, so
	# a sun's floor is wider on the plane), so it is found by going out until
	# what the worlds need no longer grows past it (a few steps; it halves or
	# better each time)
	var sep := sep0
	var z := 1.0
	var ring_a := 0.0
	var ring_b := 0.0
	var need_a := 0.0
	var need_b := 0.0
	for _k in 32:
		z = open_zoom(_twin_edge_most(L, sep, lim_a, lim_b, outer, jit))
		ring_a = _twin_ring(L.star_r, z)
		ring_b = _twin_ring(L.star2_r, z)
		need_a = _s_need(L.star_r, ring_a, z)
		need_b = _s_need(L.star2_r, ring_b, z)
		var s_need := maxf(sep0, maxf(need_a / (S_HI * lim_a), need_b / (S_HI * lim_b)))
		if s_need <= sep:
			break
		# (a hundredth of a pixel past it, so the step after meets it outright)
		sep = s_need + 0.01
	L.sep = sep
	L.star2_at = Vector2(cos(theta), sin(theta)) * sep
	L.bary = L.star2_at * (1.0 - L.star_share)
	L._keep = {-1: L.star_r + TWIN_KEEP, STAR_B: L.star2_r + TWIN_KEEP}
	L._rail = {-1: L.star_r + TWIN_RAIL, STAR_B: L.star2_r + TWIN_RAIL}
	L._ring = {-1: ring_a, STAR_B: ring_b}
	# round one star each, where in the steady zone it rolled, or as far out as
	# its ring and its drawn disc need (the separation was found so that is
	# inside the steady limit, which is the rule)
	var wa := L.bodies[sa]
	wa.host = Vector2.ZERO
	wa.host_id = -1
	wa.orbit = minf(maxf(lerpf(S_LO, S_HI, jit[sa]) * lim_a * sep, need_a), S_HI * lim_a * sep)
	var wb := L.bodies[sb]
	wb.host = L.star2_at
	wb.host_id = STAR_B
	wb.orbit = minf(maxf(lerpf(S_LO, S_HI, jit[sb]) * lim_b * sep, need_b), S_HI * lim_b * sep)
	# round both
	var po := _p_orbits(L, sep, outer, jit)
	for k in outer.size():
		var b := L.bodies[outer[k]]
		b.host = L.bary
		b.host_id = -9
		b.orbit = po[k]
	# KEPLER ROUND WHAT IT CIRCLES: a world round one star goes round as its
	# share of the mass pulls it, slower (the period formula has the whole mass
	# as 1); a world round both, as round a lone star
	for i in N:
		var b := L.bodies[i]
		var m := 1.0 if b.host_id == -9 else (L.star_share if b.host_id == -1 else 1.0 - L.star_share)
		b.period = 800.0 * pow(b.orbit / 100.0, 1.5) / sqrt(m) * (0.95 + pj[i] * 0.1)
		b.phase = ph[i] * TAU
	for b in L.bodies:
		b.zone = L.zone_of(b)
	_worlds(L, n, R)
	# NAMED OUT FROM THE SUNS: A's world first, then B's, then those round both
	# from the inside out (theirs by index is theirs by orbit)
	var short := " ".join(MapGen.star_name(n).split(" ").slice(0, 2))
	var rank: Array[int] = [sa, sb]
	rank.append_array(outer)
	for k in rank.size():
		L.bodies[rank[k]].name = "%s %s" % [short, ROMAN[mini(k, ROMAN.size() - 1)]]
	# THE EDGE, and the jobs and the Hellbender past it: by how far each body
	# reaches from its own centre, not the last one's orbit
	var far := 0.0
	var ext := 0.0
	for b in L.bodies:
		far = maxf(far, b.host.length() + b.orbit + reach_of(b))
		ext = maxf(ext, b.host.distance_to(L.bary) + b.orbit + reach_of(b))
	L.edge = maxf(HI, far) + 30.0
	for k in jobs.size():
		var jr := Rng.derive(&"job_place", n.index * 8 + k)
		var jb := _job_body(L, n, jobs[k], jr)
		var at := maxf(HI, ext) + reach_of(jb) + GAP + 24.0
		if jb.world != &"":
			at += soi_of(jb)
		jb.orbit = at
		jb.host = L.bary
		jb.host_id = -9
		jb.period = 800.0 * pow(jb.orbit / 100.0, 1.5) * (0.95 + jr.randf() * 0.1)
		jb.phase = jr.randf() * TAU
		jb.name = "%s %s" % [short, ROMAN[mini(jb.index, ROMAN.size() - 1)]]
		L.bodies.append(jb)
		ext = jb.orbit + reach_of(jb) + (soi_of(jb) if jb.world != &"" else 0.0)
		L.edge = L.bary.length() + ext + 30.0
	if hb_here:
		var hb := _hellbender_body(L, n)
		hb.orbit = maxf(HI, ext) + reach_of(hb) + GAP + 24.0
		hb.host = L.bary
		hb.host_id = -9
		hb.period = 800.0 * pow(hb.orbit / 100.0, 1.5)
		hb.phase = float(Rng.derive(&"hellbender_place", n.index).randf()) * TAU
		hb.name = "%s %s" % [short, ROMAN[mini(hb.index, ROMAN.size() - 1)]]
		L.bodies.append(hb)
		L.edge = L.bary.length() + hb.orbit + reach_of(hb) + 30.0
	for b in L.bodies:
		if b.world != &"":
			b.soi = S_RING if is_star(b.host_id) else soi_of(b)


## The orbits round both stars, in index order: spread by ratio from just past
## the nearest steady one, each at least as far from the last as the two bodies
## could be wide (`_reach_most`: the spacing is fixed before the worlds are
## rolled, so it cannot depend on them).
static func _p_orbits(L: SystemLayout, sep: float, outer: Array[int], jit: PackedFloat64Array) -> PackedFloat64Array:
	var lo := P_LIMIT * P_MARGIN * sep
	var hi := lo * P_SPREAD
	var out := PackedFloat64Array()
	var last := -INF
	var last_reach := 0.0
	for k in outer.size():
		var b := L.bodies[outer[k]]
		var f := (float(k) + 0.5 + (jit[outer[k]] - 0.5) * 0.7) / float(outer.size())
		var want := maxf(lo, lo * pow(hi / lo, f))
		var reach := _reach_most(b)
		if k > 0:
			want = maxf(want, last + last_reach + reach + GAP)
		out.append(want)
		last = want
		last_reach = reach
	return out


## The most a body can reach either side of its orbit before its world is rolled:
## a planet as a broken one, a giant as the biggest.
static func _reach_most(b: Body) -> float:
	match b.kind:
		&"planet":
			return S_WORLD_MOST
		&"giant":
			return 19.0 * 2.2
	return reach_of(b)


## How far out a twin reaches from star A at the most, for separation `sep`,
## with every world as big as it can be: its opening zoom can then only be this
## or nearer, and nearer only clears the suns more. Not the Hellbender's place
## or a signed job's: they come and go, and must move nothing when they do
## (systemtest, contracttest), so while one is out past the edge the map opens
## a little further out and a world round a star stands nearer its sun than
## SIDE_PX (the Hellbender's 36 px take about half a pixel of it; counting it
## always instead spread five times as many pairs, 164 of 1,068, for nothing).
static func _twin_edge_most(L: SystemLayout, sep: float, lim_a: float, lim_b: float, outer: Array[int], jit: PackedFloat64Array) -> float:
	var bary_r := (1.0 - L.star_share) * sep
	var ext := maxf(bary_r + S_HI * lim_a * sep, L.star_share * sep + S_HI * lim_b * sep) + S_WORLD_MOST
	var po := _p_orbits(L, sep, outer, jit)
	for k in outer.size():
		ext = maxf(ext, po[k] + _reach_most(L.bodies[outer[k]]))
	return maxf(HI, bary_r + ext) + 30.0


## A twin star's close-orbit ring at zoom z: past its rail, and outside its drawn sun.
static func _twin_ring(r: float, z: float) -> float:
	return maxf(r + TWIN_RAIL + TWIN_RING, sun_drawn(r, z) / z + RING_OUT)


## The least orbit a world round a star of radius r needs at zoom z: its ring
## clear of the star's, and its disc clear of the drawn sun beside it.
static func _s_need(r: float, ring: float, z: float) -> float:
	return maxf(ring + RING_CLEAR + S_RING, (sun_drawn(r, z) + maxf(S_WORLD_MOST * z, WORLD_FLOOR) + SIDE_PX) / z)


## HOW FAR FROM THE LIGHT a body is: the distance from a lone sun that would
## give it the light it gets here, averaged round its orbit (round a circle of
## radius a, 1/d^2 from a star c from its centre averages 1/|c^2 - a^2|). Star A
## is as bright as a lone sun, star B as its drawn area of one. One star: the
## orbit.
func light_distance(b: Body) -> float:
	var flux := 0.0
	for p in stars():
		var c := star_pos(p).distance_to(b.host)
		var lum := pow(star_radius(p) / STAR_R[StarKind.ORDINARY], 2.0)
		flux += lum / maxf(absf(c * c - b.orbit * b.orbit), 1.0)
	return 1.0 / sqrt(flux)


## A twin's zone for a body, by its light: near, middle or far (one star's go by index).
func zone_of(b: Body) -> int:
	var d := light_distance(b)
	return 0 if d < ZONE_NEAR else (1 if d < ZONE_FAR else 2)


## A world's ring, by how much it weighs (giants biggest, small rocks least).
static func soi_of(b: Body) -> float:
	return (24.0 + b.mass * 2.4) * 1.6


## The least space between a world's ring and the star's close-orbit ring.
const RING_GAP := 24.0


## The map's slant (`SystemView.TILT`): an orbit's near side is this much of its
## radius below the star on screen.
const SLANT := 0.38
## How far a world's centre keeps from the star's edge when it passes in front.
const CLEAR := 22.0


## The clear space neighbouring orbits must leave between their bodies.
const GAP := 4.0


## How far a body reaches either side of its orbit: a giant's rings go out to
## 2.2 of its radius, a belt's rocks about 16 px, a contact's marker 4.
static func reach_of(b: Body) -> float:
	match b.kind:
		&"giant":
			return b.r * 2.2
		&"belt":
			return 16.0
		&"contact":
			return 4.0
	return maxf(b.r, 4.0)


## How deep the fabric sinks at a point on the plane, under the star and every
## body at their places `pos` (one per body, from `Body.pos`).
func sink(x: float, z: float, pos: Array[Vector2]) -> float:
	var r2 := x * x + z * z
	var D := star_mass * 0.8
	var w := 46.0 + star_r * 1.4
	var d := D * w * w / (r2 + w * w)
	for i in bodies.size():
		var b := bodies[i]
		if b.mass <= 0.0:
			continue
		var dx := x - pos[i].x
		var dz := z - pos[i].y
		d += b.mass * 0.9 * b.well_w * b.well_w / (dx * dx + dz * dz + b.well_w * b.well_w)
	return d


## Whether the Hellbender has a place in this system: anchored here, or its
## wreck lying here (where it died stays a place you can fly back to).
static func hellbender_here(n: MapGen.MapNode) -> bool:
	if Run.hellbender_alive() and Run.hellbender_at == n.index:
		return true
	for raw in n.jetsam:
		if (raw as MapGen.Jetsam).art == &"hellbender":
			return true
	return false


## The Hellbender's place in this layout, or -2 if it has none.
func hellbender_place() -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.hellbender:
				return bi
	return -2


## The core custodian's place in this layout, or -2 if it has none.
func core_place() -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.core:
				return bi
	return -2


## The station's place in this layout (the body its DOCK is on), or -2 if it
## has none: where the ship has to be to dock (`Router.at_station`).
func dock_place() -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.dock:
				return bi
	return -2


## The body an option sits on, or null (also for one on the star: `place_of`).
func body_of_option(i: int) -> Body:
	for b in bodies:
		for bc in b.beacons:
			if bc.opt == i:
				return b
	return null


## Where option i sits: a body's index, -1 the star, -2 nowhere.
func place_of(i: int) -> int:
	for bi in bodies.size():
		for bc in bodies[bi].beacons:
			if bc.opt == i:
				return bi
	for bc in star_beacons:
		if bc.opt == i:
			return -1
	return -2


## The beacons at place `body` (-1 the star's own events).
func beacons_at(body: int) -> Array[Beacon]:
	if body == -1:
		return star_beacons
	if body < 0 or body >= bodies.size():
		return []
	return bodies[body].beacons
