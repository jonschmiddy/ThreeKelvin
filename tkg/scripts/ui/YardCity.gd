class_name YardCity
extends RefCounted

## What lives in the city's wall: the tenants behind the panes, the three scissor lifts
## and the capital's stars. `YardLife` owns one and calls `setup` and `draw`.

const TSTAND := [".#.", "###", "###", "###", ".#.", ".#.", ".#."]
const TSTEP_A := [".#.", "###", "###", "###", ".#.", "#.#", "#.#"]
const TSTEP_B := [".#.", "###", "###", "###", ".#.", ".#.", "##."]
const TEN_INK := Color8(42, 38, 48)
const TEN_RIM := Color8(74, 63, 58)
const CAR := {"x": 128, "y": 115, "w": 20, "h": 35}
const CAB := {"c0": 2, "c1": 17, "r0": 7, "r1": 21}

var scene: YardScene
var STARS: Array = []
var LIFE: Array = []
var LIFTCARS: Array = []
var _car_tex: Array = []
var _car_img: Array = []
var _car_burn_tex: Array = []
var _car_burn_img: Array = []
var _shaft_tex: ImageTexture = null


func _init(s: YardScene) -> void:
	scene = s
	for k in 46:
		var b := 0.45 + 0.55 * pow(YardLight.hash1(float(k) * 8.1 + 0.3), 2.0)
		STARS.append({"u": YardLight.hash1(float(k) * 2.3 + 0.1), "v": YardLight.hash1(float(k) * 5.9 + 0.7), "b": b,
			"sp": 0.35 + 1.0 * b, "tw": YardLight.hash1(float(k) * 3.7) < 0.3})


func setup() -> void:
	var doc := YardScene.doc()
	for A: Dictionary in doc.get("life_windows", []):
		var A2 := A.duplicate(true)
		for p: Dictionary in A2["people"]:
			p["s"] = int(p["seed"]) % 2147483647
			if p["s"] == 0:
				p["s"] = 1
			p["dir"] = 1.0
			p["x"] = float(p["x"])
			p["pause"] = float(p["pause"])
		LIFE.append(A2)
	var cars := [{"shaft": true, "x": 128, "stops": [115, 48], "rows": 35},
		{"x": 467, "stops": [104, 48], "rows": 27, "clip": [467, 28, 486, 138], "skip": [84, 97]},
		{"x": 652, "stops": [104, 48], "rows": 27, "clip": [652, 22, 672, 139], "skip": [84, 97]}]
	for n in cars.size():
		var L: Dictionary = cars[n]
		L["s"] = 1 + (randi() % 2147483000)
		L["at"] = n % 2
		L["Y"] = float((L["stops"] as Array)[int(L["at"])])
		L["state"] = "idle"
		L["tm"] = 0.5 + _rng(L) * 5.0
		L["open"] = 0.0
		L["riders"] = []
		L["pace"] = 0.85 + 0.3 * _rng(L)
		LIFTCARS.append(L)
		var img := Image.create(int(CAR["w"]), int(L["rows"]), false, Image.FORMAT_RGBA8)
		_car_img.append(img)
		_car_tex.append(ImageTexture.create_from_image(img))
		var bimg := Image.create(int(CAR["w"]), int(L["rows"]), false, Image.FORMAT_RGBA8)
		_car_burn_img.append(bimg)
		_car_burn_tex.append(ImageTexture.create_from_image(bimg))
	# the empty shaft where the car stood: the rails, as they run above it
	var hall := scene.light.hall_img
	if hall != null:
		var sh := Image.create(int(CAR["w"]), int(CAR["h"]), false, Image.FORMAT_RGBA8)
		for y in int(CAR["h"]):
			for x in int(CAR["w"]):
				sh.set_pixel(x, y, hall.get_pixel(int(CAR["x"]) + x, 112))
		_shaft_tex = ImageTexture.create_from_image(sh)


## The Park-Miller stream each tenant and car keeps, as the page's `rngOf`.
static func _rng(o: Dictionary) -> float:
	var s := int(o["s"])
	s = (s * 16807) % 2147483647
	o["s"] = s
	return float(s) / 2147483647.0


## THE CITY'S TENANTS: people at home behind the lit panes, some rooms empty, a
## few walking out past the glass and back (the page's `drawTenants`).
func _tenants(P: YardPaint, dt: float) -> void:
	P.use(YardPaint.HALL)
	for A: Dictionary in LIFE:
		var clip: Array = A["clip"]
		var x0 := int(clip[0])
		var y0 := int(clip[1])
		var x1 := int(clip[2])
		var y1 := int(clip[3])
		var bars: Array = A["bars"]
		for p: Dictionary in A["people"]:
			var moving := false
			if float(p["pause"]) > 0.0:
				p["pause"] = float(p["pause"]) - dt
			else:
				if not p.has("target"):
					var vis: Array = p["vis"]
					var v0 := float(vis[0])
					var v1 := float(vis[1])
					if _rng(p) < 0.3:
						if _rng(p) < 0.5:
							p["target"] = float(p["lo"]) + floorf(_rng(p) * maxf(1.0, v0 - 3.0 - float(p["lo"])))
						else:
							p["target"] = v1 + 3.0 + floorf(_rng(p) * maxf(1.0, float(p["hi"]) - v1 - 2.0))
					else:
						p["target"] = v0 + floorf(_rng(p) * (v1 - v0 + 1.0))
				if floorf(float(p["x"]) + 0.5) == float(p["target"]):
					var vis2: Array = p["vis"]
					var away := float(p["target"]) < float(vis2[0]) - 2.0 or float(p["target"]) > float(vis2[1]) + 2.0
					p["pause"] = (6.0 + _rng(p) * 19.0) if away else (2.0 + _rng(p) * 7.0)
					p.erase("target")
				else:
					p["dir"] = 1.0 if float(p["target"]) > float(p["x"]) else -1.0
					p["x"] = float(p["x"]) + float(p["dir"]) * float(p["speed"]) * dt
					moving = true
					if (float(p["dir"]) > 0.0 and float(p["x"]) > float(p["target"])) or (float(p["dir"]) < 0.0 and float(p["x"]) < float(p["target"])):
						p["x"] = p["target"]
			var xi := int(floorf(float(p["x"]) + 0.5))
			var rows: Array = TSTAND if not moving else (TSTEP_A if xi % 2 == 0 else TSTEP_B)
			var top := int(A["feet"]) - rows.size() + 1
			for j in rows.size():
				var row: String = rows[j]
				for k in 3:
					if row[k if float(p["dir"]) > 0.0 else 2 - k] != "#":
						continue
					var x := xi + k
					var y := top + j
					if x < x0 or x > x1 or y < y0 or y > y1:
						continue
					var under_bar := false
					for b: Array in bars:
						if x >= int(b[0]) and x <= int(b[1]):
							under_bar = true
					if under_bar:
						continue
					P.rect(Rect2(x, y, 1, 1), TEN_RIM if j == 0 else TEN_INK)


## The city's lifts (Jon: "THEYRE SOOO COOL"): doors open, riders swap, doors close.
func _lifts(Pl: YardPaint, dt: float) -> void:
	var hall := scene.light.hall_img
	if hall == null:
		return
	for n in LIFTCARS.size():
		var L: Dictionary = LIFTCARS[n]
		_lift_step(L, dt)
		var Y := floorf(float(L["Y"]) + 0.5)
		if L.get("shaft", false) and int(Y) != int(CAR["y"]) and _shaft_tex != null:
			Pl.use(YardPaint.HALL)
			Pl.tex(_shaft_tex, Vector2(float(CAR["x"]), float(CAR["y"])))
		var img: Image = _car_img[n]
		var bimg: Image = _car_burn_img[n]
		img.fill(Color(0, 0, 0, 0))
		bimg.fill(Color(0, 0, 0, 0))
		var px := _car_pixels(L, hall)
		var lit: PackedByteArray = px[1]
		var cols: PackedColorArray = px[0]
		var rows := int(L["rows"])
		var clip: Array = L.get("clip", [])
		var skip: Array = L.get("skip", [])
		for r in rows:
			var y := int(Y) + r
			if y < 0 or y >= YardScene.H:
				continue
			if not clip.is_empty() and (y < int(clip[1]) or y > int(clip[3]) or (y >= int(skip[0]) and y <= int(skip[1]))):
				continue
			for c in int(CAR["w"]):
				var x := int(L["x"]) + c
				if not clip.is_empty() and (x < int(clip[0]) or x > int(clip[2])):
					continue
				var o := r * int(CAR["w"]) + c
				var col := cols[o]
				if not clip.is_empty():
					var hp := hall.get_pixel(x, y)
					col = Color(col.r * 0.72 + hp.r * 0.28, col.g * 0.72 + hp.g * 0.28, col.b * 0.72 + hp.b * 0.28)
				if lit[o] == 1:
					bimg.set_pixel(c, r, col)
				else:
					img.set_pixel(c, r, col)
		(_car_tex[n] as ImageTexture).update(img)
		(_car_burn_tex[n] as ImageTexture).update(bimg)
		Pl.use(YardPaint.HALL)
		Pl.tex(_car_tex[n], Vector2(float(L["x"]), Y))
		Pl.use(YardPaint.PLAIN)
		Pl.tex(_car_burn_tex[n], Vector2(float(L["x"]), Y))


func _lift_step(L: Dictionary, dt: float) -> void:
	L["tm"] = float(L["tm"]) - dt
	var riders: Array = L["riders"]
	for rd: Dictionary in riders:
		rd["moving"] = false
	var st := String(L["state"])
	if st == "idle":
		if float(L["tm"]) <= 0.0:
			L["state"] = "opening"
	elif st == "opening":
		L["open"] = minf(1.0, float(L["open"]) + dt / 0.6)
		if float(L["open"]) >= 1.0:
			L["state"] = "out"
			for k in riders.size():
				var rd: Dictionary = riders[k]
				rd["state"] = "leave"
				rd["side"] = -1.0 if _rng(L) < 0.5 else 1.0
				rd["wait"] = float(k) * 0.45
	elif st == "out":
		var still: Array = []
		for rd: Dictionary in riders:
			if not _walk_rider(rd, dt):
				still.append(rd)
		L["riders"] = still
		if still.is_empty():
			# who gets on here: one or two, now and then nobody
			var n := 0 if _rng(L) < 0.12 else (1 if _rng(L) < 0.55 else 2)
			var spots := [6.0, 12.0] if n == 2 else [8.0 + floorf(_rng(L) * 3.0)]
			var nr: Array = []
			for k in n:
				var side := -1.0 if _rng(L) < 0.5 else 1.0
				nr.append({"x": -3.0 if side < 0.0 else float(CAR["w"]), "side": side, "spot": spots[k], "state": "enter",
					"wait": 0.3 + float(k) * 0.7 + _rng(L) * 0.4, "dir": -side, "moving": false})
			L["riders"] = nr
			L["state"] = "in"
	elif st == "in":
		var all := true
		for rd: Dictionary in riders:
			if not _walk_rider(rd, dt):
				all = false
		if all:
			for rd: Dictionary in riders:
				rd["state"] = "ride"
				rd["dir"] = -1.0 if _rng(L) < 0.5 else 1.0
			L["state"] = "dwell"
			L["tm"] = 0.5 + _rng(L) * 1.2
	elif st == "dwell":
		if float(L["tm"]) <= 0.0:
			L["state"] = "closing"
	elif st == "closing":
		L["open"] = maxf(0.0, float(L["open"]) - dt / 0.6)
		if float(L["open"]) <= 0.0:
			L["state"] = "depart"
			L["tm"] = 0.4 if not riders.is_empty() else 2.0 + _rng(L) * 5.0
	elif st == "depart":
		if float(L["tm"]) <= 0.0:
			var stops: Array = L["stops"]
			L["from"] = L["Y"]
			L["to"] = float(stops[1 - int(L["at"])])
			L["u"] = 0.0
			L["dur"] = absf(float(L["to"]) - float(L["from"])) / (11.0 * float(L["pace"]))
			L["state"] = "ride"
	elif st == "ride":
		L["u"] = minf(1.0, float(L["u"]) + dt / float(L["dur"]))
		var u := float(L["u"])
		L["Y"] = float(L["from"]) + (float(L["to"]) - float(L["from"])) * (u * u * (3.0 - 2.0 * u))
		if u >= 1.0:
			L["Y"] = L["to"]
			L["at"] = 1 - int(L["at"])
			L["state"] = "arrive"
			L["tm"] = 0.35
	elif st == "arrive":
		if float(L["tm"]) <= 0.0:
			L["state"] = "opening"


func _walk_rider(rd: Dictionary, dt: float) -> bool:
	var to := (-3.0 if float(rd["side"]) < 0.0 else float(CAR["w"])) if String(rd["state"]) == "leave" else float(rd["spot"])
	if float(rd["wait"]) > 0.0:
		rd["wait"] = float(rd["wait"]) - dt
		return false
	var d := to - float(rd["x"])
	if absf(d) < 0.01:
		return true
	rd["dir"] = signf(d)
	rd["x"] = float(rd["x"]) + float(rd["dir"]) * minf(absf(d), 7.0 * dt)
	rd["moving"] = true
	return absf(to - float(rd["x"])) < 0.01


## The car as it looks now: its painted pixels, its riders in the cabin, and
## the doors' glass over them; and which of its pixels burn (the page's `carPixels`).
func _car_pixels(L: Dictionary, hall: Image) -> Array:
	var w := int(CAR["w"])
	var h := int(CAR["h"])
	var cols := PackedColorArray()
	cols.resize(w * h)
	for r in h:
		for c in w:
			cols[r * w + c] = hall.get_pixel(int(CAR["x"]) + c, int(CAR["y"]) + r)
	for rd: Dictionary in L["riders"]:
		var xi := int(floorf(float(rd["x"]) + 0.5))
		var rows: Array = TSTAND if not bool(rd["moving"]) else (TSTEP_A if xi % 2 == 0 else TSTEP_B)
		var top := int(CAB["r1"]) - rows.size() + 1
		for j in rows.size():
			var row: String = rows[j]
			for k in 3:
				if row[k if float(rd["dir"]) > 0.0 else 2 - k] != "#":
					continue
				var c2 := xi + k
				var r2 := top + j
				if c2 < int(CAB["c0"]) or c2 > int(CAB["c1"]) or r2 < int(CAB["r0"]) or r2 > int(CAB["r1"]):
					continue
				cols[r2 * w + c2] = TEN_RIM if j == 0 else TEN_INK
	# the doors: two glass panels meeting in the middle, sliding apart
	var half := float(int(CAB["c1"]) - int(CAB["c0"]) + 1) / 2.0
	var wd := int(floorf(half * (1.0 - float(L["open"])) + 0.5))
	for r3 in range(int(CAB["r0"]), int(CAB["r1"]) + 1):
		for c3 in range(int(CAB["c0"]), int(CAB["c1"]) + 1):
			var in_l := c3 < int(CAB["c0"]) + wd
			var in_r := c3 > int(CAB["c1"]) - wd
			if not in_l and not in_r:
				continue
			var edge := (in_l and c3 == int(CAB["c0"]) + wd - 1) or (in_r and c3 == int(CAB["c1"]) - wd + 1)
			var o := r3 * w + c3
			if edge:
				cols[o] = Color8(34, 52, 58)
				continue
			var p := cols[o]
			cols[o] = Color(p.r * 0.58 + 62.0 / 255.0 * 0.42, p.g * 0.58 + 108.0 / 255.0 * 0.42, p.b * 0.58 + 116.0 / 255.0 * 0.42)
	var lit := PackedByteArray()
	lit.resize(w * h)
	for r4 in h:
		for c4 in w:
			var o2 := r4 * w + c4
			var p2 := cols[o2]
			lit[o2] = 1 if r4 >= int(CAB["r0"]) and r4 <= int(CAB["r1"]) and (0.299 * p2.r8 + 0.587 * p2.g8 + 0.114 * p2.b8) > 120.0 else 0
	return [cols, lit]


## Stars drift slowly left to right behind the rose window (Jon), not circling.
func _stars(P: YardPaint, t: float) -> void:
	var W: Variant = scene.light.doc.get("stars")
	if not (W is Dictionary):
		return
	var hall := scene.light.hall_img
	if hall == null:
		return
	var cx := float(W["cx"])
	var cy := float(W["cy"])
	var r := float(W["r"])
	var span := 2.0 * r + 3.0
	P.use(YardPaint.PLAIN)
	for s: Dictionary in STARS:
		var x := int(floorf(cx - r - 1.0 + fmod(float(s["u"]) * span + t * float(s["sp"]), span) + 0.5))
		var y := int(floorf(cy - r + float(s["v"]) * 2.0 * r + 0.5))
		var h := hall.get_pixel(x, y)
		var h0 := h.r8
		var h1 := h.g8
		var h2 := h.b8
		if not (h2 > h0 + 10 and h2 > h1 + 5 and h2 < 90):
			continue
		var b := float(s["b"])
		if bool(s["tw"]):
			b *= 0.55 + 0.45 * YardLight.vnoise(t * 2.5 + float(s["u"]) * 100.0)
		var v := (90.0 + 165.0 * b) / 255.0
		P.rect(Rect2(x, y, 1, 1), Color(v * 0.86, v * 0.92, v))


## What lives in the wall: the city's tenants and lifts, the capital's stars.
func draw(P: YardPaint, t: float, dt: float) -> void:
	if not LIFE.is_empty():
		_tenants(P, dt)
		_lifts(P, dt)
	_stars(P, t)
