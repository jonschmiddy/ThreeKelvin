class_name FaunaGuard
extends RefCounted

## BLOCK, BRACE AND DAMAGE ON A LIVING CREATURE (Oct 13). Jon, of the Void
## Leviathan in a fight with the plated brace on it: "The void leviathan having
## plating or shield is kinda weird", and "the damage to the void leviathan and
## voidwhale calf should be more organic... not ship damage". The bubble
## (`ShieldFx`), the plates (`BraceFx`) and the hull marks (`ShipHitFx`) are
## machine looks; on the Voidwhale Calf and the Void Leviathan (`wants`)
## `HitLayers` lays these instead, Jon's picks of three ideas each ("block:A
## brace:A damage:A+B+C"). The Custodian is a construct and keeps the ship
## looks ("custodian C"); so does every ship.
##   BLOCK  (`FaunaShield`)  GLOW SKIN: its own outline lit cold, breathing with
##                           it, packets of light running head to tail; a hit
##                           runs a ring of light over the skin; at 0 it gutters
##                           out pixel by pixel.
##   BRACE  (`FaunaBrace`)   HARDENED HIDE: the hide darkens and goes glassy
##                           teal, a rim light along its back and a sheen
##                           crossing it; hits flake patches off.
##   DAMAGE (`FaunaHitFx`)   WOUNDS, BRUISES and SHED scales, rolled per hit;
##                           its lights die and, badly hurt, it trails vapour.
##
## WITH THE BODY, NOT OVER IT. Everything is drawn in the picture's own rest
## space and shown where `FaunaMotion` shows that pixel now: a shader layer
## (`GuardSkin`, `PRELUDE`) maps each pixel through the motion's own column table
## (the swell, the spines' lift, the flippers' sweep), and motes and flakes
## take `FaunaMotion.off_at` at their foot. Damage is baked into the picture the
## motion is cut from, so it moves as the body does for nothing. Steps are the
## motion's (8 a second the Leviathan, 12 the calf), on its own phase, so a
## guard's step and the body's never land a frame apart (flip-backs).
##
## NOTHING ON THE WORDS. `HitLayers.keep` holds the intent words and the
## readout (name, bars, hull, chips) in this layer's space; no mote is drawn and
## no shader pixel lights inside them.

static var enabled := true
## Block's light (the bubble's colour, so block still reads as block).
const BLOCK_COL := Color("#7cd8ff")


static func wants(kind: int) -> bool:
	return enabled and (kind == FaunaMotion.Kind.CALF or kind == FaunaMotion.Kind.LEVIATHAN)


# ======================================================================= THE BODY

## The picture's parts, in canvas pixels, cut once a fight by a throwaway
## `FaunaMotion` (so the spines and lights are the motion's own), and its
## distance fields (chamfer 3-4: 3 a pixel straight, 4 diagonally).
class Body extends RefCounted:
	var kind := 0
	var W := 0
	var H := 0
	var scale := 1.0
	var img: Image
	var ink := PackedByteArray()
	var glow := PackedByteArray()
	var spine := PackedByteArray()
	var fin := PackedByteArray()
	var top := PackedInt32Array()
	var bot := PackedInt32Array()
	var x0 := 0
	var x1 := 0
	var r := Rect2i()
	var dout := PackedInt32Array()
	var din := PackedInt32Array()
	var fps := 8.0
	var cut_ms := 0.0

	func u_of(x: float) -> float:
		return clampf((x - float(x0)) / maxf(1.0, float(x1 - x0)), 0.0, 1.0)

	func on(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < W and y < H and ink[y * W + x] == 1

	func centre() -> Vector2:
		return Vector2(r.get_center())


static func body(img: Image, kind: int, scale: float) -> Body:
	var t0 := Time.get_ticks_usec()
	var b := Body.new()
	var src := img
	if src.get_format() != Image.FORMAT_RGBA8:
		src = img.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	var fm := FaunaMotion.new()
	fm.cut(src, kind, scale)
	b.kind = kind
	b.scale = scale
	b.img = src
	b.W = src.get_width()
	b.H = src.get_height()
	b.ink = fm.m_ink
	b.glow = fm.m_glow
	b.spine = fm.m_spine
	b.fin = fm.m_fin if not fm.m_fin.is_empty() else PackedByteArray()
	if b.fin.size() != b.W * b.H:
		b.fin = PackedByteArray()
		b.fin.resize(b.W * b.H)
	b.fps = fm.fps()
	fm.free()
	b.r = src.get_used_rect()
	b.x0 = b.r.position.x
	b.x1 = b.r.end.x - 1
	b.top.resize(b.W)
	b.bot.resize(b.W)
	for x in b.W:
		var tp := -1
		var bt := -1
		for y in range(b.r.position.y, b.r.end.y):
			if b.ink[y * b.W + x] == 1:
				if tp < 0:
					tp = y
				bt = y
		b.top[x] = tp
		b.bot[x] = bt
	b.dout = _chamfer(b.ink, b.W, b.H, false)
	b.din = _chamfer(b.ink, b.W, b.H, true)
	b.cut_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return b


## Distance to the nearest ink pixel (or, `inside`, to the nearest empty one),
## chamfer 3-4, capped at 60 (20 px).
static func _chamfer(ink: PackedByteArray, W: int, H: int, inside: bool) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(W * H)
	var cap := 60
	for i in W * H:
		var on := ink[i] == 1
		d[i] = 0 if (on != inside) else cap
	for y in H:
		for x in W:
			var i := y * W + x
			var v := d[i]
			if v == 0:
				continue
			if x > 0:
				v = mini(v, d[i - 1] + 3)
			if y > 0:
				v = mini(v, d[i - W] + 3)
				if x > 0:
					v = mini(v, d[i - W - 1] + 4)
				if x < W - 1:
					v = mini(v, d[i - W + 1] + 4)
			d[i] = v
	for y in range(H - 1, -1, -1):
		for x in range(W - 1, -1, -1):
			var i := y * W + x
			var v := d[i]
			if v == 0:
				continue
			if x < W - 1:
				v = mini(v, d[i + 1] + 3)
			if y < H - 1:
				v = mini(v, d[i + W] + 3)
				if x < W - 1:
					v = mini(v, d[i + W + 1] + 4)
				if x > 0:
					v = mini(v, d[i + W - 1] + 4)
			d[i] = v
	return d


# ======================================================================= THE CLOCK

## A guard's held steps, on the motion's own phase when there is one.
class Clock extends RefCounted:
	var fps := 8.0
	var phase := 0.0
	var step := -1

	## The stepped time for a guard at `t` (its own seconds), `fm` its motion.
	func tq(t: float) -> float:
		return floorf((t + phase) * fps + 1e-3) / fps - phase

	func index(t: float) -> int:
		return int(floor((t + phase) * fps + 1e-3))

	func bind(t: float, fm: FaunaMotion) -> void:
		if fm != null and is_instance_valid(fm):
			fps = fm.fps()
			phase = fm.t - t


## The `HitLayers` a guard part sits in.
static func layers_of(n: Node) -> HitLayers:
	var p := n.get_parent()
	return p as HitLayers


static func motion_of(n: Node) -> FaunaMotion:
	var L := layers_of(n)
	if L == null or L.motion == null or not is_instance_valid(L.motion):
		return null
	return L.motion


static func keep_of(n: Node) -> Array:
	var L := layers_of(n)
	return L.keep if L != null else []


## Where the rest-space pixel `p` is shown now (on the body: the motion's swell
## at its column).
static func shown(fm: FaunaMotion, p: Vector2) -> Vector2:
	if fm == null:
		return p
	return p + Vector2(0, fm.off_at(int(p.x), int(p.y)))


static func shown_spine(fm: FaunaMotion, p: Vector2) -> Vector2:
	if fm == null:
		return p
	return p + Vector2(0, fm.spine_off_at(int(p.x)))


static func in_keep(keep: Array, p: Vector2, s: Vector2 = Vector2.ONE) -> bool:
	var r := Rect2(p, s)
	for k in keep:
		if (k as Rect2).intersects(r):
			return true
	return false


## A dot (or a block), unless it would sit on the words.
static func dot(ci: CanvasItem, keep: Array, p: Vector2, c: Color, s: Vector2 = Vector2.ONE) -> bool:
	var q := p.round()
	if in_keep(keep, q, s):
		return false
	ci.draw_rect(Rect2(q, s), c)
	return true


static func lv(c: Color, l: float) -> Color:
	return Color(c.r * l, c.g * l, c.b * l, 1.0)


static func hash01(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


# ======================================================================= THE SKIN

## A layer that shows rest-space pictures (its draws, each a full canvas drawn
## at 0,0) through the motion's column table, with a look's own shader body.
class GuardSkin extends Control:
	var paint: Callable
	var mat: ShaderMaterial
	var body: Body
	var _dummy: Dictionary = {}
	var _bound: FaunaMotion = null
	var _bound_ok := false
	## What the last frame drew from (for the shape-change count).
	var sig := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func make(b: Body, code: String) -> void:
		body = b
		mat = ShaderMaterial.new()
		mat.shader = FaunaGuard.shader(code)
		material = mat
		var empty := Image.create(b.W, b.H, false, Image.FORMAT_RGBA8)
		var et := ImageTexture.create_from_image(empty)
		var par := Image.create(b.W, 2, false, Image.FORMAT_RGBAF)
		_dummy = {body_tex = et, spine_tex = et, fin_tex = et, par_tex = ImageTexture.create_from_image(par),
			fin_piv = Vector4(0, 0, 1, 1), fin_k = Vector2.ZERO, csize = Vector2(b.W, b.H)}
		mat.set_shader_parameter("ink_x", Vector2(b.x0, b.x1))
		_apply(_dummy)

	func _apply(d: Dictionary) -> void:
		for k in ["body_tex", "spine_tex", "fin_tex", "par_tex", "fin_piv", "fin_k", "csize"]:
			mat.set_shader_parameter(k, d[k])

	## Each frame: the motion's table (or none), the step's time, the words.
	func follow(fm: FaunaMotion, ts: float, keep: Array) -> void:
		var d := fm.shader_inputs() if fm != null else {}
		var ok := not d.is_empty()
		if fm != _bound or ok != _bound_ok:
			_bound = fm
			_bound_ok = ok
			_apply(d if ok else _dummy)
		elif ok:
			mat.set_shader_parameter("fin_k", d.fin_k)
		mat.set_shader_parameter("ts", ts)
		var k0 := Vector4.ZERO
		var k1 := Vector4.ZERO
		if keep.size() > 0:
			var r0: Rect2 = keep[0]
			k0 = Vector4(r0.position.x, r0.position.y, r0.end.x, r0.end.y)
		if keep.size() > 1:
			var r1: Rect2 = keep[1]
			k1 = Vector4(r1.position.x, r1.position.y, r1.end.x, r1.end.y)
		mat.set_shader_parameter("keep0", k0)
		mat.set_shader_parameter("keep1", k1)

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


static var _shaders := {}


static func shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## The shared head of every skin shader: `rest_of(p)` is the rest-space pixel
## the motion shows at p (body, spine or flipper, as `FaunaMotion`'s shader
## picks; an empty pixel goes with the body's swell), `kept(p)` whether p is on
## the words, `q8` a level put into eighths on a 4x4 dither, `breath(u)` the
## motion's own swell at u (0 the head, 1 the tail) at the step's time.
const PRELUDE := """
shader_type canvas_item;
render_mode %s;
uniform sampler2D body_tex : filter_nearest;
uniform sampler2D spine_tex : filter_nearest;
uniform sampler2D fin_tex : filter_nearest;
uniform sampler2D par_tex : filter_nearest;
uniform vec2 csize;
uniform vec2 fin_k;
uniform vec4 fin_piv;
uniform vec4 keep0;
uniform vec4 keep1;
uniform float ts;
uniform vec2 ink_x;
varying vec4 md;

const float B4[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	md = COLOR;
}

bool inb(ivec2 p) {
	return p.x >= 0 && p.y >= 0 && p.x < int(csize.x) && p.y < int(csize.y);
}

vec4 at(sampler2D s, ivec2 p) {
	if (!inb(p)) { return vec4(0.0); }
	return texelFetch(s, p, 0);
}

float dith(ivec2 p) {
	return (B4[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
}

float q8(float v, ivec2 p) {
	return floor(clamp(v, 0.0, 2.0) * 8.0 + dith(p)) / 8.0;
}

bool kin(vec4 k, ivec2 p) {
	return k.z > k.x && float(p.x) >= k.x && float(p.x) < k.z && float(p.y) >= k.y && float(p.y) < k.w;
}

bool kept(ivec2 p) {
	return kin(keep0, p) || kin(keep1, p);
}

float bump(float z) {
	return max(0.0, 1.0 - z * z);
}

float uof(float x) {
	return clamp((x - ink_x.x) / max(1.0, ink_x.y - ink_x.x), 0.0, 1.0);
}

float breath(float u) {
	float v = 0.5 - 0.5 * cos(6.2831853 * (ts - u * 0.6) / 3.6);
	return 0.5 - 0.5 * cos(3.14159265 * v);
}

float hsh(float a, float b) {
	return fract(sin(a * 12.9898 + b * 78.233) * 43758.5453);
}

ivec2 rest_of(ivec2 p, out int part) {
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
	ivec2 res = q;
	part = 0;
	ivec2 sc = ivec2(p.x, p.y - int(a.y));
	if (at(spine_tex, sc).a > 0.5) { res = sc; part = 2; }
	if (at(body_tex, q).a > 0.5) { res = q; part = 1; }
	int fy = p.y - int(b.z);
	float lf = clamp((float(fy) - fin_piv.x) / fin_piv.z, 0.0, 1.0);
	float lb = clamp((float(fy) - fin_piv.y) / fin_piv.w, 0.0, 1.0);
	ivec2 c1 = ivec2(p.x - int(round(fin_k.x * lf)), fy);
	ivec2 c2 = ivec2(p.x - int(round(fin_k.y * lb)), fy);
	vec4 f1 = at(fin_tex, c1);
	vec4 f2 = at(fin_tex, c2);
	if (f1.a > 0.75) { res = c1; part = 3; }
	else if (f2.a > 0.25 && f2.a < 0.75) { res = c2; part = 3; }
	return res;
}
"""


## A look's shader: the prelude, then its `fragment`, whose early `return;`s
## (a fragment may not return) become breaks out of a loop run once. TEXTURE
## stays in the fragment: handed to a function, the headless compiler refuses it.
static func skin_code(add: bool, body_code: String) -> String:
	var at := body_code.find("void fragment() {")
	var head := body_code.substr(0, at)
	var fn := body_code.substr(at)
	fn = fn.replace("void fragment() {", "void fragment() {
	do {").replace("return;", "break;")
	var end := fn.rfind("}")
	fn = fn.substr(0, end) + "	} while (false);
}
"
	return (PRELUDE % ("blend_add" if add else "blend_mix")) + head + fn


# ======================================================================= MOTES

## Free motes: a position, a velocity, drag, an age and a life, colours by age.
## Moved on the guard's own steps (positions worked out at the step's time), so
## each is held a whole step.
class Motes extends RefCounted:
	var list: Array = []

	func add(p: Vector2, v: Vector2, life: float, t0: float, ramp: Array, drag: float = 2.0,
			grav: float = 0.0, big: bool = false) -> void:
		list.append({p0 = p, v = v, life = life, t0 = t0, ramp = ramp, drag = drag, grav = grav, big = big})

	func prune(t: float) -> void:
		list = list.filter(func(m: Dictionary) -> bool: return t - float(m.t0) < float(m.life))

	## Where mote `m` is at time `ts` (closed form: drag on the velocity, a
	## steady fall added).
	static func pos(m: Dictionary, ts: float) -> Vector2:
		var a := maxf(0.0, ts - float(m.t0))
		var k := float(m.drag)
		var s := a if k <= 0.0 else (1.0 - exp(-k * a)) / k
		return (m.p0 as Vector2) + (m.v as Vector2) * s + Vector2(0, 0.5 * float(m.grav) * a * a)

	func paint(ci: CanvasItem, keep: Array, ts: float) -> int:
		var h := 0
		for m in list:
			var a := ts - float(m.t0)
			if a < 0.0 or a >= float(m.life):
				continue
			var f := a / float(m.life)
			var ramp: Array = m.ramp
			var c: Color = ramp[mini(ramp.size() - 1, int(f * ramp.size()))]
			var p := pos(m, ts).round()
			var s := Vector2(2, 2) if m.big and f < 0.4 else Vector2.ONE
			if FaunaGuard.dot(ci, keep, p, c, s):
				h = h * 31 + int(p.x) * 7 + int(p.y) * 131 + int(c.r * 255.0)
		return h
