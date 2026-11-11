class_name JumpHull
extends RefCounted

## The hull baked once per look for the jump films: its picture with its fitted parts (a
## fresh ShipView and MountPoints rendered to a SubViewport, so the stand-in is the live
## view pixel for pixel), and what the shaders need worked out from it on the CPU: seams,
## inner distance, a signed distance field round it, up and down facing weights, edges.
## Why: docs/why/JumpHull.md#bake

const PAD := 48
const CACHE_MAX := 4
static var _cache: Dictionary = {}

var key := ""
var size := Vector2i.ZERO
var image: Image = null
var tex: ImageTexture = null
var aux: ImageTexture = null
var aux2: ImageTexture = null
var sdf: ImageTexture = null
var ink := Rect2i()
var centroid := Vector2.ZERO
var d_in_max := 1.0
var ready := false
var _vp: SubViewport = null
var _fresh: ShipView = null
var _frames := 0
var _art: ShipView = null


## The look this bake is of: the hull, whose it is, how worn, and the canvas it draws in.
static func key_for(art: ShipView) -> String:
	var b := art._b()
	var h := b.hull if b != null else null
	return "%s|%s|%s|%d|%dx%d" % [h.resource_path + h.name if h != null else "", b.pilot if b != null else "",
		HullWear.band_for(b.damage()) if b != null else 0, 1 if art.is_half() else 0,
		int(art.canvas_width()), int(art.canvas_height())]


## The bake for this view, started if there is none; `poll` it each frame until ready.
static func of(art: ShipView, host: Node) -> JumpHull:
	var k := key_for(art)
	if _cache.has(k):
		return _cache[k]
	var jh := JumpHull.new()
	jh.key = k
	jh._art = art
	jh._start(host)
	if _cache.size() >= CACHE_MAX:
		_cache.erase(_cache.keys()[0])
	_cache[k] = jh
	return jh


func _start(host: Node) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(_art.size)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fresh = ShipView.new()
	_fresh.setup_build(ShipBuild.local(), 1)
	_fresh.size = _art.size
	_fresh.zoom(1)
	_fresh.bob(2)
	_vp.add_child(_fresh)
	var mounts := MountPoints.new()
	mounts.attach(_fresh)
	mounts.passive()
	_fresh.add_child(mounts)
	_fresh.depart(true)
	host.add_child(_vp)


## Once the viewport has drawn, read it and bake; headless, the CPU canvas stands in.
func poll() -> bool:
	if ready:
		return true
	if _vp == null or not is_instance_valid(_vp):
		return false
	_frames += 1
	if _frames < 3:
		return false
	# (headless the dummy renderer has no texture to read: the CPU canvas stands in)
	var img: Image = null
	if not LocalSky.headless() and _vp.get_texture() != null:
		img = _vp.get_texture().get_image()
	var rect := Rect2i(_fresh.hull_rect())
	if img != null and img.get_width() >= rect.end.x and img.get_height() >= rect.end.y:
		img = img.get_region(rect)
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
	if img == null or img.get_used_rect().size.x == 0:
		img = _fresh.canvas().duplicate() as Image
	_vp.queue_free()
	_vp = null
	_fresh = null
	_bake(img)
	ready = true
	return true


func _bake(img: Image) -> void:
	image = img
	size = Vector2i(img.get_width(), img.get_height())
	tex = ImageTexture.create_from_image(img)
	ink = img.get_used_rect()
	var w := size.x
	var h := size.y
	var n := w * h
	var a := PackedByteArray()
	a.resize(n)
	var hl := PackedFloat32Array()
	hl.resize(n)
	var sx := 0.0
	var sy := 0.0
	var cnt := 0
	var lums := PackedFloat32Array()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var i := y * w + x
			if c.a > 0.0:
				a[i] = 1
				hl[i] = (c.r + c.g + c.b) / 3.0 * 255.0
				lums.append(hl[i])
				sx += x
				sy += y
				cnt += 1
	centroid = Vector2(sx / maxf(cnt, 1.0), sy / maxf(cnt, 1.0))
	lums.sort()
	var lo := lums[int(float(lums.size() - 1) * 0.08)] if cnt > 0 else 0.0
	var hi := lums[int(float(lums.size() - 1) * 0.92)] if cnt > 0 else 255.0
	var er1 := _erode(a, w, h)
	var er2 := _erode(er1, w, h)
	var er4 := _erode(_erode(er2, w, h), w, h)
	var box1 := _box(hl, w, h, 1)
	var soft := _box_bytes(a, w, h, 3)
	var din := _edt(a, w, h, 0, true)
	d_in_max = 1.0
	for i in n:
		d_in_max = maxf(d_in_max, din[i])
	var ih := maxf(float(ink.size.y), 1.0)
	var ax := PackedByteArray()
	ax.resize(n * 4)
	var ax2 := PackedByteArray()
	ax2.resize(n * 4)
	for y in h:
		for x in w:
			var i := y * w + x
			if a[i] == 0:
				continue
			var seam := 1 if (hl[i] < 0.78 * box1[i] and er2[i] == 1) else 0
			var hq := clampf((hl[i] - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
			var b4 := float([0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5][(y % 4) * 4 + x % 4]) / 16.0 + 1.0 / 32.0
			var idx := clampi(int(floor(hq * 4.999 + (b4 - 0.5) * 0.6)), 0, 4)
			ax[i * 4] = 255 * seam
			ax[i * 4 + 1] = clampi(int(roundf(din[i] / 32.0 * 255.0)), 0, 255)
			ax[i * 4 + 2] = mini(idx * 64, 255)
			ax[i * 4 + 3] = 255
			# outward normal from the softened alpha; up and down facing weights as r4.py
			var gx := (soft[_at(x + 1, y, w, h)] - soft[_at(x - 1, y, w, h)]) * 0.5
			var gy := (soft[_at(x, y + 1, w, h)] - soft[_at(x, y - 1, w, h)]) * 0.5
			var nl := sqrt(gx * gx + gy * gy) + 1e-6
			var ny := -gy / nl
			var edge4 := 1.0 if er4[i] == 0 else 0.0
			var yl := float(y - ink.position.y)
			var upf := clampf(-ny, 0.0, 1.0) * (edge4 * 0.8 + 0.2) + clampf((ih * 0.45 - yl) / (ih * 0.45), 0.0, 1.0) * 0.35
			var dnf := clampf(ny, 0.0, 1.0) * (edge4 * 0.8 + 0.2) + clampf((yl - ih * 0.55) / (ih * 0.45), 0.0, 1.0) * 0.35
			ax2[i * 4] = clampi(int(roundf(upf * 255.0)), 0, 255)
			ax2[i * 4 + 1] = clampi(int(roundf(dnf * 255.0)), 0, 255)
			ax2[i * 4 + 2] = 255 if er4[i] == 0 else 0
			ax2[i * 4 + 3] = 255 if er2[i] == 0 else 0
	aux = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, ax))
	aux2 = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, ax2))
	sdf = ImageTexture.create_from_image(_sdf_image(a, w, h))


static func _at(x: int, y: int, w: int, h: int) -> int:
	return clampi(y, 0, h - 1) * w + clampi(x, 0, w - 1)


## Binary erosion by one, 4-connected, as scipy's default structure.
static func _erode(a: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			if a[i] == 1 and x > 0 and y > 0 and x < w - 1 and y < h - 1 \
					and a[i - 1] == 1 and a[i + 1] == 1 and a[i - w] == 1 and a[i + w] == 1:
				o[i] = 1
	return o


## A box mean of radius r with edge clamp (scipy's `mode="nearest"`), separable.
static func _box(f: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var o := PackedFloat32Array()
	o.resize(w * h)
	var k := float(2 * r + 1)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += f[y * w + clampi(x + d, 0, w - 1)]
			tmp[y * w + x] = s / k
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += tmp[clampi(y + d, 0, h - 1) * w + x]
			o[y * w + x] = s / k
	return o


static func _box_bytes(a: PackedByteArray, w: int, h: int, r: int) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(w * h)
	for i in w * h:
		f[i] = float(a[i])
	return _box(f, w, h, r)


## Euclidean distance to the nearest pixel of `a` equal to `target`, with `pad` rows and
## columns of background round the grid (Felzenszwalb and Huttenlocher's two 1D passes).
static func _edt(a: PackedByteArray, w: int, h: int, pad: int, inside: bool) -> PackedFloat32Array:
	var pw := w + 2 * pad
	var ph := h + 2 * pad
	var inf := 1e10
	var f := PackedFloat32Array()
	f.resize(pw * ph)
	for y in ph:
		for x in pw:
			var ix := x - pad
			var iy := y - pad
			var on := ix >= 0 and iy >= 0 and ix < w and iy < h and a[iy * w + ix] == 1
			# the sources: non-ink for a distance into the ink, ink for a distance off it
			f[y * pw + x] = 0.0 if (on != inside) else inf
	var d := PackedFloat32Array()
	d.resize(pw * ph)
	var col := PackedFloat32Array()
	col.resize(maxi(pw, ph))
	var out := PackedFloat32Array()
	out.resize(maxi(pw, ph))
	for x in pw:
		for y in ph:
			col[y] = f[y * pw + x]
		_edt1d(col, ph, out)
		for y in ph:
			d[y * pw + x] = out[y]
	for y in ph:
		for x in pw:
			col[x] = d[y * pw + x]
		_edt1d(col, pw, out)
		for x in pw:
			d[y * pw + x] = sqrt(out[x])
	return d


static func _edt1d(f: PackedFloat32Array, n: int, d: PackedFloat32Array) -> void:
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat32Array()
	z.resize(n + 1)
	var k := 0
	v[0] = 0
	z[0] = -1e20
	z[1] = 1e20
	for q in range(1, n):
		var s := ((f[q] + float(q * q)) - (f[v[k]] + float(v[k] * v[k]))) / float(2 * q - 2 * v[k])
		while s <= z[k]:
			k -= 1
			s = ((f[q] + float(q * q)) - (f[v[k]] + float(v[k] * v[k]))) / float(2 * q - 2 * v[k])
		k += 1
		v[k] = q
		z[k] = s
		z[k + 1] = 1e20
	k = 0
	for q in n:
		while z[k + 1] < float(q):
			k += 1
		var dq := float(q - v[k])
		d[q] = dq * dq + f[v[k]]


## The signed distance round the hull on a grid padded PAD px each side, two bytes a texel:
## (d + 128) / 512 over 0..65535, so the shader reads a quarter of a pixel below -128 .. 384.
func _sdf_image(a: PackedByteArray, w: int, h: int) -> Image:
	var dout := _edt(a, w, h, PAD, false)
	var din := _edt(a, w, h, PAD, true)
	var pw := w + 2 * PAD
	var ph := h + 2 * PAD
	var bytes := PackedByteArray()
	bytes.resize(pw * ph * 4)
	for i in pw * ph:
		var d := dout[i] - din[i]
		var e := int(clampf((d + 128.0) / 512.0, 0.0, 1.0) * 65535.0)
		bytes[i * 4] = e >> 8
		bytes[i * 4 + 1] = e & 255
		bytes[i * 4 + 3] = 255
	return Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, bytes)
