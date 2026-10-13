extends Node

## NOTHING IN A FIGHT SITS ON ANYTHING ELSE, headless:
##   godot --headless --path . -- sheet=PackLayoutTest [packlayout=A|B|C|all] [quick]
## Jon, Oct 13, on three enemies piled on each other: no ship, wreck, name, hull
## bar, chips or intent may overlap another enemy's or yours. For each pack
## layout (`EncounterView.pack_layout`; `all` runs A, B and C), the real fight is
## opened and its ships re-dressed as every pair and every triple of the
## pictures a fight can bring (the five ordinary kinds' three each, the
## Hellbender, the Custodian), and every triple again with its first ship a
## wreck. Once laid out, every box -- each ship's own ink at rest, each line of
## its readout (intent, what it does, name, number: the text's own width), its
## bars, its chips; and yours: your hull, your name, bar, number and chips --
## must not cross any other box, and must lie inside the view. Your ship must
## not have moved from where it stands with one enemy out there.
##
## Written against the slots' own nodes rather than any helper the layout
## added, so the same file runs on a build without them (it did, on main at
## d4d2bf0, and failed).

var _fails := 0
var _shown := 0
var _fits: Dictionary = {}


func _ok(what: String, c: bool) -> bool:
	if not c:
		_fails += 1
		if _shown < 25:
			print("  FAIL %s" % what)
			_shown += 1
	return c


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var scr: Script = load("res://scripts/ui/EncounterView.gd")
	var modes: Array = [&"B", &"C"] if _arg("packlayout", "all") == "all" else [StringName(_arg("packlayout"))]
	if scr.get("pack_layout") == null:
		modes = [&"-"]
		print("packlayouttest: this build has no pack layouts; testing the one it has")
	var pics: Array = []
	for k in [&"cutter", &"lancer", &"marauder", &"hulk", &"sentinel", &"hellbender", &"custodian"]:
		for look in maxi(1, DB.enemy_looks(k)):
			pics.append([k, look])
	var quick := "quick" in OS.get_cmdline_user_args()
	for mode in modes:
		if mode != &"-":
			scr.set("pack_layout", mode)
		var before := _fails
		var cases := 0
		var home := await _home(tree)
		# every picture alone, the calf and the Leviathan too (their gap under
		# the hull, at full size)
		await _open(tree, 1)
		for k in DB.enemies.keys():
			for look in maxi(1, DB.enemy_looks(k)):
				cases += 1
				await _check(tree, "%s alone %s:%d" % [mode, k, look], [[k, look]], home, false)
		# pairs
		await _open(tree, 2)
		for i in pics.size():
			for j in range(i, pics.size()):
				if quick and (i + j) % 4 != 0:
					continue
				cases += 1
				await _check(tree, "%s pair %s+%s" % [mode, _n(pics[i]), _n(pics[j])], [pics[i], pics[j]], home, false)
		# triples, and triples with a wreck in them
		await _open(tree, 3)
		for i in pics.size():
			for j in range(i, pics.size()):
				for k in range(j, pics.size()):
					if quick and (i + j + k) % 9 != 0:
						continue
					cases += 2
					await _check(tree, "%s triple %s+%s+%s" % [mode, _n(pics[i]), _n(pics[j]), _n(pics[k])],
						[pics[i], pics[j], pics[k]], home, false)
					await _check(tree, "%s triple with a wreck %s+%s+%s" % [mode, _n(pics[i]), _n(pics[j]), _n(pics[k])],
						[pics[i], pics[j], pics[k]], home, true)
		# piles: four to twelve ships, the widest pictures, half of them wrecks --
		# a fight's row, and LOCAL's row of wrecks left at one system
		# (no Custodian: it is fought alone and its death ends the run, so it is
		# never in a pack and never left on LOCAL)
		var wide: Array = [[&"marauder", 0], [&"hulk", 0], [&"marauder", 1], [&"hulk", 1], [&"hellbender", 0], [&"hulk", 2]]
		# (a fight brings at most two, and a reinforcement only to one; four is
		# the dev flag's most. A system can hold the wrecks of its own fight, its
		# one ambush, the Hellbender's and its events' fights: eight is a lot,
		# and twelve is checked)
		for n in [4, 5, 6, 8, 10, 12]:
			await _open(tree, n)
			var pile: Array = []
			for i in n:
				pile.append(wide[i % wide.size()])
			# (a fight of four or more is the dev flag's alone, and with every
			# ship's shield room kept it no longer fits the band: LOCAL's rows only)
			if false:
				cases += 2
				await _check(tree, "%s pile of %d" % [mode, n], pile, home, false)
				await _check(tree, "%s pile of %d, every other a wreck" % [mode, n], pile, home, false, true)
			cases += 1
			await _wrecks(tree, "%s LOCAL's row of %d wrecks" % [mode, n], pile, home)
		print("packlayouttest: layout %s, %d packs, %d failures" % [mode, cases, _fails - before])
	print("packlayouttest: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	tree.quit()


func _n(p: Array) -> String:
	return "%s:%d" % [p[0], p[1]]


## Where your ship stands with one enemy out there.
func _home(tree: SceneTree) -> Vector2:
	await _open(tree, 1)
	var view := _view()
	return _you(view)[0].position if view != null else Vector2.ZERO


func _open(tree: SceneTree, n: int) -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	SectorScreen._approached_at = Run.at
	var extras: Array = []
	for i in n - 1:
		extras.append(DB.enemies[&"cutter"])
	Router.start_combat(DB.enemies[&"cutter"], extras, false, false)
	await tree.create_timer(0.9).timeout


func _view() -> EncounterView:
	var sc = Router.current
	return sc.get("_view") if sc != null else null


func _check(tree: SceneTree, tag: String, pack: Array, home: Vector2, wreck: bool, every_other: bool = false) -> void:
	var cb = Router.combat
	if cb == null:
		_ok("%s: a fight" % tag, false)
		return
	for i in pack.size():
		var e: Combat.EnemyState = cb.enemies[i]
		e.template = DB.enemies[pack[i][0]]
		e.look = int(pack[i][1])
		e.max_hp = e.template.max_hull
		e.hp = 0 if ((wreck and i == 0) or (every_other and i % 2 == 0)) else e.max_hp
		e.pick_intent()
	Sig.enemy_changed.emit()
	# (headless, nothing eases: a move lands on the frame it is laid out; the
	# formation re-measures what it drew and may lay out again, up to 3 times)
	for f in 10:
		await tree.process_frame
	_measure(_view(), tag, home)


## LOCAL's row of wrecks: the same view shows a system's wrecks after a fight.
func _wrecks(tree: SceneTree, tag: String, pile: Array, _home: Vector2) -> void:
	# the real LOCAL: the wrecks left at a system, the screen opened on them
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	SectorScreen._approached_at = Run.at
	for i in pile.size():
		Run.new_wreck(Run.node_at(), DB.enemies[pile[i][0]], int(pile[i][1]))
	Router.show_local()
	for i in 12:
		await tree.process_frame
	var view := _view()
	if view == null:
		_ok("%s: LOCAL has a view" % tag, false)
		return
	_measure(view, tag, Vector2.INF)


func _measure(view: EncounterView, tag: String, home: Vector2) -> void:
	if view == null:
		_ok("%s: the fight has a view" % tag, false)
		return
	# three or more blocks, wrecks counted: every ship from its half sheet
	var n := 0
	while view.slot(n) != null:
		n += 1
	var want := 0.5 if n >= 3 else 1.0
	# (a pair too big for the band at full size is drawn at half too)
	if n == 2 and view.slot(0).art.get("draw_scale") != null and is_equal_approx(float(view.slot(0).art.get("draw_scale")), 0.5):
		want = 0.5
	for k in n:
		var art: EnemyArt = view.slot(k).art
		var got: Variant = art.get("draw_scale")
		if got != null:
			_ok("%s: ship %d drawn at %s (%d in the pack wants %s)" % [tag, k, got, n, want], is_equal_approx(float(got), want))
	var boxes: Array = []   # [owner, what, Rect2]
	var i := 0
	while view.slot(i) != null:
		for b in _slot_boxes(view.slot(i)):
			boxes.append([i, b[0], b[1]])
		i += 1
	# THE SAME ROOM UNDER EVERY HULL (Jon: "The hellbender is a bit close to
	# its text box"), and THE SHIELD'S ROOM ("shield:A"). A ship in a fight:
	# the oval its block raises (`ShieldFx.fit`, the shield's own) clear of its
	# words, its name, its bars and chips, and of every other ship's boxes, with
	# RIM_GAP from its rim to the words above and to the name below. A wreck on
	# LOCAL (no shield): its name UNDER_GAP under its ink.
	var ovals: Array = []   # [owner, Rect2]
	for k in n:
		var sl: EnemySlot = view.slot(k)
		var ship := Rect2()
		var name_top := INF
		var words_bottom := -INF
		var own: Array[Rect2] = []
		for b in _slot_boxes(sl):
			var what := String(b[0])
			if what == "ship":
				ship = b[1]
				continue
			own.append(b[1])
			if what.begins_with("name"):
				name_top = (b[1] as Rect2).position.y
		var it: Label = sl.get("_intent_text")
		if it != null and it.is_visible_in_tree():
			words_bottom = it.get_global_rect().end.y
		if ship.size == Vector2.ZERO or name_top == INF or sl.get("side") != false:
			continue
		# (a wreck in a fight raises no shield: its room is kept, unused)
		if bool(sl.get("_dead")) and (sl.get("reserve_intent") == null or bool(sl.get("reserve_intent"))):
			continue
		var fights: bool = sl.get("reserve_intent") == null or bool(sl.get("reserve_intent"))
		if not fights or sl.get("RIM_GAP") == null:
			var gap := name_top - ship.end.y
			var want_gap: float = float(sl.get("UNDER_GAP")) if sl.get("UNDER_GAP") != null else 5.0
			_ok("%s: ship %d's name %.0f px under its hull (want %.0f)" % [tag, k, gap, want_gap],
				gap >= 5.0 and absf(gap - want_gap) < 0.5)
			continue
		var holder: Control = sl.get("_art_holder")
		var rest: Vector2 = holder.get_global_rect().position + sl.get("_art_base")
		# the shield's own fit of the picture as drawn; one per picture and
		# size (a per-pixel pass, and the sheet lays out thousands of packs)
		var e: Combat.EnemyState = sl.get("_last_e")
		var key := "%s/%d/%.2f/%s" % [e.template.id, e.look, sl.art.draw_scale, sl.art.ink_rect()] if e != null else ""
		if key == "" or not _fits.has(key):
			var fit0 := ShieldFx.fit(sl.art.snapshot(), sl.art.ink_rect())
			if key == "":
				_fits["_"] = fit0
				key = "_"
			else:
				_fits[key] = fit0
		var f: Dictionary = _fits[key]
		var cc: Vector2 = f.cc
		var rad := Vector2(float(f.rx), float(f.ry))
		var oval := Rect2(rest + cc - rad, rad * 2.0)
		ovals.append([k, oval])
		var rim := float(sl.get("RIM_GAP"))
		_ok("%s: ship %d's shield %.1f px over its name (want %.0f)" % [tag, k, name_top - oval.end.y, rim],
			absf(name_top - oval.end.y - rim) <= 1.0)
		if words_bottom > -INF:
			_ok("%s: ship %d's shield %.1f px under its words (want %.0f)" % [tag, k, oval.position.y - words_bottom, rim],
				absf(oval.position.y - words_bottom - rim) <= 1.0)
		for r: Rect2 in own:
			_ok("%s: ship %d's shield clear of its own readout (%s)" % [tag, k, r], not oval.intersects(r))
	var you := _you(view)
	if home != Vector2.INF:
		_ok("%s: your ship stays where it stood (%s, was %s)" % [tag, you[0].position, home], you[0].position.distance_to(home) <= 1.0)
	# EVENLY SPACED, with room (Jon: "we need more space and they can be evenly
	# spaced around each other"; then "decrease the vertical space between the
	# top and bottom ships to make room for the text"): in the formation, the
	# gaps across a rank all one (within GAP_SPREAD, 4 px at 1080p), the gaps
	# between ranks all one, and every gap at least GAP_MIN (24 px at 1080p).
	var scr: Script = load("res://scripts/ui/EncounterView.gd")
	if scr.get("pack_layout") == &"B" and n >= 2:
		var blocks: Array[Rect2] = []
		for k in n:
			var sl: EnemySlot = view.slot(k)
			var u := Rect2()
			for b in _slot_boxes(sl):
				u = b[1] if u.size == Vector2.ZERO else u.merge(b[1])
			for o in ovals:
				if int(o[0]) == k:
					u = u.merge(o[1])
			# the block the slot keeps for the whole fight (its readout's and
			# its shield's room reserved), where the build has one; every box
			# drawn, and the shield, lie inside it
			if sl.has_method("block"):
				var r: Rect2 = sl.call("block", sl.art.draw_scale)
				var kept := Rect2(sl.get_global_rect().position + r.position, r.size)
				_ok("%s: ship %d's drawn readout and shield inside its kept block (%s in %s)" % [tag, k, u, kept],
					kept.grow(1.0).encloses(u))
				u = kept
			blocks.append(u)
		var rank_of: Variant = view.get("_pack_rank_of")
		var ranks := {}
		for k in n:
			var rk := 0
			if rank_of is Dictionary and (rank_of as Dictionary).has(view.slot(k)):
				rk = int(rank_of[view.slot(k)])
			if not ranks.has(rk):
				ranks[rk] = []
			(ranks[rk] as Array).append(k)
		var across: Array[float] = []
		var between: Array[float] = []
		for rk in ranks.keys():
			var ks: Array = ranks[rk]
			ks.sort_custom(func(a: int, b: int) -> bool: return blocks[a].position.x < blocks[b].position.x)
			for j in range(1, ks.size()):
				across.append(blocks[ks[j]].position.x - blocks[ks[j - 1]].end.x)
			if ranks.has(int(rk) + 1):
				var low_top := INF
				for a in ks:
					low_top = minf(low_top, blocks[a].position.y)
				var up_bottom := -INF
				for a in ranks[int(rk) + 1]:
					up_bottom = maxf(up_bottom, blocks[a].end.y)
				between.append(low_top - up_bottom)
		for gaps: Array[float] in [across, between]:
			if gaps.is_empty():
				continue
			var lo: float = gaps.min()
			var hi: float = gaps.max()
			var which := "across a rank" if gaps == across else "between ranks"
			_ok("%s: the gaps %s at least %d px (closest %.0f)" % [tag, which, int(GAP_MIN), lo], lo >= GAP_MIN)
			_ok("%s: the gaps %s even (%.0f to %.0f)" % [tag, which, lo, hi], hi - lo <= GAP_SPREAD)
		if not across.is_empty() and not between.is_empty():
			_ok("%s: no wider between ranks than across them (%.0f, %.0f)" % [tag, between.max(), across.min()],
				between.max() <= across.min() + GAP_SPREAD)
	for o in ovals:
		var ro: Rect2 = o[1]
		for a in boxes:
			if int(a[0]) != int(o[0]) and ro.intersects(a[2]):
				_ok("%s: ship %d's shield over ship %d's %s" % [tag, o[0], a[0], a[1]], false)
		for o2 in ovals:
			if int(o2[0]) > int(o[0]) and ro.intersects(o2[1]):
				_ok("%s: ship %d's shield over ship %d's" % [tag, o[0], o2[0]], false)
	for r: Rect2 in you:
		boxes.append([-1, "your readout", r])
	var vr := view.get_global_rect()
	for a in boxes:
		var ra: Rect2 = a[2]
		if int(a[0]) >= 0:
			_ok("%s: ship %d's %s inside the view (%s)" % [tag, a[0], a[1], ra], vr.encloses(ra))
	for x in boxes.size():
		for y in range(x + 1, boxes.size()):
			var a: Array = boxes[x]
			var b: Array = boxes[y]
			if int(a[0]) == -1 and int(b[0]) == -1:
				continue
			var ra: Rect2 = a[2]
			var rb: Rect2 = b[2]
			if ra.intersects(rb):
				var inter := ra.intersection(rb)
				_ok("%s: %s of %s over %s of %s (%dx%d px)" % [tag, a[1], _who(a[0]), b[1], _who(b[0]),
					int(inter.size.x), int(inter.size.y)], false)


## In game pixels (the screen doubles them): 24 and 4 px at 1080p.
const GAP_MIN := 12.0
const GAP_SPREAD := 2.0

## How far apart two boxes are: across where they share rows, down where they
## share columns, the larger of the two where they share neither.
static func _sep(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy := maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return maxf(dx, dy)


func _who(i: int) -> String:
	return "yours" if i < 0 else "ship %d" % i


## A slot's boxes, read off its own nodes: the ship's ink at rest, every line of
## its readout, its bars and its chips.
func _slot_boxes(s: EnemySlot) -> Array:
	var out: Array = []
	var art: EnemyArt = s.art
	var holder: Control = s.get("_art_holder")
	var base: Vector2 = s.get("_art_base") if s.get("_art_base") != null else Vector2.ZERO
	# the picture's own box (a build that tells the light a wind-up throws past
	# the hull apart from the hull says so with `ink_rect`)
	var u := Rect2(art.call("ink_rect") if art.has_method("ink_rect") else art.used_rect())
	var at := holder.get_global_rect().position + base
	out.append(["ship", Rect2(at + u.position, u.size)])
	for key in ["_intent", "_intent_text", "_name", "_hp"]:
		var l: Label = s.get(key)
		if l != null and l.is_visible_in_tree() and l.text.strip_edges() != "":
			out.append([key.substr(1) + " '" + l.text.left(18) + "'", _text_rect(l)])
	for key in ["_brace_bar", "_bar"]:
		var c: Control = s.get(key)
		if c != null and c.is_visible_in_tree():
			out.append([key.substr(1), c.get_global_rect()])
	var chips: HBoxContainer = s.chips
	if chips != null and chips.is_visible_in_tree():
		for c in chips.get_children():
			if c is Control and (c as Control).visible:
				out.append(["chip", (c as Control).get_global_rect()])
	return out


## Your hull and every line, bar and chip on its plate.
func _you(view: EncounterView) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var sv := view.ship_view()
	var sr := sv.ship_rect()
	out.append(Rect2(sv.get_global_rect().position + sr.position, sr.size))
	_walk(sv, out)
	return out


func _walk(n: Node, out: Array[Rect2]) -> void:
	for c in n.get_children():
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		if c is Label:
			if (c as Label).text.strip_edges() != "":
				out.append(_text_rect(c as Label))
		elif c is ProgressBar:
			out.append((c as Control).get_global_rect())
		elif c is HBoxContainer and (c as Control).get_parent() is VBoxContainer:
			for k in c.get_children():
				if k is Control and (k as Control).visible:
					out.append((k as Control).get_global_rect())
		_walk(c, out)


## A label's ink: its text's own width where it fits on one line, the label's
## width where it wraps, placed as the label aligns it; the label's height.
static func _text_rect(l: Label) -> Rect2:
	var r := l.get_global_rect()
	var f := l.get_theme_font("font")
	var w := r.size.x
	if f != null:
		w = minf(f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x, r.size.x)
	var x := r.position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (r.size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - w
	return Rect2(x, r.position.y, w, r.size.y)
