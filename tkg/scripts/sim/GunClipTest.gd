extends Node

## No view cuts a gun: Korvan's medium and heavy, the longest gun each mount takes on every mount,
## through LOCAL, the cutaway, a fight, the yard and the refit page; every gun's whole box inside
## every clip above it (`MountPoints.clipped_guns`). `-- sheet=GunClipTest` (headless).
## Why: docs/why/Database.md#on-ship-guns

var h := Harness.new()
var _shots := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_shots = Harness.arg("shots", "")
	await Harness.frames(get_tree(), 10)
	for w: HullData.Weight in [HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		await _views(w)
	# the front door's ship choice: every chassis on its stands with its launch weapons
	Router.show_chassis_select()
	await Harness.frames(get_tree(), 120)
	_check("ship choice", "choice")
	h.verdict("guncliptest")
	get_tree().quit(h.code())


func _views(w: HullData.Weight) -> void:
	var name := HullData.weight_name(w).to_lower()
	_fit(w)
	Router.show_local()
	# (past your ship's arrival from the left edge)
	await Harness.frames(get_tree(), 400)
	_check("%s LOCAL" % name, "local_%s" % name)
	var sc := Router.current as SectorScreen
	if sc != null:
		var cut := sc.open_cutaway()
		await Harness.frames(get_tree(), 60)
		_check("%s cutaway" % name, "cutaway_%s" % name)
		if cut != null:
			cut.close_now()
			await Harness.frames(get_tree(), 30)
	var pool := DB.fight_pool(3, false)
	Router.start_combat(DB.enemies[pool[0]])
	await Harness.frames(get_tree(), 240)
	_check("%s fight" % name, "fight_%s" % name)
	# the ship-loss picture is cut from the hull and its guns: grown so none touches its edge
	var fsc := Router.current as SectorScreen
	var pic := ShipLoss.picture(fsc._view.ship_view()) if fsc != null and fsc._view != null else {}
	h._ok("%s ship-loss picture: taken, no gun cut at its edge" % name, not pic.is_empty() and _edge_clear(pic.img))
	if _shots != "" and not pic.is_empty():
		(pic.img as Image).save_png("%s/shiploss_%s.png" % [_shots, name])
	Router.drop_combat()
	await Harness.frames(get_tree(), 30)
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	here.security = 4
	Router.park_at_station(here)
	Router.show_station()
	await Harness.frames(get_tree(), 120)
	_check("%s yard" % name, "yard_%s" % name)
	# the yard draws a photograph of the fitted ship, `YardScene.FIT_PAD` round its canvas:
	# every gun must stand inside that pad (measured, as a headless run takes no photograph)
	var st := Router.current as StationScreen
	var over := -1.0
	if st != null and st._scene != null and not (st._scene.placed[0] as Dictionary).is_empty():
		var v: ShipView = (st._scene.placed[0] as Dictionary).get("view")
		over = _overhang(v)
	h._ok("%s yard: the guns stand %.0f px past the canvas, inside the photograph's %d" % [name, over, YardScene.FIT_PAD],
		over >= 0.0 and over <= float(YardScene.FIT_PAD))
	Router.show_ship()
	await Harness.frames(get_tree(), 30)
	_check("%s refit page" % name, "refit_%s" % name)
	# and at 1x the whole ship, guns and all, inside its window on the left panel
	var ss := Router.current as ShipScreen
	var out: Array[String] = []
	if ss != null:
		await Harness.frames(get_tree(), 10)
		var win := ss._clip.get_global_rect().grow(0.5)
		var xf := ss._mountpts.get_global_transform()
		for sp: Dictionary in ss._mountpts.spots():
			if sp.held != null and ss._mountpts.gun_for(sp.held, sp.slot) != null:
				var r := ss._mountpts.part_rect(sp.held, sp.slot, sp.at, ss._mountpts.part_mag())
				var g := Rect2(xf * r.position, Vector2.ZERO).expand(xf * r.end)
				if not win.encloses(g):
					out.append("%s %s outside %s" % [(sp.held as ModuleData).name, g, win])
	h._ok("%s refit page: every gun inside the ship's window (%s)" % [name, "; ".join(out)], ss != null and out.is_empty())


## Korvan's frame at S with the longest gun each mount takes on every mount.
func _fit(w: HullData.Weight) -> void:
	Run.start_new_run(&"korvan", w)
	Run.hull = DB.at_tier(DB.hull_for(&"korvan", w) as HullData, 3)
	Run.installed.clear()
	for i in Run.hull.slots_for(ModuleData.Slot.WEAPON):
		var best: ModuleData = null
		var best_w := -1.0
		for id: StringName in ShipGun.ids():
			var m := DB.modules.get(id) as ModuleData
			var g := ShipGun.of(id, Run.hull.gun_sides[i])
			if m != null and g != null and g.size().x > best_w:
				best = m
				best_w = g.size().x
		if best != null:
			var c := best.duplicate(true) as ModuleData
			c.mount = i
			Run.installed.append(c)
	Run.hp = Run.max_hp()
	Sig.ship_changed.emit()


## Every gun on every hull in the tree whole, and at least one gun drawn.
func _check(what: String, shot: String) -> void:
	var cut: Array[String] = []
	var guns := 0
	for n in _all(get_tree().root):
		var mp := n as MountPoints
		if mp == null or not mp.is_visible_in_tree():
			continue
		mp.refresh()
		for s: Dictionary in mp.spots():
			if s.held != null and mp.shows(s.held) and mp.gun_for(s.held, s.slot) != null:
				guns += 1
			# (a Korvan gun, or any with an on-ship picture, on a hull with gun mounts is that picture, never the hold icon)
			var hh: HullData = mp.ship if mp.ship != null else Run.hull
			var held: ModuleData = s.held
			if held != null and mp.shows(held) and int(s.slot) == ModuleData.Slot.WEAPON and hh != null 					and not hh.gun_sides.is_empty() and (held.manufacturer == &"korvan" or ShipGun.ids().has(held.id)) and mp.gun_for(held, s.slot) == null:
				cut.append("%s drawn as its hold icon" % held.name)
		cut.append_array(mp.clipped_guns())
	print("  %-18s %d guns drawn%s" % [what, guns, "" if cut.is_empty() else ", cut: " + "; ".join(cut)])
	h._ok("%s: guns drawn" % what, guns > 0)
	h._ok("%s: no gun cut by a clip (%d)" % [what, cut.size()], cut.is_empty())
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
		get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [_shots, shot])


## How far, in canvas px, the farthest gun drawn on `v` stands past its canvas (0 when none does).
func _overhang(v: ShipView) -> float:
	if v == null:
		return -1.0
	var size := Vector2(v.canvas().get_size()) if v.canvas() != null else Vector2.ZERO
	var out := 0.0
	for c in v.get_children():
		if c is MountPoints:
			for r: Rect2 in (c as MountPoints).part_rects_canvas():
				out = maxf(out, maxf(maxf(-r.position.x, -r.position.y), maxf(r.end.x - size.x, r.end.y - size.y)))
	return out


## Nothing opaque on the picture's outermost rows and columns.
func _edge_clear(img: Image) -> bool:
	var w := img.get_width()
	var hh := img.get_height()
	for x in w:
		if img.get_pixel(x, 0).a > 0.0 or img.get_pixel(x, hh - 1).a > 0.0:
			return false
	for y in hh:
		if img.get_pixel(0, y).a > 0.0 or img.get_pixel(w - 1, y).a > 0.0:
			return false
	return true


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
