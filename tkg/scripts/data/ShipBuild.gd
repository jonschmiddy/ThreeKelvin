class_name ShipBuild
extends RefCounted

## @guarded-by NetSession.PROTOCOL
## This file is the wire format: a renamed key is a protocol change (`NetSession.PROTOCOL`).
## It carries what is drawn, not played, so any field the renderer reads must arrive here.
## Why: docs/why/ShipBuild.md#wire-format

## Who is flying it. Empty for your own ship, which needs no label.
var pilot: String = ""
var hull: HullData = null
## Plain dictionaries: writing a sender's `mount` onto shared `DB.modules[id]` moves all ships.
## Why: docs/why/ShipBuild.md#parts
var parts: Array = []

## The specification class, 0..3 — C, B, A, S. Sent because the SPRITE is keyed
## on it. See the header.
var tier: int = 0

var hp: int = 1
var max_hp: int = 1
var heat: int = 0
var heat_cap: int = 1
var dead: bool = false


## The ship you are flying, as it stands right now.
static func local() -> ShipBuild:
	var b := ShipBuild.new()
	b.hull = Run.hull
	# Before a run, and on the title screen. Every gauge below sums over the
	# hull, so asking one of them here is an error rather than a zero.
	if b.hull == null:
		return b
	b.tier = b.hull.tier
	for m in Run.installed:
		b.parts.append(part_entry(m))
	b.hp = Run.hp
	b.max_hp = maxi(1, Run.max_hp())
	b.heat = Run.heat
	b.heat_cap = maxi(1, Run.heat_cap())
	b.dead = Run.dead
	return b


## The ship you are leaving is no longer `Run.hull`, but the transfer screen must draw it armed.
## Why: docs/why/ShipBuild.md#fitted-out
static func fitted_out(h: HullData, parts_on: Array) -> ShipBuild:
	var b := showroom(h)
	if h == null:
		return b
	for raw in parts_on:
		var m := raw as ModuleData
		# A crate has no mount and no slot. The pad carries both kinds, and
		# asking a lump of ore which hardpoint it is on would draw a gun.
		if m == null or m.mount < 0:
			continue
		b.parts.append(part_entry(m))
	return b


## One place knows a part's wire shape: two copies of a serialised shape drift (`version_guard.py`).
## Why: docs/why/ShipBuild.md#part-entry
static func part_entry(m: ModuleData) -> Dictionary:
	return {
		"slot": int(m.slot),
		"mount": maxi(m.mount, 0),
		"manufacturer": m.manufacturer,
		"id": m.id,
	}


## An ordinary build with no parts, replacing the old `preview` flag and its draw branches.
## Why: docs/why/ShipBuild.md#showroom
static func showroom(h: HullData) -> ShipBuild:
	var b := ShipBuild.new()
	b.hull = h
	if h != null:
		b.tier = h.tier
		b.hp = maxi(1, h.max_hull)
		b.max_hp = maxi(1, h.max_hull)
		b.heat_cap = maxi(1, h.heat_cap)
	return b


## Capped at 1.7: past that the ship is already white and more only moves numbers.
func heat_ratio() -> float:
	return minf(1.7, float(heat) / float(maxi(1, heat_cap)))


## How beaten up, 0 to 1. Drives where the scorch marks go.
func damage() -> float:
	return 1.0 - float(hp) / float(maxi(1, max_hp))


# --- the wire -------------------------------------------------------------

func to_wire() -> Dictionary:
	return {
		"pilot": pilot,
		"manufacturer": hull.manufacturer if hull != null else &"",
		"weight": int(hull.weight) if hull != null else int(HullData.Weight.MEDIUM),
		"tier": tier,
		"parts": parts,
		"hp": hp,
		"max_hp": max_hp,
		"heat": heat,
		"heat_cap": heat_cap,
		"dead": dead,
	}


## Everything off a socket is checked: a weight of 99 gives no hull and downs the sector screen.
## Why: docs/why/ShipBuild.md#from-wire
static func from_wire(d: Dictionary) -> ShipBuild:
	var b := ShipBuild.new()
	b.pilot = String(d.get("pilot", ""))
	var w := clampi(int(d.get("weight", int(HullData.Weight.MEDIUM))),
		int(HullData.Weight.LIGHT), int(HullData.Weight.HEAVY)) as HullData.Weight
	b.hull = DB.hull_for(StringName(d.get("manufacturer", &"")), w)
	# Falls back to the unbranded frame: a wrong-looking partner is easier to notice than none.
	if b.hull == null:
		b.hull = DB.hull_for(&"", w)
	# The grade picks the sprite; `at_tier()` returns a duplicate, so shared frames stay ungraded.
	# Why: docs/why/ShipBuild.md#from-wire
	b.tier = clampi(int(d.get("tier", 0)), 0, HullData.TIER_NAMES.size() - 1)
	if b.hull != null:
		b.hull = DB.at_tier(b.hull, b.tier)
	var sent: Variant = d.get("parts", [])
	b.parts = sent if sent is Array else []
	b.hp = int(d.get("hp", 1))
	b.max_hp = maxi(1, int(d.get("max_hp", 1)))
	b.heat = int(d.get("heat", 0))
	b.heat_cap = maxi(1, int(d.get("heat_cap", 1)))
	b.dead = bool(d.get("dead", false))
	return b


## The shared catalogue entry, never a copy; null while a module has no art.
static func art_for(part: Dictionary) -> ModuleData:
	return DB.modules.get(StringName(part.get("id", &"")))
