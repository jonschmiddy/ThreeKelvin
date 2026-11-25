class_name TarpMark
extends RefCounted

## A manufacturer's emblem stencilled in code on a tarp whose art lacks it (Jon, Nov 24: "The Calyx Biosystems
## logo isn't on these ships"), painted on the cloth as Solari's cross is: the mark colour, shaded by the folds, worn.
## Why: docs/why/TarpMark.md#stencil

## Each stencilled tarp by its file's stem: (centre x, centre y, px a mark unit, tone x the mark colour).
## The units give Solari's cross's 27, 36 and 45 px; Calyx's light mark sits right of the cloth's old smear.
## Probate's light was redrawn (Jon's b1, Nov 24) without its mark; its tone matches the medium's cream.
const AT := {
	"calyx_light": [118, 50, 3, 0.65],
	"calyx_medium": [145, 67, 4, 0.65],
	"calyx_heavy": [154, 81, 5, 0.65],
	"probate_light": [89, 53, 3, 1.3],
}
## The share of a mark's pixels left bare (inside it, along its edge), and the share half faded after those.
const WEAR := 0.08
const WEAR_EDGE := 0.28
const FADE := 0.18
## A pixel is cloth (so painted) within this chroma of the cloth's median round the mark: straps, clips and patches are not.
const CLOTH_CHROMA := 0.06

## Stencilled textures by path and margin: made once a session, not once a visit.
static var _made := {}


## The tarp art at `path` with its stencil when it has one, else the art. `pad` is a wind texture's margin
## round its art (`ShipRoomOld`); the hold field's rows under the art are left alone.
static func texture(path: String, pad: int = 0) -> Texture2D:
	var key := "%s#%d" % [path, pad]
	if _made.has(key):
		return _made[key]
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var stem := path.get_file().get_basename()
	if t != null and AT.has(stem):
		var img := t.get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var art := art_rect(img, pad)
		var span := stamp(img, StringName(stem.get_slice("_", 0)), AT[stem], art)
		if pad > 0:
			_widen_span(img, art, span)
		t = ImageTexture.create_from_image(img)
	_made[key] = t
	return t


## Where the art lies in a tarp texture: all of it, or inside a wind texture's margin and above its hold field.
static func art_rect(img: Image, pad: int) -> Rect2i:
	if pad <= 0:
		return Rect2i(Vector2i.ZERO, img.get_size())
	return Rect2i(pad, 0, img.get_width() - 2 * pad, (img.get_height() - pad - 1) / 2)


## The emblem's pixels (`YardBanner.EMBLEM`'s rects) round `c`, `u` px a mark unit, in art pixels.
static func cells_of(m: StringName, c: Vector2i, u: int) -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}
	for e: Array in YardBanner.EMBLEM.get(m, []):
		var x0 := floori(c.x + float(e[0]) * u + 0.5)
		var y0 := floori(c.y + float(e[1]) * u + 0.5)
		for y in int(float(e[3]) * u):
			for x in int(float(e[2]) * u):
				out[Vector2i(x0 + x, y0 + y)] = true
	return out


## The emblem painted into `art` (a rect of `img`): each cloth pixel under it takes the mark colour x tone x its
## brightness against the cloth's median round the mark; a hash of its place wears it, the same in every copy.
## Returns the painted pixels' (darkest, lightest) brightness.
static func stamp(img: Image, m: StringName, at: Array, art: Rect2i) -> Vector2:
	var span := Vector2(1.0, 0.0)
	var md: ManufacturerData = DB.manufacturers.get(m)
	if md == null:
		return span
	var u := int(at[2])
	var cells := cells_of(m, Vector2i(int(at[0]), int(at[1])), u)
	var ref := _cloth_ref(img, cells, u, art)
	for p: Vector2i in cells:
		if not _paintable(img, p, art, ref):
			continue
		var edge := false
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			edge = edge or not cells.has(p + d)
		var h := wear_hash(p)
		var wear := WEAR_EDGE if edge else WEAR
		if h < wear:
			continue
		var c := img.get_pixelv(art.position + p)
		var k := float(at[3]) * clampf(_lum(c) / maxf(ref.x, 0.004), 0.55, 1.35)
		var paint := Color(minf(md.colour.r * k, 1.0), minf(md.colour.g * k, 1.0), minf(md.colour.b * k, 1.0))
		if h < wear + FADE:
			paint = paint.lerp(c, 0.5)
		img.set_pixelv(art.position + p, paint)
		span = Vector2(minf(span.x, _lum(paint)), maxf(span.y, _lum(paint)))
	return span


## The wind texture's param row holds the cloth's lightest and darkest (the hangar's shader clamps to them):
## widened to take the paint, or a pale mark on a dark cloth would be held down to the cloth's lightest.
static func _widen_span(img: Image, art: Rect2i, span: Vector2) -> void:
	if span.x > span.y:
		return
	var at := Vector2i(0, 2 * art.size.y + art.position.x)
	var c := img.get_pixelv(at)
	img.set_pixelv(at, Color(minf(c.r, span.x), maxf(c.g, span.y), c.b, c.a))


## The cloth round and under the mark: (median brightness, median chroma r, median chroma g) of its opaque pixels.
static func _cloth_ref(img: Image, cells: Dictionary[Vector2i, bool], u: int, art: Rect2i) -> Vector3:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for p: Vector2i in cells:
		lo = lo.min(p)
		hi = hi.max(p)
	var box := Rect2i(lo, hi - lo + Vector2i.ONE).grow(u).intersection(Rect2i(Vector2i.ZERO, art.size))
	var ls := PackedFloat32Array()
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := img.get_pixel(art.position.x + x, art.position.y + y)
			if c.a8 < 255:
				continue
			var ch := _chroma(c)
			ls.append(_lum(c))
			rs.append(ch.x)
			gs.append(ch.y)
	return Vector3(_median(ls), _median(rs), _median(gs))


## Paint lands on the cloth only: opaque with its four neighbours (so never the hem's edge), the cloth's chroma.
static func _paintable(img: Image, p: Vector2i, art: Rect2i, ref: Vector3) -> bool:
	if p.x < 1 or p.y < 1 or p.x >= art.size.x - 1 or p.y >= art.size.y - 1:
		return false
	for d: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if img.get_pixelv(art.position + p + d).a8 < 255:
			return false
	var ch := _chroma(img.get_pixelv(art.position + p))
	return absf(ch.x - ref.y) + absf(ch.y - ref.z) <= CLOTH_CHROMA


## A fixed hash of an art pixel in [0, 1): the stencil's wear, the same on the yard's tarp and the hangar's.
static func wear_hash(p: Vector2i) -> float:
	var h := (p.x * 374761393 + p.y * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65536.0


static func _lum(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0


## (r, g) over the sum, with a floor so the near-black outline does not swing.
static func _chroma(c: Color) -> Vector2:
	var s := c.r + c.g + c.b + 30.0 / 255.0
	return Vector2(c.r / s, c.g / s)


static func _median(v: PackedFloat32Array) -> float:
	if v.is_empty():
		return 0.0
	v.sort()
	return v[v.size() / 2] if v.size() % 2 == 1 else (v[v.size() / 2 - 1] + v[v.size() / 2]) * 0.5
