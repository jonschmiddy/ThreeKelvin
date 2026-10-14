extends Node

## THE ENEMIES' PICTURES, headless:
##   godot --headless --path . -- sheet=EnemyArtTest
## Jon kept PixelLab ships for every enemy (Oct 13): three per ordinary kind,
## one chosen per fight; one each for the Hellbender, the Custodian, the calf
## and the Leviathan. This checks:
##   - EVERY KIND HAS A PICTURE: each enemy id names at least one file
##     (`art/sprites/enemies/index.json`), every file loads, fits the canvas
##     (`EnemyArt.W` x `H`), is hard-edged (alpha 0 or 255), and is what
##     `EnemyArt` draws -- the sprite, not the coded fallback, and nothing else
##     on the canvas (no stars: a breakup cuts the canvas by its alpha);
##   - THE PICTURE IS THE FIGHT'S, NOT A ROLL: `Combat.look_for` gives the same
##     ships for the same fight asked twice and in a second run of the same
##     galaxy, different ships across systems (each three-picture kind shows all
##     three somewhere), and the look survives into the wrecks the win leaves
##     (in fight order) and through the save;
##   - PACKS FIT: the real fight opened on every pair of kinds a fight can
##     roll at their widest pictures, every picture beside the widest ship, a
##     the dev flag's three: once the entrance
##     has landed, every ship where its art actually IS -- inside the view, clear
##     of your ship, your ship not moved -- and a lone ship in the middle of the
##     enemy half.

var _fails := 0


func _ok(what: String, c: bool) -> bool:
	if not c:
		print("  FAIL %s" % what)
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_pictures()
	_looks()
	await _wrecks(tree)
	await _packs(tree)
	print("enemyarttest: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	tree.quit()


func _pictures() -> void:
	var ids: Array = DB.enemies.keys()
	ids.sort()
	var files := 0
	for raw in ids:
		var id: StringName = raw
		var n := DB.enemy_looks(id)
		if not _ok("%s names a picture" % id, n >= 1):
			continue
		for look in n:
			var tex := DB.enemy_sprite(id, look)
			var f := String(DB.enemy_sprite_files(id)[look])
			if not _ok("%s look %d (%s) loads" % [id, look, f], tex != null):
				continue
			files += 1
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var ink := img.get_used_rect()
			_ok("%s %s fits the %dx%d canvas (%dx%d)" % [id, f, EnemyArt.W, EnemyArt.H, ink.size.x, ink.size.y],
				ink.size.x <= EnemyArt.W and ink.size.y <= EnemyArt.H)
			var soft := 0
			for y in img.get_height():
				for x in img.get_width():
					var a := img.get_pixel(x, y).a
					if a > 0.0 and a < 1.0:
						soft += 1
			_ok("%s %s is hard-edged (%d soft pixels)" % [id, f, soft], soft == 0)
			# what EnemyArt draws from it
			var art := EnemyArt.new()
			var e := Combat.EnemyState.new()
			e.template = DB.enemies[id]
			e.max_hp = 50
			e.hp = 50
			e.look = look
			art.set_enemy(e, false)
			var u := art.used_rect()
			_ok("%s %s: EnemyArt draws the picture (box %dx%d, picture %dx%d)" % [id, f, u.size.x, u.size.y, ink.size.x, ink.size.y],
				u.size == ink.size)
			var stray := 0
			var canvas: Image = art._img
			for y in canvas.get_height():
				for x in canvas.get_width():
					if canvas.get_pixel(x, y).a > 0.0 and not u.has_point(Vector2i(x, y)):
						stray += 1
			_ok("%s %s: nothing on the canvas outside the ship (%d px)" % [id, f, stray], stray == 0)
			# THE FLAME STARTS ON ITS OWN SHIP at both sizes: read off the full
			# picture and drawn over the half one, every nozzle sat twice as far from
			# the corner as its engine, off the ship in every pack of three (Jon, Oct 14)
			for sc in [1.0, 0.5]:
				art.set_draw_scale(sc)
				art.set_enemy(e, false)
				if art._flame_fx == null:
					continue
				var on := art.used_rect().grow(2)
				var off := 0
				var pts := 0
				for nz in art._flame_fx.nozzles:
					for q in (nz as Dictionary).get("pts", PackedVector2Array()):
						pts += 1
						if not on.has_point(Vector2i(art._flame_at + (q as Vector2))):
							off += 1
				_ok("%s %s at %.1fx: its flame's %d nozzle points are on the ship (%d off)"
						% [id, f, sc, pts, off], pts > 0 and off == 0)
			art.free()
	print("enemyarttest: %d kinds, %d pictures" % [ids.size(), files])


## The same fight asked twice, the same galaxy twice, and the spread across it.
func _looks() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var seen := {}
	var first := {}
	var systems := 0
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.START:
			continue
		Run.at = n.index
		systems += 1
		for id in [&"cutter", &"lancer", &"marauder", &"hulk", &"sentinel"]:
			var a := _plan([id, id])
			var b := _plan([id, id])
			_ok("%s at %d: the same pictures asked twice" % [id, n.index], a == b)
			first["%s@%d" % [id, n.index]] = a
			for l in a:
				var k := "%s:%d" % [id, posmod(l, DB.enemy_looks(id))]
				seen[k] = true
	for id in [&"cutter", &"lancer", &"marauder", &"hulk", &"sentinel"]:
		var shown := 0
		for look in DB.enemy_looks(id):
			if seen.has("%s:%d" % [id, look]):
				shown += 1
		_ok("%s: every picture turns up somewhere in %d systems (%d of %d)" % [id, systems, shown, DB.enemy_looks(id)],
			shown == DB.enemy_looks(id))
	# a second run of the same galaxy draws the same ships
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var same := 0
	var asked := 0
	for k in first:
		var parts := String(k).split("@")
		Run.at = int(parts[1])
		asked += 1
		if _plan([StringName(parts[0]), StringName(parts[0])]) == first[k]:
			same += 1
	_ok("the same galaxy again draws the same ships (%d of %d fights)" % [same, asked], same == asked)


func _plan(ids: Array) -> Array:
	var c := Combat.new()
	var extras: Array = []
	for i in range(1, ids.size()):
		extras.append(DB.enemies[ids[i]])
	c.plan(DB.enemies[ids[0]], Run.node_at().danger, extras)
	var out: Array = []
	for e in c.enemies:
		out.append(e.look)
	return out


## Won, the wrecks wear the fight's pictures, in order, and keep them through a save.
func _wrecks(tree: SceneTree) -> void:
	Rng.forced = 777
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			idx = n.index
			break
	Run.at = idx
	SectorScreen._approached_at = idx
	Router.start_combat(DB.enemies[&"hulk"], [DB.enemies[&"marauder"]], false, false)
	for i in 5:
		await tree.process_frame
	var c: Combat = Router.combat
	if not _ok("a fight opened for the wreck check", c != null):
		return
	var looks: Array = []
	for e in c.enemies:
		looks.append(e.look)
		e.hp = 0
	c._victory()
	for i in 5:
		await tree.process_frame
	var node := Run.node_at()
	var wl: Array = []
	for raw in node.jetsam:
		var h: MapGen.Jetsam = raw
		if h.is_wreck():
			wl.append(h.look)
	_ok("the wrecks wear the fight's pictures (%s, fought %s)" % [wl, looks], wl == looks)
	var back := SaveGame._node_from(SaveGame._node_to(node))
	var bl: Array = []
	for raw in back.jetsam:
		var h: MapGen.Jetsam = raw
		if h.is_wreck():
			bl.append(h.look)
	_ok("and keep them through a save (%s)" % [bl], bl == looks)


## Every pair a fight can roll, at every combination of pictures of the widest
## kinds, and three at once (a set piece is always alone): on screen.
func _packs(tree: SceneTree) -> void:
	# every ordered pair of kinds at their widest pictures, and every picture
	# beside the widest ship there is
	var pairs: Array = []
	var pool: Array = [&"cutter", &"lancer", &"marauder", &"hulk", &"sentinel"]
	var widest := {}
	var top := [&"", 0, 0]
	for k in pool:
		widest[k] = 0
		var best := 0
		for look in DB.enemy_looks(k):
			var w := DB.enemy_sprite(k, look).get_width()
			if w > best:
				best = w
				widest[k] = look
			if w > int(top[2]):
				top = [k, look, w]
	for a in pool:
		for b in pool:
			pairs.append([[a, widest[a]], [b, widest[b]]])
	for k in pool:
		for look in DB.enemy_looks(k):
			pairs.append([[k, look], [top[0], top[1]]])
	pairs.append([[&"marauder", 0], [&"hulk", 0], [&"sentinel", 0]])
	pairs.append([[&"marauder", 0], [&"hulk", 1], [&"marauder", 1]])
	pairs.append([[&"whale", 0]])
	pairs.append([[&"leviathan", 0]])
	# where your own ship stands when one contact is out there
	await _fight(tree, [[&"cutter", 0]])
	var home := _you_x
	var worst := -999.0
	var moved := 0.0
	var gap := 999.0
	for p: Array in pairs:
		var r := await _fight(tree, p)
		worst = maxf(worst, r)
		moved = maxf(moved, absf(_you_x - home))
		gap = minf(gap, _clear)
		_ok("%s: every ship on screen (%.0f px past the view's edge)" % [str(p), r], r <= 0.0)
		# the pack makes room inside its own half, never by pushing your ship
		_ok("%s: your ship stays where it stood (%.0f px moved)" % [str(p), _you_x - home], absf(_you_x - home) <= 1.0)
		_ok("%s: no contact over your ship (%.0f px clear)" % [str(p), _clear], _clear >= 8.0)
	print("enemyarttest: %d packs; worst %.0f px from the view's right edge, your ship moved at most %.0f px, contacts at least %.0f px clear of it"
		% [pairs.size(), worst, moved, gap])
	# one ship stays where it always stood: centred in the enemy half
	for id in [&"cutter", &"custodian", &"whale"]:
		var r := await _fight(tree, [[id, 0]], true)
		_ok("%s alone sits in the middle of the enemy half (%.1f px off)" % [id, r], absf(r) <= 1.0)


var _you_x := 0.0
var _clear := 0.0

## Opens the fight; answers how far the furthest ship's box runs past the view's
## right edge (positive is off screen) -- or, `centred`, how far a lone ship is
## from the middle of the enemy half.
func _fight(tree: SceneTree, p: Array, centred: bool = false) -> float:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			Run.at = n.index
			break
	SectorScreen._approached_at = Run.at
	var extras: Array = []
	for i in range(1, p.size()):
		extras.append(DB.enemies[p[i][0]])
	Router.start_combat(DB.enemies[p[0][0]], extras, false, false)
	if Router.combat == null:
		return 0.0
	for i in p.size():
		Router.combat.enemies[i].look = int(p[i][1])
	Sig.enemy_changed.emit()
	# past the entrance (half a second, and a pack's stagger), so what is
	# measured is where each ship comes to rest, not where it was sent
	await tree.create_timer(0.9).timeout
	await tree.process_frame
	var sc = Router.current
	var view: EncounterView = sc.get("_view") if sc != null else null
	if view == null:
		_ok("%s: the fight has a view" % str(p), false)
		return 0.0
	var vr := view.get_global_rect()
	var sv := view.ship_view()
	var you := Rect2(sv.get_global_rect().position + sv.ship_rect().position, sv.ship_rect().size)
	_you_x = you.position.x
	_clear = 999.0
	var worst := -999.0
	var i := 0
	while view.slot(i) != null:
		var s: EnemySlot = view.slot(i)
		var u := Rect2(s.art.used_rect())
		# where the art IS, not where its holder says it should be
		var at := s.art.get_global_transform() * Vector2.ZERO
		var right := at.x + u.end.x
		var left := at.x + u.position.x
		worst = maxf(worst, maxf(right - vr.end.x, (vr.position.x) - left))
		_clear = minf(_clear, left - you.end.x)
		if centred:
			var sl: Control = view.get("_slots")
			var mid := sl.get_global_rect().get_center().x
			return (left + right) * 0.5 - mid
		i += 1
	return worst
