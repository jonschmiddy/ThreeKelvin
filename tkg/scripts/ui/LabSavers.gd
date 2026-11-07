class_name LabSavers
extends RefCounted

## MOCK (review_lab r5, Nov 5; not for feat/science): seven screensavers for the
## Lab's glass at rest, each with its own hover cue. Jon on round three: "I like
## the screensaver the best, but I want more options for what these can be."
##
##   B  THE BOARD'S CHART, polished: drawn with the board's own painter
##      (`LabBoard`'s rings, discs, halos, arms and states) where the landed
##      camera will find the board, turning slowly; hover squares it up and
##      zooms in a little; signing in lands it on the board's own angle and size
##   1  THE SKY OUTSIDE: this system's star and worlds in a telescope, the
##      crosshair stepping from world to world, readings ticking, DATA logged
##   2  SPECIMEN SCAN: a relic turning as a wireframe under a scan line, its
##      spectrum beside it
##   3  RESEARCH FEED: findings from other pilots and the owner's labs, one line
##      at a time, and a counter of routines researched galaxy-wide
##   4  YOUR SHIP: the hull as a blueprint, each fitted part called out in turn
##      with its augment slot
##   5  THE OWNER'S POSTERS: corporate cards in plain words, one after another
##   6  THE GALAXY: the run's galaxy turning as a toy, your route traced on it,
##      the core pulsing
##
## Everything is drawn on `LabLogin`'s canvas, in its window's px, on the lab's
## clock (`since_on`, the lamp clock) and the look's own (`_t`): never the wall.

var g: LabLogin
var _bp: LabBoard = null
## Pixels nothing is drawn on (the plate, a corner's words), and the clip.
var _keep: Array[Rect2i] = []
var _clip := Rect2i()
var _circ_c := Vector2i.ZERO
var _circ_r := -1
## Stateful motion (turns that ease to a stop on hover).
var _b_rot := 0.0
var _b_k := -1.0
var _s2_spin := 0.0
var _g_rot := 0.0
var _hull_cache := {}
var _layout: SystemLayout = null
var _layout_at := -1


func _init(login: LabLogin) -> void:
	g = login


func release() -> void:
	if _bp != null:
		_bp.free()
		_bp = null


func paint(style: String) -> void:
	_keep.clear()
	_clip = g.area()
	_circ_r = -1
	match style:
		"B":
			_paint_b()
		"1":
			_paint_1()
		"2":
			_paint_2()
		"3":
			_paint_3()
		"4":
			_paint_4()
		"5":
			_paint_5()
		"6":
			_paint_6()
		"K1":
			_paint_k1()
		"K2":
			_paint_k2()
		"K3":
			_paint_k3()
		"P1":
			_paint_p1()
		"P2":
			_paint_p2()
		"P3":
			_paint_p3()
		"R1":
			_paint_r1()
		"R2":
			_paint_r2()
		"R3":
			_paint_r3()
		"C1":
			_paint_c1()
		"C2":
			_paint_c2()
		"C3":
			_paint_c3()
		_:
			_solari().paint(style)


## MOCK (r6 owners): the Solari Foundry's own savers (`LabSaversSolari`).
var _sol: LabSaversSolari = null


func _solari() -> LabSaversSolari:
	if _sol == null:
		_sol = LabSaversSolari.new(self)
	return _sol


## The motion that carries from frame to frame: the chart's turn and size, the
## specimen's spin, the galaxy's turn.
func step(delta: float, style: String) -> void:
	var resting := g.state == LabLogin.LOGO
	if resting:
		_s3_hold = -1.0
	elif _s3_hold < 0.0:
		_s3_hold = rest_t()
	match style:
		"B":
			var goal := B_REST if resting else (B_HOVER if g.state == LabLogin.LOGIN else 1.0)
			if _b_k < 0.0:
				_b_k = goal
			_b_k = lerpf(_b_k, goal, 1.0 - exp(-delta * (9.0 if g.state == LabLogin.SIGNING else 6.0)))
			if resting:
				_b_rot = fposmod(_b_rot + delta * TAU / B_TURN_S, TAU)
			else:
				# squared up to the board's own angle (0), the short way round
				var home := 0.0 if _b_rot < PI else TAU
				_b_rot = lerpf(_b_rot, home, 1.0 - exp(-delta * (8.0 if g.state == LabLogin.SIGNING else 4.0)))
				if absf(_b_rot - home) < 0.002:
					_b_rot = 0.0
		"2":
			var sp := 1.0 if resting else 0.0
			_s2_spin += delta * TAU / S2_TURN_S * lerpf(sp, _s2_last, exp(-delta * 4.0))
			_s2_last = lerpf(_s2_last, sp, 1.0 - exp(-delta * 4.0))
		"R3":
			if resting and _r3_heat(rest_t()) > R3_RATED:
				_r3_over += delta
		"6":
			_g_last = lerpf(_g_last, 1.0 if resting else 0.0, 1.0 - exp(-delta * 3.0))
			_g_rot = fposmod(_g_rot + delta * TAU / G_TURN_S * _g_last, TAU)
		"P1", "P2", "P3":
			# the Combine's own savers ease to a stop when pointed at: their clock
			# falls behind the lab's by what the hover held back
			_p_k = lerpf(_p_k, 1.0 if resting else 0.0, 1.0 - exp(-delta * 4.0))
			if g.since_on() > 0.0:
				_p_lag += delta * (1.0 - _p_k)
		"C3":
			# the zoom eases to a stop when pointed at
			_c3_last = lerpf(_c3_last, 1.0 if resting else 0.0, 1.0 - exp(-delta * 3.0))
			_c3_u += delta / C3_T * _c3_last
	_solari().step(delta, style)


var _s2_last := 1.0
var _g_last := 1.0


# ================================================================== the kit

func ink(a: float) -> Color:
	return g._ink(clampf(a, 0.0, 1.0))


func cue() -> Color:
	return g._ink(g.cue_ink())


## The hover, eased in over `dur` (1 while signing in, 0 at rest).
func hk(dur: float = 0.3) -> float:
	if g.state == LabLogin.LOGO:
		return 0.0
	if g.state == LabLogin.SIGNING:
		return 1.0
	var k := clampf(g._t / dur, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


func rest_t() -> float:
	return maxf(0.0, g.since_on())


## The power-on's fade (the look comes up as the lab's screen opens).
func fade() -> float:
	return clampf((g.since_on() + 0.6) / 0.9, 0.0, 1.0)


func ok(x: int, y: int) -> bool:
	if not _clip.has_point(Vector2i(x, y)):
		return false
	if _circ_r >= 0:
		var dx := x - _circ_c.x
		var dy := y - _circ_c.y
		if dx * dx + dy * dy > _circ_r * _circ_r:
			return false
	for r in _keep:
		if r.has_point(Vector2i(x, y)):
			return false
	return true


func px(x: int, y: int, c: Color) -> void:
	if ok(x, y):
		g.draw_rect(Rect2(x, y, 1, 1), c)


func box_free(r: Rect2i) -> bool:
	if not _clip.encloses(r):
		return false
	for k in _keep:
		if k.intersects(r):
			return false
	return true


## A one-pixel line; `every` > 1 dots it (`off` moves the dots along).
func line(a: Vector2i, b: Vector2i, c: Color, every: int = 1, off: int = 0) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	var n := 0
	while true:
		if every <= 1 or posmod(n + off, every) == 0:
			px(p.x, p.y, c)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
		n += 1


func text(x: int, y: int, s: String, c: Color, sz: int = 8) -> void:
	g._text(x, y, s, c, sz)


## Words with "·" in them: Silkscreen's own dot if it has one, else drawn.
func say_w(s: String, sz: int = 8) -> int:
	if not s.contains("·"):
		return LabBoard.tw(s, sz)
	var w := 0
	var parts := s.split("·")
	for i in parts.size():
		w += LabBoard.tw(parts[i], sz)
		if i < parts.size() - 1:
			w += 3 if sz == 8 else 6
	return w


func say(x: int, y: int, s: String, c: Color, sz: int = 8, leaf: bool = true) -> void:
	var parts := s.split("·")
	var cx := x
	var cap := 5 if sz == 8 else 10
	var d := 1 if sz == 8 else 2
	for i in parts.size():
		if parts[i] != "":
			LabBoard.text_at(g, cx, y, parts[i], c, sz)
		cx += LabBoard.tw(parts[i], sz)
		if i < parts.size() - 1:
			var gap := 3 if sz == 8 else 6
			g.draw_rect(Rect2(cx + (gap - d) / 2 - (1 if sz == 8 else 0), y + cap / 2 - d / 2, d, d), c)
			cx += gap
	if leaf:
		g.leaves.append([s, Rect2i(x, y - 1, say_w(s, sz), cap + 2)])


func sayc(cx: int, y: int, s: String, c: Color, sz: int = 8, leaf: bool = true) -> void:
	say(cx - say_w(s, sz) / 2, y, s, c, sz, leaf)


func fit(s: String, wmax: int, sz: int = 8) -> String:
	return g._fit(s, wmax, sz)


## The owner's mark and short name, a header at (x, y) (the mark 11 px).
func head(x: int, y: int, extra: String = "") -> int:
	g._mark(x + 5, y + 5, 11, 1.0)
	var s := g.owner_short() + extra
	text(x + 14, y + 3, s, ink(0.85))
	return x + 14 + LabBoard.tw(s)


## A sign-in plate: a dark box, its frame, corner brackets, and its lines
## (centred). Returns the plate's rect (a leaf, and kept clear of the drawing).
func plate(cx: int, top: int, lines: Array, open: float = 1.0) -> Rect2i:
	var wmax := 0
	for l: Array in lines:
		wmax = maxi(wmax, say_w(String(l[0]), int(l[2]) if l.size() > 2 else 8))
	var pw := maxi(4, int(float(wmax + 14) * open)) & ~1
	var ph := 4
	for l: Array in lines:
		ph += (10 if (int(l[2]) if l.size() > 2 else 8) == 8 else 15)
	ph += 1
	return Rect2i(cx - pw / 2, top, pw, ph)


func plate_draw(r: Rect2i, lines: Array, full: bool) -> void:
	g.draw_rect(Rect2(r), LabBoard.BG)
	g._frame_box(r, ink(0.45))
	g._brackets(r.grow(2), 4, ink(0.9))
	g.leaves.append(["plate", r.grow(2)])
	if not full:
		return
	var y := r.position.y + 5
	for l: Array in lines:
		var sz: int = int(l[2]) if l.size() > 2 else 8
		sayc(r.position.x + r.size.x / 2, y, String(l[0]), l[1] as Color, sz, false)
		y += 10 if sz == 8 else 15


func ship() -> String:
	return g._ship()


func noise(i: int, j: int) -> float:
	return float(absi(hash(Vector2i(i, j))) % 1000) / 1000.0


# ================================================================== B: the board's chart

const B_TURN_S := 60.0
## The chart's size at rest, pointed at, and signing in, as a share of the size
## the landed camera will show the board at.
const B_REST := 0.8
const B_HOVER := 0.88


func _painter() -> LabBoard:
	if _bp == null:
		_bp = LabBoard.new()
	_bp.tint = g.tint
	return _bp


func _paint_b() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	# WHERE THE BOARD STANDS once the camera lands (its hub at the board's
	# CX, CY), in this window's px, and the scale the landed camera shows it at
	var c := Vector2(a.get_center())
	var kfull := 0.25
	var lab := g.lab
	if lab != null and not lab.lab.is_empty():
		var z := float(LabZoom.ZOOM.get(lab._level, 3))
		c = (Vector2(LabBoard.CX, LabBoard.CY) - LabZoom.landed_origin(lab)) / z - lab.win_rect().position
		kfull = 1.0 / z
	var kk := kfull * (_b_k if _b_k > 0.0 else B_REST)
	var rot := _b_rot
	# the owner, its mark at twice the size, in the corner
	var mcx := x0 + 14
	var mcy := y0 + h - 14
	g._mark(mcx, mcy, 22, 2.0)
	var tx := mcx + 14
	text(tx, mcy - 7, g.owner_short(), ink(0.9))
	text(tx, mcy + 3, "RESEARCH TERMINAL", ink(0.55))
	_keep.append(Rect2i(mcx - 13, mcy - 13, 14 + 26 + LabBoard.tw("RESEARCH TERMINAL"), 27))
	g._data_corner()
	var ds := "DATA %d" % g.data
	_keep.append(Rect2i(a.end.x - 8 - LabBoard.tw(ds), y0 + 2, LabBoard.tw(ds) + 6, 10))
	# the plate, pointed at: under the hub
	var hub_r := maxi(5, roundi(float(LabBoard.HR) * kk))
	var pl := Rect2i()
	var lines := [["PILOT %s · SIGN IN" % ship(), cue()]]
	if g.state == LabLogin.SIGNING:
		lines = [["PILOT %s · SIGNING IN" % ship(), ink(0.9)]]
	if g.state != LabLogin.LOGO:
		var open := clampf(g._t / 0.15, 0.0, 1.0) if g.state == LabLogin.LOGIN else 1.0
		# over the hub, clear of its glow (under it is the owner's corner)
		pl = plate(int(c.x), 0, lines, open)
		pl.position.y = maxi(y0 + 3, int(c.y) - hub_r - 8 - pl.size.y)
		_keep.append(pl.grow(3))
	if dim > 0.0:
		_b_chart(c, kk, rot, tr, dim * (1.0 - 0.3 * hk(0.45)))
	if pl.has_area():
		plate_draw(pl, lines, pl.size.x >= say_w(String(lines[0][0])) + 8)


func _b_proj(c: Vector2, k: float, rot: float, rho: float, phi: float) -> Vector2i:
	var v := c + Vector2(rho * cos(phi + rot) * LabBoard.SX, -rho * sin(phi + rot) * LabBoard.SY) * k
	return Vector2i(v.round())


func _b_depth(rot: float, phi: float) -> float:
	return 0.88 - 0.15 * sin(phi + rot)


func _b_state(b: int, k: int) -> StringName:
	var o := clampi(Run.board_owned[b] if b < Run.board_owned.size() else 0, 0, 3)
	if k < o:
		return &"owned"
	if k == o:
		return &"next" if Run.data >= int(DB.BOARD_PRICES[k]) else &"short"
	return &"later"


func _b_chart(c: Vector2, k: float, rot: float, tr: float, dim: float) -> void:
	var bp := _painter()
	var BG := LabBoard.BG
	# THE STARS OF THE DISC
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		var rho := 30.0 + pow(rng.randf(), 0.7) * 390.0
		var phi := rng.randf() * TAU
		var lv := 0.16 + 0.34 * rng.randf()
		var p := _b_proj(c, k, rot, rho, phi)
		px(p.x, p.y, ink(lv * _b_depth(rot, phi) * dim))
	# THE CORE'S GLOW, dithered
	var gr := float(LabBoard.HR) * k * 2.4
	var gi := ceili(gr)
	var cc := Vector2i(c.round())
	for dy in range(-gi, gi + 1):
		for dx in range(-gi * 2, gi * 2 + 1):
			var d := sqrt(pow(float(dx) / 1.9, 2.0) + float(dy * dy)) / gr
			if d >= 1.0:
				continue
			var q := cc + Vector2i(dx, dy)
			if LabBoard.bayer(q.x, q.y) < pow(1.0 - d, 1.6) * 0.7:
				px(q.x, q.y, ink(0.2 * dim))
	var r := maxi(3, roundi(float(LabBoard.NR) * k))
	var hub_r := maxi(5, roundi(float(LabBoard.HR) * k))
	var phase := fposmod(tr / 2.4, 1.0)
	# where each step stands now
	var at := {}
	for b in 3:
		for kk in 3:
			var rho := float(LabBoard.RHO[kk])
			var phi := float(LabBoard.PHI0[b]) + LabBoard.WIND * rho
			at[Vector2i(b, kk)] = _b_proj(c, k, rot, rho, phi)
	# THE ARMS, by the board's rule: a running stretch solid and lit, the
	# stretch to the next step dashed and moving, one still to come dotted
	for b in 3:
		for kk in 3:
			var st := _b_state(b, kk)
			var r0 := float(LabBoard.HR) if kk == 0 else float(LabBoard.RHO[kk - 1])
			var r1 := float(LabBoard.RHO[kk])
			var pts: Array[Vector2i] = []
			var rho := r0
			var stp := 0.4 / k
			var a0: Vector2i = cc if kk == 0 else at[Vector2i(b, kk - 1)]
			var a1: Vector2i = at[Vector2i(b, kk)]
			var lim0 := (hub_r + 2) if kk == 0 else (r + 2)
			while rho <= r1:
				var phi := float(LabBoard.PHI0[b]) + LabBoard.WIND * rho
				var p := _b_proj(c, k, rot, rho, phi)
				if (p - a0).length() > lim0 and (p - a1).length() > r + 2 and (pts.is_empty() or pts[-1] != p):
					pts.append(p)
				rho += stp
			var dep := _b_depth(rot, float(LabBoard.PHI0[b]) + LabBoard.WIND * (r0 + r1) * 0.5) * dim
			var n := 0
			var off := -int(phase * 8.0)
			for p in pts:
				n += 1
				match st:
					&"owned":
						px(p.x, p.y, LabBoard.mixc(BG, LabBoard.OWN, dep))
					&"next", &"short":
						if posmod(floori(float(n + off) / 3.0), 2) == 0:
							px(p.x, p.y, LabBoard.mixc(BG, LabBoard.NEXT if st == &"next" else LabBoard.mixc(LabBoard.NEXT, BG, 0.6), dep))
					_:
						if n % 3 == 0:
							px(p.x, p.y, LabBoard.mixc(BG, LabBoard.DOT, dep))
			# DATA on its way in, down every running stretch
			if st == &"owned" and pts.size() >= 6:
				for o2: float in [0.0, 0.5]:
					var t := fposmod(phase + o2 + 0.17 * b + 0.29 * kk, 1.0)
					var i := int((1.0 - t) * (pts.size() - 1))
					var hp: Vector2i = pts[i]
					px(hp.x, hp.y, LabBoard.mixc(BG, LabBoard.WHITE, dim))
					for j in [1, 2]:
						var tp: Vector2i = pts[mini(pts.size() - 1, i + j)]
						px(tp.x, tp.y, LabBoard.mixc(BG, LabBoard.HOT, dim * (0.8 if j == 1 else 0.45)))
	# THE STEPS, with the board's own rings, discs and halos (whole or not at
	# all: one behind the plate or a corner's words is not drawn)
	for b in 3:
		for kk in 3:
			var p: Vector2i = at[Vector2i(b, kk)]
			var st := _b_state(b, kk)
			var phi := float(LabBoard.PHI0[b]) + LabBoard.WIND * float(LabBoard.RHO[kk])
			var al := _b_depth(rot, phi) * dim
			if not box_free(Rect2i(p - Vector2i(r + 4, r + 4), Vector2i(2 * r + 9, 2 * r + 9))):
				continue
			var lp := fposmod(phase + 0.23 * b + 0.37 * kk, 1.0)
			match st:
				&"owned":
					var pr := r + 1 + roundi(3.0 * lp)
					bp._dither_ring(g, p.x, p.y, pr, pr + 1, LabBoard.mixc(BG, LabBoard.OWN_D if lp > 0.5 else LabBoard.OWN, al), 1.0 - lp)
					bp._disc(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.OWN, 0.2 * al))
					bp._ring(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.OWN, al))
					if r >= 5:
						bp._ring(g, p.x, p.y, r - 2, LabBoard.mixc(BG, LabBoard.OWN_D, al))
					g.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), LabBoard.mixc(BG, LabBoard.OWN, al))
				&"next":
					bp._dither_ring(g, p.x, p.y, r + 1, r + 3, LabBoard.mixc(BG, LabBoard.NEXT_D, al), 0.7 + 0.3 * sin(TAU * lp))
					bp._disc(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.NEXT, 0.2 * al))
					bp._ring(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.NEXT, al))
					bp._ring(g, p.x, p.y, r + 2, LabBoard.mixc(BG, LabBoard.NEXT, 0.6 * al), 6, lp / 6.0)
					g.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), LabBoard.mixc(BG, LabBoard.HOT, al))
				&"short":
					bp._disc(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.NEXT, 0.07 * al))
					bp._ring(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.mixc(LabBoard.NEXT, BG, 0.6), al))
					g.draw_rect(Rect2(p.x, p.y, 1, 1), LabBoard.mixc(BG, LabBoard.mixc(LabBoard.HOT, BG, 0.5), al))
				_:
					bp._disc(g, p.x, p.y, r, BG)
					bp._ring(g, p.x, p.y, r, LabBoard.mixc(BG, LabBoard.LATER_R, al), 8)
					g.draw_rect(Rect2(p.x, p.y, 1, 1), LabBoard.mixc(BG, LabBoard.LATER_I, al))
	# THE FLIGHT COMPUTER on the core: its ring, and a slot lit for every
	# routine running
	var n_owned := 0
	for b in 3:
		n_owned += clampi(Run.board_owned[b] if b < Run.board_owned.size() else 0, 0, 3)
	if box_free(Rect2i(cc - Vector2i(hub_r + 4, hub_r + 4), Vector2i(2 * hub_r + 9, 2 * hub_r + 9))):
		bp._dither_ring(g, cc.x, cc.y, hub_r + 1, hub_r + 3, LabBoard.mixc(BG, LabBoard.OWN_D, dim), 0.8 + 0.2 * sin(TAU * phase))
		bp._disc(g, cc.x, cc.y, hub_r, LabBoard.mixc(BG, LabBoard.OWN, 0.1 * dim))
		bp._ring(g, cc.x, cc.y, hub_r, LabBoard.mixc(BG, LabBoard.OWN, dim))
		bp._ring(g, cc.x, cc.y, hub_r - 2, LabBoard.mixc(BG, LabBoard.OWN_D, dim))
		for i in 9:
			var ang := deg_to_rad(90.0 - i * 40.0)
			var sx := roundi(cc.x + (hub_r - 4) * cos(ang))
			var sy := roundi(cc.y - (hub_r - 4) * sin(ang))
			g.draw_rect(Rect2(sx, sy, 1, 1), LabBoard.mixc(BG, LabBoard.OWN, dim if i < n_owned else 0.3 * dim))


# ================================================================== 1: the sky outside

func _sys() -> SystemLayout:
	if Run.map.is_empty():
		return null
	if _layout == null or _layout_at != Run.at:
		_layout_at = Run.at
		_layout = SystemLayout.of(Run.map[clampi(Run.at, 0, Run.map.size() - 1)])
	return _layout


func _paint_1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hv := hk(0.35)
	var r := (h - 6) / 2
	var sc := Vector2i(x0 + 3 + r, y0 + h / 2)
	var L := _sys()
	# THE SCOPE: its sky, the system in it, the crosshair
	_circ_c = sc
	_circ_r = r - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drift := tr * 0.6
	for i in (70 if h < 140 else 160):
		var sx := fposmod(rng.randf() * 400.0 - drift, 400.0)
		var sy := rng.randf() * float(2 * r)
		var q := Vector2i(int(sx) + sc.x - 200, int(sy) + sc.y - r)
		px(q.x, q.y, ink((0.12 + 0.3 * rng.randf()) * dim))
	var bodies: Array = []
	var om := 1.0
	if L != null:
		for b: SystemLayout.Body in L.bodies:
			if b.orbit > 0.0 and b.host_id < 0:
				bodies.append(b)
				om = maxf(om, b.orbit)
	var kp := float(r - 9) / om
	var tilt := 0.42
	var sun := Vector2(sc)
	# the worlds' paths, dotted
	for b: SystemLayout.Body in bodies:
		var rr := b.orbit * kp
		var n := maxi(24, int(rr * 2.2))
		for i in n:
			if i % 3 != 0:
				continue
			var an := float(i) / float(n) * TAU
			var q := Vector2i((sun + Vector2(cos(an) * rr, sin(an) * rr * tilt)).round())
			px(q.x, q.y, ink((0.22 if b.kind != &"belt" else 0.38) * dim))
	# where each world is now (sped up: a world goes round in 16-60 s)
	var pos: Array[Vector2i] = []
	var behind: Array[bool] = []
	for i in bodies.size():
		var b: SystemLayout.Body = bodies[i]
		var an := b.phase + tr * TAU / (16.0 + 9.0 * float(i))
		var rr := b.orbit * kp
		pos.append(Vector2i((sun + Vector2(cos(an) * rr, sin(an) * rr * tilt)).round()))
		behind.append(sin(an) < 0.0)
	# the worlds behind the star, the star, the worlds in front
	for pass_i in 2:
		if pass_i == 1:
			var sk := L.star if L != null else SystemLayout.StarKind.ORDINARY
			var col := LabBoard.HOT
			if int(sk) == 1:
				col = LabBoard.EMBER
			elif int(sk) == 2:
				col = LabBoard.ICE
			var bp := _painter()
			bp._dither_ring(g, sun.x, sun.y, 4, 9, LabBoard.mixc(LabBoard.BG, col, 0.45 * dim), 0.9 + 0.1 * sin(tr * 3.0))
			bp._disc(g, int(sun.x), int(sun.y), 3, LabBoard.mixc(LabBoard.BG, col, dim))
			g.draw_rect(Rect2(sun.x - 1, sun.y - 1, 2, 2), LabBoard.mixc(LabBoard.BG, LabBoard.WHITE, dim))
		for i in bodies.size():
			var b: SystemLayout.Body = bodies[i]
			if behind[i] != (pass_i == 0) or b.kind == &"belt":
				continue
			var p := pos[i]
			var big := (b.kind == &"planet" and b.r >= 9.0) or h >= 140
			if pass_i == 0 and (Vector2(p) - sun).length() < 5.0:
				continue
			var lit := ink((0.95 if pass_i == 1 else 0.7) * dim)
			if big:
				g.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), lit)
				px(p.x + 1, p.y + 1, ink(0.45 * dim))
			else:
				g.draw_rect(Rect2(p.x, p.y, 2, 2), lit)
	# THE CROSSHAIR steps from world to world (4 s each), and to the middle when
	# pointed at
	var tg: Array[int] = []
	for i in bodies.size():
		if (bodies[i] as SystemLayout.Body).kind != &"belt":
			tg.append(i)
	var aim := Vector2(sc)
	var cur := -1
	if not tg.is_empty():
		var slot := int(tr / 4.0)
		cur = tg[slot % tg.size()]
		var prv: int = tg[(slot + tg.size() - 1) % tg.size()]
		var e := smoothstep(0.0, 0.8, fposmod(tr, 4.0))
		aim = Vector2(pos[prv]).lerp(Vector2(pos[cur]), e)
	aim = aim.lerp(Vector2(sc), hv)
	var ai := Vector2i(aim.round())
	var ch := ink((0.32 + 0.3 * hv) * dim)
	for x in range(sc.x - r, sc.x + r + 1):
		if absi(x - ai.x) > 6 and posmod(x, 2) == 0:
			px(x, ai.y, ch)
	for y in range(sc.y - r, sc.y + r + 1):
		if absi(y - ai.y) > 6 and posmod(y, 2) == 0:
			px(ai.x, y, ch)
	var locked := tr - floorf(tr / 4.0) * 4.0 > 0.8 or hv > 0.0
	g._brackets(Rect2i(ai - Vector2i(5, 5), Vector2i(11, 11)), 3, ink((0.95 if locked else 0.55) * dim))
	_circ_r = -1
	# the scope's rim and its ticks
	var bpr := _painter()
	bpr._ring(g, sc.x, sc.y, r, ink(0.5 * dim))
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for j in 3:
			px(sc.x + d.x * (r - 1 - j), sc.y + d.y * (r - 1 - j), ink(0.6 * dim))
	# THE COLUMN: the owner, then the readings or the sign-in
	var cx0 := sc.x + r + 8
	var cw := x0 + w - 4 - cx0
	head(cx0, y0 + 2)
	var y := y0 + 18
	var big_glass := h >= 140
	var pitch := 9 if not big_glass else 12
	if g.state == LabLogin.LOGO:
		text(cx0, y, "TRACKING", ink(0.5))
		y += pitch
		var nm := "NO TARGET"
		if cur >= 0:
			nm = (bodies[cur] as SystemLayout.Body).name.to_upper()
			if nm == "":
				nm = "WORLD %d" % (cur + 1)
		text(cx0, y, fit(nm, cw), ink(0.95))
		y += pitch + 2
		var orb := 1.0
		if cur >= 0:
			orb = (bodies[cur] as SystemLayout.Body).orbit / om * 4.0 + 0.3
		var tick := floorf(tr * 4.0)
		var dist := orb + 0.01 * (noise(int(tick), 1) - 0.5)
		text(cx0, y, fit("DIST %.2f AU" % dist, cw), ink(0.7))
		y += pitch
		text(cx0, y, fit("TEMP %d K" % int(278.0 / sqrt(maxf(0.2, dist)) + 3.0 * noise(int(tick), 2)), cw), ink(0.7))
		y += pitch
		# the signal, bars stepping four times a second
		for i in 12:
			var bh := 1 + int(5.0 * noise(int(tick), 10 + i) * (0.4 + 0.6 * float(i % 5) / 4.0))
			g.draw_rect(Rect2(cx0 + i * 3, y + 6 - bh, 2, bh), ink(0.55))
		g.leaves.append(["signal", Rect2i(cx0, y, 36, 7)])
		# DATA logged, one more every 2.5 s, its +1 lit for a moment
		var n := 9 + int(tr / 2.5)
		var ly := a.end.y - 9
		var s := "LOGGED %d" % n
		text(cx0, ly, s, ink(0.6))
		if fposmod(tr, 2.5) < 0.6 and tr > 2.5:
			var plus := "+1 DATA" if LabBoard.tw(s) + 4 + LabBoard.tw("+1 DATA") <= cw else "+1"
			text(cx0 + LabBoard.tw(s) + 4, ly, plus, LabBoard.OWN)
	else:
		text(cx0, y, "OBSERVER", ink(0.5))
		y += pitch
		text(cx0, y, "PILOT", ink(0.75))
		y += pitch
		text(cx0, y, fit(ship(), cw), ink(1.0))
		y += pitch + 4
		if g.state == LabLogin.SIGNING:
			text(cx0, y, "SIGNING IN", ink(0.9))
		elif LabBoard.tw("CLICK TO SIGN IN") <= cw:
			text(cx0, y, "CLICK TO SIGN IN", cue())
		else:
			text(cx0, y, "CLICK TO", cue())
			text(cx0, y + pitch, "SIGN IN", cue())


# ================================================================== 2: specimen scan

const S2_TURN_S := 9.0
const S2_SWEEP := 2.4
const S2_GAP := 1.0


func _relic() -> Array:
	# a long crystal: two points, a six-sided waist, and a collar round it
	var v: Array[Vector3] = [Vector3(0, 1.05, 0), Vector3(0, -0.95, 0)]
	for i in 6:
		var an := float(i) / 6.0 * TAU
		v.append(Vector3(cos(an) * 0.42, 0.18, sin(an) * 0.42))
	for i in 12:
		var an := float(i) / 12.0 * TAU + 0.26
		v.append(Vector3(cos(an) * 0.66, -0.12, sin(an) * 0.66))
	var e: Array[Vector2i] = []
	for i in 6:
		e.append(Vector2i(0, 2 + i))
		e.append(Vector2i(1, 2 + i))
		e.append(Vector2i(2 + i, 2 + (i + 1) % 6))
	for i in 12:
		e.append(Vector2i(8 + i, 8 + (i + 1) % 12))
		if i % 2 == 0:
			e.append(Vector2i(8 + i, 2 + i / 2))
	return [v, e]


func _paint_2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hv := hk(0.35)
	var m := h - 8
	var box := Rect2i(x0 + 6, y0 + 4, m, m)
	var mc := Vector2(box.get_center())
	var s := float(m) * 0.4
	# THE SCAN: down the box in 2.4 s, then a beat; held in the middle, bright,
	# while pointed at
	var cyc := fposmod(tr, S2_SWEEP + S2_GAP)
	var scan_y := box.position.y + int(clampf(cyc / S2_SWEEP, 0.0, 1.0) * float(m))
	var scanning := cyc < S2_SWEEP
	if hv > 0.0:
		scan_y = int(lerpf(float(scan_y), mc.y, hv))
		scanning = true
	# the turntable under it
	var ty := int(mc.y + s * 1.08)
	for i in 40:
		var an := float(i) / 40.0 * TAU + _s2_spin
		var q := Vector2i((Vector2(mc.x, ty) + Vector2(cos(an) * s * 0.8, sin(an) * s * 0.18)).round())
		px(q.x, q.y, ink((0.45 if i % 5 == 0 else 0.18) * dim))
	# THE RELIC, its edges by depth: the far ones dim, those under the scan bright
	var rl := _relic()
	var verts: Array[Vector3] = []
	verts.assign(rl[0])
	var edges: Array[Vector2i] = []
	edges.assign(rl[1])
	var ry := _s2_spin
	var rx := 0.32
	var pts: Array[Vector2] = []
	var zs: Array[float] = []
	for v in verts:
		var p := Vector3(v.x * cos(ry) + v.z * sin(ry), v.y, -v.x * sin(ry) + v.z * cos(ry))
		p = Vector3(p.x, p.y * cos(rx) - p.z * sin(rx), p.y * sin(rx) + p.z * cos(rx))
		pts.append(mc + Vector2(p.x, -p.y) * s)
		zs.append(p.z)
	for e in edges:
		var za := (zs[e.x] + zs[e.y]) * 0.5
		var base := lerpf(0.3, 0.85, clampf((za + 0.7) / 1.4, 0.0, 1.0))
		_s2_edge(Vector2i(pts[e.x].round()), Vector2i(pts[e.y].round()), base * dim, scan_y, scanning)
	for i in pts.size():
		var q := Vector2i(pts[i].round())
		if zs[i] > -0.2:
			px(q.x, q.y, ink((0.7 + 0.3 * clampf(zs[i], 0.0, 1.0)) * dim))
	# the scan line itself, dotted, with bright ends
	if scanning:
		for x in range(box.position.x, box.end.x):
			if posmod(x, 2) == 0:
				px(x, scan_y, ink(0.3 * dim))
		for x in [box.position.x - 2, box.position.x - 1, box.end.x, box.end.x + 1]:
			px(x, scan_y, ink(0.95 * dim))
	g._brackets(box, 5, ink(0.45 * dim))
	# THE COLUMN
	var cx0 := box.end.x + 8
	var cw := x0 + w - 4 - cx0
	head(cx0, y0 + 2)
	var y := y0 + 18
	var pitch := 9 if h < 140 else 12
	if g.state == LabLogin.LOGO:
		text(cx0, y, "SPECIMEN", ink(0.5))
		y += pitch
		var code := "RELIC R-%03d" % (absi(hash(String(g.owner_id) + "relic")) % 900 + 100)
		text(cx0, y, fit(code, cw), ink(0.95))
		y += pitch + 2
		# THE SPECTRUM: bars stepping five times a second, held between sweeps
		var tick := int(floorf(tr * 5.0)) if scanning else int(floorf((tr - cyc) * 5.0))
		var bw := mini(cw, 60)
		var nb := bw / 4
		var bh := 20 if h < 140 else 30
		for i in nb:
			var shape := 0.35 + 0.65 * exp(-pow((float(i) - float(nb) * 0.62) / 2.6, 2.0)) + 0.4 * exp(-pow((float(i) - float(nb) * 0.2) / 1.5, 2.0))
			var hh := maxi(1, int(float(bh) * clampf(shape * (0.7 + 0.3 * noise(tick, i)), 0.0, 1.0)))
			g.draw_rect(Rect2(cx0 + i * 4, y + bh - hh, 3, hh), ink(0.75 if i % 4 != 2 else 0.95))
		g.leaves.append(["bar", Rect2i(cx0, y, nb * 4, bh)])
		y += bh + 4
		g.draw_rect(Rect2(cx0, y - 2, nb * 4 - 1, 1), ink(0.3))
		if scanning:
			text(cx0, y + 2, "SCANNING", ink(0.6))
		else:
			text(cx0, y + 2, fit("NO MATCH ON FILE", cw), ink(0.6))
	else:
		text(cx0, y, "HANDLER", ink(0.5))
		y += pitch
		text(cx0, y, "PILOT", ink(0.75))
		y += pitch
		text(cx0, y, fit(ship(), cw), ink(1.0))
		y += pitch + 4
		if g.state == LabLogin.SIGNING:
			text(cx0, y, "SIGNING IN", ink(0.9))
		elif LabBoard.tw("CLICK TO SIGN IN") <= cw:
			text(cx0, y, "CLICK TO SIGN IN", cue())
		else:
			text(cx0, y, "CLICK TO", cue())
			text(cx0, y + pitch, "SIGN IN", cue())


func _s2_edge(a: Vector2i, b: Vector2i, base: float, scan_y: int, scanning: bool) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		var k := base
		if scanning:
			var d := absi(p.y - scan_y)
			if d <= 1:
				k = 1.0
			elif d <= 3:
				k = maxf(base, 0.75)
			elif p.y > scan_y:
				k = base * 0.5
		px(p.x, p.y, ink(k))
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


# ================================================================== 3: research feed

const S3_EVERY := 2.6
const S3_SLIDE := 0.3
const S3_PILOTS := ["LOWTIDE", "GRIST", "HALFLIGHT", "SEVERN", "COPPER WREN", "BALLAST", "OXBOW"]
const S3_FINDS := [
	"FILM OF A RED DWARF. 9 DATA.",
	"COOLANT RUNS 4% COLDER AT IDLE.",
	"NEW ROUTINE ON FILE: QUIET RUNNING.",
	"SHIELD COIL TEST FAILED. RETRY.",
	"RELIC FROM A BELT. NOT A ROCK.",
	"AUGMENT ON A RAILGUN HELD.",
	"PULSAR READING SENT. 12 DATA.",
	"FUEL LINE FIX WORKS ON MEDIUM HULLS.",
	"DAMAGE CONTROL RUNS 2 S FASTER.",
	"SURVEY FILM FROM A GAS GIANT.",
]


func _s3_item(i: int) -> Array:
	var h := absi(hash(i * 7919 + 13))
	var src := ""
	if h % 3 == 0:
		src = "PILOT " + String(S3_PILOTS[(h / 3) % S3_PILOTS.size()])
	else:
		var ms: Array = DB.manufacturers.keys()
		var mid: StringName = g.owner_id if (h % 3 == 1 or ms.is_empty()) and g.owner_id != &"" else (ms[(h / 5) % ms.size()] as StringName)
		var nm := DB.short_name(DB.manufacturer_name(mid)).to_upper() if DB.manufacturers.has(mid) else "INDEPENDENT"
		src = "%s LAB %d" % [nm, 1 + (h / 11) % 9]
	return [src, String(S3_FINDS[i % S3_FINDS.size()])]


func _paint_3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var big := h >= 140
	# the header: the owner's net, LIVE blinking
	var hx := head(x0 + 4, y0 + 3, " RESEARCH NET")
	var live_on := int(floorf(tr / 0.6)) % 2 == 0
	var lw := LabBoard.tw("LIVE")
	if live_on:
		g.draw_rect(Rect2(a.end.x - 6 - lw - 6, y0 + 7, 3, 3), LabBoard.BAD)
	text(a.end.x - 6 - lw, y0 + 6, "LIVE", ink(0.6))
	# THE COUNTER: routines researched galaxy-wide, one more now and then, the
	# digit that changed lit for a moment
	var y := y0 + 18
	text(x0 + 6, y, "ROUTINES RESEARCHED, ALL LABS", ink(0.5))
	var base := 48213 + absi(hash(String(g.owner_id))) % 900
	var n := base
	var last_at := 0.0
	var t := 0.0
	var i := 0
	while true:
		var gap := 0.6 + 1.6 * noise(i, 77)
		if t + gap > tr:
			break
		t += gap
		last_at = t
		n += 1
		i += 1
	var ns := _thousands(n)
	var sz := 16
	var nx := x0 + 6
	var ny := y + 9
	var ink_n := ink(0.95)
	text(nx, ny, ns, ink_n, sz)
	if tr - last_at < 0.35 and i > 0:
		# the last digit, lit
		var head_s := ns.left(ns.length() - 1)
		LabBoard.text_at(g, nx + LabBoard.tw(head_s, sz), ny, ns.right(1), LabBoard.OWN, sz)
	var fy := ny + 15
	g.draw_rect(Rect2(x0 + 4, fy, w - 8, 1), ink(0.25))
	# THE FEED: two rows a finding, a new one in at the top every 2.6 s; held
	# while pointed at, and a row for you slid in on top
	var pitch := 17
	var top := fy + 4
	var hover := g.state != LabLogin.LOGO
	var ft := _s3_hold if (hover and _s3_hold >= 0.0) else tr
	var k := int(floorf(ft / S3_EVERY))
	var slide := 1.0 - clampf(fposmod(ft, S3_EVERY) / S3_SLIDE, 0.0, 1.0)
	if k == 0:
		slide = 0.0
	var hv := hk(0.3)
	var cw := w - 12
	var rows := (a.end.y - top) / pitch + 1
	for j in range(0, rows + 1):
		var yy := top + 3 + roundi((float(j) - slide) * float(pitch) + hv * float(pitch + 2))
		if yy - 1 < top or yy + 13 > a.end.y:
			continue
		var it := _s3_item(k - j)
		var last := yy + pitch + 13 > a.end.y
		var fr := 0.55 if last else 1.0
		var c2 := ink(0.85 * fr)
		if j == 0 and not hover and fposmod(ft, S3_EVERY) < 0.9 and k > 0:
			c2 = ink(1.0)
		text(x0 + 10, yy, fit(String(it[0]), cw - 4), ink(0.5 * fr))
		var stamp := "%02d:%02d" % [(8 + (k - j) / 20) % 24, posmod((k - j) * 7 + 12, 60)]
		var sw := LabBoard.tw(stamp)
		if LabBoard.tw(String(it[0])) + sw + 14 <= cw:
			text(a.end.x - 6 - sw, yy, stamp, ink(0.35 * fr))
		text(x0 + 10, yy + 7, fit(String(it[1]), cw - 4), c2)
		px(x0 + 6, yy + 2, ink(0.6 * fr))
	if hover:
		var yy := top + 3 + roundi((hv - 1.0) * float(pitch + 2))
		if yy - 3 >= top:
			var r := Rect2i(x0 + 4, yy - 3, w - 8, pitch)
			g.draw_rect(Rect2(r), LabBoard.BG)
			g._frame_box(r, ink(0.5))
			g.leaves.append(["plate", r])
			LabBoard.text_at(g, x0 + 10, yy, "THIS TERMINAL", ink(0.6))
			var s := "PILOT %s · CLICK TO SIGN IN" % ship()
			if say_w(s) > cw - 4:
				s = "PILOT %s · SIGN IN" % ship()
			if g.state == LabLogin.SIGNING:
				s = "PILOT %s · SIGNING IN" % ship()
			say(x0 + 10, yy + 7, s, ink(0.9) if g.state == LabLogin.SIGNING else cue(), 8, false)


var _s3_hold := -1.0


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


# ================================================================== 4: your ship

const S4_EACH := 2.2
const S4_SWEEP := 5.0


func _hull_art(target: Vector2i) -> Dictionary:
	if Run.hull == null:
		return {}
	var key := "%s|%s" % [Run.hull.resource_path + Run.hull.name, target]
	if _hull_cache.has(key):
		return _hull_cache[key]
	var tex: Texture2D = Run.hull.sprite
	if tex == null:
		return {}
	var img := tex.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var k := minf(float(target.x) / float(used.size.x), float(target.y) / float(used.size.y))
	var tw := int(float(used.size.x) * k)
	var th := int(float(used.size.y) * k)
	var mask := PackedByteArray()
	mask.resize(tw * th)
	var lum := PackedFloat32Array()
	lum.resize(tw * th)
	for y in th:
		for x in tw:
			var sx := used.position.x + mini(used.size.x - 1, int((float(x) + 0.5) / k))
			var sy := used.position.y + mini(used.size.y - 1, int((float(y) + 0.5) / k))
			var c := img.get_pixel(sx, sy)
			mask[y * tw + x] = 1 if c.a > 0.5 else 0
			lum[y * tw + x] = c.get_luminance()
	var edge := PackedByteArray()
	edge.resize(tw * th)
	var inner := PackedByteArray()
	inner.resize(tw * th)
	for y in th:
		for x in tw:
			if mask[y * tw + x] == 0:
				continue
			var e := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx := x + d.x
				var qy := y + d.y
				if qx < 0 or qy < 0 or qx >= tw or qy >= th or mask[qy * tw + qx] == 0:
					e = true
			edge[y * tw + x] = 1 if e else 0
			# the plating's own seams: a sharp step in brightness inside the hull
			if not e and x + 1 < tw and y + 1 < th:
				var l0 := lum[y * tw + x]
				if absf(l0 - lum[y * tw + x + 1]) > 0.16 or absf(l0 - lum[(y + 1) * tw + x]) > 0.16:
					inner[y * tw + x] = 1
	var out := {"w": tw, "h": th, "k": k, "used": used, "size": Vector2(img.get_size()), "mask": mask, "edge": edge, "inner": inner}
	_hull_cache[key] = out
	return out


func _paint_4() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	# header: the owner's FIT CHECK, the hull's name on the right
	head(x0 + 4, y0 + 3, " FIT CHECK")
	var hn := Run.hull.name.to_upper() if Run.hull != null else ""
	var hw := LabBoard.tw(hn)
	var hx_end := x0 + 4 + 14 + LabBoard.tw(g.owner_short() + " FIT CHECK")
	if hn != "" and a.end.x - 6 - hw > hx_end + 8:
		text(a.end.x - 6 - hw, y0 + 6, hn, ink(0.55))
	# the drawing's paper: a dot grid
	var body := Rect2i(x0 + 4, y0 + 17, w - 8, h - 17 - 22)
	for y in range(body.position.y, body.end.y, 6):
		for x in range(body.position.x, body.end.x, 6):
			px(x, y, ink(0.13 * dim))
	var art := _hull_art(Vector2i(body.size.x - 10, body.size.y - 4))
	if art.is_empty():
		return
	var tw: int = art.w
	var th: int = art.h
	var ox := body.position.x + (body.size.x - tw) / 2
	var oy := body.position.y + (body.size.y - th) / 2
	var edge: PackedByteArray = art.edge
	var inner: PackedByteArray = art.inner
	var mask: PackedByteArray = art.mask
	# THE HULL, a sweep running across it every 5 s
	var sweep := ox - 20 + int(fposmod(tr, S4_SWEEP) / S4_SWEEP * float(tw + 60))
	for y in th:
		for x in tw:
			var i := y * tw + x
			if mask[i] == 0:
				continue
			var d := absi(ox + x - sweep)
			var lift := 0.0 if d > 6 else (1.0 - float(d) / 6.0)
			if edge[i] == 1:
				px(ox + x, oy + y, ink((0.78 + 0.22 * lift) * dim))
			elif inner[i] == 1:
				px(ox + x, oy + y, ink((0.34 + 0.4 * lift) * dim))
			elif posmod(x + y, 4) == 0:
				px(ox + x, oy + y, ink((0.12 + 0.3 * lift) * dim))
	if absi(sweep - ox - tw / 2) < tw / 2 + 8:
		for y in range(oy - 3, oy + th + 3):
			if posmod(y, 2) == 0:
				px(sweep, y, ink(0.35 * dim))
	# THE FITTED PARTS, where the hull's mounts are
	var parts: Array = []
	var used: Rect2i = art.used
	var k: float = art.k
	var count := {}
	for m: ModuleData in Run.installed:
		count[m.slot] = int(count.get(m.slot, 0)) + 1
	var seen := {}
	var spots := {}
	for sl: int in count:
		spots[sl] = Run.hull.mounts_along(sl as ModuleData.Slot, int(count[sl]))
	for m: ModuleData in Run.installed:
		var j: int = int(seen.get(m.slot, 0))
		seen[m.slot] = j + 1
		var mp: PackedVector2Array = spots[m.slot]
		if j >= mp.size():
			continue
		var sp := mp[j] - Vector2(used.position)
		var p := Vector2i(ox + int(sp.x * k), oy + int(sp.y * k))
		parts.append([m, p])
	var cur := -1
	if not parts.is_empty():
		cur = int(floorf(tr / S4_EACH)) % parts.size()
	for i in parts.size():
		var m: ModuleData = parts[i][0]
		var p: Vector2i = parts[i][1]
		var on := hover or i == cur
		g.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), ink((1.0 if on else 0.55) * dim))
		if on:
			g._brackets(Rect2i(p - Vector2i(5, 5), Vector2i(11, 11)), 3, ink(0.95 * dim))
		# its augment slot: a diamond, filled once it is used
		var dp := p + Vector2i(5, -6)
		var dc := LabBoard.mixc(LabBoard.BG, LabBoard.OWN if m.augmented else g.tint, (0.95 if on else 0.5) * dim)
		for d: Vector2i in [Vector2i(0, -2), Vector2i(1, -1), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(-2, 0), Vector2i(-1, -1)]:
			px(dp.x + d.x, dp.y + d.y, dc)
		if m.augmented:
			px(dp.x, dp.y, dc)
	# THE CALLOUT ROW: the part in hand, its slot and its augment; or the sign-in
	var ly := a.end.y - 19
	g.draw_rect(Rect2(x0 + 4, ly - 3, w - 8, 1), ink(0.25))
	if not hover and cur >= 0:
		var m: ModuleData = parts[cur][0]
		var p: Vector2i = parts[cur][1]
		var nm := fit(m.name.to_upper(), w - 16)
		text(x0 + 8, ly, nm, ink(0.95))
		var slot_s := ["WEAPON", "SYSTEM", "UTILITY"][clampi(int(m.slot), 0, 2)] as String
		say(x0 + 8, ly + 8, "%s · %s" % [slot_s, "AUGMENTED" if m.augmented else "AUGMENT SLOT OPEN"], ink(0.55))
		# the leader from the part down to its name
		var lx := clampi(p.x, x0 + 8, x0 + 8 + LabBoard.tw(nm))
		line(Vector2i(p.x, p.y + 6), Vector2i(p.x, ly - 5), ink(0.4 * dim), 2)
		line(Vector2i(mini(p.x, lx), ly - 5), Vector2i(maxi(p.x, lx), ly - 5), ink(0.4 * dim), 2)
	elif hover:
		text(x0 + 8, ly, fit("YOUR SHIP", w - 16), ink(0.55))
		var s2 := "PILOT %s · SIGNING IN" % ship() if g.state == LabLogin.SIGNING else "PILOT %s · CLICK TO SIGN IN" % ship()
		if say_w(s2) > w - 16:
			s2 = "PILOT %s · SIGN IN" % ship()
		say(x0 + 8, ly + 8, s2, ink(0.9) if g.state == LabLogin.SIGNING else cue())


# ================================================================== 5: the owner's posters

const S5_EACH := 3.4
const S5_WIPE := 0.12


func _s5_cards() -> Array:
	var on := g.owner_short()
	return [
		["mark", on, "AUGMENT TODAY."],
		["big", "YOUR PARTS", "COULD DO MORE.", "ASK AT ANY %s LAB." % on],
		["big", "ONE AUGMENT", "PER PART.", "IT STAYS ON THE PART."],
		["big", "DATA IN.", "BETTER PARTS OUT.", "RESULTS VARY."],
		["big", "LIGHTENED PARTS", "TURN FASTER.", "+2 MAN, -1 HUL."],
	]


func _paint_5() -> void:
	var a := g.area()
	var tr := rest_t()
	var cards := _s5_cards()
	var hover := g.state != LabLogin.LOGO
	var idx := int(floorf(tr / S5_EACH)) % cards.size()
	var into := fposmod(tr, S5_EACH)
	var under: Array = cards[(idx + cards.size() - 1) % cards.size()]
	if hover:
		into = g._t
		under = cards[idx]
	var wipe := -1
	if into < S5_WIPE and (hover or tr > S5_EACH):
		wipe = a.position.y + int(into / S5_WIPE * float(a.size.y))
	# the new card above the wipe, the one before it under it
	var old := _clip
	if wipe >= 0:
		_clip = Rect2i(a.position.x, wipe, a.size.x, a.end.y - wipe)
		_s5_card(under, a, tr, false)
		_clip = Rect2i(a.position.x, a.position.y, a.size.x, wipe - a.position.y)
	if hover:
		_s5_hello(a)
	else:
		_s5_card(cards[idx], a, tr, true)
	_clip = old
	if wipe >= 0:
		g.draw_rect(Rect2(a.position.x, wipe, a.size.x, 1), ink(0.7))
		if wipe > a.position.y:
			g.draw_rect(Rect2(a.position.x, wipe - 1, a.size.x, 1), ink(0.3))
	# which card is up: a dot each, bottom right
	if not hover:
		for i in cards.size():
			var dx := a.end.x - 6 - (cards.size() - i) * 5
			g.draw_rect(Rect2(dx, a.end.y - 6, 3, 3) if i == idx else Rect2(dx + 1, a.end.y - 5, 1, 1), ink(0.9 if i == idx else 0.45))


## Words only where the clip has them whole (under a wipe they wait for it).
func _s5_text(x: int, y: int, s: String, c: Color, sz: int, leaf: bool) -> void:
	var cap := 5 if sz == 8 else 10
	var r := Rect2i(x, y - 2, LabBoard.tw(s, sz), cap + 4)
	if not _clip.encloses(r):
		return
	if leaf:
		text(x, y, s, c, sz)
	else:
		LabBoard.text_at(g, x, y, s, c, sz)


func _s5_card(cd: Array, a: Rect2i, tr: float, leaf: bool) -> void:
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	# THE OWNER'S BAR along the foot, in its own colour, a glint running down it
	var mk := DB.manufacturer_colour(g.owner_id) if DB.manufacturers.has(g.owner_id) else g.tint
	var by0 := a.end.y - 9
	var bx1 := a.end.x - 8 - 5 * 5 - 4
	var r_bar := Rect2i(x0 + 6, by0, bx1 - x0 - 6, 4)
	if _clip.encloses(r_bar):
		g.draw_rect(Rect2(x0 + 6, by0, bx1 - x0 - 6, 2), LabBoard.mixc(LabBoard.BG, mk, 0.85))
		g.draw_rect(Rect2(x0 + 6, by0 + 3, bx1 - x0 - 6, 1), ink(0.3))
		var gx := x0 + 6 + int(fposmod(tr * 45.0, float(bx1 - x0 + 80))) - 40
		for d in 8:
			var xx := gx + d
			if xx >= x0 + 6 and xx < bx1:
				g.draw_rect(Rect2(xx, by0, 1, 2), LabBoard.mixc(LabBoard.mixc(LabBoard.BG, mk, 0.85), LabBoard.WHITE, 0.6 - absf(float(d) - 3.5) * 0.12))
	if String(cd[0]) == "mark":
		var big := h >= 140
		var n := 45 if big else 33
		var s := 4.0 if big else 3.0
		var name := String(cd[1])
		var nsz := 16
		var tag := String(cd[2])
		var bw := n + 10 + maxi(LabBoard.tw(name, nsz), LabBoard.tw(tag))
		var bx := x0 + (w - bw) / 2
		var by := y0 + (h - 12 - n) / 2
		var r := Rect2i(bx - 1 - n / 2 + n / 2, by - 1, n + 2, n + 2)
		if _clip.encloses(r):
			g._mark(bx + n / 2, by + n / 2, n, s)
			# a glint runs over the mark now and then
			var gk := fposmod(tr, S5_EACH) / 1.2
			if gk < 1.0:
				var gx := bx + int(gk * float(n + n))
				for yy in n:
					for d in 2:
						var xx := gx - yy + d
						if xx >= bx and xx < bx + n:
							px(xx, by + yy, Color(1, 1, 1, 0.35))
		_s5_text(bx + n + 10, by + n / 2 - 12, name, ink(1.0), nsz, leaf)
		_s5_text(bx + n + 10, by + n / 2 + 4, tag, ink(0.75), 8, leaf)
		return
	var l1 := String(cd[1])
	var l2 := String(cd[2])
	var l3 := String(cd[3])
	var sz := 16 if LabBoard.tw(l2, 16) <= w - 16 and LabBoard.tw(l1, 16) <= w - 16 else 8
	var lh := 15 if sz == 16 else 9
	var block := lh * 2 + 8 + 5
	var by := y0 + (h - 12 - block) / 2
	_s5_text(x0 + (w - LabBoard.tw(l1, sz)) / 2, by, l1, ink(1.0), sz, leaf)
	_s5_text(x0 + (w - LabBoard.tw(l2, sz)) / 2, by + lh, l2, ink(1.0), sz, leaf)
	var l3s := fit(l3, w - 12)
	_s5_text(x0 + (w - LabBoard.tw(l3s)) / 2, by + lh * 2 + 7, l3s, ink(0.6), 8, leaf)
	# the owner's mark, small, top left on every card
	if _clip.encloses(Rect2i(x0 + 3, y0 + 3, 13, 13)):
		g._mark(x0 + 9, y0 + 9, 11, 1.0)


func _s5_hello(a: Rect2i) -> void:
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	if _clip.encloses(Rect2i(x0 + 3, y0 + 3, 13, 13)):
		g._mark(x0 + 9, y0 + 9, 11, 1.0)
	var l1 := "WELCOME BACK,"
	var l2 := "PILOT %s" % ship()
	var sz := 16 if LabBoard.tw(l2, 16) <= w - 16 else 8
	var lh := 15 if sz == 16 else 9
	var by := y0 + (h - (8 + lh + 10 + 5)) / 2
	_s5_text(x0 + (w - LabBoard.tw(l1)) / 2, by, l1, ink(0.6), 8, true)
	_s5_text(x0 + (w - LabBoard.tw(l2, sz)) / 2, by + 9, l2, ink(1.0), sz, true)
	var l3 := "SIGNING IN" if g.state == LabLogin.SIGNING else "CLICK TO SIGN IN"
	_s5_text(x0 + (w - LabBoard.tw(l3)) / 2, by + 9 + lh + 9, l3, ink(0.9) if g.state == LabLogin.SIGNING else cue(), 8, true)


# ================================================================== 6: the galaxy

const G_TURN_S := 50.0
const G_SQ := 0.42


func _paint_6() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	head(x0 + 4, y0 + 3)
	var gname := Run.galaxy_name.to_upper() if Run.galaxy_name != "" else "THIS GALAXY"
	var gw := LabBoard.tw(gname)
	var hx_end := x0 + 18 + LabBoard.tw(g.owner_short())
	if a.end.x - 6 - gw > hx_end + 8:
		text(a.end.x - 6 - gw, y0 + 6, gname, ink(0.55))
	var top := y0 + 16
	var bot := a.end.y - 13
	var R := minf(float(w) * 0.46, float(bot - top) / (2.0 * G_SQ))
	var c := Vector2(x0 + w / 2, (top + bot) / 2)
	var rot := _g_rot
	var arms := 4 if Run.galaxy_kind == 2 else 2
	# the plate's row at the foot, kept clear
	var lines := [["YOU ARE HERE", ink(0.6)], ["PILOT %s · SIGN IN" % ship(), cue()]]
	if g.state == LabLogin.SIGNING:
		lines = [["YOU ARE HERE", ink(0.6)], ["PILOT %s · SIGNING IN" % ship(), ink(0.9)]]
	var pl := Rect2i()
	if hover:
		var open := clampf(g._t / 0.15, 0.0, 1.0) if g.state == LabLogin.LOGIN else 1.0
		pl = plate(x0 + w / 2, 0, lines, open)
		pl.position.y = a.end.y - pl.size.y - 3
		# (on the far side of the disc from you, so it never hides what it names)
		if Run.at >= 0 and Run.at < Run.map.size():
			var sq0 := maxf(0.05, float(Run.galaxy.get("squash", 0.5)))
			var nd0: MapGen.MapNode = Run.map[Run.at]
			var q0 := Vector2(nd0.gal.x, nd0.gal.y / sq0).rotated(rot)
			if q0.y > 0.0:
				pl.position.y = top
		_keep.append(pl.grow(3))
	# THE DISC, in 2x2 blocks of three inks, the core a warm ball
	var dark := LabBoard.mixc(LabBoard.BG, g.tint, 0.2 * dim)
	var mid := LabBoard.mixc(LabBoard.BG, g.tint, 0.42 * dim)
	var lite := LabBoard.mixc(LabBoard.BG, g.tint, 0.7 * dim)
	var core_a := LabBoard.mixc(LabBoard.BG, LabBoard.HOT, 0.9 * dim)
	var core_b := LabBoard.mixc(LabBoard.BG, LabBoard.NEXT, 0.75 * dim)
	var beat := 0.5 + 0.5 * sin(tr * TAU / 1.6)
	var ry := R * G_SQ
	var gx0 := int(c.x - R) & ~1
	var gy0 := int(c.y - ry) & ~1
	for gy in range(gy0, int(c.y + ry) + 2, 2):
		for gx in range(gx0, int(c.x + R) + 2, 2):
			var u := (float(gx) + 1.0 - c.x) / R
			var v := (float(gy) + 1.0 - c.y) / ry
			var rr := sqrt(u * u + v * v)
			if rr > 1.0:
				continue
			var th := atan2(v, u) - rot
			var arm := pow(maxf(0.0, cos(float(arms) * (th + log(maxf(rr, 0.04)) * 2.1))), 2.0)
			var val := arm * smoothstep(1.0, 0.3, rr) * 0.95 + 0.14 * (1.0 - rr)
			var core := exp(-pow(rr / (0.2 + 0.03 * beat), 2.0))
			var col := Color(0, 0, 0, 0)
			if core > 0.55:
				col = core_a if core > 0.8 else core_b
			elif val + core > 0.62:
				col = lite
			elif val + core > 0.34:
				col = mid
			elif val + core > 0.16 or (val + core > 0.1 and LabBoard.bayer(gx / 2, gy / 2) < 0.5):
				col = dark
			if col.a > 0.0:
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					px(gx + d.x, gy + d.y, col)
	# THE SYSTEMS, the route, and you
	var sq := maxf(0.05, float(Run.galaxy.get("squash", 0.5)))
	var spots: Array[Vector2i] = []
	for nd: MapGen.MapNode in Run.map:
		var q := Vector2(nd.gal.x, nd.gal.y / sq).rotated(rot)
		spots.append(Vector2i((c + Vector2(q.x * R, q.y * ry) * 0.92).round()))
	var trail: Array[int] = []
	for ti in Run.trail:
		if ti >= 0 and ti < spots.size():
			trail.append(ti)
	for i in spots.size():
		var on_route := trail.has(i)
		var p := spots[i]
		px(p.x, p.y, ink((0.9 if on_route else 0.5) * dim))
	# the route: dashes marching along it; pointed at, a light runs it end to end
	var run_k := -1.0
	if hover:
		run_k = fposmod(g._t / 1.4, 1.0)
	var total := trail.size() - 1
	# (a dark line under it, so it reads over a bright arm)
	for i in total:
		line(spots[trail[i]] + Vector2i(0, 1), spots[trail[i + 1]] + Vector2i(0, 1), LabBoard.mixc(LabBoard.BG, Color.BLACK, 0.3))
	for i in total:
		var pa := spots[trail[i]]
		var pb := spots[trail[i + 1]]
		var lit := run_k >= 0.0 and float(i) / float(maxi(1, total)) <= run_k
		line(pa, pb, LabBoard.mixc(LabBoard.BG, LabBoard.HOT if lit else LabBoard.OWN, dim))
		if not lit:
			line(pa, pb, LabBoard.mixc(LabBoard.BG, LabBoard.WHITE, dim), 5, -int(tr * 8.0))
	for ti in trail:
		var q := spots[ti]
		g.draw_rect(Rect2(q.x, q.y, 2, 2), LabBoard.mixc(LabBoard.BG, LabBoard.ICE, dim))
	if run_k >= 0.0 and total > 0:
		var f := run_k * float(total)
		var si := mini(total - 1, int(f))
		var hp := Vector2(spots[trail[si]]).lerp(Vector2(spots[trail[si + 1]]), f - float(si))
		g.draw_rect(Rect2(Vector2i(hp.round()) - Vector2i(1, 1), Vector2(3, 3)), LabBoard.WHITE)
	if Run.at >= 0 and Run.at < spots.size():
		var me := spots[Run.at]
		var bl := int(floorf(tr / 0.5)) % 2 == 0 or hover
		var mc := LabBoard.mixc(LabBoard.BG, LabBoard.HOT, dim)
		if bl:
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				px(me.x + d.x, me.y + d.y, mc)
		var pr := 3 + int(fposmod(tr, 1.2) / 1.2 * 4.0)
		_painter()._dither_ring(g, me.x, me.y, pr, pr + 1, LabBoard.mixc(LabBoard.BG, LabBoard.HOT, 0.7 * dim), 1.0 - fposmod(tr, 1.2) / 1.2)
	# the foot: the run so far, or the plate
	if pl.has_area():
		plate_draw(pl, lines, pl.size.x >= say_w(String(lines[1][0])) + 8)
	else:
		text(x0 + 6, a.end.y - 8, "JUMPS %d" % Run.jumps, ink(0.6))
		var rs := "%d SYSTEMS ON YOUR ROUTE" % trail.size()
		if LabBoard.tw(rs) + LabBoard.tw("JUMPS 00") + 20 > w:
			rs = "ROUTE %d" % trail.size()
		text(a.end.x - 6 - LabBoard.tw(rs), a.end.y - 8, rs, ink(0.6))


# ================================================================== K: Korvan Heavy Works
# Three savers only Korvan runs (Nov 7, Jon: "Want more per owner."):
#   K1 PROOF RANGE: a test gun fires a round into a plate every 2.4 s, and the
#      count of rounds without a misfire (the posting board's 71,204) goes up
#   K2 SPEC CHECK: a stamped part on its jig, a gauge stepping bolt hole to
#      bolt hole against the old navy's sizes
#   K3 ACCOUNTS: the invoices sent to the navy stores, one a month for 201
#      years, a dot each, replayed year by year

## The owner's colour and its field, mixed into the glass's dark.
func _kc(a: float) -> Color:
	var mk := DB.manufacturer_colour(g.owner_id) if DB.manufacturers.has(g.owner_id) else g.tint
	return LabBoard.mixc(LabBoard.BG, mk, clampf(a, 0.0, 1.0))


func _kf(a: float) -> Color:
	var fd: Color = (DB.manufacturers[g.owner_id] as ManufacturerData).field if DB.manufacturers.has(g.owner_id) else g.tint.darkened(0.6)
	return LabBoard.mixc(LabBoard.BG, fd, clampf(a, 0.0, 1.0))


## The look's clock, held where the pointer came on (nothing new starts while
## the pilot is signing in).
func _k_hold() -> float:
	var tr := rest_t()
	return _s3_hold if (g.state != LabLogin.LOGO and _s3_hold >= 0.0) else tr


## The foot's two rows while pointed at: what the look is doing, and the cue.
func _k_sign(x: int, y: int, wmax: int, top: String) -> void:
	text(x, y, fit(top, wmax), ink(0.55))
	var signing := g.state == LabLogin.SIGNING
	var s := "PILOT %s · SIGNING IN" % ship() if signing else "PILOT %s · CLICK TO SIGN IN" % ship()
	if say_w(s) > wmax:
		s = "PILOT %s · SIGN IN" % ship() if not signing else "SIGNING IN"
	if say_w(s) > wmax:
		s = "SIGNING IN" if signing else "CLICK TO SIGN IN"
	say(x, y + 8, s, ink(0.9) if signing else cue())


## The header's right-hand words, when they fit beside the owner's.
func _k_right(a: Rect2i, extra: String, s: String) -> void:
	var hx_end := a.position.x + 4 + 14 + LabBoard.tw(g.owner_short() + extra)
	var sw := LabBoard.tw(s)
	if a.end.x - 6 - sw > hx_end + 8:
		text(a.end.x - 6 - sw, a.position.y + 6, s, ink(0.5))


# ------------------------------------------------------------------ K1: proof range

const K1_SHOT := 2.4
const K1_FIRST := 0.6
const K1_FLY := 0.3
## The posting board's number (PostingBoard.POSTS: DAYS WITHOUT A MISFIRE).
const K1_BASE := 71204
const K1_PER_PLATE := 8


func _k1_fired(t: float) -> int:
	if t < K1_FIRST:
		return 0
	return int(floorf((t - K1_FIRST) / K1_SHOT)) + 1


func _k1_hit_y(i: int, top: int, span: int) -> int:
	return top + 3 + absi(hash(i * 31 + 7)) % maxi(1, span - 6)


func _paint_k1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	head(x0 + 4, y0 + 3, " PROOF RANGE")
	_k_right(a, " PROOF RANGE", "NAVY PATTERN")
	# the round in hand: the last fired before the pointer came, and its age
	var n := _k1_fired(_k_hold())
	var u := tr - (K1_FIRST + float(n - 1) * K1_SHOT) if n > 0 else 99.0
	var hits := maxi(0, n if u >= K1_FLY else n - 1)
	# THE COUNT, one more each time a round lands clean
	var y := y0 + 19
	text(x0 + 6, y, fit("ROUNDS FIRED WITHOUT A MISFIRE", w - 12), ink(0.5))
	var ns := _thousands(K1_BASE + hits)
	var ny := y + 9
	text(x0 + 6, ny, ns, _kc(0.95), 16)
	if n > 0 and u >= K1_FLY and u < K1_FLY + 0.4:
		var head_s := ns.left(ns.length() - 1)
		LabBoard.text_at(g, x0 + 6 + LabBoard.tw(head_s, 16), ny, ns.right(1), LabBoard.WHITE, 16)
	# THE RANGE
	var ly0 := ny + 16
	var ly1 := a.end.y - 24
	var cy := (ly0 + ly1) / 2
	# (drawn at twice the size on a tall glass, so the range fills it)
	var q := 2 if ly1 - ly0 >= 60 else 1
	var half := clampi((ly1 - ly0) / 2 - 2, 6, 14 * q)
	var fy := cy + half
	line(Vector2i(x0 + 6, fy), Vector2i(a.end.x - 7, fy), ink(0.3 * dim), 2)
	# the gun: a stamped block on a foot plate, the owner's mark on its side,
	# a stepped cap bolted on top, kicking back as it fires
	var rec := 0
	if n > 0 and u < 0.2:
		rec = (2 if u < 0.07 else 1) * q
	var bw := 22 * q
	var bh := mini(14 * q, half * 2 - 4 * q)
	var bx := x0 + 9 - rec
	var by := fy - bh - q
	g.draw_rect(Rect2(bx - 3 * q, fy - q, bw + 6 * q, q), _kc(0.45 * dim))
	g.draw_rect(Rect2(bx, by, bw, bh), _kf(0.9 * dim))
	g.draw_rect(Rect2(bx + 3 * q, by - 3 * q, bw - 8 * q, 3 * q), _kf(0.9 * dim))
	g.draw_rect(Rect2(bx + 3 * q, by - 3 * q, bw - 8 * q, 1), _kc(0.85 * dim))
	g.draw_rect(Rect2(bx, by, bw, 1), _kc(0.85 * dim))
	g.draw_rect(Rect2(bx, by, 1, bh), _kc(0.6 * dim))
	g.draw_rect(Rect2(bx + bw - 1, by, 1, bh), _kc(0.4 * dim))
	g.draw_rect(Rect2(bx, by + bh - 1, bw, 1), _kc(0.3 * dim))
	for p: Vector2i in [Vector2i(2, 2), Vector2i(bw - 3, 2), Vector2i(2, bh - 3), Vector2i(bw - 3, bh - 3)]:
		g.draw_rect(Rect2(bx + p.x, by + p.y, q, q), _kc(0.75 * dim))
	if bh >= 13 * q and DB.manufacturers.has(g.owner_id):
		CardView.draw_emblem(g, g.owner_id, Vector2(bx + bw / 2.0, by + bh / 2.0), float(q), _kc(0.75 * dim), _kf(0.9 * dim))
	# the barrel, at the block's middle, a heavy collar at the muzzle
	var gy := by + bh / 2
	var mx0 := bx + bw
	var bl := maxi(24, w / 5)
	g.draw_rect(Rect2(mx0, gy - 2 * q, bl, 4 * q), _kc(0.5 * dim))
	g.draw_rect(Rect2(mx0, gy - 2 * q, bl, 1), _kc(0.8 * dim))
	g.draw_rect(Rect2(mx0 + 3 * q, gy - 3 * q, 3 * q, 6 * q), _kc(0.55 * dim))
	g.draw_rect(Rect2(mx0 + bl - 4 * q, gy - 3 * q, 4 * q, 6 * q), _kc(0.65 * dim))
	g.draw_rect(Rect2(mx0 + bl - 4 * q, gy - 3 * q, 4 * q, 1), _kc(0.9 * dim))
	var mz := mx0 + bl
	# the distance marks on the floor
	for tx in range(mz + 12, a.end.x - 28, 16):
		g.draw_rect(Rect2(tx, fy - 2, 1, 2), ink(0.35 * dim))
	# THE PLATE, a fresh one every eight rounds, each hit left on its face, in
	# a frame bolted to the floor
	var pwid := 6 * q
	var xt := a.end.x - 14 - pwid
	var ptop := fy - half * 2
	var span := half * 2
	g.draw_rect(Rect2(xt + pwid, ptop + 2 * q, 2 * q, span - 2 * q), _kc(0.3 * dim))
	g.draw_rect(Rect2(xt, ptop, pwid, span), _kf(0.95 * dim))
	g.draw_rect(Rect2(xt, ptop, q, span), _kc(0.85 * dim))
	g.draw_rect(Rect2(xt, ptop, pwid, 1), _kc(0.6 * dim))
	g.draw_rect(Rect2(xt - 3 * q, fy - 3 * q, pwid + 8 * q, q), _kc(0.45 * dim))
	g.draw_rect(Rect2(xt - 3 * q, fy - 3 * q, q, 3 * q), _kc(0.45 * dim))
	var first := ((hits - 1) / K1_PER_PLATE) * K1_PER_PLATE if hits > 0 else 0
	for i in range(first, hits):
		var hy := _k1_hit_y(i, ptop, span - 4 * q)
		g.draw_rect(Rect2(xt, hy, 2 * q, q), LabBoard.BG)
		g.draw_rect(Rect2(xt + 2 * q, hy, q, q), _kc(0.35 * dim))
	if n > 0:
		var hy := _k1_hit_y(n - 1, ptop, span - 4 * q)
		# the round in flight, a bright streak and its fading trail
		if u < K1_FLY:
			var k := u / K1_FLY
			var sx := mz + int(k * float(xt - mz))
			var sy := roundi(lerpf(float(gy), float(hy), k))
			for d in 4:
				g.draw_rect(Rect2(sx - d * q, sy, q, q), LabBoard.mixc(_kc(1.0), LabBoard.WHITE, 0.7 - 0.15 * float(d)))
			for d in range(5, 22, 2):
				px(sx - d, roundi(lerpf(float(gy), float(hy), maxf(0.0, k - float(d) / float(xt - mz)))), _kc(0.6 * (1.0 - float(d) / 22.0)))
		# the flash at the muzzle
		if u < 0.09:
			var hc := LabBoard.mixc(LabBoard.BG, LabBoard.HOT, 1.0 - u / 0.09)
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(3, 0)]:
				g.draw_rect(Rect2(mz + d.x * q, gy + d.y * q, q, q), hc)
		# the hit: the face lit, a few sparks back off it
		if u >= K1_FLY and u < K1_FLY + 0.35:
			var e := (u - K1_FLY) / 0.35
			if e < 0.25:
				g.draw_rect(Rect2(xt, hy - q, q, 3 * q), LabBoard.WHITE)
			for s in 5:
				var ang := PI + (noise(n, s) - 0.5) * 1.6
				var rr := e * (5.0 + 7.0 * noise(s, n))
				px(xt - 1 + roundi(cos(ang) * rr), hy + roundi(sin(ang) * rr), LabBoard.mixc(LabBoard.BG, LabBoard.HOT, 1.0 - e))
	# THE LOG ROW: the last round, or the sign-in
	var ry := a.end.y - 19
	g.draw_rect(Rect2(x0 + 4, ry - 3, w - 8, 1), ink(0.25))
	if hover:
		_k_sign(x0 + 8, ry, w - 16, "RANGE CLEAR. GUN SAFE.")
	elif n > 0:
		var st := "FIRED" if u < K1_FLY else "CLEAN"
		say(x0 + 8, ry, fit("ROUND %s · %s" % [_thousands(K1_BASE + n), st], w - 16), ink(0.9))
		text(x0 + 8, ry + 8, fit("STANDARD ISSUE SLUG, FROM STOCK", w - 16), ink(0.5))
	else:
		text(x0 + 8, ry, fit("RANGE READY", w - 16), ink(0.9))


# ------------------------------------------------------------------ K2: spec check

## Part number, name, width and height (mm), the hole size (mm), its body as
## rects (x, y, w, h in shares of the part), and its holes (x, y in shares).
const K2_PARTS := [
	["4471-B", "HULL PLATE", 900, 420, 16, [[0.0, 0.0, 1.0, 1.0]],
		[[0.07, 0.18], [0.07, 0.82], [0.5, 0.18], [0.5, 0.82], [0.93, 0.18], [0.93, 0.82]]],
	["6602-C", "ARMOUR SLAB SET", 800, 460, 20, [[0.0, 0.0, 1.0, 0.26], [0.12, 0.37, 0.76, 0.26], [0.24, 0.74, 0.52, 0.26]],
		[[0.05, 0.13], [0.95, 0.13], [0.17, 0.5], [0.83, 0.5], [0.29, 0.87], [0.71, 0.87]]],
	["0930-A", "MOUNT BRACKET", 700, 440, 12, [[0.0, 0.0, 0.3, 1.0], [0.3, 0.6, 0.7, 0.4]],
		[[0.15, 0.13], [0.15, 0.45], [0.15, 0.82], [0.55, 0.8], [0.88, 0.8]]],
	["2210-K", "BREECH BLOCK", 600, 380, 16, [[0.0, 0.28, 1.0, 0.72], [0.0, 0.0, 0.58, 0.28]],
		[[0.1, 0.13], [0.46, 0.13], [0.1, 0.84], [0.62, 0.84], [0.9, 0.5]]],
]
const K2_LEAD := 0.6
const K2_HOLE := 0.9
const K2_MOVE := 0.3
const K2_DONE := 1.8


func _k2_len(i: int) -> float:
	return K2_LEAD + float((K2_PARTS[i][6] as Array).size()) * K2_HOLE + K2_DONE


func _paint_k2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	head(x0 + 4, y0 + 3, " SPEC CHECK")
	_k_right(a, " SPEC CHECK", "OLD NAVY SIZES")
	# which part is on the jig, and how far along its check
	var t := _k_hold()
	var cyc := 0.0
	for i in K2_PARTS.size():
		cyc += _k2_len(i)
	var ph := fposmod(t + _k2_len(0), cyc)
	var pi_ := 0
	while ph >= _k2_len(pi_):
		ph -= _k2_len(pi_)
		pi_ += 1
	var part: Array = K2_PARTS[pi_]
	var holes: Array = part[6]
	var nh := holes.size()
	var come := clampf(ph / 0.35, 0.0, 1.0) if not hover else 1.0
	var dk := dim * come
	# THE DRAWING'S ROOM: a width line above, a height line at the right
	var room := Rect2i(x0 + 12, y0 + 30, w - 12 - 30, a.end.y - 26 - (y0 + 30))
	var wmm: int = part[2]
	var hmm: int = part[3]
	var k := minf(float(room.size.x) / float(wmm), float(room.size.y) / float(hmm))
	var pw := int(float(wmm) * k)
	var phh := int(float(hmm) * k)
	var ox := room.position.x + (room.size.x - pw) / 2
	var oy := room.position.y + (room.size.y - phh) / 2
	# the jig under it: a dotted rest line and two stops
	line(Vector2i(ox - 6, oy + phh + 2), Vector2i(ox + pw + 5, oy + phh + 2), ink(0.3 * dim), 2)
	g.draw_rect(Rect2(ox - 4, oy + phh - 4, 2, 6), ink(0.35 * dim))
	g.draw_rect(Rect2(ox + pw + 2, oy + phh - 4, 2, 6), ink(0.35 * dim))
	# THE PART: stamped plate in the owner's rust, lit along its top and left
	var rs: Array[Rect2i] = []
	for r: Array in part[5]:
		rs.append(Rect2i(ox + int(float(r[0]) * pw), oy + int(float(r[1]) * phh),
			maxi(2, int(float(r[2]) * pw)), maxi(2, int(float(r[3]) * phh))))
	for r in rs:
		g.draw_rect(Rect2(r), _kf(0.72 * dk))
		# rivets along its long edges
		if r.size.y >= 9:
			for rx in range(r.position.x + 4, r.end.x - 3, 7):
				px(rx, r.position.y + 2, _kc(0.5 * dk))
				px(rx, r.end.y - 3, _kc(0.5 * dk))
	for r in rs:
		g.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), _kc(0.85 * dk))
		g.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), _kc(0.7 * dk))
		g.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), _kc(0.35 * dk))
		g.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), _kc(0.35 * dk))
	# the stencilled number on its biggest face
	var big := rs[0]
	for r in rs:
		if r.size.x * r.size.y > big.size.x * big.size.y:
			big = r
	var sten := "NAVY %s" % String(part[0])
	if LabBoard.tw(sten) + 8 <= big.size.x and big.size.y >= 13:
		var sc := LabBoard.mixc(_kf(0.72 * dk), LabBoard.BG, 0.75 * dk)
		var sx := big.position.x + (big.size.x - LabBoard.tw(sten)) / 2
		var sy := big.position.y + (big.size.y - 5) / 2
		LabBoard.text_at(g, sx, sy, sten, sc)
	# the dimension lines
	var dy := oy - 6
	var ws := "%d" % wmm
	var lw := LabBoard.tw(ws)
	var lx := ox + (pw - lw) / 2
	line(Vector2i(ox, dy), Vector2i(lx - 3, dy), ink(0.4 * dim))
	line(Vector2i(lx + lw + 2, dy), Vector2i(ox + pw - 1, dy), ink(0.4 * dim))
	g.draw_rect(Rect2(ox, dy - 2, 1, 5), ink(0.4 * dim))
	g.draw_rect(Rect2(ox + pw - 1, dy - 2, 1, 5), ink(0.4 * dim))
	text(lx, dy - 2, ws, ink(0.55))
	var dx := ox + pw + 7
	var hs := "%d" % hmm
	line(Vector2i(dx, oy), Vector2i(dx, oy + phh - 1), ink(0.4 * dim))
	g.draw_rect(Rect2(dx - 2, oy, 5, 1), ink(0.4 * dim))
	g.draw_rect(Rect2(dx - 2, oy + phh - 1, 5, 1), ink(0.4 * dim))
	if dx + 3 + LabBoard.tw(hs) <= a.end.x - 3:
		text(dx + 3, oy + phh / 2 - 2, hs, ink(0.55))
	# THE HOLES, and the gauge stepping from one to the next
	var spots: Array[Vector2i] = []
	for hp: Array in holes:
		spots.append(Vector2i(ox + int(float(hp[0]) * pw), oy + int(float(hp[1]) * phh)))
	var into := ph - K2_LEAD
	var cur := clampi(int(floorf(into / K2_HOLE)), -1, nh)
	var checked := clampi(cur if fposmod(into, K2_HOLE) < K2_MOVE else cur + 1, 0, nh)
	if into < 0.0:
		checked = 0
	for j in nh:
		var p := spots[j]
		g.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), LabBoard.BG)
		px(p.x + 1, p.y + 1, _kc(0.45 * dk))
		if j < checked:
			px(p.x, p.y, LabBoard.mixc(LabBoard.BG, LabBoard.ICE, dk))
	var pp := Vector2(ox + pw / 2, oy + phh / 2)
	if into >= 0.0 and cur < nh:
		var s := fposmod(into, K2_HOLE)
		var from := Vector2(spots[cur - 1]) if cur > 0 else pp
		var e := clampf(s / K2_MOVE, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		pp = from.lerp(Vector2(spots[cur]), e)
	elif cur >= nh:
		pp = Vector2(spots[nh - 1])
	var pq := Vector2i(pp.round())
	if into < float(nh) * K2_HOLE + 0.4:
		line(Vector2i(ox - 4, pq.y), Vector2i(ox + pw + 3, pq.y), ink(0.3 * dk), 2)
		line(Vector2i(pq.x, oy - 2), Vector2i(pq.x, oy + phh + 1), ink(0.3 * dk), 2)
		g._brackets(Rect2i(pq - Vector2i(4, 4), Vector2i(9, 9)), 3, ink(0.95 * dk))
	# THE READING ROW: the part, and the hole in hand (or the sign-in)
	var ry := a.end.y - 19
	g.draw_rect(Rect2(x0 + 4, ry - 3, w - 8, 1), ink(0.25))
	if hover:
		_k_sign(x0 + 8, ry, w - 16, "NAVY PART %s, HELD" % String(part[0]))
		return
	say(x0 + 8, ry, fit("NAVY PART %s · %s" % [String(part[0]), String(part[1])], w - 16), ink(0.9))
	var hmm_d: int = part[4]
	var r2 := ""
	var c2 := ink(0.6)
	if into < 0.0:
		r2 = "ON THE JIG"
	elif cur >= nh:
		r2 = "ALL %d HOLES TO SPEC" % nh
		c2 = _kc(1.0)
	elif cur >= 0:
		var got := float(hmm_d) + (noise(pi_ * 17 + cur, 5) - 0.5) * 0.04
		r2 = "HOLE %d OF %d · %.2f MM · SPEC %d.00" % [cur + 1, nh, got, hmm_d]
		if say_w(r2) > w - 16:
			r2 = "HOLE %d OF %d · %.2f MM" % [cur + 1, nh, got]
	say(x0 + 8, ry + 8, fit(r2, w - 16), c2)


# ------------------------------------------------------------------ K3: accounts

const K3_YEARS := 201
const K3_YEAR_S := 0.1
const K3_HOLD := 6.0
## Years already drawn when the screen comes on, so it opens mostly full.
const K3_START := 150


func _paint_k3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	head(x0 + 4, y0 + 3, " ACCOUNTS")
	_k_right(a, " ACCOUNTS", "ON SCHEDULE")
	# the replay's clock: a year every 0.1 s, then six seconds full
	var cyc := float(K3_YEARS) * K3_YEAR_S + K3_HOLD
	var ph := fposmod(_k_hold() + float(K3_START) * K3_YEAR_S, cyc)
	var full := ph >= float(K3_YEARS) * K3_YEAR_S
	var months := K3_YEARS * 12 if full else int(ph / K3_YEAR_S * 12.0)
	var yr := mini(K3_YEARS, months / 12 + 1)
	text(x0 + 6, y0 + 19, fit("TO: NAVY STORES, OUTER YARD", w - 12), ink(0.85))
	var ss := "SENT %s · REPLIES 0" % _thousands(months)
	say(x0 + 6, y0 + 28, ss, ink(0.55))
	var ys := "YEAR %d" % yr
	if LabBoard.tw(ys) + say_w(ss) + 24 <= w:
		text(a.end.x - 6 - LabBoard.tw(ys), y0 + 28, ys, ink(0.55))
	# THE YEARS, as ledger lines (critic pass, Nov 7: the solid squares read as
	# a keypad): a month is a pixel, a year twelve of them and a gap, the rows
	# filling like lines in an account book
	var top := y0 + 38
	var bot := a.end.y - 26
	var yw := 13
	var per_row := maxi(1, (w - 12) / yw)
	var rows := (K3_YEARS + per_row - 1) / per_row
	var lh := 1
	var pitch := 3
	if rows * 5 <= bot - top:
		lh = 2
		pitch = 5
	if rows * 7 <= bot - top:
		pitch = 7
	var gw := per_row * yw - 1
	var gh := rows * pitch - (pitch - lh)
	var gx := x0 + (w - gw) / 2
	var gy := top + maxi(0, (bot - top - gh) / 2)
	var newest := months - 1
	var blink := int(floorf(rest_t() / 0.5)) % 2 == 0
	for yi in K3_YEARS:
		var bx := gx + (yi % per_row) * yw
		var by := gy + (yi / per_row) * pitch
		for m in 12:
			var mi := yi * 12 + m
			var c := ink(0.1 * dim)
			if mi < months:
				c = _kc((0.75 if yi == yr - 1 and not full else 0.45) * dim)
				if mi == newest and (not full or blink):
					c = LabBoard.mixc(LabBoard.BG, LabBoard.WHITE, dim)
			g.draw_rect(Rect2(bx + m, by, 1, lh), c)
	# THE FOOT: what a dot is, or the sign-in
	var ry := a.end.y - 19
	g.draw_rect(Rect2(x0 + 4, ry - 3, w - 8, 1), ink(0.25))
	if hover:
		_k_sign(x0 + 8, ry, w - 16, "ACCOUNTS, PAUSED")
		return
	text(x0 + 8, ry, fit("ONE DASH IS ONE YEAR, 12 INVOICES.", w - 16), ink(0.55))
	text(x0 + 8, ry + 8, fit("NONE LATE IN %d YEARS." % yr, w - 16), _kc(0.95))


# ================================================================== P: the Probate Combine's own
#
# MOCK (r6 owners, Nov 7): three savers only a Probate Lab runs. Jon: "Love
# these. Want more per owner." The Combine follows other people's wrecks and
# files the claim first; scrap is paid on the weight.
#
#   P1  WRECK WATCH: ships cross the Combine's watch; one slows, stops and goes
#       quiet, and the Combine files its claim on it
#   P2  CLAIM FILING: a claim of salvage typed out line by line, then stamped
#   P3  SALVAGE ASSAY: a piece of a wreck towed onto the scale, weighed, its
#       metal split by share, and paid on the weight

const P_BRASS := Color("#b3924e")
const P_BRONZE := Color("#8a6f3a")
const P_STEEL := Color("#8c949b")
## Ships that had names before the Combine filed on them.
const P_NAMES := ["MERIDIAN", "KESTREL", "SLOW HARVEST", "DUNMORE", "ALDER", "TALLOW",
	"QUIET HAND", "HOLLIS", "GREYLAG", "WINTERSET", "MARROW", "FAIR LANTERN"]

var _p_k := 1.0
var _p_lag := 0.0


## The Combine's savers' clock: the lab's, less what a hover held back.
func _p_t() -> float:
	return maxf(0.0, rest_t() - _p_lag)


func pc(c: Color, a: float) -> Color:
	return LabBoard.mixc(LabBoard.BG, c, clampf(a, 0.0, 1.0))


func _p_claim(k: int) -> String:
	return "C-%04d" % (2280 + posmod(k, 7000))


func _p_name(k: int) -> String:
	return String(P_NAMES[posmod(k * 5 + 3, P_NAMES.size())])


## The sign-in, as a column of words (the ones savers 1 and 2 use).
func _p_signin(x: int, y: int, cw: int, pitch: int, label: String) -> void:
	text(x, y, label, ink(0.5))
	y += pitch
	text(x, y, "PILOT", ink(0.75))
	y += pitch
	text(x, y, fit(ship(), cw), ink(1.0))
	y += pitch + 4
	if g.state == LabLogin.SIGNING:
		text(x, y, "SIGNING IN", ink(0.9))
	elif LabBoard.tw("CLICK TO SIGN IN") <= cw:
		text(x, y, "CLICK TO SIGN IN", cue())
	else:
		text(x, y, "CLICK TO", cue())
		text(x, y + pitch, "SIGN IN", cue())


# ------------------------------------------------------------------ P1: wreck watch

const P1_N := 7
## A ship stops every 5.5 s, the first a second after the screen comes up.
const P1_E := 5.5
const P1_M := 14.0
const P1_D := 1.4
const P1_FIRST := 1.0
## The next to stop is tracked this long before it starts to slow.
const P1_LEAD := 1.8
## Its claim is filed this long after it is still.
const P1_FILE := 0.3
const P1_TRAFFIC := 4


## Ship `s` of the watch at `t`: where it is (0..1 of the plot), its state
## (0 moving, 1 slowing, 2 still), its speed now and at cruise, its alpha, and
## the number of its stop.
func _p1_ship(s: int, t: float) -> Dictionary:
	var P := float(P1_N) * P1_E
	var raw := t - (P1_FIRST + float(s) * P1_E - P1_M)
	var gen := floori(raw / P)
	var tau := raw - float(gen) * P
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector2i(s * 31 + 7, gen)))
	var p0 := Vector2(rng.randf(), rng.randf())
	var an := rng.randf() * TAU
	var sp := 0.010 + 0.010 * rng.randf()
	var dist := 0.0
	var st := 0
	var v := sp
	if tau < P1_M:
		dist = sp * tau
	elif tau < P1_M + P1_D:
		var u := (tau - P1_M) / P1_D
		dist = sp * (P1_M + P1_D * (u - u * u / 2.0))
		v = sp * (1.0 - u)
		st = 1
	else:
		dist = sp * (P1_M + P1_D / 2.0)
		v = 0.0
		st = 2
	var dir := Vector2(cos(an), sin(an))
	var p := p0 + dir * dist
	var al := 1.0
	if tau > P - 2.0:
		al = clampf((P - tau) / 2.0, 0.0, 1.0)
	elif tau < 1.0:
		al = clampf(tau, 0.0, 1.0)
	return {"p": Vector2(fposmod(p.x, 1.0), fposmod(p.y, 1.0)), "st": st, "v": v, "sp": sp,
		"dir": dir, "al": al, "tau": tau, "k": gen * P1_N + s}


func _p1_at(inner: Rect2i, p: Vector2) -> Vector2i:
	return inner.position + Vector2i((p * Vector2(inner.size - Vector2i.ONE)).round())


func _p1_dot(q: Vector2i, dir: Vector2, k: float, c: Color, tail: int) -> void:
	for i in tail:
		var b := Vector2i((Vector2(q) - dir * float(2 + i * 2) * k).round())
		px(b.x, b.y, LabBoard.mixc(LabBoard.BG, c, 0.45 - 0.12 * float(i)))
	if box_free(Rect2i(q, Vector2i(2, 2))):
		g.draw_rect(Rect2(q.x, q.y, 2, 2), c)


func _paint_p1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := _p_t()
	var dim := fade()
	var big := h >= 140
	var hover := g.state != LabLogin.LOGO
	head(x0 + 4, y0 + 3, " WRECK WATCH")
	var colw := clampi(int(float(w) * 0.36), 94, 150)
	var plot := Rect2i(x0 + 4, y0 + 18, w - 8 - colw - 8, h - 18 - 4)
	var cx0 := plot.end.x + 8
	# THE WATCH: a dot grid, a few stars, its corners
	for yy in range(plot.position.y + 6, plot.end.y - 2, 12):
		for xx in range(plot.position.x + 6, plot.end.x - 2, 12):
			px(xx, yy, ink(0.13 * dim))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in (60 if big else 28):
		var q := plot.position + Vector2i(rng.randi_range(2, plot.size.x - 3), rng.randi_range(2, plot.size.y - 3))
		px(q.x, q.y, ink((0.08 + 0.2 * rng.randf()) * dim))
	g._brackets(plot, 5, ink(0.4 * dim))
	var inner := plot.grow(-8)
	# the station this lab is on, in the middle, and two range rings round it
	var mid := plot.get_center()
	var bpr := _painter()
	for rr: int in [mini(plot.size.x, plot.size.y) / 4, mini(plot.size.x, plot.size.y) * 2 / 5]:
		bpr._ring(g, mid.x, mid.y, rr, ink(0.16 * dim), 24)
	bpr._ring(g, mid.x, mid.y, 3, pc(P_BRASS, 0.8 * dim))
	px(mid.x, mid.y, pc(P_BRASS, dim))
	# TRAFFIC that only passes through
	for i in P1_TRAFFIC:
		var r2 := RandomNumberGenerator.new()
		r2.seed = 300 + i
		var p0 := Vector2(r2.randf(), r2.randf())
		var an := r2.randf() * TAU
		var dir := Vector2(cos(an), sin(an))
		var p := p0 + dir * (0.012 + 0.01 * r2.randf()) * t
		var q := _p1_at(inner, Vector2(fposmod(p.x, 1.0), fposmod(p.y, 1.0)))
		_p1_dot(q, dir, 1.0, ink(0.5 * dim), 2)
	# THE SHIPS THE COMBINE IS WATCHING: moving, slowing, still and claimed
	var c := floori((t - P1_FIRST + P1_LEAD) / P1_E)
	var cur_s := posmod(c, P1_N)
	var cur: Dictionary = {}
	for s in P1_N:
		var d := _p1_ship(s, t)
		var q := _p1_at(inner, d.p)
		var al: float = float(d.al) * dim
		if s == cur_s:
			cur = d
			cur["q"] = q
		match int(d.st):
			0:
				# its course ahead, dotted
				for j in 5:
					var f := Vector2i((Vector2(q) + d.dir * float(5 + j * 3)).round())
					px(f.x, f.y, ink(0.22 * al))
				_p1_dot(q, d.dir, 1.0, ink(1.0 * al), 3)
			1:
				var k := float(d.v) / float(d.sp)
				_p1_dot(q, d.dir, k, ink((0.5 + 0.35 * k) * al), 3 if k > 0.3 else 1)
			_:
				# still: a cold wreck in steel, one pixel of it dark, and once
				# filed on, the Combine's flag on it
				g.draw_rect(Rect2(q.x, q.y, 2, 2), pc(P_STEEL, 0.9 * al))
				px(q.x + 1, q.y + 1, pc(P_STEEL, 0.35 * al))
				if float(d.tau) >= P1_M + P1_D + P1_FILE:
					var fc := pc(P_BRASS, 0.95 * al)
					for j in 4:
						px(q.x + 2, q.y - 1 - j, fc)
					px(q.x + 3, q.y - 4, fc)
					px(q.x + 4, q.y - 4, fc)
					px(q.x + 3, q.y - 3, fc)
	# the one tracked now, bracketed (in brass once it is filed on)
	var claimed := not cur.is_empty() and int(cur.st) == 2 and float(cur.tau) >= P1_M + P1_D + P1_FILE
	if not cur.is_empty():
		var q: Vector2i = cur.q
		g._brackets(Rect2i(q - Vector2i(4, 4), Vector2i(10, 10)), 3, pc(P_BRASS, dim) if claimed else ink(0.95 * dim))
	# THE COLUMN: the ship tracked, its speed falling, and the claim; or the sign-in
	var pitch := 12 if big else 9
	var y := y0 + 20
	if hover:
		_p_signin(cx0, y, colw, pitch, "CLAIMANT")
		return
	text(cx0, y, "TRACKING", ink(0.5))
	y += pitch
	var nm := fit(_p_name(c), colw)
	if claimed:
		text(cx0, y, nm, ink(0.45))
		g.draw_rect(Rect2(cx0 - 1, y + 2, LabBoard.tw(nm) + 2, 1), ink(0.75))
	else:
		text(cx0, y, nm, ink(0.95))
	y += pitch
	var sp := "NO SIGNAL" if claimed else "%.1f KM/S" % (float(cur.get("v", 0.0)) * 400.0)
	text(cx0, y, sp, ink(0.6 if claimed else 0.75))
	y += pitch + 5
	if claimed:
		text(cx0, y, "CLAIM FILED", pc(P_BRASS, 0.8))
		y += pitch
		text(cx0, y, _p_claim(c), pc(P_BRASS, 1.0), 16 if big else 8)
	# claims on file, one more each stop
	var filed := 18402 + maxi(0, c - (0 if claimed else 1))
	text(cx0, a.end.y - 9 - pitch, "ON FILE", ink(0.45))
	text(cx0, a.end.y - 9, _thousands(filed), ink(0.7))


# ------------------------------------------------------------------ P2: claim filing

const P2_CYC := 7.0
const P2_TYPE_CPS := 32.0
const P2_STAMP := 2.7
const P2_LABELS := ["ITEM", "ONCE NAMED", "FOUND AT", "STATE", "FILED"]
const P2_ITEMS := ["MEDIUM HULL", "DRIVE SECTION", "CARGO POD", "LIGHT HULL", "REACTOR SHELL", "HEAVY HULL"]
const P2_STATES := ["NO POWER, NO CREW", "DRIVE COLD, HULL OPEN", "SEALED, NO SIGNAL", "BURNED OUT, NO CREW", "DRIFTING, NO SIGNAL"]


func _p2_place(k: int) -> String:
	if Run.map.is_empty():
		return "THIS SYSTEM"
	var n: MapGen.MapNode = Run.map[posmod(absi(hash(k * 13 + 5)), Run.map.size())]
	return MapGen.star_name(n).to_upper()


func _paint_p2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := _p_t()
	var dim := fade()
	var big := h >= 140
	var hover := g.state != LabLogin.LOGO
	var k := floori(t / P2_CYC)
	var u := t - float(k) * P2_CYC
	# the form goes dim in its last half second, and the next types in
	var out := clampf((P2_CYC - u) / 0.45, 0.0, 1.0) * dim
	head(x0 + 4, y0 + 3, " CLAIM OF SALVAGE")
	var cn := _p_claim(k)
	var hx_end := x0 + 18 + LabBoard.tw(g.owner_short() + " CLAIM OF SALVAGE")
	if a.end.x - 6 - LabBoard.tw(cn) > hx_end + 8:
		text(a.end.x - 6 - LabBoard.tw(cn), y0 + 6, cn, pc(P_BRASS, 0.9 * out))
	g.draw_rect(Rect2(x0 + 4, y0 + 17, w - 8, 1), ink(0.25))
	var vals := [P2_ITEMS[posmod(k, P2_ITEMS.size())], _p_name(k), _p2_place(k),
		P2_STATES[posmod(k * 3 + 1, P2_STATES.size())], "%d S AFTER IT STOPPED" % (20 + posmod(absi(hash(k)), 60))]
	var pitch := 15 if big else 10
	var lx := x0 + 8
	var vx := lx + LabBoard.tw("ONCE NAMED") + 10
	var vw := a.end.x - 8 - vx
	var y := y0 + 23
	for j in P2_LABELS.size():
		var t0 := 0.25 + float(j) * 0.4
		if u >= t0:
			text(lx, y, String(P2_LABELS[j]), ink(0.5 * out))
			var v := fit(String(vals[j]), vw)
			var n := clampi(int((u - t0) * P2_TYPE_CPS), 0, v.length())
			if n > 0:
				text(vx, y, v.left(n), ink(0.95 * out))
			if n < v.length():
				var kx := vx + (LabBoard.tw(v.left(n)) + 1 if n > 0 else 0)
				g.draw_rect(Rect2(kx, y - 1, 4, 7), ink(0.9 * out))
		y += pitch
	# the foot (on a big glass): the claims this lab has on file
	var foot := big and not hover
	var zone := Rect2i(x0 + 4, y + 1, w - 8, a.end.y - (14 if foot else 3) - (y + 1))
	if foot:
		text(lx, a.end.y - 9, "CLAIMS ON FILE " + _thousands(18402 + k), ink(0.45))
	if hover:
		var hy := zone.position.y + 4
		text(lx, hy, "CLAIMANT", ink(0.5))
		var s := "PILOT %s · CLICK TO SIGN IN" % ship()
		if say_w(s) > w - 16:
			s = "PILOT %s · SIGN IN" % ship()
		if g.state == LabLogin.SIGNING:
			s = "PILOT %s · SIGNING IN" % ship()
		say(lx, hy + pitch, s, ink(0.9) if g.state == LabLogin.SIGNING else cue())
		return
	# THE STAMP: the Combine's mark and FILED, in brass, pressed in when the
	# last line is typed
	if u < P2_STAMP:
		return
	var ks := clampf((u - P2_STAMP) / 0.18, 0.0, 1.0)
	var es := 3.0 if big else 2.0
	var en := int(9.0 * es) + 2
	var name := g.owner_name()
	var sw := en + 8 + maxi(LabBoard.tw("FILED", 16), LabBoard.tw(name))
	var sh := maxi(en, 10 + 6 + 5)
	var sx := a.end.x - 10 - sw
	var sy := zone.position.y + (zone.size.y - sh) / 2
	var bc := Color(pc(P_BRASS, out), ks)
	var fd := (DB.manufacturers[&"probate"] as ManufacturerData).field if DB.manufacturers.has(&"probate") else LabBoard.BG
	CardView.draw_emblem(g, &"probate", Vector2(sx + en / 2.0, sy + sh / 2.0), es, bc, fd)
	g.leaves.append(["mark", Rect2i(sx, sy + (sh - en) / 2, en, en)])
	var tx := sx + en + 8
	var ty := sy + (sh - 21) / 2
	text(tx, ty, "FILED", bc, 16)
	text(tx, ty + 16, name, Color(pc(P_BRASS, 0.75 * out), ks))


# ------------------------------------------------------------------ P3: salvage assay

const P3_CYC := 7.0
const P3_IN := 1.2
const P3_WEIGH := [1.2, 2.0]
const P3_FILL := [2.0, 2.6]
const P3_PAY := 2.6
const P3_OUT := 6.0

var _p3_tex: ImageTexture = null
var _p3_key := ""


## Lot `k`'s mass in tonnes, its shares of plate, wire and scrap, and its pay.
func _p3_lot(k: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + k
	var mass := snappedf(9.0 + 50.0 * rng.randf(), 0.1)
	var plate := rng.randi_range(45, 70)
	var wire := rng.randi_range(5, 15)
	return {"mass": mass, "shares": [plate, wire, 100 - plate - wire], "pay": int(mass * 10.0)}


## A piece of a wreck: plate in three metals, welded where it was cut and
## joined, a row of ports, a nose at one end and a torn edge at the other.
func _p3_piece(k: int, pw: int, ph: int) -> ImageTexture:
	var key := "%d|%d|%d" % [k, pw, ph]
	if key == _p3_key and _p3_tex != null:
		return _p3_tex
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + k
	var BG := LabBoard.BG
	var metals := [P_STEEL, P_BRASS, P_BRONZE]
	var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	var nose_left := rng.randf() < 0.5
	var taper := int(float(pw) * (0.16 + 0.1 * rng.randf()))
	var tear := maxi(4, int(float(pw) * 0.13))
	var top := PackedInt32Array()
	var bot := PackedInt32Array()
	var jag := 0
	for x in pw:
		var xs := x if nose_left else pw - 1 - x
		var tt := 0
		var bb := 0
		if xs < taper:
			var f := 1.0 - float(xs) / float(taper)
			tt = int(float(ph) * 0.4 * f * f)
			bb = int(float(ph) * 0.22 * f * f)
		if pw - 1 - xs < tear:
			jag = clampi(jag + rng.randi_range(-2, 3), 0, ph / 3)
			tt = maxi(tt, jag)
			bb = maxi(bb, jag / 2 + rng.randi_range(0, 2))
		top.append(tt)
		bot.append(ph - 1 - bb)
	# the plates: strakes along the hull (three or four bands), each band cut
	# into plates of odd lengths, the joins staggered band to band
	var pid := PackedInt32Array()
	pid.resize(pw * ph)
	var pmetal: Array[int] = []
	var nb := rng.randi_range(3, 4)
	var bands: Array[int] = [0]
	for i in nb - 1:
		bands.append(int(float(ph) * float(i + 1) / float(nb)) + rng.randi_range(-2, 2))
	bands.append(ph)
	for b in nb:
		var col_x := -rng.randi_range(0, 14)
		while col_x < pw:
			var x1 := mini(pw, col_x + rng.randi_range(14, 30))
			var roll := rng.randf()
			pmetal.append(0 if roll < 0.45 else (1 if roll < 0.8 else 2))
			var id := pmetal.size() - 1
			for yy in range(bands[b], bands[b + 1]):
				for xx in range(maxi(0, col_x), x1):
					pid[yy * pw + xx] = id
			col_x = x1
	var welded := {}
	for i in pmetal.size():
		welded[i] = rng.randf() < 0.5
	var port_y := int(float(ph) * 0.34)
	for yy in ph:
		for xx in pw:
			if yy < top[xx] or yy > bot[xx]:
				continue
			var id := pid[yy * pw + xx]
			var base: Color = metals[pmetal[id]]
			var span := maxf(1.0, float(bot[xx] - top[xx]))
			var lit := 1.0 - float(yy - top[xx]) / span
			var c := LabBoard.mixc(BG, base, 0.5 + 0.35 * lit)
			if LabBoard.bayer(xx, yy) < 0.12 and noise(xx + k * 7, yy) < 0.5:
				c = LabBoard.mixc(BG, base, 0.4 + 0.3 * lit)
			# the seams between plates, and weld beads along some of them
			var right := pid[yy * pw + xx + 1] if xx + 1 < pw else id
			var below := pid[(yy + 1) * pw + xx] if yy + 1 < ph else id
			if right != id or below != id:
				c = LabBoard.mixc(BG, base, 0.25)
			elif xx > 0 and pid[yy * pw + xx - 1] != id and welded[id] and posmod(yy, 2) == 0:
				c = LabBoard.mixc(BG, P_BRASS, 1.0)
			# fasteners near each plate's corners, not two alike
			elif (xx > 1 and pid[yy * pw + xx - 2] != id) or (xx + 2 < pw and pid[yy * pw + xx + 2] != id):
				if (yy > 1 and pid[(yy - 2) * pw + xx] != id) or (yy + 2 < ph and pid[(yy + 2) * pw + xx] != id):
					c = LabBoard.mixc(BG, P_STEEL if posmod(id, 3) != 0 else P_BRASS, 0.95)
			# a row of ports along the hull
			var mid := (xx > taper and xx < pw - tear - 2) if nose_left else (xx > tear + 2 and xx < pw - taper)
			if mid and yy >= port_y and yy < port_y + 2 and posmod(xx, 5) < 2:
				c = LabBoard.mixc(BG, Color.BLACK, 0.4)
			# the outline: lit along the top, dark below and at the ends
			if yy == top[xx] or (xx > 0 and yy < top[xx - 1]) or (xx + 1 < pw and yy < top[xx + 1]):
				c = LabBoard.mixc(BG, base.lerp(LabBoard.WHITE, 0.3), 1.0)
			elif yy == bot[xx] or xx == 0 or xx == pw - 1 or (xx > 0 and yy > bot[xx - 1]) or (xx + 1 < pw and yy > bot[xx + 1]):
				c = LabBoard.mixc(BG, base, 0.3)
			img.set_pixel(xx, yy, c)
	_p3_tex = ImageTexture.create_from_image(img)
	_p3_key = key
	return _p3_tex


func _paint_p3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var t := _p_t()
	var dim := fade()
	var big := h >= 140
	var hover := g.state != LabLogin.LOGO
	var k := floori(t / P3_CYC)
	var u := t - float(k) * P3_CYC
	var lot := _p3_lot(k)
	head(x0 + 4, y0 + 3, " SALVAGE ASSAY")
	var ls := "LOT %d" % (400 + k)
	var hx_end := x0 + 18 + LabBoard.tw(g.owner_short() + " SALVAGE ASSAY")
	if a.end.x - 6 - LabBoard.tw(ls) > hx_end + 8:
		text(a.end.x - 6 - LabBoard.tw(ls), y0 + 6, ls, ink(0.55))
	var pitch := 12 if big else 9
	var ro := a.end.y - (pitch * 3 + 12)
	g.draw_rect(Rect2(x0 + 4, ro - 5, w - 8, 1), ink(0.25))
	var bay := Rect2i(x0 + 4, y0 + 18, w - 8, ro - 7 - (y0 + 18))
	# THE SCALE: a pad with its ticks, and the tractor that holds the piece
	var ph := maxi(16, int(float(bay.size.y) * 0.6))
	var pw := mini(int(float(ph) * 2.4), int(float(bay.size.x) * 0.62))
	var pad_y := bay.end.y - 5
	var pad_w := int(float(pw) * 1.25)
	var pad_x := bay.position.x + (bay.size.x - pad_w) / 2
	for xx in range(pad_x, pad_x + pad_w):
		px(xx, pad_y, ink(0.5 * dim))
		if posmod(xx - pad_x, 6) == 0:
			px(xx, pad_y + 1, ink(0.35 * dim))
			px(xx, pad_y + 2, ink(0.35 * dim))
	for ex: int in [pad_x - 4, pad_x + pad_w + 1]:
		g.draw_rect(Rect2(ex, pad_y - 1, 3, 3), ink(0.6 * dim))
	# where the piece is: towed in, held, towed off
	var rest_x := bay.position.x + (bay.size.x - pw) / 2
	var from_x := bay.position.x - pw - 2
	var to_x := bay.end.x + 2
	var e_in := 1.0 - pow(1.0 - clampf(u / P3_IN, 0.0, 1.0), 3.0)
	var e_out := pow(clampf((u - P3_OUT) / (P3_CYC - P3_OUT), 0.0, 1.0), 2.0)
	var piece_x := int(lerpf(float(from_x), float(rest_x), e_in) + e_out * float(to_x - rest_x))
	var piece_y := pad_y - 6 - ph
	# the tractor's light, rising from the pad under the piece while it is on it
	var on_pad := absi(piece_x - rest_x) < pw / 3
	if on_pad:
		var x_lo := maxi(pad_x, piece_x + 3)
		var x_hi := mini(pad_x + pad_w, piece_x + pw - 3)
		var off := int(floorf(t * 8.0))
		for xx in range(x_lo, x_hi):
			if posmod(xx - pad_x, 6) != 3:
				continue
			for yy in range(piece_y + ph - 4, pad_y - 1):
				if posmod(yy + off, 3) == 0:
					px(xx, yy, ink(0.3 * dim))
	var tex := _p3_piece(k, pw, ph)
	var pr := Rect2i(piece_x, piece_y, pw, ph)
	var vis := pr.intersection(bay)
	if vis.has_area():
		g.draw_texture_rect_region(tex, Rect2(vis), Rect2(vis.position - pr.position, vis.size), Color(1, 1, 1, dim))
	# THE READOUT: what it was part of and its mass; the bar of its metal; the pay
	var lx := x0 + 8
	var rx := a.end.x - 8
	if hover:
		text(lx, ro, "THIS TERMINAL", ink(0.55))
		text(lx, ro + pitch, fit("PILOT %s" % ship(), w - 16), ink(1.0))
		text(lx, ro + pitch * 2 + 4, "SIGNING IN" if g.state == LabLogin.SIGNING else "CLICK TO SIGN IN",
			ink(0.9) if g.state == LabLogin.SIGNING else cue())
		return
	var ra := clampf((P3_OUT + 0.5 - u) / 0.5, 0.0, 1.0)
	var from_s := "FROM THE " + _p_name(k)
	var ms := "MASS --.- T"
	var mc := ink(0.4 * ra)
	if u >= P3_WEIGH[1]:
		ms = "MASS %.1f T" % float(lot.mass)
		mc = ink(0.95 * ra)
	elif u >= P3_WEIGH[0]:
		# the digits rolling while it settles on the scale
		var tick := int(floorf(u * 12.0))
		ms = "MASS %d%d.%d T" % [1 + int(noise(tick, 1) * 5.0), int(noise(tick, 2) * 10.0), int(noise(tick, 3) * 10.0)]
		mc = ink(0.75 * ra)
	var mw := LabBoard.tw(ms)
	text(rx - mw, ro, ms, mc)
	text(lx, ro, fit(from_s, rx - mw - 10 - lx), ink(0.55 * ra))
	# the bar: plate, wire and scrap, filling from the left
	var by := ro + pitch
	var bw := rx - lx
	var fill := clampf((u - float(P3_FILL[0])) / (float(P3_FILL[1]) - float(P3_FILL[0])), 0.0, 1.0)
	var cols := [P_STEEL, P_BRASS, P_BRONZE]
	var names := ["PLATE", "WIRE", "SCRAP"]
	var shares: Array = lot.shares
	for xx in range(lx, rx):
		if posmod(xx, 2) == 0:
			px(xx, by + 4, ink(0.2 * ra))
	var acc := 0.0
	for i in 3:
		var s0 := lx + int(acc * float(bw))
		acc += float(shares[i]) / 100.0
		var s1 := lx + int(acc * float(bw)) - (1 if i < 2 else 0)
		var lim := lx + int(fill * float(bw))
		if mini(s1, lim) > s0:
			g.draw_rect(Rect2(s0, by, mini(s1, lim) - s0, 3), pc(cols[i], 0.9 * ra))
	g.leaves.append(["bar", Rect2i(lx, by, bw, 5)])
	if fill > 0.0:
		var lgx := lx
		var lgy := by + 9
		for i in 3:
			var s := "%s %d%%" % [names[i], int(shares[i])]
			if lgx + 5 + LabBoard.tw(s) > rx:
				break
			g.draw_rect(Rect2(lgx, lgy + 1, 3, 3), pc(cols[i], 0.9 * ra))
			text(lgx + 5, lgy, s, ink(0.7 * ra))
			lgx += 5 + LabBoard.tw(s) + 10
	# paid on the weight
	var py := ro + pitch * 2 + 8
	text(lx, py, "PAID ON THE WEIGHT", ink(0.5 * ra))
	if u >= P3_PAY:
		var cs := "%d CR" % int(lot.pay)
		text(rx - LabBoard.tw(cs), py, cs, pc(P_BRASS, ra))


# ================================================================== REDLINE's own (r6, Nov 7)
# Jon on the seven: "Love these. Want more per owner." Three that only Redline
# Shipyards would run, each its own idea:
#   R1  NO RECORD: a refit job's record typed in, then the serial, the port and
#       the owner marked out; RECORD KEPT: NONE. (What it sells.)
#   R2  GOING DARK: a passive sensor's waterfall, a refitted hull's return
#       fading into the noise as its baffles close. (What it researches.)
#   R3  OVER THE LINE: a drive hung over the blast pit, its plume run past the
#       rated line and back; the line is cut where the plume crosses it. (Its name.)
# Owner red is the owner's own colour (`DB.manufacturer_colour`), so the same
# looks dressed for another owner take that owner's colour.

func _red(k: float) -> Color:
	var c := DB.manufacturer_colour(g.owner_id) if DB.manufacturers.has(g.owner_id) else g.tint
	return LabBoard.mixc(LabBoard.BG, c, clampf(k, 0.0, 1.0))


## The rest clock, held where it was while pointed at (`_s3_hold` is the
## moment the pointer came, kept by `step` for every look).
func _held_t() -> float:
	if g.state != LabLogin.LOGO and _s3_hold >= 0.0:
		return _s3_hold
	return rest_t()


## The two-line foot every Redline look ends on: a rule, then what it says at
## rest, or the pilot and CLICK TO SIGN IN while pointed at.
func _r_foot(a: Rect2i, rest1: String, rest_c: Color, hover1: String) -> void:
	var x0 := a.position.x
	var w := a.size.x
	var ly := a.end.y - 19
	g.draw_rect(Rect2(x0 + 4, ly - 4, w - 8, 1), ink(0.25))
	if g.state == LabLogin.LOGO:
		say(x0 + 8, ly + 4, fit(rest1, w - 16), rest_c)
		return
	say(x0 + 8, ly, fit(hover1, w - 16), ink(0.55))
	var s2 := "PILOT %s · CLICK TO SIGN IN" % ship()
	if say_w(s2) > w - 16:
		s2 = "PILOT %s · SIGN IN" % ship()
	if g.state == LabLogin.SIGNING:
		s2 = "PILOT %s · SIGNING IN" % ship()
	say(x0 + 8, ly + 8, fit(s2, w - 16), ink(0.9) if g.state == LabLogin.SIGNING else cue())


## The header's right-hand words, when there is room for them.
func _r_right(a: Rect2i, extra: String, s: String) -> void:
	var hx_end := a.position.x + 4 + 14 + LabBoard.tw(g.owner_short() + extra)
	var sw := say_w(s)
	if a.end.x - 6 - sw > hx_end + 8:
		say(a.end.x - 6 - sw, a.position.y + 6, s, ink(0.5))


# ------------------------------------------------------------------ R1: no record

const R1_CYCLE := 9.0
const R1_ROW := 0.3
const R1_CPS := 40.0
const R1_MARK := [1, 2, 3]
const R1_MARK_AT := 1.95
const R1_MARK_EACH := 0.3
const R1_MARK_S := 0.22
const R1_KEPT_AT := 2.9
const R1_CLEAR := 8.4
const R1_HULLS := ["RUNNER", "SLOOP", "CLIPPER", "CUTTER", "CORVETTE", "SCOW", "TENDER", "PINNACE", "SKIFF", "YAWL"]
const R1_WORK := ["NEW PAINT OVER OLD", "SERIALS FILED OFF", "VENTS BAFFLED", "QUICK RELEASE CATCHES",
	"HIDDEN HOLD FITTED", "DRIVE TUNED PAST RATE", "PANELS THINNED"]


func _r1_job(k: int) -> Array:
	var h := absi(hash(k * 104729 + 7))
	var ms: Array = DB.manufacturers.keys()
	var from := "KORVAN"
	var port := "KORVAN"
	if not ms.is_empty():
		from = DB.short_name(DB.manufacturer_name(ms[(h / 7) % ms.size()] as StringName)).to_upper()
		port = DB.short_name(DB.manufacturer_name(ms[(h / 13) % ms.size()] as StringName)).to_upper()
	return [
		String(R1_HULLS[h % R1_HULLS.size()]),
		"%s-%04d-%02d" % [from.left(2), (h / 17) % 10000, (h / 3) % 100],
		"%s DOCK %d" % [port, 1 + (h / 19) % 9],
		"PILOT " + String(S3_PILOTS[(h / 23) % S3_PILOTS.size()]),
		String(R1_WORK[(h / 29) % R1_WORK.size()]),
		"CASH. NO RECEIPT.",
	]


func _paint_r1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var dim := fade()
	var ft := _held_t()
	var k := int(floorf(ft / R1_CYCLE))
	var u := fposmod(ft, R1_CYCLE)
	head(x0 + 4, y0 + 3, " REFIT RECORD")
	_r_right(a, " REFIT RECORD", "JOB %04d" % (2200 + k + absi(hash(String(g.owner_id))) % 600))
	g.draw_rect(Rect2(x0 + 4, y0 + 17, w - 8, 1), ink(0.25))
	var right := a.end.x - 8
	var labels := ["HULL", "SERIAL", "LAST PORT", "OWNER", "WORK", "PAID"]
	var job := _r1_job(k)
	var top := y0 + 24
	var room := a.end.y - 26 - top
	var pitch := clampi(room / labels.size(), 10, 18)
	var lx := x0 + 10
	var vx := lx + LabBoard.tw("LAST PORT") + 12
	var vw := right - vx
	for i in labels.size():
		var y := top + i * pitch
		if u > R1_CLEAR + 0.08 * float(i):
			continue
		var started := u - float(i) * R1_ROW
		# the row's tick and its label, there as soon as its row starts
		if started < 0.0:
			continue
		px(lx - 4, y + 2, ink(0.5 * dim))
		say(lx, y, String(labels[i]), ink(0.5 * dim))
		var val := fit(String(job[i]), vw)
		var n := mini(val.length(), int(floorf(started * R1_CPS)))
		var shown := val.left(n)
		var mark := -1.0
		var j := R1_MARK.find(i)
		if j >= 0:
			mark = clampf((u - R1_MARK_AT - float(j) * R1_MARK_EACH) / R1_MARK_S, 0.0, 1.0)
		var full_w := LabBoard.tw(val)
		if mark < 1.0 and shown != "":
			say(vx, y, shown, ink(0.95 * dim))
			if n < val.length():
				g.draw_rect(Rect2(vx + LabBoard.tw(shown) + 1, y, 4, 5), ink(0.8 * dim))
		if mark > 0.0:
			# THE MARK-OUT: a hatched bar over the value, drawn left to right
			var bw := maxi(1, int(float(full_w + 4) * mark))
			var r := Rect2i(vx - 2, y - 1, bw, 7)
			g.draw_rect(Rect2(r), _red(0.3 * dim))
			for yy in range(r.position.y, r.end.y):
				for xx in range(r.position.x, r.end.x):
					if posmod(xx + yy, 4) == 0:
						g.draw_rect(Rect2(xx, yy, 1, 1), _red(0.6 * dim))
			if mark < 1.0:
				g.draw_rect(Rect2(r.end.x - 1, y - 2, 1, 9), _red(1.0 * dim))
			else:
				g.leaves.append(["bar", r])
	# THE FOOT: RECORD KEPT: NONE once the marks are on
	var kept := u >= R1_KEPT_AT and u < R1_CLEAR + 0.5
	if g.state != LabLogin.LOGO or kept:
		_r_foot(a, "RECORD KEPT: NONE", _red(1.0 * dim), "WE KEEP NO RECORD OF YOU")
	else:
		g.draw_rect(Rect2(x0 + 4, a.end.y - 23, w - 8, 1), ink(0.25))


# ------------------------------------------------------------------ R2: going dark

const R2_RATE := 7.0
const R2_CYCLE := 12.0
const R2_NOISE := 0.05


## The hull's return for a row written at time `t`: full, then falling as the
## baffles close, under the noise for the last part of each test.
func _r2_level(t: float) -> float:
	var u := fposmod(t, R2_CYCLE)
	if u < 2.0:
		return 1.0
	return maxf(0.02, exp(-(u - 2.0) * 0.48))


func _paint_r2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var dim := fade()
	var tr := rest_t()
	var hold := _held_t()
	var hover := g.state != LabLogin.LOGO
	head(x0 + 4, y0 + 3, " SIGNATURE TEST")
	var test := 40 + int(floorf(hold / R2_CYCLE)) + absi(hash(String(g.owner_id))) % 50
	_r_right(a, " SIGNATURE TEST", "TEST %d" % test)
	# THE WATERFALL: a row a twelfth of a second, newest on top
	var wf := Rect2i(x0 + 8, y0 + 20, w - 16, a.end.y - 27 - (y0 + 20))
	g._brackets(wf.grow(2), 4, ink(0.45 * dim))
	var now_row := int(floorf(tr * R2_RATE))
	var cx := float(wf.position.x) + float(wf.size.x) * 0.5
	var drift := float(wf.size.x) * 0.03
	var rng := RandomNumberGenerator.new()
	var per_row := maxi(4, int(float(wf.size.x) * 0.11))
	# the time scale down the left: NOW at the top, the oldest row at the foot
	var old_s := "-%d S" % int(roundf(float(wf.size.y) / R2_RATE))
	say(wf.position.x + 2, wf.position.y + 2, "NOW", ink(0.45 * dim))
	say(wf.position.x + 2, wf.end.y - 8, old_s, ink(0.45 * dim))
	_keep.append(Rect2i(wf.position.x, wf.position.y, LabBoard.tw("NOW") + 5, 9))
	_keep.append(Rect2i(wf.position.x, wf.end.y - 10, LabBoard.tw(old_s) + 5, 10))
	# pointed at, the new contact comes in from the top over three seconds
	var grow := 1.0 if g.state == LabLogin.SIGNING else clampf(g._t / 3.0, 0.0, 1.0)
	for yy in wf.size.y:
		var row := now_row - yy
		var t := float(row) / R2_RATE
		var y := wf.position.y + yy
		# the static, the same per row as it falls
		rng.seed = absi(hash(row * 7349 + 11))
		for i in per_row:
			var x := wf.position.x + rng.randi() % wf.size.x
			var n := rng.randf()
			px(x, y, ink((0.1 + 0.22 * n * n) * dim))
		# the test hull's return, in the owner's red
		var xc := cx - float(wf.size.x) * 0.18 + sin(t * 0.13) * drift
		var lv := _r2_level(t) * (1.0 - 0.6 * hk(0.5))
		if hover and t > hold:
			lv = 0.0
		if lv > R2_NOISE * 0.5:
			for d in range(-3, 4):
				var x := int(roundf(xc)) + d
				var v := lv * exp(-pow(float(d) / 1.3, 2.0)) * (0.75 + 0.25 * rng.randf())
				if v > 0.06:
					px(x, y, _red((0.25 + 0.75 * v) * dim))
		# pointed at: YOU, picked up at full return down the right of the band,
		# coming up over half a second
		if hover and float(yy) < grow * float(wf.size.y):
			var yx := int(cx + float(wf.size.x) * 0.2)
			for d in range(-5, 6):
				var v := exp(-pow(float(d) / 1.7, 2.0)) * (0.3 + 0.7 * rng.randf())
				if v > 0.1 and rng.randf() > 0.12:
					px(yx + d, y, ink((0.15 + 0.85 * v) * dim))
	# THE FOOT: the return now, or the contact
	var lvn := _r2_level(hold)
	var pct := roundi(lvn * 100.0)
	var rest1 := "RETURN %d%% · BELOW NOISE" % pct if lvn < R2_NOISE else "RETURN %d%% · TRACKING" % pct
	_r_foot(a, rest1, _red(1.0 * dim) if lvn < R2_NOISE else ink(0.75 * dim), "NEW CONTACT, FULL RETURN")


# ------------------------------------------------------------------ R3: over the line

const R3_SPEED := 22.0
const R3_RATED := 0.62
const R3_PUSH_EVERY := 7.0
const R3_IDLE := 0.22
var _r3_over := -1.0


## The drive's heat at time `t`, 0 to 1 of the chart: a working wander under
## the rated line and, every seven seconds, a push over it and back.
func _r3_heat(t: float) -> float:
	var v := 0.42 + 0.07 * sin(t * 0.9) + 0.04 * sin(t * 2.3 + 1.0) + 0.012 * sin(t * 6.1)
	var u := fposmod(t + 6.0, R3_PUSH_EVERY)
	if u < 3.0:
		v += 0.32 * pow(sin(u / 3.0 * PI), 2.0)
	return v


## R3, redrawn (critic pass, Nov 7): the strip chart it was matched Solari's
## Margin Test (a heat trace under a limit line), so the bench is a picture
## now. The drive hangs nozzle down over the blast pit; its plume runs past
## the red RATED line every seven seconds, and the line is cut where the plume
## goes through it: two red bars, the owner's own mark.
func _paint_r3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var dim := fade()
	var tr := rest_t()
	var hover := g.state != LabLogin.LOGO
	var hold := _held_t()
	if _r3_over < 0.0:
		_r3_over = 600.0 + float(absi(hash(String(g.owner_id))) % 300)
	head(x0 + 4, y0 + 3, " DRIVE BENCH")
	_r_right(a, " DRIVE BENCH", "GHOST DRIVE")
	g.draw_rect(Rect2(x0 + 4, y0 + 17, w - 8, 1), ink(0.25 * dim))
	# the thrust now (0..1 of the pit), throttled back to idle while pointed at
	var v := _r3_heat(tr)
	if hover:
		var e := clampf((tr - hold) / 1.2, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		v = lerpf(_r3_heat(hold), R3_IDLE, e)
	# THE BENCH: the picture on the left, the readings in a column on the right
	var pw := int(float(w) * 0.6)
	var pic := Rect2i(x0 + 8, y0 + 21, pw, a.end.y - 26 - (y0 + 21))
	var cx := pic.position.x + pic.size.x / 2
	var beam_y := pic.position.y + 1
	var floor_y := pic.end.y - 2
	# the drive: a ribbed casing hung from a short beam, the owner's red band
	# round its neck, cut in two like the mark, and a bell below it
	var dw := clampi(pic.size.x / 7, 10, 26) & ~1
	var dh := clampi(int(float(dw) * 0.85), 8, 24)
	g.draw_rect(Rect2(cx - dw, beam_y, dw * 2, 2), ink(0.5 * dim))
	g.draw_rect(Rect2(cx - 1, beam_y + 2, 2, 2), ink(0.6 * dim))
	var by := beam_y + 4
	g.draw_rect(Rect2(cx - dw / 2, by, dw, dh), ink(0.26 * dim))
	g._frame_box(Rect2i(cx - dw / 2, by, dw, dh), ink(0.7 * dim))
	for yy in range(by + 6, by + dh - 1, 3):
		line(Vector2i(cx - dw / 2 + 2, yy), Vector2i(cx + dw / 2 - 3, yy), ink(0.42 * dim))
	g.draw_rect(Rect2(cx - dw / 2, by + 2, dw / 2 - 1, 2), _red(1.0 * dim))
	g.draw_rect(Rect2(cx + 1, by + 2, dw / 2 - 1, 2), _red(1.0 * dim))
	var bell_top := by + dh
	var bell_h := maxi(3, dh / 4)
	for i in bell_h:
		var hw := dw / 4 + int(float(dw) * 0.2 * float(i) / float(bell_h))
		px(cx - hw, bell_top + i, ink(0.75 * dim))
		px(cx + hw - 1, bell_top + i, ink(0.75 * dim))
		if i == bell_h - 1:
			line(Vector2i(cx - hw, bell_top + i), Vector2i(cx + hw - 1, bell_top + i), ink(0.75 * dim))
	var noz_y := bell_top + bell_h
	var noz_hw := dw / 4 + int(float(dw) * 0.2)
	# the pit floor and its blast plate, hatched
	line(Vector2i(cx - noz_hw * 3, floor_y), Vector2i(cx + noz_hw * 3, floor_y), ink(0.45 * dim))
	for xx in range(cx - noz_hw * 2, cx + noz_hw * 2):
		if posmod(xx, 3) == 0:
			px(xx, floor_y + 1, ink(0.3 * dim))
	# THE PLUME: its length is the thrust; it changes shape ten times a second
	var room := float(floor_y - 2 - noz_y)
	var plen := int(clampf(v, 0.0, 1.0) * room)
	var ry := noz_y + int(R3_RATED * room)
	var over := v > R3_RATED
	var frame := int(floorf(tr * 10.0))
	for i in plen:
		var y := noz_y + i
		var s := float(i) / maxf(1.0, float(plen))
		var hw := float(noz_hw - 1) * (1.0 - 0.75 * s * s) + 0.5
		for d in range(-int(hw), int(hw) + 1):
			var edge := absf(float(d)) / maxf(1.0, hw)
			var n := noise(frame * 131 + d, y)
			var heat := (1.0 - s) * (1.0 - 0.6 * edge)
			if edge > 0.6 and n < 0.45:
				continue
			if s > 0.8 and n < (s - 0.8) * 4.0:
				continue
			var c := ink((0.3 + 0.7 * heat) * dim)
			if y > ry and over:
				c = _red((0.55 + 0.45 * heat) * dim)
			px(cx + d, y, c)
	# THE RATED LINE: dashed red across the pit, cut where the plume crosses it
	var cut_l := cx - noz_hw - 3
	var cut_r := cx + noz_hw + 2
	for xx in range(pic.position.x + 4, pic.end.x - 4):
		if over and xx >= cut_l and xx <= cut_r:
			continue
		if over:
			# the two halves go solid: the owner's two bars
			g.draw_rect(Rect2(xx, ry, 1, 2), _red(1.0 * dim))
		elif posmod(xx, 3) != 2:
			px(xx, ry, _red(0.7 * dim))
	say(pic.position.x + 5, ry - 8, "RATED", _red(0.85 * dim))
	# THE READINGS: the thrust against the rating, and the time it has run over
	var col := pic.end.x + 8
	var cw := a.end.x - 8 - col
	var y := pic.position.y + 2
	var big_step := 15 if pic.size.y >= 70 else 12
	say(col, y, fit("THRUST", cw), ink(0.5 * dim))
	y += 10
	var pct := roundi(v / R3_RATED * 100.0)
	text(col, y, "%d%%" % pct, _red(1.0 * dim) if over else ink(0.95 * dim), 16)
	y += big_step
	say(col, y, fit("OF RATED", cw), ink(0.5 * dim))
	var ov := int(_r3_over)
	if pic.size.y >= 70:
		y += 16
		say(col, y, fit("TIME OVER", cw), ink(0.5 * dim))
		y += 10
		text(col, y, "%d:%02d" % [ov / 60, ov % 60], _red(0.9 * dim), 16)
	# THE FOOT
	var rest1 := "TUNED PAST RATE · TIME OVER %d:%02d" % [ov / 60, ov % 60]
	if pic.size.y >= 70 or say_w(rest1) > w - 16:
		rest1 = "TUNED PAST RATE. NOT CERTIFIED."
	_r_foot(a, rest1, ink(0.75 * dim), "DRIVE BACK TO IDLE")


# ================================================================== Cygnet Dynamics
# (r6, Nov 7: Jon kept all seven, "OWNER", and wants more per owner. These
# three are Cygnet's own: drones, cells, units that report in, no people.)
##   C1  UNIT STATUS: the swarm's roll call. A honeycomb of launch cells, each
##       unit flashing its signal arcs as it reports in; now and then one stops
##       reporting and is replaced. Pointed at, the middle cell is yours.
##   C2  FORMATION TRIAL: eight units leave their launch cells, fly a pattern
##       round a beacon and come home. Pointed at, they ring your ship.
##   C3  NESTED HOUSING: a unit's housing, its six cells, and the housing in
##       its middle cell, zooming in without end. Pointed at, the zoom stops.

## The owner's own colour (the lab's ink if nobody holds it).
func _oc() -> Color:
	if DB.manufacturers.has(g.owner_id):
		return DB.manufacturer_colour(g.owner_id)
	return g.tint


func om(a: float) -> Color:
	return LabBoard.mixc(LabBoard.BG, _oc(), clampf(a, 0.0, 1.0))


## A flat-topped hexagon's corners, `r` px to a corner.
func _hex_pts(c: Vector2, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in 6:
		var an := float(i) * TAU / 6.0
		out.append(Vector2i((c + Vector2(cos(an), sin(an)) * r).round()))
	return out


func _hex_line(c: Vector2, r: float, col: Color, every: int = 1) -> void:
	var p := _hex_pts(c, r)
	for i in 6:
		line(p[i], p[(i + 1) % 6], col, every)


## A flat-topped hexagon filled, on a pixel's centre.
func _hex_fill(cx: int, cy: int, r: int, col: Color) -> void:
	var hh := roundi(float(r) * 0.866)
	for dy in range(-hh, hh + 1):
		var half := r - roundi(float(absi(dy)) / float(maxi(1, hh)) * float(r) * 0.5)
		for dx in range(-half, half + 1):
			px(cx + dx, cy + dy, col)


## A unit: the mark's diamond, `s` px to a point.
func _unit(cx: int, cy: int, s: int, col: Color) -> void:
	for dy in range(-s, s + 1):
		var half := s - absi(dy)
		for dx in range(-half, half + 1):
			px(cx + dx, cy + dy, col)


## The mark's signal arcs over a unit of size `s`.
func _arcs(cx: int, cy: int, s: int, col: Color, n: int) -> void:
	for k in n:
		var rr := s + 2 + 2 * k
		var lim := int(float(rr) * 0.75)
		for dx in range(-lim, lim + 1):
			var dy := -roundi(sqrt(maxf(0.0, float(rr * rr - dx * dx))))
			px(cx + dx, cy + dy, col)


## The sign-in column (as savers 1 and 2 have it), from `y`.
func _sign_col(cx0: int, y: int, cw: int, pitch: int, role: String) -> void:
	text(cx0, y, role, ink(0.5))
	y += pitch
	text(cx0, y, "PILOT", ink(0.75))
	y += pitch
	text(cx0, y, fit(ship(), cw), ink(1.0))
	y += pitch + 4
	if g.state == LabLogin.SIGNING:
		text(cx0, y, "SIGNING IN", ink(0.9))
	elif LabBoard.tw("CLICK TO SIGN IN") <= cw:
		text(cx0, y, "CLICK TO SIGN IN", cue())
	else:
		text(cx0, y, "CLICK TO", cue())
		text(cx0, y + pitch, "SIGN IN", cue())


# ------------------------------------------------------------------ C1: unit status

const C1_FLASH := 0.45
const C1_OUT := 9.0


func _c1_unit_no(i: int) -> int:
	return 100 + absi(hash(String(g.owner_id) + str(i * 31 + 7))) % 9800


func _paint_c1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	var hv := hk(0.4)
	# cells sized to the glass: about seven rows of them
	var r := clampi(h / 15, 5, 10)
	var big := r >= 8
	var hh := roundi(float(r) * 0.866)
	var dxs := roundi(1.5 * float(r + 1))
	var dys := 2 * roundi(0.866 * float(r + 1))
	var gr := Rect2i(x0 + 4, y0 + 17, w - 8, h - 17 - 15)
	var cols := maxi(1, (gr.size.x - 2 * r - 1) / dxs + 1)
	var rows := maxi(1, (gr.size.y - 2 * hh - 1 - dys / 2) / dys + 1)
	var gw := (cols - 1) * dxs + 2 * r + 1
	var gh := (rows - 1) * dys + dys / 2 + 2 * hh + 1
	var ox := gr.position.x + (gr.size.x - gw) / 2 + r
	var oy := gr.position.y + (gr.size.y - gh) / 2 + hh
	var cells: Array[Vector2i] = []
	for cx in cols:
		for ry in rows:
			cells.append(Vector2i(ox + cx * dxs, oy + ry * dys + (dys / 2 if cx % 2 == 1 else 0)))
	var n := cells.size()
	# the middle cell (yours, pointed at)
	var mid := 0
	var best := 1 << 30
	for i in n:
		var d := (cells[i] - Vector2i(gr.get_center())).length_squared()
		if d < best:
			best = d
			mid = i
	# the unit that stops reporting this cycle, and where the cycle is
	var cyc := int(floorf(tr / C1_OUT))
	var f := fposmod(tr, C1_OUT)
	var dark := absi(hash(cyc * 7 + 3 + absi(hash(String(g.owner_id))))) % maxi(1, n)
	if dark == mid:
		dark = (dark + rows) % maxi(1, n)
	var out := not hover and f >= 1.2 and f < 5.2
	var back := not hover and f >= 5.2 and f < 7.0
	# HEADER: the owner's unit status, and the count reporting
	head(x0 + 4, y0 + 3, " UNIT STATUS")
	var cnt := n - (1 if out else 0) + (1 if hover else 0)
	var tot := n + (1 if hover else 0)
	var cs := "%s OF %s" % [_thousands(cnt), _thousands(tot)]
	var hx_end := x0 + 18 + LabBoard.tw(g.owner_short() + " UNIT STATUS")
	if a.end.x - 6 - LabBoard.tw(cs) > hx_end + 8:
		text(a.end.x - 6 - LabBoard.tw(cs), y0 + 6, cs, ink(0.6))
	# the plate, pointed at: under the middle cell (over it if no room)
	var lines := [["PILOT %s · REPORTING" % ship(), ink(0.75)], ["CLICK TO SIGN IN", cue()]]
	if g.state == LabLogin.SIGNING:
		lines = [["PILOT %s · REPORTING" % ship(), ink(0.75)], ["SIGNING IN", ink(0.9)]]
	var pl := Rect2i()
	if hover:
		var open := clampf(g._t / 0.15, 0.0, 1.0) if g.state == LabLogin.LOGIN else 1.0
		var mc := cells[mid]
		pl = plate(mc.x, mc.y + hh + 7, lines, open)
		if pl.end.y > a.end.y - 14:
			pl.position.y = mc.y - hh - 7 - pl.size.y
		pl.position.x = clampi(pl.position.x, x0 + 4, a.end.x - 4 - pl.size.x)
		_keep.append(pl.grow(3))
	# THE CELLS: each unit flashes its arcs as it reports, every 3-5 s
	var us := 2 if big else 1
	for i in n:
		var c := cells[i]
		if not box_free(Rect2i(c - Vector2i(r + 1, hh + 1), Vector2i(2 * r + 3, 2 * hh + 3))):
			continue
		var per := 3.2 + 2.0 * noise(i, 1)
		var since := fposmod(tr - noise(i, 2) * per, per)
		var k := exp(-since / C1_FLASH)
		var dk := dim * (1.0 - 0.5 * hv)
		_hex_fill(c.x, c.y, r - 1, om(0.07 * dim))
		if i == mid and hover:
			_hex_line(Vector2(c), float(r), cue())
			_unit(c.x, c.y, us, LabBoard.mixc(LabBoard.BG, LabBoard.HOT, hv))
			_arcs(c.x, c.y, us, LabBoard.mixc(LabBoard.BG, LabBoard.HOT, 0.8 * hv * (0.6 + 0.4 * sin(g._t * TAU / 1.2))), 2 if big else 1)
			continue
		if i == dark and out:
			# stopped reporting: the cell empty, its rim dotted
			_hex_line(Vector2(c), float(r), LabBoard.mixc(LabBoard.BG, LabBoard.BAD, 0.6 * dk), 2)
			if int(floorf(f / 0.5)) % 2 == 0:
				g.draw_rect(Rect2(c.x - 1, c.y - 1, 3, 3), LabBoard.mixc(LabBoard.BG, LabBoard.BAD, dk))
			continue
		if i == dark and back:
			# the replacement, in from below and settling
			var e := smoothstep(0.0, 0.9, f - 5.2)
			var uy := c.y + roundi((1.0 - e) * float(hh + 3))
			_hex_line(Vector2(c), float(r), om((0.3 + 0.5 * (1.0 - e)) * dk))
			if uy <= c.y + hh - us:
				_unit(c.x, uy, us, om(dk))
			if e >= 1.0:
				_arcs(c.x, c.y, us, om(dk * (1.0 - smoothstep(6.1, 7.0, f))), 2 if big else 1)
			continue
		_hex_line(Vector2(c), float(r), om((0.28 + 0.3 * k) * dk))
		_unit(c.x, c.y, us, om((0.42 + 0.55 * k) * dk))
		if k > 0.3:
			_arcs(c.x, c.y, us, om(k * dk), 2 if big else 1)
	if out:
		# the empty cell, bracketed over its neighbours
		var dc := cells[dark]
		g._brackets(Rect2i(dc - Vector2i(r + 3, hh + 3), Vector2i(2 * r + 7, 2 * hh + 7)), 3, LabBoard.mixc(LabBoard.BG, LabBoard.BAD, 0.8 * dim))
	if pl.has_area():
		plate_draw(pl, lines, pl.size.x >= say_w(String(lines[0][0])) + 8)
		var mc2 := cells[mid]
		g._brackets(Rect2i(mc2 - Vector2i(r + 3, hh + 3), Vector2i(2 * r + 7, 2 * hh + 7)), 3, cue())
	# THE FOOT: the roll call's one line
	var fy := a.end.y - 9
	g.draw_rect(Rect2(x0 + 4, fy - 4, w - 8, 1), ink(0.25))
	if out:
		var s := "UNIT %04d · STOPPED REPORTING" % _c1_unit_no(dark)
		if say_w(s) > w - 20:
			s = "UNIT %04d · NO REPORT" % _c1_unit_no(dark)
		g.draw_rect(Rect2(x0 + 6, fy + 1, 3, 3), LabBoard.BAD)
		say(x0 + 12, fy, s, ink(0.9))
	elif back:
		say(x0 + 12, fy, "UNIT %04d · REPLACED" % _c1_unit_no(dark), ink(0.8))
		g.draw_rect(Rect2(x0 + 6, fy + 1, 3, 3), om(1.0))
	else:
		text(x0 + 12, fy, "ALL UNITS REPORTING", ink(0.6))
		g.draw_rect(Rect2(x0 + 6, fy + 1, 3, 3), om(0.8))


# ------------------------------------------------------------------ C2: formation trial

const C2_CYCLE := 8.0
const C2_N := 8
const C2_NAMES := ["RING", "FIGURE EIGHT", "TWO RINGS"]
## The trial's log: when, and what (the units leave before the order does).
const C2_LOG := [[0.2, "UNITS OUT"], [0.5, "ORDER SENT"], [1.7, "HELD"], [5.6, "RETURNING"], [7.1, "UNITS HOME"]]


func _c2_pat(kind: int, i: int, t: float, c: Vector2, R: Vector2) -> Vector2:
	var ph := float(i) / float(C2_N) * TAU
	var wv := TAU / 6.0
	match kind:
		0:
			return c + Vector2(cos(ph + t * wv), sin(ph + t * wv)) * R
		1:
			var s := ph + t * wv
			return c + Vector2(sin(s) * R.x, sin(s) * cos(s) * R.y * 1.8)
		_:
			var side := -1.0 if i % 2 == 0 else 1.0
			var s2 := ph * 2.0 + t * wv * side
			return c + Vector2(side * R.x * 0.5 + cos(s2) * R.x * 0.45, sin(s2) * R.y * 0.9)


func _c2_pos(kind: int, i: int, t: float, cell: Vector2, c: Vector2, R: Vector2) -> Vector2:
	var l0 := 0.2 + 0.12 * float(i)
	var r0 := 5.6 + 0.12 * float(i)
	if t < l0 or t >= r0 + 1.2:
		return cell
	var tg := _c2_pat(kind, i, t, c, R)
	if t < l0 + 1.1:
		var e := smoothstep(0.0, 1.0, (t - l0) / 1.1)
		return cell.lerp(tg, e) + Vector2(0.0, -sin(e * PI) * 10.0)
	if t < r0:
		return tg
	var e2 := smoothstep(0.0, 1.0, (t - r0) / 1.2)
	return tg.lerp(cell, e2) + Vector2(0.0, -sin(e2 * PI) * 10.0)


func _paint_c2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	var hv := hk(0.8)
	var big := h >= 150
	var fw := int(float(w) * (0.58 if big else 0.52))
	var box := Rect2i(x0 + 4, y0 + 4, fw, h - 8)
	var cr := clampi(h / 17, 4, 10)
	var chh := roundi(float(cr) * 0.866)
	var cdx := roundi(1.5 * float(cr + 1))
	var cdy := 2 * roundi(0.866 * float(cr + 1))
	# THE RACK: eight launch cells in a honeycomb strip along the foot
	var rack_y := box.end.y - chh - 4
	var cells: Array[Vector2] = []
	for i in C2_N:
		cells.append(Vector2(box.position.x + box.size.x / 2 + roundi((float(i) - 3.5) * float(cdx)), rack_y - (cdy / 2 if i % 2 == 1 else 0)))
	var top_rack := rack_y - cdy / 2 - chh
	var c := Vector2(box.position.x + box.size.x / 2, box.position.y + (top_rack - box.position.y) / 2 + 2)
	var R := Vector2(float(box.size.x) * 0.36, float(top_rack - box.position.y) * 0.34)
	var t := fposmod(tr, C2_CYCLE)
	var cyc := int(floorf(tr / C2_CYCLE))
	var kind := cyc % 3
	var old := _clip
	_clip = box.intersection(_clip)
	# the pattern's path, faint, while the units fly it
	var out := 0
	for i in C2_N:
		if t >= 0.2 + 0.12 * float(i) and t < 6.8 + 0.12 * float(i):
			out += 1
	if out > 0:
		for j in 90:
			var q := _c2_pat(kind, 0, float(j) / 90.0 * 6.0, c, R)
			if j % 2 == 0:
				px(roundi(q.x), roundi(q.y), om(0.3 * dim * (1.0 - hv)))
	# the beacon
	var cb := Vector2i(c.round())
	for d in [3, 4, 5]:
		for s: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			px(cb.x + s.x * d, cb.y + s.y * d, ink(0.45 * dim * (1.0 - hv)))
	if int(floorf(tr / 0.8)) % 2 == 0 and hv < 1.0:
		px(cb.x, cb.y, ink(0.8 * dim * (1.0 - hv)))
	for i in C2_N:
		var q := Vector2i(cells[i].round())
		_hex_fill(q.x, q.y, cr - 1, om(0.08 * dim))
		_hex_line(Vector2(q), float(cr), om(0.4 * dim))
	# THE UNITS, a short trail behind each; pointed at, they ring your ship
	var us := clampi(h / 55, 1, 3)
	var er := minf(R.x, R.y) * 0.85 + 4.0
	for i in C2_N:
		for tk in [6, 5, 4, 3, 2, 1, 0]:
			var tt := t - 0.05 * float(tk)
			var p := _c2_pos(kind, i, tt, cells[i], c, R)
			var an := float(i) / float(C2_N) * TAU + (tr - 0.05 * float(tk)) * TAU / 9.0
			var esc := c + Vector2(cos(an), sin(an)) * er
			p = p.lerp(esc, hv)
			var q := Vector2i(p.round())
			if tk == 0:
				_unit(q.x, q.y, us, om(0.95 * dim))
				# each unit reports now and then, its arcs lit
				var per := 2.4 + 1.2 * noise(i, 4)
				var k := exp(-fposmod(tr - noise(i, 5) * per, per) / 0.4)
				if k > 0.3 and p.distance_to(cells[i]) > 3.0:
					_arcs(q.x, q.y, us, om(k * dim), 2 if big else 1)
			elif p.distance_to(cells[i]) > 2.0:
				px(q.x, q.y, om((0.6 - 0.08 * float(tk)) * dim))
	if hv > 0.0:
		g._brackets(Rect2i(cb - Vector2i(4, 4), Vector2i(9, 9)), 3, LabBoard.mixc(LabBoard.BG, LabBoard.HOT, hv))
		g.draw_rect(Rect2(cb.x - 1, cb.y - 1, 3, 3), LabBoard.mixc(LabBoard.BG, LabBoard.HOT, hv))
	_clip = old
	g._brackets(box, 5, ink(0.45 * dim))
	# THE COLUMN
	var cx0 := box.end.x + 8
	var cw := a.end.x - 4 - cx0
	head(cx0, y0 + 2)
	var y := y0 + 18
	var pitch := 12 if big else 9
	if hover:
		_sign_col(cx0, y, cw, pitch, "ESCORT")
		return
	var ttl := "FORMATION TRIAL %d" % (40 + cyc)
	if LabBoard.tw(ttl) > cw:
		ttl = "TRIAL %d" % (40 + cyc)
	text(cx0, y, ttl, ink(0.5))
	y += pitch
	text(cx0, y, fit(String(C2_NAMES[kind]), cw), ink(0.95))
	y += pitch + 4
	var foot := a.end.y - 9
	for e: Array in C2_LOG:
		if t < float(e[0]) or y + 6 > foot - 4:
			continue
		var ts := "%.1f" % float(e[0])
		var tx := cx0 + LabBoard.tw("0.0") + 5
		if tx + LabBoard.tw(String(e[1])) > cx0 + cw:
			tx = cx0
		else:
			text(cx0, y, ts, ink(0.4))
		text(tx, y, String(e[1]), ink(0.75))
		y += pitch
	var home := C2_N - out
	var hs := "UNITS HOME %d OF %d" % [home, C2_N]
	if LabBoard.tw(hs) > cw:
		hs = "HOME %d OF %d" % [home, C2_N]
	text(cx0, foot, hs, ink(0.6))


# ------------------------------------------------------------------ C3: nested housing

const C3_T := 7.0
const C3_F := 0.34
var _c3_u := 0.0
var _c3_last := 1.0


func _c3_level(c: Vector2, rk: float, lv: int, tr: float, al: float) -> void:
	_hex_line(c, rk, om(0.8 * al))
	if rk >= 16.0:
		_hex_line(c, rk - 2.0, om(0.3 * al))
	# the rails, from the middle cell's corners out
	if rk >= 10.0:
		for i in 6:
			var d := Vector2(cos(float(i) * TAU / 6.0), sin(float(i) * TAU / 6.0))
			line(Vector2i((c + d * rk * C3_F).round()), Vector2i((c + d * rk * 0.84).round()), om(0.32 * al), 2)
	# the six cells round it, a unit in each, reporting now and then
	var crr := rk * 0.17
	if crr < 2.0:
		return
	for i in 6:
		var an := TAU / 12.0 + float(i) * TAU / 6.0
		var q := c + Vector2(cos(an), sin(an)) * rk * 0.6
		_hex_line(q, crr, om(0.55 * al))
		if crr >= 4.0:
			var per := 2.6 + 1.6 * noise(lv, i)
			var k := exp(-fposmod(tr - noise(lv, i + 9) * per, per) / 0.5)
			var qi := Vector2i(q.round())
			var s := clampi(int(crr / 4.0), 1, 4)
			_unit(qi.x, qi.y, s, om((0.35 + 0.6 * k) * al))
			if k > 0.35 and crr >= 7.0:
				_arcs(qi.x, qi.y, s, om(k * al), 1)


func _paint_c3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var h := a.size.y
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	var hv := hk(0.5)
	var big := h >= 200
	var m := mini(h - 8, int(float(w) * 0.56))
	var box := Rect2i(x0 + 6, y0 + (h - m) / 2, m, m)
	var c := Vector2(box.get_center())
	var r0 := float(m) * 0.5
	var u := _c3_u
	var depth := int(floorf(u))
	var z := pow(1.0 / C3_F, u - floorf(u))
	var old := _clip
	_clip = box.intersection(_clip)
	for k in range(-2, 7):
		var rk := r0 * z * pow(C3_F, float(k))
		if rk < 1.5:
			break
		if rk * 0.45 > float(m):
			continue
		var al := smoothstep(1.5, 9.0, rk) * dim
		_c3_level(c, rk, depth + k, tr, al)
	# the innermost unit, at the very middle
	var ci := Vector2i(c.round())
	px(ci.x, ci.y, om(0.9 * dim))
	_clip = old
	g._brackets(box, 5, ink(0.45 * dim))
	if hv > 0.0:
		# locked on the middle cell
		var old2 := _clip
		_clip = box.intersection(old2)
		_hex_line(c, r0 * z * C3_F, LabBoard.mixc(LabBoard.BG, cue(), hv))
		_hex_line(c, r0 * z * C3_F + 1.0, LabBoard.mixc(LabBoard.BG, cue(), 0.5 * hv))
		_clip = old2
	# THE COLUMN
	var cx0 := box.end.x + 8
	var cw := a.end.x - 4 - cx0
	head(cx0, y0 + 2)
	var y := y0 + 18
	var pitch := 12 if big else 9
	if hover:
		_sign_col(cx0, y, cw, pitch, "INSPECTOR")
		return
	text(cx0, y, "HOUSING", ink(0.5))
	y += pitch
	text(cx0, y, fit("H-%03d" % (absi(hash(String(g.owner_id) + " housing")) % 900 + 100), cw), ink(0.95))
	y += pitch + 4
	text(cx0, y, "CELLS 7 OF 7", ink(0.7))
	y += pitch
	text(cx0, y, "UNITS 7 OF 7", ink(0.7))
	var ly := a.end.y - 9
	var s := "DEPTH %d" % (depth + 1)
	text(cx0, ly, s, ink(0.6))
	if u - floorf(u) < 0.08 and u > 1.0:
		text(cx0 + LabBoard.tw(s) + 4, ly, "+1", om(1.0))
