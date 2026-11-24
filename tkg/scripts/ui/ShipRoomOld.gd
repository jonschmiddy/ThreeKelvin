class_name ShipRoomOld
extends ShipRoom

## The Old hangar's mothball racks (Jon, Nov 24: A16 approved, A17's lamp): a locked maker's tarps
## under one failing sodium lamp, lit as two layers (ambient, and the lamp x its level).
## Why: docs/why/ShipRoomOld.md#two-layers

## The film's loop: the lamp's schedule, the wind and the dust all run on it (each seamless at the wrap).
const LOOP := 10.0
const FPS := 30.0
## The lamp's long outages: (start s, seconds out, the frames of the stutter back on).
const OFFS := [[2.05, 0.75, [1.0, 1.0, 0.03, 0.03, 1.0, 0.05, 1.0, 1.0, 0.04]],
	[5.55, 1.30, [1.0, 0.03, 0.03, 1.0, 1.0, 0.05, 0.05, 0.05, 1.0, 0.06]]]
## Its flickers: (start s, one level a frame at 30 fps).
const BURSTS := [[1.30, [0.08, 0.08, 1, 1, 1, 0.10, 1, 1, 0.06, 0.06, 0.06, 1, 1, 0.12, 1, 1, 1, 1, 0.08, 0.08]],
	[3.10, [0.10, 0.10]],
	[4.70, [0.07, 1, 1, 0.10, 0.10, 1, 0.08, 0.08]],
	[7.40, [0.10, 0.10, 1, 0.06, 1, 1, 1, 0.10, 0.10, 0.10, 1, 1, 0.08, 1, 1, 0.12, 0.12, 1, 1, 1, 0.06, 0.06]],
	[8.90, [0.08]]]

var _level := 1.0


func hull_amb() -> float:
	return 0.35


func tuck() -> int:
	return 4


func band_colour() -> Color:
	return Color8(9, 8, 7)


func _build() -> void:
	var sh := preload("res://shaders/ship_room_old.gdshader")
	for m: ShaderMaterial in [_mat_room, _mat_thing, _mat_hull]:
		m.shader = sh
		m.set_shader_parameter(&"albedo", tex(id, "albedo.png"))
		m.set_shader_parameter(&"amb", tex(id, "amb.png"))
		m.set_shader_parameter(&"lamp", tex(id, "lamp.png"))
		m.set_shader_parameter(&"emissive", tex(id, "emissive.png"))
	_tick(0.0)


## Each tarp takes its dusty, padded wind texture (`export.py`); a maker with none wears Solari's.
func _placed() -> void:
	for st: Variant in sets:
		var s := st as YardStandSet
		if s == null or s._tarp == null or s._tarp.texture == null:
			continue
		var wt := tex(id, "tarps/" + s._tarp.texture.resource_path.get_file())
		if wt == null:
			wt = tex(id, "tarps/solari_%s.png" % YardStandSet.TARP_WEIGHT[s.weight])
		s._tarp.set_wind(wt)


## The lamp's level `u` seconds into the loop: out is out (0), the stutters and flickers are
## whole frames at 30 fps, and a steady lamp hums +-3 %.
## Why: docs/why/ShipRoomOld.md#the-lamp
static func lamp_at(u: float) -> float:
	for o: Array in OFFS:
		var t0 := float(o[0])
		var ln := float(o[1])
		if u >= t0 and u < t0 + ln:
			return 0.0
		var back: Array = o[2]
		var k := int(roundf((u - t0 - ln) * FPS))
		if k >= 0 and k < back.size():
			return float(back[k])
	var f := 1.0
	for b: Array in BURSTS:
		var steps: Array = b[1]
		var k := int(roundf((u - float(b[0])) * FPS))
		if k >= 0 and k < steps.size():
			f = float(steps[k])
	return f * (1.0 + 0.018 * sin(TAU * 3.0 * u / LOOP) + 0.012 * sin(TAU * 7.0 * u / LOOP + 1.0))


func _tick(_dt: float) -> void:
	var u := fmod(t, LOOP)
	_level = lamp_at(u) * lamp_k
	for m: ShaderMaterial in [_mat_room, _mat_thing, _mat_hull]:
		m.set_shader_parameter(&"level", _level)
		m.set_shader_parameter(&"t", u)
