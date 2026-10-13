class_name FaunaMotion
extends Control

## THE THREE THAT ARE NOT SHIPS MOVE ON THEIR OWN (Oct 13). Jon: "The custodian
## and the megafauna should get their own movement animations :) Not
## thrusters." Every ordinary ship burns an engine flame (`ThrusterFx`); The
## Custodian, the Voidwhale Calf and the Void Leviathan move instead. Jon picked
## from three ideas each (fx/fauna-motion's films): "custodian:A leviathan:B
## whale:B", and for the calf "i really like the movement of breathe but the
## lights of glow".
##   - THE CUSTODIAN, BREATH: its octahedra drift apart along the spine and
##     back, a pixel or two each, out of step; its orange pinpoints pulse in a
##     wave that runs along the spine. Charging pulls the pieces in tight, runs
##     two light waves into its heart and fills the heart with the cold charge.
##   - THE LEVIATHAN, BREATHE: the body swells up to two pixels, the belly
##     first, the swell running head to tail with a slow pulse of the belly
##     lights; the flippers drift back with each breath; a ripple lifts the
##     back crystals one after another.
##   - THE CALF, BREATHE'S BODY AND GLOW'S LIGHTS: the same swell and spine
##     ripple, and two packets of light chasing down the belly head to tail.
##   - A creature's strike (`strike`, when its attack is fired): a deep
##     in-breath, the spines bristling; the Leviathan's belly lights flare, the
##     calf's light runs back up to its head and blazes.
##
## THE PICTURE IS NEVER REDRAWN OR TURNED. Rotating pixel art shimmers, and an
## AI animation of a whole picture boils (memory turn-pixel-art-in-whole-pixel-
## steps, animate-image-redraws-the-whole-picture). Each picture is cut ONCE
## (`cut`, safe on a worker thread) into the parts it already has, and only the
## parts move, in whole pixels, on held steps (8 or 12 a second):
##   - THE CUSTODIAN into its octahedra: their apexes are the dips in its top
##     edge and they all sit on one equator (the silver spine), so each is a
##     diamond; a pixel belongs to the biggest diamond holding it (the big ones
##     read as nearer), and each piece is filled in behind its neighbours from
##     its own nearest pixels, so a piece that moves a pixel or two uncovers
##     more of the piece behind it, never a hole. Its pinpoints are the warm
##     pixels sitting in dark glass (too pale for `ShipBreakup._is_glow`), cut
##     into their little star clusters, each riding its piece.
##   - THE CREATURES in one small shader: a medial line per column (a swell
##     parts the body there, the belly half dropping, the back half rising),
##     their spines (the calf's are its thin lines, what a 3x3 opening of the
##     silhouette loses; the Leviathan's are the pale crystal blobs along its
##     back), the Leviathan's two hanging flippers (below a belly line drawn
##     between them), and their lights (`ShipBreakup._is_glow`'s, the pixels its
##     creature deaths dim).
##
## LIGHT IS DRAWN AS LIGHT (memory draw-light-as-light): every glowing pixel is
## the dark body plus its own light added back at a level, and above level 1 it
## gathers a halo, added in 4x4-ordered-dither eighths, on the body only. At
## level 1 with no halo the sum is the picture. The Custodian's charge is
## `EnemyArt._pool` to the dither: the same falloff, colour and strength, at
## the same point, so a full charge here is the charge the still picture has.
##
## REST IS THE STILL PICTURE. `settle()` (`SectorScreen._prebuild_death`, ten-
## odd frames before the breakup is cut) walks every offset back a pixel a
## frame and every light a step a frame; it is at rest in four frames or fewer
## and then draws the still picture itself, which is what the death cuts from.
##
## THE BOB is the slot's 2 px (`EnemySlot.BOB_AMP` / `BOB_HZ`), but taken from
## here (`bob_px`), on the motion's own steps: a bob step one frame and a part's
## step the next put pixels back where they were, one-frame flip-backs of 0.1-
## 0.4 x1e-4 a frame against today's 0.011 (measured on fx/fauna-motion).
##
## HALF SIZE (a pack of three or more draws each ship from its half sheet,
## `EnemyArt.draw_scale`): `pic_scale` 0.5 halves the moves (never under a pixel)
## and the cut's own measures.

enum Kind { CUSTODIAN, CALF, LEVIATHAN }

## The held-step rate, frames a second.
const FPS := {Kind.CUSTODIAN: 8.0, Kind.CALF: 12.0, Kind.LEVIATHAN: 8.0}
const BOB_AMP := 2.0
const BOB_HZ := 0.21
const STRIP := 3
## How long a strike's wind-up holds before it lets go.
const STRIKE_S := 0.6
const COLD := Color("#cfe8f5")
const HEART: Array[Color] = [Color("#eaf6fc"), Color("#ffffff")]

signal came_to_rest

var kind: int = Kind.CALF
var pic_scale := 1.0
## Advance on the real clock. Films set it false and call `advance` per frame.
var auto := true
var t := 0.0
var bob_phase := 0.0
var setup_ms := 0.0
## CPU spent in the last frame's advance and draw, in microseconds.
var cost_us := 0
var rested := false
var ready_to_draw := false

var _img: Image
var _still: ImageTexture
var _W := 0
var _H := 0
var _ink_r := Rect2i()
var _wind_on := false
var _strike_left := 0.0
var _wind := 0.0
var _settling := false
var _last_step := -1
var _light: Control
var _draw_us := 0
var _pic_key := ""


static func kind_of(id: StringName) -> int:
	match id:
		&"custodian":
			return Kind.CUSTODIAN
		&"whale":
			return Kind.CALF
		&"leviathan":
			return Kind.LEVIATHAN
	return -1


## Off, every enemy draws as its still picture (harnesses film TODAY with it).
static var enabled := true


## WHICH PICTURE the slot shows at rest, as far as the motion is concerned: the
## kind, which of its pictures, the wound bands `EnemyArt._draw_sprite` draws
## (a half-hurt scorch, a quarter, the dark under a third) and the size.
static func picture_key(e, hull: int, s: float) -> String:
	var w := float(hull) / float(maxi(1, e.max_hp))
	return "%s|%d|%d%d%d|%d|%.2f" % [e.template.id, e.look, int(w < 0.5), int(w < 0.3), int(w < 0.25),
		int(e.max_hp > 60), s]


## The picture's file name, without its extension.
static func picture_name(e) -> String:
	var files := DB.enemy_sprite_files(e.template.id)
	return String(files[posmod(e.look, files.size())]).get_basename() if not files.is_empty() else ""


## The canvas the slot's art draws for `e` at `hull`, without a wind-up, at
## size `s`: what the motion is cut from. Drawn the art's own way, by a second
## `EnemyArt` (a few ms, on the main thread), so the rest it settles to is the
## art's picture to the pixel.
static func still_canvas(e, hull: int, s: float) -> Image:
	var art := EnemyArt.new()
	art.set("draw_scale", s)
	var ghost := Combat.EnemyState.new()
	ghost.template = e.template
	ghost.max_hp = e.max_hp
	ghost.hp = hull
	ghost.look = e.look
	art.set_enemy(ghost, false, -1, false)
	var img: Image = art.snapshot()
	art.free()
	return img


## Cut `img` (an `EnemyArt` canvas holding the picture, drawn without a wind-up)
## for kind `k`. Touches nothing in the tree: safe on a worker thread.
## `pic_key` is the picture's file name (for `EnemyArt.CORE_AT`, if it has one).
func cut(img: Image, k: int, s: float = 1.0, pic_key: String = "") -> void:
	var t0 := Time.get_ticks_usec()
	kind = k
	pic_scale = s
	_pic_key = pic_key
	_img = img.duplicate()
	if _img.get_format() != Image.FORMAT_RGBA8:
		_img.convert(Image.FORMAT_RGBA8)
	_W = _img.get_width()
	_H = _img.get_height()
	_ink_r = _img.get_used_rect()
	_still = ImageTexture.create_from_image(_img)
	if kind == Kind.CUSTODIAN:
		_cut_custodian()
	else:
		_cut_creature()
	setup_ms = (Time.get_ticks_usec() - t0) / 1000.0


## On the main thread, once cut: the node's own pieces (its light layer, its
## shader), at rest.
func attach() -> void:
	size = Vector2(_W, _H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light = Control.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.size = size
	_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light.draw.connect(_draw_light)
	_light.material = _light_material()
	add_child(_light)
	if kind != Kind.CUSTODIAN:
		_mat = ShaderMaterial.new()
		_mat.shader = _creature_shader()
		for k in _shader_tex:
			_mat.set_shader_parameter(k, _shader_tex[k])
		_mat.set_shader_parameter("csize", Vector2(_W, _H))
		_mat.set_shader_parameter("fin_piv", _fin_piv)
		_mat.set_shader_parameter("fin_k", Vector2.ZERO)
		material = _mat
	t = 0.0
	rested = false
	_settling = false
	_last_step = -1
	ready_to_draw = true
	_tick()


## The still picture this was cut from.
func rest_image() -> Image:
	return _img


## FOR THE TESTS: how far from rest what is shown is -- parts off their place,
## lights off level 1 or haloed, the charge lit -- the deepest swell, and the
## wind-up's ease.
func state() -> Dictionary:
	var off := 0
	var lit := 0
	var swell := 0
	if kind == Kind.CUSTODIAN:
		for p in _pieces:
			off += int(p.off != Vector2i.ZERO)
		for l in _lights:
			lit += int(float(l.lvl) != 1.0 or float(l.hl) != 0.0)
	else:
		for x in _W:
			off += int(_cur[x * 4] != 0 or _cur[x * 4 + 1] != 0)
			swell = maxi(swell, _cur[x * 4 + 2] + _cur[x * 4 + 3])
			off += int(_cur[x * 4 + 2] != 0 or _cur[x * 4 + 3] != 0)
			lit += int(_curl[x * 2] != 1.0 or _curl[x * 2 + 1] != 0.0)
		off += int(_fin_cur != Vector2i.ZERO)
	return {off = off, lit = lit, swell = swell, wind = _wind, pool = _pool_lvl,
		parts = _pieces.size() if kind == Kind.CUSTODIAN else _W, lights = _lights.size() if kind == Kind.CUSTODIAN else _nglow}


func fps() -> float:
	return float(FPS[kind])


## The Custodian's Charging... is up (the slot's telegraph).
func windup(on: bool) -> void:
	_wind_on = on


## A creature's attack is fired: the wind-up, held a moment, then let go.
func strike() -> void:
	_strike_left = STRIKE_S


## The death starts: back to the still picture in four frames or fewer.
func settle() -> void:
	_settling = true


## The slot's bob, on this motion's steps.
func bob_px() -> float:
	var bt := floorf(t * fps() + 1e-3) / fps()
	return roundf(sin((bt + bob_phase) * TAU * BOB_HZ) * BOB_AMP)


func _process(delta: float) -> void:
	if auto and ready_to_draw:
		advance(delta)
	# the hit's flash and the death's hiding are said to the art's own
	# drawing; this stands in for it
	var p := get_parent() as CanvasItem
	if p != null and self_modulate != p.self_modulate:
		self_modulate = p.self_modulate
		if _light != null:
			_light.self_modulate = p.self_modulate


func advance(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	t += dt
	_strike_left = maxf(0.0, _strike_left - dt)
	if rested or not ready_to_draw:
		cost_us = Time.get_ticks_usec() - t0
		return
	var s := int(floor(t * fps() + 1e-3))
	if _settling or s != _last_step:
		_last_step = s
		_tick()
	cost_us = Time.get_ticks_usec() - t0 + _draw_us


## One held step: work out where everything wants to be, then move what is
## shown toward it (a pixel, a light step) -- every frame while settling.
func _tick() -> void:
	var ts := floorf(t * fps() + 1e-3) / fps()
	if not _settling:
		var want := 1.0 if (_wind_on or _strike_left > 0.0) else 0.0
		_wind = move_toward(_wind, want, 2.0 / fps())
	if kind == Kind.CUSTODIAN:
		_tick_custodian(ts)
	else:
		_tick_creature(ts)
	queue_redraw()
	_light.queue_redraw()


static func _q(v: float, n: float) -> float:
	return roundf(v * n) / n


static func _bump(z: float) -> float:
	return maxf(0.0, 1.0 - z * z)


static func _ease01(v: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(v, 0.0, 1.0))


## A move of `px` at full size, at this size: halved, never under one pixel.
func _px(v: float) -> float:
	if v == 0.0:
		return 0.0
	return signf(v) * maxf(1.0, roundf(absf(v) * pic_scale))


func _rest() -> void:
	rested = true
	material = null
	_light.visible = false
	queue_redraw()
	came_to_rest.emit()


# ======================================================================= SHADERS

static var _cshader: Shader
static var _lshader: Shader


static func _creature_shader() -> Shader:
	if _cshader == null:
		_cshader = Shader.new()
		_cshader.code = CREATURE_SHADER
	return _cshader


func _light_material() -> ShaderMaterial:
	if _lshader == null:
		_lshader = Shader.new()
		_lshader.code = LIGHT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _lshader
	return m


## The creatures: per column, where to read the body (a swell parts it at the
## medial line), the spines and the fins from, and how lit the lights are.
const CREATURE_SHADER := """
shader_type canvas_item;
uniform sampler2D body_tex : filter_nearest;
uniform sampler2D spine_tex : filter_nearest;
uniform sampler2D fin_tex : filter_nearest;
uniform sampler2D core_tex : filter_nearest;
uniform sampler2D halo_tex : filter_nearest;
uniform sampler2D par_tex : filter_nearest;
uniform vec2 csize;
uniform vec2 fin_k;
uniform vec4 fin_piv;

const float B4[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec4 at(sampler2D s, ivec2 p) {
	if (p.x < 0 || p.y < 0 || p.x >= int(csize.x) || p.y >= int(csize.y)) { return vec4(0.0); }
	return texelFetch(s, p, 0);
}

void fragment() {
	ivec2 p = ivec2(floor(UV * csize));
	vec4 a = texelFetch(par_tex, ivec2(p.x, 0), 0);
	vec4 b = texelFetch(par_tex, ivec2(p.x, 1), 0);
	int mid = int(b.w);
	int y = p.y - int(a.x);
	int su = int(a.z);
	int sd = int(a.w);
	int sy = y;
	if (y > mid) {
		sy = (y > mid + sd) ? y - sd : mid + 1;
	} else {
		sy = (y <= mid - su) ? y + su : mid;
	}
	ivec2 q = ivec2(p.x, sy);
	vec4 body = at(body_tex, q);
	vec4 outc = vec4(0.0);
	vec4 sp = at(spine_tex, ivec2(p.x, p.y - int(a.y)));
	if (sp.a > 0.5) { outc = vec4(sp.rgb, 1.0); }
	if (body.a > 0.5) {
		vec3 c = body.rgb;
		vec4 core = at(core_tex, q);
		c += core.rgb * core.a * b.x;
		vec4 h = at(halo_tex, q);
		float thr = (B4[(q.y & 3) * 4 + (q.x & 3)] + 0.5) / 16.0;
		float k = floor(h.a * b.y * 8.0 + thr) / 8.0;
		c += h.rgb * k;
		outc = vec4(min(c, vec3(1.0)), 1.0);
	}
	int fy = p.y - int(b.z);
	float lf = clamp((float(fy) - fin_piv.x) / fin_piv.z, 0.0, 1.0);
	float lb = clamp((float(fy) - fin_piv.y) / fin_piv.w, 0.0, 1.0);
	vec4 f1 = at(fin_tex, ivec2(p.x - int(round(fin_k.x * lf)), fy));
	vec4 f2 = at(fin_tex, ivec2(p.x - int(round(fin_k.y * lb)), fy));
	if (f1.a > 0.75) { outc = vec4(f1.rgb, 1.0); }
	else if (f2.a > 0.25 && f2.a < 0.75) { outc = vec4(f2.rgb, 1.0); }
	COLOR = outc;
}
"""


## The Custodian's light layer, added: each texel's colour times how much of it
## (its alpha) times the level (the draw's modulate red), put into eighths by a
## 4x4 dither locked to the canvas -- `EnemyArt._pool`'s own steps.
const LIGHT_SHADER := """
shader_type canvas_item;
render_mode blend_add;
varying vec4 md;
varying vec2 lp;

const float B4[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	md = COLOR;
	lp = VERTEX;
}

void fragment() {
	vec4 tx = texture(TEXTURE, UV);
	ivec2 p = ivec2(floor(lp));
	float thr = (B4[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
	float k = floor(tx.a * md.r * 8.0 + thr) / 8.0;
	COLOR = vec4(tx.rgb * k, 1.0);
}
"""


# ======================================================================= CREATURES

var _x0 := 0
var _x1 := 0
var _mid := PackedInt32Array()
var _cur := PackedInt32Array()      ## shown, 4 per column: body dy, spine dy, su, sd
var _curl := PackedFloat32Array()   ## shown, 2 per column: light level, halo level
var _fin_cur := Vector2i.ZERO
var _fin_piv := Vector4(0, 0, 1, 1)
var _par: Image
var _par_tex: ImageTexture
var _mat: ShaderMaterial
var _body_tex: ImageTexture
var _shader_tex := {}
var _nglow := 0


func _cut_creature() -> void:
	var W := _W
	var H := _H
	var n := W * H
	var r := _ink_r
	_x0 = r.position.x
	_x1 = r.end.x - 1
	var ink := PackedByteArray()
	ink.resize(n)
	var glow := PackedByteArray()
	glow.resize(n)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := _img.get_pixel(x, y)
			if c.a > 0.5:
				ink[y * W + x] = 1
				if ShipBreakup._is_glow(c):
					glow[y * W + x] = 1
	var spine := PackedByteArray()
	spine.resize(n)
	if kind == Kind.CALF:
		# The thin lines: what a 3x3 opening of the silhouette loses.
		var op := _grow(_shrink(ink, r), r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var i := y * W + x
				if ink[i] == 1 and op[i] == 0 and glow[i] == 0:
					spine[i] = 1
	else:
		spine = _crystals(ink, glow, r)
	var fin := PackedByteArray()
	fin.resize(n)
	if kind == Kind.LEVIATHAN:
		fin = _fins(ink, glow, spine, r)
	# Per column: the body's medial line (where a swell parts it).
	_mid.resize(W)
	for x in W:
		var top := -1
		var bot := -1
		for y in range(r.position.y, r.end.y):
			var i := y * W + x
			if ink[i] == 1 and spine[i] == 0 and fin[i] == 0:
				if top < 0:
					top = y
				bot = y
		_mid[x] = (top + bot) / 2 if top >= 0 else H / 2
	# The pictures.
	var body := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var sp := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var fi := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var core := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var halo := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var acc := PackedFloat32Array()
	acc.resize(n)
	var mean := Color(0, 0, 0, 0)
	var ng := 0
	var hr := 3.5 * pic_scale if pic_scale < 1.0 else 3.5
	var hri := int(ceil(hr))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			if ink[i] == 0:
				continue
			var c := _img.get_pixel(x, y)
			if spine[i] == 1:
				sp.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			elif fin[i] > 0:
				fi.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0 if fin[i] == 1 else 0.5))
			elif glow[i] == 1:
				body.set_pixel(x, y, Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, 1.0))
				core.set_pixel(x, y, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, 1.0))
				mean += c
				ng += 1
				for dy in range(-hri, hri + 1):
					for dx in range(-hri, hri + 1):
						var kk := 1.0 - sqrt(float(dx * dx + dy * dy)) / hr
						var xx := x + dx
						var yy := y + dy
						if kk > 0.0 and xx >= 0 and yy >= 0 and xx < W and yy < H:
							acc[yy * W + xx] += kk
			else:
				body.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	_nglow = ng
	if ng > 0:
		mean = mean / float(ng)
	var hc := Color(mean.r, mean.g, mean.b) * 0.5
	var crowd := 3.0 * (pic_scale * pic_scale if pic_scale < 1.0 else 1.0)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			if ink[i] == 1 and spine[i] == 0 and fin[i] == 0 and acc[i] > 0.0:
				halo.set_pixel(x, y, Color(hc.r, hc.g, hc.b, clampf(acc[i] / crowd, 0.0, 1.0)))
	_body_tex = ImageTexture.create_from_image(body)
	_par = Image.create(W, 2, false, Image.FORMAT_RGBAF)
	_par_tex = ImageTexture.create_from_image(_par)
	_shader_tex = {body_tex = _body_tex, spine_tex = ImageTexture.create_from_image(sp),
		fin_tex = ImageTexture.create_from_image(fi), core_tex = ImageTexture.create_from_image(core),
		halo_tex = ImageTexture.create_from_image(halo), par_tex = _par_tex}
	_cur.resize(W * 4)
	_cur.fill(0)
	_curl.resize(W * 2)
	for x in W:
		_curl[x * 2] = 1.0
		_curl[x * 2 + 1] = 0.0
	_fin_cur = Vector2i.ZERO
	_upload()


## 3x3 erosion and dilation of a mask, inside `r` (one pixel past it for the
## dilation).
func _shrink(m: PackedByteArray, r: Rect2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(m.size())
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in range(r.position.x + 1, r.end.x - 1):
			var ok := 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if m[(y + dy) * _W + x + dx] == 0:
						ok = 0
			out[y * _W + x] = ok
	return out


func _grow(m: PackedByteArray, r: Rect2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(m.size())
	for y in range(maxi(1, r.position.y - 1), mini(_H - 1, r.end.y + 1)):
		for x in range(maxi(1, r.position.x - 1), mini(_W - 1, r.end.x + 1)):
			var on := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if m[(y + dy) * _W + x + dx] == 1:
						on = 1
			out[y * _W + x] = on
	return out


## THE LEVIATHAN'S BACK CRYSTALS: blobs of pale blue (bright, blue over red,
## not saturated) that reach its top edge, along the middle 70% of it (its head
## and tail curl catch the same highlight and are not crystals), with the grey
## outline round them.
func _crystals(ink: PackedByteArray, glow: PackedByteArray, r: Rect2i) -> PackedByteArray:
	var W := _W
	var n := W * _H
	var pale := PackedByteArray()
	pale.resize(n)
	var sat := PackedFloat32Array()
	sat.resize(n)
	var val := PackedFloat32Array()
	val.resize(n)
	var top := PackedInt32Array()
	top.resize(W)
	top.fill(1 << 20)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			if ink[i] == 0:
				continue
			top[x] = mini(top[x], y)
			var c := _img.get_pixel(x, y)
			sat[i] = c.s
			val[i] = c.v
			if c.v > 0.62 and c.b > c.r + 0.12 and c.s < 0.55:
				pale[i] = 1
	var keep := PackedByteArray()
	keep.resize(n)
	var seen := PackedByteArray()
	seen.resize(n)
	var span := float(maxi(1, r.size.x - 1))
	var least := maxi(3, int(round(10.0 * pic_scale * pic_scale)))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i0 := y * W + x
			if pale[i0] == 0 or seen[i0] == 1:
				continue
			var comp: Array[int] = [i0]
			seen[i0] = 1
			var k := 0
			var touch := false
			var sx := 0.0
			while k < comp.size():
				var i := comp[k]
				k += 1
				var cx := i % W
				var cy := i / W
				sx += cx
				if cy <= top[cx] + 2:
					touch = true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var xx := cx + dx
						var yy := cy + dy
						if xx < r.position.x or yy < r.position.y or xx >= r.end.x or yy >= r.end.y:
							continue
						var j := yy * W + xx
						if pale[j] == 1 and seen[j] == 0:
							seen[j] = 1
							comp.append(j)
			var u := (sx / comp.size() - r.position.x) / span
			if comp.size() >= least and touch and u > 0.17 and u < 0.86:
				for i2 in comp:
					keep[i2] = 1
	for it in (2 if pic_scale >= 1.0 else 1):
		var add: Array[int] = []
		for y in range(r.position.y + 1, r.end.y - 1):
			for x in range(r.position.x + 1, r.end.x - 1):
				var i := y * W + x
				if ink[i] == 0 or keep[i] == 1 or glow[i] == 1:
					continue
				if not (sat[i] < 0.25 or val[i] > 0.55):
					continue
				var nb := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if keep[(y + dy) * W + x + dx] == 1:
							nb = true
				if nb:
					add.append(i)
		for i3 in add:
			keep[i3] = 1
	return keep


## THE LEVIATHAN'S FLIPPERS: everything hanging below its belly line, which is
## drawn straight between the belly either side of them. The biggest piece
## furthest back is the rear flipper (2); the rest is the front one (1).
func _fins(ink: PackedByteArray, glow: PackedByteArray, spine: PackedByteArray, r: Rect2i) -> PackedByteArray:
	var W := _W
	var out := PackedByteArray()
	out.resize(W * _H)
	var xa := r.position.x + int(0.27 * r.size.x)
	var xb := r.position.x + int(0.66 * r.size.x)
	var bot := func(x: int) -> int:
		for y in range(r.end.y - 1, r.position.y - 1, -1):
			if ink[y * W + x] == 1 and spine[y * W + x] == 0:
				return y
		return r.end.y - 1
	var ya: int = bot.call(xa)
	var yb: int = bot.call(xb)
	for x in range(xa + 1, xb):
		var belly := int(round(lerpf(ya, yb, float(x - xa) / float(xb - xa))))
		for y in range(belly + 2, r.end.y):
			var i := y * W + x
			if ink[i] == 1 and glow[i] == 0 and spine[i] == 0:
				out[i] = 1
	var lab := PackedInt32Array()
	lab.resize(W * _H)
	var comps: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(xa, xb):
			var i0 := y * W + x
			if out[i0] == 0 or lab[i0] != 0:
				continue
			var comp: Array[int] = [i0]
			lab[i0] = comps.size() + 1
			var k := 0
			var sx := 0.0
			while k < comp.size():
				var i := comp[k]
				k += 1
				sx += i % W
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var j := i + dy * W + dx
						if j >= 0 and j < out.size() and out[j] == 1 and lab[j] == 0:
							lab[j] = comps.size() + 1
							comp.append(j)
			comps.append({px = comp, mx = sx / comp.size()})
	comps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.px as Array).size() > (b.px as Array).size())
	var rear := -1
	if comps.size() >= 2:
		rear = 0 if float(comps[0].mx) > float(comps[1].mx) else 1
	var lo := Vector2(1 << 20, 1 << 20)
	var hi := Vector2(-1, -1)
	for ci in comps.size():
		var id := 2 if ci == rear else 1
		for i in comps[ci].px:
			out[i] = id
			var yy := float(int(i) / W)
			if id == 1:
				lo.x = minf(lo.x, yy)
				hi.x = maxf(hi.x, yy)
			else:
				lo.y = minf(lo.y, yy)
				hi.y = maxf(hi.y, yy)
	_fin_piv = Vector4(lo.x, lo.y, maxf(1.0, hi.x - lo.x), maxf(1.0, hi.y - lo.y))
	return out


## What each column wants this step, idle blended toward the wind-up, then the
## shown values moved toward it.
func _tick_creature(ts: float) -> void:
	var W := _W
	var span := float(maxi(1, _x1 - _x0))
	var w := _ease01(_wind)
	var tgt := PackedInt32Array()
	tgt.resize(W * 4)
	var tgl := PackedFloat32Array()
	tgl.resize(W * 2)
	var fk := Vector2.ZERO
	for x in W:
		tgl[x * 2] = 1.0
	if not _settling:
		# worked out once a strip, the same for its columns
		var last := -1
		var sv := PackedFloat32Array()
		sv.resize(6)
		for x in range(_x0, _x1 + 1):
			var sx := _x0 + ((x - _x0) / STRIP) * STRIP + STRIP / 2
			if sx != last:
				last = sx
				var u := clampf(float(sx - _x0) / span, 0.0, 1.0)
				var d := _idle(u, ts)
				var dw: Array = d if w == 0.0 else _windup_at(u, ts)
				for c in 6:
					sv[c] = lerpf(d[c], dw[c], w)
			for c in 4:
				tgt[x * 4 + c] = int(round(sv[c]))
			tgl[x * 2] = _q(sv[4], 8.0)
			tgl[x * 2 + 1] = _q(sv[5], 8.0)
		if kind == Kind.LEVIATHAN:
			var b := _ease01(0.5 - 0.5 * cos(TAU * ts / 3.6))
			fk = Vector2(roundf(b), roundf(b)).lerp(Vector2(-2, -2) * pic_scale, w).round()
	# Move what is shown: a pixel a step, a light three eighths a step; while
	# settling, every frame.
	var moved := false
	for i in tgt.size():
		var v := _cur[i]
		var nv := v + clampi(tgt[i] - v, -1, 1)
		if nv != v:
			moved = true
		_cur[i] = nv
	for i in tgl.size():
		var v2 := _curl[i]
		var nv2 := move_toward(v2, tgl[i], 0.375)
		if nv2 != v2:
			moved = true
		_curl[i] = nv2
	var nf := Vector2i(_fin_cur.x + clampi(int(fk.x) - _fin_cur.x, -1, 1),
		_fin_cur.y + clampi(int(fk.y) - _fin_cur.y, -1, 1))
	if nf != _fin_cur:
		moved = true
	_fin_cur = nf
	if _settling and _at_rest_creature():
		_rest()
		return
	if moved:
		_upload()


func _upload() -> void:
	var W := _W
	var buf := PackedFloat32Array()
	buf.resize(W * 8)
	for x in W:
		var i := x * 4
		buf[i] = _cur[i]
		buf[i + 1] = _cur[i + 1]
		buf[i + 2] = _cur[i + 2]
		buf[i + 3] = _cur[i + 3]
		var j := (W + x) * 4
		buf[j] = _curl[x * 2]
		buf[j + 1] = _curl[x * 2 + 1]
		buf[j + 2] = _cur[i] + _cur[i + 3]
		buf[j + 3] = _mid[x]
	_par.set_data(W, 2, false, Image.FORMAT_RGBAF, buf.to_byte_array())
	_par_tex.update(_par)
	if _mat != null:
		_mat.set_shader_parameter("fin_k", Vector2(_fin_cur))


func _at_rest_creature() -> bool:
	for v in _cur:
		if v != 0:
			return false
	for x in _W:
		if _curl[x * 2] != 1.0 or _curl[x * 2 + 1] != 0.0:
			return false
	return _fin_cur == Vector2i.ZERO


## Idle at u (0 the head, 1 the tail tip): [body dy, spine dy, upper swell,
## lower swell, light, halo]. BREATHE's body for both; the Leviathan breathes
## its lights with it, the calf chases GLOW's packets along them.
func _idle(u: float, ts: float) -> Array:
	var b := _ease01(0.5 - 0.5 * cos(TAU * (ts - u * 0.6) / 3.6))
	var body := 1.0 if u > 0.12 and u < 0.9 else 0.0
	var sd := (1.0 if b > 0.4 else 0.0) * body
	var su := (1.0 if b > 0.8 and pic_scale >= 1.0 else 0.0) * body
	var ripple := fposmod(ts, 2.6) / 1.7 - 0.05
	var sdy := -1.0 if absf(u - ripple) < 0.07 else 0.0
	var l := 0.6 + 0.65 * b
	if kind == Kind.CALF:
		var p := 0.0
		for kk in 2:
			var pos := fposmod(ts / 2.4 + kk * 0.5, 1.0) * 1.5 - 0.25
			p = maxf(p, _bump((u - pos) / 0.13))
		l = 0.4 + 1.1 * p
	var halo := maxf(0.0, l - 1.0) * 1.7 if kind == Kind.CALF else maxf(0.0, b - 0.55) * 1.8
	return [0.0, sdy - su, su, sd, l, halo]


## The strike at u: the deep in-breath (the swell to three pixels, the spines
## bristling); the Leviathan's lights flare, the calf's run back to its head.
func _windup_at(u: float, ts: float) -> Array:
	var body := 1.0 if u > 0.12 and u < 0.9 else 0.0
	var sd := _px(2.0) * body
	var su := 1.0 * body
	var sdy := -_px(2.0) * body
	if kind == Kind.CALF:
		var p := 0.0
		for kk in 3:
			var pos := 1.2 - fposmod(ts / 0.8 + kk / 3.0, 1.0) * 1.5
			p = maxf(p, _bump((u - pos) / 0.12))
		var head := clampf(1.0 - u / 0.22, 0.0, 1.0)
		var l := 0.45 + 1.0 * p + 1.1 * head
		return [0.0, sdy, su, sd, l, maxf(0.0, l - 1.0) * 1.7]
	return [0.0, sdy, su, sd, 1.5, 1.0]


# ======================================================================= CUSTODIAN

var _pieces: Array = []   ## {tex, at, c, hh, dir, ph, off (shown Vector2i)}
var _lights: Array = []   ## {tex, halo, at, piece, x, y, lvl, hl}
var _pool_tex: ImageTexture
var _heart_tex: ImageTexture
var _pool_at := Vector2.ZERO
var _pool_lvl := 0.0
var _core := Vector2.ZERO
var _eq := 0


func _cut_custodian() -> void:
	var W := _W
	var H := _H
	var r := _ink_r
	var n := W * H
	var big := pic_scale >= 1.0
	var ink := PackedByteArray()
	ink.resize(n)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _img.get_pixel(x, y).a > 0.5:
				ink[y * W + x] = 1
	# The top edge and the equator.
	var top := PackedInt32Array()
	top.resize(W)
	var mids: Array[float] = []
	for x in range(r.position.x, r.end.x):
		var t0 := -1
		var b0 := -1
		for y in range(r.position.y, r.end.y):
			if ink[y * W + x] == 1:
				if t0 < 0:
					t0 = y
				b0 = y
		top[x] = t0 if t0 >= 0 else 1 << 20
		if t0 >= 0:
			mids.append((t0 + b0) * 0.5)
	mids.sort()
	_eq = int(round(mids[mids.size() / 2])) if not mids.is_empty() else r.get_center().y
	# The apexes: dips in the top edge, a few pixels deep on both sides.
	var win := 5 if big else 3
	var reach := 14 if big else 7
	var deep := 3 if big else 2
	var apex: Array = []
	for x in range(r.position.x, r.end.x):
		var lo := top[x]
		var ok := true
		for dx in range(-win, win + 1):
			var xx := x + dx
			if xx >= r.position.x and xx < r.end.x and top[xx] < lo:
				ok = false
		if not ok:
			continue
		var l := 0
		var rr := 0
		for dx in range(0, reach + 1):
			if x - dx >= r.position.x:
				l = maxi(l, top[x - dx] - lo)
			if x + dx < r.end.x:
				rr = maxi(rr, top[x + dx] - lo)
		if (l >= deep or x - r.position.x < reach) and (rr >= deep or r.end.x - 1 - x < reach):
			if not apex.is_empty() and x - int(apex[-1].x) <= (4 if big else 2):
				apex[-1] = Vector2i((int(apex[-1].x) + x) / 2, mini(int(apex[-1].y), lo))
			else:
				apex.append(Vector2i(x, lo))
	if apex.is_empty():
		apex.append(Vector2i(r.get_center().x, r.position.y))
	# Each apex is a diamond on the equator.
	var dia: Array = []
	for a: Vector2i in apex:
		var hh := float(maxi(3 if not big else 6, _eq - a.y))
		dia.append({c = Vector2(a.x, _eq), hh = hh, hw = hh * 0.95})
	dia.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.hh) > float(q.hh))
	var np := dia.size()
	var own := PackedInt32Array()
	own.resize(n)
	own.fill(-1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			if ink[i] == 0:
				continue
			var best := -1
			var bd := 1e9
			for k in np:
				var d: Dictionary = dia[k]
				var dd := absf(x - d.c.x) / float(d.hw) + absf(y - d.c.y) / float(d.hh)
				if dd <= 1.04:
					best = k
					break
				if dd < bd:
					bd = dd
					best = k
			own[i] = best
	# The lights: warm pixels sitting in dark glass, and the warm pixels
	# touching them (a pinpoint's bright middle sits in its own flare).
	var light := PackedByteArray()
	light.resize(n)
	var warm := PackedByteArray()
	warm.resize(n)
	var vv := PackedFloat32Array()
	vv.resize(n)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			if ink[i] == 1:
				var c := _img.get_pixel(x, y)
				vv[i] = maxf(c.r, maxf(c.g, c.b))
				if c.r - c.b > 20.0 / 255.0:
					warm[i] = 1
	var nr := 3 if big else 2
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			if warm[i] == 0:
				continue
			var s := 0.0
			var cnt := 0
			for dy in range(-nr, nr + 1):
				for dx in range(-nr, nr + 1):
					var xx := x + dx
					var yy := y + dy
					if xx < 0 or yy < 0 or xx >= W or yy >= H:
						continue
					var j := yy * W + xx
					if ink[j] == 1 and warm[j] == 0:
						s += vv[j]
						cnt += 1
			if cnt == 0 or s / cnt < 110.0 / 255.0:
				light[i] = 1
	for it in (2 if big else 1):
		var add: Array[int] = []
		for y in range(r.position.y + 1, r.end.y - 1):
			for x in range(r.position.x + 1, r.end.x - 1):
				var i := y * W + x
				if warm[i] == 1 and light[i] == 0:
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if light[(y + dy) * W + x + dx] == 1:
								add.append(i)
		for i2 in add:
			light[i2] = 1
	# The pieces: each diamond's own pixels, filled in behind its neighbours
	# from its own nearest pixel (lights dark), back to front.
	var centre := Vector2(r.get_center())
	_pieces.clear()
	for k in range(np - 1, -1, -1):
		var d: Dictionary = dia[k]
		var box := Rect2i(int(d.c.x - d.hw) - 2, int(d.c.y - d.hh) - 2, int(d.hw * 2) + 5, int(d.hh * 2) + 5).intersection(r)
		var im := Image.create(maxi(1, box.size.x), maxi(1, box.size.y), false, Image.FORMAT_RGBA8)
		var front: Array[int] = []
		var need: Dictionary = {}
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				var i := y * W + x
				if ink[i] == 0:
					continue
				var inside := absf(x - d.c.x) / float(d.hw) + absf(y - d.c.y) / float(d.hh) <= 1.0
				if own[i] == k:
					var c := _img.get_pixel(x, y)
					if light[i] == 1:
						c = Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, 1.0)
						need[i] = true
					else:
						front.append(i)
					im.set_pixel(x - box.position.x, y - box.position.y, Color(c.r, c.g, c.b, 1.0))
				elif inside:
					need[i] = true
		var dist := {}
		for i in front:
			dist[i] = i
		var q := front.duplicate()
		var qi := 0
		while qi < q.size():
			var i: int = q[qi]
			qi += 1
			var cx := i % W
			var cy := i / W
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := cx + o.x
				var yy := cy + o.y
				if not box.has_point(Vector2i(xx, yy)):
					continue
				var j := yy * W + xx
				if need.has(j) and not dist.has(j):
					dist[j] = dist[i]
					q.append(j)
					if own[j] != k:
						var src: int = dist[i]
						var c2 := _img.get_pixel(src % W, src / W)
						im.set_pixel(xx - box.position.x, yy - box.position.y, Color(c2.r, c2.g, c2.b, 1.0))
		var dir: Vector2 = (d.c as Vector2) - centre
		dir = dir / maxf(1.0, dir.length()) if dir.length() > 10.0 * pic_scale else Vector2(0, -1)
		_pieces.append({tex = ImageTexture.create_from_image(im), img = im, at = Vector2(box.position),
			c = d.c, hh = d.hh, dir = dir, k = k, off = Vector2i.ZERO})
	var byx: Array = range(_pieces.size())
	byx.sort_custom(func(a: int, b: int) -> bool: return float(_pieces[a].c.x) < float(_pieces[b].c.x))
	for rk in byx.size():
		_pieces[byx[rk]].ph = float(rk) * 2.1
	var by_k := {}
	for pi in _pieces.size():
		by_k[int(_pieces[pi].k)] = pi
	# The light clusters, each its own light and halo, riding its piece.
	var seen := PackedByteArray()
	seen.resize(n)
	_lights.clear()
	var hr := 3.5 if big else 2.5
	var hri := int(ceil(hr))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i0 := y * W + x
			if light[i0] == 0 or seen[i0] == 1:
				continue
			var comp: Array[int] = [i0]
			seen[i0] = 1
			var k2 := 0
			while k2 < comp.size():
				var i := comp[k2]
				k2 += 1
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var j := i + dy * W + dx
						if j >= 0 and j < n and light[j] == 1 and seen[j] == 0:
							seen[j] = 1
							comp.append(j)
			var lo := Vector2i(1 << 20, 1 << 20)
			var hi := Vector2i(-1, -1)
			var sx := 0.0
			var sy := 0.0
			var mean := Color(0, 0, 0)
			var vote := {}
			for i in comp:
				var p := Vector2i(i % W, i / W)
				lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
				hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
				sx += p.x
				sy += p.y
				mean += _img.get_pixel(p.x, p.y)
				vote[own[i]] = int(vote.get(own[i], 0)) + 1
			mean = mean / float(comp.size())
			var pk := -1
			var pv := -1
			for kk in vote:
				if int(vote[kk]) > pv:
					pv = vote[kk]
					pk = kk
			var pidx: int = by_k.get(pk, 0)
			var pad := hri + 1
			var lr := Rect2i(lo - Vector2i(pad, pad), hi - lo + Vector2i(1 + pad * 2, 1 + pad * 2))
			var core := Image.create(lr.size.x, lr.size.y, false, Image.FORMAT_RGBA8)
			var halo := Image.create(lr.size.x, lr.size.y, false, Image.FORMAT_RGBA8)
			var acc := {}
			for i in comp:
				var p2 := Vector2i(i % W, i / W)
				var c := _img.get_pixel(p2.x, p2.y)
				core.set_pixel(p2.x - lr.position.x, p2.y - lr.position.y, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, 1.0))
				for dy in range(-hri, hri + 1):
					for dx in range(-hri, hri + 1):
						var kk2 := 1.0 - sqrt(float(dx * dx + dy * dy)) / hr
						if kk2 > 0.0:
							var q2 := p2 + Vector2i(dx, dy)
							acc[q2] = float(acc.get(q2, 0.0)) + kk2
			var pim: Image = _pieces[pidx].img
			var pat: Vector2 = _pieces[pidx].at
			var warmc := Color("#ffb070")
			var hc := Color(lerpf(mean.r, warmc.r, 0.5), lerpf(mean.g, warmc.g, 0.5), lerpf(mean.b, warmc.b, 0.5)) * 0.55
			for q3: Vector2i in acc:
				var lx := q3.x - int(pat.x)
				var ly := q3.y - int(pat.y)
				if lx < 0 or ly < 0 or lx >= pim.get_width() or ly >= pim.get_height():
					continue
				if pim.get_pixel(lx, ly).a < 0.5:
					continue
				var e := clampf(float(acc[q3]) / (2.5 if big else 1.6), 0.0, 1.0)
				halo.set_pixel(q3.x - lr.position.x, q3.y - lr.position.y, Color(hc.r, hc.g, hc.b, e))
			_lights.append({tex = ImageTexture.create_from_image(core), halo = ImageTexture.create_from_image(halo),
				at = Vector2(lr.position), piece = pidx, x = sx / comp.size(), y = sy / comp.size(),
				lvl = 1.0, hl = 0.0})
	_cut_charge(ink)


## THE CHARGE, as `EnemyArt._windup` lights a "core" wind-up on this picture:
## the same point (`CORE_AT` for a picture that names its heart, else the
## hull's mass, moved onto solid hull), the same `_pool` (its falloff in the
## texture's alpha, COLD[3], strength 1.6 carried by the level) and the same
## white heart.
func _cut_charge(ink: PackedByteArray) -> void:
	var W := _W
	var H := _H
	var r := _ink_r
	var at := Vector2(0.5, 0.5)
	var core_at = (EnemyArt as Script).get_script_constant_map().get("CORE_AT", {})
	if core_at is Dictionary and (core_at as Dictionary).has(_pic_key):
		at = (core_at as Dictionary)[_pic_key]
	else:
		var sx := 0.0
		var sy := 0.0
		var cnt := 0
		for y in range(r.position.y, r.end.y, 2):
			for x in range(r.position.x, r.end.x, 2):
				if ink[y * W + x] == 1:
					sx += x
					sy += y
					cnt += 1
		if cnt > 0:
			at = Vector2((sx / cnt - r.position.x) / maxf(1.0, r.size.x), (sy / cnt - r.position.y) / maxf(1.0, r.size.y))
	_core = Vector2(_on_hull(ink, r, at))
	var pr := clampf(minf(r.size.x, r.size.y) * 0.7, 20.0, 52.0)
	var pri := int(ceil(pr))
	var pim := Image.create(pri * 2 + 1, pri * 2 + 1, false, Image.FORMAT_RGBA8)
	var col: Color = EnemyArt.COLD[3]
	for y in range(-pri, pri + 1):
		for x in range(-pri, pri + 1):
			var g := Vector2i(_core) + Vector2i(x, y)
			if g.x < 0 or g.y < 0 or g.x >= W or g.y >= H or ink[g.y * W + g.x] == 0:
				continue
			var d := Vector2(x, y).length() / pr
			if d >= 1.0:
				continue
			var e := (1.0 - d) * (1.0 - d) * (1.0 + 0.5 * (1.0 - d)) / 1.5
			pim.set_pixel(x + pri, y + pri, Color(col.r, col.g, col.b, e))
	_pool_tex = ImageTexture.create_from_image(pim)
	_pool_at = _core - Vector2(pri, pri)
	var him := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var q := Vector2i(_core) + Vector2i(dx, dy)
			if absi(dx) + absi(dy) <= 2 and q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and ink[q.y * W + q.x] == 1:
				him.set_pixel(dx + 2, dy + 2, HEART[1] if absi(dx) + absi(dy) <= 1 else HEART[0])
	_heart_tex = ImageTexture.create_from_image(him)


## `EnemyArt._on_hull`: a pixel inside the hull near a point of its box, with
## hull all round it (3 px).
func _on_hull(ink: PackedByteArray, box: Rect2i, at: Vector2) -> Vector2i:
	var want := box.position + Vector2i(int(box.size.x * at.x), int(box.size.y * at.y))
	for rad in range(0, 40):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dy)) != rad:
					continue
				var p := want + Vector2i(dx, dy)
				var solid := true
				for yy in range(-3, 4):
					for xx in range(-3, 4):
						var x2 := p.x + xx
						var y2 := p.y + yy
						if x2 < 0 or y2 < 0 or x2 >= _W or y2 >= _H or ink[y2 * _W + x2] == 0:
							solid = false
				if solid:
					return p
	return want


func _tick_custodian(ts: float) -> void:
	var w := _ease01(_wind)
	var moved := false
	for p in _pieces:
		var tgt := Vector2i.ZERO
		if not _settling:
			var b := 0.5 - 0.5 * cos(TAU * ts / 5.0 + float(p.ph))
			var v: Vector2 = (p.dir as Vector2) * _px(2.0) * b
			tgt = Vector2i(v.lerp(-(p.dir as Vector2), w).round())
		var o: Vector2i = p.off
		var no := Vector2i(o.x + clampi(tgt.x - o.x, -1, 1), o.y + clampi(tgt.y - o.y, -1, 1))
		if no != o:
			moved = true
		p.off = no
	var span := float(maxi(1, _ink_r.size.x))
	var cu := (_core.x - _ink_r.position.x) / span
	for l in _lights:
		var u := (float(l.x) - _ink_r.position.x) / span
		var lv := 1.0
		var hl := 0.0
		if not _settling:
			var pos := fposmod(ts / 2.6, 1.0) * 1.5 - 0.25
			var pk := _bump((u - pos) / 0.11)
			var pos2 := fposmod(ts / 0.9, 1.0)
			var pw := maxf(_bump((u - lerpf(0.0, cu, pos2)) / 0.08), _bump((u - lerpf(1.0, cu, pos2)) / 0.08))
			lv = lerpf(0.5 + 0.85 * pk, 0.75 + 0.9 * pw, w)
			hl = maxf(0.0, lv - 0.95) * 1.8
		lv = _q(lv, 8.0)
		hl = _q(hl, 8.0)
		var ol: float = l.lvl
		var oh: float = l.hl
		l.lvl = move_toward(ol, lv, 0.375)
		l.hl = move_toward(oh, hl, 0.375)
		if l.lvl != ol or l.hl != oh:
			moved = true
	var op := _pool_lvl
	_pool_lvl = move_toward(_pool_lvl, 0.0 if _settling else _q(w, 8.0), 0.25)
	if _pool_lvl != op:
		moved = true
	if _settling and _at_rest_custodian():
		_rest()
		return
	if moved:
		queue_redraw()


func _at_rest_custodian() -> bool:
	for p in _pieces:
		if p.off != Vector2i.ZERO:
			return false
	for l in _lights:
		if float(l.lvl) != 1.0 or float(l.hl) != 0.0:
			return false
	return _pool_lvl == 0.0


# ======================================================================= DRAWING

func _draw() -> void:
	if not ready_to_draw:
		return
	var t0 := Time.get_ticks_usec()
	if rested:
		draw_texture(_still, Vector2.ZERO)
	elif kind != Kind.CUSTODIAN:
		draw_texture(_body_tex, Vector2.ZERO)
	else:
		for p in _pieces:
			draw_texture(p.tex, (p.at as Vector2) + Vector2(p.off))
	_draw_us = Time.get_ticks_usec() - t0


## The light layer (added): the pinpoints and their halos riding their pieces,
## and the charge.
func _draw_light() -> void:
	if kind != Kind.CUSTODIAN or rested or not ready_to_draw:
		return
	var t0 := Time.get_ticks_usec()
	for l in _lights:
		var off := Vector2(_pieces[int(l.piece)].off)
		_light.draw_texture(l.tex, (l.at as Vector2) + off, Color(float(l.lvl), 0, 0, 1))
		if float(l.hl) > 0.0:
			_light.draw_texture(l.halo, (l.at as Vector2) + off, Color(float(l.hl), 0, 0, 1))
	if _pool_lvl > 0.0:
		_light.draw_texture(_pool_tex, _pool_at, Color(1.6 * _pool_lvl, 0, 0, 1))
		if _pool_lvl >= 1.0:
			_light.draw_texture(_heart_tex, _core - Vector2(2, 2), Color(1, 0, 0, 1))
	_draw_us += Time.get_ticks_usec() - t0
