class_name YardClothMesh
extends RefCounted

## The banners' meshes and pictures for the GPU (`YardCloth`): one vertex a cloth node, its place read from
## the state texture; the cloths' atlas and each row's field colour; the room's lights as uniforms.
## Why: docs/why/YardBanner.md#pixels

const NX := YardCloth.NX
const NY := YardCloth.NY
const CW := YardBanner.BW
const CH := YardBanner.CLOTH

## Cloths made in their material, by cloth key (built once a session).
static var _made := {}


## The atlas of the hall's cloths (48 px a banner; alpha 255 cloth, 128 a painted mark, 192 an accent
## thread, 0 none) and, beside it, each pixel's field colour (the rims' colour).
static func atlas(banners: Array[YardBanner], n: int) -> Array[ImageTexture]:
	var img := Image.create(CW * 7, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fld := Image.create(CW * 7, CH, false, Image.FORMAT_RGBA8)
	fld.fill(Color(0, 0, 0, 1))
	for b in n:
		var m := made(banners[b])
		var d := m.data.get_data()
		for y in CH:
			for x in CW:
				var t := y * CW + x
				if d[t * 4 + 3] == 0:
					continue
				var a := YardClothTex.A_INK if m.ink[t] != 0 else (YardClothTex.A_GOLD if m.gold[t] != 0 else YardClothTex.A_CLOTH)
				img.set_pixel(b * CW + x, y, Color8(d[t * 4], d[t * 4 + 1], d[t * 4 + 2], a))
				fld.set_pixel(b * CW + x, y, Color8(m.field[t * 3], m.field[t * 3 + 1], m.field[t * 3 + 2]))
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(fld)]


## A banner's cloth in its material, made once a session.
static func made(bn: YardBanner) -> YardClothTex.Made:
	var key := YardBanner.cloth_key(bn.manufacturer, bn.open)
	if not _made.has(key):
		_made[key] = YardClothTex.make(bn.cloth, key)
	return _made[key]


## Every banner's grid as triangles (the page's eachTri), UV = (i, j + 25 b) naming the node.
static func cloth_3d(bx: PackedFloat32Array, n: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for b in n:
		for j in NY:
			for i in NX:
				verts.append(Vector3(bx[b] + i * 4.0, -(38.0 + j * 100.0 / 24.0), 0.0))
				uvs.append(Vector2(i, j + NY * b))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_INDEX] = _tris(n)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.custom_aabb = AABB(Vector3(-200, -600, -200), Vector3(1400, 800, 400))
	return m


static func _tris(n: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for b in n:
		for j in NY - 1:
			for i in NX - 1:
				var p := b * NX * NY + j * NX + i
				idx.append_array([p, p + 1, p + NX, p + 1, p + NX + 1, p + NX])
	return idx


static func cloth_2d(n: int) -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for b in n:
		for j in NY:
			for i in NX:
				verts.append(Vector2(126 + 112 * b + i * 4.0, 38.0 + j * 100.0 / 24.0))
				uvs.append(Vector2(i, j + NY * b))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_INDEX] = _tris(n)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## The rig's pixels as one quad each (UV = (1000 b + pixel, corner)): part 2 the two chains (16 rows each),
## part 1 the rod (56 x 4, its bent ends a row lower and three deep).
static func rig_2d(n: int, part: int) -> ArrayMesh:
	var ids := PackedInt32Array()
	if part == 2:
		for k in 32:
			ids.append(k)
	else:
		for xo in 56:
			for r in 4:
				if not ((xo <= 2 or xo >= 53) and r == 3):
					ids.append(xo * 4 + r)
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in n:
		for id in ids:
			var p := verts.size()
			for c in 4:
				verts.append(Vector2(126 + 112 * b + (c & 1), 30 + (c >> 1)))
				uvs.append(Vector2(1000 * b + id, c))
			idx.append_array([p, p + 1, p + 2, p + 1, p + 3, p + 2])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## The room's lights into the cloth's, the rims' and the wall's uniforms (the flicker goes in each frame).
static func light_uniforms(r: YardClothLight.Room, lit: ShaderMaterial, show: ShaderMaterial,
		wall: Array[ShaderMaterial], n: int) -> void:
	var lp := PackedVector4Array()
	var lc := PackedVector4Array()
	var lk := PackedVector4Array()
	var rp := PackedVector4Array()
	var rk := PackedVector2Array()
	for L in r.lights:
		lp.append(Vector4(L.p.x, L.p.y, L.p.z, 1.0 if L.point else 0.0))
		lc.append(Vector4(L.col.x, L.col.y, L.col.z, L.pw))
		lk.append(Vector4(L.wrap, L.trans, L.ir2, 1.0 if L.spec else 0.0))
		if L.rim > 0.0:
			rp.append(Vector4(L.p.x, L.p.y, L.p.z, 1.0 if L.point else 0.0))
			rk.append(Vector2(L.ir2, 1.0 if L.point and L.p.z < 0.0 else 0.0))
	lp.resize(16)
	lc.resize(16)
	lk.resize(16)
	rp.resize(8)
	rk.resize(8)
	lit.set_shader_parameter(&"nl", r.lights.size())
	lit.set_shader_parameter(&"lp", lp)
	lit.set_shader_parameter(&"lc", lc)
	lit.set_shader_parameter(&"lk", lk)
	lit.set_shader_parameter(&"amb", r.amb)
	lit.set_shader_parameter(&"expo", r.expo)
	var rig := PackedVector3Array(r.rig)
	rig.resize(7)
	show.set_shader_parameter(&"nr", _rims(r))
	show.set_shader_parameter(&"rp", rp)
	show.set_shader_parameter(&"rk", rk)
	show.set_shader_parameter(&"rig", rig)
	show.set_shader_parameter(&"expo", r.expo)
	var sl := PackedVector4Array()
	var ss := PackedFloat32Array()
	sl.resize(7)
	ss.resize(7)
	for b in n:
		var L: YardClothLight.Light = r.sh[b]
		if L != null:
			sl[b] = Vector4(L.p.x, L.p.y, L.p.z, 1.0 if L.point else 0.0)
			ss[b] = roundf(r.sh_s[b] * 255.0)
	for m in wall:
		m.set_shader_parameter(&"sl", sl)
		m.set_shader_parameter(&"ss", ss)


static func _rims(r: YardClothLight.Room) -> int:
	var k := 0
	for L in r.lights:
		if L.rim > 0.0:
			k += 1
	return mini(k, 8)
