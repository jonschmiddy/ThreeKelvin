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
##     wholly above the ink's top;
##   - on an enemy, above its intent words too (Jon, "C"), and no pop, at rest
##     or risen, touches any ship's intent words or its name/bar readout;
##   - and every pop, risen, is on screen under the top HUD.
## Lone ships, and packs (each in the current formation, every ship checked).

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
		_check_enemy(sc2, 0, String(id))
	# PACKS: every ship in each, in the formation as it is laid out today.
	var ids: Array = DB.enemies.keys()
	var packs: Array = [[&"cutter", &"cutter", &"lancer"]]
	for i in range(0, ids.size(), 3):
		packs.append([ids[i], ids[(i + 1) % ids.size()], ids[(i + 2) % ids.size()]])
	var packed := 0
	for pk: Array in packs:
		var sc3 := await _fight(&"korvan", int(HullData.Weight.MEDIUM), pk[0], [pk[1], pk[2]])
		if sc3 == null:
			continue
		for i2 in Router.combat.enemies.size():
			packed += 1
			_check_enemy(sc3, i2, "%s (%d of pack %s)" % [Router.combat.enemies[i2].template.id, i2, ",".join(PackedStringArray(pk))])
	print("  %d player hulls, %d enemy pictures, %d ships in packs, %d checks" % [hulls, foes, packed, _checked])
	_ok("some of each were checked", hulls > 0 and foes > 0)
	print("popplacetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


func _fight(m: StringName, w: int, foe: StringName, more: Array = []) -> SectorScreen:
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
	var extras: Array = []
	for x in more:
		extras.append(DB.enemies[x])
	Run.node_at().danger = maxi(Run.node_at().danger, 4)
	Router.start_combat(DB.enemies[foe], extras, false, false)
	await _frames(4)
	var sc := Router.current as SectorScreen
	if sc == null or Router.combat == null or sc._view == null:
		print("  (no fight for %s against %s)" % [m, foe])
		return null
	return sc


## Every pop a landing on this hull makes, as drawn at rest (before it rises).
func _pops_of(sc: SectorScreen, to_player: bool, who: int) -> Array:
	var fx := sc._view.fx
	fx._pops.clear()
	var q := {dealt = 6, absorbed = 5, missed = 1, hits = 2}
	sc._pop_hit(sc._pop_at(to_player, who, sc._pop_lines(q)), q, to_player)
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


func _check_enemy(sc: SectorScreen, who: int, what: String) -> void:
	var sl: EnemySlot = sc._view.slot(who)
	if not _ok("%s: has a slot" % what, sl != null and sl.art != null):
		return
	var ink := sl.ink_rect()
	_ok("%s: has ink" % what, ink.size.x > 4.0 and ink.size.y > 4.0)
	for t in ["-6", "-10 KILL"]:
		var r := sl.preview_rect(t)
		var d := r.get_center() - ink.get_center()
		_ok("%s: '%s' held over it is centred on its ink (off %.1f, %.1f)" % [what, t, d.x, d.y],
			absf(d.x) <= TOL and absf(d.y) <= TOL)
	var pops := _pops_of(sc, false, who)
	var ink_fx := sc._hull_ink(false, who)
	# No room above (high in a pack): on the hull, its words stepped back.
	var hushed := sl.intent_hushed()
	if hushed:
		print("  (%s: no room above, on the hull with its words hushed)" % what)
		var cx := ink_fx.get_center().x
		for row in pops:
			var r0: Rect2 = row[1]
			_ok("%s: '%s' centred on the ink across (off %.1f)" % [what, row[0], r0.get_center().x - cx],
				absf(r0.get_center().x - cx) <= TOL)
	else:
		_check_pops(pops, ink_fx, what)
	# Clear of every ship's words and readout, at rest and risen, and on screen.
	var fxg := sc._view.fx.get_global_transform()
	var inv := fxg.affine_inverse()
	var keep_out: Array = []
	for i in Router.combat.enemies.size():
		var s2: EnemySlot = sc._view.slot(i)
		if s2 == null:
			continue
		var areas: Array = [s2.readout_rect_global()]
		if not (i == who and hushed):
			areas.append(s2.intent_rect_global())
		for g: Rect2 in areas:
			if g.size.x > 0.0 and g.size.y > 0.0:
				keep_out.append([i, Rect2(inv * g.position, g.size)])
	var words := sl.intent_rect_global()
	var top_g := sc._view.get_global_rect().position.y
	if Router.hud != null and Router.hud.is_visible_in_tree():
		top_g = maxf(top_g, Router.hud.get_global_rect().end.y)
	var top := (inv * Vector2(0.0, top_g)).y
	for row in pops:
		var r: Rect2 = (row[1] as Rect2).grow(1.0)
		var risen := Rect2(r.position - Vector2(0.0, HitText.RISE), r.size)
		if words.size.y > 0.0 and not hushed:
			_ok("%s: '%s' above its intent words (bottom %.1f, words' top %.1f)" % [what, row[0], r.end.y, (inv * words.position).y],
				r.end.y <= (inv * words.position).y)
		for k in keep_out:
			var o: Rect2 = k[1]
			_ok("%s: '%s' clear of ship %d's words/readout" % [what, row[0], k[0]],
				not r.intersects(o) and not risen.intersects(o))
		_ok("%s: '%s' on screen, risen (top %.1f, limit %.1f)" % [what, row[0], risen.position.y, top],
			risen.position.y >= top)
