extends Node

## HOW TALL THE STATION'S MOUTH MUST BE (Jon: "We need to have the ship door
## opening always be the same size, no matter what ship you are in. We need to
## have it as tall as the large ships."), headless:
##   godot --headless --path . -- sheet=MouthSize [weights=heavy,medium,light]
## Every manufacturer's hull at every weight asked for and every grade, every
## mount filled with its own parts (`StationShot`'s fit=full rule), measured on
## LOCAL at a station: where the whole fitted ship (its hull's ink and every part
## bolted on, `ShipView.fitted_rect_global`) is on the station's plate as its
## nose reaches the lips on the dock's approved curve (its size following `fly`
## from its own to its berth size). Prints each, and the rows the tallest needs.

var _tree: SceneTree


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _fit_full() -> void:
	var own: Array[ModuleData] = []
	for mid in DB.modules:
		var m: ModuleData = DB.modules[mid]
		if m.manufacturer == Run.hull.manufacturer:
			own.append(m)
	own.sort_custom(func(x: ModuleData, y: ModuleData) -> bool:
		if x.reactor != y.reactor:
			return x.reactor > y.reactor
		return x.cells() < y.cells())
	for p in 2:
		for m: ModuleData in own:
			if p == 0 and Run.installed.any(func(on: ModuleData) -> bool: return on.id == m.id):
				continue
			if Run.slots_used(m.slot) < Run.slots_for(m.slot) and Run.can_power(m):
				Run.install_module(m.duplicate(true) as ModuleData)


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			st = n.index
			break
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	Router.show_local()
	await _frames(90)
	var weights := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
	var top := INF
	var bot := -INF
	var who_top := ""
	var who_bot := ""
	for wn in _arg("weights", "heavy,medium,light").split(","):
		for m: StringName in DB.STARTABLE:
			for tier in HullData.TIER_NAMES.size():
				Run.fit_chassis(m, weights[wn], tier)
				_fit_full()
				Sig.ship_changed.emit()
				await _frames(4)
				var loc := Router.current as SectorScreen
				if loc == null or loc._face == null:
					continue
				loc._place_face()
				await _frames(2)
				var art := loc._view.ship_view()
				if art == null:
					continue
				var face := loc._face
				var to_plate := face.get_global_transform().affine_inverse()
				var ink := Rect2(art.ink_rect())
				var dim := ink.size * art.scale
				var mid_g := art.get_global_transform() * art.canvas_to_local(ink.get_center())
				var start := to_plate * mid_g - face.origin()
				var fr := art.fitted_rect_global()
				var ft := (to_plate * fr.position - face.origin()).y - start.y
				var fb := (to_plate * fr.end - face.origin()).y - start.y
				var s_end := minf(StationFace.SHIP_END_SCALE, minf(StationFace.SHIP_END_LEN / dim.x, StationFace.SHIP_END_H / dim.y))
				var berth := Vector2(StationFace.TAIL_IN + dim.x * s_end * 0.5, StationFace.ROW)
				var lo := 0.0
				var hi := 1.0
				for i in 40:
					var f := (lo + hi) * 0.5
					if lerpf(start.x, berth.x, f) + dim.x * lerpf(1.0, s_end, f) * 0.5 < StationFace.LIP_X:
						lo = f
					else:
						hi = f
				var fm := (lo + hi) * 0.5
				var sc := lerpf(1.0, s_end, fm)
				var yc := lerpf(start.y, berth.y, fm)
				var t := yc + ft * sc
				var b := yc + fb * sc
				var tag := "%s %s %s" % [wn, m, HullData.TIER_NAMES[tier]]
				print("  [mouth] %-22s %-18s ink %3.0fx%3.0f fitted %3.0f..%3.0f of its middle, %d parts; at the lips scale %.3f rows %.1f..%.1f (%.1f tall)" % [
					tag, Run.hull.name, dim.x, dim.y, ft, fb, Run.installed.size(), sc, t, b, b - t])
				if t < top:
					top = t
					who_top = tag
				if b > bot:
					bot = b
					who_bot = tag
	print("  [mouth] the tallest: top row %.1f (%s), bottom row %.1f (%s)" % [top, who_top, bot, who_bot])
	_tree.quit()
