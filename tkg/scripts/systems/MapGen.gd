class_name MapGen
extends RefCounted

## Procedural galaxy. Layers run edge -> core; danger and loot quality both
## climb coreward. Layers are fully connected laterally so you can farm a
## danger band before choosing to descend. That lateral freedom is what makes
## the greed clock work: every death is self-authored.

## A place is described by three independent axes rather than one label.
## Development is how built-up it is, security is how policed, and the maker
## list is who operates there - nobody, one house, or several competing. They
## are independent on purpose: a rich city with no law is a story, and so is a
## lone policed outpost at the edge of nothing.
enum Development { UNCLAIMED, OUTPOST, SETTLEMENT, CITY, CAPITAL }

## Kept, but no longer authored - derived from the axes at generation time.
## Loot bias, fauna pools, contraband stock and station inventory all branch on
## it across five files, and collapsing three axes onto one label in exactly one
## place beats teaching every one of those sites the new vocabulary.
enum Region { FRONTIER, TERRITORY, COSMOPOLITAN, LAWLESS, FAUNA, CORE }
enum NodeType { START, FIGHT, STATION, EVENT, DERELICT, GOAL }

## Eight shells, wide apart, rather than twenty-four thin ones.
##
## Twenty-four rings put the systems in a shape where nothing was near anything:
## a ring step was 0.03 of the disc while the gap between neighbours ON a rim
## ring was 0.51, a factor of seventeen. Neighbours along your own ring were
## half a galaxy away, and a system that looked adjacent was four rings deep and
## therefore unreachable. Eight shells with populations set by perimeter puts
## every neighbour at roughly the same distance in every direction, which is
## what makes "fly to anything close enough" a rule you can actually see.
##
## Run length does not come from the ring count — it comes from how many systems
## there are, and there are just as many.
const LAYERS := 9

## Where each ring sits, as a fraction of the disc radius. Lives here rather
## than in the chart because the map's populations are derived from it: if the
## two ever disagreed, ring counts would be weighted for radii the chart does
## not draw.
const RIM := 0.92
const CORE := 0.11
## How far the rings bend from equal-area spacing toward tracking the galaxy's
## light. All the way packs the inner rings closer than a system glyph is wide.
const LIGHT_BLEND := 0.42

## The Core is not a ring, it is the middle. Spreading the schedule across all
## LAYERS spent the innermost ring on the Core and then drew the Core at zero,
## which left a third of the disc radius — the brightest part of the galaxy —
## with nothing in it at all. The populated rings run RIM to CORE between them;
## the Core sits inside the lot.
static func ring_radius(layer: int) -> float:
	if layer >= LAYERS - 1:
		return 0.0
	var depth := float(layer) / float(maxi(1, LAYERS - 2))
	var equal := sqrt(lerpf(RIM * RIM, CORE * CORE, depth))
	var k := maxf(1.0, float(Run.galaxy.core_pow))
	var lit := pow(lerpf(pow(RIM, 1.0 / k), pow(CORE, 1.0 / k), depth), k)
	return lerpf(equal, lit, LIGHT_BLEND)

## How many systems a ring holds: enough that the gap between neighbours along
## it matches the gap between rings.
##
## This is what makes the field even, and it is worth being clear about the
## trade. Populations proportional to perimeter mean uniform density by AREA,
## not density that follows the galaxy's light — a rim ring carries 42 systems
## and a core ring 14 because the rim ring is enormous. Some light bias survives
## anyway, because the rings themselves are packed toward the core, so systems
## per unit area still rises as you go in. What is gone is the deliberate
## coreward crowding; what is bought is a map where your neighbours are your
## neighbours.
## Danger runs 1 to 10. The number you see is the fine-grained one; the systems
## whose balance was tuned against a five-tier ladder — enemy pools, loot rarity
## gates, hull tiers, station stock — read it through tier() instead, so widening
## the scale changed how precisely difficulty ramps without silently reweighting
## every drop table in the game.
const DANGER_MAX := 10

static func tier(danger: int) -> int:
	return clampi((danger + 1) / 2, 1, 5)

const RING_MIN := 5
const RING_MAX := 60

static func ring_count(layer: int) -> int:
	if layer >= LAYERS - 1:
		return 1
	var sq := float(Run.galaxy.squash)
	# The radial gap the ring spacing is aiming at, on average.
	var target := (RIM - CORE) / float(maxi(1, LAYERS - 2))
	# Perimeter of the squashed ring, near enough for counting purposes.
	var perim := PI * ring_radius(layer) * (1.0 + sq)
	return clampi(int(round(perim / maxf(0.001, target))), RING_MIN, RING_MAX)

class MapNode extends RefCounted:
	var index: int = 0
	var layer: int = 0
	var row: int = 0
	var rows_in_layer: int = 1
	## Derived from the axes below at generation time, never authored. Loot bias,
	## fauna pools, contraband stock and station inventory all branch on it.
	var region: Region = Region.FRONTIER
	var development: Development = Development.UNCLAIMED
	## 1 lawless ... 5 extreme.
	var security: int = 1
	## Who operates here. Empty is nobody's space; two or more is contested.
	var makers: Array[StringName] = []
	## The dominant house, or empty. Loot rolls take a single maker to bias to.
	var manufacturer: StringName = &""
	## Migration route. Independent of the social axes - whales do not care who
	## polices the sector.
	var fauna: bool = false
	var danger: int = 1
	var type: NodeType = NodeType.FIGHT
	var visited: bool = false
	var cleared: bool = false
	var pos: Vector2 = Vector2.ZERO
	## Where this system sits in the galaxy, as a fraction of the disc radius
	## with the disc's foreshortening already applied - so it is exactly what the
	## chart draws. Links and fuel costs are both derived from it, which is what
	## makes a long jump look long and cost more.
	var gal: Vector2 = Vector2.ZERO
	var links: PackedInt32Array = []
	## Populated lazily by StationScreen
	var shop: Array = []
	var shop_hull: HullData = null
	var inspected: bool = false

const _BAYER := ["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON", "ZETA", "ETA",
	"THETA", "IOTA", "KAPPA", "LAMBDA", "SIGMA", "TAU", "OMEGA"]
const _STEM := ["FLINT", "ABYSSAL", "GALLOWS", "KESTREL", "TALLOW", "MARROW",
	"CINDER", "HOLLOW", "VESPER", "BRINE", "AUGUR", "SABLE", "THORN", "GRIST",
	"MERIDIAN", "CALLOUS", "WICK", "FALLOW"]
const _SUFFIX := [" PRIME", " SECUNDUS", "-9", "-4", " V", " IX", " MINOR",
	" WATCH", " REACH", "-2", " III", " GATE"]

## A name, fixed for the life of the run. Hashed from the index rather than
## rolled, so the same system is called the same thing every time you look.
static func star_name(n: MapNode) -> String:
	if n.type == NodeType.GOAL:
		return "THE CORE"
	var h := (n.index + 1) * 2654435761
	var a := (h >> 3) % _BAYER.size()
	var b := (h >> 11) % _STEM.size()
	var c := (h >> 19) % _SUFFIX.size()
	if n.type == NodeType.START:
		return "%s %s" % [_BAYER[a], _STEM[b]]
	return "%s %s%s" % [_BAYER[a], _STEM[b], _SUFFIX[c]]

static func region_name(r: Region) -> String:
	return ["Frontier", "Territory", "Cosmopolitan", "Lawless", "Migration Route", "Precursor Ruins"][r]

## Colour follows the axes: one house flies its colours, several read as neutral
## trade, and unclaimed space is dim.
static func region_colour(n: MapNode) -> Color:
	if n.type == NodeType.GOAL:
		return Color("#d4614f")
	if n.fauna:
		return Color("#4a7a8a")
	if n.security <= 2 and not n.makers.is_empty():
		return Color("#7a5a3a")
	if n.makers.size() >= 2:
		return Color("#8fa3ba")
	if n.makers.size() == 1:
		return DB.manufacturer_colour(n.makers[0])
	return Color("#3a4a5c")

static func type_label(t: NodeType) -> String:
	return ["START", "FIGHT", "STATION", "EVENT", "DERELICT", "CORE"][t]

static func development_name(d: Development) -> String:
	return ["Unclaimed", "Outpost", "Settlement", "City", "Capital"][d]

static func security_name(sec: int) -> String:
	return ["", "Lawless", "Minimal", "Moderate", "High", "Extreme"][clampi(sec, 1, 5)]

## The classification line: what kind of place, how policed, and who runs it.
static func place_line(n: MapNode) -> String:
	if n.type == NodeType.GOAL:
		return "SUPERMASSIVE BLACK HOLE"
	if n.fauna:
		return "MIGRATION ROUTE - " + security_name(n.security).to_upper()
	var out := development_name(n.development).to_upper() \
		+ " - " + security_name(n.security).to_upper()
	if not n.makers.is_empty():
		var names: Array[String] = []
		for m in n.makers:
			names.append(DB.short_name(DB.manufacturer_name(m)).to_upper())
		out += " - " + " / ".join(names)
	return out

## One sentence on what being here means for you.
static func place_blurb(n: MapNode) -> String:
	if n.type == NodeType.GOAL:
		return "Four million suns in a point, and the ruins of whatever came first still orbiting it. Nothing here was manufactured."
	if n.fauna:
		return "Megafauna. Exotic materials, no module salvage."
	var who := ""
	match n.makers.size():
		0: who = "Nobody's space. Thin, random salvage."
		1: who = "One maker dominates local salvage."
		_: who = "Contested. Broad stock, and nobody agrees on a price."
	var law := ""
	if n.security <= 2:
		law = " Contraband moves openly; fences carry good stock."
	elif n.security >= 4:
		law = " Inspections are thorough. Do not be carrying anything."
	return who + law

static func generate(canvas: Rect2) -> Array:
	var nodes: Array = []
	var idx := 0
	for layer in LAYERS:
		var count := ring_count(layer)
		# Across the POPULATED rings, not across all of them. Dividing by
		# LAYERS - 1 put the top tier on the Core alone — and the Core is a
		# hand-tuned boss that is never danger-scaled, so a whole run could end
		# without a single top-tier fight. The innermost ring you can actually
		# stop at is now the worst place in the galaxy.
		var ring_danger := 1 + int(round(layer * float(DANGER_MAX - 1)
			/ float(maxi(1, LAYERS - 2))))
		for row in count:
			var n := MapNode.new()
			n.index = idx
			idx += 1
			n.layer = layer
			n.row = row
			n.rows_in_layer = count
			# Jittered per system, not flat per ring. Eight rings cannot land on
			# ten tiers evenly, and more to the point a ring where every system
			# is equally bad is a ring with no decision in it.
			n.danger = clampi(ring_danger + randi_range(-1, 1), 1, DANGER_MAX)
			var depth := float(layer) / float(maxi(1, LAYERS - 1))
			if layer == 0 and row == 0:
				n.type = NodeType.START
			elif layer == LAYERS - 1:
				n.type = NodeType.GOAL
			else:
				n.type = _pick_type()
			_roll_axes(n, depth)
			n.region = _derive_region(n)
			nodes.append(n)

	_layout(nodes, canvas)
	for n in nodes:
		(n as MapNode).gal = galaxy_pos(n)
	_link(nodes)
	nodes[0].visited = true
	nodes[0].cleared = true
	return nodes

## The rim is unclaimed and the core is built up - that is the whole shape of
## the journey, so development tracks depth directly. The variance is what stops
## it being a readout of the ring number: a city out on the frontier is worth the
## detour, and an unclaimed pocket deep in is worth the risk.
static func _roll_axes(n: MapNode, depth: float) -> void:
	if n.type == NodeType.GOAL:
		# Nobody develops a black hole and nobody polices it. The social axes
		# do not apply to the thing at the centre of a galaxy.
		n.development = Development.UNCLAIMED
		n.security = 1
		return
	if n.type == NodeType.START:
		n.development = Development.OUTPOST
		n.security = 3
		return

	n.development = clampi(int(round(depth * 4.0 + randf_range(-1.1, 1.1))),
		0, 4) as Development
	# Security follows development loosely, skewed low so lawless space stays
	# common enough to matter - it is where the contraband economy lives.
	n.security = clampi(1 + int(n.development) + randi_range(-2, 1), 1, 5)

	# Nobody claims empty space; the deeper and richer it gets the more houses
	# want a piece, and two or more competing is what a crossroads actually is.
	var want := 0
	match n.development:
		Development.UNCLAIMED: want = 1 if randf() < 0.2 else 0
		Development.OUTPOST: want = 1 if randf() < 0.7 else 0
		Development.SETTLEMENT: want = 2 if randf() < 0.4 else 1
		Development.CITY: want = 3 if randf() < 0.35 else 2
		Development.CAPITAL: want = 3 if randf() < 0.6 else 2
	var pool: Array = DB.manufacturers.keys()
	pool.shuffle()
	for i in mini(want, pool.size()):
		n.makers.append(pool[i])
	if not n.makers.is_empty():
		n.manufacturer = n.makers[0]

	# Megafauna keep to the thin places.
	n.fauna = n.makers.is_empty() and int(n.development) <= 1 and randf() < 0.3

## Collapse the three axes back onto the old label, once, here. Order matters:
## the most specific claim about a place wins.
static func _derive_region(n: MapNode) -> Region:
	if n.type == NodeType.GOAL:
		return Region.CORE
	if n.fauna:
		return Region.FAUNA
	if n.security <= 2 and not n.makers.is_empty():
		return Region.LAWLESS
	if n.makers.size() >= 2:
		return Region.COSMOPOLITAN
	if n.makers.size() == 1:
		return Region.TERRITORY
	return Region.FRONTIER

## The spiral, in one place. The chart draws its stars with this and the map
## places its systems with it, so a system lands in an arm rather than beside one.
static func shape_angle(r_norm: float, arm: int, along: float) -> float:
	var g := Run.galaxy
	var n := maxi(1, int(g.arms))
	var base := float(arm) * TAU / float(n)
	var bar: float = g.bar
	if bar > 0.0 and r_norm < bar:
		# Inside the bar the arms have not started: it is a straight spine
		# through the core, so angle barely varies with radius.
		return base + along * 0.22
	var t: float = r_norm
	if bar > 0.0:
		t = (r_norm - bar) / maxf(0.001, 1.0 - bar)
	return base + t * float(g.twist) + along

static func _hash2(i: int, j: int, salt: int) -> int:
	var h := (i * 374761393 + j * 668265263 + salt * 144665) & 0x7fffffff
	h = (h ^ (h >> 13)) & 0x7fffffff
	h = (h * 1274126177) & 0x7fffffff
	return (h ^ (h >> 16)) & 0x7fffffff

static func _frac(h: int) -> float:
	return float(h % 10000) / 10000.0

## Where a system sits, in units of the disc radius. The map owns this because
## links and fuel costs are derived from it - two copies would mean pricing a
## jump for a position nobody draws.
static func galaxy_pos(n: MapNode) -> Vector2:
	if n.type == NodeType.GOAL:
		return Vector2.ZERO
	var g := Run.galaxy
	var rn := ring_radius(n.layer)
	# Galaxies with a hole in the middle have no systems in the hole.
	var hole: float = g.ring
	if hole > 0.0:
		rn = hole + rn * (1.0 - hole)

	var rows := maxi(1, n.rows_in_layer)
	# Alternate rings are offset half a step so they interleave rather than
	# lining up into spokes.
	var half: float = 0.5 if n.layer % 2 == 1 else 0.0
	var astep := TAU / float(rows)

	# Exact rings at exact angles read as a lattice, not a galaxy. These offsets
	# are hashed from the node rather than rolled, so nothing shifts between
	# frames, and each is a fraction of one ring step so a neighbour stays one.
	# Seeded per run as well, or every galaxy scatters its systems in exactly
	# the same pattern — the same ring would always have the same wobble.
	var salt := (Run.galaxy_seed % 100003) * 31
	var jr := _frac(_hash2(n.index, n.layer, 101 + salt)) - 0.5
	var ja := _frac(_hash2(n.index, n.layer, 211 + salt)) - 0.5
	var rot := (_frac(_hash2(n.layer, 7, 307 + salt)) - 0.5) * astep * 0.55
	var r := rn + jr * 0.026
	var a := (float(n.row) + half) * astep + rot + ja * astep * 0.42

	# Drawn toward the nearest arm so systems sit in the bright lanes. Capped to
	# a fraction of a ring step: an uncapped pull sends adjacent rows to opposite
	# arms, which is how one-fuel jumps once crossed the whole galaxy.
	if int(g.arms) > 0:
		var arms := maxi(1, int(g.arms))
		var best := 0.0
		var closest := TAU
		for arm in arms:
			var d := wrapf(shape_angle(rn, arm, 0.0) - a, -PI, PI)
			if absf(d) < closest:
				closest = absf(d)
				best = d
		a += clampf(best * 0.75, -astep * 0.6, astep * 0.6)

	return Vector2(cos(a), sin(a) * float(g.squash)) * r

## How far apart two systems are, as the chart draws them, in disc radii.
static func hop_distance(a: MapNode, b: MapNode) -> float:
	return a.gal.distance_to(b.gal)

static func _pick_type() -> NodeType:
	var weights := [
		NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT,
		NodeType.STATION, NodeType.STATION,
		NodeType.EVENT, NodeType.EVENT,
		NodeType.DERELICT,
	]
	return weights.pick_random()

static func _layout(nodes: Array, canvas: Rect2) -> void:
	for n in nodes:
		var nn: MapNode = n
		var fx := float(nn.layer) / float(LAYERS - 1)
		nn.pos.x = canvas.position.x + fx * canvas.size.x
		if nn.rows_in_layer == 1:
			nn.pos.y = canvas.position.y + canvas.size.y * 0.5
		else:
			var fy := (float(nn.row) + 0.5) / float(nn.rows_in_layer)
			nn.pos.y = canvas.position.y + fy * canvas.size.y

static func _link(nodes: Array) -> void:
	for layer in LAYERS - 1:
		var here: Array = nodes.filter(func(n): return n.layer == layer)
		var next: Array = nodes.filter(func(n): return n.layer == layer + 1)
		# Coreward links go to whatever is actually nearest, not to whatever
		# shares a row index. Rings hold different numbers of systems and are
		# rotated and jittered against each other, so matching by index drew
		# routes that crossed other routes and skipped the neighbour in front.
		for i in here.size():
			var n: MapNode = here[i]
			var ranked := _by_distance(n, next)
			_connect(n, ranked[0])
			# A second route, but only if it is not much further than the first:
			# the point is a choice between comparable options, not a detour.
			if ranked.size() > 1 and randf() < 0.62:
				var d0 := hop_distance(n, ranked[0])
				var d1 := hop_distance(n, ranked[1])
				if d1 < d0 * 1.8:
					_connect(n, ranked[1])
		# Guarantee every forward system is reachable, again from its nearest.
		for t in next:
			var tt: MapNode = t
			var reachable := false
			for n in here:
				if (n as MapNode).links.has(tt.index):
					reachable = true
					break
			if not reachable:
				_connect(_by_distance(tt, here)[0], tt)
		# Full lateral connectivity within the layer: farm before you descend.
		for a in here:
			for b in here:
				if a != b and absi((a as MapNode).row - (b as MapNode).row) == 1:
					_connect(a, b)
		# Close the ring: the last row neighbours the first. A ring you can only
		# traverse one way is an arc, and farming it means doubling back through
		# nodes you have already cleared.
		if here.size() >= 3:
			_connect(here[0], here[here.size() - 1])

## Candidates sorted by how far they are from `from`, nearest first.
static func _by_distance(from: MapNode, pool: Array) -> Array:
	var out := pool.duplicate()
	out.sort_custom(func(x, y):
		return hop_distance(from, x) < hop_distance(from, y))
	return out

static func _connect(a: MapNode, b: MapNode) -> void:
	if not a.links.has(b.index):
		a.links.append(b.index)
	if not b.links.has(a.index):
		b.links.append(a.index)
