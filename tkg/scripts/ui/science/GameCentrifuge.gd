class_name GameCentrifuge
extends MiniGame

## CENTRIFUGE (Jon, Nov 17: "SO SILLY LMAO I LOVE IT"): load every tube so the rotor's centre of
## mass sits on the hub, then spin; a lean shakes it. A port of the approved prototype's
## `centrifuge2.js`, rule for rule and pixel for pixel, in its approved layout and the UI kit (Nov 20).
## Why: docs/why/MiniGame.md#centrifuge

const CFG := {
	1: {ns = [12], tubes = [5, 7], masses = [1, 1], overlap = false, blocked = 0, uneven = false},
	2: {ns = [12], tubes = [4, 6], masses = [1, 2], overlap = true, blocked = 0, uneven = true},
	3: {ns = [12, 10], tubes = [5, 7], masses = [1, 2], overlap = true, blocked = 2, uneven = true},
	4: {ns = [15], tubes = [5, 7], masses = [1, 2], overlap = true, blocked = 2, uneven = true},
	5: {ns = [15, 18], tubes = [6, 8], masses = [1, 3], overlap = true, blocked = 3, uneven = true},
}
## The game area, as every game draws it (the UI kit, Nov 20).
const W := MiniKit.W
const H := MiniKit.H
## The rotor's hub (the bowl in rows 22-126, the glass's middle: A, Nov 20), and the bowl, rotor, slot
## ring and hub window radii.
const CX := 53
const CY := 74
const RB := 52
const RR := 46
const RS := 34
const HUB := 14
const RACK := Rect2i(108, 21, 40, 82)
## SPIN, centred under the rack.
const SPIN := Rect2i(111, 107, 33, MiniKit.BTN_HL)
const WELL := Color("#05070b")
const HELD := Color("#2a1a0c")
const LIQ: Array[Color] = [Color(0, 0, 0, 0), MiniPix.TRACTOR, MiniPix.HOT, MiniPix.FLARE, MiniPix.BAD]
const LIQD: Array[Color] = [Color(0, 0, 0, 0), Color("#2f8f84"), Color("#b8923f"), Color("#b86a24"), Color("#7f3328")]
const QUANT: Array[float] = [0.09, 0.065, 0.045, 0.03, 0.015, 0.0]
const HALO: Array[int] = [4, 3, 3, 2, 1, 0]

var P: Dictionary = {}
var N := 12
var slots: Array[int] = []
var blocked := {}
var fixed := {}
var tray: Array[int] = []
var sel := 0
var moves := 0
var over := false
var spinning := false
var n_place := 0
var quant := 0.0
var halo := 0
var hr := 5
var pick := -1
var ang := 0.0
var ox := 0
var oy := 0
var hox := 0
var hoy := 0
## A tube in your hand: {src "rack"|"slot", j or i, m, x, y, x0, y0, moved, over}; empty when none.
var drag: Dictionary = {}
var msg_txt := ""
var msg_col := MiniPix.COLD
var press := 0
var acted := false
var _housing: Image
var _rotor: Image
## The spin's clock: seconds in, its last 30 fps step, its phase, the imbalance it spins with.
var _spin_t := -1.0
var _spin_last := 0.0
var _spin_ph := 0.0
var _spin_r := 0.0
var _icon_t := 0.0


func id() -> StringName:
	return &"centrifuge"


func hint() -> String:
	return "Balance the tubes."


func controls() -> Array[String]:
	return ["drag"]


# ---------------------------------------------------------------- the rules

## The load's moment about the hub: (x, y, mass).
static func vec(n: int, sl: Array[int]) -> Vector3:
	var x := 0.0
	var y := 0.0
	var m := 0.0
	for i in n:
		if sl[i]:
			var a := TAU * i / n - PI / 2.0
			x += sl[i] * cos(a)
			y += sl[i] * sin(a)
			m += sl[i]
	return Vector3(x, y, m)


static func imbalance(n: int, sl: Array[int]) -> float:
	var v := vec(n, sl)
	return Vector2(v.x, v.y).length() / v.z if v.z else 0.0


## A balanced load from `r`: {n, sol (each slot's tube mass), tubes (heaviest first), blocked}.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var out: Dictionary[String, Variant] = {}
	for t_ in 2000:
		var ns: Array = c.ns
		var n: int = ns[int(r.randf() * ns.size())]
		var ks: Array[int] = []
		for k in range(2, n):
			if n % k == 0 and k <= 6:
				ks.append(k)
		var sl: Array[int] = []
		sl.resize(n)
		var clash := false
		var np := 2 + int(r.randf() * 2)
		var masses: Array = c.masses
		for p in np:
			var k := ks[int(r.randf() * ks.size())]
			var o := int(r.randf() * n)
			var m: int = int(masses[0]) + int(r.randf() * (int(masses[1]) - int(masses[0]) + 1))
			for j in k:
				var s := (o + j * n / k) % n
				if sl[s]:
					clash = true
				sl[s] += m
		if clash != bool(c.overlap) or not _fair(c, n, sl):
			continue
		var free: Array[int] = []
		for i in n:
			if not sl[i]:
				free.append(i)
		if free.size() < int(c.blocked) + 1:
			continue
		for i in range(free.size() - 1, 0, -1):
			var j := int(r.randf() * (i + 1))
			var tmp := free[i]
			free[i] = free[j]
			free[j] = tmp
		var tubes: Array[int] = []
		for v in sl:
			if v:
				tubes.append(v)
		tubes.sort()
		tubes.reverse()
		out.assign({n = n, sol = sl, tubes = tubes, blocked = free.slice(0, int(c.blocked))})
		return out
	return out


## The load's shape is one this sector deals: its tube count, weights, and a balance that is real.
static func _fair(c: Dictionary, n: int, sl: Array[int]) -> bool:
	var tubes: Array[int] = []
	for v in sl:
		if v:
			tubes.append(v)
	var lim: Array = c.tubes
	if tubes.size() < int(lim[0]) or tubes.size() > int(lim[1]) or tubes.max() > 4:
		return false
	if not c.uneven and tubes.size() % 2 == 0:
		return false
	var kinds := {}
	for v in tubes:
		kinds[v] = true
	if c.uneven and kinds.size() < 2:
		return false
	if c.uneven:
		# with weights that differ, some weight alone must lean: the mix has to matter
		var all_even := true
		for m: int in kinds:
			var only: Array[int] = []
			for v in sl:
				only.append(v if v == m else 0)
			if imbalance(n, only) >= 1e-9:
				all_even = false
		if all_even:
			return false
	return imbalance(n, sl) <= 1e-9


static func score(r: float, mv: int, n_tubes: int) -> float:
	if r > 0.3:
		return 0.1
	var base := 1.0 if r < 1e-6 else maxf(0.15, 0.85 - r * 2.5)
	return maxf(0.1, base - minf(0.2, 0.03 * maxi(0, mv - n_tubes)))


# ---------------------------------------------------------------- the game

func _mount() -> void:
	P = gen(rng, depth)
	px = MiniPix.new(W, H)
	if P.is_empty():
		push_error("GameCentrifuge: no puzzle at depth %d" % depth)
		over = true
		done(0.0, "No puzzle")
		return
	N = P.n
	slots.resize(N)
	for b: int in P.blocked:
		blocked[b] = true
	tray.assign(P.tubes)
	if sensors >= 3:
		var m := tray[0]
		var at := (P.sol as Array[int]).find(m)
		slots[at] = m
		fixed[at] = true
		tray.remove_at(0)
	n_place = tray.size()
	quant = QUANT[mini(5, sensors)]
	halo = HALO[mini(5, sensors)]
	hr = 4 if N > 15 else 5
	_housing = _draw_housing()
	_rotor = _draw_rotor()
	_paint()


func _tick(dt: float) -> void:
	if _spin_t >= 0.0:
		_spin_step(dt)
	elif not acted and not over:
		# the start frame's icon animates (the prototype redraws every 66 ms)
		_icon_t += dt
		if _icon_t >= 0.066:
			_icon_t = 0.0
			_render()


## The housing, drawn once: a bowl with a lit rim and bolts.
func _draw_housing() -> Image:
	var c := MiniPix.new(W, H)
	c.clear(Color(0, 0, 0, 0))
	for y in range(CY - RB - 1, CY + RB + 2):
		for x in range(CX - RB - 1, CX + RB + 2):
			var dx := x - CX
			var dy := y - CY
			var d := Vector2(dx, dy).length()
			if d > RB + 0.5:
				continue
			var l := (-dx - dy) / (d if d != 0.0 else 1.0) / 1.414
			if d > RB - 0.7:
				c.dot(x, y, MiniPix.BEVEL_LO)
			elif d > RB - 4:
				var tt := 0.5 + 0.5 * l
				c.dot(x, y, MiniPix.CHILL if tt > 0.8 else (MiniPix.COLD if tt > 0.6 else (MiniPix.BEVEL_HI if tt > 0.35 else (MiniPix.LINE if tt > 0.15 else MiniPix.BEVEL_LO))))
			elif d > RB - 5:
				c.dot(x, y, MiniPix.BEVEL_LO)
			else:
				# the dark well under the rotor
				c.dot(x, y, WELL if MiniPix.lit(x, y, 0.3 + 0.25 * (-l)) else MiniPix.BEVEL_LO)
	for k in 8:
		var a := k * PI / 4.0 + PI / 8.0
		var bx := MiniPix.jr(CX + (RB - 2) * cos(a))
		var by := MiniPix.jr(CY + (RB - 2) * sin(a))
		c.dot(bx, by, MiniPix.ICE)
		c.dot(bx + 1, by + 1, MiniPix.BEVEL_LO)
	return c.img


## The rotor, drawn once: brushed metal, symmetric so it never needs turning, and the hub's rim.
func _draw_rotor() -> Image:
	var c := MiniPix.new(W, H)
	c.clear(Color(0, 0, 0, 0))
	for y in range(CY - RR, CY + RR + 1):
		for x in range(CX - RR, CX + RR + 1):
			var dx := x - CX
			var dy := y - CY
			var d := Vector2(dx, dy).length()
			if d > RR + 0.4 or d < HUB + 1.5:
				continue
			var l := (-dx - dy) / (d if d != 0.0 else 1.0) / 1.414
			var col: Color
			if d > RR - 0.6:
				col = MiniPix.BEVEL_LO
			elif d > RR - 2:
				col = MiniPix.ICE if l > 0.3 else (MiniPix.CHILL if l > -0.2 else MiniPix.COLD)
			elif absf(d - (RS + hr + 3)) < 0.5:
				col = MiniPix.BEVEL_HI if l > 0 else MiniPix.LINE
			elif absf(d - (HUB + 4)) < 0.5:
				col = MiniPix.BEVEL_LO
			else:
				col = MiniPix.COLD if MiniPix.lit(x, y, 0.45 + 0.35 * l + 0.08 * sin(d * 1.7)) else MiniPix.BEVEL_HI
			c.dot(x, y, col)
	for y in range(CY - HUB - 2, CY + HUB + 3):
		for x in range(CX - HUB - 2, CX + HUB + 3):
			var dx := x - CX
			var dy := y - CY
			var d := Vector2(dx, dy).length()
			if d > HUB + 1.6 or d < HUB - 0.4:
				continue
			var l := (-dx - dy) / (d if d != 0.0 else 1.0) / 1.414
			if d > HUB + 0.6:
				c.dot(x, y, MiniPix.CHILL if l > 0 else MiniPix.LINE)
			else:
				c.dot(x, y, MiniPix.BEVEL_LO if l > 0 else MiniPix.COLD)
	return c.img


# ---------------------------------------------------------------- drawing

## The prototype's `disc`: each pixel within r (with its 0.8 r slack) asks `fn` for a colour.
func _disc(cx: int, cy: int, r: int, fn: Callable) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d2 := x * x + y * y
			if d2 <= r * r + r * 0.8:
				var c: Variant = fn.call(x, y, d2)
				if c != null:
					px.dot(cx + x, cy + y, c)


## A ring of `c` round slot (cx, cy): every pixel, or every other (`checker`).
func _ring(cx: int, cy: int, c: Color, checker: bool) -> void:
	var r := hr + 1
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d2 := x * x + y * y
			if d2 <= r * r + r * 0.8 and d2 > hr * hr and (not checker or (x + y) & 1):
				px.dot(cx + x, cy + y, c)


func slot_xy(i: int, a: float, dx: int, dy: int) -> Vector2i:
	var t2 := TAU * i / N - PI / 2.0 + a
	return Vector2i(MiniPix.jr(CX + dx + RS * cos(t2)), MiniPix.jr(CY + dy + RS * sin(t2)))


## A tube from above: glass rim, coloured liquid, a glint, its weight.
func _tube_top(cx: int, cy: int, m: int, is_fixed: bool) -> void:
	var r := hr
	var rim := (r - 1) * (r - 1) + (r - 1) * 0.8
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d2 := x * x + y * y
			if d2 <= r * r + r * 0.8:
				var col := (MiniPix.ICE if is_fixed else MiniPix.BEVEL_LO) if d2 > rim else (LIQD[m] if -(x + y) < -2 else LIQ[m])
				px.dot(cx + x, cy + y, col)
	px.dot(cx - 2, cy - 2, MiniPix.ICE)
	px.text(str(m), cx - 1, cy - 2, MiniPix.VOID)


## An empty slot, its rim lit bottom-right inside; a blocked one crossed out.
func _hole(cx: int, cy: int, is_blocked: bool) -> void:
	var r := hr
	var rim := (r - 1) * (r - 1) + (r - 1) * 0.8
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d2 := x * x + y * y
			if d2 <= r * r + r * 0.8:
				var col := (MiniPix.CHILL if x + y > 0 else MiniPix.BEVEL_LO) if d2 > rim else (WELL if x + y < -1 else MiniPix.BEVEL_LO)
				px.dot(cx + x, cy + y, col)
	if is_blocked:
		for k in range(-2, 3):
			px.dot(cx + k, cy + k, MiniPix.BAD)
			px.dot(cx + k, cy - k, MiniPix.BAD)


## A tube from the side, for the rack and the one in your hand.
func _tube_side(x: int, y: int, m: int, hot: bool) -> void:
	var th := 13
	for j in th:
		var bottom := j == th - 1
		for i in 6:
			if bottom and (i == 0 or i == 5):
				continue
			var edge := i == 0 or i == 5 or bottom
			var lvl := th - 1 - j
			var c: Color
			if edge:
				c = MiniPix.FLARE if hot else MiniPix.CHILL
			elif lvl <= m * 3:
				c = MiniPix.ICE if i == 1 else (LIQD[m] if i >= 4 else LIQ[m])
			else:
				c = MiniPix.BEVEL_HI if i == 1 else MiniPix.VOID
			px.dot(x + i, y + j, c)
	px.rect(x - 1, y, 8, 1, MiniPix.FLARE if hot else MiniPix.COLD)


func cell_rect(j: int) -> Rect2i:
	return Rect2i(RACK.position.x + 2 + (j % 2) * 19, RACK.position.y + 9 + (j / 2) * 18, 18, 17)


## The rotor as it would be with the tube in your hand dropped where it hovers (a live preview).
func view() -> Array[int]:
	if drag.is_empty() or not drag.moved:
		return slots
	var v: Array[int] = slots.duplicate()
	if drag.src == "slot":
		v[int(drag.i)] = 0
	var o := int(drag.over)
	if o >= 0 and not blocked.has(o) and not fixed.has(o) and not v[o]:
		v[o] = int(drag.m)
	return v


## Where the hub's dot sits: the load's lean, blurred to the sensors' step.
func indicator() -> Dictionary[String, Variant]:
	var v := vec(N, view())
	var tot := 0
	for m: int in P.tubes:
		tot += m
	var dx := v.x / tot
	var dy := v.y / tot
	if quant > 0.0:
		var r := Vector2(dx, dy).length()
		var qr := floorf(r / quant + 0.5) * quant
		var k := qr / r if r else 0.0
		dx *= k
		dy *= k
	var gain := 33.0
	var ln := Vector2(dx, dy).length() * gain
	var cl := (HUB - 3) / ln if ln > HUB - 3 else 1.0
	var out: Dictionary[String, Variant] = {}
	out.assign({x = MiniPix.jr(dx * gain * cl), y = MiniPix.jr(dy * gain * cl), centred = Vector2(dx, dy).length() < 1e-9})
	return out


func _render() -> void:
	px.clear(MiniKit.BORDER)
	px.blit(_housing, hox, hoy)
	px.blit(_rotor, ox, oy)
	_slots()
	_hub()
	_rack()
	_spin_button()
	MiniKit.header(px, {label = "ROTOR", value = N}, [["MOVES", moves]])
	# A (Nov 20): no status line; READY and SPINNING are SPIN's amber and the spin itself
	if not acted and not over:
		MiniKit.tell(px, "BALANCE THE TUBES.", ["click", "drag", MiniKit.ESC] as Array[String], t)
	if not drag.is_empty() and drag.moved:
		_tube_side(int(drag.x) - 3, int(drag.y) - 7, int(drag.m), true)
	draw_toast()
	dirty = true


## The slots and tubes ride the rotor.
func _slots() -> void:
	var lifted := int(drag.i) if not drag.is_empty() and drag.moved and drag.src == "slot" else -1
	for i in N:
		var at := slot_xy(i, ang, ox, oy)
		if slots[i] and i != lifted:
			_tube_top(at.x, at.y, slots[i], fixed.has(i))
		else:
			_hole(at.x, at.y, blocked.has(i))
		var free := not blocked.has(i) and not fixed.has(i) and (not slots[i] or i == lifted)
		if not drag.is_empty() and drag.moved and not spinning and free and int(drag.over) == i:
			_ring(at.x, at.y, MiniPix.FLARE, false)
		if pick == i and drag.is_empty():
			# a picked tube: tap a free slot to move it
			_ring(at.x, at.y, MiniPix.FLARE, true)


## The hub window, fixed to the housing so it reads during the spin: its target ring and the dot.
func _hub() -> void:
	var hx0 := CX + hox
	var hy0 := CY + hoy
	_disc(hx0, hy0, HUB - 1, func(x: int, y: int, _d2: int) -> Variant:
		return MiniPix.PANEL if MiniPix.lit(x + hx0, y + hy0, 0.15) else MiniPix.VOID)
	px.rect(hx0 - HUB + 2, hy0, 2 * HUB - 3, 1, MiniPix.LINE)
	px.rect(hx0, hy0 - HUB + 2, 1, 2 * HUB - 3, MiniPix.LINE)
	var ind := indicator()
	var n_in := 0
	for v in view():
		if v:
			n_in += 1
	var fin: bool = ind.centred and n_in == (P.tubes as Array).size()
	var ring := MiniPix.GOOD if fin else MiniPix.BEVEL_HI
	_disc(hx0, hy0, 3, func(_x: int, _y: int, d2: int) -> Variant: return ring if d2 >= 5 and d2 <= 12 else null)
	var dx := hx0 + int(ind.x)
	var dy := hy0 + int(ind.y)
	if halo:
		_disc(dx, dy, halo, func(x: int, y: int, d2: int) -> Variant:
			var tt := 1.0 - sqrt(d2) / (halo + 1)
			return MiniPix.FLARE if MiniPix.lit(dx + x, dy + y, tt * 0.9) else null)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		px.dot(dx + p.x, dy + p.y, MiniPix.HOT)
	px.dot(dx, dy, MiniPix.ICE)


func _rack() -> void:
	var r0 := RACK
	px.rect(r0.position.x, r0.position.y, r0.size.x, r0.size.y, MiniPix.BEVEL_LO)
	px.rect(r0.position.x + 1, r0.position.y + 1, r0.size.x - 2, r0.size.y - 2, MiniPix.PANEL)
	px.rect(r0.position.x + 1, r0.position.y + 1, r0.size.x - 2, 1, MiniPix.BEVEL_HI)
	px.rect(r0.position.x + 1, r0.position.y + 1, 1, r0.size.y - 2, MiniPix.LINE)
	px.text("RACK", r0.position.x + r0.size.x / 2, r0.position.y + 3, MiniPix.COLD, "center")
	if tray.is_empty():
		px.text("EMPTY", r0.position.x + r0.size.x / 2, r0.position.y + 38, MiniPix.LINE, "center")
	# a rotor tube held over the rack, or picked by a tap: the rack lights to take it back
	var held_over: bool = not drag.is_empty() and drag.moved and drag.src == "slot" and r0.has_point(Vector2i(int(drag.x), int(drag.y)))
	if held_over or (pick >= 0 and drag.is_empty()):
		var c := MiniPix.EMBER if pick >= 0 and drag.is_empty() else MiniPix.FLARE
		px.rect(r0.position.x, r0.position.y, r0.size.x, 1, c)
		px.rect(r0.position.x, r0.end.y - 1, r0.size.x, 1, c)
		px.rect(r0.position.x, r0.position.y, 1, r0.size.y, c)
		px.rect(r0.end.x - 1, r0.position.y, 1, r0.size.y, c)
	for j in tray.size():
		var r := cell_rect(j)
		var on := j == sel
		if on:
			px.rect(r.position.x, r.position.y, r.size.x, r.size.y, MiniPix.EMBER)
			px.rect(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2, HELD)
		if not drag.is_empty() and drag.moved and drag.src == "rack" and int(drag.j) == j:
			continue
		_tube_side(r.position.x + 3, r.position.y + 2, tray[j], on)
		px.text(str(tray[j]), r.position.x + 12, r.position.y + 6, MiniPix.HOT if on else MiniPix.CHILL)


func _spin_button() -> void:
	var ready := not over and not spinning and tray.is_empty()
	var b := SPIN
	var state := ("active-pressed" if press > 0 else "active") if ready else ("pressed" if spinning else "disabled")
	MiniKit.button(px, b.position.x, b.position.y, b.size.x, b.size.y, "SPIN", state, "spin")


func _set_msg() -> void:
	if over or not acted:
		return
	if not tray.is_empty():
		msg_txt = ""
		msg_col = MiniPix.COLD
	else:
		msg_txt = "READY"
		msg_col = MiniPix.EMBER


func _paint() -> void:
	_set_msg()
	_render()


# ---------------------------------------------------------------- moves

## Rack -> slot.
func place(j: int, i: int) -> bool:
	if over or spinning or blocked.has(i) or fixed.has(i) or slots[i] or j < 0 or j >= tray.size():
		return false
	slots[i] = tray[j]
	tray.remove_at(j)
	moves += 1
	sfx(&"seat")
	sel = mini(j, tray.size() - 1) if not tray.is_empty() else -1
	pick = -1
	_paint()
	return true


## Slot -> slot.
func shift(a: int, b: int) -> bool:
	if over or spinning or a == b or not slots[a] or fixed.has(a) or blocked.has(b) or fixed.has(b) or slots[b]:
		return false
	slots[b] = slots[a]
	slots[a] = 0
	moves += 1
	sfx(&"seat")
	pick = -1
	_paint()
	return true


## Slot -> rack.
func unload(i: int) -> bool:
	if over or spinning or not slots[i] or fixed.has(i):
		return false
	var m := slots[i]
	slots[i] = 0
	tray.append(m)
	tray.sort()
	tray.reverse()
	sel = tray.find(m)
	pick = -1
	_paint()
	return true


## Taps do the jobs drags do: tap a tube (rack or rotor), then where it goes.
func tap_slot(i: int) -> void:
	if over or spinning or blocked.has(i) or fixed.has(i):
		return
	if slots[i]:
		# pick it up; a second tap sets it down again
		pick = -1 if pick == i else i
		_paint()
		return
	if pick >= 0:
		shift(pick, i)
		return
	if sel >= 0 and sel < tray.size():
		place(sel, i)


func _do_spin() -> void:
	if over or spinning or not tray.is_empty():
		return
	sfx(&"spin")
	spinning = true
	msg_txt = "SPINNING"
	msg_col = MiniPix.CHILL
	_spin_r = imbalance(N, slots)
	_spin_t = 0.0
	_spin_last = -1.0
	_spin_ph = 0.0


## 2.2 s of spin at 30 steps a second: up to speed, a lean shaking the rotor, then down.
func _spin_step(dt: float) -> void:
	_spin_t += dt
	var tt := minf(1.0, _spin_t / 2.2)
	if _spin_t - _spin_last >= 0.033 or tt >= 1.0:
		_spin_last = _spin_t
		var sp := tt / 0.25 if tt < 0.25 else ((1.0 - tt) / 0.2 if tt > 0.8 else 1.0)
		ang += sp * 0.34
		_spin_ph += sp * 1.9
		# an off-centre load shakes the rotor; a whole pixel even for a small lean
		var amp := maxf(1.0, minf(6.0, _spin_r * 30.0)) * sp if _spin_r > 1e-6 else 0.0
		ox = MiniPix.jr(amp * cos(_spin_ph))
		oy = MiniPix.jr(amp * sin(_spin_ph))
		hox = MiniPix.jr(ox / 2.0)
		hoy = MiniPix.jr(oy / 2.0)
		_render()
	if tt >= 1.0:
		_spin_t = -1.0
		ox = 0
		oy = 0
		hox = 0
		hoy = 0
		_finish(_spin_r)


func _finish(r: float) -> void:
	over = true
	spinning = false
	var sc := score(r, moves, n_place)
	var pct := MiniPix.jr(r * 100.0)
	msg_txt = "BALANCED" if r < 1e-6 else ("ROTOR FAULT" if r > 0.3 else "WOBBLE %d%%" % pct)
	msg_col = MiniPix.GOOD if r < 1e-6 else (MiniPix.BAD if r > 0.3 else MiniPix.WARN)
	say_end(msg_txt, "good" if r < 1e-6 else ("bad" if r > 0.3 else "neutral"))
	if r < 1e-6:
		sfx(&"win")
	_render()
	var detail := "%s, %d moves" % ["balanced" if r < 1e-6 else "%d%% off" % pct, moves]
	after(0.7, func() -> void: done(sc, detail))


# ---------------------------------------------------------------- input

func slot_at(q: Vector2i) -> int:
	var best := -1
	var bd := 1e9
	for i in N:
		var at := slot_xy(i, 0.0, 0, 0)
		var d := Vector2(q - at).length()
		if d < bd:
			bd = d
			best = i
	return best if bd <= hr + 2.5 else -1


func rack_at(q: Vector2i) -> int:
	for j in tray.size():
		if cell_rect(j).has_point(q):
			return j
	return -1


func down(q: Vector2i) -> void:
	if over or spinning:
		return
	acted = true
	if SPIN.has_point(q):
		if tray.is_empty():
			press = 1
			_render()
			after(0.09, func() -> void:
				press = 0
				_do_spin())
		return
	if pick >= 0 and RACK.has_point(q):
		# a picked rotor tube, then the rack: back it goes
		unload(pick)
		return
	var j := rack_at(q)
	if j >= 0:
		drag = {src = "rack", j = j, i = -1, m = tray[j], x = q.x, y = q.y, x0 = q.x, y0 = q.y, moved = false, over = -1}
		_render()
		return
	var i := slot_at(q)
	if i >= 0 and slots[i] and not fixed.has(i):
		drag = {src = "slot", j = -1, i = i, m = slots[i], x = q.x, y = q.y, x0 = q.x, y0 = q.y, moved = false, over = -1}
		_render()
		return
	if i >= 0:
		tap_slot(i)


func move(q: Vector2i) -> void:
	if drag.is_empty():
		return
	drag.x = q.x
	drag.y = q.y
	if not drag.moved and Vector2(q.x - int(drag.x0), q.y - int(drag.y0)).length() > 2:
		drag.moved = true
		pick = -1
	drag.over = slot_at(q)
	_render()


func up(q: Vector2i, cancel := false) -> void:
	if drag.is_empty():
		return
	var d := drag
	drag = {}
	if cancel:
		_paint()
		return
	if not d.moved:
		# a tap
		if d.src == "rack":
			sel = int(d.j)
			pick = -1
			_paint()
		else:
			tap_slot(int(d.i))
		return
	var i := slot_at(q)
	if d.src == "rack":
		if i >= 0 and place(int(d.j), i):
			return
		sel = int(d.j)
		_paint()
		return
	if i >= 0 and i != int(d.i) and shift(int(d.i), i):
		return
	if i < 0 and Vector2(q.x - CX, q.y - CY).length() > RR + 2:
		# dragged off the rotor: back to the rack
		unload(int(d.i))
		return
	# dropped on the rotor but not in a free slot: it stays put
	_paint()


func give_up() -> void:
	if over:
		return
	over = true
	spinning = false
	_spin_t = -1.0
	ox = 0
	oy = 0
	hox = 0
	hoy = 0
	msg_txt = "GAVE UP"
	msg_col = MiniPix.COLD
	_render()
	done(0.0, "Gave up")
