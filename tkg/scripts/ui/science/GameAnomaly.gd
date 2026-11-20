class_name GameAnomaly
extends MiniGame

## ANOMALY COUNT (Jon loved, Nov 17; round 3: "bigger than the others?"): a microscope feed; mark
## every critter the rule names. A port of the approved `anomaly2.js`, in its approved layout and the
## UI kit (Nov 20); status A (Nov 20): the lens back to r 55 in the middle of the whole glass, the rule
## in the bottom corners it leaves free.
## Why: docs/why/MiniGame.md#the-round-2-games

const CFG := {
	1: {n = 9, kinds = ["and2"], k = [3, 4], time = 32, swim = 0},
	2: {n = 10, kinds = ["and3", "and2"], k = [3, 4], time = 35, swim = 0},
	3: {n = 10, kinds = ["or", "and3"], k = [3, 4], time = 38, swim = 0},
	4: {n = 10, kinds = ["and3", "or"], k = [3, 4], time = 42, swim = 1},
	5: {n = 10, kinds = ["switch"], k = [2, 3], time = 50, swim = 1},
}
const DISH_R := 39.0
const MIN_GAP := 23.0
const SHAPES: Array[String] = ["ROUND", "ROD", "STAR"]
const ATTRS := {"shape": [0, 1, 2], "spots": [0, 1, 2, 3], "ring": [0, 1], "tail": [0, 1]}
const KEYS: Array[String] = ["shape", "spots", "ring", "tail"]
const W := MiniKit.W
const H := MiniKit.H
const CX := 75
const CY := 75
const LENS := 55
## The dish's scale on the lens (positions, swim speed and its edge are in r 52 units).
const PS := LENS / 52.0
## Critter scale, and its sprite box and centre.
const K := 1.7
const SP := 37
const SHC := 18
const SPOTS := [[[0, 0]], [[-1.7, -1.2], [1.7, 1.2]], [[-1.9, -1.5], [1.9, -1.5], [0, 2.1]]]
const ROD_SPOTS := [[[0, 0]], [[0, -1.9], [0, 1.9]], [[0, -3.1], [0, 0], [0, 3.1]]]

var pz: Dictionary = {}
var T := 32.0
var phase := 0
var found := 0
var wrong := 0
var ended := false
var time_left := 32.0
var started := false
var clock := 0.0
var rule_flash := -9.0
var total := 0
var marked := {}
var fx: Array = []
var crit: Array = []
var hints: Array[int] = []
var press: Dictionary = {}
var _seeds: Array[float] = []
var _cache := {}
var _under: Image
var _over: Image
var _acc := 0.0
var MEM: Color
var CYTO: Color
var CYTO2: Color
var LIT: Color
var NUC: Color
var NUC2: Color
var NUCD: Color
var HALO: Color
var HALO2: Color


func id() -> StringName:
	return &"anomaly"


func hint() -> String:
	return "Find every match."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

## The order the prototype's `shuffle` leaves n things in (its draws do not depend on what they are).
static func order(nn: int, r: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = []
	for i in nn:
		a.append(i)
	for i in range(nn - 1, 0, -1):
		var j := int(r.randf() * (i + 1))
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


static func ix(nn: int, r: RandomNumberGenerator) -> int:
	return int(r.randf() * nn)


static func word(k: String, v: int) -> String:
	match k:
		"shape":
			return SHAPES[v]
		"spots":
			return "NO SPOTS" if v == 0 else ("1 SPOT" if v == 1 else "%d SPOTS" % v)
		"ring":
			return "HALO" if v else "NO HALO"
	return "TAIL" if v else "NO TAIL"


static func _attr(k: String, r: RandomNumberGenerator) -> int:
	var a: Array = ATTRS[k]
	return int(a[ix(a.size(), r)])


static func rand_spec(r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var s: Dictionary[String, Variant] = {}
	s.shape = _attr("shape", r)
	s.spots = _attr("spots", r)
	s.ring = _attr("ring", r)
	s.tail = _attr("tail", r)
	s.rot = int(r.randf() * 8)
	return s


static func holds(t: Array, s: Dictionary) -> bool:
	for c: Dictionary in t:
		if int(s[c.k]) != int(c.v):
			return false
	return true


static func any_holds(rule: Dictionary, s: Dictionary) -> bool:
	for t: Array in rule.terms:
		if holds(t, s):
			return true
	return false


static func make_term(r: RandomNumberGenerator, nn: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in order(KEYS.size(), r).slice(0, nn):
		out.append({k = KEYS[i], v = _attr(KEYS[i], r)})
	return out


static func make_rule(kind: String, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if kind == "and2" or kind == "and3":
		out.terms = [make_term(r, 2 if kind == "and2" else 3)]
		return out
	var a := make_term(r, 2)
	var b: Array[Dictionary]
	while true:
		b = make_term(r, 2)
		var all_in := true
		for c in b:
			if not a.any(func(q: Dictionary) -> bool: return q.k == c.k):
				all_in = false
		if not all_in:
			break
	out.terms = [a, b]
	return out


static func rule_text(rule: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for t: Array in rule.terms:
		out.append(" + ".join(t.map(func(c: Dictionary) -> String: return word(c.k, c.v))))
	return out


static func matches(rule: Dictionary, specs: Array) -> Array[int]:
	var out: Array[int] = []
	for i in specs.size():
		if any_holds(rule, specs[i]):
			out.append(i)
	return out


## A term's critter with one of its parts wrong.
static func near_miss(rule: Dictionary, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var terms: Array = rule.terms
	for g in 50:
		var s := rand_spec(r)
		var t: Array = terms[ix(terms.size(), r)]
		for c: Dictionary in t:
			s[c.k] = c.v
		var c: Dictionary = t[ix(t.size(), r)]
		var alts: Array = (ATTRS[c.k] as Array).filter(func(v: int) -> bool: return v != int(c.v))
		s[c.k] = alts[ix(alts.size(), r)]
		if not any_holds(rule, s):
			return s
	return {} as Dictionary[String, Variant]


static func _matching(rule: Dictionary, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var s := rand_spec(r)
	var terms: Array = rule.terms
	for c: Dictionary in terms[ix(terms.size(), r)]:
		s[c.k] = c.v
	return s


static func _shuffle_specs(specs: Array[Dictionary], r: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in order(specs.size(), r):
		out.append(specs[i])
	return out


static func gen_attr(rule: Dictionary, tot: int, k: int, r: RandomNumberGenerator) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var guard := 0
	while specs.size() < k and guard < 5000:
		guard += 1
		specs.append(_matching(rule, r))
	guard = 0
	while specs.size() < tot and guard < 20000:
		guard += 1
		var s := near_miss(rule, r) if r.randf() < 0.5 else rand_spec(r)
		if s.is_empty() or any_holds(rule, s):
			continue
		specs.append(s)
	return _shuffle_specs(specs, r) if specs.size() == tot else [] as Array[Dictionary]


## Critters scattered in the dish, never touching.
static func place(nn: int, r: RandomNumberGenerator) -> Array[Vector2]:
	for att in 50:
		var pos: Array[Vector2] = []
		var guard := 0
		while pos.size() < nn and guard < 6000:
			guard += 1
			var a := r.randf() * 2.0 * PI
			var d := sqrt(r.randf()) * DISH_R
			var p := Vector2(cos(a) * d, sin(a) * d)
			if pos.all(func(q: Vector2) -> bool: return (q - p).length() >= MIN_GAP):
				pos.append(p)
		if pos.size() == nn:
			return pos
	return [] as Array[Vector2]


## Sector 5: the rule changes halfway, so each rule's critters must not fit the other.
static func _switch(c: Dictionary, k: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var first: Array[String] = ["and2", "and3"]
	var second: Array[String] = ["and2", "or"]
	var a := make_rule(first[ix(2, r)], r)
	var b: Dictionary[String, Variant]
	while true:
		b = make_rule(second[ix(2, r)], r)
		if var_to_str(a) != var_to_str(b):
			break
	var tot: int = c.n
	var lim: Array = c.k
	var specs: Array[Dictionary] = []
	var guard := 0
	while specs.size() < k and guard < 5000:
		guard += 1
		var s := _matching(a, r)
		if not any_holds(b, s):
			specs.append(s)
	var kb := int(lim[0]) + int(r.randf() * (int(lim[1]) - int(lim[0]) + 1))
	guard = 0
	while specs.size() < k + kb and guard < 5000:
		guard += 1
		var s := _matching(b, r)
		if not any_holds(a, s):
			specs.append(s)
	guard = 0
	while specs.size() < tot and guard < 20000:
		guard += 1
		var s: Dictionary[String, Variant]
		if r.randf() < 0.5:
			s = near_miss(a if r.randf() < 0.5 else b, r)
		else:
			s = rand_spec(r)
		if s.is_empty() or any_holds(a, s) or any_holds(b, s):
			continue
		specs.append(s)
	if specs.size() != tot:
		return out
	var sh := _shuffle_specs(specs, r)
	var ma := matches(a, sh)
	var mb := matches(b, sh)
	if ma.size() != k or mb.size() != kb:
		return out
	out.assign({specs = sh, rules = [a, b], answers = [ma, mb]})
	return out


## {specs, rules, answers (each rule's critters), pos, time, swim}; {} if none came.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG.get(d, CFG[1])
	var out: Dictionary[String, Variant] = {}
	var lim: Array = c.k
	var kinds: Array = c.kinds
	for tries in 300:
		var kind := String(kinds[ix(kinds.size(), r)])
		var k := int(lim[0]) + int(r.randf() * (int(lim[1]) - int(lim[0]) + 1))
		var got: Dictionary[String, Variant] = {}
		if kind == "switch":
			got = _switch(c, k, r)
			if got.is_empty():
				continue
		else:
			var rule := make_rule(kind, r)
			var specs := gen_attr(rule, c.n, k, r)
			if specs.is_empty():
				continue
			var m := matches(rule, specs)
			if m.size() != k:
				continue
			got.assign({specs = specs, rules = [rule], answers = [m]})
		var pos := place(c.n, r)
		if pos.is_empty():
			continue
		got.pos = pos
		got.time = c.time
		got.swim = c.swim
		out.assign(got)
		return out
	return out


static func score(fd: int, tot: int, wr: int, left_frac: float) -> float:
	var base := float(fd) / tot if tot else 0.0
	return maxf(0.0, base * maxf(0.0, 1.0 - 0.12 * wr) * (0.85 + 0.15 * minf(1.0, left_frac / 0.3)))


# ---------------------------------------------------------------- the picture

func _colours() -> void:
	MEM = MiniPix.shade(MiniPix.GOOD, -0.62)
	CYTO = MiniPix.shade(MiniPix.GOOD, 0.18)
	CYTO2 = MiniPix.GOOD
	LIT = MiniPix.shade(MiniPix.GOOD, 0.55)
	NUC = MiniPix.TIERS[3]
	NUC2 = MiniPix.shade(MiniPix.TIERS[3], 0.45)
	NUCD = MiniPix.shade(MiniPix.TIERS[3], -0.55)
	HALO = MiniPix.shade(MiniPix.TIERS[2], -0.25)
	HALO2 = MiniPix.shade(MiniPix.TIERS[2], 0.3)


static func _inside(s: Dictionary, u: float, v: float, sc: float, sd: float) -> bool:
	sc *= K
	u /= sc
	v /= sc
	if int(s.shape) == 0:
		return Vector2(u, v).length() <= 4.4 + sin(atan2(v, u) * 3.0 + sd) * 0.2
	if int(s.shape) == 1:
		var vv := maxf(-3.4, minf(3.4, v))
		return Vector2(u + sin(v * 0.35 + sd) * 0.4, v - vv).length() <= 2.6
	return Vector2(u, v).length() <= 3.1 + 2.6 * pow(absf(cos(2.5 * atan2(v, u) + sd * 0.2)), 1.6)


## One critter drawn small, turned in 45 degree steps, its tail at phase 0..3 (the prototype's `critter`).
func _critter(s: Dictionary, rot: int, ph: int, sd: float) -> Image:
	var c := MiniPix.new(SP, SP)
	c.clear(Color(0, 0, 0, 0))
	var a := rot * PI / 4.0
	var ca := cos(a)
	var sa := sin(a)
	if int(s.tail):
		var back := (5.6 if int(s.shape) == 1 else (4.2 if int(s.shape) == 0 else 4.0)) * K
		for k in 20:
			var v := back + k * 0.55
			var u := sin(k * 0.42 + ph * PI / 2.0) * (0.5 + k * 0.16)
			var x := SHC + u * ca - v * sa
			var y := SHC + u * sa + v * ca
			var big := k < 14
			c.rect(MiniPix.jr(x - 0.5), MiniPix.jr(y - 0.5), 2 if big else 1, 2 if big else 1, MEM if big else MiniPix.shade(MiniPix.GOOD, -0.4))
	for y in SP:
		for x in SP:
			var dx := x + 0.5 - SHC
			var dy := y + 0.5 - SHC
			var u := dx * ca + dy * sa
			var v := -dx * sa + dy * ca
			if _inside(s, u, v, 1.0, sd):
				var edge := not _inside(s, u + 0.95, v, 1.0, sd) or not _inside(s, u - 0.95, v, 1.0, sd) \
					or not _inside(s, u, v + 0.95, 1.0, sd) or not _inside(s, u, v - 0.95, 1.0, sd)
				var lt := (-(x - SHC) - (y - SHC)) / (6.0 * K)
				c.dot(x, y, MEM if edge else (LIT if lt > 0.55 else (CYTO if lt > -0.2 else (CYTO2 if MiniPix.bay(x, y) < 0.5 else CYTO))))
			elif int(s.ring) and _inside(s, u, v, 1.62, sd) and not _inside(s, u, v, 1.3, sd):
				c.dot(x, y, HALO2 if _inside(s, u, v, 1.46, sd) else HALO)
	if int(s.spots):
		var l: Array = ROD_SPOTS if int(s.shape) == 1 else SPOTS
		var set: Array = [[0, 0]] if int(s.spots) == 1 else l[int(s.spots) - 1]
		for q: Array in set:
			var u := float(q[0]) * K
			var v := float(q[1]) * K
			var xx := MiniPix.jr(SHC + u * ca - v * sa - 1.5)
			var yy := MiniPix.jr(SHC + u * sa + v * ca - 1.5)
			c.rect(xx - 1, yy, 5, 3, NUCD)
			c.rect(xx, yy - 1, 3, 5, NUCD)
			c.rect(xx, yy, 3, 3, NUC)
			c.rect(xx, yy, 1, 1, NUC2)
	return c.img


func _sprite(i: int, rot: int, ph: int) -> Image:
	var k := i * 64 + rot * 4 + ph
	if not _cache.has(k):
		_cache[k] = _critter(pz.specs[i], rot, ph, _seeds[i])
	return _cache[k]


func _ring_px(cx: float, cy: float, r: float, c: Color, every := 0) -> void:
	var nn := maxi(8, MiniPix.jr(r * 7.0))
	var seen := {}
	for k in nn:
		if every and k % every:
			continue
		var a := float(k) / nn * 2.0 * PI
		var x := MiniPix.jr(cx + r * cos(a))
		var y := MiniPix.jr(cy + r * sin(a))
		var key := x * 999 + y
		if seen.has(key):
			continue
		seen[key] = true
		px.dot(x, y, c)


## The lit slide under the critters, and the lens and its fall-off over them, drawn once.
func _layers() -> void:
	var u := MiniPix.new(W, H)
	u.clear(MiniPix.VOID)
	for y in H:
		for x in W:
			var r := Vector2(x + 0.5 - CX, y + 0.5 - CY).length()
			if r > LENS:
				continue
			var t_ := r / LENS
			var col := MiniPix.ICE if t_ < 0.45 else ((MiniPix.CHILL if MiniPix.bay(x, y) < (t_ - 0.45) / 0.27 else MiniPix.ICE) if t_ < 0.72 \
				else (MiniPix.COLD if MiniPix.bay(x, y) < (t_ - 0.72) / 0.28 else MiniPix.CHILL))
			u.dot(x, y, col)
	var hs: int = ((pz.pos as Array).size() * 7919 + int(pz.specs[0].rot)) | 1
	for k in 40:
		hs = _lcg(hs)
		var a := float(hs) / 0x7fffffff * 6.28
		hs = _lcg(hs)
		var d := sqrt(float(hs) / 0x7fffffff) * LENS * 0.9
		hs = _lcg(hs)
		u.dotf(CX + cos(a) * d, CY + sin(a) * d, MiniPix.CHILL if float(hs) / 0x7fffffff < 0.5 else MiniPix.COLD)
	_under = u.img
	var o := MiniPix.new(W, H)
	o.clear(Color(0, 0, 0, 0))
	for y in H:
		for x in W:
			var r := Vector2(x + 0.5 - CX, y + 0.5 - CY).length()
			if r > LENS + 3:
				o.dot(x, y, MiniPix.PANEL)
				continue
			if r > LENS:
				var lt := (-(x - CX) - (y - CY)) / r
				o.dot(x, y, MiniPix.BEVEL_LO if r > LENS + 2 else (MiniPix.BEVEL_HI if lt > 0.3 else (MiniPix.BEVEL_LO if lt < -0.3 else MiniPix.LINE)))
				continue
			var tt := (r - LENS * 0.82) / (LENS * 0.18)
			if tt > 0.0 and MiniPix.bay(x, y) < tt * 0.85:
				o.dot(x, y, MiniPix.LINE if tt > 0.7 else MiniPix.COLD)
	var ret := MiniPix.shade(MiniPix.COLD, 0.2)
	for k in range(-LENS + 8, LENS - 7, 2):
		if absi(k) < 4:
			continue
		o.dot(CX + k, CY, ret)
		o.dot(CX, CY + k, ret)
	_over = o.img


## The specks' generator: `(hs * 1103515245 + 12345) & 0x7fffffff`, its double product kept.
static func _lcg(hs: int) -> int:
	var m := fmod(float(hs) * 1103515245.0 + 12345.0, 4294967296.0)
	return int(m) & 0x7fffffff


func _mount() -> void:
	px = MiniPix.new(W, H)
	pz = gen(rng, depth)
	if pz.is_empty():
		push_error("GameAnomaly: no puzzle at depth %d" % depth)
		ended = true
		done(0.0, "No puzzle")
		return
	_colours()
	T = float(pz.time) + 4 * sensors
	time_left = T
	for a: Array in pz.answers:
		total += a.size()
	for i in (pz.specs as Array).size():
		_seeds.append(float(((i * 2654435761) & 0xFFFFFFFF) % 100) / 16.0)
		var s: Dictionary = pz.specs[i]
		var p: Vector2 = pz.pos[i]
		crit.append({s = s, x = p.x * PS, y = p.y * PS, rot = int(s.rot), swim = int(pz.swim) and int(s.tail), ph = i % 4})
	_pick_hints()
	_layers()
	_draw()


func _pick_hints() -> void:
	var left: Array = (pz.answers[phase] as Array).filter(func(i: int) -> bool: return not marked.has(i))
	var nh := 2 if sensors >= 4 else (1 if sensors >= 2 else 0)
	hints.clear()
	for i in order(left.size(), rng).slice(0, nh):
		hints.append(int(left[i]))


## The rule to match, a STANDING readout in the bottom corners the round lens leaves free (A, Nov 20):
## one term a line in goal blue (blinking for a moment when it changes), "+" before the 2nd and 3rd;
## an OR rule's second half bottom-right under a neutral OR. The last line on rows H-7 to H-3.
func _draw_rule() -> void:
	if ended:
		return
	var fl := clock - rule_flash < 1.2 and int(floorf(clock * 5.0)) % 2 == 0
	var col := MiniPix.ICE if fl else MiniKit.ink("goal")
	var terms: Array = pz.rules[phase].terms
	_rule_block(terms[0], false, col)
	if terms.size() > 1:
		_rule_block(terms[1], true, col)


## One term's lines: left-aligned at the gutter, or right-aligned under "OR" at the right.
func _rule_block(term: Array, right: bool, col: Color) -> void:
	var rows: Array[String] = []
	if right:
		rows.append("OR")
	for i in term.size():
		rows.append(("+" if i else "") + word(term[i].k, term[i].v))
	for i in rows.size():
		var s := rows[i]
		var y := H - 7 - (rows.size() - 1 - i) * 6
		var x := W - MiniKit.GUT - MiniKit.tw(s) if right else MiniKit.GUT
		px.text(s, x, y, MiniKit.ink("neutral") if right and i == 0 else col)


func _draw() -> void:
	px.img.blit_rect(_under, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var tph := int(floorf(clock * 6.0)) % 4
	for i in hints:
		var c: Dictionary = crit[i]
		var xx := MiniPix.jr(CX + float(c.x))
		var yy := MiniPix.jr(CY + float(c.y))
		for y in range(-15, 16):
			for x in range(-15, 16):
				var r := Vector2(x, y).length()
				if r > 10 and r < 15 and MiniPix.bay(xx + x, yy + y) < (15.0 - r) / 10.0:
					px.dot(xx + x, yy + y, MiniPix.HOT)
	for i in crit.size():
		var c: Dictionary = crit[i]
		px.blit(_sprite(i, int(c.rot), (tph + int(c.ph)) % 4 if int(c.s.tail) else 0), MiniPix.jr(CX + float(c.x)) - SHC, MiniPix.jr(CY + float(c.y)) - SHC)
	for i: int in marked:
		var c: Dictionary = crit[i]
		_ring_px(CX + float(c.x), CY + float(c.y), 13.5, MiniPix.EMBER)
		_ring_px(CX + float(c.x), CY + float(c.y), 14.5, MiniPix.EMBER)
		_ring_px(CX + float(c.x), CY + float(c.y), 15.5, MiniPix.shade(MiniPix.EMBER, -0.4), 2)
	_effects()
	px.blit(_over, 0, 0)
	var fr := time_left / T
	var nn := MiniPix.jr(fr * 120.0)
	for k in nn:
		var a := -PI / 2.0 + float(k) / 120.0 * 2.0 * PI
		px.dotf(CX + (LENS + 1.5) * cos(a), CY + (LENS + 1.5) * sin(a), MiniPix.BAD if fr < 0.25 else MiniPix.EMBER)
	_draw_rule()
	var need: Array = pz.answers[phase]
	var got := need.filter(func(i: int) -> bool: return marked.has(i)).size()
	var right: Array = []
	if (pz.rules as Array).size() > 1:
		right.append(["RULE", "%d/%d" % [phase + 1, (pz.rules as Array).size()]])
	right.append(["WRONG", wrong, "bad" if wrong else ""])
	right.append(["TIME", ceili(time_left), "bad" if fr < 0.25 else ""])
	MiniKit.header(px, {label = "FOUND", value = "%d/%d" % [got, need.size()], vkind = "good" if got == need.size() else ""}, right)
	if not started:
		MiniKit.tell(px, "FIND EVERY MATCH.", ["click", MiniKit.ESC] as Array[String], clock)
	_loupe()
	draw_toast()
	dirty = true


func _effects() -> void:
	var keep: Array = []
	for f: Dictionary in fx:
		var a := clock - float(f.t0)
		if a > float(f.life):
			continue
		keep.append(f)
		var c: Dictionary = crit[int(f.i)]
		var x := CX + float(c.x)
		var y := CY + float(c.y)
		if f.get("bad", false):
			_ring_px(x, y, 14.5, MiniPix.BAD, 2 if a > 0.6 else 0)
			if a < 0.6:
				for d in range(-5, 6):
					px.dotf(x + d, y + d, MiniPix.BAD)
					px.dotf(x + d, y - d, MiniPix.BAD)
		else:
			_ring_px(x, y, 14.0 + a * 16.0, MiniPix.FLARE, 2)
	fx = keep


## Press and hold on the slide: a 2x loupe over the finger (its round rim drawn hard, not smoothed).
func _loupe() -> void:
	if press.is_empty() or ended:
		return
	if not press.loupe and t - float(press.t) >= 0.3:
		press.loupe = true
	if not press.loupe:
		return
	var snap := px.img.duplicate() as Image
	var q: Vector2 = press.q
	var fxx := MiniPix.jr(q.x)
	var fyy := MiniPix.jr(q.y)
	var lr := 24
	var lx := maxi(lr + 2, mini(W - lr - 3, fxx))
	var ly := fyy - lr - 14 if fyy - lr - 14 > lr + 11 else mini(MiniKit.deck_y(false) - lr - 3, fyy + lr + 14)
	for y in range(-lr, lr):
		for x in range(-lr, lr):
			if Vector2(x + 0.5, y + 0.5).length() > lr:
				continue
			var sx := fxx - lr / 2 + (x + lr) / 2
			var sy := fyy - lr / 2 + (y + lr) / 2
			var c := snap.get_pixel(sx, sy) if sx >= 0 and sy >= 0 and sx < W and sy < H else MiniPix.ICE
			px.dot(lx + x, ly + y, c)
	_ring_px(lx, ly, lr, MiniPix.BEVEL_LO)
	_ring_px(lx, ly, lr + 1, MiniPix.CHILL)
	_ring_px(lx, ly, lr + 2, MiniPix.BEVEL_LO)


func _tick(dt: float) -> void:
	_acc += dt
	if _acc < 1.0 / 30.0:
		if not press.is_empty():
			if drawing:
				_draw()
		return
	var step := minf(0.1, _acc)
	_acc = 0.0
	clock += step
	_step(step)
	if drawing:
		_draw()


func _step(dt: float) -> void:
	if not started or ended:
		return
	time_left = maxf(0.0, time_left - dt)
	if (pz.rules as Array).size() > 1 and phase == 0 and time_left < T * 0.5:
		_next_phase()
	for c: Dictionary in crit:
		if not c.swim:
			continue
		var a := int(c.rot) * PI / 4.0
		c.x += sin(a) * 3.2 * PS * dt
		c.y -= cos(a) * 3.2 * PS * dt
		var r := Vector2(c.x, c.y).length()
		if r > DISH_R * PS:
			c.x *= DISH_R * PS / r
			c.y *= DISH_R * PS / r
			var to_c := atan2(-float(c.x), float(c.y))
			c.rot = posmod(MiniPix.jr(to_c / (PI / 4.0)) % 8, 8)
	if time_left <= 0.0:
		_end()


# ---------------------------------------------------------------- input

func nearest(q: Vector2) -> int:
	var best := -1
	var bd := 14.0
	for i in crit.size():
		var c: Dictionary = crit[i]
		var d := Vector2(CX + float(c.x) - q.x, CY + float(c.y) - q.y).length()
		if d < bd:
			bd = d
			best = i
	return best


## The canvas point over critter `i`, for a scripted tap.
func where(i: int) -> Vector2:
	var c: Dictionary = crit[i]
	return Vector2(CX + float(c.x), CY + float(c.y))


func down(_p: Vector2i) -> void:
	if ended:
		return
	started = true
	press = {q = pf, t = t, loupe = false}


func move(_p: Vector2i) -> void:
	if not press.is_empty():
		press.q = pf


func up(_p: Vector2i, cancel := false) -> void:
	if press.is_empty():
		return
	var pr := press
	press = {}
	if cancel or pr.loupe or ended:
		return
	var i := nearest(pf)
	if i >= 0:
		tap(i)


func tap(i: int) -> void:
	if ended or marked.has(i):
		return
	var ans: Array = pz.answers[phase]
	if ans.has(i):
		sfx(&"mark")
		marked[i] = true
		found += 1
		fx.append({i = i, t0 = clock, life = 0.4})
		hints.erase(i)
		if ans.all(func(j: int) -> bool: return marked.has(j)):
			_next_phase()
	else:
		wrong += 1
		fx.append({i = i, t0 = clock, life = 1.1, bad = true})
		say("WRONG", "bad")


func _next_phase() -> void:
	sfx(&"clear")
	if phase + 1 < (pz.rules as Array).size():
		phase += 1
		rule_flash = clock
		_pick_hints()
	else:
		sfx(&"win")
		_end()


func _end() -> void:
	if ended:
		return
	ended = true
	say_end("ALL LOGGED" if found == total else "TIME UP", "good" if found == total else "bad")
	done(score(found, total, wrong, time_left / T), "Found %d/%d, %d wrong" % [found, total, wrong])


func give_up() -> void:
	if ended:
		return
	ended = true
	done(0.5 * score(found, total, wrong, 0.0), "Gave up, found %d/%d" % [found, total])
