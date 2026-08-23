class_name SaveGame
extends RefCounted

## The run in progress, on disk. One slot, rewritten at every safe point.
##
## This is a SUSPEND SAVE, not a checkpoint. Loading deletes the file, and the
## file is rewritten from live state at the very next safe point — so there is
## never an older state on disk to go back to. Quitting is a bookmark. It is not
## a way to retry a fight you are losing or a jump you regret.
##
## That restraint is not fussiness. "Lateral map travel is always available and
## cheap, so every death is self-authored" is a design ruling, and it only means
## anything while a death is final. A reloadable save repeals the greed clock
## without appearing to change a single number.
##
## COMBAT IS DELIBERATELY OUTSIDE THE SAVE. A safe point is a moment when the
## only live state is RunState's, so restoring one cannot strand a half-resolved
## fight. The autosave lands immediately BEFORE a fight begins rather than after
## the jump that led to it, so force-quitting mid-fight costs you the fight, not
## the jump — you resume on the sector with the contact still there and ENGAGE
## still offered. It does refund the hull the fight had already taken, which is
## the one hole in this; closing it would mean serialising deck order, enemy
## intent loops, drones and charge timers for a case reached only by force-quit.

const PATH := "user://run.save"
## Bumped whenever the shape below changes. An old file is discarded rather than
## guessed at — a half-understood save produces a run that is subtly wrong,
## which is worse than no save at all.
## 2: the economy. `exotic` became the first row of a materials ledger, station
## stock stopped storing a price and started deriving one, and a node learned
## whether it has ever been stocked and how much has been sold into it.
## 3: heat reached the map. A node now carries whether it rolled for an ambush
## and what that roll produced, so a hostile attracted by your own heat cannot
## be refused by quitting and coming back cold.
## 6: a node carries the BAG a shared kill left in it, and whether one has been
## rolled. Stored by value like the shelf rather than re-derived: the roll is
## deterministic from the node, but its SIZE came from how many ships were in the
## fight, and nothing on a resumed map remembers that.
## 7: the contract ledger and house standing. A version 6 save has neither, so
## it resumes with an empty board and no accounts — which is survivable but
## silently loses work the player had already flown for.
## 8: the hold became a GRID. A part carries the cell it sits in, so a hold you
## arranged comes back arranged rather than re-packed from scratch.
## 9: the hellbender — where the galaxy's other harvester is, what hull it has
## left, and how many moves it has made (the counter is a seed source, so
## losing it would re-derive a different walk). A node also carries `eaten`:
## a save that forgot it would resume a derelict the rival stripped as one
## somebody in the party did.
##
## 8 rather than either side's number, and the reason is worth writing down: two
## branches both shipped a "6" — the shared-kill bag on one and the hold grid on
## the other — so a file stamped 6 could be either shape and there is no way to
## tell which from the number. This format has BOTH, so it is readable by
## neither, and taking a fresh number is the only answer that keeps the rule
## above true. Anything stamped 6 or 7 is now discarded, which is the correct
## outcome and the whole reason the field exists.
##
## AND THEN IT HAPPENED AGAIN AT 8. The hold grid and the hellbender were written
## on separate branches and both stamped 8, so an 8 can be either shape by
## exactly the argument above. 9 has both.
##
## Which says something the paragraph before it did not: the number is not the
## defence. It collides whenever two branches are open at once, and it will
## collide again. What actually keeps a wrong save from being loaded is the
## rule at the top -- an unreadable file is DISCARDED rather than guessed at --
## and the number is only how that rule recognises one. 8 is discarded now for
## the same reason 6 and 7 were.
const VERSION := 9

## Every rolled scalar on a hull. The frame supplies the art and the anchors; a
## saved hull is a frame plus the numbers LootGen rolled onto it.
const HULL_FIELDS: Array[String] = ["weight", "tier", "reactor", "hand_size",
	"max_hull", "heat_cap", "dissipation", "dodge", "initiative", "fuel_factor",
	"weapon_slots", "system_slots", "utility_slots", "sensors", "stealth"]

# --------------------------------------------------------------------- queries

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

## What the launcher prints on the CONTINUE button. Reads the file WITHOUT
## consuming it — only load_into_run() is allowed to do that.
static func summary() -> Dictionary:
	var d := _read()
	if d.is_empty():
		return {}
	return {
		galaxy = str(d.get("galaxy_title", "")),
		jumps = int(d.get("jumps", 0)),
		hp = int(d.get("hp", 0)),
		max_hp = int(d.get("max_hp", 0)),
		danger = int(d.get("danger", 1)),
		system = str(d.get("system", "")),
	}

# ---------------------------------------------------------------------- write

## Called from Router at every safe point. Cheap enough to be unconditional:
## the map is the bulk of it and a hundred and fifty nodes stringify in a
## millisecond or two, which is nothing beside the screen swap that triggered it.
##
## The map guard is doubled here and in Router._autosave() on purpose. This is
## the one function that writes, and _snapshot() indexes `Run.map[Run.at]` with
## nothing in front of it — a half-populated run reaching this call takes the
## process down rather than declining to write.
static func save() -> void:
	if Run.hull == null or Run.map.is_empty() or Run.dead or Run.won:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: could not open %s for writing (%d)" % [
			PATH, FileAccess.get_open_error()])
		return
	# full_precision, not the default. Without it JSON rounds floats hard enough
	# to move systems on the chart by a visible fraction of a pixel.
	#
	# It is still not bit-exact, and it is worth writing down what was measured
	# rather than leaving the next person to wonder: over 20,000 random floats,
	# 63% round-trip exactly and the worst relative error is 9.3e-14. That is
	# three orders of magnitude below single precision and it cannot reach any
	# observable in this game — fuel is int(round(distance * 10)), so flipping
	# one would need a distance sitting within 1e-13 of a .5 boundary.
	#
	# JSON is kept over FileAccess.store_var, which WOULD be bit-exact, because
	# a save you can read in a text editor is worth more during development than
	# fourteen digits nothing consults.
	f.store_string(JSON.stringify(_snapshot(), "", true, true))
	f.close()

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

static func _snapshot() -> Dictionary:
	var installed: Array = []
	for m in Run.installed:
		installed.append(_module_to(m))
	var cargo: Array = []
	for m in Run.cargo:
		cargo.append(_module_to(m))
	var nodes: Array = []
	for n in Run.map:
		nodes.append(_node_to(n))
	var here: MapGen.MapNode = Run.node_at()
	return {
		version = VERSION,
		# Denormalised for summary(). The launcher should not have to rebuild a
		# hundred and fifty map nodes to print one line of button text.
		system = MapGen.star_name(here),
		danger = here.danger,
		max_hp = Run.max_hp(),

		started_at = Run.started_at,
		galaxy_kind = Run.galaxy_kind,
		galaxy = Run.galaxy,
		galaxy_seed = Run.galaxy_seed,
		# Where every roll stream had got to. Without this, loading a run
		# rewinds them all to the start of the run, and the next module you
		# find is the first module you found. See Rng.state().
		rng = Rng.state(),
		galaxy_spin = Run.galaxy_spin,
		galaxy_name = Run.galaxy_name,
		galaxy_title = Run.galaxy_title,

		hull = _hull_to(Run.hull),
		installed = installed,
		cargo = cargo,
		found_hull = _hull_to(Run.found_hull) if Run.found_hull != null else null,

		hp = Run.hp,
		heat = Run.heat,
		heat_cap_bonus = Run.heat_cap_bonus,
		credits = Run.credits,
		# The whole ledger, not the one row that used to be a field. A material
		# added to DB.MATERIALS is saved by construction rather than by somebody
		# remembering to add a line here.
		materials = Run.materials.duplicate(),
		fuel = Run.fuel,
		dross = Run.dross.map(func(x: StringName) -> String: return String(x)),
		whale_boon = Run.whale_boon,
		# The ledger and the accounts. Both are RUN state — a contract points at a
		# node index in this galaxy and standing is spent inside this dive — so
		# both belong here and neither survives the dive ending.
		contracts = _contracts_to(),
		next_contract_id = Run.next_contract_id,
		standing = _standing_to(),

		map = nodes,
		at = Run.at,
		trail = Array(Run.trail),
		jumps = Run.jumps,
		kills = Run.kills,

		hellbender_at = Run.hellbender_at,
		hellbender_hp = Run.hellbender_hp,
		hellbender_max = Run.hellbender_max,
		hellbender_moves = Run.hellbender_moves,
		hellbender_ticks = Run.hellbender_ticks,
	}

# ----------------------------------------------------------------------- read

static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != VERSION:
		return {}
	return d

## Restores the run and consumes the file. True when a run is now live.
##
## The delete is the whole point of the model, but it also opens a window: a
## crash between here and the next safe point would lose the run. Router saves
## on the very next screen swap, which is the one this call is about to cause,
## so that window is a few milliseconds wide.
static func load_into_run() -> bool:
	var d := _read()
	if d.is_empty():
		clear()
		return false

	# Checked before the first write to Run, not after the last one. Everything
	# below overwrites the live run field by field, and this check used to sit
	# at the bottom — so a file with a good version and a truncated map returned
	# false having already left a hull, an economy and an empty map behind, and
	# the launcher this failure routes to autosaved that and indexed map[at].
	var saved_map: Variant = d.get("map", [])
	if typeof(saved_map) != TYPE_ARRAY or (saved_map as Array).is_empty():
		clear()
		return false

	Run.started_at = float(d.get("started_at", 0.0))
	Run.galaxy_kind = int(d.get("galaxy_kind", 0))
	Run.galaxy = _galaxy_from(Run.galaxy_kind, d.get("galaxy", {}))
	Run.galaxy_seed = int(d.get("galaxy_seed", 0))
	Rng.restore(d.get("rng", {"master": Run.galaxy_seed}))
	Run.galaxy_spin = float(d.get("galaxy_spin", 0.0))
	Run.galaxy_name = str(d.get("galaxy_name", ""))
	Run.galaxy_title = str(d.get("galaxy_title", ""))

	# The hull before the map: ring_radius() reads Run.galaxy, and half the
	# screens read Run.hull the moment a signal reaches them.
	Run.hull = _hull_from(d.get("hull", {}))
	var installed: Array[ModuleData] = []
	for e in d.get("installed", []):
		var m := _module_from(e)
		if m != null:
			installed.append(m)
	Run.installed = installed
	# A save written before mounts existed carries -1 on every fitted part, which
	# reads as "in the hold" and would draw a fully-armed ship with an empty rack.
	# Anything unplaced gets the first free hardpoint, so an old file loads as the
	# same loadout in a tidy arrangement rather than as a ship with no guns on it.
	for m in Run.installed:
		if m.mount < 0:
			m.mount = Run.free_mount(m.slot)
	var cargo: Array[ModuleData] = []
	for e in d.get("cargo", []):
		var m := _module_from(e)
		if m != null:
			cargo.append(m)
	Run.cargo = cargo
	# Anything that came back without a cell — a pre-grid save, or a part whose
	# position no longer fits the hull it was loaded onto — gets one now. Done
	# AFTER the assignment because repack_hold reads Run.cargo, and after the
	# hull is set for the same reason: the grid's shape is the hull's.
	var unplaced := false
	for m in Run.cargo:
		if m.hold_at.x < 0 or not Run.can_place(m, m.hold_at):
			unplaced = true
			break
	if unplaced:
		Run.repack_hold()
	var fh: Variant = d.get("found_hull", null)
	Run.found_hull = _hull_from(fh) if typeof(fh) == TYPE_DICTIONARY else null

	Run.hp = int(d.get("hp", 1))
	Run.heat = int(d.get("heat", 0))
	Run.heat_cap_bonus = int(d.get("heat_cap_bonus", 0))
	Run.credits = int(d.get("credits", 0))
	# JSON hands back String keys and float values; the ledger is StringName to
	# int. Rebuilt entry by entry rather than assigned wholesale, because a
	# dictionary that compares equal but hashes its keys as Strings prints
	# differently from the one it replaced — and that difference is the sort of
	# thing that gets chased for an hour later.
	var mats: Dictionary = {}
	var saved_mats: Variant = d.get("materials", {})
	if typeof(saved_mats) == TYPE_DICTIONARY:
		for k in (saved_mats as Dictionary).keys():
			mats[StringName(str(k))] = int((saved_mats as Dictionary)[k])
	Run.materials = mats
	Run.fuel = int(d.get("fuel", 0))
	# A save written when dross was a COUNT restores as that many Dross, which is
	# exactly what it meant at the time. Nothing is lost and nothing is invented.
	var raw: Variant = d.get("dross", [])
	var ids: Array[StringName] = []
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		for i in int(raw):
			ids.append(&"dross")
	else:
		for x in (raw as Array):
			ids.append(StringName(x))
	Run.dross = ids
	Run.whale_boon = bool(d.get("whale_boon", false))
	Run.contracts = _contracts_from(d.get("contracts", []))
	Run.next_contract_id = maxi(1, int(d.get("next_contract_id", 1)))
	# ZEROED, not restored — these two are deliberately outside the save, so a
	# load has to clear them the way `start_new_run()` does. Without it, SAVE &
	# QUIT to the launcher and CONTINUE inside the same process carries the
	# previous run's haul count and its dismissed salvage rail into the loaded
	# one: the rail stays shut in-session and opens after a cold start, which is
	# the same save behaving two different ways.
	Run.hauls = 0
	Run.salvage_hushed_hauls = -1
	Run.salvage_hushed_bag = -1
	var stand: Dictionary = {}
	var saved_stand: Variant = d.get("standing", {})
	if typeof(saved_stand) == TYPE_DICTIONARY:
		for k in (saved_stand as Dictionary).keys():
			# Filtered against the catalogue: a house that no longer exists is
			# standing the player can never spend and a row they can never clear.
			var house := StringName(str(k))
			if DB.manufacturers.has(house):
				stand[house] = int((saved_stand as Dictionary)[k])
	Run.standing = stand

	var map: Array = []
	for e in saved_map:
		map.append(_node_from(e))
	Run.map = map
	Run.at = clampi(int(d.get("at", 0)), 0, maxi(0, map.size() - 1))
	var trail := PackedInt32Array()
	for i in d.get("trail", []):
		trail.append(int(i))
	Run.trail = trail
	Run.jumps = int(d.get("jumps", 0))
	Run.kills = int(d.get("kills", 0))

	# Clamped like `at`, because a stale index here is not a wrong marker — it
	# is an index error inside whatever reads the hellbender's node next.
	Run.hellbender_at = clampi(int(d.get("hellbender_at", -1)), -1, map.size() - 1)
	Run.hellbender_max = maxi(0, int(d.get("hellbender_max", 0)))
	Run.hellbender_hp = clampi(int(d.get("hellbender_hp", 0)), 0, Run.hellbender_max)
	Run.hellbender_moves = maxi(0, int(d.get("hellbender_moves", 0)))
	Run.hellbender_ticks = maxi(0, int(d.get("hellbender_ticks", 0)))

	Run.won = false
	Run.dead = false
	Run.death_reason = ""
	# Jump range is a pure function of a system and the galaxy, and both just
	# changed underneath it.
	Run._range_cache.clear()

	clear()
	Sig.run_started.emit()
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	Run.log_line("Reactor warm. Resuming from %s." % MapGen.star_name(Run.node_at()), &"big")
	return true

# --------------------------------------------------------------- galaxy params

## JSON has one number type, so a round-trip turns every int in the parameter
## block into a float — and `arms` is a loop count. Rebuilding from the KIND
## template and coercing each saved value to the template's type restores the
## rolled numbers without restoring them as the wrong type.
static func _galaxy_from(kind: int, saved: Variant) -> Dictionary:
	var out: Dictionary = GalaxyGen.params(kind).duplicate()
	if typeof(saved) != TYPE_DICTIONARY:
		return out
	for raw_key in (saved as Dictionary).keys():
		# JSON hands back String keys; the template's are StringName. Godot
		# hashes the two alike so lookups work either way, but a String key
		# added beside StringName ones makes the restored dictionary print
		# differently from the one it copied — and that difference is the sort
		# of thing that gets chased for an hour later.
		var k := StringName(str(raw_key))
		var v: Variant = (saved as Dictionary)[raw_key]
		if out.has(k):
			match typeof(out[k]):
				TYPE_INT: v = int(v)
				TYPE_FLOAT: v = float(v)
				TYPE_BOOL: v = bool(v)
				TYPE_STRING: v = str(v)
		else:
			# `hole` is rolled rather than authored, so it has no template entry.
			v = float(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else v
		out[k] = v
	return out

# -------------------------------------------------------------------- modules

## A module is a template id plus what LootGen rolled onto it. Affixes are
## stored by name and resolved back to the shared DB instances, which is how
## they are held during a run too — LootGen picks out of a shallow duplicate.
##
## There used to be a "price" meta in here as well, because a station stamped one
## on its stock and a shelf that came back without it silently held a sale.
## Market removed the whole class of problem: a price is a function of the place
## and the part, computed when it is asked for, so there is no longer a price
## anywhere to lose. A derived number that is saved is a second copy of the
## truth, and it only ever goes one way.
static func _module_to(m: ModuleData) -> Dictionary:
	var affixes: Array = []
	for a in m.affixes:
		affixes.append(a.name)
	return {
		id = String(m.id),
		rarity = int(m.rarity),
		scrap_value = m.scrap_value,
		affixes = affixes,
		# Which hardpoint it is bolted to. Without this a resumed ship keeps every
		# part it had and rearranges them, because -1 is "in the hold" and the
		# refit screen would draw a full rack of empty mounts over a full loadout.
		mount = m.mount,
		turned = m.turned,
		hold_at = [m.hold_at.x, m.hold_at.y],
	}

## Null when the id is gone from the database — content changed under a save.
## The module is dropped and the rest of the run loads, which beats refusing the
## whole file over one retired part.
static func _module_from(e: Variant) -> ModuleData:
	if typeof(e) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = e
	var id := StringName(str(d.get("id", "")))
	if not DB.modules.has(id):
		push_warning("SaveGame: dropped unknown module '%s'" % id)
		return null
	var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
	m.rarity = int(d.get("rarity", int(m.rarity))) as ModuleData.Rarity
	m.scrap_value = int(d.get("scrap_value", m.scrap_value))
	m.mount = int(d.get("mount", -1))
	m.turned = bool(d.get("turned", false))
	# Version 6. A save from before the hold was a grid carries no position, and
	# -1,-1 is exactly what a part not yet placed looks like — so the loader
	# below re-packs those rather than leaving them claiming no cells.
	var at: Array = d.get("hold_at", [-1, -1])
	m.hold_at = Vector2i(int(at[0]), int(at[1])) if at.size() == 2 else -Vector2i.ONE
	var affixes: Array[AffixData] = []
	for want in d.get("affixes", []):
		for a in DB.affixes:
			if a.name == str(want):
				affixes.append(a)
				break
	m.affixes = affixes
	return m

# ---------------------------------------------------------------------- hulls

## `manufacturer` is written alongside perk_id rather than added to HULL_FIELDS,
## and that is not a style choice: the restore loop below coerces every listed
## field to int or float, so a StringName in that list would come back as 0.
##
## It is written at all — rather than inherited from the frame matched by name —
## because who built your hull decides a set bonus. The name lookup happens to
## resolve it today, but its fallback is hull_frames[1], an UNBRANDED frame, so
## any save whose hull name stopped matching would silently cost you a set piece
## and nothing would report it.
static func _hull_to(h: HullData) -> Dictionary:
	var d := {name = h.name, perk_id = String(h.perk_id),
		manufacturer = String(h.manufacturer)}
	for f in HULL_FIELDS:
		d[f] = h.get(f)
	return d

static func _hull_from(e: Variant) -> HullData:
	var d: Dictionary = e if typeof(e) == TYPE_DICTIONARY else {}
	var base: HullData = DB.hull_frames[1]
	# MAKER AND WEIGHT FIRST, name only as a fallback.
	#
	# The warning above came true: hulls gained a name per CLASS, so a save
	# holding a Halberd Cutter found nothing in `hull_frames` — those carry
	# the tier-0 name — and silently restored an unbranded Medium Frame with
	# somebody else's perk. Maker and weight are both written into the save
	# and neither is renameable, so they identify the frame outright.
	var man := StringName(str(d.get("manufacturer", "")))
	var found := false
	if man != &"":
		for frame in DB.hull_frames:
			if frame.manufacturer == man and int(frame.weight) == int(d.get("weight", -1)):
				base = frame
				found = true
				break
	if not found:
		for frame in DB.hull_frames:
			if frame.name == str(d.get("name", "")):
				base = frame
				break
	var h := base.duplicate(true) as HullData
	# THE NAME IS RESTORED, not inherited. It used to come free because the
	# frame was FOUND by name; matching on maker and weight instead means the
	# frame carries the tier-0 name, so a Halberd Cutter came back as a Picket
	# Cutter — same ship, same stats, wrong badge. Intermittent, because it
	# only shows on a hull rolled above C.
	var saved_name := str(d.get("name", ""))
	if saved_name != "":
		h.name = saved_name
	h.perk_id = StringName(str(d.get("perk_id", "salvage_rack")))
	# Absent in a save written before hulls had makers, in which case the frame
	# matched by name above already carries the right one.
	if d.has("manufacturer"):
		h.manufacturer = StringName(str(d["manufacturer"]))
	for f in HULL_FIELDS:
		if not d.has(f):
			continue
		h.set(f, float(d[f]) if typeof(h.get(f)) == TYPE_FLOAT else int(d[f]))
	return h

# ----------------------------------------------------------------- map nodes

## The map is stored whole rather than regenerated from a seed. MapGen draws on
## the global RNG rather than a seeded stream, so there is no seed that would
## reproduce it — and even if there were, the run's own marks (visited, cleared,
## inspected, rolled shop stock) are not in it.
static func _contracts_to() -> Array:
	var out: Array = []
	for c in Run.contracts:
		out.append((c as ContractData).to_wire())
	return out


static func _contracts_from(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in (raw as Array):
		if typeof(e) == TYPE_DICTIONARY:
			out.append(ContractData.from_wire(e))
	return out


static func _standing_to() -> Dictionary:
	var out: Dictionary = {}
	for k in Run.standing:
		out[String(k)] = int(Run.standing[k])
	return out


static func _node_to(n: MapGen.MapNode) -> Dictionary:
	var makers: Array = []
	for m in n.makers:
		makers.append(String(m))
	var shop: Array = []
	for m in n.shop:
		shop.append(_module_to(m))
	# Everything the bag was rolled with, including the parts already claimed.
	# `taken` is what says which are gone, and dropping the claimed ones here
	# would renumber the rest — the array must not shrink, on disk any more than
	# in memory. See MapGen.OPTION_BAG.
	var bag: Array = []
	for m in n.bag:
		bag.append(_module_to(m))
	return {
		index = n.index, layer = n.layer, row = n.row,
		rows_in_layer = n.rows_in_layer,
		region = int(n.region), development = int(n.development),
		security = n.security, makers = makers,
		manufacturer = String(n.manufacturer), fauna = n.fauna,
		danger = n.danger, type = int(n.type),
		visited = n.visited, cleared = n.cleared, eaten = n.eaten,
		taken = Array(n.taken),
		inspected = n.inspected,
		fled = n.fled, stocked = n.stocked, trades = n.trades,
		foes = _names(n.foes), event_key = n.event_key,
		ambush = _names(n.ambush), ambush_rolled = n.ambush_rolled,
		in_nebula = n.in_nebula, nebula_emission = n.nebula_emission,
		pos = [n.pos.x, n.pos.y], gal = [n.gal.x, n.gal.y],
		links = Array(n.links),
		shop = shop,
		shop_hull = _hull_to(n.shop_hull) if n.shop_hull != null else null,
		bag = bag, bagged = n.bagged,
	}

static func _node_from(e: Variant) -> MapGen.MapNode:
	var d: Dictionary = e if typeof(e) == TYPE_DICTIONARY else {}
	var n := MapGen.MapNode.new()
	n.index = int(d.get("index", 0))
	n.layer = int(d.get("layer", 0))
	n.row = int(d.get("row", 0))
	n.rows_in_layer = int(d.get("rows_in_layer", 1))
	n.region = int(d.get("region", 0)) as MapGen.Region
	n.development = int(d.get("development", 0)) as MapGen.Development
	n.security = int(d.get("security", 1))
	var makers: Array[StringName] = []
	for m in d.get("makers", []):
		makers.append(StringName(str(m)))
	n.makers = makers
	n.manufacturer = StringName(str(d.get("manufacturer", "")))
	n.fauna = bool(d.get("fauna", false))
	n.danger = int(d.get("danger", 1))
	n.type = int(d.get("type", 0)) as MapGen.NodeType
	n.visited = bool(d.get("visited", false))
	n.cleared = bool(d.get("cleared", false))
	n.eaten = bool(d.get("eaten", false))
	# Absent on a save written before a system could offer more than one thing
	# to do. A cleared node with no list is a node whose single option was the
	# system itself, which is what it always was.
	var taken := PackedInt32Array()
	for o in d.get("taken", []):
		taken.append(int(o))
	if taken.is_empty() and n.cleared:
		taken.append(MapGen.OPTION_WHOLE)
	n.taken = taken
	n.fled = bool(d.get("fled", false))
	# Absent on a save written before the node carried its own roll. Left empty,
	# which makes the node roll once on the next arrival and keep it from then
	# on — the old behaviour for exactly one more visit, rather than a crash.
	var foes: Array[StringName] = []
	for f in d.get("foes", []):
		foes.append(StringName(str(f)))
	n.foes = foes
	n.event_key = str(d.get("event_key", ""))
	# Absent on a save written before heat had a map layer. An unrolled node
	# rolls once on the next arrival, which is the old behaviour for exactly one
	# more visit rather than a crash — same contract as `foes` above.
	var amb: Array[StringName] = []
	for a in d.get("ambush", []):
		amb.append(StringName(str(a)))
	n.ambush = amb
	n.ambush_rolled = bool(d.get("ambush_rolled", false))
	n.inspected = bool(d.get("inspected", false))
	# Whether the shelf has ever been rolled, and how much has been sold into
	# this market. Both are run marks like `visited` — losing either would let a
	# save-and-resume re-roll a bought-out station or reset a saturated one.
	n.stocked = bool(d.get("stocked", false))
	n.trades = int(d.get("trades", 0))
	n.in_nebula = bool(d.get("in_nebula", false))
	n.nebula_emission = bool(d.get("nebula_emission", false))
	n.pos = _vec(d.get("pos", []))
	n.gal = _vec(d.get("gal", []))
	var links := PackedInt32Array()
	for i in d.get("links", []):
		links.append(int(i))
	n.links = links
	for m in d.get("shop", []):
		var mod := _module_from(m)
		if mod != null:
			n.shop.append(mod)
	var sh: Variant = d.get("shop_hull", null)
	n.shop_hull = _hull_from(sh) if typeof(sh) == TYPE_DICTIONARY else null
	for m in d.get("bag", []):
		var part := _module_from(m)
		if part != null:
			n.bag.append(part)
	n.bagged = bool(d.get("bagged", false))
	return n

static func _names(a: Array[StringName]) -> Array:
	var out: Array = []
	for s in a:
		out.append(String(s))
	return out

static func _vec(v: Variant) -> Vector2:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
		return Vector2.ZERO
	return Vector2(float((v as Array)[0]), float((v as Array)[1]))
