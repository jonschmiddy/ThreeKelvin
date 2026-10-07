extends Node

## THE FIRST-RUN HINTS IN PLACE (`Hints`), one still each as the game draws it:
##   godot --path . --windowed --position 3840,0 -- sheet=HintShot hints keepwindow out=<dir>
##
## `hints` turns them on under the harness (the seen flags go to the harness
## settings file, which this resets first). It walks the real screens:
##   - LOCAL with a loaded wreck and a pile on the floor: wreck, loot, ship;
##   - the cutaway;
##   - the event band, its text arrived and its choices up;
##   - a fight's hand;
##   - the sector map with an event's page, at GO;
##   - the shipyard: your ship, for the cutaway.
## Each hint is photographed `HINT_S` after it shows (`<n>_<id>.png`), then
## dismissed with a click as a player would. A hint that never shows is printed
## as `[hintshot] MISSING <id>`. Needs a window.

const HINT_S := 0.5

var _args: PackedStringArray
var _out := ""
var _k := 0


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _secs(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(t * 1000.0):
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	GameShell.input_target(get_tree()).get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("  hintshot: %s" % name)


## Wait for hint `id`, photograph it, click it away.
func _hint(id: StringName, wait: float = 8.0) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await RenderingServer.frame_post_draw
		if Hints.card != null and is_instance_valid(Hints.card) and Hints.card.id == id:
			await _secs(HINT_S)
			_k += 1
			_shot("%d_%s" % [_k, id])
			var c: HintCard = Hints.card
			print("  hintshot: %s card %s, subject %s, side %s" % [id, c.card_rect(), c.subject, c.side])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			Hints.click(ev)
			await _secs(Hints.GAP_S + 0.2)
			return
	print("  [hintshot] MISSING %s (showing: %s)" % [id, Hints.card.id if Hints.card != null else "none"])


func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not m.cleared:
			Run.at = m.index
			m.visited = true
			SectorScreen._approached_at = m.index
			OptionTable.ensure(m)
			return m
	return null


func _run() -> void:
	var tree := get_tree()
	_out = _arg("out", "user://hintshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	Hints.reset()
	Rng.forced = int(_arg("seed", "1"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n := _system()
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	Router.show_local()
	await _secs(1.5)
	await _hint(&"wreck")
	await _hint(&"loot")
	await _hint(&"ship")
	var sc := Router.current as SectorScreen
	if sc != null:
		sc.open_cutaway()
		await _hint(&"cutaway")
		if sc._cutaway != null:
			sc._cutaway.close_now()
		await _secs(0.5)
		# the event band: the middle-length event, its text arriving first
		var all: Array = OptionTable.all().duplicate()
		all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("body", "")).length() < String(b.get("body", "")).length())
		n.options.append(StringName(all[all.size() / 2].id))
		sc._events.open(n.options.size() - 1)
		await _hint(&"drawer", 25.0)
		sc._events.not_now()
		await _secs(0.5)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _secs(1.5)
	await _hint(&"hand", 12.0)
	# GO, on a fresh run's sector map
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	n = _system()
	Router.show_system()
	await _secs(2.0)
	var map := Router.current as SystemMapScreen
	if map != null:
		var opened := false
		for bi in map.view.layout.bodies.size():
			for bc in map.view.layout.bodies[bi].beacons:
				if bc.opt >= 0 and not opened:
					map.open_beacon(bi, bc)
					opened = true
		await _hint(&"go")
	# the shipyard: a fresh hint for your ship there
	Hints.mark_seen(&"ship", false)
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			Run.at = m.index
			m.visited = true
			break
	Router.show_station()
	await _secs(2.5)
	await _hint(&"ship", 10.0)
	Hints.reset()
	tree.quit()
