class_name FirstRunIntro
extends Control

## THE FIRST-RUN INTRO (Jon called the storyboard "GREAT"; scratchpad
## `local_role/notes.md` section 2). The opening as it is -- the name card, the
## ship flying in -- and then a tour of the three zooms, one line each:
##   1. "LOCAL. This is your ship."
##   2. pull back into the ship's place on the sector map: "SECTOR. This is your
##      star system."
##   3. out to the star chart, the system shrinking to its star as the galaxy
##      eases in: "STARCHART. Reach the core at its heart."
##   4. "Scroll or press Tab to zoom. Pick a star in range, then jump." -- and
##      control is handed back on the chart, where the FIRST SURVEY card follows,
##      as it follows the first chart today.
##
## Built from the screens as they are (a scripted tour through `Router`), not on
## the zoom ladder that comes after the alpha. ONCE PER PLAYER: the seen flag is
## in settings.cfg (`[hints] intro`), the same file the hints will use. Any key
## or click skips straight to the end. Never under a harness (`TestRun.active()`)
## unless it asks with `-- intro`, and then the flag goes to a scratch file, never
## the player's. Reduced motion cuts between the screens instead of zooming.

const LINES := [
	["LOCAL.", "This is your ship."],
	["SECTOR.", "This is your star system."],
	["STARCHART.", "Reach the core at its heart."],
	["", "Scroll or press Tab to zoom. Pick a star in range, then jump."],
]
## How long each line is read for, s
const HOLD := [2.8, 2.8, 3.0, 3.8]
## The fade between screens, and the zoom out across each one, s
const FADE_S := 0.35
const MAP_OUT_S := 2.2
const CHART_OUT_S := 2.6
## The chart's zoom on the system before it eases out to the galaxy
const CHART_NEAR := 4.0

const SECTION := "hints"
const KEY := "intro"

## The one playing, if any.
static var playing: FirstRunIntro = null

var _caption: PanelContainer
var _head: Label
var _line: Label
var _black: ColorRect
var _done := false
var _skipped := false


## Where the seen flag lives: the player's settings, or a scratch file under a
## harness (a shot of the intro must never mark the player's as seen).
static func store_path() -> String:
	return "user://harness_settings.cfg" if TestRun.active() else DisplaySettings.path


static func seen() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(store_path()) != OK:
		return false
	return bool(cfg.get_value(SECTION, KEY, false))


static func mark_seen(v: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(store_path())
	cfg.set_value(SECTION, KEY, v)
	cfg.save(store_path())


## Played for a new run's launch, if this player has not seen it.
static func maybe_start() -> void:
	var forced := "intro" in OS.get_cmdline_user_args()
	if not forced and (TestRun.active() or seen()):
		return
	if playing != null and is_instance_valid(playing):
		return
	if Router.content == null or not Router.content.is_inside_tree():
		return
	var it := FirstRunIntro.new()
	playing = it
	# AT THE ROOT OF THE GAME'S PICTURE, over every screen and the HUD (the
	# content's own parent is a container, which laid the overlay out under it)
	Router.content.get_viewport().add_child(it)
	# and in the game's own theme (its pixel font), which lives on an ancestor of
	# the screens, not on the viewport
	var n: Node = Router.content
	while n != null:
		if n is Control and (n as Control).theme != null:
			it.theme = (n as Control).theme
			break
		n = n.get_parent()
	it._play()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the cut between screens, over everything
	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = UITheme.VOID
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	# THE LINE: low in the frame, over the picture, never over the ship or the
	# map's middle; a heading word in ICE, the line in CHILL
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var mid := CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(mid)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 46)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pad)
	_caption = PanelContainer.new()
	_caption.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, 0.92), UITheme.LINE, 0, 14, 10))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	mid.add_child(_caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(row)
	_head = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	row.add_child(_head)
	_line = UITheme.body("", UITheme.CHILL, UITheme.FS_HEAD)
	row.add_child(_line)


## ANY KEY OR CLICK SKIPS, to the end state: the chart, the FIRST SURVEY card.
func _input(e: InputEvent) -> void:
	if _done:
		return
	var press := (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo) \
		or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed)
	if not press:
		return
	get_viewport().set_input_as_handled()
	_skip()


func _moving() -> bool:
	return not DisplaySettings.reduced_motion


func _wait(s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if _done or not is_inside_tree():
			return false
		await get_tree().process_frame
	return not _done and is_inside_tree()


func _say(i: int) -> void:
	_head.text = String(LINES[i][0])
	_head.visible = _head.text != ""
	_line.text = String(LINES[i][1])
	if _moving():
		var tw := create_tween()
		tw.tween_property(_caption, "modulate:a", 1.0, 0.25).from(0.0)
	else:
		_caption.modulate.a = 1.0


func _unsay() -> void:
	if _moving():
		var tw := create_tween()
		tw.tween_property(_caption, "modulate:a", 0.0, 0.2)
	else:
		_caption.modulate.a = 0.0


## Dark over the change of screen and back (a cut, with reduced motion).
func _cut(to_dark: bool) -> bool:
	if not _moving():
		_black.modulate.a = 0.0
		return not _done
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0 if to_dark else 0.0, FADE_S)
	return await _wait(FADE_S)


func _play() -> void:
	# 0. THE OPENING, AS IT IS: the name card and the ship flying in
	var t0 := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - t0 < 14000:
		var sc := Router.current as SectorScreen
		if sc != null and sc.get("_phase") == SectorScreen.Phase.NONE and Time.get_ticks_msec() - t0 > 600:
			break
		await get_tree().process_frame
	if _done:
		return
	# 1. LOCAL
	_say(0)
	if not await _wait(HOLD[0]):
		return
	_unsay()
	# ONE CAMERA (`ZoomLadder`): the tour is the ladder's own moves, no cuts
	if ZoomLadder.enabled():
		await _ladder_tour()
		return
	# 2. SECTOR: pulled back into the ship's place on the map, then out to the system
	if not await _cut(true):
		return
	Router.show_system()
	var map := await _settled_map()
	if _done:
		return
	if map != null and _moving():
		map.call("_glide_to", "loc", -9, SystemMapScreen.ZOOM_LOCATION, 0.01)
		await get_tree().process_frame
		await get_tree().process_frame
	if not await _cut(false):
		return
	if map != null and _moving():
		map.call("_glide_to", "body", -1, float(map.get("zoom_min")), MAP_OUT_S)
	_say(1)
	if not await _wait(maxf(HOLD[1], MAP_OUT_S if _moving() else 0.0)):
		return
	_unsay()
	# 3. STARCHART: the system shrinks to its star, the galaxy eases in
	if not await _cut(true):
		return
	Router.show_starchart()
	var chart := await _settled_chart()
	if _done:
		return
	if chart != null:
		_hold_primer(true)
		if _moving():
			chart.call("center_on_ship", CHART_NEAR)
	if not await _cut(false):
		return
	if chart != null:
		if _moving():
			chart.call("glide_to", StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, CHART_OUT_S)
		else:
			chart.call("_go_to", StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, false)
	_say(2)
	if not await _wait(HOLD[2]):
		return
	# 4. HOW TO MOVE, and control is yours
	_say(3)
	if not await _wait(HOLD[3]):
		return
	_finish()


## Steps 2 to 4 on the zoom ladder: LOCAL pulls back into the map, the map
## out into the chart, each the ladder's own move.
func _ladder_tour() -> void:
	Router.show_system()
	var map := await _settled_map()
	if _done:
		return
	await _ladder_idle()
	_say(1)
	if not await _wait(HOLD[1]):
		return
	_unsay()
	Router.show_starchart()
	var chart := await _settled_chart()
	if _done:
		return
	if chart != null:
		_hold_primer(true)
	await _ladder_idle()
	if chart != null and is_instance_valid(chart):
		chart.call("glide_to", StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, CHART_OUT_S)
	_say(2)
	if not await _wait(HOLD[2]):
		return
	_say(3)
	if not await _wait(HOLD[3]):
		return
	_finish()
	if map == null:
		return


func _ladder_idle() -> void:
	for i in 180:
		if not ZoomLadder.busy() or _done:
			return
		await get_tree().process_frame


## The map, once it has laid itself out (its sector built and framed).
func _settled_map() -> Control:
	for i in 120:
		var s := Router.current
		# (its ship placed: the last thing `show_system` does after framing the sector)
		if s is SystemMapScreen and s.get("flight") != null:
			await get_tree().process_frame
			return s
		await get_tree().process_frame
		if _done:
			return null
	return null


## The chart's drawing, once it has a size to frame in.
func _settled_chart() -> Control:
	for i in 60:
		var s := Router.current
		if s is StarchartScreen:
			var c: Control = s.get("_chart")
			if c != null and c.size.x > 10.0:
				await get_tree().process_frame
				return c
		await get_tree().process_frame
		if _done:
			return null
	return null


## The FIRST SURVEY card waits for the tour, then follows it.
func _hold_primer(hold: bool) -> void:
	var s := Router.current
	if s is StarchartScreen:
		var p: Control = s.get("_primer")
		if p != null and is_instance_valid(p):
			p.visible = not hold


func _skip() -> void:
	if _done:
		return
	_skipped = true
	_done = true
	# straight to the end state: on the chart, framed on the galaxy (and no
	# zoom ladder move on the way: a skip is a cut)
	if ZoomLadder.busy():
		ZoomLadder.active.finish_now()
	if not (Router.current is StarchartScreen) and not Run.dead:
		ZoomLadder.hold_off = true
		Router.show_starchart()
		ZoomLadder.hold_off = false
		for i in 3:
			await get_tree().process_frame
	else:
		var c: Control = Router.current.get("_chart")
		if c != null:
			c.call("_go_to", StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, false)
	_black.modulate.a = 0.0
	_end()


func _finish() -> void:
	_done = true
	_end()


func _end() -> void:
	mark_seen(true)
	_hold_primer(false)
	if playing == self:
		playing = null
	if _moving() and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
	else:
		queue_free()
