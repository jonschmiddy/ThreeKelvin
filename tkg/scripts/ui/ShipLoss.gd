class_name ShipLoss
extends RefCounted

## A PLAYER'S SHIP COMING APART (Jon, Oct 13): "When you die... let's have your
## ship crack and explode... pause for a beat... then the run ended popup shows
## up."
##
## The same `ShipBreakup` the enemies die in, cut from your own hull's picture
## as `ShipView` paints it (the full sheet in the fight, the half sheet in a
## convoy slot) with the parts bolted to it laid in, so a turret does not hang
## in space over the wreck. Nothing else of the screen: not the stars, not the
## plate, not the HUD.
##
## THE BOSS-LENGTH VERSION, always: the losing ship gets the prelude of bursts a
## boss does, because it is the last thing this run shows.
##
## FACING. `ShipBreakup` reads a ship as facing LEFT, as every enemy does: the
## stern is the right-hand end (`_engines`), and OVERLOAD blows the back off
## from there. Your ship faces right. So the picture is mirrored before it is
## cut and the breakup is drawn mirrored back (`scale.x` negative): the engines
## it finds are your engines, and every pixel of the wreck lands where it was
## drawn.
##
## STYLE AND CUT are positional, as an enemy's are (`EnemyArt.death_style`):
## from the system and the ship, so a seeded run loses the same way twice and a
## partner's ship comes apart the same way on every screen in the party.

## Rolled from the ships' pool, never the creatures'.
static func style_for(node_index: int, who: int) -> int:
	var r := Rng.derive(&"ship_lost", node_index * 1024 + posmod(who, 1024))
	return EnemyArt.SHIP_STYLES[r.randi() % EnemyArt.SHIP_STYLES.size()]


static func seed_for(node_index: int, who: int) -> int:
	var r := Rng.derive(&"ship_lost_cut", node_index * 1024 + posmod(who, 1024))
	return int(r.randi() & 0x7fffffff)


## Where the canvas's top-left pixel sits in `v`, at rest. The same arithmetic
## as `ShipView.canvas_to_local`, without the bob: the bob is already inside the
## canvas, where the hull was pasted.
static func canvas_origin(v: ShipView) -> Vector2:
	return ((v.size - Vector2(v.canvas_width(), v.canvas_height())) * 0.5).floor()


## The picture a breakup cuts, taken NOW (on the main thread): the canvas, the
## parts laid in, the procedural fallback's background stars taken out.
## {img, used, bob, k}, or {} when there is no ship to cut.
static func picture(v: ShipView) -> Dictionary:
	if v == null or v.canvas() == null:
		return {}
	var img := v.canvas().duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var k := maxi(1, v.zoom_level())
	var lo := canvas_origin(v)
	for c in v.get_children():
		if c is MountPoints:
			_lay_parts(img, c as MountPoints, lo, float(k))
	# The coded fallback scatters thirty single-pixel stars over its canvas;
	# a sprite hull has none, and a sprite's ink is never a lone pixel.
	var h: HullData = v._hull()
	if h != null and h.sprite == null:
		_drop_lone_pixels(img)
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return {}
	return {img = img, used = used, bob = v.bob_offset(), k = k}


## Every fitted part with a sprite, into the canvas where `MountPoints` draws it
## (`ModuleIcon.draw_sprite`'s placement: centred on its box, stood on end
## anticlockwise when the hull turned it, mirrored about the box's middle row).
## A part with no sprite is a coded silhouette and stays out: it goes with the
## hull, a frame early.
static func _lay_parts(img: Image, mp: MountPoints, lo: Vector2, k: float) -> void:
	# Placed against the hull as it is drawn this frame (the bob moves both).
	mp.refresh()
	var mag := mp._mag()
	var s := maxi(1, int(roundf(mag)))
	for spot: Dictionary in mp.spots():
		var m: ModuleData = spot.held
		# (only what the hull showed: a picture of the ship carries its guns
		# alone, `MountPoints.weapons_only`)
		if not mp.shows(m) or m.sprite == null:
			continue
		var src := m.sprite.get_image()
		if src == null:
			continue
		src = src.duplicate() as Image
		if src.is_compressed():
			src.decompress()
		if src.get_format() != Image.FORMAT_RGBA8:
			src.convert(Image.FORMAT_RGBA8)
		if s > 1:
			src.resize(src.get_width() * s, src.get_height() * s, Image.INTERPOLATE_NEAREST)
		var f := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
		var box := mp.part_rect(m, spot.slot, spot.at, mag)
		var cy := box.get_center().y
		var dst := Vector2(src.get_size())
		var at: Vector2
		if ModuleIcon.sprite_turn(m.sprite, f):
			var c := box.get_center().round()
			var o := (-dst * 0.5).round()
			src.rotate_90(COUNTERCLOCKWISE)
			at = Vector2(c.x + o.y, c.y - o.x - dst.x)
			dst = Vector2(dst.y, dst.x)
		else:
			at = (box.position + (box.size - dst) * 0.5).round()
		if m.flipped:
			src.flip_y()
			at.y = cy * 2.0 - (at.y + dst.y)
		var p := ((at - lo) / k).round()
		img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(p))


static func _drop_lone_pixels(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var a := PackedByteArray()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = 1 if img.get_pixel(x, y).a > 0.0 else 0
	for y in h:
		for x in w:
			if a[y * w + x] == 0:
				continue
			var n := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var xx: int = x + dx
					var yy: int = y + dy
					if (dx != 0 or dy != 0) and xx >= 0 and yy >= 0 and xx < w and yy < h:
						n += a[yy * w + xx]
			if n == 0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## Cut the picture on a worker thread, mirrored (see FACING), boss length.
## {task, held, pic}; `play` picks it up.
static func prebuild(pic: Dictionary, style: int, seed: int) -> Dictionary:
	var img := (pic.img as Image).duplicate() as Image
	img.flip_x()
	var u: Rect2i = pic.used
	var used := Rect2i(img.get_width() - u.end.x, u.position.y, u.size.x, u.size.y)
	var held := {b = null}
	# the node here, the cut on the worker, `finish` in `play`
	var b := ShipBreakup.new()
	var task := WorkerThreadPool.add_task(func() -> void:
		b.setup(img, used, Vector2.ZERO, style, seed, true)
		held.b = b)
	return {task = task, held = held, pic = pic}


static func is_cut(pre: Dictionary) -> bool:
	return pre.is_empty() or WorkerThreadPool.is_task_completed(pre.task)


## The ship comes apart where it is drawn: the breakup into `host` (at child
## index `at_index`, or on top when it is -1), over the hull's own place, and the
## hull hidden. `rest` is where `v` sits in its parent when nothing is shaking
## it: the hit's kick moves the view for a few frames and the wreck must not
## keep that offset. Returns the breakup, or null.
static func play(pre: Dictionary, host: Control, v: ShipView, at_index: int = -1,
		rest: Vector2 = Vector2.ZERO) -> ShipBreakup:
	if pre.is_empty() or v == null:
		return null
	WorkerThreadPool.wait_for_task_completion(pre.task)
	var b: ShipBreakup = pre.held.b
	if b == null:
		return null
	b.finish()
	var pic: Dictionary = pre.pic
	# The bob has moved on since the picture was taken; the hull in it is where
	# it was then. Kept from here on: the wreck does not bob.
	pic.dy = float(v.bob_offset() - int(pic.bob)) * float(pic.k)
	b.size = host.size
	b.scale = Vector2(-float(pic.k), float(pic.k))
	b.set_meta(&"pic", pic)
	place(b, host, v, rest)
	host.add_child(b)
	if at_index >= 0:
		host.move_child(b, at_index)
	return b


## Put a playing breakup over the hull's place again: the view's layout can
## move under it (the hand lowering once a fight is over moves every ship).
static func place(b: ShipBreakup, host: Control, v: ShipView, rest: Vector2 = Vector2.ZERO) -> void:
	if b == null or v == null or not b.has_meta(&"pic"):
		return
	var pic: Dictionary = b.get_meta(&"pic")
	var k := float(pic.k)
	var lo := canvas_origin(v) + Vector2(0.0, float(pic.get("dy", 0.0)))
	var parent := v.get_parent() as Control
	var g := (parent.get_global_transform() if parent != null else Transform2D.IDENTITY) * (rest + lo)
	var p := (host.get_global_transform().affine_inverse() * g).round()
	b.position = p + Vector2(float((pic.img as Image).get_width()) * k, 0.0)
