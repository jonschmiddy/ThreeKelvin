class_name MaterialData
extends HoldItem

## One physical thing in your hold that is not a module.
##
## `MaterialTable` is the catalogue -- 64 authored rows with ids, tiers, shapes,
## values and text. This is the INSTANCE: the particular crate of deck plate you
## are carrying, which knows where it sits.
##
## Two rules from `docs/briefs/MATERIALS_NOTE.md` shape this class:
##
## §3.1 -- materials DO NOT STACK. Two coil stock take two cells. Which is why
## this is an instance rather than a tally on the hold, per §3.2: a tally cannot
## say "one is here and the other is over there".
##
## §1 -- credits are the only currency. A material carries a `value`, and that
## value is what a station PAYS for it. It never prices anything.


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

## Its picture, or null while it has none.
##
## THE SAME SHAPE `ModuleData.sprite` USES, and for the same reason: the icon
## draws art when there is art and the authored container when there is not, so
## a material without a picture is a crate rather than a hole. `MaterialIcon`'s
## own note argues a material should read as cargo rather than as its contents,
## and that argument still holds for the forty rows of deck plate and coil stock
## -- what it did not anticipate is an ARTIFACT, which is the one tier where the
## object itself is the reason you are carrying it.
@export var sprite: Texture2D = null


## Build one from its catalogue row.
##
## `cells` is a string in the table -- "2x1" -- because that is how it was
## authored, and the note is explicit that the shape is a decision somebody
## already made rather than something to derive from a name later. Parsing it
## here is the one place that string becomes a shape.
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


## "2x1" -> Vector2i(2, 1). Falls back to a single cell rather than to zero,
## because an item with no footprint would occupy nothing and stack invisibly --
## which is the one behaviour §3.1 rules out.
static func parse_cells(s: String) -> Vector2i:
	var parts := s.split("x")
	if parts.size() != 2:
		return Vector2i.ONE
	return Vector2i(maxi(1, int(parts[0])), maxi(1, int(parts[1])))


## Rebuilt from the catalogue, for loading a save. Only the id and the cell are
## stored; a row that changed between versions changes what you are carrying,
## which is the right answer -- the alternative is a save that contradicts the
## table it was authored against.
static func by_id(id_: StringName) -> MaterialData:
	return of(MaterialTable.by_id(id_))


func hold_line() -> String:
	return "%s · %s" % [name, String(tier).to_upper()]
