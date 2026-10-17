extends Node

## THE HULL DAMAGE LOOKS KEEP THEIR RULES (Oct 17; `HullHitFx`, `ShipHitFx.look`).
##   godot --headless --path . -- sheet=HullDamageTest
## Headless. For each look (A, B, C, and D, all three mixed), on three ships' pictures (a light hull, a
## dark one, a white one) from their full sheets and their half sheets, the nine
## hits of `HullDamageFilm` from full hull to 6, the clock stepped 1/60 s:
##   * NO HOLES: no blob of 4 or more pixels gone near black (under 9% light)
##     where the art was not (15% or more). Today's marks fail this by design
##     (Chain's bites were 40 to 115 px), and that is the playtester's note;
##   * every mark on the hull's own pixels and never its outline;
##   * every mark's colour one the sprite already has, or the heat ramp's
##     darkest (burnt metal); every glowing pixel the heat ramp's, on the hull;
##   * the same seed, the same marks, pixel for pixel;
##   * a glow changes shape, while it glows, between 8 and 12 times a second;
##   * the marks build up: more of the hull marked at 6 hull than at 60;
##   * D mixes: its hits roll A's, B's and C's kinds over the three ships, and it
##     marks less of each hull than today's marks do for the same nine hits.
## Then the real fight: with a look picked, every ship's hits are `HullHitFx`
## (yours too), a shot through `Combat.damage_enemy` marks the enemy's picture,
## and the kill's wreck keeps the marks; the Custodian keeps today's; with no
## look picked (the default), everything is today's.

const Film := preload("res://scripts/sim/HullDamageFilm.gd")
const SHIPS := ["cutter:0", "hulk:0", "marauder:2"]

var h := Harness.new()
var _tree: SceneTree


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _pic(spec: String, half: bool) -> Image:
	var parts := spec.split(":")
	var tex := DB.enemy_sprite(StringName(parts[0]), int(parts[1]), half)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var pic := Image.create(img.get_width() + 16, img.get_height() + 16, false, Image.FORMAT_RGBA8)
	pic.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(8, 8))
	return pic


func _make(pic: Image, look: int, scale: float, seed: int) -> HullHitFx:
	var hx := HullHitFx.new()
	hx.style = look
	hx.auto = false
	hx.mark_scale = scale
	add_child(hx)
	hx.setup(pic, pic.get_used_rect(), Vector2.ZERO, seed, -1)
	return hx


## The nine hits, stepped; returns the marked pixels at 60 hull and at the end,
## the shortest gap between two changes of the glow that no hit caused, and the
## longest stretch it glowed without changing.
func _play(hx: HullHitFx) -> Dictionary:
	var hp := 100
	var marked60 := -1
	var last := PackedByteArray()
	var t := 0.0
	var last_change := -1.0
	var last_step := -1.0
	var mingap := 1e9
	var maxgap := 0.0
	for i in Film.SHOTS.size():
		hp -= Film.SHOTS[i]
		hx.hit(Film.SHOTS[i], hp, 100)
		if hp <= 60 and marked60 < 0:
			marked60 = _marked(hx)
		for s in 66:
			hx.advance(1.0 / 60.0)
			t += 1.0 / 60.0
			var g := hx._glow.get_data()
			var glowing := not hx._glow.is_invisible()
			if g != last:
				last = g
				# a hit lights its flash the frame it lands; between hits the
				# glow keeps its own steps
				if s > 0:
					if last_step >= 0.0:
						mingap = minf(mingap, t - last_step)
					last_step = t
				last_change = t
			elif glowing and last_change >= 0.0:
				maxgap = maxf(maxgap, t - last_change)
	return {m60 = marked60, end = _marked(hx), mingap = mingap, maxgap = maxgap}


func _marked(hx: HullHitFx) -> int:
	var n := 0
	var m := hx.marks()
	for i in hx._w * hx._h:
		if m.get_pixel(i % hx._w, i / hx._w).a > 0.0:
			n += 1
	return n


func _run() -> void:
	await _frames(2)
	var ramp := {}
	for c in ShipBreakup.HEAT_RAMP:
		ramp[HullHitFx._key(c)] = true
	var d_kinds := {}
	for look in [1, 2, 3, 4]:
		for spec in SHIPS:
			for half in [false, true]:
				var pic := _pic(spec, half)
				var sc := 0.5 if half else 1.0
				var hx := _make(pic, look, sc, 4242)
				var r := _play(hx)
				var tag := "%s %s %s" % ["ABCD"[look - 1], spec, "half" if half else "full"]
				if look == 4:
					for kd in hx.rolled:
						d_kinds[kd] = true
					var today := ShipHitFx.new()
					today.auto = false
					today.mark_scale = sc
					add_child(today)
					today.setup(pic, pic.get_used_rect(), Vector2.ZERO, 4242, -1)
					var hp2 := 100
					for s2 in Film.SHOTS:
						hp2 -= s2
						today.hit(s2, hp2, 100)
					var tm := 0
					for i5 in today._w * today._h:
						if today.marks().get_pixel(i5 % today._w, i5 / today._w).a > 0.0:
							tm += 1
					_ok("%s: quieter than today's (%d px marked, today %d)" % [tag, r.end, tm], r.end < tm)
					today.queue_free()
				# holes
				var worst := _worst_blob(hx)
				_ok("%s: no hole (largest near-black blob %d px)" % [tag, worst], worst < 4)
				# on the hull, off the outline; colours
				var off := 0
				var foreign := 0
				var pal := {}
				for c in hx._pal:
					pal[HullHitFx._key(c)] = true
				pal[HullHitFx._key(ShipBreakup.HEAT_RAMP[5])] = true
				var m := hx.marks()
				for i in hx._w * hx._h:
					var c2 := m.get_pixel(i % hx._w, i / hx._w)
					if c2.a <= 0.0:
						continue
					if hx._mask[i] == 0 or hx._edge[i] == 1:
						off += 1
					if not pal.has(HullHitFx._key(c2)):
						foreign += 1
				_ok("%s: every mark on the hull, none on its outline (%d off)" % [tag, off], off == 0)
				_ok("%s: every mark's colour the ship's own or burnt metal (%d not)" % [tag, foreign], foreign == 0)
				# glow: the ramp's, on the hull
				var gbad := 0
				for k in 3:
					hx.hit(10, 5, 100)
					hx.advance(0.05)
					var g := hx._glow
					for i in hx._w * hx._h:
						var c3 := g.get_pixel(i % hx._w, i / hx._w)
						if c3.a <= 0.0:
							continue
						if hx._mask[i] == 0 or not ramp.has(HullHitFx._key(c3)):
							gbad += 1
				_ok("%s: every glowing pixel the heat ramp's, on the hull (%d not)" % [tag, gbad], gbad == 0)
				_ok("%s: a glow changes shape 8 to 12 times a second (gaps %.3f to %.3f s)" % [tag, r.mingap, r.maxgap],
					r.mingap >= 1.0 / 12.0 - 0.01 and r.maxgap <= 1.0 / 8.0 + 0.01)
				_ok("%s: the marks build up (%d px at 60 hull, %d at 6)" % [tag, r.m60, r.end], r.end > r.m60 and r.m60 > 0)
				# repeatable
				var hx2 := _make(pic, look, sc, 4242)
				_play(hx2)
				var hx3 := _make(pic, look, sc, 4242)
				_play(hx3)
				_ok("%s: the same seed, the same marks" % tag, hx2.marks().get_data() == hx3.marks().get_data())
				hx.queue_free()
				hx2.queue_free()
				hx3.queue_free()
	var fam := {"A": ["DENT", "SCRAPE", "RIVETS", "SPLIT"], "B": ["BLOOM"], "C": ["PEEL", "KNOCK"]}
	for f in fam:
		var any := false
		for kd2 in fam[f]:
			any = any or d_kinds.has(kd2)
		_ok("D rolls %s's kinds (%s)" % [f, ", ".join(d_kinds.keys())], any)
	await _fight()
	_end()


## The biggest 4-connected blob of pixels the marks took near black.
func _worst_blob(hx: HullHitFx) -> int:
	var w := hx._w
	var m := hx.marks()
	var dark := PackedByteArray()
	dark.resize(w * hx._h)
	for i in w * hx._h:
		var c := m.get_pixel(i % w, i / w)
		if c.a > 0.0 and c.get_luminance() < 0.09 and hx._orig[i].get_luminance() >= 0.15:
			dark[i] = 1
	var worst := 0
	var seen := PackedByteArray()
	seen.resize(w * hx._h)
	for i0 in w * hx._h:
		if dark[i0] == 0 or seen[i0] == 1:
			continue
		var q: Array[int] = [i0]
		seen[i0] = 1
		var n := 0
		while not q.is_empty():
			var i: int = q.pop_back()
			n += 1
			for o in [1, -1, w, -w]:
				var j: int = i + int(o)
				if j >= 0 and j < w * hx._h and dark[j] == 1 and seen[j] == 0 \
						and absi((j % w) - (i % w)) <= 1:
					seen[j] = 1
					q.append(j)
		worst = maxi(worst, n)
	return worst


func _fight() -> void:
	h.seed_run(4242)
	for look in [0, 2, 4]:
		ShipHitFx.look = look
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var idx := -1
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.SYSTEM and not n.cleared and not Router.no_fights_at(n):
				idx = n.index
				break
		Run.at = idx
		Run.map[idx].visited = true
		SectorScreen._approached_at = idx
		Router.show_local()
		await _frames(3)
		Router.start_combat(DB.enemies[&"cutter"], [DB.enemies[&"lancer"]], false, false)
		await _frames(4)
		var sc := Router.current as SectorScreen
		var cb: Combat = Router.combat
		if not _ok("look %d: a fight on the real screen" % look, sc != null and cb != null):
			return
		Run.hp = Run.max_hp()
		sc._refresh_enemy()
		sc._refresh_player()
		await _frames(2)
		var want := "HullHitFx" if look > 0 else "ShipHitFx"
		var all := true
		for i in 2:
			var sl := sc._view.slot(i)
			all = all and sl != null and sl.layers != null and sl.layers.hits.get_script().get_global_name() == want
		_ok("look %d: every enemy's hits are %s" % [look, want], all)
		_ok("look %d: and yours" % look, sc._ship_fx != null
			and sc._ship_fx.hits.get_script().get_global_name() == want)
		var e: Combat.EnemyState = cb.enemies[0]
		var sl0 := sc._view.slot(0)
		var before := sl0.art._img.get_data()
		var v0 := sl0.layers.hits.version
		e.hp = e.max_hp
		cb.damage_enemy(maxi(1, e.max_hp / 5), 1, "test", e)
		await _frames(6)
		_ok("look %d: a shot through damage_enemy marks the hull (version %d -> %d)" % [look, v0, sl0.layers.hits.version],
			sl0.layers.hits.version > v0)
		_ok("look %d: and the enemy's picture carries it" % look, sl0.art._img.get_data() != before)
		if look > 0:
			var wid := sl0.wreck_id
			cb.damage_enemy(9999, 1, "test", e)
			await _frames(8)
			var marked: Dictionary = EnemyArt._marked.get(wid, {})
			_ok("look %d: the kill leaves a marked wreck" % look, not marked.is_empty())
		Router.combat = null
		await _frames(2)
	# the Custodian keeps today's
	ShipHitFx.look = 2
	var L := HitLayers.new()
	L.kind = FaunaMotion.Kind.CUSTODIAN
	_ok("the Custodian keeps today's marks", L._hull_hits().get_script().get_global_name() == "ShipHitFx")
	L.free()
	ShipHitFx.look = 0


func _end() -> void:
	ShipHitFx.look = 0
	h.verdict("hulldamagetest")
	_tree.quit(h.code())
