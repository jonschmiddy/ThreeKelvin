class_name SaveGame
extends RefCounted

## A suspend save, not a checkpoint: loading deletes the file, so death stays final.
## Combat is outside the save; the autosave lands just before a fight begins.
## Why: docs/why/SaveGame.md#suspend-save

const PATH := "user://run.save"
## Harnesses write a scratch file per process: tests once overwrote Jon's run.save (2026-10-05).
## Why: docs/why/SaveGame.md#save-path
static var path: String = TestRun.scratch("run", "save") if TestRun.active() else PATH
## True while a load announces its run (`Sig.run_started`), so a listener can
## tell CONTINUE from a new run (A.S.H.'s introduction is a new run's only).
static var restoring := false
## Bumped whenever the shape changes; an old file is discarded, never guessed at.
## Why: docs/why/SaveGame.md#version-history
const VERSION := 40
## The oldest file this build reads. Everything from here to VERSION must load
## as what it meant; see 30.
const OLDEST_READ := 29

## Every rolled scalar on a hull. The frame supplies the art and the anchors; a
## saved hull is a frame plus the numbers LootGen rolled onto it.
const HULL_FIELDS: Array[String] = ["weight", "tier", "reactor", "hand_size",
	"max_hull", "heat_cap", "dissipation", "dodge", "initiative", "fuel_factor",
	"thrust", "weapon_slots", "system_slots", "utility_slots", "sensors",
	"stealth"]

# --------------------------------------------------------------------- queries

static func has_save() -> bool:
	return FileAccess.file_exists(path)

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

## Unconditional and cheap. The map guard is doubled here as this is the one writer.
## Why: docs/why/SaveGame.md#saving
static func save() -> void:
	if Run.hull == null or Run.map.is_empty() or Run.dead or Run.won:
		return
	_write(false)


## The one save a won run may have: the core cleared with its body, so a quit returns to it.
## Why: docs/why/SaveGame.md#core-won-save
static func save_core_won() -> void:
	if Run.hull == null or Run.map.is_empty() or Run.dead or not Run.won:
		return
	_write(true)


static func _write(_core_won: bool) -> void:
	# The map still up writes its ship's spot first, as it records it only when put away.
	if Router.current is SystemMapScreen:
		(Router.current as SystemMapScreen)._keep_ship()
	# `full_precision` on: the default rounds floats enough to move systems on the chart.
	# Not bit-exact (worst error 9.3e-14) but unobservable. JSON stays readable in dev.
	# Why: docs/why/SaveGame.md#json-precision
	SafeFile.write_text(path, JSON.stringify(_snapshot(), "", true, true))

## Mid-fight SAVE & EXIT keeps the old save and notes the fight to restart on CONTINUE.
static func mark_fight(fight: Dictionary) -> void:
	var d := _read()
	if d.is_empty() or fight.is_empty():
		return
	d["fight"] = fight
	SafeFile.write_text(path, JSON.stringify(d, "", true, true))

static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _snapshot() -> Dictionary:
	var installed: Array = []
	for m in Run.installed:
		installed.append(_module_to(m))
	var cargo: Array = []
	for m in Run.cargo:
		cargo.append(_item_to(m))
	var pad: Array = []
	for m in Run.pad:
		pad.append(_item_to(m))
	var nodes: Array = []
	for n in Run.map:
		nodes.append(_node_to(n))
	var here: MapGen.MapNode = Run.node_at()
	return {
		version = VERSION,
		core_won = Run.won,
		# Denormalised for summary(). The launcher should not have to rebuild a
		# hundred and fifty map nodes to print one line of button text.
		system = MapGen.star_name(here),
		danger = here.danger,
		max_hp = Run.max_hp(),

		started_at = Run.started_at,
		galaxy_kind = Run.galaxy_kind,
		galaxy = Run.galaxy,
		galaxy_seed = Run.galaxy_seed,
		# What the world may hold (VERSION 34).
		unlocked = Array(Run.unlocked_manufacturers).map(
			func(m: StringName) -> String: return String(m)),
		# Saved so a load does not rewind every roll stream to the start of the run.
		rng = Rng.state(),
		galaxy_spin = Run.galaxy_spin,
		galaxy_name = Run.galaxy_name,
		galaxy_title = Run.galaxy_title,

		hull = _hull_to(Run.hull),
		ship_name = Run.ship_name,
		launched_as = String(Run.launched_as),
		installed = installed,
		cargo = cargo,
		pad = pad,
		found_hull = _hull_to(Run.found_hull) if Run.found_hull != null else null,
		# What it cuts up for (VERSION 37), empty for a hull with no SCRAP.
		found_scrap = {"credits": Run.found_scrap_credits(),
			"material": String(Run.found_scrap.get("material", &""))} \
			if Run.found_scrap_credits() > 0 else {},
		# The ship you are moving out of, while anything is still aboard it
		# (VERSION 36): the move's left half is drawn from it.
		old_hull = _hull_to(Run.old_hull) if Run.old_hull != null and not Run.pad.is_empty() else null,

		hp = Run.hp,
		heat = Run.heat,
		heat_cap_bonus = Run.heat_cap_bonus,
		credits = Run.credits,
		fuel = Run.fuel,
		dross = Run.dross.map(func(x: StringName) -> String: return String(x)),
		whale_boon = Run.whale_boon,
		# Contracts and standing are run state tied to this galaxy, so they live here.
		contracts = _contracts_to(),
		next_contract_id = Run.next_contract_id,
		# The event quests and the finished order (VERSION 35).
		event_quests = _event_quests_to(),
		quests_done = Array(Run.quests_done),
		# Optional: a save without it loads an empty log, so it needed no `VERSION`.
		ash_comms = Ash.comms_to(),
		standing = _standing_to(),

		map = nodes,
		at = Run.at,
		# Where the ship was left in each system you have been in (VERSION 30).
		parked = _parked_to(),
		# And each system's map clock, which those spots were left at (VERSION 39).
		clocks = _clocks_to(),
		trail = Array(Run.trail),
		jumps = Run.jumps,
		# The lead ship's, in co-op (VERSION 40); 0 alone.
		party_jumps = Run.party_jumps,
		kills = Run.kills,

		hellbender_at = Run.hellbender_at,
		hellbender_hp = Run.hellbender_hp,
		hellbender_max = Run.hellbender_max,
		hellbender_moves = Run.hellbender_moves,
		hellbender_ticks = Run.hellbender_ticks,
	}

# ----------------------------------------------------------------------- read

static func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	var v := int(d.get("version", -1))
	if v < OLDEST_READ or v > VERSION:
		return {}
	return d

## The file is consumed on load; Router saves on the next swap, so the window is milliseconds.
## Why: docs/why/SaveGame.md#loading
static func load_into_run() -> bool:
	var d := _read()
	if d.is_empty():
		clear()
		return false

	# Check before the first write to Run: a truncated map used to leave a half-loaded run.
	var saved_map: Variant = d.get("map", [])
	# The fight this run was saved out of, if any. Always assigned, so a stale
	# one from an earlier load can never restart a fight this save never had.
	var fight: Variant = d.get("fight", {})
	Router.fight_on_resume = fight if typeof(fight) == TYPE_DICTIONARY else {}
	if typeof(saved_map) != TYPE_ARRAY or (saved_map as Array).is_empty():
		clear()
		return false

	Run.started_at = float(d.get("started_at", 0.0))
	Run.galaxy_kind = int(d.get("galaxy_kind", 0))
	Run.galaxy = _galaxy_from(Run.galaxy_kind, d.get("galaxy", {}))
	Run.galaxy_seed = int(d.get("galaxy_seed", 0))
	Rng.restore(d.get("rng", {"master": Run.galaxy_seed}))
	Run.unlocked_manufacturers = _unlocked_from(d.get("unlocked", null))
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
	# Unplaced parts from an old save get the first free hardpoint, not an empty rack.
	for m in Run.installed:
		if m.mount < 0:
			m.mount = Run.free_mount(m.slot)
	var cargo: Array[HoldItem] = []
	for e in d.get("cargo", []):
		var m := _item_from(e)
		if m != null:
			cargo.append(m)
	Run.cargo = cargo
	# Cleared here, before `repack_hold` appends to the pad, or the old run's pad leaks.
	Run.pad.clear()
	# Cell-less parts are repacked after the hull is set, as the grid's shape is the hull's.
	var unplaced := false
	for m in Run.cargo:
		if m.hold_at.x < 0 or not Run.can_place(m, m.hold_at):
			unplaced = true
			break
	if unplaced:
		Run.repack_hold()
	# Read the pad after the repack, which appends to it, or the repack's parts are lost.
	var padded: Array[HoldItem] = []
	for e in d.get("pad", []):
		var pm := _item_from(e)
		if pm != null:
			padded.append(pm)
	Run.pad.append_array(padded)

	var fh: Variant = d.get("found_hull", null)
	Run.found_hull = _hull_from(fh) if typeof(fh) == TYPE_DICTIONARY else null
	# AFTER the hull, whose setter clears it (VERSION 37; a 36 save has none).
	var fs: Variant = d.get("found_scrap", {})
	if Run.found_hull != null and typeof(fs) == TYPE_DICTIONARY and int((fs as Dictionary).get("credits", 0)) > 0:
		Run.found_scrap = {credits = int(fs.get("credits", 0)),
			material = StringName(String(fs.get("material", "")))}
	# The undo is cleared, not kept: it names objects this load just replaced.
	var oh: Variant = d.get("old_hull", null)
	Run.old_hull = _hull_from(oh) if typeof(oh) == TYPE_DICTIONARY else null
	Run._undo_move = {}

	# A save written before ships could be named restores as unnamed, which is
	# what it meant at the time.
	Run.ship_name = str(d.get("ship_name", ""))
	# Optional: a save from before it was kept says nothing, and the run's win
	# then falls back to the hull it ends in (`RunHistory.record`).
	Run.launched_as = StringName(str(d.get("launched_as", "")))

	Run.hp = int(d.get("hp", 1))
	Run.heat = int(d.get("heat", 0))
	Run.heat_cap_bonus = int(d.get("heat_cap_bonus", 0))
	Run.credits = int(d.get("credits", 0))
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
	# VERSION 35; missing (a 34 save) is none, and `QuestLog` reads the map
	Run.event_quests = _event_quests_from(d.get("event_quests", []))
	Run.quests_done.clear()
	var done_raw: Variant = d.get("quests_done", [])
	if typeof(done_raw) == TYPE_ARRAY:
		for k in (done_raw as Array):
			Run.quests_done.append(str(k))
	# Zeroed, not restored: these sit outside the save, so a load must clear them like a new run.
	# Why: docs/why/SaveGame.md#load-resets
	Run.hauls = 0
	Run.salvage_hushed_hauls = -1
	Run.salvage_hushed_bag = -1
	var stand: Dictionary = {}
	var saved_stand: Variant = d.get("standing", {})
	if typeof(saved_stand) == TYPE_DICTIONARY:
		for k in (saved_stand as Dictionary).keys():
			# Filtered against the catalogue: a manufacturer that no longer exists is
			# standing the player can never spend and a row they can never clear.
			var manufacturer := StringName(str(k))
			if DB.manufacturers.has(manufacturer):
				stand[manufacturer] = int((saved_stand as Dictionary)[k])
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
	# The lead ship's (VERSION 40); a 39 save has none, so its count is its own.
	Run.party_jumps = maxi(0, int(d.get("party_jumps", 0)))
	# the badge's arrival at this count was shown before the save, or never will
	# be: a loaded run does not replay it (`RunState.custodian_seen`)
	Run.custodian_seen = Run.custodian_jumps()
	Run.kills = int(d.get("kills", 0))

	# Clamped like `at`, because a stale index here is not a wrong marker — it
	# is an index error inside whatever reads the hellbender's node next.
	Run.hellbender_at = clampi(int(d.get("hellbender_at", -1)), -1, map.size() - 1)
	Run.hellbender_max = maxi(0, int(d.get("hellbender_max", 0)))
	Run.hellbender_hp = clampi(int(d.get("hellbender_hp", 0)), 0, Run.hellbender_max)
	Run.hellbender_moves = maxi(0, int(d.get("hellbender_moves", 0)))
	Run.hellbender_ticks = maxi(0, int(d.get("hellbender_ticks", 0)))

	# A run comes back unwon, except the one written at the core between the
	# kill and its body (`save_core_won`): won already, recorded already.
	Run.won = bool(d.get("core_won", false))
	Run.dead = false
	Run.death_reason = ""
	# Last, once the map is back: a part put in the hold announces a ship change.
	var mended := Run.mend_loadout()
	if mended > 0:
		Router.crumb("[save] mended %d part%s: off a hardpoint it could not have, or off a pad with no old ship"
			% [mended, "" if mended == 1 else "s"])

	clear()
	restoring = true
	Sig.run_started.emit()
	restoring = false
	# HER COMMS, after run_started (which empties them for a new run); none in a
	# save from before them
	Ash.comms_from(d.get("ash_comms", []))
	# After `run_started`, whose Router listener clears the parked record.
	SystemMapScreen._parked = _parked_from(d.get("parked", []), map.size())
	# (the map clocks with them, after run_started for the same reason; a 38
	# save has none: every system at t 0, as a 38 build drew it)
	Run.map_clock = _clocks_from(d.get("clocks", []), map.size())
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	Run.log_line("Reactor warm. Resuming from %s." % MapGen.star_name(Run.node_at()), &"big")
	return true

# --------------------------------------------------------------- galaxy params

## JSON turns ints into floats, so rebuild from the KIND template and coerce each value.
static func _galaxy_from(kind: int, saved: Variant) -> Dictionary:
	var out: Dictionary = GalaxyGen.params(kind).duplicate()
	if typeof(saved) != TYPE_DICTIONARY:
		return out
	for raw_key in (saved as Dictionary).keys():
		# JSON keys are Strings; convert to StringName so the restored dictionary prints the same.
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

## A module is a template id plus its rolls; a material stores only id and cell.
## No price is saved: a derived number that is saved is a second copy of the truth.
## Why: docs/why/SaveGame.md#module-rows
static func _item_to(m: HoldItem) -> Dictionary:
	if m is CreditChit:
		return {kind = "credits", amount = (m as CreditChit).amount}
	if m is MaterialData:
		var mat := m as MaterialData
		return {
			kind = "material",
			id = String(mat.id),
			hold_at = [mat.hold_at.x, mat.hold_at.y],
			turned = mat.turned,
		}
	return _module_to(m as ModuleData)


static func _item_from(e: Variant) -> HoldItem:
	var row := e as Dictionary
	if row == null:
		return null
	if String(row.get("kind", "")) == "credits":
		# Only the amount. A chit has no other state and never sits in a cell.
		return CreditChit.of(int(row.get("amount", 0)))
	if String(row.get("kind", "")) == "material":
		var mat := MaterialData.by_id(StringName(row.get("id", &"")))
		if mat == null:
			# The row was dropped from the catalogue between versions. Losing the
			# item is better than carrying a nameless shape that sells for zero.
			return null
		var at: Array = row.get("hold_at", [-1, -1])
		mat.hold_at = Vector2i(int(at[0]), int(at[1])) if at.size() == 2 \
			else -Vector2i.ONE
		mat.turned = bool(row.get("turned", false))
		return mat
	return _module_from(e)


static func _module_to(m: ModuleData) -> Dictionary:
	var affixes: Array = []
	for a in m.affixes:
		affixes.append(a.name)
	return {
		id = String(m.id),
		rarity = int(m.rarity),
		scrap_value = m.scrap_value,
		affixes = affixes,
		# The mount is saved, or a resumed ship rearranges every part into the hold.
		mount = m.mount,
		turned = m.turned,
		hold_at = [m.hold_at.x, m.hold_at.y],
	}

## A retired part id is dropped and the rest of the run loads.
static func _module_from(e: Variant) -> ModuleData:
	if typeof(e) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = e
	var id := StringName(str(d.get("id", "")))
	if not DB.modules.has(id):
		push_warning("SaveGame: dropped unknown module '%s'" % id)
		return null
	var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
	# Through `DB.regrade` so a part saved a grade up gets that grade's pips.
	DB.regrade(m, int(d.get("rarity", int(m.rarity))))
	m.scrap_value = int(d.get("scrap_value", m.scrap_value))
	m.mount = int(d.get("mount", -1))
	m.turned = bool(d.get("turned", false))
	# Version 6: a pre-grid save has no position, so those parts are re-packed.
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

## `manufacturer` is written apart from `HULL_FIELDS`, whose restore loop coerces to numbers.
## It is saved at all as the name lookup can fall back to an unbranded frame.
## Why: docs/why/SaveGame.md#hull-rows
static func _hull_to(h: HullData) -> Dictionary:
	# `tier_perks` sits beside `perk_id`, not in `HULL_FIELDS`, whose loop coerces to numbers.
	var wrote: Array = []
	for tp in h.tier_perks:
		wrote.append(String(tp))
	var d := {name = h.name, perk_id = String(h.perk_id),
		manufacturer = String(h.manufacturer), tier_perks = wrote}
	for f in HULL_FIELDS:
		d[f] = h.get(f)
	return d

static func _hull_from(e: Variant) -> HullData:
	var d: Dictionary = e if typeof(e) == TYPE_DICTIONARY else {}
	var base: HullData = DB.hull_frames[1]
	# Match on manufacturer and weight, name only as a fallback: neither is renameable.
	# Why: docs/why/SaveGame.md#hull-restore
	var manufacturer := StringName(str(d.get("manufacturer", "")))
	var found := false
	if manufacturer != &"":
		for frame in DB.hull_frames:
			if frame.manufacturer == manufacturer and int(frame.weight) == int(d.get("weight", -1)):
				base = frame
				found = true
				break
	if not found:
		for frame in DB.hull_frames:
			if frame.name == str(d.get("name", "")):
				base = frame
				break
	var h := base.duplicate(true) as HullData
	# The name is restored, not inherited: weight matching lost class names (Halberd to Picket).
	var saved_name := str(d.get("name", ""))
	if saved_name != "":
		h.name = saved_name
	h.perk_id = StringName(str(d.get("perk_id", "salvage_rack")))
	# Grade perks are restored, never re-derived: `_hull_from` skips `at_tier`.
	# Why: docs/why/SaveGame.md#hull-restore
	var tp: Array = d.get("tier_perks", []) as Array
	var restored: Array[StringName] = []
	for e2 in tp:
		restored.append(StringName(str(e2)))
	h.tier_perks = restored
	# Absent in a save written before hulls had berths, in which case the frame
	# matched by name above already carries the right one.
	if d.has("manufacturer"):
		h.manufacturer = StringName(str(d["manufacturer"]))
	for f in HULL_FIELDS:
		if not d.has(f):
			continue
		h.set(f, float(d[f]) if typeof(h.get(f)) == TYPE_FLOAT else int(d[f]))
	return h

# ----------------------------------------------------------------- map nodes

## The map is stored whole: MapGen has no seed, and the run's marks are not in it.
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


## The event quests (`Run.event_quests`), one row each: `at`, `id`, `from`, and
## once taken `credits` and `got`. Rows, for the reason 23 gives.
static func _event_quests_to() -> Array:
	var out: Array = []
	for raw in Run.event_quests:
		var r: Dictionary = raw
		var row := {at = int(r.get("at", -1)), id = String(r.get("id", &"")),
			from = String(r.get("from", &""))}
		if r.has("credits"):
			row["credits"] = int(r.credits)
			row["got"] = Array(r.get("got", [])).map(func(x: Variant) -> String: return str(x))
		out.append(row)
	return out


static func _event_quests_from(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in (raw as Array):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		var r := {at = int(d.get("at", -1)), id = StringName(str(d.get("id", ""))),
			from = StringName(str(d.get("from", "")))}
		if d.has("credits"):
			r["credits"] = int(d.get("credits", 0))
			r["got"] = Array(d.get("got", [])).map(func(x: Variant) -> String: return str(x))
		out.append(r)
	return out


## Missing means every manufacturer. Unknown ids are dropped; Korvan is always first.
static func _unlocked_from(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(raw) != TYPE_ARRAY:
		out.assign(Unlocks.CHAIN)
		return out
	for e in raw:
		var id := StringName(str(e))
		if Unlocks.CHAIN.has(id) and not out.has(id):
			out.append(id)
	if out.is_empty():
		out.append(Unlocks.CHAIN[0])
	return out

static func _standing_to() -> Dictionary:
	var out: Dictionary = {}
	for k in Run.standing:
		out[String(k)] = int(Run.standing[k])
	return out


## Rows, not a dictionary, as JSON keys are strings. Absent orbit fields just settle again.
## Why: docs/why/SaveGame.md#parked-ship-rows
static func _parked_to() -> Array:
	var out: Array = []
	for k in SystemMapScreen._parked:
		var e: Dictionary = SystemMapScreen._parked[k]
		var p: Vector2 = e.get("p", Vector2.ZERO)
		var v: Vector2 = e.get("v", Vector2.ZERO)
		var row := {index = int(k), at = int(e.get("at", -9)), p = [p.x, p.y], v = [v.x, v.y],
			head = float(e.get("head", 0.0)), mode = String(e.get("mode", &""))}
		if e.has("r"):
			row.cen = int(e.get("cen", -1))
			row.r = float(e.r)
			row.sense = float(e.get("sense", 1.0))
		out.append(row)
	return out


## The rows back into the record the map reads, in its own types. A row for a
## system outside this map is dropped rather than kept against the wrong place.
static func _parked_from(raw: Variant, systems: int) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = e
		var idx := int(r.get("index", -1))
		if idx < 0 or idx >= systems:
			continue
		out[idx] = {"at": int(r.get("at", -9)), "p": _vec(r.get("p")), "v": _vec(r.get("v")),
			"head": float(r.get("head", 0.0)), "mode": StringName(str(r.get("mode", "")))}
		if r.has("r"):
			out[idx]["cen"] = int(r.get("cen", -1))
			out[idx]["r"] = float(r.get("r", -1.0))
			out[idx]["sense"] = float(r.get("sense", 1.0))
	return out


## EACH SYSTEM'S MAP CLOCK (`Run.map_clock`), one row per system: {index, t}.
## Rows, not a dictionary keyed by system, for the reason 23 gives.
static func _clocks_to() -> Array:
	var out: Array = []
	for k in Run.map_clock:
		out.append({index = int(k), t = float(Run.map_clock[k])})
	return out


## Rows outside this map or with a bad clock are dropped; that system opens at t 0.
static func _clocks_from(raw: Variant, systems: int) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = e
		var idx := int(r.get("index", -1))
		var t := float(r.get("t", 0.0))
		if idx < 0 or idx >= systems or not is_finite(t) or t < 0.0:
			continue
		out[idx] = t
	return out


static func _node_to(n: MapGen.MapNode) -> Dictionary:
	var berths: Array = []
	for m in n.berths:
		berths.append(String(m))
	var shop: Array = []
	for m in n.shop:
		shop.append(_module_to(m))
	# Keep the claimed bag parts: `taken` marks them gone, and the array must not shrink.
	var bag: Array = []
	for m in n.bag:
		bag.append(_item_to(m))
	# Containers persist as node state. Two arrays, not a dictionary: JSON keys are strings.
	# Why: docs/why/SaveGame.md#node-containers
	var res_at: Array = []
	var res_of: Array = []
	for k in n.results:
		res_at.append(int(k))
		res_of.append(String(n.results[k]))
	# What the cards say is saved the same way (VERSION 29), only for options touched.
	var left_at: Array = []
	var left_of: Array = []
	for k in n.left:
		left_at.append(int(k))
		left_of.append(String(n.left[k]))
	var said_at: Array = []
	var said_of: Array = []
	for k in n.said:
		said_at.append(int(k))
		said_of.append(Array(n.said[k]).map(func(x: Variant) -> String: return String(x)))
	var jetsam: Array = []
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		var items: Array = []
		for m2 in h.items:
			items.append(_item_to(m2))
		jetsam.append({slot = h.slot, art = String(h.art), look = h.look, label = h.label,
			site = h.site, scanned = h.scanned, opened = h.opened, items = items})
	return {
		index = n.index, layer = n.layer, row = n.row,
		rows_in_layer = n.rows_in_layer,
		region = int(n.region), development = int(n.development),
		star = int(n.star), gas_giant = n.gas_giant,
		near_pulsar = n.near_pulsar, twin = n.twin,
		security = n.security, berths = berths,
		manufacturer = String(n.manufacturer), fauna = n.fauna,
		danger = n.danger, type = int(n.type),
		visited = n.visited, cleared = n.cleared, eaten = n.eaten,
		sensed = n.sensed,
		taken = Array(n.taken),
		inspected = n.inspected,
		fled = n.fled, stocked = n.stocked, trades = n.trades,
		foes = _names(n.foes), event_key = n.event_key,
		ambush_pending = n.ambush_pending, ambush_rolled = n.ambush_rolled,
		in_nebula = n.in_nebula, nebula_emission = n.nebula_emission,
		pos = [n.pos.x, n.pos.y], gal = [n.gal.x, n.gal.y],
		links = Array(n.links),
		shop = shop,
		shop_hull = _hull_to(n.shop_hull) if n.shop_hull != null else null,
		bag = bag, bagged = n.bagged, jetsam = jetsam,
		options = _names(n.options),
		results_at = res_at, results_of = res_of,
		left_at = left_at, left_of = left_of,
		said_at = said_at, said_of = said_of,
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
	var berths: Array[StringName] = []
	for m in d.get("berths", []):
		berths.append(StringName(str(m)))
	n.berths = berths
	n.manufacturer = StringName(str(d.get("manufacturer", "")))
	n.fauna = bool(d.get("fauna", false))
	n.danger = int(d.get("danger", 1))
	n.star = int(d.get("star", 0)) as MapGen.Star
	n.gas_giant = bool(d.get("gas_giant", false))
	n.near_pulsar = bool(d.get("near_pulsar", false))
	# (VERSION 38; missing on a 37 save, which had one sun everywhere)
	n.twin = bool(d.get("twin", false))
	n.type = int(d.get("type", 0)) as MapGen.NodeType
	n.visited = bool(d.get("visited", false))
	# Absent on old saves; false is honest and the next arrival fills it in.
	n.sensed = bool(d.get("sensed", false))
	n.cleared = bool(d.get("cleared", false))
	n.eaten = bool(d.get("eaten", false))
	# Absent on old saves: a cleared node with no list had the system itself as its option.
	var taken := PackedInt32Array()
	for o in d.get("taken", []):
		taken.append(int(o))
	if taken.is_empty() and n.cleared:
		taken.append(MapGen.OPTION_WHOLE)
	n.taken = taken
	n.fled = bool(d.get("fled", false))
	# Absent on old saves: left empty, the node rolls once on the next arrival, no crash.
	var foes: Array[StringName] = []
	for f in d.get("foes", []):
		foes.append(StringName(str(f)))
	n.foes = foes
	n.event_key = str(d.get("event_key", ""))
	# Saved as ids and resolved lazily, so a missing option never refuses a save.
	# Why: docs/why/SaveGame.md#node-options
	var opts: Array[StringName] = []
	for o in d.get("options", []):
		opts.append(StringName(str(o)))
	n.options = opts
	# Absent on old saves: an unrolled node rolls once on the next arrival, like `foes`.
	var amb: Array[StringName] = []
	for a in d.get("ambush", []):
		amb.append(StringName(str(a)))
	n.ambush_pending = bool(d.get("ambush_pending", not amb.is_empty()))
	n.ambush_rolled = bool(d.get("ambush_rolled", false))
	n.inspected = bool(d.get("inspected", false))
	# Run marks like `visited`: losing them would let a resume re-roll or reset a market.
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
	var res_at: Array = d.get("results_at", [])
	var res_of: Array = d.get("results_of", [])
	for ri in mini(res_at.size(), res_of.size()):
		n.results[int(res_at[ri])] = StringName(res_of[ri])
	var left_at: Array = d.get("left_at", [])
	var left_of: Array = d.get("left_of", [])
	for li in mini(left_at.size(), left_of.size()):
		n.left[int(left_at[li])] = String(left_of[li])
	var said_at: Array = d.get("said_at", [])
	var said_of: Array = d.get("said_of", [])
	for si in mini(said_at.size(), said_of.size()):
		var pair: Array = said_of[si] if typeof(said_of[si]) == TYPE_ARRAY else []
		if pair.size() >= 2:
			n.said[int(said_at[si])] = [String(pair[0]), String(pair[1])]
	for raw in d.get("jetsam", []):
		var row: Dictionary = raw
		var h := MapGen.Jetsam.new()
		h.slot = int(row.get("slot", 0))
		h.art = StringName(row.get("art", ""))
		# (absent before the enemies had several pictures: the first one)
		h.look = int(row.get("look", 0))
		h.label = String(row.get("label", "SECTOR LOOT"))
		# (absent before wrecks had a place: shown at every place, as then)
		h.site = int(row.get("site", MapGen.SITE_ANY))
		h.scanned = bool(row.get("scanned", false))
		# (absent before SECTOR LOOT showed opened wrecks: a swept one was opened)
		h.opened = bool(row.get("opened", h.scanned))
		for e2 in row.get("items", []):
			var it := _item_from(e2)
			if it != null:
				h.items.append(it)
		n.jetsam.append(h)
	for m in d.get("bag", []):
		var part := _item_from(m)
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
