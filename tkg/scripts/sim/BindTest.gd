extends Harness

## Key bindings, driven with real key events through the real screens:
##   godot --headless --path . -- bindtest
##
## Four claims, and each fails silently in play. THE DEFAULTS ARE THE KEYS THE
## GAME ALWAYS HAD: every screen used to read a keycode off the event, and a
## binding with the wrong default moves a key without anyone deciding to.
## A REBOUND KEY WORKS AND THE OLD ONE STOPS, set through Settings' own capture
## with the pause menu open over it -- the path where a stray Escape or Tab
## would close the menu or change the page instead. A BINDING SURVIVES A
## RELOAD of the settings file without taking the display and audio sections
## with it. A CLASH IS CAUGHT on the screens that share keys and not on the
## screens that never meet.
##
## THE PLAYER'S FILE IS NEVER TOUCHED. `Keys.path` points at a scratch file for
## the whole run and the file is deleted at the end. F11 is checked as a binding
## and never pressed: it would flip the real window and save the mode.

const SCRATCH := "user://bindtest.cfg"

var _tree: SceneTree
var _main: Node


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	Keys.path = SCRATCH
	_drop_scratch()
	# A display section already in the file, to prove a key save keeps it.
	var seed_cfg := ConfigFile.new()
	seed_cfg.set_value("display", "brightness", 1)
	seed_cfg.save(SCRATCH)
	Keys.load_keys()

	print("defaults")
	_defaults()

	print("clashes")
	_clashes()

	_main = first(tree.root, func(n: Node) -> bool:
		return n.has_method("toggle_menu") and n.has_method("_open_settings"))
	if not _ok("Main is up", _main != null):
		await _finish()
		return

	Rng.reseed(4471, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	print("ship screen")
	await _ship_screen()

	print("persistence")
	_persistence()

	print("settings clash, swap and reset")
	await _settings_clash()

	print("star chart")
	await _star_chart()

	print("next screen")
	await _next_screen()

	print("sector map")
	await _sector_map()

	Keys.reset_all()
	await _finish()


# ------------------------------------------------------------------- claims

func _defaults() -> void:
	var want := {
		&"next_screen": KEY_TAB, &"fullscreen": KEY_F11,
		&"hold_turn": KEY_R, &"part_flip": KEY_F, &"ship_zoom": KEY_Z,
		&"ship_thrust": KEY_W, &"ship_brake": KEY_S, &"ship_left": KEY_A, &"ship_right": KEY_D,
		&"map_up": KEY_UP, &"map_down": KEY_DOWN, &"map_left": KEY_LEFT, &"map_right": KEY_RIGHT,
		&"map_location": KEY_L, &"event_prev": KEY_BRACKETLEFT, &"event_next": KEY_BRACKETRIGHT,
		&"chart_up": KEY_W, &"chart_down": KEY_S, &"chart_left": KEY_A, &"chart_right": KEY_D,
		&"chart_region": KEY_L,
	}
	_ok("every action has a default checked here (%d)" % Keys.actions().size(),
		Keys.actions().size() == want.size())
	# and the chart's pans have the arrows as their second key
	var want2 := {&"chart_up": KEY_UP, &"chart_down": KEY_DOWN, &"chart_left": KEY_LEFT, &"chart_right": KEY_RIGHT}
	for id: StringName in want:
		var ev := InputMap.action_get_events(id) if InputMap.has_action(id) else []
		var codes: Array[int] = []
		for e: InputEvent in ev:
			codes.append(int((e as InputEventKey).keycode))
		var expect: Array[int] = [int(want[id])]
		if want2.has(id):
			expect.append(int(want2[id]))
		var name := Keys.key_name(want[id]) + (" and " + Keys.key_name(want2[id]) if want2.has(id) else "")
		_ok("%s is %s and only that" % [id, name], codes == expect)
	# Every Settings row reads in the drawer: a label of sixteen characters or fewer.
	var longest := ""
	for id: StringName in Keys.actions():
		if Keys.label(id).length() > longest.length():
			longest = Keys.label(id)
	_ok("the longest label is short (%s)" % longest, longest.length() <= 16)


func _clashes() -> void:
	_ok("L on the chart's PAN UP clashes with LOCAL REGION",
		_ids(Keys.clashes(&"chart_up", KEY_L)) == "chart_region")
	_ok("W on BRAKE clashes with THRUST and not with the chart's PAN UP",
		_ids(Keys.clashes(&"ship_brake", KEY_W)) == "ship_thrust")
	_ok("TAB anywhere clashes with NEXT SCREEN",
		_ids(Keys.clashes(&"chart_up", KEY_TAB)) == "next_screen")
	_ok("R on THRUST clashes with TURN PART (the salvage drawer opens over the map)",
		_ids(Keys.clashes(&"ship_thrust", KEY_R)) == "hold_turn")
	_ok("F on the chart clashes with nothing (the hold and the chart never meet)",
		Keys.clashes(&"chart_up", KEY_F).is_empty())
	_ok("ESC cannot be bound", not Keys.set_key(&"ship_zoom", 0, KEY_ESCAPE))
	_ok("and ZOOM SHIP is still Z after the refusal", Keys.slots(&"ship_zoom") == [KEY_Z, 0])
	_ok("an action's only key cannot be emptied", not Keys.clear(&"ship_zoom", 0))


func _ship_screen() -> void:
	Router.show_ship()
	var ship := await _wait_for(func() -> bool: return Router.current is ShipScreen)
	if not _ok("the ship screen is up", ship):
		return
	await _frames(3)
	var scr := Router.current as ShipScreen
	await _press(KEY_Z)
	_ok("Z zooms the ship (the default)", scr._zoomed)
	await _press(KEY_Z)
	_ok("and Z again lets go", not scr._zoomed)

	# REBIND THROUGH SETTINGS, with the pause menu open, by pressing keys.
	_main.call("toggle_menu", false)
	_main.call("_open_settings")
	await _frames(2)
	var page := _page()
	if not _ok("Settings is open in the pause menu, with CONTROLS", page != null):
		return
	page.listen(&"ship_zoom", 0)
	await _press(KEY_ESCAPE)
	_ok("ESC while waiting for a key cancels the wait", not page.listening())
	_ok("and does not close Settings", _in_settings())
	_ok("and ZOOM SHIP is still Z", Keys.slots(&"ship_zoom") == [KEY_Z, 0])
	page = _page()
	page.listen(&"ship_zoom", 0)
	await _press(KEY_X)
	_ok("X pressed in Settings binds ZOOM SHIP to X", Keys.slots(&"ship_zoom") == [KEY_X, 0])
	_ok("and the X did not leave Settings", _in_settings())
	_ok("and the row now offers RESET", not Keys.is_default(&"ship_zoom"))
	await _press(KEY_ESCAPE)
	_ok("ESC with nothing waiting backs out of Settings", not _in_settings())
	await _press(KEY_ESCAPE)
	_ok("and ESC again closes the menu", _main.get("_menu") == null)
	await _frames(2)

	await _press(KEY_X)
	_ok("X now zooms the ship", scr._zoomed)
	await _press(KEY_X)
	await _press(KEY_Z)
	_ok("and Z no longer does", not scr._zoomed)


func _persistence() -> void:
	var cfg := ConfigFile.new()
	_ok("the scratch settings file was written", cfg.load(SCRATCH) == OK)
	_ok("it holds ZOOM SHIP as X", cfg.get_value(Keys.SECTION, "ship_zoom", []) == [KEY_X, 0])
	_ok("and only what was moved", cfg.get_section_keys(Keys.SECTION).size() == 1)
	_ok("and the display section beside it survived", int(cfg.get_value("display", "brightness", 0)) == 1)
	# Scramble what is live, then read the file: a pass cannot be the value
	# that was already sitting in memory.
	InputMap.action_erase_events(&"ship_zoom")
	Keys.load_keys()
	_ok("after a reload ZOOM SHIP is X again", Keys.slots(&"ship_zoom") == [KEY_X, 0])
	var ev := InputMap.action_get_events(&"ship_zoom")
	_ok("and Godot's InputMap says so too",
		ev.size() == 1 and (ev[0] as InputEventKey).keycode == KEY_X)
	# A hand-edited file cannot take the menu key.
	cfg.set_value(Keys.SECTION, "ship_brake", [KEY_ESCAPE, 0])
	cfg.save(SCRATCH)
	Keys.load_keys()
	_ok("a file binding ESC is ignored and BRAKE keeps S", Keys.slots(&"ship_brake") == [KEY_S, 0])


func _settings_clash() -> void:
	_main.call("_open_settings")
	await _frames(2)
	var page := _page()
	if not _ok("Settings is open again", page != null):
		return
	page.listen(&"chart_up", 0)
	await _press(KEY_L)
	_ok("L for the chart's PAN UP is held as a clash, not taken",
		Keys.slots(&"chart_up") == [KEY_W, KEY_UP] and Keys.slots(&"chart_region") == [KEY_L, 0])
	var said := page.clash_text()
	print("    says: %s" % said)
	_ok("the row names the action that has it", said.contains("LOCAL REGION"))
	page.swap()
	_ok("SWAP gives PAN UP L and LOCAL REGION W",
		Keys.slots(&"chart_up") == [KEY_L, KEY_UP] and Keys.slots(&"chart_region") == [KEY_W, 0])
	page = _page()
	page.listen(&"ship_brake", 0)
	page.offer(KEY_W)
	page.cancel()
	_ok("CANCEL on a clash changes nothing",
		Keys.slots(&"ship_brake") == [KEY_S, 0] and Keys.slots(&"ship_thrust") == [KEY_W, 0])
	# A second key, then emptied with Delete.
	page = _page()
	page.listen(&"ship_thrust", 1)
	await _press(KEY_SPACE)
	_ok("SPACE as THRUST's second key", Keys.slots(&"ship_thrust") == [KEY_W, KEY_SPACE])
	page = _page()
	page.listen(&"ship_thrust", 1)
	await _press(KEY_DELETE)
	_ok("DEL empties the second key", Keys.slots(&"ship_thrust") == [KEY_W, 0])
	page = _page()
	page.ask_reset_all()
	page.confirm_reset_all()
	var all_back := true
	for id: StringName in Keys.actions():
		all_back = all_back and Keys.is_default(id)
	_ok("RESET ALL puts every key back", all_back)
	var cfg := ConfigFile.new()
	cfg.load(SCRATCH)
	_ok("and leaves nothing in the file's key section", not cfg.has_section(Keys.SECTION))
	_main.call("_close_settings")
	await _frames(2)


func _star_chart() -> void:
	Router.show_starchart()
	var up := await _wait_for(func() -> bool:
		return Router.current is StarchartScreen and (Router.current as StarchartScreen)._chart != null)
	if not _ok("the star chart is up", up):
		return
	var scr := Router.current as StarchartScreen
	scr.dismiss_primer()
	await _frames(2)
	var chart := scr._chart
	var was: bool = StarchartScreen._region_on
	await _press(KEY_L)
	_ok("L toggles LOCAL REGION (the default)", StarchartScreen._region_on != was)
	await _press(KEY_L)

	await _down(KEY_W)
	_ok("W held pans up (the default)", chart._walk.y < 0.0)
	await _up(KEY_W)
	_ok("and letting go stops it", chart._walk == Vector2.ZERO)
	await _down(KEY_LEFT)
	_ok("LEFT held pans left too (the default, as on the sector map)", chart._walk.x < 0.0)
	await _up(KEY_LEFT)
	_ok("and letting go stops it", chart._walk == Vector2.ZERO)

	Keys.set_key(&"chart_up", 0, KEY_I)
	Keys.set_key(&"chart_up", 1, 0)
	await _down(KEY_W)
	_ok("rebound to I, W no longer pans", chart._walk == Vector2.ZERO)
	await _up(KEY_W)
	await _down(KEY_I)
	_ok("and I does", chart._walk.y < 0.0)
	await _up(KEY_I)
	_ok("and stops", chart._walk == Vector2.ZERO)

	# Two keys for one direction: letting one go leaves the other running.
	Keys.set_key(&"chart_up", 1, KEY_W)
	await _down(KEY_W)
	await _down(KEY_I)
	await _up(KEY_I)
	_ok("with W and I both PAN UP, letting go of I keeps W panning", chart._walk.y < 0.0)
	await _up(KEY_W)
	_ok("and letting go of W stops it", chart._walk == Vector2.ZERO)
	Keys.reset(&"chart_up")


## The sector map: THRUST rebound flies the ship on the new key and not on W,
## the arrows pan the view, L is LOCATION and [ ] step the events.
func _sector_map() -> void:
	# A JUMP TO A SYSTEM WITH THINGS IN IT, as `-- sheet=FlightClip` makes one:
	# the run starts somewhere with no events to step through.
	var dest := -1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM:
			dest = m.index
			break
	if dest >= 0:
		Router.commit_jump(dest)
	else:
		# none in jump range (the galaxy's layout moves when generation does):
		# put the ship at the first system that has events, and show it there
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			if m.type == MapGen.NodeType.SYSTEM and not m.options.is_empty():
				Run.at = m.index
				break
		Router.show_system()
	var t0 := Time.get_ticks_msec()
	var up := false
	while Time.get_ticks_msec() - t0 < 20000:
		if Router.current is SystemMapScreen and Router.current.view.layout != null \
				and Router.current.flight != null:
			up = true
			break
		await _tree.process_frame
	if not _ok("the sector map is up with the ship on it", up):
		return
	var scr := Router.current as SystemMapScreen
	scr.harness_keys = false
	await _frames(3)

	await _down(KEY_W)
	await _frames(4)
	_ok("W held is THRUST (the default)", scr._wasd.w)
	_ok("and the ship burns", scr.flight.burn)
	await _up(KEY_W)
	_ok("letting go of W lets go of THRUST", not scr._wasd.w)

	Keys.set_key(&"ship_thrust", 0, KEY_I)
	await _frames(20)
	await _down(KEY_W)
	await _frames(4)
	_ok("rebound to I, W no longer thrusts", not scr._wasd.w and not scr.flight.burn)
	await _up(KEY_W)
	await _down(KEY_I)
	await _frames(4)
	_ok("and I does", scr._wasd.w)
	_ok("and the ship burns on it", scr.flight.burn)
	await _up(KEY_I)
	_ok("and letting go of I stops it", not scr._wasd.w)
	Keys.reset(&"ship_thrust")

	await _down(KEY_LEFT)
	_ok("LEFT held pans the view (the default)", scr._arrows.x < 0.0)
	await _up(KEY_LEFT)
	_ok("and letting go stops it", scr._arrows == Vector2.ZERO)

	# The pan eases out, and moving the view lets go of LOCATION -- the game's
	# own rule -- so wait for the view to stop before asking for it.
	for i in 300:
		if scr._pan_v.length() <= 1.0:
			break
		await _tree.process_frame
	var was_loc: bool = SystemMapScreen._location_on
	await _press(KEY_L)
	_ok("L is LOCATION (the default)", SystemMapScreen._location_on != was_loc)
	await _press(KEY_L)
	_ok("and L again lets go", SystemMapScreen._location_on == was_loc)

	var encs: Array = scr.panel._encounters()
	print("    system %d (wanted %d), %d options, %d events listed" % [scr.view.node.index, dest, scr.view.node.options.size(), scr.panel._events().size()])
	if not _ok("this system has events to step through (%d)" % encs.size(), encs.size() > 0):
		return
	await _press(KEY_BRACKETRIGHT)
	var first_open: int = scr.panel.open_opt
	_ok("] opens an event", scr.panel.mode != &"list" and first_open in encs)
	if encs.size() > 1:
		await _press(KEY_BRACKETRIGHT)
		_ok("] again steps to the next", scr.panel.open_opt != first_open)
		await _press(KEY_BRACKETLEFT)
		_ok("and [ steps back", scr.panel.open_opt == first_open)
	scr.panel_back()
	await _frames(2)


func _next_screen() -> void:
	Router.show_ship()
	await _wait_for(func() -> bool: return Router.current is ShipScreen)
	await _frames(2)
	var was := Router.current
	await _press(KEY_TAB)
	await _frames(2)
	_ok("TAB changes the page (the default; %s)" % _name(Router.current),
		Router.current != was and not (Router.current is ShipScreen))

	Keys.set_key(&"next_screen", 0, KEY_N)
	Router.show_ship()
	await _wait_for(func() -> bool: return Router.current is ShipScreen)
	await _frames(2)
	was = Router.current
	await _press(KEY_TAB)
	await _frames(2)
	_ok("rebound to N, TAB does nothing", Router.current == was)
	await _press(KEY_N)
	await _frames(2)
	_ok("and N changes the page", Router.current != was)
	Keys.reset(&"next_screen")


# ------------------------------------------------------------------- helpers

## Action ids, joined, so a typed and an untyped array compare as text.
func _ids(a: Array) -> String:
	var out: PackedStringArray = []
	for x: Variant in a:
		out.append(String(x))
	return ",".join(out)

func _page() -> KeyBindings:
	return first(_tree.root, func(n: Node) -> bool: return n is KeyBindings) as KeyBindings


func _in_settings() -> bool:
	var m: Variant = _main.get("_menu")
	return m != null and is_instance_valid(m) and (m as PauseMenu).in_settings()


func _name(n: Node) -> String:
	if n == null:
		return "nothing"
	var s: Script = n.get_script()
	return s.get_global_name() if s != null else n.get_class()


func _key(code: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func _down(code: Key) -> void:
	Input.parse_input_event(_key(code, true))
	await _frames(1)


func _up(code: Key) -> void:
	Input.parse_input_event(_key(code, false))
	await _frames(1)


func _press(code: Key) -> void:
	await _down(code)
	await _up(code)
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## A bounded wait on the thing looked for, not a count of frames at it.
func _wait_for(cond: Callable) -> bool:
	for i in 90:
		if cond.call():
			return true
		await _tree.process_frame
	return cond.call()


func _drop_scratch() -> void:
	var p := ProjectSettings.globalize_path(SCRATCH)
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(p)


## Torn down first, as `QuitTest._finish` does: a headless run that quits
## holding a live Control tree reports leaks the gate reads as errors.
func _finish() -> void:
	_drop_scratch()
	Keys.path = DisplaySettings.path
	if Router.current != null:
		var last := Router.current
		Router.current = null
		last.get_parent().remove_child(last)
		last.free()
	await _tree.process_frame
	print("")
	verdict("bindtest")
	_tree.quit(code())
