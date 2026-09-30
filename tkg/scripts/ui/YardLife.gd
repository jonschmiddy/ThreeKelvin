class_name YardLife
extends RefCounted

## Everyone and everything at work in the Yard (the Yard Drones page's floor
## life, crew, air and wall): the crew walking their lanes, the forklift and its
## crates, the welder on his scissor lift under the ship for sale, the tech at
## his console, the mechanic under his machine, the grinder at his bench, the
## station's flyers and small drones, the city's tenants and lift cars, the
## capital's stars, the settlement's moths, dust in the cones -- and, one at a
## time, the rare events Jon kept (the page's E2-E3, E10-E15, E17, E19, E20).
##
## ALL OF IT STANDS IN THE HALL'S LIGHT. Something standing on the floor takes
## the light where it stands, so it walks into the ships' shadows; it is
## grounded as the hulls are: a contact shadow, its foot in the polish. It is
## drawn back to front in depth order, behind the ships if it stands behind
## them (`YardScene`'s back and front layers).
##
## A DIFFERENT YARD EVERY VISIT (Jon: "the same things in the same places all
## the time would be boring"): the mechanic's machine and the bench's grinder
## are picked when you arrive.

const TINT := Color(0.8, 0.8, 0.82)
## Where the ships' depth is, on the floor: nearer than this row stands in
## front of them (the page's depth buffer, Z 500 at row 330).
const SHIP_ROW := 330.0
const MECHS := ["mech_gen_1", "mech_gen_2", "mech_legs_1", "mech_legs_2", "mech_kneel_2"]
const LIFT := Vector2(560, 318)
const DESK := {"cx": 52.0, "feet": 336.0}
const ENG := Vector2(194, 436)
const BENCH := Vector2(412, 262)
const FKL := {"lane": 412.0, "stackX": 432.0}
const HATCH := Vector2(340, 428)
const TSTAND := [".#.", "###", "###", "###", ".#.", ".#.", ".#."]
const TSTEP_A := [".#.", "###", "###", "###", ".#.", "#.#", "#.#"]
const TSTEP_B := [".#.", "###", "###", "###", ".#.", ".#.", "##."]
const TEN_INK := Color8(42, 38, 48)
const TEN_RIM := Color8(74, 63, 58)
const CAR := {"x": 128, "y": 115, "w": 20, "h": 35}
const CAB := {"c0": 2, "c1": 17, "r0": 7, "r1": 21}
const AMBF := ["d1", "d2", "d3", "d4", "d6", "d7", "d10", "d11", "d13", "d14"]
const PLANE_ART := {
	"far": [[1, 0, 2, "#eef3f8"], [0, 1, 3, "#b8c2cc"]],
	"mid": [[2, 0, 2, "#ffffff"], [0, 1, 5, "#eef3f8"], [2, 2, 2, "#9aa6b2"]],
	"near": [[3, 0, 3, "#ffffff"], [0, 1, 7, "#eef3f8"], [2, 2, 4, "#b8c2cc"], [4, 3, 2, "#7d8894"]],
}

var scene: YardScene
var art: Dictionary = {}
var level := ""
## The crew's lanes (`yard.json`), and anyone crossing on a lane of his own.
var CREW: Array = []
var RUN: Array = []
var GLYPH: Array = []
var _items: Array = []
var VISIT := {"mech": 0, "grind": 0}
## this tick's small lights' sources
var weld_now := {"on": false, "x": 0.0, "y": 0.0}
var CONSOLE := {"x": 0.0, "y": 0.0, "k": 0.0, "blue": false}
var GRINDLIT := {"on": false, "x": 0.0, "y": 0.0}
var FORKLIT := {"on": false, "x": 0.0, "y": 0.0, "lane": 0.0, "front": 0.0}
var WELD := {"period": 7.5, "pause": -1.0}
var sparks: Array = []
var gsparks: Array = []
var pop_sparks: Array = []
var FK: Dictionary = {}
var SMALL: Array = []
var AMB: Array = []
var BOT: Dictionary = {}
var CAT: Dictionary = {}
var RIDE: Dictionary = {}
var PLANE: Dictionary = {}
var HEAD: Dictionary = {}
var SHUF: Dictionary = {}
var BALLOON: Dictionary = {}
var CRASH: Dictionary = {}
var CHASE: Dictionary = {}
var DUST: Array = []
var MOTHS: Array = []
var STARS: Array = []
var LIFE: Array = []
var LIFTCARS: Array = []
var _car_tex: Array = []
var _car_img: Array = []
var _car_burn_tex: Array = []
var _car_burn_img: Array = []
var _shaft_tex: ImageTexture = null
var _console_img: Image = null
var _bot_img: Image = null
var _crew_img: Dictionary = {}
var last_forgot: Dictionary = {}
var has_welder := true
var _standing: Dictionary = {}


func _init(s: YardScene) -> void:
	scene = s
	level = scene.level
	art = YardScene.doc().get("art", {})
	var doc := YardScene.doc()
	for c: Dictionary in doc.get("lanes", []):
		var c2 := c.duplicate()
		c2["Z"] = zat(float(c2["y"]))
		CREW.append(c2)
	pick_visit()
	FK = {"x": -140.0, "lift": 0.0, "load": -1, "q": [], "cur": {}, "mode": "deliver", "stack": [0, 0], "moving": 0, "back": false, "kind": 0}
	for k in 170:
		DUST.append({"x": YardLight.hash1(float(k) * 3.1 + 0.2) * 766.0, "y": 30.0 + YardLight.hash1(float(k) * 7.7 + 0.5) * 150.0,
			"vx": (YardLight.hash1(float(k) * 1.9) - 0.5) * 4.0, "vy": -0.8 - YardLight.hash1(float(k) * 4.3) * 1.8,
			"ph": YardLight.hash1(float(k) * 9.1) * 6.28})
	for k in 15:
		MOTHS.append({"lamp": k, "ph": YardLight.hash1(float(k) * 4.1 + 0.2) * 100.0, "r": 5.0 + YardLight.hash1(float(k) * 2.7 + 0.1) * 9.0,
			"sp": 0.8 + YardLight.hash1(float(k) * 6.3 + 0.4) * 0.7})
	for k in 46:
		var b := 0.45 + 0.55 * pow(YardLight.hash1(float(k) * 8.1 + 0.3), 2.0)
		STARS.append({"u": YardLight.hash1(float(k) * 2.3 + 0.1), "v": YardLight.hash1(float(k) * 5.9 + 0.7), "b": b,
			"sp": 0.35 + 1.0 * b, "tw": YardLight.hash1(float(k) * 3.7) < 0.3})
	var con: Dictionary = (art.get("life", {}) as Dictionary).get("console", {})
	_console_img = scene.img(String(con.get("picture", "")))
	var bot: Dictionary = (art.get("life", {}) as Dictionary).get("bot", {})
	_bot_img = scene.img(String(bot.get("picture", "")))
	if bool(scene.light.doc.get("people", false)):
		_setup_city()


## A picture's measurements, and the part of its texture to draw: one picture,
## or one frame of a strip.
func sprite(key: String, frame: int = -1) -> Dictionary:
	var L: Dictionary = (art.get("life", {}) as Dictionary).get(key, {})
	if L.is_empty():
		return {}
	var tex := scene.tex(String(L.get("picture", "")))
	if L.has("frames"):
		var fr: Array = L["frames"]
		var i := clampi(frame, 0, fr.size() - 1)
		var F: Dictionary = fr[i]
		var fw := float(L["fw"])
		return {"tex": tex, "src": Rect2(fw * float(i), 0, fw, float(L["fh"])), "w": F["w"], "h": F["h"], "x0": F["x0"], "x1": F["x1"],
			"top": F["top"], "foot": F["foot"], "cx": F["cx"], "tip": F.get("tip", [0, 0])}
	return {"tex": tex, "src": Rect2(0, 0, float(L["w"]), float(L["h"])), "w": L["w"], "h": L["h"], "x0": L["x0"], "x1": L["x1"],
		"top": L["top"], "foot": L["foot"], "cx": L["cx"]}


func frames_of(key: String) -> int:
	var L: Dictionary = (art.get("life", {}) as Dictionary).get(key, {})
	return int(L.get("n", 1))


func crew_strip(name: String) -> Dictionary:
	return (art.get("crew", {}) as Dictionary).get(name, {})


func crew_frame(name: String, f: int) -> Dictionary:
	var C := crew_strip(name)
	var fw := float(C.get("frame_w", 10))
	var fh := float(C.get("frame_h", 20))
	var fs: Array = C.get("fs", [])
	return {"tex": scene.tex(String(C.get("picture", ""))), "src": Rect2(fw * float(f), 0, fw, fh), "w": fw, "h": fh,
		"fs": float(fs[f]) if f < fs.size() else 4.0}


## The pixels of a crew frame, for the head out of a hatch.
func crew_image(name: String) -> Image:
	if not _crew_img.has(name):
		_crew_img[name] = scene.img(String(crew_strip(name).get("picture", "")))
	return _crew_img[name]


func zat(y: float) -> float:
	return 300.0 * 500.0 / maxf(1.0, y - 30.0)


func pick_visit() -> void:
	VISIT["mech"] = randi() % MECHS.size()
	VISIT["grind"] = randi() % 2


# ------------------------------------------------------------------ the crew

## Where a crewman is on his lane at `t`: planted feet, a measured step per pose.
func walk_at(c: Dictionary, t: float) -> Dictionary:
	var C := crew_strip(String(c["name"]))
	var span := absf(float(c["to"]) - float(c["from"]))
	var back := bool(c.get("pace_back", false))
	var lap := 2.0 * span if back else span
	var pace := float(c.get("pace", C.get("pace", 10.0)))
	var adv := float(C.get("advance", 1.0))
	var dist := pace * t + float(c.get("phase", 0.0)) * lap
	var stp := floorf(dist / adv)
	var along := fposmod(stp * adv, lap)
	var dir := float(c["dir"])
	if back and along >= span:
		along = lap - along
		dir = -dir
	var x := float(c["from"]) + along if float(c["dir"]) > 0.0 else float(c["to"]) - along
	return {"x": x, "dir": dir, "f": int(stp) % int(C.get("frames", 8)), "dy": 0.0}


## The phase that has a through-lane walker at x now, so he carries on from there.
func rephase(c: Dictionary, x: float, t: float) -> void:
	var C := crew_strip(String(c["name"]))
	var lap := absf(float(c["to"]) - float(c["from"]))
	var along := x - float(c["from"]) if float(c["dir"]) > 0.0 else float(c["to"]) - x
	var pace := float(c.get("pace", C.get("pace", 10.0)))
	c["phase"] = fposmod(((along + 0.5 * float(C.get("advance", 1.0))) - pace * t) / lap, 1.0)


func _crew(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in RUN:
		if t <= float(r["until"]):
			keep.append(r)
	RUN = keep
	for c: Dictionary in CREW + RUN:
		var C := crew_strip(String(c["name"]))
		if C.is_empty():
			continue
		var p := walk_at(c, t)
		if c.has("ev"):
			var q: Variant = (c["ev"] as Callable).call(t)
			if q is Dictionary:
				p = q
			else:
				p = walk_at(c, t)
		if c.has("dyEase") and t > float(c["dyEase"]["t0"]) + float(c["dyEase"]["dur"]):
			c.erase("dyEase")
		var ease := 0.0
		if c.has("dyEase"):
			var de: Dictionary = c["dyEase"]
			ease = float(de["from"]) * (1.0 - YardLight.smooth(float(de["t0"]), float(de["t0"]) + float(de["dur"]), t))
		var dy := floorf(float(p.get("dy", 0.0)) + ease + 0.5)
		var cy := float(c["y"]) + dy
		var F := crew_frame(String(c["name"]), int(p["f"]))
		var x0 := floorf(float(p["x"]) - float(F["w"]) / 2.0 + 0.5)
		var y0 := cy - float(F["h"]) + 1.0
		var fl := float(p["dir"]) < 0.0
		var px := float(p["x"])
		var back := float(c["y"]) < SHIP_ROW
		var fs := float(F["fs"])
		_items.append({"y": cy, "back": back, "draw": func(P: YardPaint) -> void:
			P.use(YardPaint.PLAIN)
			scene.shade(P, floorf(px + 0.5), cy + 1.0, maxf(3.0, fs + 1.5), 2.0, 0.4)
			P.use(YardPaint.MIRROR)
			P.mirror(F["tex"], F["src"], x0, cy + 1.0, 0.16, TINT, fl)
			P.use(YardPaint.FLOOR, YardScene.cell(px, cy))
			P.tex(F["tex"], Vector2(x0, y0), F["src"], Color.WHITE, fl)})
		c["lastX"] = px
		c["lastH"] = float(F["h"])
		if bool(p.get("bang", false)):
			GLYPH.append([floorf(px + 0.5) + (2.0 if float(p["dir"]) > 0.0 else -2.0), y0 - 9.0])


## The pose a walker stops in (feet closest together) and the one he steps in.
func stand_frame(name: String) -> int:
	return int(crew_strip(name).get("stand", 0))


func stride_frame(name: String) -> int:
	return int(crew_strip(name).get("stride", 0))


## E2 FORGOT SOMETHING: a walker in the middle of the floor stops, a "!" pops
## over his head, and he turns round and walks back the way he came.
func forgot(t: float) -> bool:
	var pool: Array = []
	for c: Dictionary in CREW:
		if c.get("pace_back", false) or c.has("ev") or float(c["y"]) < 266.0:
			continue
		var p := walk_at(c, t)
		if float(p["x"]) > 110.0 and float(p["x"]) < 560.0:
			pool.append([c, p])
	if pool.is_empty():
		return false
	var pick: Array = pool[randi() % pool.size()]
	var c2: Dictionary = pick[0]
	var p2: Dictionary = pick[1]
	var sf := stand_frame(String(c2["name"]))
	var x0 := float(p2["x"])
	var d0 := float(p2["dir"])
	last_forgot = c2
	c2["ev"] = func(tt: float) -> Variant:
		var u := tt - t
		if u < 1.1:
			return {"x": x0, "dir": d0, "f": sf, "bang": u > 0.15 and u < 0.85, "dy": 0.0}
		c2["dir"] = -float(c2["dir"])
		rephase(c2, x0, tt)
		c2.erase("ev")
		return null
	return true


## E3 LATE FOR SHIFT: someone hurries across on a lane of his own, at well over
## twice the crew's pace.
func late(t: float) -> bool:
	if not RUN.is_empty():
		return false
	var dir := 1.0 if randf() < 0.5 else -1.0
	var c := {"name": "look_rigger", "y": 384.0, "from": -40.0, "to": 810.0, "dir": dir, "pace": 38.0}
	c["Z"] = zat(384.0)
	rephase(c, -40.0 if dir > 0.0 else 810.0, t)
	c["until"] = t + 850.0 / 38.0 + 0.5
	RUN.append(c)
	return true


## E15 THE SIDEWALK SHUFFLE: two walkers meet head-on, both step the same way,
## both step the other way, then one steps back and waits while the other
## squeezes past.
func shuffle(t: float) -> bool:
	if not SHUF.is_empty():
		return false
	var names := ["look_rigger", "look_welder", "look_suit", "look_loader"]
	var pool: Array = []
	for c: Dictionary in CREW:
		if c.get("pace_back", false) or c.has("ev") or float(c["y"]) < 340.0 or float(c["y"]) > 400.0:
			continue
		var p := walk_at(c, t)
		var pa := float(c.get("pace", crew_strip(String(c["name"])).get("pace", 10.0)))
		var edge := 806.0 if float(p["dir"]) > 0.0 else -36.0
		var others: Array = names.filter(func(n: String) -> bool: return n != String(c["name"]))
		var bn: String = others[randi() % others.size()]
		var pb := float(crew_strip(bn).get("pace", 10.0))
		var meet := float(p["x"]) + (edge - float(p["x"])) * pa / (pa + pb)
		if meet > 110.0 and meet < 540.0 and float(p["x"]) > -10.0 and float(p["x"]) < 776.0:
			pool.append({"c": c, "p": p, "bn": bn, "edge": edge})
	if pool.is_empty():
		return false
	var pk: Dictionary = pool[randi() % pool.size()]
	var A: Dictionary = pk["c"]
	var B := {"name": pk["bn"], "y": A["y"], "from": -40.0, "to": 810.0, "dir": -float(pk["p"]["dir"]), "until": t + 120.0}
	B["Z"] = A["Z"]
	rephase(B, float(pk["edge"]), t)
	SHUF = {"A": A, "B": B, "phase": "approach", "t0": t}
	RUN.append(B)
	return true


func _shuffle_step(t: float) -> void:
	if SHUF.is_empty():
		return
	var A: Dictionary = SHUF["A"]
	var B: Dictionary = SHUF["B"]
	if SHUF["phase"] == "approach":
		var pa := walk_at(A, t)
		var pb := walk_at(B, t)
		if absf(float(pa["x"]) - float(pb["x"])) <= 17.0 and (float(pb["x"]) - float(pa["x"])) * float(pa["dir"]) > 0.0:
			SHUF["phase"] = "dance"
			var t1 := t
			var sfA := stand_frame(String(A["name"]))
			var sfB := stand_frame(String(B["name"]))
			var stA := stride_frame(String(A["name"]))
			var stB := stride_frame(String(B["name"]))
			var xa := float(pa["x"])
			var xb := float(pb["x"])
			var da := float(pa["dir"])
			var db := float(pb["dir"])
			var ease := func(u: float, a0: float, a1: float, y0: float, y1: float) -> float:
				return y0 + (y1 - y0) * YardLight.smooth(a0, a1, u)
			var dy_of := func(u: float) -> float:
				if u < 0.6:
					return 0.0
				if u < 1.1:
					return ease.call(u, 0.6, 1.1, 0.0, -8.0)
				if u < 1.7:
					return -8.0
				if u < 2.3:
					return ease.call(u, 1.7, 2.3, -8.0, 8.0)
				return 8.0
			var moving := func(u: float) -> bool:
				return (u >= 0.6 and u < 1.1) or (u >= 1.7 and u < 2.3)
			A["ev"] = func(tt: float) -> Variant:
				var u := tt - t1
				if u < 3.6:
					return {"x": xa, "dir": da, "f": stA if moving.call(u) else sfA, "dy": dy_of.call(u), "bang": u > 0.08 and u < 0.6}
				A.erase("ev")
				rephase(A, xa, tt)
				A["dyEase"] = {"from": 8.0, "t0": tt, "dur": 1.4}
				return null
			B["ev"] = func(tt: float) -> Variant:
				var u := tt - t1
				if u < 2.9:
					return {"x": xb, "dir": db, "f": stB if moving.call(u) else sfB, "dy": dy_of.call(u), "bang": u > 0.14 and u < 0.6}
				if u < 4.7:
					var bk := u < 3.5
					return {"x": xb, "dir": db, "f": stB if bk else sfB, "dy": ease.call(u, 2.9, 3.5, 8.0, -10.0) if bk else -10.0}
				B.erase("ev")
				rephase(B, xb, tt)
				B["dyEase"] = {"from": -10.0, "t0": tt, "dur": 1.6}
				SHUF["phase"] = "after"
				SHUF["t2"] = tt
				return null
		elif t - float(SHUF["t0"]) > 40.0:
			SHUF = {}
	elif SHUF["phase"] == "after" and t - float(SHUF["t2"]) > 2.0:
		SHUF = {}


# ------------------------------------------------------------------ standing things

## A picture standing on the floor (the page's `put`): its contact shadow, its
## foot in the polish, then itself in the light where it stands.
func put(P: YardPaint, S: Dictionary, x: float, bottom: float, o: Dictionary = {}) -> void:
	if S.is_empty():
		return
	var flip := bool(o.get("flip", false))
	var cx := float(S["w"]) - 1.0 - float(S["cx"]) if flip else float(S["cx"])
	var left := floorf(x - cx + 0.5)
	var top := bottom - float(S["foot"])
	var fl := float(o.get("floor", bottom))
	var inkw := float(S["x1"]) - float(S["x0"]) + 1.0
	var sh: Variant = o.get("shadow", null)
	if (sh is bool and sh == true) or (not (sh is bool and sh == false) and fl == bottom):
		P.use(YardPaint.PLAIN)
		scene.shade(P, floorf(x + 0.5), fl + 1.0, maxf(3.0, inkw * 0.5), maxf(2.0, floorf(inkw * 0.07 + 0.5)), float(o.get("k", 0.4)))
	if o.get("mirror", true) != false:
		P.use(YardPaint.MIRROR)
		P.mirror(S["tex"], S["src"], left, fl + (fl - bottom) + 1.0 - (float(S["h"]) - 1.0 - float(S["foot"])), float(o.get("gloss", 0.2)), TINT, flip)
	P.use(YardPaint.FLOOR, YardScene.cell(x, fl))
	P.tex(S["tex"], Vector2(left, top), S["src"], Color.WHITE, flip)


func item(y: float, back: bool, fn: Callable) -> void:
	_items.append({"y": y, "back": back, "draw": fn})


## M1: a welder on a scissor lift under the ship for sale; sparks rain down and
## each flash lights the hull.
func weld_pose(t: float) -> Dictionary:
	if t < float(WELD["pause"]):
		return {"f": 5, "on": false}
	var u := fmod(t, float(WELD["period"]))
	if u < 4.2:
		return {"f": [0, 1, 2, 1][int(floorf(u * 8.0)) % 4], "on": true}
	if u < 4.6:
		return {"f": 3 + mini(2, int(floorf((u - 4.2) / 0.13))), "on": false}
	if u < 6.8:
		return {"f": 5, "on": false}
	if u < 7.2:
		return {"f": 5 - mini(2, int(floorf((u - 6.8) / 0.13))), "on": false}
	return {"f": 0, "on": false}


func _lift_sprite() -> Dictionary:
	var L: Dictionary = (art.get("lifts", {}) as Dictionary).get(level, {})
	if L.is_empty():
		return {}
	return {"tex": scene.tex(String(L["picture"])), "src": Rect2(0, 0, float(L["w"]), float(L["h"])), "w": L["w"], "h": L["h"],
		"x0": L["x0"], "x1": L["x1"], "top": L["top"], "foot": L["foot"], "cx": L["cx"], "deck": L.get("deck", 10)}


func _welder(t: float) -> void:
	weld_now = {"on": false, "x": 0.0, "y": 0.0}
	var LS := _lift_sprite()
	if not has_welder or LS.is_empty():
		return
	var P0 := weld_pose(t)
	var F := sprite("welder_strip", int(P0["f"]))
	var wx := LIFT.x - 4.0
	var wb := LIFT.y - float(LS["foot"]) + float(LS["deck"])
	var tip: Array = F["tip"]
	weld_now = {"on": bool(P0["on"]), "x": floorf(wx - float(F["cx"]) + float(tip[0]) + 0.5), "y": wb - float(F["foot"]) + float(tip[1])}
	item(LIFT.y, LIFT.y < SHIP_ROW, func(P: YardPaint) -> void:
		put(P, F, wx, wb, {"floor": LIFT.y, "shadow": false, "mirror": false})
		put(P, LS, LIFT.x, LIFT.y, {"k": 0.5}))


func _sparks(t: float, dt: float) -> void:
	if weld_now["on"]:
		for k in 3:
			sparks.append({"x": float(weld_now["x"]) + 0.5, "y": float(weld_now["y"]) + 0.5, "vx": -28.0 + 56.0 * randf(),
				"vy": -34.0 + 30.0 * randf(), "age": 0.0, "life": 0.35 + 0.5 * randf()})
	var LS := _lift_sprite()
	var keep: Array = []
	for s: Dictionary in sparks:
		s["age"] = float(s["age"]) + dt
		if float(s["age"]) > float(s["life"]):
			continue
		keep.append(s)
		s["vy"] = float(s["vy"]) + 240.0 * dt
		s["x"] = float(s["x"]) + float(s["vx"]) * dt
		s["y"] = float(s["y"]) + float(s["vy"]) * dt
		if not LS.is_empty():
			var L0 := LIFT.x - float(LS["cx"]) + float(LS["x0"]) - 1.0
			var L1 := LIFT.x - float(LS["cx"]) + float(LS["x1"]) + 1.0
			var deck := LIFT.y - float(LS["foot"]) + float(LS["deck"])
			var stop := deck if float(s["x"]) >= L0 and float(s["x"]) <= L1 else LIFT.y + 1.0
			if float(s["y"]) >= stop and float(s["vy"]) > 0.0:
				s["y"] = stop
				s["vy"] = float(s["vy"]) * -0.3
				s["vx"] = float(s["vx"]) * 0.6
	sparks = keep


## M2: a tech typing at a rolling console beside your ship; its screen flickers
## as he works, and E19 crashes it.
func _desk(t: float) -> void:
	var cu := t - float(CRASH["t0"]) if not CRASH.is_empty() else -1.0
	if not CRASH.is_empty() and cu > 3.3:
		CRASH = {}
	var blue := cu >= 0.0 and (cu < 1.95 or (cu < 2.6 and int(floorf(cu * 12.0)) % 2 == 0))
	var shake := (1.0 if int(floorf(cu * 30.0)) % 2 == 1 else -1.0) if (cu >= 1.95 and cu < 2.25) else 0.0
	var lean := -1.0 if (cu >= 1.85 and cu < 2.1) else 0.0
	var typing := not (cu >= 0.0 and cu < 2.7)
	var C := sprite("console")
	if C.is_empty():
		return
	var ntech := frames_of("tech_strip")
	var TF := sprite("tech_strip", int(floorf(t * 8.0)) % ntech if typing else 0)
	var T0 := sprite("tech_strip", 0)
	var cw := float(C["w"])
	var con_left := floorf(float(DESK["cx"]) - (cw - 1.0 - float(C["cx"])) + 0.5)
	var tx := con_left + (cw - 1.0) - 3.0 - 9.0 + float(T0["cx"])
	var feet := float(DESK["feet"])
	var left := con_left + shake
	var top := feet - float(C["foot"])
	var k0 := 0.82 + 0.18 * YardLight.hash1(floorf(t * 9.0) * 0.71)
	var row := int(floorf(fmod(t * 6.0, 12.0)))
	CONSOLE = {"x": left + (cw - 1.0) - 15.5, "y": top + 9.0, "k": k0, "blue": blue}
	var scr: Array = ((art.get("life", {}) as Dictionary).get("console", {}) as Dictionary).get("screen", [])
	var img := _console_img
	item(feet, feet < SHIP_ROW, func(P: YardPaint) -> void:
		put(P, C, float(DESK["cx"]) + shake, feet, {"flip": true})
		# the screen: flickers as lines come and go, a brighter line scrolling
		# down it; or, crashed, blue
		P.use(YardPaint.PLAIN)
		for q: Array in scr:
			var x := int(q[0])
			var y := int(q[1])
			var X := left + (cw - 1.0) - float(x)
			var Y := top + float(y)
			var c: Color
			if blue:
				c = Color8(96, 146, 238) if y % 3 == 0 else Color8(40, 88, 200)
			elif img != null:
				var k := k0 * (1.18 if y % 12 == row else 1.0)
				var o := img.get_pixel(x, y)
				c = Color(minf(1.0, o.r * k), minf(1.0, o.g * k), minf(1.0, o.b * k))
			else:
				continue
			P.rect(Rect2(X, Y, 1, 1), c)
		put(P, TF, tx + lean, feet))
	if cu > 0.35 and cu < 1.2:
		GLYPH.append([floorf(tx + 0.5) + 1.0, feet - float(TF["foot"]) + float(TF["top"]) - 9.0])


## M3: a mechanic at work on a machine on the front floor (one of Jon's five,
## picked each visit), his raised boot tapping now and then.
func _engine(t: float) -> void:
	var key: String = MECHS[int(VISIT["mech"])]
	var n := frames_of(key)
	var u := fmod(t, 4.2)
	var tap := n > 1 and u < 0.9 and int(floorf(u / 0.15)) % 2 == 1
	var F := sprite(key, 1 if tap else 0)
	var glint := key == "mech_kneel_2" and int(floorf(t * 2.2)) % 3 == 0
	item(ENG.y, ENG.y < SHIP_ROW, func(P: YardPaint) -> void:
		put(P, F, ENG.x, ENG.y, {"k": 0.45})
		if glint:
			# a glint on his wrench as he turns it
			P.use(YardPaint.PLAIN)
			P.rect(Rect2(floorf(ENG.x - float(F["cx"]) + 0.5) + 35.0, ENG.y - float(F["foot"]) + 24.0, 1, 1), Color8(255, 250, 230)))


## M4: a worker at a grinder on a bench against the back wall, between the ships
## (one of Jon's two, picked each visit).
func _bench(t: float) -> void:
	var u := fmod(t, 5.2)
	var on := u <= 3.4
	GRINDLIT = {"on": on, "x": BENCH.x + 4.0, "y": BENCH.y - 12.0}
	if int(VISIT["grind"]) == 0:
		var f := int(floorf(u * 10.0)) % 9 if on else 0
		var F := sprite("grind_strip", f)
		item(BENCH.y, BENCH.y < SHIP_ROW, func(P: YardPaint) -> void: put(P, F, BENCH.x, BENCH.y, {"k": 0.35}))
		return
	# the second grinder is a still: its sparks come off the wheel in code
	var F2 := sprite("grind_2")
	item(BENCH.y, BENCH.y < SHIP_ROW, func(P: YardPaint) -> void: put(P, F2, BENCH.x, BENCH.y, {"k": 0.35}))
	var ox := floorf(BENCH.x - float(F2["cx"]) + 0.5) + 21.0
	var oy := BENCH.y - float(F2["foot"]) + 13.0
	GRINDLIT["x"] = ox
	GRINDLIT["y"] = oy
	if on:
		for k in 2:
			gsparks.append({"x": ox, "y": oy, "vx": -12.0 - randf() * 30.0, "vy": -14.0 + randf() * 24.0, "age": 0.0, "life": 0.18 + randf() * 0.25})


# ------------------------------------------------------------------ the forklift

func _fork() -> Dictionary:
	var forks: Array = art.get("forks", [])
	return forks[clampi(int(FK["kind"]), 0, forks.size() - 1)] if not forks.is_empty() else {}


func _crate() -> Dictionary:
	return sprite("crate")


func _crate_h() -> float:
	var C := _crate()
	return float(C["foot"]) - float(C["top"]) + 1.0 if not C.is_empty() else 10.0


func _stack_top() -> float:
	return float((FK["stack"] as Array).size()) * _crate_h()


func _at_stack() -> float:
	return float(FKL["stackX"]) - float(_fork().get("slot", 0))


## The forklift's next trip: deliver until the stack is three high, then fetch
## them back down to one (the page's `fkPlan`).
func _fk_plan(t: float) -> void:
	var n := (FK["stack"] as Array).size()
	if FK["mode"] == "deliver" and n >= 3:
		FK["mode"] = "fetch"
	if FK["mode"] == "fetch" and n <= 1:
		FK["mode"] = "deliver"
	var forks: Array = art.get("forks", [])
	FK["kind"] = randi() % maxi(1, forks.size())
	var q: Array = FK["q"]
	var A := _at_stack()
	q.append({"wait": 4.0 + randf() * 7.0})
	if FK["mode"] == "deliver":
		q.append({"fn": func() -> void:
			FK["x"] = -140.0
			FK["lift"] = 0.0
			FK["load"] = 0})
		q.append({"x": A - 34.0, "v": 34.0})
		q.append({"lift": func() -> float: return _stack_top() - float(_fork().get("rest", 10)) + 1.0, "d": 0.9})
		q.append({"x": A, "v": 12.0})
		q.append({"lift": func() -> float: return float(FK["lift"]) - 2.0, "d": 0.25, "fn": func() -> void:
			(FK["stack"] as Array).append(FK["load"])
			FK["load"] = -1})
		q.append({"x": A - 34.0, "v": 18.0, "back": true})
		q.append({"x": -140.0, "v": 26.0, "lift": 0.0, "back": true})
	else:
		q.append({"fn": func() -> void:
			FK["x"] = -140.0
			FK["lift"] = 0.0
			FK["load"] = -1})
		q.append({"x": A - 34.0, "v": 34.0})
		q.append({"lift": func() -> float: return _stack_top() - _crate_h() - float(_fork().get("rest", 10)) - 1.0, "d": 0.9})
		q.append({"x": A, "v": 12.0})
		q.append({"lift": func() -> float: return float(FK["lift"]) + 3.0, "d": 0.3, "fn": func() -> void:
			FK["load"] = (FK["stack"] as Array).pop_back()})
		q.append({"x": A - 34.0, "v": 18.0, "back": true})
		q.append({"x": -140.0, "v": 26.0, "lift": 0.0, "back": true})


func _fk_step(t: float) -> void:
	if (FK["cur"] as Dictionary).is_empty():
		if (FK["q"] as Array).is_empty():
			_fk_plan(t)
		var c: Dictionary = (FK["q"] as Array).pop_front()
		c["t0"] = t
		c["fx"] = FK["x"]
		c["fl"] = FK["lift"]
		if c.has("x"):
			c["tx"] = float((c["x"] as Callable).call()) if c["x"] is Callable else float(c["x"])
		if c.has("lift"):
			c["tl"] = float((c["lift"] as Callable).call()) if c["lift"] is Callable else float(c["lift"])
		var dur := 0.0
		if c.has("wait"):
			dur = float(c["wait"])
		else:
			dur = maxf(float(c.get("d", 0.0)), absf(float(c["tx"]) - float(FK["x"])) / float(c["v"]) if c.has("tx") else 0.0)
		c["dur"] = dur if dur > 0.0 else 0.01
		FK["cur"] = c
	var cur: Dictionary = FK["cur"]
	var u := clampf((t - float(cur["t0"])) / float(cur["dur"]), 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	FK["moving"] = 1 if cur.has("tx") and u < 1.0 else 0
	FK["back"] = bool(cur.get("back", false)) and int(FK["moving"]) == 1
	if cur.has("tx"):
		FK["x"] = float(cur["fx"]) + (float(cur["tx"]) - float(cur["fx"])) * (u if cur.has("v") else e)
	if cur.has("tl"):
		FK["lift"] = float(cur["fl"]) + (float(cur["tl"]) - float(cur["fl"])) * e
	if u >= 1.0:
		if cur.has("fn"):
			(cur["fn"] as Callable).call()
		FK["cur"] = {}


## The forklift's roof beacon (Jon: "A is good."): a flash every 0.8 s that
## fades, then a dim glow.
static func beacon_pulse(t: float) -> float:
	var ph := fmod(t * 1.25, 1.0)
	return 1.0 - ph / 0.3 * 0.6 if ph < 0.3 else 0.12


func _forklift(t: float) -> void:
	FORKLIT["on"] = false
	var FB := _fork()
	if FB.is_empty():
		return
	var lane := float(FKL["lane"])
	# the stack, bottom crate first
	var C := _crate()
	var h := 0.0
	var st: Array = FK["stack"]
	for k in st.size():
		var b := lane - h
		var x := float(FKL["stackX"]) + (float(C["x1"]) - float(C["x0"])) / 2.0
		h += _crate_h()
		var kk := k
		item(lane + 0.1 + float(k) * 0.01, false, func(P: YardPaint) -> void: put(P, C, x, b, {"floor": lane, "shadow": kk == 0}))
	var fx := float(FK["x"])
	if fx < -130.0 or fx > 800.0:
		return
	var B := sprite(String(FB["body"]).trim_prefix("life_").trim_suffix(".png"))
	var BL := sprite(String(FB["blade"]).trim_prefix("life_").trim_suffix(".png"))
	var top := lane - float(B["foot"])
	var lift_px := floorf(float(FK["lift"]) + 0.5)
	var x2 := fx + float(B["cx"])
	var beacon: Array = FB.get("beacon", [0, 0])
	var bx := floorf(x2 - float(B["cx"]) + 0.5) + float(beacon[0])
	var by := lane - float(B["foot"]) + float(beacon[1]) - 1.0
	var hot := beacon_pulse(t) > 0.5
	FORKLIT = {"on": true, "x": bx, "y": by, "lane": lane, "front": floorf(x2 - float(B["cx"]) + 0.5) + float(B["x1"])}
	var load := int(FK["load"])
	var bl := floorf(fx + 0.5) + float(BL["x0"])
	var bt := top + float(FB.get("bladeTop", 0)) - lift_px
	item(lane, false, func(P: YardPaint) -> void:
		put(P, B, x2, lane, {"floor": lane, "k": 0.5, "shadow": true})
		for d: Array in [[-1, -1], [0, -1], [-1, 0], [0, 0]]:
			var c: Color
			if hot:
				c = Color8(255, 226, 150) if int(d[1]) < 0 else Color8(255, 176, 60)
				P.use(YardPaint.PLAIN)
			else:
				c = Color8(150, 96, 44) if int(d[1]) < 0 else Color8(112, 64, 26)
				P.use(YardPaint.FLOOR, YardScene.cell(x2, lane))
			P.rect(Rect2(bx + float(d[0]), by + float(d[1]), 1, 1), c)
		# the blades, and the crate on them, at the lift's height
		P.use(YardPaint.FLOOR, YardScene.cell(x2, lane))
		P.tex(BL["tex"], Vector2(floorf(fx + 0.5), top - lift_px), BL["src"])
		if load >= 0:
			put(P, C, bl + (float(C["x1"]) - float(C["x0"])) / 2.0, bt - 1.0, {"floor": lane, "shadow": false}))


# ------------------------------------------------------------------ the rare floor events

## E10: a little cleaning bot trundles along, bumps into a crewman's boots, and
## reverses away.
func send_bot(t: float) -> bool:
	if not BOT.is_empty() or not RIDE.is_empty():
		return false
	BOT = {"x": -14.0, "dir": 1.0, "v": 13.0, "state": "go", "t0": t, "bumped": false}
	return true


func _bot(t: float, dt: float) -> void:
	if BOT.is_empty():
		return
	var b := BOT
	var lane := 446.0
	var w: Dictionary = {}
	for c: Dictionary in CREW:
		if String(c["name"]) == "f_welder":
			w = c
	var S := sprite("bot")
	if b["state"] == "go":
		b["x"] = float(b["x"]) + float(b["dir"]) * float(b["v"]) * dt
		if not w.is_empty():
			var wp := walk_at(w, t)
			if not b["bumped"] and absf(float(wp["x"]) - float(b["x"])) < 12.0 and (float(wp["x"]) - float(b["x"])) * float(b["dir"]) > 0.0:
				b["state"] = "bonk"
				b["t0"] = t
				b["bumped"] = true
		if float(b["x"]) > 470.0 and float(b["dir"]) > 0.0:
			b["dir"] = -1.0
		if float(b["x"]) < -20.0 and float(b["dir"]) < 0.0:
			BOT = {}
			return
	elif b["state"] == "bonk":
		var u := t - float(b["t0"])
		if u < 0.1:
			b["x"] = float(b["x"]) - float(b["dir"]) * 30.0 * dt
		if u > 0.2 and u < 0.8:
			GLYPH.append([floorf(float(b["x"]) + 0.5), lane - float(S["foot"]) + float(S["top"]) - 9.0])
		if u >= 0.9:
			b["state"] = "go"
			b["dir"] = -float(b["dir"])
			b["v"] = 18.0
	var x := float(b["x"])
	var fl := float(b["dir"]) < 0.0
	item(lane + 0.2, false, func(P: YardPaint) -> void:
		put(P, S, x, lane, {"flip": fl, "k": 0.45})
		_bot_lamp(P, S, x, lane, fl))


## The bot's green lamp burns on its own.
func _bot_lamp(P: YardPaint, S: Dictionary, x: float, bottom: float, flip: bool) -> void:
	var em: Array = ((art.get("life", {}) as Dictionary).get("bot", {}) as Dictionary).get("em", [])
	if em.is_empty() or _bot_img == null:
		return
	var w := float(S["w"])
	var cx := w - 1.0 - float(S["cx"]) if flip else float(S["cx"])
	var left := floorf(x - cx + 0.5)
	var top := bottom - float(S["foot"])
	P.use(YardPaint.PLAIN)
	for q: Array in em:
		var sx := int(q[0])
		var sy := int(q[1])
		var dx := (w - 1.0 - float(sx)) if flip else float(sx)
		P.rect(Rect2(left + dx, top + float(sy), 1, 1), _bot_img.get_pixel(sx, sy))


## E11: the station cat trots in, sits, washes, and wanders back out.
func send_cat(t: float) -> bool:
	if not CAT.is_empty() or not RIDE.is_empty() or not CHASE.is_empty():
		return false
	CAT = {"x": -24.0, "state": "in", "t0": t, "stop": 170.0 + floorf(randf() * 60.0 + 0.5)}
	return true


func _cat(t: float) -> void:
	if CAT.is_empty():
		return
	var c := CAT
	var lane := 458.0
	var pace := 22.0
	var adv := 2.75
	var F: Dictionary
	var flip := false
	var u := maxf(0.0, t - float(c["t0"]))
	var st := String(c["state"])
	if st == "in":
		var d := pace * u
		var x := -24.0 + floorf(d / adv) * adv
		c["x"] = x
		F = sprite("cat_walk", int(floorf(d / adv)) % 8)
		if x >= float(c["stop"]):
			c["state"] = "sit"
			c["t0"] = t
			c["x"] = c["stop"]
	elif st == "sit":
		F = sprite("cat_sit", mini(7, int(floorf(u * 10.0))))
		if u > 1.0:
			c["state"] = "lick"
			c["t0"] = t
	elif st == "lick":
		F = sprite("cat_lick", int(floorf(u * 9.0)) % 12)
		if u > 12.0 / 9.0 * 2.0:
			c["state"] = "rise"
			c["t0"] = t
	elif st == "rise":
		F = sprite("cat_sit", maxi(0, 7 - int(floorf(u * 10.0))))
		if u > 0.9:
			c["state"] = "out"
			c["t0"] = t
	else:
		var d2 := pace * u
		c["xo"] = float(c["stop"]) - floorf(d2 / adv) * adv
		F = sprite("cat_walk", int(floorf(d2 / adv)) % 8)
		flip = true
		if float(c["xo"]) < -30.0:
			CAT = {}
			return
	# the tick it turns to go it has not stepped yet: it is still where it sat
	var x2 := float(c.get("xo", c["x"])) if String(c["state"]) == "out" else float(c["x"])
	item(lane + 0.3, false, func(P: YardPaint) -> void: put(P, F, x2, lane, {"flip": flip, "k": 0.4}))


## E12: the cat rides the bot out, washes a paw while it waits, and rides back.
func cat_ride(t: float) -> bool:
	if not RIDE.is_empty() or not BOT.is_empty() or not CAT.is_empty():
		return false
	RIDE = {"x": -16.0, "dir": 1.0, "t0": t, "state": "go", "turnX": 280.0 + floorf(randf() * 90.0 + 0.5)}
	return true


func _ride(t: float, dt: float) -> void:
	if RIDE.is_empty():
		return
	var r := RIDE
	var lane := 452.0
	if r["state"] == "go":
		r["x"] = float(r["x"]) + float(r["dir"]) * 30.0 * dt
		if float(r["dir"]) > 0.0 and float(r["x"]) >= float(r["turnX"]):
			r["state"] = "pause"
			r["tp"] = t
		if float(r["dir"]) < 0.0 and float(r["x"]) < -24.0:
			RIDE = {}
			return
	elif r["state"] == "pause" and t - float(r["tp"]) > 2.7:
		r["state"] = "go"
		r["dir"] = -1.0
	var B := sprite("bot")
	var cat := sprite("cat_lick", int(floorf((t - float(r["tp"])) * 9.0)) % 12) if r["state"] == "pause" else sprite("cat_sit", 7)
	var bot_top := lane - (float(B["foot"]) - float(B["top"]))
	var x := float(r["x"])
	var fl := float(r["dir"]) < 0.0
	item(lane + 0.25, false, func(P: YardPaint) -> void:
		put(P, B, x, lane, {"flip": fl, "k": 0.45})
		_bot_lamp(P, B, x, lane, fl)
		put(P, cat, x, bot_top + 1.0, {"floor": lane, "flip": fl, "shadow": false}))


## E13 A PAPER PLANE: thrown from the back of the hall, it glides down toward you
## in swoops, lands and skids to a stop; its shadow runs along the floor under it.
func paper_plane(t: float) -> bool:
	if not PLANE.is_empty():
		return false
	PLANE = {"t0": t, "x0": 380.0 + randf() * 60.0, "x1": 150.0 + randf() * 90.0}
	return true


func plane_at(t: float) -> Dictionary:
	var p := PLANE
	var u := (t - float(p["t0"])) / 5.2
	if u < 1.0:
		var d := 234.0 + (438.0 - 234.0) * u
		var h := 38.0 * pow(1.0 - u, 1.2) + 6.0 * sin(u * PI * 4.0) * (1.0 - u)
		return {"x": float(p["x0"]) + (float(p["x1"]) - float(p["x0"])) * u + 12.0 * sin(u * PI * 3.0), "d": d, "h": maxf(0.0, h), "landed": false}
	var s := minf(1.0, (u - 1.0) * 5.2 / 0.5)
	return {"x": float(p["x1"]) - 12.0 * (1.0 - (1.0 - s) * (1.0 - s)), "d": 438.0, "h": 0.0, "landed": true}


func _plane_shadow() -> void:
	if PLANE.is_empty():
		return
	var t := scene.now()
	if t - float(PLANE["t0"]) > 5.2 + 14.0:
		PLANE = {}
		return
	var q := plane_at(t)
	if q["landed"] or float(q["h"]) <= 1.0:
		return
	var art2: Array = PLANE_ART["far"] if float(q["d"]) < 300.0 else (PLANE_ART["mid"] if float(q["d"]) < 380.0 else PLANE_ART["near"])
	var w := 7.0 if art2 == PLANE_ART["near"] else (5.0 if art2 == PLANE_ART["mid"] else 3.0)
	var x := float(q["x"])
	var d := float(q["d"])
	item(d, d < SHIP_ROW, func(P: YardPaint) -> void:
		P.use(YardPaint.PLAIN)
		scene.shade(P, floorf(x + 0.5), floorf(d + 0.5), 2.0 + w / 3.0, 1.0, 0.35))


func _draw_plane(P: YardPaint, t: float) -> void:
	if PLANE.is_empty():
		return
	var q := plane_at(t)
	var art2: Array = PLANE_ART["far"] if float(q["d"]) < 300.0 else (PLANE_ART["mid"] if float(q["d"]) < 380.0 else PLANE_ART["near"])
	var w := 7.0 if art2 == PLANE_ART["near"] else (5.0 if art2 == PLANE_ART["mid"] else 3.0)
	var x := floorf(float(q["x"]) - w / 2.0 + 0.5)
	var y := floorf(float(q["d"]) - float(q["h"]) + 0.5) - (4.0 if art2 == PLANE_ART["near"] else 3.0)
	var M := scene.light.m_at(float(q["x"]), float(q["d"]))
	P.use(YardPaint.PLAIN)
	for a: Array in art2:
		P.rect(Rect2(x + float(a[0]), y + float(a[1]), float(a[2]), 1), YardScene.lit(Color(String(a[3])), M))


## E14 SOMEONE LOOKS OUT OF A HATCH: a floor hatch lifts, a crewman's head comes
## up, looks left, looks right, ducks back down, and the lid drops. The hatch's
## plate is always there, set in the floor.
func hatch_peek(t: float) -> bool:
	if not HEAD.is_empty():
		return false
	HEAD = {"t0": t, "who": ["look_rigger", "look_welder", "look_suit"][randi() % 3]}
	return true


func _hatch(t: float) -> void:
	var u := t - float(HEAD["t0"]) if not HEAD.is_empty() else -1.0
	if not HEAD.is_empty() and u > 4.2:
		HEAD = {}
		u = -1.0
	var lid := 0.0
	if u >= 0.0:
		lid = u / 0.3 if u < 0.3 else (1.0 if u < 3.6 else (1.0 - (u - 3.6) / 0.3 if u < 3.9 else 0.0))
	var rise := 0.0
	if u >= 0.35:
		rise = (u - 0.35) / 0.55 if u < 0.9 else (1.0 if u < 3.0 else (1.0 - (u - 3.0) / 0.5 if u < 3.5 else 0.0))
	var who := String(HEAD.get("who", ""))
	var x0 := HATCH.x - 7.0
	var y0 := HATCH.y - 3.0
	var dark := Color8(40, 43, 47)
	item(HATCH.y - 0.2, false, func(P: YardPaint) -> void:
		P.use(YardPaint.HALL)
		if lid <= 0.0:
			# closed: a plate in the floor, rimmed, with two bolts
			P.rect(Rect2(x0, y0, 14, 1), dark)
			P.rect(Rect2(x0, y0 + 3.0, 14, 1), dark)
			P.rect(Rect2(x0, y0 + 1.0, 14, 1), Color8(104, 110, 116))
			P.rect(Rect2(x0, y0 + 2.0, 14, 1), Color8(78, 83, 89))
			P.rect(Rect2(x0 - 1.0, y0, 1, 4), dark)
			P.rect(Rect2(x0 + 14.0, y0, 1, 4), dark)
			P.rect(Rect2(x0 + 2.0, y0 + 2.0, 1, 1), Color8(140, 146, 152))
			P.rect(Rect2(x0 + 11.0, y0 + 2.0, 1, 1), Color8(140, 146, 152))
			return
		# open: the hole, dark, and the lid standing up on its back edge
		P.rect(Rect2(x0 - 1.0, y0, 16, 1), Color8(24, 26, 29))
		P.rect(Rect2(x0 - 1.0, y0 + 1.0, 16, 3), Color8(12, 13, 15))
		var lh := int(floorf(8.0 * lid + 0.5))
		for y in range(1, lh + 1):
			for x in 14:
				var c: Color
				if y == lh or x == 0 or x == 13:
					c = dark
				else:
					c = Color8(88 + (y & 1) * 10, 94 + (y & 1) * 10, 100 + (y & 1) * 10)
				P.rect(Rect2(x0 + float(x), y0 - float(y), 1, 1), c)
		if rise > 0.0 and who != "":
			# the head and shoulders, from the top of a walker's standing pose
			var img := crew_image(who)
			var C := crew_strip(who)
			if img != null:
				var fw := int(C.get("frame_w", 20))
				var sf := stand_frame(who)
				var n := int(floorf(15.0 * rise + 0.5))
				var flipped := u > 0.9 and u < 1.8
				for y2 in n:
					for x2 in fw:
						var sx := fw - 1 - x2 if flipped else x2
						var c2 := img.get_pixel(sf * fw + sx, y2)
						if c2.a8 < 128:
							continue
						P.rect(Rect2(HATCH.x - float(fw >> 1) + float(x2), y0 + 1.0 - float(n) + float(y2), 1, 1), Color(c2.r, c2.g, c2.b)))
	if u > 2.2 and u < 2.8:
		GLYPH.append([HATCH.x + 1.0, y0 - floorf(15.0 * rise + 0.5) - 9.0])


## E17 A STRAY BALLOON: someone's red balloon drifts up between the ships and
## bumps along under the ceiling lights until it is gone.
func balloon(t: float) -> bool:
	if not BALLOON.is_empty():
		return false
	BALLOON = {"t0": t, "x0": 380.0 + randf() * 50.0}
	return true


func balloon_at(t: float) -> Vector2:
	var u := t - float(BALLOON["t0"])
	var y_top := 42.0
	var y0 := 300.0
	var rise := 17.0
	var t_up := (y0 - y_top) / rise
	var x0 := float(BALLOON["x0"])
	if u < t_up:
		return Vector2(x0 + 6.0 * sin(u * 1.3), y0 - rise * u)
	var v := u - t_up
	return Vector2(x0 + 6.0 * sin(t_up * 1.3) + 12.0 * v, y_top + 1.5 * sin(v * 2.4))


func _draw_balloon(P: YardPaint, t: float) -> void:
	if BALLOON.is_empty():
		return
	var q := balloon_at(t)
	var x := floorf(q.x + 0.5)
	var y := floorf(q.y + 0.5)
	if x > 790.0:
		BALLOON = {}
		return
	var M := scene.light.m_air()
	P.use(YardPaint.PLAIN)
	var string_c := YardScene.lit(Color("#c9c2b8"), M)
	for k in 11:
		P.rect(Rect2(x + floorf(sin(t * 3.0 + float(k) * 0.6) * (float(k) / 11.0) * 1.5 + 0.5), y + 8.0 + float(k), 1, 1), string_c)
	var R := YardScene.lit(Color("#c8322a"), M)
	var D := YardScene.lit(Color("#8e1f1a"), M)
	var H := YardScene.lit(Color("#ff9d8f"), M)
	P.rect(Rect2(x - 2.0, y, 5, 1), R)
	P.rect(Rect2(x - 3.0, y + 1.0, 7, 4), R)
	P.rect(Rect2(x - 2.0, y + 5.0, 5, 1), R)
	P.rect(Rect2(x - 1.0, y + 6.0, 3, 1), D)
	P.rect(Rect2(x, y + 7.0, 1, 1), D)
	P.rect(Rect2(x + 3.0, y + 2.0, 1, 3), D)
	P.rect(Rect2(x + 1.0, y + 5.0, 2, 1), D)
	P.rect(Rect2(x - 2.0, y + 1.0, 2, 1), H)
	P.rect(Rect2(x - 2.0, y + 2.0, 1, 1), H)


## E19 THE CONSOLE CRASHES: the tech's screen goes blue; he stops, stares,
## gives the console a thump, and it flickers back to life.
func crash(t: float) -> bool:
	if not CRASH.is_empty():
		return false
	CRASH = {"t0": t}
	return true


## E20 THE CAT CHASES A DRONE: a small drone skims low across the floor, just
## out of reach, with the cat running flat out behind it.
func cat_chase(t: float) -> bool:
	if not CHASE.is_empty() or not CAT.is_empty() or not RIDE.is_empty():
		return false
	CHASE = {"t0": t, "k": randi() % 3}
	return true


func _chase(t: float) -> void:
	if CHASE.is_empty():
		return
	var u := maxf(0.0, t - float(CHASE["t0"]))
	var lane := 454.0
	var dx := -30.0 + 46.0 * u
	var cx := dx - 34.0
	if cx > 800.0:
		CHASE = {}
		return
	var Fd := sprite("drone_%d" % (int(CHASE["k"]) + 1))
	var hop := floorf(10.0 + 3.0 * sin(u * 5.0) + 0.5)
	var stp := int(floorf(maxf(0.0, cx + 40.0) / 2.75))
	var Fc := sprite("cat_walk", stp % 8)
	CHASE["last"] = [dx, cx]
	item(lane + 0.35, false, func(P: YardPaint) -> void:
		put(P, Fd, dx, lane - hop, {"floor": lane, "shadow": true, "k": 0.3})
		put(P, Fc, cx, lane, {"k": 0.4}))


# ------------------------------------------------------------------ in the air

## D1: the station's own flyers, crossing high by the ceiling lights now and then.
func send_flyer(t: float) -> bool:
	var k: String = AMBF[randi() % AMBF.size()]
	var F: Dictionary = (art.get("flyers", {}) as Dictionary).get(k, {})
	if F.is_empty():
		return false
	var dir := 1.0 if randf() < 0.5 else -1.0
	var fw := float(F["fw"])
	AMB.append({"F": F, "dir": dir, "v": 40.0 + randf() * 22.0, "y": 10.0 + floorf(randf() * 14.0 + 0.5), "t0": t,
		"x0": -fw / 2.0 - 4.0 if dir > 0.0 else 766.0 + fw / 2.0 + 4.0, "seed": randf() * 10.0})
	return true


func _draw_flyers(P: YardPaint, t: float) -> void:
	var M := YardScene.quant(scene.light.m_air())
	P.use(YardPaint.PLAIN)
	var keep: Array = []
	for f: Dictionary in AMB:
		var x := float(f["x0"]) + float(f["dir"]) * float(f["v"]) * (t - float(f["t0"]))
		var y := float(f["y"]) + floorf(2.0 * sin(t * 2.3 + float(f["seed"])) + 0.5)
		if x < -80.0 or x > 846.0:
			continue
		keep.append(f)
		var F: Dictionary = f["F"]
		var fw := float(F["fw"])
		var fh := float(F["fh"])
		var fi := int(floorf(t * 10.0 + float(f["seed"]) * 7.0)) % 12
		P.tex(scene.tex_abs(String(F["picture"])), Vector2(floorf(x - fw / 2.0 + 0.5), floorf(y - fh / 2.0 + 0.5)), Rect2(fi * fw, 0, fw, fh), M)
	AMB = keep


## D2: small far-off drones along the back wall, some with a little crate slung
## underneath.
func send_small(t: float) -> bool:
	var dir := 1.0 if randf() < 0.5 else -1.0
	SMALL.append({"k": randi() % 3, "dir": dir, "v": 16.0 + randf() * 12.0, "y": 140.0 + floorf(randf() * 24.0 + 0.5), "t0": t,
		"x0": -12.0 if dir > 0.0 else 778.0, "seed": randf() * 9.0, "crate": randf() < 0.4})
	return true


func _draw_small(P: YardPaint, t: float) -> void:
	var M := scene.light.m_air()
	var Mq := YardScene.quant(M)
	P.use(YardPaint.PLAIN)
	var keep: Array = []
	for s: Dictionary in SMALL:
		var x := float(s["x0"]) + float(s["dir"]) * float(s["v"]) * (t - float(s["t0"]))
		var y := float(s["y"]) + floorf(sin(t * 3.0 + float(s["seed"])) + 0.5)
		if x < -20.0 or x > 786.0:
			continue
		keep.append(s)
		var F := sprite("drone_%d" % (int(s["k"]) + 1))
		if bool(s["crate"]):
			var cx := floorf(x + 0.5)
			var cy := y + 3.0
			P.px(cx, cy - 2.0, 1, 2, YardScene.lit(Color("#2a2e33"), M))
			P.px(cx - 2.0, cy, 5, 4, YardScene.lit(Color("#4a3622"), M))
			P.px(cx - 1.0, cy + 1.0, 3, 2, YardScene.lit(Color("#8a6a44"), M))
		P.tex(F["tex"], Vector2(floorf(x - float(F["cx"]) + 0.5), floorf(y - float(F["foot"]) + 0.5)), F["src"], Mq)
	SMALL = keep


# ------------------------------------------------------------------ in the wall

func _setup_city() -> void:
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


## THE CITY'S LIFTS (Jon: "THEYRE SOOO COOL"): each car stops, its doors slide
## open, whoever rode steps out, one or two step in (now and then nobody), the
## doors close with them behind the glass, and it goes (the page's `drawLifts`).
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


## THE CAPITAL'S ROSE WINDOW looks out on space: stars drifting slowly past
## behind its gold tracery, left to right, the brighter ones faster (Jon: "the
## stars should move slowly left to right ... not circling").
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


# ------------------------------------------------------------------ the frame

## This tick's floor, before anything is drawn: who is where, and what lights up.
## The yard is going. A closure here holds this object -- a draw item, a crew
## member's event, a step of the forklift's run -- and an event also holds the
## crew member it sits on, so let go of every one, or this keeps itself and its
## pictures alive after the scene has gone.
func release() -> void:
	for c: Dictionary in CREW + RUN:
		c.erase("ev")
	_items = []
	CREW = []
	RUN = []
	SHUF = {}
	FK = {}
	last_forgot = {}


func tick(t: float, dt: float) -> void:
	_items.clear()
	GLYPH.clear()
	_shuffle_step(t)
	_crew(t)
	_welder(t)
	_desk(t)
	_engine(t)
	_bench(t)
	_fk_step(t)
	_forklift(t)
	_bot(t, dt)
	_cat(t)
	_ride(t, dt)
	_hatch(t)
	_chase(t)
	_plane_shadow()


## The small lights the floor makes this tick (the page's `lightDynamic`, the
## floor's part): the tech's screen on him, the grinder's sparks at the bench,
## the welder's arc on the belly over it, the forklift's beacon and work lights.
func light_up(t: float) -> void:
	var dyn: Array = scene.light.dyn
	if float(CONSOLE["k"]) > 0.0:
		dyn.append([CONSOLE["x"], CONSOLE["y"], 24.0, 20.0, 0.5, Color(0.35, 0.55, 1.0) if CONSOLE["blue"] else Color(0.45, 0.95, 1.0), CONSOLE["k"]])
	if GRINDLIT["on"]:
		dyn.append([GRINDLIT["x"], GRINDLIT["y"], 22.0, 16.0, 1.0, Color(1.0, 0.62, 0.25), 0.6 + 0.4 * YardLight.hash1(floorf(t * 20.0) * 1.93)])
	if weld_now["on"]:
		var fl := 0.55 + 0.45 * YardLight.hash1(floorf(t * 22.0) * 1.37)
		var arc := Color(0.75, 0.86, 1.0)
		dyn.append([weld_now["x"], weld_now["y"], 64.0, 46.0, 1.5, arc, fl])
		dyn.append([weld_now["x"], LIFT.y + 2.0, 80.0, 18.0, 0.9, arc, fl])
	if FORKLIT["on"]:
		dyn.append([FORKLIT["x"], float(FORKLIT["y"]) + 4.0, 22.0, 15.0, 0.9, Color(1.0, 0.6, 0.2), beacon_pulse(t)])
		dyn.append([float(FORKLIT["front"]) + 24.0, float(FORKLIT["lane"]) - 1.0, 32.0, 9.0, 0.85, Color(1.0, 0.95, 0.84), 1.0])


## What lives in the wall: the city's tenants and lifts, the capital's stars.
func draw_wall(P: YardPaint, t: float, dt: float) -> void:
	if not LIFE.is_empty():
		_tenants(P, dt)
		_lifts(P, dt)
	_stars(P, t)


## The floor, back to front: behind the ships into `back`, in front into `front`.
func draw_floor(back: YardPaint, front: YardPaint) -> void:
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for it: Dictionary in _items:
		(it["draw"] as Callable).call(back if bool(it["back"]) else front)


## Dust in the lamps' light: specks drifting slowly, seen only where a cone is
## bright (the page's `drawDust`).
func draw_dust(P: YardPaint, t: float, dt: float) -> void:
	var L := scene.light
	var c := L.dust_col
	P.use(YardPaint.PLAIN)
	for n in mini(DUST.size(), L.dust_n):
		var p: Dictionary = DUST[n]
		p["x"] = float(p["x"]) + (float(p["vx"]) + sin(t * 0.6 + float(p["ph"])) * 1.4) * dt
		p["y"] = float(p["y"]) + (float(p["vy"]) + cos(t * 0.45 + float(p["ph"])) * 0.6) * dt
		if float(p["y"]) < 24.0:
			p["y"] = 176.0
			p["x"] = YardLight.hash1(float(p["ph"]) + t) * 766.0
		if float(p["x"]) < 0.0:
			p["x"] = float(p["x"]) + 766.0
		if float(p["x"]) >= 766.0:
			p["x"] = float(p["x"]) - 766.0
		var x := clampi(int(floorf(float(p["x"]) + 0.5)), 0, 765)
		var y := clampi(int(floorf(float(p["y"]) + 0.5)), 0, 481)
		var s := L.s_at(x, y)
		if s < 0.6 or L.own_at(x, y) != 0 or scene.covered(x, y):
			continue
		P.rect(Rect2(x, y, 1, 1), Color(c.r, c.g, c.b, minf(0.8, (s - 0.6) * 1.2)))


## Over the light: the popping bulb's sparks, the moths, the flyers, the small
## drones, the welder's and the grinder's sparks, a balloon, a paper plane.
func draw_air(P: YardPaint, t: float, dt: float) -> void:
	_draw_pop_sparks(P, t, dt)
	_draw_moths(P, t)
	_draw_flyers(P, t)
	_draw_small(P, t)
	P.use(YardPaint.PLAIN)
	for s: Dictionary in sparks:
		var a := float(s["age"]) / float(s["life"])
		var col := Color("#ffffff") if a < 0.15 else (Color("#ffe9a8") if a < 0.4 else (Color("#ffb347") if a < 0.7 else Color("#c0501a")))
		P.px(float(s["x"]), float(s["y"]), 1, 1, col)
	var keep: Array = []
	for g: Dictionary in gsparks:
		g["age"] = float(g["age"]) + dt
		if float(g["age"]) > float(g["life"]):
			continue
		keep.append(g)
		g["vy"] = float(g["vy"]) + 200.0 * dt
		g["x"] = float(g["x"]) + float(g["vx"]) * dt
		g["y"] = float(g["y"]) + float(g["vy"]) * dt
		var a2 := float(g["age"]) / float(g["life"])
		P.px(float(g["x"]), float(g["y"]), 1, 1, Color("#fff6d8") if a2 < 0.3 else (Color("#ffb347") if a2 < 0.7 else Color("#c0501a")))
	gsparks = keep
	_draw_balloon(P, t)
	_draw_plane(P, t)


## A walker's "!", a startled tech's, the bot's (the page's `drawGlyphs`).
func draw_glyphs(P: YardPaint) -> void:
	P.use(YardPaint.PLAIN)
	var out := Color("#0a0e15")
	var ink := Color("#ffd28a")
	for g: Array in GLYPH:
		var x := float(g[0])
		var y := float(g[1])
		P.px(x - 1.0, y - 1.0, 3, 7, out)
		P.px(x, y, 1, 4, ink)
		P.px(x, y + 5.0, 1, 1, ink)


## THE POP: the bulb flashes, spits a shower of sparks that fall to the floor
## and bounce, and is dark a moment.
func pop_bulb(t: float) -> void:
	var L := scene.light
	if L.pop_k < 0:
		return
	var at: Array = (L.lights[L.pop_k] as Dictionary).get("at", [0, 0])
	L.pop_t0 = t
	L.pop_off = 0.9 + 1.2 * randf()
	L.pop_next = t + 16.0 + 18.0 * randf()
	var x := float(at[0])
	var y := float(at[1])
	for n in 18:
		var a := randf() * TAU
		var v := 10.0 + randf() * 34.0
		pop_sparks.append({"x": x + (randf() - 0.5) * 2.0, "y": y - 2.0 + (randf() - 0.5) * 2.0, "vx": cos(a) * v, "vy": sin(a) * v * 0.8 + 10.0,
			"t0": t, "life": 0.5 + randf() * 1.1})


func _draw_pop_sparks(P: YardPaint, t: float, dt: float) -> void:
	var floor_y := 207.0 + 2.0
	P.use(YardPaint.PLAIN)
	var keep: Array = []
	for s: Dictionary in pop_sparks:
		var u := (t - float(s["t0"])) / float(s["life"])
		if u >= 1.0:
			continue
		keep.append(s)
		s["vy"] = float(s["vy"]) + 190.0 * dt
		s["x"] = float(s["x"]) + float(s["vx"]) * dt
		s["y"] = float(s["y"]) + float(s["vy"]) * dt
		if float(s["y"]) > floor_y and float(s["vy"]) > 0.0:
			s["y"] = floor_y
			s["vy"] = float(s["vy"]) * -0.35
			s["vx"] = float(s["vx"]) * 0.6
		var col := Color("#fff6d8") if u < 0.25 else (Color("#ffd27a") if u < 0.55 else (Color("#ff9a3c") if u < 0.8 else Color("#b8562a")))
		P.px(float(s["x"]), float(s["y"]), 1, 1, col)
		if u < 0.3 and sqrt(float(s["vx"]) * float(s["vx"]) + float(s["vy"]) * float(s["vy"])) > 28.0:
			P.px(float(s["x"]) - float(s["vx"]) * 0.03, float(s["y"]) - float(s["vy"]) * 0.03, 1, 1, col)
	pop_sparks = keep


## THE SETTLEMENT'S MOTHS: two or three round each pendant lamp, drawn to its
## warm light, flitting under the shade.
func _draw_moths(P: YardPaint, t: float) -> void:
	var L := scene.light
	if not bool(L.doc.get("moths", false)):
		return
	var lamps: Array = L.doc.get("moth_lamps", [])
	if lamps.is_empty():
		return
	P.use(YardPaint.PLAIN)
	for m: Dictionary in MOTHS:
		var li := int(m["lamp"]) % lamps.size()
		var c: Dictionary = lamps[li]
		if L.nw[int(L.ceil_idx[li])] < 0.5:
			continue
		var u := t * float(m["sp"]) + float(m["ph"])
		var r := float(m["r"])
		var x := float(c["x"]) + r * sin(u * 1.7) + 3.0 * sin(u * 5.3 + float(m["ph"]))
		var y := float(c["y"]) + 9.0 + r * 0.7 * (0.5 + 0.5 * sin(u * 2.3 + 1.0)) + 2.0 * sin(u * 7.1)
		P.px(x, y, 1, 1, Color("#f6e9c8") if int(floorf(t * 16.0 + float(m["ph"]))) % 2 == 1 else Color("#a8977a"))
