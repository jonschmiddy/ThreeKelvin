class_name LegacyHole
extends RefCounted

## THE BLACK HOLE IN THE LEGACY STYLE, the CPU half of
## `legacy_hole.gdshaderinc` (read its header for the interface): direction C's
## hole from the Oct 5 showcase, Jon's pick for every style, on the star chart's
## core and the sector map's core system.
##
## The photon table is traced ONCE, here, and kept for the process: for each
## impact parameter b (Schwarzschild radius 1) the orbit u'' = -u + 1.5 u^2
## (u = 1/r) is integrated over the path angle, RK4, and the table keeps u at
## every angle and, for a ray that escapes, how far it was bent. It depends on
## nothing but the physics, so it is the same for every galaxy and every system.
## Traced in GDScript it takes about a second, so it is shipped (`TABLE_PATH`,
## written by `-- sheet=LegacyLensBake`) and only traced here when that file is
## missing.
##
## A material that includes the hole gets everything it needs from `apply`.

const BMAX := 24.0
const PMAX := 2.6 * PI
const POW := 1.6
const NB := 320
const NP := 640
const SHADOW := 2.5980762
const TABLE_PATH := "res://art/sky/legacy_lens.res"

## The disc's colours, darkest first: cream, then amber, then orange, then
## red-brown, as Jon picked them. sRGB here; the shader is handed them linear.
const PALETTE: Array[Color] = [Color("#1e0804"), Color("#4a1406"), Color("#84280c"),
	Color("#c24a14"), Color("#ec7a26"), Color("#ffb054"), Color("#ffdc96"), Color("#fff6e2")]

static var _tex: Texture2D = null


## The table as a texture: loaded once a process, traced if it was never baked.
static func lens_texture() -> Texture2D:
	if _tex != null:
		return _tex
	var img: Image = null
	if ResourceLoader.exists(TABLE_PATH):
		img = load(TABLE_PATH) as Image
	if img == null:
		push_warning("LegacyHole: %s missing, tracing the photon table now (bake it with -- sheet=LegacyLensBake)" % TABLE_PATH)
		img = trace_table()
	_tex = ImageTexture.create_from_image(img)
	return _tex


## Everything `legacy_hole.gdshaderinc` reads, onto a material.
static func apply(m: ShaderMaterial, tilt: float = 0.38) -> void:
	m.set_shader_parameter("lh_lens", lens_texture())
	m.set_shader_parameter("lh_dims", Vector3(BMAX, PMAX, POW))
	m.set_shader_parameter("lh_pal", palette_linear())
	m.set_shader_parameter("lh_tilt", tilt)


static func palette_linear() -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in PALETTE:
		var l := c.srgb_to_linear()
		out.append(Vector3(l.r, l.g, l.b))
	return out


## The photon table: NB columns of impact parameter (power-spaced to BMAX), NP
## rows of path angle (0 to PMAX). R = u = 1/r along the path (1.5 once the ray
## has fallen in, 0 once it has escaped), G = the deflection of a ray that
## escapes (3.0 for one that fell in).
static func trace_table() -> Image:
	var data := PackedFloat32Array()
	data.resize(NB * NP * 2)
	var dph := PMAX / float(NP - 1)
	var sub := 6
	var h := dph / float(sub)
	for i in NB:
		var b := maxf(0.02, BMAX * pow(float(i) / float(NB - 1), POW))
		var u := 0.0
		var w := 1.0 / b
		var state := 0
		var defl := PMAX - PI
		for j in NP:
			data[(j * NB + i) * 2] = 1.5 if state == 1 else (0.0 if state == 2 else u)
			if state != 0:
				continue
			for s in sub:
				var k1u := w
				var k1w := -u + 1.5 * u * u
				var u2 := u + 0.5 * h * k1u
				var k2u := w + 0.5 * h * k1w
				var k2w := -u2 + 1.5 * u2 * u2
				var u3 := u + 0.5 * h * k2u
				var k3u := w + 0.5 * h * k2w
				var k3w := -u3 + 1.5 * u3 * u3
				var u4 := u + h * k3u
				var k4u := w + h * k3w
				var k4w := -u4 + 1.5 * u4 * u4
				var un := u + h / 6.0 * (k1u + 2.0 * k2u + 2.0 * k3u + k4u)
				var wn := w + h / 6.0 * (k1w + 2.0 * k2w + 2.0 * k3w + k4w)
				var ph_now := float(j) * dph + float(s + 1) * h
				if un >= 1.0:
					state = 1
					u = 1.5
					break
				if un <= 0.0 and ph_now > 0.5:
					var fr := u / (u - un)
					defl = ph_now - h + fr * h - PI
					state = 2
					u = 0.0
					break
				u = un
				w = wn
		var g := 3.0 if state == 1 else defl
		for j in NP:
			data[(j * NB + i) * 2 + 1] = g
	return Image.create_from_data(NB, NP, false, Image.FORMAT_RGF, data.to_byte_array())


## The CPU copy of the include's `lh_hash`: lowbias32 on two inputs, [0, 1).
## Every event clock (the chart's supernovae, blooms, lightning) draws from it.
static func hash01(n: int, s: int) -> float:
	var x := _imul(n & 0xffffffff, 2654435761) ^ _imul((s + 1663821227) & 0xffffffff, 2246822507)
	x ^= x >> 16
	x = _imul(x, 2146121005)
	x ^= x >> 15
	x = _imul(x, 2221713035)
	x ^= x >> 16
	return float(x >> 8) / 16777216.0


## 32-bit multiply, wrapped, without leaning on 64-bit overflow.
static func _imul(a: int, b: int) -> int:
	var lo := (a * (b & 0xffff)) & 0xffffffff
	var hi := ((a * (b >> 16)) & 0xffff) << 16
	return (lo + hi) & 0xffffffff
