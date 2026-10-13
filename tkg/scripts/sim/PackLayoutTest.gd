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
	var modes: Array = [&"A", &"B", &"C"] if _arg("packlayout", "all") == "all" else [StringName(_arg("packlayout"))]
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


func _check(tree: SceneTree, tag: String, pack: Array, home: Vector2, wreck: bool) -> void:
	var cb = Router.combat
	if cb == null:
		_ok("%s: a fight" % tag, false)
		return
	for i in pack.size():
		var e: Combat.EnemyState = cb.enemies[i]
		e.template = DB.enemies[pack[i][0]]
		e.look = int(pack[i][1])
		e.max_hp = e.template.max_hull
		e.hp = 0 if (wreck and i == 0) else e.max_hp
		e.pick_intent()
	Sig.enemy_changed.emit()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	# (headless, nothing eases: a move lands on the frame it is laid out)
	var view := _view()
	if view == null:
		_ok("%s: the fight has a view" % tag, false)
		return
	var boxes: Array = []   # [owner, what, Rect2]
	var i := 0
	while view.slot(i) != null:
		for b in _slot_boxes(view.slot(i)):
			boxes.append([i, b[0], b[1]])
		i += 1
	var you := _you(view)
	_ok("%s: your ship stays where it stood (%s, was %s)" % [tag, you[0].position, home], you[0].position.distance_to(home) <= 1.0)
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


func _who(i: int) -> String:
	return "yours" if i < 0 else "ship %d" % i


## A slot's boxes, read off its own nodes: the ship's ink at rest, every line of
## its readout, its bars and its chips.
func _slot_boxes(s: EnemySlot) -> Array:
	var out: Array = []
	var art: EnemyArt = s.art
	var holder: Control = s.get("_art_holder")
	var base: Vector2 = s.get("_art_base") if s.get("_art_base") != null else Vector2.ZERO
	var u := Rect2(art.used_rect())
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
