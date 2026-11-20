class_name GameCultureLook
extends RefCounted

## Culture Dish's picture, as `culture2.js` draws it: the bench, the dish and its agar and stains
## drawn once into a pixel buffer; each frame the colony as a lit blob field over it, then the ghost
## rings, the food, the drops and splashes, and the kit.
## Why: docs/why/MiniGame.md#culture-dish

const W := GameCulture.W
const H := GameCulture.H
const CX := GameCulture.CX
const CY := GameCulture.CY
const AR := GameCulture.AR
const RO := GameCulture.RO
const STEPMS := GameCulture.STEPMS


static func _put(bg: PackedByteArray, x: int, y: int, c: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	var k := (y * W + x) * 4
	bg[k] = (c >> 16) & 255
	bg[k + 1] = (c >> 8) & 255
	bg[k + 2] = c & 255
	bg[k + 3] = 255


static func _hex(c: Color) -> int:
	var v := MiniPix.c8(c)
	return (v.x << 16) | (v.y << 8) | v.z


## The static picture: bench, the dish's shadow, glass rim, agar, its specks and the stains.
static func background(g: GameCulture) -> void:
	var bg := PackedByteArray()
	bg.resize(W * H * 4)
	var panel := _hex(MiniPix.PANEL)
	var lo := _hex(MiniPix.BEVEL_LO)
	for y in H:
		for x in W:
			_put(bg, x, y, panel)
	for y in H:
		for x in W:
			if GameSling.hyp(x - CX - 3, y - CY - 4) <= RO + 1 and GameSling.hyp(x - CX, y - CY) > RO - 1:
				_put(bg, x, y, lo)
	var noise := PackedFloat32Array()
	noise.resize(W * H)
	g.phase.resize(W * H)
	for i in W * H:
		noise[i] = g.hr()
		g.phase[i] = g.hr()
	g.sm.resize(W * H)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var a := 0.0
			for j in range(-1, 2):
				for i in range(-1, 2):
					a += noise[(y + j) * W + x + i]
			g.sm[y * W + x] = a / 9.0
	_dish(g, bg, lo)
	_stains(g, bg)
	var ln := _hex(MiniPix.LINE)
	for ab: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0)]:
		for k in 3:
			_put(bg, CX + ab.x * (RO + 3 + k), CY + ab.y * (RO + 3 + k), ln)
	g.bg = bg


static func _dish(g: GameCulture, bg: PackedByteArray, lo: int) -> void:
	var agar := GameCulture.AGAR
	var ice := _hex(MiniPix.ICE)
	var chill := _hex(MiniPix.CHILL)
	var cold := _hex(MiniPix.COLD)
	var rim := _hex(GameCulture.RIM_DK)
	for y in H:
		for x in W:
			var dx := x - CX
			var dy := y - CY
			var d := GameSling.hyp(dx, dy)
			if d <= AR - 0.5:
				g.dish.append(y * W + x)
				var lit := 0.5 + 0.32 * (-dx - dy) / (AR * 1.41) + (g.sm[y * W + x] - 0.5) * 0.5
				var k := lit * (agar.size() - 1.2) + MiniPix.bay(x, y) - 0.5
				_put(bg, x, y, agar[clampi(MiniPix.jr(k), 1, agar.size() - 2)])
			elif d <= RO + 0.4:
				var a := atan2(float(dy), float(dx))
				var lt := (-cos(a) - sin(a)) / 1.41
				var col := lo
				if not (d > RO - 0.6 or d < AR + 0.6):
					var t := 0.45 + 0.4 * lt + (0.1 if d > RO - 2.5 else 0.0)
					var b := MiniPix.bay(x, y) * 0.3
					col = ice if t + b > 0.95 else (chill if t + b > 0.62 else (cold if t > 0.25 else rim))
				_put(bg, x, y, col)
	for i in g.dish:
		var x := i % W
		var y := i / W
		var d := GameSling.hyp(x - CX, y - CY)
		if d > AR - 2.2:
			var a := atan2(float(y - CY), float(x - CX))
			if cos(a) + sin(a) < 0.3 or d > AR - 1.2:
				_put(bg, x, y, agar[0])
	var ang := -2.55
	while ang <= -1.75:
		_put(bg, MiniPix.jr(CX + (RO - 2) * cos(ang)), MiniPix.jr(CY + (RO - 2) * sin(ang)), 0xffffff)
		ang += 0.01
	ang = 0.75
	while ang <= 1.0:
		_put(bg, MiniPix.jr(CX + (RO - 2) * cos(ang)), MiniPix.jr(CY + (RO - 2) * sin(ang)), chill)
		ang += 0.01
	for k in 26:
		var an := g.hr() * PI * 2.0
		var r := g.hr() * (AR - 6)
		var x := MiniPix.jr(CX + r * cos(an))
		var y := MiniPix.jr(CY + r * sin(an))
		if g.hr() < 0.5:
			_put(bg, x, y, agar[5])
			_put(bg, x + 1, y + 1, agar[1])
		else:
			_put(bg, x, y, agar[1])


## Stains: dark blots with a red rim, each wobbled by three draws of the look's hash.
static func _stains(g: GameCulture, bg: PackedByteArray) -> void:
	var sta := GameCulture.STA
	var bad := _hex(MiniPix.BAD)
	for st: int in g.p.stains:
		var o := g.pos[st]
		var rr := float(g.c.s) * 0.95
		var wob: Array[float] = [g.hr(), g.hr(), g.hr()]
		for y in range(-9, 10):
			for x in range(-9, 10):
				var a := atan2(float(y), float(x))
				var d := GameSling.hyp(x, y)
				var edge := rr * (1.0 + 0.18 * sin(3.0 * a + wob[0] * 6.0) + 0.12 * sin(5.0 * a + wob[1] * 6.0))
				if d > edge + 1.2:
					continue
				var xx := o.x + x
				var yy := o.y + y
				if d > edge:
					_put(bg, xx, yy, bad if MiniPix.bay(xx, yy) < 0.45 else sta[2])
				else:
					_put(bg, xx, yy, sta[0] if d < edge * 0.45 else (sta[1] if d < edge * 0.8 or MiniPix.bay(xx, yy) < 0.5 else sta[2]))


# ---------------------------------------------------------------- shapes

## A midpoint circle; with `t`, only the pixels the 4x4 dither lights at that density.
static func circ(px: MiniPix, cx: int, cy: int, r: int, c: Color, t := INF) -> void:
	var x := r
	var y := 0
	var e := 1 - r
	var seen: Dictionary[Vector2i, bool] = {}
	while x >= y:
		for q: Vector2i in [Vector2i(x, y), Vector2i(y, x), Vector2i(-y, x), Vector2i(-x, y), Vector2i(-x, -y), Vector2i(-y, -x), Vector2i(y, -x), Vector2i(x, -y)]:
			var at := Vector2i(cx, cy) + q
			if seen.has(at):
				continue
			seen[at] = true
			if MiniPix.bay(at.x, at.y) >= t:
				continue
			px.rect(at.x, at.y, 1, 1, c)
		y += 1
		if e < 0:
			e += 2 * y + 1
		else:
			x -= 1
			e += 2 * (y - x) + 1


static func disc(px: MiniPix, cx: int, cy: int, r: int, c: Color, t := INF) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y > r * r + r * 0.6:
				continue
			if MiniPix.bay(cx + x, cy + y) >= t:
				continue
			px.rect(cx + x, cy + y, 1, 1, c)


## A lit droplet: rim in ramp[0], the rest shaded from the top-left.
static func ball(px: MiniPix, cx: int, cy: int, r: int, ramp: Array[Color]) -> void:
	var rr := r * r + r * 0.8
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y > rr:
				continue
			var edge := (x - 1) * (x - 1) + y * y > rr or (x + 1) * (x + 1) + y * y > rr or x * x + (y - 1) * (y - 1) > rr or x * x + (y + 1) * (y + 1) > rr
			var col := ramp[0]
			if not edge:
				var nx := x / (r + 0.5)
				var ny := y / (r + 0.5)
				var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
				var l := maxf(0.0, -nx * 0.55 - ny * 0.62 + nz * 0.56)
				col = ramp[maxi(1, mini(ramp.size() - 1, MiniPix.jr(l * (ramp.size() - 1) + MiniPix.bay(cx + x, cy + y) - 0.5)))]
			px.rect(cx + x, cy + y, 1, 1, col)


static func _drop_shape(px: MiniPix, x: int, y: int) -> void:
	var rows: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 1), Vector2i(-1, 2), Vector2i(-1, 2), Vector2i(-2, 3), Vector2i(-2, 3), Vector2i(-2, 3), Vector2i(-1, 2)]
	var dp := GameCulture.DROP
	for j in rows.size():
		px.rect(x + rows[j].x - 1, y - 7 + j, rows[j].y + 2, 1, dp[0])
	px.rect(x - 1, y + 1, 3, 1, dp[0])
	for j in range(1, rows.size()):
		px.rect(x + rows[j].x, y - 7 + j, rows[j].y, 1, dp[2] if j < 4 else dp[1])
	px.rect(x - 1, y - 3, 1, 2, dp[3])


# ---------------------------------------------------------------- a frame

static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func _ease_back(t: float) -> float:
	return 1.0 + 2.6 * pow(t - 1.0, 3.0) + 1.6 * pow(t - 1.0, 2.0)


## The colony as blobs: [x, y, r, dead] each, the seeds and every birth sliding out of its parent.
static func _blobs(g: GameCulture, now: float) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	if g.run.is_empty():
		return out
	for i: int in g.run.seeds:
		out.append(PackedFloat64Array([g.pos[i].x, g.pos[i].y, g.rad, 0.0]))
	var st: Array = g.run.step_t
	var frames: Array = g.run.ev.r.frames
	for k in st.size():
		var el := now - float(st[k])
		var u := minf(1.0, el / (STEPMS * 0.75))
		for b: Vector3i in frames[k]:
			var a := g.pos[b.y]
			var z := g.pos[b.x]
			var m := _ease_out(u)
			var gr := _ease_back(minf(1.0, u * 1.1))
			var x := a.x + (z.x - a.x) * m
			var y := a.y + (z.y - a.y) * m
			var r := g.rad * maxf(0.15, minf(1.08, gr))
			var dead := 0.0
			if b.z == 0:
				var w := maxf(0.0, (el - STEPMS * 0.55) / (STEPMS * 0.5))
				if w > 0.0:
					dead = 1.0
					r = g.rad * maxf(0.55, 0.9 - 0.35 * minf(1.0, w))
			out.append(PackedFloat64Array([x, y, r, dead]))
	return out


static func _field(f: PackedFloat32Array, bx: float, by: float, rad: float) -> void:
	var ri := rad * 1.9
	var ri2 := ri * ri
	var x0 := maxi(0, floori(bx - ri))
	var x1 := mini(W - 1, ceili(bx + ri))
	var y0 := maxi(0, floori(by - ri))
	var y1 := mini(H - 1, ceili(by + ri))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x - bx
			var dy := y - by
			var d2 := dx * dx + dy * dy
			if d2 >= ri2:
				continue
			var u := 1.0 - d2 / ri2
			f[y * W + x] += u * u * 1.0


## The colony's pixels over the static picture: in where the field passes its wobbling threshold,
## its rim dark, its body lit by the field's slope, a rare cell glinting.
static func _colony(g: GameCulture, buf: PackedByteArray, t: float) -> void:
	var fl := g.fl
	var fd := g.fd
	var ins := g.inside_
	for i in g.dish:
		var v := fl[i] + fd[i]
		if v < 0.2:
			continue
		var th := 0.5 + (g.sm[i] - 0.5) * 0.55 + 0.035 * sin(t / 380.0 + g.phase[i] * 6.28)
		if v >= th:
			ins[i] = 1
	for i in g.dish:
		if not ins[i]:
			continue
		var ramp := GameCulture.GREY if fd[i] > fl[i] else GameCulture.GREEN
		var col := ramp[0]
		if ins[i - 1] and ins[i + 1] and ins[i - W] and ins[i + W]:
			var gx := (fl[i + 1] + fd[i + 1]) - (fl[i - 1] + fd[i - 1])
			var gy := (fl[i + W] + fd[i + W]) - (fl[i - W] + fd[i - W])
			var v := fl[i] + fd[i]
			var lv := 2.0 + (gx + gy) * 5.5 / (v + 0.4) + (0.35 if v > 1.15 else 0.0)
			if not ins[i - W - 1] or not ins[i - 2 * W] or not ins[i - 2]:
				lv += 0.8
			if not ins[i + W + 1] or not ins[i + 2 * W]:
				lv -= 0.9
			var k := clampi(MiniPix.jr(lv + MiniPix.bay(i % W, i / W) - 0.5), 1, 4)
			var ph := g.phase[i]
			if k < 4 and ph > 0.992 and int(t / 140.0 + ph * 40.0) % 5 == 0:
				k = 4
			col = ramp[k]
		var q := i * 4
		buf[q] = (col >> 16) & 255
		buf[q + 1] = (col >> 8) & 255
		buf[q + 2] = col & 255


static func render(g: GameCulture, now: float) -> void:
	var px := g.px
	var t := now - GameCulture.T0
	g.fl.fill(0.0)
	g.fd.fill(0.0)
	g.inside_.fill(0)
	var blobs := _blobs(g, now)
	for b in blobs:
		_field(g.fd if b[3] > 0.0 else g.fl, b[0], b[1], b[2])
	var buf := g.bg.duplicate()
	if not blobs.is_empty():
		_colony(g, buf, t)
	px.img.set_data(W, H, false, Image.FORMAT_RGBA8, buf)
	var gh := _ghost(g)
	_draw_ghost(g, gh, t)
	_food(g, gh, t)
	for k in range(g.pulses.size() - 1, -1, -1):
		var pu := g.pulses[k]
		var u := (now - float(pu.t)) / 600.0
		if u >= 1.0:
			g.pulses.remove_at(k)
			continue
		circ(px, pu.x, pu.y, MiniPix.jr(3.0 + u * 9.0), MiniPix.MARK, 1.0 - u)
		if u > 0.15:
			circ(px, pu.x, pu.y, MiniPix.jr(2.0 + u * 6.0), MiniPix.HOT, 0.7 * (1.0 - u))
	_drops(g, now)
	_hud(g, now, t)


## The ghost: every ring still to come and the food it reaches, for the seeds down (and the one under
## the pointer), or for the growth under way; {} when there is none.
static func _ghost(g: GameCulture) -> Dictionary[String, Variant]:
	var sd: Array[int] = []
	var from := 0
	if g.mode == "place":
		sd = g.seeds.duplicate()
		var hv := g.hover
		if hv >= 0 and not g.seeds.has(hv) and not g.food_set.has(hv) and g.stain_mask[hv] == 0:
			if sd.size() >= int(g.p.nSeeds):
				sd.pop_front()
			sd.append(hv)
		if sd.is_empty():
			return _none()
	elif not g.run.is_empty() and g.mode == "grow":
		from = (g.run.step_t as Array).size()
	else:
		return _none()
	var r: Dictionary = g.run.ev.r if g.mode == "grow" else GameCulture.simulate(g.p.B, g.p.steps, sd, g.stain_mask)
	var fed: Dictionary[int, bool] = {}
	var alive: PackedByteArray = r.alive
	for f: int in g.p.food:
		if alive[f]:
			fed[f] = true
	var out: Dictionary[String, Variant] = {}
	out.assign({r = r, from = from, fed = fed})
	return out


static func _none() -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	return out


static func _draw_ghost(g: GameCulture, gh: Dictionary, t: float) -> void:
	if gh.is_empty():
		return
	var px := g.px
	var pulse := 0.55 + 0.25 * sin(t / 220.0)
	var frames: Array = gh.r.frames
	var from: int = gh.from
	var rr := MiniPix.jr(g.rad) - 1
	for k in frames.size():
		if k < from:
			continue
		var nxt := k == from
		var a := pulse if nxt else maxf(0.18, 0.42 - (k - from) * 0.08)
		for b: Vector3i in frames[k]:
			var o := g.pos[b.x]
			if b.z == 0:
				var fl := int(t / 250.0) % 2
				px.rect(o.x - 2, o.y - 2, 1, 1, MiniPix.BAD)
				px.rect(o.x + 2, o.y - 2, 1, 1, MiniPix.BAD)
				px.rect(o.x - 1, o.y - 1, 3, 3, MiniPix.BAD if fl == 1 else GameCulture.DEAD_DK)
				px.rect(o.x - 2, o.y + 2, 1, 1, MiniPix.BAD)
				px.rect(o.x + 2, o.y + 2, 1, 1, MiniPix.BAD)
				continue
			if nxt:
				disc(px, o.x, o.y, rr, MiniPix.MARK, a * 0.3)
				circ(px, o.x, o.y, rr, MiniPix.MARK, a + 0.2)
				continue
			# later rings: a seed-dot per spot, and the final edge outlined
			px.rect(o.x - 1, o.y - 1, 2, 2, GameCulture.GHOST_DK)
			px.rect(o.x - 1, o.y - 1, 1, 1, MiniPix.GOOD)
			if k == frames.size() - 1:
				circ(px, o.x, o.y, rr, MiniPix.GOOD, 0.5)


static func _food(g: GameCulture, gh: Dictionary, t: float) -> void:
	var px := g.px
	for f: int in g.p.food:
		var o := g.pos[f]
		if g.inside_[o.y * W + o.x]:
			continue
		var tw := int(t / 220.0 + f * 3) % 9 == 0
		px.rect(o.x - 2, o.y - 1, 5, 3, MiniPix.BEVEL_LO)
		px.rect(o.x - 1, o.y - 2, 3, 5, MiniPix.BEVEL_LO)
		px.rect(o.x - 1, o.y - 1, 2, 2, MiniPix.ICE)
		px.rect(o.x + 1, o.y, 1, 1, MiniPix.CHILL)
		px.rect(o.x, o.y + 1, 1, 1, MiniPix.CHILL)
		px.rect(o.x - 1, o.y - 1, 1, 1, Color.WHITE if tw else MiniPix.ICE)
		if not gh.is_empty():
			var fed: bool = (gh.fed as Dictionary).has(f)
			circ(px, o.x, o.y, 4, MiniPix.MARK if fed else MiniPix.BAD, 0.9 if fed else 0.55 + 0.3 * sin(t / 200.0))


## The seeds down, the drops falling (a splash where each lands), ripples, spray and the hover ring.
static func _drops(g: GameCulture, now: float) -> void:
	var px := g.px
	if g.mode == "place":
		for i in g.seeds:
			var falling := false
			for d in g.drops:
				falling = falling or int(d.i) == i
			if not falling:
				ball(px, g.pos[i].x, g.pos[i].y, 3, GameCulture.DROP)
	if not g.run.is_empty():
		for i: int in g.run.seeds:
			px.rect(g.pos[i].x, g.pos[i].y, 1, 1, MiniPix.MARK)
	for k in range(g.drops.size() - 1, -1, -1):
		var d := g.drops[k]
		var u := (now - float(d.t)) / 280.0
		var o := g.pos[int(d.i)]
		if u >= 1.0:
			g.drops.remove_at(k)
			_splash(g, o.x, o.y, now)
			continue
		var y := MiniPix.jr(o.y - 34.0 * (1.0 - u * u))
		var sh := MiniPix.jr(1.0 + u * 2.0)
		px.rect(o.x - sh, o.y + 2, sh * 2 + 1, 1, GameCulture.SHADOW)
		_drop_shape(px, o.x, y)
	for k in range(g.ripples.size() - 1, -1, -1):
		var r := g.ripples[k]
		var u := (now - float(r.t)) / 450.0
		if u >= 1.0:
			g.ripples.remove_at(k)
			continue
		circ(px, r.x, r.y, MiniPix.jr(2.0 + u * 7.0), r.c, 0.8 * (1.0 - u))
	for k in range(g.parts.size() - 1, -1, -1):
		var q := g.parts[k]
		var u := (now - float(q.t)) / float(q.life)
		if u >= 1.0:
			g.parts.remove_at(k)
			continue
		px.rect(MiniPix.jr(float(q.x) + float(q.vx) * u), MiniPix.jr(float(q.y) + float(q.vy) * u + 10.0 * u * u), 1, 1, q.c)
	if g.mode == "place" and g.hover >= 0 and not g.seeds.has(g.hover):
		circ(px, g.pos[g.hover].x, g.pos[g.hover].y, 4, MiniPix.TRACTOR, 0.55)


static func _splash(g: GameCulture, x: int, y: int, now: float) -> void:
	g.ripples.append({x = x, y = y, t = now, c = MiniPix.TRACTOR})
	for k in 7:
		var a := -PI * (0.1 + 0.8 * k / 6.0)
		var vx := cos(a) * (5.0 + g.hr() * 4.0)
		var vy := sin(a) * (5.0 + g.hr() * 3.0)
		g.parts.append({x = x, y = y, vx = vx, vy = vy, t = now, life = 380.0 + g.hr() * 120.0, c = MiniPix.TRACTOR if k % 2 == 1 else MiniPix.MARK})


static func _hud(g: GameCulture, now: float, t: float) -> void:
	var px := g.px
	var fed := int(g.run.covered) if not g.run.is_empty() else 0
	var nf := (g.p.food as Array).size()
	var right: Array = ["FED", "%d/%d" % [fed, nf], null]
	if fed == nf:
		right[2] = "good"
	# A (Nov 20): the try's dead join FED in the header (bad) while it has any; the END line is the card
	var pairs: Array = [right]
	if not g.run.is_empty() and int(g.run.hits) != 0:
		pairs.append(["DEAD", int(g.run.hits), "bad"])
	MiniKit.header(px, {label = "TRY", value = "%d/%d" % [mini(g.attempt + 1, g.tries), g.tries]}, pairs)
	MiniKit.deck(px, false)
	if not g.touched and t < 6000.0:
		MiniKit.tell(px, "EAT EVERY SPECK.", ["click", MiniKit.ESC] as Array[String], t / 1000.0)
	g.panel(now)
	g.draw_toast()
	g.dirty = true
