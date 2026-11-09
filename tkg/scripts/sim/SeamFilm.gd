extends Node

## Films the two seams of stripped-down UI part 3 (Jon, Nov 9) on the game's own fixed-fps
## clock: `what=decks`, the station's elevator riding every deck; `what=loot`, a wreck's
## loot opening where it lies, a take, DONE, then SECTOR LOOT at your ship. `rm`: reduced motion.
## Why: docs/why/SeamFilm.md#seam-film

var _tree: SceneTree
var _args: PackedStringArray
var _f0 := 0


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _mark(name: String) -> void:
	print("  mark %s %d" % [name, Engine.get_frames_drawn() - _f0])


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	DisplaySettings.reduced_motion = "rm" in _args
	Rng.forced = Harness.seed_arg(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	_f0 = Engine.get_frames_drawn()
	if Harness.arg("what", "loot") == "decks":
		await _decks()
	else:
		await _loot()
	_tree.quit()


## Docked, the yard settled; then the elevator: up to the PROMENADE, down to the
## LABORATORY, up to the EXCHANGE, down to the HIRING BOARD, down to the yard.
func _decks() -> void:
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			st = n.index
			break
	if st < 0:
		print("  [seamfilm] no station")
		return
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	Router.park_at_station()
	# (docked at once, no dock played, and the berth settled)
	ZoomLadder.force = 0
	Router.show_station()
	ZoomLadder.force = 1
	await Harness.frames(_tree, 90)
	var scr := Router.current as StationScreen
	if scr == null:
		print("  [seamfilm] no station screen")
		return
	_mark("station")
	for id: StringName in [&"stock", &"bench", &"hold", &"work", &"services"]:
		(scr._tabs[id] as Button).pressed.emit()
		_mark("deck_%s" % id)
		var n := 0
		while scr.deck_changing() and n < 120:
			await _tree.process_frame
			n += 1
		_mark("landed_%s" % id)
		await Harness.frames(_tree, 40)


## LOCAL with a wreck: the wreck clicked, held, one part taken, DONE; then SECTOR
## LOOT from the bar, held, DONE.
func _loot() -> void:
	var idx := -1
	for raw in Run.map:
		var n0: MapGen.MapNode = raw
		if n0.type == MapGen.NodeType.SYSTEM and not n0.cleared and n0.region != MapGen.Region.FAUNA:
			idx = n0.index
			break
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	var node: MapGen.MapNode = Run.node_at()
	var wreck := Run.new_wreck(node, DB.enemies[&"cutter"])
	for i in 3:
		Run.stow(LootGen.roll_module(3, &"korvan"))
	wreck.items.append(LootGen.roll_module(4, &"korvan"))
	wreck.items.append(LootGen.roll_module(3, &"solari"))
	wreck.items.append(MaterialData.of(MaterialTable.all()[2]))
	var pile := Run.sector_jetsam(node, true)
	pile.items.append(LootGen.roll_module(3))
	pile.items.append(MaterialData.of(MaterialTable.all()[5]))
	Router.show_local()
	await Harness.frames(_tree, 60)
	var sc := Router.current as SectorScreen
	if sc == null:
		print("  [seamfilm] not on LOCAL")
		return
	_mark("local")
	var slot := sc._view.wreck_slot(wreck)
	var at := _wreck_point(slot) if slot != null else Vector2.INF
	if at.x == INF:
		print("  [seamfilm] no wreck to click")
		return
	await _glide(at, 15)
	await _click_at(at)
	_mark("wreck_clicked")
	var tv: TransferView = sc._transfer
	await _settled(tv)
	_mark("wreck_open")
	await Harness.frames(_tree, 40)
	# a part taken, by a double-click on it as the first-run bot takes one
	var icons := tv._loose.find_children("*", "ItemIcon", true, false) if tv != null else []
	if not icons.is_empty():
		var p := (icons[0] as Control).get_global_rect().get_center().round()
		await _glide(p, 15)
		await _double_click(p)
		_mark("took_one")
		await Harness.frames(_tree, 40)
	if tv != null:
		await _glide(tv._done.get_global_rect().get_center().round(), 12)
		tv._done.pressed.emit()
	_mark("done")
	var n := 0
	while sc._transfer != null and n < 120:
		await _tree.process_frame
		n += 1
	_mark("wreck_shut")
	await Harness.frames(_tree, 40)
	var b := sc.find_child("SectorLoot", true, false) as Button
	if b != null:
		await _glide(b.get_global_rect().get_center().round(), 15)
		b.pressed.emit()
		_mark("sector_loot")
		tv = sc._transfer
		await _settled(tv)
		_mark("pile_open")
		await Harness.frames(_tree, 50)
		if tv != null:
			await _glide(tv._done.get_global_rect().get_center().round(), 12)
			tv._done.pressed.emit()
		n = 0
		while sc._transfer != null and n < 120:
			await _tree.process_frame
			n += 1
		_mark("pile_shut")
	await Harness.frames(_tree, 40)


func _settled(tv: TransferView) -> void:
	var n := 0
	while tv != null and is_instance_valid(tv) and not tv.settled() and n < 120:
		await _tree.process_frame
		n += 1


## A point on the wreck's own metal, on screen.
func _wreck_point(slot: EnemySlot) -> Vector2:
	var view := slot.get_viewport().get_visible_rect()
	var r := slot.art.get_global_rect() if slot.art != null else slot.get_global_rect()
	for yy in range(int(r.position.y), int(r.end.y), 2):
		for xx in range(int(r.end.x) - 1, int(r.position.x), -2):
			var p := Vector2(xx, yy)
			if view.has_point(p) and slot._on_hull(slot.get_global_transform().affine_inverse() * p):
				return p
	return Vector2.INF


var _mouse := Vector2(480, 300)


## The pointer eased to `to` over `frames`, so the film shows a hand.
func _glide(to: Vector2, frames: int) -> void:
	var from := _mouse
	var target := GameShell.input_target(_tree)
	for i in frames:
		var e := float(i + 1) / float(frames)
		e = 1.0 - pow(1.0 - e, 2.0)
		_mouse = from.lerp(to, e).round()
		var mv := InputEventMouseMotion.new()
		mv.position = _mouse
		mv.global_position = _mouse
		target.push_input(mv)
		await _tree.process_frame


func _click_at(at: Vector2) -> void:
	var target := GameShell.input_target(_tree)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mb.position = at
		mb.global_position = at
		target.push_input(mb)
		await _tree.process_frame


func _double_click(at: Vector2) -> void:
	var vp := GameShell.input_target(_tree)
	for dbl in [false, true]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.double_click = dbl
		mb.position = at
		mb.global_position = at
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mb)
		await _tree.process_frame
		var up := mb.duplicate() as InputEventMouseButton
		up.pressed = false
		up.double_click = false
		up.button_mask = 0
		vp.push_input(up)
		await _tree.process_frame
