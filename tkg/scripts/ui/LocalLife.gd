class_name LocalLife
extends RefCounted

## LOCAL'S LIFE (Oct 11, the magnificent pass; Jon kept these four of five):
##   * THE AIR of the world you orbit, a thin bright shell on its sunward limb
##     (`local_air.gdshader`);
##   * ITS CITY LIGHTS, when the system is settled and the world has dry
##     ground: its towns on the night side, clusters of points of light
##     (`local_night.gdshader`);
##   * ITS MOONS GO ROUND it, in front of its face and behind it, their eclipses
##     on its face -- but only while nothing is staged in its sky (below);
##   * FAR TRAFFIC in a settled system, tiny ships crossing along its plane.
## (A fifth, the star's light on your hull, was cut: Jon, Oct 11.)
##
## IN EVERY STYLE, each in its own hand (as the dust is, `LocalDust`):
## SIMPLIFIED dithered steps; PAINTED flat hand-picked tones, no soft glow,
## motion in held poses; RADIANT light through an exposure, softer and wider;
## LEGACY its old blue-greys, plainer.
##
## THE MOONS KEEP OUT OF WHAT IS STAGED (Jon: a moon must never pass over an
## event's subject, a station or your ship during the dock). Two rules:
##   * a moon goes round only while LOCAL is QUIET -- no event's subject up, no
##     fight and no wrecks in the slots, no zoom (the cutaway, the ladder: the
##     dock is a ladder move), the camera at rest -- and otherwise holds where
##     it is (it eases to a stop in a fraction of a second, a block at most);
##   * each moon's orbit is CHOSEN CLEAR of what always stands there -- your
##     ship, and at a station its side and the corridor your ship docks along --
##     from a few orbits by size, tilt and roll; a moon with no clear orbit
##     stays where it always hung. And it never steps into anything staged even
##     so (each step is checked against every subject piece, slot and station
##     rect, and held if it would).
## `-- sheet=MoonTest` checks both, headless, in the merge gate.
##
## The traffic keeps far and sparse, above the fight in the system's band, and
## is never up with an encounter: it fades out while LOCAL is not quiet, so it
## can never be read as part of one.

const AIR := preload("res://shaders/local_air.gdshader")
const NIGHT := preload("res://shaders/local_night.gdshader")

## A harness's veto (`LocalLifeShot`): the ideas named here drawn as if they
## were not there -- the moons hanging where they always hung -- to film the
## same frame with one and without it.
static var hide := {}
## its own CPU time, microseconds, since a harness zeroed it
static var cpu_us := 0

var sky: LocalSky
## 0 SIMPLIFIED, 1 PAINTED, 2 RADIANT, 3 LEGACY (`LocalDust`'s numbers)
var style := 0
## 1 while nothing is staged in LOCAL's sky, eased to 0 while something is
## (the traffic's)
var quiet_k := 1.0
## the moons' clock speed (0 the moment anything is staged, eased back up)
var _moon_k := 1.0

var _air: ColorRect = null
var _air_mat: ShaderMaterial = null
var _night: MultiMeshInstance2D = null
var _night_mat: ShaderMaterial = null
var _night_for: Object = null
var _traffic: _Traffic = null
## per moon: {i (its entry in the sky's near things), a, incl, roll, period,
## phase, held, r, rest (its old still place, rel. the world's middle)}
var moons: Array = []
var _moons_chosen := false
## the sky's plan of the world you orbit, made once (`_world`)
var _plan := {}
var _plan_made := false


func _init(s: LocalSky) -> void:
	sky = s
	style = {&"painted": 1, &"radiant": 2, &"legacy": 3}.get(s.style, 0)


func step(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var q := quiet()
	quiet_k = move_toward(quiet_k, 0.0 if staged() else 1.0, delta / 1.0)
	# (the moons stop at once -- a block every half second, so no jolt shows --
	# and set off again gently)
	_moon_k = move_toward(_moon_k, 1.0, delta / 1.0) if q else 0.0
	_step_moons(delta)
	sync()
	cpu_us += Time.get_ticks_usec() - t0


## Everything drawn as it is now, no clock moved (a harness films a frame
## again with `hide` changed).
func sync() -> void:
	_draw_moons()
	_step_air()
	_step_night()
	_step_traffic()


# ------------------------------------------------------------------ quiet

## The view this sky is the backdrop of (`EncounterView`), or null.
func view() -> EncounterView:
	return sky.get_parent() as EncounterView


## LOCAL at rest with nothing staged in its sky: the moons go round. Not while
## anything is `staged`, under a zoom (the cutaway) or while the camera moves
## (the ship flying in or out).
func quiet() -> bool:
	return not staged() and is_equal_approx(sky.zoom, 1.0) and absf(sky.cam.x) <= 0.5


## Something staged in LOCAL's sky: an event's subject, a fight or its wrecks,
## a move between distances (the dock is one), the station's dock under way.
func staged() -> bool:
	if ZoomLadder.busy():
		return true
	var v := view()
	if v == null:
		return false
	if v._slots != null and v._slots.visible:
		return true
	var sub := LocalSubject.of(v)
	if sub != null and sub.visible and not sub.drawn_rects().is_empty():
		return true
	for c in v.get_children():
		if c is StationFace and (c as StationFace).dock_k > 0.0:
			return true
	return false


## A global rect in this sky's 960x540 frame (where its near things are laid).
func to_frame(g: Rect2) -> Rect2:
	var gp := sky.get_global_rect().position
	var off := (gp / 2.0).round() * 2.0 - gp
	return Rect2(g.position + off, g.size)


## WHAT A MOON MUST KEEP OUT OF, this sky's px. `always`: only what stands there
## whatever is staged (your ship; at a station its side and the corridor your
## ship docks along), which the orbits are chosen clear of; else everything on
## the view now (every subject piece, every slot's ship).
func keep_out(always: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var v := view()
	if v == null:
		return out
	var ship := Rect2()
	var art := v.ship_view()
	if art != null:
		var sr := art.ship_rect()
		ship = Rect2(sr.position + art.global_position, sr.size)
		if ship.size.x > 1.0:
			out.append(to_frame(ship.grow(10.0)))
	for c in v.get_children():
		if c is StationFace and not (c as StationFace).front:
			var f := c as StationFace
			var fr := f.get_global_rect()
			var x0 := fr.end.x - StationFace.SHOWN - 12.0
			out.append(to_frame(Rect2(x0, fr.position.y, fr.end.x - x0, fr.size.y)))
			# the corridor your ship docks along, its height and some
			if ship.size.x > 1.0:
				out.append(to_frame(Rect2(ship.position.x, ship.position.y - 16.0, x0 - ship.position.x + 4.0, ship.size.y + 32.0)))
	if always:
		return out
	var sub := LocalSubject.of(v)
	if sub != null and sub.visible:
		for r in sub.drawn_rects():
			out.append(to_frame(r.grow(6.0)))
	if v._slots != null and v._slots.visible:
		for s in v._slots.get_children():
			if s is Control and (s as Control).visible:
				out.append(to_frame((s as Control).get_global_rect()))
	return out


# ------------------------------------------------------------------ the moons

## The world you orbit's middle and radius at rest (this sky's px), and its
## moons' still places: from the sky's plan, so it holds headless too.
func _world() -> Dictionary:
	if _plan_made:
		return _plan
	_plan_made = true
	_plan = sky.near_plan()
	if _plan.is_empty() or (_plan.moons as Array).is_empty():
		_plan = {}
		return _plan
	var hs := Worlds.half_size(StringName(_plan.world), float(_plan.R))
	_plan.c = Vector2(_plan.at) + Vector2.ONE * float(hs % 2)
	return _plan


## A moon's place on its orbit at `phase` (radians): its offset from the
## world's middle (this sky's px, y down) and its depth (+ toward you).
static func orbit_at(m: Dictionary, phase: float) -> Array:
	var ox := -cos(phase) * float(m.a)
	var oz := sin(phase) * float(m.a)
	var p := Vector2(ox, oz * sin(float(m.incl))).rotated(float(m.roll))
	return [p, oz * cos(float(m.incl))]


## Hidden behind the world (far side, inside its disc).
static func behind(p: Vector2, z: float, R: float, mr: float) -> bool:
	return z < 0.0 and p.length() < R - mr


## A moon at `p` (offset) and `z` clear of every rect (or hidden behind the world).
static func clear_at(c: Vector2, p: Vector2, z: float, R: float, mr: float, rects: Array[Rect2]) -> bool:
	if behind(p, z, R, mr):
		return true
	var box := Rect2(c + p - Vector2.ONE * (mr + 2.0), Vector2.ONE * (2.0 * mr + 4.0))
	for r in rects:
		if box.intersects(r):
			return false
	return true


## Each moon's orbit, chosen clear of what always stands there.
func _choose() -> void:
	moons.clear()
	_moons_chosen = true
	var w := _world()
	if w.is_empty():
		return
	var c: Vector2 = w.c
	var R := float(w.R)
	# (a little wider than the step check: a moon is drawn on its block, a
	# pixel either way of its true place)
	var rects: Array[Rect2] = []
	for r in keep_out(true):
		rects.append(r.grow(3.0))
	var k := 0
	for mm: Dictionary in w.moons:
		var hk := LocalSky.SkyBakeS.hash2(int(mm.seed), 71)
		var base := {"r": float(mm.r), "rest": Vector2(mm.at) - Vector2(w.at), "held": true,
			"phase": (0.2 + 0.31 * float(k) + 0.17 * hk) * TAU}
		# the candidates: its own orbit first, then nearer, flatter, rolled the
		# other way
		for cand: Array in [[1.45 + 0.42 * float(k) + 0.12 * hk, 0.3 + 0.12 * hk, (hk - 0.5) * 0.22],
				[1.3 + 0.3 * float(k), 0.22, (hk - 0.5) * 0.22], [1.45 + 0.42 * float(k), 0.42, -(hk - 0.5) * 0.22],
				[1.25 + 0.2 * float(k), 0.16, 0.0], [1.6 + 0.4 * float(k), 0.5, 0.12], [1.2 + 0.15 * float(k), 0.34, -0.12]]:
			var o := {"a": R * float(cand[0]), "incl": float(cand[1]), "roll": float(cand[2])}
			var ok := true
			# (a step of a pixel or less round it: a big world close by has orbits
			# long enough that 720 steps left gaps a moon crossed a rect through)
			var steps := maxi(720, ceili(TAU * float(o.a)))
			for s in steps:
				var oa := orbit_at(o, TAU * float(s) / float(steps))
				if not clear_at(c, oa[0], oa[1], R, float(mm.r), rects):
					ok = false
					break
			if ok:
				base.merge(o, true)
				base.held = false
				# (inner faster, outer slower: a Kepler-ish period, compressed)
				base.period = 180.0 * pow(float(o.a) / (R * 1.45), 1.5)
				break
		moons.append(base)
		k += 1


func _step_moons(dt: float) -> void:
	if _world().is_empty():
		return
	if not _moons_chosen:
		# (once the view is laid out: the first frame it has a size)
		var v := view()
		if v != null and v.size.x < 1.0:
			return
		_choose()
	if moons.is_empty() or _moon_k <= 0.0 or dt <= 0.0:
		return
	var w := _world()
	var rects := keep_out(false)
	for m: Dictionary in moons:
		if bool(m.held):
			continue
		var nph := float(m.phase) + dt * _moon_k * TAU / float(m.period)
		var oa := orbit_at(m, nph)
		# (never a step into anything staged: held instead)
		if clear_at(w.c, oa[0], oa[1], float(w.R), float(m.r), rects):
			m.phase = nph


## Where each moon is now: [offset from the world's middle (this sky's px, at
## rest), depth, held] -- for the drawing and the test.
func moon_places() -> Array:
	var out: Array = []
	for m: Dictionary in moons:
		if bool(m.held) or hide.has(&"moons"):
			out.append([Vector2(m.rest), 1.0, true])
		else:
			var oa := orbit_at(m, float(m.phase))
			out.append([oa[0], oa[1], false])
	return out


func _draw_moons() -> void:
	if moons.is_empty() or not (sky._near_world is PlanetView) or not sky._hand.is_empty() or sky._near.size() < 2:
		return
	var pv := sky._near_world as PlanetView
	var parent := pv.get_parent()
	var zl := sky._zl(LocalSky.Z_NEAR)
	var R := float(sky._near[0][3]) * zl
	var wc := pv.position
	var wm := pv.get("_mat") as ShaderMaterial
	var Lw := wm.get_shader_parameter("light") as Vector3
	var places := moon_places()
	var msh := PackedVector4Array()
	var k := 0
	for i in range(1, sky._near.size()):
		var e: Array = sky._near[i]
		if StringName(e[4]) != &"moon" or k >= places.size():
			continue
		var pl: Array = places[k]
		var m: Dictionary = moons[k]
		k += 1
		var mv := e[0] as PlanetView
		var hs := Worlds.half_size(&"moon", float(e[3]))
		var mr := float(e[3]) * zl
		var p: Vector2 = (pl[0] as Vector2) * zl
		var z := float(pl[1])
		var front := z >= 0.0
		var kl := 1.0
		var pos: Vector2
		if bool(pl[2]):
			# where it always hung (`_step_near`'s own place for it)
			pos = sky._zp(sky._block_round(Vector2(e[1]) - sky.cam * float(e[2])), LocalSky.Z_NEAR) + Vector2.ONE * float(hs % 2)
		else:
			pos = sky._block_round(wc + p) + Vector2.ONE * float(hs % 2)
			# in the world's shadow: behind it from the star, inside its radius
			var M3 := Vector3(p.x, p.y, z)
			var along := M3.dot(Lw)
			if along < 0.0:
				kl = lerpf(0.1, 1.0, smoothstep(R * 0.9, R * 1.08, (M3 - Lw * along).length()))
			# ITS SHADOW MOVES WHEN IT DOES, a block at a time, all of it: its place
			# and its depth held from the step the moon was drawn at until its next.
			# (From its true place the shadow crept a fraction of a pixel a frame;
			# then with its place stepped but its depth still gliding, each step
			# threw the shadow a block on and the glide drew it back a hair the next
			# frame -- a block of RADIANT's fine shading at the shadow's edge went
			# A, B, A at every step of every moon.)
			if pos != m.get("sh_at", Vector2.INF):
				var pd := pos - Vector2.ONE * float(hs % 2) - wc
				m.sh_at = pos
				m.sh = Vector4(pd.x, pd.y, z, mr)
			if front and msh.size() < 4:
				msh.append(m.sh)
		mv.position = pos
		# (lit from the star as the world is: one light for the moon wherever it
		# is on its orbit -- from its own place the light turned a little with
		# every block it moved, and RADIANT's fine shading flickered with it)
		var d := (sky.origin() - (pos if bool(pl[2]) else wc)) / zl
		mv.step(sky.t, Vector3(d.x, d.y, 140.0).normalized(), kl)
		if front and mv.get_index() < pv.get_index():
			parent.move_child(mv, -1)
		elif not front and mv.get_index() > pv.get_index():
			parent.move_child(mv, 0)
	var n := msh.size()
	msh.resize(4)
	wm.set_shader_parameter("moon_sh", msh)
	wm.set_shader_parameter("n_moon_sh", n)


# ------------------------------------------------------------------ the air

func _step_air() -> void:
	if not (sky._near_world is PlanetView) or sky._near_rect == null or sky._scene == null:
		return
	var pv := sky._near_world as PlanetView
	var wn := StringName(pv.spec.get("world", &""))
	var atm: Variant = (Worlds.WORLD.get(wn, {}) as Dictionary).get("atm", null)
	if atm == null:
		return
	if _air == null or not is_instance_valid(_air):
		_air = sky._rect()
		_air_mat = ShaderMaterial.new()
		_air_mat.shader = AIR
		_air_mat.set_shader_parameter("style", style)
		_air.material = _air_mat
		sky._scene.add_child(_air)
	if _air.get_index() < sky._near_rect.get_index():
		sky._scene.move_child(_air, -1)
	_air.visible = not hide.has(&"air") and sky._hand.is_empty()
	var m := pv.get("_mat") as ShaderMaterial
	var r := float(m.get_shader_parameter("r"))
	var c := Color(String(atm))
	var W: Dictionary = Worlds.WORLD[wn]
	var thick := bool(W.get("thick", false))
	var giant := bool(W.get("giant", false))
	_air_mat.set_shader_parameter("ctr", pv.position)
	_air_mat.set_shader_parameter("r", r)
	_air_mat.set_shader_parameter("L", m.get_shader_parameter("light"))
	_air_mat.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	# (RADIANT: its painter already wraps the world in a lit shell, so gentler)
	var k := (0.7 if giant else 0.85) * (0.6 if style == 2 else 1.0)
	_air_mat.set_shader_parameter("k", k)
	_air_mat.set_shader_parameter("w", (4.0 + 0.03 * r) * (1.6 if thick else 1.0))
	_air_mat.set_shader_parameter("ring", _rings(pv))


## A world's rings in its radii, or (0, 0).
static func _rings(pv: PlanetView) -> Vector2:
	if not bool(pv.spec.get("ring", false)):
		return Vector2.ZERO
	var m := pv.get("_mat") as ShaderMaterial
	var ring := Vector2(float(m.get_shader_parameter("ring_in")), float(m.get_shader_parameter("ring_out")))
	return ring if ring.y > 0.0 else Vector2(1.5, 2.2)


# ------------------------------------------------------------------ city lights

## Worlds with dry ground for towns (an ocean or a living world would put them
## on the sea), and how many towns a settled system has.
const NIGHT_GROUND := [&"rock", &"desert", &"iron", &"ice", &"toxic", &"eyeball", &"cracked", &"crystal",
	&"haze", &"volcanic", &"swamp", &"moon"]
const NIGHT_TOWNS := {MapGen.Development.SETTLEMENT: 22, MapGen.Development.CITY: 40, MapGen.Development.CAPITAL: 64}


func _step_night() -> void:
	var n := sky.node
	if not (sky._near_world is PlanetView) or sky._near_rect == null or sky._scene == null or n == null:
		return
	var pv := sky._near_world as PlanetView
	var wn := StringName(pv.spec.get("world", &""))
	if not wn in NIGHT_GROUND or not NIGHT_TOWNS.has(n.development):
		return
	if _night == null or not is_instance_valid(_night) or _night_for != pv:
		if _night != null and is_instance_valid(_night):
			_night.queue_free()
		_night_for = pv
		_night = _build_night(pv, int(NIGHT_TOWNS[n.development]), n.development == MapGen.Development.CAPITAL)
		sky._scene.add_child(_night)
	# (over the near picture, not in it: the play tone presses the near things'
	# light down to a mid-tone, and a town's lights pressed so came out as tan
	# smudges -- a light is exempt, as the lab's glowing pixels are)
	if _night.get_index() < sky._near_rect.get_index():
		sky._scene.move_child(_night, -1)
	_night.visible = not hide.has(&"night") and sky._hand.is_empty()
	var m := pv.get("_mat") as ShaderMaterial
	_night_mat.set_shader_parameter("ctr", pv.position)
	_night_mat.set_shader_parameter("r", float(m.get_shader_parameter("r")))
	_night_mat.set_shader_parameter("time", float(m.get_shader_parameter("time")))
	_night_mat.set_shader_parameter("L", m.get_shader_parameter("light"))
	_night_mat.set_shader_parameter("ring", _rings(pv))


## The lights, built once a world: towns as clusters (a few big, many small),
## lone lights between them; each an instance with its place on the sphere.
func _build_night(pv: PlanetView, towns: int, capital: bool) -> MultiMeshInstance2D:
	var pts: Array = []
	var R := Worlds.XRng.new(float(pv.spec.get("seed", 1.0)) * 131.0 + 9.0)
	for i in towns:
		var c := Worlds.sphere_rand(R)
		# (towns keep off the poles' ice)
		if absf(c.y) > 0.8:
			c.y *= 0.7
			c = c.normalized()
		var big := pow(R.next(), 2.2) * (1.25 if capital else 1.0)
		var n := 4 + int(big * 30.0)
		var spread := 0.03 + 0.08 * big
		var e1 := c.cross(Vector3.UP if absf(c.y) < 0.9 else Vector3.RIGHT).normalized()
		var e2 := c.cross(e1)
		for k in n:
			var a := R.next() * TAU
			var rr := spread * sqrt(R.next())
			var p := (c + e1 * cos(a) * rr + e2 * sin(a) * rr).normalized()
			# a big town's middle brighter
			var s := 0.45 + 0.55 * R.next() + (0.8 * big if rr < spread * 0.35 else 0.0)
			pts.append([p, s])
	# and between the towns, lone lights: roads, farms, a mine
	for i in towns * 2:
		var p := Worlds.sphere_rand(R)
		if absf(p.y) < 0.85:
			pts.append([p, 0.3 + 0.3 * R.next()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = LocalDust._quad()
	mm.instance_count = pts.size()
	for i in pts.size():
		var p: Vector3 = pts[i][0]
		mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
		mm.set_instance_custom_data(i, Color(p.x, p.y, p.z, float(pts[i][1])))
	var mi := MultiMeshInstance2D.new()
	mi.multimesh = mm
	_night_mat = ShaderMaterial.new()
	_night_mat.shader = NIGHT
	_night_mat.set_shader_parameter("style", style)
	_night_mat.set_shader_parameter("term", 0.22 if style == 2 else 0.0)
	var sp := pv.spec
	_night_mat.set_shader_parameter("w_seed", float(sp.get("seed", 0.0)))
	_night_mat.set_shader_parameter("spin", float(sp.get("spin", 0.0)))
	_night_mat.set_shader_parameter("tilt", float(sp.get("tilt", 0.0)))
	mi.material = _night_mat
	mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return mi


# ------------------------------------------------------------------ traffic

## A ship crosses in one to four minutes; spaced so a capital has five or six in
## view, a city or a station three or four, a settlement one or two, an
## outpost one now and then, nobody where nobody lives.
const TRAFFIC_EVERY := {MapGen.Development.OUTPOST: 110.0, MapGen.Development.SETTLEMENT: 55.0,
	MapGen.Development.CITY: 30.0, MapGen.Development.CAPITAL: 18.0}


func _step_traffic() -> void:
	var n := sky.node
	if n == null or sky._box == null:
		return
	var dev := n.development
	if n.type == MapGen.NodeType.STATION:
		dev = maxi(dev, MapGen.Development.CITY) as MapGen.Development
	if not TRAFFIC_EVERY.has(dev):
		return
	if _traffic == null or not is_instance_valid(_traffic):
		_traffic = _Traffic.new()
		_traffic.seed = n.index
		_traffic.every = float(TRAFFIC_EVERY[dev])
		_traffic.style = style
		var sc: Vector3 = LocalSky.SkyBakeS.STARCOL.get(sky.kind, LocalSky.SkyBakeS.STARCOL.ORDINARY)
		_traffic.lit = Color(sc.x, sc.y, sc.z).lerp(Color("#8a96a8"), 0.45)
		if style == 3:
			_traffic.hull = Color("#232d39")
			_traffic.lit = Color("#4d5f73")
		sky.add_child(_traffic)
	# (gone while anything is staged: never part of an encounter; and pulled
	# back toward the map's scale, as the dust is: the map has none. A push-in
	# carries it at the band's depth, every ship redrawn where the zoom puts
	# it, a game pixel each, never scaled.)
	var a := quiet_k * smoothstep(0.6, 1.0, minf(sky.zoom, 1.0))
	_traffic.visible = not hide.has(&"traffic") and a > 0.0
	_traffic.modulate.a = a
	_traffic.position = sky._box.position
	_traffic.t = sky.pose(sky.t, 8.0) if style == 1 else sky.t
	_traffic.shift = -sky.cam.x * LocalSky.F_BAND
	var zs := sky._zl(LocalSky.Z_BAND)
	_traffic.zs = zs
	_traffic.za = sky._zoom_fixed + (sky._zoom_to - sky._zoom_fixed) * LocalSky.Z_BAND - sky._zoom_fixed * zs
	_traffic.hide_c = Vector2(-9999, -9999)
	_traffic.hide_r = 0.0
	if sky._near_world is PlanetView:
		_traffic.hide_c = sky._near_world.position
		_traffic.hide_r = float((sky._near_world.get("_mat") as ShaderMaterial).get_shader_parameter("r")) + 4.0
	_traffic.queue_redraw()


## The far ships, a game pixel at a time over the sky, at the band's depth:
## worked out from the sky's clock alone, so the same moment shows the same
## ships. A dark sliver of hull lit along its top by the star (the nearer
## ones), its drive a point of light with a short fading wake; in the band
## above the fight, hidden behind the world you orbit.
class _Traffic extends Node2D:
	var seed := 0
	var every := 5.0
	var t := 0.0
	var shift := 0.0
	var style := 0
	var hull := Color("#141a24")
	var lit := Color.WHITE
	var hide_c := Vector2(-9999, -9999)
	var hide_r := 0.0
	## the zoom at the band's depth: a scene point p is drawn at za + p * zs
	var zs := 1.0
	var za := Vector2.ZERO
	const DRIVES := [Color(1.0, 0.72, 0.36), Color(0.62, 0.82, 1.0), Color(1.0, 0.9, 0.7)]
	const LEGACY_DRIVE := Color("#9fc0e0")

	func _h(j: int, k: int) -> float:
		return LocalSky.SkyBakeS.hash2(seed * 131 + j, 900 + k)

	func _px(x: float, y: float, c: Color) -> void:
		if Vector2(x, y).distance_to(hide_c) < hide_r:
			return
		draw_rect(Rect2(x, y, 1, 1), c)

	## A ship's nose, where the zoom puts it (a whole pixel).
	func _at(x: float, y: float) -> Vector2:
		return (za + Vector2(x, y) * zs).round()

	func _draw() -> void:
		var j1 := floori(t / every)
		var j0 := j1 - int(ceil(260.0 / every))
		for j in range(j0, j1 + 1):
			var far := _h(j, 1) < 0.55
			var v := (4.0 + 3.0 * _h(j, 2)) if far else (8.0 + 6.0 * _h(j, 2))
			var tj := (float(j) + 0.8 * _h(j, 3)) * every
			var age := t - tj
			if age < 0.0:
				continue
			var dir := 1.0 if _h(j, 4) < 0.5 else -1.0
			var x := (-24.0 + v * age) if dir > 0.0 else (984.0 - v * age)
			if x < -30.0 or x > 990.0:
				continue
			var pz := _at(x + shift, (58.0 + 30.0 * _h(j, 5)) if far else (92.0 + 34.0 * _h(j, 5)))
			x = pz.x
			var y := pz.y
			var n := (2 + int(2.0 * _h(j, 6))) if far else (7 + int(5.0 * _h(j, 6)))
			var drive: Color = LEGACY_DRIVE if style == 3 else DRIVES[int(_h(j, 7) * 3.0) % 3]
			var a := 0.7 if far else 1.0
			# the wake: behind the drive, fading (PAINTED: two flat tones; RADIANT
			# longer and softer; LEGACY short)
			var wl := (3 if far else 6) + int(4.0 * _h(j, 8))
			if style == 2:
				wl += 3
			elif style == 3:
				wl = maxi(2, wl / 2)
			for i in wl:
				var f := 1.0 - float(i) / float(wl)
				var wa := 0.45 * f
				if style == 1:
					wa = 0.4 if f > 0.5 else 0.18
				elif f < 0.4 and i % 2 == 1:
					continue
				_px(x - dir * float(n + 1 + i), y, Color(drive, wa * a))
			# the hull, nose first; its top row lit by the star (a near one only)
			for i in n:
				_px(x - dir * float(i), y, Color(hull, a))
				if not far and i > 0 and i < n - 1:
					_px(x - dir * float(i), y - 1.0, Color(lit, 0.8 * a))
				if not far and i > 1 and i < n - 2:
					_px(x - dir * float(i), y + 1.0, Color(hull.darkened(0.3), a))
			# the drive: a point of light and its glow (PAINTED and LEGACY: the
			# point alone)
			var dx := x - dir * float(n)
			_px(dx, y, Color(drive, a))
			if style == 0 or style == 2:
				var ga := 0.42 if style == 2 else 0.3
				for o: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-dir, 0)]:
					_px(dx + o.x, y + o.y, Color(drive, ga * a))


# ------------------------------------------------------------------ the test

## THE MOONS OVER `secs` OF QUIET (`-- sheet=MoonTest`): run forward from where
## they are on a copy of their clocks, each step checked against what always
## stands there; the steps a visible moon overlapped any of it, and how many
## moons went round and how many were held still. Headless as on screen: the
## places are the sky's plan's.
func audit(secs: float, dt: float = 0.1) -> Dictionary:
	if not _moons_chosen:
		_choose()
	var w := _world()
	var out := {"moons": moons.size(), "moving": 0, "held": 0, "bad": []}
	if w.is_empty():
		return out
	var rects := keep_out(true)
	for mi in moons.size():
		var m: Dictionary = moons[mi]
		if bool(m.held):
			out.held = int(out.held) + 1
			continue
		out.moving = int(out.moving) + 1
		var ph := float(m.phase)
		var n := int(secs / dt)
		for s in n:
			ph += dt * TAU / float(m.period)
			var oa := orbit_at(m, ph)
			if not clear_at(w.c, oa[0], oa[1], float(w.R), float(m.r), rects):
				(out.bad as Array).append("moon %d at %.1f s, %s" % [mi, dt * float(s), w.c + (oa[0] as Vector2)])
				break
	return out
