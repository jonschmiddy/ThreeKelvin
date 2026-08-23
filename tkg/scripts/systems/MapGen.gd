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
## PULSAR is last on purpose: type_label indexes this by value, and inserting
## in the middle would silently relabel every node type after it.
enum NodeType { START, FIGHT, STATION, EVENT, DERELICT, GOAL, PULSAR }

## The option id meaning "the system itself, all of it".
##
## Every encounter in the game today consumes the whole node: you strip the
## wreck, you win the fight, you answer the hail, and there is nothing else
## here. A system that offers three or four things to do consumes them one at a
## time, and this is the id reserved for the case where there is only one.
##
## Zero on purpose. It is what an absent field reads as, so a save or a message
## written before options existed says "the system" rather than "option zero of
## a list nobody wrote".
const OPTION_WHOLE := 0

## A station's shelf: `OPTION_SHOP + i` is the i-th part standing on it.
##
## The shelf is the second contested thing in the game, and the first that is a
## LIST. One station, four buyers, and one Legendary — the same shape as the
## wreck, except that a wreck is taken whole and a shelf is taken a part at a
## time. That is what the option id was for.
##
## INDEXED, WHICH MEANS THE ARRAY MUST NOT SHRINK. `n.shop` used to have the
## bought part erased out of it, which silently renumbered everything after it:
## one purchase and every machine's idea of "slot 2" disagreed. So a sold part
## stays on the shelf and is marked gone in `taken` instead, which is what that
## field has always been for.
##
## Based at 100 so the ids read as a namespace rather than as a count, and so a
## fourth kind of option added later has somewhere obvious to live.
const OPTION_SHOP := 100
## And the hull on the rack, which is one object rather than a list.
const OPTION_SHOP_HULL := 110

## What a shared kill left floating: `OPTION_BAG + i` is the i-th part in it.
##
## The third contested thing, and the second that is a LIST — so it is the
## shelf's shape rather than the wreck's, and for the same reason: a bag is taken
## a part at a time. `MapNode.bag` therefore never shrinks either. See `taken`.
##
## Based at 200 rather than 120 so the shelf keeps room to grow. A station that
## one day stocks more than ten parts must not start renumbering into the bag.
const OPTION_BAG := 200

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
	var r := ring_radius(layer)
	var perim := PI * r * (1.0 + sq)
	# Weighted toward the middle. Populations straight off the perimeter give
	# even spacing everywhere, which reads as a uniform grid of places — and it
	# puts most of the galaxy out on the rim, where the danger is lowest and
	# there is least reason to be. Tilting it inward means the frontier is
	# genuinely thin and the deep galaxy is genuinely crowded, which is the
	# shape of the run: sparse and safe at the edge, dense and lethal in.
	# The curve matters more than the endpoints. A linear tilt from 0.44 to 1.5
	# still put roughly the same number of systems on every ring — the perimeter
	# shrinks inward at almost the rate the weight grows, so they cancel and the
	# field comes out flat however the endpoints are set. Raising f to a power
	# breaks that cancellation: the weight stays low across the outer half and
	# then climbs steeply, which is what actually empties the frontier and packs
	# the deep galaxy. Areal density now runs about fifty to one from rim to
	# core, against six to one before.
	var f: float = clampf(1.0 - (r - CORE) / maxf(0.001, RIM - CORE), 0.0, 1.0)
	var weight: float = lerpf(0.14, 3.3, pow(f, 1.6))
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
	## Cleared by the Hellbender rather than by anybody in the party. The sector
	## reads it to say "something fed here" instead of "stripped", which is
	## most of what makes the rival feel like a rival. See RunState.hellbender_land.
	var eaten: bool = false
	## Contact was broken here and you have not left since. NOT the same as
	## cleared: the hostile is still out there, so returning re-engages, and
	## nothing was salvaged. It exists because the sector has to be able to tell
	## "you have not fought this yet" from "you just ran from it" — the first
	## offers ENGAGE, the second must not, or the button that got you out of a
	## fight is the same button that puts you back in one.
	var fled: bool = false
	## Which of this system's options have been used up, by option id.
	##
	## `cleared` says the system as a whole is finished; this says WHICH parts of
	## it are gone. They are not the same question the moment a system offers
	## more than one thing to do — one ship strips the wreck and another still
	## wants the fight, and a single boolean cannot hold that.
	##
	## Option `MapGen.OPTION_WHOLE` is the system itself, which is what every
	## encounter that exists today consumes. So a node with one thing to do
	## carries exactly one entry and the two fields agree, which is why nothing
	## reading `cleared` had to change.
	##
	## In a party this is a copy of what the host holds. See NetSession.claims.
	var taken: PackedInt32Array = PackedInt32Array()
	## What followed your heat trail in, rolled once on arrival. Stored on the
	## node for the same reason `foes` is: an ambush that re-rolled on resume
	## would be a hostile you could refuse by quitting and coming back cold,
	## which is save-scumming through the front door.
	var ambush: Array[StringName] = []
	## Whether the roll has HAPPENED, which is not the same as whether it hit.
	## Without this an empty `ambush` cannot be told from "not rolled yet", so a
	## quiet arrival would roll again on every redraw until something bit.
	var ambush_rolled: bool = false
	var pos: Vector2 = Vector2.ZERO
	## Where this system sits in the galaxy, as a fraction of the disc radius
	## with the disc's foreshortening already applied - so it is exactly what the
	## chart draws. Links and fuel costs are both derived from it, which is what
	## makes a long jump look long and cost more.
	var gal: Vector2 = Vector2.ZERO
	## Sitting inside one of the galaxy's gas clouds. Set at generation from the
	## same placement the chart draws, so a system that plainly looks like it is
	## in a nebula is one.
	var in_nebula: bool = false
	## And whether that cloud is lit from within.
	var nebula_emission: bool = false
	var links: PackedInt32Array = []
	## What the party's kill left floating, as `ModuleData`. See
	## `MapGen.OPTION_BAG` and `RunState.open_bag()`.
	##
	## ONE POOL, NOT ONE PER SHIP. Two ships used to each roll their own drop off
	## their own seat-salted stream, which is duplication solved and distribution
	## never attempted: the party was paid twice for one frigate. The bag is what
	## the kill was worth to the party, and who ends up carrying each part is a
	## decision somebody makes rather than a thing the game decides for them.
	##
	## Like `shop`, THIS ARRAY MUST NOT SHRINK — a taken part stays in it and is
	## marked gone in `taken`, or two machines stop agreeing what "part 2" is.
	var bag: Array = []
	## Rolled once, and never again. The same distinction `stocked` draws for the
	## shelf, and it exists here for a sharper reason: every machine in the party
	## rolls this bag independently off `Rng.derive(&"bag", index)`, so a second
	## roll is not a re-stock, it is one machine disagreeing with the others about
	## what is in the room.
	var bagged: bool = false
	## Populated lazily by StationScreen
	var shop: Array = []
	var shop_hull: HullData = null
	## Stocked ONCE, and never again.
	##
	## Not the same test as `shop.is_empty()`, which is what this used to be, and
	## the difference was an exploit: buying a shelf out emptied the array, so the
	## next visit re-rolled a full one. A station was an infinite supply of parts
	## and — before Market closed the other half of it — an infinite supply of
	## money. A station is a place, not a vending machine. What is on the shelf is
	## what somebody brought here, and when it is gone it is gone.
	var stocked: bool = false
	## How many parts you have sold into this market. Every sale moves the price
	## down a little; see Market._saturation().
	var trades: int = 0
	var inspected: bool = false
	## What is waiting here, rolled on arrival and then fixed for the life of the
	## run. [0] opens the fight and the rest are the pack.
	##
	## On the node rather than in Router for the same reason `shop` is: it has to
	## survive a save. Rolled at the moment the fight started, a force-quit and a
	## resume re-rolled the enemy, so a bad draw cost nothing to reject — which is
	## the one thing SaveGame's header says a suspend save must never buy.
	var foes: Array[StringName] = []
	## Which hail this system is offering, by title. Same reason as `foes`, and
	## the title rather than an index so that inserting an event into the table
	## does not silently repoint every save in flight at a different one.
	var event_key: String = ""

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
## What colour a system is drawn.
##
## Five states you can name, and deliberately NOT one colour per manufacturer.
##
## The maker colours are accents: small highlights on a module sprite, where
## being a few points apart is exactly right. Reused as the identity of a whole
## system they stopped working — redline and calyx are both muted greens within
## a hair of each other, probate and korvan are both browns, and cygnet sits on
## top of the unclaimed grey-blue. On a chart of a hundred and fifty icons that
## is not a code, it is noise that looks like a code.
##
## Which house holds a place is a detail you read when you point at one, and the
## tooltip and the panel both say it in words. What the chart has to carry at a
## glance is whether anyone holds it at all.
static func region_colour(n: MapNode) -> Color:
	if n.type == NodeType.GOAL:
		return Color("#d4614f")
	if n.type == NodeType.PULSAR:
		return Color("#8fd2e0")
	if n.fauna:
		return Color("#4a7a8a")
	if n.security <= 2 and not n.makers.is_empty():
		# Lawless but held: the one distinction worth a colour of its own,
		# because it changes what the place sells and what it does to you.
		return Color("#a9713d")
	if n.makers.size() >= 2:
		return Color("#93a8c2")
	if n.makers.size() == 1:
		return Color("#6f8296")
	return Color("#41505f")

static func type_label(t: NodeType) -> String:
	return ["START", "FIGHT", "STATION", "EVENT", "DERELICT", "CORE", "PULSAR"][t]

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
	if n.in_nebula:
		# Said in the sector blurb as well as drawn, because a player who has not
		# opened the chart lately should still know why the sky is moving.
		var gas := "Lit gas. Something inside this cloud is still burning." 			if n.nebula_emission else "Cold gas, thick enough to hide in."
		return gas + " Nothing else out here to see by."
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
			n.danger = clampi(ring_danger + Rng.world.randi_range(-1, 1), 1, DANGER_MAX)
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
	for n in nodes:
		var nn: MapNode = n
		var cloud := NebulaField.at(nn.gal)
		nn.in_nebula = cloud != null
		if cloud != null:
			nn.nebula_emission = cloud.emission
	_seed_pulsars(nodes)

	_link(nodes)
	nodes[0].visited = true
	nodes[0].cleared = true
	# And say so in the same vocabulary as everything else that finishes a
	# system. The start is consumed at generation rather than through
	# RunState.take_whole(), so without this it is the one node in the galaxy
	# whose `cleared` and `taken` disagree — and SaveGame infers the missing
	# entry when it reads an old save, which makes it disagree only AFTER a
	# round trip. That is exactly the shape of bug savetest exists to catch.
	nodes[0].taken.append(OPTION_WHOLE)
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
	if n.type == NodeType.PULSAR:
		# Nothing is established beside a neutron star. The beam sterilises
		# whatever it sweeps and the wind strips the rest, so there is no
		# outpost to police, no house with a claim on it, and nothing living
		# that migrates through — a pulsar is weather, not territory.
		#
		# Re-run rather than rolled in place: _seed_pulsars sets the type long
		# after the axes have been rolled, so it calls back into here to undo
		# them. The depth argument is ignored on this path.
		n.development = Development.UNCLAIMED
		n.security = 1
		n.makers.clear()
		n.manufacturer = &""
		n.fauna = false
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

	# Nobody claims empty space; the deeper and richer it gets the more houses
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
		n.makers.append(pool[i])
	if not n.makers.is_empty():
		n.manufacturer = n.makers[0]

	# Megafauna keep to the thin places.
	n.fauna = n.makers.is_empty() and int(n.development) <= 1 and Rng.world.randf() < 0.3

## Collapse the three axes back onto the old label, once, here. Order matters:
## the most specific claim about a place wins.
## What is wrong with a place, as short shouted words.
##
## Kept here rather than in the panel that happens to draw it, because a hazard
## is a fact about the sector and more than one screen wants to say it — the
## chart warns you before you commit the fuel, the sector screen reminds you
## once you are standing in it.
##
## Deliberately a LIST. Somewhere can be both inside a nebula and on top of a
## neutron star, and the honest answer then is both lines, not whichever one
## the code happened to test first. New hazards get added here and appear
## everywhere that asks, with no screen needing to learn about them.
static func hazards(n: MapNode) -> PackedStringArray:
	var out := PackedStringArray()
	if n.type == NodeType.PULSAR:
		out.append("PULSAR")
	if n.in_nebula:
		out.append("NEBULA")
	if n.type == NodeType.GOAL:
		out.append("EVENT HORIZON")
	return out

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
	# Includes the run's spin, so the arms turn with the systems rather than
	# the systems sliding around a fixed galaxy.
	var base := float(arm) * TAU / float(n) + Run.galaxy_spin
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
	var a := (float(n.row) + half) * astep + rot + ja * astep * 0.42 + Run.galaxy_spin

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

## Put a neutron star at the heart of every shell that has a system in it.
##
## Pulsars used to be rolled like any other node type, which put them wherever
## the dice fell — including out in clean space, where nothing had ever
## exploded. The object and its cause were unrelated.
##
## Now the cloud comes first and the pulsar is derived from it: a supernova
## remnant or a planetary nebula is a star's corpse, so if a system sits inside
## one, THAT is the system with the corpse in it. The consequence is that
## pulsars are properly scarce and unevenly spread — a galaxy can roll none,
## and one that rolls three has three shells to show for them — and that the
## ring you can see on the chart is the REASON the place is dangerous rather
## than decoration sitting next to it.
##
## Membership is NebulaField's own test at its own reach: the same one the
## sector screen asks to decide whether you are standing in gas. Two answers to
## "is this system inside that cloud" would agree exactly until one was edited.
static func _seed_pulsars(nodes: Array) -> void:
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		# REMNANTS ONLY. A planetary nebula is the envelope of a low-mass star
		# gently shrugging off its outer layers, and what it leaves behind is a
		# white dwarf — no collapse, no neutron star, no beam. Only a
		# core-collapse supernova leaves the thing this node is about.
		if cl.kind != NebulaField.Kind.REMNANT:
			continue
		# How far a system may be dragged to become this shell's pulsar.
		#
		# The test used to be "inside the cloud", which was the right question
		# when the pulsar stayed where it was. Now that it MOVES to the centre,
		# the only thing that matters is whether hauling it there wrecks the
		# layout — and a shell with no system quite inside it is a ring drawn
		# around nothing, which is worse than a system nudged half a cloud.
		#
		# Floored, because a planetary is small enough that a radius-relative
		# reach alone would almost never catch anything.
		var reach: float = clampf(cl.radius * 2.2, 0.14, 0.20)
		# Nearest to the middle, because the middle is where the star was.
		var best: MapNode = null
		var closest := INF
		for n in nodes:
			var nn: MapNode = n
			if nn.type == NodeType.START or nn.type == NodeType.GOAL:
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
		# And it MOVES to the middle of the shell. Picking the nearest system
		# and leaving it where the layout happened to put it meant the neutron
		# star sat somewhere on the ring it had supposedly thrown off — usually
		# right in the wall of it. The shell is gas expanding away from a point,
		# and the point is the pulsar; anywhere else and the picture argues with
		# itself.
		#
		# Safe to do here because gal is what everything downstream reads: _link
		# has not run yet, so the jump distances are measured from the new
		# position, and the chart draws from it too. The node keeps its layer,
		# so its depth and danger are untouched.
		best.gal = cl.pos
		# Strip whatever civilisation the axes gave it when it was still an
		# ordinary system. Depth is ignored for a pulsar, so the value passed
		# here does not matter.
		_roll_axes(best, 0.0)
		best.region = _derive_region(best)
		# Whatever else was true of the place, standing next to a neutron star
		# is the dangerous part.
		best.danger = maxi(best.danger, DANGER_MAX - 1)

static func _pick_type() -> NodeType:
	# No PULSAR here. A neutron star is not scattered at random across the
	# galaxy: it is what a big star leaves when it goes, and the only places
	# that happened are the shells still hanging where it stood. They are placed
	# by _seed_pulsars, against the clouds, once positions exist.
	#
	# The other weights are left exactly as they were, so removing pulsars from
	# the draw did not quietly change the mix of fights, stations, events and
	# wrecks along with it.
	var weights := [
		NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT,
		NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT,
		NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT,
		NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT, NodeType.FIGHT,
		NodeType.STATION, NodeType.STATION, NodeType.STATION, NodeType.STATION,
		NodeType.STATION, NodeType.STATION, NodeType.STATION, NodeType.STATION,
		NodeType.EVENT, NodeType.EVENT, NodeType.EVENT, NodeType.EVENT,
		NodeType.EVENT, NodeType.EVENT, NodeType.EVENT, NodeType.EVENT,
		NodeType.DERELICT, NodeType.DERELICT, NodeType.DERELICT, NodeType.DERELICT,
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
			if ranked.size() > 1 and Rng.world.randf() < 0.62:
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
