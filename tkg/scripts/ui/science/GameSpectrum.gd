class_name GameSpectrum
extends MiniGame

## STAR LIGHT (Jon, Nov 17: "a delight"): switch gas tubes on until your light matches the star's,
## line for line. A port of the approved `spectrum2.js` as fit4 laid it out (fit2 taken to every tube
## count) and dressed in the kit (Nov 20): MATCH meter and LINES in the header; on status A the rows share
## rows 36 to 139, n EXTRA is a toast and MATCH! the shell's result card.
## Why: docs/why/MiniGame.md#beams-and-spectrum-on-the-glass

const BINS := 21
const CFG := {
	1: {tray = 3, pick = 2, lines = [2, 3], overlap = false},
	2: {tray = 4, pick = 2, lines = [2, 3], overlap = true},
	3: {tray = 5, pick = 3, lines = [2, 3], overlap = true},
	4: {tray = 6, pick = 3, lines = [2, 4], overlap = true},
	5: {tray = 7, pick = 3, lines = [3, 4], overlap = true},
}
const W := MiniKit.W
const H := MiniKit.H
const SX := 21
const BW := 6
const SW := BINS * BW
## The tube rows share rows 36 to 139 (A, Nov 20: the whole glass); a strip is up to 14 tall, centred in its row.
const ROWS_Y := 36
const ROWS_H := 104
const DARK := Color("#151c26")
const DARK2 := Color("#0b0f15")
const BROKEN_LINE := Color("#1f2935")

var P: Dictionary = {}
var T := 3
var ROW := 13
var TY := 36
var SH := 8
var OY := 0
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
		px = MiniPix.new(W, H)
		push_error("GameSpectrum: no puzzle at depth %d" % depth)
		over = true
		done(0.0, "No puzzle")
		return
	var tray: Array = P.tray
	T = tray.size()
	ROW = ROWS_H / T
	TY = ROWS_Y + ((ROWS_H - T * ROW) >> 1)
	SH = mini(ROW - 5, 14)
	OY = (ROW - SH - 5) >> 1
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
	_strip(b, 12, 8)
	_strip(b, 25, 8)
	b.text("STAR", 2, 14, MiniPix.CHILL)
	b.text("YOU", 2, 27, MiniPix.CHILL)
	for i in T:
		_strip(b, TY + i * ROW + OY + 2, SH)
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


## A gas tube SH + 1 rows tall: caps, glass, the gas lit or dark, cracked if broken, warn corners if locked.
func _tube(i: int, x: int, y: int, now: float) -> void:
	var lit := (on >> i) & 1
	var gc := gas_of[i]
	var th := SH + 1
	var cm := (th - 1) / 2.0
	var cr := (th - 2) * 1.5 / 7.0
	var cy := (th - 9) >> 1
	if lit:
		var fl := 0.35 + 0.15 * sin(now / 90.0 + i * 2)
		var gd := MiniPix.mix(gc, Color.BLACK, 0.4)
		for xx in range(x - 1, x + 18):
			if MiniPix.bay(xx, y - 1) < fl:
				px.dot(xx, y - 1, gd)
			if MiniPix.bay(xx, y + th) < fl:
				px.dot(xx, y + th, gd)
	px.rect(x, y + 1, 3, th - 2, Color.BLACK)
	px.rect(x + 1, y + 2, 2, th - 4, MiniPix.COLD)
	px.rect(x + 1, y + 2, 1, th - 4, MiniPix.CHILL)
	px.rect(x + 15, y + 1, 3, th - 2, Color.BLACK)
	px.rect(x + 15, y + 2, 2, th - 4, MiniPix.COLD)
	px.rect(x + 15, y + 2, 1, 1, MiniPix.CHILL)
	px.rect(x + 3, y, 12, 1, Color.BLACK)
	px.rect(x + 3, y + th - 1, 12, 1, Color.BLACK)
	if lit:
		var hi := MiniPix.mix(gc, Color.WHITE, 0.55)
		var lo := MiniPix.mix(gc, Color.BLACK, 0.3)
		var sh := int(floorf(now / 70.0))
		for xx in 12:
			for j in range(1, th - 1):
				var core := absf(j - cm) <= cr
				var f := MiniPix.bay(x + 3 + xx + sh, y + j)
				px.dot(x + 3 + xx, y + j, (Color.WHITE if f < 0.5 else hi) if core else (gc if f < 0.6 else lo))
		px.rect(x + 4, y + 1, 10, 1, MiniPix.mix(gc, Color.WHITE, 0.7))
	else:
		px.rect(x + 3, y + 1, 12, th - 2, DARK)
		px.rect(x + 4, y + 1, 10, 1, MiniPix.BEVEL_HI)
		px.rect(x + 4, y + th - 3, 10, 1, MiniPix.mix(gc, Color.BLACK, 0.7))
		px.rect(x + 6, y + (th >> 1), 6, 1, DARK2)
	if broken.has(i):
		px.rect(x + 3, y + 1, 12, th - 2, DARK2)
		px.rect(x + 6, y + cy + 1, 1, 2, MiniPix.CHILL)
		px.rect(x + 7, y + cy + 3, 1, 2, MiniPix.CHILL)
		px.rect(x + 8, y + cy + 5, 1, 1, MiniPix.CHILL)
		px.rect(x + 9, y + cy + 6, 2, 1, MiniPix.CHILL)
	if locked.has(i):
		for q: Vector2i in [Vector2i(1, 0), Vector2i(16, 0), Vector2i(1, th - 1), Vector2i(16, th - 1)]:
			px.dot(x + q.x, y + q.y, MiniPix.WARN)


func _render(now: float) -> void:
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var mine := union(P.tray, on)
	var target: int = P.target
	for bn in BINS:
		if (target >> bn) & 1:
			var m := (mine >> bn) & 1
			_draw_line(line_x(bn), 12, 8, _bin_col(bn), 0.7 if m else 0.35, won != 0.0 or (m and land_t.has(bn) and now - float(land_t[bn]) < 250.0))
	_mine(mine, target, now)
	_flying(now)
	var cnt := _counts(mine, target)
	_header(cnt)
	var tray: Array = P.tray
	for i in T:
		var y := TY + i * ROW + OY
		var lit := (on >> i) & 1
		_tube(i, 1, y + 1, now)
		for bn: int in tray[i]:
			var x := line_x(bn)
			if broken.has(i):
				px.rect(x, y + 2 + (SH >> 2), 2, SH >> 1, BROKEN_LINE)
				continue
			_draw_line(x, y + 2, SH, _bin_col(bn), 0.5 if lit else 0.0, false)
			if not lit:
				px.rect(x, y + 2, 2, SH, MiniPix.mix(_bin_col(bn), Color.BLACK, 0.55))
	if not toggles and not over:
		MiniKit.tell(px, "MATCH THE STAR.", ["click", MiniKit.ESC] as Array[String], (now - 1000.0) / 1000.0)
	draw_toast()
	dirty = true


## Your lines: a bright bracket joins one to the star's; an extra one shakes, boxed in red.
func _mine(mine: int, target: int, now: float) -> void:
	for bn in BINS:
		if not ((mine >> bn) & 1) or fly.any(func(f: Dictionary) -> bool: return int(f.bin) == bn and f.up):
			continue
		var x := line_x(bn)
		var age := now - float(land_t[bn]) if land_t.has(bn) else 999.0
		if (target >> bn) & 1:
			_draw_line(x, 25, 8, _bin_col(bn), 0.6, won != 0.0 or age < 250.0)
			px.rect(x, 21, 2, 1, MiniPix.GOOD)
			px.rect(x, 23, 2, 1, MiniPix.GOOD)
			px.rect(x, 22, 2, 1, Color.WHITE if age < 300.0 else MiniPix.GOOD)
		else:
			var wob := MiniPix.jr(sin(age / 40.0)) if age < 400.0 else 0
			_draw_line(x + wob, 25, 8, _bin_col(bn), 0.0, false)
			px.rect(x - 1 + wob, 24, 4, 1, MiniPix.BAD)
			px.rect(x - 1 + wob, 33, 4, 1, MiniPix.BAD)


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
		var y := MiniPix.jr(y0 + (25.0 - y0) * u * u if f.up else 25.0 + (y0 - 25.0) * u)
		var h := 8 - MiniPix.jr(2.0 * (1.0 - u)) if f.up else maxi(1, 8 - MiniPix.jr(6.0 * u))
		_draw_line(line_x(f.bin), y, h, _bin_col(f.bin), 0.0, true)
	fly = keep


## The lines so far: x the star's matched, y extras of yours, z the star's count.
static func _counts(mine: int, target: int) -> Vector3i:
	var n := 0
	var matched := 0
	var extras := 0
	for bn in BINS:
		var a := (mine >> bn) & 1
		if (target >> bn) & 1:
			n += 1
			matched += a
		elif a:
			extras += 1
	return Vector3i(matched, extras, n)


## The kit header: the MATCH meter left; LINES m/n (red while extras are on) and the switch count right
## (A: LINES left the status line). The meter is as wide as the widest right side lets it (n/n and a
## two-digit count): 33 for a star of up to 9 lines, 25 for 10 or more.
func _header(cnt: Vector3i) -> void:
	var frac := maxf(0.0, cnt.x - cnt.y) / cnt.z
	var full := frac == 1.0 and not cnt.y
	var mw := 44 - (str(cnt.z).length() * 8 + 3)
	var lk := "bad" if cnt.y else ("good" if cnt.x == cnt.z else "")
	MiniKit.header(px, {label = "MATCH", meter = {w = mw, frac = frac, kind = "good" if full else "neutral"}},
		[["LINES", "%d/%d" % [cnt.x, cnt.z], lk], ["SWITCHES", toggles]])


func _tick(_dt: float) -> void:
	var f := int(floorf(t * 30.0))
	if f != _frame:
		_frame = f
		if drawing:
			_render(_now())


## The canvas point over tube row `i`, for a scripted tap.
func row_at(i: int) -> Vector2i:
	return Vector2i(60, TY + i * ROW + (ROW >> 1))


func toggle(i: int, now: float) -> void:
	if over or broken.has(i) or locked.has(i):
		return
	var xb := _counts(union(P.tray, on), int(P.target)).y
	on ^= 1 << i
	toggles += 1
	sfx(&"tube")
	var lit := (on >> i) & 1
	var y := TY + i * ROW + OY + 2
	var tray: Array = P.tray
	for bn: int in tray[i]:
		var still := union(tray, on)
		if lit:
			# when each line takes off is its flight's look: the global generator, as Math.random
			fly.append({bin = bn, y0 = y, t = now + randf() * 60.0, up = true})
		elif not ((still >> bn) & 1):
			fly.append({bin = bn, y0 = y, t = now, up = false})
			land_t.erase(bn)
	# a wrong tube going on: n EXTRA, a toast (A)
	var xa := _counts(union(tray, on), int(P.target)).y
	if lit and xa > xb:
		say("%d EXTRA" % xa, "bad")
	if union(tray, on) == int(P.target):
		over = true
		after(0.3, func() -> void:
			won = _now()
			sfx(&"match")
			sfx(&"win"))
		say_end("MATCH!", "good")
		done(score_of(toggles, min_t, (now - 1000.0) / 1000.0, t1), "Matched in %d switch%s (best %d)" % [toggles, "" if toggles == 1 else "es", min_t])


func down(q: Vector2i) -> void:
	if q.y >= TY and q.y < TY + T * ROW:
		toggle((q.y - TY) / ROW, _now())


func give_up() -> void:
	if over:
		return
	over = true
	done(0.0, "Gave up after %d switches" % toggles)
