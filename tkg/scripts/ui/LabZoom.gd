class_name LabZoom
extends Control

## THE CAMERA ONTO THE LAB'S SCREEN (science S9; Jon's 1C, Nov 4, and his
## question the same day: "is the screen really big enough for a player to see
## all of it?"). It is not, at the glass's own size: the capital's glass is
## 440x228 and the settlement's 230x124, and the board was drawn for 908x488.
## So pressing the screen in the room moves the camera onto the glass until the
## glass fills the window, and the Lab's pages come up on it at the board's own
## size: RESEARCH (the star chart, `LabBoard`), AUGMENT and RECIPES. LEAVE, or
## Esc, takes the camera back out to the room, the screen on its logo.
##
## ONE CAMERA MOVE, NOT A CUT, from the frame after the press: the camera
## moves (`LAB_ZOOM_S`, smootherstep), the screen's own effects going off the
## sign-in as it sets off (`FX_S`), and carries the deck's frame, the
## elevator and the HUD out of the window with the room, and the Lab's pages
## come up on the landed glass over the sign-in it carried in (`UI_IN_S`).
## Back out it all runs backwards: the frame, the elevator and the HUD ride
## back in with the room and stand in their places on the frame the camera
## lands (Jon, Nov 5: "a smoother transition with the elevator", and of the
## frame fading back after: "the fact that the frame pops in is kinda
## awkward, yeah?"). No still beat before the move, nor after it on the way
## out (the review of aebd46f6: ZoomLadder's `UI_OUT_S` held the camera still
## 13 frames after the click, and 13 more on the way out with the input
## eaten after the camera had stopped); the other moves keep theirs. A
## click or a key during a move is eaten and the camera goes on (camera
## moves, never cuts): Esc, or the pad's B, on the way in turns it round; Tab
## takes the camera out at three times the pace and then goes on to the
## ladder.
##
## A PURE CAMERA (Jon, Nov 5: "I don't really like the warping of the screen
## getting bigger than the room, it should stay fixed"). The room is one
## picture at one scale: the lab's painted room, lit by the lab's own light
## (`LabScene`'s material, so a lamp that flickers in the room flickers here),
## its life (the tanks' bubbles, the monitors) and the screen's sign-on
## (`LabLogin`, the very texture the room shows), all through the one camera,
## sampled nearest, its origin on whole pixels. Nothing is sliced, repeated or
## stretched: the frame round the glass is never bigger than the wall it is in.
## The scale goes from the room's own to the lab's `ZOOM` geometrically (each
## frame the same ratio bigger, as a camera closing in at a steady speed),
## about the one point of the room that holds still on screen, so the glass
## comes from where it stands in the room to the window's middle.
##
## THE LANDED GLASS. Each lab's `ZOOM` is the smallest whole number that puts
## the board's own glass (908x488 at 26,26) inside the lab's glass on screen:
## the settlement's glass is 920x496 at 4 (its bezel, 20 and 22 px, round the
## window), the den's is the window's whole width at 3 (its bezel 9 px top and
## bottom, which the board's ground covers: `board_rect`), and the outpost's, the city's and the capital's go past the window
## on every side, so their glass is the whole window. The board is laid out as
## it always was: the chart's ground runs on to the lab's glass edge, wherever
## that is (`lab_chart.gdshader`'s `rpos`).
##
## THE DECK'S FRAME IS PART OF THE PICTURE (`_frame`): the deck page's plate
## round the room (its backing and its border) drawn through the same camera,
## at the room's pixel size, so the room is never a bare rectangle on the dark
## and nothing round it fades. It replaces the plate the frame the camera
## leaves the room, and hands it back the frame it lands, the two the same
## pixels there. (Round three let the room's edge fall away into the dark, a
## veil faded on before the move and off after it; with the plate fading the
## same way, the frame popped back after the camera landed.)

signal opened
signal closed
## The camera is on its way back out (LEAVE, Esc): the screen goes to its logo.
signal leaving

## The board's own margin round its glass, and its window.
const T := 26
const W := 960
const H := 540
const GLASS := Rect2(26, 26, 908, 488)
## THE CAMERA'S ZOOM AT EACH LAB, a whole number: the smallest that puts the
## board's glass (`GLASS`) inside the lab's glass on screen. The glass on
## screen at that zoom (labs.json `screen.glass`):
##   unclaimed  438x174 x3 = 1314x522, the window's width, 9 px of bezel top and bottom
##   outpost    276x176 x4 = 1104x704, past the window all round
##   settlement 230x124 x4 =  920x496, a bezel of 20 px each side and 22 top and bottom
##   city       268x142 x4 = 1072x568, past the window all round
##   capital    440x228 x3 = 1320x684, past the window all round
## At one less, each is too small for the board: 876x348, 828x528, 690x372,
## 804x426 and 880x456.
const ZOOM := {"unclaimed": 3, "outpost": 4, "settlement": 4, "city": 4, "capital": 3}
const TABS := [[&"research", "RESEARCH"], [&"augment", "AUGMENT"], [&"recipes", "RECIPES"]]
const CHART := preload("res://shaders/lab_chart.gdshader")
const FIN_ADD := preload("res://shaders/lab_finish_add.gdshader")
const FIN_MUL := preload("res://shaders/lab_finish_mul.gdshader")
const BLOOM := preload("res://shaders/lab_bloom.gdshader")

## THE SCREEN'S OWN EFFECTS (`on_glass`) go off over the camera's first
## `FX_S`, and come back over its last on the way out: no beat of their own.
const FX_S := ZoomLadder.UI_OUT_S

## `stationshot labzoom=k`: the move held at this much of its camera (0..1).
static var hold_at := -1.0

var lab: LabScene
## The screen's sign-on in the room (`StationScreen`'s, a viewport's texture
## at the lab's `win_rect`): the camera carries the very same pixels in.
var screen: TextureRect
## What else is on the room's glass and goes as the chrome goes: what the big
## screen does over the sign-on (`LabScene.fx_layer`; a bad-signal snow line
## flashed on the bare glass as the camera set off).
var on_glass: Array = []
## The station screen: the recipes are made through it (`_fabricate`).
var station: Node
var tab: StringName = &"research"

var view: Control
var board: LabBoard
var augment: LabAugment
var recipes: LabRecipes
var tab_buttons := {}
var leave_button: LabPlate

var _at := 0.0
var _goal := 0.0
var _level := ""
var _z := 3
var _tint := Color(1, 1, 1)
var _ground: ColorRect
var _fin_add: ColorRect
var _fin_mul: ColorRect
var _room: Control
var _life: Control
var _screen: Control
var _header: Control
var _pages := {}
## THE CAMERA NOW: the room's picture px p is on screen at `_o + p * _s`
## (`_o` on whole px). `_o1` is where it lands at `_z`, and `glass_on_screen`
## the lab's glass there.
var _s := 1.0
var _o := Vector2.ZERO
var _o1 := Vector2.ZERO
var glass_on_screen := Rect2()
## WHERE THE BOARD'S GROUND AND FINISH LIE once landed: the lab's glass on
## screen, or the whole window (and a margin past it, so the rim is off it)
## where the glass leaves no more than `THIN` px of bezel at any edge. The
## den's 9 px strips of bezel top and bottom read as a crop, not a frame.
var board_rect := Rect2()
const THIN := 12.0
## The pace of the move (1, or 3 for Tab), and the key Tab leaves for Main once
## the camera is back out.
var _rate := 1.0
var _then_key: InputEvent
var _data_was := -1
var _note := ""
## THE BLOOM: what glows drawn alone into `_light_vp`, blurred into
## `_bloom_vp` (`lab_bloom.gdshader`) only when it changes, and added over the
## pages (`_bloom`).
var _light_vp: SubViewport
var _light_draw: Control
var _bloom_vp: SubViewport
var _bloom: TextureRect
var _light_dirty := true
var _bloom_wait := 0
## THE DECK'S FRAME through the camera (`_draw_frame`), under the room.
var _frame: Control


func _init() -> void:
	top_level = true
	position = Vector2.ZERO
	size = Vector2(W, H)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# (after the lab has lit its room this frame)
	process_priority = 10
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	_room = Control.new()
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room.draw.connect(_draw_room)
	add_child(_room)
	_life = _Life.new()
	_life.zoom = self
	add_child(_life)
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# (a transparent viewport's colour comes out premultiplied)
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_screen.material = pm
	_screen.draw.connect(_draw_screen)
	add_child(_screen)
	_ground = ColorRect.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.material = ShaderMaterial.new()
	(_ground.material as ShaderMaterial).shader = CHART
	add_child(_ground)
	_build_view()
	_fin_add = ColorRect.new()
	_fin_add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fin_add.material = ShaderMaterial.new()
	(_fin_add.material as ShaderMaterial).shader = FIN_ADD
	add_child(_fin_add)
	_fin_mul = ColorRect.new()
	_fin_mul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fin_mul.material = ShaderMaterial.new()
	(_fin_mul.material as ShaderMaterial).shader = FIN_MUL
	add_child(_fin_mul)


# ------------------------------------------------------------------ the view

## The Lab's pages at the board's own size, built once: the tabs, DATA and
## CREDITS, LEAVE, and RESEARCH, AUGMENT and RECIPES under them.
func _build_view() -> void:
	view = Control.new()
	view.size = Vector2(W, H)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	board = LabBoard.new()
	board.buy.connect(_on_buy)
	view.add_child(board)
	_pages[&"research"] = board
	augment = LabAugment.new()
	augment.lit_changed.connect(func() -> void: _light_dirty = true)
	view.add_child(augment)
	_pages[&"augment"] = augment
	recipes = LabRecipes.new()
	recipes.maker = _make
	recipes.lit_changed.connect(func() -> void: _light_dirty = true)
	view.add_child(recipes)
	_pages[&"recipes"] = recipes
	_header = Control.new()
	_header.size = Vector2(W, H)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	view.add_child(_header)
	var x := 42
	for row in TABS:
		var id: StringName = row[0]
		var label: String = row[1]
		var b := LabPlate.new(label, &"tab")
		b.position = Vector2(x, 34)
		b.size = Vector2(LabPlate.width_for(label, &"tab"), 16)
		b.pressed.connect(show_tab.bind(id))
		view.add_child(b)
		tab_buttons[id] = b
		x += int(b.size.x) + 4
	var lw := LabPlate.width_for("LEAVE", &"leave")
	leave_button = LabPlate.new("LEAVE", &"leave")
	leave_button.position = Vector2(W - T - 12 - lw, 34)
	leave_button.size = Vector2(lw, 17)
	leave_button.pressed.connect(close)
	view.add_child(leave_button)
	_light_vp = SubViewport.new()
	_light_vp.size = Vector2i(W, H)
	_light_vp.transparent_bg = true
	_light_vp.disable_3d = true
	_light_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_light_draw = Control.new()
	_light_draw.size = Vector2(W, H)
	_light_draw.draw.connect(func() -> void: _paint_light(_light_draw))
	_light_vp.add_child(_light_draw)
	add_child(_light_vp)
	_bloom_vp = SubViewport.new()
	_bloom_vp.size = Vector2i(W, H)
	_bloom_vp.disable_3d = true
	_bloom_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var blur := ColorRect.new()
	blur.size = Vector2(W, H)
	blur.material = ShaderMaterial.new()
	(blur.material as ShaderMaterial).shader = BLOOM
	(blur.material as ShaderMaterial).set_shader_parameter(&"light", _light_vp.get_texture())
	_bloom_vp.add_child(blur)
	add_child(_bloom_vp)
	_bloom = TextureRect.new()
	_bloom.texture = _bloom_vp.get_texture()
	_bloom.size = Vector2(W, H)
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bloom.material = add
	view.add_child(_bloom)
	board.lit_changed.connect(func() -> void: _light_dirty = true)


## THE RECIPES (`LabRecipes`, AUGMENT's layout since Jon's Nov 5 review) are
## made through the station, which logs the line and plays the bench's sound.
## Returns the line, "" when it did not happen.
func _make(r: Dictionary) -> String:
	if station != null and station.has_method(&"_fabricate"):
		return str(station.call(&"_fabricate", r))
	var line := Fabricator.make(Run.node_at(), r)
	if not line.is_empty():
		Audio.play(&"fabricate", 0.04)
	return line


func _on_buy(b: int) -> void:
	var k: int = Run.board_owned[b]
	var line := Science.buy(b)
	if line.is_empty():
		Audio.denied()
		return
	Audio.play(&"fabricate", 0.04)
	board.mark_bought(Vector2i(b, k))


## Show one of the Lab's pages.
func show_tab(id: StringName) -> void:
	if not _pages.has(id):
		return
	tab = id
	for k in _pages:
		(_pages[k] as Control).visible = k == id
	for k2 in tab_buttons:
		var b: LabPlate = tab_buttons[k2]
		b.on = k2 == id
		b.queue_redraw()
	(_ground.material as ShaderMaterial).set_shader_parameter(&"galaxy", 1.0 if id == &"research" else 0.0)
	_header.queue_redraw()
	_light_dirty = true


## Read the run again: the board, the recipes, the readouts. Never builds a node.
func refresh() -> void:
	if _data_was >= 0 and Run.data != _data_was and _goal > 0.0:
		_note = "%+d" % (Run.data - _data_was)
	_data_was = Run.data
	board.refresh()
	augment.refresh()
	recipes.refresh()
	_header.queue_redraw()


func _draw_header() -> void:
	_paint_header(_header, false)
	_light_dirty = true


## The readouts and the rule; with `light`, only what glows (the DATA count,
## the marks, the tab you are on).
func _paint_header(c: CanvasItem, light: bool) -> void:
	if light:
		for id in tab_buttons:
			var tb: LabPlate = tab_buttons[id]
			if tb.on:
				c.draw_rect(Rect2(tb.position.x, tb.position.y + 15, tb.size.x, 1), LabPlate.EMBER)
				LabBoard.text_at(c, int(tb.position.x) + 6, int(tb.position.y) + 5, tb.label, LabPlate.HOT)
	var lw := int(leave_button.size.x)
	var xr := W - T - 12 - lw - 16
	var cn := str(Run.credits)
	xr -= LabBoard.tw(cn, 16)
	if not light:
		LabBoard.text_at(c, xr, 38, cn, UITheme.ICE, 16)
	xr -= 9
	_mark(c, LabIcons.CR_MARK, xr, 40, UITheme.CHILL)
	xr -= 6 + LabBoard.tw("CREDITS")
	if not light:
		LabBoard.text_at(c, xr, 40, "CREDITS", UITheme.CHILL)
	xr -= 18
	var dn := str(Run.data)
	xr -= LabBoard.tw(dn, 16)
	LabBoard.text_at(c, xr, 38, dn, LabBoard.OWN, 16)
	xr -= 9
	_mark(c, LabIcons.DATA_MARK, xr, 40, LabBoard.OWN)
	xr -= 6 + LabBoard.tw("DATA")
	if light:
		return
	LabBoard.text_at(c, xr, 40, "DATA", UITheme.CHILL)
	if _note != "":
		xr -= 8 + LabBoard.tw(_note)
		LabBoard.text_at(c, xr, 40, _note, LabBoard.BAD if _note.begins_with("-") else LabBoard.OWN)
	var ink := LabBoard.mixc(LabBoard.BG, _tint, 0.22)
	c.draw_rect(Rect2(GLASS.position.x + 10, 57, GLASS.size.x - 20, 1), ink)


## What glows on the page on show, alone on black, for the bloom.
func _paint_light(ci: CanvasItem) -> void:
	_paint_header(ci, true)
	if tab == &"research":
		board.light = true
		board.paint(ci)
		board.paint_live(ci)
		board.light = false
	elif tab == &"augment":
		augment.light = true
		augment.paint(ci)
		augment.paint_live(ci)
		augment.light = false
	elif tab == &"recipes":
		recipes.light = true
		recipes.paint(ci)
		recipes.paint_live(ci)
		recipes.light = false


## The header's boxes, as the mockup's box test has them.
func header_leaves() -> Array:
	var out: Array = []
	for id in tab_buttons:
		var b: LabPlate = tab_buttons[id]
		out.append(["[tab %s]" % b.label, Rect2i(b.position, b.size)])
	out.append(["[LEAVE]", Rect2i(leave_button.position, leave_button.size)])
	var lw := int(leave_button.size.x)
	var xr := W - T - 12 - lw - 16
	for item: Array in [[str(Run.credits), 16, 38, 9], ["CREDITS", 8, 40, 18], [str(Run.data), 16, 38, 9], ["DATA", 8, 40, 8]]:
		var s: String = item[0]
		var sz: int = item[1]
		var w := LabBoard.tw(s, sz)
		xr -= w
		out.append([s, Rect2i(xr, int(item[2]) - 1, w, (5 if sz == 8 else 10) + 2)])
		xr -= int(item[3]) + (6 if s == str(Run.credits) or s == str(Run.data) else 0)
	if _note != "":
		var nw := LabBoard.tw(_note)
		out.append([_note, Rect2i(xr - nw, 39, nw, 7)])
	return out


func _mark(ci: CanvasItem, rows: Array, x: int, y: int, c: Color) -> void:
	var c2 := LabBoard.mixc(c, LabBoard.BG, 0.55)
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			if row[i] == "#":
				ci.draw_rect(Rect2(x + i, y + j, 1, 1), c)
			elif row[i] == "+":
				ci.draw_rect(Rect2(x + i, y + j, 1, 1), c2)


# ------------------------------------------------------------------ the move

## Whether the camera is in the glass, or on its way.
func is_open() -> bool:
	return _goal > 0.0


## Whether the move has landed and the pages are up.
func landed() -> bool:
	return _goal > 0.0 and _at >= _goal


func _total() -> float:
	return ZoomLadder.LAB_ZOOM_S + ZoomLadder.UI_IN_S


## Into the glass, onto page `id`.
func open(id: StringName = &"research") -> void:
	if lab == null or lab.lab.is_empty():
		return
	_level = lab._level
	_z = int(ZOOM.get(_level, 3))
	var tn: Array = (lab.lab.get("screen", {}) as Dictionary).get("tint", [255, 255, 255])
	_tint = Color(float(tn[0]) / 255.0, float(tn[1]) / 255.0, float(tn[2]) / 255.0)
	board.tint = _tint
	for k in tab_buttons:
		(tab_buttons[k] as LabPlate).rule = LabBoard.mixc(LabBoard.BG, _tint, 0.3)
	for m: ColorRect in [_ground, _fin_add]:
		(m.material as ShaderMaterial).set_shader_parameter(&"tint", Vector3(float(tn[0]), float(tn[1]), float(tn[2])))
	_land_at()
	_room.material = lab._mat
	_note = ""
	_data_was = Run.data
	# nothing new starts on the room's screen from the press on: the bad
	# signal's snow line crossed the sign-on at half strength
	lab.hush_screen(true)
	augment.tint = _tint
	augment.done = {}
	recipes.tint = _tint
	recipes.reset()
	board.bought = Vector2i(-1, -1)
	board.pick = Vector2i(-1, -1)
	show_tab(id)
	refresh()
	board._sig = ""
	board.refresh()
	visible = true
	_goal = _total()
	_rate = 1.0
	_then_key = null
	if not Router.animating():
		_at = _goal
	_apply()


## Back out to the room, the screen on its logo. The logo goes up at once while
## the sign-on is hidden under the pages; turned round before that (Esc on the
## way in), the glass keeps SIGNING IN until the camera is at rest
## (`StationScreen._process` then shows the logo, or the sign-in under the
## pointer): swapped mid-move, the look popped.
func close() -> void:
	if _goal <= 0.0:
		return
	_goal = 0.0
	_note = ""
	if signon_alpha() <= 0.0 or not Router.animating():
		leaving.emit()
	if not Router.animating():
		_at = 0.0
	_apply()


## The move to its end at once (a harness; never a player's key: camera moves,
## never cuts).
func finish() -> void:
	_at = _goal
	_apply()


func _process(delta: float) -> void:
	if not visible:
		return
	if _at != _goal:
		_at = move_toward(_at, _goal, delta * _rate)
		# NO FRAME OF THE MOVE WITH THE CAMERA STILL IN IT: smootherstep's first
		# and last hundredths move the picture by less than a px, so the camera
		# sets off from the first px it moves (the frame after the press) and
		# is at rest, the input back, on the frame its picture is the room's own
		if hold_at < 0.0 and _at > 0.0 and _at < ZoomLadder.LAB_ZOOM_S and _still_at(_at):
			_at = 0.0 if _goal <= 0.0 else _first_move()
		_apply()
	elif _at > 0.0:
		# the lab's light moves round the landed glass; its life with it
		if _room.visible:
			_room.queue_redraw()
			_life.queue_redraw()
	if _screen.visible:
		_screen.queue_redraw()
	(_ground.material as ShaderMaterial).set_shader_parameter(&"phase", board.phase)
	if _light_dirty and view.visible:
		_light_dirty = false
		_light_draw.queue_redraw()
		_light_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_bloom_wait = 2
	if _bloom_wait > 0:
		_bloom_wait -= 1
		_bloom_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _input(e: InputEvent) -> void:
	if _goal <= 0.0 and _at <= 0.0:
		return
	var key := e as InputEventKey
	var mb := e as InputEventMouseButton
	var pad := e as InputEventJoypadButton
	# NEXT SCREEN (Tab) WITH THE CAMERA IN THE GLASS: out to the room, the
	# station's chrome back, and then the key for Main, so the ladder's move off
	# the station starts from the room it knows (it played under the Lab's
	# picture, and the map arrived as a cut). The camera goes out at three times
	# its pace rather than jumping: it moves, never cuts. Unanimated (a harness)
	# it is out at once and the key goes straight on.
	if key != null and key.pressed and not key.echo and key.is_action_pressed(&"next_screen"):
		if _goal <= 0.0 and _then_key != null:
			get_viewport().set_input_as_handled()
			return
		var was_open := _goal > 0.0
		_goal = 0.0
		if not Router.animating():
			_at = 0.0
			leaving.emit()
			_apply()
			return
		get_viewport().set_input_as_handled()
		if was_open and signon_alpha() <= 0.0:
			leaving.emit()
		_rate = 3.0
		_then_key = e.duplicate()
		_apply()
		return
	var esc := key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE
	# THE PAD'S B is the pad's Esc: the pad's A opens the Lab
	# (`StationScreen._unhandled_input`), and there was no way back out on it
	var back := esc or (pad != null and pad.pressed and pad.button_index == JOY_BUTTON_B)
	var moving := _at != _goal
	if moving and ((key != null and key.pressed) or (mb != null and mb.pressed) or (pad != null and pad.pressed)):
		# A PRESS DURING A MOVE IS EATEN, AND THE CAMERA GOES ON (camera moves,
		# never cuts: it used to finish the move at once, a jump). Eaten, a click
		# on the way out cannot open the Lab again from the glass, nor the second
		# click of a double-click on the glass land on a page key. Esc or B on the
		# way in turns the camera round (not on to the pause menu over a Lab that
		# just landed).
		get_viewport().set_input_as_handled()
		if back and _goal > 0.0:
			close()
		return
	if back and _goal > 0.0:
		get_viewport().set_input_as_handled()
		close()


## Whether at the timeline's point `t` the camera's picture is still the
## room's own, px for px: the room and the deck's frame on screen where they
## stand at rest.
func _still_at(t: float) -> bool:
	if lab == null or not is_instance_valid(lab) or lab.lab.is_empty():
		return false
	var xf := lab.get_global_transform()
	var s0 := xf.get_scale().x
	var o0 := xf.origin
	var z := float(_z)
	if is_equal_approx(s0, z):
		return true
	var e := ZoomLadder._ease_cam(t / ZoomLadder.LAB_ZOOM_S)
	if e <= 0.0:
		return true
	var s := s0 * pow(z / s0, e)
	var pt := (_o1 - o0) / (s0 - z)
	var o := (o0 + pt * s0 - pt * s).round()
	var rects: Array[Rect2] = [Rect2(Vector2.ZERO, LabScene.PANEL)]
	var p := _frame_page()
	if p != null:
		var g := p.get_global_rect()
		rects.append(Rect2((g.position - o0) / s0, g.size / s0))
	for r: Rect2 in rects:
		if (o + r.position * s).round() != (o0 + r.position * s0).round() 				or (o + r.end * s).round() != (o0 + r.end * s0).round():
			return false
	return true


## The first point of the move whose picture is not the room's own (found by
## halving: the camera only goes further in as `t` grows).
func _first_move() -> float:
	var lo := _at
	var hi := ZoomLadder.LAB_ZOOM_S
	for i in 24:
		var mid := (lo + hi) * 0.5
		if _still_at(mid):
			lo = mid
		else:
			hi = mid
	return hi


## Everything at the timeline's point `_at`.
func _apply() -> void:
	var move_s := ZoomLadder.LAB_ZOOM_S
	var in_s := ZoomLadder.UI_IN_S
	var ui_k := clampf(_at / FX_S, 0.0, 1.0)
	# WHAT THE BIG SCREEN DOES GOES WITH THE CHROME (its snow and slips over the
	# sign-on); the sign-on itself stays, and the camera carries it in
	for c0: CanvasItem in on_glass:
		if c0 != null and is_instance_valid(c0):
			c0.modulate.a = 1.0 - ui_k
	var u := clampf(_at / move_s, 0.0, 1.0)
	if hold_at >= 0.0:
		u = hold_at
	var e := ZoomLadder._ease_cam(u)
	var moving := _at > 0.0 or hold_at >= 0.0
	var landed_now := e >= 1.0
	var vk := clampf((_at - move_s) / in_s, 0.0, 1.0) if hold_at < 0.0 else 0.0
	# THE ROOM, through the camera, from the moment it moves. Once the pages
	# are up over a glass that covers the window, nothing of the room shows:
	# it is not drawn for nothing under the board. Where the bezel shows round
	# the glass (the settlement, the den) it stays, lit and live; the sign-on
	# under the board's ground goes once the ground is whole.
	var covered := Rect2(0, 0, W, H).intersection(board_rect).is_equal_approx(Rect2(0, 0, W, H))
	var room_on := moving and not (landed_now and vk >= 1.0 and covered)
	for c: CanvasItem in [_room, _life]:
		c.visible = room_on
	# THE DECK'S FRAME GOES WITH THE ROOM: drawn through the camera while the
	# room is, the deck's own plate hidden under it from the frame the camera
	# leaves the room to the frame it lands back there (the same pixels at
	# both ends, so the hand-over is not seen). Nothing of it fades.
	_frame.visible = room_on
	_chrome(moving)
	# THE SIGN-ON GOES BEFORE THE PAGES COME (the review, Nov 5: the sign-in's
	# fields at 3-4x crossed the chart's 1x words for 0.4 s): out over the first
	# half of the beat, the pages in from 0.3 of it; on LEAVE the other way round
	var so := signon_alpha()
	_screen.visible = moving and so > 0.0
	# (premultiplied: the colour goes down with the alpha)
	_screen.modulate = Color(so, so, so, so)
	var shown := _at > 0.0 or hold_at >= 0.0
	# THE PAGES COME UP ON THE LANDED GLASS, its ground with them, over the
	# sign-in the camera carried in (and go, back out, before it moves)
	var pk := smoothstep(0.3, 1.0, vk)
	view.visible = pk > 0.0
	view.modulate.a = pk
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c2: ColorRect in [_ground, _fin_add, _fin_mul]:
		c2.visible = vk > 0.0
		(c2.material as ShaderMaterial).set_shader_parameter(&"amount", vk)
	mouse_filter = Control.MOUSE_FILTER_STOP if _at > 0.0 or _goal > 0.0 else Control.MOUSE_FILTER_IGNORE
	if shown and lab != null and is_instance_valid(lab) and not lab.lab.is_empty():
		_place(e if moving else 0.0)
		_carry(true)
	if _at <= 0.0 and _goal <= 0.0:
		visible = false
		if lab != null and is_instance_valid(lab):
			lab.hush_screen(false)
		for c3: CanvasItem in on_glass:
			if c3 != null and is_instance_valid(c3):
				c3.modulate.a = 1.0
		_chrome(false)
		_carry(false)
		_rate = 1.0
		closed.emit()
		if _then_key != null:
			var k := _then_key
			_then_key = null
			GameShell.input_target(get_tree()).push_input(k)
	elif _at >= _goal and _goal > 0.0 and vk >= 1.0:
		opened.emit()


## How much of the sign-on the camera carries in shows now: whole while the
## camera moves, gone by the middle of the pages' beat (`UI_IN_S`).
func signon_alpha() -> float:
	if hold_at >= 0.0:
		return 1.0
	var vk := clampf((_at - ZoomLadder.LAB_ZOOM_S) / ZoomLadder.UI_IN_S, 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 0.5, vk)


## The deck's own plate hidden while the camera draws it (`away`), or as it
## was (`StationScreen.lab_chrome`).
func _chrome(away: bool) -> void:
	if station != null and is_instance_valid(station) and station.has_method(&"lab_chrome"):
		station.call(&"lab_chrome", away)


## THE ELEVATOR AND THE HUD RIDE THE FRAME'S EDGES (`StationScreen.lab_carry`):
## moved as far as the camera has moved the deck's frame from where it
## stands (the elevator by its left edge, the HUD by its top), out of the
## window going in and back into their places on the frame the camera lands
## coming out; `on` false puts them back as they were. By the frame, not the
## room: the frame's margin grows with the camera, and carried by the room's
## edge the elevator ran onto it.
func _carry(on: bool) -> void:
	if station == null or not is_instance_valid(station) or not station.has_method(&"lab_carry"):
		return
	var d := Vector2.ZERO
	var p := _frame_page()
	if on and p != null and lab != null and is_instance_valid(lab):
		d = frame_rect().position - p.get_global_rect().position
	station.call(&"lab_carry", d, on)


## The deck page whose plate frames the room (`StationScreen.lab_frame`).
func _frame_page() -> Control:
	if station == null or not is_instance_valid(station) or not station.has_method(&"lab_frame"):
		return null
	var p: Variant = station.call(&"lab_frame")
	if is_instance_valid(p) and p is Control:
		return p as Control
	return null


## Whatever takes the station away (a screen change, a run's end) takes the
## Lab with it: the HUD it hid comes back.
func _exit_tree() -> void:
	_chrome(false)
	_carry(false)
	if lab != null and is_instance_valid(lab):
		lab.hush_screen(false)


## WHERE THE CAMERA LANDS: the lab's glass at `_z`, centred in the window (each
## lab's glass is an even number of picture px across and down, so this is on
## whole px), and the board's ground, finish and chart laid on it.
func _land_at() -> void:
	var g := lab.glass_rect()
	_o1 = landed_origin(lab)
	glass_on_screen = Rect2(_o1 + g.position * float(_z), g.size * float(_z))
	board_rect = glass_on_screen
	var gaps := [glass_on_screen.position.x, glass_on_screen.position.y,
		W - glass_on_screen.end.x, H - glass_on_screen.end.y]
	if gaps.all(func(v: float) -> bool: return v <= THIN):
		board_rect = glass_on_screen.merge(Rect2(0, 0, W, H).grow(16.0))
	for c: ColorRect in [_ground, _fin_add, _fin_mul]:
		c.position = board_rect.position
		c.size = board_rect.size
	var gm := _ground.material as ShaderMaterial
	gm.set_shader_parameter(&"rpos", board_rect.position)
	gm.set_shader_parameter(&"rsize", board_rect.size)
	for f: ColorRect in [_fin_add, _fin_mul]:
		(f.material as ShaderMaterial).set_shader_parameter(&"gsize", board_rect.size)
	# (the glare on the glass where the window's top-left corner sees it, as on
	# the board's own glass)
	(_fin_add.material as ShaderMaterial).set_shader_parameter(&"glare_at",
		Vector2(maxf(0.0, -board_rect.position.x), maxf(0.0, -board_rect.position.y)))


## Where the room's picture stands on screen once the camera has landed: the
## lab's glass at its zoom, centred in the window (each lab's glass is an even
## number of picture px across and down, so this is on whole px).
static func landed_origin(l: LabScene) -> Vector2:
	var g := l.glass_rect()
	var z := float(ZOOM.get(l._level, 3))
	return (Vector2(W, H) / 2.0 - (g.position + g.size / 2.0) * z).round()


## What of the room's picture (picture px) the window shows once the camera has
## landed. The sign-on is laid out inside it (`LabLogin.safe`): the sign-in's
## header ran to the screen's edges and was cut off at four labs.
static func landed_view(l: LabScene) -> Rect2:
	var z := float(ZOOM.get(l._level, 3))
	return Rect2(-landed_origin(l) / z, Vector2(W, H) / z)


## THE CAMERA at its progress `e` (0 the room where it stands, 1 landed): one
## scale for the whole room, going from the room's own to `_z` by the same
## ratio each step, about the one point of the room that both ends put at the
## same place on screen. Its origin is held to whole px.
func _place(e: float) -> void:
	var xf := lab.get_global_transform()
	var s0 := xf.get_scale().x
	var o0 := xf.origin
	var z := float(_z)
	if e <= 0.0:
		_s = s0
		_o = o0
	elif e >= 1.0:
		_s = z
		_o = _o1
	else:
		_s = s0 * pow(z / s0, e)
		# the still point: o0 + p * s0 == _o1 + p * z
		var p := (_o1 - o0) / (s0 - z)
		_o = (o0 + p * s0 - p * _s).round()
	_frame.queue_redraw()
	_room.queue_redraw()
	_life.queue_redraw()
	_screen.queue_redraw()


## Where the room's picture is on screen now.
func room_rect() -> Rect2:
	return Rect2(_o, LabScene.PANEL * _s)


## The camera's scale now (screen px per picture px).
func cam_scale() -> float:
	return _s


## Where the deck's frame (its plate's outer edge) is on screen now: the
## page's rect as the room's picture has it, through the camera, on whole px.
## At rest, the page's own rect.
func frame_rect() -> Rect2:
	var p := _frame_page()
	if p == null or lab == null or not is_instance_valid(lab):
		return Rect2()
	var xf := lab.get_global_transform()
	var s0 := xf.get_scale().x
	var g := p.get_global_rect()
	return to_screen(Rect2((g.position - xf.origin) / s0, g.size / s0))


## A rect of the room's picture (picture px) where the camera has it, on whole px.
func to_screen(r: Rect2) -> Rect2:
	var a := (_o + r.position * _s).round()
	var b := (_o + r.end * _s).round()
	return Rect2(a, b - a)


## THE ROOM, the whole painted lab at the camera's one scale, lit by the
## lab's own light.
func _draw_room() -> void:
	if lab == null or lab._pic.texture == null:
		return
	_room.draw_texture_rect(lab._pic.texture, Rect2(_o, LabScene.PANEL * _s), false)


## THE DECK'S FRAME, the page's plate as its stylebox draws it (its backing
## inside a border), through the camera: the border as many screen px thick
## as the camera makes one of the room's, every edge on the room's own grid
## (`to_screen`), so the frame and the room move as one picture.
func _draw_frame() -> void:
	var p := _frame_page()
	if p == null or lab == null or not is_instance_valid(lab):
		return
	var sb := p.get_theme_stylebox(&"panel") as StyleBoxFlat
	if sb == null:
		return
	var xf := lab.get_global_transform()
	var s0 := xf.get_scale().x
	var g := p.get_global_rect()
	var pic := Rect2((g.position - xf.origin) / s0, g.size / s0)
	var outer := to_screen(pic)
	var bl := Vector2(sb.border_width_left, sb.border_width_top) / s0
	var br := Vector2(sb.border_width_right, sb.border_width_bottom) / s0
	var inner := to_screen(Rect2(pic.position + bl, pic.size - bl - br))
	if sb.draw_center:
		_frame.draw_rect(inner, sb.bg_color)
	var bc := sb.border_color
	if bc.a <= 0.0:
		return
	_frame.draw_rect(Rect2(outer.position, Vector2(outer.size.x, inner.position.y - outer.position.y)), bc)
	_frame.draw_rect(Rect2(outer.position.x, inner.end.y, outer.size.x, outer.end.y - inner.end.y), bc)
	_frame.draw_rect(Rect2(outer.position.x, inner.position.y, inner.position.x - outer.position.x, inner.size.y), bc)
	_frame.draw_rect(Rect2(inner.end.x, inner.position.y, outer.end.x - inner.end.x, inner.size.y), bc)


## THE SIGN-ON ON THE GLASS, the room's own texture through the camera: as
## much of it as the power-on's scan has opened in the room.
func _draw_screen() -> void:
	if screen == null or not is_instance_valid(screen) or screen.texture == null or lab == null:
		return
	var wr := lab.win_rect()
	var shown := wr.size.y
	var clip := screen.get_parent() as Control
	if clip != null and clip.clip_contents:
		shown = clampf(clip.position.y + clip.size.y - wr.position.y, 0.0, wr.size.y)
	if shown <= 0.0:
		return
	var tex := screen.texture
	var tsz := Vector2(tex.get_size())
	var src := Rect2(Vector2.ZERO, Vector2(minf(tsz.x, wr.size.x), minf(tsz.y, shown)))
	var at := to_screen(Rect2(wr.position, src.size))
	_screen.draw_texture_rect_region(tex, at, src)


## THE ROOM'S LIFE THROUGH THE CAMERA: the lab draws its bubbles, monitors and
## fizz here as it does in the room (`LabScene._draw_life`), each of its rects
## where the camera has that part of the room.
class _Life extends Control:
	var zoom: LabZoom

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if zoom == null or zoom.lab == null or zoom.lab.lab.is_empty():
			return
		zoom.lab._draw_life(self)

	func life_rect(r: Rect2, c: Color) -> void:
		var rr := zoom.to_screen(r)
		if rr.has_area():
			draw_rect(rr, c)


# ------------------------------------------------------------------ the tests

## Every box on the page on show, as the mockup's box test has them: drawn
## words and rings, and the keys.
func leaves() -> Array:
	var out: Array = header_leaves()
	if tab == &"research":
		out.append_array(board.leaves)
	elif tab == &"augment":
		out.append_array(augment.leaves)
	elif tab == &"recipes":
		out.append_array(recipes.leaves)
	return out


## The box test on the page on show: empty when every box is inside the
## glass, no two overlap, and no word crosses an arm. And the board's glass is
## inside the lab's glass as the camera has landed it, and in the window.
func check() -> PackedStringArray:
	var bad := PackedStringArray()
	if glass_on_screen.has_area():
		var seen := Rect2(0, 0, W, H).intersection(glass_on_screen)
		if not seen.grow(0.01).encloses(GLASS):
			bad.append("the board's glass %s is not inside the lab's glass on screen %s" % [GLASS, seen])
	if tab == &"research":
		bad.append_array(board.check(header_leaves()))
		return bad
	if tab == &"augment":
		bad.append_array(augment.check(header_leaves()))
		return bad
	if tab == &"recipes":
		bad.append_array(recipes.check(header_leaves()))
		return bad
	var all := leaves()
	for l: Array in all:
		if not Rect2i(GLASS).encloses(l[1]):
			bad.append("'%s' %s is outside the glass" % [l[0], l[1]])
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i][1] as Rect2i).intersects(all[j][1]):
				bad.append("'%s' overlaps '%s'" % [all[i][0], all[j][0]])
	return bad
