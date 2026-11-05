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
## ONE CAMERA MOVE, NOT A CUT, between ZoomLadder's two beats: the station's
## chrome goes, the HUD, the deck rail and the deck's plate (`UI_OUT_S`, the
## camera still), the camera moves (`LAB_ZOOM_S`, smootherstep), and the Lab's
## pages come up on the landed glass over the sign-in it carried in
## (`UI_IN_S`). Back out it all runs backwards, the chrome back only once the
## camera is at rest. A click or a key during a move finishes it at once and is
## eaten (Esc on the way in turns it round); Tab takes the camera out at once
## and goes on to the ladder.
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
## bottom), and the outpost's, the city's and the capital's go past the window
## on every side, so their glass is the whole window. The board is laid out as
## it always was: the chart's ground runs on to the lab's glass edge, wherever
## that is (`lab_chart.gdshader`'s `rpos`).
##
## THE ROOM'S EDGE: as the chrome goes, the picture's own rectangle falls away
## into the window's dark (`_veil`), so no edge of it is ever bare on the dark
## while the camera carries it out of the window.

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
const VEIL := preload("res://shaders/lab_veil.gdshader")
## THE ROOM'S EDGE, LET GO: how far in from the picture's edge (picture px) the
## room falls away into the dark as the chrome goes (`_veil`). Its lights stay
## lit where the edge does not cut them (`_veil_lights`): the capital's top
## tube, 14 px in, went dull under it while its pool stayed bright.
const FEATHER := 48.0

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
var recipes: Control
var tab_buttons := {}
var leave_button: LabPlate
## One per recipe: {r, make, y} built once, and what it says now ({on, can,
## name, held, cost, what}), read on each refresh.
var recipe_rows: Array = []

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
var _veil: ColorRect
## The lab the veil's emitters were read for (`_veil_lights`).
var _veil_level := ""


func _init() -> void:
	top_level = true
	position = Vector2.ZERO
	size = Vector2(W, H)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# (after the lab has lit its room this frame)
	process_priority = 10
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
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.size = Vector2(W, H)
	_veil.material = ShaderMaterial.new()
	(_veil.material as ShaderMaterial).shader = VEIL
	(_veil.material as ShaderMaterial).set_shader_parameter(&"field", RenderingServer.get_default_clear_color())
	add_child(_veil)
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
## reads a relic out as a part. In the AUGMENT page's hand: a ring with the
## recipe's icon (lit when you can make it), its name, the bill with the
## mockup's drawn arrow, and MAKE where AUGMENT stands. The rows are drawn;
## only MAKE is a node, built once and restyled (`refresh`).
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
		var make := LabPlate.new("MAKE", &"commit")
		make.size = Vector2(150, 19)
		make.position = Vector2(W - T - 14 - make.size.x, y - 2)
		make.pressed.connect(_make.bind(r))
		recipes.add_child(make)
		recipe_rows.append({r = r, make = make, y = y, on = false, can = false,
			name = str(r.name).to_upper(), held = "", cost = "", what = str(r.text).to_upper()})


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
	augment.refresh()
	var n: MapGen.MapNode = Run.node_at()
	for row: Dictionary in recipe_rows:
		var r: Dictionary = row.r
		var on := n != null and Fabricator.available(n).has(r)
		row.on = on
		(row.make as LabPlate).visible = on
		if not on:
			continue
		var can := Fabricator.can_make(n, r)
		row.can = can
		var bits: PackedStringArray = []
		for id in (r.mats as Dictionary).keys():
			var held := Run.material(id)
			var word := str(MaterialTable.by_id(id).get("name", id)).to_upper()
			bits.append("%d %s%s" % [held, word, "" if held == 1 or word.ends_with("S") else "S"])
		row.held = "YOU HAVE " + ", ".join(bits)
		row.cost = Fabricator.cost_line(n, r).to_upper()
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
	elif tab == &"augment":
		augment.light = true
		augment.paint(ci)
		augment.paint_live(ci)
		augment.light = false
	elif tab == &"recipes":
		_paint_recipes(ci, true)


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
	_recipe_leaves.clear()
	_paint_recipes(recipes, false)
	_light_dirty = true


## Every box on RECIPES, as the box test has them.
var _recipe_leaves: Array = []
const NR_RECIPE := 20


## The rows, as they look or (`light`) only what glows: the ring of a recipe
## you can make, its name, and MAKE's word.
func _paint_recipes(ci: CanvasItem, light: bool) -> void:
	var ink := LabBoard.mixc(LabBoard.BG, _tint, 0.22)
	var first := true
	for row: Dictionary in recipe_rows:
		if not row.on:
			continue
		var y: int = row.y
		if not first and not light:
			ci.draw_rect(Rect2(GLASS.position.x + 10, y - 18, GLASS.size.x - 20, 1), ink)
		first = false
		var can: bool = row.can
		var cy := y + 12
		var icon: String = row.name
		if can:
			if not light:
				_disc(ci, 60, cy, NR_RECIPE, LabBoard.mixc(LabBoard.BG, LabBoard.NEXT, 0.2))
			_ring(ci, 60, cy, NR_RECIPE, LabBoard.NEXT)
			_icon(ci, icon, 60, cy, LabBoard.HOT)
		elif not light:
			_disc(ci, 60, cy, NR_RECIPE, LabBoard.mixc(LabBoard.BG, LabBoard.NEXT, 0.07))
			_ring(ci, 60, cy, NR_RECIPE, LabBoard.mixc(LabBoard.NEXT, LabBoard.BG, 0.6))
			_icon(ci, icon, 60, cy, LabBoard.mixc(LabBoard.HOT, LabBoard.BG, 0.5))
		_rleaf(light, "ring " + icon, Rect2i(60 - NR_RECIPE - 4, cy - NR_RECIPE - 4, 2 * NR_RECIPE + 9, 2 * NR_RECIPE + 9))
		var tx := 96
		var nw := LabBoard.tw(row.name, 16)
		if can or not light:
			LabBoard.text_at(ci, tx, y, row.name, LabBoard.HOT if can else LabBoard.mixc(LabBoard.HOT, LabBoard.BG, 0.3), 16)
		_rleaf(light, row.name, Rect2i(tx, y - 1, nw, 12))
		if not light:
			LabBoard.text_at(ci, tx + nw + 10, y + 4, row.held, UITheme.CHILL)
			LabBoard.text_at(ci, tx, y + 18, row.cost, UITheme.ICE if can else LabBoard.LATER_T)
			LabBoard.text_at(ci, tx, y + 30, row.what, UITheme.CHILL)
		_rleaf(light, row.held, Rect2i(tx + nw + 10, y + 3, LabBoard.tw(row.held), 7))
		_rleaf(light, row.cost, Rect2i(tx, y + 17, LabBoard.tw(row.cost), 7))
		_rleaf(light, str(row.what).left(24), Rect2i(tx, y + 29, LabBoard.tw(row.what), 7))
		var mk := row.make as LabPlate
		_rleaf(light, "[MAKE %s]" % row.name, Rect2i(mk.position, mk.size))
		if light and not mk.disabled:
			var r := Rect2i(mk.position, mk.size)
			LabBoard.text_at(ci, r.position.x + floori((r.size.x - LabBoard.tw(mk.label)) / 2.0),
				r.position.y + floori((r.size.y - 5) / 2.0), mk.label, LabPlate.HOT)


func _rleaf(light: bool, name: String, r: Rect2i) -> void:
	if not light:
		_recipe_leaves.append([name, r])


func _ring(ci: CanvasItem, cx: int, cy: int, r: int, c: Color) -> void:
	for p in LabBoard.ring_pts(r):
		ci.draw_rect(Rect2(cx + int(p.x), cy + int(p.y), 1, 1), c)


func _disc(ci: CanvasItem, cx: int, cy: int, r: int, c: Color) -> void:
	var lim := (r - 0.5) * (r - 0.5) + 0.25
	for dy in range(-r, r + 1):
		var half := -1
		for dx in range(0, r + 1):
			if dx * dx + dy * dy < lim:
				half = dx
		if half >= 0:
			ci.draw_rect(Rect2(cx - half, cy + dy, half * 2 + 1, 1), c)


func _icon(ci: CanvasItem, name: String, cx: int, cy: int, c: Color) -> void:
	var rows: Array = LabIcons.ICONS.get(name, [])
	var n := rows.size()
	var c2 := LabBoard.mixc(c, LabBoard.BG, 0.5)
	for j in n:
		var row: String = rows[j]
		for i in row.length():
			if row[i] == "#":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), c)
			elif row[i] == "+":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), c2)



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
	_veil_lights()
	# nothing new starts on the room's screen from the press on: the bad
	# signal's snow line crossed the sign-on at half strength
	lab.hush_screen(true)
	augment.tint = _tint
	augment.done = {}
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


## Back out to the room, the screen on its logo.
func close() -> void:
	if _goal <= 0.0:
		return
	_goal = 0.0
	_note = ""
	leaving.emit()
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
	# NEXT SCREEN (Tab) WITH THE CAMERA IN THE GLASS: out to the room at once,
	# the station's chrome back, and the key left for Main, so the ladder's
	# move off the station starts from the room it knows (it played under the
	# Lab's picture, and the map arrived as a cut).
	if key != null and key.pressed and not key.echo and key.is_action_pressed(&"next_screen"):
		_goal = 0.0
		_at = 0.0
		leaving.emit()
		_apply()
		return
	var moving := _at != _goal
	if moving and ((key != null and key.pressed) or (mb != null and mb.pressed)):
		# A PRESS DURING A MOVE ENDS IT, AND IS EATEN: a click that hurried the
		# move out went on to the room (onto the glass, it opened the Lab
		# again), and the second click of a double-click on the glass landed on
		# whatever page key was under it. Esc on the way in turns the camera
		# round (not on to the pause menu over a Lab that just landed).
		get_viewport().set_input_as_handled()
		if key != null and key.keycode == KEY_ESCAPE and _goal > 0.0:
			close()
		else:
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
	var ui_k := clampf(_at / out_s, 0.0, 1.0)
	# WHAT THE BIG SCREEN DOES GOES WITH THE CHROME (its snow and slips over the
	# sign-on); the sign-on itself stays, and the camera carries it in
	for c0: CanvasItem in on_glass:
		if c0 != null and is_instance_valid(c0):
			c0.modulate.a = 1.0 - ui_k
	# THE STATION'S CHROME LEAVES before the camera moves, and comes back only
	# once it is back at rest: the HUD and the deck rail stood still at 1x
	# while the room grew over them, cut mid-word by its edge
	_chrome(ui_k)
	var u := clampf((_at - out_s) / move_s, 0.0, 1.0)
	if hold_at >= 0.0:
		u = hold_at
	var e := ZoomLadder._ease_cam(u)
	var moving := _at > out_s or hold_at >= 0.0
	var landed_now := e >= 1.0
	var vk := clampf((_at - out_s - move_s) / in_s, 0.0, 1.0) if hold_at < 0.0 else 0.0
	# THE ROOM, through the camera, from the moment it moves. Once the pages
	# are up over a glass that covers the window, nothing of the room shows:
	# it is not drawn for nothing under the board. Where the bezel shows round
	# the glass (the settlement, the den) it stays, lit and live; the sign-on
	# under the board's ground goes once the ground is whole.
	var covered := Rect2(0, 0, W, H).intersection(glass_on_screen).is_equal_approx(Rect2(0, 0, W, H))
	var room_on := moving and not (landed_now and vk >= 1.0 and covered)
	for c: CanvasItem in [_room, _life]:
		c.visible = room_on
	_screen.visible = moving and not (landed_now and vk >= 1.0)
	# THE ROOM'S EDGE LETS GO WITH THE CHROME (Jon: "the square is kinda weird
	# and harsh"): the picture's own rectangle falls away into the dark round
	# it as the HUD and rail go, ahead of them (all gone by the beat's middle,
	# while the deck's plate still frames the room), so no edge of it is ever
	# bare on the dark, nor there for the camera to carry out of the window
	var shown := _at > 0.0 or hold_at >= 0.0
	_veil.visible = shown and not landed_now
	(_veil.material as ShaderMaterial).set_shader_parameter(&"amount",
		1.0 if moving else smoothstep(0.0, 1.0, minf(1.0, ui_k * 2.0)))
	# THE PAGES COME UP ON THE LANDED GLASS, its ground with them, over the
	# sign-in the camera carried in (and go, back out, before it moves)
	view.visible = vk > 0.0
	view.modulate.a = vk
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c2: ColorRect in [_ground, _fin_add, _fin_mul]:
		c2.visible = vk > 0.0
		(c2.material as ShaderMaterial).set_shader_parameter(&"amount", vk)
	mouse_filter = Control.MOUSE_FILTER_STOP if _at > 0.0 or _goal > 0.0 else Control.MOUSE_FILTER_IGNORE
	if shown and lab != null and is_instance_valid(lab) and not lab.lab.is_empty():
		_place(e if moving else 0.0)
	if _at <= 0.0 and _goal <= 0.0:
		visible = false
		if lab != null and is_instance_valid(lab):
			lab.hush_screen(false)
		for c3: CanvasItem in on_glass:
			if c3 != null and is_instance_valid(c3):
				c3.modulate.a = 1.0
		_chrome(0.0)
		closed.emit()
	elif _at >= _goal and _goal > 0.0 and vk >= 1.0:
		opened.emit()


## The station's HUD, deck rail and deck plate, k of the way gone
## (`StationScreen.lab_chrome`); at 0 they are as they were.
func _chrome(k: float) -> void:
	if station != null and is_instance_valid(station) and station.has_method(&"lab_chrome"):
		station.call(&"lab_chrome", k)


## Whatever takes the station away (a screen change, a run's end) takes the
## Lab with it: the HUD it hid comes back.
func _exit_tree() -> void:
	_chrome(0.0)
	if lab != null and is_instance_valid(lab):
		lab.hush_screen(false)


## THE ROOM'S LIGHTS ARE NOT VEILED: which of the lab's emitters the veil leaves
## lit (`lab_veil.gdshader`), each one the picture's edge does not cut, read
## off the picture's outer 2 px once per lab.
func _veil_lights() -> void:
	if _level == _veil_level or lab._own.is_empty():
		return
	_veil_level = _level
	var w := int(LabScene.PANEL.x)
	var h := int(LabScene.PANEL.y)
	var keep := PackedFloat32Array()
	keep.resize(8)
	keep.fill(1.0)
	for y in h:
		var xs: Array = range(w) if y < 2 or y >= h - 2 else [0, 1, w - 2, w - 1]
		for x: int in xs:
			var o := int(lab._own[(y * w + x) * 4]) - 1
			if o >= 0 and o < 8:
				keep[o] = 0.0
	var vm := _veil.material as ShaderMaterial
	vm.set_shader_parameter(&"own_map", lab._mat.get_shader_parameter(&"own_map"))
	vm.set_shader_parameter(&"panel", LabScene.PANEL)
	vm.set_shader_parameter(&"own_keep", keep)


## WHERE THE CAMERA LANDS: the lab's glass at `_z`, centred in the window (each
## lab's glass is an even number of picture px across and down, so this is on
## whole px), and the board's ground, finish and chart laid on it.
func _land_at() -> void:
	var g := lab.glass_rect()
	_o1 = (Vector2(W, H) / 2.0 - (g.position + g.size / 2.0) * float(_z)).round()
	glass_on_screen = Rect2(_o1 + g.position * float(_z), g.size * float(_z))
	for c: ColorRect in [_ground, _fin_add, _fin_mul]:
		c.position = glass_on_screen.position
		c.size = glass_on_screen.size
	var gm := _ground.material as ShaderMaterial
	gm.set_shader_parameter(&"rpos", glass_on_screen.position)
	gm.set_shader_parameter(&"rsize", glass_on_screen.size)
	for f: ColorRect in [_fin_add, _fin_mul]:
		(f.material as ShaderMaterial).set_shader_parameter(&"gsize", glass_on_screen.size)
	# (the glare on the glass where the window's top-left corner sees it, as on
	# the board's own glass)
	(_fin_add.material as ShaderMaterial).set_shader_parameter(&"glare_at",
		Vector2(maxf(0.0, -glass_on_screen.position.x), maxf(0.0, -glass_on_screen.position.y)))


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
	var vm := _veil.material as ShaderMaterial
	var ws := LabScene.PANEL * _s
	vm.set_shader_parameter(&"room", Vector4(_o.x, _o.y, _o.x + ws.x, _o.y + ws.y))
	vm.set_shader_parameter(&"feather", FEATHER * _s)
	vm.set_shader_parameter(&"size", Vector2(W, H))
	_room.queue_redraw()
	_life.queue_redraw()
	_screen.queue_redraw()


## Where the room's picture is on screen now.
func room_rect() -> Rect2:
	return Rect2(_o, LabScene.PANEL * _s)


## The camera's scale now (screen px per picture px).
func cam_scale() -> float:
	return _s


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
		out.append_array(_recipe_leaves)
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
	var all := leaves()
	for l: Array in all:
		if not Rect2i(GLASS).encloses(l[1]):
			bad.append("'%s' %s is outside the glass" % [l[0], l[1]])
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i][1] as Rect2i).intersects(all[j][1]):
				bad.append("'%s' overlaps '%s'" % [all[i][0], all[j][0]])
	return bad
