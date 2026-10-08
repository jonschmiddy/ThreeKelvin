class_name LocalFx
extends Node2D

## WHAT AN EVENT'S SKY DOES THAT NO PICTURE CAN (`LocalSubject`'s `fx` stages;
## Jon's "Forty-three bare events" plan, every one said yes to): things with no
## outline -- a pulsar's beam, a blue star's glare, a front, a bank of dust, a
## stream of ice -- which no generation has drawn well, drawn here in code in
## the scene's own light, behind the subject's pieces and in front of the sky.
##
## AS LIGHT ("draw light as light", "pixel-art lighting is a light map"):
## gathered, smooth inside, its edge dithered over a few pixels on a fixed
## pattern (`local_fx_light.gdshader`), eased in and out and never flashing. A
## moving edge crosses a pixel once (a beam's flat core lasts frames, so its
## peak never goes A, B, A). Nothing is drawn on your ship or within a margin of
## it, or under the event's band. With reduced motion nothing here moves: the
## beam, the wind and the drifting specks are not drawn at all, the rest hold
## still.
##
## An `fx` stage is `{stage = &"fx", fx = <kind>, ...}`:
##   beam    a pulsar's beam sweeping the sky every `period` s (`faint`: weaker).
##           FROM THE PULSAR, AS IT TURNS: the nearest pulsar on the chart, on
##           LOCAL's horizon at its bearing, its beam the lower lobe of
##           `PulsarView`'s own spin (the map's tilt, the map's sense of turn:
##           right, down, left, then away toward you) -- one turn a `period` --
##           fading as it turns toward you instead of flashing
##   glare   a blue star's glare spread over a quarter of the sky, washing it white
##   wind    a star shedding itself: thin streaks racing outward from the star,
##           each on its own ray, above the fight only
##   dust    a bank of dust (`at` from the box's middle, `radii`, `tilt`, `warm`,
##           `dens`) in 2x2 blocks, lit toward the star (`local_fx_dust`)
##   front   a curved shell coming in from the right edge, grit glinting in it
##   stream  a band of ice grit from `from` to `to` (from the box's middle),
##           thick in the middle, a few fast pieces out in front
##   drift   light things blowing out from the star past the pieces, as specks
##   gas     the gas closed in: the sky's far stars faded, its cloud thickened
##           (`LocalSky.set_closed`)
##   buoy    LOCAL's own coded beacon, dead (its rings and lamp out), at `at`,
##           a tether from its mast to the piece `tether` (a piece id)
##   marks   `marks` big painted marks on the piece `on` that cannot be read
##           (never letters)
##   moor    a slack line from piece `from` (its point `from_at`) to `to` (`to_at`)
## And on a piece: `tail` -- a comet's tails off it, away from the star.

const LIGHT := preload("res://shaders/local_fx_light.gdshader")
const DUST := preload("res://shaders/local_fx_dust.gdshader")
const PulsarViewS := preload("res://scripts/ui/sysmap/PulsarView.gd")

var sub: LocalSubject = null
var stages: Array = []
## the shader rects: {kind, rect, mat, st}
var _rects: Array = []
## paint behind the pieces (the buoy, its tether), light behind them (streaks,
## specks, the pulsar), paint over them (marks on a rock)
var _under: Node2D
var _light: Node2D
var _over_paint: Node2D
var _t := 0.0
var _rng_seed := 0
## THE BEAM this frame: where it comes from, where it points, its core and soft
## half-widths (radians), how strong it is (0 when it is not seen)
var beam_src := Vector2.ZERO
var beam_ang := 0.0
var beam_core := 0.05
var beam_soft := 0.12
var beam_k := 0.0
var _has_beam := false
var _wind: Array = []
var _drift: Array = []
var _stream: Array = []
var _closed := false


func _init() -> void:
	z_index = 0


## Build the effects of `fx_stages` (the subject's `fx` stages).
func build(fx_stages: Array) -> void:
	stages = fx_stages
	_rng_seed = absi(String(sub.oid).hash())
	_under = Node2D.new()
	_under.draw.connect(_draw_under)
	_light = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	_light.draw.connect(_draw_light)
	for st: Dictionary in stages:
		match StringName(st.get("fx", &"")):
			&"beam":
				_has_beam = true
				_rect(&"beam", 0, st)
			&"glare":
				_rect(&"glare", 1, st)
			&"front":
				_rect(&"front", 2, st)
			&"dust":
				_rect(&"dust", -1, st)
			&"wind":
				_seed_wind()
			&"drift":
				_seed_drift()
			&"stream":
				_seed_stream(st)
			&"gas":
				_closed = true
				if sub.sky != null and is_instance_valid(sub.sky):
					sub.sky.set_closed(float(st.get("k", 1.0)))
	# a comet's tails off a piece
	for rec: Dictionary in sub._placed:
		if bool(rec.get("tail", false)):
			_rect(&"tail", 3, {fx = &"tail"})
			break
	add_child(_under)
	add_child(_light)
	_over_paint = Node2D.new()
	_over_paint.draw.connect(_draw_over_paint)
	sub.add_child(_over_paint)
	# (over the pieces, under their clamps and lights)
	if sub._links != null:
		sub.move_child(_over_paint, sub._links.get_index())


func _rect(kind: StringName, mode: int, st: Dictionary) -> void:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.WHITE
	r.size = sub.size if sub.size.x > 0.0 else Vector2(944, 491)
	var m := ShaderMaterial.new()
	m.shader = DUST if mode < 0 else LIGHT
	if mode >= 0:
		m.set_shader_parameter("mode", mode)
	r.material = m
	# (the dust under the light, both under the pieces)
	add_child(r)
	if mode < 0:
		move_child(r, 0)
	_rects.append({kind = kind, rect = r, mat = m, st = st})


## What an effect asked of the sky goes with it.
func leave() -> void:
	if _closed and sub != null and sub.sky != null and is_instance_valid(sub.sky):
		sub.sky.set_closed(0.0)
	_closed = false


func _box_point(at: Variant) -> Vector2:
	var b: Rect2 = LocalSubject.box_for(sub.size)
	return b.get_center() + (at as Vector2 if at is Vector2 else Vector2.ZERO)


func _ship_v4() -> Vector4:
	var s: Rect2 = sub.ship_l
	return Vector4(s.position.x, s.position.y, s.size.x, s.size.y)


# ------------------------------------------------------------------ every frame

func step(t: float) -> void:
	_t = t
	var still := DisplaySettings.reduced_motion
	for e: Dictionary in _rects:
		var r: ColorRect = e.rect
		if r.size != sub.size and sub.size.x > 0.0:
			r.size = sub.size
		var m: ShaderMaterial = e.mat
		var st: Dictionary = e.st
		m.set_shader_parameter("ship", _ship_v4())
		m.set_shader_parameter("band_y", sub.band_y)
		m.set_shader_parameter("time", t)
		match StringName(e.kind):
			&"beam":
				_step_beam(st, t)
				r.visible = beam_k > 0.003 and not still
				m.set_shader_parameter("src", beam_src)
				m.set_shader_parameter("ang", beam_ang)
				m.set_shader_parameter("core", beam_core)
				m.set_shader_parameter("soft", beam_soft)
				m.set_shader_parameter("reach", 900.0)
				# (a soft band, not a searchlight; above the fight: fading out below
				# your ship's top)
				m.set_shader_parameter("k", beam_k * 0.6)
				m.set_shader_parameter("col", Vector3(0.62, 0.78, 1.0))
				m.set_shader_parameter("floor_y", sub.ship_l.position.y + 10.0 if sub.ship_l.size.x > 0.0 else 9999.0)
			&"glare":
				# breathing a little with the star, slowly
				var br := 1.0 if still else 0.94 + 0.06 * sin(t * TAU / 9.0)
				m.set_shader_parameter("src", sub.star_l)
				m.set_shader_parameter("r0", sub.star_r * 1.2 + 10.0)
				m.set_shader_parameter("r1", float(st.get("reach", 430.0)))
				m.set_shader_parameter("dir", st.get("dir", Vector2(0.9, 0.42)))
				m.set_shader_parameter("lean", float(st.get("lean", 0.72)))
				m.set_shader_parameter("col", Vector3(0.86, 0.93, 1.0))
				m.set_shader_parameter("col2", Vector3(0.3, 0.45, 0.8))
				m.set_shader_parameter("k", 0.8 * br)
			&"front":
				var R := float(st.get("r", 560.0))
				var lead_x := sub.size.x - float(st.get("inset", 250.0))
				var c := Vector2(lead_x + R, LocalSubject.box_for(sub.size).get_center().y - 30.0)
				m.set_shader_parameter("src", c)
				m.set_shader_parameter("r0", R)
				m.set_shader_parameter("r1", float(st.get("thick", 48.0)))
				m.set_shader_parameter("col", Vector3(1.0, 0.9, 0.74))
				m.set_shader_parameter("col2", Vector3(0.55, 0.42, 0.36))
				m.set_shader_parameter("k", 0.62 if still else 0.58 + 0.06 * sin(t * TAU / 11.0))
			&"tail":
				var head := _tail_head()
				r.visible = head.x > -9000.0
				var d := head - sub.star_l
				var ax := d.normalized() if d.length() > 1.0 else Vector2(1.0, 0.3)
				# (the dust tail bends back along the orbit: upward, off the fight)
				var nx := Vector2(-ax.y, ax.x)
				var bend := nx if nx.y < 0.0 else -nx
				m.set_shader_parameter("src", head)
				m.set_shader_parameter("dir", ax)
				m.set_shader_parameter("r1", float(st.get("len", 360.0)))
				m.set_shader_parameter("tail_bend", bend)
				m.set_shader_parameter("col", Vector3(0.45, 0.68, 1.0))
				m.set_shader_parameter("col2", Vector3(1.0, 0.9, 0.72))
				m.set_shader_parameter("k", 0.85)
			&"dust":
				var cc := _box_point(st.get("at", Vector2.ZERO))
				m.set_shader_parameter("centre", cc)
				m.set_shader_parameter("radii", st.get("radii", Vector2(250.0, 110.0)))
				m.set_shader_parameter("tilt", deg_to_rad(float(st.get("tilt", 0.0))))
				m.set_shader_parameter("dens", float(st.get("dens", 0.85)))
				m.set_shader_parameter("seed", float(_rng_seed % 97))
				var ts := sub.star_l - cc
				m.set_shader_parameter("to_star", ts.normalized() if ts.length() > 1.0 else Vector2(-0.6, -0.8))
				m.set_shader_parameter("time", 0.0 if still else t)
				_dust_colours(m, st)
	_light.queue_redraw()
	_under.queue_redraw()
	if _over_paint != null:
		_over_paint.queue_redraw()


# ------------------------------------------------------------------ the beam

## Where the nearest pulsar on the chart lies from this system: LOCAL looks
## across the system with the chart's east on its right, so the pulsar stands
## on the horizon toward its bearing (off the view's edge when it lies well to
## one side). In the sky's own 960x540 frame.
func _pulsar_at() -> Vector2:
	var x := 700.0
	if sub.node_index >= 0 and sub.node_index < Run.map.size():
		var n: MapGen.MapNode = Run.map[sub.node_index]
		var best: MapGen.MapNode = null
		var bd := INF
		for raw in Run.map:
			var o: MapGen.MapNode = raw
			if o.type != MapGen.NodeType.PULSAR:
				continue
			var d := MapGen.hop_distance(n, o)
			if d < bd:
				bd = d
				best = o
		if best != null:
			var sq := maxf(0.05, float(Run.galaxy.squash)) if Run.galaxy != null else 1.0
			var v := Vector2(best.gal.x - n.gal.x, (best.gal.y - n.gal.y) / sq)
			if v.length() > 0.001:
				x = 480.0 + 560.0 * clampf(v.normalized().x, -1.0, 1.0)
	return Vector2(roundf(x), LocalSky.HORIZON - 4.0)


func _step_beam(st: Dictionary, t: float) -> void:
	var period := maxf(float(st.get("period", 11.0)), 1.0)
	var inv := sub.get_global_transform().affine_inverse()
	var src_scene := _pulsar_at()
	var g := sub.sky.scene_to_global(src_scene) if sub.sky != null and is_instance_valid(sub.sky) else src_scene
	beam_src = inv * g
	# THE PULSAR'S OWN TURN, one a period: `PulsarView.frame`'s magnetic axis at
	# that beat (the map's tilt, its sense of turn), its lower lobe -- the end
	# that reaches down across the sky
	var ph := float(_rng_seed % 1000) / 1000.0
	var G: Dictionary = PulsarViewS.frame({"wobble": 0.0, "quake": false}, t / period + ph + PulsarViewS.PEAK_S + PulsarViewS.OFF_S)
	var mv: Vector3 = G.m
	var low := Vector2(mv.x, mv.y)
	if low.y < 0.0:
		low = -low
	var s := low.length() / 0.925
	beam_ang = low.angle()
	# its core lasts frames as it crosses a pixel (no peak going A, B, A): the
	# fastest the lobe turns on screen is 1.32 times the spin
	var per_frame := 1.32 * TAU / period / 30.0
	beam_core = maxf(0.035, per_frame * 1.4)
	beam_soft = beam_core * 2.6
	# turning toward you it fades (where the map's pulsar flashes, this never does)
	var env := smoothstep(0.3, 0.8, s)
	beam_k = env * (0.45 if bool(st.get("faint", false)) else 1.0)


## How lit a point (this control's px) is by the beam now, 0..1.
func beam_hit(p: Vector2) -> float:
	if not _has_beam or beam_k <= 0.0 or DisplaySettings.reduced_motion:
		return 0.0
	var d := p - beam_src
	if d.length() < 4.0:
		return 0.0
	var da := absf(wrapf(d.angle() - beam_ang, -PI, PI))
	var m := 1.0 - clampf((da - beam_core) / maxf(beam_soft - beam_core, 1e-3), 0.0, 1.0)
	# (above the fight only, as the beam is drawn)
	var floor_y := sub.ship_l.position.y + 10.0 if sub.ship_l.size.x > 0.0 else 9999.0
	var fl := clampf((floor_y + 40.0 - p.y) / 40.0, 0.0, 1.0)
	return m * m * clampf(beam_k / 0.45, 0.0, 1.0) * fl


# ------------------------------------------------------------------ the dust's colours

func _dust_colours(m: ShaderMaterial, st: Dictionary) -> void:
	var lit := Vector3(0.74, 0.44, 0.24)
	var dark := Vector3(0.16, 0.08, 0.06)
	var sky := sub.sky
	if not bool(st.get("warm", false)) and sky != null and is_instance_valid(sky):
		# a shoal in the lane's own light: the cloud's colour where there is one,
		# a cold grey-blue where there is none, lit by the star
		var hue := Vector3(0.36, 0.42, 0.52)
		if sky._neb_mat != null and sky._sky_look.has("hue"):
			hue = sky._sky_look.hue
		var sl := sky.star_light()
		lit = hue.lerp(Vector3(0.62, 0.6, 0.58), 0.4) * (Vector3(0.7, 0.7, 0.7) + sl * 0.3)
		dark = hue * 0.18 + Vector3(0.03, 0.035, 0.05)
	m.set_shader_parameter("lit_col", lit)
	m.set_shader_parameter("dark_col", dark)
	var pn0: Variant = m.get_shader_parameter("pal_n")
	if sky != null and is_instance_valid(sky) and sky._palette_mat != null and (pn0 == null or int(pn0) == 0):
		var pn := int(sky._palette_mat.get_shader_parameter("pal_n"))
		if pn > 0:
			m.set_shader_parameter("pal", sky._palette_mat.get_shader_parameter("pal"))
			m.set_shader_parameter("pal_n", pn)


# ------------------------------------------------------------------ the comet

func _tail_head() -> Vector2:
	for rec: Dictionary in sub._placed:
		if bool(rec.get("tail", false)):
			return (rec.node as Node2D).position
	return Vector2(-9999.0, -9999.0)


# ------------------------------------------------------------------ streaks and specks

func _h(a: int, b: int) -> float:
	return LocalSky.SkyBakeS.hash2(_rng_seed % 100000 + a, b)


func _seed_wind() -> void:
	_wind.clear()
	for i in 40:
		# out from the star along its own ray, the rays fanned across the sky
		# below it, a little either side of level
		_wind.append({
			"a": lerpf(-0.18, PI + 0.18, _h(i, 1)),
			"v": 80.0 + 70.0 * _h(i, 2),
			"len": 16.0 + 30.0 * _h(i, 3),
			"ph": _h(i, 4) * 900.0,
		})


func _seed_drift() -> void:
	_drift.clear()
	for i in 22:
		_drift.append({"d0": 40.0 + 260.0 * _h(i, 11), "side": (_h(i, 12) - 0.5) * 120.0,
			"v": 5.0 + 9.0 * _h(i, 13), "life": 7.0 + 5.0 * _h(i, 14), "ph": _h(i, 15) * 20.0})


func _seed_stream(st: Dictionary) -> void:
	_stream.clear()
	for i in int(st.get("grit", 90)):
		_stream.append({"u": _h(i, 21), "w": (_h(i, 22) + _h(i, 23) + _h(i, 24) - 1.5) / 1.5,
			"b": _h(i, 25), "fast": i < 4})


## Light behind the pieces: the pulsar itself, the wind's streaks, the light
## things blowing out, the stream's grit.
func _draw_light() -> void:
	var still := DisplaySettings.reduced_motion
	var t := _t
	if _has_beam:
		# the pulsar, where it stands in view: a small steady point, never flashing
		var p := beam_src.round()
		if p.x >= 0.0 and p.x < sub.size.x and p.y >= 0.0:
			_glow(p, 9, Color(0.4, 0.55, 1.0), 0.35)
			_glow(p, 3, Color(0.85, 0.93, 1.0), 0.9)
	if not _wind.is_empty() and not still:
		_draw_wind(t)
	if not _drift.is_empty() and not still:
		_draw_drift(t)
	if not _stream.is_empty():
		_draw_stream(t, still)


## THE WIND, out from the star: each streak a line of whole pixels along its own
## ray from the star's centre, its head bright and its tail fading, moving out a
## pixel step at a time; only above the fight (over your ship's top, less a
## margin), easing out toward that line and in from the star's edge.
func _draw_wind(t: float) -> void:
	var c := sub.star_l
	var lim := minf(sub.ship_l.position.y - 26.0 if sub.ship_l.size.x > 0.0 else 150.0, sub.band_y - 30.0)
	var r_in := sub.star_r + 16.0
	for w: Dictionary in _wind:
		var dir := Vector2.from_angle(float(w.a))
		var span := 760.0
		var head := r_in + fposmod(float(w.ph) + float(w.v) * t, span)
		var L := float(w.len)
		var s := floorf(head - L)
		while s <= head:
			var q := (c + dir * s).round()
			s += 1.0
			if q.y > lim or q.y < 0.0 or q.x < 0.0 or q.x >= sub.size.x:
				continue
			var f := 1.0 - (head - s) / L
			var lv := floorf(f * 3.0 + 0.5) / 3.0
			var ease := clampf((s - r_in) / 40.0, 0.0, 1.0) * clampf((lim - q.y) / 30.0, 0.0, 1.0)
			var a := lv * ease * 0.55
			if a <= 0.02:
				continue
			_put(q, Color(0.62 * a, 0.78 * a, 1.0 * a, 1.0))


## LIGHT THINGS BLOWING OUT from the star past the heavy pieces: specks, each
## moving slowly out along its ray, fading in and out over its life.
func _draw_drift(t: float) -> void:
	var b := LocalSubject.box_for(sub.size)
	var dirv := b.get_center() - sub.star_l
	var ax := dirv.normalized() if dirv.length() > 1.0 else Vector2(0.8, 0.6)
	var nx := Vector2(-ax.y, ax.x)
	for d: Dictionary in _drift:
		var life := float(d.life)
		var u := fposmod(t + float(d.ph), life)
		var gen := floorf((t + float(d.ph)) / life)
		var j := fposmod(sin(gen * 12.9898 + float(d.ph)) * 43758.5, 1.0)
		var base := sub.star_l + ax * (sub.star_r + float(d.d0)) + nx * (float(d.side) + (j - 0.5) * 40.0)
		var rad := (base - sub.star_l).normalized()
		var q := (base + rad * float(d.v) * u).round()
		var e := sin(u / life * PI)
		if not _clear_of_ship(q, 16.0) or q.y > sub.band_y - 12.0:
			continue
		_glow(q, 2, Color(1.0, 0.92, 0.78), 0.55 * e)


## THE STREAM'S GRIT: specks across the band from `from` to `to`, thick in its
## middle and thin at its ends, drifting along it; the first few fast, out in
## front of it.
func _draw_stream(t: float, still: bool) -> void:
	var st: Dictionary = {}
	for s: Dictionary in stages:
		if StringName(s.get("fx", &"")) == &"stream":
			st = s
	var a := _box_point(st.get("from", Vector2(-200.0, -90.0)))
	var b := _box_point(st.get("to", Vector2(220.0, 40.0)))
	var ax := b - a
	var L := ax.length()
	if L < 1.0:
		return
	var u0 := ax / L
	var nx := Vector2(-u0.y, u0.x)
	var width := float(st.get("width", 34.0))
	for g: Dictionary in _stream:
		var u := float(g.u)
		var q: Vector2
		var a2 := 0.0
		if bool(g.fast):
			# out in front: from the band's leading end onward, quick, then again
			var run := 90.0
			var k := fposmod(u * run + (0.0 if still else t * 34.0), run)
			q = b + u0 * (8.0 + k) + nx * float(g.w) * 6.0
			a2 = sin(k / run * PI) * 0.6
		else:
			var uu := fposmod(u + (0.0 if still else t * 0.006), 1.0)
			var thick := sin(uu * PI)
			q = a + ax * uu + nx * float(g.w) * width * (0.35 + 0.65 * thick)
			a2 = (0.25 + 0.35 * float(g.b)) * clampf(thick * 2.5, 0.0, 1.0)
		q = q.round()
		if not _clear_of_ship(q, 14.0) or q.y > sub.band_y - 10.0:
			continue
		var col := Color(0.62, 0.74, 0.86)
		_put(q, Color(col.r * a2, col.g * a2, col.b * a2, 1.0))
		if float(g.b) > 0.8:
			_put(q + Vector2(1, 0), Color(col.r * a2 * 0.5, col.g * a2 * 0.5, col.b * a2 * 0.5, 1.0))


## (`lit_points`: what would be drawn, collected instead)
var _collect: Variant = null


func _put(q: Vector2, c: Color) -> void:
	if _collect != null:
		(_collect as Array).append(q)
		return
	_light.draw_rect(Rect2(q, Vector2.ONE), c)


## Every point the streaks, specks and grit would light at time `t` (for
## `-- subjecttest`: none on your ship, none under the band).
func lit_points(t: float) -> Array:
	_collect = []
	if not _wind.is_empty():
		_draw_wind(t)
	if not _drift.is_empty():
		_draw_drift(t)
	if not _stream.is_empty():
		_draw_stream(t, false)
	var out: Array = _collect
	_collect = null
	return out


func _clear_of_ship(q: Vector2, m: float) -> bool:
	return not sub.ship_l.grow(m).has_point(q)


func _glow(at: Vector2, r: int, col: Color, a: float) -> void:
	if a <= 0.01:
		return
	if _collect != null:
		(_collect as Array).append(at)
		return
	var tex := LocalSubject._glow_tex(maxi(r, 1))
	var sz := tex.get_size()
	_light.draw_texture(tex, (at - sz * 0.5).round(), Color(col.r * a, col.g * a, col.b * a, 1.0))


# ------------------------------------------------------------------ paint

## Paint behind the pieces: LOCAL's coded beacon, dead, and its tether.
func _draw_under() -> void:
	for st: Dictionary in stages:
		if StringName(st.get("fx", &"")) == &"moor":
			# A LINE between two pieces (a cutter moored off a wreck's stern):
			# from a point of one to a point of the other, slack
			var ra := _rec_of(StringName(st.get("from", &"")))
			var rb := _rec_of(StringName(st.get("to", &"")))
			if not ra.is_empty() and not rb.is_empty():
				var a: Vector2 = sub._at(ra, st.get("from_at", [0, 0]))
				var b: Vector2 = sub._at(rb, st.get("to_at", [0, 0]))
				var prev := a
				for i in range(1, 17):
					var u := float(i) / 16.0
					var q := a.lerp(b, u) + Vector2(0.0, sin(u * PI) * 6.0)
					_under.draw_line(prev.round(), q.round(), Color(0.34, 0.36, 0.4), 1.0)
					prev = q
			continue
		if StringName(st.get("fx", &"")) != &"buoy":
			continue
		var c := _box_point(st.get("at", Vector2.ZERO)).round()
		c.y += roundf(sin(_t * TAU / 29.0) * 1.5) if not DisplaySettings.reduced_motion else 0.0
		# the tether first: from the mast's foot to the piece it holds, sagging
		var to := _piece_pos(StringName(st.get("tether", &"")))
		if to.x > -9000.0:
			var from := c + Vector2(4.0, -8.0)
			var prev := from
			for i in range(1, 17):
				var u := float(i) / 16.0
				var q := from.lerp(to, u) + Vector2(0.0, sin(u * PI) * 10.0)
				_under.draw_line(prev.round(), q.round(), Color(0.3, 0.32, 0.36), 1.0)
				prev = q
		_buoy(c)


## LOCAL's own beacon buoy (`EncounterView.AreaView._beacon`), the same steel,
## with its power off: no rings walking out, its lamp dark glass.
func _buoy(c: Vector2) -> void:
	var grey: Array[Color] = [Color("#141721"), Color("#1e202a"), Color("#2e313e"),
		Color("#424758"), Color("#5c6376"), Color("#80889e")]
	_body(c + Vector2(-4, -34), Vector2(8, 62), grey, 0.5)
	_body(c + Vector2(-16, -44), Vector2(32, 12), grey, 0.7)
	_body(c + Vector2(-11, 24), Vector2(22, 7), grey, 0.4)
	var ink := Color("#0b0f16")
	_under.draw_rect(Rect2(c + Vector2(-6, -50), Vector2(12, 6)), ink, true)
	_under.draw_rect(Rect2(c + Vector2(-5, -49), Vector2(10, 4)), Color("#1c2230"), true)
	_under.draw_rect(Rect2(c + Vector2(-3, -49), Vector2(6, 1)), Color("#34405a"), true)


func _body(pos: Vector2, dim: Vector2, r: Array[Color], deck: float) -> void:
	var p := pos.round()
	var w := dim.x
	var h := dim.y
	var d := clampf(roundf(h * deck), 1.0, h - 1.0)
	var ink := Color("#0b0f16")
	_under.draw_rect(Rect2(p - Vector2.ONE, Vector2(w + 2, h + 2)), ink, true)
	_under.draw_rect(Rect2(p, Vector2(w, d)), r[3], true)
	_under.draw_rect(Rect2(p, Vector2(w, 1)), r[4], true)
	_under.draw_rect(Rect2(p + Vector2(0, d - 1), Vector2(w, 1)), r[5], true)
	_under.draw_rect(Rect2(p + Vector2(0, d), Vector2(w, h - d)), r[1], true)
	_under.draw_rect(Rect2(p + Vector2(0, d), Vector2(w, minf(2.0, h - d))), r[2], true)
	_under.draw_rect(Rect2(p + Vector2(0, h - 1), Vector2(w, 1)), r[0], true)


func _rec_of(id: StringName) -> Dictionary:
	for rec: Dictionary in sub._placed:
		if StringName(rec.get("id", &"")) == id:
			return rec
	return {}


func _piece_pos(id: StringName) -> Vector2:
	if id == &"":
		return Vector2(-9999.0, -9999.0)
	for rec: Dictionary in sub._placed:
		if StringName(rec.get("id", &"")) == id:
			return (rec.node as Node2D).position
	return Vector2(-9999.0, -9999.0)


## Paint over the pieces: big marks on a rock nobody can read. Each a few blocky
## strokes on a 3 px grid from the event's own seed -- bars and hooks, never a
## letter's shape -- in a row across the rock's face, weathered (a stroke
## broken here and there), turning with nothing: they drift with the rock.
func _draw_over_paint() -> void:
	for st: Dictionary in stages:
		if StringName(st.get("fx", &"")) != &"marks":
			continue
		var at := _piece_pos(StringName(st.get("on", &"")))
		if at.x < -9000.0:
			continue
		var n := int(st.get("marks", 4))
		var cell := 3.0
		var gw := 3
		var gh := 5
		var gap := 4.0
		var total := float(n) * float(gw) * cell + float(n - 1) * gap
		var o: Vector2 = at + (st.get("off", Vector2.ZERO) as Vector2) - Vector2(total * 0.5, float(gh) * cell * 0.5)
		var paint := Color(0.86, 0.8, 0.62)
		var shade := Color(0.5, 0.45, 0.36)
		for g in n:
			for yy in gh:
				for xx in gw:
					# a stroke pattern: a spine on one side, bars across at odd
					# heights, a hook -- all of it chosen by hash, never a glyph
					var hh := _h(g * 31 + yy * 7 + xx, 41)
					var spine := xx == (0 if _h(g, 42) < 0.5 else gw - 1)
					var bar := yy % 2 == 0 and _h(g * 5 + yy, 43) < 0.6
					var on := (spine and _h(g, 44) < 0.8) or bar or hh < 0.18
					if not on or _h(g * 13 + yy * 3 + xx, 45) < 0.12:
						continue
					var q := (o + Vector2(float(g) * (float(gw) * cell + gap) + float(xx) * cell, float(yy) * cell)).round()
					_over_paint.draw_rect(Rect2(q, Vector2(cell, cell)), paint)
					_over_paint.draw_rect(Rect2(q + Vector2(0, cell - 1.0), Vector2(cell, 1.0)), shade)
