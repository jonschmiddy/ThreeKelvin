class_name MiniDump
extends RefCounted

## A dealt mini game as its prototype names it, for `tools/dev/minigame/diff.py` to deal the same
## puzzle on the approved page: Godot's types become the JS shapes the page's `mount` reads.
## Why: docs/why/MiniGame.md#tests


static func js(v: Variant) -> Variant:
	if v is Vector2 or v is Vector2i:
		return [v.x, v.y]
	if v is Rect2:
		return {x0 = v.position.x, y0 = v.position.y, x1 = v.end.x, y1 = v.end.y}
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is PackedFloat64Array or v is PackedFloat32Array or v is PackedInt32Array:
		return Array(v)
	if v is Array:
		return (v as Array).map(func(e: Variant) -> Variant: return js(e))
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[str(k)] = js(v[k])
		return out
	return v


## The deal as the page's `mount` would have made it.
static func puzzle(g: MiniGame) -> Dictionary:
	var p: Dictionary
	match g.id():
		&"coolant":
			p = js((g as GameCoolant).P)
			p.pathLen = p.path_len
			for t: Dictionary in p.tiles:
				if int(t.goal) < 0:
					t.goal = null
		&"centrifuge":
			p = js((g as GameCentrifuge).P)
			p.N = p.n
		&"icecore":
			p = js((g as GameIceCore).p)
		&"tray":
			p = js((g as GameTray).P)
		&"anomaly":
			p = js((g as GameAnomaly).pz)
		&"beams":
			p = js((g as GameBeams).P)
		&"spectrum":
			p = js((g as GameSpectrum).P)
		&"pulsar":
			p = _pulsar(g as GamePulsar)
		&"fourkelvin":
			p = js((g as GameFourKelvin).F)
			for o: Dictionary in p.rocks:
				o.craters = (o.craters as Array).map(func(c: Array) -> Dictionary: return {x = c[0], y = c[1], r = c[2]})
		&"torch":
			p = js((g as GameTorch).P)
		&"leak":
			p = js((g as GameLeak).P)
			p.parPuffs = p.par_puffs
			if (p.wind as Dictionary).is_empty():
				p.wind = null
		&"sling":
			p = js((g as GameSling).P)
		&"tuning":
			p = js((g as GameTuning).g0)
		&"seismic":
			p = js((g as GameSeismic).P)
		&"corescan":
			p = js((g as GameCoreScan).P)
		&"culture":
			p = _culture(g as GameCulture)
		&"dock":
			p = js((g as GameDock).P)
	return p


static func _pulsar(g: GamePulsar) -> Dictionary:
	var p: Dictionary = js(g.g0)
	p.decoy = null if float(g.g0.decoy) < 0.0 else g.g0.decoy
	p.peaks = (g.g0.peaks as Array).map(func(q: Vector2) -> Dictionary: return {u = q.x, v = q.y})
	var pairs: Array = []
	for u: int in g.g0.S:
		pairs.append([u, g.g0.S[u]])
	p.S = pairs
	return p


## The dish's board as the page builds it: cells {q, r} and each cell's neighbours.
static func _culture(g: GameCulture) -> Dictionary[String, Variant]:
	var p: Dictionary[String, Variant] = {}
	p.assign(js(g.p))
	var b: Dictionary = g.p.B
	p.B = {R = b.R, cells = (b.cells as Array).map(func(c: Vector2i) -> Dictionary: return {q = c.x, r = c.y}), nb = js(b.nb)}
	return p
