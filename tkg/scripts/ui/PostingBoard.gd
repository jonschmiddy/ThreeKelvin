class_name PostingBoard
extends Control

## The Hiring Hall: a bulletin board, and the whole deck is the board.
##
## IT WAS A BOARD IN A ROOM, and before that a board filling a panel with nothing
## on it but the work. Neither looked like the thing every station actually has,
## which is a bulletin board somebody has been pinning to for years: notices hung
## wherever there was room, a wanted poster, a clipping, a flyer with half its
## tabs torn off, and the holes of every pin that was ever pulled out. The WORK is
## what you came for; the rest is how the deck says people live here.
##
## EVERYTHING WITH WORDS ON IT HANGS SQUARE. The notices and the town's sheets
## were each turned a few degrees for one pass, and pixel text turned by even a
## degree breaks into stair-steps. The board is made of things to read, so the
## lived-in look comes from overlaps, shadows and pin holes instead.
##
## TWO KINDS OF PAPER, AND ONLY ONE OF THEM IS A BUTTON. The real contracts are the
## dark printed notices down the left -- `_offer_row` and `_deliver_row` build
## them as they always did, pinned in a straight column. Everything in the
## right-hand column is drawn here and is scenery: nothing in it can be signed, so
## none of it is printed the way the notices that can be are.
##
## AND THE MANUFACTURERS PIN THINGS UP TOO. Every manufacturer holding the station
## has a notice of its own on the board, in its own colours and in its own voice
## -- Korvan's misfire counter, Calyx asking you not to feed the hull. A board at a
## Korvan yard and a board at a Calyx one should not read the same, and a notice
## is the cheapest way there is to say who runs a place.
##
## Drawn rather than loaded, like the rest of the station's furniture.

## The notices pinned to this. Read every redraw, never cached -- the rows are
## rebuilt from scratch on every refresh of the deck.
var list: Control = null
## The layer the pins are drawn on, above the notices.
var _pins: Control = null
## The manufacturers whose own notices are pinned up here, in order. Set by the
## screen from who holds the station; see `StationScreen._board_posts`.
var posts: Array[StringName] = []

const CORK := Color("#241c14")
const GRAIN := Color("#2e2418")
const HOLE := Color("#15100b")
const FRAME := Color("#3a2c1c")
const FRAME_DARK := Color("#2a1f14")
const LIP := Color("#54402a")
const SHADE := Color("#070a10")
const PIN := Color("#d4614f")
const PIN_COOL := Color("#6f8fb0")

## THE TOWN'S PAPER. Every sheet is lighter than the cork, because it is furniture
## on a surface, and every sheet is a different shade from the next, because
## nothing on a real board came out of the same packet.
const PAPER := Color("#c2b48e")
const NEWSPRINT := Color("#a7a397")
const CARD := Color("#cdc1a0")
const INDEX := Color("#d6d0bd")
const INK := Color("#2a241a")
const INK_SOFT := Color("#5d5445")
const RED := Color("#9b3a2b")
const BLUE := Color("#3d5a86")
const EMBER := Color("#d97b29")

## How thick the board's wooden frame is.
const FRAME_W := 10.0
## How much of the board's width the real notices get, from the left. The rest of
## it is the town's column.
const NOTICE_SHARE := 0.62
## Where on a notice its pin goes through: the top-left corner, where somebody
## pinning it up with one hand would put it.
const PIN_AT := Vector2(14.0, 3.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func watch(l: Control) -> void:
	list = l
	var redraw := _redraw_all
	var box := l as Container
	if box != null and not box.sort_children.is_connected(redraw):
		box.sort_children.connect(redraw)
	if not l.resized.is_connected(redraw):
		l.resized.connect(redraw)


func _redraw_all() -> void:
	queue_redraw()
	if _pins != null and is_instance_valid(_pins):
		_pins.queue_redraw()


## The pins through the notices, as a layer for the page to add ABOVE them.
##
## A control draws under its children, and a pin goes THROUGH the paper -- so the
## notices' pins cannot be drawn by the board. This hands back a layer whose
## drawing the board does, the same pattern the Shipyard's old service rows used.
func make_pins() -> Control:
	var p := Control.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.draw.connect(_draw_pins.bind(p))
	_pins = p
	return p


## A repeatable scatter, so the holes land in the same place every redraw.
func _scatter(i: int, span: float) -> float:
	return fmod(float(i) * 2654435761.0 / 65536.0, maxf(1.0, span))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 60.0 or h <= 60.0:
		return

	# --- THE CORK: a pressed mat, so its texture has no beat.
	draw_rect(Rect2(0.0, 0.0, w, h), CORK)
	var gy := 4.0
	var step := 0
	while gy < h - 3.0:
		var gx := 6.0 + float((step * 37) % 23)
		while gx < w - 6.0:
			draw_rect(Rect2(gx, gy, 2.0 + float((step + int(gx)) % 3), 1.0), GRAIN)
			gx += 13.0 + float((step * 11 + int(gx)) % 11)
		gy += 4.0
		step += 1
	# THE HOLES OF EVERY PIN EVER PULLED OUT. The one detail that says this board
	# has been used for years rather than put up this morning.
	for i in 170:
		draw_rect(Rect2(floorf(8.0 + _scatter(i * 7 + 2, w - 16.0)),
			floorf(8.0 + _scatter(i * 13 + 9, h - 16.0)), 1.0, 1.0), HOLE)
	# And the pale ghosts of posters taken down, where the cork never saw light.
	for g in 3:
		draw_rect(Rect2(w * (0.08 + 0.21 * float(g)), h * (0.56 + 0.1 * float(g % 2)),
			70.0 + 12.0 * float(g), 44.0 + 8.0 * float(g)),
			Color(GRAIN.r, GRAIN.g, GRAIN.b, 0.55))

	# --- THE TOWN'S OWN PAPER, down the right.
	_town(Rect2(w * NOTICE_SHARE + 8.0, FRAME_W + 8.0,
		w * (1.0 - NOTICE_SHARE) - FRAME_W - 16.0, h - FRAME_W * 2.0 - 16.0))

	# --- THE SHADOWS THE REAL NOTICES CAST, down and right of each, which is what
	# makes a notice sit ON the cork rather than printed into it.
	if list != null and is_instance_valid(list):
		var off := list.position - position
		for child in list.get_children():
			var c := child as Control
			if c == null or not c.visible or c.size.x <= 0.0:
				continue
			var t := c.get_transform()
			var pts := PackedVector2Array()
			for corner: Vector2 in [Vector2.ZERO, Vector2(c.size.x, 0.0), c.size,
					Vector2(0.0, c.size.y)]:
				pts.append(off + t * corner + Vector2(3.0, 4.0))
			draw_colored_polygon(pts, Color(SHADE.r, SHADE.g, SHADE.b, 0.55))

	# --- AND THE FRAME, last, so anything pinned near an edge tucks under it.
	var e := FRAME_W
	for r: Rect2 in [Rect2(0.0, 0.0, w, e), Rect2(0.0, h - e, w, e),
			Rect2(0.0, 0.0, e, h), Rect2(w - e, 0.0, e, h)]:
		draw_rect(r, FRAME)
	# Grain along the rails.
	for i in 7:
		var gx2 := 16.0 + float(i) * (w - 40.0) / 7.0
		draw_rect(Rect2(gx2, 3.0 + float(i % 3) * 2.0, w / 11.0, 1.0), FRAME_DARK)
		draw_rect(Rect2(gx2 + 20.0, h - e + 3.0 + float((i + 1) % 3) * 2.0, w / 12.0, 1.0),
			FRAME_DARK)
	for i in 4:
		var gy2 := 20.0 + float(i) * (h - 40.0) / 4.0
		draw_rect(Rect2(3.0 + float(i % 2) * 3.0, gy2, 1.0, h / 8.0), FRAME_DARK)
		draw_rect(Rect2(w - e + 4.0 + float((i + 1) % 2) * 3.0, gy2 + 14.0, 1.0, h / 9.0),
			FRAME_DARK)
	# A lit outer edge, a shadow where the frame meets the cork, mitred corners.
	draw_rect(Rect2(0.0, 0.0, w, 1.0), LIP)
	draw_rect(Rect2(0.0, h - e, w, 1.0), LIP)
	draw_rect(Rect2(e, e, w - e * 2.0, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
	draw_rect(Rect2(e, e, 1.0, h - e * 2.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	for s in int(e):
		for corner: Vector2 in [Vector2(float(s), float(s)), Vector2(w - 1.0 - float(s), float(s)),
				Vector2(float(s), h - 1.0 - float(s)), Vector2(w - 1.0 - float(s), h - 1.0 - float(s))]:
			draw_rect(Rect2(corner.x, corner.y, 1.0, 1.0), FRAME_DARK)


func _draw_pins(p: Control) -> void:
	if list == null or not is_instance_valid(list):
		return
	var off := list.position - p.position
	var n := 0
	for child in list.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var at := off + c.position + PIN_AT
		var col := PIN_COOL if n % 3 == 2 else PIN
		p.draw_rect(Rect2(at.x - 1.0, at.y - 1.0, 6.0, 6.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.6))
		p.draw_rect(Rect2(at.x - 2.0, at.y - 3.0, 5.0, 5.0), col)
		p.draw_rect(Rect2(at.x - 2.0, at.y - 3.0, 2.0, 2.0), col.lightened(0.45))
		n += 1


# ------------------------------------------------------------- the town's paper


## The scenery column, laid out top to bottom. Anything that would run off the
## bottom of the board is simply not put up.
##
## SQUARE, EVERY SHEET WITH WORDS ON IT. They were each turned a few degrees, and
## the poster's name and the flyer's message broke into stair-steps -- unreadable,
## which is the whole reason to pin them up. Only the torn scrap keeps an angle,
## because it has nothing on it to read.
func _town(col: Rect2) -> void:
	var x := col.position.x
	var cw := col.size.x
	# FROM THE HEAD OF THE COLUMN. No banners on this board: a manufacturer's
	# colours hang in the rooms it holds, and a noticeboard is the town's own.
	var y := col.position.y + 6.0
	var poster := Vector2(minf(136.0, cw * 0.56), 170.0)
	if y + poster.y < col.end.y:
		_sheet(Vector2(x + 4.0, y), poster, 0.0, _wanted, 0.5)
	var news := Vector2(minf(122.0, cw * 0.5), 106.0)
	if y + 14.0 + news.y < col.end.y:
		_sheet(Vector2(col.end.x - news.x - 2.0, y + 14.0), news, 0.0, _news, 0.88)
	var flyer := Vector2(minf(110.0, cw * 0.46), 96.0)
	if y + 132.0 + flyer.y < col.end.y:
		_sheet(Vector2(col.end.x - flyer.x - 8.0, y + 132.0), flyer, 0.0, _flyer, 0.88)
	var card := Vector2(minf(100.0, cw * 0.42), 58.0)
	if y + 186.0 + card.y < col.end.y:
		_sheet(Vector2(x + 16.0, y + 186.0), card, 0.0, _card, 0.88)
	# --- WHAT THE STATION'S MANUFACTURERS HAVE PUT UP.
	#
	# Two places in the lower half of this column, and a third low in the work's
	# column, where a long run of contracts will pin over it -- which is exactly
	# what happens to old notices on a real board.
	var spots: Array[Rect2] = [
		Rect2(x + 6.0, col.position.y + 262.0, 118.0, 96.0),
		Rect2(col.end.x - 122.0, col.position.y + 300.0, 116.0, 96.0),
		Rect2(FRAME_W + 22.0, size.y - FRAME_W - 116.0, 124.0, 98.0),
	]
	var put := 0
	for mid in posts:
		if put >= spots.size():
			break
		var spot: Rect2 = spots[put]
		if spot.end.y > size.y - FRAME_W - 4.0 or not DB.manufacturers.has(mid):
			continue
		# The pin in the right-hand corner, clear of the emblem at the head.
		_sheet(spot.position, spot.size, 0.0, _post.bind(mid), 0.86)
		put += 1
	# The corner of a notice somebody tore down, still under its pin -- only when
	# the manufacturers have left it the room.
	var scrap := Vector2(x + cw * 0.5, col.end.y - 52.0)
	if put < 2 and scrap.y > y + 256.0:
		_sheet(scrap, Vector2(46.0, 30.0), 9.0, _scrap, 0.5)
	# And a pin with nothing on it.
	_pin(Vector2(x + 34.0, col.end.y - 22.0), PIN_COOL)


## One sheet, with its shadow and its pin -- turned about its corner only when
## `deg` is not zero, which is only ever the scrap with nothing written on it.
##
## THE PIN GOES WHERE THE WORDS ARE NOT. It sat dead centre on every sheet, and on
## a sheet whose title starts at its left edge the centre is the end of the title:
## the rota card read SHIFT ROT with a pin where the A was. `pin_x` is a fraction
## of the width -- the middle for a centred title, the right-hand corner for one
## that starts at the left.
func _sheet(at: Vector2, sz: Vector2, deg: float, paint: Callable, pin_x: float) -> void:
	draw_set_transform(at, deg_to_rad(deg), Vector2.ONE)
	draw_rect(Rect2(3.0, 4.0, sz.x, sz.y), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	paint.call(sz)
	_pin(Vector2(floorf(sz.x * pin_x), 4.0), PIN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pin(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 6.0, 6.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.6))
	draw_rect(Rect2(p.x - 2.0, p.y - 3.0, 5.0, 5.0), col)
	draw_rect(Rect2(p.x - 2.0, p.y - 3.0, 2.0, 2.0), col.lightened(0.45))


func _text(s: String, x: float, baseline: float, fs: int, col: Color) -> void:
	draw_string(UITheme.pixel_font(), Vector2(x, baseline), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _centre(s: String, baseline: float, width: float, fs: int, col: Color) -> void:
	var f := UITheme.pixel_font()
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(floorf((width - tw) * 0.5), baseline), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## WANTED: THE HELLBENDER. The rival harvester every run shares its galaxy with,
## drawn as the salamander of a hull the log describes, its holds glowing.
## Stamped CLAIMED once somebody has actually killed it, so the board keeps up
## with the run it is in.
func _wanted(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), PAPER)
	draw_rect(Rect2(Vector2.ZERO, sz), PAPER.darkened(0.3), false, 1.0)
	_centre("WANTED", 22.0, sz.x, UITheme.FS_HEAD, RED)
	draw_rect(Rect2(8.0, 27.0, sz.x - 16.0, 1.0), INK_SOFT)
	var box := Rect2(10.0, 32.0, sz.x - 20.0, 58.0)
	draw_rect(box, Color(INK.r, INK.g, INK.b, 0.16))
	draw_rect(box, INK_SOFT, false, 1.0)
	var cy := box.position.y + box.size.y * 0.55
	var bx := box.position.x + 12.0
	var bw := box.size.x - 30.0
	draw_rect(Rect2(bx, cy - 6.0, bw, 12.0), INK)
	for s in 5:
		draw_rect(Rect2(bx + bw + float(s) * 2.0, cy - 5.0 + float(s), 2.0,
			10.0 - float(s) * 2.0), INK)
	draw_rect(Rect2(bx + bw * 0.3, cy - 12.0, bw * 0.25, 6.0), INK)
	draw_rect(Rect2(bx - 6.0, cy - 3.0, 6.0, 6.0), INK)
	for d in 4:
		draw_rect(Rect2(bx + 8.0 + float(d) * bw * 0.2, cy - 1.0, 3.0, 2.0), EMBER)
	_centre("THE HELLBENDER", 102.0, sz.x, UITheme.FS_SMALL, INK)
	_centre("RIVAL HARVESTER", 113.0, sz.x, UITheme.FS_SMALL, INK_SOFT)
	_centre("FOR STOLEN HEAT", 124.0, sz.x, UITheme.FS_SMALL, INK_SOFT)
	draw_rect(Rect2(8.0, 131.0, sz.x - 16.0, 1.0), INK_SOFT)
	_centre("BOUNTY", 145.0, sz.x, UITheme.FS_SMALL, INK)
	_centre("2500 CR", 164.0, sz.x, UITheme.FS_HEAD, RED)
	if not Run.hellbender_alive():
		draw_rect(Rect2(14.0, 48.0, sz.x - 28.0, 24.0), RED, false, 2.0)
		_centre("CLAIMED", 66.0, sz.x, UITheme.FS_HEAD, RED)


## A clipping from the station's sheet, cut out along a ragged bottom edge.
func _news(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), NEWSPRINT)
	for i in int(sz.x / 4.0):
		draw_rect(Rect2(float(i) * 4.0, sz.y, 4.0, float((i * 3) % 3)), NEWSPRINT)
	_text("DOCK CRIER", 5.0, 11.0, UITheme.FS_SMALL, INK)
	draw_rect(Rect2(4.0, 14.0, sz.x - 8.0, 1.0), INK)
	draw_rect(Rect2(4.0, 16.0, sz.x - 8.0, 1.0), INK_SOFT)
	_text("LANE CLOSED", 5.0, 27.0, UITheme.FS_SMALL, INK)
	var photo := Rect2(sz.x - 44.0, 32.0, 38.0, 30.0)
	draw_rect(photo, Color(INK.r, INK.g, INK.b, 0.35))
	draw_rect(Rect2(photo.position.x + 12.0, photo.position.y + 12.0, 12.0, 5.0), INK)
	draw_rect(Rect2(photo.position.x + 22.0, photo.position.y + 10.0, 3.0, 3.0), EMBER)
	for row in 10:
		var yy := 34.0 + float(row) * 6.0
		if yy > sz.y - 4.0:
			break
		var right := sz.x - 50.0 if yy < 64.0 else sz.x - 6.0
		draw_rect(Rect2(5.0, yy, right - 5.0 - float((row * 13) % 17), 2.0),
			Color(INK.r, INK.g, INK.b, 0.5))


## A lost-and-found flyer with its number on tear-off tabs, a third of them gone.
func _flyer(sz: Vector2) -> void:
	var body := sz.y - 26.0
	draw_rect(Rect2(0.0, 0.0, sz.x, body), CARD)
	_text("LOST DRONE", 6.0, 14.0, UITheme.FS_SMALL, INK)
	_text("ANSWERS TO", 6.0, 28.0, UITheme.FS_SMALL, INK_SOFT)
	_text("BLIP", 6.0, 40.0, UITheme.FS_SMALL, BLUE)
	# A drawing of Blip, done by somebody who loved it.
	draw_rect(Rect2(sz.x - 34.0, 22.0, 20.0, 10.0), INK_SOFT)
	draw_rect(Rect2(sz.x - 30.0, 25.0, 4.0, 3.0), EMBER)
	draw_rect(Rect2(sz.x - 38.0, 26.0, 4.0, 2.0), INK_SOFT)
	draw_rect(Rect2(sz.x - 14.0, 26.0, 4.0, 2.0), INK_SOFT)
	var tabs := 8
	var tw := sz.x / float(tabs)
	for i in tabs:
		if i % 3 == 1:
			continue
		var tr := Rect2(float(i) * tw, body, tw - 1.0, 26.0)
		draw_rect(tr, CARD)
		for d in 4:
			draw_rect(Rect2(tr.position.x + tw * 0.5 - 1.0, tr.position.y + 4.0 + float(d) * 5.0,
				2.0, 3.0), Color(INK.r, INK.g, INK.b, 0.6))
	var dx := 0.0
	while dx < sz.x:
		draw_rect(Rect2(dx, body, 3.0, 1.0), INK_SOFT)
		dx += 5.0


## An index card with the shift rota on it, in blue biro.
func _card(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), INDEX)
	draw_rect(Rect2(0.0, 11.0, sz.x, 1.0), Color(RED.r, RED.g, RED.b, 0.7))
	var ly := 19.0
	while ly < sz.y - 2.0:
		draw_rect(Rect2(0.0, ly, sz.x, 1.0), Color(BLUE.r, BLUE.g, BLUE.b, 0.25))
		ly += 8.0
	_text("SHIFT ROTA", 4.0, 9.0, UITheme.FS_SMALL, INK)
	for r in 4:
		var yy := 15.0 + float(r) * 8.0
		if yy > sz.y - 4.0:
			break
		draw_rect(Rect2(5.0, yy, 30.0 + float((r * 11) % 25), 2.0),
			Color(BLUE.r, BLUE.g, BLUE.b, 0.7))


## The corner of a notice torn down, left behind under its pin.
func _scrap(sz: Vector2) -> void:
	var row := 0.0
	while row < sz.y:
		var wide := floorf(sz.x * (1.0 - row / sz.y))
		draw_rect(Rect2(0.0, row, wide, 1.0), PAPER.darkened(0.08))
		row += 1.0


## What each manufacturer pins up: its lines, then one word set large.
##
## IN EACH ONE'S OWN VOICE, lifted from who they already are rather than invented
## beside it. Korvan stamps parts for a war two centuries over, and they fire every
## time; Solari lost an argument about safety margins; Probate follows other
## people's disasters; Redline is never at the address on its invoices; Verity
## makes few and signs them; Cygnet's drones anticipate you and nobody discusses
## it; Calyx hulls are grown, with a clause about what not to feed them.
const POSTS := {
	&"korvan": [["DAYS WITHOUT", "A MISFIRE"], "71204"],
	&"solari": [["NOW HIRING", "FURNACE HANDS", "MUST ENJOY"], "HEAT"],
	&"probate": [["ESTATE SALE", "HULLS OF THE", "RECENTLY LATE"], "BIDS"],
	&"redline": [["FAST REFITS", "NO SERIALS", "NO RECORDS"], "CASH"],
	&"verity": [["BY APPOINTMENT", "COMMISSIONS", "CLOSED"], ""],
	&"cygnet": [["A REMINDER", "FROM THE SWARM", "YOU ARE NEVER"], "ALONE"],
	&"calyx": [["PLEASE DO NOT", "FEED THE HULL", "THANK YOU"], ""],
}


## One manufacturer's notice: its field for paper, its mark for ink, its emblem at
## the head, a band of its colour across the top, and its lines under that.
func _post(sz: Vector2, mid: StringName) -> void:
	var m: ManufacturerData = DB.manufacturers.get(mid)
	if m == null:
		return
	# INK THAT READS ON ITS OWN PAPER. Verity and Calyx print on pale stock and the
	# rest on dark, so the mark is pushed away from whichever the field is.
	var pale := m.field.get_luminance() > 0.5
	var ink := m.colour.darkened(0.3) if pale else m.colour.lightened(0.12)
	var soft := Color(ink.r, ink.g, ink.b, 0.8)
	draw_rect(Rect2(Vector2.ZERO, sz), m.field)
	draw_rect(Rect2(0.0, 0.0, sz.x, 3.0), m.colour)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(ink.r, ink.g, ink.b, 0.45), false, 1.0)
	CardView.draw_emblem(self, mid, Vector2(sz.x * 0.5, 14.0), 1.0, m.colour, m.field)
	var entry: Array = POSTS.get(mid, [[], ""])
	var lines: Array = entry[0]
	var big: String = entry[1]
	var baseline := 40.0
	for line in lines:
		_centre(String(line), baseline, sz.x, UITheme.FS_SMALL, soft)
		baseline += 11.0
	if big != "":
		_centre(big, sz.y - 8.0, sz.x, UITheme.FS_HEAD, ink)
	else:
		# A signature where the big word would go: somebody put their name to it.
		var sx := sz.x * 0.3
		var i := 0
		while sx < sz.x * 0.72:
			draw_rect(Rect2(sx, sz.y - 14.0 + float((i * 3) % 5) - 2.0, 4.0, 1.0), ink)
			sx += 3.0
			i += 1
