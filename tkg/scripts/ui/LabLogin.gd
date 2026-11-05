class_name LabLogin
extends Control

## THE LAB'S SCREEN AT REST: the owner's sign-on (Jon, Nov 5: "you start the
## lab fully zoomed out, the screen turns on like normal, has a corpo logo or
## something, and you hover over the screen, it changes to a login type look
## or something, and if you click on the screen the view zooms onto the
## screen").
##
## THREE LOOKS, drawn in code on the screen's window (`LabScene.win_rect`), in
## the lab's own phosphor (labs.json `screen.tint`):
##
##   LOGO     the station owner's mark (`CardView.draw_emblem`, the same mark
##            its cards and hulls wear) on its banner ground, its name, and
##            RESEARCH TERMINAL under it; your DATA small in the corner
##   LOGIN    pointing at the glass: a sign-in panel, PILOT with your ship's
##            name, a password field filling with dots, a blinking cursor
##   SIGNING  the glass pressed: the password whole, SIGNING IN, while the
##            camera goes into the glass (`LabZoom`)
##
## Drawn into a SubViewport the size of the window (`StationScreen`), so the
## room shows it at 1:1 and the camera carries the very same pixels in.
## The glass is the only key: nothing on here is drawn as a button.

const LOGO := &"logo"
const LOGIN := &"login"
const SIGNING := &"signing"
## The password's length, and how fast it types in (dots a second).
const DOTS := 8
const DOT_RATE := 10.0
## The cursor's blink: on, then off, for this long each.
const BLINK_S := 0.4
## CLICK TO SIGN IN breathes between these inks over `PULSE_S` (brightness
## only, nothing moves): the review found it the weakest thing on the sign-in,
## at the field labels' 0.55.
const PULSE_LO := 0.8
const PULSE_S := 1.6
## THE SWAP between the logo and the sign-in is a refresh: one bright line runs
## down the glass over this long (5 frames), as the new look comes up.
const WIPE_S := 0.083

var state: StringName = LOGO
## The station's owner (a manufacturer id, &"" for none) and the lab's tint.
var owner_id: StringName = &""
var tint := Color(0.75, 0.94, 0.92)
var pilot := ""
var data := 0
## WHERE THE LOOKS ARE LAID OUT, in this window's own px: the part of it the
## camera still has on screen once it has landed (`LabZoom.landed_view`). The
## sign-in's header ran across the whole window, and at four labs the landed
## glass is wider or taller than the screen: "EPENDENT", "RVAN", no DATA. Empty
## is the whole window.
var safe := Rect2i()
## The look before this one (a swap between the logo and the sign-in wipes).
var _wipe := false
## How long this look has been up (game time, its own frames' deltas).
var _t := 0.0
var _sig := ""
## Every word and mark drawn, [name, Rect2i], for the box test.
var leaves: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Set the look. A new look starts its own clock (the dots type in afresh).
func set_state(s: StringName) -> void:
	if s == state:
		return
	_wipe = (s == LOGIN and state == LOGO) or (s == LOGO and state == LOGIN)
	state = s
	_t = 0.0
	queue_redraw()


## The window's area the looks are laid out in.
func area() -> Rect2i:
	var all := Rect2i(Vector2i.ZERO, Vector2i(size))
	return all if not safe.has_area() else all.intersection(safe)


## Where the refresh line is now, or -1.
func wipe_y() -> int:
	if not _wipe or _t >= WIPE_S:
		return -1
	var a := area()
	return a.position.y + int(floorf(_t / WIPE_S * float(a.size.y)))


## CLICK TO SIGN IN's ink now, in 1/40 steps.
func cue_ink() -> float:
	var k := 0.5 - 0.5 * cos(_t * TAU / PULSE_S)
	return snappedf(PULSE_LO + (1.0 - PULSE_LO) * k, 0.025)


## How many dots the password shows now.
func dots() -> int:
	if state == SIGNING:
		return DOTS
	if state == LOGIN:
		return mini(DOTS, int(floorf(_t * DOT_RATE)))
	return 0


func cursor_on() -> bool:
	return state == LOGIN and int(floorf(_t / BLINK_S)) % 2 == 0


func _process(delta: float) -> void:
	_t += delta
	var s := "%s|%d|%s|%s|%s|%d|%s|%s|%s|%d|%.3f" % [state, dots(), cursor_on(), owner_id, pilot, data, tint, size,
		safe, wipe_y(), cue_ink() if state == LOGIN else 0.0]
	if s != _sig:
		_sig = s
		queue_redraw()


func _draw() -> void:
	leaves.clear()
	match state:
		LOGO:
			_paint_logo()
		_:
			_paint_login()
	var y := wipe_y()
	if y >= 0:
		var a := area()
		draw_rect(Rect2(a.position.x, y, a.size.x, 1), _ink(0.7))
		if y > a.position.y:
			draw_rect(Rect2(a.position.x, y - 1, a.size.x, 1), _ink(0.3))


# ------------------------------------------------------------------ the looks

func _ink(a: float) -> Color:
	return LabBoard.mixc(LabBoard.BG, tint, a)


## The owner's name in full, and in one word.
func owner_name() -> String:
	if owner_id == &"" or not DB.manufacturers.has(owner_id):
		return "INDEPENDENT"
	return DB.manufacturer_name(owner_id).to_upper()


func owner_short() -> String:
	if owner_id == &"" or not DB.manufacturers.has(owner_id):
		return "INDEPENDENT"
	return DB.short_name(DB.manufacturer_name(owner_id)).to_upper()


## The mark on its ground: a plate `n` px square, the mark at scale `s` on its
## true centre (`CardView.draw_emblem` measures in halves: an odd plate for a
## mark at 1, an even one at 2, or the mark falls between pixels).
func _mark(cx: int, cy: int, n: int, s: float) -> void:
	var mk := DB.manufacturer_colour(owner_id)
	var fd: Color = (DB.manufacturers[owner_id] as ManufacturerData).field if DB.manufacturers.has(owner_id) else LabBoard.BG
	var h := n / 2
	var r := Rect2i(cx - h, cy - h, n, n)
	draw_rect(Rect2(r.position - Vector2i.ONE, r.size + Vector2i(2, 2)), _ink(0.35))
	draw_rect(Rect2(r), fd)
	if owner_id == &"" or not DB.manufacturers.has(owner_id):
		mk = tint
	CardView.draw_emblem(self, owner_id, Vector2(r.position) + Vector2(n, n) / 2.0, s, mk, fd)
	leaves.append(["mark", Rect2i(r.position - Vector2i.ONE, r.size + Vector2i(2, 2))])


func _text(x: int, ycap: int, s: String, c: Color, sz: int = 8) -> void:
	LabBoard.text_at(self, x, ycap, s, c, sz)
	leaves.append([s, Rect2i(x, ycap - 1, LabBoard.tw(s, sz), (5 if sz == 8 else 10) + 2)])


func _data_corner() -> void:
	var a := area()
	var s := "DATA %d" % data
	_text(a.end.x - 6 - LabBoard.tw(s), a.position.y + 5, s, LabBoard.OWN)


## LOGO: the mark, the owner, RESEARCH TERMINAL; the block centred.
func _paint_logo() -> void:
	_data_corner()
	var a := area()
	var x0 := a.position.x
	var w := a.size.x
	var h := a.size.y
	var name := owner_short()
	var line := "RESEARCH TERMINAL"
	var block := 28 + 8 + 10 + 7 + 5
	var y0 := a.position.y + (h - block) / 2 + 3
	_mark(x0 + w / 2, y0 + 14, 28, 2.0)
	var ny := y0 + 28 + 8
	_text(x0 + (w - LabBoard.tw(name, 16)) / 2, ny, name, _ink(1.0), 16)
	_text(x0 + (w - LabBoard.tw(line)) / 2, ny + 17, line, _ink(0.6))


## LOGIN and SIGNING: the owner small on top, then PILOT and PASSWORD in
## their fields, and what to do (or what is happening) under them.
func _paint_login() -> void:
	var a := area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	_mark(x0 + 11, y0 + 10, 11, 1.0)
	_text(x0 + 21, y0 + 8, owner_short(), _ink(0.85))
	_data_corner()
	draw_rect(Rect2(x0 + 4, y0 + 20, w - 8, 1), _ink(0.25))
	var fw := mini(170, w - 40)
	var fx := x0 + (w - fw) / 2
	var block := 7 + 13 + 7 + 7 + 13 + 9 + 5
	var y := y0 + 21 + maxi(6, (h - 21 - block) / 2)
	# PILOT, your ship's name in its field
	_text(fx, y, "PILOT", _ink(0.55))
	y += 7
	_field(fx, y, fw)
	var who := pilot.to_upper() if pilot != "" else "PILOT"
	while who.length() > 1 and LabBoard.tw(who) > fw - 8:
		who = who.left(who.length() - 1)
	_text(fx + 4, y + 4, who, _ink(1.0))
	y += 13 + 7
	# PASSWORD, its dots typing in
	_text(fx, y, "PASSWORD", _ink(0.55))
	y += 7
	_field(fx, y, fw)
	var n := dots()
	for i in n:
		draw_rect(Rect2(fx + 4 + i * 5, y + 5, 3, 3), _ink(1.0))
	if n > 0:
		leaves.append(["dots", Rect2i(fx + 4, y + 5, n * 5 - 2, 3)])
	if cursor_on():
		draw_rect(Rect2(fx + 4 + n * 5, y + 3, 1, 7), _ink(1.0))
	y += 13 + 9
	var say := "SIGNING IN" if state == SIGNING else "CLICK TO SIGN IN"
	_text(x0 + (w - LabBoard.tw(say)) / 2, y, say, _ink(0.85) if state == SIGNING else _ink(cue_ink()))


func _field(x: int, y: int, fw: int) -> void:
	draw_rect(Rect2(x, y, fw, 13), _ink(0.08))
	var e := _ink(0.4)
	for r: Rect2 in [Rect2(x, y, fw, 1), Rect2(x, y + 12, fw, 1), Rect2(x, y, 1, 13), Rect2(x + fw - 1, y, 1, 13)]:
		draw_rect(r, e)
	leaves.append(["field", Rect2i(x, y, fw, 13)])


## The box test on this look: every word and mark inside the window, and
## inside the part of it the landed camera keeps (`safe`), none on another
## (the fields hold their own words, so those are let be).
func check() -> PackedStringArray:
	var bad := PackedStringArray()
	var all := area()
	for l: Array in leaves:
		if not all.encloses(l[1]):
			bad.append("'%s' %s is outside the screen %s" % [l[0], l[1], all])
	for i in leaves.size():
		for j in range(i + 1, leaves.size()):
			var a: Rect2i = leaves[i][1]
			var b: Rect2i = leaves[j][1]
			# (a field holds its own words and dots)
			if (leaves[i][0] == "field" and a.encloses(b)) or (leaves[j][0] == "field" and b.encloses(a)):
				continue
			if a.intersects(b):
				bad.append("'%s' overlaps '%s'" % [leaves[i][0], leaves[j][0]])
	return bad
