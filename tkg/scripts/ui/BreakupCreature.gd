class_name CreatureFilm
extends RefCounted
## The creature deaths of ShipBreakup (GLOWOUT, BLOOM, PART): their plan, glow bands and spores.
## The film's state stays on `film`; this holds only what the creatures alone use.
## Why: docs/why/ShipBreakup.md#creature-deaths

var film: ShipBreakup


func _init(the_film: ShipBreakup) -> void:
	film = the_film


# ---------------------------------------------------------------- the film

var _gl_tex: Array = []   ## [stage][band] -> {tex, at (canvas)}
var _fluid := Color("#e07a5a")
var _body_px := PackedVector2Array()
var _torn := PackedByteArray()


## Glow pixels as gathered light over the dark body, so full light gives the art back
## exactly.
func _glow_band(pts: PackedVector2Array, cols: PackedColorArray, mean: Color) -> Dictionary:
	if pts.is_empty():
		return {tex = null, at = Vector2.ZERO}
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for p in pts:
		lo = Vector2i(mini(lo.x, int(p.x)), mini(lo.y, int(p.y)))
		hi = Vector2i(maxi(hi.x, int(p.x)), maxi(hi.y, int(p.y)))
	lo -= Vector2i(3, 3)
	hi += Vector2i(3, 3)
	var W := hi.x - lo.x + 1
	var Hh := hi.y - lo.y + 1
	var acc := PackedFloat32Array()
	acc.resize(W * Hh)
	var core := {}
	for i in pts.size():
		var q := Vector2i(pts[i]) - lo
		core[q] = cols[i]
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var kk := 1.0 - sqrt(float(dx * dx + dy * dy)) / 3.0
				if kk > 0.0:
					acc[(q.y + dy) * W + q.x + dx] += kk
	var im := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	for y in Hh:
		for x in W:
			var q2 := Vector2i(x, y)
			if core.has(q2):
				var c: Color = core[q2]
				im.set_pixel(x, y, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, 1.0))
				continue
			var a := acc[y * W + x]
			if a >= 2.0:
				im.set_pixel(x, y, FxKit.lv(mean, 0.3))
			elif a >= 0.8 and ((x + lo.x + y + lo.y) & 1) == 0:
				im.set_pixel(x, y, FxKit.lv(mean, 0.16))
	return {tex = film._tex(im), at = Vector2(lo)}


func setup_creature(img: Image, used: Rect2i, seed: int) -> void:
	film._lead = 0.0
	film.duration = float(ShipBreakup.LIFE[film.style])
	film._cut = ShipBreakup.cut(img, used, seed, false, film.style)
	film._plan = film._cut.get("plan", {})
	film._centre = film._origin + Vector2(film._cut.centre)
	film._flash_tex = film._tex(ShipBreakup._radial_light(22))
	film._plan_events()
	for m in film._cut.majors:
		var mi: Image = m.image
		var tex := film._tex(mi)
		film._majors.append({tex = tex, stages = [tex], images = [mi], at = m.at, off = m.off, own = m.own,
			glob = m.glob, crack = m.crack, dir = m.dir, lab = m.lab,
			glow = film._tex(film._glow_image(m.crack, mi.get_size()))})
		for y in mi.get_height():
			for x in mi.get_width():
				if mi.get_pixel(x, y).a > 0.0 and film._rng.randf() < 0.12:
					_body_px.append(Vector2(m.at) + Vector2(x, y))
	var gl: Dictionary = film._plan.glow
	var gp: PackedVector2Array = gl.p
	var gc: PackedColorArray = gl.c
	var gb: PackedInt32Array = gl.band
	var nb: int = film._plan.nb
	var mean := Color(0, 0, 0)
	for c in gc:
		mean += c
	if gc.size() > 0:
		mean = mean / float(gc.size())
		_fluid = Color(mean.r, mean.g, mean.b, 1.0)
	var steps := ShipBreakup.CURL_STEPS + 1 if film.style == ShipBreakup.Style.GLOWOUT else 1
	for s in steps:
		var row: Array = []
		for b in nb:
			var pts := PackedVector2Array()
			var cs := PackedColorArray()
			for i in gp.size():
				if gb[i] != b:
					continue
				var p := gp[i]
				if film.style == ShipBreakup.Style.GLOWOUT:
					var cu: Dictionary = film._plan.curl
					var lx := p.x - float((film._plan.r as Rect2i).position.x)
					p.y += BreakupCuts._curl_dy(lx, cu, float(s) / float(ShipBreakup.CURL_STEPS))
				pts.append(p)
				cs.append(gc[i])
			row.append(_glow_band(pts, cs, _fluid))
		_gl_tex.append(row)
	if film.style == ShipBreakup.Style.GLOWOUT:
		var H := BreakupCuts.hull_pic(img, used, 12)
		var raw: PackedColorArray = H.raw
		var mask: PackedByteArray = H.mask
		var col := PackedColorArray()
		col.resize(raw.size())
		for i in raw.size():
			if mask[i] == 1:
				var c2 := raw[i]
				col[i] = Color(c2.r * 0.3, c2.g * 0.3, c2.b * 0.3, c2.a) if BreakupCuts._is_glow(c2) else c2
		film._stage_at = Vector2((H.r as Rect2i).position)
		for s2 in ShipBreakup.CURL_STEPS + 1:
			var cp := BreakupCuts._curl_pic(H, col, mask, film._plan.curl, float(s2) / float(ShipBreakup.CURL_STEPS))
			film._stage_tex.append(film._tex(BreakupCuts._pic_image(H, cp.col, cp.mask)))
	if film.style == ShipBreakup.Style.PART:
		_torn.resize(ShipBreakup.PART_TEAR.size() + 2)


func plan_creature() -> float:
	var nb: int = film._plan.nb
	match film.style:
		ShipBreakup.Style.GLOWOUT:
			film._ev(0.0, &"flare", 0.5)
			film._ev(0.0, &"groan", 0.5, 1.8)
			film._ev(0.3, &"curl", 0.3, 1.32)
			for b in nb:
				film._ev(0.35 + 0.3 * b, &"dim", 0.3, 0.0, Vector2.INF, {band = b})
			film._ev(1.7, &"still", 0.15)
			return 1.5
		ShipBreakup.Style.BLOOM:
			film._ev(0.0, &"flare", 0.6)
			film._ev(0.25, &"bloom", 0.8)
			film._ev(0.25, &"spores", 0.5, 1.0)
			for b in nb:
				film._ev(0.7 + 0.2 * b, &"dim", 0.3, 0.0, Vector2.INF, {band = b})
			film._ev(1.3, &"still", 0.15)
			return 0.0
		ShipBreakup.Style.PART:
			film._ev(0.0, &"pulse", 0.4)
			for i in nb - 1:
				film._ev(ShipBreakup.PART_TEAR[i], &"tear", 0.4 + 0.1 * i, 0.0, Vector2.INF, {seam = i})
			film._ev(0.15, &"fluid", 0.4, 1.4)
			for b in nb:
				film._ev(0.7 + 0.2 * b, &"dim", 0.3, 0.0, Vector2.INF, {band = b})
			film._ev(1.6, &"still", 0.15)
			return 0.15
	return 0.0


## How lit band `b` is: a last flare, held, then out in four held steps.
func _glow_lvl(b: int, tt: float) -> float:
	var out := 0.0
	var flare := 1.0
	match film.style:
		ShipBreakup.Style.GLOWOUT:
			out = 0.35 + 0.3 * b
			flare = 1.15 if tt < 0.08 else (1.3 if tt < 0.2 else 1.0)
		ShipBreakup.Style.BLOOM:
			out = 0.7 + 0.2 * b
			flare = 1.15 if tt < 0.1 else (1.4 if tt < 0.3 else 1.0)
		ShipBreakup.Style.PART:
			out = 0.7 + 0.2 * b
			flare = 1.2 if tt < 0.1 else 1.0
	if tt < out:
		return flare
	var a := tt - out
	return 0.6 if a < 0.08 else (0.3 if a < 0.16 else (0.12 if a < 0.26 else 0.0))


func fire_creature(e: Dictionary) -> void:
	match e.kind:
		&"dim":
			# What light it had leaves it as a few motes, drifting off slowly.
			var gl: Dictionary = film._plan.glow
			var gp: PackedVector2Array = gl.p
			var gc: PackedColorArray = gl.c
			var gb: PackedInt32Array = gl.band
			var mine: Array[int] = []
			for i in gp.size():
				if gb[i] == int(e.band):
					mine.append(i)
			for j in mini(12, mine.size()):
				var i2 := mine[film._rng.randi() % mine.size()]
				var p := _creature_glow_pos(gp[i2], int(e.band))
				var v := (p - film._centre).normalized() * film._rng.randf_range(6.0, 16.0) \
					+ Vector2(film._rng.randf_range(-4.0, 4.0), film._rng.randf_range(-4.0, 4.0))
				film._mote(p, v, film._rng.randf_range(0.6, 1.0), 5, film._rng.randf() < 0.3, gc[i2], 0.3)
		&"bloom":
			for j in 280:
				_spore()
		&"tear":
			var sd: Dictionary = film._plan.seams
			var sp: PackedVector2Array = sd.p
			var si: PackedInt32Array = sd.i
			var seam: int = e.seam
			_torn[seam] = 1
			for i in sp.size():
				if si[i] != seam or film._rng.randf() > 0.55:
					continue
				var side := 1.0 if film._rng.randf() < 0.5 else -1.0
				film._mote(film._origin + sp[i], Vector2(side * film._rng.randf_range(4.0, 14.0), film._rng.randf_range(-6.0, 6.0)),
					film._rng.randf_range(0.8, 1.3), 6, film._rng.randf() < 0.35, _fluid, 0.4)


## Where a glow pixel is drawn now (it rides the curl, the drift, its segment).
func _creature_glow_pos(p: Vector2, band: int) -> Vector2:
	var q := film._origin + p + film._hull_shift()
	if film.style == ShipBreakup.Style.GLOWOUT:
		var lx := p.x - float((film._plan.r as Rect2i).position.x)
		q.y += BreakupCuts._curl_dy(lx, film._plan.curl, float(_curl_stage()) / float(ShipBreakup.CURL_STEPS))
	elif film.style == ShipBreakup.Style.PART:
		for m in film._majors:
			if int(m.lab) == band:
				q += film._major_pos_new(m) - (film._origin + Vector2(m.at))
	return q


func _spore() -> void:
	if _body_px.is_empty():
		return
	var gl: Dictionary = film._plan.glow
	var gp: PackedVector2Array = gl.p
	var p: Vector2
	if film._rng.randf() < 0.5 and not gp.is_empty():
		p = film._origin + gp[film._rng.randi() % gp.size()] + film._hull_shift()
	else:
		p = film._origin + _body_px[film._rng.randi() % _body_px.size()] + film._hull_shift()
	var v := (p - film._centre).normalized() * film._rng.randf_range(12.0, 46.0) \
		+ Vector2(film._rng.randf_range(-8.0, 8.0), film._rng.randf_range(-8.0, 8.0))
	film._mote(p, v, film._rng.randf_range(0.7, 1.2), 7, film._rng.randf() < 0.55, Color.WHITE, 0.5)


func tick_creature(delta: float, tt: float) -> void:
	match film.style:
		ShipBreakup.Style.BLOOM:
			if tt >= 0.25 and tt < 1.25:
				var rate := 440.0 * snappedf(1.0 - (tt - 0.25) / 1.0, 0.25)
				var n := int(rate * delta + film._rng.randf())
				for i in n:
					_spore()
		ShipBreakup.Style.PART:
			var torn := 0
			for x in _torn:
				torn += int(x)
			if torn > 0 and tt < 1.3:
				var rate2 := 50.0 * float(torn) / float(maxi(1, int(film._plan.nb) - 1)) * (1.0 if tt < 1.0 else 0.5)
				var n2 := int(rate2 * delta + film._rng.randf())
				for i in n2:
					var m: Dictionary = film._majors[film._rng.randi() % film._majors.size()]
					var cr: PackedVector2Array = m.crack
					if cr.is_empty():
						continue
					var q := film._major_pos_new(m) + cr[film._rng.randi() % cr.size()]
					var side := signf(q.x - (film._major_pos_new(m).x + float((m.tex as ImageTexture).get_width()) * 0.5))
					film._mote(q, Vector2(side * film._rng.randf_range(3.0, 10.0), film._rng.randf_range(-5.0, 5.0)),
						film._rng.randf_range(0.6, 1.0), 6, film._rng.randf() < 0.3, _fluid, 0.4)


func _curl_stage() -> int:
	var tt := film.t - film._lead
	if tt < 0.3:
		return 0
	return mini(ShipBreakup.CURL_STEPS, 1 + int((tt - 0.3) / 0.22))


func _creature_tint() -> Color:
	if film.done:
		return ShipBreakup.WRECK_TINT
	var q := snappedf(clampf((film.t - 0.3) / (film.duration - 0.5), 0.0, 1.0), 0.25)
	return Color.WHITE.lerp(ShipBreakup.WRECK_TINT, q)


func paint_creature_body(ci: CanvasItem) -> void:
	var tint := _creature_tint()
	if film.style == ShipBreakup.Style.GLOWOUT and film.t < film._split_at and not film._stage_tex.is_empty():
		ci.draw_texture(film._stage_tex[_curl_stage()], film._origin + film._stage_at + film._hull_shift(), tint)
	else:
		for m in film._majors:
			ci.draw_texture(m.tex, film._major_pos_new(m), tint)
	if film.style == ShipBreakup.Style.PART:
		var sd: Dictionary = film._plan.seams
		var sp: PackedVector2Array = sd.p
		var sc: PackedColorArray = sd.c
		var si: PackedInt32Array = sd.i
		for i in sp.size():
			if _torn[si[i]] == 0:
				ci.draw_rect(Rect2(film._origin + sp[i], Vector2.ONE), sc[i] * tint)


func paint_creature_light(ci: CanvasItem, tt: float) -> void:
	var nb: int = film._plan.nb
	var row: Array = _gl_tex[_curl_stage() if film.style == ShipBreakup.Style.GLOWOUT else 0]
	for b in nb:
		var l := _glow_lvl(b, tt)
		var g: Dictionary = row[b]
		if l <= 0.0 or g.tex == null:
			continue
		var at := film._origin + (g.at as Vector2) + film._hull_shift()
		if film.style == ShipBreakup.Style.PART:
			for m in film._majors:
				if int(m.lab) == b:
					at += film._major_pos_new(m) - (film._origin + Vector2(m.at) + film._hull_shift())
		ci.draw_texture(g.tex, at.round(), Color(l, l, l, 1.0))
	if film.style == ShipBreakup.Style.PART:
		var on := 0.0
		if tt >= 0.15:
			on = 1.0 if tt < 0.6 else (0.75 if tt < 0.9 else (0.5 if tt < 1.15 else (0.25 if tt < 1.4 else 0.0)))
		if on > 0.0:
			for m2 in film._majors:
				ci.draw_texture(m2.glow, film._major_pos_new(m2) - Vector2(ShipBreakup.GLOW_PAD, ShipBreakup.GLOW_PAD),
					Color(0.5 * on, 0.22 * on, 0.18 * on, 1.0))
