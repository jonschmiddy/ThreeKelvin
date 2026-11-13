extends Node

## TRIAL: the `-- yardinfo=B1|B2|B3` band and dossier box-tested, every word,
## icon, stack, key and chip against every other and the hulls, for each
## open manufacturer's three ships picked. `-- sheet=YardInfoFit yardinfo=B1`.

var _bad: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	if DevMode.available:
		DevMode.enabled = true
	Router.new_run(4242)
	await Harness.frames(get_tree(), 6)
	var cs := Router.current as ChassisSelect
	var checked := 0
	for m: StringName in DB.STARTABLE:
		cs._select(DB.STARTABLE.find(m))
		for w: HullData.Weight in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			cs._pick_weight(w)
			await Harness.frames(get_tree(), 3)
			_fit(cs, "%s %s" % [m, HullData.weight_name(w)])
			checked += 1
	print("yardinfofit %s: %d picks, %d overlaps" % [YardInfoTrial.opt(), checked, _bad.size()])
	for b in _bad.slice(0, 20):
		print("  OVER " + b)
	get_tree().quit(0 if _bad.is_empty() else 1)


func _fit(cs: ChassisSelect, when: String) -> void:
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	for n in cs._band.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c is YardInfoTrial.DeckStrip or c.get_parent() is YardInfoTrial.DeckStrip:
			continue
		if c is Label and (c as Label).text.strip_edges() != "":
			boxes.append(_ink(c as Label))
			names.append((c as Label).text.left(18))
		elif c is YardInfoTrial.PartIcon or c is YardInfoTrial.DeckStack or c is YardInfoTrial.Emblem or c is Button:
			boxes.append(c.get_global_rect())
			names.append(c.get_class() if not (c is Button) else (c as Button).text)
	var d := cs.get_node_or_null(^"Dossier") as Control
	var things: Array[Rect2] = []
	for s: YardStandSet in cs._yard.sets.values():
		things.append(Rect2(s.thing))
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if _hit(boxes[i], boxes[j]) and not boxes[i].encloses(boxes[j]) and not boxes[j].encloses(boxes[i]):
				_bad.append("%s: %s x %s" % [when, names[i], names[j]])
		if not Rect2(0, 0, 960, 540).encloses(boxes[i]):
			_bad.append("%s: %s off screen" % [when, names[i]])
	if d != null:
		var dr := Rect2(d.position.x, d.position.y, d.size.x, d.size.y)
		for t in things:
			if _hit(dr, t):
				_bad.append("%s: the dossier over a hull at %s" % [when, t])
		if dr.end.y > 404.0:
			_bad.append("%s: the dossier into the band" % when)


## A label's box as its text is set, not its control's.
static func _ink(l: Label) -> Rect2:
	var f := UITheme.pixel_font()
	var px := l.get_theme_font_size(&"font_size")
	var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.custom_minimum_size.x > 0.0:
		var lines := YardInfoTrial._lines(l.text, int(l.custom_minimum_size.x))
		return Rect2(l.global_position, Vector2(minf(w, l.custom_minimum_size.x), lines * YardInfoTrial.LINE))
	return Rect2(l.global_position, Vector2(w, float(px) + 2.0))


static func _hit(a: Rect2, b: Rect2) -> bool:
	var r := a.intersection(b)
	return r.size.x > 0.0 and r.size.y > 0.0
