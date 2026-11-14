extends Node

## The Promenade and the Exchange load their art ahead of the first ride (`RoomsAhead`) or on first
## draw; both must leave the same pages. Per development level: a docking left idle until loaded, and
## dockings ridden at once, in each order of first visit; every deck visited; both pages dumped whole
## and compared inside the run (no stored baseline). `-- sheet=StationAheadTest [dev=N] [dump=<dir>]`,
## with `--fixed-fps 60`. Why: docs/why/StationScreen.md#rooms-ahead

const DECKS: Array[StringName] = [&"services", &"work", &"stock", &"hold", &"bench"]

var h := Harness.new()
var _tree: SceneTree


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _station(dev: int, seed0: int) -> MapGen.MapNode:
	Rng.forced = seed0
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = dev
	here.security = 4
	here.danger = 5
	here.in_nebula = false
	here.berths.clear()
	here.manufacturer = &""
	return here


func _dock(here: MapGen.MapNode) -> StationScreen:
	Router.powered.clear()
	Router.park_at_station(here)
	Router.show_station()
	await Harness.frames(_tree, 2)
	return Router.current as StationScreen


## One floor change, waited out.
func _ride(st: StationScreen, id: StringName) -> void:
	(st._tabs[id] as Button).pressed.emit()
	var guard := 0
	while st.deck_changing() and guard < 600:
		guard += 1
		await _tree.process_frame
	await Harness.frames(_tree, 3)


## What decides a picture, as a string: the same on every run that should draw the same.
static func _tex(t: Variant) -> String:
	if not (t is Texture2D):
		return "-"
	var tx := t as Texture2D
	var img := tx.get_image() if not (tx is ViewportTexture) else null
	return "%s %s %s" % [tx.resource_path, tx.get_size(), str(hash(img.get_data())) if img != null else "-"]


static func _box(b: StyleBoxTexture) -> String:
	return "-" if b == null else "%s margins %s" % [_tex(b.texture), var_to_str([b.texture_margin_left,
		b.texture_margin_top, b.texture_margin_right, b.texture_margin_bottom, int(b.axis_stretch_horizontal),
		int(b.axis_stretch_vertical), b.draw_center])]


static func _node(n: Node, path: String, out: PackedStringArray) -> void:
	var line := "%s %s" % [path, n.get_class()]
	if n.get_script() != null:
		line += " <%s>" % String(n.get_script().get_global_name())
	if n is CanvasItem:
		var c := n as CanvasItem
		line += " vis=%s z=%d mod=%s" % [c.visible, c.z_index, var_to_str(c.modulate)]
	if n is Control:
		var c := n as Control
		line += " pos=%s size=%s scale=%s" % [var_to_str(c.position), var_to_str(c.size), var_to_str(c.scale)]
	elif n is Node2D:
		line += " pos=%s" % var_to_str((n as Node2D).position)
	for prop in ["texture", "art", "art_override"]:
		if prop in n:
			line += " %s=%s" % [prop, _tex(n.get(prop))]
	if n is Label:
		line += " text=%s" % (n as Label).text
	if n is ShopScene:
		line += _room(n as ShopScene)
	out.append(line)
	for i in n.get_child_count():
		_node(n.get_child(i), "%s/%d" % [path, i], out)


## The room's own state: what it picked and what it will draw from.
static func _room(r: ShopScene) -> String:
	var s := " plate_key=%s bd=%s bd_drop=%s bd_pos=%s reflect=%s tone=%s" % [r._plate_key, r._bd_id,
		r._bd_drop, var_to_str(r._bd_pos), r._reflect, var_to_str(r._tone)]
	s += " light=%d/%s" % [r._light_bytes.size(), str(hash(r._light_bytes))]
	s += " light_node=%s" % (str(r._light_node.visible) if r._light_node != null else "-")
	var keys := r._tex.keys()
	keys.sort()
	for k in keys:
		s += "\n    tex %s %s" % [k, _tex(r._tex[k])]
	for i in r._views.size():
		s += "\n    view %d %s" % [i, _tex(r._views[i])]
	s += "\n    backdrop %s" % _tex(r._backdrop) if not (r._backdrop is ViewportTexture) else "\n    backdrop sky"
	s += "\n    wall %s trim %s door %s window %s" % [_tex(r._plate_wall), _tex(r._plate_trim),
		_box(r._box_door), _box(r._box_window)]
	if r is ExchangeScene:
		var e := r as ExchangeScene
		s += "\n    hold_size=%s frame=%s opening=%s view_tex=%s" % [e.hold_size, var_to_str(e.frame_rect()),
			var_to_str(e.hold_opening()), _tex(e._view_tex)]
		if e._sky != null:
			s += "\n    sky node=%d frame_in=%s size=%s update=%d" % [e._sky_for.index if e._sky_for != null else -1,
				var_to_str(e._sky.frame_in), var_to_str(e._sky.size), e._sky_vp.render_target_update_mode]
	return s


func _dump(st: StationScreen) -> String:
	var out := PackedStringArray()
	for id in [&"stock", &"hold"]:
		out.append("== page %s" % id)
		_node(st._pages[id], "p", out)
	return "\n".join(out)


## Both rooms have what a draw would have loaded for them.
func _loaded(st: StationScreen) -> bool:
	return st._shop._plate_key != &"" and st._exchange._plate_key != &"" and st._exchange._sky != null


func _visit_all(st: StationScreen, order: Array[StringName]) -> void:
	await Harness.frames(_tree, 2)
	for id in order:
		await _ride(st, id)
	await _ride(st, &"services")
	await Harness.frames(_tree, 20)


func _one(dev: int, seed0: int, label: String, wait: bool, order: Array[StringName]) -> String:
	var st := await _dock(_station(dev, seed0))
	if wait:
		# Idle: the quiet spell, then a step a frame.
		var n := 0
		while not _loaded(st) and n < 400:
			n += 1
			await _tree.process_frame
		h._ok("%s dev %d: both rooms loaded ahead, while hidden (%d frames)" % [label, dev, n],
			(_loaded(st) or Harness.arg("baseline") != "") and not st._shop.is_visible_in_tree() and not st._exchange.is_visible_in_tree())
		await Harness.frames(_tree, 3)
		var ra: Variant = null
		for c in st.get_children():
			if c is RoomsAhead:
				ra = c
		h._ok("%s dev %d: the ahead-load stopped once done" % [label, dev], ra != null and ra._done)
	else:
		h._ok("%s dev %d: nothing loaded yet when the ride starts" % [label, dev],
			st._shop._plate_key == &"" and st._exchange._plate_key == &"" and st._exchange._sky == null)
	await _visit_all(st, order)
	h._ok("%s dev %d: both loaded after the visit" % [label, dev], _loaded(st))
	var d := _dump(st)
	if Harness.arg("dump") != "":
		var f := FileAccess.open("%s/%s_dev%d.txt" % [Harness.arg("dump"), label, dev], FileAccess.WRITE)
		f.store_string(d)
	return d


func _run() -> void:
	await _tree.process_frame
	Router.animate_in_harness = true
	var seed0 := h.seed_run(777)
	var devs: Array[int] = [0, 1, 2, 3, 4]
	if Harness.arg("dev") != "":
		devs = [int(Harness.arg("dev"))]
	var sh: Array[StringName] = [&"stock", &"hold"]
	var hs: Array[StringName] = [&"hold", &"stock"]
	for dev in devs:
		var ahead_sh := await _one(dev, seed0, "ahead-stock-first", true, sh)
		var ahead_hs := await _one(dev, seed0, "ahead-hold-first", true, hs)
		var lazy_sh := await _one(dev, seed0, "lazy-stock-first", false, sh)
		var lazy_hs := await _one(dev, seed0, "lazy-hold-first", false, hs)
		h._ok("dev %d: the dump is not empty (%d chars)" % [dev, ahead_sh.length()], ahead_sh.length() > 2000)
		h._ok("dev %d: ahead and lazy leave the same pages (stock first)" % dev, ahead_sh == lazy_sh)
		h._ok("dev %d: ahead and lazy leave the same pages (hold first)" % dev, ahead_hs == lazy_hs)
		h._ok("dev %d: the order of first visit changes nothing" % dev, ahead_sh == ahead_hs and lazy_sh == lazy_hs)
	h.verdict("stationaheadtest")
	_tree.quit(h.code())
