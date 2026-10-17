extends Node

## THE HULL DAMAGE LOOKS SIDE BY SIDE, AS STILLS (Oct 17), for working on them
## without a fight: each ship's picture taking `HullDamageFilm`'s nine hits in
## each look, the clock stepped 1/30 s, photographed at four moments -- just
## after the first hit, just after the fourth, a second after the sixth, and
## 2.6 s after the last -- as the marks and the light on the plating (no
## sparks or vapour: those are drawn, not baked). Headless.
##   godot --headless --path . -- sheet=HullDamageSheet out=<png>
##       [ships=cutter:0,hulk:0,marauder:2] [looks=0,1,2,3] [scale=1|0.5] [k=2]
## One PNG a ship (`<out>_<ship>.png`), one row a look, today's first. `scale=0.5` uses the half sheets, as
## a pack of three draws them.

const Film := preload("res://scripts/sim/HullDamageFilm.gd")

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	await get_tree().process_frame
	var out := _arg("out", "user://hull_damage_sheet.png")
	var ships := _arg("ships", "cutter:0,hulk:0,marauder:2").split(",")
	var looks := _arg("looks", "0,1,2,3").split(",")
	var half := float(_arg("scale", "1")) < 1.0
	var zoom := int(_arg("k", "2"))
	for s in ships:
		var parts := (s as String).split(":")
		var tex := DB.enemy_sprite(StringName(parts[0]), int(parts[1]) if parts.size() > 1 else 0, half)
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		# room round it, as the fight's canvas has
		var pic := Image.create(img.get_width() + 16, img.get_height() + 16, false, Image.FORMAT_RGBA8)
		pic.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(8, 8))
		var rows: Array[Image] = []
		for l in looks:
			var t0 := Time.get_ticks_msec()
			rows.append(_row(pic, int(l), 0.5 if half else 1.0))
			print("hulldamagesheet: %s look %s %d ms" % [s, l, Time.get_ticks_msec() - t0])
		var rh := rows[0].get_height() * zoom
		var sheet := Image.create(rows[0].get_width() * zoom, rows.size() * rh, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.04, 0.05, 0.08))
		for j in rows.size():
			var r := rows[j]
			r.resize(r.get_width() * zoom, r.get_height() * zoom, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), Vector2i(0, j * rh))
		var path := out.get_basename() + "_" + (s as String).replace(":", "") + ".png"
		sheet.save_png(path)
		print("hulldamagesheet: wrote %s" % path)
	get_tree().quit()


## One look on one picture: the four moments in a row.
func _row(pic: Image, look: int, scale: float) -> Image:
	ShipHitFx.look = look
	var h: ShipHitFx
	if look > 0:
		var hh := HullHitFx.new()
		hh.style = look
		h = hh
	else:
		h = ShipHitFx.new()
	h.auto = false
	h.mark_scale = scale
	add_child(h)
	h.setup(pic, pic.get_used_rect(), Vector2.ZERO, 4242, -1)
	if _arg("debug") == "1" and h is HullHitFx:
		var hx := h as HullHitFx
		var p0 := Vector2i(int(float(hx._H.cx)), int(float(hx._H.cy)))
		print("debug: p0 %s ok %s pal %d mask %d lum %.2f" % [p0, hx._ok(p0.x, p0.y), hx._pal.size(), hx._mask[p0.y * hx._w + p0.x], hx._lum[p0.y * hx._w + p0.x]])
		var before := hx.version
		var c0 := hx._col[p0.y * hx._w + p0.x]
		hx._tone(p0.y * hx._w + p0.x, 0.42)
		print("debug: tone 0.42 version %d -> %d, %s -> %s, snap %s" % [before, hx.version, c0, hx._col[p0.y * hx._w + p0.x], hx._snap(c0 * 0.42)])
		before = hx.version
		hx._soot(p0, true)
		print("debug: soot version %d -> %d" % [before, hx.version])
	if _arg("stamp") != "" and h is HullHitFx:
		# each kind alone at the points given, the hull 4x round each
		var hx2 := h as HullHitFx
		var pi0 := 12 * hx2._w + 128
		var o0 := hx2._orig[pi0]
		print("debug: orig %s ok %s snap55 %s snap55c %s pal %d" % [o0, hx2._ok(128, 12), hx2._snap(o0 * 0.55), hx2._snap(Color(o0.r * 0.55, o0.g * 0.52, o0.b * 0.47), true), hx2._pal.size()])
		var pl := []
		for c in hx2._pal:
			pl.append(c.to_html(false))
		print("debug: pal ", " ".join(pl))
		hx2._tone(pi0, 0.5)
		print("debug: after tone %s" % hx2._col[pi0])
		var pts := _arg("stamp").split(";")
		var nk := 5 if look == 1 else 3
		var tiles: Array[Image] = []
		for kk in nk:
			for ps in pts:
				var xy := (ps as String).split(",")
				var hh := HullHitFx.new()
				hh.style = look
				hh.auto = false
				hh.mark_scale = scale
				add_child(hh)
				hh.setup(pic, pic.get_used_rect(), Vector2.ZERO, 4242 + kk, -1)
				var pp := Vector2i(int(xy[0]), int(xy[1]))
				if kk == 4:
					pp = hh._pick(true, 6.0)
				hh._one(kk, pp, 0.16, true)
				var im := _snap(pic, hh)
				var c := Rect2i(hh.marks_at() + pp - Vector2i(24, 14), Vector2i(48, 28))
				var tile := im.get_region(c)
				tile.resize(192, 112, Image.INTERPOLATE_NEAREST)
				tiles.append(tile)
				hh.free()
		var sheet := Image.create(192 * pts.size(), 112 * nk, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.04, 0.05, 0.08))
		for j in tiles.size():
			sheet.blend_rect(tiles[j], Rect2i(0, 0, 192, 112), Vector2i((j % pts.size()) * 192, (j / pts.size()) * 112))
		sheet.save_png(_arg("out").get_basename() + "_stamp%d.png" % look)
	var shots := Film.SHOTS
	var hp := 100
	var snaps: Array[Image] = []
	var at := {0: 0.15, 3: 0.15, 5: 1.0, 8: 2.6}
	for i in shots.size():
		hp -= shots[i]
		var v0 := h.version
		var m0 := h._marks.size()
		h.hit(shots[i], hp, 100)
		if _arg("debug") == "1":
			var ps := []
			for mk in h._marks.slice(m0):
				ps.append("(%d,%d)" % [int(mk.p.x), int(mk.p.y)])
			print("debug: hit %d %s at %s px changed %d" % [i, h.rolled[h.rolled.size() - 1], " ".join(ps), h.version - v0])
		var held := float(at.get(i, Film.GAP))
		var tt := 0.0
		while tt < held - 0.001:
			h.advance(1.0 / 30.0)
			tt += 1.0 / 30.0
		if at.has(i):
			snaps.append(_snap(pic, h))
		if i < shots.size() - 1:
			while tt < Film.GAP - 0.001:
				h.advance(1.0 / 30.0)
				tt += 1.0 / 30.0
	var dark := 0
	var light := 0
	var same := 0
	var m := h.marks()
	for i in h._w * h._h:
		var c := m.get_pixel(i % h._w, i / h._w)
		if c.a <= 0.0:
			continue
		var dl := c.get_luminance() - h._orig[i].get_luminance()
		if dl < -0.05:
			dark += 1
		elif dl > 0.05:
			light += 1
		else:
			same += 1
	if _arg("debug") == "1":
		var mm := m.duplicate() as Image
		mm.resize(mm.get_width() * 4, mm.get_height() * 4, Image.INTERPOLATE_NEAREST)
		mm.save_png(_arg("out").get_basename() + "_marks%d.png" % look)
	print("hulldamagesheet: look %d marks %d darker, %d lighter, %d about the same" % [look, dark, light, same])
	h.queue_free()
	var w := pic.get_width()
	var row := Image.create(w * snaps.size(), pic.get_height(), false, Image.FORMAT_RGBA8)
	row.fill(Color(0.04, 0.05, 0.08))
	for k in snaps.size():
		row.blend_rect(snaps[k], Rect2i(Vector2i.ZERO, snaps[k].get_size()), Vector2i(k * w, 0))
	return row


func _snap(pic: Image, h: ShipHitFx) -> Image:
	var im := pic.duplicate() as Image
	im.blend_rect(h.marks(), Rect2i(Vector2i.ZERO, h.marks().get_size()), h.marks_at())
	if h is HullHitFx:
		var g: Image = (h as HullHitFx)._glow
		im.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), h.marks_at())
	return im
