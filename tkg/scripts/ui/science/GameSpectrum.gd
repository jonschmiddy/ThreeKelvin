class_name GameSpectrum
extends MiniGame

## STAR LIGHT (Jon, Nov 17: "a delight"): switch gas tubes on until your light matches the star's,
## line for line. A port of the approved `spectrum2.js` in the layout Jon picked to fit the glass
## (Nov 19, "fit2"): a tighter header, the meter carrying MATCH!, the tubes' rows kept at 13 px.
## Why: docs/why/MiniGame.md#beams-and-spectrum-on-the-glass

const BINS := 21
const CFG := {
	1: {tray = 3, pick = 2, lines = [2, 3], overlap = false},
	2: {tray = 4, pick = 2, lines = [2, 3], overlap = true},
	3: {tray = 5, pick = 3, lines = [2, 3], overlap = true},
	4: {tray = 6, pick = 3, lines = [2, 4], overlap = true},
	5: {tray = 7, pick = 3, lines = [3, 4], overlap = true},
}
const W := 150
const SX := 21
const BW := 6
const SW := BINS * BW
const ROW := 13
const TY := 40
const MY := 31
const DARK := Color("#151c26")
const DARK2 := Color("#0b0f15")
const BROKEN_LINE := Color("#1f2935")
const INK := Color("#0a0e15")

var P: Dictionary = {}
var T := 3
var H := 80
var on := 0
var over := false
var toggles := 0
var won := 0.0
var broken := {}
var locked := {}
var min_t := 0
var t1 := 26.0
var gas_of: Array[Color] = []
var fly: Array = []
var land_t := {}
var hues: Array[Color] = []
var _bg: Image
var _frame := -1


func id() -> StringName:
	return &"spectrum"


func hint() -> String:
	return "Match the star."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

static func mk_el(r: RandomNumberGenerator, c: Dictionary, favour: Array[int]) -> Array[int]:
	var lim: Array = c.lines
	var nn := int(lim[0]) + int(r.randf() * (int(lim[1]) - int(lim[0]) + 1))
	for g in 200:
		var out: Array[int] = []
		var guard := 0
		while out.size() < nn and guard < 100:
			guard += 1
			var p: int
			if not favour.is_empty() and r.randf() < 0.45:
				p = favour[int(r.randf() * favour.size())]
			else:
				p = int(r.randf() * BINS)
			if out.any(func(q: int) -> bool: return absi(q - p) < 2):
				continue
			out.append(p)
		if out.size() == nn:
			out.sort()
			return out
	return [] as Array[int]


static func mask_of(l: Array) -> int:
	var m := 0
	for p: int in l:
		m |= 1 << p
	return m


static func union(tray: Array, set: int) -> int:
	var m := 0
	for i in tray.size():
		if set & (1 << i):
			m |= mask_of(tray[i])
	return m


static func solutions(tray: Array, target: int) -> Array[int]:
	var out: Array[int] = []
	for s in range(1, 1 << tray.size()):
		if union(tray, s) == target:
			out.append(s)
	return out


## {tray (each tube's lines), set (the star's tubes), target, depth}; {} if none came.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var out: Dictionary[String, Variant] = {}
	for tries in 2000:
		var real: Array = []
		var bad := false
		for i in int(c.pick):
			var e := mk_el(r, c, [] as Array[int])
			if e.is_empty():
				bad = true
				break
			real.append(e)
		if bad:
			continue
		var flat: Array[int] = []
		for e: Array in real:
			flat.append_array(e)
		var uniq: Array[int] = []
		for p in flat:
			if not uniq.has(p):
				uniq.append(p)
		if not c.overlap and uniq.size() != flat.size():
			continue
		var els: Array = real.duplicate()
		while els.size() < int(c.tray):
			var e := mk_el(r, c, uniq)
			if not e.is_empty():
				els.append(e)
		var keys := {}
		for e: Array in els:
			keys[str(e)] = true
		if keys.size() != els.size():
			continue
		var order: Array[int] = []
		for i in els.size():
			order.append(i)
		for i in range(order.size() - 1, 0, -1):
			var j := int(r.randf() * (i + 1))
			var tmp := order[i]
			order[i] = order[j]
			order[j] = tmp
		var tray: Array = []
		var set := 0
		for pos in order.size():
			tray.append(els[order[pos]])
			if order[pos] < int(c.pick):
				set |= 1 << pos
		var target := union(tray, set)
		var sols := solutions(tray, target)
		if sols.size() != 1 or sols[0] != set:
			continue
		# every decoy shares at least one line with the star, so it is a real choice
		var dull := false
		for i in tray.size():
			if not (set & (1 << i)) and not (mask_of(tray[i]) & target):
				dull = true
		if dull:
			continue
		out.assign({tray = tray, set = set, target = target, depth = d})
		return out
	return out


static func score_of(n_t: int, mn: int, secs: float, tt: float) -> float:
	var p := maxf(0.0, 1.0 - 0.1 * maxi(0, n_t - mn))
	var t := 1.0 if secs <= tt else maxf(0.0, 1.0 - (secs - tt) / (2.0 * tt))
	return clampf(0.3 + 0.45 * p + 0.25 * t, 0.0, 1.0)


static func order_of(nn: int, r: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = []
	for i in nn:
		a.append(i)
	for i in range(nn - 1, 0, -1):
		var j := int(r.randf() * (i + 1))
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


# ---------------------------------------------------------------- the game

func _now() -> float:
	return 1000.0 + t * 1000.0


func _mount() -> void:
	P = gen(rng, depth)
	if P.is_empty():
		px = MiniPix.new(W, 80)
		push_error("GameSpectrum: no puzzle at depth %d" % depth)
		over = true
		done(0.0, "No puzzle")
		return
	var tray: Array = P.tray
	T = tray.size()
	H = TY + T * ROW - 1
	px = MiniPix.new(W, H)
	hues.assign([MiniPix.TIERS[3], MiniPix.TIERS[2], MiniPix.TRACTOR, MiniPix.TIERS[1], MiniPix.HOT, MiniPix.FLARE, MiniPix.BAD])
	var gas: Array[Color] = [MiniPix.BAD, MiniPix.HOT, MiniPix.FLARE, MiniPix.TIERS[3], MiniPix.TRACTOR, MiniPix.TIERS[4], MiniPix.ICE, MiniPix.TIERS[2]]
	for i in order_of(gas.size(), rng).slice(0, T):
		gas_of.append(gas[i])
	var real_i: Array[int] = []
	var fake_i: Array[int] = []
	for i in T:
		(real_i if (int(P.set) >> i) & 1 else fake_i).append(i)
	var rr: Array[int] = []
	for i in order_of(real_i.size(), rng):
		rr.append(real_i[i])
	var ff: Array[int] = []
	for i in order_of(fake_i.size(), rng):
		ff.append(fake_i[i])
	if sensors >= 1 and ff.size() > 0:
		broken[ff[0]] = true
	if sensors >= 5 and ff.size() > 1:
		broken[ff[1]] = true
	if sensors >= 3:
		locked[rr[0]] = true
		on |= 1 << rr[0]
	min_t = real_i.size() - locked.size()
	t1 = 18.0 + 8.0 * depth + (int(sensors >= 2) + int(sensors >= 4)) * 8.0
	_bg = _draw_bg()
	_render(_now())


func _bin_col(b: float) -> Color:
	return hues[mini(6, int(floorf(b * 7.0 / BINS)))]


func _strip(b: MiniPix, y: int, h: int) -> void:
	b.rect(SX - 1, y - 1, SW + 2, h + 2, Color.BLACK)
	b.rect(SX - 2, y - 2, SW + 4, 1, MiniPix.BEVEL_LO)
	b.rect(SX - 2, y + h + 1, SW + 4, 1, MiniPix.BEVEL_HI)
	for x in SW:
		var dim := MiniPix.mix(_bin_col(float(x) / BW), Color.BLACK, 0.6)
		for j in h:
			b.dot(SX + x, y + j, dim if MiniPix.bay(SX + x, y + j) < 0.28 else MiniPix.VOID)


func _draw_bg() -> Image:
	var b := MiniPix.new(W, H)
	b.rect(0, 0, W, H, MiniPix.PANEL)
	_strip(b, 2, 10)
	_strip(b, 17, 10)
	b.text("STAR", 2, 5, MiniPix.CHILL)
	b.text("YOU", 2, 20, MiniPix.CHILL)
	for i in T:
		_strip(b, TY + i * ROW + 2, 8)
	b.rect(0, TY - 3, W, 1, MiniPix.BEVEL_LO)
	b.rect(0, TY - 2, W, 1, MiniPix.BEVEL_HI)
	return b.img


static func line_x(bin: int) -> int:
	return SX + bin * BW + 2


func _draw_line(x: int, y: int, h: int, col: Color, glow: float, bright: bool) -> void:
	if glow > 0.0:
		var g := MiniPix.mix(col, Color.BLACK, 0.3)
		for j in h:
			if MiniPix.bay(x - 1, y + j) < glow:
				px.dot(x - 1, y + j, g)
			if MiniPix.bay(x + 2, y + j) < glow:
				px.dot(x + 2, y + j, g)
	px.rect(x, y, 2, h, MiniPix.mix(col, Color.WHITE, 0.5) if bright else col)
	px.rect(x, y, 1, h, Color.WHITE if bright else MiniPix.mix(col, Color.WHITE, 0.3))


func _tube(i: int, x: int, y: int, now: float) -> void:
	var lit := (on >> i) & 1
	var gc := gas_of[i]
	if lit:
		var fl := 0.35 + 0.15 * sin(now / 90.0 + i * 2)
		var gd := MiniPix.mix(gc, Color.BLACK, 0.4)
		for xx in range(x - 1, x + 18):
			if MiniPix.bay(xx, y - 1) < fl:
				px.dot(xx, y - 1, gd)
			if MiniPix.bay(xx, y + 9) < fl:
				px.dot(xx, y + 9, gd)
	px.rect(x, y + 1, 3, 7, Color.BLACK)
	px.rect(x + 1, y + 2, 2, 5, MiniPix.COLD)
	px.rect(x + 1, y + 2, 1, 5, MiniPix.CHILL)
	px.rect(x + 15, y + 1, 3, 7, Color.BLACK)
	px.rect(x + 15, y + 2, 2, 5, MiniPix.COLD)
	px.rect(x + 15, y + 2, 1, 1, MiniPix.CHILL)
	px.rect(x + 3, y, 12, 1, Color.BLACK)
	px.rect(x + 3, y + 8, 12, 1, Color.BLACK)
	if lit:
		var hi := MiniPix.mix(gc, Color.WHITE, 0.55)
		var lo := MiniPix.mix(gc, Color.BLACK, 0.3)
		var sh := int(floorf(now / 70.0))
		for xx in 12:
			for j in range(1, 8):
				var core := j >= 3 and j <= 5
				var f := MiniPix.bay(x + 3 + xx + sh, y + j)
				px.dot(x + 3 + xx, y + j, (Color.WHITE if f < 0.5 else hi) if core else (gc if f < 0.6 else lo))
		px.rect(x + 4, y + 1, 10, 1, MiniPix.mix(gc, Color.WHITE, 0.7))
	else:
		px.rect(x + 3, y + 1, 12, 7, DARK)
		px.rect(x + 4, y + 1, 10, 1, MiniPix.BEVEL_HI)
		px.rect(x + 4, y + 6, 10, 1, MiniPix.mix(gc, Color.BLACK, 0.7))
		px.rect(x + 6, y + 4, 6, 1, DARK2)
	if broken.has(i):
		px.rect(x + 3, y + 1, 12, 7, DARK2)
		px.rect(x + 6, y + 1, 1, 2, MiniPix.CHILL)
		px.rect(x + 7, y + 3, 1, 2, MiniPix.CHILL)
		px.rect(x + 8, y + 5, 1, 1, MiniPix.CHILL)
		px.rect(x + 9, y + 6, 2, 1, MiniPix.CHILL)
	if locked.has(i):
		for q: Vector2i in [Vector2i(1, 0), Vector2i(16, 0), Vector2i(1, 8), Vector2i(16, 8)]:
			px.dot(x + q.x, y + q.y, MiniPix.WARN)


func _render(now: float) -> void:
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var mine := union(P.tray, on)
	var target: int = P.target
	for bn in BINS:
		if (target >> bn) & 1:
			var m := (mine >> bn) & 1
			_draw_line(line_x(bn), 2, 10, _bin_col(bn), 0.7 if m else 0.35, won != 0.0 or (m and land_t.has(bn) and now - float(land_t[bn]) < 250.0))
	_mine(mine, target, now)
	_flying(now)
	_meter(mine, target)
	var tray: Array = P.tray
	for i in T:
		var y := TY + i * ROW
		var lit := (on >> i) & 1
		_tube(i, 1, y + 1, now)
		for bn: int in tray[i]:
			var x := line_x(bn)
			if broken.has(i):
				px.rect(x, y + 4, 2, 4, BROKEN_LINE)
				continue
			_draw_line(x, y + 2, 8, _bin_col(bn), 0.5 if lit else 0.0, false)
			if not lit:
				px.rect(x, y + 2, 2, 8, MiniPix.mix(_bin_col(bn), Color.BLACK, 0.55))
	if not toggles and not over and now - 1000.0 < 4500.0:
		_card(SX - 2, 18, SW + 4, "MATCH THE STAR.", (now - 1000.0) / 1000.0)
	dirty = true


## Your lines: a bright bracket joins one to the star's; an extra one shakes, boxed in red.
func _mine(mine: int, target: int, now: float) -> void:
	for bn in BINS:
		if not ((mine >> bn) & 1) or fly.any(func(f: Dictionary) -> bool: return int(f.bin) == bn and f.up):
			continue
		var x := line_x(bn)
		var age := now - float(land_t[bn]) if land_t.has(bn) else 999.0
		if (target >> bn) & 1:
			_draw_line(x, 17, 10, _bin_col(bn), 0.6, won != 0.0 or age < 250.0)
			px.rect(x, 13, 2, 1, MiniPix.GOOD)
			px.rect(x, 15, 2, 1, MiniPix.GOOD)
			px.rect(x, 14, 2, 1, Color.WHITE if age < 300.0 else MiniPix.GOOD)
		else:
			var wob := MiniPix.jr(sin(age / 40.0)) if age < 400.0 else 0
			_draw_line(x + wob, 17, 10, _bin_col(bn), 0.0, false)
			px.rect(x - 1 + wob, 16, 4, 1, MiniPix.BAD)
			px.rect(x - 1 + wob, 27, 4, 1, MiniPix.BAD)


func _flying(now: float) -> void:
	var keep: Array = []
	# the prototype walks its flights last first, landing the done ones as it goes
	for k in range(fly.size() - 1, -1, -1):
		var f: Dictionary = fly[k]
		var u := (now - float(f.t)) / 260.0
		if u >= 1.0:
			if f.up:
				land_t[int(f.bin)] = now
			continue
		keep.push_front(f)
		var y0: float = f.y0
		var y := MiniPix.jr(y0 + (17.0 - y0) * u * u if f.up else 17.0 + (y0 - 17.0) * u)
		var h := 10 - MiniPix.jr(2.0 * (1.0 - u)) if f.up else maxi(1, 10 - MiniPix.jr(8.0 * u))
		_draw_line(line_x(f.bin), y, h, _bin_col(f.bin), 0.0, true)
	fly = keep


## The match meter, 5 px: its dividers drop once it is full, so MATCH! on it reads clean.
func _meter(mine: int, target: int) -> void:
	var tgt: Array[int] = []
	for bn in BINS:
		if (target >> bn) & 1:
			tgt.append(bn)
	var matched := tgt.filter(func(bn: int) -> bool: return (mine >> bn) & 1).size()
	var extras := 0
	for bn in BINS:
		if (mine >> bn) & 1 and not ((target >> bn) & 1):
			extras += 1
	var frac := maxf(0.0, matched - extras) / tgt.size()
	var mx := SX
	var mw := SW
	px.rect(mx - 1, MY - 1, mw + 2, 7, Color.BLACK)
	px.rect(mx, MY, mw, 5, MiniPix.VOID)
	var fw := MiniPix.jr(mw * frac)
	var mcol := MiniPix.GOOD if frac == 1.0 and not extras else (MiniPix.FLARE if extras else MiniPix.TIERS[1])
	var top := MiniPix.mix(mcol, Color.WHITE, 0.5)
	var bot := MiniPix.mix(mcol, Color.BLACK, 0.35)
	for y in 5:
		px.rect(mx, MY + y, fw, 1, top if y == 0 else (bot if y > 3 else mcol))
	if not (frac == 1.0 and not extras):
		for k in range(1, tgt.size()):
			px.rect(mx + MiniPix.jr(mw * float(k) / tgt.size()), MY, 1, 5, Color.BLACK)
	px.text("%d%%" % MiniPix.jr(frac * 100.0), mx + mw - 2, MY, INK if frac > 0.55 else MiniPix.ICE, "right")
	if won != 0.0:
		px.text("MATCH!", SX + (SW >> 1), MY, INK, "center")
	elif over:
		px.text("NO MATCH", SX + (SW >> 1), MY, MiniPix.BAD, "center")


func _card(x: int, y: int, w: int, txt: String, tt: float) -> void:
	px.rect(x, y, w, 19, MiniPix.BEVEL_LO)
	px.rect(x, y, w, 1, MiniPix.EMBER)
	px.rect(x, y + 18, w, 1, MiniPix.EMBER)
	var tw := txt.length() * 4 - 1
	var x0 := x + ((w - (16 + tw)) >> 1)
	px.icon("click", x0, y + 3, tt)
	px.text(txt, x0 + 16, y + 7, MiniPix.HOT)


func _tick(_dt: float) -> void:
	var f := int(floorf(t * 30.0))
	if f != _frame:
		_frame = f
		if drawing:
			_render(_now())


## The canvas point over tube row `i`, for a scripted tap.
static func row_at(i: int) -> Vector2i:
	return Vector2i(60, TY + i * ROW + 6)


func toggle(i: int, now: float) -> void:
	if over or broken.has(i) or locked.has(i):
		return
	on ^= 1 << i
	toggles += 1
	sfx(&"tube")
	var lit := (on >> i) & 1
	var y := TY + i * ROW + 2
	var tray: Array = P.tray
	for bn: int in tray[i]:
		var still := union(tray, on)
		if lit:
			# when each line takes off is its flight's look: the global generator, as Math.random
			fly.append({bin = bn, y0 = y, t = now + randf() * 60.0, up = true})
		elif not ((still >> bn) & 1):
			fly.append({bin = bn, y0 = y, t = now, up = false})
			land_t.erase(bn)
	if union(tray, on) == int(P.target):
		over = true
		after(0.3, func() -> void:
			won = _now()
			sfx(&"match")
			sfx(&"win"))
		done(score_of(toggles, min_t, (now - 1000.0) / 1000.0, t1), "Matched in %d switch%s (best %d)" % [toggles, "" if toggles == 1 else "es", min_t])


func down(q: Vector2i) -> void:
	if q.y >= TY and q.y < TY + T * ROW:
		toggle((q.y - TY) / ROW, _now())


func give_up() -> void:
	if over:
		return
	over = true
	done(0.0, "Gave up after %d switches" % toggles)
