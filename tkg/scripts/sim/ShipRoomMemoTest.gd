extends Node

## Korvan's room layers drawn from a remembered pose (`ShipRoomKorvanPaint.recall`) still draw on the
## frame after: the whole 30 s loop stepped frame by frame, each such layer non-empty on every frame and
## every remembered pose still holding its drawing at the end (the office's clerks blinked, Nov 25).
## Why: docs/why/ShipRoomKorvan.md#remembered-poses

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
	h.verdict("shiproommemotest")
	_tree.quit(h.code())
