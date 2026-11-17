class_name ShipGun
extends RefCounted

## A weapon's picture as it stands on the ship, not its hold icon: drawn at full size with
## `anchor` on the hull's mount point. `art/tools/ship_guns.py` writes the table.
## Why: docs/why/Database.md#on-ship-guns

const TABLE := "res://art/sprites/guns/guns.json"

var tex: Texture2D
## The gun's contact point in its own pixels: under a top gun's foot, or a belly gun's top row.
var anchor := Vector2.ZERO

static var _table: Dictionary = {}
static var _cache: Dictionary = {}


## The picture of module `id` for a `side` (`&"top"` or `&"belly"`) mount, or null when
## there is none and the hold icon stands in.
static func of(id: StringName, side: StringName) -> ShipGun:
	var ck := "%s|%s" % [id, side]
	if _cache.has(ck):
		return _cache[ck]
	var g: ShipGun = null
	_load()
	var e: Variant = _table.get(String(id), {})
	var d: Variant = (e as Dictionary).get(String(side)) if e is Dictionary else null
	if d is Dictionary:
		var path := TABLE.get_base_dir().path_join(String((d as Dictionary).get("file", "")))
		var a: Variant = (d as Dictionary).get("anchor", [])
		if ResourceLoader.exists(path) and a is Array and (a as Array).size() == 2:
			g = ShipGun.new()
			g.tex = load(path) as Texture2D
			g.anchor = Vector2(float(a[0]), float(a[1]))
	_cache[ck] = g
	return g


## The size of the picture in its own pixels.
func size() -> Vector2:
	return Vector2(tex.get_size()) if tex != null else Vector2.ZERO


## The table as `ship_guns.py` wrote it, read once: {id: {side: {file, anchor}}}.
static func _load() -> void:
	if _table.is_empty() and FileAccess.file_exists(TABLE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
		_table = d if d is Dictionary else {"_": true}
