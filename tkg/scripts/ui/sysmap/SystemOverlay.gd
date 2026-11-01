extends Node2D

## WHAT IS DRAWN OVER A SYSTEM'S PICTURE: the stations and derelicts, a beacon
## for every encounter, the selection, your ship and the hover tip -- the
## approved mockup's (scratchpad `sysmap/template.html`: `frame()`, `shipDraw`,
## `tip`) in the game's own colours and face.
##
## A beacon rides its body: a glyph for its lead tag in its tag's colour, a
## dotted stem down to the body, a ring pulsing out while it is open; spent, it
## stays put, dim, and says what it came to. Hovering a beacon in an exclusive
## group dims its rivals, joins them with a dashed line and marks each WILL
## BE MADE UNAVAILABLE (Jon's words, the same as the panel's cards); pointing
## at a card in the panel does the same here. Two beacons on one world stand
## side by side. Your ship warps in at the system's edge and is flown
## (`ShipFlight`, Jon's arcade orbits): WASD, the rings that take it into orbit,
## the dotted line of where it will end up, and the transfer orbit a second click
## flies. A place's beacons are lit only while you are in orbit of it or
## alongside it; until then they stand dim (Jon: "when orbiting a planet, that's
## when an event on a planet should become available").
##
## HOVER AS THE STAR CHART DOES (`StarchartScreen._draw_tip`): four corner ticks
## closing in on the thing as the hover eases in, the tip sliding in with it; the
## selection is the same reticle, closed and held. A belt is hovered as its whole
## band and brightens.

const GLYPH := {
	&"fight": ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
	&"hazard": ["..#..", ".#.#.", ".#.#.", "#...#", "#####"],
	&"salvage": ["##.##", "#...#", ".....", "#...#", "##.##"],
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
## A beacon lit from the panel: pointing at its card lights it here as pointing
## at it would (brackets, rivals dimmed and marked), without the tip. `linked`
## is the Beacon, or null with `link_body` -1 for the pulsar's own.
var link_on := false
var linked = null
var link_body := -2

## THE SHIP, flown (`ShipFlight`); the screen steps it, this draws it.
var flight
## A GO UNDER WAY (the screen's `_taking`): the map takes no click until it
## lands, so the tip offers none (only pressable things look pressable).
var clicks_held := false
var _ship_at := Vector2.ZERO
## YOUR OWN HULL, drawn at the map's scale (`MapHull`): the picture it is made
## from (`ShipView.hull_art`, the one LOCAL draws) and the map's picture of it,
## remade when the hull is swapped. {} (and the old arrow) with no hull art.
const MapHullS := preload("res://scripts/ui/sysmap/MapHull.gd")
var hull_src: Texture2D = null
var hull_pic: Dictionary = {}
var _hull_key: Array = []
## THE ION DRIVE'S COLOURS, two steps of the player's cold drive ramp
## (`ThrusterFx.COOL_RAMP`): the cool blue the flame leaves the stern in, and
## the paler blue it fades to at the tip. The ramp's deep blue was tried for
## the flame's edges and vanished against the map's blue nebulae.
const ION_CORE := Color("#5ea6ff")
const ION_TIP := Color("#bfe2ff")
## FOR THE HARNESSES (`-- sheet=MapShipTest`): every pixel of the ship drawn
## last frame, `[screen point, colour, &"hull" | &"outline" | &"rim" | &"glow" |
## &"flame" | &"rcs"]` (&"rim" the light outline on a binary's small world's
## ring, `ringed_world`), kept while `record_px` is on (headless draws nothing
## anyone can read back).
var record_px := false
var ship_px: Array = []
## THE LIGHT OUTLINE round the ship on the ring of a world that circles one sun
## of a binary (Jon, Nov 1, "ring:A"): 1 px of the ice the HUD draws in, outside
## the hull's own dark outline.
const RING_OUTLINE := UITheme.ICE
var _last_rel := Vector2.INF
## The hover easing in, as the chart's `_hover_t` (move_toward at 9 a second),
## from nothing again for each new thing pointed at.
var _hover_t := 0.0
var _hover_key := ""
## The flight a second click would fly, drawn before you fly it.
var preview_to := -9
## IN ORBIT OR NOT, AT A GLANCE (Jon: "it's hard to tell if I'm in an orbit or
## not"). In orbit the orbit is a solid ring the ship rides, never drawn smaller
## than the world's disc plus 9 px: at the opening zoom the ship's offset from
## its world is drawn scaled up by `_ok` (eased, so a capture never jumps), from
## `_ok_body`. A trail behind the ship; a pulse on capture; the ring left behind
## fading as you break away.
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
## and the plane point it circles (star A's origin with one sun: `_settle_c`)
var _star_c := Vector2.ZERO
var _preview: Array = []
var _preview_key := ""
var _preview_ms := 0.0
## THE PLAN DRAWN BEFORE IT IS FLOWN, held steady (Jon: "the predictive path
## updates every time the ship rotates around the planet"): from an orbit it is
## planned from the orbit itself (its departure point fixed on the ring), and
## replanned only when the place, the orbit or the state changes, or every 3 s
## to follow the worlds, keeping to the same choice; in free flight every half
## second. Each replan blends in over PV_BLEND s, point for point along the path.
## (1,600: at 320 a turn-round a few pixels across was cut into corners)
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
## THE PLAN DRAWN (`ShipFlight.FlightPlan`), which a click flies as it is while
## its departure is still ahead (`ShipFlight.fly_bg`), and the key it was asked
## for under: planned on a worker since ruling 20 (a twin's solved flight takes
## a median of 40 ms), so it comes in a few frames after it is asked for
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


## THE MAP'S WORDS, QUEUED and laid out last (Jon: "why do I get so much text
## here?"): each with a priority -- the orbit you are on 4, the forecast's 3,
## a selection's name and TOO FAST 2, YOU 1 -- placed highest first, and any
## that would overlap one already placed dropped. YOU is dropped too whenever a
## forecast or orbit label is near the ship.
var _lq: Array = []
## WHERE THE WORDS WENT last frame: the weather keeps its events off them
## (`SkyWeather.clear_at`)
var label_rects: Array = []
## and the words in each (a harness reads which is which)
var label_says: Array = []
## THE WORDS HELD BACK last frame to keep them off a binary's suns, where no
## spot cleared (`_spot_off_suns`): a harness tells them from words a higher
## label took the place of
var label_held: Array = []
var _held_q: Array = []
## A FLASH NEAR THE SHIP (`SkyWeather` `nearstrike`): its place on screen, its
## colour and how strong it is now ({} for none). The edge of the hull facing it
## catches its light for a moment; the outline stays.
var catch_light: Dictionary = {}


func _label(at: Vector2, s: String, c: Color, prio: int, shadow: bool) -> void:
	_lq.append([prio, at, s, c, shadow])


## HIDE NAMES (the map's toolbar, `SystemMapScreen._on_names`): the words that
## name a place -- the one selected, the orbit you are in or going to, where a
## flight will leave you -- held back; YOU and the flight's warnings stay.
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
				if int(_lq[k][0]) >= 3 and (placed[k] as Rect2).get_center().distance_to(_ship_at) < 160.0:
					hit = true
		if hit:
			placed.append(Rect2())
			continue
		placed.append(box)
		label_rects.append(box)
		label_says.append(s)
		if e[4]:
			_text(at + Vector2(1, 1), s, Color(Color("#05070b"), (e[3] as Color).a))
		_text(at, s, e[3])
	_lq.clear()


## WHETHER WORDS AT `at` WOULD BE WRITTEN ACROSS A SUN: their box, as
## `_place_labels` builds it, against the disc of each star of a pair but `but`
## (one sun has no other). The words a twin puts by a star or a selected name
## sat across the other sun about half the time at the opening zoom: the suns
## are 56 to 106 px apart there, and such words 140 to 230 px wide (the words
## review, Oct 31).
func _meets_sun(at: Vector2, words: String, but := -99) -> bool:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return false
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var box := Rect2(at + Vector2(-2, -10), Vector2(tw + 4, 14))
	for st: int in L.stars():
		if st == but:
			continue
		var c := star_scr(st)
		var near := Vector2(clampf(c.x, box.position.x, box.end.x), clampf(c.y, box.position.y, box.end.y))
		if near.distance_to(c) < star_disc(st):
			return true
	return false


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
			# (the wide orbit left behind, round what it circled: `_star_c`, kept
			# under that star's id, or -9 round both suns, so a capture into the
			# close orbit of the star it circled draws no fade, as with one sun)
			_left = {"body": _settle_id(_star_c), "r": _star_r * view.zoom, "t0": _clock(), "a": 0.35, "c": _star_c}
		elif sw > 0.0 and _star_r < 0.0:
			_pulse = {"body": -2, "t0": _clock()}
		_star_r = sw
		if sw > 0.0:
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
	if L == null:
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
				sx = view.screen(b.host.x + cos(a) * b.orbit, b.host.y + sin(a) * b.orbit).round()
			elif b.beacons.size() > 1:
				# TWO ON ONE WORLD STAND SIDE BY SIDE. They were drawn on the
				# same spot, so a world with two events showed one beacon and
				# the one underneath could not be pointed at or clicked.
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
		var so: Vector2 = view.origin()
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
		var hat: Vector2 = view.origin() + Vector2(14, -16)
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
				_text(g[0] + Vector2(-roundf(w / 2.0), -9), words, UITheme.WARN)
	# a card pointed at in the panel: its beacon bracketed, as the map's own
	# selection is
	if from_card:
		var c0: Vector2 = hv.at
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
			# NEVER ACROSS A SUN of a pair: the other side, else under the
			# reticle, else over it (on a flight to star B it lay over star A's
			# disc); then each a step further out (`_spot_off_suns`), the side
			# spots up or down. Where none clears, the name is held back: the
			# panel names what is selected. A world close to its sun kept its
			# name across that sun where both first tries met it (SIGMA
			# CINDER-2 II on seed 7, the picks review, Nov 1).
			if _meets_sun(at, nm, selected):
				var side2 := Vector2(s.x - r - 4.0 - tw if lx > s.x else s.x + r + 4.0, s.y + 3.0)
				var cx := clampf(s.x - roundf(tw / 2.0), view.window.position.x + 4.0, view.window.end.x - tw - 4.0)
				var under := Vector2(cx, s.y + r + 12.0)
				var over := Vector2(cx, s.y - r - 5.0)
				at = _spot_off_suns([side2, under, over, at, at, side2],
					[Vector2.UP, Vector2.DOWN, Vector2.UP, Vector2.UP, Vector2.DOWN, Vector2.DOWN], nm, selected)
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
	_draw_partners(t)
	view.tick("overlay ship", t_ship)
	_place_labels()
	# WHAT THE SHIP IS DOING, top left of the frame, under the goal and its step
	var st := ship_status()
	if String(st[0]) != "":
		_text(view.window.position + STATUS_AT, st[0], st[1])
	if not hover.is_empty():
		_draw_tip()


# ---------------------------------------------------------------- the reticle
## The drawn edge of a place, and the reticle's reach out from it.
func _reach(body: int) -> float:
	var L: SystemLayout = view.layout
	if SystemLayout.is_star(body):
		return star_disc(body) + 7.0
	if not SystemLayout.is_place(body):
		# (-9, both suns' balance point: no disc there)
		return 7.0
	return view.draw_r(L.bodies[body]) + 7.0


# ---------------------------------------------------------------- the stars
## STAR p ON SCREEN (-1 star A, the star; `SystemLayout.STAR_B` star B of two
## suns, ruling 20): where its disc is drawn, on the block grid as `origin()`
## puts star A. The view says where it draws star B (`SystemView.star_screen`)
## once it does; until then it is worked out the same way, since star B holds
## still at `star2_at`.
func star_scr(p: int) -> Vector2:
	if view.has_method(&"star_screen"):
		return view.call(&"star_screen", p)
	var L: SystemLayout = view.layout
	if p == SystemLayout.STAR_B and L != null and L.twin:
		return view.block_round(view.screen(L.star2_at.x, L.star2_at.y))
	return view.origin()


## How big star p's disc is drawn (its radius on screen, px): the view's own
## size for it (`SystemView.star_disc`) once it says, else star A's as it was
## always read here and star B's at the floor the map eases a sun up to
## (`SystemLayout.sun_drawn`, a block or so off the held size).
func star_disc(p: int) -> float:
	if view.has_method(&"star_disc"):
		return float(view.call(&"star_disc", p))
	var L: SystemLayout = view.layout
	if p == SystemLayout.STAR_B and L != null and L.twin:
		return SystemLayout.sun_drawn(L.star2_r, view.zoom)
	return L.star_r * view.star_k()


## Where place p is drawn: a star's disc, or a body's place on the grid. (`at`
## is an Array, and `at[-4]` would quietly have been the fourth body from the
## end.)
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


## THE INSERTION A CAPTURE AT `body` WILL FLY (the ship at `rel` from it,
## moving `rv` relative to it): `ShipFlight.insert_plan` as `start_rail` makes
## it, cleared against the very star it is onto. Drawn with star A's keep-out
## for a twin's star B, bigger by 0.4 to 1.5 px where B's rail is 2 px clear,
## the curl drawn was up to 58 px off the one flown, 961 of 1,666 captures at
## star B (the seams review, Oct 31).
func capture_ins(body: int, rel: Vector2, rv: Vector2) -> Dictionary:
	var rt: float = flight.orbit_r(body)
	var dir := 1.0 if rel.x * rv.y - rel.y * rv.x >= 0.0 else -1.0
	var spd: float = flight.STAR_RAIL_V if SystemLayout.is_star(body) else flight.RAIL_V
	var star := SystemLayout.is_star(body)
	return flight.insert_plan(rel, rv, rt, dir * spd / rt, null if star else view.layout.bodies[body], Vector2.ZERO, body if star else -1)


## A place's name: a star's, or a body's.
func _place_nm(p: int) -> String:
	return star_name_of(p) if SystemLayout.is_star(p) else view.layout.bodies[p].name


## THE CENTRE OF THE WIDE STAR ORBIT the ship is settled on (plane): star A at
## the origin as it always was, or, in a pair, whatever the flight settles round
## (the nearer star or both suns' balance point): the flight's own settle
## centre, `ShipFlight.f.cen` (`_settle_centre`). It is read by name, since a
## flight without a pair's settle has no such field and settles round star A.
func _settle_c() -> Vector2:
	if flight != null and flight.has_method(&"star_orbit_c"):
		return flight.call(&"star_orbit_c")
	if flight != null and flight.f != null:
		var c = flight.f.get("cen")
		if c is Vector2:
			return c
	return Vector2.ZERO


## WHAT THE WIDE ORBIT ROUND `c` CIRCLES, as a place id: -1 star A (the one
## star), `SystemLayout.STAR_B` star B, -9 both suns. The flight says which
## (`ShipFlight.f.cen_id`) while it is settled round `c`; else it is told by
## where `c` is.
func _settle_id(c: Vector2) -> int:
	var L: SystemLayout = view.layout
	if L == null or not L.twin:
		return -1
	if flight != null and flight.f != null and flight.star_orbiting():
		var id = flight.f.get("cen_id")
		var fc = flight.f.get("cen")
		if id is int and fc is Vector2 and (fc as Vector2).distance_to(c) < 1.0:
			return id
	if c.distance_to(Vector2.ZERO) < 1.0:
		return -1
	if c.distance_to(L.star2_at) < 1.0:
		return SystemLayout.STAR_B
	return -9


## What a wide orbit round `c` circles, named: a star, or BOTH STARS round the
## pair (it was BOTH SUNS: "Let's call it Binary instead of two suns", Nov 1;
## the panel's AROUND row says the same, `SystemView.host_line`).
func _settle_nm(c: Vector2) -> String:
	var id := _settle_id(c)
	return "BOTH STARS" if id == -9 else star_name_of(id)


## The stars' discs a point on the plane is behind, as [screen centre, radius]:
## what hides a ship (yours, a partner's) or the far half of an orbit. A point
## is behind a star where it is further from the viewer (`depth`), as it was
## behind the one star at the origin.
func _star_occ(q: Vector2) -> Array:
	var out: Array = []
	var d: float = view.depth(q)
	for s: int in view.layout.stars():
		if d < view.depth(view.layout.star_pos(s)):
			out.append([star_scr(s), star_disc(s)])
	return out


## StarchartScreen's reticle: four corner ticks, 3 px, in white.
func _reticle(at: Vector2, reach: float, k: float, alpha: float) -> void:
	var c := Color(1, 1, 1, alpha * k)
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
			if _left.has("c"):
				# a wide orbit left: round what it circled, behind that star's disc
				# if it was one (round both, -9, there is no disc at its middle)
				var lc: Vector2 = _left.c
				lw = _scr(lc.x, lc.y)
			else:
				lw = _body_scr(lb)
			_ring(lw, float(_left.r), Color(UITheme.FLARE, float(_left.get("a", 0.8)) * (1.0 - age2 / 0.9)), lb, true)


## THE STAR ORBIT of plane radius r: faint all round, bright for a stretch either
## side of plane point `by` (the ship); `k` fades it, `arc_only` draws the stretch.
## Round `_star_c`: star A at the origin with one sun; in a pair, the star or
## the balance point the flight settles round, its far half behind either sun.
func _star_orbit(r: float, by: Vector2, k: float, arc_only: bool) -> void:
	var c := _star_c
	var o: Vector2 = view.origin() if c == Vector2.ZERO else view.block_round(view.screen(c.x, c.y))
	var rp: float = r * view.zoom
	var a0 := atan2(by.y - c.y, by.x - c.x)
	var disc: float = view.layout.star_r * view.star_k()
	var two: bool = view.layout.twin
	# (each sun as [its plane z, its disc's centre on screen, its radius])
	var suns: Array = []
	if two:
		for s: int in view.layout.stars():
			suns.append([view.layout.star_pos(s).y, star_scr(s), star_disc(s)])
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
## WHERE YOU WILL END UP (`ShipFlight.predict`): the coast, to the ring it slides
## into and round the orbit you will be on, with TOO FAST and BUMP where they
## happen; with a key held, a fainter line for keeping it held. A flight shows
## what is left of it; a selected place, the flight a second click would fly.
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
		# THE FLIGHT BEING FLOWN (or ridden round to, or held alongside for, or
		# its last burn onto the place): what is left of it -- faded when
		# another place is chosen, its flight drawn over it. Round a settled
		# star orbit its ride is the plan's first samples, not drawn: the line
		# starts where it leaves, as it was drawn
		if _fly_line_plan != flight.plan:
			_fly_line_plan = flight.plan
			_fly_line = _plan_line(flight.plan, true)
		var u := 0.0
		if flight.mode == &"fly" or arriving:
			u = clampf((t - flight.fly_t0) / flight.plan.dur, 0.0, 1.0)
		u = maxf(u, float(flight.plan.u_dep))
		_draw_line3(_fly_line[0], _fly_line[1], 1.0, _fly_line[2], u, flight.plan)
	# FLYING BY HAND (a key held, or let go of a moment ago): only where you are
	# going is drawn, never a plan replanned from under you (Jon: "why does the
	# predicted orbit act so weird")
	# ONLY OUT OF AN ORBIT does a click fly (`ShipFlight.can_fly`), so only then
	# is its flight drawn: not on the way, not burning onto an orbit, not under
	# thrust or settling
	var by_hand: bool = flight.mode == &"free" and t - float(flight.thrust_t) < 1.0
	var can: bool = flight.can_fly() and not by_hand
	# A NEW SHIP (another system shown, or this one again): nothing drawn for the
	# last one carries over. Its clock starts again at 0 and the arrival orbit's
	# key is the same every visit, so a preview from an earlier visit could pass
	# as this one's and, its time ahead of the clock, never be planned again
	# (the flight review, Oct 31)
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
		var key := "%d:%d:%d:%s" % [preview_to, flight.orbit_body() if in_orbit else -9, roundi(float(flight.rail.get("rt", 0.0))) if in_orbit else 0, flight.mode]
		# PLANNED AGAIN: round a ring every 3 s to check it holds (its choice
		# rebuilds the very flight while its departure is ahead), alongside or
		# round a star orbit every second (DESIGN: a departure from there is
		# only kept while its hold lasts), and as its departure comes up (the
		# drawn flight then gives way to the one after it)
		var every := 3.0 if in_orbit else 1.0
		# (today's planner, the fallback, is made on the worker ahead as a solved
		# flight is, and kept the same way; made for the moment only, every 2 s
		# at the least, as before)
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
			# STALE (another place chosen, or the ship off what it was planned
			# from, or its departure gone by while it was made): dropped, and asked
			# for again
			if pl != null and int(got.i) == preview_to and _pv_req_key == key and not flight._takeable(pl, t).is_empty():
				var was_same: bool = _pv_plan != null and int(_pv_plan.to) == preview_to
				# A SOLVED FLIGHT IS DRAWN AS IT IS, never blended in: the line on
				# screen is the flight a click flies. Blended over PV_BLEND from
				# the last, it was another flight for that half second, a fifth of
				# the time a preview showed (the flight review, Oct 31); the same
				# flight planned again is the same line point for point, so the
				# blend only ever showed a flight that had changed. Today's
				# planner's made for the moment only still blend, as they did.
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
			# FROM THE SHIP WHERE IT IS NOW: in open space today's planner's plan
			# starts at the ship, which moves on between replans, so the line's
			# start is eased onto it over the first stretch, not left behind it. A
			# solved flight's line starts where it leaves the star orbit, ahead of
			# the ship, as round a ring: eased onto the ship it was not the flight
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


## A WHOLE FLIGHT LAID OUT ALONG ITS LENGTH: PV_N points at even distances along
## it (the escape, the coast, the insertion after), whether the engine burns at
## each, and how far through the flight each is (`ShipFlight.lay_out`, made on
## the worker with the plan when it was asked for so, `plan_bg`'s `lay`).
func _plan_line(pl, _with_u: bool) -> Array:
	if (pl.line as Array).size() == 3 and (pl.line[0] as PackedVector3Array).size() == PV_N:
		return pl.line
	return flight.lay_out(pl, PV_N)


## A LAID-OUT FLIGHT, DOTTED: projected point by point, a smooth curve through
## them, a dot every 3 px of it -- in the burn's colour where the engine burns,
## ice on the coast; from `u0` of the flight on. `pl`, the plan it is: its ends
## drawn at its rings' drawn size (`_drawn_ends`).
## HIDDEN BEHIND what stands in front of it, as the ship is: a sun's disc, a
## nearer world's. Dotted over everything, a flight's line ran across a sun's
## face where it passed behind it -- a quarter of a twin's flights at the
## opening zoom, up to 26 px of it, the ship itself hidden on that stretch --
## and over nearer worlds (the seen review, Oct 31). Each dot goes by the point
## of the flight it is on.
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


## WHAT CAN STAND IN FRONT OF A POINT ON THE PLANE, as [screen centre, drawn
## radius, depth]: each sun's disc and each world drawn. `_hidden` is the rule
## `_draw_ship` and `_draw_partners` keep (`_star_occ`, nearer worlds).
func _occluders() -> Array:
	var out: Array = []
	var L: SystemLayout = view.layout
	for st: int in L.stars():
		out.append([star_scr(st), star_disc(st), view.depth(L.star_pos(st))])
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


## A SOLVED FLIGHT'S ENDS AT ITS RINGS' DRAWN SIZE: a ring is drawn bigger than
## life to read (`_orbit_k`), and the ship on it drawn out with it (`_ok`, on
## its spring: easing to life size as it leaves, to the ring's size as it burns
## on), while its line was laid at life size. At a twin's worlds round one
## star (a ring of 4 to 5 px drawn at about 10) the line began and ended on the
## world's face and the ship rode 3.5 to 8.9 px off it at each end (the seen
## review, Oct 31). Each point is drawn off its place as the ship will be drawn
## there at its moment: the departure's spring from the plan's start, the
## arrival's from its burn (`ShipFlight._arrive_t`). The moments and places are
## worked out once a plan (`_ends_table`); the sizes, which go with the zoom,
## every frame. Today's planner's lines, and a one-sun or giant system's (where
## a ring is drawn its own size), are as laid out.
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
		return L.star_pos(i) if SystemLayout.is_star(i) else _flat3(flight.center(i, tt))
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


## A SMOOTH CURVE THROUGH POINTS ON SCREEN (Jon: "why is this path so lumpy?"):
## a Catmull-Rom spline walked about a pixel at a time -- its points, the
## distance walked to each, and the stretch of the input each is in -- so dots
## and dashes can be laid at even distances along it rather than between
## sparse corners.
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


## How much bigger than life an orbit is drawn: never closer to the world's disc
## than ORBIT_MIN_PX, so it reads round a 5 px world at the opening zoom; in a
## pair, never further out than fits there (`_orbit_cap`).
func _orbit_k(body: int, r: float) -> float:
	return orbit_floor_k(r * view.zoom, _reach(body) - 7.0, _orbit_cap(body))


## (static, so a harness can measure it for every pair without a map) An orbit
## of `r_px` round a disc of `disc` px, drawn out to the disc + ORBIT_MIN_PX but
## no further than `cap` px; never smaller than it is.
static func orbit_floor_k(r_px: float, disc: float, cap: float) -> float:
	var want := minf(maxf(r_px, disc + ORBIT_MIN_PX), maxf(cap, r_px))
	return maxf(1.0, want / maxf(r_px, 0.01))


## HOW FAR OUT AN ORBIT ROUND `body` MAY BE DRAWN in a pair (ruling 20), px. The
## floor above drew a star's close orbit at its disc + 9 px, about 19 px at a
## twin's opening zoom, where it rides 12.5 to 13 px out, and that cut into the
## disc of the star's own world; and it drew a ship riding a world round a star
## at the world's disc + 9 px, where it rides about 5 px out, across its sun's
## disc every lap. Measured at fit_zoom over the 470 stars of seed 4242's twins
## (TwinSiteTest): 454 close orbits drawn into their world's disc (5 outside
## its orbit altogether) and 454 world orbits onto their sun. So in a twin:
##   - a star's close orbit stops 2 px short of the disc of each world round
##     that star, where the world stands widest from it on screen;
##   - an orbit round a world that goes round one star stops 2 px short of that
##     star's disc there.
## Neither is ever drawn smaller than it is. With the cap, 0 and 0, and the
## least room left between a close orbit as drawn and its sun is 1.84 px. One
## sun: no cap (INF), since its close orbit (ring - 8, 87 px) and its worlds are
## far wider than the floor. (The tilt brings both nearer above and below the
## star, where a world passes in front of and behind its sun anyway.)
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


## A place's centre on screen. A star's from the layout: both hold still, star
## A at the origin and star B at `star2_at`.
func _body_scr(body: int) -> Vector2:
	if SystemLayout.is_star(body):
		var sp: Vector2 = view.layout.star_pos(body)
		return _scr(sp.x, sp.y)
	var c: Vector3 = flight.center(body, view.t)
	return _scr(c.x, c.z)


## A ring round a place, flattened as the plane is: solid, or dashed 4 on 3 off.
## Its far half goes behind the place's disc.
func _ring(w: Vector2, r: float, col: Color, body: int, dashed: bool) -> void:
	var disc := _reach(body) - 7.0
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
		if sin(an) < 0.0 and q.distance_to(w) < disc:
			continue
		_px(q.round(), col)


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
	for fr: Dictionary in ln.fast:
		var at: Vector2 = fr.at
		_label(_scr(at.x, at.y) + Vector2(5, -4), "TOO FAST", Color(UITheme.HOT, minf(1.0, a * 1.6)), 2, true)
	var bp: Vector2 = ln.bump
	if bp != Vector2.INF:
		_label(_scr(bp.x, bp.y) + Vector2(5, -4), "BUMP", Color(UITheme.TRACTOR, minf(1.0, a * 1.6)), 2, true)
	var o: Dictionary = ln.out
	if o.is_empty():
		return
	var path := PackedVector2Array()
	for q0 in ln.pts:
		path.append(_scr(q0.x, q0.y))
	if o.kind == &"star":
		# SETTLING ROUND THE STAR: the stretch of that orbit where it settles, dashed
		# (round what it settles round: star A at the origin, or in a pair the
		# centre the flight's settle gives, `out.c`)
		var sr: float = o.r
		var sc0: Vector2 = o.get("c", Vector2.ZERO)
		var sat: Vector2 = (o.at as Vector2) - sc0
		var st0 := atan2(sat.y, sat.x)
		var arc := PackedVector2Array()
		var so: Vector2 = view.origin() if sc0 == Vector2.ZERO else view.block_round(view.screen(sc0.x, sc0.y))
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
	# (a star's centre from the layout: star B holds still at `star2_at`)
	var c: Vector3 = Vector3(L.star_pos(body).x, 0.0, L.star_pos(body).y) if SystemLayout.is_star(body) else flight.center(body, float(o.t))
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
		# THE ORBIT YOU WILL BE ON, round where its world will be when you get
		# there: the line curls in from where the ring takes you onto it, as the
		# rail eases you in, and goes round it, dashed
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


## THE WORDS FOR WHERE THE LINE ENDS, on a shadow and clear of the line: under
## the ring (`half` its half-height round `at`), on the side away from where the
## path comes in; failing that centred, or over it, or on the other side.
## NEVER ACROSS A SUN of a binary (`_meets_sun`): a spot clear of the line that
## meets one is passed over; where the one it falls back on meets one, each spot
## a step further out (`_spot_off_suns`), clear of the line, else not; else the
## words are held back (the ring and the reticle still show the place). Coasting
## into OMEGA CALLOUS I's ring on seed 7, WILL ORBIT OMEGA CALLOUS I sat across
## star A in every frame; over 40 binaries a seed about half the forecasts
## crossed a sun (the picks review, Nov 1). One sun: as it always was.
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
	for p: Vector2 in spots:
		if clear.call(p) and not _meets_sun(p.round(), tag):
			pick = p
			break
	pick = pick.round()
	if _meets_sun(pick, tag):
		var near: Array = spots.map(func(p: Vector2) -> Vector2: return p.round())
		var steps := [Vector2.DOWN, Vector2.DOWN, Vector2.UP, Vector2.UP, Vector2.DOWN]
		pick = _spot_off_suns(near, steps, tag, -99, clear)
		if pick == Vector2.INF:
			pick = _spot_off_suns(near, steps, tag)
		if pick == Vector2.INF:
			if names_on:
				_held_q.append(tag)
			return
	_name_label(pick, tag, Color(UITheme.HOT, minf(1.0, a * 1.8)), 3, true)


# ---------------------------------------------------------------- the party
## Each partner's ship as last drawn: `[[peer id, screen point], ...]`.
var partner_at: Array = []
## Where each partner is drawn on the plane, eased toward its last report so a
## ship reported six times a second flies rather than steps.
var _partner_plane: Dictionary = {}
var _partner_ms: int = 0
## AND ON AN ORBIT, AT THE ORBIT'S DRAWN SIZE, as your own ship is (`_ok`): by
## partner, [the place it is drawn off, how much bigger than life], eased. At
## its true offset a partner riding with you round a twin's world round one
## star sat on the world's disc, 5 px off the ring as drawn (the seams review).
var _partner_kb: Dictionary = {}

## THE PARTY ON THE MAP: the small arrow your own ship was before it was your
## hull, in the party's colour, with its pilot's name (Oct 22 playtest:
## partners were never drawn here). A partner sitting where you are -- two
## ships that jumped in together arrive on the same point -- is drawn a ship's
## length off, in formation, never on top of you: as far below as your hull
## reaches (`ship_r`), and a row more for each partner after.
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
	var k := 1.0 - exp(-dt * 8.0)
	var row := 0
	for e: Array in scr.partner_points():
		var id: int = e[0]
		var want: Vector2 = e[1]
		var q: Vector2 = _partner_plane.get(id, want)
		# a jump across the system is a new place, not a flight to it
		var jumped := q.distance_to(want) > 400.0
		q = want if jumped else q.lerp(want, k)
		_partner_plane[id] = q
		var pb: int = int(e[4]) if e.size() > 4 else -10
		var want_k := 1.0
		var kb: Array = _partner_kb.get(id, [pb, -1.0])
		if SystemLayout.is_place(pb):
			var cp: Vector2 = view.layout.star_pos(pb) if SystemLayout.is_star(pb) else _flat3(flight.center(pb, view.t))
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
		partner_at.append([id, x])
		# HIDDEN BEHIND what stands in front of it, as your own ship is: the
		# star's disc (either sun's, of two), a nearer world's (the first stills
		# had a partner in close orbit drawn across the face of the star)
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
		# The name UNDER the ship, where YOU (over yours) cannot meet it when
		# the two sit side by side, and at priority 0: placed last, so it gives
		# way to every word the map already had, and outside YOU's own rule
		# (priority 1, dropped near your orbit's words), under which every
		# partner's name went whenever you were in orbit. Not for a ship wholly
		# behind the star.
		if shown > 0:
			_label(x + Vector2(-8, 17), String(e[3]), UITheme.GOOD, 0, true)


# ---------------------------------------------------------------- the ship
## Where the ship is relative to the star on screen: LOCATION follows exactly this.

func ship_rel() -> Vector2:
	if flight == null:
		return Vector2.ZERO
	var p: Vector3 = flight.where3()
	return Vector2(p.x, p.z * view.TILT) * view.zoom


## A place relative to the star on screen, for LOCATION holding a world you orbit
## and a right-click holding a place. Star B is where it holds still
## (`star2_at`); star A, and anything that is not a place, the origin.
func place_rel(body: int) -> Vector2:
	if SystemLayout.is_star(body) and view.layout != null:
		var sp: Vector2 = view.layout.star_pos(body)
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


## THE WORLD WHOSE RING THE SHIP RIDES, where that world circles one sun of a
## binary (on its rail: in orbit, burning onto it or riding round to leave); -9
## anywhere else, a world round both suns and every one-sun system included.
## There the ship is drawn over that world all the way round, outlined
## (`_draw_ship`, `RING_OUTLINE`).
func ringed_world() -> int:
	if flight == null or view == null or view.layout == null or not view.layout.twin or flight.mode != &"rail":
		return -9
	var w := int(flight.rail.get("body", -9))
	if w < 0 or w >= view.layout.bodies.size():
		return -9
	return w if SystemLayout.is_star(view.layout.bodies[w].host_id) else -9


## HOW FAR THE SHIP REACHES from its middle, whichever way it points (px): what
## the words round it, the ring and a partner in formation keep clear of. The
## old arrow's was 7.
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
	var ob: int = flight.reached()
	_draw_trail(x, flight.orbit_body())
	_ship_at = x
	# HIDDEN BEHIND what stands in front of it: the star's disc (either sun's,
	# of two), a nearer world's
	var my_depth: float = view.depth(Vector2(p3.x, p3.z))
	var occ: Array = _star_occ(Vector2(p3.x, p3.z))
	# ON THE RING OF A WORLD ROUND ONE SUN OF A BINARY (Jon, Nov 1, "ring:A"):
	# that world is small and its ring tight, so at the opening zoom the ship sat
	# on it (its middle on the disc for a quarter of the lap and up to all of it,
	# TwinDrawTest), and on the far side the world hid part of the hull. It is
	# drawn over its own world all the way round, in a 1 px light outline
	# (`RING_OUTLINE`), so the hull reads on any world and the camera never moves
	# on its own. Every other world and either sun still hides it.
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
	# THE LIGHT OUTLINE on its own world's ring (above): each pixel beside the
	# shape and not in it, hidden as the hull is; under the drive, so its glow
	# and flame still show
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
	# THE DRIVE, AN ION DRIVE (Jeremy: blue engines on the map, so flying in a
	# system reads as the drive and not the warp): the old flame's shape and
	# motion in the player's cold drive ramp (`ThrusterFx.COOL_RAMP`), a cool
	# blue core and a paler tip. LOCAL's and the fight's flames are their own.
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
	# WHAT IT IS DOING, by the ship itself: in orbit, alongside, a close orbit
	# (which says which ship well enough: YOU would sit on the ring)
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
		words = "ORBITING " + _settle_nm(_star_c)
	if words == "":
		_label(x + Vector2(-8, -you_up()), "YOU", UITheme.FLARE, 1, false)
	else:
		var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var lc := x
		var ly := x.y + maxf(17.0, ship_r() + 11.0)
		if SystemLayout.is_place(on):
			# UNDER THE RING it names, centred on its place (under the ship it sat
			# on the world when zoomed in)
			var bw := _body_scr(on)
			var rr := _orbit_px(on, _orbit_r(on)) * _ok / maxf(_orbit_k(on, _orbit_r(on)), 1.0)
			var disc: float = star_disc(on) if SystemLayout.is_star(on) else (_reach(on) - 7.0)
			lc = bw
			ly = bw.y + maxf(rr * view.TILT, disc) + 13.0
		var lx := clampf(lc.x - roundf(tw / 2.0), view.window.position.x + 4.0, view.window.end.x - tw - 4.0)
		# NEVER ACROSS A SUN of a binary (`_words_off_suns`). In a star's close
		# orbit they sat across the other one, 46 of 90 twins; on the ring of a
		# world round star A at the opening zoom, under the ring, above it and
		# under the ship all crossed a sun (OMEGA CALLOUS REACH on seed 7, Nov 1:
		# the suns 76 px apart, the words 136 px wide)
		if names_on and _meets_sun(Vector2(lx, ly), words):
			var spot := _words_off_suns(words, on, x)
			if spot.is_empty():
				_held_q.append(words)
				words = ""
			else:
				lx = (spot[0] as Vector2).x
				ly = (spot[0] as Vector2).y
				words = spot[1]
		if not names_on:
			_label(x + Vector2(-8, -you_up()), "YOU", UITheme.FLARE, 1, false)
		elif words != "":
			_label(Vector2(lx, ly), words, UITheme.FLARE, 4, true)


## HOW FAR WORDS MAY STEP OFF THEIR PLACE to clear a sun (px; the ship's, a
## selected name, the let-go forecast's, `_spot_off_suns`): past this they
## would read as another place's.
const WORDS_STEP_MOST := 40.0


## WHERE THE WORDS BY THE SHIP GO CLEAR OF A BINARY'S SUNS (`_meets_sun`), as
## [their baseline's left end, the words], or [] where nothing clears. The spots
## the words always tried, in their order: under the ring they name (under the
## ship off a ring), above it, under the ship. Then each of those a step further
## out, 2 px at a time to `WORDS_STEP_MOST`, the nearest first. Then the same for
## the words before their " · " alone (IN ORBIT, CLOSE ORBIT, ALONGSIDE: the
## status line at the frame's top left still names the place). Where nothing
## clears, the words are held back, as `_place_labels` holds back words that
## would sit on others, and the status line says them.
func _words_off_suns(words: String, on: int, x: Vector2) -> Array:
	var win: Rect2 = view.window
	var sayings: Array[String] = [words]
	if words.contains(" · "):
		sayings.append(words.get_slice(" · ", 0))
	# the spots' heights, and the middle they are centred on
	var c := x
	var under := x.y + maxf(17.0, ship_r() + 11.0)
	var over := x.y - float(you_up())
	if SystemLayout.is_place(on):
		c = _body_scr(on)
		var rr := _orbit_px(on, _orbit_r(on)) * _ok / maxf(_orbit_k(on, _orbit_r(on)), 1.0)
		var disc: float = star_disc(on) if SystemLayout.is_star(on) else (_reach(on) - 7.0)
		under = c.y + maxf(rr * view.TILT, disc) + 13.0
		over = c.y - maxf(rr * view.TILT, disc) - 5.0
	var ship_y := x.y + maxf(17.0, ship_r() + 11.0)
	for s: String in sayings:
		var tw := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var at_x := clampf(c.x - roundf(tw / 2.0), win.position.x + 4.0, win.end.x - tw - 4.0)
		var ship_x := clampf(x.x - roundf(tw / 2.0), win.position.x + 4.0, win.end.x - tw - 4.0)
		var q := _spot_off_suns([Vector2(at_x, under), Vector2(at_x, over), Vector2(ship_x, ship_y)],
			[Vector2.DOWN, Vector2.UP, Vector2.DOWN], s)
		if q != Vector2.INF:
			return [q, s]
	return []


## THE NEAREST SPOT CLEAR OF A BINARY'S SUNS for `words` (`_meets_sun`, every
## star but `but`): each of `spots` as it is, in its order, then each moved on
## along its own `steps` 2 px at a time to `WORDS_STEP_MOST`, the nearest first.
## Their box, as `_place_labels` builds it, inside the frame, and passing `ok`
## where one is given (the let-go forecast's words clear of its path). Vector2.INF
## where none clears. The ship's words (`_words_off_suns`), a selected place's
## name and the forecast's (`_label_clear`) all step out this way: the forecast's
## WILL ORBIT <world> sat across a sun in about half the coasts into a binary's
## rings at the opening zoom, and a selected world close to its sun had its name
## across that sun on every side it tried (the picks review, Nov 1).
func _spot_off_suns(spots: Array, steps: Array, words: String, but := -99, ok := Callable()) -> Vector2:
	var win: Rect2 = view.window
	var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var d := 0.0
	while d <= WORDS_STEP_MOST:
		for i in spots.size():
			var q: Vector2 = (spots[i] as Vector2) + (steps[i] as Vector2) * d
			if q.x < win.position.x + 4.0 - 0.01 or q.x + tw > win.end.x - 4.0 + 0.01:
				continue
			if q.y - 10.0 < win.position.y or q.y + 4.0 > win.end.y:
				continue
			if _meets_sun(q, words, but) or (ok.is_valid() and not bool(ok.call(q))):
				continue
			return q
		d += 2.0
	return Vector2.INF


## Where the ship's status is written (its words' baseline) from the frame's top
## left: under the goal line and its step (`GoalLine`, at the picture's top left
## since Jon's Oct 20 ruling; 4 px in, two 13 px lines and 1 between), 6 px clear
## of them. It was 16, where the goal now stands.
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
				return ["ORBITING " + _settle_nm(_settle_c()), UITheme.FLARE]
			if flight.f.no_cap_left > 0.0:
				return ["LEAVING ORBIT", UITheme.CHILL]
			if t - flight.fast_t < 0.6:
				return ["TOO FAST TO ORBIT · SLOW DOWN", UITheme.HOT]
			if SystemLayout.is_place(flight.sticky):
				return ["WILL SLIDE INTO ORBIT · " + nm.call(flight.sticky), UITheme.HOT]
	return ["", UITheme.CHILL]


# ---------------------------------------------------------------- the tip
## THE TIP'S WORDS for what is pointed at (`hit`), as [lines, chip colour]: each
## line [words, colour]. What `_draw_tip` draws, and what a harness reads.
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
	draw_rect(Rect2(x, y, w, hgt), Color(11 / 255.0, 17 / 255.0, 27 / 255.0, 0.94 * al))
	draw_rect(Rect2(x + 0.5, y + 0.5, w - 1.0, hgt - 1.0), Color(Color("#3c4c60"), al), false, 1.0)
	draw_rect(Rect2(x, y, 2, hgt), Color(chip, al))
	for k in lines.size():
		var lc: Color = lines[k][1]
		_text(Vector2(x + 8, y + 12 + k * 11), lines[k][0], Color(lc, lc.a * al))


## What a click on this place will do: select it, fly there (a second click on
## the selection), or nothing, being there already; as the tip's lines, one or
## none. While a GO flies (`clicks_held`) a click does nothing, so no line offers
## one: its place is ON YOUR WAY, and the rest say nothing of clicking.
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
## A BODY AT PLANE POINT q IS HIDDEN AT SCREEN POINT p by a sun in front of it,
## whose disc p is on. In a pair a world round one star passes 6 to 8 px from
## its sun's middle at the far side of its circle, behind the disc, and its
## click circle covered the sun's middle there (the review: on ZETA HOLLOW-4,
## seed 4242, 8 of 48 clicks on star B over one turn went to its world). A
## click on the sun you see is on the sun: TwinSiteTest puts each star's world
## just behind its middle, and on its own turn where it is behind (2 and 3 of 48
## on LAMBDA CALLOUS SECUNDUS), and every click is the sun's. One sun's
## innermost world never comes that near.
func _behind_sun(q: Vector2, p: Vector2) -> bool:
	var L: SystemLayout = view.layout
	for s: int in L.stars():
		if view.depth(q) < view.depth(L.star_pos(s)) and p.distance_to(star_scr(s)) <= star_disc(s):
			return true
	return false


func hit(p: Vector2) -> Dictionary:
	for e in beacons_at:
		var at: Vector2 = e[0]
		if absf(p.x - at.x) <= 9.0 and absf(p.y - at.y) <= 9.0:
			return {"kind": &"beacon", "body": e[1], "beacon": e[2], "at": at}
	var L: SystemLayout = view.layout
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind == &"belt" or b.kind == &"contact":
			continue
		var at: Vector2 = view.at[i]
		if p.distance_to(at) <= maxf(view.draw_r(b), 4.0) + 3.0 and not _behind_sun(view.pos[i], p):
			return {"kind": &"body", "body": i, "beacon": null, "at": at}
	# EITHER STAR, at its own place and drawn size (star B, ruling 20: -4)
	for s: int in L.stars():
		var sc: Vector2 = star_scr(s)
		if p.distance_to(sc) <= maxf(8.0, star_disc(s)):
			return {"kind": &"star", "body": s, "beacon": null, "at": sc}
	# A BELT IS ITS BAND: anywhere within the band's width of its orbit, all the
	# way round (it had no hit at all, so it could only be reached by its beacon);
	# round its own centre, which in a pair is the balance point
	var rel: Vector2 = (p - view.origin()) / maxf(view.zoom, 0.0001)
	var plane := Vector2(rel.x, rel.y / view.TILT)
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind == &"belt" and absf((plane - b.host).length() - b.orbit) < maxf(26.0, 5.0 / view.zoom):
			return {"kind": &"belt", "body": i, "beacon": null, "at": p}
	return {}
