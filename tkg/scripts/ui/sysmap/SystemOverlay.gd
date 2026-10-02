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
## BECOME UNAVAILABLE. Your ship warps in at the system's edge, flies to a
## beacon in about a second when one is clicked, and stays parked there.

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

## THE SHIP: warping in at the edge, flying to a body, or parked at one.
var ship_from := Vector2.ZERO
var ship_fly_t0 := -1.0
var ship_fly_to := -2
var ship_park := -3
var ship_warp_t := 0.0
var ship_ang := PI
var _ship_at := Vector2.ZERO
## The same, relative to the star, for the flight's heading and its start.
var _ship_rel := Vector2.ZERO
var _fly_done: Callable = Callable()


func _font() -> FontFile:
	return UITheme.pixel_font()


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


func spent_word(bc) -> Array:
	if bc == null or bc.opt < 0:
		return []
	var r: Variant = view.node.results.get(bc.opt, null)
	if r == null and not view.node.taken.has(MapGen.OPTION_SITE + bc.opt):
		return []
	return EncounterDrawer.result_stamp(r if r != null else MapGen.R_DONE)


func beacon_look(bc) -> Array:
	if bc.dock:
		return [&"dock", UITheme.ICE]
	if bc.core:
		return [&"core", UITheme.BAD]
	var o := option_of(bc)
	if o.is_empty():
		return [&"signal", UITheme.TRACTOR]
	return [EncounterDrawer.lead_tag(o), EncounterDrawer.tag_colour(o)]


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var L: SystemLayout = view.layout
	if L == null:
		return
	var t: float = view.t
	beacons_at.clear()
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
	if hover.get("kind", &"") == &"beacon":
		hover_group = String(option_of(hover.beacon).get("group", ""))
	for i in L.bodies.size():
		var b := L.bodies[i]
		for k in b.beacons.size():
			var bc = b.beacons[k]
			var sx: Vector2 = view.at[i]
			if b.kind == &"belt":
				var a: float = b.phase + t / b.period * TAU + k * 0.9
				sx = view.screen(cos(a) * b.orbit, sin(a) * b.orbit).round()
			var by := sx.y - maxf(view.world_r(b) * view.zoom, 2.0) - 14.0
			var at := Vector2(sx.x, by)
			var look := beacon_look(bc)
			var col: Color = look[1]
			var spent := not spent_word(bc).is_empty()
			var o := option_of(bc)
			var rival: bool = hover_group != "" and String(o.get("group", "")) == hover_group and hover.beacon != bc and not spent
			if not spent:
				var ph := fmod(t * 0.6 + i * 0.37 + k * 0.5, 1.0)
				var pr := 6.0 + ph * 13.0
				for a2 in range(0, 24, 2):
					var an := float(a2) / 24.0 * TAU
					_px(at + Vector2(cos(an) * pr, sin(an) * pr * 0.7), Color(col, 0.6 * (1.0 - ph)))
			var y := by + 7.0
			while y < sx.y - maxf(view.world_r(b) * view.zoom, 2.0) - 1.0:
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
		glyph(hat, &"harvest", UITheme.TRACTOR)
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
			if g[1] != hover.beacon:
				_text(g[0] + Vector2(-52, -9), "WILL BECOME UNAVAILABLE", UITheme.WARN)
	# the selection: corner brackets and the name
	if selected >= -1:
		var s: Vector2 = view.origin() if selected == -1 else view.at[selected]
		var b: SystemLayout.Body = null if selected == -1 else L.bodies[selected]
		var r: float = (L.star_r * view.zoom + 8.0) if b == null else (0.0 if b.kind == &"belt" else maxf(view.world_r(b) * view.zoom, 4.0) + 6.0)
		if r > 0.0:
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var c := s + Vector2(d.x * r, d.y * r * 0.9)
				draw_rect(Rect2(c + Vector2(-3 if d.x > 0 else 0, 0), Vector2(4, 1)).abs(), UITheme.ICE)
				draw_rect(Rect2(c + Vector2(0, -3 if d.y > 0 else 0), Vector2(1, 4)).abs(), UITheme.ICE)
			_text(s + Vector2(r + 4, 3), view.star_name() if b == null else b.name, UITheme.ICE)
	_draw_ship(t)
	if not hover.is_empty():
		_draw_tip()


# ---------------------------------------------------------------- the ship
func fly_to(body: int, done: Callable) -> void:
	# where it left from, relative to the star and unzoomed, so the flight holds
	# its path while the camera pans and zooms round it
	ship_from = _ship_rel / maxf(view.zoom, 0.0001)
	ship_fly_to = body
	ship_fly_t0 = view.t
	_fly_done = done


## Where the ship parks at `body`, relative to the star on screen, worked out
## from the orbit at this moment (not from last frame's drawing).
func _park_rel(body: int) -> Vector2:
	var L: SystemLayout = view.layout
	var z: float = view.zoom
	if body == -1:
		return Vector2(L.star_r * z + 14, 12)
	var b := L.bodies[body]
	if b.kind == &"belt":
		var a: float = b.phase + view.t / b.period * TAU
		return Vector2(cos(a) * b.orbit, sin(a) * b.orbit * view.TILT) * z + Vector2(8, 5)
	var p := b.pos(view.t)
	return Vector2(p.x, p.y * view.TILT) * z + Vector2(maxf(view.world_r(b) * z, 3.0) + 7.0, 5.0)


## WHERE THE SHIP IS THIS FRAME, relative to the star on screen: parked, flying
## or just warped in. The camera's LOCATION follows exactly this, and the ship is
## drawn from exactly this, so the two cannot disagree by a pixel.
func ship_rel() -> Vector2:
	var L: SystemLayout = view.layout
	var z: float = view.zoom
	if ship_fly_t0 >= 0.0:
		var u: float = clampf((view.t - ship_fly_t0) / 1.0, 0.0, 1.0)
		var e := 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
		var to := _park_rel(ship_fly_to)
		var f: Vector2 = ship_from * z
		var mid := (f + to) / 2.0 + Vector2((to.y - f.y) * 0.25, -(to.x - f.x) * 0.25)
		return (1.0 - e) * (1.0 - e) * f + 2.0 * (1.0 - e) * e * mid + e * e * to
	if ship_park >= -1:
		return _park_rel(ship_park)
	var ex := minf(L.edge, (view.window.end.x - view.CX - 26.0) / z)
	return Vector2(ex, -70.0 * view.TILT) * z


func _draw_ship(t: float) -> void:
	var flying := ship_fly_t0 >= 0.0
	var rel := ship_rel()
	var x: Vector2 = (Vector2(view.CX, view.CY) + view.pan + rel).round()
	if flying:
		var u: float = clampf((view.t - ship_fly_t0) / 1.0, 0.0, 1.0)
		# heading from the flight itself, not from the screen, which the camera moves
		if rel.distance_to(_ship_rel) > 0.01:
			ship_ang = (rel - _ship_rel).angle()
		if u >= 1.0:
			ship_fly_t0 = -1.0
			ship_park = ship_fly_to
			if _fly_done.is_valid():
				var d := _fly_done
				_fly_done = Callable()
				d.call()
	elif ship_park < -1:
		var w: float = view.t - ship_warp_t
		if w < 0.6:
			for k in int(80.0 * (1.0 - w / 0.6)):
				_px(x + Vector2(k, 0), Color(UITheme.ICE, 0.7 * (1.0 - k / 80.0)))
		ship_ang = PI
	_ship_at = x
	_ship_rel = rel
	# YOUR SHIP, easy to find: a hull with a dark outline, a ring pulsing round
	# it in the game's flare orange, and YOU over it
	var c := cos(ship_ang)
	var s := sin(ship_ang)
	var P := func(u: float, v: float, col: Color) -> void:
		_px(x + Vector2(u * c - v * s, u * s + v * c), col)
	var in_hull := func(u: int, v: int) -> bool:
		return u >= -3 and u <= 6 and absf(v) <= (6 - u) * 0.5
	for u in range(-4, 8):
		for v in range(-4, 5):
			if not in_hull.call(u, v) and (in_hull.call(u - 1, v) or in_hull.call(u + 1, v) or in_hull.call(u, v - 1) or in_hull.call(u, v + 1)):
				P.call(u, v, Color("#05070b"))
	for u in range(-3, 7):
		for v in range(-4, 5):
			if in_hull.call(u, v):
				P.call(u, v, Color.WHITE if u > 3 else (UITheme.CHILL if absi(v) >= 2 else UITheme.ICE))
	P.call(-4, -1, UITheme.HOT)
	P.call(-4, 1, UITheme.HOT)
	P.call(-5, -1, UITheme.FLARE if int(t * 20.0) % 2 == 1 else UITheme.HOT)
	P.call(-5, 1, UITheme.FLARE if int(t * 20.0 + 1) % 2 == 1 else UITheme.HOT)
	if flying:
		for k in range(2, 10):
			P.call(-4 - k, -1, Color(UITheme.EMBER, 0.55 - k * 0.05))
			P.call(-4 - k, 1, Color(UITheme.EMBER, 0.55 - k * 0.05))
	else:
		var rr := 11.0 + sin(t * 2.4) * 1.5
		for k in range(0, 40, 2):
			var an := float(k) / 40.0 * TAU
			_px(x + Vector2(cos(an) * rr, sin(an) * rr * 0.8), Color(UITheme.FLARE, 0.75))
	_text(x + Vector2(-8, -13), "YOU", UITheme.FLARE)


# ---------------------------------------------------------------- the tip
func _draw_tip() -> void:
	var L: SystemLayout = view.layout
	var lines: Array = []
	var chip := UITheme.ICE
	var h := hover
	if h.kind == &"star":
		lines.append([view.star_name(), UITheme.ICE])
		lines.append([view.star_class(), UITheme.COLD])
		lines.append(["CLICK FOR ITS INFO", UITheme.QUOTE])
	elif h.kind == &"body":
		var b := L.bodies[h.body]
		lines.append([b.name, UITheme.ICE])
		lines.append([view.body_kind(b), UITheme.COLD])
		if b.beacons.size() > 0:
			lines.append(["%d %s" % [b.beacons.size(), "BEACON" if b.beacons.size() == 1 else "BEACONS"], UITheme.EMBER])
		lines.append(["CLICK FOR ITS INFO", UITheme.QUOTE])
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
	var f := _font()
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	w = ceilf(w) + 14.0
	var hgt := lines.size() * 11.0 + 8.0
	var at: Vector2 = h.at
	var x := roundf(at.x + 12.0)
	var y := roundf(at.y - 6.0)
	var win: Rect2 = view.window
	if x + w > win.end.x - 6:
		x = roundf(at.x - w - 12.0)
	if y + hgt > win.end.y - 6:
		y = win.end.y - 6 - hgt
	y = maxf(y, win.position.y + 6)
	draw_rect(Rect2(x, y, w, hgt), Color(11 / 255.0, 17 / 255.0, 27 / 255.0, 0.94))
	draw_rect(Rect2(x + 0.5, y + 0.5, w - 1.0, hgt - 1.0), Color("#3c4c60"), false, 1.0)
	draw_rect(Rect2(x, y, 2, hgt), chip)
	for k in lines.size():
		_text(Vector2(x + 8, y + 12 + k * 11), lines[k][0], lines[k][1])


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
		if p.distance_to(at) <= maxf(view.world_r(b) * view.zoom, 4.0) + 3.0:
			return {"kind": &"body", "body": i, "beacon": null, "at": at}
	var sc: Vector2 = view.origin()
	if p.distance_to(sc) <= maxf(8.0, L.star_r * view.zoom):
		return {"kind": &"star", "body": -1, "beacon": null, "at": sc}
	return {}
