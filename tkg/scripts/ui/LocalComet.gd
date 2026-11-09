extends Node2D

## The comet in LOCAL (`CometPath`). Far off, on the band where the map has it at the clock LOCAL
## holds. Met on its path (`CometCatch`), the close pass: it comes alongside the ship for its
## reading, its coma round the ship's nose, and goes once the reading is taken.
## Why: docs/why/LocalComet.md#on-the-band

## the sky it is drawn in (`LocalSky`)
var sky
## Its size against the map's (Jon, Nov 9, "K3"): a real presence in the sky that does
## not upstage the ship. Why: docs/why/LocalComet.md#size
const K_NEAR := 1.25
const K_FAR := 1.0
const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

## Frames since LOCAL's palette was cut: as the map's comet, it shows only after
## (`SkyWeather.RealComet._since_pal`).
var _since_pal := 0


## Plane point p (from star A as LOCAL left the pair) on the band's screen.
func _on_band(p: Vector2) -> Vector2:
	return sky._zp(sky.band_origin() + Vector2(p.x, p.y * sky.TILT) * sky._s, sky.Z_BAND)


## Where the head is drawn, or INF while it is not in the system.
func head() -> Vector2:
	var L: SystemLayout = sky.layout if sky != null else null
	if L == null or L.comet == null or not L.comet.here(sky._tm):
		return Vector2.INF
	return (_on_band(sky._rel(L.comet.pos(L, sky._tm))) / 2.0).round() * 2.0


func _process(d: float) -> void:
	# (a sky with no palette to cut has nothing to wait for)
	var cut: bool = sky != null and (bool(sky._palette_built) or (sky._palette_mat == null and bool(sky._ready_sky)))
	_since_pal = _since_pal + 1 if cut else 0
	visible = _since_pal > SkyWeatherS.RealComet.PAL_WAIT
	_step_pass(d)


func _draw() -> void:
	# (a pass under way, or over: then it has gone by and is not on the band near you)
	if _pass_k != -1:
		_draw_pass()
		return
	var hs := head()
	if hs == Vector2.INF:
		return
	var L: SystemLayout = sky.layout
	var c: CometPath = L.comet
	var tm: float = sky._tm
	var a := c.age(tm)
	var A := clampf(pow(2.5 * c.q / maxf(c.rel(a).length(), 1.0), 2.0), 0.0, 1.0)
	var fade := clampf(a / 5.0, 0.0, 1.0) * clampf((c.T - a) / 5.0, 0.0, 1.0)
	var away := hs - _on_band(sky._rel(L.star_pos(-1, tm)))
	var ad := away.normalized() if away.length() > 0.5 else Vector2.RIGHT
	var going := _on_band(sky._rel(c.pos(L, tm + 0.5))) - hs
	var side: Vector2 = SkyWeatherS.RealComet.trailing_side(ad, going)
	# The map's look (`SkyWeather.RealComet.paint`) at the band's place.
	SkyWeatherS.RealComet.paint(self, hs, ad, side, lerpf(K_FAR, K_NEAR, A), fade, bool(sky.radiant))


# ---------------------------------------------------------------- the close pass
## Each spot's pass, far to at the star: how far the head sits off the ship's nose toward the
## star (so its tails stream back over the ship), the coma's radius, the nucleus's, and the grit
## in the tail. Nearer is closer, bigger and rougher. Why: docs/why/LocalComet.md#the-close-pass
const PASS_D: Array[float] = [150.0, 118.0, 92.0]
const PASS_COMA: Array[float] = [92.0, 118.0, 142.0]
const PASS_NUC: Array[float] = [18.0, 22.0, 28.0]
const PASS_GRIT: Array[int] = [0, 36, 80]
const ARRIVE_S := 2.4
const LEAVE_S := 2.6
## where it comes in from and goes out to, against where it holds (px)
const FROM := Vector2(620, -60)
const TO := Vector2(-760, 70)

## The spot of the pass under way (-1 none), its clock, and when it began to leave.
var _pass_k := -1
var _pass_t := 0.0
var _leave_t := -1.0
var _pass_opt := -1
var _tex: ImageTexture = null
## the head's place in the pass picture (half-size px), and the tails' way
var _anchor := Vector2.ZERO
var _ad := Vector2.RIGHT
var _side := Vector2.DOWN
var _grit: Array[Vector3] = []


## A comet's reading open here, met at a spot: its option, else -1.
func _reading_here() -> int:
	var n: MapGen.MapNode = sky.node
	var i := LocalEventDrawer.open_here(n)
	if i < 0 or StringName(OptionTable.by_id(n.options[i]).get("site", &"")) != &"comet":
		return -1
	return i if CometPath.caught_at(n) >= 0 else -1


func _step_pass(d: float) -> void:
	if sky == null or sky.node == null:
		return
	var i := _reading_here()
	if _pass_k < 0:
		if i < 0:
			return
		_pass_k = CometPath.caught_at(sky.node)
		_pass_opt = i
		_pass_t = 0.0
		_leave_t = -1.0
		_tex = null
	_pass_t += d
	var taken: bool = sky.node.taken.has(MapGen.OPTION_SITE + _pass_opt)
	if _leave_t < 0.0 and (taken or i < 0) and _pass_t > ARRIVE_S:
		_leave_t = _pass_t
	if _leave_t >= 0.0 and _pass_t - _leave_t > LEAVE_S:
		_pass_k = -2
	queue_redraw()


## The ship's nose on screen: where the head is held off.
func _nose() -> Vector2:
	var cs: Control = sky.cam_ship
	if cs != null and is_instance_valid(cs) and cs.is_inside_tree():
		var r := cs.get_global_rect()
		return Vector2(r.end.x - 20.0, r.get_center().y)
	return Vector2(330, 278)


## Where the head holds for the reading: off the nose toward the star.
func _hold() -> Vector2:
	var nose := _nose()
	var sun: Vector2 = sky.origin()
	var to_sun := (sun - nose).normalized() if sun.distance_to(nose) > 1.0 else Vector2(0.6, -0.8)
	var hold := nose + to_sun * PASS_D[_pass_k]
	hold.y = maxf(hold.y, 96.0)
	return hold


## Where the head is now: in from the right, held off the nose, out to the left.
func _pass_head() -> Vector2:
	var hold := _hold()
	if _pass_t < ARRIVE_S:
		var u := _pass_t / ARRIVE_S
		return hold + FROM * pow(1.0 - u, 3.0)
	if _leave_t >= 0.0:
		var v := clampf((_pass_t - _leave_t) / LEAVE_S, 0.0, 1.0)
		return hold + TO * v * v * v
	# (alongside, it drifts a little as it goes by)
	return hold + Vector2(-6.0, 1.5) * sin((_pass_t - ARRIVE_S) * 0.4)


func _draw_pass() -> void:
	if _pass_k < 0:
		return
	var hs := (_pass_head() / 2.0).round() * 2.0
	if _tex == null:
		# (its tails away from the star from where it holds, not where it first shows)
		var sun: Vector2 = sky.origin()
		var hold := _hold()
		_ad = (hold - sun).normalized() if hold.distance_to(sun) > 1.0 else Vector2(0.6, 0.8)
		_side = SkyWeatherS.RealComet.trailing_side(_ad, TO)
		_tex = _bake(_pass_k)
		_seed_grit()
	draw_texture_rect(_tex, Rect2(hs - _anchor * 2.0, Vector2(_tex.get_size()) * 2.0), false)
	_draw_grit(hs)
	if _pass_k == 2:
		_draw_heat()


## THE PASS PICTURE, painted once: the coma, the dust tail and the ion tail as light in
## dithered steps, and a lumpy lit nucleus, at half size (each pixel one of the sky's blocks).
func _bake(k: int) -> ImageTexture:
	var R := PASS_COMA[k] / 2.0
	var L_ion := 300.0
	var L_dust := 230.0
	# (only the box the coma and both tails fill: the whole square was half a million steps)
	var box := Rect2(-Vector2(R, R), Vector2(R, R) * 2.0)
	for e: Vector2 in [_ad * L_ion + _side * 8.0, _ad * L_ion - _side * 8.0, _ad * L_dust + _side * (0.0045 * L_dust * L_dust + 52.0), _ad * L_dust + _side * (0.0045 * L_dust * L_dust - 52.0)]:
		box = box.expand(e)
	box = box.grow(2.0)
	var img := Image.create(int(box.size.x) + 1, int(box.size.y) + 1, false, Image.FORMAT_RGBA8)
	_anchor = -box.position
	var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x, y) - _anchor
			var th := float(bayer[(y % 4) * 4 + x % 4]) / 16.0
			var u := d.dot(_ad)
			var v := d.dot(_side)
			var c := Color(0, 0, 0, 0)
			# the coma: falling off from the head in five steps
			var rc := d.length() / R
			if rc < 1.0:
				var I := floorf((1.0 - rc) * (1.0 - rc) * 5.0 + th) / 5.0
				c = _over(c, Color(0.8, 0.93, 1.0, 0.55 * I))
			# the dust tail: broad, bending to the side it trails from, gold to rust
			if u > 0.0 and u < L_dust:
				var f := u / L_dust
				var vb := v - 0.0045 * u * u
				var wd := 4.0 + 46.0 * f
				if absf(vb) < wd:
					var I2 := floorf((1.0 - f) * (1.0 - absf(vb) / wd) * 4.0 + th) / 4.0
					var dc := Color("#ffe6a8").lerp(Color("#f0a030"), f * 1.4).lerp(Color("#7a3010"), maxf(f - 0.5, 0.0) * 1.6)
					c = _over(c, Color(dc, 0.8 * I2))
			# the ion tail: straight, narrow, blue
			if u > 0.0 and u < L_ion:
				var f3 := u / L_ion
				var wi := 2.0 + 5.0 * f3
				if absf(v) < wi:
					var I3 := floorf((1.0 - f3) * (1.0 - absf(v) / wi) * 4.0 + th) / 4.0
					c = _over(c, Color(Color("#a8e0ff").lerp(Color("#3a74d8"), f3), 0.85 * I3))
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	_nucleus(img, PASS_NUC[k] / 2.0)
	return ImageTexture.create_from_image(img)


## Dirty ice, lumpy, lit from the star with a dithered edge where the light ends.
func _nucleus(img: Image, r: float) -> void:
	var lt := -_ad
	var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var n := int(ceil(r * 1.6))
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var a := atan2(float(dy), float(dx))
			var rr := r * (1.0 + 0.16 * sin(3.0 * a + 1.3) + 0.09 * sin(5.0 * a + 0.4)) * (1.3 if absf(cos(a)) > 0.6 else 1.0)
			var e := Vector2(dx / 1.3, dy)
			if e.length() > rr * 0.8:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - pow(e.length() / (rr * 0.8), 2.0)))
			var lit := (dx / (r * 1.2)) * lt.x + (dy / r) * lt.y + nz * 0.35
			var spot := 0.5 + 0.5 * sin(dx * 0.9 + 1.0) * cos(dy * 1.1 - 2.0)
			var x := int(_anchor.x) + dx
			var y := int(_anchor.y) + dy
			var th := float(bayer[(posmod(y, 4)) * 4 + posmod(x, 4)]) / 16.0
			var col: Color
			if lit > 0.55 + th * 0.2:
				col = Color("#d2dcea") if spot > 0.35 else Color("#9aa4b4")
			elif lit > 0.15 + th * 0.25:
				col = Color("#6e7686") if spot > 0.3 else Color("#545866")
			else:
				col = Color("#2e303c") if spot > 0.4 else Color("#20222c")
			img.set_pixel(x, y, col)


static func _over(a: Color, b: Color) -> Color:
	var al := b.a + a.a * (1.0 - b.a)
	if al <= 0.0:
		return a
	return Color((b.r * b.a + a.r * a.a * (1.0 - b.a)) / al, (b.g * b.a + a.g * a.a * (1.0 - b.a)) / al, (b.b * b.a + a.b * a.a * (1.0 - b.a)) / al, al)


## Grit in the tail at the near spots: each grain's place across the tail, its speed and phase.
func _seed_grit() -> void:
	_grit = []
	var h := hash(sky.node.index) if sky.node != null else 7
	for g in PASS_GRIT[_pass_k]:
		var a := float((h + g * 7919) % 1000) / 1000.0
		var b := float((h + g * 104729) % 1000) / 1000.0
		_grit.append(Vector3(a * 2.0 - 1.0, 140.0 + 160.0 * b, float(g) * 0.37))


func _draw_grit(hs: Vector2) -> void:
	for gr in _grit:
		var span := 520.0
		var u := fposmod(_pass_t * gr.y + gr.z * 97.0, span)
		var p := hs + _ad * u + _side * gr.x * (16.0 + u * 0.22)
		var q := (p / 2.0).floor() * 2.0
		var al := 0.8 * (1.0 - u / span)
		draw_rect(Rect2(q, Vector2(2, 2)), Color(Color("#ffe0b0"), al))
		draw_rect(Rect2(q - _ad * 2.0, Vector2(2, 2)), Color(Color("#c07838"), al * 0.6))


## At the star the heat comes in: the light round the star's side of the view, in dithered steps.
func _draw_heat() -> void:
	var sun: Vector2 = sky.origin()
	for step in 4:
		var r := 120.0 + float(step) * 70.0
		var al := 0.07 * (4.0 - float(step))
		for k in 48:
			var a := TAU * float(k) / 48.0 + float(step) * 0.13
			var p := ((sun + Vector2(cos(a), sin(a)) * r) / 2.0).floor() * 2.0
			draw_rect(Rect2(p, Vector2(2, 2)), Color(Color("#ffb070"), al))
