extends Node

## Korvan's room layers drawn from a remembered pose (`ShipRoomKorvanPaint.recall`) still draw on the
## frame after: the whole 30 s loop stepped frame by frame, each such layer non-empty on every frame and
## every remembered pose still holding its drawing at the end (the office's clerks blinked, Nov 25).
## Also the hall lamps' relight after the engine test: each lamp jumps at most ~10 times a second there.
## Why: docs/why/ShipRoomKorvan.md#remembered-poses, docs/why/ShipRoomKorvan.md#relight

const LAYERS := {
	back = [&"office", &"rig_chain", &"rig_lit", &"rig_dark"],
	front = [&"tech_arm", &"tech_beam"],
}

var _tree: SceneTree
var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	var room := ShipRoom.make(&"korvan") as ShipRoomKorvan
	room.build()
	add_child(room.under)
	add_child(room.above)
	var layers: Dictionary[StringName, ShipRoomKorvanPaint] = {}
	for side: String in LAYERS:
		var d: Dictionary = room.back.p if side == "back" else room.front.p
		for n: StringName in LAYERS[side]:
			if h._ok("the room has its %s layer" % n, d.has(n)):
				layers[n] = d[n]
	var blank: Dictionary[StringName, int] = {}
	var first_blank: Dictionary[StringName, int] = {}
	for n in layers:
		blank[n] = 0
	for f in ShipRoomKorvanFilm.NF:
		room.t = f / 30.0
		room._tick(0.0)
		for n in layers:
			if layers[n]._kind.is_empty():
				blank[n] += 1
				if not first_blank.has(n):
					first_blank[n] = f
	for n in layers:
		var memo := layers[n]._memo
		var hollow := 0
		for k: Variant in memo:
			if (memo[k][0] as PackedByteArray).is_empty():
				hollow += 1
		h._ok("%s drew on all %d frames (blank on %d, first at %d)" % [n, ShipRoomKorvanFilm.NF, blank[n],
			first_blank.get(n, -1)], blank[n] == 0)
		h._ok("%s remembers %d poses, %d of them emptied" % [n, memo.size(), hollow],
			not memo.is_empty() and hollow == 0)
	room.under.queue_free()
	room.above.queue_free()
	_relight()
	h.verdict("shiproommemotest")
	_tree.quit(h.code())


## The relight (film frames 506-548): a lamp of the film's own jumps up to 11 times a second (27 counting all
## lamps); the drawn ones (Jon's pick A, Nov 26) hold each value 3 or 4 frames. A jump is a change over 5%; the
## slow brightening before the relight is not one.
func _relight() -> void:
	ShipRoomKorvanLight.F.ensure()
	var L := ShipRoomKorvanLight.new()
	var film: Array = ShipRoomKorvanLight.F.D["lamps"]
	var n := (film[0] as Array).size()
	var raw_most := 0
	var drawn_most := 0
	var prev := PackedFloat32Array()
	var drawn := PackedInt32Array()
	drawn.resize(n)
	for f in range(506, 549):
		L._lamps(f, 0.0)
		var tw: PackedFloat32Array = L.u[&"tw"]
		for i in n:
			if f > 506 and absf(tw[i] - prev[i]) > 0.05:
				drawn[i] += 1
		prev = tw.duplicate()
	for i in n:
		var raw := 0
		for f in range(507, 549):
			if absi(int((film[f] as Array)[i]) - int((film[f - 1] as Array)[i])) > 500:
				raw += 1
		raw_most = maxi(raw_most, raw)
		drawn_most = maxi(drawn_most, drawn[i])
	var secs := 42.0 / 30.0
	h._ok("the film's relight blinks fast (%.1f/s at most), so this check can see it" % (raw_most / secs),
		raw_most / secs > 10.5)
	h._ok("the drawn relight stutters at %.1f/s at most (at most 10.5)" % (drawn_most / secs),
		drawn_most / secs <= 10.5)
