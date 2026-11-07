class_name LabSaversSolari
extends RefCounted

## MOCK (review_lab r6 owners, Nov 7; not for feat/science): three screensavers
## only a Solari Foundry Lab runs. Jon on the seven: "Love these. Want more per
## owner." Each is its own idea, drawn with `LabSavers`' kit on `LabLogin`'s
## canvas, on the lab's clock (never the wall):
##
##   SOL1  MARGIN TEST: a Foundry part held hot on the test stand, its
##         temperature trace running past the old safe limit (the argument the
##         guild lost) and held under the Foundry's own
##   SOL2  HEAT GAUGE: the ship's heat gauge filling turn by turn, and what a
##         Solari gun's shot is worth at each step of it (heat scaling, from
##         the card itself)
##   SOL3  RADIATOR WATCH: the station's radiator wing seen through a thermal
##         camera, coolant pulses carrying heat out along the truss into the fins

var k: LabSavers
var g: LabLogin
## The look's own clock: runs at rest, eases nearly to a stop when pointed at.
var _ct := 0.0
var _run := 1.0
var _parts: Array[String] = []


func _init(kit: LabSavers) -> void:
	k = kit
	g = kit.g


func paint(style: String) -> bool:
	match style:
		"SOL1":
			_paint_1()
		"SOL2":
			_paint_2()
		"SOL3":
			_paint_3()
		_:
			return false
	return true


func step(delta: float, style: String) -> void:
	if not style.begins_with("SOL"):
		return
	var resting := g.state == LabLogin.LOGO
	_run = lerpf(_run, 1.0 if resting else 0.0, 1.0 - exp(-delta * 3.0))
	_ct += delta * _run


# ================================================================== shared

func _mk() -> Color:
	if DB.manufacturers.has(g.owner_id):
		return DB.manufacturer_colour(g.owner_id)
	return g.tint


## The Foundry's heat ramp: dark, ember, amber, straw, white (0..1).
func _heat(u: float, dim: float) -> Color:
	var stops: Array[Color] = [LabBoard.BG, Color("#3a1408"), LabBoard.EMBER, LabBoard.NEXT, LabBoard.HOT, LabBoard.WHITE]
	var pos: Array[float] = [0.0, 0.2, 0.45, 0.65, 0.85, 1.0]
	u = clampf(u, 0.0, 1.0)
	var c := stops[0]
	for i in range(1, stops.size()):
		if u <= pos[i]:
			c = LabBoard.mixc(stops[i - 1], stops[i], (u - pos[i - 1]) / (pos[i] - pos[i - 1]))
			break
	return LabBoard.mixc(LabBoard.BG, c, dim)


## A thermal camera's ramp (black, violet, crimson, orange, straw, white).
func _iron(u: float, dim: float) -> Color:
	var stops: Array[Color] = [LabBoard.BG, Color("#2c1446"), Color("#86203c"), LabBoard.EMBER, LabBoard.NEXT, LabBoard.HOT, LabBoard.WHITE]
	var pos: Array[float] = [0.0, 0.16, 0.36, 0.56, 0.72, 0.88, 1.0]
	u = clampf(u, 0.0, 1.0)
	var c := stops[0]
	for i in range(1, stops.size()):
		if u <= pos[i]:
			c = LabBoard.mixc(stops[i - 1], stops[i], (u - pos[i - 1]) / (pos[i] - pos[i - 1]))
			break
	return LabBoard.mixc(LabBoard.BG, c, dim)


## The Foundry's own parts, by name, for the test stand.
func _solari_parts() -> Array[String]:
	if _parts.is_empty():
		var ids: Array = DB.modules.keys()
		ids.sort()
		for id in ids:
			var m: ModuleData = DB.modules[id]
			if m.manufacturer == &"solari":
				_parts.append(m.name.to_upper())
		if _parts.is_empty():
			_parts.append("FIREBRICK LINING")
	return _parts


## The foot's two lines (a rule over them): `l1`, `l2` at rest; pointed at,
## the pilot and the sign-in. Returns the rule's y.
func _foot(l1: String, c1: Color, l2: String, c2: Color) -> int:
	var a := g.area()
	var x0 := a.position.x
	var w := a.size.x
	var ly := a.end.y - 19
	g.draw_rect(Rect2(x0 + 4, ly - 4, w - 8, 1), k.ink(0.25))
	if g.state == LabLogin.LOGO:
		k.say(x0 + 8, ly, k.fit(l1, w - 16), c1)
		k.say(x0 + 8, ly + 8, l2, c2)
	else:
		k.text(x0 + 8, ly, k.fit("PILOT %s" % k.ship(), w - 16), k.ink(0.9))
		if g.state == LabLogin.SIGNING:
			k.text(x0 + 8, ly + 8, "SIGNING IN", k.ink(0.9))
		else:
			k.text(x0 + 8, ly + 8, "CLICK TO SIGN IN", k.cue())
	return ly - 4


## A line of words that must fit `wmax`: the long form, else the short.
func _pick(long_s: String, short_s: String, wmax: int) -> String:
	return long_s if k.say_w(long_s) <= wmax else short_s


# ================================================================== SOL1: margin test

const M_LO := 1000.0
const M_HI := 2300.0
const M_OLD := 1400.0
const M_OURS := 2100.0
## How fast the chart paper runs (px a second) and how long each part is up.
const M_PXS := 7.0
const M_EACH := 12.0


func _m_temp(t: float) -> float:
	return 1800.0 + 95.0 * sin(t * 0.29) + 42.0 * sin(t * 1.07 + 1.3) + 18.0 * sin(t * 2.9 + 0.4)


func _paint_1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var dim := k.fade()
	var t := _ct
	var mk := _mk()
	# THE HEADER: the owner, and which stand this is
	var hx := k.head(x0 + 4, y0 + 3)
	var st := "TEST STAND 3"
	if a.end.x - 6 - LabBoard.tw(st) > hx + 8:
		k.text(a.end.x - 6 - LabBoard.tw(st), y0 + 6, st, k.ink(0.55))
	# THE FOOT: the part on the stand, and how hot it is held
	var parts := _solari_parts()
	var part: String = parts[int(floorf(t / M_EACH)) % parts.size()]
	var now := _m_temp(t)
	var over := int(now - M_OLD)
	var l2 := _pick("%d K · %d K OVER THE OLD LIMIT" % [int(now), over], "%d K · OLD LIMIT +%d K" % [int(now), over], w - 16)
	var rule := _foot("ON TEST: " + part, k.ink(0.95), l2, k.ink(0.6))
	# THE CHART
	var cl := x0 + 8
	var cr := a.end.x - 8
	var ct := y0 + 19
	var cb := rule - 6
	var span := float(cb - ct)
	var yv := func(temp: float) -> int:
		return cb - roundi((temp - M_LO) / (M_HI - M_LO) * span)
	# the paper's grid, running left with the trace
	var off := int(floorf(t * M_PXS))
	for x in range(cl + 1, cr):
		if posmod(x + off, 24) == 0:
			for y in range(ct, cb):
				if posmod(y, 3) == 0:
					k.px(x, y, k.ink(0.11 * dim))
	# the axes
	g.draw_rect(Rect2(cl, ct, 1, cb - ct + 1), k.ink(0.35 * dim))
	g.draw_rect(Rect2(cl, cb, cr - cl, 1), k.ink(0.35 * dim))
	# THE TWO LIMITS: the guild's, dotted; the Foundry's, solid, in its colour
	var y_old: int = yv.call(M_OLD)
	var y_ours: int = yv.call(M_OURS)
	var lo_s := _pick("OLD SAFE LIMIT 1400 K", "OLD LIMIT 1400 K", cr - cl - 40)
	var hi_s := _pick("FOUNDRY LIMIT 2100 K", "OUR LIMIT 2100 K", cr - cl - 40)
	k.text(cl + 4, y_old + 4, lo_s, k.ink(0.6))
	k.text(cl + 4, y_ours - 8, hi_s, LabBoard.mixc(LabBoard.BG, mk, 0.95))
	k._keep.append(Rect2i(cl + 2, y_ours - 10, LabBoard.tw(hi_s) + 4, 9))
	for x in range(cl + 1, cr):
		if posmod(x, 2) == 0:
			k.px(x, y_old, k.ink(0.45 * dim))
		k.px(x, y_ours, LabBoard.mixc(LabBoard.BG, mk, 0.8 * dim))
	# THE TRACE, newest at the pen; under it the heat, dithered down to the axis
	var pen := cr - 6
	var prev := -1
	for x in range(cl + 1, pen + 1):
		var temp := _m_temp(t - float(pen - x) / M_PXS)
		var y: int = yv.call(temp)
		var u := 0.5 + 0.45 * (temp - M_OLD) / (M_OURS - M_OLD)
		# the glow under it, down to the old limit
		for yy in range(y + 1, y_old):
			var d := float(yy - y) / float(maxi(1, y_old - y))
			if LabBoard.bayer(x, yy) < 0.16 * pow(1.0 - d, 2.4):
				k.px(x, yy, _heat(0.42, 0.75 * dim))
		var c := _heat(u, dim)
		if prev < 0:
			k.px(x, y, c)
		else:
			for yy in range(mini(prev, y), maxi(prev, y) + 1):
				k.px(x, yy, c)
		prev = y
	# the pen, and its tick out to the edge
	var py: int = yv.call(now)
	g.draw_rect(Rect2(pen - 1, py - 1, 3, 3), LabBoard.mixc(LabBoard.BG, LabBoard.WHITE, dim))
	for x in range(pen + 2, cr):
		k.px(x, py, k.ink(0.5 * dim))


# ================================================================== SOL2: heat gauge

const H_CYCLE := 14.0
const H_PLAYS := [0.6, 1.7, 2.8, 3.9, 5.0, 6.1, 7.2]
const H_STEPS := [3, 2, 3, 2, 4, 3, 3]
const H_VENT := [10.4, 12.6]


## The heat now in the cycle (a card's heat landing every 1.1 s, a hold, a
## vent), and the cap it is drawn against.
func _h_heat(t: float, cap: int) -> float:
	var tt := fposmod(t, H_CYCLE)
	var total := 0
	for s: int in H_STEPS:
		total += s
	var kscale := float(cap - 2) / float(total)
	var hv := 0.0
	for i in H_PLAYS.size():
		var e := clampf((tt - float(H_PLAYS[i])) / 0.35, 0.0, 1.0)
		hv += float(H_STEPS[i]) * kscale * (1.0 - pow(1.0 - e, 3.0))
	if tt > float(H_VENT[0]):
		var v := clampf((tt - float(H_VENT[0])) / (float(H_VENT[1]) - float(H_VENT[0])), 0.0, 1.0)
		hv *= 1.0 - smoothstep(0.0, 1.0, v)
	return hv


## The Solari shot this gauge prices: the ship's own, else the issued Ember Lance.
func _h_card() -> Array:
	for m: ModuleData in Run.installed:
		if m.manufacturer != &"solari":
			continue
		for c: CardData in m.cards:
			if c.heat_scale > 0 and c.damage > 0:
				return [m.name.to_upper(), c]
	var em: ModuleData = DB.modules.get(&"emberlance")
	if em != null and not em.cards.is_empty():
		return [em.name.to_upper(), em.cards[0]]
	return []


func _paint_2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var dim := k.fade()
	var mk := _mk()
	var cap := 22
	if Run.hull != null:
		cap = maxi(6, Run.heat_cap())
	var hv := _h_heat(_ct, cap)
	var heat := int(floorf(hv + 0.001))
	# THE GAUGE, a half round on the left
	var colw := clampi(w * 47 / 100, 118, 200)
	var r := mini((w - colw - 18) / 2, h - 48)
	var cx := x0 + 8 + r
	var cy := y0 + (h - 22 - r) / 2 + r + 2
	var bt := maxi(5, r / 8)
	var fill := hv / float(cap)
	var bp := k._painter()
	for dy in range(-r, 1):
		for dx in range(-r, r + 1):
			var d := sqrt(float(dx * dx + dy * dy))
			if d > float(r - 3) or d < float(r - 3 - bt):
				continue
			var ang := atan2(float(-dy), float(dx))
			var u := 1.0 - ang / PI
			if u <= fill:
				k.px(cx + dx, cy + dy, _heat(0.42 + 0.55 * u, dim))
			elif LabBoard.bayer(cx + dx, cy + dy) < 0.25:
				k.px(cx + dx, cy + dy, k.ink(0.3 * dim))
	# the rim and a tick for every heat (every fifth long)
	for i in cap + 1:
		var ang := PI * (1.0 - float(i) / float(cap))
		var l0 := r - 1
		var l1 := r + (2 if i % 5 == 0 or i == cap else 0)
		k.line(Vector2i(roundi(cx + cos(ang) * l0), roundi(cy - sin(ang) * l0)),
			Vector2i(roundi(cx + cos(ang) * l1), roundi(cy - sin(ang) * l1)), k.ink((0.7 if i % 5 == 0 else 0.4) * dim))
	# the needle and its hub
	var na := PI * (1.0 - fill)
	var tip := Vector2i(roundi(cx + cos(na) * (r - bt - 6)), roundi(cy - sin(na) * (r - bt - 6)))
	k.line(Vector2i(cx, cy), tip, LabBoard.mixc(LabBoard.BG, LabBoard.WHITE, dim))
	bp._disc(g, cx, cy, 3, LabBoard.mixc(LabBoard.BG, mk, dim))
	var hs := "HEAT %d OF %d" % [heat, cap]
	k.text(cx - LabBoard.tw(hs) / 2, cy + 8, hs, k.ink(0.85))
	# THE COLUMN: the owner, then the shot at this heat, or the sign-in
	var cx0 := cx + r + 12
	var cw := a.end.x - 6 - cx0
	k.head(cx0, y0 + 3)
	var y := y0 + 22
	var pitch := 10 if h < 200 else 13
	if g.state != LabLogin.LOGO:
		k.text(cx0, y, "OBSERVER", k.ink(0.5))
		y += pitch
		k.text(cx0, y, "PILOT", k.ink(0.75))
		y += pitch
		k.text(cx0, y, k.fit(k.ship(), cw), k.ink(1.0))
		y += pitch + 4
		if g.state == LabLogin.SIGNING:
			k.text(cx0, y, "SIGNING IN", k.ink(0.9))
		else:
			k.text(cx0, y, "CLICK TO SIGN IN", k.cue())
		return
	var pick := _h_card()
	if pick.is_empty():
		return
	var c: CardData = pick[1]
	k.text(cx0, y, k.fit(String(pick[0]), cw), k.ink(0.55))
	y += pitch
	k.text(cx0, y, k.fit(c.name.to_upper(), cw), k.ink(0.95))
	y += pitch
	k.text(cx0, y, k.fit(_pick("%d DMG, +1 PER %d HEAT" % [c.damage, c.heat_scale], "%d +1/%d HEAT" % [c.damage, c.heat_scale], cw), cw), k.ink(0.6))
	y += pitch + 6
	# what it hits for now, lit as it goes up a step
	var dmg := c.damage + heat / c.heat_scale
	var ds := "%d DMG" % dmg
	var prev_dmg := c.damage + int(floorf(_h_heat(_ct - 0.45, cap) + 0.001)) / c.heat_scale
	var lit := prev_dmg < dmg
	k.text(cx0, y, ds, LabBoard.mixc(LabBoard.BG, LabBoard.WHITE if lit else mk, dim), 16)
	y += 18
	var tt := fposmod(_ct, H_CYCLE)
	var note := ""
	if tt > float(H_VENT[0]) and heat > 0:
		note = "VENTING"
	elif heat < cap:
		note = "NEXT +1 AT %d HEAT" % ((heat / c.heat_scale + 1) * c.heat_scale)
	if note != "" and LabBoard.tw(note) <= cw:
		k.text(cx0, y, note, k.ink(0.55))


# ================================================================== SOL3: radiator watch

const R_PULSE := 1.7
const R_SPEED := 38.0


func _paint_3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var dim := k.fade()
	var t := _ct
	# THE HEADER
	var hx := k.head(x0 + 4, y0 + 3)
	var wing := _pick("RADIATOR WING 2 · THERMAL", "WING 2 · THERMAL", a.end.x - 6 - hx - 8)
	if a.end.x - 6 - k.say_w(wing) > hx + 8:
		k.say(a.end.x - 6 - k.say_w(wing), y0 + 6, wing, k.ink(0.55))
	# THE SCENE, between the header and the foot (its numbers worked out first)
	var sx0 := x0 + 6
	var sy0 := y0 + 17
	var sx1 := a.end.x - 30
	var sy1 := a.end.y - 28
	var cy := (sy0 + sy1) / 2
	var hull_w := 12
	var big := a.size.y >= 200
	var sp := 20 if big else 14
	var fw := sp - 4
	var fx0 := sx0 + hull_w + 8
	var n := maxi(3, (sx1 - 6 - fx0) / sp)
	var truss_end := fx0 + n * sp
	var fh := (sy1 - sy0) / 2 - 5
	# each fin's heat: nearer the core runs hotter, and a coolant pulse warms
	# a fin as it passes
	var heats: Array[float] = []
	var hottest := 0
	for i in n:
		var base := 0.72 - 0.34 * float(i) / float(maxi(1, n - 1)) + 0.04 * sin(t * 0.4 + float(i) * 1.7)
		var fxm := float(fx0 + i * sp + fw / 2 - (sx0 + hull_w))
		var since := fposmod(t - fxm / R_SPEED, R_PULSE)
		base += 0.16 * exp(-since / 0.7)
		heats.append(base)
		if base > heats[hottest]:
			hottest = i
	var total := 0.0
	for hh in heats:
		total += hh
	var mw := 0.55 * total
	var l2 := _pick("HOTTEST FIN %d · %d K" % [hottest + 1, int(420.0 + 820.0 * heats[hottest])],
		"FIN %d · %d K" % [hottest + 1, int(420.0 + 820.0 * heats[hottest])], w - 16)
	_foot("HEAT OUT %.1f MW" % mw, k.ink(0.95), l2, k.ink(0.6))
	# the stars behind, very slow
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 70:
		var sx := sx0 + int(fposmod(rng.randf() * float(sx1 - sx0) - t * 0.8, float(sx1 - sx0)))
		var sy := sy0 + int(rng.randf() * float(sy1 - sy0))
		k.px(sx, sy, k.ink((0.1 + 0.25 * rng.randf()) * dim))
	# THE HULL'S EDGE, on the left, its vent slots warm
	for y in range(sy0, sy1):
		for x in range(sx0, sx0 + hull_w):
			var e := x == sx0 + hull_w - 1
			k.px(x, y, _iron(0.3 if e else 0.2, dim))
	var vy := sy0 + 4
	while vy < sy1 - 3:
		for x in range(sx0 + 3, sx0 + hull_w - 3):
			k.px(x, vy, _iron(0.55 + 0.1 * sin(t * 1.3 + float(vy)), dim))
		vy += 6
	# THE TRUSS, laced, out to the last fin
	for x in range(sx0 + hull_w, truss_end):
		k.px(x, cy - 3, _iron(0.38, dim))
		k.px(x, cy + 3, _iron(0.38, dim))
		var ph := posmod(x - sx0, 6)
		k.px(x, cy - 3 + ph, _iron(0.3, dim))
	# THE FINS, above and below the truss: ribbed panels, hottest at the root
	for i in n:
		var fxa := fx0 + i * sp
		for side: int in [-1, 1]:
			for j in fh:
				var y := cy + side * (5 + j)
				var fall := pow(1.0 - float(j) / float(fh), 0.8)
				for x in range(fxa, fxa + fw):
					var edge := x == fxa or x == fxa + fw - 1 or j == fh - 1
					var rib := posmod(x - fxa, 2) == 1
					var u := heats[i] * (0.25 + 0.75 * fall)
					if edge:
						u = maxf(u * 0.8, 0.22)
					elif not rib:
						u *= 0.72
					k.px(x, y, _iron(u, dim))
			# the coolant run up the fin's middle, from the truss
			for j in range(0, 4):
				k.px(fxa + fw / 2, cy + side * (1 + j), _iron(heats[i] * 0.9, dim))
	# THE PULSES, white-hot, out along the truss
	var travel := float(truss_end - (sx0 + hull_w))
	var np := int(travel / (R_SPEED * R_PULSE)) + 2
	for pi in np:
		var d := (fposmod(t, R_PULSE) + float(pi) * R_PULSE) * R_SPEED
		if d > travel:
			continue
		var px0 := sx0 + hull_w + int(d)
		for tl in 6:
			k.px(px0 - tl, cy, _iron(0.98 - 0.12 * float(tl), dim))
	# THE CAMERA'S MARKS: its corners, and its scale on the right
	g._brackets(Rect2i(sx0 - 2, sy0 - 2, sx1 - sx0 + 4, sy1 - sy0 + 4), 4, k.ink(0.5 * dim))
	var bx := a.end.x - 16
	for y in range(sy0 + 8, sy1 - 8):
		var u := 1.0 - float(y - sy0 - 8) / float(maxi(1, sy1 - sy0 - 17))
		g.draw_rect(Rect2(bx, y, 3, 1), _iron(u, dim))
	k.sayc(bx + 1, sy0 - 1, "HOT", k.ink(0.55))
	k.sayc(bx + 1, sy1 - 5, "COLD", k.ink(0.55))
