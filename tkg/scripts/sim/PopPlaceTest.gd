extends Node

## WHERE THE NUMBERS SIT, on every hull:
##   godot --headless --path . -- sheet=PopPlaceTest
##
## Jon, Oct 13 ("Pops: B"): held over a ship, the card's number is ON it,
## centred on the hull's ink both ways; landed, the pop is ABOVE the ship,
## centred across on the ink and clear of its top, stacking upward. Measured
## off the ink, not the canvas: BLOCKED 5 sat right of your hull's middle
## because the canvas carries the exhaust's clearance on one side.
##
## For every enemy picture (`DB.enemies`) and every player hull (each
## manufacturer at each weight), in a real fight:
##   - the preview's letters (`EnemySlot` / `ShipSlot.preview_rect`) are
##     centred on the hull's ink within 1 px, both ways;
##   - every pop a landing makes (-6, BLOCKED 5, MISS, stacked) is centred
##     across on the ink within 1 px, and its letters and their outline are
##     wholly above the ink's top.

var _tree: SceneTree
var _fails := 0
var _checked := 0
const TOL := 1.0


func _ok(what: String, c: bool) -> bool:
	_checked += 1
	if not c:
		print("  FAIL %s" % what)
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	var hulls := 0
	for m in DB.manufacturers.keys():
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			if DB.hull_for(m, w) == null:
				continue
			var sc := await _fight(m, int(w), &"cutter")
			if sc == null:
				continue
			hulls += 1
			_check_player(sc, "%s/%d" % [m, w])
	var foes := 0
	for id in DB.enemies.keys():
		var sc2 := await _fight(&"korvan", int(HullData.Weight.MEDIUM), id)
		if sc2 == null:
			continue
		foes += 1
		_check_enemy(sc2, String(id))
	print("  %d player hulls, %d enemy pictures, %d checks" % [hulls, foes, _checked])
	_ok("some of each were checked", hulls > 0 and foes > 0)
	print("popplacetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


func _fight(m: StringName, w: int, foe: StringName) -> SectorScreen:
	Rng.forced = 2024
	Run.start_new_run(m, w)
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if idx < 0:
		return null
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _frames(2)
	if not DB.enemies.has(foe):
		return null
	Router.start_combat(DB.enemies[foe], [], false, false)
	await _frames(3)
	var sc := Router.current as SectorScreen
	if sc == null or Router.combat == null or sc._view == null:
		print("  (no fight for %s against %s)" % [m, foe])
		return null
	return sc


## Every pop a landing on this hull makes, as drawn at rest (before it rises).
func _pops_of(sc: SectorScreen, to_player: bool, who: int) -> Array:
	var fx := sc._view.fx
	fx._pops.clear()
	sc._pop_hit(sc._pop_at(to_player, who), {dealt = 6, absorbed = 5, missed = 1, hits = 2}, to_player)
	var out: Array = []
	for p in fx._pops:
		var at := (p.at + Vector2(-HitText.ink_width(p.text) * 0.5, 0.0)).round()
		out.append([p.text, HitText.ink_rect(at, p.text)])
	fx._pops.clear()
	return out


func _check_pops(pops: Array, ink: Rect2, what: String) -> void:
	_ok("%s: a landing pops three lines (%d)" % [what, pops.size()], pops.size() == 3)
	var cx := ink.get_center().x
	for row in pops:
		var r: Rect2 = row[1]
		_ok("%s: '%s' centred on the ink across (off %.1f)" % [what, row[0], r.get_center().x - cx],
			absf(r.get_center().x - cx) <= TOL)
		# The outline is one pixel below the letters' last row.
		_ok("%s: '%s' wholly above the ink's top (bottom %.1f, top %.1f)" % [what, row[0], r.end.y + 1.0, ink.position.y],
			r.end.y + 1.0 <= ink.position.y)


func _check_player(sc: SectorScreen, what: String) -> void:
	var ss: EncounterView.ShipSlot = sc._view._ship_slot
	if not _ok("%s: your ship has a slot" % what, ss != null and ss.art != null):
		return
	var ink := ss.ink_rect()
	_ok("%s: your hull has ink" % what, ink.size.x > 8.0 and ink.size.y > 4.0)
	for t in ["+5 BRACE", "+7 BLOCK"]:
		var r := ss.preview_rect(t)
		var d := r.get_center() - ink.get_center()
		_ok("%s: '%s' held over your hull is centred on its ink (off %.1f, %.1f)" % [what, t, d.x, d.y],
			absf(d.x) <= TOL and absf(d.y) <= TOL)
	_check_pops(_pops_of(sc, true, 0), sc._hull_ink(true, 0), what + " (your hull)")


func _check_enemy(sc: SectorScreen, what: String) -> void:
	var sl: EnemySlot = sc._view.slot(0)
	if not _ok("%s: has a slot" % what, sl != null and sl.art != null):
		return
	var ink := sl.ink_rect()
	_ok("%s: has ink" % what, ink.size.x > 4.0 and ink.size.y > 4.0)
	for t in ["-6", "-10 KILL"]:
		var r := sl.preview_rect(t)
		var d := r.get_center() - ink.get_center()
		_ok("%s: '%s' held over it is centred on its ink (off %.1f, %.1f)" % [what, t, d.x, d.y],
			absf(d.x) <= TOL and absf(d.y) <= TOL)
	_check_pops(_pops_of(sc, false, 0), sc._hull_ink(false, 0), what)
