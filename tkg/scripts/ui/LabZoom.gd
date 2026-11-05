class_name LabZoom
extends Control

## THE CAMERA INTO THE LAB'S SCREEN (science S9; Jon's 1C, Nov 4, and his
## question the same day: "is the screen really big enough for a player to see
## all of it?"). It is not, at the glass's own size: the capital's glass is
## 440x228 and the settlement's 230x124, and the board was drawn for 908x488.
## So pressing the screen in the room moves the camera into the glass until the
## glass fills the window, and the Lab's pages are on it at the board's own
## size: RESEARCH (the star chart, `LabBoard`), AUGMENT and RECIPES. LEAVE, or
## Esc, takes the camera back out to the room.
##
## ONE CAMERA MOVE, NOT A CUT, between ZoomLadder's two beats: the room's entry
## on the glass goes (`UI_OUT_S`, the camera still), the camera moves
## (`LAB_ZOOM_S`, smootherstep), and the Lab's pages come up on the landed
## glass (`UI_IN_S`). Back out it all runs backwards. A click or a key during a
## move finishes it at once, as on the ladder.
##
## THE PICTURE IS THE ROOM'S OWN, LIT AND LIVE. This draws the lab's painted
## room with the lab's own light (`LabScene`'s material, so a lamp that
## flickers in the room flickers here) and the room's life (the tanks' bubbles,
## the monitors), scaled by the camera to a whole number per lab (`ZOOM`: the
## frame and the wall keep one pixel size). The glass then fills the window but
## for the bezel round it (`T`): the bezel is the room's own, NINE-SLICED as the
## approved mockup's `frame()` did it (tk-scratch/science/sheet2/tree/build/
## build.py) -- its corners as painted, each side stretched by repeating its
## most even run (`FIT`, the mockup's own choice per side) or cut in one. The
## warp grows with the camera, so the first frame of the move is the room as
## it stood and the last is the mockup's frame.
##
## THE CAPITAL'S BENCH stands in front of its screen's lower edge, its flasks
## over the glass. The view looks over them: the bezel's lower edge is its
## upper profile turned over (the mockup's rule), dithered in as the camera
## moves (`lab_light.gdshader`'s `mirror`), and the flasks go with it.
##
## THE GLASS GOES AS THE CAMERA MOVES (`hole`): the screen's own dark glass
## gives way to the chart under it (`lab_chart.gdshader`), so what the camera
## lands on is the Lab's screen showing the board, never a held picture.

signal opened
signal closed

const T := 26
const K := 16
## The run a side repeats to stretch, in zoomed px.
const RUN := 24
const W := 960
const H := 540
const GLASS := Rect2(26, 26, 908, 488)
## The camera's whole-number zoom at each lab: the glass at that scale fits
## the window, its sides stretched or cut a little.
const ZOOM := {"capital": 2, "unclaimed": 2, "settlement": 3, "city": 3, "outpost": 3}
## Where each side of each lab's bezel repeats (or is cut), in zoomed px from
## the side's first px past its corner: the mockup's `fit` searched each side
## of the lit room for its most even run, and these are its answers (top,
## bottom, left, right), so the frame here is the frame Jon approved.
const FIT := {
	"capital": [28, 28, 200, 184],
	"settlement": [32, 512, 50, 24],
	"city": [24, 80, 74, 74],
	"outpost": [176, 116, 74, 362],
	"unclaimed": [392, 124, 232, 264],
}
## The capital's bench in its picture: its top edge (row 318) and its ends.
const BENCH := Rect2(104, 318, 532, 70)
const TABS := [[&"research", "RESEARCH"], [&"augment", "AUGMENT"], [&"recipes", "RECIPES"]]
const CHART := preload("res://shaders/lab_chart.gdshader")
const FIN_ADD := preload("res://shaders/lab_finish_add.gdshader")
const FIN_MUL := preload("res://shaders/lab_finish_mul.gdshader")
const BLOOM := preload("res://shaders/lab_bloom.gdshader")

## `stationshot labzoom=k`: the move held at this much of its camera (0..1).
static var hold_at := -1.0

var lab: LabScene
## The room's entry on the glass: it goes before the camera moves.
var entry: Control
## The station screen: the recipes are made through it (`_fabricate`).
var station: Node
var tab: StringName = &"research"

var view: Control
var board: LabBoard
var augment: Control
var recipes: Control
var tab_buttons := {}
var leave_button: LabPlate
## One per recipe: {r, name, held, cost, what, make}, built once.
var recipe_rows: Array = []

var _at := 0.0
var _goal := 0.0
var _level := ""
var _z := 2
var _tint := Color(1, 1, 1)
var _ground: ColorRect
var _fin_add: ColorRect
var _fin_mul: ColorRect
var _room: Control
var _life: Control
var _header: Control
var _pages := {}
## The glass on screen now, and the camera's px per zoomed px.
var _f := Rect2()
var _q := 1.0
var _maps := {}
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
## The capital's bench, looked over: how far, and where (picture px).
var _mirror := 0.0
var _mirror_box := Rect2()


func _init() -> void:
	top_level = true
	position = Vector2.ZERO
	size = Vector2(W, H)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# (after the lab has lit its room this frame)
	process_priority = 10
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
	_room = Control.new()
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room.draw.connect(_draw_room)
	add_child(_room)
	_life = _Life.new()
	_life.zoom = self
	add_child(_life)


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
	# TODO(S9 part two): AUGMENT and STRIP, on the mockup's 2_augment_capital.png.
	augment = Control.new()
	augment.size = Vector2(W, H)
	augment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(augment)
	_pages[&"augment"] = augment
	recipes = Control.new()
	recipes.size = Vector2(W, H)
	recipes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipes.draw.connect(_draw_recipes)
	view.add_child(recipes)
	_pages[&"recipes"] = recipes
	_build_recipes()
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


## THE RECIPES, AS ROWS ON THE GLASS: what the Lab makes from what you carry,
## each with what you hold of it and the one key that makes it. DEVELOP FILM
## and READ FOR DATA turn a survey film and a relic into DATA; RELIC ANALYSIS
## reads a relic out as a part. Built once and restyled (`refresh`).
const RECIPE_ORDER := [&"develop", &"read", &"analysis"]
const RECIPE_Y := 82
const RECIPE_PITCH := 72


func _build_recipes() -> void:
	var order: Array = []
	for id in RECIPE_ORDER:
		for r in DB.RECIPES:
			if StringName(r.id) == id:
				order.append(r)
	for r in DB.RECIPES:
		if not order.has(r):
			order.append(r)
	for i in order.size():
		var r: Dictionary = order[i]
		var y := RECIPE_Y + i * RECIPE_PITCH
		var name := _label(str(r.name).to_upper(), UITheme.ICE, 16, 60, y)
		var held := _label("", UITheme.CHILL, 8, 60 + LabBoard.tw(str(r.name).to_upper(), 16) + 10, y + 4)
		var cost := _label("", UITheme.EMBER, 8, 60, y + 18)
		var what := _label(str(r.text).to_upper(), UITheme.CHILL, 8, 60, y + 30)
		var make := LabPlate.new("MAKE", &"commit")
		make.size = Vector2(LabBoard.tw("MAKE") + 60, 19)
		make.position = Vector2(W - T - 14 - make.size.x, y - 2)
		make.pressed.connect(_make.bind(r))
		recipes.add_child(make)
		recipe_rows.append({r = r, name = name, held = held, cost = cost, what = what, make = make, y = y})


## A word on the glass with its capitals' top on `ycap` (a Label's box starts
## above its capitals: 4 px at F8, 7 at F16).
func _label(s: String, c: Color, sz: int, x: int, ycap: int) -> Label:
	var l := UITheme.body(s, c, sz)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(x, ycap - (4 if sz == 8 else 7))
	recipes.add_child(l)
	return l


func _make(r: Dictionary) -> void:
	if station != null and station.has_method(&"_fabricate"):
		station.call(&"_fabricate", r)


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
	var n: MapGen.MapNode = Run.node_at()
	for row: Dictionary in recipe_rows:
		var r: Dictionary = row.r
		var on := n != null and Fabricator.available(n).has(r)
		for k in ["name", "held", "cost", "what", "make"]:
			(row[k] as Control).visible = on
		if not on:
			continue
		var can := Fabricator.can_make(n, r)
		(row.name as Label).add_theme_color_override("font_color", UITheme.ICE if can else UITheme.COLD)
		var bits: PackedStringArray = []
		for id in (r.mats as Dictionary).keys():
			bits.append("%d %s" % [Run.material(id), str(MaterialTable.by_id(id).get("name", id)).to_upper()])
		(row.held as Label).text = "YOU HAVE " + ", ".join(bits)
		(row.cost as Label).text = Fabricator.cost_line(n, r).to_upper()
		(row.cost as Label).add_theme_color_override("font_color", UITheme.EMBER if can else UITheme.QUOTE)
		(row.make as LabPlate).disabled = not can
		(row.make as LabPlate).queue_redraw()
	recipes.queue_redraw()
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
	elif tab == &"recipes":
		for row: Dictionary in recipe_rows:
			var mk := row.make as LabPlate
			if mk.visible and not mk.disabled:
				var r := Rect2i(mk.position, mk.size)
				LabBoard.text_at(ci, r.position.x + floori((r.size.x - LabBoard.tw(mk.label)) / 2.0),
					r.position.y + floori((r.size.y - 5) / 2.0), mk.label, LabPlate.HOT)


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


func _draw_recipes() -> void:
	var ink := LabBoard.mixc(LabBoard.BG, _tint, 0.22)
	for i in range(1, recipe_rows.size()):
		var y: int = recipe_rows[i].y - 18
		recipes.draw_rect(Rect2(GLASS.position.x + 10, y, GLASS.size.x - 20, 1), ink)


# ------------------------------------------------------------------ the move

## Whether the camera is in the glass, or on its way.
func is_open() -> bool:
	return _goal > 0.0


## Whether the move has landed and the pages are up.
func landed() -> bool:
	return _goal > 0.0 and _at >= _goal


func _total() -> float:
	return ZoomLadder.UI_OUT_S + ZoomLadder.LAB_ZOOM_S + ZoomLadder.UI_IN_S


## Into the glass, onto page `id`.
func open(id: StringName = &"research") -> void:
	if lab == null or lab.lab.is_empty():
		return
	_level = lab._level
	_z = int(ZOOM.get(_level, 2))
	var tn: Array = (lab.lab.get("screen", {}) as Dictionary).get("tint", [255, 255, 255])
	_tint = Color(float(tn[0]) / 255.0, float(tn[1]) / 255.0, float(tn[2]) / 255.0)
	board.tint = _tint
	for k in tab_buttons:
		(tab_buttons[k] as LabPlate).rule = LabBoard.mixc(LabBoard.BG, _tint, 0.3)
	for m: ColorRect in [_ground, _fin_add]:
		(m.material as ShaderMaterial).set_shader_parameter(&"tint", Vector3(float(tn[0]), float(tn[1]), float(tn[2])))
	_note = ""
	_data_was = Run.data
	board.bought = Vector2i(-1, -1)
	board.pick = Vector2i(-1, -1)
	show_tab(id)
	refresh()
	board._sig = ""
	board.refresh()
	visible = true
	_goal = _total()
	if not Router.animating():
		_at = _goal
	_apply()


## Back out to the room.
func close() -> void:
	if _goal <= 0.0:
		return
	_goal = 0.0
	_note = ""
	if not Router.animating():
		_at = 0.0
	_apply()


## The move to its end at once (a click or a key during it; a harness).
func finish() -> void:
	_at = _goal
	_apply()


func _process(delta: float) -> void:
	if not visible:
		return
	if _at != _goal:
		_at = move_toward(_at, _goal, delta)
		_apply()
	elif _at > ZoomLadder.UI_OUT_S:
		# the lab's light moves under the frame; its life with it
		_room.queue_redraw()
		_life.queue_redraw()
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
	var moving := _at != _goal
	if moving and ((key != null and key.pressed) or (mb != null and mb.pressed)):
		# A PRESS DURING A MOVE ENDS IT, as on the ladder, and is not eaten
		finish()
		return
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and _goal > 0.0:
		get_viewport().set_input_as_handled()
		close()


## Everything at the timeline's point `_at`.
func _apply() -> void:
	var out_s := ZoomLadder.UI_OUT_S
	var move_s := ZoomLadder.LAB_ZOOM_S
	var in_s := ZoomLadder.UI_IN_S
	if entry != null and is_instance_valid(entry):
		entry.modulate.a = 1.0 - clampf(_at / out_s, 0.0, 1.0)
	var u := clampf((_at - out_s) / move_s, 0.0, 1.0)
	if hold_at >= 0.0:
		u = hold_at
	var e := ZoomLadder._ease_cam(u)
	var moving := _at > out_s or hold_at >= 0.0
	for c: CanvasItem in [_ground, _fin_add, _fin_mul, _room, _life]:
		c.visible = moving
	var vk := clampf((_at - out_s - move_s) / in_s, 0.0, 1.0) if hold_at < 0.0 else 0.0
	view.visible = vk > 0.0
	view.modulate.a = vk
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP if _at > 0.0 or _goal > 0.0 else Control.MOUSE_FILTER_IGNORE
	# the glass gives way to the chart over the move's first part, and the
	# capital's flasks go as the camera passes over them
	var hole := clampf(u / 0.4, 0.0, 1.0)
	var mirror := smoothstep(0.2, 0.8, u)
	if lab != null and is_instance_valid(lab) and not lab.lab.is_empty():
		_set_light(hole if moving else 0.0, mirror if moving else 0.0)
	for c2: ColorRect in [_ground, _fin_add, _fin_mul]:
		(c2.material as ShaderMaterial).set_shader_parameter(&"amount", hole)
	if moving:
		_place(e)
	if _at <= 0.0 and _goal <= 0.0:
		visible = false
		if lab != null and is_instance_valid(lab):
			_set_light(0.0, 0.0)
		if entry != null and is_instance_valid(entry):
			entry.modulate.a = 1.0
		closed.emit()
	elif _at >= _goal and _goal > 0.0 and vk >= 1.0:
		opened.emit()


## The lab's own light, told where the glass and the bench are.
func _set_light(hole: float, mirror: float) -> void:
	var m: ShaderMaterial = lab._mat
	var g: Array = (lab.lab.get("screen", {}) as Dictionary).get("glass", [0, 0, 0, 0])
	var gx0 := float(g[0])
	var gy0 := float(g[1])
	var gx1 := float(g[2]) + 1.0
	var gy1 := float(g[3]) + 1.0
	m.set_shader_parameter(&"hole", hole)
	m.set_shader_parameter(&"hole_box", Vector4(gx0, gy0, gx1, gy1))
	m.set_shader_parameter(&"hole_masked", (lab.lab.get("screen", {}) as Dictionary).has("glassCols"))
	m.set_shader_parameter(&"hole_k", float(K) / float(_z))
	if _level == "capital":
		# from the glass's middle down to the bench's top, across the bench: the
		# mockup turned the rows over from the middle to the frame's edge, and
		# going on to the bench takes the flasks and microscopes whole (their
		# feet stood below the frame's edge, cut through mid-move)
		var t := float(T) / float(_z)
		var mid := floorf((gy0 + gy1) / 2.0)
		var x0 := minf(gx0 - t, BENCH.position.x)
		var x1 := maxf(gx1 + t, BENCH.end.x)
		var y1 := maxf(gy1 + t, BENCH.position.y)
		m.set_shader_parameter(&"mirror", mirror)
		m.set_shader_parameter(&"mirror_box", Vector4(x0, mid, x1, y1))
		m.set_shader_parameter(&"mirror_sum", gy0 + gy1 - 1.0)
		_mirror = mirror
		_mirror_box = Rect2(x0, mid, x1 - x0, y1 - mid)
	else:
		m.set_shader_parameter(&"mirror", 0.0)
		_mirror = 0.0


## The glass on screen at the camera's progress `e`, and the warp that frames it.
func _place(e: float) -> void:
	var g: Array = (lab.lab.get("screen", {}) as Dictionary).get("glass", [0, 0, 0, 0])
	var gx0 := int(g[0])
	var gy0 := int(g[1])
	var gw := int(g[2]) - gx0 + 1
	var gh := int(g[3]) - gy0 + 1
	var xf := lab.get_global_transform()
	var s0 := xf.get_scale().x
	var rest := Rect2(xf * Vector2(gx0, gy0), Vector2(gw, gh) * s0)
	_f = Rect2(rest.position.lerp(GLASS.position, e), rest.size.lerp(GLASS.size, e))
	var s := lerpf(s0, float(_z), e)
	_q = s / float(_z)
	var z := _z
	var fit: Array = FIT.get(_level, [0, 0, 0, 0])
	var x0 := gx0 * z
	var x1 := (gx0 + gw) * z
	var y0 := gy0 * z
	var y1 := (gy0 + gh) * z
	var wz := int(LabScene.PANEL.x) * z
	var hz := int(LabScene.PANEL.y) * z
	var nx := int(GLASS.size.x) - 2 * K - (x1 - x0 - 2 * K)
	var ny := int(GLASS.size.y) - 2 * K - (y1 - y0 - 2 * K)
	_maps = {
		top = _axis(x0, x1, wz, _f.position.x, _f.end.x, int(fit[0]), nx),
		bottom = _axis(x0, x1, wz, _f.position.x, _f.end.x, int(fit[1]), nx),
		left = _axis(y0, y1, hz, _f.position.y, _f.end.y, int(fit[2]), ny),
		right = _axis(y0, y1, hz, _f.position.y, _f.end.y, int(fit[3]), ny),
		x0 = x0, x1 = x1, y0 = y0, y1 = y1,
	}
	for c: ColorRect in [_ground, _fin_add, _fin_mul]:
		c.position = _f.position.round()
		c.size = (_f.end.round() - _f.position.round())
	_room.queue_redraw()
	_life.queue_redraw()


## ONE AXIS OF THE FRAME'S WARP, as segments [u0, u1, d0, flip] in zoomed px
## (`u`), where u lands on screen at d0 + (u - u0) * q (flipped: d0 + (u1 - u)
## * q). Everything before the glass's far side of its first corner rides the
## glass's near edge, everything past the other corner its far edge, and the
## middle is stretched by repeating the run at `best` (turned over every other
## time) or cut there, by as much as the glass on screen has outgrown the
## camera's own zoom: nothing at the move's start, the mockup's frame at its end.
func _axis(lo: int, hi: int, full: int, flo: float, fhi: float, best: int, need_end: int) -> Array:
	var q := _q
	var segs: Array = []
	segs.append([0.0, float(lo + K), flo - lo * q, false])
	var m := hi - lo - 2 * K
	var need := (fhi - flo) / q - 2.0 * K - m
	var a0 := lo + K
	if need_end >= 0:
		need = clampf(need, 0.0, float(need_end))
		var split := a0 + best + RUN
		segs.append([float(a0), float(split), flo + (a0 - lo) * q, false])
		var at := flo + (split - lo) * q
		var left := need
		var i := 0
		var s0 := float(a0 + best)
		while left > 0.001:
			var ln := minf(RUN, left)
			if i % 2 == 0:
				segs.append([s0, s0 + ln, at, false])
			else:
				segs.append([s0 + RUN - ln, s0 + RUN, at, true])
			at += ln * q
			left -= ln
			i += 1
		segs.append([float(split), float(hi - K), fhi + (split - hi) * q, false])
	else:
		var cut := clampf(-need, 0.0, float(-need_end))
		var c0 := float(a0 + best + RUN / 2)
		segs.append([float(a0), c0, flo + (a0 - lo) * q, false])
		segs.append([c0 + cut, float(hi - K), fhi + (c0 + cut - hi) * q, false])
	segs.append([float(hi - K), float(full), fhi - K * q, false])
	return segs


## The room, through the warp: each piece of the painted lab a straight copy
## at the camera's scale, lit by the lab's own light.
func _draw_room() -> void:
	if _maps.is_empty() or lab == null or lab._pic.texture == null:
		return
	_room.material = lab._mat
	var tex := lab._pic.texture
	var z := float(_z)
	var top: Array = _maps.top
	var bot: Array = _maps.bottom
	var lft: Array = _maps.left
	var rgt: Array = _maps.right
	var ylo: Array = lft[0]
	var yhi: Array = lft[-1]
	# the bands above and below the glass, each with its own stretch along it
	for xs: Array in top:
		_piece(tex, xs, ylo, z)
	for xs2: Array in bot:
		_piece(tex, xs2, yhi, z)
	# the bands either side, each with its own stretch down it, and the glass
	var xlo: Array = top[0]
	var xhi: Array = top[-1]
	for i in range(1, lft.size() - 1):
		_piece(tex, xlo, lft[i], z)
		for j in range(1, top.size() - 1):
			_piece(tex, top[j], lft[i], z)
	for i2 in range(1, rgt.size() - 1):
		_piece(tex, xhi, rgt[i2], z)


func _piece(tex: Texture2D, xs: Array, ys: Array, z: float) -> void:
	var q := _q
	var ux0: float = xs[0]
	var ux1: float = xs[1]
	var uy0: float = ys[0]
	var uy1: float = ys[1]
	if ux1 <= ux0 or uy1 <= uy0:
		return
	var dx0 := roundf(float(xs[2]))
	var dx1 := roundf(float(xs[2]) + (ux1 - ux0) * q)
	var dy0 := roundf(float(ys[2]))
	var dy1 := roundf(float(ys[2]) + (uy1 - uy0) * q)
	if dx1 <= dx0 or dy1 <= dy0 or dx1 < 0.0 or dy1 < 0.0 or dx0 > W or dy0 > H:
		return
	var src := Rect2(ux0 / z, uy0 / z, (ux1 - ux0) / z, (uy1 - uy0) / z)
	var fx: bool = xs[3]
	var fy: bool = ys[3]
	if fx or fy:
		_room.draw_set_transform(Vector2(dx1 if fx else 0.0, dy1 if fy else 0.0), 0.0,
			Vector2(-1.0 if fx else 1.0, -1.0 if fy else 1.0))
		var lx := 0.0 if fx else dx0
		var ly := 0.0 if fy else dy0
		_room.draw_texture_rect_region(tex, Rect2(lx, ly, dx1 - dx0, dy1 - dy0), src)
		_room.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_room.draw_texture_rect_region(tex, Rect2(dx0, dy0, dx1 - dx0, dy1 - dy0), src)


## Where a point of the room (zoomed px) lands on screen through the warp.
func map_u(u: Vector2) -> Vector2:
	var x0: int = _maps.x0
	var x1: int = _maps.x1
	var y0: int = _maps.y0
	var y1: int = _maps.y1
	var xs: Array = _maps.top
	var ys: Array = _maps.left
	if u.y >= y1 - K:
		xs = _maps.bottom
	elif u.y >= y0 + K and u.x >= x1 - K:
		ys = _maps.right
	return Vector2(_seg_at(xs, u.x), _seg_at(ys, u.y))


func _seg_at(segs: Array, u: float) -> float:
	for s: Array in segs:
		if not bool(s[3]) and u >= float(s[0]) and u < float(s[1]):
			return float(s[2]) + (u - float(s[0])) * _q
	var last: Array = segs[-1]
	return float(last[2]) + (u - float(last[0])) * _q


## THE ROOM'S LIFE THROUGH THE WARP: the lab draws its bubbles, monitors and
## fizz here as it does in the room (`LabScene._draw_life`), each of its
## pixels carried to where the warp puts that part of the room.
class _Life extends Control:
	var zoom: LabZoom

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if zoom == null or zoom._maps.is_empty() or zoom.lab == null or zoom.lab.lab.is_empty():
			return
		zoom.lab._draw_life(self)

	## One of the room's life rects (picture px), where the warp has it. Not
	## where the capital's bench is being looked over: what moves on it goes
	## with it, pixel for pixel in the same dither (`lab_light.gdshader`).
	func life_rect(r: Rect2, c: Color) -> void:
		if zoom._mirror > 0.0 and zoom._mirror_box.has_point(r.position):
			var p := Vector2i(r.position)
			if (LabBoard.bayer(p.x, p.y) * 16.0 + 0.5) / 16.0 < zoom._mirror:
				return
		var z := float(zoom._z)
		var at := zoom.map_u(r.position * z)
		var s := zoom._q * z
		draw_rect(Rect2(at.round(), (r.size * s).round()), c)


# ------------------------------------------------------------------ the tests

## Every box on the page on show, as the mockup's box test has them: drawn
## words and rings, and the keys.
func leaves() -> Array:
	var out: Array = header_leaves()
	if tab == &"research":
		out.append_array(board.leaves)
	elif tab == &"recipes":
		for row: Dictionary in recipe_rows:
			for k in ["name", "held", "cost", "what"]:
				var l := row[k] as Label
				if l.visible and l.text != "":
					out.append([l.text.left(24), _ink_box(l)])
			var mk := row.make as LabPlate
			if mk.visible:
				out.append(["[MAKE %s]" % row.r.name, Rect2i(mk.position, mk.size)])
	return out


## A label's capitals and descenders, not its whole line box.
func _ink_box(l: Label) -> Rect2i:
	var sz := l.get_theme_font_size("font_size")
	var cap := 5 if sz <= 8 else 10
	var top := int(l.position.y) + (4 if sz <= 8 else 7)
	return Rect2i(int(l.position.x), top - 1, LabBoard.tw(l.text, sz), cap + 2)


## The box test on the page on show: empty when every box is inside the
## glass, no two overlap, and no word crosses an arm.
func check() -> PackedStringArray:
	if tab == &"research":
		return board.check(header_leaves())
	var bad := PackedStringArray()
	var all := leaves()
	for l: Array in all:
		if not Rect2i(GLASS).encloses(l[1]):
			bad.append("'%s' %s is outside the glass" % [l[0], l[1]])
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i][1] as Rect2i).intersects(all[j][1]):
				bad.append("'%s' overlaps '%s'" % [all[i][0], all[j][0]])
	return bad
