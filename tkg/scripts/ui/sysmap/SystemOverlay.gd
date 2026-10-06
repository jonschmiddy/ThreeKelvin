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
## The body selected (-1: the star; -2: nothing).
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
var _ship_at := Vector2.ZERO
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
var _pv_b0 := -99.0
var _pv_choice: Dictionary = {}
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
## A FLASH NEAR THE SHIP (`SkyWeather` `nearstrike`): its place on screen, its
## colour and how strong it is now ({} for none). The edge of the hull facing it
## catches its light for a moment; the outline stays.
var catch_light: Dictionary = {}


func _label(at: Vector2, s: String, c: Color, prio: int, shadow: bool) -> void:
	_lq.append([prio, at, s, c, shadow])


func _place_labels() -> void:
	_lq.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	var placed: Array = []
	label_rects = []
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
		if e[4]:
			_text(at + Vector2(1, 1), s, Color(Color("#05070b"), (e[3] as Color).a))
		_text(at, s, e[3])
	_lq.clear()


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string(_font(), at.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, c)


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
	if bc.core:
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
			if _was >= -1:
				_left = {"body": _was, "r": _orbit_px(_was, _orbit_r(_was)), "t0": _clock(), "a": 0.8}
			if now >= -1:
				_pulse = {"body": now, "t0": _clock()}
			_was = now
		var sw: float = flight.f.orbit_r if flight.star_orbiting() else -1.0
		if sw < 0.0 and _star_r > 0.0:
			_left = {"body": -1, "r": _star_r * view.zoom, "t0": _clock(), "a": 0.35}
		elif sw > 0.0 and _star_r < 0.0:
			_pulse = {"body": -2, "t0": _clock()}
		_star_r = sw
		var on: int = flight.orbit_body()
		if on >= -1:
			_ok_body = on
		# ON A SPRING, so the drawn ship's motion has no step when it starts or stops
		var want := 1.0 if on < -1 else _orbit_k(on, _orbit_r(on))
		_ok_v += (OK_W * OK_W * (want - _ok) - 2.0 * OK_W * _ok_v) * d
		_ok += _ok_v * d
		if on < -1 and absf(_ok - 1.0) < 0.002 and absf(_ok_v) < 0.01:
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
				var a: float = b.phase + t / b.period * TAU + k * 0.9
				sx = view.screen(cos(a) * b.orbit, sin(a) * b.orbit).round()
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
	if selected >= -1:
		var s: Vector2 = view.origin() if selected == -1 else view.at[selected]
		var b: SystemLayout.Body = null if selected == -1 else L.bodies[selected]
		if b == null or b.kind != &"belt":
			var r := _reach(selected)
			_reticle(s, r, 1.0, 0.95)
		# in orbit of it, the label under the ship names it instead (the two sat on
		# top of each other)
		if (b == null or b.kind != &"belt") and (flight == null or flight.reached() != selected):
			var r := _reach(selected)
			var nm: String = view.star_name() if b == null else b.name
			var tw := _font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
			var lx := s.x + r + 4.0
			if lx + tw > view.window.end.x - 4.0:
				lx = s.x - r - 4.0 - tw
			_label(Vector2(lx, s.y + 3.0), nm, UITheme.ICE, 2, false)
	# THE HOVER: the same reticle, closing in from 13 px to 7 px as it eases in
	var hk: StringName = hover.get("kind", &"")
	if (hk == &"body" or hk == &"star") and int(hover.body) != selected and _hover_t > 0.0:
		var hs: Vector2 = view.origin() if int(hover.body) == -1 else view.at[int(hover.body)]
		_reticle(hs, _reach(int(hover.body)) + (6.0 - 6.0 * _hover_t), _hover_t, 0.55)
	var t_paths := Time.get_ticks_usec()
	_draw_paths(t)
	view.tick("overlay paths", t_paths)
	var t_ship := Time.get_ticks_usec()
	_draw_ship(t)
	view.tick("overlay ship", t_ship)
	_place_labels()
	# WHAT THE SHIP IS DOING, top left of the frame
	var st := ship_status()
	if String(st[0]) != "":
		_text(view.window.position + Vector2(10, 16), st[0], st[1])
	if not hover.is_empty():
		_draw_tip()


# ---------------------------------------------------------------- the reticle
## The drawn edge of a place, and the reticle's reach out from it.
func _reach(body: int) -> float:
	var L: SystemLayout = view.layout
	if body == -1:
		return L.star_r * view.star_k() + 7.0
	return view.draw_r(L.bodies[body]) + 7.0


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
	if ob < -1 and flight.mode == &"rail" and flight.rail.has("phase"):
		ob = flight.orbit_body()
	if ob >= -1:
		var bw := _body_scr(ob)
		_ring(bw, _orbit_px(ob, _orbit_r(ob)) * _ok / maxf(_orbit_k(ob, _orbit_r(ob)), 1.0), Color(UITheme.FLARE, 0.95), ob, false)
		if selected != ob and not _is_belt(ob):
			_reticle(view.origin() if ob == -1 else view.at[ob], _reach(ob), 1.0, 0.95)
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
			_ring(_body_scr(int(_left.body)), float(_left.r), Color(UITheme.FLARE, float(_left.get("a", 0.8)) * (1.0 - age2 / 0.9)), int(_left.body), true)


## THE STAR ORBIT of plane radius r: faint all round, bright for a stretch either
## side of plane point `by` (the ship); `k` fades it, `arc_only` draws the stretch.
func _star_orbit(r: float, by: Vector2, k: float, arc_only: bool) -> void:
	var o: Vector2 = view.origin()
	var rp: float = r * view.zoom
	var a0 := atan2(by.y, by.x)
	var disc: float = view.layout.star_r * view.star_k()
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
		var skip := (arc_only and near <= 0.0) or not win.has_point(q) or (sin(an) < 0.0 and q.distance_to(o) < disc)
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
		var previewing: bool = preview_to >= -1 and flight.orbit_body() != preview_to and t - float(flight.thrust_t) >= 1.0 and flight.can_fly()
		if not previewing and not (flight.hold_line as Dictionary).is_empty():
			_line(flight.hold_line, 0.22, t, false)
		if not (flight.line as Dictionary).is_empty():
			_line(flight.line, 0.25 if previewing else 0.55, t, not previewing)
	elif flight.plan != null and (flight.mode == &"fly" or (flight.mode == &"rail" and flight.rail.has("phase"))):
		# THE FLIGHT BEING FLOWN (or ridden round to): what is left of it --
		# faded when another place is chosen, its flight drawn over it
		if _fly_line_plan != flight.plan:
			_fly_line_plan = flight.plan
			_fly_line = _plan_line(flight.plan, true)
		var u := 0.0
		if flight.mode == &"fly":
			u = clampf((t - flight.fly_t0) / flight.plan.dur, 0.0, 1.0)
		_draw_line3(_fly_line[0], _fly_line[1], 1.0, _fly_line[2], u)
	# FLYING BY HAND (a key held, or let go of a moment ago): only where you are
	# going is drawn, never a plan replanned from under you (Jon: "why does the
	# predicted orbit act so weird")
	# ONLY OUT OF AN ORBIT does a click fly (`ShipFlight.can_fly`), so only then
	# is its flight drawn: not on the way, not burning onto an orbit, not under
	# thrust or settling
	var by_hand: bool = flight.mode == &"free" and t - float(flight.thrust_t) < 1.0
	var can: bool = flight.can_fly() and not by_hand
	if not can:
		_preview_key = ""
		_pv_new = PackedVector3Array()
		_pv_old = PackedVector3Array()
	if preview_to >= -1 and can and flight.orbit_body() != preview_to:
		var in_orbit: bool = flight.mode == &"rail" and not flight.inserting()
		var key := "%d:%d:%d:%s" % [preview_to, flight.orbit_body() if in_orbit else -9, roundi(float(flight.rail.get("rt", 0.0))) if in_orbit else 0, flight.mode]
		var every := 3.0 if in_orbit else 0.5
		var slow: bool = _preview_ms > 30.0
		if slow:
			every = maxf(every, 2.0)
		if key != _preview_key or t - _pv_at > every:
			var same := key == _preview_key
			_preview_key = key
			_pv_at = t
			var t0 := Time.get_ticks_usec()
			var pl = flight.make_plan(preview_to, t, _pv_choice if same else {})
			_preview_ms = float(Time.get_ticks_usec() - t0) / 1000.0
			if pl != null:
				_pv_choice = pl.choice
				var ln: Array = _plan_line(pl, false)
				_pv_old = _pv_blend() if same and _pv_new.size() == PV_N else PackedVector3Array()
				_pv_new = ln[0]
				_pv_lit = ln[1]
				_pv_b0 = _clock() if not _pv_old.is_empty() else -99.0
		if _pv_new.size() == PV_N:
			var pvl := _pv_blend()
			# FROM THE SHIP WHERE IT IS NOW: in open space it moves on between
			# replans (half a second apart), so the line's start is eased onto it
			# over the first stretch, not left behind it
			if flight.mode == &"free":
				var off: Vector3 = flight.where3() - pvl[0]
				if off.length() > 0.5:
					var step := maxf(pvl[1].distance_to(pvl[0]), 0.01)
					var m := clampi(roundi(maxf(60.0, off.length() * 3.0) / step), 8, PV_N / 4)
					var eased := PackedVector3Array(pvl)
					for j in m:
						var x := float(j) / float(m)
						eased[j] = pvl[j] + off * (1.0 - x * x * (3.0 - 2.0 * x))
					pvl = eased
			_draw_line3(pvl, _pv_lit, 1.0, PackedFloat32Array(), 0.0)


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
## each, and (`with_u`) how far through the flight each is.
func _plan_line(pl, with_u: bool) -> Array:
	var dense := PackedVector3Array()
	var lit := PackedByteArray()
	var us := PackedFloat32Array()
	var n: int = pl.samp.size()
	for j in range(0, n, 1):
		dense.append(pl.samp[j])
		lit.append(1 if pl.burns[j] == 1 else 0)
		us.append(float(j) / float(maxi(n - 1, 1)))
	for q in pl.tail:
		dense.append(q)
		lit.append(1)
		us.append(1.0)
	var cum := PackedFloat32Array()
	cum.resize(dense.size())
	var tot := 0.0
	for j in dense.size():
		if j > 0:
			tot += dense[j].distance_to(dense[j - 1])
		cum[j] = tot
	var pts := PackedVector3Array()
	var lits := PackedByteArray()
	var uu := PackedFloat32Array()
	var j2 := 0
	for k in PV_N:
		var dk := tot * float(k) / float(PV_N - 1)
		while j2 < dense.size() - 2 and cum[j2 + 1] < dk:
			j2 += 1
		var seg := maxf(cum[j2 + 1] - cum[j2], 0.0001) if dense.size() > 1 else 1.0
		var f := clampf((dk - cum[j2]) / seg, 0.0, 1.0)
		pts.append(dense[j2].lerp(dense[mini(j2 + 1, dense.size() - 1)], f))
		lits.append(lit[j2])
		uu.append(lerpf(us[j2], us[mini(j2 + 1, us.size() - 1)], f))
	return [pts, lits, uu]


## A LAID-OUT FLIGHT, DOTTED: projected point by point, a smooth curve through
## them, a dot every 3 px of it -- in the burn's colour where the engine burns,
## ice on the coast; from `u0` of the flight on.
func _draw_line3(pts: PackedVector3Array, lit: PackedByteArray, k: float, us: PackedFloat32Array, u0: float) -> void:
	var sp := PackedVector2Array()
	var sl := PackedByteArray()
	for j in pts.size():
		if not us.is_empty() and us[j] < u0:
			continue
		sp.append(_scr(pts[j].x, pts[j].z))
		sl.append(lit[j])
	if sp.size() < 2:
		return
	var w := _spline(sp)
	var next := 0.0
	var wp: PackedVector2Array = w[0]
	var wd: PackedFloat32Array = w[1]
	var ws: PackedInt32Array = w[2]
	var was_on := false
	for j in wp.size():
		var on: bool = sl[ws[j]] == 1
		# A BURN MARKER where each real burn starts: a small plus, so a change of
		# course reads as a manoeuvre (only the burns the plan marks as real)
		if on and not was_on:
			var c0: Vector2 = wp[j].round()
			for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]:
				_px(c0 + d, Color(UITheme.HOT, 0.85 * k))
		was_on = on
		if wd[j] >= next:
			next += 3.0
			_px(wp[j].round(), Color(UITheme.FLARE, 0.85 * k) if on else Color(UITheme.ICE, 0.65 * k))


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
## than ORBIT_MIN_PX, so it reads round a 5 px world at the opening zoom.
func _orbit_k(body: int, r: float) -> float:
	var disc := _reach(body) - 7.0
	return maxf(1.0, (disc + ORBIT_MIN_PX) / maxf(r * view.zoom, 0.01))


## An orbit's drawn radius in screen pixels.
func _orbit_px(body: int, r: float) -> float:
	return r * view.zoom * _orbit_k(body, r)


func _is_belt(body: int) -> bool:
	return body >= 0 and view.layout.bodies[body].kind == &"belt"


## A place's centre on screen.
func _body_scr(body: int) -> Vector2:
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
		var base: Vector2 = view.origin() if b < -1 else _body_scr(b)
		var q: Vector2 = (base + (e[2] as Vector2) * view.zoom).round()
		var age := (now - float(e[0])) / TRAIL_S
		_px(q, Color(UITheme.FLARE if b >= -1 else UITheme.ICE, 0.55 * (1.0 - age)))
	if float(view.t) - float(flight.warp_t) < 0.6:
		return
	var base2: Vector2 = view.origin() if ob < -1 else _body_scr(ob)
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
		var sr: float = o.r
		var sat: Vector2 = o.at
		var st0 := atan2(sat.y, sat.x)
		var arc := PackedVector2Array()
		# from where the line ends, on along the orbit the way it goes (it began a
		# little behind, and the two met in a V)
		var dirn := signf(sat.x * (o.get("v", Vector2(0, 1)) as Vector2).y - sat.y * (o.get("v", Vector2(0, 1)) as Vector2).x) if o.has("v") else 1.0
		for j in 21:
			var an := st0 + dirn * 0.5 * float(j) / 20.0
			arc.append(view.origin() + Vector2(cos(an), sin(an) * view.TILT) * sr * view.zoom)
		_dashes_px(arc, Color(UITheme.FLARE, a * 0.9), false)
		return
	var body: int = o.body
	var nm: String = view.star_name() if body == -1 else L.bodies[body].name
	var tag: String
	var c: Vector3 = flight.center(body, float(o.t))
	var cw := _scr(c.x, c.z)
	var rel: Vector2 = o.rel
	var under := 0.0
	# the place it takes you to, its reticle held faintly
	if not _is_belt(body):
		_reticle(view.origin() if body == -1 else view.at[body], _reach(body), 1.0, a)
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
		var dir := 1.0 if rel.x * rv.y - rel.y * rv.x >= 0.0 else -1.0
		var spd: float = flight.STAR_RAIL_V if body == -1 else flight.RAIL_V
		# THE INSERTION AS THE SHIP WILL FLY IT (`ShipFlight.insert_plan`), its
		# offset drawn at the ring's scale
		var ins: Dictionary = flight.insert_plan(rel, rv, rt, dir * spd / rt, null if body == -1 else L.bodies[body])
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
	for sx in range(-10, 11, 3):
		for sy in range(-16, 9, 3):
			blocks.append(_ship_at + Vector2(sx, sy))
	var pick: Vector2 = cands[0]
	for cv: Vector2 in cands:
		var p := Vector2(clampf(cv.x, view.window.position.x + 4.0, view.window.end.x - tw - 4.0), cv.y)
		# the text's box, glyphs above its baseline, with a pixel or two round it
		var box := Rect2(p + Vector2(-2, -9), Vector2(tw + 4, 12))
		var hit := false
		for q in blocks:
			if box.has_point(q):
				hit = true
				break
		if not hit:
			pick = p
			break
	pick = pick.round()
	_label(pick, tag, Color(UITheme.HOT, minf(1.0, a * 1.8)), 3, true)


# ---------------------------------------------------------------- the ship
## Where the ship is relative to the star on screen: LOCATION follows exactly this.
func ship_rel() -> Vector2:
	if flight == null:
		return Vector2.ZERO
	var p: Vector3 = flight.where3()
	return Vector2(p.x, p.z * view.TILT) * view.zoom


## A place relative to the star on screen, for LOCATION holding a world you orbit.
func place_rel(body: int) -> Vector2:
	if body < 0 or flight == null:
		return Vector2.ZERO
	var c: Vector3 = flight.center(body, view.t)
	return Vector2(c.x, c.z * view.TILT) * view.zoom


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
	if _ok > 1.001 and _ok_body >= -1:
		var bw := _body_scr(_ok_body)
		x = (bw + (x - bw) * _ok).round()
	var ob: int = flight.reached()
	_draw_trail(x, flight.orbit_body())
	_ship_at = x
	# HIDDEN BEHIND what stands in front of it: the star's disc, a nearer world's
	var occ: Array = []
	var my_depth: float = view.depth(Vector2(p3.x, p3.z))
	if my_depth < 0.0:
		occ.append([view.origin(), view.layout.star_r * view.star_k()])
	for i: int in view._views:
		var b: SystemLayout.Body = view.layout.bodies[i]
		if view.depth(view.pos[i]) > my_depth:
			occ.append([view.at[i], view.draw_r(b)])
	var ang: float = flight.ang
	var c := cos(ang)
	var s := sin(ang)
	var P := func(u: float, v: float, col: Color) -> void:
		var q := (x + Vector2(u * c - v * s, u * s + v * c)).round()
		for o: Array in occ:
			if q.distance_to(o[0]) < float(o[1]):
				return
		_px(q, col)
	var in_hull := func(u: int, v: int) -> bool:
		return u >= -3 and u <= 6 and absf(v) <= (6 - u) * 0.5
	for u in range(-4, 8):
		for v in range(-4, 5):
			if not in_hull.call(u, v) and (in_hull.call(u - 1, v) or in_hull.call(u + 1, v) or in_hull.call(u, v - 1) or in_hull.call(u, v + 1)):
				P.call(u, v, Color("#05070b"))
	var cf: float = float(catch_light.get("f", 0.0))
	var cdir := Vector2.ZERO
	if cf > 0.0:
		cdir = ((catch_light.at as Vector2) - x).normalized()
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
				P.call(u, v, hc)
	P.call(-4, -1, UITheme.HOT)
	P.call(-4, 1, UITheme.HOT)
	P.call(-5, -1, UITheme.FLARE if int(t * 20.0) % 2 == 1 else UITheme.HOT)
	P.call(-5, 1, UITheme.FLARE if int(t * 20.0 + 1) % 2 == 1 else UITheme.HOT)
	if flight.burn:
		# THE FLAME, out of the back whichever way the nose points: as long and
		# as bright as the burn (brighter as it lights), flickering a pixel or two
		var bk: float = clampf(flight.burn_k, 0.25, 1.6)
		var fl2 := int(t * 30.0) % 3
		var ln := int(4.0 + 8.0 * bk) + (fl2 - 1)
		for k in range(1, ln + 1):
			var fade := 1.0 - float(k) / float(ln + 1)
			var col: Color = UITheme.FLARE.lerp(UITheme.EMBER, minf(1.0, float(k) / 3.0))
			var al := minf(1.0, (0.35 + 0.45 * bk) * fade + (0.25 if k <= 2 else 0.0))
			P.call(-4 - k, -1, Color(col, al))
			P.call(-4 - k, 1, Color(col, al))
			if k <= 3 + int(bk * 3.0):
				P.call(-4 - k, 0, Color(UITheme.HOT, minf(1.0, al * 1.1)))
	if flight.rcs:
		var fl := int(t * 20.0) % 2
		P.call(7 + fl, -1, Color(UITheme.HOT, 0.8))
		P.call(7 + (1 - fl), 1, Color(UITheme.HOT, 0.8))
	# THE RING when it is settled (arrived, or stopped); in orbit the orbit is it
	var settled: bool = flight.mode == &"warp"
	if settled:
		var rr := 11.0 + sin(t * 2.4) * 1.5
		for k in range(0, 40, 2):
			var an := float(k) / 40.0 * TAU
			_px(x + Vector2(cos(an) * rr, sin(an) * rr * 0.8), Color(UITheme.FLARE, 0.75))
	# WHAT IT IS DOING, by the ship itself: in orbit, alongside, a close orbit
	# (which says which ship well enough: YOU would sit on the ring)
	var on: int = flight.orbit_body()
	var words := ""
	if ob >= -1:
		var nm: String = view.star_name() if ob == -1 else view.layout.bodies[ob].name
		words = ("CLOSE ORBIT · " if ob == -1 else ("ALONGSIDE · " if flight.mode == &"keep" else "IN ORBIT · ")) + nm
	elif on >= -1 and flight.mode == &"rail" and flight.rail.has("phase"):
		words = "LEAVING ORBIT · " + (view.star_name() if on == -1 else view.layout.bodies[on].name)
	elif on >= -1 and flight.inserting():
		words = ("COMING ALONGSIDE · " if flight.mode == &"keep" else "ENTERING ORBIT · ") + (view.star_name() if on == -1 else view.layout.bodies[on].name)
	elif flight.star_orbiting():
		words = "ORBITING " + view.star_name()
	if words == "":
		_label(x + Vector2(-8, -13), "YOU", UITheme.FLARE, 1, false)
	else:
		var tw := _font().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		var lc := x
		var ly := x.y + 17.0
		if on >= -1:
			# UNDER THE RING it names, centred on its place (under the ship it sat
			# on the world when zoomed in)
			var bw := _body_scr(on)
			var rr := _orbit_px(on, _orbit_r(on)) * _ok / maxf(_orbit_k(on, _orbit_r(on)), 1.0)
			var disc: float = (view.layout.star_r * view.star_k()) if on == -1 else (_reach(on) - 7.0)
			lc = bw
			ly = bw.y + maxf(rr * view.TILT, disc) + 13.0
		var lx := clampf(lc.x - roundf(tw / 2.0), view.window.position.x + 4.0, view.window.end.x - tw - 4.0)
		_label(Vector2(lx, ly), words, UITheme.FLARE, 4, true)


## WHAT THE MAP SAYS ABOUT THE SHIP, top left: in orbit, alongside, too fast,
## sliding in, leaving.
func ship_status() -> Array:
	var L: SystemLayout = view.layout
	if flight == null:
		return ["", UITheme.CHILL]
	var t: float = view.t
	var nm := func(b: int) -> String: return view.star_name() if b == -1 else L.bodies[b].name
	match flight.mode:
		&"fly":
			return ["TO A CLOSE ORBIT OF THE STAR" if flight.fly_to == -1 else "TO " + nm.call(flight.fly_to), UITheme.CHILL]
		&"rail":
			var b := int(flight.rail.body)
			if flight.rail.has("phase"):
				return ["LEAVING ORBIT · " + ("TO A CLOSE ORBIT OF THE STAR" if flight.fly_to == -1 else "TO " + nm.call(flight.fly_to)), UITheme.CHILL]
			if flight.inserting():
				return ["ENTERING ORBIT · " + nm.call(b), UITheme.HOT]
			return ["CLOSE ORBIT · " + nm.call(b) if b == -1 else "IN ORBIT · " + nm.call(b), UITheme.FLARE]
		&"keep":
			if flight.inserting():
				return ["COMING ALONGSIDE · " + nm.call(int(flight.keep.body)), UITheme.HOT]
			return ["ALONGSIDE · " + nm.call(int(flight.keep.body)), UITheme.FLARE]
		&"free":
			if flight.star_orbiting():
				return ["ORBITING " + view.star_name(), UITheme.FLARE]
			if flight.f.no_cap_left > 0.0:
				return ["LEAVING ORBIT", UITheme.CHILL]
			if t - flight.fast_t < 0.6:
				return ["TOO FAST TO ORBIT · SLOW DOWN", UITheme.HOT]
			if flight.sticky >= -1:
				return ["WILL SLIDE INTO ORBIT · " + nm.call(flight.sticky), UITheme.HOT]
	return ["", UITheme.CHILL]


# ---------------------------------------------------------------- the tip
func _draw_tip() -> void:
	var L: SystemLayout = view.layout
	var lines: Array = []
	var chip := UITheme.ICE
	var h := hover
	if h.kind == &"star":
		lines.append([view.star_name(), UITheme.ICE])
		lines.append([view.star_class(), UITheme.COLD])
		lines.append(_click_line(-1))
	elif h.kind == &"body" or h.kind == &"belt":
		var b := L.bodies[h.body]
		lines.append([b.name, UITheme.ICE])
		lines.append([view.body_kind(b), UITheme.COLD])
		if b.beacons.size() > 0:
			var here: bool = flight != null and flight.reached() == int(h.body)
			lines.append(["%d %s · %s" % [b.beacons.size(), "EVENT" if b.beacons.size() == 1 else "EVENTS", "OPEN" if here else ("OPEN ALONGSIDE" if b.kind == &"belt" or b.kind == &"station" else "OPEN IN ORBIT")], UITheme.EMBER])
		lines.append(_click_line(int(h.body)))
	else:
		if h.body >= 0:
			var b := L.bodies[h.body]
			lines.append([b.name, UITheme.ICE])
			lines.append([view.body_kind(b), UITheme.COLD])
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
			lines.append(["IT HAS BEEN WAITING", UITheme.BAD])
		lines.append(_click_line(int(h.body)))
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
## the selection), or nothing, being there already.
func _click_line(body: int) -> Array:
	if flight != null and flight.reached() == body:
		return ["YOU ARE HERE", UITheme.FLARE]
	if selected == body:
		if flight != null and flight.mode == &"fly" and flight.fly_to == body:
			return ["ON YOUR WAY", UITheme.HOT]
		return ["CLICK AGAIN: FLY HERE", UITheme.HOT]
	return ["CLICK: SELECT", UITheme.QUOTE]


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
		if p.distance_to(at) <= maxf(view.draw_r(b), 4.0) + 3.0:
			return {"kind": &"body", "body": i, "beacon": null, "at": at}
	var sc: Vector2 = view.origin()
	if p.distance_to(sc) <= maxf(8.0, L.star_r * view.star_k()):
		return {"kind": &"star", "body": -1, "beacon": null, "at": sc}
	# A BELT IS ITS BAND: anywhere within the band's width of its orbit, all the
	# way round (it had no hit at all, so it could only be reached by its beacon)
	var rel: Vector2 = (p - view.origin()) / maxf(view.zoom, 0.0001)
	var plane := Vector2(rel.x, rel.y / view.TILT)
	for i in L.bodies.size():
		var b := L.bodies[i]
		if b.kind == &"belt" and absf(plane.length() - b.orbit) < maxf(26.0, 5.0 / view.zoom):
			return {"kind": &"belt", "body": i, "beacon": null, "at": p}
	return {}
