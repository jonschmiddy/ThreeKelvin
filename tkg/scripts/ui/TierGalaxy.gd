class_name TierGalaxy
extends Control

## The tier's galaxy on the LAUNCH A RUN box (Jon's v2, Nov 9): 112 px of
## procedural pixel art, animated. The body is a dithered glow drawn by
## `tier_galaxy.gdshader`; over it, whole-pixel stars that move smoothly and
## twinkle, and flares from the core. Everything rises with the tier.
## Why: docs/why/Ladder.md#the-galaxy

const G := 112
const RED := Color8(255, 60, 40)
const MID := [Color8(120, 150, 225), Color8(235, 185, 105), Color8(245, 115, 55), Color8(255, 80, 70)]
const COOL := Color8(140, 165, 230)
const PANEL := Color8(17, 24, 35)
## The stars step on a 30 Hz clock, as a film of them would.
const HZ := 30.0
## The ring of ten lamps round the galaxy, one lit per rule in force (Jon's T-C, Nov 11).
## Why: docs/why/LaunchBox.md#the-stack
const LAMP_R := 52.0
const RING := Color8(30, 42, 57)
const LAMP_RIM := Color8(9, 13, 20)
const LAMP_OFF := Color8(44, 60, 78)
## The tier's picture: a strip of square frames, `tier_<n>.png`, drawn G px across and
## played at ART_FPS on GameClock. Off ("") until Jon picks; C2's strips stay in art/ui/tiers.
## Why: docs/why/LaunchBox.md#the-pictures
const ART := ""
const ART_FPS := 12.0
## Dev switches: a folder of draft strips (`-- sheet=LaunchBoxShot tierart=<dir>`), and a held frame.
static var art_dir := ""
static var hold_frame := -1

var tier: int = 0
var form: int = 0
var heat: float = 0.0
var omega: float = 0.12
var twinkle: float = 0.12
var pulse_amp: float = 0.04
var pulse_t: float = 3.4
var flare_rate: float = 0.0
var glare: float = 0.0
var bloom: float = 0.65
var tilt: float = 0.52
var rot: float = 0.0
var mid: Color = MID[0]
var core: Color = Color8(255, 244, 220)

var _t: float = 0.0
var _tick: int = -1
var _stars: Array[Dictionary] = []
var far: Array[Vector2i] = []
var _flares: Array[Array] = []
var _rng := RandomNumberGenerator.new()
var _body: ColorRect
var _mat: ShaderMaterial
var _art: Texture2D
var _art_n := 0
var _art_k := -1
var _lamps: Lamps
var _ring: Array[Vector2] = []


func _init() -> void:
	# it takes the pointer for its tag: the rules in force, by name
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(G, G)
	size = Vector2(G, G)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = ColorRect.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = Vector2(G, G)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/tier_galaxy.gdshader")
	_body.material = _mat
	add_child(_body)
	_lamps = Lamps.new()
	_lamps.gal = self
	add_child(_lamps)
	for i in 720:
		var q := (Vector2(G / 2.0, G / 2.0) + Vector2.from_angle(i * PI / 360.0) * LAMP_R).floor()
		if not _ring.has(q):
			_ring.append(q)
	# the far stars behind it, the same every time
	var fr := RandomNumberGenerator.new()
	fr.seed = 3
	for i in 26:
		far.append(Vector2i(fr.randi_range(0, G - 1), fr.randi_range(0, G - 1)))


## Build the galaxy for a tier: its heat, colours, shape and stars.
func set_tier(t: int) -> void:
	tier = clampi(t, 0, Ladder.count() - 1)
	form = int(Ladder.form(tier))
	var h := float(tier) / 10.0
	heat = h
	omega = 0.12 + 1.2 * pow(h, 1.6)
	twinkle = 0.12 + 0.7 * h
	pulse_amp = 0.04 + 0.36 * h
	pulse_t = 3.4 - 2.8 * h
	flare_rate = 0.0 if tier < 4 else (0.4 + 1.2 * float(tier - 4) / 6.0)
	glare = maxf(0.0, float(tier - 2) / 8.0)
	bloom = 0.65 + 0.6 * h
	var within: float = [h * 10.0 / 3.0, float(tier - 4) / 2.0, float(tier - 7) / 2.0, 1.0][form]
	mid = MID[form].lerp(RED, 0.35 * clampf(within, 0.0, 1.0))
	core = Color8(255, 244, 220).lerp(Color8(255, 200, 170), h)
	tilt = [0.52, 0.28, 0.92, 0.5][form]
	rot = deg_to_rad(-22.0) if form == 3 else 0.0
	_rng.seed = 7 + tier
	_stars.clear()
	_flares.clear()
	_seed_stars()
	_mat.set_shader_parameter(&"form", form)
	_mat.set_shader_parameter(&"omega", omega)
	_mat.set_shader_parameter(&"bloom", bloom)
	_mat.set_shader_parameter(&"glare", glare)
	_mat.set_shader_parameter(&"heat", heat)
	_mat.set_shader_parameter(&"tilt", tilt)
	_mat.set_shader_parameter(&"rot", rot)
	_mat.set_shader_parameter(&"mid", Vector3(mid.r, mid.g, mid.b))
	_mat.set_shader_parameter(&"core", Vector3(core.r, core.g, core.b))
	_mat.set_shader_parameter(&"cool", Vector3(COOL.r, COOL.g, COOL.b))
	_mat.set_shader_parameter(&"panel", Vector3(PANEL.r, PANEL.g, PANEL.b))
	_tick = -1
	_art = _load_art()
	_art_n = 0 if _art == null else _art.get_width() / _art.get_height()
	_art_k = -1
	_body.visible = _art == null
	tooltip_text = rules_text()
	_lamps.queue_redraw()
	queue_redraw()


func _load_art() -> Texture2D:
	var draft := art_dir.path_join("tier_%d.png" % tier)
	if art_dir != "":
		return ImageTexture.create_from_image(Image.load_from_file(draft)) if FileAccess.file_exists(draft) else null
	var path := ART.path_join("tier_%d.png" % tier)
	return load(path) as Texture2D if ART != "" and ResourceLoader.exists(path) else null


## The picture's frame now, or -1 with no picture.
func art_frame() -> int:
	if _art_n == 0:
		return -1
	return posmod(hold_frame if hold_frame >= 0 else int(GameClock.now() * ART_FPS), _art_n)


func _seed_stars() -> void:
	var r := _rng
	if form == 3:
		for i in 90:
			_stars.append({kind = &"core", r = r.randf(), a = r.randf() * 6.3, b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.12})
		for i in 170:
			_stars.append({kind = &"tail", u = r.randf(), w = r.randfn(0.0, 2.6), sp = r.randf_range(0.05, 0.11), b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.15})
		for i in 120:
			var arm := r.randi_range(0, 1)
			var rr := 8.0 + 50.0 * pow(r.randf(), 0.85)
			var a := float(arm) * PI + log(1.0 + rr / 7.0) * 2.1 + r.randfn(0.0, 0.2)
			_stars.append({kind = &"arm", r = rr, a = a, b = r.randf_range(0.4, 0.9), ph = r.randf() * 6.3, big = r.randf() < 0.06})
		return
	var n: int = [240, 200, 300][form]
	for i in n:
		var u := r.randf()
		if form == 0:
			var arm := r.randi_range(0, 1)
			var rr := 5.0 + 46.0 * pow(u, 0.85)
			var a := float(arm) * PI + log(1.0 + rr / 6.0) * 2.1 + r.randfn(0.0, 0.22)
			_stars.append({kind = &"orbit", r = rr, a = a, s = 1.0, inc = 0.0, b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.08})
		elif form == 1:
			var rr := 4.0 + 48.0 * pow(u, 0.6)
			_stars.append({kind = &"orbit", r = rr, a = r.randf() * 6.3, s = 1.0, inc = 0.0, b = r.randf_range(0.4, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.06})
		else:
			var rr := 3.0 + 48.0 * pow(u, 1.7)
			var sp := r.randf_range(0.5, 1.6) * (-1.0 if r.randf() < 0.5 else 1.0)
			_stars.append({kind = &"ball", r = rr, a = r.randf() * 6.3, s = sp, inc = r.randf() * PI, b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.1})


func pulse() -> float:
	var p := sin(TAU * _t / pulse_t)
	if form == 3:
		# a stutter: the beat holds, drops, jumps, by a hash of the moment
		var step := int(_t * 9.0)
		var j := float((step * 7919) % 11) / 10.0
		p = 1.0 if j > 0.45 else -0.6
	return 1.0 + pulse_amp * p


func _process(delta: float) -> void:
	if _art != null:
		if art_frame() != _art_k:
			_art_k = art_frame()
			queue_redraw()
		return
	_t += delta
	var tick := int(floorf(_t * HZ))
	if tick == _tick:
		return
	var dt := float(tick - _tick) / HZ if _tick >= 0 else 0.0
	_tick = tick
	_mat.set_shader_parameter(&"t", _t)
	_mat.set_shader_parameter(&"pulse", pulse())
	if _rng.randf() < flare_rate * dt:
		_flares.append([_rng.randf() * 6.3, _t, _rng.randf_range(0.25, 0.5), _rng.randf_range(18.0, 40.0)])
	var keep: Array[Array] = []
	for f in _flares:
		if _t - float(f[1]) < float(f[2]):
			keep.append(f)
	_flares = keep
	queue_redraw()


func _bez(u: float) -> Vector2:
	var p0 := Vector2(90, 86)
	var p1 := Vector2(66, 112)
	var p2 := Vector2(24, 100)
	var p3 := Vector2(46, 60)
	var v := 1.0 - u
	return v * v * v * p0 + 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u * p3


func _draw() -> void:
	# the far stars behind the body are under the ColorRect: drawn by the parent, they
	# would be over it, so the body rect is kept transparent where the glow is none
	if _art != null:
		for q in _ring:
			draw_rect(Rect2(q, Vector2.ONE), RING)
		var fh := float(_art.get_height())
		draw_texture_rect_region(_art, Rect2(0, 0, G, G), Rect2(maxi(art_frame(), 0) * fh, 0, fh, fh))
		return
	for p in far:
		draw_rect(Rect2(p.x, p.y, 1, 1), Color8(40, 52, 68) if (p.x * 7 + p.y * 13) % 10 < 7 else Color8(70, 84, 104))
	# the lamps' ring, under the glow like the far stars: it shows only where the galaxy is dark
	for q in _ring:
		draw_rect(Rect2(q, Vector2.ONE), RING)
	var th := omega * _t
	var c := G / 2.0
	var dw := Vector2(90, 86)
	for st in _stars:
		var x := 0.0
		var y := 0.0
		var fade := 1.0
		var base := mid
		match st.kind:
			&"core":
				var rr := pow(float(st.r), 0.7) * 8.0
				var a := float(st.a) + th * 0.8
				x = dw.x - c + rr * cos(a)
				y = dw.y - c + rr * sin(a) * 0.8
			&"tail":
				var u := fmod(float(st.u) + _t * float(st.sp), 1.0)
				var p := _bez(u)
				var a0 := _bez(maxf(0.0, u - 0.01))
				var b0 := _bez(minf(1.0, u + 0.01))
				var tg := (b0 - a0).normalized()
				var nrm := Vector2(-tg.y, tg.x)
				x = p.x - c + nrm.x * float(st.w)
				y = p.y - c + nrm.y * float(st.w)
				fade = 1.0 - u * u * 0.9
				base = mid.lerp(COOL, u * u)
			&"arm":
				var a := float(st.a) + th * 0.3
				x = 34.0 - c + float(st.r) * cos(a)
				y = 30.0 - c + float(st.r) * sin(a) * 0.55
				base = COOL
			&"ball":
				var a := float(st.a) + th * float(st.s)
				x = float(st.r) * cos(a)
				y = float(st.r) * sin(a) * cos(float(st.inc)) * 0.92
			_:
				var a := float(st.a) + th
				x = float(st.r) * cos(a)
				y = float(st.r) * sin(a) * tilt
		var tw := 1.0 - twinkle * (0.5 + 0.5 * sin(_t * (2.5 + 9.0 * heat) + float(st.ph)))
		var b := float(st.b) * tw * fade
		if b < 0.18:
			continue
		var px := int(round(c + x))
		var py := int(round(c + y))
		if px < 0 or px >= G or py < 0 or py >= G:
			continue
		var col := base.lerp(Color.WHITE, minf(1.0, b))
		draw_rect(Rect2(px, py, 1, 1), col)
		if bool(st.big) and b > 0.6:
			var half := col.lerp(mid, 0.5)
			draw_rect(Rect2(px + 1, py, 1, 1), half)
			draw_rect(Rect2(px, py + 1, 1, 1), half)
	var fc := dw if form == 3 else Vector2(c, c)
	for f in _flares:
		var age := (_t - float(f[1])) / float(f[2])
		var L := float(f[3]) * (0.5 if form == 3 else 1.0) * minf(1.0, age * 3.0)
		var a := float(f[0])
		var from := Vector2(fc.x + cos(a) * 6.0, fc.y + sin(a) * 6.0 * tilt).round()
		var to := Vector2(fc.x + cos(a) * L, fc.y + sin(a) * L * tilt).round()
		draw_line(from, to, mid.lerp(Color.WHITE, (1.0 - age) * 0.9), 1.0)


# ------------------------------------------------------------------ the rules in force

## Lamp k's 3 x 3 core (k 1 to 10, clockwise from the top), in this control's pixels.
func lamp_rect(k: int) -> Rect2:
	var a := -PI / 2.0 + float(k - 1) * TAU / 10.0
	var c := (Vector2(G / 2.0, G / 2.0) + Vector2.from_angle(a) * LAMP_R).floor()
	return Rect2(c - Vector2.ONE, Vector2(3, 3))


## How many lamps are lit: one per rule in force.
func lamps_lit() -> int:
	return Ladder.in_force(tier).size()


## The tag's words as plain text (what `TagLayer` keys on); the tag itself is `_make_custom_tooltip`.
func rules_text() -> String:
	var ks := Ladder.in_force(tier)
	if ks.is_empty():
		return "No rules in force."
	var names: PackedStringArray = []
	for k in ks:
		names.append("%d %s" % [k, Ladder.rung_name(k)])
	return "%s
%s" % [heading(), "
".join(names)]


func heading() -> String:
	var n := Ladder.in_force(tier).size()
	return "NO RULES IN FORCE" if n == 0 else ("1 RULE IN FORCE" if n == 1 else "%d RULES IN FORCE" % n)


func _make_custom_tooltip(_for_text: String) -> Object:
	var body := RulesTag.new()
	body.setup(tier, heading())
	return body


## The tag's body: the count, then each rule in force by number and name, newest first.
class RulesTag extends Control:
	const NUM_W := 12
	var tier := 0
	var head := ""
	var rows: Array[int] = []

	func setup(t: int, h: String) -> void:
		tier = t
		head = h
		rows = Ladder.in_force(t)
		var f := UITheme.pixel_font()
		var w := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		for k in rows:
			w = maxf(w, NUM_W + f.get_string_size(Ladder.rung_name(k), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
		custom_minimum_size = Vector2(ceilf(w), HoloTag.LINE_H * (1 + rows.size()) + (2 if rows.size() > 0 else 0) - 2)
		size = custom_minimum_size

	func _draw() -> void:
		var f := UITheme.pixel_font()
		var y := f.get_ascent(UITheme.FS_SMALL) - 1.0
		draw_string(f, Vector2(0, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, UITheme.ICE)
		y += HoloTag.LINE_H + 2
		for k in rows:
			draw_string(f, Vector2(0, y), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Ladder.colour(k))
			draw_string(f, Vector2(NUM_W, y), Ladder.rung_name(k), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL,
				UITheme.ICE if k == tier else UITheme.CHILL)
			y += HoloTag.LINE_H


## The ten lamps, over the glow: lit in their rule's kind colour up to the tier, the
## current one with a white heart and four glints, the rest dark.
class Lamps extends Control:
	var gal: TierGalaxy

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(G, G)

	func _draw() -> void:
		for k in range(1, 11):
			var r := gal.lamp_rect(k)
			draw_rect(r.grow(1.0), LAMP_RIM)
			if k > gal.tier:
				draw_rect(r, LAMP_OFF)
				continue
			var kc := Ladder.colour(k)
			draw_rect(r, kc)
			if k == gal.tier:
				var p := r.position
				draw_rect(Rect2(p + Vector2(1, 1), Vector2.ONE), Color8(250, 250, 250))
				for d: Vector2 in [Vector2(1, -2), Vector2(1, 4), Vector2(-2, 1), Vector2(4, 1)]:
					draw_rect(Rect2(p + d, Vector2.ONE), PANEL.lerp(kc, 0.5))
