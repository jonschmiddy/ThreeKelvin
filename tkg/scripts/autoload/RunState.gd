extends Node
## Everything that persists across a run: ship, cargo, economy, map position.
## Combat state lives in Combat.gd and is discarded when the fight ends.

var hull: HullData
var installed: Array[ModuleData] = []
var cargo: Array[ModuleData] = []

var hp: int = 35
var heat: int = 0
var heat_cap_bonus: int = 0
var scrap: int = 40
var exotic: int = 0
var fuel: int = 30
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
	fuel = 30
	dross = 0
	jumps = 0
	kills = 0
	won = false
	dead = false
	death_reason = ""
	found_hull = null
	whale_boon = false
	map = MapGen.generate(MAP_CANVAS)
	at = 0
	Sig.run_started.emit()
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	log_line("Reactor cold-started. The farlight is seven jumps coreward, at least.", &"big")

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

func fuel_cost_to(n: MapGen.MapNode) -> int:
	var lateral := n.layer == node_at().layer
	var factor := 0.6 if lateral else 1.0 + n.danger * 0.15
	return maxi(1, int(round(hull.fuel_factor * factor)))

func can_jump_to(n: MapGen.MapNode) -> bool:
	return node_at().links.has(n.index) and fuel >= fuel_cost_to(n)

## True while at least one link out of the current node is affordable.
func has_legal_jump() -> bool:
	for idx in node_at().links:
		if can_jump_to(map[idx]):
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
	n.visited = true
	jumps += 1
	Sig.resources_changed.emit()
	Sig.jumped.emit(index)
