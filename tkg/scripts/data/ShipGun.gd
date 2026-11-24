class_name ShipGun
extends RefCounted

## A weapon's picture as it stands on the ship, not its hold icon: drawn at full size with
## `anchor` on the hull's mount point. `art/tools/ship_guns.py` writes the table.
## Why: docs/why/Database.md#on-ship-guns

const TABLE := "res://art/sprites/guns/guns.json"

var tex: Texture2D
## The gun's contact point in its own pixels: under a top gun's foot, or a belly gun's top row.
var anchor := Vector2.ZERO

static var _tables: Dictionary[StringName, Dictionary] = {}
static var _cache: Dictionary = {}


## The picture of module `id` for a `side` (`&"top"` or `&"belly"`) mount, or null when
## there is none and the hold icon stands in. With a `manufacturer`, that manufacturer's drawing of the
## gun when it has one. Why: docs/why/ShipGun.md#manufacturer-drawn-yard-guns
static func of(id: StringName, side: StringName, manufacturer: StringName = &"") -> ShipGun:
	var ck := "%s|%s|%s" % [id, side, manufacturer]
	if _cache.has(ck):
		return _cache[ck]
	var g: ShipGun = null
	if manufacturer != &"":
		g = _entry(_table_of(manufacturer), manufacturer_dir(manufacturer), id, side)
	if g == null:
		g = _entry(_table_of(&""), TABLE.get_base_dir(), id, side)
	_cache[ck] = g
	return g


## The folder of `manufacturer`'s drawings of the unbranded guns (`art/tools/manufacturer_guns.py`).
static func manufacturer_dir(manufacturer: StringName) -> String:
	return TABLE.get_base_dir().path_join(String(manufacturer))


## One table's picture of `id` on `side`, its files in `dir`, or null.
static func _entry(table: Dictionary[String, Variant], dir: String, id: StringName, side: StringName) -> ShipGun:
	var e: Variant = table.get(String(id), {})
	var d: Variant = (e as Dictionary).get(String(side)) if e is Dictionary else null
	if not d is Dictionary:
		return null
	var path := dir.path_join(String((d as Dictionary).get("file", "")))
	var a: Variant = (d as Dictionary).get("anchor", [])
	if not ResourceLoader.exists(path) or not a is Array or (a as Array).size() != 2:
		return null
	var g := ShipGun.new()
	g.tex = load(path) as Texture2D
	g.anchor = Vector2(float(a[0]), float(a[1]))
	return g


## Every module id with an on-ship picture.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in _table_of(&""):
		out.append(StringName(k))
	return out


## The size of the picture in its own pixels.
func size() -> Vector2:
	return Vector2(tex.get_size()) if tex != null else Vector2.ZERO


## A table as the tools wrote it, read once: {id: {side: {file, anchor}}}; `&""` is the
## plain guns' (`ship_guns.py`), a manufacturer's is its own folder's (`manufacturer_guns.py`).
static func _table_of(manufacturer: StringName) -> Dictionary[String, Variant]:
	if not _tables.has(manufacturer):
		var path := TABLE if manufacturer == &"" else manufacturer_dir(manufacturer).path_join(TABLE.get_file())
		var t: Dictionary[String, Variant] = {}
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				t.assign(d)
		_tables[manufacturer] = t
	return _tables[manufacturer]
