class_name MaterialData
extends HoldItem

## A material is an instance, as materials do not stack and a tally cannot say where each sits.
## Why: docs/why/MaterialData.md#materials


## The catalogue row this came from. The identity, and what a save stores --
## everything else on the instance is recoverable from the table.
@export var id: StringName = &""

## `common` through `legendary`, plus `contraband`, `exotic` and `artifact`.
## Carried rather than looked up because it decides the colour it draws in.
@export var tier: StringName = &"common"

## What a station pays. Flat, everywhere -- `MATERIALS_NOTE` §3.3. A regional
## multiplier can be added later without touching one row of the catalogue.
@export var value: int = 0

## The line it says when you look at it.
@export var text: String = ""

## Null art falls back to the authored container, but an ARTIFACT's own object is why you carry it.
## Why: docs/why/MaterialData.md#material-picture
@export var sprite: Texture2D = null


## Cells stay a string like `2x1` as authored; this is the one place it becomes a shape.
## Why: docs/why/MaterialData.md#material-cells
static func of(row: Dictionary) -> MaterialData:
	if row.is_empty():
		return null
	var m := MaterialData.new()
	m.id = StringName(row.get("id", &""))
	m.name = String(row.get("name", ""))
	m.tier = StringName(row.get("tier", &"common"))
	m.value = int(row.get("value", 0))
	m.text = String(row.get("text", ""))
	m.size = parse_cells(String(row.get("cells", "1x1")))
	# BY CONVENTION FROM THE ID, exactly as modules and hulls resolve theirs.
	# Built here rather than authored in the row so a new picture is a file drop.
	m.sprite = DB.material_sprite(m.id)
	return m


## Falls back to one cell, as a zero footprint would stack invisibly, which §3.1 rules out.
static func parse_cells(s: String) -> Vector2i:
	var parts := s.split("x")
	if parts.size() != 2:
		return Vector2i.ONE
	return Vector2i(maxi(1, int(parts[0])), maxi(1, int(parts[1])))


## Rebuilt from the table on load, so a changed row changes what you carry, not contradicts it.
static func by_id(id_: StringName) -> MaterialData:
	return of(MaterialTable.by_id(id_))


func hold_line() -> String:
	return "%s · %s" % [name, String(tier).to_upper()]
