class_name OutcomeCheck
extends RefCounted

## WHAT AN EVENT'S RESULT SAYS YOU ENDED UP WITH, checked against what actually
## moved (`OutcomeRow`, all four looks). Shared by `-- localeventtest` (every
## choice of every option, in the bare band) and `-- sheet=OutcomeTest` (real
## outcomes on the real LOCAL, with the HUD).
##
## The expectation is read off the RUN, not off `OutcomeRow`: the ledger either
## side of the choice, the system's pile, the hold, the found frame and the
## archive, diffed here. A look that drew what `OutcomeRow.changes` said would
## agree with itself whatever the run did.
##
## THE NUMBERS: today's four pairs ("HULL -5", "CREDITS —"); A and C one entry
## for every change and nothing else ("-5 HULL", "+1 PART: ...", no dash
## anywhere); B a row for every change with its totals ("HULL -5 35 > 30");
## NOTHING GAINED OR LOST when nothing moved.
##
## THE BOXES (fit means nothing overlaps): every entry inside the band, apart
## from every other entry, off every button (CONTINUE, REWARD, CHOOSE AGAIN,
## THEY ARE FIRING), off the text, the head and the YOU CHOSE line; B's rows
## inside their own column; and CONTINUE where today's look puts it.

const WORDS := {"credits": "CREDITS", "heat": "HEAT", "hp": "HULL", "fuel": "FUEL"}
const BUTTONS := ["Continue", "Reward", "ChooseAgain", "TheyAreFiring"]


## Everything a choice could move, before it runs.
static func snapshot(n: MapGen.MapNode) -> Dictionary:
	var pile := Run.sector_jetsam(n, false)
	return {
		ledger = Run.ledger(),
		pile = (pile.items as Array).duplicate() if pile != null else [],
		hold = Run.cargo.duplicate(),
		frame = Run.found_hull,
		docs = Archive.count(),
	}


## What it did move: {stats: {key: [n, was, now]}, gained: {name: count},
## lost: {name: count}, frame, doc, place}.
static func expect(n: MapGen.MapNode, before: Dictionary, res: Dictionary) -> Dictionary:
	var now := Run.ledger()
	var stats := {}
	for k in WORDS:
		stats[k] = [int(now[k]) - int(before.ledger[k]), int(before.ledger[k]), int(now[k])]
	var gained := {}
	var kind := {}
	var pile := Run.sector_jetsam(n, false)
	if pile != null:
		for it in pile.items:
			if not (before.pile as Array).has(it):
				var nm := String((it as Resource).get("name")).to_upper()
				gained[nm] = int(gained.get(nm, 0)) + 1
				kind[nm] = "part" if it is ModuleData else ("material" if it is MaterialData else "item")
	var lost := {}
	for it in before.hold:
		if not Run.cargo.has(it):
			var nm2 := String((it as Resource).get("name")).to_upper()
			lost[nm2] = int(lost.get(nm2, 0)) + 1
			kind[nm2] = "part" if it is ModuleData else ("material" if it is MaterialData else "item")
	return {
		stats = stats, gained = gained, lost = lost, kind = kind,
		frame = Run.found_hull != null and Run.found_hull != before.frame,
		doc = Archive.count() > int(before.docs),
		place = res.has("place"),
	}


## Every drawn outcome entry of drawer d: [{rect, text, col, cw}].
static func entries(d: LocalEventDrawer) -> Array:
	var outl: Array = []
	for nd in d.get_tree().get_nodes_in_group(OutcomeRow.GROUP):
		if not d.is_ancestor_of(nd) or not (nd as CanvasItem).is_visible_in_tree():
			continue
		if nd.has_method(&"entry_boxes"):
			outl.append_array(nd.call(&"entry_boxes"))
		else:
			outl.append({rect = (nd as Control).get_global_rect(), text = String(nd.get_meta(&"outcome_text", "")), col = -1, cw = 0.0})
	return outl


## The failures, as lines; empty when the look said it right and fits.
static func check(d: LocalEventDrawer, look: StringName, want: Dictionary) -> Array:
	var bad: Array = []
	var ents := entries(d)
	var texts: Array = ents.map(func(x: Dictionary) -> String: return String(x.text))
	var said := ", ".join(texts)
	var changed := 0
	for k in WORDS:
		var s: Array = want.stats[k]
		if int(s[0]) != 0:
			changed += 1
	var things := (want.gained as Dictionary).size() + (want.lost as Dictionary).size() \
		+ (1 if want.frame else 0) + (1 if want.doc else 0) + (1 if want.place else 0)
	match look:
		&"today":
			for k in WORDS:
				var s: Array = want.stats[k]
				var t := "%s %s" % [WORDS[k], "—" if int(s[0]) == 0 else "%+d" % int(s[0])]
				if not texts.has(t):
					bad.append("today: no '%s' in [%s]" % [t, said])
		&"A", &"C", &"B", &"D":
			for k in WORDS:
				var s: Array = want.stats[k]
				if int(s[0]) == 0:
					continue
				var t := "%+d %s" % [int(s[0]), WORDS[k]]
				if look == &"B":
					t = "%s %+d %d > %d" % [WORDS[k], int(s[0]), int(s[1]), int(s[2])]
				elif look == &"D":
					t = "%s %+d %d" % [WORDS[k], int(s[0]), int(s[2])]
				if not texts.has(t):
					bad.append("%s: no '%s' in [%s]" % [look, t, said])
			for nm in want.gained:
				var c := int(want.gained[nm])
				if not texts.any(func(t: String) -> bool: return t.begins_with("+%d" % c) and t.contains(nm)):
					bad.append("%s: gained %d %s not said in [%s]" % [look, c, nm, said])
			for nm in want.lost:
				var c2 := int(want.lost[nm])
				if not texts.any(func(t: String) -> bool: return t.begins_with("-%d" % c2) and t.contains(nm)):
					bad.append("%s: lost %d %s not said in [%s]" % [look, c2, nm, said])
			if want.frame and not texts.any(func(t: String) -> bool: return t.begins_with("+1 HULL FRAME")):
				bad.append("%s: the hull frame not said in [%s]" % [look, said])
			if want.doc and not texts.any(func(t: String) -> bool: return t.begins_with("+1 DOCUMENT")):
				bad.append("%s: the document not said in [%s]" % [look, said])
			if want.place and not texts.any(func(t: String) -> bool: return t.begins_with("MARKED")):
				bad.append("%s: the marked place not said in [%s]" % [look, said])
			if said.contains("—"):
				bad.append("%s: a dash in [%s]" % [look, said])
			var named := texts.filter(func(t: String) -> bool: return t != "")
			if changed + things == 0:
				if not texts.has(OutcomeRow.NOTHING):
					bad.append("%s: nothing moved and it does not say so: [%s]" % [look, said])
			elif named.size() < changed + (want.gained as Dictionary).size() + (want.lost as Dictionary).size():
				bad.append("%s: %d entries for %d changes: [%s]" % [look, named.size(), changed + things, said])
	bad.append_array(boxes(d, look, ents))
	if look == &"D":
		bad.append_array(table_place(d))
	return bad


## D's table sits directly over the buttons, its right edge on theirs, at
## least their width (in every layout: on the card too it is right-aligned
## over them).
static func table_place(d: LocalEventDrawer) -> Array:
	var bad: Array = []
	var t := d.panel.find_child("OutcomeTable", true, false) as Control
	var b := d._choices
	if t == null or b == null:
		return ["D: no table or no buttons"]
	var tr := t.get_global_rect()
	var br := b.get_global_rect()
	if absf(tr.end.x - br.end.x) > 0.5:
		bad.append("D: the table ends at x %d, the buttons at %d" % [int(tr.end.x), int(br.end.x)])
	if tr.size.x < br.size.x - 0.5:
		bad.append("D: the table %d wide, narrower than the buttons' %d" % [int(tr.size.x), int(br.size.x)])
	if tr.end.y > br.position.y + 0.5:
		bad.append("D: the table %s comes down onto the buttons %s" % [tr, br])
	if br.position.y - tr.end.y > 12.0:
		bad.append("D: the table %s floats %d px above the buttons" % [tr, int(br.position.y - tr.end.y)])
	return bad


## The box test. Rects are global and in game px.
static func boxes(d: LocalEventDrawer, look: StringName, ents: Array) -> Array:
	var bad: Array = []
	if d.panel == null:
		return ["no band"]
	var band := d.panel.get_global_rect()
	var keep_off: Array = []
	for nm in BUTTONS:
		var b := d.panel.find_child(nm, true, false) as Control
		if b != null and b.is_visible_in_tree():
			keep_off.append([nm, b.get_global_rect()])
	for nm in ["Head", "Chose"]:
		var c := d.panel.find_child(nm, true, false) as Control
		if c != null and c.is_visible_in_tree():
			keep_off.append([nm, _ink_rect(c)])
	if d._scroll != null and d._scroll.is_visible_in_tree():
		keep_off.append(["the text", d._scroll.get_global_rect()])
	for i in ents.size():
		var e: Dictionary = ents[i]
		var r: Rect2 = e.rect
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			bad.append("%s: '%s' has no box" % [look, e.text])
			continue
		if not band.encloses(r):
			bad.append("%s: '%s' %s is off the band %s" % [look, e.text, r, band])
		for k in keep_off:
			if r.intersects(k[1]):
				bad.append("%s: '%s' %s is on %s %s" % [look, e.text, r, k[0], k[1]])
		for jj in range(i + 1, ents.size()):
			var r2: Rect2 = ents[jj].rect
			if r.intersects(r2):
				bad.append("%s: '%s' and '%s' overlap" % [look, e.text, ents[jj].text])
		if int(e.get("col", -1)) >= 0:
			var led := d.panel.find_child("OutcomeLedger", true, false) as Control
			if led != null:
				var x0 := led.global_position.x + (0.0 if int(e.col) == 0 else float(e.cw) + 12.0)
				if r.position.x < x0 - 0.01 or r.end.x > x0 + float(e.cw) + 0.01:
					bad.append("%s: '%s' crosses its column" % [look, e.text])
	return bad


## A label's box is its text's, not the row it was stretched across.
static func _ink_rect(c: Control) -> Rect2:
	if c is Label:
		var l := c as Label
		var f := l.get_theme_font(&"font")
		var fs := l.get_theme_font_size(&"font_size")
		var w := minf(l.size.x, f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) if l.autowrap_mode == TextServer.AUTOWRAP_OFF else l.size.x
		return Rect2(l.global_position, Vector2(w, l.size.y))
	if c is BoxContainer:
		var r := Rect2()
		for k in c.get_children():
			if k is Control and (k as Control).is_visible_in_tree() and (k as Control).size.x > 0.0:
				var g := _ink_rect(k as Control)
				r = g if r.size == Vector2.ZERO else r.merge(g)
		return r
	return c.get_global_rect()


# ------------------------------------------------------------------ real cases

## Seeds of the event stream each choice is tried on.
const SEEDS := 8

## The starting ship every try is made from, so a found case replays.
static func reset(n: MapGen.MapNode, id: StringName, seed_v: int) -> void:
	n.options.clear()
	n.options.append(id)
	n.taken.clear()
	n.results.clear()
	n.left.clear()
	n.said.clear()
	n.jetsam.clear()
	n.cleared = false
	n.ambush_pending = false
	Run.at = n.index
	Run.dead = false
	Run.cargo.clear()
	Run.found_hull = null
	Run.hp = Run.max_hp() - 4
	Run.heat = 2
	Run.fuel = 120
	Run.credits = 180
	Rng.event.seed = seed_v
	Rng.loot.seed = seed_v * 7 + 1
	Rng.world.seed = seed_v * 13 + 5


static func find_cases(n: MapGen.MapNode, verbose: bool = false) -> Dictionary:
	var found := {}
	var best_big := -1
	var sigs := {}
	for o in OptionTable.all():
		var choices: Array = o.get("choices", [])
		for j in choices.size():
			var c: Dictionary = choices[j]
			if c.has("needs_material"):
				continue
			for s in SEEDS:
				reset(n, StringName(o.id), s + 1)
				var before := OutcomeCheck.snapshot(n)
				var r: Dictionary = await OptionResolve.take(n, 0, j)
				if not r.get("ok", false) or r.get("dead", false) or r.get("fight_now", false):
					continue
				var res: Dictionary = r.get("res", {})
				var want := OutcomeCheck.expect(n, before, res)
				var sg := sig(want)
				var fight := bool(res.get("fight", false))
				var key := ", ".join(sg) if not sg.is_empty() else "nothing"
				sigs[key] = int(sigs.get(key, 0)) + 1
				var rec := {id = String(o.id), j = j, seed = s + 1, sig = key, stay = bool(r.get("stay", false))}
				var st: Dictionary = want.stats
				var moved := func(k: String) -> int: return int((st[k] as Array)[0])
				var parts := 0
				for nm in want.gained:
					if want.kind.get(nm, "") == "part":
						parts += 1
				var lostn := (want.lost as Dictionary).size()
				if not found.has("jon") and o.id == &"drifting_lifepod" and j == 0 and moved.call("hp") < 0 \
						and sg.size() == 1:
					found["jon"] = rec
				if not found.has("gain") and moved.call("credits") > 0 and parts > 0 and moved.call("hp") >= 0 \
						and moved.call("fuel") >= 0 and moved.call("heat") <= 0 and lostn == 0 and not fight:
					found["gain"] = rec
				# (credits up, fuel down AND heat up is in no authored choice -- the
				# survey says so -- so the mix is credits up and fuel down, with
				# heat if one ever does)
				if moved.call("credits") > 0 and moved.call("fuel") < 0 and (not found.has("mix")
						or (moved.call("heat") > 0 and not String(found["mix"].sig).contains("heat+"))):
					found["mix"] = rec
				if not found.has("card") and parts > 0 and sg.size() == 1 and not fight:
					found["card"] = rec
				if not found.has("nothing") and sg.is_empty() and not rec.stay and not fight:
					found["nothing"] = rec
				# THE MOST LINES: every stat moved and every different thing named
				var lines := (sg.size() - (1 if sg.has("part+") else 0) - (1 if sg.has("material+") else 0)
					+ (want.gained as Dictionary).size())
				# (a tie goes to the one with a part: its cards make the longest line)
				lines = lines * 10 + (1 if parts > 0 else 0)
				if lines > best_big and not fight:
					best_big = lines
					found["big"] = rec
	# WHAT THE TABLE CAN DO, counted over every choice and seed
	var keys := sigs.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(sigs[a]) > int(sigs[b]))
	var kinds := {}
	for k: String in keys:
		for bit in k.split(", "):
			kinds[bit] = int(kinds.get(bit, 0)) + int(sigs[k])
	print("  outcomeshot: survey %d outcome shapes; each kind of change, by count: %s" % [keys.size(), kinds])
	if verbose:
		for k: String in keys:
			print("    %5d  %s" % [int(sigs[k]), k])
	return found


## The change kinds an outcome made: "hp-", "credits+", "part+", "frame+".
static func sig(want: Dictionary) -> Array:
	var outs: Array = []
	for k in ["hp", "fuel", "credits", "heat"]:
		var d := int((want.stats[k] as Array)[0])
		if d != 0:
			outs.append("%s%s" % [k, "+" if d > 0 else "-"])
	var g := {}
	for nm in want.gained:
		g["%s+" % want.kind.get(nm, "item")] = true
	for nm in want.lost:
		g["%s-" % want.kind.get(nm, "item")] = true
	outs.append_array(g.keys())
	if want.frame:
		outs.append("frame+")
	if want.doc:
		outs.append("document+")
	if want.place:
		outs.append("place+")
	return outs
