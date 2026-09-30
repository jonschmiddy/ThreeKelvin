class_name YardDeal
extends RefCounted

## The deal, on each level's own TV at the bottom right of the Yard (the Yard
## Drones page's `drawTerminal`, `groundTV`, `LIGHTS`, `signal`, `sagWithBulb`).
##
## JON'S PICK FOR EACH LEVEL, lit and misbehaving the way that level's lab does:
## its lamps are its own painted pixels, brightened and dimmed by the lab's
## clock (`LabScene._weights`, ported); its glass warms, then the deal scans in
## -- what they ask, what your ship is worth to them, and what leaves your
## account, over TAKE IT. Then the lab's screen trick: unclaimed's screen
## failing with its bulb, the outpost losing its signal every 2.6 s and the
## settlement every 14, the city's sweep, the gold light running round the
## capital's glass.
##
## THE BOX TAKES THE HALL'S LIGHT as it stands when the TV is fully on (Jon:
## "the boxes shouldn't be fully dark... just the screen"): only its glass and
## lamps follow the power-on. It stands on the floor, with a top, a contact
## shadow and its foot in the polish, and its lamps light the floor in front
## of it ("it looked pasted in").
##
## THE GLASS is composed in its own small viewport every tick, as the page
## composed it in a canvas of its own: the bands a bad signal slips are pieces
## of that picture.

const LID := 13
const DEAL_CAP := Color("#8fa3ba")
const DEAL_VAL := Color("#c3d2e2")
const DEAL_PRICE := Color("#ffbe55")
const DEAL_RULE := Color("#2c3b4d")
const AMBER := Color("#f0a030")
const POOR := Color("#5a6470")
const SHADOW := Color(4.0 / 255.0, 6.0 / 255.0, 10.0 / 255.0, 0.75)

var scene: YardScene
var level := ""
var T: Dictionary = {}
var X := 0.0
var Y := 0.0
var IW := 0
var IH := 0
var GW := 0
var GH := 0
var gx0 := 0
var gy0 := 0
var tint := Color(1, 1, 1)
var hover_take := false
## The viewport the glass is composed in, and what draws into it.
var vp: SubViewport
var _gl: _Glass
var _tex := {}
## Each lamp on the TV, as pictures: its lit pixels, its outline, and (the
## unclaimed bulb) its unlit glass.
var _lamps: Array = []
var _halos := {}
var bulb_was := -1.0
## What its lamps put at its own feet, now and at full (the page's `SPILLAT`).
var spill_now := PackedFloat32Array([0, 0, 0, 0, 0])
var spill_full := PackedFloat32Array([0, 0, 0, 0, 0])
var glow := 0.0
var reveal := 0.0
var W8: Dictionary = {}


func _init(s: YardScene) -> void:
	scene = s
	level = scene.level
	T = ((YardScene.doc().get("tvs", {}) as Dictionary).get(level, {}) as Dictionary)
	var sz: Array = T.get("size", [160, 160])
	IW = int(sz[0])
	IH = int(sz[1])
	var g: Array = T.get("glass", [0, 0, 10, 10])
	gx0 = int(g[0])
	gy0 = int(g[1])
	GW = int(T.get("GW", 10))
	GH = int(T.get("GH", 10))
	var tn: Array = T.get("tint", [255, 255, 255])
	tint = Color8(int(tn[0]), int(tn[1]), int(tn[2]))
	X = 760.0 - float(IW)
	Y = float(scene.dial.get("tv", 475)) - float(IH)
	for k in ["art", "dim", "glowL"]:
		if T.has(k):
			_tex[k] = scene.tex(String(T[k]))
	_tex["body"] = scene.tex("tv_%s.png" % level)
	_tex["lid"] = scene.tex("tv_%s_lid.png" % level)
	_tex["ao"] = scene.tex("tv_%s_ao.png" % level)
	for L: Dictionary in T.get("lights", []):
		_lamps.append(_lamp_pictures(L))
	vp = SubViewport.new()
	vp.size = Vector2i(GW, GH)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_gl = _Glass.new()
	_gl.deal = self
	_gl.size = Vector2(GW, GH)
	vp.add_child(_gl)
	scene.add_child(vp)


## A lamp's pixels as pictures: lit, outline as painted, and unlit glass.
func _lamp_pictures(L: Dictionary) -> Dictionary:
	var lit := Image.create(IW, IH, false, Image.FORMAT_RGBA8)
	var line := Image.create(IW, IH, false, Image.FORMAT_RGBA8)
	var off := Image.create(IW, IH, false, Image.FORMAT_RGBA8)
	var any_line := false
	var glass := String(L.get("off", "")) == "glass"
	var xs: Array[int] = []
	var ys: Array[int] = []
	for q: Array in L.get("px", []):
		var x := int(q[0])
		var y := int(q[1])
		if x < 0 or y < 0 or x >= IW or y >= IH:
			continue
		var c := Color8(int(q[2]), int(q[3]), int(q[4]))
		if int(q[5]) == 0:
			line.set_pixel(x, y, c)
			any_line = true
			continue
		lit.set_pixel(x, y, c)
		xs.append(x)
		ys.append(y)
		if glass:
			var o: Array = q[6] if q.size() > 6 else [int(q[2]) * 0.4, int(q[3]) * 0.4, int(q[4]) * 0.4]
			off.set_pixel(x, y, Color(float(o[0]) / 255.0, float(o[1]) / 255.0, float(o[2]) / 255.0))
	var out := {"L": L, "lit": ImageTexture.create_from_image(lit), "glass": glass}
	if any_line:
		out["line"] = ImageTexture.create_from_image(line)
	if glass:
		out["off"] = ImageTexture.create_from_image(off)
	if L.has("coneImg"):
		out["cone"] = scene.tex(String(L["coneImg"]))
	if L.has("halo"):
		out["halo"] = _halo_picture(L["halo"])
	if not xs.is_empty():
		xs.sort()
		ys.sort()
		out["bx0"] = xs[0]
		out["bx1"] = xs[xs.size() - 1]
		out["by0"] = ys[0]
		out["by1"] = ys[ys.size() - 1]
	return out


## A soft glow round a lamp on its panel, in steps (the page's halo), at full.
func _halo_picture(H: Dictionary) -> ImageTexture:
	var r := int(H.get("r", 9))
	var img := Image.create(2 * r + 1, 2 * r + 1, false, Image.FORMAT_RGBA8)
	var col: Array = H.get("col", [255, 255, 255])
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var dd := sqrt(float(dx * dx + dy * dy)) / float(r)
			if dd >= 1.0:
				continue
			var f := floorf((1.0 - dd) * 3.0 + float((dx + dy) & 1) * 0.5) / 3.0
			if f <= 0.0:
				continue
			img.set_pixel(dx + r, dy + r, Color(float(col[0]) / 255.0, float(col[1]) / 255.0, float(col[2]) / 255.0, float(H.get("a", 0.5)) * f))
	return ImageTexture.create_from_image(img)


func release() -> void:
	if vp != null and is_instance_valid(vp):
		vp.queue_free()


# ------------------------------------------------------------------ the lab's clocks

static func flutter(t: float, s: float) -> float:
	return 0.9 + 0.1 * (sin(t * 7.3 + s) * 0.5 + sin(t * 13.1 + s * 2.0) * 0.3 + sin(t * 2.1 + s * 3.0) * 0.2)


## Each level's lamps, as its lab's clock has them (the page's `LIGHTS`).
func lights(t: float, tb: float) -> Dictionary:
	match level:
		"unclaimed":
			var n := int(floorf(tb * 30.0 + 0.5))
			var on := 1.0 if n >= 36 else (1.0 if n in [9, 10, 18, 19, 30, 31, 33, 34] else (0.04 if n >= 9 else 0.0))
			return {"bulb": on * (YardLight.loose(t, 1.3) if tb > 3.0 else 1.0) * flutter(t, 0.4)}
		"outpost":
			var st := 0.0
			if tb >= 1.0:
				if tb < 1.7:
					st = 1.0 if int(floorf((tb - 1.0) / 0.12)) % 2 == 1 else 0.1
				else:
					st = 0.5 - 0.5 * cos(t * TAU / 2.6)
			return {"status": st}
		"settlement":
			var at := 0.3
			return {"lamp": YardLight.smooth(at, at + 0.45, tb) * (1.0 + 0.12 * sin((tb - at) * 9.0) * exp(-maxf(0.0, tb - at) * 2.0)) * flutter(t, 3.1)}
		"city":
			return {"hood": YardLight.strikes(tb, 0.3, 0.55, 1.3) * (0.9 + 0.1 * sin(t * TAU / 4.5)),
				"edge": (0.0 if tb < 2.3 else minf(1.0, (tb - 2.3) / 0.1)) * (0.95 + 0.05 * sin(t * 3.3))}
		"capital":
			return {"bar": YardLight.strikes(tb, 0.3, 0.6, 3.3) * (0.96 + 0.04 * sin(t * TAU / 5.0)),
				"tanks": YardLight.smooth(1.5, 2.3, tb) * (0.9 + 0.1 * sin(t * TAU / 3.7))}
	return {}


## Bad signal: bands slip and a line of snow flashes (the page's `signal`).
func bad_signal(t: float, s: Dictionary) -> Dictionary:
	var n := GH >> 1
	var slot := float(s.get("every", 5.2))
	var k := floorf(t / slot)
	var dur := float(s.get("dur", 0.24))
	var start := k * slot + slot * (0.12 + 0.5 * YardLight.hash1(k * 1.7 + 0.3))
	if t < start or t >= start + dur:
		return {}
	var f := int(floorf((t - start) * 30.0))
	var steps := [2, 4, -2, 2, 0, -4, 2, -2]
	var big := float(s.get("shift", 4)) / 4.0
	var bands: Array = []
	for b in mini(int(s.get("bands", 2)), 4):
		var bh := 2 * (2 + int(floorf(YardLight.hash1(k * 5.5 + float(b) * 1.9) * float(s.get("tall", 4)))))
		var by := 2 * int(floorf(YardLight.hash1(k * 3.1 + float(b) * 7.3) * (float(n) - float(bh) / 2.0)))
		var sh := int(floorf(float(steps[(f + b * 3) % 8]) * big / 2.0 + 0.5)) * 2
		var src := by
		if bool(s.get("tear", false)) and b == 0:
			src = 2 * int(floorf(YardLight.hash1(k * 2.3 + floorf(float(f) / 2.0) * 0.1) * (float(n) - float(bh) / 2.0)))
		if sh != 0 or src != by:
			bands.append([by, bh, sh, src])
	var snow: Array = []
	if f % 2 == 0:
		for s2 in mini(int(s.get("snow", 1)), 3):
			snow.append(2 * int(floorf(YardLight.hash1(k * 9.1 + float(f) * 0.77 + float(s2) * 4.1) * float(n))))
	return {"bands": bands, "snow": snow, "jolt": 2.0 if bool(s.get("jolt", false)) and f % 3 == 1 else 0.0, "f": f, "k": k}


## Failing: the screen sags with the bulb, then comes back with a flash and a
## jolt (the page's `sagWithBulb`).
func sag_with_bulb(t: float, s: Dictionary) -> Dictionary:
	var seed := float(s.get("bulbSeed", 1.3))
	var v := YardLight.loose(t, seed)
	var v1 := YardLight.loose(t - 1.0 / 30.0, seed)
	var v2 := YardLight.loose(t - 2.0 / 30.0, seed)
	if v >= 0.5 and v1 >= 0.5 and v2 >= 0.5:
		return {}
	if s.has("sagEvery"):
		var k := floorf((t + seed) / 3.2)
		var every := float(s["sagEvery"])
		if floorf(YardLight.blink_at(k, seed) / every) == floorf(YardLight.blink_at(k - 1.0, seed) / every):
			return {}
	if v < 0.5:
		return {"sag": 1.0 - float(s.get("sag", 0.55))}
	return {"jolt": float(s.get("joltPx", 2)), "flash": (0.16 if v1 < 0.5 else 0.07) * float(s.get("flash", 0.6))}


# ------------------------------------------------------------------ this tick

## Its lamps' weights and what they light, before anything is drawn (the
## page's `lightDynamic`, the TV's part): a stepped pool on the floor in front
## of it for each lamp, and what they put at its own feet.
func light_up(t: float, tb: float) -> void:
	W8 = lights(t, tb)
	var sc: Array = T.get("screen", [2.4, 2.9])
	glow = YardLight.smooth(float(sc[0]), float(sc[1]), tb)
	var rv: Array = T.get("reveal", [2.7, 3.3])
	reveal = clampf((tb - float(rv[0])) / (float(rv[1]) - float(rv[0])), 0.0, 1.0)
	var feet := float(scene.dial.get("tv", 475))
	var sx := X + float(IW >> 1)
	var sy := feet
	spill_now = PackedFloat32Array([0, 0, 0, 0, 0])
	spill_full = PackedFloat32Array([0, 0, 0, 0, 0])
	for L: Dictionary in T.get("spill", []):
		var key := String(L.get("key", ""))
		var w := glow if key == "screen" else clampf(float(W8.get(key, 1.0)), 0.0, 1.1)
		var st := floorf(w * 4.0 + 0.5) / 4.0
		var c: Array = L.get("col", [255, 255, 255])
		var col := Color(float(c[0]) / 255.0, float(c[1]) / 255.0, float(c[2]) / 255.0)
		var cx := X + float(L.get("cx", 0))
		var cy := feet + 2.0
		var rx := float(L.get("rx", 40))
		var ry := maxf(12.0, float(L.get("ry", 6)) * 2.4)
		var k := float(L.get("k", 0.3))
		if st > 0.0:
			scene.light.dyn.append([cx, cy, rx, ry, 2.0 * k * st, col, w / st])
		var dd := pow((sx - cx) / rx, 2.0) + pow((sy - cy) / ry, 2.0)
		var f := pow(1.0 - dd, 1.6) if dd < 1.0 else 0.0
		if f > 0.0:
			spill_now[0] += 2.0 * k * st * f * col.r
			spill_now[1] += 2.0 * k * st * f * col.g
			spill_now[2] += 2.0 * k * st * f * col.b
			spill_full[0] += 2.0 * k * f * col.r
			spill_full[1] += 2.0 * k * f * col.g
			spill_full[2] += 2.0 * k * f * col.b
			if st > 0.0:
				spill_now[3] += 2.0 * k * st * f
				spill_now[4] += 2.0 * k * f * w
			spill_full[3] += 2.0 * k * f
			spill_full[4] += 2.0 * k * f


## Where it stands on the floor: its shadow and its foot in the polish, under
## the light (the page's `groundTV`).
func draw_ground(P: YardPaint) -> void:
	var feet := float(scene.dial.get("tv", 475))
	var w := float(IW)
	P.use(YardPaint.PLAIN)
	scene.shade(P, X + w / 2.0 - 6.0, feet - 2.0, w * 0.6, 12.0, 0.2)
	scene.shade(P, X + w / 2.0, feet, w * 0.54, 6.0, 0.5)
	P.use(YardPaint.MIRROR)
	P.mirror(_tex["body"], Rect2(0, 0, IW, IH), X, feet, 0.22, Color(0.8, 0.8, 0.82), false)


## The TV itself, over the light (the page's `drawTerminal`).
func draw(P: YardPaint, t: float, tb: float) -> void:
	var feet := float(scene.dial.get("tv", 475))
	Y = feet - float(IH)
	var GX := X + float(gx0)
	var GY := Y + float(gy0)
	var M := scene.light.box_light(X + float(IW >> 1), feet, spill_now, spill_full)
	var Mq := YardScene.quant(M)
	P.use(YardPaint.PLAIN)
	P.tex(_tex["lid"], Vector2(X, Y - LID), Rect2(), Mq)
	P.tex(_tex["body"], Vector2(X, Y), Rect2(), Mq)
	P.tex(_tex["ao"], Vector2(X, Y))
	# the glass warms, then the rows scan in, at the lab's times (composed in `_gl`)
	_gl.t = t
	_gl.tb = tb
	_gl.queue_redraw()
	var fx: Dictionary = T.get("fx", {})
	var rv: Array = T.get("reveal", [2.7, 3.3])
	var live := tb >= float(rv[1]) + 0.5
	var s: Dictionary = {}
	var sag: Dictionary = {}
	var kind := String(fx.get("kind", ""))
	if live and kind == "failing":
		sag = sag_with_bulb(t, fx)
	if live and (kind == "signal" or (kind == "failing" and sag.is_empty())):
		s = bad_signal(t, fx)
	var jolt := float(sag.get("jolt", 0.0))
	if jolt == 0.0:
		jolt = float(s.get("jolt", 0.0))
	var Mg := Color(M.r + (1.0 - M.r) * glow, M.g + (1.0 - M.g) * glow, M.b + (1.0 - M.b) * glow)
	var gt := vp.get_texture()
	P.tex(gt, Vector2(GX, GY + jolt), Rect2(0, 0, GW, GH), Mg)
	if sag.has("sag"):
		var a := 1.0 - float(sag["sag"])
		P.tex(_tex["art"], Vector2(GX, GY), Rect2(), Color(Mq.r, Mq.g, Mq.b, a))
	if sag.has("flash"):
		P.rect(Rect2(GX, GY, GW, GH), Color(tint.r, tint.g, tint.b, float(sag["flash"])))
	if not s.is_empty():
		for bd: Array in s["bands"]:
			var by := float(bd[0])
			var bh := float(bd[1])
			var sh := float(bd[2])
			var src := float(bd[3])
			P.tex(_tex["dim"], Vector2(GX, GY + by), Rect2(0, by, GW, bh))
			var x0 := GX + sh
			var cut0 := maxf(0.0, -sh)
			var cut1 := maxf(0.0, sh)
			P.tex(gt, Vector2(x0 + cut0, GY + by), Rect2(cut0, src, float(GW) - cut0 - cut1, bh))
		var snc := Color(tint.r, tint.g, tint.b, 0.35)
		for ly: int in s["snow"]:
			var x := 0
			while x < GW:
				if YardLight.hash1(float(x) * 0.37 + float(s["f"]) * 1.7 + float(s["k"]) + float(ly)) < 0.55:
					P.rect(Rect2(GX + float(x), GY + float(ly), 2, 2), snc)
				x += 2
	# the bulb's light on the glass, from the bulb where it hangs
	if T.has("glowL"):
		var wb0 := clampf(float(W8.get("bulb", 1.0)), 0.0, 1.1)
		var was := bulb_was if bulb_was >= 0.0 else wb0
		if was >= 0.6 and wb0 <= 0.35 and tb > 3.0:
			scene.flick_sound("tv")
		bulb_was = wb0
		if wb0 > 0.01:
			P.use(YardPaint.ADD)
			P.tex(_tex["glowL"], Vector2(GX, GY), Rect2(), Color(1, 1, 1, minf(1.0, wb0)))
	# the lamps: each painted lamp pixel at its clock's brightness
	for Lp: Dictionary in _lamps:
		var L: Dictionary = Lp["L"]
		var w := clampf(float(W8.get(String(L.get("id", "")), 1.0)), 0.0, 1.1)
		P.use(YardPaint.PLAIN)
		if Lp.has("line"):
			P.tex(Lp["line"], Vector2(X, Y))
		if bool(Lp["glass"]):
			# unlit, it takes the hall's light; lit, it burns
			var u := minf(1.0, w)
			var f := maxf(1.0, w)
			P.tex(Lp["off"], Vector2(X, Y), Rect2(), M)
			if u > 0.0:
				_bright(P, Lp["lit"], Vector2(X, Y), f, u)
		else:
			var k := (0.2 + (float(L["bright"]) - 0.2) * w) if L.has("bright") else (0.3 + 0.7 * w)
			_bright(P, Lp["lit"], Vector2(X, Y), k, 1.0)
		if Lp.has("cone") and w > 0.02:
			var at: Array = L.get("coneAt", [0, 0])
			P.use(YardPaint.ADD)
			P.tex(Lp["cone"], Vector2(X + float(at[0]), Y + float(at[1])), Rect2(), Color(1, 1, 1, minf(1.0, w)))
		if Lp.has("halo") and w > 0.02:
			var H: Dictionary = L["halo"]
			var r := float(H.get("r", 9))
			P.use(YardPaint.ADD)
			P.tex(Lp["halo"], Vector2(X + float(H["cx"]) - r, Y + float(H["cy"]) - r), Rect2(), Color(1, 1, 1, minf(1.0, w)))
		if bool(L.get("bubbles", false)) and w > 0.3 and Lp.has("bx0"):
			P.use(YardPaint.PLAIN)
			var bx0 := float(Lp["bx0"])
			var bx1 := float(Lp["bx1"])
			var by0 := float(Lp["by0"])
			var by1 := float(Lp["by1"])
			for i in 4:
				var sp := 10.0 + 8.0 * YardLight.hash1(float(i) * 3.3 + bx0)
				var u2 := fmod(t * sp + YardLight.hash1(float(i) * 7.1 + bx0) * (by1 - by0), by1 - by0)
				var bx := bx0 + 1.0 + floorf(YardLight.hash1(float(i) * 5.9 + bx0) * (bx1 - bx0 - 1.0)) + (0.0 if int(floorf(t * 3.0 + float(i))) % 2 == 1 else 1.0)
				P.px(X + minf(bx1, bx), Y + by1 - u2, 1, 1, Color(225.0 / 255.0, 1.0, 250.0 / 255.0, 0.8 * w))


## A lamp's picture at `k` times its colour, laid over what is there with
## opacity `a`: past full, the rest is added on top.
func _bright(P: YardPaint, tex: Texture2D, at: Vector2, k: float, a: float) -> void:
	P.use(YardPaint.PLAIN)
	P.tex(tex, at, Rect2(), Color(minf(1.0, k), minf(1.0, k), minf(1.0, k), a))
	if k > 1.0:
		P.use(YardPaint.ADD)
		P.tex(tex, at, Rect2(), Color(k - 1.0, k - 1.0, k - 1.0, a))


## Is the pointer on TAKE IT (in the hall's pixels)?
func on_take(p: Vector2) -> bool:
	var k: Array = T.get("take", [0, 0, 0, 0])
	var GX := X + float(gx0)
	var GY := Y + float(gy0)
	return p.x >= GX + float(k[0]) and p.x < GX + float(k[0]) + float(k[2]) and p.y >= GY + float(k[1]) and p.y < GY + float(k[1]) + float(k[3])


## The glass as the page composed it in a canvas of its own: the picture, its
## backlight warming, the deal scanned in with TAKE IT (`_Rows`, clipped at the
## scan), and the scan line, the sweep or the rim running round it (`_Over`).
class _Glass:
	extends Control
	var deal: YardDeal
	var t := 0.0
	var tb := 0.0
	var rows: _Rows
	var over: _Over

	func _init() -> void:
		rows = _Rows.new()
		rows.clip_contents = true
		add_child(rows)
		over = _Over.new()
		add_child(over)

	func _draw() -> void:
		var D := deal
		rows.deal = D
		over.deal = D
		over.t = t
		over.tb = tb
		draw_texture(D._tex["art"], Vector2.ZERO)
		if D.glow > 0.0:
			draw_texture(D._tex["dim"], Vector2.ZERO, Color(1, 1, 1, D.glow))
		var sy := floorf(D.reveal * float(D.GH))
		rows.visible = sy > 0.0
		rows.size = Vector2(D.GW, sy)
		over.size = Vector2(D.GW, D.GH)
		rows.queue_redraw()
		over.queue_redraw()


class _Rows:
	extends Control
	var deal: YardDeal

	func _draw() -> void:
		var D := deal
		if D == null:
			return
		var font := D.scene.font()
		var tx: Array = D.T.get("text", [0, 0, D.GW, D.GH])
		var TOX := float(tx[0])
		var TW := float(tx[2])
		var oy := float(D.T.get("rows_y", 0))
		var d: Dictionary = D.scene.deal
		if d.is_empty():
			# nothing on the blocks: the glass says so, in the caption's ink
			_put(font, "NO SHIP", TOX + TW / 2.0, oy + 22.0, YardDeal.DEAL_CAP, 1, 8)
			_put(font, "FOR SALE", TOX + TW / 2.0, oy + 32.0, YardDeal.DEAL_CAP, 1, 8)
			return
		_put(font, "ASKING", TOX + 6.0, oy + 11.0, YardDeal.DEAL_CAP, 0, 8)
		_put(font, "%d" % int(d.get("ask", 0)), TOX + TW - 6.0, oy + 11.0, YardDeal.DEAL_VAL, 2, 8)
		_put(font, "YOUR SHIP", TOX + 6.0, oy + 21.0, YardDeal.DEAL_CAP, 0, 8)
		_put(font, "-%d" % int(d.get("trade", 0)), TOX + TW - 6.0, oy + 21.0, YardDeal.DEAL_VAL, 2, 8)
		draw_rect(Rect2(TOX + 6.0, oy + 25.0, TW - 12.0, 1.0), YardDeal.DEAL_RULE)
		_put(font, "%d CR" % int(d.get("price", 0)), TOX + 6.0, oy + 42.0, YardDeal.DEAL_PRICE, 0, 16)
		var k: Array = D.T.get("take", [0, 0, 44, 17])
		var ok := bool(d.get("ok", false))
		var on := D.hover_take and D.reveal >= 1.0 and ok
		var kr := Rect2(float(k[0]), float(k[1]), float(k[2]), float(k[3]))
		if on:
			draw_rect(kr, Color(240.0 / 255.0, 160.0 / 255.0, 48.0 / 255.0, 0.2))
		# TAKE IT you cannot pay for is written in the grey a price you cannot
		# pay is written in on the drones
		var edge := YardDeal.AMBER if ok else YardDeal.POOR
		draw_rect(Rect2(kr.position, Vector2(kr.size.x, 1)), edge)
		draw_rect(Rect2(kr.position + Vector2(0, kr.size.y - 1.0), Vector2(kr.size.x, 1)), edge)
		draw_rect(Rect2(kr.position, Vector2(1, kr.size.y)), edge)
		draw_rect(Rect2(kr.position + Vector2(kr.size.x - 1.0, 0), Vector2(1, kr.size.y)), edge)
		var tc := (Color("#fff0cc") if on else Color("#f0d8a0")) if ok else YardDeal.POOR
		_put(font, "TAKE IT", kr.position.x + kr.size.x / 2.0, kr.position.y + 12.0, tc, 1, 8, false)

	## A line of the deal, with the page's drop shadow: align 0 left, 1 centre, 2 right.
	func _put(font: Font, s: String, x: float, y: float, c: Color, align: int, size: int, shadow: bool = true) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x0 := x
		if align == 1:
			x0 = x - w / 2.0
		elif align == 2:
			x0 = x - w
		x0 = floorf(x0 + 0.5)
		if shadow:
			draw_string(font, Vector2(x0 + 1.0, y + 1.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, YardDeal.SHADOW)
		draw_string(font, Vector2(x0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


class _Over:
	extends Control
	var deal: YardDeal
	var t := 0.0
	var tb := 0.0

	func _draw() -> void:
		var D := deal
		if D == null:
			return
		var sy := floorf(D.reveal * float(D.GH))
		var tn := D.tint
		if D.reveal > 0.0 and D.reveal < 1.0:
			draw_rect(Rect2(0, sy, D.GW, 1), Color(tn.r, tn.g, tn.b, 0.6))
			draw_rect(Rect2(0, maxf(0.0, sy - 2.0), D.GW, 2), Color(tn.r, tn.g, tn.b, 0.18))
		var fx: Dictionary = D.T.get("fx", {})
		var rv: Array = D.T.get("reveal", [2.7, 3.3])
		var kind := String(fx.get("kind", ""))
		# sweep: a thin line down the rows for 1.4 s in every 7
		if kind == "sweep" and tb >= float(rv[1]) + 1.0:
			var ph := fmod(t, 7.0) / 1.4
			if ph <= 1.0:
				var ly := floorf(ph * float(D.GH))
				draw_rect(Rect2(0, ly, D.GW, 1), Color(tn.r, tn.g, tn.b, 0.45))
				draw_rect(Rect2(0, maxf(0.0, ly - 2.0), D.GW, 2), Color(tn.r, tn.g, tn.b, 0.12))
		# rim: a gold streak runs once round the glass's inside edge, every 7 s,
		# in 2px steps as the lab's does
		if kind == "rim" and tb >= float(rv[1]) + 0.5:
			var every := float(fx.get("every", 7))
			var run := float(fx.get("run", 3.2))
			var tail := int(fx.get("tail", 14))
			var ph2 := fmod(t, every)
			if ph2 <= run:
				var gw := D.GW >> 1
				var gh := D.GH >> 1
				var per := 2 * (gw + gh) - 4
				var head := int(floorf(ph2 / run * float(per)))
				var gc: Array = D.T.get("gold", [250, 215, 140])
				for i in tail:
					var p := head - i
					if p < 0:
						break
					var e := _edge(p, gw, gh)
					draw_rect(Rect2(float(e.x) * 2.0, float(e.y) * 2.0, 2, 2),
						Color(float(gc[0]) / 255.0, float(gc[1]) / 255.0, float(gc[2]) / 255.0, 0.6 * (1.0 - float(i) / float(tail))))

	static func _edge(p: int, gw: int, gh: int) -> Vector2i:
		if p < gw:
			return Vector2i(p, 0)
		if p < gw + gh - 1:
			return Vector2i(gw - 1, p - gw + 1)
		if p < 2 * gw + gh - 2:
			return Vector2i(gw - 1 - (p - gw - gh + 2), gh - 1)
		return Vector2i(0, gh - 1 - (p - 2 * gw - gh + 3))
