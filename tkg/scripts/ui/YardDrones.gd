class_name YardDrones
extends RefCounted

## The Yard's four services, each carried on one of the station's flyer drones
## over your ship (the Yard Drones page's drones, `step`, `carry`, `buy`,
## `drawDrone`, `drawWork`): PATCH, REPAIR, REFUEL and FAULTS.
##
## THEY COME AFTER THE TV (Jon: "can we have the drones fly in more spread out
## AFTER the TV turns on ?", then "closer together ... but not all at the same
## time"): the first 0.4 s after the deal has scanned onto the TV, the others
## about 0.42 s behind each other. Each bobs above your ship, and what it
## carries says what it will do and what it costs. Pointed at, its glass lights
## amber; clicked, it dips to the hull and does the work -- a torch for a patch,
## a welder's white for a repair, fuel coming down, a scan down the hull for a
## fault. When there is nothing left for it to do its screen says why ("HULL
## FULL", "NO FAULTS") and it flies off; on paper, at an unclaimed station, what
## it offered is scribbled out in red first.
##
## WHAT THEY CARRY is the level's (Jon, 2026-09-29): paper scraps at an
## unclaimed station, chunky casings at an outpost or settlement, riveted
## frames in a city, glowing frames at a capital.
##
## AND NOW AND THEN, ONE OF THEM MISBEHAVES (the page's rare events): it nods
## off and sinks (E1), two bump screens (E5), one shows a joke (E6), one
## sneezes (E18).

const PH := [0.0, 1.3, 0.6, 2.1]
## The flyers that carry the four screens (the station's own, twelve frames).
const FLYERS := ["d8", "d5", "d9", "d12"]
## Text on glass is the station's own ink; on paper it is written in dark ink
## and a rust red.
const INK_SCREEN := {"l": Color("#c3d2e2"), "p": Color("#f0a030"), "poor": Color("#5a6470"), "flash": Color("#ffd28a"),
	"done": Color("#6b7d94"), "shadow": true}
const INK_PAPER := {"l": Color("#2a2118"), "p": Color("#8a2a10"), "poor": Color("#8a7f62"), "flash": Color("#2d5a1e"),
	"done": Color("#6a5a40"), "shadow": false}
const AMBER := Color("#f0a030")
const PEN := [Color("#d8412f"), Color("#c42b1f"), Color("#c42b1f"), Color("#8e1c14")]
const JOKES := ["BACK IN 5", "LUNCH", "NO", "BRB", "ON BREAK", "ASK LATER", "404", "HMM"]

var scene: YardScene
## The level's set: P paper, B casings, A riveted frames, C glowing frames.
var set_key := "B"
var paper := false
var screens: Array = []
var fly: Array = []
## The four drones: each {i, hx, hy, mode, t0, x, y, ...}.
var D: Array = []
## The work on the hull, seen: [{i, t0, hx}].
var FX: Array = []
## What was hovered, and whether it is a drone.
var hover := -1
var bonks: Array = []
var puffs: Array = []


func _init(s: YardScene) -> void:
	scene = s
	set_key = String(scene.lv.get("set", "B"))
	paper = set_key == "P"
	var art: Dictionary = YardScene.doc().get("art", {})
	screens = (art.get("screens", {}) as Dictionary).get(set_key, [])
	for k: String in FLYERS:
		fly.append((art.get("flyers", {}) as Dictionary).get(k, {}))
	for i in 4:
		D.append({"i": i, "hx": 0.0, "hy": 0.0, "mode": "wait", "t0": 0.0, "x": 0.0, "y": -100.0, "doneAt": -1.0})


## Where each drone hovers: over your ship, spaced by the widest screen.
func homes() -> Array:
	var span := 0.0
	for sc: Dictionary in screens:
		span = maxf(span, float(sc.get("w", 80)))
	span += 8.0
	var x0 := 200.0 - span * 1.5
	var dh := float(scene.dial.get("drones", 50))
	var out := []
	for i in 4:
		out.append([floorf(x0 + span * float(i) + 0.5), dh + (16.0 if i % 2 == 1 else 0.0)])
	return out


static func bob(i: int, t: float) -> float:
	return floorf(4.0 * sin((t + float(PH[i])) * TAU / 2.8) + 0.5)


static func sway(i: int, t: float) -> float:
	return floorf(sin((t + float(PH[i]) * 1.7) * TAU / 4.3) + 0.5)


## Fly them in, after the TV: the page's `bring`.
func bring(t: float, reveal_end: float) -> void:
	var H := homes()
	var t1 := t + reveal_end + 0.4
	for i in 4:
		var d: Dictionary = D[i]
		d["hx"] = float(H[i][0])
		d["hy"] = float(H[i][1])
		d["mode"] = "arrive"
		d["t0"] = t1 + float(i) * 0.42 + (0.16 * (YardLight.hash1(float(i) * 7.3 + t) - 0.5) if i > 0 else 0.0)
		for k in ["flew", "flash", "last", "doze", "bump", "joke", "sneeze", "say", "r"]:
			d.erase(k)
		d["doneAt"] = -1.0
	FX.clear()


func offer(i: int) -> Dictionary:
	var o: Array = scene.offers
	return o[i] if i < o.size() else {"label": "", "cost": 0, "ok": false, "done": ""}


## One drone's move this tick (the page's `step`).
func step(d: Dictionary, t: float) -> void:
	var i := int(d["i"])
	var mode := String(d["mode"])
	if mode == "arrive":
		var u := clampf((t - float(d["t0"])) / 1.5, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 3.0)
		var side := -1.0 if i < 2 else 1.0
		if t >= float(d["t0"]) and not d.get("flew", false):
			d["flew"] = true
			scene.sound_arrive(float(d["hx"]))
		d["x"] = floorf(float(d["hx"]) + side * 50.0 * (1.0 - e) + 0.5)
		d["y"] = floorf(float(d["hy"]) - 190.0 * (1.0 - e) + bob(i, t) * e + 0.5)
		if u >= 1.0:
			d["mode"] = "hover"
		return
	if mode == "hover" or mode == "dip" or mode == "tell":
		d["x"] = float(d["hx"]) + sway(i, t)
		d["y"] = float(d["hy"]) + bob(i, t)
		if d.has("doze"):
			var o := doze_at(d, t)
			if o.has("done"):
				d.erase("doze")
			else:
				d["x"] += o["dx"]
				d["y"] += o["dy"]
		if d.has("bump"):
			var o2 := bump_at(d, t)
			if o2.has("done"):
				d.erase("bump")
			else:
				d["x"] += o2["dx"]
				d["y"] += o2["dy"]
		if d.has("sneeze"):
			var o3 := sneeze_at(d, t)
			if o3.has("done"):
				d.erase("sneeze")
				d.erase("say")
			else:
				d["x"] += o3["dx"]
				d["y"] += o3["dy"]
				if o3.get("say", "") != "":
					d["say"] = o3["say"]
				else:
					d.erase("say")
		if mode == "dip":
			var u2 := (t - float(d["td"])) / 0.6
			if u2 >= 1.0:
				d["mode"] = "hover"
			else:
				d["y"] += floorf(12.0 * sin(PI * u2) + 0.5)
		if String(d["mode"]) == "hover" and float(d["doneAt"]) >= 0.0 and t >= float(d["doneAt"]):
			d["mode"] = "tell"
			d["tt"] = t
		if String(d["mode"]) == "tell" and t >= float(d["tt"]) + (1.35 if paper else 1.1):
			d["mode"] = "leave"
			d["tl"] = t
			d["lx"] = d["x"]
			d["ly"] = d["y"]
			scene.sound_leave(float(d["hx"]))
		return
	if mode == "leave":
		var u3 := (t - float(d["tl"])) / 2.6
		var e3 := u3 * u3
		var dir := -1.0 if i < 2 else 1.0
		d["x"] = floorf(float(d["lx"]) + dir * 60.0 * e3 + 2.0 * sin(t * 9.0) + 0.5)
		d["y"] = floorf(float(d["ly"]) - 260.0 * e3 + 0.5)
		if u3 >= 1.0:
			d["mode"] = "gone"


## A service is about to go through: what every drone offers now, before the
## money moves, so one whose job it finishes can show what it offered, crossed
## out (the page's `before`). Taken first because the purchase itself refreshes
## the offers, on the game's own signals, before it comes back here.
func serving(i: int) -> void:
	_before = []
	for e: Dictionary in D:
		_before.append(offer(int(e["i"])).duplicate())
	_served_i = i


## A service went through (the page's `buy`, after the money): the drone dips,
## its screen says what it did, and the work lands on the hull.
func served(i: int, text: String, t: float) -> void:
	var d: Dictionary = D[i]
	if d.has("doze") and t - float(d["doze"]["t0"]) < 2.6:
		d["doze"]["t0"] = t - 2.6
	var mine: Dictionary = scene.placed[0]
	if String(d["mode"]) != "gone" and String(d["mode"]) != "wait":
		d["mode"] = "dip"
		d["td"] = t
		d["flash"] = {"text": text, "until": t + 1.0}
		var hx := float(d["hx"])
		if not mine.is_empty():
			hx = clampf(hx, float(mine["x0"]) + 10.0, float(mine["x0"]) + float(mine["w"]) - 14.0)
		FX.append({"i": i, "t0": t + 0.15, "hx": hx})
		scene.sound_work(i, float(d["hx"]))


var _before: Array = []
var _served_i := -1


## The new offers are in: whichever drone has nothing left to do tells you, and
## goes (the page's check after a sale). Only a sale sends them: a drone that
## came with nothing to sell -- HULL FULL, NO FAULTS -- hovers until one does.
func offers_changed(t: float) -> void:
	if _served_i < 0:
		return
	for e: Dictionary in D:
		var i := int(e["i"])
		var o := offer(i)
		var mode := String(e["mode"])
		if String(o.get("done", "")) != "" and float(e["doneAt"]) < 0.0 and (mode == "hover" or mode == "dip"):
			e["doneAt"] = t + (1.0 if i == _served_i else 0.5)
			var was: Dictionary = _before[i] if i < _before.size() else {}
			if was.is_empty() or String(was.get("done", "")) != "":
				e.erase("last")
			else:
				e["last"] = [String(was.get("label", "")), "%d CR" % int(was.get("cost", 0))]
	if not _before.is_empty() and _before.size() == D.size():
		# spent once the offers it was taken against have come in
		var any_new := false
		for e2: Dictionary in D:
			if String(offer(int(e2["i"])).get("done", "")) != String((_before[int(e2["i"])] as Dictionary).get("done", "")) 					or String(offer(int(e2["i"])).get("label", "")) != String((_before[int(e2["i"])] as Dictionary).get("label", "")):
				any_new = true
		if any_new:
			_served_i = -1
			_before = []


## Which drone is under the pointer: one that is hovering and still has work.
func hit(p: Vector2) -> int:
	for d: Dictionary in D:
		if String(d["mode"]) != "hover" or float(d["doneAt"]) >= 0.0 or not d.has("r"):
			continue
		var r: Dictionary = d["r"]
		var x0 := minf(float(r["fx0"]), float(r["sx"])) - 3.0
		var x1 := maxf(float(r["fx0"]) + float(r["fw"]), float(r["sx"]) + float(r["w"])) + 3.0
		if p.x >= x0 and p.x <= x1 and p.y >= float(r["fy0"]) - 3.0 and p.y <= float(r["sy"]) + float(r["h"]) + 3.0:
			return int(d["i"])
	return -1


## A drone clicked: it wakes if it was dozing; the scene decides if it sells.
func wake(i: int, t: float) -> void:
	var d: Dictionary = D[i]
	if d.has("doze") and t - float(d["doze"]["t0"]) < 2.6:
		d["doze"]["t0"] = t - 2.6


# ------------------------------------------------------------------ the rare events

## E1 A DRONE NODS OFF: sinks slowly, screen and all, with a few z's, jolts
## awake, and zips back up past its place. Clicking it wakes it at once.
func doze(t: float) -> bool:
	var live: Array = []
	for d: Dictionary in D:
		if String(d["mode"]) == "hover" and float(d["doneAt"]) < 0.0 and not d.has("doze") and not d.has("bump") and int(d["i"]) != hover:
			live.append(d)
	if live.is_empty():
		return false
	(live[randi() % live.size()] as Dictionary)["doze"] = {"t0": t}
	return true


func doze_at(d: Dictionary, t: float) -> Dictionary:
	var u := t - float(d["doze"]["t0"])
	if u < 2.6:
		return {"dx": 0.0, "dy": floorf(15.0 * YardLight.smooth(0.0, 2.6, u) + 0.5)}
	if u < 2.95:
		return {"dx": 2.0 if int(floorf(u * 30.0)) % 2 == 1 else -2.0, "dy": 15.0}
	if u < 3.6:
		var e := clampf((u - 2.95) / 0.25, 0.0, 1.0)
		return {"dx": 0.0, "dy": floorf(15.0 * (1.0 - e) - 4.0 * sin(PI * clampf((u - 3.1) / 0.5, 0.0, 1.0)) + 0.5)}
	return {"dx": 0.0, "dy": 0.0, "done": true}


## E5 TWO DRONES BUMP: neighbours drift together until their screens touch,
## clack, and wobble apart.
func bump(t: float) -> bool:
	var pairs: Array = []
	for i in 3:
		if _bumpable(D[i]) and _bumpable(D[i + 1]):
			pairs.append([D[i], D[i + 1]])
	if pairs.is_empty():
		return false
	var pr: Array = pairs[randi() % pairs.size()]
	var a: Dictionary = pr[0]
	var b: Dictionary = pr[1]
	var ra: Dictionary = a["r"]
	var rb: Dictionary = b["r"]
	var gap := maxf(0.0, float(rb["sx"]) - (float(ra["sx"]) + float(ra["w"])))
	var half := ceilf(gap / 2.0)
	a["bump"] = {"t0": t, "s": 1.0, "g": half}
	b["bump"] = {"t0": t, "s": -1.0, "g": half}
	bonks.append({"t0": t + 0.7, "a": a, "b": b})
	return true


func _bumpable(d: Dictionary) -> bool:
	return String(d["mode"]) == "hover" and float(d["doneAt"]) < 0.0 and not d.has("doze") and not d.has("bump") \
		and d.has("r") and int(d["i"]) != hover


func bump_at(d: Dictionary, t: float) -> Dictionary:
	var u := t - float(d["bump"]["t0"])
	var g := float(d["bump"]["g"])
	var s := float(d["bump"]["s"])
	if u < 0.7:
		var e := YardLight.smooth(0.0, 0.7, u)
		return {"dx": s * floorf(g * e * e + 0.5), "dy": 0.0}
	if u < 2.3:
		var v := u - 0.7
		return {"dx": s * floorf((g + 1.0) * exp(-5.0 * v) * cos(v * 16.0) + 0.5),
			"dy": -floorf(2.0 * exp(-6.0 * v) * absf(sin(v * 16.0)) + 0.5)}
	return {"dx": 0.0, "dy": 0.0, "done": true}


## E6 A JOKE ON A SCREEN, for a moment, in the screen's own ink.
func joke(t: float) -> bool:
	var live: Array = []
	for d: Dictionary in D:
		if String(d["mode"]) == "hover" and float(d["doneAt"]) < 0.0 and not d.has("joke"):
			live.append(d)
	if live.is_empty():
		return false
	(live[randi() % live.size()] as Dictionary)["joke"] = {"text": JOKES[randi() % JOKES.size()], "until": t + 1.7}
	return true


## E18 A DRONE SNEEZES: AH..., it rears up, then ACHOO! -- it jerks down in a
## puff of smoke, and shakes it off.
func sneeze(t: float) -> bool:
	var live: Array = []
	for d: Dictionary in D:
		if String(d["mode"]) == "hover" and float(d["doneAt"]) < 0.0 and not d.has("doze") and not d.has("bump") \
				and not d.has("sneeze") and not d.has("joke") and int(d["i"]) != hover:
			live.append(d)
	if live.is_empty():
		return false
	(live[randi() % live.size()] as Dictionary)["sneeze"] = {"t0": t}
	return true


func sneeze_at(d: Dictionary, t: float) -> Dictionary:
	var sn: Dictionary = d["sneeze"]
	var u := t - float(sn["t0"])
	if u < 0.9:
		return {"dx": 0.0, "dy": -floorf(3.0 * YardLight.smooth(0.0, 0.9, u) + 0.5), "say": "AH..." if u > 0.12 else ""}
	if u < 1.05:
		if not sn.get("puffed", false) and d.has("r"):
			sn["puffed"] = true
			var r: Dictionary = d["r"]
			var cx := float(r["fx0"]) + float(r["fw"]) / 2.0
			var cy := float(r["fy0"]) + 10.0
			for k in 12:
				puffs.append({"x": cx + (randf() - 0.5) * 10.0, "y": cy + randf() * 6.0, "vx": (randf() - 0.5) * 36.0,
					"vy": -8.0 + randf() * 22.0, "t0": t, "life": 0.45 + randf() * 0.4})
		return {"dx": 0.0, "dy": floorf(5.0 * (u - 0.9) / 0.15 + 0.5), "say": "ACHOO!"}
	if u < 2.0:
		return {"dx": 1.0 if int(floorf(u * 24.0)) % 2 == 1 else -1.0, "dy": floorf(5.0 * (1.0 - (u - 1.05) / 0.95) + 0.5),
			"say": "ACHOO!" if u < 1.7 else ""}
	return {"dx": 0.0, "dy": 0.0, "done": true}


# ------------------------------------------------------------------ drawing

## Every drone this tick: moved, and drawn in depth order with its screen, its
## work on the hull under them (the page's `drawWork`, then `drawDrone`).
func draw(P: YardPaint, t: float) -> void:
	for d: Dictionary in D:
		step(d, t)
	_draw_work(P, t)
	var order: Array = D.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for d: Dictionary in order:
		_draw_drone(P, d, t)


func _draw_drone(P: YardPaint, d: Dictionary, t: float) -> void:
	var mode := String(d["mode"])
	if mode == "wait" or mode == "gone":
		return
	var i := int(d["i"])
	var ink: Dictionary = INK_PAPER if paper else INK_SCREEN
	var o := offer(i)
	var crossed := paper and (mode == "tell" or mode == "leave") and d.has("last")
	var lines: Array
	if d.has("joke") and t >= float(d["joke"]["until"]):
		d.erase("joke")
	if d.has("flash") and t < float(d["flash"]["until"]):
		lines = [[String(d["flash"]["text"]), ink["flash"]]]
	elif d.has("sneeze") and d.has("say"):
		lines = [[String(d["say"]), ink["l"]]]
	elif d.has("joke"):
		lines = [[String(d["joke"]["text"]), ink["l"]]]
	elif crossed:
		lines = [[String(d["last"][0]), ink["l"]], [String(d["last"][1]), ink["p"]]]
	elif mode == "tell" or mode == "leave" or String(o.get("done", "")) != "":
		lines = [[String(o.get("done", "")), ink["done"]]]
	else:
		lines = [[String(o.get("label", "")), ink["l"]], ["%d CR" % int(o.get("cost", 0)), ink["p"] if bool(o.get("ok", false)) else ink["poor"]]]
	var M := scene.light.m_at(float(d["x"]), float(scene.shiprow()), true)
	d["r"] = carry(P, i, float(d["x"]), float(d["y"]), t, lines, hover == i, M)
	if crossed:
		var sc: Dictionary = screens[i]
		scribble(P, float(d["r"]["sx"]), float(d["r"]["sy"]), sc["glass"], t - float(d["tt"]), float(i) * 3.7 + 1.3, M)


## A drone and what it carries (the page's `carry`): its cables, the drone
## lit from above and darker underneath, the screen shaded along its top where
## the drone hangs over it, its glass unlit, and what the glass says.
func carry(P: YardPaint, i: int, cx: float, cy: float, t: float, lines: Array, hot: bool, M: Color) -> Dictionary:
	var F: Dictionary = fly[i]
	var sc: Dictionary = screens[i]
	var fw := float(F.get("fw", 60))
	var fh := float(F.get("fh", 35))
	var fi := int(floorf(t * 10.0 + float(i) * 3.0)) % 12
	var fx0 := floorf(cx - fw / 2.0 + 0.5)
	var fy0 := floorf(cy - fh / 2.0 + 0.5)
	var sw := float(sc.get("w", 80))
	var sh := float(sc.get("h", 40))
	var sx := floorf(cx - sw / 2.0 + 0.5)
	var sy := fy0 + float(F.get("low", 30)) + float(scene.dial.get("screens", 10)) - float(sc.get("top", 0))
	var ab := fy0 + float((F.get("bot", []) as Array)[fi]) if (F.get("bot", []) as Array).size() > fi else fy0 + fh
	var ink: Dictionary = INK_PAPER if paper else INK_SCREEN
	var Mq := YardScene.quant(M)
	P.use(YardPaint.PLAIN)
	if paper:
		P.line(cx, ab, sx + float(sc.get("hook", sw / 2.0)), sy + float(sc.get("top", 0)), YardScene.lit(Color("#a89066"), M))
	else:
		var hooks: Array = sc.get("hooks", [14, sw - 15])
		P.line(cx - 7.0, ab, sx + float(hooks[0]), sy + float(sc.get("top", 0)) + 1.0, YardScene.lit(Color("#15181b"), M))
		P.line(cx + 7.0, ab, sx + float(hooks[1]), sy + float(sc.get("top", 0)) + 1.0, YardScene.lit(Color("#15181b"), M))
	# the drone, lit from above: toward its bottom it falls into its own shade
	var ft := scene.tex_abs(String(F.get("picture", "")))
	scene.draw_shaded(P, ft, Rect2(fi * fw, 0, fw, fh), Vector2(fx0, fy0), Mq, 0.45, 0.5, 3, [])
	# the screen, shaded toward its bottom and along its top under the drone,
	# its glass as it is
	var st := scene.tex(String(sc.get("picture", "")))
	var cast := [sw / 2.0, floorf(fw * 0.5 + 0.5), 5.0, 0.42]
	scene.draw_shaded(P, st, Rect2(0, 0, sw, sh), Vector2(sx, sy), Mq, 0.5, 0.38, 2, cast)
	var g: Array = sc.get("glass", [0, 0, sw - 1, sh - 1])
	if not paper:
		P.tex(st, Vector2(sx + float(g[0]), sy + float(g[1])), Rect2(float(g[0]), float(g[1]), float(g[2]) - float(g[0]) + 1.0, float(g[3]) - float(g[1]) + 1.0))
	var gh := float(g[3]) - float(g[1]) + 1.0
	var mx := floorf(sx + (float(g[0]) + float(g[2]) + 1.0) / 2.0 + 0.5)
	if hot:
		var gx0 := sx + float(g[0])
		var gy0 := sy + float(g[1])
		var gw := float(g[2]) - float(g[0]) + 1.0
		P.rect(Rect2(gx0, gy0, gw, 1), AMBER)
		P.rect(Rect2(gx0, gy0 + gh - 1.0, gw, 1), AMBER)
		P.rect(Rect2(gx0, gy0, 1, gh), AMBER)
		P.rect(Rect2(gx0 + gw - 1.0, gy0, 1, gh), AMBER)
	if lines.size() == 1:
		_put(P, String(lines[0][0]), mx, sy + float(g[1]) + floorf((gh - 5.0) / 2.0) + 5.0, lines[0][1], ink, M)
	else:
		var top := sy + float(g[1]) + floorf((gh - 14.0) / 2.0)
		_put(P, String(lines[0][0]), mx, top + 5.0, lines[0][1], ink, M)
		_put(P, String(lines[1][0]), mx, top + 14.0, lines[1][1], ink, M)
	return {"fx0": fx0, "fy0": fy0, "fw": fw, "sx": sx, "sy": sy, "w": sw, "h": sh}


func _put(P: YardPaint, s: String, mx: float, y: float, col: Color, ink: Dictionary, M: Color) -> void:
	var font := scene.font()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x := floorf(mx - w / 2.0 + 0.5)
	if bool(ink["shadow"]):
		P.text(font, Vector2(x + 1.0, y + 1.0), s, 8, Color(4.0 / 255.0, 6.0 / 255.0, 10.0 / 255.0, 0.8))
	P.text(font, Vector2(x, y), s, 8, YardScene.lit(col, M) if paper else col)


## A RED X, SCRIBBLED: two pen strokes across a used-up paper tag, the second
## after the first, each a little wobbly and overshooting its end. The wobble
## is fixed per tag, so the X does not shimmer.
func scribble(P: YardPaint, sx: float, sy: float, glass: Array, e: float, seed: float, M: Color) -> void:
	var x0 := sx + float(glass[0]) + 3.0
	var y0 := sy + float(glass[1]) + 2.0
	var x1 := sx + float(glass[2]) - 3.0
	var y1 := sy + float(glass[3]) - 2.0
	var strokes := [[x0, y0, x1 + 3.0, y1 + 1.0], [x1, y0 - 1.0, x0 - 2.0, y1 + 2.0]]
	var pens: Array = []
	for c: Color in PEN:
		pens.append(YardScene.lit(c, M))
	for k in 2:
		var s: Array = strokes[k]
		var p := clampf((e - float(k) * 0.25) / 0.2, 0.0, 1.0)
		if p <= 0.0:
			continue
		var ax := float(s[0])
		var ay := float(s[1])
		var bx := float(s[2])
		var by := float(s[3])
		var ln := sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
		var nx := -(by - ay) / ln
		var ny := (bx - ax) / ln
		var n := ceilf(ln)
		var j := 0
		while float(j) <= n * p:
			var u := float(j) / n
			var wob := 1.1 * sin(u * 6.5 + seed + float(k) * 2.1) + 0.8 * sin(u * 17.0 + seed * 3.0) * u
			var x := floorf(ax + (bx - ax) * u + nx * wob + 0.5)
			var y := floorf(ay + (by - ay) * u + ny * wob + 0.5)
			P.rect(Rect2(x, y, 1, 1), pens[0])
			P.rect(Rect2(x + 1.0, y, 1, 1), pens[1])
			P.rect(Rect2(x, y + 1.0, 1, 1), pens[2])
			P.rect(Rect2(x + 1.0, y + 1.0, 1, 1), pens[3])
			j += 1


## The work, seen on the hull: a torch, a welder's white, fuel coming down, a
## scan down the hull (the page's `drawWork`).
func _draw_work(P: YardPaint, t: float) -> void:
	var m: Dictionary = scene.placed[0]
	P.use(YardPaint.PLAIN)
	var keep: Array = []
	for f: Dictionary in FX:
		if t - float(f["t0"]) < 1.2:
			keep.append(f)
		var u := (t - float(f["t0"])) / 0.7
		var d: Dictionary = D[int(f["i"])]
		if u < 0.0 or u > 1.0 or not d.has("r") or m.is_empty():
			continue
		var r: Dictionary = d["r"]
		var bx := float(d["x"])
		var by := float(r["sy"]) + float(r["h"])
		var hx := float(f["hx"])
		var hy := scene.top_at(hx)
		var i := int(f["i"])
		if i == 3:
			var top := float(m["top"])
			var y := floorf(top + u * (float(m["h"]) - 1.0) + 0.5)
			var X0 := int(m["x0"])
			for x in range(X0, X0 + int(m["w"])):
				if x < 0 or x >= YardScene.W:
					continue
				if scene.hull_top[x] >= 0 and y >= float(scene.hull_top[x]) and y <= float(scene.hull_bot[x]):
					P.rect(Rect2(x, y, 1, 1), Color("#7fe6f2"))
			if u < 0.6:
				var k := by
				while k < hy:
					P.px(bx + floorf((hx - bx) * (k - by) / maxf(1.0, hy - by) + 0.5), k, 1, 1, Color("#5fd0e0"))
					k += 3.0
		elif i == 2:
			for k in 4:
				var v := clampf((u - float(k) * 0.12) / 0.55, 0.0, 1.0)
				if v <= 0.0 or v >= 1.0:
					continue
				P.px(bx + (hx - bx) * v, by + (hy - by) * v, 2, 2, Color("#8fe29a") if v > 0.8 else Color("#5fbf6a"))
		else:
			var hotc := [Color("#ffe28a"), Color("#ffcf6a"), Color("#f08a20")] if i == 0 else [Color("#ffffff"), Color("#dfe7ee"), Color("#9fb0c0")]
			if u < 0.45:
				P.line(bx, by, hx, hy, hotc[1])
			var fr := floorf(t * 20.0)
			for k in 7:
				var a := YardLight.hash1(fr * 3.1 + float(k) * 7.7) * PI
				var rr := 1.0 + YardLight.hash1(fr * 1.3 + float(k) * 2.9) * 6.0 * u
				P.px(hx + cos(a) * rr * (1.0 if YardLight.hash1(float(k) * 5.1) > 0.5 else -1.0), hy - sin(a) * rr, 1, 1, hotc[k % 3])
	FX = keep


## The z's over a dozing drone and the clack where two screens meet (the page's
## `drawGlyphs`, the drones' part), and the sneeze's puffs (`drawPuffs`).
func draw_marks(P: YardPaint, t: float, dt: float) -> void:
	P.use(YardPaint.PLAIN)
	for d: Dictionary in D:
		if not d.has("doze") or not d.has("r"):
			continue
		var u := t - float(d["doze"]["t0"])
		if u < 0.5 or u > 2.6:
			continue
		var r: Dictionary = d["r"]
		for k in 3:
			var v := fposmod((u - 0.5) * 0.9 + float(k) * 0.33, 1.0)
			var zx := floorf(float(r["fx0"]) + float(r["fw"]) - 4.0 + 5.0 * v + float(k) + 0.5)
			var zy := floorf(float(r["fy0"]) + 4.0 - 16.0 * v + 0.5)
			var col := Color("#c9d7e6") if v < 0.75 else Color("#7286a0")
			P.rect(Rect2(zx, zy, 3, 1), col)
			P.rect(Rect2(zx + 1.0, zy + 1.0, 1, 1), col)
			P.rect(Rect2(zx, zy + 2.0, 3, 1), col)
	var keep: Array = []
	for b: Dictionary in bonks:
		var u2 := t - float(b["t0"])
		if u2 > 0.16:
			continue
		keep.append(b)
		if u2 < 0.0:
			continue
		var a: Dictionary = b["a"]
		var c: Dictionary = b["b"]
		if not a.has("r") or not c.has("r"):
			continue
		var ra: Dictionary = a["r"]
		var rc: Dictionary = c["r"]
		var x := floorf((float(ra["sx"]) + float(ra["w"]) + float(rc["sx"])) / 2.0 + 0.5)
		var y := floorf((maxf(float(ra["sy"]), float(rc["sy"])) + minf(float(ra["sy"]) + float(ra["h"]), float(rc["sy"]) + float(rc["h"]))) / 2.0 + 0.5)
		P.rect(Rect2(x, y - 2.0, 1, 5), Color("#fff6d8"))
		P.rect(Rect2(x - 2.0, y, 5, 1), Color("#fff6d8"))
		P.rect(Rect2(x - 1.0, y - 1.0, 3, 3), Color("#ffffff"))
	bonks = keep
	var live: Array = []
	for p: Dictionary in puffs:
		var a2 := (t - float(p["t0"])) / float(p["life"])
		if a2 > 1.0:
			continue
		live.append(p)
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["vx"] = float(p["vx"]) * 0.92
		var M := scene.light.m_at(float(p["x"]), float(scene.shiprow()), true)
		var sz := 2.0 if a2 < 0.4 else 1.0
		P.px(float(p["x"]), float(p["y"]), sz, sz, YardScene.lit(Color("#c3c9d0") if a2 < 0.5 else Color("#8a9199"), M))
	puffs = live
