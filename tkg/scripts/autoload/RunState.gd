extends Node
## Everything that persists across a run: ship, cargo, economy, map position.
## Combat state lives in Combat.gd and is discarded when the fight ends.

var hull: HullData
var installed: Array[ModuleData] = []
var cargo: Array[ModuleData] = []
## Which galaxy this run is flown in. Chosen once at the start so the chart
## is the same shape all the way through — a map that changes shape is not a
## map. 0 two-arm spiral, 1 barred, 2 four-arm.
## Every system you have been to, in order. The route you actually took is the
## story of the run, and it should be on the chart.
var trail: PackedInt32Array = PackedInt32Array()
var galaxy_kind: int = 0
## The rolled parameters for THIS galaxy, and the seed its star field is built
## from. Both fixed for the life of the run: the chart rebuilds its stars from
## the seed, and the map derives system positions from the parameters, so either
## changing mid-run would redraw the sky and move the systems under the player.
var galaxy: Dictionary = {}
var galaxy_seed: int = 0
## How far the whole galaxy is turned. The run starts on the rim at the first
## row of the outermost shell, and that row sat at angle zero — so every run
## began on the right-hand edge of the disc. Turning the entire thing by a
## rolled angle, arms and systems together, moves the start anywhere around the
## rim without disturbing a single relative position.
var galaxy_spin: float = 0.0

## A galaxy exists before any run does — screens can be built and asked to draw
## before start_new_run() has rolled one — so it is never an empty dictionary.
func _ready() -> void:
	if galaxy.is_empty():
		galaxy = GalaxyGen.params(0).duplicate()
var galaxy_name: String = ""
var galaxy_title: String = ""

var hp: int = 35
var heat: int = 0
var heat_cap_bonus: int = 0
var scrap: int = 40
var exotic: int = 0
var fuel: int = 150
var dross: int = 0

var map: Array = []
var at: int = 0

var jumps: int = 0
var kills: int = 0
var won: bool = false
var dead: bool = false
var death_reason: String = ""

var found_hull: HullData = null      ## offered for transfer
var whale_boon: bool = false

const MAP_CANVAS := Rect2(60, 50, 900, 430)

func start_new_run() -> void:
	hull = (DB.hull_frames[1] as HullData).duplicate(true) as HullData
	hull.tier = 0
	hull.perk_id = &"salvage_rack"
	installed.clear()
	cargo.clear()
	for id in DB.STARTER_KIT:
		installed.append((DB.modules[id] as ModuleData).duplicate(true) as ModuleData)
	hp = max_hp()
	heat = 0
	heat_cap_bonus = 0
	scrap = 40
	exotic = 0
	fuel = 150
	dross = 0
	jumps = 0
	kills = 0
	won = false
	dead = false
	death_reason = ""
	found_hull = null
	whale_boon = false
	galaxy_kind = randi() % GalaxyGen.count()
	galaxy = GalaxyGen.roll(galaxy_kind)
	galaxy_seed = randi()
	galaxy_spin = randf() * TAU
	galaxy_name = GalaxyGen.roll_name()
	galaxy_title = GalaxyGen.roll_title()
	map = MapGen.generate(MAP_CANVAS)
	at = 0
	trail = PackedInt32Array([0])
	_range_cache.clear()
	Sig.run_started.emit()
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	log_line("Reactor cold-started. The core is twenty jumps coreward, at least.", &"big")

func log_line(text: String, kind: StringName = &"sys") -> void:
	Sig.log_line.emit(text, kind)

# ------------------------------------------------------------------ derived stats

func max_hp() -> int:
	return hull.max_hull

func heat_cap() -> int:
	return hull.heat_cap + heat_cap_bonus

func dissipation() -> int:
	var d := hull.dissipation
	if hull.perk_id == &"baffled_vents":
		d += 1
	return d

func reactor() -> int:
	var e := hull.reactor
	if hull.perk_id == &"overspec_reactor":
		e += 1
	if has_set(&"veyra", 5):
		e += 1
	return e

func hand_size() -> int:
	var h := hull.hand_size
	if has_set(&"redline", 3):
		h += 1
	return h

func slots_for(s: ModuleData.Slot) -> int:
	var c := hull.slots_for(s)
	if s == ModuleData.Slot.UTILITY and hull.perk_id == &"spare_bay":
		c += 1
	return c

func slots_used(s: ModuleData.Slot) -> int:
	var n := 0
	for m in installed:
		if m.slot == s:
			n += 1
	return n

func manufacturer_count(id: StringName) -> int:
	var n := 0
	for m in installed:
		if m.manufacturer == id:
			n += 1
	return n

## Set bonuses are the class system: identity is assembled, not chosen.
func has_set(id: StringName, threshold: int) -> bool:
	return manufacturer_count(id) >= threshold

func contraband_count() -> int:
	var n := 0
	for m in installed:
		if m.contraband:
			n += 1
	for m in cargo:
		if m.contraband:
			n += 1
	return n

func repair_cost_per_hull() -> int:
	return 1 if hull.perk_id == &"cheap_parts" else 2

func scrap_value_of(m: ModuleData) -> int:
	var v := m.scrap_value
	if hull.perk_id == &"salvage_rack":
		v = int(round(v * 1.5))
	return v

# --------------------------------------------------------------------- mutations

## Fly a pulsar's beam: the densest fuel in the galaxy, paid for in hull.
##
## The arithmetic lives here rather than in Router because the simulator has to
## be able to run it. Anything that only exists on a screen is invisible to the
## balance model, and a node type that hands out fuel and takes hull is exactly
## the kind of thing the model needs to see.
func harvest_pulsar() -> void:
	var n := node_at()
	if n.cleared:
		return
	n.cleared = true
	# Scales with danger, so a deep pulsar is both a better haul and a worse
	# idea — which is the shape of this whole map.
	var gain_fuel := 14 + n.danger * 2
	var gain_exotic := 1 + int(n.danger / 4)
	var burn := 6 + int(n.danger * 1.6)
	var gain_heat := 3 + int(n.danger / 3)

	fuel += gain_fuel
	exotic += gain_exotic
	heat += gain_heat
	log_line("Beam sweep. The tank fills in eleven seconds.", &"good")
	log_line("+%d fuel, +%d exotic." % [gain_fuel, gain_exotic], &"good")
	log_line("Hard radiation through the hull. +%d heat." % gain_heat, &"them")
	Sig.resources_changed.emit()
	# Last: it can end the run, and everything above has to have happened first.
	# Dying with the fuel aboard is the point of the trade.
	take_hull_damage(burn, "Cooked by a neutron star. The hull held; nothing inside it did.")

func take_hull_damage(amount: int, reason: String) -> void:
	hp -= amount
	Sig.resources_changed.emit()
	if hp <= 0:
		hp = 0
		die(reason)

func heal(amount: int) -> int:
	var gained := mini(amount, max_hp() - hp)
	hp += gained
	if gained > 0:
		Sig.resources_changed.emit()
	return gained

func add_scrap(n: int) -> void:
	scrap = maxi(0, scrap + n)
	Sig.resources_changed.emit()

func die(reason: String) -> void:
	dead = true
	death_reason = reason
	Sig.run_ended.emit(false, reason)

func win() -> void:
	won = true
	Sig.run_ended.emit(true, "You cross into the light.")

func install_module(m: ModuleData) -> void:
	if slots_used(m.slot) >= slots_for(m.slot):
		var worst: ModuleData = null
		for x in installed:
			if x.slot == m.slot and (worst == null or x.scrap_value < worst.scrap_value):
				worst = x
		if worst != null:
			installed.erase(worst)
			cargo.append(worst)
			log_line("Removed %s to make room." % worst.name, &"sys")
	cargo.erase(m)
	installed.append(m)
	log_line("Installed %s." % m.name, &"good")
	Sig.ship_changed.emit()

func uninstall_module(m: ModuleData) -> void:
	installed.erase(m)
	cargo.append(m)
	Sig.ship_changed.emit()

func scrap_module(m: ModuleData) -> void:
	var v := scrap_value_of(m)
	cargo.erase(m)
	add_scrap(v)
	log_line("Scrapped %s for %d scrap." % [m.name, v], &"good")
	Sig.ship_changed.emit()

func transfer_to_hull(h: HullData) -> void:
	# Shed anything that no longer fits, cheapest first.
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var cap: int = h.slots_for(s)
		if s == ModuleData.Slot.UTILITY and h.perk_id == &"spare_bay":
			cap += 1
		while slots_used(s) > cap:
			var worst: ModuleData = null
			for x in installed:
				if x.slot == s and (worst == null or x.scrap_value < worst.scrap_value):
					worst = x
			if worst == null:
				break
			installed.erase(worst)
			cargo.append(worst)
	var ratio := float(hp) / float(max_hp())
	hull = h
	hp = maxi(6, int(round(h.max_hull * ratio)))
	found_hull = null
	log_line("Transferred to %s. %s" % [h.display_name(), DB.perk_text(h.perk_id)], &"big")
	Sig.ship_changed.emit()
	Sig.resources_changed.emit()

# -------------------------------------------------------------------------- map

func node_at() -> MapGen.MapNode:
	return map[at]

## Fuel is distance. Not a flat lateral rate and a flat coreward rate — those
## made every jump on the chart cost the same 1 fuel no matter how far it
## plainly was, which is why the numbers beside the systems looked like
## decoration.
##
## An ordinary hop is about 0.11 of a disc radius now that the field is even,
## so this prices one at 1 fuel and a long reach across the cluster at 2.
##
## The attrition of the frontier no longer comes from each hop being dear — it
## comes from there being 42 systems on the rim ring and 14 at the core. Farming
## the edge is a long haul rather than an expensive one, which is a cleaner way
## to say the same thing.
const FUEL_PER_DISC_RADIUS := 10.0
const FUEL_MAX_HOP := 6

func fuel_cost_to(n: MapGen.MapNode) -> int:
	var d := MapGen.hop_distance(node_at(), n)
	return clampi(int(round(hull.fuel_factor * d * FUEL_PER_DISC_RADIUS)),
		1, FUEL_MAX_HOP)

## How many systems the drive can pick from. Range is whatever radius happens
## to enclose this many of your nearest neighbours, so it scales itself: half a
## disc out on the rim where systems are strung far apart, almost nothing near
## the core where they are packed.
##
## Deriving it from the FURTHEST charted link, as this first did, meant one long
## link inflated the radius and dragged a dozen distant systems into range with
## it — the lines that reached across the galaxy while ignoring the neighbour
## sitting right there.
const JUMP_NEIGHBOURS := 6
## Cleared whenever the map changes. Range is a pure function of a system and
## the galaxy, and working it out costs a pass over every system.
var _range_cache: Dictionary = {}

func range_from(here: MapGen.MapNode) -> float:
	var hit: float = _range_cache.get(here.index, -1.0)
	if hit >= 0.0:
		return hit
	var ds: Array[float] = []
	for n in map:
		var t: MapGen.MapNode = n
		if t.index == here.index:
			continue
		ds.append(MapGen.hop_distance(here, t))
	if ds.is_empty():
		_range_cache[here.index] = 0.0
		return 0.0
	ds.sort()
	# Relative to your CLOSEST neighbour, not a fixed count.
	#
	# Taking the sixth-nearest meant the drive always reached exactly six
	# systems — so out on the thin frontier it stretched across enormous gaps to
	# find them, and in the crowded deep galaxy it stopped short of things
	# sitting right next to you. Every neighbourhood looked identical however
	# dense the region actually was, which quietly threw away the whole point of
	# populating the rings unevenly.
	#
	# Anything within about two and a half times your nearest neighbour is close
	# enough to be a real option; past that it is a trek. Floored at the third
	# nearest so a sparse ring still offers a choice rather than a corridor, and
	# capped at the sixth so a dense one does not offer twenty.
	var nearest: float = ds[0]
	var lo: float = ds[mini(2, ds.size() - 1)]
	var hi: float = ds[mini(JUMP_NEIGHBOURS - 1, ds.size() - 1)]
	var r: float = clampf(nearest * 2.5, lo, hi) * 1.06
	_range_cache[here.index] = r
	return r

## Close enough to fly to. Pure distance, nothing else.
##
## There used to be a hard cap of one shell as well. It was a genuine necessity
## when range was a fixed radius wide enough to reach along a rim ring — that
## same radius reached most of the way to the core — but it stopped being one
## the moment range became relative to your nearest neighbour, which is local by
## construction. What it did keep doing was refusing a system you could plainly
## see was nearer than one it offered, because the nearer one happened to lie
## two rings in. A map that contradicts the picture is worse than a map that
## lets you cut a corner.
##
## Charted links do not grant passage either: a link is how generation
## guarantees the galaxy hangs together, not a promise that the place is near.
func reachable_from(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:
	if n.index == here.index:
		return false
	return MapGen.hop_distance(here, n) <= range_from(here)

func reachable(n: MapGen.MapNode) -> bool:
	return reachable_from(node_at(), n)

## The local cluster, as the chart draws it.
func in_range_of(here: MapGen.MapNode) -> Array:
	var out: Array = []
	for n in map:
		if reachable_from(here, n):
			out.append(n)
	return out

func in_range() -> Array:
	return in_range_of(node_at())

func jump_range() -> float:
	return range_from(node_at())

func can_jump_to(n: MapGen.MapNode) -> bool:
	return reachable(n) and fuel >= fuel_cost_to(n)

## True while at least one link out of the current node is affordable.
func has_legal_jump() -> bool:
	for n in map:
		if can_jump_to(n):
			return true
	return false

## Ends the run when no jump is affordable. Without this the ship sits on the
## chart alive and immobile forever — a soft-lock the simulator hit in 9% of runs.
## Call only after a node is fully resolved: a station refuel or an event can
## still rescue an empty tank, so checking on arrival would kill unfairly.
func check_stranded() -> void:
	if dead or won:
		return
	if not has_legal_jump():
		die("Adrift. The tank ran dry between stars.")

func jump_to(index: int) -> void:
	var n: MapGen.MapNode = map[index]
	if not can_jump_to(n):
		return
	fuel -= fuel_cost_to(n)
	at = index
	trail.append(index)
	n.visited = true
	jumps += 1
	Sig.resources_changed.emit()
	Sig.jumped.emit(index)
