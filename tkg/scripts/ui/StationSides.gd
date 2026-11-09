class_name StationSides
extends RefCounted

## The sides and interiors Jon kept (Oct 10-11), all sharing the Drum's entrance rows.
## Which a station gets is decided by seed and place alone, so no run stream is touched.
## Why: docs/why/StationSides.md#station-sides

const IDS: Array[StringName] = [&"drum1", &"drum3", &"pile1", &"pile3", &"pile4", &"shanty3", &"terraces"]
const INTERIORS: Array[StringName] = [&"iris_90_0", &"iris_220_1", &"hallway_90_1", &"hallway_130_0",
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
		# (the interiors on a stride of 5 through the 12: neighbours far apart; 5 and
		# 12 share no factor, so every interior comes round)
		out.interior = INTERIORS[(_mix(g + 104729) + rank * 5) % INTERIORS.size()]
	if force_side != &"":
		out.side = force_side
	if force_interior != &"":
		out.interior = force_interior
	return out
