extends RefCounted

## The type check a save file gets before the loader reads it (`SaveGame.load_into_run`).
## Read side only: nothing here is written. No `class_name`: `SaveGame` preloads it.
## Why: docs/why/SaveGame.md#damaged-saves

## Keys a loader reads with int(), float(), str() or bool(): a list or a map there is damage.
const _TOP_SCALARS: Array[String] = ["started_at", "galaxy_kind", "galaxy_seed", "ascension",
	"galaxy_spin", "galaxy_name", "galaxy_title", "data", "black_box_spent", "ship_name",
	"launched_as", "hp", "max_hp", "heat", "heat_cap_bonus", "credits", "fuel", "whale_boon",
	"next_contract_id", "at", "jumps", "party_jumps", "kills", "hellbender_at", "hellbender_hp",
	"hellbender_max", "hellbender_moves", "hellbender_ticks", "core_won", "moored_right",
	"danger", "system"]
const _ITEM_SCALARS: Array[String] = ["id", "rarity", "scrap_value", "mount", "turned",
	"augmented", "kind", "amount"]
const _NODE_SCALARS: Array[String] = ["index", "layer", "row", "rows_in_layer", "region",
	"development", "security", "manufacturer", "fauna", "danger", "star", "gas_giant",
	"near_pulsar", "twin", "type", "visited", "sensed", "cleared", "eaten", "fled", "event_key",
	"ambush_pending", "ambush_rolled", "inspected", "stocked", "trades", "in_nebula",
	"nebula_emission", "bagged"]
const _NODE_LISTS: Array[String] = ["berths", "taken", "foes", "options", "ambush", "links",
	"results_at", "results_of", "left_at", "left_of", "said_at"]
const _JETSAM_SCALARS: Array[String] = ["slot", "art", "look", "label", "site", "scanned", "opened"]
const _RNG_SCALARS: Array[String] = ["master", "seat", "world", "loot", "event", "foe", "fight"]


## True, and a line in the log, when a field has the wrong kind of value for what it holds.
static func damaged(d: Dictionary) -> bool:
	var bad := scalar_bad(d)
	if bad == "":
		bad = _lists_bad(d)
	if bad == "":
		bad = _nodes_bad(d)
	if bad != "":
		Router.crumb("[save] refused whole, a damaged field: %s" % bad)
	return bad != ""


static func version_ok(d: Dictionary) -> bool:
	return _scalar(d.get("version", -1))


static func _scalar(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_BOOL or t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_STRING


## A list of plain values.
static func _flat(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	for e in (v as Array):
		if not _scalar(e):
			return false
	return true


## The first of these keys the row has with the wrong kind of value, or "".
static func _row_bad(row: Dictionary, scalars: Array, lists: Array) -> String:
	for k in scalars:
		if row.has(k) and not _scalar(row[k]):
			return str(k)
	for k in lists:
		if row.has(k) and not _flat(row[k]):
			return str(k)
	return ""


## `key` of the first row (of those that are rows) that fails; a list that is not one fails whole.
static func _rows_bad(v: Variant, scalars: Array, lists: Array, key: String) -> String:
	if typeof(v) != TYPE_ARRAY:
		return key
	for e in (v as Array):
		if typeof(e) == TYPE_DICTIONARY and _row_bad(e, scalars, lists) != "":
			return key
	return ""


static func _hull_bad(v: Variant, key: String) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return ""
	var scalars: Array = ["name", "perk_id", "manufacturer"] + SaveGame.HULL_FIELDS
	return key if _row_bad(v, scalars, ["tier_perks"]) != "" else ""


static func scalar_bad(d: Dictionary) -> String:
	return _row_bad(d, _TOP_SCALARS, [])


static func _lists_bad(d: Dictionary) -> String:
	for k in ["installed", "cargo", "pad"]:
		var bad := _rows_bad(d.get(k, []), _ITEM_SCALARS, ["affixes", "hold_at"], str(k))
		if bad != "":
			return bad
	var dross: Variant = d.get("dross", [])
	if not (typeof(dross) == TYPE_INT or typeof(dross) == TYPE_FLOAT or _flat(dross)):
		return "dross"
	var fixed: Array = [
		["trail", not d.has("trail") or _flat(d["trail"])],
		["board_owned", typeof(d.get("board_owned")) != TYPE_ARRAY or _flat(d["board_owned"])],
		["rng", not d.has("rng") or (typeof(d["rng"]) == TYPE_DICTIONARY
			and _row_bad(d["rng"], _RNG_SCALARS, []) == "")],
		["galaxy", typeof(d.get("galaxy")) != TYPE_DICTIONARY
			or (d["galaxy"] as Dictionary).values().all(_scalar)],
		["standing", typeof(d.get("standing")) != TYPE_DICTIONARY
			or (d["standing"] as Dictionary).values().all(_scalar)],
		["found_scrap", typeof(d.get("found_scrap")) != TYPE_DICTIONARY
			or _row_bad(d["found_scrap"], ["credits", "material"], []) == ""],
	]
	for pair: Array in fixed:
		if not pair[1]:
			return String(pair[0])
	for k in ["hull", "found_hull", "old_hull"]:
		if _hull_bad(d.get(k), str(k)) != "":
			return k
	# Lists the loader skips when they are not lists, so only their rows are looked at.
	var rows: Array = [
		["contracts", ["id", "manufacturer", "kind", "state", "at", "posted_at", "pay", "standing",
			"amount", "text", "item"], []],
		["event_quests", ["at", "id", "from", "credits"], ["got"]],
		["ash_comms", ["line", "voice", "kind", "jump", "tutorial"], []],
		["parked", ["index", "at", "head", "mode", "cen", "r", "sense"], ["p", "v"]],
		["clocks", ["index", "t"], []],
	]
	for spec: Array in rows:
		var key := String(spec[0])
		if typeof(d.get(key)) == TYPE_ARRAY and _rows_bad(d[key], spec[1], spec[2], key) != "":
			return key
	return ""


## The map is a list with a system in it, and each system's fields are the kinds they are saved as.
static func _nodes_bad(d: Dictionary) -> String:
	var nodes: Variant = d.get("map", [])
	if typeof(nodes) != TYPE_ARRAY or (nodes as Array).is_empty():
		return "map"
	for e in (nodes as Array):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var n: Dictionary = e
		var bad := _row_bad(n, _NODE_SCALARS, _NODE_LISTS)
		for k in ["shop", "bag"]:
			if bad == "" and n.has(k):
				bad = _rows_bad(n[k], _ITEM_SCALARS, ["affixes", "hold_at"], str(k))
		if bad == "" and n.has("jetsam"):
			bad = _jetsam_bad(n["jetsam"])
		if bad == "" and n.has("said_of"):
			bad = "said_of" if typeof(n["said_of"]) != TYPE_ARRAY or not (n["said_of"] as Array).all(
				func(x: Variant) -> bool: return typeof(x) != TYPE_ARRAY or _flat(x)) else ""
		for k in ["pos", "gal"]:
			if bad == "" and typeof(n.get(k)) == TYPE_ARRAY and not _flat(n[k]):
				bad = str(k)
		if bad == "":
			bad = _hull_bad(n.get("shop_hull"), "shop_hull")
		if bad != "":
			return "map." + bad
	return ""


static func _jetsam_bad(v: Variant) -> String:
	if typeof(v) != TYPE_ARRAY:
		return "jetsam"
	for raw in (v as Array):
		if typeof(raw) != TYPE_DICTIONARY or _row_bad(raw, _JETSAM_SCALARS, []) != "":
			return "jetsam"
		var items: Variant = (raw as Dictionary).get("items", [])
		if _rows_bad(items, _ITEM_SCALARS, ["affixes", "hold_at"], "jetsam") != "":
			return "jetsam"
	return ""
