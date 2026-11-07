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
		"VER1":
			_paint_ver1()
		"VER2":
			_paint_ver2()
		"VER3":
			_paint_ver3()


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
		"6":
			_g_last = lerpf(_g_last, 1.0 if resting else 0.0, 1.0 - exp(-delta * 3.0))
			_g_rot = fposmod(_g_rot + delta * TAU / G_TURN_S * _g_last, TAU)


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
		["big", "ONE AUGMENT", "PER PART.", "WE ASKED. THE PARTS SAID NO."],
		["big", "DATA IN.", "BETTER PARTS OUT.", "RESULTS MAY VARY. THEY DO VARY."],
		["big", "LIGHTENED PARTS", "MOVE FASTER.", "+2 MANEUVER, -1 HULL, FOR GOOD."],
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


# ================================================================== Verity Ateliers' own three
# (review_lab r6, Nov 7: Jon kept all seven, per owner, "Want more per owner.")
#   VER1  THE HULL REGISTER: the signed hulls, one entry at a time, its maker's
#         signature drawn in under the number
#   VER2  THE SEAM GAUGE: a probe runs along one hull seam, magnified, and
#         plots how flush the two panels sit
#   VER3  THE COMMISSION: a new hull drawn in hairlines, then signed

var _vr_said := false


## Verity's gold, lifted a little so it reads on the dark glass.
func _vr_gold(a: float) -> Color:
	var mk := DB.manufacturer_colour(g.owner_id) if DB.manufacturers.has(g.owner_id) else g.tint
	return LabBoard.mixc(LabBoard.BG, LabBoard.mixc(mk, LabBoard.WHITE, 0.3), clampf(a, 0.0, 1.0))


## The house rule: two gold rules and the hairline between them (its mark, laid flat).
func _vr_rules(x: int, y: int, w: int, dim: float) -> void:
	for xx in range(x, x + w):
		px(xx, y, _vr_gold(0.8 * dim))
		if posmod(xx, 2) == 0:
			px(xx, y + 2, ink(0.4 * dim))
		px(xx, y + 4, _vr_gold(0.8 * dim))


## The header: the mark and the owner, a title, a word on the right if it fits, and the rule.
func _vr_head(a: Rect2i, title: String, right: String, dim: float) -> void:
	if not _vr_said:
		_vr_said = true
		print("FILM verity area %s" % a)
	var hx := head(a.position.x + 4, a.position.y + 3, title)
	if right != "":
		var rw := say_w(right)
		if a.end.x - 6 - rw > hx + 10:
			say(a.end.x - 6 - rw, a.position.y + 6, right, ink(0.5))
	_vr_rules(a.position.x + 4, a.position.y + 17, a.size.x - 8, dim)


## Words with " · " cut at a dot until they fit, then cut short.
func _vr_fit(s: String, wmax: int) -> String:
	while say_w(s) > wmax and s.contains(" · "):
		s = s.left(s.rfind(" · "))
	return s if say_w(s) <= wmax else fit(s, wmax)


## The two rows at the foot: at rest what the saver says there; pointed at, the sign-in.
func _vr_foot(a: Rect2i, l1: String, l2: String, c2: Color) -> void:
	var x := a.position.x + 8
	var ly := a.end.y - 17
	var wmax := a.size.x - 16
	g.draw_rect(Rect2(a.position.x + 4, ly - 5, a.size.x - 8, 1), ink(0.25))
	if g.state == LabLogin.LOGO:
		if l1 != "":
			say(x, ly, _vr_fit(l1, wmax), ink(0.55))
		if l2 != "":
			say(x, ly + 8, _vr_fit(l2, wmax), c2)
		return
	say(x, ly, "THIS TERMINAL", ink(0.55))
	var s := "PILOT %s · CLICK TO SIGN IN" % ship()
	if say_w(s) > wmax:
		s = "PILOT %s · SIGN IN" % ship()
	if g.state == LabLogin.SIGNING:
		s = "PILOT %s · SIGNING IN" % ship()
	say(x, ly + 8, s, ink(0.9) if g.state == LabLogin.SIGNING else cue())


## A signature: one hairline stroke, `k` of it drawn.
func _vr_sign(x: int, y: int, wd: int, k: float, c: Color, sd: int) -> void:
	var n := int(float(wd) * clampf(k, 0.0, 1.0))
	var ph := noise(sd, 4) * 3.0
	var prev := Vector2i(x, y)
	for i in range(1, n + 1):
		var f := float(i)
		var dy := 2.4 * sin(f * 0.62 + ph) * (1.0 - f / float(wd + 12)) + 1.2 * sin(f * 1.45 + ph * 2.0)
		var p := Vector2i(x + i, y + roundi(dy))
		line(prev, p, c)
		prev = p


# ------------------------------------------------------------------ VER1: the hull register

const VR1_EVERY := 4.0
const VR1_SLIDE := 0.4
const VR1_SIGN := 1.2
## Number, name, year made, times back for repair, now.
const VR1_BOOK := [
	[31, "MERIDIAN", 14, 22, "IN SERVICE"],
	[58, "LONG VIGIL", 27, 19, "IN SERVICE"],
	[102, "HALCYON", 51, 31, "IN THE YARD"],
	[117, "PATIENCE", 58, 12, "IN SERVICE"],
	[164, "ASTER PROVOST", 80, 9, "LOST"],
	[189, "STILL HOUR", 94, 15, "IN SERVICE"],
	[214, "THE ENDURING", 106, 14, "IN SERVICE"],
	[233, "QUIET ORBIT", 117, 8, "IN SERVICE"],
	[276, "LANTERN", 139, 11, "IN THE YARD"],
	[301, "FAIR WITNESS", 152, 6, "IN SERVICE"],
	[342, "KEEPSAKE", 171, 4, "IN SERVICE"],
	[386, "SLOW LIGHT", 194, 1, "IN SERVICE"],
]


func _paint_ver1() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	var big := a.size.y >= 140
	_vr_head(a, " HULL REGISTER", "SIGNED HULLS", dim)
	var ft := _s3_hold if (hover and _s3_hold >= 0.0) else tr
	var k := int(floorf(ft / VR1_EVERY))
	var into := fposmod(ft, VR1_EVERY)
	var n := VR1_BOOK.size()
	var cur: Array = VR1_BOOK[posmod(k, n)]
	# THE ENTRY: its number large, the maker's signature drawn in under it; its
	# name, when it was made, how often it came back, and where it is now
	var cy := y0 + 27
	var num := "NO. %04d" % int(cur[0])
	text(x0 + 8, cy, num, ink(0.95), 16)
	var nw := LabBoard.tw(num, 16)
	_vr_sign(x0 + 9, cy + 16, mini(nw - 4, 44), into / VR1_SIGN if not hover else 1.0, _vr_gold(0.95 * dim), int(cur[0]))
	var cx := x0 + 8 + nw + 10
	var cw := a.end.x - 6 - cx
	text(cx, cy, fit(String(cur[1]), cw), ink(1.0))
	say(cx, cy + 8, _vr_fit("MADE YEAR %d · BACK %d TIMES" % [int(cur[2]), int(cur[3])], cw), ink(0.6))
	var st := String(cur[4])
	if st == "LOST":
		st = "LOST YEAR 141 · RECORD KEPT"
	say(cx, cy + 16, _vr_fit(st, cw), _vr_gold(1.0) if st == "IN SERVICE" else ink(0.8))
	# THE BOOK: the entry before and the ones after, the entry in hand lit;
	# the page moves up one line as the next is read
	var top := cy + 27
	var pitch := 9
	g.draw_rect(Rect2(x0 + 4, top - 4, w - 8, 1), ink(0.25))
	var c_no := x0 + 10
	var c_name := x0 + 38
	var c_made := x0 + int(float(w) * 0.52)
	if big:
		text(c_no, top, "NO.", ink(0.4))
		text(c_name, top, "HULL", ink(0.4))
		text(c_made, top, "MADE", ink(0.4))
		var sw := LabBoard.tw("NOW")
		text(a.end.x - 6 - sw, top, "NOW", ink(0.4))
		top += pitch + 1
	var bottom := a.end.y - 23
	var slide := 0.0
	if k > 0 and into < VR1_SLIDE:
		var e := into / VR1_SLIDE
		slide = 1.0 - (1.0 - pow(1.0 - e, 3.0))
	var rows := (bottom - top) / pitch + 2
	for r in range(0, rows + 1):
		var yy := top + roundi((float(r) - 1.0 + slide) * float(pitch))
		if yy < top or yy + 6 > bottom:
			continue
		var it: Array = VR1_BOOK[posmod(k + r - 1, n)]
		var lit := r == 1
		var last := yy + pitch + 6 > bottom
		var c := ink(1.0 if lit else (0.32 if last else 0.5))
		if lit:
			g.draw_rect(Rect2(x0 + 5, yy - 1, 2, 7), _vr_gold(dim))
		text(c_no, yy, "%04d" % int(it[0]), c)
		var stw := LabBoard.tw(String(it[4]))
		var st_x := a.end.x - 6 - stw
		var made := "YEAR %d" % int(it[2])
		# (the year only where the glass is wide enough for every row to have it)
		var show_made := big and c_made + LabBoard.tw(made) + 6 <= st_x
		var name_end := (c_made if show_made else st_x) - 6
		text(c_name, yy, fit(String(it[1]), name_end - c_name), c)
		if show_made:
			text(c_made, yy, made, c)
		text(st_x, yy, String(it[4]), c)
	_vr_foot(a, "397 HULLS MADE · 391 IN SERVICE · NONE REPLACED", "WE REPAIR EVERY HULL WE MADE.", _vr_gold(1.0))


# ------------------------------------------------------------------ VER2: the seam gauge

const VR2_PASS := 5.5
const VR2_BACK := 1.3


func _paint_ver2() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	_vr_head(a, " SEAM GAUGE", "HULL NO. 0214", dim)
	var ft := _s3_hold if (hover and _s3_hold >= 0.0) else tr
	var cyc := VR2_PASS + VR2_BACK
	var k := int(floorf(ft / cyc))
	var into := fposmod(ft, cyc)
	var panel := 7 + k
	var top := y0 + 26
	var bot := a.end.y - 26
	var vh := maxi(18, int(float(bot - top) * 0.46))
	var view := Rect2i(x0 + 6, top, w - 12, vh)
	var graph := Rect2i(x0 + 6, top + vh + 5, w - 12, bot - top - vh - 5)
	# the magnification, top right of the view, kept clear
	var mag := "4000 X"
	var mw := LabBoard.tw(mag)
	text(view.end.x - mw - 1, view.position.y + 1, mag, ink(0.45))
	_keep.append(Rect2i(view.end.x - mw - 3, view.position.y - 1, mw + 4, 9))
	# THE SEAM: two panels flush, the hairline between, a flush fastener each side
	var sx := view.position.x + view.size.x / 2
	var sy := view.position.y + maxi(9, vh * 2 / 5)
	var fasts := [0.2, 0.34, 0.66, 0.8]
	for x in range(view.position.x, view.end.x):
		if x == sx or x == sx - 1:
			continue
		var s := sy + (1 if x > sx else 0)
		var edge := x == sx - 2 or x == sx + 1
		px(x, s, ink(0.9 * dim))
		for y in range(s + 1, view.end.y):
			if edge:
				px(x, y, ink(0.5 * dim))
			elif posmod(x + y, 4) == 0:
				px(x, y, ink(0.14 * dim))
	for f: float in fasts:
		var fx := view.position.x + int(f * float(view.size.x))
		var s := sy + (1 if fx > sx else 0)
		line(Vector2i(fx - 3, s + 1), Vector2i(fx - 1, s + 3), ink(0.5 * dim))
		line(Vector2i(fx + 3, s + 1), Vector2i(fx + 1, s + 3), ink(0.5 * dim))
		line(Vector2i(fx - 1, s + 4), Vector2i(fx - 1, mini(view.end.y - 1, s + 11)), ink(0.4 * dim))
		line(Vector2i(fx + 1, s + 4), Vector2i(fx + 1, mini(view.end.y - 1, s + 11)), ink(0.4 * dim))
	# THE PROBE: along the surface, then lifted and back for the next panel;
	# pointed at, it lifts and waits
	var x_a := view.position.x + 6
	var x_b := view.end.x - 7
	var pxx := x_a
	var lift := 0.0
	if into < VR2_PASS:
		var e := into / VR2_PASS
		pxx = x_a + int(e * float(x_b - x_a))
	else:
		var e := (into - VR2_PASS) / VR2_BACK
		e = e * e * (3.0 - 2.0 * e)
		pxx = x_b - int(e * float(x_b - x_a))
		lift = 4.0
	lift = maxf(lift, 4.0 * hk(0.4))
	var tip := sy + (1 if pxx > sx else 0) - 1 - int(lift)
	if (pxx == sx or pxx == sx - 1) and lift < 1.0:
		tip += 2
	var head_y := view.position.y + 1
	g.draw_rect(Rect2(pxx - 2, head_y, 5, 3), _vr_gold(0.9 * dim))
	line(Vector2i(pxx, head_y + 3), Vector2i(pxx, tip - 2), ink(0.75 * dim))
	px(pxx - 1, tip - 1, ink(0.85 * dim))
	px(pxx + 1, tip - 1, ink(0.85 * dim))
	px(pxx, tip - 1, ink(0.95 * dim))
	px(pxx, tip, LabBoard.mixc(ink(1.0), LabBoard.WHITE, 0.4))
	# THE TRACE: how far the surface strays from flat, between the limits; this
	# pass's line drawn as far as the probe has come, the last pass's under it
	var gm := graph.position.y + graph.size.y / 2
	var lim := maxi(4, graph.size.y / 2 - 2)
	for x in range(graph.position.x, graph.end.x):
		if posmod(x, 3) == 0:
			px(x, gm - lim, _vr_gold(0.55 * dim))
			px(x, gm + lim, _vr_gold(0.55 * dim))
		if posmod(x, 6) == 0:
			px(x, gm, ink(0.22 * dim))
	line(Vector2i(graph.position.x, gm - lim - 1), Vector2i(graph.position.x, gm + lim + 1), ink(0.3 * dim))
	var upto := pxx if into < VR2_PASS else graph.end.x - 1
	for pass_i: int in [k - 1, k]:
		if pass_i < 0:
			continue
		var bright := pass_i == k
		var end_x := upto if bright else graph.end.x - 1
		if not bright and into >= VR2_PASS:
			continue
		var prev := Vector2i(-1, -1)
		for x in range(graph.position.x + 1, end_x + 1):
			# a smooth wander (noise eased between every 5th px), not a scribble
			var fx := float(x) / 5.0
			var i0 := int(floorf(fx))
			var fr := smoothstep(0.0, 1.0, fx - float(i0))
			var wv := lerpf(noise(i0, pass_i * 31 + 3), noise(i0 + 1, pass_i * 31 + 3), fr)
			var d := (wv - 0.5) * float(lim) * 0.6
			d += sin(float(x) * 0.09 + float(pass_i)) * float(lim) * 0.15
			if x > sx:
				d += float(lim) * 0.12
			if absi(x - sx) <= 1:
				d = float(lim) * 0.62
			var p := Vector2i(x, gm + roundi(d))
			if prev.x >= 0:
				line(prev, p, ink((0.9 if bright else 0.3) * dim))
			prev = p
	var gap := 0.0018 + 0.0006 * noise(panel, 3)
	var stp := 0.0008 + 0.0004 * noise(panel, 5)
	var done := into >= VR2_PASS
	_vr_foot(a, "GAP %.4f MM · STEP %.4f MM · LIMIT 0.0040 MM" % [gap, stp],
		"PANEL %d OF 212 · %s" % [panel, "IN LIMIT" if done else "MEASURING"], _vr_gold(1.0) if done else ink(0.8))


# ------------------------------------------------------------------ VER3: the commission

const VR3_CYCLE := 15.0
## Where the clock starts in the cycle (so a lab that has just come on is mid-drawing).
const VR3_OFFSET := 6.0
const VR3_LINES := 2.4
const VR3_PEN := 9.0
const VR3_STAMP := 9.6
const VR3_HOLD := 13.8


## The hull's half-height at `u` along it (tail 0, nose 1).
func _vr3_t(u: float, hh: float, aa: float, c: float) -> float:
	return hh * pow(maxf(0.0, sin(PI * (c + (1.0 - c) * pow(clampf(u, 0.0, 1.0), aa)))), 0.6)


func _paint_ver3() -> void:
	var a := g.area()
	var x0 := a.position.x
	var y0 := a.position.y
	var w := a.size.x
	var tr := rest_t()
	var dim := fade()
	var hover := g.state != LabLogin.LOGO
	_vr_head(a, " COMMISSIONS", "BY APPOINTMENT", dim)
	var ft := (_s3_hold if (hover and _s3_hold >= 0.0) else tr) + VR3_OFFSET
	var kc := int(floorf(ft / VR3_CYCLE))
	var p := fposmod(ft, VR3_CYCLE)
	var no := 398 + kc
	var dd := dim
	if p > VR3_HOLD:
		dd *= 1.0 - clampf((p - VR3_HOLD) / (VR3_CYCLE - VR3_HOLD), 0.0, 1.0)
	# this commission's lines
	var aa := 0.55 + 0.3 * noise(no, 1)
	var rb := 0.6 + 0.2 * noise(no, 2)
	var fh := 0.7 + 0.4 * noise(no, 3)
	var c := 0.1 + 0.08 * noise(no, 4)
	var metres := 140 + int(90.0 * noise(no, 5))
	var body := Rect2i(x0 + 8, y0 + 25, w - 16, a.end.y - 24 - (y0 + 25))
	var ll := int(float(body.size.x) * 0.8)
	var hh := minf(float(body.size.y - 15) / (1.0 + fh + rb + 0.15), float(ll) * 0.13)
	var stack := hh * (1.0 + fh + rb) + 13.0
	var cy := body.position.y + int((float(body.size.y) - stack) / 2.0 + hh * (1.0 + fh))
	var xl := body.position.x + (body.size.x - ll) / 2
	# THE STAMP, top right, kept clear; it goes on once the hull is drawn
	var sg := "SIGNED"
	var sgw := LabBoard.tw(sg)
	var stamp := Rect2i(body.end.x - 13 - sgw - 4, body.position.y - 1, sgw + 4 + 13, 13)
	_keep.append(stamp)
	if p >= VR3_STAMP and dd > 0.3:
		g._mark(body.end.x - 6, body.position.y + 5, 11, 1.0)
		text(body.end.x - 13 - sgw - 2, body.position.y + 3, sg, _vr_gold(1.0))
	# THE SETTING OUT: the centre line, the ends, the length, ruled in first
	var yd := cy + int(hh * rb) + 5
	var dim_s := "LENGTH %d M" % metres
	var dsw := LabBoard.tw(dim_s)
	var dsx := xl + (ll - dsw) / 2
	var drect := Rect2i(dsx - 3, yd + 3, dsw + 6, 8)
	if p >= VR3_LINES - 0.4:
		_keep.append(drect)
	var k1 := clampf(p / 0.8, 0.0, 1.0)
	var k2 := clampf((p - 0.8) / 0.6, 0.0, 1.0)
	var k3 := clampf((p - 1.4) / 0.6, 0.0, 1.0)
	var cl_a := xl - 6
	var cl_b := cl_a + int(k1 * float(ll + 12))
	for x in range(cl_a, cl_b):
		if posmod(x - cl_a, 8) < 4 or posmod(x - cl_a, 8) == 6:
			px(x, cy, ink(0.3 * dd))
	var top_y := cy - int(hh * (1.0 + fh)) - 1
	for xe: int in [xl, xl + ll]:
		var yb := top_y + int(k2 * float(yd + 2 - top_y))
		line(Vector2i(xe, top_y), Vector2i(xe, yb), ink(0.28 * dd), 2)
	if k3 > 0.0:
		var xb := xl + int(k3 * float(ll))
		line(Vector2i(xl, yd), Vector2i(xb, yd), ink(0.45 * dd))
		line(Vector2i(xl, yd), Vector2i(xl + 2, yd - 2), ink(0.45 * dd))
		line(Vector2i(xl, yd), Vector2i(xl + 2, yd + 2), ink(0.45 * dd))
		if k3 >= 1.0:
			line(Vector2i(xl + ll, yd), Vector2i(xl + ll - 2, yd - 2), ink(0.45 * dd))
			line(Vector2i(xl + ll, yd), Vector2i(xl + ll - 2, yd + 2), ink(0.45 * dd))
	if p >= VR3_LINES - 0.4 and dd > 0.3:
		text(dsx, yd + 5, dim_s, ink(0.55))
	# THE HULL: one hairline, drawn by the pen from the tail along the top to
	# the nose and back underneath, then the fin
	var segs: Array[PackedVector2Array] = []
	var outline := PackedVector2Array()
	var t0 := _vr3_t(0.0, hh, aa, c)
	outline.append(Vector2(xl, cy - t0))
	for i in range(0, ll + 1):
		var u := float(i) / float(ll)
		outline.append(Vector2(xl + i, cy - _vr3_t(u, hh, aa, c)))
	for i in range(ll, -1, -1):
		var u := float(i) / float(ll)
		outline.append(Vector2(xl + i, cy + _vr3_t(u, hh, aa, c) * rb))
	outline.append(Vector2(xl, cy - t0))
	segs.append(outline)
	var fin := PackedVector2Array()
	# a swept fin: the leading edge up and back, a short flat top, the trailing edge down
	var tip_y := cy - _vr3_t(0.08, hh, aa, c) - hh * fh
	fin.append(Vector2(xl + 0.3 * ll, cy - _vr3_t(0.3, hh, aa, c)))
	fin.append(Vector2(xl + 0.1 * ll, tip_y))
	fin.append(Vector2(xl + 0.04 * ll, tip_y))
	fin.append(Vector2(xl + 0.14 * ll, cy - _vr3_t(0.14, hh, aa, c)))
	segs.append(fin)
	var total := 0.0
	for sgm: PackedVector2Array in segs:
		for i in range(1, sgm.size()):
			total += sgm[i].distance_to(sgm[i - 1])
	var kp := clampf((p - VR3_LINES) / (VR3_PEN - VR3_LINES), 0.0, 1.0)
	var left := total * kp
	var pen := Vector2i(-1, -1)
	for sgm: PackedVector2Array in segs:
		for i in range(1, sgm.size()):
			if left <= 0.0:
				break
			var a0 := sgm[i - 1]
			var b0 := sgm[i]
			var dl := a0.distance_to(b0)
			var b1 := b0 if left >= dl else a0.lerp(b0, left / dl)
			left -= dl
			line(Vector2i(roundi(a0.x), roundi(a0.y)), Vector2i(roundi(b1.x), roundi(b1.y)), ink(0.95 * dd))
			pen = Vector2i(roundi(b1.x), roundi(b1.y))
	# one seam, after the pen: a hull of few seams
	if p >= VR3_PEN:
		var xs := xl + int(0.52 * float(ll))
		var us := 0.52
		line(Vector2i(xs, cy - int(_vr3_t(us, hh, aa, c)) + 2), Vector2i(xs, cy + int(_vr3_t(us, hh, aa, c) * rb) - 2), ink(0.35 * dd), 2)
	if kp > 0.0 and kp < 1.0 and pen.x >= 0:
		g.draw_rect(Rect2(pen.x - 1, pen.y - 1, 2, 2), _vr_gold(dim))
	var l2 := "DRAWING THE HULL"
	var c2 := ink(0.8)
	if p < VR3_LINES:
		l2 = "SETTING OUT THE LINES"
	elif p >= VR3_STAMP:
		l2 = "SIGNED · ENTERED IN THE REGISTER"
		c2 = _vr_gold(1.0)
	_vr_foot(a, "COMMISSION NO. %04d · MADE TO ORDER" % no, l2, c2)
