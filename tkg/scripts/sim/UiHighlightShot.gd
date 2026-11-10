extends Node

## Stills of the highlight, dim, tooltip and keyword states for the stripped-down UI, part 2
## (C1, C2, C3, T1, T2; Jon, Nov 9): one screen staged with the pointer on something, the
## game's 960x540 photographed to `out=`. Stages and flags: docs/tests.md. Needs a window.
##   tools/dev/render.sh --path tkg -- asrelease nolauncher sheet=UiHighlightShot stage=<name> out=<png>

var _tree: SceneTree
var _out := ""


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _secs(s: float) -> void:
	await _tree.create_timer(s).timeout


## The pointer put at `at` (game px) with a motion event, so hovers fire as a real move would.
func _hover(at: Vector2) -> void:
	_tree.root.warp_mouse(at)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	Input.parse_input_event(mm)
	await _frames(2)


func _click(at: Vector2) -> void:
	await _hover(at)
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		Input.parse_input_event(mb)
		await _frames(3)


func _screen() -> SectorScreen:
	return Router.current as SectorScreen


## A run under way on LOCAL (a sheet stops Main's own boot, so the screen is this file's).
func _local() -> SectorScreen:
	Router.animate_in_harness = true
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.index > 0 and n.type == MapGen.NodeType.SYSTEM and not n.cleared 				and n.region != MapGen.Region.FAUNA:
			Run.at = n.index
			break
	Run.map[Run.at].visited = true
	SectorScreen._approached_at = Run.at
	Router.show_local()
	await _secs(14.0)
	return _screen()


## The fight screen up and still: its band raised, its pack placed, the hand dealt.
func _fight() -> SectorScreen:
	await _local()
	Router.start_combat(DB.enemies[&"cutter"], [], false, true)
	for i in 1800:
		await _tree.process_frame
		var sc := _screen()
		if sc != null and sc.fighting() and not sc._hold and not sc._opening 				and sc._hand != null and sc._hand._views.size() > 0 and i > 120:
			break
	await _secs(2.5)
	return _screen()


## Docked at a city station with two berths, the yard up (`tab=services` on the command line).
func _station() -> void:
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	here.security = 4
	here.berths = [&"solari", &"cygnet"]
	here.manufacturer = &"solari"
	here.danger = 5
	Run.hp = Run.max_hp() - 5
	Router.park_at_station(here)
	Router.show_station()
	await _secs(9.0)


## The first card in the hand `pick` says yes to; its view.
func _card(sc: SectorScreen, pick: Callable) -> CardView:
	for v: CardView in sc._hand._views:
		if is_instance_valid(v) and pick.call(v.card):
			return v
	return null


func _aim(sc: SectorScreen, view: CardView, to: Vector2) -> void:
	var from := view.get_global_rect().get_center()
	sc._on_card_grabbed(view, from)
	# (the first move decides the gesture, the second arms it, the third is tracked)
	for p in [from + Vector2(0, -6), to, to]:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		sc._input(mm)
	_tree.root.warp_mouse(to)


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	_out = _arg("out", "user://ui_highlight.png")
	var stage := _arg("stage", "fight_hover")
	MarkOutline.look = int(_arg("marklook", str(MarkOutline.DEFAULT_LOOK)))
	TornTag.look = int(_arg("tiplook", str(TornTag.DEFAULT_LOOK)))
	# The window at the game's own size, as `Main._shoot` has it: root px are game px.
	get_window().size = Vector2i(960, 540)
	await _frames(8)
	print("[stage] ", stage)
	match stage:
		"fight_hover", "fight_readout", "fight_word":
			var sc := await _fight()
			var v: CardView = null
			if stage == "fight_word":
				v = _card(sc, func(c: CardData) -> bool: return not c.keywords().is_empty())
			if v == null and sc._hand._views.size() > 2:
				v = sc._hand._views[2]
			if v != null:
				var r := v.get_global_rect()
				var at := r.get_center()
				if stage == "fight_word":
					# the first underlined word: where the text box's first line sits once the
					# card has lifted its 8 px (the word answers the motion, so move twice)
					at = r.position + Vector2(CardView.Z_TEXT.position.x + 8.0, CardView.Z_TEXT.position.y - 3.0)
					await _hover(at)
					await _secs(0.4)
				await _hover(at)
				await _secs(0.5 if stage == "fight_hover" else 1.8)
		"fight_aim":
			var sc := await _fight()
			var v := _card(sc, func(c: CardData) -> bool: return c.damage > 0 and sc.combat.can_play(c))
			var slot := sc._view.slot(0)
			if v != null and slot != null:
				var to := slot.get_global_rect().get_center()
				var ink := slot.ink_rect()
				to = slot.get_global_transform() * ink.get_center()
				_aim(sc, v, to)
				await _secs(0.8)
		"fight_noenergy":
			var sc := await _fight()
			sc.combat.energy = 0
			Sig.hand_changed.emit()
			Sig.player_combat_state_changed.emit()
			await _hover(Vector2(480, 300))
			await _secs(0.8)
		"fight_endturn_tip":
			var sc := await _fight()
			await _hover(sc._end_button.get_global_rect().get_center())
			await _secs(0.8)
		"fight_intent_tip":
			var sc := await _fight()
			var slot := sc._view.slot(0)
			if slot != null:
				var r := slot.intent_rect_global()
				await _hover(r.get_center())
				await _secs(0.8)
		"local_ship", "hud_tip":
			var sc := await _local()
			if stage == "hud_tip":
				await _hover(Router.hud._hull.get_global_rect().get_center())
			elif sc != null and sc._view.ship_view() != null:
				var art := sc._view.ship_view()
				var ink: Rect2 = Rect2(art.ship_rect())
				await _hover(art.get_global_transform() * ink.get_center())
			await _secs(0.8)
		"local_wreck":
			var sc := await _fight()
			sc.combat.damage_enemy(9999, 1, "test")
			# a win lowers the band and lands on LOCAL by itself, the wreck where the ship was
			for i in 1800:
				await _tree.process_frame
				sc = _screen()
				if sc != null and sc.settled_local() and sc._view.slot(0) != null and sc._view.slot(0)._dead 						and sc._view.slot(0).opened.is_valid() and sc._view.slot(0).modulate.a > 0.99:
					break
			await _secs(2.0)
			sc = _screen()
			if sc != null:
				var slot := sc._view.slot(0)
				if slot != null:
					await _hover(slot.get_global_transform() * slot.ink_rect().get_center())
			await _secs(0.8)
		"readout":
			# a part on the station's shelf, pointed at: its readout on the rich plate
			await _station()
			var icons := (Router.current as Node).find_children("*", "ModuleIcon", true, false)
			for ic in icons:
				if (ic as Control).is_visible_in_tree():
					await _hover((ic as Control).get_global_rect().get_center())
					break
			await _secs(0.8)
		"yard_ship", "yard_drone", "deck":
			await _station()
			var st: Variant = Router.current
			if stage == "yard_ship" and st.get("_mine_view") != null:
				var mv: ShipView = st.get("_mine_view")
				await _hover(mv.get_global_transform() * Rect2(mv.ship_rect()).get_center())
			elif stage == "yard_drone" and st.get("_scene") != null:
				var scene: Variant = st.get("_scene")
				var drones: Variant = scene.get("drones")
				if drones != null:
					for d: Dictionary in drones.D:
						if String(d["mode"]) == "hover" and d.has("r") and float(d["doneAt"]) < 0.0:
							var r: Dictionary = d["r"]
							var p := Vector2(float(r["sx"]) + float(r["w"]) * 0.5, float(r["sy"]) + float(r["h"]) * 0.5)
							await _hover((scene as Control).get_global_transform() * p)
							break
			elif stage == "deck" and st.get("_rail") != null:
				var rail: Control = st.get("_rail")
				var cells := rail.find_children("*", "Button", true, false)
				if cells.size() > 3:
					await _hover((cells[3] as Control).get_global_rect().get_center())
			await _secs(0.8)
		"map_world":
			await _local()
			Router.show_system()
			for i in 600:
				var m := Router.current as SystemMapScreen
				if m != null and m.flight != null and m.view.layout != null and not ZoomLadder.busy():
					break
				await _tree.process_frame
			await _secs(1.5)
			var m := Router.current as SystemMapScreen
			if m != null:
				var L: SystemLayout = m.view.layout
				for bi in L.bodies.size():
					if L.bodies[bi].world != &"":
						var at: Vector2 = m.view.at[bi]
						await _hover(m._box.get_global_transform() * at)
						break
			await _secs(1.2)
		"chart", "chart_rest":
			await _local()
			Router.show_starchart()
			await _secs(3.0)
			var ch := Router.current as StarchartScreen
			if ch != null:
				var picked := -1
				var hov := -1
				for t in Run.in_range():
					var tn := t as MapGen.MapNode
					if tn.sensed and tn.index != Run.at:
						if picked < 0:
							picked = tn.index
						elif hov < 0:
							hov = tn.index
				if stage == "chart" and picked >= 0:
					ch._on_node_picked(picked)
					await _secs(0.5)
				if hov >= 0:
					var p: Vector2 = ch._chart._screen_pos(Run.map[hov])
					await _hover(ch._chart.get_global_transform() * p)
			await _secs(1.2)
	if "tagprobe" in OS.get_cmdline_user_args():
		var L := TagLayer.instance
		var ow: Control = L._owner_of(L._over) if L._over != null else null
		print("[tag] over %s since %.2f owner %s text \"%s\" shown %s mouse %s" % [str(L._over), L._since, str(ow),
			(L._text_of(ow) if ow != null else "").c_escape(), str(L.shown()), str(L.get_viewport().get_mouse_position())])
	# where the tag is, for a crop
	var up: Control = TagLayer.instance.shown() if TagLayer.instance != null else null
	if up == null and _screen() != null:
		up = _screen().word_tag()
	if up != null:
		var tr := up.get_global_rect()
		print("[tagrect] %d %d %d %d" % [int(tr.position.x), int(tr.position.y), int(tr.size.x), int(tr.size.y)])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	img.save_png(_out)
	print("[shot] %s %dx%d" % [ProjectSettings.globalize_path(_out), img.get_width(), img.get_height()])
	_tree.quit()
