extends Node2D

## Follows the approved mockup in the game's own colours and face.
## Beacons are lit only in orbit of a place or alongside it, so its events become available there.
## Why: docs/why/SystemOverlay.md#overlay-design

const GLYPH := {
	&"fight": ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
	&"hazard": ["..#..", ".#.#.", ".#.#.", "#...#", "#####"],
	&"salvage": ["##.##", "#...#", ".....", "#...#", "##.##"],
	# a reading (science): three bars rising, a readout's columns
	&"science": ["....#", "..#.#", "..#.#", "#.#.#", "#.#.#"],
	&"signal": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	&"contract": ["#####", "#...#", "#.#.#", "#...#", "#####"],
	&"quest": ["..#..", "..#..", "#####", "..#..", "..#.."],
	&"dock": [".###.", "#...#", "#.#.#", "#...#", ".###."],
	&"harvest": ["#.#.#", ".###.", "##.##", ".###.", "#.#.#"],
	&"core": ["#...#", ".###.", ".#.#.", ".###.", "#...#"],
}
const SPENT := Color("#3a4654")

var view
## What the pointer is over: {kind: &"beacon"|&"body"|&"star", body: int, beacon: Beacon or null, at: Vector2}
var hover: Dictionary = {}
## The place selected: a body, -1 the star (star A of two suns),
## `SystemLayout.STAR_B` (-4) star B, -2 nothing.
var selected: int = -2
## Every beacon drawn this frame, for hit-testing: [at, body index, Beacon]
var beacons_at: Array = []
## A card in the panel lights its beacon here as pointing at it would, without the tip.
var link_on := false
var linked = null
var link_body := -2

## THE SHIP, flown (`ShipFlight`); the screen steps it, this draws it.
var flight
## A GO UNDER WAY (the screen's `_taking`): the map takes no click until it
## lands, so the tip offers none (only pressable things look pressable).
var clicks_held := false
var _ship_at := Vector2.ZERO
## Hull drawn at map scale from the art LOCAL draws, remade when the hull is swapped.
const MapHullS := preload("res://scripts/ui/sysmap/MapHull.gd")
var hull_src: Texture2D = null
var hull_pic: Dictionary = {}
var _hull_key: Array = []
## The ion drive uses two steps of the cold ramp:
## the ramp's deep blue vanished against the map's blue nebulae.
## Why: docs/why/SystemOverlay.md#ship-drawing
const ION_CORE := Color("#5ea6ff")
const ION_TIP := Color("#bfe2ff")
## Harness record of every ship pixel, kept only while
## `record_px` is on, as headless draws nothing readable.
var record_px := false
var ship_px: Array = []
## 1 px ice outline outside the hull's own, for a world circling one sun of a binary.
const RING_OUTLINE := UITheme.ICE
var _last_rel := Vector2.INF
## The hover easing in, as the chart's `_hover_t` (move_toward at 9 a second),
## from nothing again for each new thing pointed at.
var _hover_t := 0.0
var _hover_key := ""
## The flight a second click would fly, drawn before you fly it.
var preview_to := -9
## The orbit is a solid ring never smaller than the world's disc plus 9 px,
## so being in orbit or not reads at a glance.
## Why: docs/why/SystemOverlay.md#orbit-look
const ORBIT_MIN_PX := 9.0
const TRAIL_S := 1.4
var _ok := 1.0
var _ok_v := 0.0
const OK_W := 5.0
var _ok_body := -9
var _trail: Array = []
var _was := -9
var _pulse := {}
var _left := {}
## the star orbit the ship is settled on (plane radius), or -1
var _star_r := -1.0
## and what it circles (`_settle_id`: -1 star A, the one star; STAR_B; -9 both
## suns), kept as the ship breaks away so the orbit left fades round it
var _star_id := -9
## and where that is now on the plane (the origin with one sun: `_settle_c`)
var _star_c := Vector2.ZERO
var _preview: Array = []
var _preview_key := ""
var _preview_ms := 0.0
## The preview is planned from the orbit and replanned only on change, so it holds steady.
## PV_N is 1,600 because at 320 a turn-round a few pixels across was cut into corners.
## Why: docs/why/SystemOverlay.md#plan-preview
const PV_N := 1600
const PV_BLEND := 0.5
var _pv_at := -99.0
var _pv_old := PackedVector3Array()
var _pv_new := PackedVector3Array()
var _pv_lit := PackedByteArray()
## how far through its flight each of the preview's points is (`lay_out`)
var _pv_u := PackedFloat32Array()
var _pv_b0 := -99.0
var _pv_choice: Dictionary = {}
## The plan drawn, which a click flies as is; planned on a worker, so it arrives a few frames late.
var _pv_plan = null
var _pv_req_key := ""
## the ship the preview was made for (`_draw_paths` starts afresh on a new one)
var _pv_flight = null
## The flight being flown, laid out once.
var _fly_line: Array = []
var _fly_line_plan = null

## WHERE THE SHIP IS PARKED, for the harnesses that set it: -3 at the edge as
## arrived, or a place (a world or -1 the star) it sits in orbit of or alongside.
var ship_park: int:
	get:
		if flight == null or flight.mode == &"warp" or flight.fresh:
			return -3
		return flight.reached()
	set(v):
		if flight != null:
			flight.place_at(v, view.t)
## Whether it is on a planned flight: >= 0 while it is, as the old field read.
var ship_fly_t0: float:
	get:
		return 1.0 if flight != null and flight.mode == &"fly" else -1.0
	set(_v):
		pass


func _font() -> FontFile:
	return UITheme.pixel_font()


## Words queue by priority and any overlapping a placed
## one are dropped, as the map showed too much text.
var _lq: Array = []
## WHERE THE WORDS WENT last frame: the weather keeps its events off them
## (`SkyWeather.clear_at`)
var label_rects: Array = []
## and the words in each (a harness reads which is which)
var label_says: Array = []
## Words held back to keep off a binary's suns, so a harness can tell them from displaced ones.
var label_held: Array = []
var _held_q: Array = []
## Words left on a beacon when no spot cleared suns and beacons both; for a harness.
var label_on_beacon: Array = []
var _on_beacon_q: Array = []
## THE WORDS A HIGHER LABEL TOOK THE PLACE OF last frame (`_place_labels`), each
## [the words, the box they would have had]: a harness tells which hid which
var label_under: Array = []
## Where the ship's words were placed last frame and what that spot is clear of, for a harness.
## Why: docs/why/SystemOverlay.md#harness-records
var ship_words: Dictionary = {}
var _ship_words_q: Dictionary = {}
## A nearby flash lights the hull edge facing it for a moment; the outline stays.
var catch_light: Dictionary = {}


func _label(at: Vector2, s: String, c: Color, prio: int, shadow: bool) -> void:
	_lq.append([prio, at, s, c, shadow])


## Hide names holds back place-naming words; YOU and the flight's warnings stay.
var names_on := true


func _name_label(at: Vector2, s: String, c: Color, prio: int, shadow: bool) -> void:
	if names_on:
		_label(at, s, c, prio, shadow)


func _place_labels() -> void:
	_lq.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	var placed: Array = []
	label_rects = []
	label_says = []
	label_held = _held_q
	_held_q = []
	label_on_beacon = _on_beacon_q
	_on_beacon_q = []
	label_under = []
	ship_words = _ship_words_q
	_ship_words_q = {}
	# (the spots words stepped to this frame, held for the next: `_spot_kept`;
	# words not placed this frame let theirs go)
	_spot_mem = _spot_seen
	_spot_seen = {}
	for e: Array in _lq:
		var at: Vector2 = e[1]
		var s: String = e[2]
		var tw := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var box := Rect2(at + Vector2(-2, -10), Vector2(tw + 4, 14))
		var hit := false
		for r: Rect2 in placed:
			if r.intersects(box):
				hit = true
				break
		if int(e[0]) == 1:
			for k in placed.size():
				if int(_lq[k][0]) >= 3 and (placed[k] as Rect2).has_area() and (placed[k] as Rect2).get_center().distance_to(_ship_at) < 160.0:
					hit = true
		if hit:
			placed.append(Rect2())
			label_under.append([s, box])
			continue
		placed.append(box)
		label_rects.append(box)
		label_says.append(s)
		if e[4]:
			_text(at + Vector2(1, 1), s, Color(Color("#05070b"), (e[3] as Color).a))
		_text(at, s, e[3])
	_lq.clear()


## THE BOX OF WORDS whose baseline's left end is `at`, as `_place_labels`
## builds it.
func _words_box(at: Vector2, words: String) -> Rect2:
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	return Rect2(at + Vector2(-2, -10), Vector2(tw + 4, 14))


## Words by a twin's star sat across the other sun about half the time at the opening zoom:
## the suns are 56 to 106 px apart and the words 140 to 230 px wide.
## Why: docs/why/SystemOverlay.md#words-off-suns
func _meets_sun(at: Vector2, words: String, but := -99, grow := 0.0) -> bool:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return false
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var box := Rect2(at + Vector2(-2, -10), Vector2(tw + 4, 14)).grow(grow)
	for st: int in L.stars():
		if st == but:
			continue
		var c := star_scr(st)
		var near := Vector2(clampf(c.x, box.position.x, box.end.x), clampf(c.y, box.position.y, box.end.y))
		if near.distance_to(c) < star_disc(st):
			return true
	return false


## WHERE AN EVENT'S BEACON IS DRAWN round its point `at` (`beacons_at`): its
## glyph's 5 cells of 2 px, `glyph`, a 10 px square.
static func beacon_box(at: Vector2) -> Rect2:
	return Rect2(at.round() + Vector2(-4, -4), Vector2(10, 10))


## THE CORNER TICKS OF THE RETICLE round `at` (`_reticle`), each the 3 px square
## its two ticks stand in.
static func reticle_boxes(at: Vector2, reach: float) -> Array:
	var out: Array = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var kp: Vector2 = (at + corner * reach).round()
		out.append(Rect2(kp - Vector2(0.0 if corner.x > 0 else 2.0, 0.0 if corner.y > 0 else 2.0), Vector2(3, 3)))
	return out


## Stepping the ship's words off the suns put them over an event beacon (seed 7),
## so spots are also kept clear of beacons.
## Why: docs/why/SystemOverlay.md#words-off-suns
func _clear_of_beacons(words: String, also: Array = [], grow := 0.0) -> Callable:
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var keep: Array = also.duplicate()
	for e in beacons_at:
		keep.append(beacon_box(e[0]))
	return func(q: Vector2) -> bool:
		var box := Rect2(q + Vector2(-2, -10), Vector2(tw + 4, 14)).grow(grow)
		for r: Rect2 in keep:
			if box.intersects(r):
				return false
		return true


## THE WORDS HELD BACK while the zoom ladder is far from rest (`ZoomLadder`):
## a label magnified with the picture is a smear of letter-sized blocks.
var hush_labels := false
## and faded on their way out and back in (`SystemMapScreen.ladder_chrome`)
var label_a := 1.0


func _text(at: Vector2, s: String, c: Color) -> void:
	if hush_labels or label_a <= 0.01:
		return
	draw_string(_font(), at.round(), LowHull.scr(self, s, UITheme.FS_SMALL, _font()), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(c, c.a * label_a))



func _px(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p.round(), Vector2.ONE), c)


func glyph(at: Vector2, name: StringName, c: Color) -> void:
	var m: Array = GLYPH.get(name, GLYPH[&"signal"])
	for r in 5:
		for k in 5:
			if (m[r] as String)[k] == "#":
				draw_rect(Rect2((at + Vector2((k - 2) * 2, (r - 2) * 2)).round(), Vector2(2, 2)), c)


func option_of(bc) -> Dictionary:
	if bc == null or bc.opt < 0:
		return {}
	return OptionTable.by_id(view.node.options[bc.opt])


## What a spent beacon says, and in what colour; empty while it is still open
## (a walk-away is still open). The same reading as the panel's stamps.
func spent_word(bc) -> Array:
	if bc == null or bc.opt < 0:
		return []
	var st := EncounterDrawer.option_state(view.node, bc.opt)
	if st.kind == &"open" or st.kind == &"left":
		return []
	return [st.word, st.ink]


func beacon_look(bc) -> Array:
	if bc.dock:
		return [&"dock", UITheme.ICE]
	if bc.core or bc.hellbender:
		return [&"core", UITheme.BAD]
	var o := option_of(bc)
	if o.is_empty():
		return [&"signal", UITheme.TRACTOR]
	return [EncounterDrawer.lead_tag(o), EncounterDrawer.tag_colour(o)]


func _process(d: float) -> void:
	if flight != null and view.layout != null:
		# THE PULSE LANDS AS THE BURN ENDS: `reached` turns only once the insertion
		# is done
		var now: int = flight.reached()
		if now != _was:
			if SystemLayout.is_place(_was):
				_left = {"body": _was, "r": _orbit_px(_was, _orbit_r(_was)), "t0": _clock(), "a": 0.8}
			if SystemLayout.is_place(now):
				_pulse = {"body": now, "t0": _clock()}
			_was = now
		var sw: float = flight.f.orbit_r if flight.star_orbiting() else -1.0
		if sw < 0.0 and _star_r > 0.0:
			# Kept under the circled star's id (-9 for both),
			# so a close-orbit capture draws no fade.
			_left = {"body": _star_id, "r": _star_r * view.zoom, "t0": _clock(), "a": 0.35, "id": _star_id}
		elif sw > 0.0 and _star_r < 0.0:
			_pulse = {"body": -2, "t0": _clock()}
		_star_r = sw
		if sw > 0.0:
			_star_id = _settle_id()
			_star_c = _settle_c()
		var on: int = flight.orbit_body()
		if SystemLayout.is_place(on):
			_ok_body = on
		# ON A SPRING, so the drawn ship's motion has no step when it starts or stops
		var want := 1.0 if not SystemLayout.is_place(on) else _orbit_k(on, _orbit_r(on))
		_ok_v += (OK_W * OK_W * (want - _ok) - 2.0 * OK_W * _ok_v) * d
		_ok += _ok_v * d
		if not SystemLayout.is_place(on) and absf(_ok - 1.0) < 0.002 and absf(_ok_v) < 0.01:
			_ok = 1.0
			_ok_v = 0.0
	var key := "" if hover.is_empty() else "%s:%s" % [hover.get("kind", &""), hover.get("body", -9)]
	if key != _hover_key:
		_hover_key = key
		_hover_t = 0.0
	_hover_t = move_toward(_hover_t, 0.0 if hover.is_empty() else 1.0, d * 9.0)
	# THE MOONS' ORBITS, only for the world pointed at, selected or circled
	var mf := {}
	if not hover.is_empty() and int(hover.get("body", -9)) >= 0:
		mf[int(hover.body)] = true
	if selected >= 0:
		mf[selected] = true
	if flight != null and flight.reached() >= 0:
		mf[int(flight.reached())] = true
	view.moon_focus = mf
	queue_redraw()


func _draw() -> void:
	var L: SystemLayout = view.layout
	tip_rect = Rect2()
	if L == null:
		# (no picture, no arrows over it)
		mark_rects = []
		mark_words = []
		marks_drawn.emit()
		return
	var t: float = view.t
	# WHAT IS POINTED AT: the cursor on the map, or else a card in the panel
	# (found by last frame's positions, which is a frame behind a slow orbit)
	var hv := hover
	var from_card := false
	if hv.is_empty() and link_on:
		for e in beacons_at:
			if e[2] == linked and int(e[1]) == link_body:
				hv = {"kind": &"beacon", "body": e[1], "beacon": e[2], "at": e[0]}
				from_card = true
	beacons_at.clear()
	_drawn_marks = []
	var t_rings := Time.get_ticks_usec()
	_draw_rings(t)
	view.tick("overlay rings", t_rings)
	# the small built things: a station, a derelict hulk
	for i in L.bodies.size():
		var b := L.bodies[i]
		var s: Vector2 = view.at[i]
		if b.kind == &"station":
			draw_rect(Rect2(s + Vector2(-4, 0), Vector2(9, 1)), UITheme.CHILL)
			draw_rect(Rect2(s + Vector2(0, -3), Vector2(1, 7)), UITheme.CHILL)
			draw_rect(Rect2(s + Vector2(-2, -1), Vector2(5, 3)), UITheme.ICE)
			_px(s, UITheme.EMBER)
			if int(floor(t * 2.0)) % 2 == 1:
				_px(s + Vector2(4, 0), UITheme.HOT)
		elif b.kind == &"derelict":
			draw_rect(Rect2(s + Vector2(-3, -1), Vector2(6, 2)), Color("#5a6068"))
			draw_rect(Rect2(s + Vector2(-1, -2), Vector2(2, 1)), Color("#7a828c"))
			_px(s + Vector2(3, 0), Color("#3a4048"))
	# the beacons
	var groups := {}
	var hover_group := ""
	if hv.get("kind", &"") == &"beacon":
		hover_group = String(option_of(hv.beacon).get("group", ""))
	for i in L.bodies.size():
		var b := L.bodies[i]
		for k in b.beacons.size():
			var bc = b.beacons[k]
			var sx: Vector2 = view.at[i]
			if b.kind == &"belt":
				# (round the belt's own centre: the pair's balance point in a twin)
				var a: float = b.phase + t / b.period * TAU + k * 0.9
				var bh: Vector2 = b.host_at(t)
				sx = view.screen(bh.x + cos(a) * b.orbit, bh.y + sin(a) * b.orbit).round()
			elif b.beacons.size() > 1:
				# Two beacons on one world stand side by side,
				# or the lower one could not be clicked.
				sx.x += roundf((float(k) - float(b.beacons.size() - 1) * 0.5) * 14.0)
			var by := sx.y - maxf(view.draw_r(b), 2.0) - 14.0
			var at := Vector2(sx.x, by)
			var look := beacon_look(bc)
			var col: Color = look[1]
			var spent := not spent_word(bc).is_empty()
			var o := option_of(bc)
			var rival: bool = hover_group != "" and String(o.get("group", "")) == hover_group and hv.beacon != bc and not spent
			# CLOSED UNTIL YOU ARE THERE: dim, no pulse, until in orbit or alongside
			var open_here: bool = flight == null or flight.reached() == i
			if not open_here and not spent:
				col = Color(col, 0.42)
			if not spent and open_here:
				var ph := fmod(t * 0.6 + i * 0.37 + k * 0.5, 1.0)
				var pr := 6.0 + ph * 13.0
				for a2 in range(0, 24, 2):
					var an := float(a2) / 24.0 * TAU
					_px(at + Vector2(cos(an) * pr, sin(an) * pr * 0.7), Color(col, 0.6 * (1.0 - ph)))
			var y := by + 7.0
			while y < sx.y - maxf(view.draw_r(b), 2.0) - 1.0:
				_px(Vector2(sx.x, y), Color(col, 0.25 if spent else 0.5))
				y += 2.0
			glyph(at, look[0], SPENT if spent else (Color(col, 0.35) if rival else col))
			if o.get("group", "") != "":
				var g := String(o.group)
				if not groups.has(g):
					groups[g] = []
				groups[g].append([at, bc])
			beacons_at.append([at, i, bc])
	# THE STAR'S OWN EVENTS (an option sited on a red or blue star): over the
	# star's disc, side by side, open only from a close orbit of it
	var ns := L.star_beacons.size()
	for k in ns:
		var bc = L.star_beacons[k]
		# (star A's: only a red or blue one holds any, and those are never a
		# pair, `MapGen.twin_ok`; read where star A is drawn all the same)
		var so: Vector2 = star_scr(-1)
		var sr := maxf(L.star_r * view.star_k(), 3.0)
		var sx := Vector2(so.x + roundf((float(k) - float(ns - 1) * 0.5) * 14.0), so.y)
		var by := sx.y - sr - 14.0
		var at := Vector2(sx.x, by)
		var look := beacon_look(bc)
		var col: Color = look[1]
		var spent := not spent_word(bc).is_empty()
		var o := option_of(bc)
		var rival: bool = hover_group != "" and String(o.get("group", "")) == hover_group and hv.beacon != bc and not spent
		var open_here: bool = flight == null or flight.reached() == -1
		if not open_here and not spent:
			col = Color(col, 0.42)
		if not spent and open_here:
			var ph := fmod(t * 0.6 + k * 0.5, 1.0)
			var pr := 6.0 + ph * 13.0
			for a2 in range(0, 24, 2):
				var an := float(a2) / 24.0 * TAU
				_px(at + Vector2(cos(an) * pr, sin(an) * pr * 0.7), Color(col, 0.6 * (1.0 - ph)))
		var y := by + 7.0
		while y < sx.y - sr - 1.0:
			_px(Vector2(sx.x, y), Color(col, 0.25 if spent else 0.5))
			y += 2.0
		glyph(at, look[0], SPENT if spent else (Color(col, 0.35) if rival else col))
		if o.get("group", "") != "":
			var g := String(o.group)
			if not groups.has(g):
				groups[g] = []
			groups[g].append([at, bc])
		beacons_at.append([at, -1, bc])
	# a pulsar's own beacon: harvest the beam
	if L.star == SystemLayout.StarKind.PULSAR:
		var hat: Vector2 = star_scr(-1) + Vector2(14, -16)
		glyph(hat, &"harvest", UITheme.TRACTOR if flight == null or flight.reached() == -1 else Color(UITheme.TRACTOR, 0.42))
		beacons_at.append([hat, -1, null])
	# an exclusive group: rivals joined with a dashed line and marked
	if hover_group != "" and groups.has(hover_group):
		var gs: Array = groups[hover_group]
		for a in gs.size():
			for b2 in range(a + 1, gs.size()):
				var p1: Vector2 = gs[a][0]
				var p2: Vector2 = gs[b2][0]
				var n := p1.distance_to(p2)
				var kk := 0.0
				while kk < n:
					if int(kk / 4.0) % 2 == 0:
						_px(p1.lerp(p2, kk / n), Color(UITheme.WARN, 0.8))
					kk += 4.0
		for g in gs:
			if g[1] != hv.beacon:
				var words := "WILL BE MADE UNAVAILABLE"
				var w := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
				var wat: Vector2 = g[0] + Vector2(-roundf(w / 2.0), -9)
				_text(wat, words, UITheme.WARN)
				_drawn_marks.append(Rect2(wat + Vector2(-2, -10), Vector2(w + 4, 14)).grow(MARK_WORDS_CLEAR))
	# a card pointed at in the panel: its beacon bracketed, as the map's own
	# selection is
	if from_card:
		var c0: Vector2 = hv.at
		_drawn_marks.append(Rect2(c0 - Vector2(10, 9), Vector2(21, 19)).grow(MARK_CLEAR))
		for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var c := c0 + Vector2(d.x * 10.0, d.y * 9.0)
			draw_rect(Rect2(c + Vector2(-3 if d.x > 0 else 0, 0), Vector2(4, 1)).abs(), UITheme.ICE)
			draw_rect(Rect2(c + Vector2(0, -3 if d.y > 0 else 0), Vector2(1, 4)).abs(), UITheme.ICE)
	# THE SELECTION: the chart's reticle, closed and held, brighter than a hover,
	# and the name beside it (on the left near the frame's right edge)
	if SystemLayout.is_place(selected):
		var s: Vector2 = _place_scr(selected)
		var b: SystemLayout.Body = null if SystemLayout.is_star(selected) else L.bodies[selected]
		if b == null or b.kind != &"belt":
			var r := _reach(selected)
			_reticle(s, r, 1.0, 0.95)
		# in orbit of it, the label under the ship names it instead (the two sat on
		# top of each other)
		if (b == null or b.kind != &"belt") and (flight == null or flight.reached() != selected):
			var r := _reach(selected)
			var nm: String = star_name_of(selected) if b == null else b.name
			var tw := _font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
			var lx := s.x + r + 4.0
			if lx + tw > view.window.end.x - 4.0:
				lx = s.x - r - 4.0 - tw
			var at := Vector2(lx, s.y + 3.0)
			# A selected name never sits across a pair's sun; spots step out until one clears,
			# else the name is held back, as the panel names what is selected.
			# Why: docs/why/SystemOverlay.md#words-off-suns
			if _meets_sun(at, nm, selected):
				var side2 := Vector2(s.x - r - 4.0 - tw if lx > s.x else s.x + r + 4.0, s.y + 3.0)
				var cx := clampf(s.x - roundf(tw / 2.0), view.window.position.x + 4.0, view.window.end.x - tw - 4.0)
				var under := Vector2(cx, s.y + r + 12.0)
				var over := Vector2(cx, s.y - r - 5.0)
				var spots := [side2, under, over, at, at, side2]
				var steps := [Vector2.UP, Vector2.DOWN, Vector2.UP, Vector2.UP, Vector2.DOWN, Vector2.DOWN]
				var ship_words_at: Array = []
				var fw: Array = [] if flight == null or not names_on else _ship_words_first(_ship_at)
				if not fw.is_empty():
					var fww := _font().get_string_size(String(fw[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
					ship_words_at.append(Rect2((fw[1] as Vector2) + Vector2(-2, -10), Vector2(fww + 4, 14)))
				# (held where it stood while it stays clear there, `_spot_kept`)
				var tries: Array = [["words", spots, steps, nm, _clear_of_beacons(nm, ship_words_at)]]
				if not ship_words_at.is_empty():
					tries.append(["beacons", spots, steps, nm, _clear_of_beacons(nm)])
				tries.append(["suns", spots, steps, nm, Callable()])
				var got := _spot_kept("sel", nm, tries, selected)
				at = Vector2.INF if got.is_empty() else (got[0] as Vector2)
				if not got.is_empty() and (got[1] as Array)[0] == "suns" and names_on:
					_on_beacon_q.append(nm)
			if at != Vector2.INF:
				_name_label(at, nm, UITheme.ICE, 2, false)
			elif names_on:
				_held_q.append(nm)
	# THE HOVER: the same reticle, closing in from 13 px to 7 px as it eases in
	var hk: StringName = hover.get("kind", &"")
	if (hk == &"body" or hk == &"star") and int(hover.body) != selected and _hover_t > 0.0:
		var hs: Vector2 = _place_scr(int(hover.body))
		_reticle(hs, _reach(int(hover.body)) + (6.0 - 6.0 * _hover_t), _hover_t, 0.55)
	var t_paths := Time.get_ticks_usec()
	_draw_paths(t)
	view.tick("overlay paths", t_paths)
	var t_ship := Time.get_ticks_usec()
	_draw_ship(t)
	_draw_partners_and_comet(t)
	view.tick("overlay ship", t_ship)
	_place_labels()
	# WHAT THE SHIP IS DOING, top left of the frame, under the goal and its step
	var st := ship_status()
	if String(st[0]) != "":
		_text(view.window.position + STATUS_AT, st[0], st[1])
	_draw_edge_marks(String(st[0]))
	if not hover.is_empty():
		_draw_tip()
	marks_drawn.emit()


# ---------------------------------------------------------------- the edge marks
# A wide pair opens framed on its suns, so off-screen events and ships get an edge arrow.
# The look is Jon's Edge arrows C (Nov 2, Nov 5). It is not a control: it takes no click.
# Why: docs/why/SystemOverlay.md#edge-marks
var mark_zoom := INF
## the screen's own things the arrows keep off, in this space
## (`SystemMapScreen.mark_keep`)
var mark_keep: Array = []
## The arrows drawn last frame, with their boxes, glyph, name and target, for a harness.
## Why: docs/why/SystemOverlay.md#harness-records
var edge_marks: Array = []
## Names beside the ships' arrows, for the screen to draw with them.
var mark_words: Array = []
## how far in from the frame's edge an arrow's middle stands (clear of the
## frame's bezel), and the step it is slid round the edge by
const MARK_IN := 12.0
const MARK_STEP := 3.0
## and how many steps either way it may go (240 px) before it is left out
const MARK_SLIDES := 80
## How far an arrow keeps off words: at 8 the top-left arrow read as the status line's bullet.
const MARK_WORDS_CLEAR := 12.0
const MARK_CLEAR := 2.0
## A PARTNER'S HULL's half-size on screen (`_draw_partners`: its cells reach 4
## back and 7 forward, 4 either side, with the outline)
const PARTNER_HALF := 8.0
## Marks drawn before the arrows that no list holds, which `_draw_edge_marks` keeps off.
var _drawn_marks: Array = []
## what the screen draws over the picture for the arrows this frame, in this
## space, [Rect2, Color] each (outline first)
var mark_rects: Array = []
## the hover tip's box this frame (Rect2() with none): the screen draws no
## arrow pixel under it, so the tip covers an arrow
var tip_rect := Rect2()
## the overlay has drawn this frame's arrows (the screen redraws its layer on
## it, so the arrows are never a frame behind the picture)
signal marks_drawn
## Nothing in the column under the status line: an up arrow 12 px under it read as its caret.
const MARK_UNDER_WORDS := 40.0
## the glyph's cells this far (the outline's width) off the arrow's
const MARK_GLYPH_GAP := 1
## Glyph cells are 2 px each (Jon, Nov 5), 10 px, as tall as a side arrow is across.
const MARK_GLYPH_CELL := 2
const MARK_GLYPH_PX := 5 * MARK_GLYPH_CELL
## THE ARROW'S LINE, 2 px (Jon, Nov 5, "Two px"), as the glyph's strokes are
const MARK_LINE := 2
## A ship's name sits 1 px off the arrow's outline and is cut with .. past MARK_NAME_MOST.
const MARK_NAME_GAP := 1.0
const MARK_NAME_MOST := 72.0
const MARK_NAME_SHORT := 30.0
## and kept this far inside the frame
const MARK_NAME_IN := 2.0
const MARK_DARK := Color("#05070b")
## Narrow triangle, about 40 degrees at the point: a 90-degree one read as a mound or a play button.
## Why: docs/why/SystemOverlay.md#edge-arrow-shape
const TRI_SIDE := ["##...........", "#####........", "########.....", "###########..",
	"#############", "#############", "###########..", "########.....", "#####........",
	"##..........."]
const TRI_SIDE_AT := Vector2i(-7, -5)
## Diagonal is the triangle turned 45 degrees: the wedge
## with legs on the axes read as a ramp or resize grip.
## Why: docs/why/SystemOverlay.md#edge-arrow-shape
const TRI_DIAG := ["..........##", ".........###", ".......####.", ".....#####..",
	"..########..", "#########...", "#########...", "########....", ".#######....",
	"..######....", "...####.....", "....###....."]
const TRI_DIAG_AT := Vector2i(-6, -6)
static var _tri_cache := {}
static var _line_cache := {}


## TRI_SIDE is turned for up, left and down; TRI_DIAG is mirrored for the other diagonals.
static func tri_px(dir: Vector2i) -> Array:
	if _tri_cache.has(dir):
		return _tri_cache[dir]
	var diag := dir.x != 0 and dir.y != 0
	var rows: Array = TRI_DIAG if diag else TRI_SIDE
	var at: Vector2i = TRI_DIAG_AT if diag else TRI_SIDE_AT
	var out: Array = []
	for j in rows.size():
		for k in (rows[j] as String).length():
			if (rows[j] as String)[k] == "#":
				out.append(_tri_turn(at + Vector2i(k, j), dir))
	_tri_cache[dir] = out
	return out


## Hollow arrow (Jon, Nov 5): the edge cells of `tri_px`, MARK_LINE (2) px of line.
static func tri_line(dir: Vector2i) -> Array:
	if _line_cache.has(dir):
		return _line_cache[dir]
	var left := {}
	for p: Vector2i in tri_px(dir):
		left[p] = true
	var out: Array = []
	for i in MARK_LINE:
		var edge: Array = []
		for p: Vector2i in left:
			if not (left.has(p + Vector2i.RIGHT) and left.has(p + Vector2i.LEFT) and left.has(p + Vector2i.UP)
					and left.has(p + Vector2i.DOWN)):
				edge.append(p)
		for p: Vector2i in edge:
			left.erase(p)
		out.append_array(edge)
	_line_cache[dir] = out
	return out


## Pixel p of the right (or up-right) arrow, turned (or mirrored) to point `dir`:
## its centre moved, then floored, so the shape stays round the same corner.
static func _tri_turn(p: Vector2i, dir: Vector2i) -> Vector2i:
	var c := Vector2(p) + Vector2(0.5, 0.5)
	var v: Vector2
	if dir.x != 0 and dir.y != 0:
		v = Vector2(c.x * dir.x, -c.y * dir.y)
	else:
		v = Vector2(c.x * dir.x - c.y * dir.y, c.x * dir.y + c.y * dir.x)
	return Vector2i(floori(v.x), floori(v.y))


## Glyph box is stepped back along -dir until clear of every arrow pixel, so outlines meet.
static func _glyph_at(dir: Vector2i) -> Vector2i:
	var key := dir + Vector2i(10, 10)
	if _tri_cache.has(key):
		return _tri_cache[key]
	var px := tri_px(dir)
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for p: Vector2i in px:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	var mid := Vector2(lo + hi + Vector2i.ONE) * 0.5
	var g := Vector2i.ZERO
	var half := MARK_GLYPH_PX * 0.5
	var far := MARK_GLYPH_PX - 1
	for r in 40:
		g = Vector2i(roundi(mid.x - dir.x * r - half), roundi(mid.y - dir.y * r - half))
		var ok := true
		for p: Vector2i in px:
			var dx := maxi(maxi(g.x - p.x, p.x - (g.x + far)), 0)
			var dy := maxi(maxi(g.y - p.y, p.y - (g.y + far)), 0)
			if maxi(dx, dy) < MARK_GLYPH_GAP + 1:
				ok = false
				break
		if ok:
			break
	_tri_cache[key] = g
	return g


## Where an arrow at `q` stands and the boxes it holds: all, arrow, glyph, name and baseline.
func _tri_boxes(q: Vector2, dir: Vector2i, glyph_too: bool, name_w := -1.0) -> Array:
	var ab := Rect2()
	for p: Vector2i in tri_px(dir):
		var r := Rect2(Vector2(p), Vector2.ONE)
		ab = r if ab.size == Vector2.ZERO else ab.merge(r)
	ab = Rect2(ab.position + q, ab.size).grow(1.0)
	var all := ab
	var gb := Rect2()
	if glyph_too:
		gb = Rect2(q + Vector2(_glyph_at(dir)), Vector2.ONE * MARK_GLYPH_PX)
		all = all.merge(gb.grow(1.0))
	var nb := Rect2()
	var base := Vector2.ZERO
	if name_w >= 0.0:
		base = _name_at(q, dir, ab, name_w)
		nb = name_box(base, name_w)
		all = all.merge(nb)
	return [all, ab, gb, nb, base]


## WHETHER A SHIP'S NAME IN `nb` STANDS BESIDE ITS ARROW in `ab` pointing
## `dir`: off it, and on its inward side (behind the way it points).
static func name_beside(ab: Rect2, nb: Rect2, dir: Vector2i) -> bool:
	return not nb.intersects(ab) and (nb.get_center() - ab.get_center()).dot(Vector2(dir)) < 0.0


## Name box: the 5 px caps and a Q's tail with the 1 px dark rim round them.
static func name_box(base: Vector2, w: float) -> Rect2:
	return Rect2(base + Vector2(-1.0, -6.0), Vector2(w + 2.0, 9.0))


## A ship's name stands on the arrow's inward side, MARK_NAME_GAP off its outline,
## and is kept MARK_NAME_IN inside the frame.
## Why: docs/why/SystemOverlay.md#edge-arrow-shape
func _name_at(q: Vector2, dir: Vector2i, ab: Rect2, w: float) -> Vector2:
	var b := Vector2.ZERO
	if dir.x == 0:
		b.x = roundf(ab.get_center().x - w * 0.5)
		b.y = ab.end.y + MARK_NAME_GAP + 6.0 if dir.y < 0 else ab.position.y - MARK_NAME_GAP - 3.0
	else:
		b.x = ab.position.x - MARK_NAME_GAP - 1.0 - w if dir.x > 0 else ab.end.x + MARK_NAME_GAP + 1.0
		# (the caps' rows base-5 to base-1, centred on the arrow's middle row)
		b.y = q.y + 3.0 - float(dir.y) * 3.0
	if view != null:
		var win: Rect2 = view.window
		if win.size.x > w + 2.0 * MARK_NAME_IN + 2.0:
			b.x = clampf(b.x, win.position.x + MARK_NAME_IN + 1.0, win.end.x - MARK_NAME_IN - 1.0 - w)
			b.y = clampf(b.y, win.position.y + MARK_NAME_IN + 6.0, win.end.y - MARK_NAME_IN - 3.0)
	return b


## Dark runs just inside the hollow line only: on a sun's glow its bright inner side
## read as a filled pale arrow and lost the colour.
## Why: docs/why/SystemOverlay.md#edge-arrow-shape
func _tri_queue(q: Vector2, dir: Vector2i, c: Color, glyph_too: bool, gname: StringName) -> void:
	var solid := {}
	for p: Vector2i in tri_px(dir):
		solid[p] = true
	var fill := {}
	for p: Vector2i in tri_line(dir):
		fill[p] = true
	var shape := solid.duplicate()
	if glyph_too:
		var g := _glyph_at(dir)
		var m: Array = GLYPH.get(gname, GLYPH[&"signal"])
		for r in 5:
			for k in 5:
				if (m[r] as String)[k] == "#":
					for a in MARK_GLYPH_CELL:
						for b in MARK_GLYPH_CELL:
							var gp := g + Vector2i(k * MARK_GLYPH_CELL + a, r * MARK_GLYPH_CELL + b)
							fill[gp] = true
							shape[gp] = true
	var edge := {}
	for p: Vector2i in fill:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := p + Vector2i(dx, dy)
				# (round the whole shape outside, and just inside the line)
				if not fill.has(n) and (not shape.has(n) or solid.has(n)):
					edge[n] = true
	var dark := Color(MARK_DARK, 0.8 * c.a)
	for p: Vector2i in edge:
		mark_rects.append([Rect2(q + Vector2(p), Vector2.ONE), dark])
	for p: Vector2i in fill:
		mark_rects.append([Rect2(q + Vector2(p), Vector2.ONE), c])


func _draw_edge_marks(status: String) -> void:
	edge_marks = []
	mark_rects = []
	mark_words = []
	if hush_labels or label_a <= 0.01 or view.zoom > mark_zoom:
		return
	var win: Rect2 = view.window
	# (no picture yet: the frame is not laid out, its window empty)
	if win.size.x <= MARK_IN * 4.0 or win.size.y <= MARK_IN * 4.0:
		return
	var inner := win.grow(-MARK_IN)
	var mid := win.get_center()
	var L: SystemLayout = view.layout
	# what is off the picture: the events' beacons, your ship and the partners'
	var want: Array = []
	for e in beacons_at:
		if not beacon_box(e[0]).intersects(win):
			var bc = e[2]
			var col: Color = UITheme.TRACTOR if bc == null else beacon_look(bc)[1]
			if bc != null and not spent_word(bc).is_empty():
				col = SPENT
			# (the event's key glyph: a pulsar's beacon has none of its own,
			# harvest the beam)
			want.append([e[0], int(e[1]), col, 0, &"harvest" if bc == null else beacon_look(bc)[0], ""])
	if flight != null and not win.grow(-2.0).has_point(_ship_at):
		want.append([_ship_at, -9, UITheme.ICE, 0, &"", "YOU"])
	# Partners get arrows too: framed on a wide pair's own part,
	# 15 of 16 out on a world round both were nowhere.
	# Why: docs/why/SystemOverlay.md#edge-marks
	for e: Array in partner_at:
		if not win.grow(-2.0).has_point(e[1]):
			want.append([e[1], -9, UITheme.GOOD, int(e[0]), &"", String(e[2]) if e.size() > 2 else ""])
	if want.is_empty():
		return
	# what is drawn on the picture already
	var keep: Array = []
	for r: Rect2 in label_rects:
		keep.append(r.grow(MARK_WORDS_CLEAR))
	keep.append_array(mark_keep)
	keep.append_array(_drawn_marks)
	if status != "":
		keep.append(status_rect(status).grow(MARK_WORDS_CLEAR))
		# and the column under it, so nothing hangs off it
		var sr := status_rect(status)
		keep.append(Rect2(sr.position.x - MARK_WORDS_CLEAR, sr.position.y, sr.size.x + MARK_WORDS_CLEAR * 2.0,
			sr.size.y + MARK_UNDER_WORDS))
	for e in beacons_at:
		if beacon_box(e[0]).intersects(win):
			keep.append(beacon_box(e[0]).grow(MARK_CLEAR))
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind != &"belt" and i < view.at.size():
			var r := maxf(view.draw_r(b), 2.0)
			keep.append(Rect2(view.at[i] - Vector2(r, r), Vector2(r, r) * 2.0))
	for p in L.stars():
		var r := star_disc(p)
		keep.append(Rect2(star_scr(p) - Vector2(r, r), Vector2(r, r) * 2.0))
	if flight != null:
		keep.append(Rect2(_ship_at - Vector2.ONE * ship_r(), Vector2.ONE * ship_r() * 2.0).grow(MARK_CLEAR))
	for e: Array in partner_at:
		keep.append(Rect2(e[1] - Vector2.ONE * PARTNER_HALF, Vector2.ONE * PARTNER_HALF * 2.0).grow(MARK_CLEAR))
	for w: Array in want:
		var to: Vector2 = w[0]
		var d := to - mid
		if d.length() < 0.5:
			continue
		# where the line from the middle meets the edge, the frame's inset
		var k := minf(absf((inner.size.x * 0.5) / d.x) if absf(d.x) > 0.001 else INF,
			absf((inner.size.y * 0.5) / d.y) if absf(d.y) > 0.001 else INF)
		var s0 := _round_s(inner, mid + d * k)
		# Arrows slide round the edge to a clear spot;
		# a mark for the goal's corner goes down the left side.
		var spot := Vector2.INF
		var glyph_too: bool = int(w[1]) != -9
		var nm := ""
		var names: Array = [""]
		if String(w[5]) != "":
			names = [OutcomeRow.fit(String(w[5]), UITheme.FS_SMALL, MARK_NAME_MOST),
				OutcomeRow.fit(String(w[5]), UITheme.FS_SMALL, MARK_NAME_SHORT)]
			# (a short name, YOU or GENO, is the same both cuts: tried once)
			if names[1] == names[0]:
				names.resize(1)
			# and where no spot clears even the short name, the bare arrow, as
			# round one drew it: an arrow with no name beats a ship not marked
			names.append("")
		for try_nm: String in names:
			var nw := -1.0 if try_nm == "" else _font().get_string_size(try_nm, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
			for st in MARK_SLIDES:
				for sg in ([1.0] if st == 0 else [1.0, -1.0]):
					var q := _round_at(inner, s0 + MARK_STEP * float(st) * float(sg)).round()
					# the box of what would be drawn there, arrow, glyph and name,
					# pointing the way it would from there
					var qd := _eight_way(to - q)
					var bxs: Array = _tri_boxes(q, qd, glyph_too, nw)
					var box: Rect2 = bxs[0]
					# Near a corner the frame pushed a diagonal arrow's name onto the arrow itself.
					var hit := not win.encloses(box) or (nw >= 0.0 and not name_beside(bxs[1], bxs[3], qd))
					for r: Rect2 in keep:
						if hit or r.intersects(box):
							hit = true
							break
					if not hit:
						spot = q
						break
				if spot != Vector2.INF:
					break
			if spot != Vector2.INF:
				nm = try_nm
				break
		if spot == Vector2.INF:
			continue
		# pointing at it from where it stands, the nearest of the eight ways
		var dir := _eight_way(to - spot)
		var nw2 := -1.0 if nm == "" else _font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var bx := _tri_boxes(spot, dir, glyph_too, nw2)
		keep.append((bx[0] as Rect2).grow(1.0))
		var c := Color(w[2], (w[2] as Color).a * label_a)
		_tri_queue(spot, dir, c, glyph_too, w[4])
		if nm != "":
			mark_words.append([bx[4], nm, c, bx[3]])
		edge_marks.append({"at": spot, "box": bx[0], "body": w[1], "peer": w[3], "dir": dir, "to": to,
			"arrow_box": bx[1], "glyph_box": bx[2], "glyph": w[4] if glyph_too else &"", "name": nm, "name_box": bx[3]})


## The nearest of the eight ways to `d` (x and y -1, 0 or 1).
static func _eight_way(d: Vector2) -> Vector2i:
	var a := d.angle()
	return Vector2i(roundi(cos(a) * 1.2), roundi(sin(a) * 1.2)).clamp(Vector2i(-1, -1), Vector2i.ONE)


## A point on the edge of `r` that far round it, clockwise from its top left.
static func _round_at(r: Rect2, s: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	var u := fposmod(s, 2.0 * (w + h))
	if u < w:
		return r.position + Vector2(u, 0.0)
	u -= w
	if u < h:
		return Vector2(r.end.x, r.position.y + u)
	u -= h
	if u < w:
		return Vector2(r.end.x - u, r.end.y)
	return Vector2(r.position.x, r.end.y - (u - w))


## How far round the edge of `r` (clockwise from its top left) point p on it is.
static func _round_s(r: Rect2, p: Vector2) -> float:
	var w := r.size.x
	var h := r.size.y
	if absf(p.y - r.position.y) < 0.5:
		return p.x - r.position.x
	if absf(p.x - r.end.x) < 0.5:
		return w + p.y - r.position.y
	if absf(p.y - r.end.y) < 0.5:
		return w + h + r.end.x - p.x
	return 2.0 * w + h + r.end.y - p.y


# ---------------------------------------------------------------- the reticle
## The drawn edge of a place, and the reticle's reach out from it.
## The comet's reticle radius (px): its head and coma.
const COMET_R := 7.0

func _reach(body: int) -> float:
	var L: SystemLayout = view.layout
	if SystemLayout.is_star(body):
		return star_disc(body) + 7.0
	if not SystemLayout.is_place(body):
		# (-9, both suns' balance point: no disc there)
		return 7.0
	return view.draw_r(L.bodies[body]) + 7.0


# ---------------------------------------------------------------- the stars
# Star B's screen place comes from the view once it says; until then it is worked out the same way.
# Why: docs/why/SystemOverlay.md#star-positions
func star_scr(p: int) -> Vector2:
	if view.has_method(&"star_screen"):
		return view.call(&"star_screen", p)
	var L: SystemLayout = view.layout
	if L != null and L.twin:
		var sp := L.star_pos(p, float(view.t))
		return view.block_round(view.screen(sp.x, sp.y))
	return view.origin()


## Wide orbits are told by id, as a zero centre was star A only while A held still.
## A sun's ring rides its disc on the block grid, so it never wobbles against it.
## Why: docs/why/SystemOverlay.md#star-positions
func _ring_c(id: int, c: Vector2) -> Vector2:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return view.origin()
	if SystemLayout.is_star(id) and c.distance_to(L.star_pos(id, float(view.t))) < 0.5:
		return star_scr(id)
	return view.block_round(view.screen(c.x, c.y))


## Star disc size comes from the view once it says, else star A's as before.
func star_disc(p: int) -> float:
	if view.has_method(&"star_disc"):
		return float(view.call(&"star_disc", p))
	var L: SystemLayout = view.layout
	if p == SystemLayout.STAR_B and L != null and L.twin:
		return SystemLayout.sun_drawn(L.star2_r, view.zoom)
	return L.star_r * view.star_k()


## `at` is an Array, and `at[-4]` would quietly have been the fourth body from the end.
func _place_scr(p: int) -> Vector2:
	if SystemLayout.is_star(p):
		return star_scr(p)
	return view.at[p]


## Star p's name: the system's for one star, "<system> A" / "<system> B" for two.
func star_name_of(p: int) -> String:
	return view.layout.star_title(view.node, p)


## What kind of star p is, in the panel's and the tip's words: YELLOW DWARF...;
## a pair's star B the ORANGE DWARF it is drawn as (`SystemView.star_facts_of`).
func star_class_of(p: int) -> String:
	if p == SystemLayout.STAR_B and view.layout.twin:
		return String(view.star_facts_of(view.layout, view.KIND_NAMES[view.layout.star2], p).kind)
	return view.star_class()


## Cleared against the very star it is onto: star A's keep-out
## for star B drew a curl up to 58 px off the one flown.
## Why: docs/why/SystemOverlay.md#capture-insertion
func capture_ins(body: int, rel: Vector2, rv: Vector2) -> Dictionary:
	var rt: float = flight.orbit_r(body)
	var dir := 1.0 if rel.x * rv.y - rel.y * rv.x >= 0.0 else -1.0
	var spd: float = flight.STAR_RAIL_V if SystemLayout.is_star(body) else flight.RAIL_V
	var star := SystemLayout.is_star(body)
	return flight.insert_plan(rel, rv, rt, dir * spd / rt, null if star else view.layout.bodies[body], Vector2.ZERO, body if star else -1)


## A place's name: a star's, or a body's.
func _place_nm(p: int) -> String:
	return star_name_of(p) if SystemLayout.is_star(p) else view.layout.bodies[p].name


## The centre is worked out from what the ship circles, never kept as a point,
## as a kept centre was off its turning sun within seconds.
## Why: docs/why/SystemOverlay.md#settle-id
func _settle_c() -> Vector2:
	return centre_of(_settle_id(), float(view.t))


## A sun where the pair has it then, the fixed balance point, or the origin with one sun.
func centre_of(id: int, t: float) -> Vector2:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return Vector2.ZERO
	return L.star_pos(id, t) if SystemLayout.is_star(id) else L.bary


## Read by id, never by a centre point: once the pair turns a point drifts,
## and a ship round star B read ORBITING BOTH STARS.
## Why: docs/why/SystemOverlay.md#settle-id
func _settle_id() -> int:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return -1
	if flight != null and flight.f != null and flight.star_orbiting():
		var id = flight.f.get("cen_id")
		if id is int and (int(id) == -9 or SystemLayout.is_star(int(id))):
			return id
	return _star_id


## Both suns is named BOTH STARS (Jon, Nov 1: call it Binary instead of two suns),
## matching the panel's AROUND row.
## Why: docs/why/SystemOverlay.md#settle-id
func _settle_nm(id: int) -> String:
	if not view.layout.twin:
		return star_name_of(-1)
	return "BOTH STARS" if id == -9 else star_name_of(id)


## A point is behind a star where it is further from the viewer (`depth`).
func _star_occ(q: Vector2) -> Array:
	var out: Array = []
	var d: float = view.depth(q)
	for s: int in view.layout.stars():
		if d < view.depth(view.layout.star_pos(s, float(view.t))):
			out.append([star_scr(s), star_disc(s)])
	return out


## StarchartScreen's reticle: four corner ticks, 3 px, in white.
func _reticle(at: Vector2, reach: float, k: float, alpha: float) -> void:
	var c := Color(1, 1, 1, alpha * k)
	_drawn_marks.append(Rect2(at - Vector2.ONE * (reach + 2.0), Vector2.ONE * (reach + 2.0) * 2.0 + Vector2.ONE).grow(MARK_CLEAR))
	for raw in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner: Vector2 = raw
		var kp: Vector2 = (at + corner * reach).round()
		draw_rect(Rect2(kp - Vector2(0.0 if corner.x > 0 else 2.0, 0), Vector2(3, 1)), c)
		draw_rect(Rect2(kp - Vector2(0, 0.0 if corner.y > 0 else 2.0), Vector2(1, 3)), c)


# ---------------------------------------------------------------- rings
## A point on the plane, on screen.
func _scr(x: float, z: float) -> Vector2:
	return view.screen(x, z)


func _circle(c: Vector3, r: float, col: Color, step: int = 3) -> void:
	var n := int(r * view.zoom * 2.4) + 24
	var k := 0
	while k < n:
		var a := float(k) / n * TAU
		_px(_scr(c.x + cos(a) * r, c.z + sin(a) * r), col)
		k += step


## Each world's ring (where it will take you) while you are near it or on it,
## and the rail you are on.
func _draw_rings(t: float) -> void:
	var L: SystemLayout = view.layout
	if flight == null:
		return
	var sp: Vector3 = flight.where3()
	for b in L.bodies:
		if b.world == &"":
			continue
		var c: Vector3 = b.point3(t)
		var held: bool = flight.mode == &"rail" and int(flight.rail.body) == b.index
		var d := Vector2(sp.x - c.x, sp.z - c.z).length()
		var kk := 0.0 if held else clampf((b.soi * 2.2 - d) / (b.soi * 1.2), 0.0, 1.0)
		if kk > 0.0:
			_circle(c, b.soi, Color(UITheme.COLD, 0.5 * kk))
	# BURNING ONTO AN ORBIT: the orbit it is burning onto, dashed
	if flight.inserting():
		var ib: int = flight.orbit_body()
		_ring(_body_scr(ib), _orbit_px(ib, _orbit_r(ib)) * _ok / maxf(_orbit_k(ib, _orbit_r(ib)), 1.0), Color(UITheme.FLARE, 0.7), ib, true)
	# ROUND THE STAR: the whole orbit faint (it is the size of the system), the
	# stretch the ship is on bright
	if flight.star_orbiting():
		_star_orbit(float(flight.f.orbit_r), flight.f.p, 1.0, false)
	# THE ORBIT YOU ARE ON: solid and bright, round the world, the ship on it --
	# still while it rides round to where a flight leaves from
	var ob: int = flight.reached()
	if not SystemLayout.is_place(ob) and flight.mode == &"rail" and flight.rail.has("phase"):
		ob = flight.orbit_body()
	if SystemLayout.is_place(ob):
		var bw := _body_scr(ob)
		_ring(bw, _orbit_px(ob, _orbit_r(ob)) * _ok / maxf(_orbit_k(ob, _orbit_r(ob)), 1.0), Color(UITheme.FLARE, 0.95), ob, false)
		if selected != ob and not _is_belt(ob):
			_reticle(_place_scr(ob), _reach(ob), 1.0, 0.95)
	# SETTLED ROUND THE STAR: the arc by the ship pulses once
	if not _pulse.is_empty() and int(_pulse.body) == -2 and flight.star_orbiting():
		var age3 := _clock() - float(_pulse.t0)
		if age3 < 0.7:
			_star_orbit(float(flight.f.orbit_r) + 14.0 * ease(age3 / 0.7, 0.5) / maxf(view.zoom, 0.05), flight.f.p, 1.0 - age3 / 0.7, true)
	# A CAPTURE: one ring pulsing out from the orbit
	if not _pulse.is_empty() and int(_pulse.body) == ob:
		var age := _clock() - float(_pulse.t0)
		if age < 0.7:
			var r0 := _orbit_px(ob, _orbit_r(ob)) * _ok / maxf(_orbit_k(ob, _orbit_r(ob)), 1.0)
			_ring(_body_scr(ob), r0 + 22.0 * ease(age / 0.7, 0.5), Color(UITheme.FLARE, 0.9 * (1.0 - age / 0.7)), ob, false)
	# LEAVING: the orbit you were on fades as you break away
	if not _left.is_empty() and int(_left.body) != ob:
		var age2 := _clock() - float(_left.t0)
		if age2 < 0.9:
			var lb := int(_left.body)
			var lw: Vector2
			if _left.has("id"):
				# A left wide orbit is drawn round what it circled,
				# behind that star's disc; none for both.
				var lc := centre_of(int(_left.id), float(view.t))
				lw = _scr(lc.x, lc.y)
			else:
				lw = _body_scr(lb)
			_ring(lw, float(_left.r), Color(UITheme.FLARE, float(_left.get("a", 0.8)) * (1.0 - age2 / 0.9)), lb, true)


## Faint all round, bright either side of the ship; round a pair its far half goes behind a sun.
func _star_orbit(r: float, by: Vector2, k: float, arc_only: bool) -> void:
	var c := _star_c
	var o: Vector2 = _ring_c(_star_id, c)
	var rp: float = r * view.zoom
	var a0 := atan2(by.y - c.y, by.x - c.x)
	var disc: float = view.layout.star_r * view.star_k()
	var two: bool = view.layout.twin
	# (each sun as [its plane z, its disc's centre on screen, its radius])
	var suns: Array = []
	if two:
		for s: int in view.layout.stars():
			suns.append([view.layout.star_pos(s, float(view.t)).y, star_scr(s), star_disc(s)])
	# AS A LINE OF SINGLE PIXELS, only the stretch on screen (point by point it
	# was thousands of dots a frame for the orbit you arrive on, zoomed in)
	var eb: float = rp * float(view.TILT)
	var per: float = PI * (3.0 * (rp + eb) - sqrt((3.0 * rp + eb) * (rp + 3.0 * eb)))
	var n := clampi(int(per / 1.5), 48, 4000)
	var win: Rect2 = view.window.grow(4.0)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for j in n + 1:
		var an := float(j) / float(n) * TAU
		var dd := absf(wrapf(an - a0, -PI, PI))
		var near := clampf(1.0 - dd / 0.55, 0.0, 1.0)
		var q: Vector2 = (o + Vector2(cos(an) * rp, sin(an) * eb)).round()
		var skip := (arc_only and near <= 0.0) or not win.has_point(q)
		if not skip and not two:
			skip = sin(an) < 0.0 and q.distance_to(o) < disc
		elif not skip:
			# behind a sun: further from the viewer than it, and on its disc
			var pz := c.y + sin(an) * r
			for oc: Array in suns:
				if pz < float(oc[0]) and q.distance_to(oc[1]) < float(oc[2]):
					skip = true
					break
		if skip:
			if pts.size() > 1:
				draw_polyline_colors(pts, cols, 1.0)
			pts = PackedVector2Array()
			cols = PackedColorArray()
			continue
		if pts.size() > 0 and pts[pts.size() - 1] == q:
			continue
		pts.append(q + Vector2(0.5, 0.5))
		cols.append(Color(UITheme.FLARE, k * (0.13 + 0.72 * near * near)))
	if pts.size() > 1:
		draw_polyline_colors(pts, cols, 1.0)


# ---------------------------------------------------------------- the lines
# The forecast line: the coast to the ring and orbit you end on, plus a fainter held-key line.
func _draw_paths(t: float) -> void:
	if flight == null:
		return
	if flight.mode == &"free":
		# WITH A FLIGHT DRAWN TOO, the let-go forecast steps back (the two leave
		# the ship together and read as one line with a corner in it)
		var previewing: bool = SystemLayout.is_place(preview_to) and flight.orbit_body() != preview_to and t - float(flight.thrust_t) >= 1.0 and flight.can_fly()
		if not previewing and not (flight.hold_line as Dictionary).is_empty():
			_line(flight.hold_line, 0.22, t, false)
		if not (flight.line as Dictionary).is_empty():
			_line(flight.line, 0.25 if previewing else 0.55, t, not previewing)
	var arriving: bool = flight.plan != null and (flight.rail.has("arrive") or flight.keep.has("arrive"))
	if flight.plan != null and (flight.mode == &"fly" or arriving or (flight.mode == &"rail" and flight.rail.has("phase")) or (flight.mode == &"keep" and flight.keep.has("hold"))):
		# A flight under way shows what is left of it; round a star orbit the ride is not drawn.
		if _fly_line_plan != flight.plan:
			_fly_line_plan = flight.plan
			_fly_line = _plan_line(flight.plan, true)
		var u := 0.0
		if flight.mode == &"fly" or arriving:
			u = clampf((t - flight.fly_t0) / flight.plan.dur, 0.0, 1.0)
		u = maxf(u, float(flight.plan.u_dep))
		_draw_line3(_fly_line[0], _fly_line[1], 1.0, _fly_line[2], u, flight.plan)
	# By hand only where you are going is drawn, never a plan replanned from under you.
	# A click flies only out of an orbit, so only then is its flight drawn.
	# Why: docs/why/SystemOverlay.md#flight-line
	var by_hand: bool = flight.mode == &"free" and t - float(flight.thrust_t) < 1.0
	var can: bool = flight.can_fly() and not by_hand
	# A new ship drops all preview state: its clock restarts at 0 and the arrival key repeats,
	# so an old preview could pass as current and never be planned again.
	# Why: docs/why/SystemOverlay.md#plan-preview
	if flight != _pv_flight:
		_pv_flight = flight
		_preview_key = ""
		_pv_req_key = ""
		_pv_new = PackedVector3Array()
		_pv_old = PackedVector3Array()
		_pv_plan = null
		_pv_choice = {}
		_pv_at = -99.0
		_fly_line = []
		_fly_line_plan = null
	if not can:
		_preview_key = ""
		_pv_new = PackedVector3Array()
		_pv_old = PackedVector3Array()
		_pv_plan = null
		flight.drop_bg(&"preview")
	if SystemLayout.is_place(preview_to) and can and flight.orbit_body() != preview_to:
		var in_orbit: bool = flight.mode == &"rail" and not flight.inserting()
		# (the AUTOPILOT setting's path too: changed, the line is planned again)
		var key := "%d:%d:%d:%s:%s" % [preview_to, flight.orbit_body() if in_orbit else -9, roundi(float(flight.rail.get("rt", 0.0))) if in_orbit else 0, flight.mode, flight.flight_opts().path]
		# Replan every 3 s on a ring, every 1 s alongside
		# or round a star orbit, and as departure nears.
		var every := 3.0 if in_orbit else 1.0
		# The old planner's plan is made ahead on the worker too and kept the same way.
		var ahead: bool = _pv_plan != null and (_pv_plan.res != null or _pv_plan.ahead)
		if _pv_plan != null and not ahead:
			every = maxf(every, 2.0)
		var gone: bool = ahead and (t >= float(_pv_plan.t0) - flight.PLAN_AHEAD or flight._takeable(_pv_plan, t).is_empty())
		if key != _preview_key and _pv_plan != null and int(_pv_plan.to) != preview_to:
			# ANOTHER PLACE: the last one's flight is not drawn while this one's is made
			_pv_plan = null
			_pv_new = PackedVector3Array()
			_pv_old = PackedVector3Array()
		if (key != _preview_key or t - _pv_at > every or gone) and not flight.planning(&"preview"):
			var same := key == _preview_key
			_preview_key = key
			_pv_at = t
			# (its line laid out on the worker too, `ShipFlight.lay_out`)
			if flight.plan_bg(preview_to, t, _pv_choice if same else {}, &"preview", PV_N):
				_pv_req_key = key
		var got: Dictionary = flight.take_bg(&"preview", t)
		if not got.is_empty():
			var pl = got.plan
			_preview_ms = float(flight.last_ms)
			# A stale plan is dropped and asked for again.
			if pl != null and int(got.i) == preview_to and _pv_req_key == key and not flight._takeable(pl, t).is_empty():
				var was_same: bool = _pv_plan != null and int(_pv_plan.to) == preview_to
				# A solved flight is drawn as it is, never blended: blended over PV_BLEND the line
				# was another flight for that half second.
				# Why: docs/why/SystemOverlay.md#plan-preview
				var blend: bool = was_same and _pv_new.size() == PV_N and pl.res == null and not pl.ahead and _pv_plan.res == null and not _pv_plan.ahead
				_pv_plan = pl
				_pv_choice = pl.choice
				var ln: Array = _plan_line(pl, false)
				_pv_old = _pv_blend() if blend else PackedVector3Array()
				_pv_new = ln[0]
				_pv_lit = ln[1]
				_pv_u = ln[2]
				_pv_b0 = _clock() if not _pv_old.is_empty() else -99.0
			elif pl == null and int(got.i) == preview_to:
				# (nothing at all from here: none drawn, and asked again in a while)
				_pv_plan = null
				_pv_new = PackedVector3Array()
				_pv_old = PackedVector3Array()
			else:
				_pv_at = -99.0
		if _pv_new.size() == PV_N:
			var pvl := _pv_blend()
			# The old planner's line eases onto the ship;
			# a solved flight's starts where it leaves, ahead.
			if flight.mode == &"free" and _pv_plan != null and _pv_plan.res == null and not _pv_plan.ahead:
				var off: Vector3 = flight.where3() - pvl[0]
				if off.length() > 0.5:
					var step := maxf(pvl[1].distance_to(pvl[0]), 0.01)
					var m := clampi(roundi(maxf(60.0, off.length() * 3.0) / step), 8, PV_N / 4)
					var eased := PackedVector3Array(pvl)
					for j in m:
						var x := float(j) / float(m)
						eased[j] = pvl[j] + off * (1.0 - x * x * (3.0 - 2.0 * x))
					pvl = eased
			# (a solved flight's ends at its rings' drawn size: `_drawn_ends`)
			var whole: bool = _pv_plan != null and _pv_plan.res != null and _pv_old.is_empty() and _pv_u.size() == pvl.size()
			_draw_line3(pvl, _pv_lit, 1.0, _pv_u if whole else PackedFloat32Array(), 0.0, _pv_plan if whole else null)


## The preview as it is drawn now: the last plan blending into the new.
func _pv_blend() -> PackedVector3Array:
	var k := clampf((_clock() - _pv_b0) / PV_BLEND, 0.0, 1.0)
	if _pv_old.size() != PV_N or k >= 1.0:
		return _pv_new
	k = k * k * (3.0 - 2.0 * k)
	var out := PackedVector3Array()
	out.resize(PV_N)
	for j in PV_N:
		out[j] = _pv_old[j].lerp(_pv_new[j], k)
	return out


## PV_N even-spaced points, made on the worker with the plan when it was asked for so.
func _plan_line(pl, _with_u: bool) -> Array:
	if (pl.line as Array).size() == 3 and (pl.line[0] as PackedVector3Array).size() == PV_N:
		return pl.line
	return flight.lay_out(pl, PV_N)


## The dotted line hides behind suns and nearer worlds: dotted over everything,
## it ran across a sun's face in a quarter of a twin's flights.
## Why: docs/why/SystemOverlay.md#flight-line
func _draw_line3(pts: PackedVector3Array, lit: PackedByteArray, k: float, us: PackedFloat32Array, u0: float, pl = null) -> void:
	var drawn := _drawn_ends(pts, us, pl)
	var sp := PackedVector2Array()
	var sl := PackedByteArray()
	var sd := PackedFloat32Array()
	for j in drawn.size():
		if not us.is_empty() and us[j] < u0:
			continue
		var q: Vector3 = drawn[j]
		sp.append(_scr(q.x, q.z))
		sl.append(lit[j])
		sd.append(view.depth(Vector2(q.x, q.z)))
	if sp.size() < 2:
		return
	var occ := _occluders()
	var w := _spline(sp)
	var next := 0.0
	var wp: PackedVector2Array = w[0]
	var wd: PackedFloat32Array = w[1]
	var ws: PackedInt32Array = w[2]
	var was_on := false
	for j in wp.size():
		var on: bool = sl[ws[j]] == 1
		var dot := wd[j] >= next
		if dot:
			next += 3.0
		var mark := on and not was_on
		was_on = on
		if not dot and not mark:
			continue
		if _hidden(wp[j], sd[ws[j]], occ):
			continue
		# A BURN MARKER where each real burn starts: a small plus, so a change of
		# course reads as a manoeuvre (only the burns the plan marks as real)
		if mark:
			var c0: Vector2 = wp[j].round()
			for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]:
				_px(c0 + d, Color(ION_TIP, 0.85 * k))
		if dot:
			_px(wp[j].round(), Color(ION_CORE, 0.85 * k) if on else Color(UITheme.ICE, 0.65 * k))


## What can stand in front of a point: each sun's disc and each drawn world.
func _occluders() -> Array:
	var out: Array = []
	var L: SystemLayout = view.layout
	for st: int in L.stars():
		out.append([star_scr(st), star_disc(st), view.depth(L.star_pos(st, float(view.t)))])
	for i: int in view._views:
		out.append([view.at[i], view.draw_r(L.bodies[i]), view.depth(view.pos[i])])
	return out


## Whether screen point `x`, of a plane point at depth `d`, is behind one of
## `occ` (`_occluders`): nearer the viewer than it, and over it.
static func _hidden(x: Vector2, d: float, occ: Array) -> bool:
	for o: Array in occ:
		if float(o[2]) > d and x.distance_to(o[0]) < float(o[1]):
			return true
	return false


## Ends are drawn at the rings' drawn size: laid at life size the line began and ended
## on a world's face and the ship rode 3.5 to 8.9 px off it.
## Why: docs/why/SystemOverlay.md#flight-line
func _drawn_ends(pts: PackedVector3Array, us: PackedFloat32Array, pl) -> PackedVector3Array:
	if pl == null or pl.res == null or us.size() != pts.size() or pts.is_empty():
		return pts
	var tab: Dictionary = _ends_table(pts, us, pl)
	var kd: float = _orbit_k(int(tab.dp), float(tab.rd)) if bool(tab.has_d) else 1.0
	var ka: float = _orbit_k(int(tab.to), float(tab.ra)) if bool(tab.has_a) else 1.0
	if kd <= 1.001 and ka <= 1.001:
		return pts
	var out := PackedVector3Array(pts)
	var rows: Array = tab.rows
	for e: Array in rows:
		var j: int = e[0]
		var c: Vector2 = e[1]
		var sc: float = 1.0 + (kd - 1.0) * float(e[2]) + (ka - 1.0) * float(e[3])
		var q := pts[j]
		out[j] = Vector3(c.x + (q.x - c.x) * sc, q.y, c.y + (q.z - c.y) * sc)
	return out


## (per plan: what `_drawn_ends` scales, and each point's share of each scale)
var _ends_tabs: Dictionary = {}
func _ends_table(pts: PackedVector3Array, us: PackedFloat32Array, pl) -> Dictionary:
	var key := "%d:%d" % [pl.get_instance_id(), pts.size()]
	if _ends_tabs.has(key):
		return _ends_tabs[key]
	if _ends_tabs.size() >= 4:
		_ends_tabs.clear()
	var L: SystemLayout = view.layout
	var dep: Dictionary = pl.dep
	var dk := StringName(dep.get("kind", &""))
	var dp := int(dep.get("place", -9))
	var has_d := SystemLayout.is_place(dp) and (dk == &"ring" or dk == &"keep")
	var rd := float(dep.get("rt", 0.0)) if dk == &"ring" else maxf((dep.get("off", Vector2.ZERO) as Vector2).length(), 4.0)
	var to := int(pl.to)
	var has_a := SystemLayout.is_place(to)
	var ra: float = maxf((pl.end.get("arel", Vector2.ZERO) as Vector2).length(), 4.0) if bool(pl.end.get("keep", false)) else float(flight.orbit_r(to)) if has_a else 0.0
	var t0 := float(pl.t0)
	var dur := float(pl.dur)
	var t_end := float(pl.end.get("t", t0 + dur))
	var t_arr: float = flight._arrive_t(pl)
	var w := OK_W
	# (the spring's own fall from rest, `_process`'s `_ok`)
	var g := func(tau: float) -> float:
		return (1.0 + w * tau) * exp(-w * tau) if tau > 0.0 else 1.0
	var at := func(i: int, tt: float) -> Vector2:
		return L.star_pos(i, tt) if SystemLayout.is_star(i) else _flat3(flight.center(i, tt))
	# (the tail after the last sample, TAIL_S of the ring, at its own moments)
	var n_tail := 0
	for j in range(us.size() - 1, -1, -1):
		if us[j] < 1.0:
			break
		n_tail += 1
	var wd_arr: float = g.call(t_arr - t0) if has_d else 0.0
	var rows: Array = []
	var nt := 0
	for j in pts.size():
		var tj := t0 + float(us[j]) * dur
		if us[j] >= 1.0 and n_tail > 1:
			tj = t_end + float(flight.TAIL_S) * float(nt) / float(n_tail - 1)
			nt += 1
		if has_a and tj > t_arr:
			var ga: float = g.call(tj - t_arr)
			rows.append([j, at.call(to, tj), wd_arr * ga, 1.0 - ga])
		elif has_d:
			var gd: float = g.call(tj - t0)
			if gd > 0.001:
				rows.append([j, at.call(dp, tj), gd, 0.0])
	var tab := {"dp": dp, "rd": rd, "has_d": has_d, "to": to, "ra": ra, "has_a": has_a, "rows": rows}
	_ends_tabs[key] = tab
	return tab


## Catmull-Rom spline walked about a pixel at a time, so dots and dashes sit at even distances.
static func _spline(sp: PackedVector2Array) -> Array:
	var out := PackedVector2Array([sp[0]])
	var dist := PackedFloat32Array([0.0])
	var segs := PackedInt32Array([0])
	var n := sp.size()
	var walked := 0.0
	var prev := sp[0]
	for j in n - 1:
		var p0 := sp[maxi(j - 1, 0)]
		var p1 := sp[j]
		var p2 := sp[j + 1]
		var p3 := sp[mini(j + 2, n - 1)]
		var m := maxi(1, int(ceil(p1.distance_to(p2))))
		for k in range(1, m + 1):
			var u := float(k) / float(m)
			var u2 := u * u
			var u3 := u2 * u
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)
			walked += q.distance_to(prev)
			prev = q
			out.append(q)
			dist.append(walked)
			segs.append(j)
	return [out, dist, segs]


## The clock the map's own effects run on (a capture's pulse, a leave's fade).
static func _clock() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## The radius of the orbit (or the station-keeping) the ship is on round a place.
func _orbit_r(body: int) -> float:
	if flight.mode == &"rail" and int(flight.rail.body) == body:
		return float(flight.rail.rt)
	if flight.mode == &"keep" and int(flight.keep.body) == body:
		return maxf((flight.keep.off as Vector2).length(), 4.0)
	return flight.orbit_r(body)


## Never closer than ORBIT_MIN_PX to the disc, so it reads round a 5 px world; capped in a pair.
func _orbit_k(body: int, r: float) -> float:
	return orbit_floor_k(r * view.zoom, _reach(body) - 7.0, _orbit_cap(body))


## Static so a harness can measure it for every pair without a map.
static func orbit_floor_k(r_px: float, disc: float, cap: float) -> float:
	var want := minf(maxf(r_px, disc + ORBIT_MIN_PX), maxf(cap, r_px))
	return maxf(1.0, want / maxf(r_px, 0.01))


## In a twin an orbit is capped 2 px short of the discs it would cut: uncapped, 454 close
## orbits drew into their world's disc (TwinSiteTest, seed 4242).
## Why: docs/why/SystemOverlay.md#orbit-cap
func _orbit_cap(body: int) -> float:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return INF
	var z: float = view.zoom
	if SystemLayout.is_star(body):
		var cap := INF
		for b in L.bodies:
			if b.host_id == body and b.kind != &"belt":
				cap = minf(cap, b.orbit * z - view.draw_r(b) - 2.0)
		return cap
	if not SystemLayout.is_place(body):
		return INF
	var hb: SystemLayout.Body = L.bodies[body]
	if SystemLayout.is_star(hb.host_id):
		return hb.orbit * z - star_disc(hb.host_id) - 2.0
	return INF


## An orbit's drawn radius in screen pixels.
func _orbit_px(body: int, r: float) -> float:
	return r * view.zoom * _orbit_k(body, r)


func _is_belt(body: int) -> bool:
	return body >= 0 and view.layout.bodies[body].kind == &"belt"


static func _flat3(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## A place's centre on screen. A star's from the layout, where the pair has it
## at the view's t.
func _body_scr(body: int) -> Vector2:
	if SystemLayout.is_star(body):
		var sp: Vector2 = view.layout.star_pos(body, float(view.t))
		return _scr(sp.x, sp.y)
	var c: Vector3 = flight.center(body, view.t)
	return _scr(c.x, c.z)


## A ring round a place, flattened as the plane is: solid, or dashed 4 on 3 off.
## Its far half goes behind the place's disc.
func _ring(w: Vector2, r: float, col: Color, body: int, dashed: bool) -> void:
	for q: Vector2 in ring_pts(w, r, body, dashed):
		_px(q, col)


## The far half hides behind the disc where it is drawn now, as a ring round a future
## world stood 5 to 9 px off the world as drawn.
## Why: docs/why/SystemOverlay.md#ring-drawing
func ring_pts(w: Vector2, r: float, body: int, dashed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var disc := _reach(body) - 7.0
	var wd := _place_scr(body) if SystemLayout.is_place(body) or SystemLayout.is_star(body) else w
	var off := wd.distance_squared_to(w) > 0.01
	var n := int(r * 6.4) + 24
	var arc := TAU * r / float(n)
	# only what is on screen (the star orbit you arrive on, zoomed in, ran to
	# thousands of points a frame, nearly all of them off it)
	var win: Rect2 = view.window.grow(2.0)
	for j in n:
		if dashed and fmod(float(j) * arc, 7.0) >= 4.0:
			continue
		var an := float(j) / float(n) * TAU
		var q := w + Vector2(cos(an) * r, sin(an) * r * view.TILT)
		if not win.has_point(q):
			continue
		if sin(an) < 0.0 and (q.distance_to(w) < disc or (off and q.distance_to(wd) < disc)):
			continue
		out.append(q.round())
	return out


## A path on the plane, dashed 4 on 3 off; `fade` takes it out toward its end.
func _dashes(pts: PackedVector2Array, col: Color, fade: bool) -> void:
	var sp := PackedVector2Array()
	for q in pts:
		sp.append(_scr(q.x, q.y))
	_dashes_px(sp, col, fade)


func _dashes_px(sp: PackedVector2Array, col: Color, fade: bool) -> void:
	if sp.size() < 2:
		return
	# along a smooth curve through the points, dashes at even distances
	var w := _spline(sp)
	var wp: PackedVector2Array = w[0]
	var wd: PackedFloat32Array = w[1]
	var total: float = wd[wd.size() - 1]
	var seen := {}
	var next := 0.0
	for j in wp.size():
		if wd[j] < next:
			continue
		next = floorf(wd[j]) + 1.0
		if fmod(wd[j], 7.0) < 4.0:
			var q := wp[j].round()
			if not seen.has(q):
				seen[q] = true
				var al := col.a
				if fade and total > 0.0:
					al *= clampf(1.0 - wd[j] / total, 0.0, 1.0)
				_px(q, Color(col, al))


## THE TRAIL: where the ship has been this last second and a half, fading; in
## orbit, kept round its world, so it follows the ring.
func _draw_trail(x: Vector2, ob: int) -> void:
	var now := _clock()
	while not _trail.is_empty() and now - float(_trail[0][0]) > TRAIL_S:
		_trail.pop_front()
	for e: Array in _trail:
		var b := int(e[1])
		var base: Vector2 = _body_scr(b) if SystemLayout.is_place(b) else view.origin()
		var q: Vector2 = (base + (e[2] as Vector2) * view.zoom).round()
		var age := (now - float(e[0])) / TRAIL_S
		_px(q, Color(UITheme.FLARE if SystemLayout.is_place(b) else UITheme.ICE, 0.55 * (1.0 - age)))
	if float(view.t) - float(flight.warp_t) < 0.6:
		return
	var base2: Vector2 = _body_scr(ob) if SystemLayout.is_place(ob) else view.origin()
	_trail.append([now, ob, (x - base2) / maxf(view.zoom, 0.01)])


func _line(ln: Dictionary, a: float, t: float, main: bool) -> void:
	var L: SystemLayout = view.layout
	# DASHED, unlike the solid orbit you are on; with nothing at its end it fades.
	# The faint line (keys kept held) is the path alone: no words, no rings.
	_dashes(ln.pts, Color(UITheme.ICE, a), (ln.out as Dictionary).is_empty() or not main)
	if not main:
		return
	for k in (ln.fast as Array).size():
		var at: Vector2 = ln.fast[k].at
		_mark_word("fast%d" % k, _scr(at.x, at.y), "TOO FAST", Color(UITheme.HOT, minf(1.0, a * 1.6)))
	var bp: Vector2 = ln.bump
	if bp != Vector2.INF:
		_mark_word("bump", _scr(bp.x, bp.y), "BUMP", Color(UITheme.TRACTOR, minf(1.0, a * 1.6)))
	var o: Dictionary = ln.out
	if o.is_empty():
		return
	var path := PackedVector2Array()
	for q0 in ln.pts:
		path.append(_scr(q0.x, q0.y))
	if o.kind == &"star":
		# Dashed stretch where it settles, round what it
		# settles round at `out.t`, as a sun turns on.
		var sr: float = o.r
		var sid: int = int(o.get("id", -1))
		var sc0: Vector2 = centre_of(sid, float(o.get("t", view.t))) if L.twin else (o.get("c", Vector2.ZERO) as Vector2)
		var sat: Vector2 = (o.at as Vector2) - sc0
		var st0 := atan2(sat.y, sat.x)
		var arc := PackedVector2Array()
		var so: Vector2 = _ring_c(sid, sc0)
		# from where the line ends, on along the orbit the way it goes (it began a
		# little behind, and the two met in a V)
		var dirn := signf(sat.x * (o.get("v", Vector2(0, 1)) as Vector2).y - sat.y * (o.get("v", Vector2(0, 1)) as Vector2).x) if o.has("v") else 1.0
		for j in 21:
			var an := st0 + dirn * 0.5 * float(j) / 20.0
			arc.append(so + Vector2(cos(an), sin(an) * view.TILT) * sr * view.zoom)
		_dashes_px(arc, Color(UITheme.FLARE, a * 0.9), false)
		return
	var body: int = o.body
	var nm: String = _place_nm(body)
	var tag: String
	# (a star's centre where it will be then, as a world's: `ShipFlight.center`)
	var c: Vector3 = flight.center(body, float(o.t))
	var cw := _scr(c.x, c.z)
	var rel: Vector2 = o.rel
	var under := 0.0
	# the place it takes you to, its reticle held faintly
	if not _is_belt(body):
		_reticle(_place_scr(body), _reach(body), 1.0, a)
	if o.kind == &"keep":
		under = maxf(rel.length() * view.zoom, _reach(body) + 2.0)
		_ring(cw, under, Color(UITheme.HOT, a * 0.9), body, true)
		tag = "WILL BE ALONGSIDE " + nm
	else:
		# The orbit you will be on, round where its world will be when you get there.
		var rt: float = flight.orbit_r(body)
		var rpx := _orbit_px(body, rt)
		var rv: Vector2 = o.rv if o.get("rv") != null else Vector2.ZERO
		# THE INSERTION AS THE SHIP WILL FLY IT, its offset drawn at the ring's scale
		var ins := capture_ins(body, rel, rv)
		var kq := _orbit_k(body, rt)
		var curl := PackedVector2Array()
		for j in 61:
			var q1: Vector2 = flight._ins_at(ins, float(j) / 60.0, 0) * view.zoom
			var sc := lerpf(1.0, kq, smoothstep(0.0, 1.0, float(j) / 60.0))
			curl.append(cw + Vector2(q1.x, q1.y * view.TILT) * sc)
		_dashes_px(curl, Color(UITheme.HOT, a), false)
		path.append_array(curl)
		_ring(cw, rpx, Color(UITheme.HOT, a * 0.9), body, true)
		under = rpx
		tag = "WILL ORBIT " + nm
	_label_clear(tag, cw, maxf(under * view.TILT, _reach(body) - 7.0), path, a)


## Words on the line never sit across a binary's sun: BUMP on the right sat across
## the sun's face once the pair turned.
## Why: docs/why/SystemOverlay.md#words-off-suns
func _mark_word(key: String, p: Vector2, words: String, col: Color) -> void:
	var right := p + Vector2(5, -4)
	if not _meets_sun(right, words):
		_label(right, words, col, 2, true)
		return
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var left := p + Vector2(-5.0 - tw, -4)
	var got := _spot_kept(key, words, [["side", [right, left, right, left], [Vector2.UP, Vector2.UP, Vector2.DOWN, Vector2.DOWN], words, Callable()]])
	if got.is_empty():
		_held_q.append(words)
		return
	_label(got[0], words, col, 2, true)


## Forecast words step off suns and beacons: about half the forecasts crossed a sun,
## and a quarter of those stepped onto a beacon (TwinSiteTest).
## Why: docs/why/SystemOverlay.md#words-off-suns
func _label_clear(tag: String, at: Vector2, half: float, path: PackedVector2Array, a: float) -> void:
	var tw := _font().get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var entry: Vector2 = path[0] if path.size() > 0 else at
	var away := 1.0 if at.x >= entry.x else -1.0
	var below := roundf(at.y + half + 12.0)
	var above := roundf(at.y - half - 6.0)
	var cands := [
		Vector2(at.x - tw * 0.5 + away * (tw * 0.5 - 6.0), below),
		Vector2(at.x - tw * 0.5, below),
		Vector2(at.x - tw * 0.5 + away * (tw * 0.5 - 6.0), above),
		Vector2(at.x - tw * 0.5, above),
		Vector2(at.x - tw * 0.5 - away * (tw * 0.5 - 6.0), below),
	]
	# the ship and its YOU are in the way too (last frame's place)
	var blocks := path.duplicate()
	var sr := ship_r()
	for sx in range(-sr - 3, sr + 4, 3):
		for sy in range(-you_up() - 3, sr + 2, 3):
			blocks.append(_ship_at + Vector2(sx, sy))
	# clear of the line and the ship: the text's box, glyphs above its baseline,
	# with a pixel or two round it
	var clear := func(p: Vector2) -> bool:
		var box := Rect2(p + Vector2(-2, -9), Vector2(tw + 4, 12))
		for q in blocks:
			if box.has_point(q):
				return false
		return true
	var spots: Array = []
	for cv: Vector2 in cands:
		spots.append(Vector2(clampf(cv.x, view.window.position.x + 4.0, view.window.end.x - tw - 4.0), cv.y))
	var pick: Vector2 = cands[0]
	# In a binary, last frame's spot is kept while clear,
	# as the turning suns changed the first clear spot.
	var two: bool = view.layout.twin
	var took := -1
	var was: Array = _spot_mem.get("fc_pick", []) if two else []
	if was.size() == 2 and was[0] == tag and int(was[1]) < spots.size():
		var wp: Vector2 = spots[int(was[1])]
		if clear.call(wp) and not _meets_sun(wp.round(), tag):
			took = int(was[1])
	if took < 0:
		for i in spots.size():
			var p: Vector2 = spots[i]
			if clear.call(p) and not _meets_sun(p.round(), tag):
				took = i
				break
	if took >= 0:
		pick = spots[took]
		if two:
			_spot_seen["fc_pick"] = [tag, took]
	pick = pick.round()
	if _meets_sun(pick, tag):
		var near: Array = spots.map(func(p: Vector2) -> Vector2: return p.round())
		var steps := [Vector2.DOWN, Vector2.DOWN, Vector2.UP, Vector2.UP, Vector2.DOWN]
		var off_beacons := _clear_of_beacons(tag)
		var got := _spot_kept("fc", tag, [
			["all", near, steps, tag, func(p: Vector2) -> bool: return clear.call(p) and off_beacons.call(p)],
			["line", near, steps, tag, clear],
			["suns", near, steps, tag, Callable()]])
		pick = Vector2.INF if got.is_empty() else (got[0] as Vector2)
		if not got.is_empty() and (got[1] as Array)[0] != "all" and names_on:
			_on_beacon_q.append(tag)
		if pick == Vector2.INF:
			if names_on:
				_held_q.append(tag)
			return
	_name_label(pick, tag, Color(UITheme.HOT, minf(1.0, a * 1.8)), 3, true)


# ---------------------------------------------------------------- the party
## Each partner's ship as last drawn: `[[peer id, screen point, pilot's name], ...]`.
var partner_at: Array = []
## Where each partner is drawn on the plane, eased toward its last report so a
## ship reported six times a second flies rather than steps.
var _partner_plane: Dictionary = {}
var _partner_ms: int = 0
## Partners on an orbit are drawn at its size, as at true offset they sat on the world's disc.
var _partner_kb: Dictionary = {}

## Partners were never drawn here (Oct 22 playtest);
## one sitting on you is drawn a ship's length off.
## Why: docs/why/SystemOverlay.md#partners
func _draw_partners(_t: float) -> void:
	partner_at.clear()
	var scr = get_parent()
	while scr != null and not scr.has_method("partner_points"):
		scr = scr.get_parent()
	if scr == null:
		return
	var now := Time.get_ticks_msec()
	var dt := clampf(float(now - _partner_ms) / 1000.0, 0.0, 0.25)
	_partner_ms = now
	# Held with the map's clock through a move (Jon, Nov 2), so a new report does not move them.
	var hold: bool = scr.has_method("clock_held") and scr.clock_held()
	var k := 0.0 if hold else 1.0 - exp(-dt * 8.0)
	var row := 0
	for e: Array in scr.partner_points():
		var id: int = e[0]
		var want: Vector2 = e[1]
		var q: Vector2 = _partner_plane.get(id, want)
		# a jump across the system is a new place, not a flight to it
		var jumped := q.distance_to(want) > 400.0 and not hold
		# (on a flight it said (PROTOCOL 17): on its path exactly, not eased)
		var flying: bool = e.size() > 5 and bool(e[5]) and not hold
		q = want if (jumped or flying) else q.lerp(want, k)
		_partner_plane[id] = q
		var pb: int = int(e[4]) if e.size() > 4 else -10
		var want_k := 1.0
		var kb: Array = _partner_kb.get(id, [pb, -1.0])
		if SystemLayout.is_place(pb):
			var cp: Vector2 = view.layout.star_pos(pb, float(view.t)) if SystemLayout.is_star(pb) else _flat3(flight.center(pb, view.t))
			want_k = _orbit_k(pb, maxf((q - cp).length(), 4.0))
			kb[0] = pb
		# (first seen, or jumped: drawn where it is at once)
		var kq: float = want_k if (float(kb[1]) < 0.0 or jumped) else lerpf(float(kb[1]), want_k, k)
		if want_k == 1.0 and absf(kq - 1.0) < 0.002:
			kq = 1.0
		kb[1] = kq
		_partner_kb[id] = kb
		var x := _scr(q.x, q.y)
		if kq > 1.001 and SystemLayout.is_place(int(kb[0])):
			var bw := _body_scr(int(kb[0]))
			x = bw + (x - bw) * kq
		x = x.round()
		if x.distance_to(_ship_at) < ship_r() + 7.0:
			row += 1
			x = _ship_at + Vector2(-6.0, ship_r() + 5.0 + 12.0 * (row - 1))
		partner_at.append([id, x, String(e[3])])
		# Hidden behind a star or nearer world as your ship is;
		# a close-orbit partner was drawn over the star.
		var depth: float = view.depth(q)
		var occ: Array = _star_occ(q)
		for i: int in view._views:
			if view.depth(view.pos[i]) > depth:
				occ.append([view.at[i], view.draw_r(view.layout.bodies[i])])
		var ang: float = e[2]
		var c := cos(ang)
		var s := sin(ang)
		var in_hull := func(u: int, v: int) -> bool:
			return u >= -3 and u <= 6 and absf(v) <= (6 - u) * 0.5
		var shown := 0
		for u in range(-4, 8):
			for v in range(-4, 5):
				var q2 := (x + Vector2(u * c - v * s, u * s + v * c)).round()
				var hid := false
				for o: Array in occ:
					if q2.distance_to(o[0]) < float(o[1]):
						hid = true
						break
				if hid:
					continue
				if in_hull.call(u, v):
					shown += 1
					_px(q2, UITheme.GOOD if u > 3 or absi(v) < 2 else UITheme.GOOD.darkened(0.3))
				elif in_hull.call(u - 1, v) or in_hull.call(u + 1, v) or in_hull.call(u, v - 1) or in_hull.call(u, v + 1):
					_px(q2, Color("#05070b"))
		# Partner names go under the ship at priority 0 so they yield to every other word;
		# none for a ship off the picture, whose edge arrow names it.
		# Why: docs/why/SystemOverlay.md#partners
		if shown > 0 and _win_in(2.0).has_point(x):
			_label(x + Vector2(-8, 17), String(e[3]), UITheme.GOOD, 0, true)


# ---------------------------------------------------------------- the ship
## Where the ship is relative to the star on screen: LOCATION follows exactly this.

func ship_rel() -> Vector2:
	if flight == null:
		return Vector2.ZERO
	var p: Vector3 = flight.where3()
	return Vector2(p.x, p.z * view.TILT) * view.zoom


## A place relative to the origin for LOCATION and right-click holds; a star where the pair has it.
func place_rel(body: int) -> Vector2:
	if SystemLayout.is_star(body) and view.layout != null:
		var sp: Vector2 = view.layout.star_pos(body, float(view.t))
		return Vector2(sp.x, sp.y * view.TILT) * view.zoom
	if body < 0 or flight == null:
		return Vector2.ZERO
	var c: Vector3 = flight.center(body, view.t)
	return Vector2(c.x, c.z * view.TILT) * view.zoom


## The map's picture of your hull, remade when the hull, its grade or the run
## changes (a swap at a yard hands `Run` a new frame).
func _hull_pic() -> Dictionary:
	var h: HullData = Run.hull
	if h == null or h.sprite == null:
		hull_src = null
		hull_pic = {}
		_hull_key = []
		return hull_pic
	var key := [h, h.tier, Rng.master]
	if key != _hull_key:
		_hull_key = key
		hull_src = ShipView.hull_art(h, "", false)
		hull_pic = MapHullS.picture(h, hull_src)
	return hull_pic


## The world whose ring the ship rides: drawn over that world all the way round, outlined.
func ringed_world() -> int:
	if flight == null or view == null or view.layout == null or not view.layout.twin or flight.mode != &"rail":
		return -9
	var w := int(flight.rail.get("body", -9))
	if w < 0 or w >= view.layout.bodies.size():
		return -9
	return w if SystemLayout.is_star(view.layout.bodies[w].host_id) else -9


## How far the ship reaches from its middle: what words, ring and partners keep clear of.
func ship_r() -> int:
	return 7 if hull_pic.is_empty() else int(hull_pic.R)


## How far over the ship YOU is written (its baseline): 13 over the old arrow,
## and over a longer hull pointing straight up, clear of its nose.
func you_up() -> int:
	return maxi(13, ship_r() + 5)


func _draw_ship(t: float) -> void:
	if flight == null:
		return
	var rel := ship_rel()
	var x: Vector2 = (Vector2(view.CX, view.CY) + view.pan + rel).round()
	var p3: Vector3 = flight.where3()
	# WARPING IN: the streak behind it as it drops onto its orbit
	if t - float(flight.warp_t) < 0.6:
		var w: float = t - flight.warp_t
		if w >= 0.0:
			for k in int(80.0 * (1.0 - w / 0.6)):
				_px(x + Vector2(k, 0), Color(UITheme.ICE, 0.7 * (1.0 - k / 80.0)))
	_last_rel = rel
	# ON THE ORBIT AS DRAWN: its offset from its world scaled as the ring is
	if _ok > 1.001 and SystemLayout.is_place(_ok_body):
		var bw := _body_scr(_ok_body)
		x = (bw + (x - bw) * _ok).round()
	_draw_trail(x, flight.orbit_body())
	_ship_at = x
	# HIDDEN BEHIND what stands in front of it: the star's disc (either sun's,
	# of two), a nearer world's
	var my_depth: float = view.depth(Vector2(p3.x, p3.z))
	var occ: Array = _star_occ(Vector2(p3.x, p3.z))
	# On a small world's tight ring the ship sat on the disc, so it is drawn over its own
	# world all the way round, outlined, and the camera never moves on its own.
	# Why: docs/why/SystemOverlay.md#ship-drawing
	var own_w := ringed_world()
	for i: int in view._views:
		if i == own_w:
			continue
		var b: SystemLayout.Body = view.layout.bodies[i]
		if view.depth(view.pos[i]) > my_depth:
			occ.append([view.at[i], view.draw_r(b)])
	# (every pixel of the hull and its own dark outline, hidden or not: the light
	# outline goes round the whole shape and is hidden where the hull would be)
	var shape := {}
	var cf: float = float(catch_light.get("f", 0.0))
	var cdir := Vector2.ZERO
	if cf > 0.0:
		cdir = ((catch_light.at as Vector2) - x).normalized()
	if record_px:
		ship_px = []
	var pic := _hull_pic()
	# YOUR HULL, turned to the step nearest the nose (`MapHull`), or the old
	# arrow where there is no hull picture to draw
	var ang: float = flight.ang if pic.is_empty() else MapHullS.bin_angle(MapHullS.bin_of(flight.ang))
	var c := cos(ang)
	var s := sin(ang)
	var P := func(u: float, v: float, col: Color, what: StringName) -> void:
		var q := (x + Vector2(u * c - v * s, u * s + v * c)).round()
		if own_w >= 0 and (what == &"hull" or what == &"outline"):
			shape[Vector2i(q)] = true
		for o: Array in occ:
			if q.distance_to(o[0]) < float(o[1]):
				return
		_px(q, col)
		if record_px:
			ship_px.append([q, col, what])
	# where the engines burn from, the rows either side of their middle and the
	# middle (the column of each that the hull's outline ends on), and the nose
	var ev := 0
	var stern: Array = [-4, -4, -4]
	var nose: Array = [5, 5, 5]
	if pic.is_empty():
		var in_hull := func(u: int, v: int) -> bool:
			return u >= -3 and u <= 6 and absf(v) <= (6 - u) * 0.5
		for u in range(-4, 8):
			for v in range(-4, 5):
				if not in_hull.call(u, v) and (in_hull.call(u - 1, v) or in_hull.call(u + 1, v) or in_hull.call(u, v - 1) or in_hull.call(u, v + 1)):
					P.call(u, v, MapHullS.OUTLINE, &"outline")
		for u in range(-3, 7):
			for v in range(-4, 5):
				if in_hull.call(u, v):
					var hc: Color = Color.WHITE if u > 3 else (UITheme.CHILL if absi(v) >= 2 else UITheme.ICE)
					if cf > 0.0:
						# the hull's edge facing the flash, lit toward its colour, never white
						var nl := Vector2.ZERO
						for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if not in_hull.call(u + o.x, v + o.y):
								nl += Vector2(o)
						if nl != Vector2.ZERO:
							var ns := Vector2(nl.x * c - nl.y * s, nl.x * s + nl.y * c).normalized()
							if ns.dot(cdir) > 0.5:
								hc = hc.lerp(catch_light.col as Color, 0.5 * cf)
					P.call(u, v, hc, &"hull")
	else:
		ev = int(pic.ev)
		stern = pic.stern
		nose = pic.nose
		var tp: Dictionary = MapHullS.turned(pic, MapHullS.bin_of(flight.ang))
		var offs: PackedVector2Array = tp.o
		var cols: PackedColorArray = tp.c
		var nrm: PackedVector2Array = tp.n
		var hulls: PackedFloat32Array = tp.hull
		for i in offs.size():
			var q := x + offs[i]
			if own_w >= 0:
				shape[Vector2i(q.round())] = true
			var hid := false
			for o: Array in occ:
				if q.distance_to(o[0]) < float(o[1]):
					hid = true
					break
			if hid:
				continue
			var hc := cols[i]
			# the hull's edge facing the flash, lit toward its colour, never white
			if cf > 0.0 and nrm[i] != Vector2.ZERO and nrm[i].dot(cdir) > 0.5:
				hc = Color(hc.lerp(catch_light.col as Color, 0.5 * cf * hulls[i]), hc.a)
			_px(q, hc)
			if record_px:
				ship_px.append([q, hc, &"hull" if hulls[i] > 0.0 else &"outline"])
	# Light outline is drawn under the drive, so its glow and flame still show.
	if own_w >= 0:
		var rim := {}
		for k: Vector2i in shape:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not shape.has(k + d):
					rim[k + d] = true
		for k: Vector2i in rim:
			var q := Vector2(k)
			var hid := false
			for o: Array in occ:
				if q.distance_to(o[0]) < float(o[1]):
					hid = true
					break
			if hid:
				continue
			_px(q, RING_OUTLINE)
			if record_px:
				ship_px.append([q, RING_OUTLINE, &"rim"])
	# Blue ion drive so flying in a system reads as the drive,
	# not the warp; LOCAL's flames are their own.
	var o0: int = stern[0]
	var o1: int = stern[1]
	var o2: int = stern[2]
	P.call(o0, ev - 1, ION_CORE, &"glow")
	P.call(o2, ev + 1, ION_CORE, &"glow")
	P.call(o0 - 1, ev - 1, ION_TIP if int(t * 20.0) % 2 == 1 else ION_CORE, &"glow")
	P.call(o2 - 1, ev + 1, ION_TIP if int(t * 20.0 + 1) % 2 == 1 else ION_CORE, &"glow")
	if flight.burn:
		# THE FLAME, out of the back whichever way the nose points: as long and
		# as bright as the burn (brighter as it lights), flickering a pixel or two
		var bk: float = clampf(flight.burn_k, 0.25, 1.6)
		var fl2 := int(t * 30.0) % 3
		var ln := int(4.0 + 8.0 * bk) + (fl2 - 1)
		for k in range(1, ln + 1):
			var fade := 1.0 - float(k) / float(ln + 1)
			var tip := float(k) / float(ln)
			var al := minf(1.0, (0.35 + 0.45 * bk) * fade + (0.25 if k <= 2 else 0.0))
			var col: Color = ION_CORE.lerp(ION_TIP, tip)
			P.call(o0 - k, ev - 1, Color(col, al), &"flame")
			P.call(o2 - k, ev + 1, Color(col, al), &"flame")
			if k <= 3 + int(bk * 3.0):
				P.call(o1 - k, ev, Color(col, minf(1.0, al * 1.1)), &"flame")
	if flight.rcs:
		var fl := int(t * 20.0) % 2
		var n0: int = 7 if pic.is_empty() else nose[0] + 1
		var n2: int = 7 if pic.is_empty() else nose[2] + 1
		P.call(n0 + fl, -1, Color(ION_TIP, 0.8), &"rcs")
		P.call(n2 + (1 - fl), 1, Color(ION_TIP, 0.8), &"rcs")
	# THE RING when it is settled (arrived, or stopped); in orbit the orbit is it
	var settled: bool = flight.mode == &"warp"
	if settled:
		var rr := float(ship_r()) + 4.0 + sin(t * 2.4) * 1.5
		for k in range(0, 40, 2):
			var an := float(k) / 40.0 * TAU
			_px(x + Vector2(cos(an) * rr, sin(an) * rr * 0.8), Color(UITheme.FLARE, 0.75))
	# Off the picture its edge arrow says YOU, so YOU over the hull would say it twice.
	var on: int = flight.orbit_body()
	var first := _ship_words_first(x)
	var off_pic: bool = not _win_in(2.0).has_point(x)
	if first.is_empty():
		if not off_pic:
			_label(x + Vector2(-8, -you_up()), "YOU", UITheme.FLARE, 1, false)
	else:
		var words: String = first[0]
		var lx: float = (first[1] as Vector2).x
		var ly: float = (first[1] as Vector2).y
		# The ship's words keep off a binary's suns and, where a spot clears both, off an event's
		# beacon too. In a star's close orbit 46 of 90 twins had them across the other sun.
		# Why: docs/why/SystemOverlay.md#words-off-suns
		var sun: bool = names_on and _meets_sun(Vector2(lx, ly), words)
		var clear_of := &""
		# Words go back to their first spot only when clear by WORDS_BACK_PX, or they hopped
		# 16 px down, up and down again in 4 s.
		# Why: docs/why/SystemOverlay.md#words-off-suns
		var was: Array = _spot_mem.get("ship", [])
		var grow := WORDS_BACK_PX if was.size() == 4 and was[0] == words else 0.0
		# Words are not cut by the frame: ones that would be are dropped, as the edge arrow
		# and the status line already say YOU.
		# Why: docs/why/SystemOverlay.md#words-off-suns
		var cut: bool = names_on and not _win_in(0.0).encloses(_words_box(Vector2(lx, ly), words))
		var stepped: bool = grow > 0.0 and names_on and (_meets_sun(Vector2(lx, ly), words, -99, grow) \
			or (view.layout.twin and not _clear_of_beacons(words, [], grow).call(Vector2(lx, ly))) \
			or not _win_in(grow).encloses(_words_box(Vector2(lx, ly), words)))
		var on_beacon: bool = names_on and view.layout.twin and not _clear_of_beacons(words).call(Vector2(lx, ly))
		if off_pic and not _win_in(NavField.EDGE_FADE).encloses(_words_box(Vector2(lx, ly), words)):
			words = ""
		elif sun or stepped or on_beacon or cut:
			var spot := _words_off_suns(words, on, x)
			if spot.is_empty() and sun:
				_held_q.append(words)
				words = ""
			elif spot.is_empty() and cut:
				words = ""
			elif spot.is_empty() and on_beacon:
				_on_beacon_q.append(words)
				clear_of = &"suns"
			elif spot.is_empty():
				# (within the margin of what they stepped off, and no spot: where
				# they first stand, which clears it)
				pass
			else:
				lx = (spot[0] as Vector2).x
				ly = (spot[0] as Vector2).y
				words = spot[1]
				clear_of = spot[2]
		if not names_on:
			if not off_pic:
				_label(x + Vector2(-8, -you_up()), "YOU", UITheme.FLARE, 1, false)
		elif words != "":
			_label(Vector2(lx, ly), words, UITheme.FLARE, 4, true)
			_ship_words_q = {"says": words, "at": Vector2(lx, ly), "clear": clear_of}


## The window is never a negative Rect2, whose has_point and encloses log errors (Nov 5 gate).
## Why: docs/why/SystemOverlay.md#words-off-suns
func _win_in(m: float) -> Rect2:
	var r: Rect2 = (view.window as Rect2).abs().grow(-m)
	r.size = r.size.max(Vector2.ZERO)
	return r


func _ship_words_first(x: Vector2) -> Array:
	var ob: int = flight.reached()
	var on: int = flight.orbit_body()
	var words := ""
	if SystemLayout.is_place(ob):
		words = ("CLOSE ORBIT · " if SystemLayout.is_star(ob) else ("ALONGSIDE · " if flight.mode == &"keep" else "IN ORBIT · ")) + _place_nm(ob)
	elif SystemLayout.is_place(on) and flight.mode == &"rail" and flight.rail.has("phase"):
		words = "LEAVING ORBIT · " + _place_nm(on)
	elif SystemLayout.is_place(on) and flight.mode == &"keep" and flight.keep.has("hold"):
		# (holding alongside to leave: it said YOU, the flight already drawn)
		words = "LEAVING · " + _place_nm(on)
	elif SystemLayout.is_place(on) and flight.inserting():
		words = ("COMING ALONGSIDE · " if flight.mode == &"keep" else "ENTERING ORBIT · ") + _place_nm(on)
	elif flight.star_orbiting():
		words = "ORBITING " + _settle_nm(_settle_id())
	if words == "":
		return []
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var lc := x
	var ly := x.y + maxf(17.0, ship_r() + 11.0)
	if SystemLayout.is_place(on):
		var bw := _body_scr(on)
		var rr := _orbit_px(on, _orbit_r(on)) * _ok / maxf(_orbit_k(on, _orbit_r(on)), 1.0)
		var disc: float = star_disc(on) if SystemLayout.is_star(on) else (_reach(on) - 7.0)
		lc = bw
		ly = bw.y + maxf(rr * view.TILT, disc) + 13.0
	var lx := clampf(lc.x - roundf(tw / 2.0), view.window.position.x + 4.0, view.window.end.x - tw - 4.0)
	return [words, Vector2(lx, ly)]


## Past this distance stepped words would read as another place's.
const WORDS_STEP_MOST := 40.0
## and how far clear their first spot must be before words stepped off it go
## back (px, `_draw_ship`)
const WORDS_BACK_PX := 2.0


## Ring spots are tried before the ship's: tried all together, the words hopped between
## them about twice an orbit.
## Why: docs/why/SystemOverlay.md#words-off-suns
func _words_off_suns(words: String, on: int, x: Vector2) -> Array:
	var win: Rect2 = view.window
	var sayings: Array[String] = [words]
	if words.contains(" · "):
		sayings.append(words.get_slice(" · ", 0))
	# the spots' heights, and the middle they are centred on
	var c := x
	var under := x.y + maxf(17.0, ship_r() + 11.0)
	var over := x.y - float(you_up())
	var ticks: Array = []
	if SystemLayout.is_place(on):
		c = _body_scr(on)
		var rr := _orbit_px(on, _orbit_r(on)) * _ok / maxf(_orbit_k(on, _orbit_r(on)), 1.0)
		var disc: float = star_disc(on) if SystemLayout.is_star(on) else (_reach(on) - 7.0)
		under = c.y + maxf(rr * view.TILT, disc) + 13.0
		over = c.y - maxf(rr * view.TILT, disc) - 5.0
		if not _is_belt(on):
			ticks = reticle_boxes(_place_scr(on), _reach(on))
	var ship_y := x.y + maxf(17.0, ship_r() + 11.0)
	# the words queued under them this frame, each in its box as `_place_labels`
	# builds it
	var lower: Array = []
	for e: Array in _lq:
		if int(e[0]) < 4:
			var lw := _font().get_string_size(String(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
			lower.append(Rect2((e[1] as Vector2) + Vector2(-2, -10), Vector2(lw + 4, 14)))
	var tries: Array = []
	for clear_of: StringName in [&"all", &"marks", &"suns"]:
		for si in sayings.size():
			var s: String = sayings[si]
			var tw := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
			var at_x := clampf(c.x - roundf(tw / 2.0), win.position.x + 4.0, win.end.x - tw - 4.0)
			var ok := Callable()
			if clear_of != &"suns":
				ok = _clear_of_beacons(s, ticks + lower if clear_of == &"all" else ticks)
			tries.append(["%s:%d:ring" % [clear_of, si], [Vector2(at_x, under), Vector2(at_x, over)], [Vector2.DOWN, Vector2.UP], s, ok, clear_of])
			# (off a place, under the ring is under the ship already)
			if SystemLayout.is_place(on):
				var ship_x := clampf(x.x - roundf(tw / 2.0), win.position.x + 4.0, win.end.x - tw - 4.0)
				tries.append(["%s:%d:ship" % [clear_of, si], [Vector2(ship_x, ship_y)], [Vector2.DOWN], s, ok, clear_of])
	var got := _spot_kept("ship", words, tries)
	if got.is_empty():
		return []
	var tr: Array = got[1]
	if tr[5] == &"suns":
		_on_beacon_q.append(String(tr[3]))
	return [got[0], tr[3], tr[5]]


## Each kind of words' spot as last frame placed it, for `_spot_kept`.
var _spot_mem := {}
var _spot_seen := {}


## Stepped words keep last frame's spot while clear, as turning suns made them hop:
## placed afresh they moved 59 times, held 26 (TwinSiteTest).
## Why: docs/why/SystemOverlay.md#words-off-suns
func _spot_kept(key: String, words: String, tries: Array, but := -99) -> Array:
	var m: Array = _spot_mem.get(key, [])
	if m.size() == 4 and m[0] == words:
		for tr: Array in tries:
			if tr[0] == m[1]:
				var q := _spot_off_suns(tr[1], tr[2], tr[3], but, tr[4], int(m[2]), float(m[3]))
				if q != Vector2.INF:
					_spot_seen[key] = [words, tr[0], _spot_i, _spot_d]
					return [q, tr]
				break
	for tr: Array in tries:
		var q := _spot_off_suns(tr[1], tr[2], tr[3], but, tr[4])
		if q != Vector2.INF:
			_spot_seen[key] = [words, tr[0], _spot_i, _spot_d]
			return [q, tr]
	return []


## One nearest-clear-spot search serves the ship, selected name and forecast words;
## the forecast's WILL ORBIT sat across a sun in about half the coasts.
## Why: docs/why/SystemOverlay.md#words-off-suns
var _spot_i := -1
var _spot_d := 0.0


func _spot_off_suns(spots: Array, steps: Array, words: String, but := -99, ok := Callable(), only := -1, from_d := 0.0) -> Vector2:
	var win: Rect2 = view.window
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var d := from_d
	while d <= WORDS_STEP_MOST:
		for i in spots.size():
			if only >= 0 and i != only:
				continue
			var q: Vector2 = (spots[i] as Vector2) + (steps[i] as Vector2) * d
			if q.x < win.position.x + 4.0 - 0.01 or q.x + tw > win.end.x - 4.0 + 0.01:
				continue
			if q.y - 10.0 < win.position.y or q.y + 4.0 > win.end.y:
				continue
			if _meets_sun(q, words, but) or (ok.is_valid() and not bool(ok.call(q))):
				continue
			_spot_i = i
			_spot_d = d
			return q
		d += 2.0
	return Vector2.INF


## Status sits 6 px under the goal line, where the old 16 now collides with the goal.
const STATUS_AT := Vector2(10, 47)
## Its box from there: the words' height above the baseline, and the line.
const STATUS_UP := 10.0
const STATUS_H := 12.0


## The ship's status line's box for `words`, in the overlay's own space.
func status_rect(words: String) -> Rect2:
	var tw := UITheme.pixel_font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	return Rect2(view.window.position + STATUS_AT - Vector2(0, STATUS_UP), Vector2(tw, STATUS_H))


## WHAT THE MAP SAYS ABOUT THE SHIP, top left: in orbit, alongside, too fast,
## sliding in, leaving.
func ship_status() -> Array:
	var L: SystemLayout = view.layout
	if flight == null:
		return ["", UITheme.CHILL]
	var t: float = view.t
	var nm := func(b: int) -> String: return _place_nm(b)
	# where a flight is going: a star's close orbit (THE STAR with one sun; with
	# two, which of them), or a place by name
	var to := func(b: int) -> String:
		if SystemLayout.is_star(b):
			return "TO A CLOSE ORBIT OF " + (star_name_of(b) if L.twin else "THE STAR")
		return "TO " + nm.call(b)
	match flight.mode:
		&"fly":
			return [to.call(flight.fly_to), UITheme.CHILL]
		&"rail":
			var b := int(flight.rail.body)
			if flight.rail.has("phase"):
				return ["LEAVING ORBIT · " + to.call(flight.fly_to), UITheme.CHILL]
			if flight.inserting():
				return ["ENTERING ORBIT · " + nm.call(b), UITheme.HOT]
			return ["CLOSE ORBIT · " + nm.call(b) if SystemLayout.is_star(b) else "IN ORBIT · " + nm.call(b), UITheme.FLARE]
		&"keep":
			if flight.inserting():
				return ["COMING ALONGSIDE · " + nm.call(int(flight.keep.body)), UITheme.HOT]
			# HOLDING ALONGSIDE TO LEAVE (`FlightSolve`'s KEEP_HOLD, or while the
			# flight is planned): on its way, as riding round a ring to leave is
			if flight.keep.has("hold"):
				return ["LEAVING · " + to.call(flight.fly_to), UITheme.CHILL]
			return ["ALONGSIDE · " + nm.call(int(flight.keep.body)), UITheme.FLARE]
		&"free":
			if flight.star_orbiting():
				return ["ORBITING " + _settle_nm(_settle_id()), UITheme.FLARE]
			if flight.f.no_cap_left > 0.0:
				return ["LEAVING ORBIT", UITheme.CHILL]
			if t - flight.fast_t < 0.6:
				return ["TOO FAST TO ORBIT · SLOW DOWN", UITheme.HOT]
			if SystemLayout.is_place(flight.sticky):
				return ["WILL SLIDE INTO ORBIT · " + nm.call(flight.sticky), UITheme.HOT]
	return ["", UITheme.CHILL]


# ---------------------------------------------------------------- the tip
# The tip's words for what is pointed at, as [lines, chip colour], which a harness reads.
func tip_lines(h: Dictionary) -> Array:
	var L: SystemLayout = view.layout
	var lines: Array = []
	var chip := UITheme.ICE
	if h.kind == &"star":
		# EITHER STAR, by its own name and kind (star B, ruling 20); the star's
		# events are star A's (`star_beacons`: star B holds none)
		var sb := int(h.body)
		lines.append([star_name_of(sb), UITheme.ICE])
		lines.append([star_class_of(sb), UITheme.COLD])
		var ns := L.star_beacons.size() if sb == -1 else 0
		if ns > 0:
			var here_s: bool = flight != null and flight.reached() == -1
			lines.append(["%d %s · %s" % [ns, "EVENT" if ns == 1 else "EVENTS", "OPEN" if here_s else "OPEN IN A CLOSE ORBIT"], UITheme.EMBER])
		lines.append_array(_click_line(sb))
	elif h.kind == &"body" or h.kind == &"belt":
		var b := L.bodies[h.body]
		lines.append([b.name, UITheme.ICE])
		lines.append([view.body_kind(b), UITheme.COLD])
		if b.beacons.size() > 0:
			var here: bool = flight != null and flight.reached() == int(h.body)
			lines.append(["%d %s · %s" % [b.beacons.size(), "EVENT" if b.beacons.size() == 1 else "EVENTS", "OPEN" if here else ("OPEN ALONGSIDE" if b.kind == &"belt" or b.kind == &"station" else "OPEN IN ORBIT")], UITheme.EMBER])
		lines.append_array(_click_line(int(h.body)))
	elif h.kind == &"comet" and L.comet != null:
		lines.append([L.comet.name, UITheme.ICE])
		lines.append([CometPath.KIND, UITheme.COLD])
		lines.append([L.comet.status(float(view.t)), UITheme.QUOTE])
		if selected != SystemLayout.COMET:
			lines.append(["CLICK: SELECT", UITheme.QUOTE])
	else:
		if h.body >= 0:
			var b := L.bodies[h.body]
			lines.append([b.name, UITheme.ICE])
			lines.append([view.body_kind(b), UITheme.COLD])
		elif h.body == -1 and h.beacon != null:
			lines.append([star_name_of(-1), UITheme.ICE])
			lines.append([star_class_of(-1), UITheme.COLD])
		var bc = h.beacon
		if bc == null:
			lines.append([view.star_name(), UITheme.ICE])
			lines.append(["NEUTRON STAR · HARVEST", UITheme.TRACTOR])
		elif bc.opt >= 0:
			var o := option_of(bc)
			chip = EncounterDrawer.tag_colour(o)
			lines.append([String(o.get("title", "")).to_upper(), UITheme.HOT])
			lines.append([" · ".join((o.get("tags", []) as Array).map(func(x): return String(x).to_upper())), chip])
			for l in _wrap(_first_sentence(String(o.get("body", ""))), 34).slice(0, 3):
				lines.append([l, UITheme.CHILL])
			var sw := spent_word(bc)
			if not sw.is_empty():
				lines.append([sw[0], sw[1]])
		elif bc.dock:
			lines.append(["DOCK", UITheme.ICE])
			lines.append(["THE STATION'S DECKS", UITheme.CHILL])
		elif bc.core:
			chip = UITheme.BAD
			lines.append(["THE CUSTODIAN", UITheme.HOT])
			lines.append(["GUARDS THE CORE", UITheme.BAD])
		elif bc.hellbender:
			chip = UITheme.BAD
			lines.append(["THE HELLBENDER", UITheme.HOT])
			lines.append(["ANCHORED HERE" if Run.hellbender_alive() else "ITS WRECK", UITheme.BAD])
		lines.append_array(_click_line(int(h.body)))
	return [lines, chip]


func _draw_tip() -> void:
	var h := hover
	var tl := tip_lines(h)
	var lines: Array = tl[0]
	var chip: Color = tl[1]
	var f := _font()
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	w = ceilf(w) + 14.0
	var hgt := lines.size() * 11.0 + 8.0
	var at: Vector2 = h.at
	# sliding in and fading up with the hover, as the chart's tip does
	var slide := roundf((1.0 - _hover_t) * 5.0)
	var x := roundf(at.x + 12.0) + slide
	var y := roundf(at.y - 6.0)
	var win: Rect2 = view.window
	if x + w > win.end.x - 6:
		x = roundf(at.x - w - 12.0) - slide
	if y + hgt > win.end.y - 6:
		y = win.end.y - 6 - hgt
	y = maxf(y, win.position.y + 6)
	var al := maxf(0.15, _hover_t)
	tip_rect = Rect2(x, y, w, hgt)
	draw_rect(Rect2(x, y, w, hgt), Color(11 / 255.0, 17 / 255.0, 27 / 255.0, 0.94 * al))
	draw_rect(Rect2(x + 0.5, y + 0.5, w - 1.0, hgt - 1.0), Color(Color("#3c4c60"), al), false, 1.0)
	draw_rect(Rect2(x, y, 2, hgt), Color(chip, al))
	for k in lines.size():
		var lc: Color = lines[k][1]
		_text(Vector2(x + 8, y + 12 + k * 11), lines[k][0], Color(lc, lc.a * al))


## While a GO flies a click does nothing, so no line offers one.
func _click_line(body: int) -> Array:
	if flight != null and flight.reached() == body:
		return [["YOU ARE HERE", UITheme.FLARE]]
	if clicks_held:
		return [["ON YOUR WAY", UITheme.HOT]] if flight != null and flight.heading_to() == body else []
	if selected == body:
		if flight != null and flight.mode == &"fly" and flight.fly_to == body:
			return [["ON YOUR WAY", UITheme.HOT]]
		return [["CLICK AGAIN: FLY HERE", UITheme.HOT]]
	return [["CLICK: SELECT", UITheme.QUOTE]]


static func _first_sentence(s: String) -> String:
	var re := RegEx.create_from_string("^.*?[.!?](\\s|$)")
	var m := re.search(s)
	return m.get_string().strip_edges() if m != null else s


static func _wrap(text: String, n: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		if (line + " " + word).strip_edges().length() > n:
			out.append(line.strip_edges())
			line = word
		else:
			line += " " + word
	if line.strip_edges() != "":
		out.append(line.strip_edges())
	return out


# ---------------------------------------------------------------- what the pointer is over
# A body behind a sun is hidden there: its click circle covered the sun's middle,
# so 8 of 48 clicks on star B went to its world.
# Why: docs/why/SystemOverlay.md#click-hit-test
func _behind_sun(q: Vector2, p: Vector2) -> bool:
	var L: SystemLayout = view.layout
	for s: int in L.stars():
		if view.depth(q) < view.depth(L.star_pos(s, float(view.t))) and p.distance_to(star_scr(s)) <= star_disc(s):
			return true
	return false


## The suns, the one nearer the viewer first (`depth` where the pair has them at
## the view's t); star A first where they stand level, and with one sun.
func _suns_near_first() -> Array[int]:
	var out: Array[int] = view.layout.stars()
	if out.size() == 2 and view.depth(view.layout.star_pos(out[1], float(view.t))) > view.depth(view.layout.star_pos(out[0], float(view.t))):
		out.reverse()
	return out


## How near the comet's head a click must land (px): its coma is about this wide.
const COMET_HIT := 8.0

## The partners' ships, then the comet's marks: its reticle and name when selected, or
## the hover's reticle closing in.
func _draw_partners_and_comet(t: float) -> void:
	_draw_partners(t)
	var L: SystemLayout = view.layout
	var hk: StringName = hover.get("kind", &"")
	# THE COMET selected: the same reticle on its head and its name, while it passes
	if selected == SystemLayout.COMET:
		var cs: Vector2 = comet_scr()
		if cs != Vector2.INF:
			_reticle(cs, COMET_R, 1.0, 0.95)
			var cn: String = L.comet.name
			var cw := _font().get_string_size(cn, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
			var cx := cs.x + COMET_R + 4.0
			if cx + cw > view.window.end.x - 4.0:
				cx = cs.x - COMET_R - 4.0 - cw
			_name_label(Vector2(cx, cs.y + 3.0), cn, UITheme.ICE, 2, false)
	if hk == &"comet" and selected != SystemLayout.COMET and _hover_t > 0.0:
		var hc: Vector2 = comet_scr()
		if hc != Vector2.INF:
			_reticle(hc, COMET_R + (6.0 - 6.0 * _hover_t), _hover_t, 0.55)


## Where the comet's head is drawn, or INF while it is not in the system (`CometPath`).
func comet_scr() -> Vector2:
	var c: CometPath = view.layout.comet if view.layout != null else null
	if c == null or not c.here(float(view.t)):
		return Vector2.INF
	var p := c.pos(view.layout, float(view.t))
	return view.block_round(view.screen(p.x, p.y))


func hit(p: Vector2) -> Dictionary:
	for e in beacons_at:
		var at: Vector2 = e[0]
		if absf(p.x - at.x) <= 9.0 and absf(p.y - at.y) <= 9.0:
			return {"kind": &"beacon", "body": e[1], "beacon": e[2], "at": at}
	var L: SystemLayout = view.layout
	# the comet's head, while it is passing (`CometPath`)
	var cs: Vector2 = comet_scr()
	if cs != Vector2.INF and p.distance_to(cs) <= COMET_HIT:
		return {"kind": &"comet", "body": SystemLayout.COMET, "beacon": null, "at": cs}
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind == &"belt" or b.kind == &"contact":
			continue
		var at: Vector2 = view.at[i]
		if p.distance_to(at) <= maxf(view.draw_r(b), 4.0) + 3.0 and not _behind_sun(view.pos[i], p):
			return {"kind": &"body", "body": i, "beacon": null, "at": at}
	# A click where two suns overlap is on the sun drawn on top, the nearer.
	for s: int in _suns_near_first():
		var sc: Vector2 = star_scr(s)
		if p.distance_to(sc) <= maxf(8.0, star_disc(s)):
			return {"kind": &"star", "body": s, "beacon": null, "at": sc}
	# A belt is hit anywhere within its band, as it had no hit and only its beacon reached it.
	var rel: Vector2 = (p - view.origin()) / maxf(view.zoom, 0.0001)
	var plane := Vector2(rel.x, rel.y / view.TILT)
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind == &"belt" and absf((plane - b.host_at(float(view.t))).length() - b.orbit) < maxf(26.0, 5.0 / view.zoom):
			return {"kind": &"belt", "body": i, "beacon": null, "at": p}
	return {}
