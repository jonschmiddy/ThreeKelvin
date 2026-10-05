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
## - options that want a world share one about half the time;
## - no padding: one body is always there, and a system has as many more as
##   its options, its giant, its station and its belt make -- one, two or three
##   is normal (Jon: "I like the diversity and scarcity");
## - the core's custodian as a contact on the outermost orbit.
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
		return Vector3(cos(a) * orbit, 0.0, sin(a) * orbit)


var star: StarKind = StarKind.ORDINARY
var star_r: float = 16.0
var star_mass: float = 46.0
var bodies: Array[Body] = []
## How far out the outermost orbit reaches, plus a margin.
var edge: float = HI + 30.0


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

	# what each option wants to sit on
	var want: Array = []
	for i in n.options.size():
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
			var planets := order.filter(func(o): return o.kind == &"planet")
			if not planets.is_empty() and R.randf() < 0.5:
				var host: Dictionary = planets[int(R.randf() * planets.size())]
				host["also"] = (host.get("also", []) as Array) + [w[0]]
				continue
			order.append({"kind": &"planet", "opt": w[0]})
		else:
			order.append({"kind": w[1], "opt": w[0], "r": 3.0 if w[1] == &"derelict" else 0.0})
	if not order.any(func(o): return o.kind == &"planet"):
		order.insert(0, {"kind": &"planet"})
	if n.gas_giant and L.star != StarKind.PULSAR:
		order.insert(mini(order.size(), 2 + int(R.randf() * 2.0)), {"kind": &"giant"})
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

	# where each body falls, out from the star: which pool its world comes from
	for i in L.bodies.size():
		var f := 0.0 if L.bodies.size() == 1 else float(i) / float(L.bodies.size() - 1)
		L.bodies[i].zone = 0 if f < 0.34 else (1 if f < 0.7 else 2)
		L.bodies[i].index = i

	# what each world is
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
	var star_ring := (150.0 if L.star == StarKind.CORE else L.star_r + 44.0) + 35.0
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
	# EACH WORLD'S RING, sized by how much it weighs (giants biggest, small rocks
	# least) and spread for the wider system; nothing else has one
	for b in L.bodies:
		if b.world != &"":
			b.soi = soi_of(b)
	return L


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


## The body an option sits on, or null.
func body_of_option(i: int) -> Body:
	for b in bodies:
		for bc in b.beacons:
			if bc.opt == i:
				return b
	return null
