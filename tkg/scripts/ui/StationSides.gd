class_name StationSides
extends RefCounted

## THE STATION SIDES JON KEPT (Oct 10-11): seven sides and thirteen interiors,
## the pool every station on LOCAL is drawn from (`StationFace`).
##
## THE SIDES: the Drum takes 1 and 3, the Container Pile takes 1, 3 and 4, the
## Shanty take 3 and the Terraces (s115_1). Every one carries the Drum's
## entrance at the same rows, so the hallway, the recess, the inner door, the
## lips and the camera's numbers are the Drum's for all of them (`StationFace`'s
## SLOT, RECESS, DOOR_X, LIP_X, EDGE_X). All seven are lit and split by
## `art/stations/sides.py` (Jon's 1A for lights and depth, "all of it"): the star's
## rim, shaded undersides, near-over-far layers (the piles' boxes) that move
## by whole pixels as the camera comes in, the bay lit from its inner door, and
## the lamps drawn as light, Drum take 1 too (Jon's 2B). Every side's hallway is
## 48 rows taller than painted (`art/stations/mouth.py`: one mouth for every
## ship, tall enough for the tallest). The five sides recovered from LOCAL frames (Drum 3, the Piles, the Shanty)
## had their right ends painted by PixelLab (Jon's 1B, `art/stations/src/
## painted/`), so the camera following your ship in sees the side's own hull,
## not a repeat.
##
## THE INTERIORS (Jon: "For the entrance I wanted this part changed"): the
## recess only, plate x 84..211, rows 206..331, drawn over the bay; the lips, the
## gold frame and the lamp strip are the side's own. Each was made 48 rows taller
## from its own art (`sides.py`'s `interiors`: rows that repeat, copied) -- the
## six hallways and four cargo bays; the three irises, whose rings would have
## stretched to pills, repainted at the new height (Jon's "Irises: A").
##
## WHICH ONE A STATION GETS: decided by the station alone -- this galaxy's seed
## and the station's place among the map's stations -- so it is the same on
## every visit, after SAVE & EXIT and CONTINUE, and nothing is rolled for it
## (the run's random streams are never touched). The map's stations take the
## sides in turn from a start the seed sets, so neighbours differ while there
## are sides to go round; the interiors the same way, on their own start and
## stride.

const IDS: Array[StringName] = [&"drum1", &"drum3", &"pile1", &"pile3", &"pile4", &"shanty3", &"terraces"]
const INTERIORS: Array[StringName] = [&"iris_90_0", &"iris_90_1", &"iris_220_1", &"hallway_90_1", &"hallway_130_0",
	&"hallway_130_1", &"hallway_170_0", &"hallway_170_1", &"hallway_220_0", &"cargo_90_0", &"cargo_130_0",
	&"cargo_130_1", &"cargo_170_0"]
const NONE := &"none"
## where an interior is drawn (plate px): the recess the door lights
const INTERIOR_AT := Vector2(84, 206)

## (harnesses: a side and an interior for every station, instead of the pick;
## `NONE` for no interior)
static var force_side := &""
static var force_interior := &""


## One side, loaded.
class SideArt:
	var id: StringName
	## its layers, far first: [texture, parallax], parallax 1 the nearest
	var layers: Array = []
	## the hull less the bay in one dark tone, under the layers
	var solid: Texture2D
	var lamps: Texture2D
	var bay_dark: Texture2D
	var bay_lit: Texture2D
	var bay_at := Vector2(76, 206)
	## the lamps that are not the entrance's: {rect, kind, color, radius, group}
	var extra: Array = []
	## the lights drawn in code: {kind, at, radius, color, period, offset}
	var code: Array = []
	## the hull the camera tiles past the plate: the plate's own window
	## `hull_src` repeated from `hull_x0`, where the plate is cut off
	var hull_src := Rect2()
	var hull_x0 := 0.0


static var _sides := {}
static var _interiors := {}


static func side(id: StringName) -> SideArt:
	if not IDS.has(id):
		id = &"drum1"
	if _sides.has(id):
		return _sides[id]
	var s := SideArt.new()
	s.id = id
	var dir := "res://art/stations/%s/" % id
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json"))
	for l: Dictionary in data.layers:
		s.layers.append([load(dir + String(l.file)), float(l.parallax)])
	s.solid = load(dir + "solid.png")
	s.lamps = load(dir + "lamps.png")
	s.bay_dark = load(dir + "bay_dark.png")
	s.bay_lit = load(dir + "bay_lit.png")
	var bb: Array = data.bay
	s.bay_at = Vector2(float(bb[0]), float(bb[1]))
	for l: Dictionary in data.lamps:
		var r: Array = l.rect
		s.extra.append({"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), "kind": StringName(l.kind),
			"color": Color(String(l.color)), "radius": int(l.glow_radius), "group": StringName(l.group)})
	for c: Dictionary in data.code_lights:
		var at: Array = c.at
		s.code.append({"kind": StringName(c.kind), "at": Vector2(float(at[0]), float(at[1])), "radius": int(c.radius),
			"color": Color(String(c.color)), "period": float(c.period), "offset": float(c.get("offset", 0.0))})
	var h: Array = (data.hull as Dictionary).src
	s.hull_src = Rect2(float(h[0]), float(h[1]), float(h[2]), float(h[3]))
	s.hull_x0 = float((data.hull as Dictionary).x0)
	_sides[id] = s
	return s


## An interior's two pictures, [dark, lit] (the recess, 128 x 126), or [] for none.
static func interior(id: StringName) -> Array:
	if not INTERIORS.has(id):
		return []
	if not _interiors.has(id):
		var dir := "res://art/stations/interiors/%s/" % id
		_interiors[id] = [load(dir + "dark.png"), load(dir + "lit.png")]
	return _interiors[id]


## A small, fixed scramble of a number (no random stream is touched).
static func _mix(x: int) -> int:
	x = (x ^ (x >> 16)) * 0x45d9f3b
	x &= 0x7fffffff
	x = (x ^ (x >> 16)) * 0x45d9f3b
	x &= 0x7fffffff
	return x ^ (x >> 16)


## The side and interior a station gets: {"side", "interior"}.
static func pick(n: MapGen.MapNode) -> Dictionary:
	var out := {"side": &"drum1", "interior": NONE}
	if n != null:
		# the station's place among the map's stations (its index if the map
		# does not hold it)
		var rank := n.index
		var k := 0
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			if m == n:
				rank = k
				break
			if m.type == MapGen.NodeType.STATION:
				k += 1
		var g := Run.galaxy_seed & 0x7fffffff
		out.side = IDS[(_mix(g + 7919) + rank) % IDS.size()]
		# (the interiors on a stride of 5 through the 13: neighbours far apart)
		out.interior = INTERIORS[(_mix(g + 104729) + rank * 5) % INTERIORS.size()]
	if force_side != &"":
		out.side = force_side
	if force_interior != &"":
		out.interior = force_interior
	return out
