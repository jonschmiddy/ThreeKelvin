class_name LabLogin
extends Control

## THE LAB'S SCREEN AT REST: the owner's screensavers (Jon, Nov 5: "you start the lab fully
## zoomed out, the screen turns on like normal, has a corpo logo or something ...
## Why: docs/why/LabLogin.md#the-labs-screen-at-rest

const LOGO := &"logo"
const LOGIN := &"login"
const SIGNING := &"signing"
## CLICK TO SIGN IN breathes between these inks over `PULSE_S` (brightness
## only, nothing moves).
const PULSE_LO := 0.8
const PULSE_S := 1.6
## THE TURN: each saver stays up this long on the lab's clock (at rest; the
## clock waits while you point), then the glass dips to dark over `DIP_S` and
## comes up on the next over `DIP_S`.
const HOLD_S := 40.0
const DIP_S := 0.5
## The hold in use: `HOLD_S`, shorter only for a film of the turn (`saverturn`).
static var hold_s := HOLD_S

var state: StringName = LOGO
## The station's owner (a manufacturer id, &"" for none) and the lab's tint.
var owner_id: StringName = &""
var tint := Color(0.75, 0.94, 0.92)
var pilot := ""
var data := 0
## The station this lab stands in, for the order its savers come in
## (`StationScreen._refresh_bench`: the galaxy's seed and the system).
var station_key := 0
## WHERE THE LOOKS ARE LAID OUT, in this window's own px: the part of it the
## camera still has on screen once it has landed (`LabZoom.landed_view`).
## Empty is the whole window.
var safe := Rect2i()
## How long this state has been up (game time, its own frames' deltas).
var _t := 0.0
## Every word and mark drawn, [name, Rect2i], for the box test.
var leaves: Array = []
## The lab, for its power-on clock (the savers run off it).
var lab: LabScene = null
## A saver pinned for a film or a test ("" the turn; "?" not read yet).
static var forced := "?"
## The turn's clock (seconds at rest since the power-on), the saver up, and
## the lab's clock (`since_on`) when it came up.
var turn_t := 0.0
var _turn_i := 0
var shown_from := 0.0
var _saver: LabSavers = null
## The saver drawn last frame: a new one up (the turn, or a pin) starts its own
## clock and its motion from nothing.
var _shown_code := ""
## A test's or a film's fixed moment in the saver's own clock (seconds since it
## came up), or -1 to run it (`LabSavers.rest_t`): one look, the same every run.
var rest_pin := -1.0
## The dip drawn now: it follows `dip()`, but clears or comes back no faster
## than `DIP_S` / 2 for the whole way (pointed at mid-dip, the glass brightens,
## it does not jump).
var _dip_shown := 0.0
## How long the last frame's saver took to draw, in microseconds of the wall's
## clock (a cost, not a time anything runs on: `LabSaverTest` reads it).
var paint_us := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Set the look. A new look starts its own clock.
func set_state(s: StringName) -> void:
	if s == state:
		return
	state = s
	_t = 0.0
	queue_redraw()


## The window's area the looks are laid out in.
func area() -> Rect2i:
	var all := Rect2i(Vector2i.ZERO, Vector2i(size))
	return all if not safe.has_area() else all.intersection(safe)


## CLICK TO SIGN IN's ink now, in 1/40 steps.
func cue_ink() -> float:
	var k := 0.5 - 0.5 * cos(_t * TAU / PULSE_S)
	return snappedf(PULSE_LO + (1.0 - PULSE_LO) * k, 0.025)


## The saver pinned on the command line (`saver=` or the old `splash=`), or "".
static func pinned() -> String:
	if forced == "?":
		forced = ""
		for a in OS.get_cmdline_user_args():
			var s := a as String
			if s.begins_with("saver="):
				forced = s.substr(6).to_upper()
			elif s.begins_with("splash="):
				forced = s.substr(7).to_upper()
	return forced


## This lab's savers, in the order it shows them.
func savers() -> Array[String]:
	return LabSavers.list_for(owner_id, station_key)


## The saver on the glass now.
func code() -> String:
	var p := pinned()
	if p != "" and LabSavers.ALL.has(p):
		return p
	var l := savers()
	return l[_turn_i % l.size()]


## How dark the glass is for the turn (0 clear, 1 dark): down over the last
## `DIP_S` of a saver's hold and up over the first of the next. Pointed at, it
## clears.
func dip() -> float:
	if pinned() != "" or state != LOGO:
		return 0.0
	var into := fposmod(turn_t, hold_s)
	var k := 0.0
	if into > hold_s - DIP_S:
		k = (into - (hold_s - DIP_S)) / DIP_S
	elif turn_t >= hold_s and into < DIP_S:
		k = 1.0 - into / DIP_S
	return smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	# THE TURN runs on the lab's clock, at rest, once the screen is up
	if pinned() == "" and state == LOGO and since_on() > 0.0:
		turn_t += delta
		_turn_i = int(floorf(turn_t / hold_s))
	# A NEW SAVER UP starts from nothing: its clock and its motion
	var c := code()
	if c != _shown_code:
		if _shown_code != "":
			shown_from = since_on()
			saver().reset()
		_shown_code = c
	var goal := dip()
	_dip_shown = goal if absf(goal - _dip_shown) <= delta * 2.0 / DIP_S else move_toward(_dip_shown, goal, delta * 2.0 / DIP_S)
	# NOT DRAWN OFF THE DECK: the glass sits in its own viewport, which a hidden
	# deck does not hide, so it would paint every frame anywhere at the station
	if lab != null and is_instance_valid(lab) and not lab.is_visible_in_tree():
		return
	saver().step(delta, c)
	queue_redraw()


func _draw() -> void:
	leaves.clear()
	var t0 := Time.get_ticks_usec()
	saver().paint(code())
	paint_us = Time.get_ticks_usec() - t0
	var k := _dip_shown
	if k > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(LabBoard.BG, k))


# ------------------------------------------------------------------ the kit

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


## The box test on this look: every word and mark inside the window, and
## inside the part of it the landed camera keeps (`safe`), none on another
## (a plate, a card, a field or a bar holds its own words, so those are let be).
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
			if (leaves[i][0] in ["field", "card", "plate", "bar"] and a.encloses(b)) or (leaves[j][0] in ["field", "card", "plate", "bar"] and b.encloses(a)):
				continue
			if a.intersects(b):
				bad.append("'%s' overlaps '%s'" % [leaves[i][0], leaves[j][0]])
	return bad


func saver() -> LabSavers:
	if _saver == null:
		_saver = LabSavers.new(self)
	return _saver


func _exit_tree() -> void:
	if _saver != null:
		_saver.release()


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
