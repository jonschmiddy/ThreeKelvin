class_name MapGen
extends RefCounted

## Layers run edge to core and are laterally connected, so every death is self-authored.

## Development, security and berths are independent axes on purpose, so odd mixes exist.
enum Development { UNCLAIMED, OUTPOST, SETTLEMENT, CITY, CAPITAL }

## Derived from the axes at generation: five files branch on it, so one collapse is cheaper.
## Why: docs/why/MapGen.md#region-enum
enum Region { FRONTIER, TERRITORY, COSMOPOLITAN, LAWLESS, FAUNA, DEEP }
## The order is a save format: `type` is saved as an int, so changing it bumps the save version.
## Why: docs/why/MapGen.md#node-types
enum NodeType { START, STATION, CORE, PULSAR, SYSTEM }

## Zero on purpose: an absent field reads as the whole system, not a missing option.
## Why: docs/why/MapGen.md#option-ids
const OPTION_WHOLE := 0

## The shelf is indexed so it never shrinks: sold parts are marked in `taken`, not erased.
## Why: docs/why/MapGen.md#option-ids
const OPTION_SHOP := 100
## And the hull on the rack, which is one object rather than a list.
const OPTION_SHOP_HULL := 110

## The bag never shrinks either, and sits at 200 so the shelf has room to grow.
## Why: docs/why/MapGen.md#option-ids
const OPTION_BAG := 200

## Site ids never re-base or shrink: they are in saved `taken` arrays and the co-op claims.
## `RED` is named for the colour the chart paints, not for the flare hazard.
## Why: docs/why/MapGen.md#option-ids
enum Star { ORDINARY, RED, BLUE }

const OPTION_SITE := 300

## `GONE` is kept apart from `DONE`: resolved and no longer resolvable are opposite facts.
## Why: docs/why/MapGen.md#option-results
const R_SUCCESS := &"success"
const R_PARTIAL := &"partial"
const R_BOTCHED := &"botched"
const R_DONE := &"done"
const R_GONE := &"gone"
const RESULTS: Array[StringName] = [R_SUCCESS, R_PARTIAL, R_BOTCHED, R_DONE,
	R_GONE]

## Jetsam ids start at 1000 so no existing constant renumbers; the stride is a loose ceiling.
## Why: docs/why/MapGen.md#option-ids
const OPTION_JETSAM := 1000
const JETSAM_STRIDE := 64


## Wrecks and the floor are one class, so popup, claim, sweep and save share one thing.
## Why: docs/why/MapGen.md#jetsam
const SITE_ANY := -99


class Jetsam extends RefCounted:
	## Its slot in `MapNode.jetsam`, and what its claims are numbered from. Never
	## reused and never renumbered -- see `OPTION_JETSAM`.
	var slot: int = 0
	## The enemy template whose hull this is, or empty for the system's own pile.
	## Empty is what makes it the floor rather than a wreck.
	var art: StringName = &""
	## Which of that kind's pictures the hull was (`EnemyState.look`).
	var look: int = 0
	var label: String = "SECTOR LOOT"
	## Where in the system it lies (Jon, Oct 14); `SITE_ANY` keeps old saves' wrecks everywhere.
	## Why: docs/why/MapGen.md#jetsam
	var site: int = -9
	## MUST NOT SHRINK. A taken thing stays in it and is marked in `MapNode.taken`,
	## exactly as `shop` and `bag` learned to.
	var items: Array = []
	## Whether the sweep has already run on this one. Once per container, so
	## opening a wreck you have already been through is not a discovery.
	var scanned: bool = false
	## Once opened, what is left in a wreck also counts as sector loot (Jon, Oct 15).
	## Why: docs/why/MapGen.md#jetsam
	var opened: bool = false

	func is_wreck() -> bool:
		return art != &""


	## The grid title is asked of the container, since a shot wreck is salvage, not jetsam.
	## Why: docs/why/MapGen.md#jetsam
	func title() -> String:
		return "SALVAGE" if is_wreck() else "JETSAM"


	## The claim id of the i-th thing in here.
	func option(i: int) -> int:
		return OPTION_JETSAM + slot * JETSAM_STRIDE + i


## A view, never stored: each thing is claimed in its own container so lists never shrink.
## Why: docs/why/MapGen.md#sector-loot-view
class PileView extends Jetsam:
	## The system's pile, or null while nothing has been put down here.
	var pile: Jetsam = null
	## Per item: [the container it is in, its index there].
	var from: Array = []

	func add(h: Jetsam, i: int) -> void:
		items.append(h.items[i])
		from.append([h, i])

	func option(i: int) -> int:
		var f: Array = from[i]
		return (f[0] as Jetsam).option(int(f[1]))

## Few wide shells keep neighbours evenly spaced; `RING_SPACING` owns gap, `LAYERS` depth.
## Why: docs/why/MapGen.md#ring-layout
const LAYERS := 15

## Spacing along a ring, held constant so more layers do not inflate ring populations.
## Why: docs/why/MapGen.md#ring-layout
const RING_SPACING := 0.1157

## Nominal foreshortening, so `density = 1.0` means an ordinary galaxy's system count.
const SQUASH_REF := 0.62

## Parked at 1.00 (off): the sim pilot cannot route yet, so thinning would tune against it.
## Measured pick for later is 0.40: fast dive 21 jumps against about 38 farming.
## Why: docs/why/MapGen.md#door-share
const DOOR_SHARE := 1.00

## Two doors minimum, so one unlucky system placement never decides the whole run.
const MIN_DOORS := 2

## `RIM` is authored, not derived: the chart normalises against it without importing it.
## Why: docs/why/MapGen.md#ring-radii
const RIM := 0.92
const CORE := 0.11
## How far the rings bend from equal-area spacing toward tracking the galaxy's
## light. All the way packs the inner rings closer than a system glyph is wide.
const LIGHT_BLEND := 0.42

## The Core hole is applied here so `ring_count` and `galaxy_pos` agree on a ring's size.
## Why: docs/why/MapGen.md#ring-radii
static func ring_radius(layer: int) -> float:
	var rn := _ring_radius_raw(layer)
	# Galaxies with a hole in the middle have no systems in the hole.
	var hole: float = float(Run.galaxy.get("ring", 0.0))
	if hole > 0.0:
		rn = hole + rn * (1.0 - hole)
	return rn


## Private so callers use `ring_radius`: two callers disagreeing on the holed radius was the bug.
static func _ring_radius_raw(layer: int) -> float:
	if layer >= LAYERS - 1:
		return 0.0
	var depth := float(layer) / float(maxi(1, LAYERS - 2))
	var equal := sqrt(lerpf(RIM * RIM, CORE * CORE, depth))
	var k := maxf(1.0, float(Run.galaxy.core_pow))
	var lit := pow(lerpf(pow(RIM, 1.0 / k), pow(CORE, 1.0 / k), depth), k)
	return lerpf(equal, lit, LIGHT_BLEND)

## Ring size follows perimeter so neighbours are evenly spaced; danger tiers read through `tier()`.
## Why: docs/why/MapGen.md#ring-population
const DANGER_MAX := 10

static func tier(danger: int) -> int:
	return clampi((danger + 1) / 2, 1, 5)


## Display only, never in encounter prose: naming the tier reads the gate out loud.
## Why: docs/why/MapGen.md#danger-tiers
const TIER_NAMES: Array[String] = ["", "EASY", "ROUGH", "HARD", "BRUTAL", "LETHAL"]

static func tier_name(danger: int) -> String:
	return TIER_NAMES[tier(danger)]

const RING_MIN := 5
const RING_MAX := 60

static func ring_count(layer: int) -> int:
	if layer >= LAYERS - 1:
		return 1
	# Reads `density`, not `squash`: squash is a camera angle and must not change star counts.
	# Why: docs/why/MapGen.md#ring-population
	var den := float(Run.galaxy.get("density", 1.0))
	# Fixed `RING_SPACING`, not derived from `LAYERS`: that inflated the count to 528 from ~287.
	# Why: docs/why/MapGen.md#ring-population
	var target := RING_SPACING
	# Perimeter of the squashed ring, near enough for counting purposes.
	var r := ring_radius(layer)
	# Perimeter uses `SQUASH_REF`, so `density = 1.0` reproduces the nominal galaxy's counts.
	# Why: docs/why/MapGen.md#ring-population
	var perim := PI * r * (1.0 + SQUASH_REF) * den
	# Depth is read off the unholed schedule: the drawn radius would weight ring galaxies wrongly.
	# Why: docs/why/MapGen.md#ring-weighting
	var depth_r := _ring_radius_raw(layer)
	var f: float = clampf(1.0 - (depth_r - CORE) / maxf(0.001, RIM - CORE), 0.0, 1.0)
	# Weights flattened to 0.80-1.80 so one fixed jump radius works at every ring.
	# Why: docs/why/MapGen.md#ring-weighting
	var weight: float = lerpf(0.80, 1.80, pow(f, 1.6))
	return clampi(int(round(perim / maxf(0.001, target) * weight)),
		RING_MIN, RING_MAX)

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
	var berths: Array[StringName] = []
	## The dominant manufacturer, or empty. Loot rolls take a single manufacturer to bias to.
	var manufacturer: StringName = &""
	## Migration route. Independent of the social axes - whales do not care who
	## polices the sector.
	var fauna: bool = false

	## One star per system. Pulsar is not a star kind: `NodeType.PULSAR` already means it.
	## Why: docs/why/MapGen.md#system-fields
	var star: Star = Star.ORDINARY

	## Its own flag, not a `star` value: a system can have a flaring star and a gas giant.
	var gas_giant: bool = false

	## Ruling 20, Oct 30: decided off its own derive tag and saved like `star`.
	## Why: docs/why/MapGen.md#twin-suns
	var twin: bool = false

	## Computed once at generation: `admits` asks every option of every system, so no scans.
	var near_pulsar: bool = false
	var danger: int = 1
	var type: NodeType = NodeType.SYSTEM
	var visited: bool = false

	## Set by `RunState.chart_from` and never cleared; saved with the other run marks.
	var sensed: bool = false
	var cleared: bool = false
	## Lets the sector say something fed here instead of stripped; it makes the rival feel real.
	var eaten: bool = false
	## Not `cleared`: the hostile remains, and ENGAGE must not reappear right after a flight.
	## Why: docs/why/MapGen.md#system-fields
	var fled: bool = false
	## `taken` says which options are gone; one boolean cannot, once a system has several.
	## Why: docs/why/MapGen.md#option-state
	var taken: PackedInt32Array = PackedInt32Array()
	## `results` records what each spent option came to, so the stamp survives jumping away.
	## Why: docs/why/MapGen.md#option-state
	var results: Dictionary = {}
	## Yours alone in a party: written only by your own choice, never claimed or synced.
	## Why: docs/why/MapGen.md#option-state
	var left: Dictionary = {}
	var said: Dictionary = {}
	## Stored as a flag: arrival autosaves before the ambush resolves, so quitting cannot refuse it.
	## Why: docs/why/MapGen.md#ambush
	var ambush_pending: bool = false
	## Tells not rolled from rolled-and-empty, so a quiet arrival does not reroll on redraw.
	var ambush_rolled: bool = false
	var pos: Vector2 = Vector2.ZERO
	## Foreshortening already applied, so it is what the chart draws; links and fuel derive from it.
	var gal: Vector2 = Vector2.ZERO
	## Set from the same placement the chart draws, so a system that looks nebular is.
	var in_nebula: bool = false
	## And whether that cloud is lit from within.
	var nebula_emission: bool = false
	var links: PackedInt32Array = []
	## One pool per kill, not per ship, or the party was paid twice. It must not shrink.
	## Why: docs/why/MapGen.md#loot-pools
	var bag: Array = []

	## Separate from `bag`, whose claims are numbered from `OPTION_BAG`; new work uses `jetsam`.
	## Why: docs/why/MapGen.md#loot-pools
	var jetsam: Array = []

	## Stored as ids so a save survives table changes; rolled once before the autosave.
	## Why: docs/why/MapGen.md#option-state
	var options: Array[StringName] = []
	## Rolled once: a second roll would have one machine disagree about what is in the room.
	var bagged: bool = false
	## Populated lazily by StationScreen
	var shop: Array = []
	var shop_hull: HullData = null
	## Stocked once: `shop.is_empty()` let a bought-out shelf reroll into infinite parts and money.
	## Why: docs/why/MapGen.md#station-stock
	var stocked: bool = false
	## How many parts you have sold into this market. Every sale moves the price
	## down a little; see Market._saturation().
	var trades: int = 0
	var inspected: bool = false
	## On the node so a force-quit cannot reroll the enemy and make a bad draw free to reject.
	## Why: docs/why/MapGen.md#rolled-on-arrival
	var foes: Array[StringName] = []
	## Stored by title, not index, so inserting an event does not repoint saves.
	var event_key: String = ""

const _BAYER := ["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON", "ZETA", "ETA",
	"THETA", "IOTA", "KAPPA", "LAMBDA", "SIGMA", "TAU", "OMEGA"]
const _STEM := ["FLINT", "ABYSSAL", "GALLOWS", "KESTREL", "TALLOW", "MARROW",
	"CINDER", "HOLLOW", "VESPER", "BRINE", "AUGUR", "SABLE", "THORN", "GRIST",
	"MERIDIAN", "CALLOUS", "WICK", "FALLOW"]
const _SUFFIX := [" PRIME", " SECUNDUS", "-9", "-4", " V", " IX", " MINOR",
	" WATCH", " REACH", "-2", " III", " GATE"]

## Hashed from the index; `_combo` moves later collisions so no two systems share a name.
## Why: docs/why/MapGen.md#system-names
static func star_name(n: MapNode) -> String:
	if n.type == NodeType.CORE:
		return "THE CORE"
	var code := _combo(n.index)
	var c := code % _SUFFIX.size()
	var b := (code / _SUFFIX.size()) % _STEM.size()
	var a := code / (_SUFFIX.size() * _STEM.size())
	if n.type == NodeType.START:
		return "%s %s" % [_BAYER[a], _STEM[b]]
	return "%s %s%s" % [_BAYER[a], _STEM[b], _SUFFIX[c]]

## Depends on the index alone, so every machine and save agrees.
static var _names: PackedInt32Array = PackedInt32Array()
static var _used: Dictionary = {}

static func _combo(index: int) -> int:
	var total := _BAYER.size() * _STEM.size() * _SUFFIX.size()
	while _names.size() <= index:
		var i := _names.size()
		var h := (i + 1) * 2654435761
		var a := (h >> 3) % _BAYER.size()
		var b := (h >> 11) % _STEM.size()
		var c := (h >> 19) % _SUFFIX.size()
		var code := (a * _STEM.size() + b) * _SUFFIX.size() + c
		# The next suffix on the same two words, then onward. Only past `total`
		# systems (3024) does a name have to repeat, and no galaxy is that big.
		if _used.size() < total:
			while _used.has(code):
				code = (code + 1) % total
		_used[code] = true
		_names.append(code)
	return _names[index]

## Prose, not keys, and a constant so `-- maptest` can check its length against the enum.
const REGION_NAMES: Array[String] = ["Frontier", "Territory", "Cosmopolitan",
	"Lawless", "Migration Route", "Precursor Ruins"]

## Five nameable states, not a colour per manufacturer: the accent colours blur on a chart.
## `star_kind` avoids the `star_name` clash with the system namer.
## Why: docs/why/MapGen.md#system-colour
static func star_kind(n: MapNode) -> String:
	if n.type == NodeType.PULSAR:
		return "NEUTRON STAR"
	if n.type == NodeType.CORE:
		return "NOTHING THAT SHINES"
	match n.star:
		Star.RED: return "RED HYPERGIANT"
		Star.BLUE: return "BLUE HYPERGIANT"
	return "ORDINARY"


## Colour is the star's, not paperwork; fauna and lawless facts stay on tooltip and panel.
## Why: docs/why/MapGen.md#system-colour
static func star_colour(n: MapNode) -> Color:
	return swatch(n.type, n.star)


## One implementation for chart key and nodes, so the legend cannot drift from the map.
## Why: docs/why/MapGen.md#system-colour
static func swatch(t: NodeType, star: Star = Star.ORDINARY) -> Color:
	if t == NodeType.CORE:
		return Color("#d4614f")
	# The pulsar keeps its own, which is the point of it: a neutron star is not
	# a colour of starlight, it is a lighthouse.
	if t == NodeType.PULSAR:
		return Color("#8fd2e0")
	match star:
		Star.RED: return Color("#c05046")
		Star.BLUE: return Color("#5b8fd4")
	return Color("#cbd6e3")

## Built from the enum keys: a parallel array mislabelled four node types after 2026-08-27.
## Why: docs/why/MapGen.md#type-labels
static func type_label(t: NodeType) -> String:
	return NodeType.keys()[t]

## Title case rather than the enum's shouting, so it reads in a sentence.
const DEVELOPMENT_NAMES: Array[String] = ["Unclaimed", "Outpost", "Settlement",
	"City", "Capital"]

static func development_name(d: Development) -> String:
	return DEVELOPMENT_NAMES[d]

static func security_name(sec: int) -> String:
	return ["", "Lawless", "Minimal", "Moderate", "High", "Extreme"][clampi(sec, 1, 5)]

## The classification line: what kind of place, how policed, and who runs it.
static func place_line(n: MapNode) -> String:
	if n.type == NodeType.CORE:
		return "SUPERMASSIVE BLACK HOLE"
	if n.fauna:
		return "MIGRATION ROUTE - " + security_name(n.security).to_upper()
	var out := development_name(n.development).to_upper() \
		+ " - " + security_name(n.security).to_upper()
	if not n.berths.is_empty():
		var names: Array[String] = []
		for m in n.berths:
			names.append(DB.short_name(DB.manufacturer_name(m)).to_upper())
		out += " - " + " / ".join(names)
	return out

## One sentence on what being here means for you.
static func place_blurb(n: MapNode) -> String:
	if n.type == NodeType.CORE:
		return "Four million suns in one point. Ruins from whoever came first still orbit it. No manufacturer made any of it."
	if n.fauna:
		return "Megafauna live here. They give exotic materials, but there are no modules to find."
	if n.in_nebula:
		# Said in the sector blurb as well as drawn, because a player who has not
		# opened the chart lately should still know why the sky is moving.
		var gas := "The gas glows from a star still burning inside the cloud." 			if n.nebula_emission else "Cold gas, thick enough to hide in."
		return gas + " There is nothing else out here to see by."
	var who := ""
	match n.berths.size():
		0:
			# A station with no berth still posts work (Jon, Nov 3), for its dock desk.
			# Why: docs/why/MapGen.md#dock-desk
			var desk := Contracts.dock_desk(n)
			if desk != &"":
				who = "No manufacturer holds this space. Salvage is thin and random. %s posts work from a desk on the dock." \
					% DB.short_name(DB.manufacturer_name(desk))
			else:
				who = "No manufacturer holds this space. Salvage is thin and random."
		1: who = "One manufacturer dominates local salvage."
		_: who = "Contested. The stock is broad, and each manufacturer sets its own prices."
	var law := ""
	if n.security <= 2:
		law = " Contraband moves openly; fences carry good stock."
	elif n.security >= 4:
		law = " Inspections are thorough. Do not carry contraband here."
	return who + law

static func generate(canvas: Rect2) -> Array:
	var nodes: Array = []
	var idx := 0
	for layer in LAYERS:
		var count := ring_count(layer)
		# Spread over populated rings: the Core is never scaled, so `LAYERS - 1` skipped top tier.
		var ring_danger := 1 + int(round(layer * float(DANGER_MAX - 1)
			/ float(maxi(1, LAYERS - 2))))
		for row in count:
			var n := MapNode.new()
			n.index = idx
			idx += 1
			n.layer = layer
			n.row = row
			n.rows_in_layer = count
			# Jittered per system: a ring of equally bad systems has no decision in it.
			n.danger = clampi(ring_danger + Rng.world.randi_range(-1, 1), 1, DANGER_MAX)
			var depth := float(layer) / float(maxi(1, LAYERS - 1))
			if layer == 0 and row == 0:
				n.type = NodeType.START
			elif layer == LAYERS - 1:
				n.type = NodeType.CORE
			else:
				n.type = _pick_type()
			_roll_axes(n, depth)
			n.region = _derive_region(n)
			nodes.append(n)

	_layout(nodes, canvas)
	# Reach is applied once on the finished position; it is the dial for crossing cost.
	var reach := float(Run.galaxy.get("reach", 1.0)) * test_stretch
	if placement == Placement.PULL:
		for n in nodes:
			(n as MapNode).gal = galaxy_pos(n) * reach
	else:
		var at := spread_positions(nodes)
		for i in nodes.size():
			(nodes[i] as MapNode).gal = at[i] * reach
	_ensure_flyable(nodes)
	for n in nodes:
		var nn: MapNode = n
		var cloud := NebulaField.at(nn.gal)
		nn.in_nebula = cloud != null
		if cloud != null:
			nn.nebula_emission = cloud.emission
	_seed_pulsars(nodes)
	_place_stations(nodes)
	_mark_pulsar_neighbours(nodes)
	_roll_twins(nodes)

	_link(nodes)
	nodes[0].visited = true
	nodes[0].cleared = true
	# Marked taken like any finished system, or `cleared` and `taken` disagree after a save trip.
	# Why: docs/why/MapGen.md#start-node
	nodes[0].taken.append(OPTION_WHOLE)
	return nodes

## After placement a walk guarantees the slowest ship can reach the core (Oct 11).
## Seed 65867625 stranded its start at the rim; a start swap or ring bridge fixes that.
## Why: docs/why/MapGen.md#flyable-core
const FLY_MARGIN := 0.95
## (off only for `-- maptest norepair`, to count what the repair saves)
static var flyable_repair := true
## (`-- maptest stretch=K` only: every galaxy laid out K times wider, so walls
## the shipped galaxies almost never make are common, and the bridging is tested)
static var test_stretch := 1.0

static func _ensure_flyable(nodes: Array) -> void:
	if not flyable_repair:
		return
	var r: float = Run.JUMP_RADIUS * Run.study_radius_min() * FLY_MARGIN
	var core := -1
	for n in nodes:
		if (n as MapNode).type == NodeType.CORE:
			core = (n as MapNode).index
	if core < 0 or _flown(nodes, r, core).has(core):
		return
	# 1. THE START, if it is stranded where it was put
	if _near_count(nodes, 0, r) == 0:
		var best := -1
		var most := 0
		for i in range(1, nodes.size()):
			var n: MapNode = nodes[i]
			if n.layer != 0 or n.type == NodeType.CORE:
				continue
			var c := _near_count(nodes, i, r)
			if c > most:
				most = c
				best = i
		if best > 0:
			var g0: Vector2 = (nodes[0] as MapNode).gal
			(nodes[0] as MapNode).gal = (nodes[best] as MapNode).gal
			(nodes[best] as MapNode).gal = g0
	# 2. ANY WALL LEFT, bridged at its narrowest
	var sq := maxf(0.05, float(Run.galaxy.squash))
	for _pass in 64:
		var seen := _flown(nodes, r, core)
		if seen.has(core):
			return
		var bd := INF
		var pa := -1
		var pb := -1
		for i: int in seen:
			var a: MapNode = nodes[i]
			for j in nodes.size():
				var b: MapNode = nodes[j]
				if seen.has(j) or b.type == NodeType.CORE or absi(b.layer - a.layer) > 1:
					continue
				var d := hop_distance(a, b)
				if d < bd:
					bd = d
					pa = i
					pb = j
		if pb < 0:
			return
		# Moved round its own ring beside the reached one, nudged so the two never share a spot.
		var A: MapNode = nodes[pa]
		var B: MapNode = nodes[pb]
		var qa := Vector2(A.gal.x, A.gal.y / sq)
		var qb := Vector2(B.gal.x, B.gal.y / sq)
		var rb := qb.length()
		var th := qa.angle() + (RING_GAP * spread_gap * 0.5) / maxf(rb, 0.01) * (1.0 if wrapf(qb.angle() - qa.angle(), -PI, PI) >= 0.0 else -1.0)
		var q := Vector2(cos(th), sin(th)) * rb
		B.gal = Vector2(q.x, q.y * sq)


## Every system a ship with jump radius `r` can get to from the start: index ->
## true. Bucketed by `r`, so a walk costs about one look at each system.
static func _flown(nodes: Array, r: float, core: int) -> Dictionary:
	var sq := maxf(0.05, float(Run.galaxy.squash))
	var grid := {}
	var q := PackedVector2Array()
	q.resize(nodes.size())
	for i in nodes.size():
		var n: MapNode = nodes[i]
		q[i] = Vector2(n.gal.x, n.gal.y / sq)
		var key := Vector2i(floori(q[i].x / r), floori(q[i].y / r))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(i)
	var seen := {0: true}
	var frontier: Array[int] = [0]
	while not frontier.is_empty():
		var next: Array[int] = []
		for i in frontier:
			var a: MapNode = nodes[i]
			# (the last ring's free approach, as `RunState.reachable_from` grants it)
			if a.layer >= LAYERS - 2 and not seen.has(core):
				seen[core] = true
				next.append(core)
			var key := Vector2i(floori(q[i].x / r), floori(q[i].y / r))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var cell: Variant = grid.get(key + Vector2i(dx, dy))
					if cell == null:
						continue
					for j: int in cell:
						# (and two rings deeper at most, `RunState.too_deep`)
						if not seen.has(j) and q[i].distance_to(q[j]) <= r \
								and not Run.too_deep(a, nodes[j]):
							seen[j] = true
							next.append(j)
		frontier = next
	return seen


## How many systems sit within `r` of system i.
static func _near_count(nodes: Array, i: int, r: float) -> int:
	var c := 0
	for j in nodes.size():
		if j != i and hop_distance(nodes[i], nodes[j]) <= r:
			c += 1
	return c


## Computed once after `_seed_pulsars`, using the sight radius so close means one thing.
## Why: docs/why/MapGen.md#pulsar-neighbours
static func _mark_pulsar_neighbours(nodes: Array) -> void:
	var beacons: Array = []
	for raw in nodes:
		if (raw as MapNode).type == NodeType.PULSAR:
			beacons.append(raw)
	if beacons.is_empty():
		return
	for raw2 in nodes:
		var n: MapNode = raw2
		if n.type != NodeType.SYSTEM:
			continue
		for b in beacons:
			if hop_distance(n, b as MapNode) <= RING_SPACING * 2.0:
				n.near_pulsar = true
				break


## About one in four eligible systems; own stream (ruling 20, Oct 30), so no other roll moves.
## Why: docs/why/MapGen.md#twin-suns
const TWIN_CHANCE := 0.25
## Harness switch: 1 all, -1 none, 0 as the command line says.
static var twin_force := 0


static func _roll_twins(nodes: Array) -> void:
	var force := _twin_force()
	for raw in nodes:
		var n: MapNode = raw
		n.twin = false
		if not twin_ok(n):
			continue
		var roll := Rng.derive(&"twin", n.index).randf()
		n.twin = force > 0 or (force == 0 and roll < TWIN_CHANCE)


## Called Binary wherever a player reads it (Jon, Nov 1), not Two Suns.
## Why: docs/why/MapGen.md#twin-suns
const BINARY := "BINARY"


## Ordinary stars' ordinary systems only: not start, station, pulsar, core, or red or blue star.
static func twin_ok(n: MapNode) -> bool:
	return n.type == NodeType.SYSTEM and n.star == Star.ORDINARY


static func _twin_force() -> int:
	if twin_force != 0:
		return twin_force
	for a in OS.get_cmdline_user_args():
		if a == "twin=all" or a == "twin=close" or a == "twin=wide":
			return 1
		if a == "twin=none":
			return -1
	return 0


## Development tracks depth, with variance so a frontier city or deep pocket can still happen.
static func _roll_axes(n: MapNode, depth: float) -> void:
	if n.type == NodeType.CORE:
		# Nobody develops a black hole and nobody polices it. The social axes
		# do not apply to the thing at the centre of a galaxy.
		n.development = Development.UNCLAIMED
		n.security = 1
		return
	if n.type == NodeType.PULSAR:
		# Nothing is established by a neutron star; `_seed_pulsars` re-runs this to undo axes.
		# Why: docs/why/MapGen.md#pulsar-axes
		n.development = Development.UNCLAIMED
		n.security = 1
		n.berths.clear()
		n.manufacturer = &""
		n.fauna = false
		# (and a neutron star is one star, whatever the system had before)
		n.twin = false
		# No red or blue sky and no giant, or its events and chart row would offer them.
		n.star = Star.ORDINARY
		n.gas_giant = false
		return
	if n.type == NodeType.START:
		n.development = Development.OUTPOST
		n.security = 3
		return

	n.development = clampi(int(round(depth * 4.0 + Rng.world.randf_range(-1.1, 1.1))),
		0, 4) as Development
	# Security follows development loosely, skewed low so lawless space stays
	# common enough to matter - it is where the contraband economy lives.
	n.security = clampi(1 + int(n.development) + Rng.world.randi_range(-2, 1), 1, 5)

	# Nobody claims empty space; the deeper and richer it gets the more manufacturers
	# want a piece, and two or more competing is what a crossroads actually is.
	var want := 0
	match n.development:
		Development.UNCLAIMED: want = 1 if Rng.world.randf() < 0.2 else 0
		Development.OUTPOST: want = 1 if Rng.world.randf() < 0.7 else 0
		Development.SETTLEMENT: want = 2 if Rng.world.randf() < 0.4 else 1
		Development.CITY: want = 3 if Rng.world.randf() < 0.35 else 2
		Development.CAPITAL: want = 3 if Rng.world.randf() < 0.6 else 2
	var pool: Array = DB.manufacturers.keys()
	Rng.shuffle(Rng.world, pool)
	for i in mini(want, pool.size()):
		n.berths.append(pool[i])
	if not n.berths.is_empty():
		n.manufacturer = n.berths[0]

	# Megafauna keep to the thin places.
	n.fauna = n.berths.is_empty() and int(n.development) <= 1 and Rng.world.randf() < 0.3

	# Rolled off `Rng.world` so peers agree; rare on purpose, four systems in five stay ordinary.
	# Why: docs/why/MapGen.md#sky-roll
	var sky := Rng.world.randf()
	n.star = Star.RED if sky < 0.12 else (Star.BLUE if sky < 0.20 else Star.ORDINARY)
	n.gas_giant = Rng.world.randf() < 0.45

## Kept here, not in a panel, as several screens want it. A list, as a place can have several.
## Why: docs/why/MapGen.md#hazards
static func hazards(n: MapNode) -> PackedStringArray:
	var out := PackedStringArray()
	if n.type == NodeType.PULSAR:
		out.append("PULSAR")
	if n.in_nebula:
		out.append("NEBULA")
	if n.type == NodeType.CORE:
		out.append("EVENT HORIZON")
	return out

## HOW DEEP IS DEEP. The last four shells of fifteen -- far enough in that a
## run reaching them has committed to the ending rather than wandered into it.
const DEEP_FROM := LAYERS - 4

static func _derive_region(n: MapNode) -> Region:
	if n.type == NodeType.CORE:
		return Region.DEEP
	# Megafauna first: a herd outranks where the place is.
	if n.fauna:
		return Region.FAUNA
	# Depth outranks everything: the deep encounters need a dock, so DEEP cannot exclude berths.
	# Why: docs/why/MapGen.md#region-derivation
	if n.layer >= DEEP_FROM:
		return Region.DEEP
	if n.security <= 2 and not n.berths.is_empty():
		return Region.LAWLESS
	if n.berths.size() >= 2:
		return Region.COSMOPOLITAN
	if n.berths.size() == 1:
		return Region.TERRITORY
	return Region.FRONTIER

## The spiral, in one place. The chart draws its stars with this and the map
## places its systems with it, so a system lands in an arm rather than beside one.
static func shape_angle(r_norm: float, arm: int, along: float) -> float:
	return shape_angle_in(Run.galaxy, Run.galaxy_spin, r_norm, arm, along)

## The same spiral for a galaxy handed in rather than the run's: the chart's
## star field built on a worker (`MapChart.build_ahead`) reads a copy, never Run.
static func shape_angle_in(g: Dictionary, spin: float, r_norm: float, arm: int, along: float) -> float:
	var n := maxi(1, int(g.arms))
	# Includes the run's spin, so the arms turn with the systems rather than
	# the systems sliding around a fixed galaxy.
	var base := float(arm) * TAU / float(n) + spin
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

## Shipped PULL values (Jon, 2026-10-03); `-- sheet=GalaxyDump pulls` previews other strengths.
## Why: docs/why/MapGen.md#arm-pull
static var arm_pull := 0.9
static var arm_pull_cap := 3.0

## SPREAD is the default: PULL piled whole runs of a ring on one arm (Jon, 2026-10-04).
## Saves keep their positions, so only new runs change.
## Why: docs/why/MapGen.md#placement-modes
enum Placement { PULL, SPREAD }
static var placement := Placement.SPREAD

## A floor of zero would empty the dark between arms, a wall for a fixed jump radius.
## Why: docs/why/MapGen.md#placement-modes
static var arm_floor := 0.15

## Measured on the squashed chart as drawn, since overlap on screen is the fault.
static var spread_gap := 0.6

## SPREAD: how wide an arm is for the systems, as a share of the chart's arm.
static var arm_width := 1.0

## The gap between neighbouring rings before the light bends them inward: the
## unit `spread_gap` is counted in.
const RING_GAP := (RIM - CORE) / (LAYERS - 2.0)

## How many times SPREAD pushes crowded systems apart. Most galaxies are clear
## in under ten; the rest stop here and keep what they have.
const SPREAD_PASSES := 40

## How finely a ring's brightness is sampled for SPREAD, in steps round it.
const SPREAD_BINS := 360

## The map owns positions because links and fuel derive from them; two copies misprice jumps.
static func galaxy_pos(n: MapNode) -> Vector2:
	if n.type == NodeType.CORE:
		return Vector2.ZERO
	var g := Run.galaxy
	# The hole is inside ring_radius now -- applying it again here is what made
	# the counted ring and the drawn ring two different circles.
	var rn := ring_radius(n.layer)

	var rows := maxi(1, n.rows_in_layer)
	# Alternate rings are offset half a step so they interleave rather than
	# lining up into spokes.
	var half: float = 0.5 if n.layer % 2 == 1 else 0.0
	var astep := TAU / float(rows)

	# Hashed offsets break up the lattice without shifting between frames; seeded per run.
	var salt := (Run.galaxy_seed % 100003) * 31
	var jr := _frac(_hash2(n.index, n.layer, 101 + salt)) - 0.5
	var ja := _frac(_hash2(n.index, n.layer, 211 + salt)) - 0.5
	var rot := (_frac(_hash2(n.layer, 7, 307 + salt)) - 0.5) * astep * 0.55
	var r := rn + jr * 0.026
	var a := (float(n.row) + half) * astep + rot + ja * astep * 0.42 + Run.galaxy_spin

	# The cap is in neighbour widths: below 1.0 the pull is disabled, so it is 3.0.
	# At 4.0 the flyability gate failed once in 120, so staying well below is the margin.
	# Why: docs/why/MapGen.md#arm-pull-cap
	if int(g.arms) > 0:
		var arms := maxi(1, int(g.arms))
		var best := 0.0
		var closest := TAU
		for arm in arms:
			var d := wrapf(shape_angle(rn, arm, 0.0) - a, -PI, PI)
			if absf(d) < closest:
				closest = absf(d)
				best = d
		a += clampf(best * arm_pull, -astep * arm_pull_cap, astep * arm_pull_cap)

	return Vector2(cos(a), sin(a) * float(g.squash)) * r

## SPREAD lays rings out by brightness, then pushes close pairs apart; hashed, no `Rng.world` draw.
## Why: docs/why/MapGen.md#placement-modes
static func spread_positions(nodes: Array) -> PackedVector2Array:
	var g := Run.galaxy
	var sq := float(g.squash)
	var arms := int(g.arms)
	var salt := (Run.galaxy_seed % 100003) * 31
	var count := nodes.size()
	var rad := PackedFloat32Array()
	var ang := PackedFloat32Array()
	rad.resize(count)
	ang.resize(count)
	var rings: Dictionary = {}
	for i in count:
		var n: MapNode = nodes[i]
		if n.type == NodeType.CORE:
			continue
		if not rings.has(n.layer):
			rings[n.layer] = []
		(rings[n.layer] as Array).append(i)

	for layer in rings:
		var members: Array = rings[layer]
		var rows := members.size()
		var rn := ring_radius(layer)
		# Same offsets as `galaxy_pos`, so an armless galaxy is placed exactly as before.
		var half: float = 0.5 if layer % 2 == 1 else 0.0
		var astep := TAU / float(rows)
		var rot := (_frac(_hash2(layer, 7, 307 + salt)) - 0.5) * astep * 0.55
		var base := rot + Run.galaxy_spin
		var cdf := PackedFloat32Array()
		if arms > 0:
			cdf = _arm_cdf(rn, base, rows)
		for i in members:
			var n: MapNode = nodes[i]
			var jr := _frac(_hash2(n.index, n.layer, 101 + salt)) - 0.5
			var ja := _frac(_hash2(n.index, n.layer, 211 + salt)) - 0.5
			rad[i] = rn + jr * 0.026
			var slot := (float(n.row) + half + ja * 0.42) / float(rows)
			if arms > 0:
				ang[i] = base + _invert_cdf(cdf, fposmod(slot, 1.0)) * TAU
			else:
				ang[i] = base + slot * TAU

	# Crowded pairs separate along their rings, as the across-ring gap cannot change.
	var dmin := spread_gap * RING_GAP
	var px := PackedVector2Array()
	px.resize(count)
	var push := PackedFloat32Array()
	push.resize(count)
	# How far a radian round its ring moves each system on the chart.
	var pace := PackedFloat32Array()
	pace.resize(count)
	for _pass in SPREAD_PASSES:
		var grid: Dictionary = {}
		for i in count:
			px[i] = Vector2(cos(ang[i]), sin(ang[i]) * sq) * rad[i]
			pace[i] = maxf(0.001, rad[i] * Vector2(-sin(ang[i]), cos(ang[i]) * sq).length())
			push[i] = 0.0
			if (nodes[i] as MapNode).type == NodeType.CORE:
				continue
			var key := Vector2i(floori(px[i].x / dmin), floori(px[i].y / dmin))
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(i)
		var crowded := 0
		for key in grid:
			for i in grid[key]:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var near: Variant = grid.get(key + Vector2i(dx, dy))
						if near == null:
							continue
						for j in near:
							if j <= i:
								continue
							var sep: Vector2 = px[i] - px[j]
							var d := sep.length()
							if d >= dmin:
								continue
							crowded += 1
							var mid := ang[j] + wrapf(ang[i] - ang[j], -PI, PI) * 0.5
							var along_dir := Vector2(-sin(mid), cos(mid) * sq).normalized()
							var along := sep.dot(along_dir)
							var across2 := maxf(0.0, d * d - along * along)
							var need := (sqrt(maxf(0.0, dmin * dmin - across2)) - absf(along)) * 0.5
							var s := signf(along)
							if s == 0.0:
								s = 1.0
							push[i] += s * need / pace[i]
							push[j] -= s * need / pace[j]
		if crowded == 0:
			break
		for i in count:
			ang[i] += push[i] * 0.8

	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		if (nodes[i] as MapNode).type == NodeType.CORE:
			out[i] = Vector2.ZERO
		else:
			out[i] = Vector2(cos(ang[i]), sin(ang[i]) * sq) * rad[i]
	return out

## Arm bells match the chart's stars; steps are capped so crowded arms space evenly.
## Why: docs/why/MapGen.md#arm-brightness
static func _arm_cdf(rn: float, base: float, rows: int) -> PackedFloat32Array:
	var g := Run.galaxy
	var arms := maxi(1, int(g.arms))
	var hw := arm_half_width(rn)
	var scatter := float(g.chaos) * float(g.chaos) * 16.0 / 12.0
	var s1 := sqrt(hw * hw * arm_width * arm_width / 3.0 + scatter) + 0.04
	var ridge := PackedFloat32Array()
	for arm in arms:
		ridge.append(shape_angle(rn, arm, 0.0))
	var w := PackedFloat32Array()
	w.resize(SPREAD_BINS)
	var total := 0.0
	for m in SPREAD_BINS:
		var th := base + (float(m) + 0.5) * TAU / float(SPREAD_BINS)
		var v := 0.0
		for arm in arms:
			var d := wrapf(th - ridge[arm], -PI, PI)
			v += exp(-0.5 * d * d / (s1 * s1))
			# A wide arm reaches round the back of the ring as well.
			if s1 > 0.8:
				var e1 := d - TAU
				var e2 := d + TAU
				v += exp(-0.5 * e1 * e1 / (s1 * s1)) + exp(-0.5 * e2 * e2 / (s1 * s1))
		w[m] = v
		total += v
	var floor_share := clampf(arm_floor, 0.0, 1.0)
	var share := PackedFloat32Array()
	var cap := PackedFloat32Array()
	share.resize(SPREAD_BINS)
	cap.resize(SPREAD_BINS)
	var sq := float(g.squash)
	var bin := TAU / float(SPREAD_BINS)
	var room := float(rows) * spread_gap * RING_GAP
	for m in SPREAD_BINS:
		share[m] = floor_share / float(SPREAD_BINS) + (1.0 - floor_share) * w[m] / maxf(total, 0.000001)
		var th := base + (float(m) + 0.5) * bin
		cap[m] = bin * rn * Vector2(sin(th), cos(th) * sq).length() / maxf(room, 0.000001)
	# Water-filled: clip to the cap, hand the excess to the bins still under it.
	for _round in 12:
		var excess := 0.0
		var free := 0.0
		for m in SPREAD_BINS:
			if share[m] > cap[m]:
				excess += share[m] - cap[m]
				share[m] = cap[m]
			elif share[m] < cap[m]:
				free += share[m]
		if excess <= 0.000001 or free <= 0.0:
			break
		for m in SPREAD_BINS:
			if share[m] < cap[m]:
				share[m] += excess * share[m] / free
	var cdf := PackedFloat32Array()
	cdf.resize(SPREAD_BINS + 1)
	cdf[0] = 0.0
	for m in SPREAD_BINS:
		cdf[m + 1] = cdf[m] + share[m]
	# Normalised in case the ring cannot hold its systems at the gap at all.
	var sum := cdf[SPREAD_BINS]
	for m in SPREAD_BINS + 1:
		cdf[m] /= maxf(sum, 0.000001)
	return cdf

## One definition of arm half-width, shared by SPREAD, FIT and GalaxyDump.
static func arm_half_width(rn: float) -> float:
	var g := Run.galaxy
	var hw := 0.5 * (0.55 + 0.9 * rn) * float(g.spread)
	var bar: float = g.bar
	if bar > 0.0 and rn < bar:
		hw *= 0.22
	return hw

## Where `cdf` reaches `u`, as a fraction of the way round (0 to 1).
static func _invert_cdf(cdf: PackedFloat32Array, u: float) -> float:
	var hi := cdf.bsearch(u, true)
	var m := clampi(hi - 1, 0, SPREAD_BINS - 1)
	var span := cdf[m + 1] - cdf[m]
	var f := 0.0 if span <= 0.0 else clampf((u - cdf[m]) / span, 0.0, 1.0)
	return (float(m) + f) / float(SPREAD_BINS)

## Measured un-squashed (ruling D1, 2026-08-25): the tilt made north-south jumps cheaper.
## Why: docs/why/MapGen.md#jump-distance
static func hop_distance(a: MapNode, b: MapNode) -> float:
	var sq := maxf(0.05, float(Run.galaxy.squash))
	var pa := Vector2(a.gal.x, a.gal.y / sq)
	var pb := Vector2(b.gal.x, b.gal.y / sq)
	return pa.distance_to(pb)

## Pulsars derive from nebula shells, so the visible ring is the reason a place is dangerous.
## Why: docs/why/MapGen.md#pulsar-seeding
static func _seed_pulsars(nodes: Array) -> void:
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		# Remnants only: a planetary nebula leaves a white dwarf, not a neutron star.
		if cl.kind != NebulaField.Kind.REMNANT:
			continue
		# Reach is shell-relative with a floor, so hauling a system cannot wreck the layout.
		# Why: docs/why/MapGen.md#pulsar-seeding
		var reach: float = clampf(cl.radius * 2.2, 0.14, 0.20)
		# Nearest to the middle, because the middle is where the star was.
		var best: MapNode = null
		var closest := INF
		for n in nodes:
			var nn: MapNode = n
			if nn.type == NodeType.START or nn.type == NodeType.CORE:
				continue
			if nn.type == NodeType.PULSAR:
				continue
			if nn.gal.distance_to(cl.pos) > reach:
				continue
			var d: float = nn.gal.distance_to(cl.pos)
			if d < closest:
				closest = d
				best = nn
		if best == null:
			continue
		best.type = NodeType.PULSAR
		# The pulsar moves to the shell's centre; safe because `_link` has not run yet.
		# Why: docs/why/MapGen.md#pulsar-seeding
		best.gal = cl.pos
		# Strips the civilisation the axes gave it as an ordinary system; depth is ignored here.
		_roll_axes(best, 0.0)
		best.region = _derive_region(best)
		# Whatever else was true of the place, standing next to a neutron star
		# is the dangerous part.
		best.danger = maxi(best.danger, DANGER_MAX - 1)

## Thinned to about 36 a galaxy, none within a jump of another (Jon, Nov 3, S3).
## Makes no `Rng.world` draw, so every other roll stays the same.
## Why: docs/why/MapGen.md#station-thinning
const STATION_KEEP := 0.5

static func _place_stations(nodes: Array) -> void:
	var stations: Array = []
	for raw in nodes:
		if (raw as MapNode).type == NodeType.STATION:
			stations.append(raw)
	# 1. HALF KEPT. The keys are worked out once, not inside the sort: they are
	# distinct floats, so the order is the one the study's sort gave.
	var keep_key := {}
	for raw in stations:
		var k: MapNode = raw
		keep_key[k.index] = Rng.derive(&"station_keep", k.index).randf()
	stations.sort_custom(func(a: MapNode, b: MapNode) -> bool:
		return keep_key[a.index] < keep_key[b.index])
	var keep := int(round(float(stations.size()) * STATION_KEEP))
	for i in range(keep, stations.size()):
		(stations[i] as MapNode).type = NodeType.SYSTEM
	stations = stations.slice(0, keep)
	# 2. SPACED
	var gap_key := {}
	for raw in stations:
		var g: MapNode = raw
		gap_key[g.index] = Rng.derive(&"station_gap", g.index).randf()
	stations.sort_custom(func(a: MapNode, b: MapNode) -> bool:
		return gap_key[a.index] < gap_key[b.index])
	var kept: Array = []
	var extra: Array = []
	for raw in stations:
		if _clear_of_stations(raw as MapNode, kept):
			kept.append(raw)
		else:
			extra.append(raw)
	for raw in extra:
		var s: MapNode = raw
		s.type = NodeType.SYSTEM
		var best: MapNode = null
		var best_d := INF
		for raw2 in nodes:
			var c: MapNode = raw2
			if c.type != NodeType.SYSTEM or c == s or absi(c.layer - s.layer) > 1:
				continue
			if not _clear_of_stations(c, kept):
				continue
			var d := hop_distance(c, s)
			if d < best_d or (d == best_d and best != null and c.index < best.index):
				best_d = d
				best = c
		if best != null:
			best.type = NodeType.STATION
			kept.append(best)

## Further than a bare drive's jump from every station in `kept`.
static func _clear_of_stations(n: MapNode, kept: Array) -> bool:
	for raw in kept:
		if hop_distance(n, raw as MapNode) <= Run.JUMP_RADIUS:
			return false
	return true

static func _pick_type() -> NodeType:
	# No PULSAR here: `_seed_pulsars` places them against clouds; the other weights are untouched.
	# Why: docs/why/MapGen.md#type-weights
	var weights := [
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.STATION, NodeType.STATION, NodeType.STATION, NodeType.STATION,
		NodeType.STATION, NodeType.STATION, NodeType.STATION, NodeType.STATION,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
	]
	return Rng.pick(Rng.world, weights)

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
		# Coreward links go to the nearest system; doors roll from `Rng.world` so peers agree.
		# Why: docs/why/MapGen.md#linking
		var doors := 0
		for i in here.size():
			var n: MapNode = here[i]
			var ranked := _by_distance(n, next)
			if Rng.world.randf() >= DOOR_SHARE:
				continue
			_connect(n, ranked[0])
			doors += 1
			# A second route, but only if it is not much further than the first:
			# the point is a choice between comparable options, not a detour.
			if ranked.size() > 1 and Rng.world.randf() < 0.62:
				var d0 := hop_distance(n, ranked[0])
				var d1 := hop_distance(n, ranked[1])
				if d1 < d0 * 1.8:
					_connect(n, ranked[1])

		# Only the ring needs doors: the complete lateral cycle makes its systems reachable.
		# Why: docs/why/MapGen.md#linking
		while doors < MIN_DOORS and doors < here.size():
			var spare: Array = here.filter(func(x): return not _descends(x, next))
			if spare.is_empty():
				break
			var extra: MapNode = spare[Rng.world.randi() % spare.size()]
			_connect(extra, _by_distance(extra, next)[0])
			doors += 1
		# Lateral links join systems in angle order, the only construction that forms one cycle.
		# Why: docs/why/MapGen.md#linking
		var ring: Array = here.duplicate()
		ring.sort_custom(func(x, y) -> bool:
			return atan2((x as MapNode).gal.y, (x as MapNode).gal.x) 				< atan2((y as MapNode).gal.y, (y as MapNode).gal.x))
		for i in ring.size():
			if ring.size() < 2:
				break
			_connect(ring[i], ring[(i + 1) % ring.size()])

## Does this system already carry a link into the next ring?
static func _descends(n: MapNode, next: Array) -> bool:
	for t in next:
		if n.links.has((t as MapNode).index):
			return true
	return false


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
