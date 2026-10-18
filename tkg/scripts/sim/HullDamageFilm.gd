extends Node

## A SHIP'S HULL MARKS FROM FULL HULL TO NEAR DEATH, IN A REAL FIGHT, FILMED
## (hull damage looks, Oct 17: James, a playtester, on today's marks: "ships
## can't really have holes in them"). Every hit goes through
## `Combat.damage_enemy`, flies from your ship and lands through
## `HitLayers.land`, as in play.
##
##   one ship, cropped at 2x (the window is the game at 2x):
##   godot --path . --resolution 1920x1080 --fixed-fps 30 -- sheet=HullDamageFilm
##       id=<kind>[:<look>] hull=<today|A|B|C|D> crop=<dir> [boxtest=1]
##   a pack of three and your ship, the whole window (with --write-movie):
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
##       -- sheet=HullDamageFilm pack=<kind>[:<look>],<kind>[:<look>],<kind>[:<look>] hull=<...>
##
## THE SAME HITS EVERY TIME: the ship's hull set to 100, then nine shots of
## 9 15 8 12 16 9 11 7 7 (94 in all, leaving 6), 1.1 s apart from 0.3 s, then
## 2.6 s held at 6 hull. A pack's three ships take the same nine, each a third
## of a beat after the one before; your ship takes four shots of its own. The
## kinds each hit rolls come from the fight's seeded stream, so a re-run is the
## same film. `crop=` writes `c_####.png` every frame from 0.2 s before the
## first shot (30 a second at --fixed-fps 30, so true speed), and prints the
## crop (window px). `boxtest=1` (no film) draws every frame twice, the hull
## marks shown and hidden, and counts the pixels of the ship's words, name and
## bars that differ: they must not.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
const SHOTS: Array[int] = [9, 15, 8, 12, 16, 9, 11, 7, 7]
const FIRST := 0.3
const GAP := 1.1
const HOLD := 2.6
const YOU: Array = [[1.0, 6], [3.4, 9], [5.6, 7], [7.9, 8]]

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _wait(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await get_tree().process_frame


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	ShipHitFx.look = {"today": 0, "A": 1, "B": 2, "C": 3, "D": 4}.get(_arg("hull", "today"), 0)
	var pack := _arg("pack", "")
	var specs := (pack if pack != "" else _arg("id", "cutter")).split(",")
	var kinds: Array[StringName] = []
	var looks: Array[int] = []
	for s in specs:
		var parts := (s as String).split(":")
		kinds.append(StringName(parts[0]))
		looks.append(int(parts[1]) if parts.size() > 1 else -1)
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START \
				and String(SkyWeatherS.sky_of_node(n)) == "calm":
			Run.at = n.index
			break
	SectorScreen._approached_at = Run.at
	var extras: Array = []
	for i in range(1, kinds.size()):
		extras.append(DB.enemies[kinds[i]])
	Router.start_combat(DB.enemies[kinds[0]], extras, false, false)
	var cb: Combat = Router.combat
	var sc := Router.current as SectorScreen
	for k in cb.enemies.size():
		var e: Combat.EnemyState = cb.enemies[k]
		e.max_hp = 100
		e.hp = 100
		e.block = 0
		e.brace = 0
		if k < looks.size() and looks[k] >= 0 and e.look != looks[k]:
			e.look = looks[k]
			# armed already on the other picture: arm again on this one
			var sl0: EnemySlot = sc._view.slot(k) if sc._view != null else null
			if sl0 != null and sl0.layers != null:
				sl0.layers.queue_free()
				sl0.layers = null
				sl0.art.marks = null
	Sig.enemy_changed.emit()
	await _wait(float(_arg("settle", "3.4")))
	var k2 := float(get_window().size.x) / get_viewport().get_visible_rect().size.x
	var crop_dir := _arg("crop", "")
	var box := _arg("boxtest", "0") == "1"
	var r := Rect2()
	var sl: EnemySlot = sc._view.slot(0)
	r = sl.holder_rect()
	for rr in [sl.intent_rect_global(), sl.readout_rect_global()]:
		if (rr as Rect2).size != Vector2.ZERO:
			r = r.merge(rr)
	r = r.grow(10.0)
	var cr := Rect2i(Vector2i((r.position * k2).floor()), Vector2i((r.size * k2).ceil()))
	print("hulldamage: look %d crop %d %d %d %d" % [ShipHitFx.look, cr.position.x, cr.position.y, cr.size.x, cr.size.y])
	for k in cb.enemies.size():
		var s2: EnemySlot = sc._view.slot(k)
		print("hulldamage: ship %d %s look %d hits %s" % [k, cb.enemies[k].template.id, cb.enemies[k].look,
			s2.layers.hits.get_script().get_global_name() if s2.layers != null else "-"])
	if crop_dir != "":
		DirAccess.make_dir_recursive_absolute(crop_dir)
	print("hulldamage: start %d" % Engine.get_frames_drawn())
	# the plan: [time, ship (-1 yours), amount]
	var plan: Array = []
	var n_ships := cb.enemies.size()
	for k in n_ships:
		for i in SHOTS.size():
			plan.append([FIRST + GAP * float(i) + float(k) * GAP / 3.0, k, SHOTS[i]])
	if pack != "":
		for y in YOU:
			plan.append([float(y[0]), -1, int(y[1])])
	plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var end_at := FIRST + GAP * float(SHOTS.size() - 1) + float(n_ships - 1) * GAP / 3.0 + HOLD
	var start := GameClock.now()
	var pi := 0
	var frame := 0
	var box_bad := 0
	var box_n := 0
	var kinds_rolled := {}
	var start_crop := FIRST - 0.2
	while true:
		var now := GameClock.now() - start
		if now >= end_at:
			break
		while pi < plan.size() and now >= float(plan[pi][0]):
			var step: Array = plan[pi]
			pi += 1
			var who := int(step[1])
			if who < 0:
				var d := int(step[2])
				Run.hp = maxi(1, Run.hp - d)
				Sig.combat_hit.emit(true, 0, d, 0, 0, 1)
			else:
				Run.hp = Run.max_hp() if pack == "" else Run.hp
				cb.damage_enemy(int(step[2]), 1, "film", cb.enemies[who])
		await RenderingServer.frame_post_draw
		if crop_dir != "" and now >= start_crop:
			var im := get_viewport().get_texture().get_image()
			im.get_region(cr.intersection(Rect2i(Vector2i.ZERO, im.get_size()))).save_png(crop_dir + "/c_%04d.png" % frame)
			frame += 1
		if box:
			var bad := _boxtest(sc, k2)
			box_n += 1
			if bad > 0:
				box_bad += 1
				print("hulldamage: boxtest %d px on the words at %.2f" % [bad, now])
	for k in n_ships:
		var s3: EnemySlot = sc._view.slot(k)
		print("hulldamage: ship %d hull %d/%d" % [k, cb.enemies[k].hp, cb.enemies[k].max_hp])
		if s3.layers != null:
			var hf := s3.layers.hits
			print("hulldamage: ship %d kinds %s" % [k, JSON.stringify(hf.rolled)])
			print("hulldamage: ship %d %s" % [k, _measure(hf)])
			if crop_dir != "":
				_still(hf).save_png(crop_dir + "/../marks_%d.png" % k)
	if pack != "" and sc._ship_fx != null:
		print("hulldamage: yours kinds %s" % JSON.stringify(sc._ship_fx.hits.rolled))
		print("hulldamage: yours %s" % _measure(sc._ship_fx.hits))
	if box:
		print("hulldamage: boxtest %d frames, %d with marks on the words" % [box_n, box_bad])
	print("hulldamage: frames %d" % frame)
	print("hulldamage: done")
	tree.quit()


## The hull as the art drew it with every mark on it (no light, no dark blend).
func _still(hf: ShipHitFx) -> Image:
	var im := Image.create(hf._w, hf._h, false, Image.FORMAT_RGBA8)
	for i in hf._w * hf._h:
		if hf._mask[i] == 1:
			im.set_pixel(i % hf._w, i / hf._w, hf._orig[i])
	im.blend_rect(hf.marks(), Rect2i(Vector2i.ZERO, hf.marks().get_size()), Vector2i.ZERO)
	return im


## What the marks left, in the picture's own pixels: how many the hull has, and
## the near-black ones (under 9% luminance where the art was 15% or more) as
## blobs -- what reads as a hole -- with each blob's box.
func _measure(hf: ShipHitFx) -> String:
	var w: int = hf._w
	var h: int = hf._h
	var dmg: Image = hf.marks()
	var dark := PackedByteArray()
	dark.resize(w * h)
	var hull := 0
	var marked := 0
	for y in h:
		for x in w:
			var i := y * w + x
			if hf._mask[i] == 0:
				continue
			hull += 1
			var c := dmg.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			marked += 1
			if c.get_luminance() < 0.09 and hf._orig[i].get_luminance() >= 0.15:
				dark[i] = 1
	var blobs: Array = []
	var seen := PackedByteArray()
	seen.resize(w * h)
	for i0 in w * h:
		if dark[i0] == 0 or seen[i0] == 1:
			continue
		var q: Array[int] = [i0]
		seen[i0] = 1
		var n := 0
		var mn := Vector2i(w, h)
		var mx := Vector2i(-1, -1)
		while not q.is_empty():
			var i: int = q.pop_back()
			n += 1
			var p := Vector2i(i % w, i / w)
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var np: Vector2i = p + o
				if np.x < 0 or np.y < 0 or np.x >= w or np.y >= h:
					continue
				var j := np.y * w + np.x
				if dark[j] == 1 and seen[j] == 0:
					seen[j] = 1
					q.append(j)
		if n >= 4:
			blobs.append("%dpx %dx%d" % [n, mx.x - mn.x + 1, mx.y - mn.y + 1])
	var holes := 0
	for wv in hf._what:
		if int(wv) == 2:
			holes += 1
	return "hull %d px, marked %d, cut through (today's bites; C's exposed structure) %d px, near-black blobs >=4px: %s" % [hull, marked, holes, ", ".join(blobs)]


## The words' pixels (intent, name, bars) of every ship, with every ship's hull
## marks drawn and hidden: the count that differs.
func _boxtest(sc: SectorScreen, k: float) -> int:
	var hide: Array[CanvasItem] = []
	var rects: Array[Rect2] = []
	var i := 0
	while sc._view.slot(i) != null:
		var sl: EnemySlot = sc._view.slot(i)
		if sl.layers != null:
			hide.append(sl.layers.hits)
		for rr in [sl.intent_rect_global(), sl.readout_rect_global()]:
			if (rr as Rect2).size != Vector2.ZERO:
				rects.append(rr)
		i += 1
	if sc._ship_fx != null and is_instance_valid(sc._ship_fx):
		hide.append(sc._ship_fx.hits)
	RenderingServer.force_draw(false, 0.0)
	var on := get_viewport().get_texture().get_image()
	for c in hide:
		c.visible = false
	RenderingServer.force_draw(false, 0.0)
	var off := get_viewport().get_texture().get_image()
	for c in hide:
		c.visible = true
	var bad := 0
	for r in rects:
		for y in range(int(r.position.y * k), int(ceil(r.end.y * k))):
			for x in range(int(r.position.x * k), int(ceil(r.end.x * k))):
				if x < 0 or y < 0 or x >= on.get_width() or y >= on.get_height():
					continue
				if on.get_pixel(x, y) != off.get_pixel(x, y):
					bad += 1
	return bad
