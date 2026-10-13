extends Node

## HITS, BLOCK AND BRACE IN A REAL FIGHT (Jon's picks, Oct 13: hits B, the
## bubble, brace I).
##   godot --headless --path . -- sheet=HitFxLiveTest
## Through the real SectorScreen, a pack of three: every enemy and your ship
## carry their `HitLayers`; and for each kind of landing, its visual --
##   block gained: the bubble up with that block (an enemy's and yours);
##   brace gained: the plated overlay's panels clamped on;
##   a shot the block soaks: the bubble takes it, still up;
##   a shot that empties the block: it fizzles;
##   a shot into the brace: the overlay takes it, sheds panels in proportion;
##   a shot into the hull: a mark (the marks' version moves);
##   the turn's end: your leftover block fizzles;
## then a kill: the dead slot's wreck is cut from the picture WITH the marks
## (EnemyArt's marked wreck, keyed where it lies), and LOCAL's wreck slot at that
## place draws the same picture. Headless, so every landing lands at once.

var h := Harness.new()
var _tree: SceneTree
var _moments := {}


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _run() -> void:
	await _frames(2)
	h.seed_run(4242)
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
	Router.start_combat(DB.enemies[&"cutter"], [DB.enemies[&"lancer"], DB.enemies[&"cutter"]], false, false)
	await _frames(4)
	var sc := Router.current as SectorScreen
	var cb: Combat = Router.combat
	if not _ok("a fight of three on the real screen", sc != null and cb != null and cb.enemies.size() == 3):
		_end()
		return
	Run.hp = Run.max_hp()
	sc._refresh_enemy()
	sc._refresh_player()
	await _frames(2)

	# armed
	var armed := 0
	for i in 3:
		var sl := sc._view.slot(i)
		if sl != null and sl.layers != null and sl.art.marks == sl.layers.hits:
			armed += 1
			sl.layers.moment.connect(func(k: StringName, _s: float, _l: float) -> void:
				_moments[String(k)] = int(_moments.get(String(k), 0)) + 1)
	_ok("every enemy carries its hits, bubble and armour (%d of 3)" % armed, armed == 3)
	_ok("so does your ship", sc._ship_fx != null and is_instance_valid(sc._ship_fx))
	var L: HitLayers = sc._view.slot(0).layers
	var e: Combat.EnemyState = cb.enemies[0]

	# block and brace gained
	e.max_hp = 200
	e.hp = 200
	e.block = 6
	e.brace = 6
	sc._refresh_enemy()
	await _frames(2)
	_ok("enemy block: the bubble up with it (%d)" % L.shield.block, L.shield.block == 6 and L.shield._up)
	var on0 := L.brace._pieces.filter(func(p: Dictionary) -> bool: return p.on).size()
	_ok("enemy brace: the armour clamped on (%d of %d panels)" % [on0, L.brace._pieces.size()],
		L.brace.brace == 6 and on0 == L.brace._pieces.size() and on0 > 0)

	# a shot the block soaks
	var v0 := L.hits.version
	cb.damage_enemy(4, 1, "test", e)
	await _frames(2)
	_ok("a soaked shot: the bubble takes it and stays (%d left)" % L.shield.block,
		L.shield.block == 2 and L.shield._fizz_t < 0.0 and L.shield._shim_t >= 0.0)
	_ok("and marks nothing", L.hits.version == v0)
	# one that empties it and goes on into the brace
	cb.damage_enemy(5, 1, "test", e)
	await _frames(2)
	var on1 := L.brace._pieces.filter(func(p: Dictionary) -> bool: return p.on).size()
	_ok("a shot that empties the block: it fizzles", L.shield.block == 0 and L.shield._fizz_t >= 0.0)
	_ok("and the rest lands on the armour, which sheds in proportion (%d -> %d panels, brace %d)" % [on0, on1, L.brace.brace],
		L.brace.brace == 3 and on1 < on0 and on1 > 0)
	# through the rest of the brace into the hull
	cb.damage_enemy(9, 1, "test", e)
	await _frames(2)
	var on2 := L.brace._pieces.filter(func(p: Dictionary) -> bool: return p.on).size()
	_ok("brace spent: the last of the armour goes (%d panels)" % on2, L.brace.brace == 0 and on2 == 0)
	_ok("and the hull is marked (%d)" % L.hits.version, L.hits.version > v0)
	var vm := L.hits.version
	for k in 3:
		cb.damage_enemy(4, 1, "test", e)
		await _frames(1)
	_ok("more hits, more marks (%d -> %d)" % [vm, L.hits.version], L.hits.version > vm)
	await _tree.create_timer(0.7).timeout   # a crack runs over a quarter second
	await _frames(2)
	_ok("baked into the enemy's own picture, cracks and all", sc._view.slot(0).art._sig.contains("marks %d" % L.hits.version))

	# your ship
	var Y := sc._ship_fx
	cb.block = 5
	cb.brace = 4
	sc._refresh_player()
	await _frames(2)
	_ok("your block: your bubble up (%d)" % Y.shield.block, Y.shield.block == 5 and Y.shield._up)
	_ok("your brace: your armour on (%d)" % Y.brace.brace, Y.brace.brace == 4)
	var yv := Y.hits.version
	Y.land(0, 3, Run.hp)
	_ok("a shot on you the block soaks: shimmer, not a mark", Y.shield.block == 2 and Y.hits.version == yv)
	Y.land(6, 6, Run.hp - 6)
	await _tree.create_timer(0.7).timeout   # a crack runs over a quarter second
	_ok("one through block and brace onto your hull: fizzle, armour off, a mark",
		Y.shield.block == 0 and Y.brace.brace == 0 and Y.hits.version > yv)
	cb.block = 3
	sc._refresh_player()
	await _frames(1)
	cb.block = 0
	sc._refresh_player()
	await _frames(1)
	_ok("your leftover block at the turn's end: it fizzles", Y.shield.block == 0 and Y.shield._fizz_t >= 0.0)

	# the kill: its wreck keeps the marks
	var wid := sc._wreck_id_of(0)
	cb.damage_enemy(999, 1, "test", e)
	await _frames(4)
	var sl0 := sc._view.slot(0)
	var marked: Dictionary = EnemyArt._marked.get(wid, {})
	_ok("the kill leaves a marked wreck where it lies (id %d)" % wid, not marked.is_empty())
	if not marked.is_empty():
		var clean := ShipBreakup.wreck_image(EnemyArt.dead_canvas(e)[0], EnemyArt.dead_canvas(e)[1],
			EnemyArt.wreck_seed(e.template), e.template.boss, int(marked.style))
		_ok("which differs from the clean wreck (the marks are on it)",
			(marked.img as Image).get_data() != clean.get_data())
		_ok("and is what the dead slot draws", sl0.art._img.get_data() == (marked.img as Image).get_data())
		# LOCAL's wreck slot at that place
		var ghost := Combat.EnemyState.new()
		ghost.template = e.template
		ghost.max_hp = e.template.max_hull
		ghost.hp = 0
		ghost.look = e.look
		var art := EnemyArt.new()
		art.wreck_id = wid
		art.set_enemy(ghost, false, -1, true, int(marked.style))
		_ok("and LOCAL's wreck at that place, later", art._img.get_data() == (marked.img as Image).get_data())
		art.free()
	var kinds := ["shield_up", "shield_hit", "shield_fizzle", "bolt_on", "clang", "plate_off", "impact"]
	for k2 in kinds:
		_ok("moment %s fires (%d)" % [k2, int(_moments.get(k2, 0))], int(_moments.get(k2, 0)) > 0)
	_end()


func _end() -> void:
	h.verdict("hitfxlivetest")
	_tree.quit(h.code())
