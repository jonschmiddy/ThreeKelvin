class_name StationSpine
extends Control

## A cutaway of floors of one structure shows where you stand; every floor is an interior.
## Why: docs/why/StationSpine.md#station-spine

## Which floors are showing, top to bottom -- outposts do not have every deck, so
## this is not always five. Ids from `StationScreen.DECKS`.
var floors: Array[StringName] = []
## Which of them you are standing on. -1 lights none.
var active: int = -1
## The car's float position lights floors as it passes, so it reads as moving, not teleporting.
## Why: docs/why/StationSpine.md#elevator-car
var car: float = -1.0
## Whoever holds the station, for the pigment shift. Same weight as the berth.
var manufacturer: StringName = &""
## A fixed inset for the far wall now, as the building no longer slides: the car does.
## Why: docs/why/StationSpine.md#parallax
var parallax: float = 0.0

const WALL := Color("#0d141d")
const PLATE := Color("#151e2a")
const EDGE := Color("#202d3d")
const DEEP := Color("#080c12")
const LAMP := UITheme.EMBER
## How thick the station's outer hull is, down both edges of every floor.
const HULL_W := 6.0
## The deck plate between one floor and the next.
const DECK_T := 3.0

## Floors are pictures (Jon, 2026-10-01): active in colour and animated, others muted, still.
## Why: docs/why/StationSpine.md#floor-pictures
const RAIL_DIR := "res://art/sprites/station/rail/"
## A picture's size; a floor shows the window of it that fits.
const PIC := Vector2(144.0, 128.0)
## deck -> {tex, muted, ms, seq, cols, top}. Read once, never inside `_draw`.
static var _rail: Dictionary = {}
static var _rail_read := false
## The frame each lit floor last drew, so it redraws only when one changes.
var _drawn := ""


static func _read_rail() -> void:
	if _rail_read:
		return
	_rail_read = true
	var path := RAIL_DIR + "rail.json"
	if not FileAccess.file_exists(path):
		return
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary:
		return
	for k: String in (doc as Dictionary).keys():
		var tex := load(RAIL_DIR + k + ".png") as Texture2D
		var muted := load(RAIL_DIR + k + "_muted.png") as Texture2D
		if tex == null or muted == null:
			continue
		var d: Dictionary = doc[k]
		_rail[StringName(k)] = {"tex": tex, "muted": muted, "ms": float(d["ms"]),
			"seq": d["seq"], "cols": int(d["cols"]), "top": float(d["top"])}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_rail()


## Redraw when a lit floor's picture has moved on a frame, and not otherwise.
func _process(_dt: float) -> void:
	var key := _frames_now()
	if key != _drawn:
		queue_redraw()


func _frames_now() -> String:
	if car < 0.0 or _rail.is_empty():
		return ""
	var t := GameClock.now_ms()
	var key := ""
	for i in floors.size():
		if absf(car - float(i)) < 1.0 and _rail.has(floors[i]):
			var art: Dictionary = _rail[floors[i]]
			key += "%d:%d:%.2f," % [i, int(float(t) / float(art["ms"])), car]
	return key


## One floor's picture in its room: the window of it that fits, its foot on the
## floor, muted, and the live frame over that as bright as the car makes it.
func _draw_picture(art: Dictionary, room: Rect2, glow: float) -> void:
	var sw := minf(room.size.x, PIC.x)
	var sh := minf(room.size.y, PIC.y)
	var top := clampf(float(art["top"]), 0.0, PIC.y - sh)
	var sx := floorf((PIC.x - sw) * 0.5)
	var dst := Rect2(roundf(room.position.x + (room.size.x - sw) * 0.5),
		roundf(room.end.y - sh), sw, sh)
	if room.size.y > sh:
		draw_rect(Rect2(room.position, Vector2(room.size.x, room.size.y - sh)), DEEP)
	draw_texture_rect_region(art["muted"], dst, Rect2(sx, top, sw, sh))
	if glow <= 0.0:
		return
	var seq: Array = art["seq"]
	var f := int(seq[int(float(GameClock.now_ms()) / float(art["ms"])) % seq.size()])
	var cols := int(art["cols"])
	draw_texture_rect_region(art["tex"], dst,
		Rect2(float(f % cols) * PIC.x + sx, float(f / cols) * PIC.y + top, sw, sh),
		Color(1.0, 1.0, 1.0, glow))


func _tint(c: Color) -> Color:
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	return c if m == null else c.lerp(m.colour, 0.12)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 8.0 or h <= 8.0 or floors.is_empty():
		return
	var wall := _tint(WALL)
	var plate := _tint(PLATE)
	var edge := _tint(EDGE)
	var fh := h / float(floors.size())

	_drawn = _frames_now()
	draw_rect(Rect2(0.0, 0.0, w, h), DEEP)
	for i in floors.size():
		var top := fh * float(i)
		# HOW LIT, NOT WHETHER. One when the car is on this floor, nothing when it
		# is a floor away, and the ramp between is the car passing.
		var glow: float = 0.0
		if car >= 0.0:
			glow = clampf(1.0 - absf(car - float(i)), 0.0, 1.0)
		var lit: bool = glow > 0.45
		var room := Rect2(HULL_W, top, w - HULL_W * 2.0, fh - DECK_T)
		if _rail.has(floors[i]):
			_draw_picture(_rail[floors[i]], room, glow)
			draw_rect(Rect2(0.0, top + fh - DECK_T, w, DECK_T), plate)
			draw_rect(Rect2(0.0, top + fh - DECK_T, w, 1.0), edge)
			continue

		# The room you are in is lit, not just brighter, so it reads as occupied, not selected.
		draw_rect(room, wall.lerp(LAMP, 0.10 * glow))
		# The back wall is inset and lags, as a further wall does.
		var back := Rect2(room.position.x + 7.0,
			room.position.y + 4.0 - parallax * 0.33,
			room.size.x - 14.0, room.size.y - 8.0)
		draw_rect(back, DEEP.lerp(wall, 0.45))
		var sy := back.position.y + 5.0
		while sy < back.end.y - 2.0:
			draw_rect(Rect2(back.position.x, sy, back.size.x, 1.0),
				wall.lerp(edge, 0.30))
			sy += 9.0
		if glow > 0.02:
			# Lamp spill is banded from the ceiling and scaled by `glow`, so light comes up.
			for step in 3:
				draw_rect(Rect2(room.position.x, room.position.y + 3.0 * float(step),
					room.size.x, 3.0),
					Color(LAMP.r, LAMP.g, LAMP.b,
						(0.09 - 0.025 * float(step)) * glow))
		# Furniture is drawn brighter than its room: eight levels of difference was unreadable.
		# Why: docs/why/StationSpine.md#furniture-contrast
		var furn := plate.lerp(EDGE, 1.4).lerp(LAMP, 0.16 * glow)
		var line := EDGE.lerp(Color("#5c718c"), 0.55).lerp(LAMP, 0.20 * glow)
		_furnish(floors[i], room, furn, line, lit)

		# The deck plate under it. Drawn last so nothing in the room sits on top
		# of the floor it is standing on.
		draw_rect(Rect2(0.0, top + fh - DECK_T, w, DECK_T), plate)
		draw_rect(Rect2(0.0, top + fh - DECK_T, w, 1.0), edge)

	# The car is a frame, not a fill, so the room shows; a brighter left post marks selection.
	# Why: docs/why/StationSpine.md#elevator-car
	if car >= 0.0:
		var cy := fh * car
		var cr := Rect2(0.0, cy, w, fh - DECK_T)
		draw_rect(Rect2(cr.position.x, cr.position.y, cr.size.x, 2.0), LAMP)
		draw_rect(Rect2(cr.position.x, cr.end.y - 2.0, cr.size.x, 2.0), LAMP)
		draw_rect(Rect2(cr.position.x, cr.position.y, 3.0, cr.size.y), LAMP)
		draw_rect(Rect2(cr.end.x - 2.0, cr.position.y, 2.0, cr.size.y),
			Color(LAMP.r, LAMP.g, LAMP.b, 0.55))

	# The near side is in banded shade so deck names read; steps, as the renderer has no gradient.
	# Why: docs/why/StationSpine.md#label-shadow
	for band in 5:
		var bw := 78.0 - 13.0 * float(band)
		draw_rect(Rect2(HULL_W, 0.0, bw, h),
			Color(DEEP.r, DEEP.g, DEEP.b, 0.30))

	# --- THE OUTER HULL, down both sides and over everything. It is what makes
	# five rooms one station rather than five pictures in a column.
	draw_rect(Rect2(0.0, 0.0, HULL_W, h), plate)
	draw_rect(Rect2(w - HULL_W, 0.0, HULL_W, h), plate)
	draw_rect(Rect2(HULL_W - 1.0, 0.0, 1.0, h), edge)
	draw_rect(Rect2(w - HULL_W, 0.0, 1.0, h), edge)
	# Ribs, so the hull has a scale and is not two grey bars.
	var y := 8.0
	while y < h:
		draw_rect(Rect2(0.0, y, HULL_W, 1.0), edge)
		draw_rect(Rect2(w - HULL_W, y, HULL_W, 1.0), edge)
		y += 19.0


## What is IN each room. One clause per deck, and each is the smallest set of
## shapes that could only be that place.
func _furnish(id: StringName, r: Rect2, plate: Color, edge: Color,
		lit: bool) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	var floor_y := y + h
	var warm := LAMP if lit else LAMP.lerp(WALL, 0.55)

	match id:
		&"stock":
			# THE PROMENADE: stalls under awnings, and goods hung off them. The
			# awning is the shape that says market at eight pixels.
			for i in 3:
				var sx := x + w * (0.14 + 0.26 * float(i))
				draw_rect(Rect2(sx, y + h * 0.34, w * 0.19, 3.0), plate)
				draw_rect(Rect2(sx, y + h * 0.34, w * 0.19, 1.0), edge)
				draw_rect(Rect2(sx + 2.0, floor_y - h * 0.30, 3.0, h * 0.30), plate)
				draw_rect(Rect2(sx + w * 0.14, floor_y - h * 0.22, 3.0, h * 0.22), plate)
			draw_rect(Rect2(x + w * 0.20, y + h * 0.42, 2.0, 5.0), warm)
			draw_rect(Rect2(x + w * 0.72, y + h * 0.42, 2.0, 5.0), warm)
		&"services":
			# THE YARD: a gantry, and the only hull in the building.
			draw_rect(Rect2(x + w * 0.08, y + h * 0.26, w * 0.84, 3.0), plate)
			draw_rect(Rect2(x + w * 0.08, y + h * 0.26, w * 0.84, 1.0), edge)
			draw_rect(Rect2(x + w * 0.22, y + h * 0.29, 3.0, h * 0.16), plate)
			var hull := Rect2(x + w * 0.20, floor_y - h * 0.40, w * 0.58, h * 0.24)
			draw_rect(hull, plate.lerp(edge, 0.55))
			draw_rect(hull, edge, false, 1.0)
			draw_rect(Rect2(hull.position.x + hull.size.x * 0.46, hull.position.y,
				3.0, hull.size.y), warm)
			# The cradle under it, two posts and a rail.
			draw_rect(Rect2(x + w * 0.18, floor_y - 5.0, w * 0.62, 3.0), plate)
			for a in [0.24, 0.66]:
				draw_rect(Rect2(x + w * a, floor_y - h * 0.16, 3.0, h * 0.16), plate)
		&"hold":
			# THE EXCHANGE: stacked crates, uneven, because a hold that is packed
			# neatly is a hold nobody uses.
			var stack := [[0.16, 0.30, 0.20], [0.40, 0.20, 0.34],
				[0.58, 0.26, 0.16], [0.76, 0.16, 0.26]]
			for c in stack:
				var cw := w * float(c[1])
				var ch := h * float(c[2])
				var cx := x + w * float(c[0])
				draw_rect(Rect2(cx, floor_y - ch - 2.0, cw, ch), plate)
				draw_rect(Rect2(cx, floor_y - ch - 2.0, cw, ch), edge, false, 1.0)
				draw_rect(Rect2(cx + 2.0, floor_y - ch, cw - 4.0, 1.0), edge)
		&"work":
			# THE HIRING HALL: a lit board with postings on it, and a bench.
			var board := Rect2(x + w * 0.16, y + h * 0.24, w * 0.44, h * 0.40)
			draw_rect(board, plate)
			draw_rect(board, edge, false, 1.0)
			for i in 3:
				draw_rect(Rect2(board.position.x + 4.0,
					board.position.y + 5.0 + 6.0 * float(i),
					board.size.x * (0.72 - 0.16 * float(i)), 2.0), warm)
			draw_rect(Rect2(x + w * 0.66, floor_y - h * 0.20, w * 0.20, 3.0), plate)
			draw_rect(Rect2(x + w * 0.68, floor_y - h * 0.18, 2.0, h * 0.18), plate)
			draw_rect(Rect2(x + w * 0.82, floor_y - h * 0.18, 2.0, h * 0.18), plate)
		&"bench":
			# THE LABORATORY: culture tanks, and exactly one of them alive. The
			# single warm tank is the whole reason this floor is not the Exchange.
			for i in 3:
				var tw := w * 0.13
				var th := h * (0.44 - 0.06 * float(i))
				var tx := x + w * (0.18 + 0.24 * float(i))
				var tank := Rect2(tx, floor_y - th - 3.0, tw, th)
				draw_rect(tank, plate)
				draw_rect(tank, edge, false, 1.0)
				if i == 1:
					draw_rect(Rect2(tank.position.x + 2.0, tank.position.y + 3.0,
						tank.size.x - 4.0, tank.size.y - 6.0),
						Color(warm.r, warm.g, warm.b, 0.55 if lit else 0.28))
			draw_rect(Rect2(x + w * 0.16, y + h * 0.22, w * 0.62, 2.0), plate)
