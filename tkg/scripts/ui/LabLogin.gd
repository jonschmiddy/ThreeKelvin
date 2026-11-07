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
## MOCK (review_lab r3 splash): which splash idea draws, from `splash=A|B|C` on
## the command line; empty is the shipped look.
static var style := "?"
## The lab, for its power-on clock (the splash runs off it).
var lab: LabScene = null


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
	if splash() in SAVERS:
		saver().step(delta, splash())
	if splash() != "":
		queue_redraw()
		return
	var s := "%s|%d|%s|%s|%s|%d|%s|%s|%s|%d|%.3f" % [state, dots(), cursor_on(), owner_id, pilot, data, tint, size,
		safe, wipe_y(), cue_ink() if state == LOGIN else 0.0]
	if s != _sig:
		_sig = s
		queue_redraw()


func _draw() -> void:
	leaves.clear()
	if splash() in SAVERS:
		saver().paint(splash())
		return
	if splash() != "":
		match splash():
			"A":
				_paint_a()
			"B0":
				_paint_b()
			"C":
				_paint_c()
		return
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
			if (leaves[i][0] in ["field", "card", "plate", "bar"] and a.encloses(b)) or (leaves[j][0] in ["field", "card", "plate", "bar"] and b.encloses(a)):
				continue
			if a.intersects(b):
				bad.append("'%s' overlaps '%s'" % [leaves[i][0], leaves[j][0]])
	return bad



# =================================================== MOCK: three splash ideas
# (review_lab r3, Nov 5: Jon, "I don't really like the splash screen. It needs
# to be better." Three ideas, drawn in code; not for feat/science.)

## MOCK (review_lab r5 savers): the screensavers `LabSavers` draws.
const SAVERS := ["B", "1", "2", "3", "4", "5", "6", "K1", "K2", "K3", "SOL1", "SOL2", "SOL3", "P1", "P2", "P3", "R1", "R2", "R3"]
var _saver: LabSavers = null


func saver() -> LabSavers:
	if _saver == null:
		_saver = LabSavers.new(self)
	return _saver


func _exit_tree() -> void:
	if _saver != null:
		_saver.release()


static func splash() -> String:
	if style == "?":
		style = ""
		for a in OS.get_cmdline_user_args():
			var s := a as String
			if s.begins_with("splash="):
				style = s.substr(7).to_upper()
	return style


## Seconds since the lab's power-on scan finished (negative while it runs).
func since_on() -> float:
	if lab == null or lab.lab.is_empty():
		return 100.0
	var rv: Array = (lab.lab.get("boot", {}) as Dictionary).get("reveal", [2.3, 2.9])
	return lab._lab_clock - lab._boot_at - float(rv[1])


func _ship() -> String:
	return pilot.to_upper() if pilot != "" else "PILOT"


## Text cut to fit `wmax` px.
func _fit(s: String, wmax: int, sz: int = 8) -> String:
	while s.length() > 1 and LabBoard.tw(s, sz) > wmax:
		s = s.left(s.length() - 1)
	return s


func _px(x: int, y: int, c: Color) -> void:
	draw_rect(Rect2(x, y, 1, 1), c)


func _frame_box(r: Rect2i, c: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), c)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c)
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), c)
	draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c)


## Four corner brackets, `arm` px each way, on `r`.
func _brackets(r: Rect2i, arm: int, c: Color) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 1
	var y1 := r.end.y - 1
	for p: Array in [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]:
		var x: int = p[0]
		var y: int = p[1]
		var sx: int = p[2]
		var sy: int = p[3]
		draw_rect(Rect2(mini(x, x + sx * (arm - 1)), y, arm, 1), c)
		draw_rect(Rect2(x, mini(y, y + sy * (arm - 1)), 1, arm), c)


## The owner's mark on its plate, only its top `rows` px drawn in (the rest the
## bare plate), a bright line on the row being drawn.
func _mark_rows(cx: int, cy: int, n: int, s: float, rows: int) -> void:
	_mark(cx, cy, n, s)
	if rows >= n:
		return
	var fd: Color = (DB.manufacturers[owner_id] as ManufacturerData).field if DB.manufacturers.has(owner_id) else LabBoard.BG
	var h := n / 2
	var top := cy - h
	draw_rect(Rect2(cx - h, top + rows, n, n - rows), fd)
	if rows >= 0:
		draw_rect(Rect2(cx - h - 2, top + rows, n + 4, 1), _ink(1.0))


# ------------------------------------------------------------------ A: boot

const A_MARK_S := 0.8
const A_LOAD := [0.9, 2.3]
const A_LOG := ["MOUNT DATA STORE", "LOAD OWNER KEY", "CHECK COOLANT", "LINK CHART CACHE",
	"WAKE SCAN RIG", "READ RESEARCH BOARD", "SYNC CLOCK", "TEST PHOSPHOR"]
const A_IDLE := ["UPLINK IDLE", "WAITING FOR PILOT", "COOLANT OK", "BOARD ON FILE"]


func _a_version() -> String:
	var h := absi(hash(String(owner_id)))
	return "RT-OS %d.%02d" % [2 + h % 6, (h / 7) % 60]


func _paint_a() -> void:
	if state == LOGO:
		_a_rest()
	else:
		_a_scan()


func _a_rest() -> void:
	var a := area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := since_on()
	var big := h >= 140
	var s := 4.0 if big else 3.0
	var n := 44 if big else 33
	# the header: the system's version, the DATA, a rule
	_text(x0 + 6, y0 + 5, _a_version(), _ink(0.5))
	_data_corner()
	draw_rect(Rect2(x0 + 4, y0 + 14, w - 8, 1), _ink(0.2))
	var name := owner_short()
	var nsz := 16 if LabBoard.tw(name, 16) <= w - n - 30 else 8
	var line := "RESEARCH TERMINAL"
	var tw := maxi(LabBoard.tw(name, nsz), LabBoard.tw(line))
	var bw := n + 10 + tw
	var lines := 4 if big else 3
	var pitch := 8
	var block := n + 8 + 7 + 4 + 5 + 7 + lines * pitch
	var by := y0 + 15 + maxi(4, (h - 15 - block) / 2)
	var bx := x0 + (w - bw) / 2
	# THE MARK DRAWS ITSELF, top to bottom
	var rows := int(floorf(clampf(t / A_MARK_S, 0.0, 1.0) * float(n))) if t >= 0.0 else -1
	if t >= 0.0:
		_mark_rows(bx + n / 2, by + n / 2, n, s, rows)
	# the name and the line come up as the mark finishes
	var cap := 10 if nsz == 16 else 5
	var ty := by + (n - cap - 6 - 5) / 2
	if t >= A_MARK_S * 0.7:
		var k := clampf((t - A_MARK_S * 0.7) / 0.35, 0.0, 1.0)
		_text(bx + n + 10, ty, name.left(ceili(k * name.length())), _ink(1.0), nsz)
	if t >= A_MARK_S:
		_text(bx + n + 10, ty + cap + 6, line, _ink(0.6))
	# THE LOADING BAR, in whole segments
	var y := by + n + 8
	var lk := clampf((t - float(A_LOAD[0])) / (float(A_LOAD[1]) - float(A_LOAD[0])), 0.0, 1.0)
	if t >= 0.0:
		_frame_box(Rect2i(bx, y, bw, 7), _ink(0.4))
		leaves.append(["bar", Rect2i(bx, y, bw, 7)])
		var segs := (bw - 4) / 4
		for i in int(floorf(lk * float(segs))):
			draw_rect(Rect2(bx + 2 + i * 4, y + 2, 3, 3), _ink(0.9))
	y += 7 + 4
	if t >= 0.0:
		if lk < 1.0:
			_text(bx, y, "LOADING %d%%" % int(lk * 100.0), _ink(0.6))
		else:
			_text(bx, y, "READY", _ink(0.85))
	y += 5 + 7
	# THE SYSTEM'S LOG scrolling under it: fast while it loads, then slow
	var shown := 0
	if t >= 0.2:
		shown = mini(A_LOG.size(), 1 + int((t - 0.2) / 0.2))
		if t > float(A_LOAD[1]):
			shown = A_LOG.size() + int((t - float(A_LOAD[1])) / 2.5)
	var first := maxi(0, shown - lines)
	for i in range(first, shown):
		var msg: String = A_LOG[i] if i < A_LOG.size() else A_IDLE[(i - A_LOG.size()) % A_IDLE.size()]
		var row := i - first
		var newest := i == shown - 1
		_text(bx, y + row * pitch, _fit("OK  " + msg, bw), _ink(0.6 if newest else 0.32))


func _a_scan() -> void:
	var a := area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := 10.0 if state == SIGNING else _t
	var big := h >= 140
	_mark(x0 + 11, y0 + 10, 11, 1.0)
	_text(x0 + 21, y0 + 8, owner_short(), _ink(0.85))
	_data_corner()
	draw_rect(Rect2(x0 + 4, y0 + 20, w - 8, 1), _ink(0.25))
	# THE ID CARD, centred
	var cw := mini(230 if big else 150, w - 40)
	var ch := 66 if big else 46
	var avail := h - 21
	var cy := y0 + 21 + maxi(8, (avail - ch - 13 - (10 if big else 5)) / 2)
	var cx := x0 + (w - cw) / 2
	var card := Rect2i(cx, cy, cw, ch)
	draw_rect(Rect2(card), _ink(0.1))
	_frame_box(card, _ink(0.5))
	for p: Vector2i in [card.position, Vector2i(card.end.x - 1, cy), Vector2i(cx, card.end.y - 1), card.end - Vector2i.ONE]:
		_px(p.x, p.y, LabBoard.BG)
	leaves.append(["card", card])
	# the photo: head and shoulders
	var ph := ch - 14
	var pw := ph * 4 / 5
	var pr := Rect2i(cx + 6, cy + 7, pw, ph)
	draw_rect(Rect2(pr), _ink(0.2))
	_frame_box(pr, _ink(0.45))
	var hx := pr.position.x + pw / 2
	var hr := maxi(3, pw / 5)
	var hy := pr.position.y + 4 + hr
	for dy in range(-hr, hr + 1):
		for dx in range(-hr, hr + 1):
			if dx * dx + dy * dy <= hr * hr:
				_px(hx + dx, hy + dy, _ink(0.6))
	var sw := pw - 6
	draw_rect(Rect2(hx - sw / 2, hy + hr + 2, sw, pr.end.y - 1 - (hy + hr + 2)), _ink(0.6))
	# PILOT, the ship, a barcode
	var tx := pr.end.x + 6
	var tmax := card.end.x - 6 - tx
	_text(tx, cy + 7, "PILOT", _ink(0.55))
	var nsz := 16 if big else 8
	_text(tx, cy + 15, _fit(_ship(), tmax, nsz), _ink(1.0), nsz)
	var bar_y := cy + (31 if big else 25)
	var bh := ch - (bar_y - cy) - 7
	var seed := absi(hash(pilot))
	var bxp := tx
	var i := 0
	while bxp < card.end.x - 7:
		var bwid := 1 + ((seed >> (i % 24)) & 1)
		draw_rect(Rect2(bxp, bar_y, bwid, bh), _ink(0.6))
		bxp += bwid + 1 + ((seed >> ((i + 5) % 24)) & 1)
		i += 1
	leaves.append(["barcode", Rect2i(tx, bar_y, bxp - tx, bh)])
	if t >= 1.0:
		var ok := "ID OK"
		_text(card.end.x - 6 - LabBoard.tw(ok), cy + 7, ok, LabBoard.OWN)
	# THE RETICLE closes on the card, then the scan runs down it
	var g := 3 + int(floorf(7.0 * (1.0 - clampf(t / 0.3, 0.0, 1.0))))
	g = mini(g, mini(cx - x0 - 1, cy - (y0 + 22)))
	_brackets(card.grow(g), 6, _ink(1.0 if t >= 1.0 else 0.8))
	if t >= 0.3 and t < 1.0:
		var sy := cy + int((t - 0.3) / 0.7 * float(ch))
		for k in 3:
			var yy := sy - k
			if yy >= cy and yy < card.end.y:
				draw_rect(Rect2(cx - 2 if k == 0 else cx, yy, cw + 4 if k == 0 else cw, 1), _ink([1.0, 0.5, 0.25][k]))
	# what to do
	var say := "SCANNING ID" + ".".repeat(int(t / 0.2) % 4) if t < 1.0 else "CLICK TO SIGN IN"
	var c := _ink(0.6) if t < 1.0 else _ink(cue_ink())
	if state == SIGNING:
		say = "ACCESS GRANTED"
		c = _ink(0.9)
	var ssz := 16 if big and t >= 1.0 else 8
	var sx := x0 + (w - LabBoard.tw("SCANNING ID...")) / 2 if t < 1.0 else x0 + (w - LabBoard.tw(say, ssz)) / 2
	_text(sx, card.end.y + 3 + 10, say, c, ssz)


# ------------------------------------------------------------------ B: screensaver

const B_TURN_S := 45.0


func _paint_b() -> void:
	var a := area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := since_on()
	# the chart's own room: under the DATA, over the owner's corner
	var cr := Rect2i(x0 + 2, y0 + 13, w - 4, h - 13 - 18)
	var hov := 0.0
	if state == LOGIN:
		hov = clampf(_t / 0.45, 0.0, 1.0)
		hov = 1.0 - pow(1.0 - hov, 3.0)
	elif state == SIGNING:
		hov = 1.0
	var z := 1.0 + 0.18 * hov
	if state == SIGNING:
		z += 0.25 * (1.0 - pow(1.0 - clampf(_t / 0.6, 0.0, 1.0), 3.0))
	var fade := clampf((t + 0.6) / 0.9, 0.0, 1.0)
	var dim := fade * (1.0 - 0.45 * hov)
	# the plate the sign-in stands on (the chart keeps off it)
	var plate := Rect2i()
	var line1 := "PILOT " + _ship()
	var line2 := "SIGNING IN" if state == SIGNING else "CLICK TO SIGN IN"
	if state != LOGO:
		line1 = _fit(line1, cr.size.x - 24)
		var pw := maxi(LabBoard.tw(line1), LabBoard.tw("CLICK TO SIGN IN")) + 16
		var open := clampf(_t / 0.15, 0.0, 1.0) if state == LOGIN else 1.0
		pw = maxi(4, int(float(pw) * open)) & ~1
		var ph := 26
		# under the core, so the flight computer stays in sight as the chart closes in
		var c := cr.get_center()
		var kz := minf(float(cr.size.x) / 834.0, float(cr.size.y) / 350.0) * z
		var top := mini(int(c.y) + roundi(float(LabBoard.HR) * kz) + 6, cr.end.y - ph - 2)
		plate = Rect2i(int(c.x) - pw / 2, top, pw, ph)
	_b_chart(cr, t, z, dim, plate)
	# the owner, small, in the corner
	var oy := y0 + h - 9
	_mark(x0 + 9, oy, 11, 1.0)
	_text(x0 + 19, oy - 6, owner_short(), _ink(0.85))
	_text(x0 + 19, oy + 1, "RESEARCH TERMINAL", _ink(0.55))
	_data_corner()
	if plate.has_area():
		draw_rect(Rect2(plate), LabBoard.BG)
		_frame_box(plate, _ink(0.45))
		_brackets(plate.grow(2), 4, _ink(0.9))
		leaves.append(["plate", plate.grow(2)])
		if plate.size.x >= LabBoard.tw("CLICK TO SIGN IN") + 8:
			var cx := plate.position.x + plate.size.x / 2
			LabBoard.text_at(self, cx - LabBoard.tw(line1) / 2, plate.position.y + 6, line1, _ink(1.0))
			var c2 := _ink(0.85) if state == SIGNING else _ink(cue_ink())
			LabBoard.text_at(self, cx - LabBoard.tw(line2) / 2, plate.position.y + 15, line2, c2)


## THE DEALT BOARD, small and turning: the board's own disc (`LabBoard`'s arms,
## steps and tilt) at `k` of its size, its steps in their run's colours.
func _b_chart(cr: Rect2i, t: float, z: float, dim: float, keep_off: Rect2i) -> void:
	if dim <= 0.0:
		return
	_b_cr = cr
	_b_off = keep_off.grow(3) if keep_off.has_area() else Rect2i()
	var k := minf(float(cr.size.x) / 834.0, float(cr.size.y) / 350.0) * z
	var c := Vector2(cr.get_center())
	var rot := t * TAU / B_TURN_S
	# the stars of the disc
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var rho := 30.0 + pow(rng.randf(), 0.7) * 380.0
		var phi := rng.randf() * TAU
		var lv := (0.18 + 0.35 * rng.randf())
		var p := _b_proj(c, k, rot, rho, phi)
		if _b_ok(p):
			_px(p.x, p.y, _ink(lv * _b_depth(rot, phi) * dim))
	# THE CORE'S GLOW, dithered: the galaxy's bulge round the flight computer
	var gr := float(LabBoard.HR) * k * 2.2
	var gi := ceili(gr)
	var cc0 := Vector2i(c.round())
	for dy in range(-gi, gi + 1):
		for dx in range(-gi * 2, gi * 2 + 1):
			var d := sqrt(pow(float(dx) / 1.9, 2.0) + float(dy * dy)) / gr
			if d >= 1.0:
				continue
			var p := cc0 + Vector2i(dx, dy)
			if _b_ok(p) and LabBoard.bayer(p.x, p.y) < pow(1.0 - d, 1.6) * 0.75:
				_px(p.x, p.y, _ink(0.22 * dim))
	# the arms, dotted
	var owned := [0, 0, 0]
	for b in 3:
		owned[b] = clampi(Run.board_owned[b] if b < Run.board_owned.size() else 0, 0, 3)
	var step := 2.0 / k
	for b in 3:
		var rho := float(LabBoard.HR) + 6.0
		while rho < float(LabBoard.RHO[2]):
			var phi := float(LabBoard.PHI0[b]) + LabBoard.WIND * rho
			var p := _b_proj(c, k, rot, rho, phi)
			var lit: bool = owned[b] > 0 and rho <= float(LabBoard.RHO[owned[b] - 1])
			if _b_ok(p):
				var col := LabBoard.OWN if lit else tint
				_px(p.x, p.y, LabBoard.mixc(LabBoard.BG, col, (0.7 if lit else 0.38) * dim * _b_depth(rot, phi)))
			rho += step
	# the steps
	var r := maxi(3, roundi(float(LabBoard.NR) * k))
	for b in 3:
		for kk in 3:
			var rho := float(LabBoard.RHO[kk])
			var phi := float(LabBoard.PHI0[b]) + LabBoard.WIND * rho
			var p := _b_proj(c, k, rot, rho, phi)
			var st := &"later"
			if kk < owned[b]:
				st = &"owned"
			elif kk == owned[b]:
				st = &"next" if Run.data >= int(DB.BOARD_PRICES[kk]) else &"short"
			var col: Color = LabBoard.LATER_T
			match st:
				&"owned":
					col = LabBoard.OWN
				&"next":
					col = LabBoard.NEXT
				&"short":
					col = LabBoard.EMBER
			var al := dim * _b_depth(rot, phi)
			_b_ring(p, r, LabBoard.mixc(LabBoard.BG, col, al))
			if st == &"owned":
				_b_disc(p, r - 2, LabBoard.mixc(LabBoard.BG, col, al * 0.7))
			elif st != &"later":
				_b_disc(p, 1, LabBoard.mixc(LabBoard.BG, col, al))
	# the flight computer on the core
	var cc := Vector2i(c.round())
	_b_disc(cc, maxi(2, roundi(float(LabBoard.HR) * k * 0.45)), _ink(0.35 * dim))
	_b_ring(cc, maxi(4, roundi(float(LabBoard.HR) * k)), _ink(0.9 * dim))


var _b_cr := Rect2i()
var _b_off := Rect2i()


func _b_proj(c: Vector2, k: float, rot: float, rho: float, phi: float) -> Vector2i:
	var v := c + Vector2(rho * cos(phi + rot) * LabBoard.SX, -rho * sin(phi + rot) * LabBoard.SY) * k
	return Vector2i(v.round())


## The far side of the tipped disc a little dimmer.
func _b_depth(rot: float, phi: float) -> float:
	return 0.88 - 0.15 * sin(phi + rot)


func _b_ok(p: Vector2i) -> bool:
	return _b_cr.has_point(p) and not (_b_off.has_area() and _b_off.has_point(p))


func _b_ring(p: Vector2i, r: int, col: Color) -> void:
	for dy in range(-r - 1, r + 2):
		for dx in range(-r - 1, r + 2):
			var d := sqrt(float(dx * dx + dy * dy))
			if d >= r - 0.5 and d < r + 0.5 and _b_ok(p + Vector2i(dx, dy)):
				_px(p.x + dx, p.y + dy, col)


func _b_disc(p: Vector2i, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r and _b_ok(p + Vector2i(dx, dy)):
				_px(p.x + dx, p.y + dy, col)


# ------------------------------------------------------------------ C: terminal

const C_CPS := 45.0
const C_LOGIN_CPS := 18.0


func _paint_c() -> void:
	var a := area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := since_on()
	var big := h >= 140
	var bsz := 16 if w >= 300 and h >= 120 else 8
	var bcap := 10 if bsz == 16 else 5
	var cwid := 6 if bsz == 16 else 4
	var pitch := 16 if bsz == 16 else 8
	var x := x0 + 6
	var y := y0 + (6 if big else 4)
	var rule := "=".repeat(maxi(1, (w - 12) / maxi(1, LabBoard.tw("="))))
	var name := owner_name()
	var nsz := 16
	if LabBoard.tw(name, 16) > w - 32:
		name = owner_short()
	if LabBoard.tw(name, 16) > w - 32:
		nsz = 8
	# what the screen types, in order: [kind, text]
	var rows: Array = [["rule", rule], ["banner", name], ["rule", rule],
		["line", "> DATA %d ON FILE" % data], ["line", "> RESEARCH TERMINAL READY"]]
	var budget := int(floorf(maxf(0.0, t) * C_CPS)) if t >= 0.0 else -1
	var cur := Vector2i(x, y)
	var done := true
	for r: Array in rows:
		var kind: String = r[0]
		var s: String = r[1]
		var hgt := pitch
		if kind == "banner":
			hgt = (10 if nsz == 16 else 5) + (6 if big else 4)
		elif kind == "rule":
			hgt = 8 if bsz == 16 else pitch
		var cost := 6 if kind == "rule" else s.length()
		if budget < 0:
			done = false
			break
		var part := s
		if kind == "rule":
			part = s.left(int(float(s.length()) * clampf(float(budget) / 6.0, 0.0, 1.0)))
		else:
			part = s.left(mini(s.length(), budget))
		var ink := _ink(0.5) if kind == "rule" else (_ink(1.0) if kind == "banner" else _ink(0.8))
		if kind == "banner":
			_mark(x + 5, y + (10 if nsz == 16 else 5) / 2, 11, 1.0)
			if part != "":
				_text(x + 16, y, part, ink, nsz)
			cur = Vector2i(x + 16 + LabBoard.tw(part, nsz) + 2, y)
		elif part != "":
			var sz := 8 if kind == "rule" else bsz
			_text(x, y, part, ink, sz)
			cur = Vector2i(x + LabBoard.tw(part, sz) + 2, y)
		budget -= cost
		if budget < 0:
			done = false
			break
		y += hgt
	var blink := int(floorf(_t / 0.5)) % 2 == 0
	if not done:
		# typing: the cursor rides the text
		draw_rect(Rect2(cur.x, cur.y, cwid, bcap), _ink(1.0))
	elif state == LOGO:
		_text(x, y, ">", _ink(0.8), bsz)
		if int(floorf(t / 0.5)) % 2 == 0:
			draw_rect(Rect2(x + LabBoard.tw("> ", bsz), y, cwid, bcap), _ink(1.0))
	else:
		# POINTED AT: it types your login, then asks for the press
		var cmd := "> login " + _ship().to_lower()
		var tt := 100.0 if state == SIGNING else _t
		var nshow := mini(cmd.length(), 2 + int(floorf(tt * C_LOGIN_CPS)))
		var part := _fit(cmd.left(nshow), w - 16, bsz)
		_text(x, y, part, _ink(0.8), bsz)
		var typed := nshow >= cmd.length()
		if not typed:
			draw_rect(Rect2(x + LabBoard.tw(part, bsz) + 2, y, cwid, bcap), _ink(1.0))
		y += pitch + 2
		if state == SIGNING:
			_text(x, y, "> CONNECTING" + ".".repeat(int(_t / 0.15) % 4), _ink(0.9), bsz)
		elif typed and _t >= float(cmd.length() - 2) / C_LOGIN_CPS + 0.15:
			var say := "PRESS TO CONNECT"
			var pad := 6 if bsz == 16 else 4
			var bw := LabBoard.tw(say, bsz) + pad * 2
			var bh := bcap + (6 if bsz == 16 else 4)
			draw_rect(Rect2(x, y - bh / 2 + bcap / 2, bw, bh), _ink(cue_ink()))
			LabBoard.text_at(self, x + pad, y, say, LabBoard.BG, bsz)
			leaves.append([say, Rect2i(x, y - bh / 2 + bcap / 2, bw, bh)])
			if blink:
				draw_rect(Rect2(x + bw + 3, y, cwid, bcap), _ink(1.0))
	# THE TUBE: every other line a shade darker
	var yy := y0 + 1
	while yy < y0 + h:
		draw_rect(Rect2(x0, yy, w, 1), Color(0, 0, 0, 0.18))
		yy += 2
